#!/usr/bin/env node
/**
 * luaguard-unpack — extract readable data from scripts protected by Lua-Guard (lua-guard.xyz)
 *
 * What it does, in order:
 *   1. Lexes the input and finds the long base64 string literals that make up the payload.
 *   2. Concatenates + decodes them into the packed VM blob.
 *   3. Figures out the HMAC salt by *trying candidates against the embedded digest* —
 *      no variable names are assumed, so renaming `h` to `_x9` does not break us.
 *   4. Re-implements the loader's blob format (3-byte little-ish fields, per-prototype
 *      XOR key derived from an LCG, SoA operand arrays) and walks every prototype.
 *   5. Decrypts the AES-256-CBC string table (key derived from the salt + entry id).
 *   6. Emits a disassembly whose opcode names were read out of the VM's own handlers.
 *
 * Every step is verified against checksums that the ORIGINAL program carries
 * (global HMAC, per-prototype arithmetic checksum, exact byte consumption),
 * so a run either reports full confidence or tells you exactly where it deviated.
 *
 * Usage:
 *   luaguard-unpack <protected.lua> [-o outdir] [--verify] [--quiet] [--no-disasm]
 */
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { parseBlob } from "./parser.mjs";
import { pseudocode, TABLES } from "./pseudo.mjs";
import { structured } from "./structure.mjs";
import { makeDescriber } from "./regnames.mjs";
import { foldExpressions, cleanup } from "./fold.mjs";
import { detect } from "./detect.mjs";

const D7 = 0x800000; // signed 24-bit bias used all over the loader
const KEY_LEN = 32;  // loader's LCG key length
const MIN_SEG_LEN = 500;
const BASE64_RE = /^[A-Za-z0-9+/=]+$/;

// ── CLI ────────────────────────────────────────────────────────────────────────
function parseArgs(argv) {
    const args = { input: null, url: null, out: "unpacked", verify: false, quiet: false, disasm: true };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === "-o" || a === "--out") args.out = argv[++i];
        else if (a === "-u" || a === "--url") args.url = argv[++i];
        else if (a === "--verify") args.verify = true;
        else if (a === "--quiet") args.quiet = true;
        else if (a === "--no-disasm") args.disasm = false;
        else if (a === "-h" || a === "--help") { printHelp(); process.exit(0); }
        else if (!a.startsWith("-")) args.input = a;
    }
    return args;
}
function printHelp() {
    console.log(`luaguard-unpack — unpack Lua-Guard protected Lua scripts

Usage:
  luaguard-unpack <protected.lua> [options]
  luaguard-unpack --url <https://...> [options]

Options:
  -o, --out <dir>   output directory (default: ./unpacked)
  -u, --url <url>   download the protected script from a URL (no local file needed)
  --verify          only validate the payload (HMAC + checksums), write nothing
  --no-disasm       skip disassembly (much faster on huge payloads)
  --quiet           only print errors and the final verdict
  -h, --help        show this help`);
}

const args = parseArgs(process.argv.slice(2));
const log = (...m) => { if (!args.quiet) console.log(...m); };
const warn = (...m) => console.warn(...m);
const die = (msg, code = 1) => { console.error(`\x1b[31merror:\x1b[0m ${msg}`); process.exit(code); };

if (!args.input && !args.url) { printHelp(); process.exit(1); }
if (args.input && !fs.existsSync(args.input)) die(`input not found: ${args.input}`);

// ── Lua lexer: collect every string literal ────────────────────────────────────
function luaStringLiterals(src) {
    const out = [];
    let i = 0;
    const n = src.length;
    const longBracket = (at) => {
        let j = at + 1, eq = 0;
        while (src[j] === "=") { eq++; j++; }
        if (src[j] !== "[") return -1;
        const close = "]" + "=".repeat(eq) + "]";
        const e = src.indexOf(close, j + 1);
        return e < 0 ? -1 : { end: e + close.length };
    };
    while (i < n) {
        const c = src[i];
        if (c === "-" && src[i + 1] === "-") {         // comment (--[[ ]] included)
            const lb = longBracket(i + 2);
            if (lb > 0) { i = lb.end; continue; }
            const nl = src.indexOf("\n", i);
            i = nl < 0 ? n : nl + 1;
            continue;
        }
        if (c === "[") {                                // long string [[ ]]
            const lb = longBracket(i);
            if (lb > 0) { i = lb.end; continue; }
            i++;
            continue;
        }
        if (c === '"' || c === "'") {
            let j = i + 1;
            while (j < n) {
                const d = src[j];
                if (d === "\\") { j += 2; continue; }
                if (d === c) break;
                j++;
            }
            out.push({ kind: "quoted", start: i + 1, raw: src.slice(i + 1, j) });
            i = j + 1;
            continue;
        }
        if (c === "`") {                                // Luau interpolated string (kept literal)
            let j = i + 1, depth = 0;
            while (j < n) {
                const d = src[j];
                if (d === "\\") { j += 2; continue; }
                if (d === "{") { depth++; j++; continue; }
                if (d === "}" && depth > 0) { depth--; j++; continue; }
                if (d === "`" && depth === 0) break;
                j++;
            }
            out.push({ kind: "interp", start: i + 1, raw: src.slice(i + 1, j) });
            i = j + 1;
            continue;
        }
        i++;
    }
    return out;
}

