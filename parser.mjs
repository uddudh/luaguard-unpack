/**
 * 通用 blob 解析器：参数全部由调用方给出（从源码里提取或用 checksum 暴力确认）。
 * 已适配 v1(Elton) / v2(Hood Rivals) / v3(RIVALS) 三种变体。
 */
const IA = 0x800000;

export const READERS = {
    // v1 与 v3：第 2 字节进高 16 位
    odd: (b, p) => b[p + 1] * 65536 + b[p] * 256 + b[p + 2] - IA,
    // v2：第 3 字节进高 16 位
    m3: (b, p) => b[p + 2] * 65536 + b[p] * 256 + b[p + 1] - IA,
    // 标准大端
    be: (b, p) => b[p] * 65536 + b[p + 1] * 256 + b[p + 2] - IA,
};
const READERS4 = {
    odd: (b, p) => b[p + 3] * 16777216 + b[p + 1] * 65536 + b[p + 2] * 256 + b[p],
    m3: (b, p) => b[p + 2] * 16777216 + b[p + 3] * 65536 + b[p] * 256 + b[p + 1],
    be: (b, p) => b[p] * 16777216 + b[p + 1] * 65536 + b[p + 2] * 256 + b[p + 3],
    // v3(RIVALS)：第 3 字节进最高位，第 1 字节进次高位
    odd2: (b, p) => b[p + 2] * 16777216 + b[p] * 65536 + b[p + 3] * 256 + b[p + 1],
};

export function bx(a, b) {
    a = ((a % 256) + 256) % 256; b = ((b % 256) + 256) % 256;
    let r = 0, t = 1;
    for (let k = 0; k < 8; k++) { const x = a % 2, y = b % 2; a = Math.floor(a / 2); b = Math.floor(b / 2); if (x !== y) r += t; t *= 2; }
    return r;
}

export function lcg(seed, m1, m2, len = 32) {
    const k = []; let e = seed;
    for (let i = 1; i <= len; i++) { e = (e * 214013 + 2531011) % 16777216; k[i] = bx(e % 256, (i * m1 + m2) % 256); }
    return k;
}

/**
 * @param {Buffer} blob
 * @param {object} cfg
 *   read: "odd"|"m3"|"be"
 *   seed, mix1, mix2, opMul, checksumConst
 *   phaseOrder: [{key:"b",phase:6},{key:"a",phase:5},{key:"c",phase:7},{key:"op"}]
 */
export function parseBlob(blob, cfg) {
    const R3 = READERS[cfg.read3 ?? cfg.read], R4 = READERS4[cfg.read4 ?? cfg.read];
    let p = 0;
    const M3 = () => { if (p + 3 > blob.length) throw new Error("EOF@" + p); const v = R3(blob, p); p += 3; return v; };
    const M4 = () => { if (p + 4 > blob.length) throw new Error("EOF@" + p); const v = R4(blob, p); p += 4; return v; };
    const STR = () => { const n = M4(); if (p + n > blob.length) throw new Error("EOF-str"); const s = blob.subarray(p, p + n); p += n; return s; };

    const header = {};                       // 5 个字段，名字因版本而异，只关心它们是数组索引键
    for (let i = 0; i < 5; i++) M3();

    const numParams = M3(), startState = M3();
    const constCount = M3();
    for (let i = 0; i < constCount; i++) M3();
    const instrCount = M3();
    const keyOff = M3() + IA, shift = M3();
    const key = lcg(cfg.seed, cfg.mix1, cfg.mix2);
    for (let i = 1; i <= 32; i++) key[i] = bx(key[i], keyOff);

    const code = {};
    for (const step of cfg.phaseOrder) {
        const arr = [];
        if (step.key === "op") {
            for (let i = 0; i < instrCount; i++) {
                const v = R3(blob, p); p += 3;
                // Lua 的 % 对负数返回非负，JS 不——必须归一化，否则所有负操作数指令都错
                arr.push((((((v) - IA) - shift) * cfg.opMul) % 256 + 256) % 256);
            }
        } else {
            let d = step.phase;
            for (let i = 0; i < instrCount; i++) {
                const v = R3(blob, p); p += 3;
                arr.push(bx(v - IA, key[d]));
                d += 3; if (d > 32) d -= 32;
            }
        }
        code[step.key] = arr;
    }

    const upCount = M3();
    for (let i = 0; i < upCount; i++) { M3(); M3(); }
    const protoCount = M3();
    const protos = [];
    for (let i = 0; i < protoCount; i++) { const q = M3(); protos.push(blob.subarray(p, p + q)); p += q; }
    const checksum = M3();
    const expect = ((((((numParams * 131 + startState * 17) + constCount * 257) + instrCount * 521) +
        upCount * 1031) + protoCount * 2053) + cfg.checksumConst) % 8000001;

    return {
        nums: { numParams, startState, constCount, instrCount, upCount, protoCount },
        code, protos, checksum, expect, ok: checksum === expect, end: p,
        readGlobals: (n) => { const out = []; for (let i = 0; i < n; i++) { out.push({ name: STR().toString("latin1"), type: STR().toString("latin1"), val: STR().toString("latin1") }); } return out; },
        readResources: (n, order) => {
            const ord = order ?? ["cipher", "iv", "id", "tag"];
            const out = [];
            for (let i = 0; i < n; i++) {
                const o = {};
                for (const k of ord) o[k] = STR().toString("latin1");
                out.push(o);
            }
            return out;
        },
        count: M4,
        pos: () => p,
    };
}
