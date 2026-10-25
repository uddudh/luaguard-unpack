import fs from "node:fs";
import { tokenize } from "./tokenizer.mjs";

const o = fs.readFileSync("luraph_source.lua", "utf8");
const c = fs.readFileSync("luraph_final7.lua", "utf8");
const to = tokenize(o).map(t => t.value);
const tc = tokenize(c).map(t => t.value);
console.log("原版 token:", to.length, "| 转换版 token:", tc.length, "| 差:", tc.length - to.length);

// 贪心判断 to 是否为 tc 的子序列，并收集差异
let i = 0, j = 0;
const missing = [];
const extra = [];
while (i < to.length && j < tc.length) {
    if (to[i] === tc[j]) { i++; j++; continue; }
    // 尝试在 tc 中跳过（插入）
    let found = -1;
    for (let k = j + 1; k < Math.min(j + 60, tc.length); k++) {
        if (tc[k] === to[i]) { found = k; break; }
    }
    if (found >= 0) {
        for (let k = j; k < found; k++) extra.push(tc[k]);
        j = found;
    } else {
        missing.push({ idx: i, tok: to[i], ctx: to.slice(Math.max(0, i - 6), i + 6).join(" ") });
        i++;
    }
}
while (i < to.length) { missing.push({ idx: i, tok: to[i], ctx: "" }); i++; }
for (; j < tc.length; j++) extra.push(tc[j]);

console.log("原版有而转换版缺的 token:", missing.length);
for (const m of missing.slice(0, 10)) console.log("  MISS", JSON.stringify(m));
console.log("转换版多出的 token:", extra.length);
const kinds = {};
for (const e of extra) kinds[e] = (kinds[e] || 0) + 1;
console.log("多出的 token 统计(前15):", Object.entries(kinds).sort((a,b)=>b[1]-a[1]).slice(0,15));
