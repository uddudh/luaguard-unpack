import fs from "node:fs";
let out = fs.readFileSync("luraph_source.lua", "utf8");

function isElseWord(s, i, w) {
    if (w !== "else") return false;
    if (/\w/.test(s[i-1] || "")) return false;
    const after = s.slice(i + 4, i + 6);
    return !(after === "if" || after === " if");
}
function isThenWord(s, i, w) {
    if (w !== "then") return false;
    return !/\w/.test(s[i-1] || "") && !/\w/.test(s[i+4] || "");
}
/** 判断这个 if 是「表达式」还是「语句」 */
function isExprIf(s, i) {
    // 往前找非空白
    let j = i - 1;
    while (j >= 0 && /\s/.test(s[j])) j--;
    if (j < 0) return false;
    const c = s[j];
    // 表达式 if 前面是 = , ( { return [ 或运算符
    return c === "=" || c === "," || c === "(" || c === "{" || c === "[";
}
function isStatement(text) {
    const t = text.trim();
    return /^(for|while|repeat|local|return|break)\b/.test(t) || /\bend\s*$/.test(t) || t.includes(";");
}

/** 读表达式（正确处理表达式 if 无 end） */
function readExpr(s, i, stopAtComma) {
    let pd = 0, kd = 0;
    const start = i;
    while (i < s.length) {
        const c = s[i];
        if (c === '"' || c === "'") { const q = c; i++; while (i < s.length) { if (s[i] === "\\") { i += 2; continue; } if (s[i] === q) { i++; break; } i++; } continue; }
        if (c === "(" || c === "{" || c === "[") { pd++; i++; continue; }
        if (c === ")" || c === "}" || c === "]") { if (pd === 0) break; pd--; i++; continue; }
        if (pd === 0 && /\w/.test(c)) {
            const m = /^\w+/.exec(s.slice(i));
            const w = m[0];
            // 只有「语句型」关键字才增加 kd
            if (w === "function" || w === "do" || w === "for" || w === "while" || w === "repeat") { kd++; i += w.length; continue; }
            if (w === "if") {
                // 表达式 if 不算 kd；语句 if 算
                if (!isExprIf(s, i)) kd++;
                i += 2; continue;
            }
            if (w === "end" || w === "until") { if (kd === 0) break; kd--; i += w.length; continue; }
            if (kd === 0 && isElseWord(s, i, w)) break;
            i += w.length; continue;
        }
        if (pd === 0 && kd === 0 && stopAtComma && (c === "," || c === ";" || c === "\n")) break;
        i++;
    }
    return { text: s.slice(start, i), end: i };
}

function mkBranch(text) {
    const t = text.trim();
    if (isStatement(t)) return `${t}; return nil`;
    return `return ${t}`;
}

function parseIf(s, pos) {
    let i = pos + 2;
    let pd = 0, condStart = i;
    while (i < s.length) {
        const c = s[i];
        if (c === '"' || c === "'") { const q = c; i++; while (i < s.length) { if (s[i] === "\\") { i += 2; continue; } if (s[i] === q) { i++; break; } i++; } continue; }
        if (c === "(" || c === "{" || c === "[") { pd++; i++; continue; }
        if (c === ")" || c === "}" || c === "]") { if (pd === 0) break; pd--; i++; continue; }
        if (pd === 0 && /\w/.test(c)) {
            const m = /^\w+/.exec(s.slice(i));
            if (isThenWord(s, i, m[0])) break;
            i += m[0].length; continue;
        }
        i++;
    }
    if (i >= s.length) return null;
    const cond = s.slice(condStart, i).trim();
    i += 4;
    const ra = readExpr(s, i, false);
    if (!isElseWord(s, ra.end, "else")) return null;
    i = ra.end + 4;
    const rb = readExpr(s, i, true);
    return { cond, a: ra.text.trim(), b: rb.text.trim(), end: rb.end };
}

let count = 0;
for (let round = 0; round < 300; round++) {
    const re = /(?:=\s*|,\s*|\{\s*|\(\s*|return\s+)if\s/g;
    let m, target = -1;
    while ((m = re.exec(out))) {
        const p = m.index + m[0].lastIndexOf("if");
        if (out.startsWith("if ", p)) { target = p; break; }
    }
    if (target < 0) break;
    const r = parseIf(out, target);
    if (!r) { console.log("失败 @" + target); break; }
    out = out.slice(0, target) +
        `(function() if ${r.cond} then ${mkBranch(r.a)} else ${mkBranch(r.b)} end end)()` +
        out.slice(r.end);
    count++;
}
out = out.replace(/return\s+return\s+/g, "return ");
fs.writeFileSync("luraph_v10.lua", out);
console.log("转换:", count);
