/**
 * 全流程验收检查。对每个样本跑一遍完整流程，检查输出文件与内容质量。
 */
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import os from "node:os";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CLI = path.join(HERE, "luaguard-unpack.mjs");

const SAMPLES = [
    { name: "v1 Elton",   file: "plain_out.lua",   layout: "v1" },
    { name: "v2 Hood",    file: "sample_hood.lua",  layout: "v2" },
    { name: "v3 RIVALS",  file: "sample_rivals.lua", layout: "v3" },
];

let pass = 0, fail = 0;
const rows = [];
function check(label, ok, detail = "") {
    rows.push({ label, ok, detail });
    ok ? pass++ : fail++;
}

for (const s of SAMPLES) {
    const out = path.join(os.tmpdir(), "luaguard-check", s.name.replace(/\W+/g, "_"));
    fs.rmSync(out, { recursive: true, force: true });
    let stdout = "", code = 0;
    try {
        stdout = execFileSync(process.execPath, [CLI, path.join("..", "elton", s.file), "-o", out], { encoding: "utf8", cwd: HERE, stdio: ["ignore", "pipe", "pipe"] });
    } catch (e) { stdout = `${e.stdout ?? ""}${e.stderr ?? ""}`; code = e.status ?? 1; }

    check(`${s.name} 退出码 0`, code === 0, `got ${code}`);
    check(`${s.name} 输出 verified`, /fully verified/.test(stdout));
    check(`${s.name} 识别为 ${s.layout}`, new RegExp(`layout: ${s.layout}`).test(stdout) || (s.layout === "v1" && /prototypes: /.test(stdout)));

    const files = ["strings.txt", "strings.json", "globals.json", "disasm.txt", "structure.json"];
    for (const f of files) check(`${s.name} 产出 ${f}`, fs.existsSync(path.join(out, f)));

    // 字符串质量
    if (fs.existsSync(path.join(out, "strings.json"))) {
        const str = JSON.parse(fs.readFileSync(path.join(out, "strings.json"), "utf8"));
        const good = str.filter(x => x.text !== null && x.text !== undefined).length;
        check(`${s.name} 字符串全部解密`, good === str.length, `${good}/${str.length}`);
    }
    // 反汇编质量
    if (fs.existsSync(path.join(out, "disasm.txt"))) {
        const d = fs.readFileSync(path.join(out, "disasm.txt"), "utf8");
        const instr = (d.match(/^\s+\d{4}\s+\S+/gm) || []).length;
        const annotated = (d.match(/;\s+"/g) || []).length;
        check(`${s.name} 反汇编非空`, instr > 100, `${instr} 条指令`);
        check(`${s.name} 常量注释存在`, annotated > 10, `${annotated} 条注释`);
    }
    // 结构化质量（v2/v3）
    if (s.layout !== "v1" && fs.existsSync(path.join(out, "structured.txt"))) {
        const st = fs.readFileSync(path.join(out, "structured.txt"), "utf8");
        const labels = new Set([...st.matchAll(/^L(\d{4}):/gm)].map(m => m[1]));
        const gotos = [...st.matchAll(/goto L(\d{4})/g)].map(m => m[1]);
        const missing = gotos.filter(g => !labels.has(g));
        check(`${s.name} goto 全部有标签`, missing.length === 0, `缺 ${missing.length}`);
        const bad = (st.match(/\br\d{3,}\b/g) || []).filter(x => +x.slice(1) > 255);
        check(`${s.name} 无越界寄存器号`, bad.length === 0, `${bad.length} 个`);
    }
}

// 边界：非 lua-guard 文件
{
    const junk = path.join(os.tmpdir(), "luaguard-check", "junk.lua");
    fs.mkdirSync(path.dirname(junk), { recursive: true });
    fs.writeFileSync(junk, "print('hello')");
    let out = "", code = 0;
    try { out = execFileSync(process.execPath, [CLI, junk, "-o", junk + ".d"], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }); }
    catch (e) { out = `${e.stdout ?? ""}${e.stderr ?? ""}`; code = e.status ?? 1; }
    check("非目标文件 → 明确报错", code !== 0 && /does not look like|no base64|unrecognised protection/.test(out), out.split("\n")[0]?.slice(0, 60));
}

console.log("\n" + "=".repeat(70));
for (const r of rows) console.log(`${r.ok ? "  ok  " : " FAIL "} ${r.label}${r.detail ? "   (" + r.detail + ")" : ""}`);
console.log("=".repeat(70));
console.log(`\n通过 ${pass} 项，失败 ${fail} 项`);
process.exit(fail ? 1 : 0);
