/** 追踪 loadstring(HttpGet("url")) 链，直到拿到真正的脚本 */
import fs from "node:fs";

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

async function fetchText(url) {
    const r = await fetch(url, { headers: { "User-Agent": UA }, signal: AbortSignal.timeout(45000) });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.text();
}

const LOADER_RE = /loadstring\s*\(\s*(?:game\s*:\s*)?HttpGet\s*\(\s*["']([^"']+)["']\s*\)\s*\)/i;

const [startUrl, maxHops = 8] = process.argv.slice(2);
let url = startUrl;
let text = "";
for (let hop = 1; hop <= Number(maxHops); hop++) {
    try {
        text = await fetchText(url);
    } catch (e) {
        console.log(`[${hop}] 下载失败 ${url}: ${e.message}`);
        break;
    }
    const m = text.match(LOADER_RE);
    console.log(`[${hop}] ${url}`);
    console.log(`     ${text.length} 字节`);
    if (m) {
        console.log(`     → 加载器，指向 ${m[1]}`);
        url = m[1];
        continue;
    }
    console.log(`     → 非加载器（真实脚本）`);
    const out = url.split("/").pop().replace(/[^\w.-]/g, "_") || "final.lua";
    fs.writeFileSync(out, text);
    console.log(`     已保存: ${out}`);
    break;
}