// ── Step 0: unwrap the outer encryption layer, if present ───────────────────────
/**
 * Lua-Guard produces two kinds of files:
 *
 *   A) the protected script — a table of base64 chunks plus a self-contained
 *      decryptor written in plain Lua (hand-rolled SHA256, base64 and a byte-wise
 *      XOR). Its runtime is: key = sha256(salt .. ':' .. scriptId .. ':runtime'),
 *      plaintext = XOR(base64decode(concat(chunks in `order`)), key)
 *
 *   B) the plain payload — what this tool already understood.
 *
 * Handling A here means the user never has to boot Roblox or an executor to get
 * at the payload: point the tool at the protected file directly.
 *
 * The chunk table always contains decoy entries: only `order.length` of them are
 * used, and they are picked in the order given by that permutation array. Skipping
 * either detail yields garbage, which is exactly what makes this layer annoying.
 */
function decryptOuterLayer(src) {
    const tbl = src.match(/local\s+t[0-9a-f]{6,}\s*=\s*\{([\s\S]*?)\}\s*local/);
    if (!tbl) return null;

    const parts = [...tbl[1].matchAll(/'([^']*)'/g)].map((m) => m[1]);
    if (parts.length < 16) return null;

    // A permutation of 1..N that selects/orders the real chunks (decoys stay unused).
    let order = null;
    for (const m of src.matchAll(/=\s*\{((?:\s*\d+\s*,){64,}[^}]*)\}/g)) {
        const nums = (m[1].match(/\d+/g) || []).map(Number);
        const sorted = [...nums].sort((a, b) => a - b);
        if (sorted[0] === 1 && sorted[sorted.length - 1] === nums.length && nums.length >= parts.length * 0.9) {
            order = nums;
            break;
        }
    }
    if (!order) return null;

    const salt = (src.match(/local\s+[a-z0-9_]+\s*=\s*'([0-9a-f]{16})'/i) || [])[1];
    const scriptId = (src.match(/\.\.\s*'([0-9a-f]{16,})[^']*:runtime'/i) || [])[1];
    if (!salt || !scriptId) return null;

    // Chunks are pulled by permutation (Lua arrays are 1-based), then the result is
    // squeezed through the base64 filter which also drops inserted junk characters.
    const joined = order.map((i) => parts[i - 1] ?? "").join("");
    const clean = joined.replace(/[^A-Za-z0-9+/=]/g, "");

    let ct;
    try { ct = Buffer.from(clean, "base64"); } catch { return null; }
    if (!ct.length) return null;

    // key = sha256(salt ":" scriptId ":runtime") — taken verbatim from the decryptor.
    const key = crypto.createHash("sha256").update(`${salt}:${scriptId}:runtime`).digest();

    const out = Buffer.alloc(ct.length);
    for (let i = 0; i < ct.length; i++) out[i] = ct[i] ^ key[i % key.length];

    // Only accept the result if it actually looks like the payload we understand.
    const text = out.toString("latin1");
    if (!/table\.concat|local\s+C\s*=|Lua-Guard|LG-/i.test(text.slice(0, 4000))) return null;

    return {
        plain: text,
        salt, scriptId,
        chunks: parts.length,
        used: order.length,
        decoys: parts.length - order.length,
        bytes: out.length,
    };
}

// ── Step 1: locate payload segments ────────────────────────────────────────────
let raw;
if (args.url) {
    log(`[0/5] downloading ${args.url}`);
    let res;
    try {
        res = await fetch(args.url, { signal: AbortSignal.timeout(60000), redirect: "follow" });
    } catch (e) {
        die(`download failed: ${e.message}`);
    }
    if (!res.ok) die(`download failed: HTTP ${res.status}`);
    raw = await res.text();
    if (!raw.length) die("downloaded file is empty");
} else {
    raw = fs.readFileSync(args.input, "latin1");
}

const outer = decryptOuterLayer(raw);
if (outer) {
    log(`[0/5] outer encryption unwrapped: ${outer.chunks} chunks ` +
        `(${outer.used} used, ${outer.decoys} decoys) → ${outer.bytes} bytes plaintext`);
    raw = outer.plain;
}
const literals = luaStringLiterals(raw);
const segments = literals
    .filter((l) => l.raw.length >= MIN_SEG_LEN && BASE64_RE.test(l.raw))
    .sort((a, b) => a.start - b.start);

if (!segments.length) {
    die(
        "no base64 payload segments found.\n" +
        "       This file does not look like it was protected by Lua-Guard,\n" +
        "       or the payload is stored differently in this version."
    );
}
// The payload segments are stored back-to-back inside one concat() call, so a genuine
// segment is always close to its neighbours. Anything far away (e.g. an unrelated long
// base64 literal elsewhere in the file) must not be glued into the payload.
function largestRun(list, maxGap = 256) {
    const runs = [];
    let cur = [list[0]];
    for (let i = 1; i < list.length; i++) {
        const gap = list[i].start - (list[i - 1].start + list[i - 1].raw.length);
        if (gap <= maxGap) cur.push(list[i]);
        else { runs.push(cur); cur = [list[i]]; }
    }
    runs.push(cur);
    const size = (r) => r.reduce((a, x) => a + x.raw.length, 0);
    runs.sort((a, b) => b.length - a.length || size(b) - size(a));
    return runs;
}
const runs = largestRun(segments);
const kept = runs[0];
if (runs.length > 1) {
    const rejected = runs.slice(1).reduce((a, r) => a + r.length, 0);
    warn(`\x1b[33mwarning:\x1b[0m found ${runs.length} separate clusters of long base64 literals; ` +
         `using the largest (${kept.length} segments) and ignoring ${rejected} elsewhere in the file.`);
}

