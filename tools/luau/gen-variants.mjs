import fs from "node:fs";
import { Parser } from "./parser.mjs";
import { tokenize } from "./tokenizer.mjs";

const orig = fs.readFileSync("luraph_source.lua", "utf8");
const toks = tokenize(orig);
const p = new Parser(orig);
let raw;
try { raw = p.parseChunk(); } catch (e) { console.error("parse fail", e.message); process.exit(1); }
const map = new Map();
for (const e of raw) {
    const k = e.startPos;
    if (!map.has(k) || (map.get(k).endPos - map.get(k).startPos) < (e.endPos - e.startPos)) map.set(k, e);
}
const all = [...map.values()];
// 去掉包含关系（只保留最内层）
const edits = all.filter(a => !all.some(b => b !== a && b.startPos >= a.startPos && b.endPos <= a.endPos && (b.startPos !== a.startPos || b.endPos !== a.endPos)));
edits.sort((a, b) => a.startPos - b.startPos);
console.log("找到表达式 if:", edits.length);

function render(a, b) { return toks.slice(a, b).map(t => t.value).join(" "); }
function isStmt(text) {
    const t = text.trim();
    if (/^(local|for|while|repeat|return|break|do)\b/.test(t)) return true;
    let pd = 0, i = 0;
    while (i < t.length) {
        const c = t[i];
        if (c === '"' || c === "'") { const q = c; i++; while (i < t.length) { if (t[i] === "\\") { i += 2; continue; } if (t[i] === q) { i++; break; } i++; } continue; }
        if ("({[".includes(c)) { pd++; i++; continue; }
        if (")}]".includes(c)) { pd--; i++; continue; }
        if (c === ";" && pd === 0) return true;
        i++;
    }
    return false;
}
function mk(t) { const x = t.trim(); if (!x) return "return nil"; return isStmt(x) ? `${x}; return nil` : `return ${x}`; }

// 为每个 edit 生成替换文本
const repl = [];
for (const e of edits) {
    const ti = toks.findIndex(t => t.pos === e.startPos);
    if (ti < 0) { repl.push(null); continue; }
    let i = ti + 1, pd = 0;
    const condStart = i;
    while (i < toks.length) {
        const t = toks[i];
        if ("({[".includes(t.value)) pd++;
        else if (")}]".includes(t.value)) pd--;
        else if (pd === 0 && t.value === "then") break;
        i++;
    }
    const condEnd = i;
    const branches = [];
    let j = i + 1, ok = true;
    while (true) {
        const aStart = j; let d2 = 0;
        while (j < toks.length) {
            const t = toks[j];
            if ("({[".includes(t.value)) d2++;
            else if (")}]".includes(t.value)) { if (d2 === 0) { ok = false; break; } d2--; }
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
            if ("({[".includes(t.value)) d3++;
            else if (")}]".includes(t.value)) d3--;
            else if (d3 === 0 && t.value === "then") break;
            j++;
        }
        j++;
    }
    if (!ok || j >= toks.length || toks[j].value !== "else") { repl.push(null); continue; }
    j++;
    const bStart = j; let d4 = 0;
    while (j < toks.length) {
        const t = toks[j];
        if ("({[".includes(t.value)) d4++;
        else if (")}]".includes(t.value)) { if (d4 === 0) break; d4--; }
        else if (d4 === 0 && (";,".includes(t.value))) break;
        else if (d4 === 0 && (t.value === "end" || t.value === "else" || t.value === "elseif")) break;
        j++;
    }
    const bEnd = j;
    let body = mk(render(bStart, bEnd));
    for (let k = branches.length - 1; k >= 0; k--) {
        const br = branches[k];
        body = `if ${render(br.condStart, br.condEnd)} then ${mk(render(br.aStart, br.aEnd))} else ${body} end`;
    }
    repl.push({ startPos: e.startPos, endPos: toks[bEnd - 1].end, text: `(function() ${body} end)()` });
}
const good = repl.filter(Boolean);
console.log("可用替换:", good.length);

const KS = [6, 12, 18, 24, 30, good.length];
for (const K of KS) {
    let out = orig;
    const use = good.slice(0, K).sort((a, b) => b.startPos - a.startPos);
    for (const e of use) out = out.slice(0, e.startPos) + e.text + out.slice(e.endPos);
    const f = `variant_${K}.lua`;
    fs.writeFileSync(f, out);
    console.log(`${f}: ${out.length} 字节 (应用 ${K} 处)`);
}
