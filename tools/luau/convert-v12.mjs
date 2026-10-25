import fs from "node:fs";
import { Parser } from "./parser.mjs";
import { tokenize } from "./tokenizer.mjs";

let src = fs.readFileSync("luraph_source.lua", "utf8");
let total = 0;

function render(toks, a, b) { return toks.slice(a, b).map(t => t.value).join(" "); }

/** 判断是否是「语句」：以语句关键字开头，或含顶层分号 */
function isStmt(text) {
    const t = text.trim();
    if (/^(local|for|while|repeat|return|break|do)\b/.test(t)) return true;
    // 顶层分号（跳过字符串与括号）
    let pd = 0, i = 0;
    while (i < t.length) {
        const c = t[i];
        if (c === '"' || c === "'") { const q = c; i++; while (i < t.length) { if (t[i] === "\\") { i += 2; continue; } if (t[i] === q) { i++; break; } i++; } continue; }
        if (c === "(" || c === "{" || c === "[") { pd++; i++; continue; }
        if (c === ")" || c === "}" || c === "]") { pd--; i++; continue; }
        if (c === ";" && pd === 0) return true;
        i++;
    }
    return false;
}
function mk(text) {
    const t = text.trim();
    if (!t) return "return nil";
    if (isStmt(t)) return `${t}; return nil`;
    return `return ${t}`;
}

function round(src) {
    const toks = tokenize(src);
    const p = new Parser(src);
    let raw;
    try { raw = p.parseChunk(); } catch { return { src, n: 0 }; }
    if (!raw.length) return { src, n: 0 };
    const map = new Map();
    for (const e of raw) {
        const k = e.startPos;
        if (!map.has(k) || (map.get(k).endPos - map.get(k).startPos) < (e.endPos - e.startPos)) map.set(k, e);
    }
    // 只取最内层（不含其他 edit）
    let edits = [...map.values()].filter(a => !mapValues().some(b => b !== a && b.startPos > a.startPos && b.endPos < a.endPos && !(b.startPos === a.startPos && b.endPos === a.endPos)));
    function mapValues() { return [...map.values()]; }
    edits.sort((a, b) => b.startPos - a.startPos);

    let out = src, n = 0;
    for (const e of edits) {
        const ti = toks.findIndex(t => t.pos === e.startPos);
        if (ti < 0) continue;
        let i = ti + 1, pd = 0;
        const condStart = i;
        while (i < toks.length) {
            const t = toks[i];
            if (t.value === "(" || t.value === "{" || t.value === "[") pd++;
            else if (t.value === ")" || t.value === "}" || t.value === "]") pd--;
            else if (pd === 0 && t.value === "then") break;
            i++;
        }
        if (i >= toks.length) continue;
        const condEnd = i;
        const branches = [];
        let j = i + 1, ok = true;
        while (true) {
            const aStart = j;
            let d2 = 0;
            while (j < toks.length) {
                const t = toks[j];
                if (t.value === "(" || t.value === "{" || t.value === "[") d2++;
                else if (t.value === ")" || t.value === "}" || t.value === "]") { if (d2 === 0) { ok = false; break; } d2--; }
                else if (d2 === 0 && (t.value === "else" || t.value === "elseif")) break;
                j++;
            }
            if (!ok) break;
            branches.push({ condStart, condEnd, aStart, aEnd: j });
            if (j >= toks.length || toks[j].value !== "elseif") break;
            j++;
            let d3 = 0;
            while (j < toks.length) {
                const t = toks[j];
                if (t.value === "(" || t.value === "{" || t.value === "[") d3++;
                else if (t.value === ")" || t.value === "}" || t.value === "]") d3--;
                else if (d3 === 0 && t.value === "then") break;
                j++;
            }
            j++;
        }
        if (!ok || j >= toks.length || toks[j].value !== "else") continue;
        j++;
        const bStart = j;
        let d4 = 0;
        while (j < toks.length) {
            const t = toks[j];
            if (t.value === "(" || t.value === "{" || t.value === "[") d4++;
            else if (t.value === ")" || t.value === "}" || t.value === "]") { if (d4 === 0) break; d4--; }
            else if (d4 === 0 && (t.value === ";" || t.value === ",")) break;
            else if (d4 === 0 && (t.value === "end" || t.value === "else" || t.value === "elseif")) break;
            j++;
        }
        const bEnd = j;
        const endPos = toks[bEnd - 1].end;

        let body = mk(render(toks, bStart, bEnd));
        for (let k = branches.length - 1; k >= 0; k--) {
            const br = branches[k];
            body = `if ${render(toks, br.condStart, br.condEnd)} then ${mk(render(toks, br.aStart, br.aEnd))} else ${body} end`;
        }
        out = out.slice(0, e.startPos) + `(function() ${body} end)()` + out.slice(endPos);
        n++;
    }
    return { src: out, n };
}

for (let r = 0; r < 20; r++) {
    const res = round(src);
    if (!res.n) break;
    src = res.src;
    total += res.n;
    console.log(`第 ${r+1} 轮: ${res.n}`);
}
console.log("总计:", total);
fs.writeFileSync("luraph_final5.lua", src);
const bad = (src.match(/\);\s*return nil/g) || []).length;
console.log("可疑的 \"); return nil\" 数量:", bad);