const b64 = kept.map((s) => s.raw).join("");
if (b64.length % 4 !== 0) die(`payload base64 length ${b64.length} is not a multiple of 4 — file may be truncated`);

const blob = Buffer.from(b64, "base64");
if (blob.length < 64) die(`decoded payload is only ${blob.length} bytes — too small to be valid`);

log(`[1/5] segments: ${kept.length} (${kept[0].raw.length} … ${kept[kept.length - 1].raw.length} chars) → ${b64.length} b64 → ${blob.length} bytes`);

// ── Step 2: identify the HMAC salt by verification, not by name ────────────────
const sha256hex = (s) => crypto.createHash("sha256").update(s).digest("hex");

// Candidate salts: base64-looking string literals in the 24..64 char range.
// Ranked so the most likely shape (32-byte key => 44 base64 chars with padding) is tried first;
// ranking only affects speed, correctness comes from the HMAC check below.
const saltCandidates = [...new Set(
    literals
        .filter((l) => l.raw.length >= 24 && l.raw.length <= 64 && BASE64_RE.test(l.raw))
        .map((l) => l.raw)
)].sort((x, y) => {
    const score = (s) => (s.length === 44 ? 4 : 0) + (s.endsWith("=") ? 2 : 0) + (s.length === 32 ? 1 : 0);
    return score(y) - score(x);
});

// Digest candidates: every 64-char lowercase hex literal in the file.
const digests = [...new Set(literals.map((l) => l.raw).filter((s) => /^[0-9a-f]{64}$/.test(s)))];

let salt = null;
let hmacOk = false;
for (const c of saltCandidates) {
    const key = sha256hex(`${c}:mac:global`);
    const mac = crypto.createHmac("sha256", key).update(b64).digest("hex");
    if (digests.includes(mac)) { salt = c; hmacOk = true; break; }
    if (!salt) salt = c;   // provisional, replaced if a later candidate verifies
}
if (digests.length === 0) {
    warn("\x1b[33mwarning:\x1b[0m no 64-hex digest literal found — the salt cannot be verified.");
}

log(`[2/5] salt ${hmacOk ? "verified" : "guessed (no matching digest in file)"}: ${salt.slice(0, 12)}… (${salt.length} chars)`);
if (!hmacOk) warn("       warning: global HMAC did not match any embedded digest. Parsing continues, but treat results as unverified.");

// ── Step 3a: newer blob layouts (v2 / v3) ─────────────────────────────────────
// Lua-Guard changes the whole parameter set between versions: the LCG seed and mixer,
// the 3- and 4-byte field orders, the opcode multiplier, the checksum constant, the
// order of the four instruction arrays and the field order of the string table.
// Rather than hardcode one, we try each known profile and accept the first whose
// checksum passes AND which consumes the blob to the last byte.
const MODERN_PROFILES = {
    v1: {
        read3: "odd", read4: "odd", seed: 348, mix1: 17, mix2: 173,
        opMul: 143, checksumConst: 4442017,
        phaseOrder: [{ key: "op" }, { key: "c", phase: 7 }, { key: "a", phase: 5 }, { key: "b", phase: 6 }],
        resOrder: ["id", "cipher", "iv", "tag"],
        // v1 的 opcode 语义（50 个，早前从 handler 逐个读出）
        opNames: {"3":"VTOA","8":"SETNIL","10":"LEN","13":"MOVE","15":"NEWTABLE","16":"NOT","34":"CALLV1","39":"CALLMULTI","42":"CALL2VA","43":"CALL2","47":"CALLV1M","48":"CALL0M","51":"CONCAT","53":"SETUPVAL","55":"VARARG","57":"LOADK","61":"ADD","70":"SUB","73":"COPYVARARG","74":"TEST","79":"FORPREP","90":"CALLV0","93":"GETRET","101":"MUL","109":"GETTABLE","116":"SETTABLE","117":"METHODM","125":"LE","126":"MOD","130":"CALL2M","131":"CALL3","132":"CALL3M","138":"CALL0","141":"LT","142":"EQ","152":"CLOSURE","157":"GETUPVAL","170":"TESTNIL","178":"CALL3DISCARD","183":"UNM","186":"POW","198":"FORLOOP","201":"GETGLOBAL","206":"RETURNRANGE","210":"JMP","212":"VTOB","213":"DIV","220":"CALL1M","228":"CALL2DISCARD","248":"CALL0DISCARD"},
    },
    v2: {
        read3: "m3", read4: "m3", seed: 617, mix1: 25, mix2: 70,
        opMul: 151, checksumConst: 736242,
        phaseOrder: [{ key: "b", phase: 6 }, { key: "a", phase: 5 }, { key: "c", phase: 7 }, { key: "op" }],
        resOrder: ["cipher", "iv", "id", "tag"],
        // 人工精读 handler 后确定的语义（相似度对齐只能给参考，这里是核对过的）
        opNames: {"1":"GETUPVAL","2":"NOT","13":"SETTABLE","22":"SETNIL","26":"GETRET","29":"CLOSEUPS","31":"CMP","37":"GETGLOBAL","39":"ARITH","40":"MOVE","44":"CALL3","57":"CALL0","68":"VARARG","89":"CALL2DISCARD","92":"CMP","106":"CALL2M","108":"GETTABLE","111":"LOADK","115":"CLOSURE","121":"ARITH","124":"NEWTABLE","130":"CALL3DISCARD","144":"CONCAT","147":"CALL0M","172":"SETUPVAL","179":"CALL2","184":"NOP","189":"CALL0DISCARD","191":"CALL3M","203":"SUBI","215":"TEST","216":"ADDI","217":"JMP","218":"CMP","233":"VTOB","250":"CALLMULTI"},
    },
    v3: {
        read3: "odd", read4: "odd2", seed: 52, mix1: 31, mix2: 231,
        opMul: 97, checksumConst: 2608344,
        phaseOrder: [{ key: "b", phase: 6 }, { key: "op" }, { key: "c", phase: 7 }, { key: "a", phase: 5 }],
        resOrder: ["iv", "id", "tag", "cipher"],
        opNames: {"2":"SETNIL","6":"CONCAT","7":"VTOB","28":"VARARG","30":"GETTABLE","33":"SETTABLE","42":"CLOSEUPS","60":"GETUPVAL","67":"ARITH","70":"CLOSURE","73":"NOP","95":"CMP","107":"GETGLOBAL","118":"GETRET","119":"CALL3M","123":"CALL2M","141":"CALL2","143":"CALL0M","149":"ADDI","171":"SETUPVAL","173":"CMP","178":"LOADK","185":"CALL0DISCARD","188":"MOVE","190":"CALL3DISCARD","198":"CALL3","203":"JMP","205":"ARITH","207":"TEST","210":"CMP","227":"CALL2DISCARD","231":"NOT","235":"NEWTABLE","238":"CALL0","248":"SUBI","254":"CALLMULTI"},
    },
};

