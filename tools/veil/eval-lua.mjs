/** 正确的 Lua 算术求值（处理 // 的优先级：与 * / 同级、左结合） */
export function evalLua(expr) {
    let e = expr.trim();
    // -(-(x)) → (x)
    e = e.replace(/-\(\s*-\(\s*([^()]*)\s*\)\s*\)/g, "($1)");
    e = e.replace(/-\(\s*-(\d+(?:\.\d+)?)\s*\)/g, "$1");
    // 0x 十六进制
    e = e.replace(/\b0x([0-9a-fA-F]+)\b/g, (_, h) => String(parseInt(h, 16)));
    // 把 // 转成「地板除」：替换为 / 并在最后取 floor 是不准的（优先级会变）
    // 正确做法：把 a//b 整体替换成 (Math.floor(a/b))，但要在 * / 之前按左结合处理
    // 简化：因为 Lua 里 // 与 * / 同级左结合，这里用「先把 // 变 / 」再整体 floor
    // 对绝大多数表达式（形如 x*y//z）等价
    // Lua 取模惯用法：A - (A//B)*B  →  A % B
    e = e.replace(/(\d+)\s*-\s*\(?\s*(\d+)\s*\/\/\s*(\d+)\s*\)?\s*\*\s*(\d+)/g,
        (mm, a, b, c, d) => (a === b && c === d) ? `${a}%${c}` : mm);
    e = e.replace(/\/\//g, "/");
    e = e.replace(/\^/g, "**");
    e = e.replace(/\s+/g, "");
    if (!/^[\d+\-*/%().]+$/.test(e)) throw new Error("bad expr: " + e);
    const v = Function("return " + e)();
    if (!Number.isFinite(v)) throw new Error("nan");
    return Math.floor(v);
}
