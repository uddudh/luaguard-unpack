import fs from "node:fs";
import { evalLua } from "../samples/eval_final2.mjs";
const s = fs.readFileSync("loader.lua", "latin1");
const xi = s.indexOf("local X={");
let j = s.indexOf("{", xi), depth = 0, xst = j;
for (; j < s.length; j++) { if (s[j] === "{") depth++; else if (s[j] === "}") { depth--; if (depth === 0) break; } }
const body = s.slice(xst+1, j);

// 逐个条目：["key"]=expr 或 name=expr
// 关键：不用正则，手写扫描，保留每个键（重复时后者覆盖）
const X = {};
const seen = {};
let i = 0;
let count = 0;
while (i < body.length) {
    while (i < body.length && /[;,\s]/.test(body[i])) i++;
    if (i >= body.length) break;
    let key = null;
    if (body[i] === "[" && body[i+1] === '"') {
        let k = i + 2;
        let raw = "";
        while (k < body.length && body[k] !== '"') {
            if (body[k] === "\\" && k+1 < body.length) { raw += body[k+1]; k += 2; continue; }
            raw += body[k]; k++;
        }
        key = raw;
        k++;
        while (k < body.length && body[k] !== "=") k++;
        i = k + 1;
    } else if (/[A-Za-z_]/.test(body[i])) {
        let k = i;
        while (k < body.length && /[A-Za-z0-9_]/.test(body[k])) k++;
        key = body.slice(i, k);
        while (k < body.length && body[k] !== "=") k++;
        i = k + 1;
    } else { i++; continue; }
    let vstart = i, d = 0;
    while (i < body.length) {
        const c = body[i];
        if (c === "(" || c === "[") d++;
        else if (c === ")" || c === "]") d--;
        else if ((c === ";" || c === ",") && d === 0) break;
        i++;
    }
    const expr = body.slice(vstart, i).trim();
    if (key && expr) {
        try {
            const v = evalLua(expr);
            if (seen[key] !== undefined) count++;
            seen[key] = v;
            X[key] = v;
        } catch(e) {}
    }
}
console.log("X 项数:", Object.keys(X).length, "| 重复键:", count);
console.log("X[E] =", X["E"], "(应 36)");
console.log("X[4] =", X["4"], "(应 28)");
console.log("X[K] =", X["K"], "(应 5)");
console.log("X[Q] =", X["Q"], "(应 38)");
fs.writeFileSync("x_table_v2.json", JSON.stringify(X, null, 1));