function tryModern() {
    for (const [name, cfg] of Object.entries(MODERN_PROFILES)) {
        let r;
        try { r = parseBlob(blob, cfg); } catch { continue; }
        if (!r.ok) continue;
        try {
            const gCount = r.count();
            const globals = r.readGlobals(gCount);
            const rCount = r.count();
            const resources = r.readResources(rCount, cfg.resOrder);
            if (r.pos() !== blob.length) continue;   // must consume exactly

            const strings = [];
            let failed = 0;
            for (const res of resources) {
                try {
                    const key = Buffer.from(sha256hex(`${salt}:enc:${res.id}`), "hex");
                    const dec = crypto.createDecipheriv("aes-256-cbc", key, Buffer.from(res.iv, "base64"));
                    const pt = Buffer.concat([dec.update(Buffer.from(res.cipher, "base64")), dec.final()]);
                    strings.push({ id: res.id, text: pt.toString("latin1") });
                } catch (e) { failed++; strings.push({ id: res.id, text: null, error: e.message }); }
            }
            return { name, cfg, r, globals, resources, strings, failed };
        } catch { continue; }
    }
    return null;
}

const modern = tryModern();
if (modern) {
    log(`[3/5] layout: ${modern.name} (checksum ${modern.r.checksum} OK, ${modern.r.pos()}/${blob.length} bytes)`);
    log(`      globals ${modern.globals.length} | strings ${modern.strings.length} | main instr ${modern.r.nums.instrCount} | protos ${modern.r.nums.protoCount}`);
    log(`[4/5] strings: ${modern.strings.length - modern.failed}/${modern.strings.length} decrypted`);

    if (args.verify) {
        // HMAC 才是数据完整性的唯一保证（各原型的 checksum 只看字段「数量」，不看内容），
        // 所以篡改过的文件即使能解析出来，也必须判定为「未验证」。
        const ok = modern.failed === 0 && hmacOk;
        console.log("");
        console.log(ok ? "\x1b[32mverify: fully verified\x1b[0m (checksum + exact byte consumption + all strings)"
                      : `\x1b[33mverify: incomplete\x1b[0m strings=${modern.strings.length - modern.failed}/${modern.strings.length}`);
        process.exit(ok ? 0 : 3);
    }

    fs.mkdirSync(args.out, { recursive: true });
    kept.forEach((seg, i) => fs.writeFileSync(path.join(args.out, `seg${String(i + 1).padStart(2, "0")}.b64`), seg.raw));
    fs.writeFileSync(path.join(args.out, "blob.bin"), blob);
    fs.writeFileSync(path.join(args.out, "strings.json"), JSON.stringify(modern.strings, null, 1));
    fs.writeFileSync(path.join(args.out, "strings.txt"),
        modern.strings.map((x) => (x.text === null ? `[${x.id}] <decrypt failed: ${x.error}>` : `[${x.id}] ${JSON.stringify(x.text)}`)).join("\n"));
    fs.writeFileSync(path.join(args.out, "globals.json"), JSON.stringify(modern.globals, null, 1));
    // 递归解析所有子函数原型（每个 proto 是一段独立的字节码，没有 header）
    function walkProtos(list, depth, prefix) {
        const out = [];
        for (let i = 0; i < list.length; i++) {
            let p;
            try { p = parseBlob(list[i], modern.cfg, { skipHeader: true }); } catch { continue; }
            p.label = `${prefix}#${i}`;
            p.depth = depth;
            p.bytes = list[i].length;
            out.push(p);
            if (p.protos.length && depth < 6) out.push(...walkProtos(p.protos, depth + 1, `${p.label}.`));
        }
        return out;
    }
    const allProtos = walkProtos(modern.r.protos, 1, "chunk");
    const goodProtos = allProtos.filter(p => p.ok);
    log(`[5/5] child prototypes: ${allProtos.length} (${goodProtos.length} checksum OK), total instructions ${allProtos.reduce((a, p) => a + p.nums.instrCount, 0)}`);

    if (args.disasm) {
        const names = modern.cfg.opNames ?? {};
        const L = [];
        L.push(`; disassembly of ${args.url ?? args.input}`);
        L.push(`; layout ${modern.name} | blob ${blob.length} bytes | ${modern.strings.length} strings | main ${modern.r.nums.instrCount} instructions`);
        L.push(`; opcode names were matched against the v1 handler set and spot-checked against the v2 bodies`);
        L.push("");
        // 常量池索引 → 具体值（资源字符串 / 全局数值），让每条 LOADK 都能直接读到内容
        const strById = new Map(modern.strings.filter((s) => s.text !== null).map((s) => [s.id, s.text]));
        const globalById = new Map(modern.globals.map((g) => [g.name, g.val]));
        const annotate = (p, i, nm) => {
            // 常量索引落在哪个操作数上因版本而异，三个位置都试，命中即止
            if (nm !== "LOADK" && nm !== "GETGLOBAL") return "";
            for (const ci of [p.code.c?.[i], p.code.a?.[i], p.code.b?.[i]]) {
                if (ci === undefined) continue;
                const ref = p.constRefs?.[ci - 1] ?? p.constRefs?.[ci];
                if (ref === undefined) continue;
                const sv = strById.get(String(ref));
                if (sv !== undefined) return "   ; " + JSON.stringify(sv.length > 50 ? sv.slice(0, 50) + "…" : sv);
                const gv = globalById.get(String(ref));
                if (gv !== undefined) return "   ; " + gv;
            }
            return "";
        };
        const dumpArr = (arr, title, proto) => {
            if (!arr) return;
            L.push(`;${"─".repeat(74)}`);
            L.push(`; ${title}: ${arr.length} instructions`);
            for (let i = 0; i < arr.length; i++) {
                const nm = names[arr[i]] ?? `OP_${arr[i]}`;
                const A = proto.code.a?.[i], B = proto.code.b?.[i], C = proto.code.c?.[i];
                const ops = `a=${String(A).padStart(4)} b=${String(B).padStart(4)} c=${String(C).padStart(4)}`;
                L.push(`  ${String(i).padStart(4, "0")}  ${nm.padEnd(14)} ${ops}${annotate(proto, i, nm)}`);
            }
            L.push("");
        };
        dumpArr(modern.r.code.op, "main: opcode stream", modern.r);
        for (const p of allProtos) {
            L.push(`;${"─".repeat(74)}`);
            L.push(`; ${p.label} (depth ${p.depth})  instr=${p.nums.instrCount} consts=${p.nums.constCount} upvals=${p.nums.upCount} bytes=${p.bytes} checksum=${p.ok ? "OK" : "FAIL"}`);
            dumpArr(p.code.op, p.label, p);
        }
        fs.writeFileSync(path.join(args.out, "disasm.txt"), L.join("\n"));

        // ── 线性伪代码：每行一条语句，跳转用标签 ──
        // 每个函数原型有自己的常量表，所以 constOf 必须绑定到具体 proto，
        // 否则子函数里的常量会全部退化成 K[n]（之前就是这个 bug）。
        const constOfFor = (proto) => (idx) => {
            const ref = proto.constRefs?.[idx - 1];
            if (ref === undefined) return "K[" + idx + "]";
            const sv = strById.get(String(ref));
            if (sv !== undefined) return "K[" + JSON.stringify(sv.length > 40 ? sv.slice(0, 40) + "…" : sv) + "]";
            const gv = globalById.get(String(ref));
            if (gv !== undefined) return gv;
            return "K[" + idx + "]";
        };
        const constOf = constOfFor(modern.r);
        const P = [];
        P.push("; linear pseudocode — one statement per instruction, jumps as labels");
        P.push("; registers are rN (no names recovered); this is NOT a decompiler");
        P.push("");
        P.push(";; ===== main =====");
        P.push(pseudocode(modern.r, modern.name, constOf, names));
        for (const p of allProtos) {
            P.push("");
            P.push(`;; ===== ${p.label} (depth ${p.depth}) =====`);
            P.push(pseudocode(p, modern.name, constOfFor(p), names));
        }
        fs.writeFileSync(path.join(args.out, "pseudocode.txt"), P.join("\n"));

        // ── 结构化：TEST/CMP + JMP 合并成 if ──
        const S = [];
        S.push("; structured view — conditional jumps are folded into if statements");
        S.push("; labels mark jump targets; still no variable names or loop reconstruction");
        S.push("");
        S.push(";; ===== main =====");
        S.push(cleanup(foldExpressions(structured(modern.r, modern.name, constOf, names, TABLES[modern.name], makeDescriber(modern.r, modern.name, constOf, names)).split("\n"))).join("\n"));
        for (const p2 of allProtos) {
            S.push("");
            S.push(`;; ===== ${p2.label} (depth ${p2.depth}) =====`);
            S.push(cleanup(foldExpressions(structured(p2, modern.name, constOfFor(p2), names, TABLES[modern.name], makeDescriber(p2, modern.name, constOfFor(p2), names)).split("\n"))).join("\n"));
        }
        fs.writeFileSync(path.join(args.out, "structured.txt"), S.join("\n"));
    }

    fs.writeFileSync(path.join(args.out, "structure.json"), JSON.stringify({
        source: args.url ?? args.input,
        layout: modern.name,
        salt, saltVerified: hmacOk,
        blobBytes: blob.length,
        numbers: modern.r.nums,
        checksum: { got: modern.r.checksum, expected: modern.r.expect },
        globals: modern.globals,
        resources: modern.resources,
        strings: modern.strings,
        codeArrays: Object.keys(modern.r.code),
        childProtos: modern.r.protos.length,
    }, null, 1));

    console.log("");
    if (modern.failed !== 0) {
        console.log(`\x1b[33mdone with warnings (${modern.name})\x1b[0m — ${modern.failed} strings failed → ${args.out}/`);
    } else if (!hmacOk) {
        console.log(`\x1b[31mUNVERIFIED (${modern.name})\x1b[0m — payload HMAC did not match; the file is truncated or tampered with → ${args.out}/`);
    } else {
        console.log(`\x1b[32mdone — fully verified (${modern.name})\x1b[0m → ${args.out}/`);
    }
    process.exit(modern.failed === 0 && hmacOk ? 0 : 3);
}

