/** VEIL 完整解密：从 1.78MB 编码串 → 真正的字节码 */
import fs from "node:fs";

const M = 63, OFF = 42;
const K = 125;   // 替换表异或
const V = 195;   // 密钥流异或

// 1) 第一层：base-N 解码（已验证）
function decodeLayer1(s0) {
    s0 = s0.replace(/\s/g, "");
    const base = (s0.charCodeAt(0) % 46) + 63;
    const out = [];
    for (let i = 0; i + 4 < s0.length; i += 5) {
        const c1 = s0.charCodeAt(i), c2 = s0.charCodeAt(i+1), c3 = s0.charCodeAt(i+2),
              c4 = s0.charCodeAt(i+3), c5 = s0.charCodeAt(i+4);
        let v = (M * (c5 - OFF)) % base;
        v = v + base * ((((c4 - OFF) * M) % base) +
            base * (((M * (c3 - OFF)) % base) +
            base * ((((c2 - OFF) * M) % base) +
            base * ((M * (c1 - OFF)) % base))));
        out.push((v >>> 24) & 255, (v >>> 16) & 255, (v >>> 8) & 255, v & 255);
    }
    return Buffer.from(out).subarray(0, out.length - 5);
}

// 2) 拼接 _6k / _6m
const T = JSON.parse(fs.readFileSync("veil_tables.json", "utf8"));
const cat = (...names) => names.flatMap(n => T[n] || []);
const _6k = cat("_6s", "_8r", "_1u", "_9h", "_3m", "_4c", "_7s");
const _9n = [197];
const _8n = [112, 250, 12574 % 301];
const _6m = cat("_9x", "_5d").concat(_9n).concat(_8n).concat(T["_8h"] || []);
console.log("_6k 长度:", _6k.length, "（应为 256）");
console.log("_6m 长度:", _6m.length);

// 3) 生成替换表和密钥流
const _8m = _6k.map(b => (b ^ K) & 255);        // 替换表（256）
const _5v = _6m.map(b => (b ^ V) & 255);        // 密钥流

// 4) 第二层：链式 XOR + 替换
function decodeLayer2(buf) {
    const nn = buf.length;
    const out = Buffer.alloc(nn);
    let pv = 0, ix = 0, off = 0;
    const nv = _5v.length || 1;
    while (off + 4 <= nn) {
        const e1 = buf[off], e2 = buf[off+1], e3 = buf[off+2], e4 = buf[off+3];
        const q1 = (e1 ^ _5v[ix % nv] ^ pv) & 255;
        const q2 = (e2 ^ _5v[(1+ix) % nv] ^ e1) & 255;
        const q3 = (e3 ^ _5v[(2+ix) % nv] ^ e2) & 255;
        const q4 = (e4 ^ _5v[(3+ix) % nv] ^ e3) & 255;
        // 注意源码里的字节顺序：q2*256 + q4*16777216 + q3*65536 + q1
        out[off]   = _8m[q1] ?? q1;
        out[off+1] = _8m[q2] ?? q2;
        out[off+2] = _8m[q3] ?? q3;
        out[off+3] = _8m[q4] ?? q4;
        pv = e4;
        ix += 4;
        off += 4;
    }
    while (off < nn) {
        const e1 = buf[off];
        const q1 = (e1 ^ _5v[ix % nv] ^ pv) & 255;
        out[off] = _8m[q1] ?? q1;
        pv = e1; ix++; off++;
    }
    return out;
}

const src = fs.readFileSync("VEIL.lua", "latin1");
const big = src.match(/\[==\[([^]{100,}?)\]==\]/)[1];
const l1 = decodeLayer1(big);
console.log("第一层解码:", l1.length, "字节");
const l2 = decodeLayer2(l1);
fs.writeFileSync("veil_payload2.bin", l2);
console.log("第二层解码:", l2.length, "字节");
const printable = [...l2].filter(b => (b >= 32 && b < 127) || b === 10 || b === 9).length;
console.log(`可打印率: ${(printable / l2.length * 100).toFixed(1)}%`);
console.log("\n前 200 字节 ascii:");
console.log([...l2.subarray(0, 200)].map(b => (b >= 32 && b < 127) ? String.fromCharCode(b) : ".").join(""));
