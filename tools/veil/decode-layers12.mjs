import fs from "node:fs";
import { evalLua } from "./eval_lua_fixed3.mjs";

const M = 63, OFF = 42;
// Lua 的 % 对负数返回非负；JS 会保留负号 → 必须归一化
const luaMod = (a, b) => ((a % b) + b) % b;
const s = fs.readFileSync("VEIL.lua", "latin1");

function splitTop(body) {
    const parts = []; let d = 0, cur = "";
    for (const c of body) {
        if ("({[".includes(c)) d++;
        if (")}]".includes(c)) d--;
        if (c === "," && d === 0) { parts.push(cur); cur = ""; continue; }
        cur += c;
    }
    if (cur.trim()) parts.push(cur);
    return parts;
}

// 提取所有常量表
const tables = {};
const re = /([A-Za-z_]\w*)=\{/g;
let m;
while ((m = re.exec(s))) {
    const name = m[1], start = m.index + m[0].length;
    let depth = 1, i = start;
    while (i < s.length && depth > 0) {
        const c = s[i];
        if (c === "{") depth++;
        else if (c === "}") depth--;
        else if (c === '"') { i++; while (i < s.length && s[i] !== '"') { if (s[i] === "\\") i++; i++; } }
        i++;
    }
    if (depth !== 0) continue;
    const body = s.slice(start, i - 1);
    if (body.length > 5000) continue;
    const items = splitTop(body);
    if (items.length < 1) continue;
    const vals = [];
    let ok = true;
    for (const it of items) {
        if (it.includes("_") || it.includes('"') || it.trim() === "") { ok = false; break; }
        try { vals.push(evalLua(it) & 255); } catch { ok = false; break; }
    }
    if (ok) tables[name] = vals;
}

const cat = (...n) => n.flatMap(x => tables[x] || []);
const _6k = cat("_6s", "_8r", "_1u", "_9h", "_3m", "_7s", "_4c");
const _6mcore = cat("_9x", "_5d").concat([197]).concat([112, 250, 12574 % 301]);
const _6m = _6mcore.slice();
let g = _6mcore.length;
for (let i = 0; i < (tables["_8h"] || []).length; i++) { g++; _6m[g - 1] = tables["_8h"][i]; }

console.log("_6k:", _6k.length, "项，前 8:", _6k.slice(0, 8).join(","));
console.log("_6m:", _6m.length, "项");

const _8m = _6k.map(b => (b ^ 125) & 255);
const _5v = _6m.map(b => (b ^ 195) & 255);

function layer1(s0) {
    s0 = s0.replace(/\s/g, "");
    const base = (s0.charCodeAt(0) % 46) + 63;
    const out = [];
    for (let i = 0; i + 4 < s0.length; i += 5) {
        const c = [0,1,2,3,4].map(k => s0.charCodeAt(i + k));
        let v = luaMod(M * (c[4] - OFF), base);
        v = v + base * (luaMod((c[3] - OFF) * M, base) +
            base * (luaMod(M * (c[2] - OFF), base) +
            base * (luaMod((c[1] - OFF) * M, base) +
            base * luaMod(M * (c[0] - OFF), base))));
        out.push((v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255);
    }
    return Buffer.from(out).subarray(0, out.length - 5);
}

function layer2(buf) {
    const nn = buf.length, out = Buffer.alloc(nn);
    let pv = 0, ix = 0, off = 0;
    const nv = _5v.length;
    while (off + 4 <= nn) {
        const e1 = buf[off], e2 = buf[off+1], e3 = buf[off+2], e4 = buf[off+3];
        const q1 = (e1 ^ _5v[ix % nv] ^ pv) & 255;
        const q2 = (e2 ^ _5v[(1+ix) % nv] ^ e1) & 255;
        const q3 = (e3 ^ _5v[(2+ix) % nv] ^ e2) & 255;
        const q4 = (e4 ^ _5v[(3+ix) % nv] ^ e3) & 255;
        out[off] = _8m[q1]; out[off+1] = _8m[q2]; out[off+2] = _8m[q3]; out[off+3] = _8m[q4];
        pv = e4; ix += 4; off += 4;
    }
    while (off < nn) {
        const e1 = buf[off], q1 = (e1 ^ _5v[ix % nv] ^ pv) & 255;
        out[off] = _8m[q1]; pv = e1; ix++; off++;
    }
    return out;
}

const big = s.match(/\[==\[([^]{100,}?)\]==\]/)[1];
const l1 = layer1(big);
const l2 = layer2(l1);
fs.writeFileSync("veil_final.bin", l2);
const printable = [...l2].filter(b => (b >= 32 && b < 127) || b === 10 || b === 9 || b === 13).length;
console.log(`第1层 ${l1.length} → 第2层 ${l2.length} 字节`);
console.log(`可打印率: ${(printable / l2.length * 100).toFixed(1)}%`);
console.log("\n前 200 ascii:");
console.log([...l2.subarray(0, 200)].map(b => (b >= 32 && b < 127) ? String.fromCharCode(b) : ".").join(""));