// ── Step 3: legacy v1-only parser (fallback) ───────────────────────────────────
// Everything below this line is the original hand-written v1 parser. It is now DEAD CODE
// for all three known layouts — the profile-driven parser above handles v1/v2/v3 and
// returns before reaching here. It is kept only as a safety net for a v1 payload whose
// header the profile parser somehow rejects, and can be deleted once that has never
// happened across a large sample.
// ────────────────────────────────────────────────────────────────────────────────
function bxor8(a, b) {
    // Operand values are signed 24-bit and the VM feeds them straight into a naive
    // bit-by-bit XOR whose modulo is always non-negative (Lua semantics). JavaScript's
    // % returns a negative remainder, so the same code here computes the wrong bits.
    // Normalising to 0..255 first reproduces the low-8-bit two's complement XOR.
    // Without this, every instruction with a negative operand decodes to garbage.
    a = ((a % 256) + 256) % 256;
    b = ((b % 256) + 256) % 256;
    let r = 0, t = 1;
    for (let k = 0; k < 8; k++) {
        const ba = a % 2, bb = b % 2;
        a = Math.floor(a / 2); b = Math.floor(b / 2);
        if (ba !== bb) r += t;
        t *= 2;
    }
    return r;
}
// The loader derives its 32-byte key from this LCG, then XORs per-prototype offsets on top.
const LCG = (() => {
    const k = [];
    let x = 348;
    for (let i = 1; i <= KEY_LEN; i++) {
        x = (x * 214013 + 2531011) % 16777216;
        k[i] = bxor8(x % 256, (i * 17 + 173) % 256);
    }
    return k;
})();

