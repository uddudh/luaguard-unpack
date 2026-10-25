import fs from "node:fs";
import { tokenize, isName, isOp } from "./tokenizer.mjs";

const full = fs.readFileSync("luraph_source.lua", "utf8");
const marker = "[51]=function(j,K,K,K,Z,M,d,P,z,r,f,f,x,S,b,I,G)";
const pos = full.indexOf(marker);
const fw = full.indexOf(":FW()");
const tableEnd = full.lastIndexOf("}", fw);
const orig = full.slice(pos, tableEnd);
const toks = tokenize(orig);
console.log("tokens:", toks.length);

const ops = ["=",",","(","{","[","==","~=","<=",">=","<",">","+","-","*","/","%","..","//","^"];
const names = ["return","then","else","and","or"];
const STMT_KW = ["local","for","while","repeat","break","return","do"];

/** 找 if i 的 then */
function findThen(i) {
    let j = i + 1, pd = 0;
    while (j < toks.length) {
        const t = toks[j];
        if (isOp(t,"(") || isOp(t,"{") || isOp(t,"[")) pd++;
        else if (isOp(t,")") || isOp(t,"}") || isOp(t,"]")) { if (pd===0) return -1; pd--; }
        else if (pd===0 && isName(t,"then")) return j;
        j++;
    }
    return -1;
}
/** 找 if i 的「then 分支」里是否有顶层 else（表达式 if 的分界）*/
function hasTopElse(i) {
    const th = findThen(i);
    if (th < 0) return false;
    let k = th + 1, pd = 0, kd = 0;
    while (k < toks.length) {
        const t = toks[k];
        if (isOp(t,"(") || isOp(t,"{") || isOp(t,"[")) pd++;
        else if (isOp(t,")") || isOp(t,"}") || isOp(t,"]")) { if (pd===0) return false; pd--; }
        else if (pd===0 && t.type==="name") {
            if (STMT_KW.includes(t.value) && t.value !== "return") kd++;
            else if (t.value === "end" || t.value === "until") { if (kd===0) return false; kd--; }
            else if (t.value === "if") { if (!isExprIf(k)) kd++; }
            else if (kd===0 && t.value === "else") return true;
        }
        if (pd===0 && kd===0 && isOp(t,";")) { /* 继续 */ }
        k++;
    }
    return false;
}
/** 判断表达式 if */
function isExprIf(i) {
    const th = findThen(i);
    if (th < 0) return false;
    const after = toks[th+1];
    if (!after) return false;
    // then 后是语句关键字 → 语句
    if (after.type === "name" && STMT_KW.includes(after.value)) return false;
    // then 后是 if → 递归
    if (after.type === "name" && after.value === "if") return isExprIf(th+1);
    // then 后是「赋值语句」（有多目标 =）：探测 then 后的顶层 =
    // 表达式 if 的 then 分支是「单个表达式」，不会有「名字 = 」这种
    // 找 then 分支里第一个顶层 token：如果是 name 且后面跟 , 或 = → 语句
    let k = th + 1, pd = 0, kd = 0;
    let depth0Names = [];
    while (k < toks.length) {
        const t = toks[k];
        if (isOp(t,"(") || isOp(t,"{") || isOp(t,"[")) { pd++; k++; continue; }
        if (isOp(t,")") || isOp(t,"}") || isOp(t,"]")) { if (pd===0) break; pd--; k++; continue; }
        if (pd===0 && t.type==="name") {
            if (STMT_KW.includes(t.value) && t.value !== "return") { kd++; k++; continue; }
            if (t.value === "end" || t.value === "until") { if (kd===0) break; kd--; k++; continue; }
            if (t.value === "if") { if (!isExprIf(k)) kd++; k++; continue; }
            if (kd===0 && t.value === "else") break;
        }
        if (kd===0 && pd===0) {
            if (t.type === "name") depth0Names.push(t.value);
            // 遇到顶层 "=" 且前面是 name（多目标赋值）→ 语句
            if (isOp(t,"=") && depth0Names.length > 0) return false;
            // 遇到 "(" 之后是调用（表达式）
        }
        k++;
    }
    return true;
}

function parseIfAt(i) {
    const condEnd = findThen(i);
    if (condEnd < 0) return null;
    let k = condEnd + 1, pd = 0, kd = 0;
    while (k < toks.length) {
        const t = toks[k];
        if (isOp(t,"(") || isOp(t,"{") || isOp(t,"[")) pd++;
        else if (isOp(t,")") || isOp(t,"}") || isOp(t,"]")) { if (pd===0) return null; pd--; }
        else if (pd===0 && t.type==="name") {
            if (["function","do","for","while","repeat"].includes(t.value)) kd++;
            else if (t.value==="end" || t.value==="until") { if (kd===0) return null; kd--; }
            else if (t.value==="if") { if (!isExprIf(k)) kd++; }
            else if (kd===0 && t.value==="else") break;
        }
        k++;
    }
    if (k >= toks.length) return null;
    const elseIdx = k;
    let m = elseIdx + 1, pd3 = 0, kd3 = 0;
    while (m < toks.length) {
        const t = toks[m];
        if (isOp(t,"(") || isOp(t,"{") || isOp(t,"[")) pd3++;
        else if (isOp(t,")") || isOp(t,"}") || isOp(t,"]")) { if (pd3===0) break; pd3--; }
        else if (pd3===0 && t.type==="name") {
            if (["function","do","for","while","repeat"].includes(t.value)) kd3++;
            else if (t.value==="end" || t.value==="until") { if (kd3===0) break; kd3--; }
            else if (t.value==="if") { if (!isExprIf(m)) kd3++; }
            else if (kd3===0 && t.value==="else") break;
        }
        if (pd3===0 && kd3===0 && isOp(t,";")) break;
        m++;
    }
    if (m >= toks.length) return null;
    const jt = (a,b) => toks.slice(a,b).map(t=>t.value).join(" ");
    const mk = (t) => {
        if (/^(local|for|while|repeat|return|break|do)\b/.test(t) || /\bend\b/.test(t)) return `${t}; return nil`;
        return `return ${t}`;
    };
    return {
        startPos: toks[i].pos,
        endPos: toks[m-1].end,
        text: `(function() if ${jt(i+1,condEnd)} then ${mk(jt(condEnd+1,elseIdx))} else ${mk(jt(elseIdx+1,m))} end end)()`,
    };
}

const edits = [];
for (let i = toks.length - 1; i >= 1; i--) {
    if (!isName(toks[i], "if")) continue;
    const p = toks[i-1];
    const ok = (p.type==="op" && ops.includes(p.value)) || (p.type==="name" && names.includes(p.value));
    if (!ok) continue;
    if (!isExprIf(i)) continue;
    const r = parseIfAt(i);
    if (!r) continue;
    if (edits.some(e => !(r.endPos <= e.pos || r.startPos >= e.end))) continue;
    edits.push({ pos: r.startPos, end: r.endPos, text: r.text });
}
edits.sort((a,b) => b.pos - a.pos);
let out = orig;
for (const e of edits) out = out.slice(0, e.pos) + e.text + out.slice(e.end);
console.log("转换:", edits.length);
fs.writeFileSync("item51_v4.txt", "return { " + out + " }");
fs.writeFileSync("edits51_v4.json", JSON.stringify(edits));
