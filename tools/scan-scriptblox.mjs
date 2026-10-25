/** 批量拉取 ScriptBlox 热门脚本，提取真实代码，检测保护类型 */
import fs from "node:fs";

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";
const H = { "User-Agent": UA, "Accept": "application/json", "Referer": "https://scriptblox.com/" };

async function get(url, json = true) {
    const r = await fetch(url, { headers: H, signal: AbortSignal.timeout(40000) });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return json ? await r.json() : await r.text();
}

const LOADER_RE = /loadstring\s*\(\s*(?:game\s*:\s*)?HttpGet\s*\(\s*["']([^"']+)["']\s*\)\s*\)/i;

async function resolveChain(startText, maxHops = 6) {
    let text = startText, url = "(inline)", hops = [];
    for (let i = 0; i < maxHops; i++) {
        const m = text.match(LOADER_RE);
        if (!m) break;
        url = m[1];
        hops.push(url);
        try {
            const r = await fetch(url, { headers: { "User-Agent": UA }, signal: AbortSignal.timeout(40000) });
            text = await r.text();
        } catch (e) { hops.push("FAIL:" + e.message); break; }
    }
    return { text, hops };
}

function classify(text) {
    if (/Luraph Obfuscator|This file was protected using Luraph/i.test(text)) return "Luraph";
    if (/lura\.ph|lura\.ph/.test(text)) return "Luraph?";
    if (/\bMoonsec|moonsec\.com/i.test(text)) return "Moonsec";
    if (/IronBrew|ironbrew/i.test(text)) return "IronBrew";
    const esc = (text.match(/\\\d{1,3}/g) || []).length;
    const b64 = [...text.matchAll(/"([A-Za-z0-9+/=]{500,})"/g)].length;
    const bxor = /bit32\.bxor/.test(text);
    if (b64 >= 4 && bxor) return "Lua-Guard?";
    if (esc > 5000) return `数字转义(${esc})`;
    if (b64 > 0) return `base64段(${b64})`;
    return "未知/明文";
}

const keywords = ["hub", "aimbot", "esp"];
const seen = new Set();
const results = [];

for (const kw of keywords) {
    const j = await get(`https://scriptblox.com/api/script/search?q=${kw}&page=1&max=20`);
    for (const s of j.result?.scripts || []) {
        const id = s._id;
        if (!id || seen.has(id)) continue;
        seen.add(id);
        const code = s.script || "";
        let finalText = code, hops = [];
        if (LOADER_RE.test(code)) {
            const r = await resolveChain(code);
            finalText = r.text; hops = r.hops;
        }
        results.push({
            title: (s.title || "").slice(0, 42),
            views: s.views || 0,
            bytes: finalText.length,
            kind: classify(finalText),
            hops: hops.length,
            id,
        });
    }
}

results.sort((a, b) => b.views - a.views);
console.log("=== 热门脚本保护类型 ===");
for (const r of results.slice(0, 18)) {
    console.log(`${String(r.views).padStart(8)} | ${String(r.bytes).padStart(8)}B | ${(r.kind + "            ").slice(0, 14)} | ${r.title}`);
    if (r.hops) console.log(`         └ 经过 ${r.hops} 层加载器`);
}
fs.writeFileSync("scan_results.json", JSON.stringify(results, null, 2));