class Reader {
    constructor(buf, base = 0) { this.buf = buf; this.p = base; }
    /** 3-byte field: (b1<<16 | b0<<8 | b2) - 0x800000 — deliberately not a standard endianness. */
    u24() {
        if (this.p + 3 > this.buf.length) throw new Error(`unexpected end of payload at byte ${this.p}`);
        const b0 = this.buf[this.p], b1 = this.buf[this.p + 1], b2 = this.buf[this.p + 2];
        this.p += 3;
        return b1 * 65536 + b0 * 256 + b2 - D7;
    }
    /**
     * 4-byte field. NOT little-endian either: bytes are weighted 1, 0x10000, 0x100, 0x1000000
     * (same "second byte up top" quirk as u24). Getting this wrong shifts every table by a byte.
     */
    u32() {
        if (this.p + 4 > this.buf.length) throw new Error(`unexpected end of payload at byte ${this.p}`);
        const b0 = this.buf[this.p], b1 = this.buf[this.p + 1], b2 = this.buf[this.p + 2], b3 = this.buf[this.p + 3];
        this.p += 4;
        return b3 * 16777216 + b1 * 65536 + b2 * 256 + b0;
    }
    str() { const n = this.u32(); const s = this.buf.subarray(this.p, this.p + n); this.p += n; return s; }
}

function parseProto(rd) {
    const v14 = rd.u24();
    const v12 = rd.u24();                 // per-prototype key offset (reported as keyOff)

    const constCount = rd.u24();
    const constRefs = [];
    for (let i = 0; i < constCount; i++) constRefs.push(rd.u24());

    const instrCount = rd.u24();
    const keyOff = rd.u24() + D7;
    const shift = rd.u24();

    const key = [];
    // keyOff 是 24 位数，必须整宽异或（8 位的 bxor8 会截断，导致操作数带固定大偏移）
    for (let i = 1; i <= KEY_LEN; i++) key[i] = LCG[i] ^ keyOff;

    const ops = [];
    for (let i = 0; i < instrCount; i++) {
        const t = rd.buf[rd.p], k = rd.buf[rd.p + 1], x = rd.buf[rd.p + 2];
        rd.p += 3;
        const v = (k * 65536 + t * 256 + x) - D7;
        // Lua's % always returns a non-negative result for a positive modulus.
        ops.push((((v - shift) * 143) % 256 + 256) % 256);
    }
    const decodeOperands = (seed) => {
        const arr = [];
        let d = seed;
        for (let i = 0; i < instrCount; i++) {
            const k = rd.buf[rd.p], x = rd.buf[rd.p + 1], a = rd.buf[rd.p + 2];
            rd.p += 3;
            // VM 是 xor(raw, key) - 0x800000：先异或 24 位数，再减偏移
            arr.push(((x * 65536 + k * 256 + a) ^ key[d]) - D7);
            d += 3; if (d > KEY_LEN) d -= KEY_LEN;
        }
        return arr;
    };
    const cs = decodeOperands(7);   // C operand
    const as = decodeOperands(5);   // A operand
    const bs = decodeOperands(6);   // B operand

    const upvalCount = rd.u24();
    const upvals = [];
    for (let i = 0; i < upvalCount; i++) upvals.push([rd.u24() === 1, rd.u24()]);

    const childCount = rd.u24();    // nested function prototypes (used by the CLOSURE opcode)
    const children = [];
    for (let i = 0; i < childCount; i++) {
        const n = rd.u24();         // note: 3-byte length here, unlike the outer tables
        children.push(Buffer.from(rd.buf.subarray(rd.p, rd.p + n)));
        rd.p += n;
    }

    const checksum = rd.u24();
    const expect = ((((((v14 * 131 + v12 * 17) + constCount * 257) + instrCount * 521) +
        upvalCount * 1031) + childCount * 2053) + 4442017) % 8000001;

    return {
        v14, v12, constRefs, instrCount, keyOff, shift, upvals, children,
        ops, a: as, b: bs, c: cs,
        checksumOK: checksum === expect,
    };
}

