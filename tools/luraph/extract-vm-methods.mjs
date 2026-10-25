import fs from "node:fs";
const s = fs.readFileSync("luraph_source.lua", "utf8");

const names = "c Y z p W J x G H Z K D M U L Q r b s l k B N f j q F a h A C m t u T O o R v V i g I E d yW".split(" ");
const found = {};

for (const name of names) {
    if (found[name]) continue;
    // 找 `,Name=function` 或 `{Name=function` 或 `;Name=function`
    const re = new RegExp("[,;{]" + name + "=function\\s*\\(");
    const m = re.exec(s);
    if (!m) continue;
    const start = m.index + 1 + name.length + 1;   // 指向 function 关键字
    // 配平 end
    let depth = 0, i = start;
    const kw = /\b(function|do|if|end)\b/g;
    kw.lastIndex = start;
    let mm, end = -1;
    while ((mm = kw.exec(s))) {
        const w = mm[1];
        if (w === "function" || w === "do" || w === "if") depth++;
        else if (w === "end") { depth--; if (depth === 0) { end = mm.index + 3; break; } }
    }
    if (end > 0) found[name] = { start, len: end - start, src: s.slice(start, end) };
}

console.log("找到方法:", Object.keys(found).length, "/", names.length);
const missing = names.filter(n => !found[n]);
if (missing.length) console.log("缺失:", missing.join(" "));

// 按长度排序输出
const sorted = Object.entries(found).sort((a, b) => a[1].len - b[1].len);
console.log("\n按长度:");
for (const [k, v] of sorted) console.log(`  ${k.padEnd(4)} ${String(v.len).padStart(5)} 字符`);

fs.writeFileSync("luraph_methods.json", JSON.stringify(found, null, 1));
