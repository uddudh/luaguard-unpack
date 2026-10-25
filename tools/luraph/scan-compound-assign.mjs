import fs from "node:fs";
const src = fs.readFileSync("luraph_source.lua", "utf8");

// 逐字符扫描，跳过字符串和长字符串，找代码区的复合赋值
const found = [];
let i = 0;
while (i < src.length) {
    const c = src[i];
    if (c === '"' || c === "'") {
        const q = c; i++;
        while (i < src.length) {
            if (src[i] === "\\") { i += 2; continue; }
            if (src[i] === q) { i++; break; }
            i++;
        }
        continue;
    }
    if (c === "[" && (src[i+1] === "=" || src[i+1] === "[")) {
        const m = /^\[(=*)\[/.exec(src.slice(i));
        if (m) {
            const close = "]" + m[1] + "]";
            const e = src.indexOf(close, i + m[0].length);
            if (e >= 0) { i = e + close.length; continue; }
        }
    }
    if (c === "-" && src[i+1] === "-") {
        const nl = src.indexOf("\n", i);
        i = nl < 0 ? src.length : nl + 1;
        continue;
    }
    // 检查复合赋值
    const two = src.slice(i, i + 2);
    if (["+=", "-=", "*=", "/=", "%=", "^="].includes(two)) {
        found.push({ pos: i, op: two, ctx: src.slice(Math.max(0, i - 50), i + 50) });
    }
    i++;
}
console.log("代码区复合赋值:", found.length);
for (const f of found.slice(0, 10)) {
    console.log(`  @${f.pos} ${f.op}: ${JSON.stringify(f.ctx)}`);
}
