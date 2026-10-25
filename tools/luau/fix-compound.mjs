import fs from "node:fs";
import { tokenize } from "./tokenizer.mjs";

let src = fs.readFileSync("luraph_final3.lua", "utf8");
// tokenizer 会把 += 识别为 op，所以我们要在 token 层处理
// 但 tokenizer 是只读的，这里用「token 重建 + 替换」
const toks = tokenize(src);
// 检查是否有 += 等
const comp = toks.filter(t => ["+=","-=","*=","/=","%=","^="].includes(t.value));
console.log("复合赋值 token:", comp.length);

// 在字符层处理（跳过字符串）
let out = "", i = 0;
while (i < src.length) {
    const c = src[i];
    if (c === '"' || c === "'") {
        const q = c; let j = i + 1;
        while (j < src.length) { if (src[j] === "\\") { j += 2; continue; } if (src[j] === q) { j++; break; } j++; }
        out += src.slice(i, j); i = j; continue;
    }
    if (c === "[") {
        const m = /^\[(=*)\[/.exec(src.slice(i));
        if (m) {
            const close = "]" + m[1] + "]";
            const e = src.indexOf(close, i + m[0].length);
            if (e >= 0) { const end = e + close.length; out += src.slice(i, end); i = end; continue; }
        }
    }
    if (c === "-" && src[i+1] === "-") { const nl = src.indexOf("\n", i); const e = nl < 0 ? src.length : nl+1; out += src.slice(i, e); i = e; continue; }
    // 复合赋值：NAME op= EXPR
    const m = /^([A-Za-z_]\w*)\s*(\+|\-|\*|\/|%|\^)=\s*([^;,]+)/.exec(src.slice(i));
    if (m) {
        out += `${m[1]} = ${m[1]} ${m[2]} (${m[3].trim()})`;
        i += m[0].length;
        continue;
    }
    out += c; i++;
}
fs.writeFileSync("luraph_final4.lua", out);
console.log("处理完成，长度:", out.length);
