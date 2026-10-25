import fs from "node:fs";
let src = fs.readFileSync("luraph_final2.lua", "utf8");

// 剩余模式：P= if C then (function() ... end)() else B;
// 这是外层的 if 表达式（then 分支已被转成函数调用）
// 处理：找到 "P = if"，解析到对应 else
function fixPatterns(s) {
    let out = s;
    let n = 0;
    for (let guard = 0; guard < 20; guard++) {
        // 找 "= if " 后跟 " then "
        const m = /=\s*if\s/.exec(out);
        if (!m) break;
        const ifPos = m.index + m[0].lastIndexOf("if");
        // 解析：if COND then A else B
        let i = ifPos + 2, pd = 0, condStart = i;
        while (i < out.length) {
            const c = out[i];
            if (c === "(" || c === "{" || c === "[") pd++;
            else if (c === ")" || c === "}" || c === "]") { if (pd === 0) break; pd--; }
            else if (pd === 0 && out.startsWith("then", i) && !/\w/.test(out[i-1]||"") && !/\w/.test(out[i+4]||"")) break;
            i++;
        }
        if (i >= out.length) break;
        const condEnd = i;
        i += 4;
        // A 部分：到顶层 else
        let aStart = i; pd = 0;
        let kd = 0;
        while (i < out.length) {
            const c = out[i];
            if (c === "(" || c === "{" || c === "[") pd++;
            else if (c === ")" || c === "}" || c === "]") { if (pd === 0) break; pd--; }
            else if (pd === 0 && /\w/.test(c)) {
                const w = /^\w+/.exec(out.slice(i))[0];
                if (["function","do","for","while","repeat"].includes(w)) kd++;
                else if (w === "end" || w === "until") { if (kd === 0) break; kd--; }
                else if (kd === 0 && w === "else") break;
                i += w.length; continue;
            }
            i++;
        }
        if (i >= out.length) break;
        const aEnd = i;
        if (!out.startsWith("else", aEnd)) break;
        i += 4;
        let bStart = i; pd = 0; kd = 0;
        while (i < out.length) {
            const c = out[i];
            if (c === "(" || c === "{" || c === "[") pd++;
            else if (c === ")" || c === "}" || c === "]") { if (pd === 0) break; pd--; }
            else if (pd === 0 && /\w/.test(c)) {
                const w = /^\w+/.exec(out.slice(i))[0];
                if (["function","do","for","while","repeat"].includes(w)) kd++;
                else if (w === "end" || w === "until") { if (kd === 0) break; kd--; }
                i += w.length; continue;
            }
            else if (pd === 0 && (c === ";" || c === ",")) break;
            i++;
        }
        const bEnd = i;
        const cond = out.slice(condStart, condEnd).trim();
        const aPart = out.slice(aStart, aEnd).trim();
        const bPart = out.slice(bStart, bEnd).trim();
        const mk = (t) => {
            if (!t) return "return nil";
            if (/^(local|for|while|repeat|return|break|do)\b/.test(t) || /\bend\b/.test(t)) return `${t}; return nil`;
            return `return ${t}`;
        };
        const repl = `(function() if ${cond} then ${mk(aPart)} else ${mk(bPart)} end end)()`;
        out = out.slice(0, ifPos) + repl + out.slice(bEnd);
        n++;
    }
    return { out, n };
}
const r = fixPatterns(src);
console.log("手工修复:", r.n);
fs.writeFileSync("luraph_final3.lua", r.out);
