import fs from "node:fs";
const s = fs.readFileSync("decoded_loader.bin", "latin1");
const n = Math.floor(s.length / 5);
const P85 = [85 ** 4, 85 ** 3, 85 ** 2, 85, 1];
const ops = new Map();
const cells = [];
for (let i = 0; i < n; i++) {
    const c = [];
    for (let k = 0; k < 5; k++) c.push(s.charCodeAt(i * 5 + k) - 32);
    // 低 4 位（前 4 字符）与高 1 位（第 5 字符）
    const low = c[0] * 85 ** 3 + c[1] * 85 ** 2 + c[2] * 85 + c[3];
    const op = c[4];
    const full = op * 85 ** 4 + low;
    cells.push({ op, low, full, raw: c });
    ops.set(op, (ops.get(op) || 0) + 1);
}
console.log("指令数:", n);
console.log("操作码（第5字符-32）种类:", ops.size);
const keys = [...ops.keys()].sort((a, b) => a - b);
console.log("操作码范围:", keys[0], "~", keys[keys.length - 1]);
console.log("操作码分布:", keys.map(k => `${k}:${ops.get(k)}`).join(" "));
console.log("\n前 12 条:");
for (const c of cells.slice(0, 12)) {
    console.log(`  op=${String(c.op).padStart(2)}  low=${String(c.low).padStart(9)}  full=${String(c.full).padStart(12)}  数字=[${c.raw.join(",")}]`);
}
fs.writeFileSync("program.json", JSON.stringify(cells));
