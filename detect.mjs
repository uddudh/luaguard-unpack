/**
 * 防护识别器：给任意一个 Roblox 脚本源文件，判断它被什么保护、能不能解。
 *
 * 这是「任意链接」的入口。现在的判定基于特征指纹：
 *   - Lua-Guard：42/若干段长 base64 + SHA256 校验 + 自研 VM
 *   - IronBrew2：常见的 VM 混淆，特征是超长数字转义字符串 + 巨型 if/elseif 链
 *   - Luraph：类似但有自己的 VM 结构
 *   - 朴素混淆：单层 base64 / XOR / 字符串拼接
 *
 * 认不出来时不要瞎猜，输出「未知 + 已提取到的线索」，方便人工判断。
 */
import fs from "node:fs";

const P = (s) => s;

/** 常见混淆器的特征指纹 */
const FINGERPRINTS = [
    {
        name: "Lua-Guard",
        check(ctx) {
            const segs = ctx.longBase64;
            // Lua-Guard 的真实指纹（实测三个样本都有）：分片长 base64 + bit32.bxor 运算
            const hasBxor = /bit32\.bxor/.test(ctx.src);
            const hasChunks = segs.length >= 4;
            // 段数异常多（v1 是 42 段）几乎只有分片方案会这么干
            const manySegs = segs.length >= 10;
            if (manySegs && hasBxor) return { score: 96, note: `${segs.length} 个长 base64 段 + bit32.bxor（Lua-Guard v1 分片方案）` };
            if (hasChunks && hasBxor) return { score: 90, note: `${segs.length} 个长 base64 段 + bit32.bxor（Lua-Guard）` };
            if (manySegs) return { score: 75, note: `${segs.length} 个长 base64 段（分片方案，但没看到 bit32.bxor）` };
            if (hasChunks) return { score: 55, note: `${segs.length} 个长 base64 段` };
            return null;
        },
    },
    {
        name: "IronBrew2 / VM 混淆",
        check(ctx) {
            // IronBrew 的典型特征：大量 \ddd 转义 + 巨型 elseif 链 + 自研 bytecode
            const esc = (ctx.src.match(/\\\d{1,3}/g) || []).length;
            const elseif = (ctx.src.match(/\belseif\b/g) || []).length;
            if (esc > 500 && elseif > 50) return { score: 85, note: `${esc} 个数字转义 + ${elseif} 个 elseif（典型 VM 反编译防护）` };
            if (elseif > 200) return { score: 60, note: `${elseif} 个 elseif（可能是控制流平坦化）` };
            return null;
        },
    },
    {
        name: "朴素 base64 / XOR",
        check(ctx) {
            const b64 = ctx.longBase64;
            const hasLoad = /loadstring\s*\(/.test(ctx.src) || /\bload\s*\(/.test(ctx.src);
            if (b64.length === 1 && b64[0].length > 1000 && hasLoad) {
                return { score: 70, note: "单个超长 base64 + loadstring（单层编码）" };
            }
            return null;
        },
    },
];

export function detect(src) {
    const longBase64 = [...src.matchAll(/"([A-Za-z0-9+/=]{500,})"/g)].map(m => m[1]);
    const ctx = { src, longBase64 };

    const hits = [];
    for (const f of FINGERPRINTS) {
        const r = f.check(ctx);
        if (r) hits.push({ name: f.name, ...r });
    }
    hits.sort((a, b) => b.score - a.score);

    const stats = {
        bytes: src.length,
        lines: src.split("\n").length,
        longBase64Count: longBase64.length,
        longBase64Total: longBase64.reduce((n, s) => n + s.length, 0),
        numericEscapes: (src.match(/\\\d{1,3}/g) || []).length,
        elseifCount: (src.match(/\belseif\b/g) || []).length,
        hasLoadstring: /loadstring\s*\(/.test(src),
        hasHttpGet: /HttpGet|http_request|request\s*\(/.test(src),
        hasGetfenv: /getfenv|getgenv|getrenv/.test(src),
    };

    return { hits, stats };
}

// CLI
if (process.argv[1] && process.argv[1].endsWith("detect.mjs")) {
    const files = process.argv.slice(2);
    for (const f of files) {
        const src = fs.readFileSync(f, "latin1");
        const r = detect(src);
        console.log(`\n=== ${f} ===`);
        console.log(`大小 ${r.stats.bytes} 字节 / ${r.stats.lines} 行`);
        console.log(`长 base64 段: ${r.stats.longBase64Count} 个（共 ${r.stats.longBase64Total} 字符）`);
        console.log(`数字转义: ${r.stats.numericEscapes} | elseif: ${r.stats.elseifCount}`);
        console.log(`loadstring: ${r.stats.hasLoadstring} | HttpGet: ${r.stats.hasHttpGet} | getfenv: ${r.stats.hasGetfenv}`);
        if (r.hits.length) {
            console.log(`判定: ${r.hits[0].name}（置信度 ${r.hits[0].score}）— ${r.hits[0].note}`);
            for (const h of r.hits.slice(1)) console.log(`  次选: ${h.name}（${h.score}）— ${h.note}`);
        } else {
            console.log(`判定: 未知格式（没有命中任何已知指纹）`);
        }
    }
}
