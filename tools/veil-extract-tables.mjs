/** 提取 VEIL 的所有常量表（_6s, _8r, _1u, _9h ...），求值成字节数组 */
import fs from "node:fs";

const s = fs.readFileSync("VEIL.lua", "latin1");

function evalLua(expr) {
    let e = expr.trim();
    e = e.replace(/-\(\s*-\(\s*([^()]+)\s*\)\s*\)/g, "($1)");
    e = e.replace(/-\(\s*-(\d+(?:\.\d+)?)\s*\)/g, "$1");
    e = e.replace(/\b0x([0-9a-fA-F]+)\b/g, (_, h) => String(parseInt(h, 16)));
    e = e.replace(/(\d+(?:\.\d+)?)\s*\/\/\s*(\d+(?:\.\d+)?)/g, (_, a, b) => String(Math.floor(+a / +b)));
    e = e.replace(/\^/g, "**");
    e = e.replace(/\s+/g, "");
    const v = Function("return " + e)();
    if (!Number.isFinite(v)) throw new Error("nan");
    return Math.floor(v);
}

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

// 找所有 "NAME={...}" 形式
const tables = {};
const re = /([A-Za-z_]\w*)=\{/g;
let m;
while ((m = re.exec(s))) {
    const name = m[1];
    const start = m.index + m[0].length;
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
    if (body.length > 5000) continue;                 // 跳过大表（嵌套或超长）
    const items = splitTop(body);
    if (items.length < 4) continue;
    const vals = [];
    let okAll = true;
    for (const it of items) {
        if (it.includes("_") || it.includes('"') || it.trim() === "") { okAll = false; break; }
        try { vals.push(evalLua(it) & 255); } catch { okAll = false; break; }
    }
    if (okAll && vals.length >= 4) tables[name] = vals;
}

console.log("提取到的常量表:");
for (const [k, v] of Object.entries(tables)) {
    console.log(`  ${k}: ${v.length} 项  [${v.slice(0,8).join(",")}...]`);
}
fs.writeFileSync("veil_tables.json", JSON.stringify(tables, null, 1));
