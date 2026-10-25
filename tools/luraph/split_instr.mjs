import fs from "node:fs";
const s = fs.readFileSync("decoded_loader.bin", "latin1");
console.log("流长度:", s.length, "| 5 字符对齐余数:", s.length % 5);
// 验证前 5 组与 trace 一致
const traceHead = `u32 0 1229539899
u8 4 56
u32 5 1129004403
u8 9 76
u32 10 1095246150
u8 14 85`;
let ok = true;
for (let g = 0; g < 3; g++) {
    const off = g * 5;
    const v = s.charCodeAt(off) | (s.charCodeAt(off + 1) << 8) | (s.charCodeAt(off + 2) << 16) | (s.charCodeAt(off + 3) << 24);
    const o = s.charCodeAt(off + 4);
    const expectV = [1229539899, 1129004403, 1095246150][g];
    const expectO = [56, 76, 85][g];
    if (v !== expectV || o !== expectO) { ok = false; console.log(`组${g} 不符: v=${v} o=${o}`); }
}
console.log("与 trace 一致:", ok ? "✅" : "❌");

const n = Math.floor(s.length / 5);
const ops = new Map();
const cells = [];
for (let i = 0; i < n; i++) {
    const off = i * 5;
    const v = (s.charCodeAt(off) | (s.charCodeAt(off + 1) << 8) | (s.charCodeAt(off + 2) << 16) | (s.charCodeAt(off + 3) << 24)) >>> 0;
    const o = s[off + 4];
    ops.set(o, (ops.get(o) || 0) + 1);
    cells.push({ v, o });
}
console.log("指令总数:", n);
console.log("操作码种类:", ops.size);
const sorted = [...ops.entries()].sort((a, b) => b[1] - a[1]);
console.log("\n操作码频率（字符/码点/次数）:");
for (const [ch, c] of sorted) console.log(`  '${ch}' (${ch.charCodeAt(0)}) × ${c}`);
fs.writeFileSync("instr_loader.json", JSON.stringify(cells));
// 前 20 条
console.log("\n前 20 条指令:");
for (const c of cells.slice(0, 20)) console.log(`  op='${c.o}'(${c.o.charCodeAt(0)})  v=${c.v}`);
