import fs from "node:fs";
import { Parser } from "./parser.mjs";
import { tokenize } from "./tokenizer.mjs";

let src = fs.readFileSync("luraph_source.lua", "utf8");
let totalApplied = 0;

function tokRender(toks, a, b) {
    return toks.slice(a, b).map(t => t.value).join(" ");
}
function mkBranch(txt) {
    if (!txt) return "return nil";
    if (/^(local|for|while|repeat|return|break|do)\b/.test(txt) || /\bend\b/.test(txt)) return `${txt}; return nil`;
    return `return ${txt}`;
}

/** 转换一轮（从后往前，处理所有最内层） */
function convertOneRound(src) {
    const toks = tokenize(src);
    const p = new Parser(src);
    let raw;
    try { raw = p.parseChunk(); } catch { return { src, n: 0 }; }
    if (!raw.length) return { src, n: 0 };
    // 去重
    const map = new Map();
    for (const e of raw) {
        const k = e.startPos;
        if (!map.has(k) || (map.get(k).endPos - map.get(k).startPos) < (e.endPos - e.startPos)) map.set(k, e);
    }
    // 按 startPos 排序，取最内层（没有其他 edit 包含它）
    let edits = [...map.values()];
    // 去掉「包含其他 edit」的（只保留最内层，下一轮再处理外层）
    edits = edits.filter(a => !edits.some(b => b !== a && b.startPos > a.startPos && b.endPos < a.endPos && !(b.startPos === a.startPos && b.endPos === a.endPos)));
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
        let j = i + 1;
        let ok = true;
        while (true) {
            const aStart = j;
            let pd2 = 0;
            while (j < toks.length) {
                const t = toks[j];
                if (t.value === "(" || t.value === "{" || t.value === "[") pd2++;
                else if (t.value === ")" || t.value === "}" || t.value === "]") { if (pd2 === 0) { ok = false; break; } pd2--; }
                else if (pd2 === 0 && (t.value === "else" || t.value === "elseif")) break;
                j++;
            }
            if (!ok) break;
            branches.push({ condStart, condEnd, aStart, aEnd: j });
            if (j >= toks.length || toks[j].value !== "elseif") break;
            j++;
            const c2 = j;
            let pd3 = 0;
            while (j < toks.length) {
                const t = toks[j];
                if (t.value === "(" || t.value === "{" || t.value === "[") pd3++;
                else if (t.value === ")" || t.value === "}" || t.value === "]") pd3--;
                else if (pd3 === 0 && t.value === "then") break;
                j++;
            }
            j++;
        }
        if (!ok || j >= toks.length || toks[j].value !== "else") continue;
        j++;
        const bStart = j;
        let pd4 = 0;
        while (j < toks.length) {
            const t = toks[j];
            if (t.value === "(" || t.value === "{" || t.value === "[") pd4++;
            else if (t.value === ")" || t.value === "}" || t.value === "]") { if (pd4 === 0) break; pd4--; }
            else if (pd4 === 0 && (t.value === ";" || t.value === ",")) break;
            else if (pd4 === 0 && (t.value === "end" || t.value === "else" || t.value === "elseif")) break;
            j++;
        }
        const bEnd = j;
        const endPos = toks[bEnd - 1].end;
        let body = mkBranch(tokRender(toks, bStart, bEnd));
        for (let k = branches.length - 1; k >= 0; k--) {
            const br = branches[k];
            body = `if ${tokRender(toks, br.condStart, br.condEnd)} then ${mkBranch(tokRender(toks, br.aStart, br.aEnd))} else ${body} end`;
        }
        const repl = `(function() ${body} end)()`;
        out = out.slice(0, e.startPos) + repl + out.slice(endPos);
        n++;
    }
    return { src: out, n };
}

// 多轮（最多 20 轮）
for (let round = 0; round < 20; round++) {
    const r = convertOneRound(src);
    if (r.n === 0) break;
    src = r.src;
    totalApplied += r.n;
    console.log(`第 ${round+1} 轮: ${r.n} 个`);
}
console.log("总计:", totalApplied);
fs.writeFileSync("luraph_final2.lua", src);
