import fs from "node:fs";
const X = JSON.parse(fs.readFileSync("x_table_v2.json", "utf8"));
const s = fs.readFileSync("loader.lua", "latin1");
const st = s.indexOf("local K={");
let i = s.indexOf("{", st) + 1;
const K = []; let cur = null;
while (i < s.length) {
    const c = s[i];
    if (cur === null) { if (c === "}") break; if (c === '"') { cur = ""; i++; continue; } i++; continue; }
    if (c === "\\") { const n = s[i+1]; cur += n === "n" ? "\n" : n === "t" ? "\t" : n === "r" ? "\r" : n; i += 2; continue; }
    if (c === '"') { K.push(cur); cur = null; i++; continue; }
    cur += c; i++;
}
const rev = (a,l,r) => { while (l<r) { const t=a[l-1]; a[l-1]=a[r-1]; a[r-1]=t; l++; r--; } };
rev(K,1,1057); rev(K,1,529); rev(K,530,1057);
const P = x => K[x-28546];

function decode(str) {
    if (!str.startsWith("E")) return null;
    const q = str.slice(1), out = [];
    let pos = 1;
    while (pos <= q.length) {
        const remain = q.length - pos + 1;
        const cnt = Math.min(5, remain);
        const vals = [];
        for (let k = 0; k < 5; k++) vals.push(k < cnt ? X[q[pos-1+k]] : 84);
        let D = 0;
        for (const v of vals) D = (D * 85 + v) >>> 0;
        const bytes = [Math.floor(D/16777216)%256, Math.floor(D/65536)%256, Math.floor(D/256)%256, D%256];
        const n = cnt===5?4:cnt===4?3:cnt===3?2:1;
        out.push(...bytes.slice(0, n));
        pos += cnt;
    }
    return Buffer.from(out);
}

// 解码所有 K[i]（i 从 0 开始），并作为 P(i+28546) 的字符串
const results = [];
for (let idx = 0; idx < K.length; idx++) {
    const raw = K[idx];
    const buf = decode(raw);
    results.push({
        pIndex: idx + 28546,
        raw: raw.slice(0, 40),
        decoded: buf ? buf.toString("utf8") : "(非E)",
        hex: buf ? buf.subarray(0, 16).toString("hex") : "",
    });
}
console.log("总字符串:", results.length);
// 统计可读的
const readable = results.filter(r => r.decoded && /^[\x20-\x7e]+$/.test(r.decoded));
console.log("可读 ASCII:", readable.length);
console.log("\n样例（可读的）:");
for (const r of readable.slice(0, 25)) console.log(`  P(${r.pIndex}) = ${JSON.stringify(r.decoded)}`);
fs.writeFileSync("sparkhub_strings.json", JSON.stringify(results, null, 1));
