/** 基于 token 的转换器 v4：用「有无 end」区分语句/表达式 if */
import fs from "node:fs";
import { tokenize, isName, isOp } from "./tokenizer.mjs";

let src = fs.readFileSync("luraph_source.lua", "utf8");
const toks = tokenize(src);
console.log("tokens:", toks.length);

/** 判断 token i 的 if 是表达式：前面是表达式位置，且「then 分支」不以语句开头 */
function isExprIf(i) {
    const prev = toks[i - 1];
    if (!prev) return false;
    const ops = ["=",",","(","{","[","==","~=","<=",">=","<",">","+","-","*","/","%","..","//"];
    const names = ["return","then","else","and","or"];
    const isExprPos = (prev.type === "op" && ops.includes(prev.value)) || (prev.type === "name" && names.includes(prev.value));
    if (!isExprPos) return false;
    // 看 then 后面第一个 token
    let j = i + 1, pd = 0;
    while (j < toks.length) {
        const t = toks[j];
        if (isOp(t, "(") || isOp(t, "{") || isOp(t, "[")) pd++;
        else if (isOp(t, ")") || isOp(t, "}") || isOp(t, "]")) pd--;
        else if (pd === 0 && isName(t, "then")) break;
        j++;
    }
    if (j >= toks.length) return false;
    const after = toks[j + 1];
    if (!after) return false;
    // then 后面是语句关键字 → 语句 if
    if (after.type === "name" && ["local","for","while","repeat","break","return","do"].includes(after.value)) return false;
    // then 后面是 if → 递归判断
    if (after.type === "name" && after.value === "if") {
        // 找它对应的 end：跳过内层
        // 简化：如果 then 分支里有 local/for/while，就是语句
        let k = j + 2, pd2 = 0, kd2 = 0;
        while (k < toks.length) {
            const t = toks[k];
            if (isOp(t, "(") || isOp(t, "{") || isOp(t, "[")) pd2++;
            else if (isOp(t, ")") || isOp(t, "}") || isOp(t, "]")) { if (pd2 === 0) break; pd2--; }
            else if (pd2 === 0 && t.type === "name") {
                if (["local","for","while","repeat"].includes(t.value)) return false;
                if (t.value === "end") break;
            }
            k++;
        }
    }
    return true;
}

function readExprTokens(i, stopAtSemi) {
    const out = [];
    let pd = 0, kd = 0;
    while (i < toks.length) {
        const t = toks[i];
        if (t.type === "op") {
            if (["(", "{", "["].includes(t.value)) { pd++; out.push(t); i++; continue; }
            if ([")", "}", "]"].includes(t.value)) { if (pd === 0) break; pd--; out.push(t); i++; continue; }
        }
        if (pd === 0 && t.type === "name") {
            if (["function", "do", "for", "while", "repeat"].includes(t.value)) { kd++; out.push(t); i++; continue; }
            if (t.value === "if") { if (!isExprIf(i)) kd++; out.push(t); i++; continue; }
            if (t.value === "end" || t.value === "until") { if (kd === 0) break; kd--; out.push(t); i++; continue; }
        }
        if (pd === 0 && kd === 0) {
            if (isName(t, "else")) break;
            if (stopAtSemi && isOp(t, ";")) break;
        }
        out.push(t); i++;
    }
    return { tokens: out, next: i };
}

function parseIf(i) {
    const cond = [];
    let j = i + 1, pd = 0;
    while (j < toks.length) {
        const t = toks[j];
        if (isOp(t, "(") || isOp(t, "{") || isOp(t, "[")) pd++;
        else if (isOp(t, ")") || isOp(t, "}") || isOp(t, "]")) { if (pd === 0) return null; pd--; }
        else if (pd === 0 && isName(t, "then")) break;
        cond.push(t); j++;
    }
    if (j >= toks.length) return null;
    j++;
    const ra = readExprTokens(j, true);
    if (!ra.tokens.length || !isName(toks[ra.next], "else")) return null;
    j = ra.next + 1;
    const rb = readExprTokens(j, true);
    return { cond, a: ra.tokens, b: rb.tokens, next: rb.next };
}

function join(tokens) {
    let out = "", prev = null;
    for (const t of tokens) {
        const sp = prev && (
            (prev.type === "name" && t.type === "name") ||
            (prev.type === "number" && (t.type === "name" || t.type === "number")) ||
            (prev.type === "name" && t.type === "number")
        );
        out += (sp ? " " : "") + t.value;
        prev = t;
    }
    return out;
}
function mkBranch(tokens) {
    const text = join(tokens).trim();
    if (!text) return "return nil";
    if (/^(for|while|repeat|local|return|break)\b/.test(text) || /\bend\b/.test(text)) return `${text}; return nil`;
    return `return ${text}`;
}

const edits = [];
let skipped = 0;
for (let i = toks.length - 1; i >= 0; i--) {
    if (!isName(toks[i], "if") || !isExprIf(i)) continue;
    const r = parseIf(i);
    if (!r) { skipped++; continue; }
    const startPos = toks[i].pos, endPos = toks[r.next - 1].end;
    if (edits.some(e => !(endPos <= e.pos || startPos >= e.end))) { skipped++; continue; }
    edits.push({ pos: startPos, end: endPos, text: `(function() if ${join(r.cond)} then ${mkBranch(r.a)} else ${mkBranch(r.b)} end end)()` });
}
edits.sort((a, b) => b.pos - a.pos);
for (const e of edits) src = src.slice(0, e.pos) + e.text + src.slice(e.end);
fs.writeFileSync("luraph_conv4.lua", src);
console.log("转换:", edits.length, "| 跳过:", skipped);
