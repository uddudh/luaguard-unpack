/** Lua / Luau 词法分析器（只做 token 化，不做 AST） */
export function tokenize(src) {
    const tokens = [];
    let i = 0;
    const n = src.length;
    const push = (type, value, pos, end) => tokens.push({ type, value, pos, end });

    while (i < n) {
        const c = src[i];

        // 空白
        if (c === " " || c === "\t" || c === "\r" || c === "\n") { i++; continue; }

        // 注释
        if (c === "-" && src[i+1] === "-") {
            // 长注释 --[[ ... ]] 或 --[=[ ... ]=]
            const m = /^--\[(=*)\[/.exec(src.slice(i));
            if (m) {
                const close = "]" + m[1] + "]";
                const e = src.indexOf(close, i + m[0].length);
                i = e < 0 ? n : e + close.length;
                continue;
            }
            // 行注释
            const nl = src.indexOf("\n", i);
            i = nl < 0 ? n : nl + 1;
            continue;
        }

        // 长字符串 [[ ... ]] / [=[ ... ]=]
        if (c === "[") {
            const m = /^\[(=*)\[/.exec(src.slice(i));
            if (m) {
                const close = "]" + m[1] + "]";
                const e = src.indexOf(close, i + m[0].length);
                const end = e < 0 ? n : e + close.length;
                push("string", src.slice(i, end), i, end);
                i = end;
                continue;
            }
        }

        // 短字符串
        if (c === '"' || c === "'") {
            const start = i, q = c;
            i++;
            let val = "";
            while (i < n) {
                if (src[i] === "\\") {
                    val += src[i] + src[i+1];
                    i += 2;
                    continue;
                }
                if (src[i] === q) { i++; break; }
                val += src[i];
                i++;
            }
            push("string", val, start, i);
            continue;
        }

        // 数字（含十六进制、浮点、科学计数）
        if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(src[i+1] || ""))) {
            const start = i;
            const m = /^(0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)/.exec(src.slice(i));
            if (m) { i += m[0].length; push("number", m[0], start, i); continue; }
            i++;
            continue;
        }

        // 名字 / 关键字
        if (/[A-Za-z_]/.test(c)) {
            const start = i;
            while (i < n && /[A-Za-z0-9_]/.test(src[i])) i++;
            push("name", src.slice(start, i), start, i);
            continue;
        }

        // 长括号运算符（.. = ... == ~= <= >= //）
        const three = src.slice(i, i + 3);
        if (["...", "..="].includes(three)) { push("op", three, i, i+3); i += 3; continue; }
        const two = src.slice(i, i + 2);
        if (["==", "~=", "<=", ">=", "//", "..", "::", "->", "+=", "-=", "*=", "/=", "%=", "^="].includes(two)) {
            push("op", two, i, i+2); i += 2; continue;
        }

        // 单字符
        if ("+-*/%^#&~|<>=(){}[];:,.".includes(c)) {
            push("op", c, i, i+1); i++; continue;
        }

        // 未知字符
        push("unknown", c, i, i+1);
        i++;
    }
    return tokens;
}

/** 判断 token 是否是名字 "xxx" */
export const isName = (t, v) => t && t.type === "name" && (v === undefined || t.value === v);
export const isOp = (t, v) => t && t.type === "op" && t.value === v;