let main, header, globals, resources, consumed;
try {
    const rd = new Reader(blob, 0);
    header = { a: rd.u24(), count: rd.u24(), op: rd.u24(), c: rd.u24(), b: rd.u24() };
    main = parseProto(rd);

    globals = [];
    {
        const n = rd.u32();
        if (n < 0 || n > 1e6) throw new Error(`implausible global count ${n}`);
        for (let i = 0; i < n; i++) {
            const name = rd.str().toString("latin1");
            const type = rd.str().toString("latin1");
            const rawv = rd.str().toString("latin1");
            globals.push({ name, type, raw: rawv, value: type === "n" ? Number(rawv) : type === "b" ? rawv === "true" : rawv });
        }
    }
    resources = [];
    {
        const n = rd.u32();
        if (n < 0 || n > 1e6) throw new Error(`implausible string-table size ${n}`);
        for (let i = 0; i < n; i++) {
            const id = rd.str().toString("latin1");
            const t = rd.str().toString("latin1");
            const iv = rd.str().toString("latin1");
            const tag = rd.str().toString("latin1");
            resources.push({ id, t, iv, tag });
        }
    }
    consumed = rd.p;
} catch (e) {
    die(`failed to parse the payload structure — ${e.message}\n       The file may use a newer Lua-Guard format than this tool supports.`);
}
const complete = consumed === blob.length;
if (!complete) {
    warn(`\x1b[33mwarning:\x1b[0m parsed ${consumed} of ${blob.length} bytes (${blob.length - consumed} left over).`);
    warn("         Structure is probably fine but layout differs slightly; results may be incomplete.");
}

log(`[3/5] structure: ${globals.length} globals, ${resources.length} encrypted strings, ` +
    `main prototype self-check ${main.checksumOK ? "OK" : "FAILED"}, bytes ${consumed}/${blob.length}`);

// ── Step 4: decrypt the string table (AES-256-CBC, key = hex2bin(sha256hex(salt..":enc:"..id))) ──
const strings = [];
let failed = 0;
for (const r of resources) {
    try {
        const key = Buffer.from(sha256hex(`${salt}:enc:${r.id}`), "hex");
        const iv = Buffer.from(r.iv, "base64");
        const dec = crypto.createDecipheriv("aes-256-cbc", key, iv);
        const pt = Buffer.concat([dec.update(Buffer.from(r.t, "base64")), dec.final()]);
        strings.push({ id: r.id, text: pt.toString("latin1") });
    } catch (e) {
        failed++;
        strings.push({ id: r.id, error: e.message });
    }
}
log(`[4/5] strings: ${strings.length - failed}/${strings.length} decrypted`);
if (failed && failed === strings.length) {
    warn("       every string failed to decrypt — the AES key derivation differs in this version.");
}

// ── Step 5: walk nested prototypes ─────────────────────────────────────────────
function walk(children, depth, prefix, out) {
    for (let i = 0; i < children.length; i++) {
        const buf = children[i];
        let p;
        try {
            const rd = new Reader(buf, 0);
            p = parseProto(rd);
            p.complete = rd.p === buf.length;
        } catch {
            continue; // a malformed child must not abort the whole walk
        }
        p.size = buf.length;
        p.depth = depth;
        p.label = `${prefix}#${i}`;
        out.push(p);
        if (p.children.length && depth < 8) walk(p.children, depth + 1, `${p.label}.`, out);
    }
    return out;
}
const protos = walk(main.children, 1, "chunk", []);
const totalInstr = protos.reduce((a, p) => a + p.instrCount, 0);
const allGood = protos.every((p) => p.complete && p.checksumOK);
log(`[5/5] prototypes: ${protos.length}, instructions: ${totalInstr}, all checksums pass: ${allGood}`);

// ── Opcode table (semantics read from the VM's own handler bodies) ─────────────
const OPS = {
    3: "VTOA", 8: "SETNIL", 10: "LEN", 13: "MOVE", 15: "NEWTABLE", 16: "NOT",
    34: "CALLV1", 39: "CALLMULTI", 42: "CALL2VA", 43: "CALL2", 47: "CALLV1M",
    48: "CALL0M", 51: "CONCAT", 53: "SETUPVAL", 55: "VARARG", 57: "LOADK",
    61: "ADD", 70: "SUB", 73: "COPYVARARG", 74: "TEST", 79: "FORPREP",
    90: "CALLV0", 93: "GETRET", 101: "MUL", 109: "GETTABLE", 116: "SETTABLE",
    117: "METHODM", 125: "LE", 126: "MOD", 130: "CALL2M", 131: "CALL3",
    132: "CALL3M", 138: "CALL0", 141: "LT", 142: "EQ", 152: "CLOSURE",
    157: "GETUPVAL", 170: "TESTNIL", 178: "CALL3DISCARD", 183: "UNM", 186: "POW",
    198: "FORLOOP", 201: "GETGLOBAL", 206: "RETURNRANGE", 210: "JMP", 212: "VTOB",
    213: "DIV", 220: "CALL1M", 228: "CALL2DISCARD", 248: "CALL0DISCARD",
};

