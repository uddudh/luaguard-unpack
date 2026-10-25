/** VEIL 的数据解码器（完整还原）
 *
 * Lua 原版：
 *   s0 = gsub(s0, "[%s]", "")              -- 去掉所有空白
 *   base = byte(s0,1) % 46 + 63
 *   for i = 1, #s0, 5 do
 *     c1..c5 = byte(s0, i, i+4)
 *     V = 5 个 base 进制数字组合成 32 位数（加权 63, 33+9）
 *     tt += char(V>>24, V>>16, V>>8, V)
 *   end
 *   return sub(concat(tt), 1, #rs - 5)
 */
import fs from "node:fs";

const M = 63, OFF = 33 + 9;   // _5m=63, _4b+_4p=42

function decodeVeil(s0) {
    s0 = s0.replace(/\s/g, "");
    const base = (s0.charCodeAt(0) % 46) + 63;
    const out = [];
    for (let i = 0; i + 4 < s0.length; i += 5) {
        const c1 = s0.charCodeAt(i), c2 = s0.charCodeAt(i+1), c3 = s0.charCodeAt(i+2),
              c4 = s0.charCodeAt(i+3), c5 = s0.charCodeAt(i+4);
        // V 的五层嵌套（低位在前）
        let V = (M * (c5 - OFF)) % base;
        V = V + base * ((((c4 - OFF) * M) % base) +
            base * (((M * (c3 - OFF)) % base) +
            base * ((((c2 - OFF) * M) % base) +
            base * ((M * (c1 - OFF)) % base))));
        out.push((V >>> 24) & 255, (V >>> 16) & 255, (V >>> 8) & 255, V & 255);
    }
    return Buffer.from(out).subarray(0, out.length - 5);   // #rs - 5
}

const s = fs.readFileSync("VEIL.lua", "latin1");
const big = s.match(/\[==\[([^]{100,}?)\]==\]/)[1];
console.log("原始长串:", big.length, "字符");
const decoded = decodeVeil(big);
console.log("解码后:", decoded.length, "字节");
fs.writeFileSync("veil_payload.bin", decoded);
console.log("\n前 200 字节 (hex):");
console.log([...decoded.subarray(0, 200)].map(x => x.toString(16).padStart(2, "0")).join(" "));
console.log("\n前 200 字节 (ascii):");
console.log([...decoded.subarray(0, 200)].map(x => (x >= 32 && x < 127) ? String.fromCharCode(x) : ".").join(""));
