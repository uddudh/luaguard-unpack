/**
 * 「转义明文」格式解包器。
 *
 * 很多 hub 的下载器会把源码包成：
 *   local source = "\045\045\032..."
 *   loadstring(source, "=Name")()
 *
 * 这不是加密，只是「每个字符写成 \ddd 十进制转义」。解出来就是原始 Lua。
 * 识别特征：一个超长的 \ddd 转义串，且文件中出现 loadstring(source…)。
 */
export function detectEscaped(src) {
    const m = src.match(/(?:local\s+)?([A-Za-z_]\w*)\s*=\s*"((?:\\\d{1,3}){200,})"/);
    if (!m) return null;
    return { varName: m[1], body: m[2] };
}

export function decodeEscaped(body) {
    const bytes = [];
    let i = 0;
    while (i < body.length) {
        const c = body[i];
        if (c === "\\") {
            let d = "", j = i + 1;
            while (j < body.length && d.length < 3 && /\d/.test(body[j])) { d += body[j]; j++; }
            if (d) { bytes.push(parseInt(d, 10)); i = j; continue; }
            // 其他转义（\n \t \r \\ \" 等）
            const n = body[i + 1];
            const map = { n: 10, t: 9, r: 13, a: 7, b: 8, f: 12, v: 11, "\\": 92, '"': 34, "'": 39 };
            if (n in map) { bytes.push(map[n]); i += 2; continue; }
            bytes.push(n.charCodeAt(0)); i += 2; continue;
        }
        bytes.push(c.charCodeAt(0));
        i++;
    }
    return Buffer.from(bytes).toString("utf8");
}