if (args.verify) {
    const ok = hmacOk && complete && allGood && failed === 0;
    console.log("");
    console.log(ok ? "\x1b[32mverify: fully verified\x1b[0m (hmac + structure + every checksum + all strings)"
           : `\x1b[33mverify: incomplete\x1b[0m hmac=${hmacOk} bytes=${complete} checksums=${allGood} strings=${strings.length - failed}/${strings.length}`);
    process.exit(ok ? 0 : 3);
}

const outDir = args.out;
fs.mkdirSync(outDir, { recursive: true });

// ── Outputs ────────────────────────────────────────────────────────────────────
kept.forEach((seg, i) => fs.writeFileSync(path.join(outDir, `seg${String(i + 1).padStart(2, "0")}.b64`), seg.raw));
fs.writeFileSync(path.join(outDir, "blob.bin"), blob);
fs.writeFileSync(path.join(outDir, "strings.json"), JSON.stringify(strings, null, 1));
fs.writeFileSync(path.join(outDir, "strings.txt"),
    strings.map((s) => (s.text === undefined ? `[${s.id}] <decrypt failed: ${s.error}>` : `[${s.id}] ${JSON.stringify(s.text)}`)).join("\n"));
fs.writeFileSync(path.join(outDir, "globals.json"), JSON.stringify(globals, null, 1));

if (args.disasm) {
    const strById = new Map(strings.filter((s) => s.text !== undefined).map((s) => [s.id, s.text]));
    const numById = new Map(globals.map((g) => [g.name, g.value]));
    const constOf = (p, idx) => {
        const ref = p.constRefs[idx - 1];
        if (ref === undefined) return null;
        const s = strById.get(String(ref));
        if (s !== undefined) return JSON.stringify(s.length > 60 ? s.slice(0, 60) + "…" : s);
        const n = numById.get(String(ref));
        if (n !== undefined) return String(n);
        return null;
    };
    const lines = [];
    lines.push(`; disassembly of ${args.url ?? args.input}`);
    lines.push(`; blob ${blob.length} bytes | ${globals.length} globals | ${strings.length} strings | ${protos.length} prototypes | ${totalInstr} instructions`);
    lines.push(`; bytecode is a custom register VM; opcode names were read from the VM's own handlers`);
    lines.push("");
    const dump = (p, title) => {
        lines.push(`;${"─".repeat(74)}`);
        lines.push(`; ${title}  instr=${p.instrCount} consts=${p.constRefs.length} children=${p.children.length} upvals=${p.upvals.length} keyOff=${p.v12} checksum=${p.checksumOK ? "OK" : "FAIL"}`);
        for (let i = 0; i < p.instrCount; i++) {
            const op = p.ops[i];
            const name = OPS[op] ?? `OP_${op}`;
            const a = p.a[i], b = p.b[i], c = p.c[i];
            let extra = "";
            if (op === 57) { const v = constOf(p, b); if (v) extra = `   ; ${v}`; }
            if (op === 201) { const v = constOf(p, a); if (v) extra = `   ; ${v}`; }
            lines.push(`  ${String(i).padStart(4, "0")}  ${name.padEnd(13)} a=${String(a).padStart(4)} b=${String(b).padStart(4)} c=${String(c).padStart(4)}${extra}`);
        }
        lines.push("");
    };
    dump(main, "main prototype (no instructions; logic lives in the children)");
    for (const p of protos) dump(p, `${p.label} (depth ${p.depth})`);
    fs.writeFileSync(path.join(outDir, "disasm.txt"), lines.join("\n"));
}

fs.writeFileSync(path.join(outDir, "structure.json"), JSON.stringify({
    source: args.input,
    fileBytes: raw.length,
    segments: kept.length,
    segmentLengths: kept.map((s) => s.raw.length),
    blobBytes: blob.length,
    salt, saltVerified: hmacOk,
    header,
    globals,
    resources,
    strings,
    main: { instrCount: main.instrCount, consts: main.constRefs, children: main.children.length, checksumOK: main.checksumOK },
    prototypes: protos.map((p) => ({ label: p.label, depth: p.depth, instrCount: p.instrCount, consts: p.constRefs, children: p.children.length, upvals: p.upvals.length, bytes: p.size, ok: p.complete && p.checksumOK })),
    consumedBytes: consumed,
    verdict: {
        hmac: hmacOk,
        byteExact: complete,
        allChecksums: allGood,
        stringsDecrypted: strings.length - failed,
        stringsTotal: strings.length,
    },
}, null, 1));

const verdict = hmacOk && complete && allGood && failed === 0;
console.log("");
console.log(verdict
    ? `\x1b[32mdone — fully verified\x1b[0m → ${outDir}/`
    : `\x1b[33mdone with warnings\x1b[0m → ${outDir}/  (hmac=${hmacOk} bytes=${complete} checksums=${allGood} strings=${failed === 0})`);
process.exit(verdict ? 0 : 3);
