/** VEIL 第三层：严格按源码的位偏移管理（oaE） */
export function lzssDecompress(input, targetLen) {
    const out = [];
    let ip = 0;                 // 字节流位置
    let curByte = 0;            // 当前标志字节 (quJwQ)
    let oaE = 8;                // 位偏移，8 表示需要读新字节

    const readByte = () => (ip < input.length ? input[ip++] : -1);

    while (out.length < targetLen) {
        if (oaE >= 8) {
            const b = readByte();
            if (b < 0) break;
            curByte = b;
            oaE = 0;
        }
        // 统计前导零
        let zeros = 0;
        while (oaE + zeros < 8 && out.length + zeros < targetLen) {
            const bit = (curByte >> (7 - (oaE + zeros))) & 1;
            if (bit === 0) zeros++;
            else break;
        }
        if (zeros > 0) {
            // 源码：Kbzsn = min(Kbzsn, 剩余输入, 剩余目标)
            const remainingIn = input.length - ip;
            if (zeros > remainingIn) zeros = remainingIn;
            const remainingOut = targetLen - out.length;
            if (zeros > remainingOut) zeros = remainingOut;
            if (zeros < 1) break;
            for (let i = 0; i < zeros; i++) {
                const b = readByte();
                if (b < 0) return Buffer.from(out);
                out.push(b);
            }
            oaE += zeros;
            continue;
        }
        // 回引：读 2 字节（不占位流）
        if (oaE < 8 && out.length < targetLen) {
            const b1 = readByte(), b2 = readByte();
            if (b1 < 0 || b2 < 0) break;
            const ref = b1 | (b2 << 8);          // 小端 readu16
            const dist = (ref >>> 4) - 1;   // 源码 129-(134-6) = 1
            const len = (ref & 15) + 3;
            oaE += 1;                             // 只前进 1 位
            // 源码：dist = min(dist, 已输出长度)；len = min(len, 剩余目标)
            let d = dist;
            if (d > out.length) d = out.length;
            let l = len;
            if (l > targetLen - out.length) l = targetLen - out.length;
            if (d <= 0) { out.push(0); continue; }
            const start = out.length - d;
            for (let i = 0; i < l && out.length < targetLen; i++) {
                out.push(start + i < out.length ? out[start + i] : 0);
            }
        }
    }
    return Buffer.from(out);
}
