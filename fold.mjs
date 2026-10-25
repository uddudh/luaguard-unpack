/**
 * 表达式折叠：把「寄存器流水账」压成表达式。
 *
 * 思路（保守版）：
 *   统计每个 rN 在一条语句序列里的出现次数。若某寄存器只出现两次
 *   （一次定义 + 一次使用），说明它是纯临时量，可以直接把定义式内联到使用处。
 *   出现 ≥3 次的（真的被多处引用）保持原样，绝不复制表达式，避免语义漂移。
 *
 * 只做同一基本块内的折叠（遇标签/跳转即截断），因为跨跳转的活跃性我们不做数据流分析。
 */

/** @param {string[]} lines structured 输出的行 */
export function foldExpressions(lines) {
    const out = [];
    let block = [];

    const flush = () => {
        if (!block.length) return;
        // 每块的寄存器出现次数
        const count = new Map();
        for (const l of block) {
            for (const m of l.matchAll(/\br(\d+)\b/g)) {
                count.set(m[1], (count.get(m[1]) || 0) + 1);
            }
        }
        // 从后往前折叠，这样一次内联不会破坏前面已算好的行
        const buf = block.slice();
        for (let i = buf.length - 1; i >= 0; i--) {
            const line = buf[i];
            const m = line.match(/^(\s*)r(\d+) = (.+?)(\s+;.*)?$/);
            if (!m) continue;
            const [, indent, dst, expr, comment] = m;
            if (count.get(dst) !== 2) continue;         // 只处理「定义 1 次 + 使用 1 次」
            // 找到唯一的那个使用者（必须是后面紧邻的行，避免顺序问题）
            const useIdx = i + 1;
            if (useIdx >= buf.length) continue;
            const next = buf[useIdx];
            if (!new RegExp(`\\br${dst}\\b`).test(next)) continue;
            // 表达式本身不能含副作用（调用/vararg），否则内联会改变求值次数
            if (/\br\d+\(|\bvararg|\)\s*\(/.test(expr)) continue;
            buf[useIdx] = next.replace(new RegExp(`\\br${dst}\\b`), `(${expr})`);
            buf[i] = null;                               // 这一行被吸收
        }
        for (const l of buf) if (l !== null) out.push(l);
        block = [];
    };

    for (const line of lines) {
        // 标签、跳转、条件、注释行都是块边界
        if (/^L\d+:/.test(line) || /\bgoto\b|\bif\b/.test(line) || /^\s*--/.test(line) || /^\s*;/.test(line)) {
            flush();
            out.push(line);
        } else {
            block.push(line);
        }
    }
    flush();
    return out;
}

/**
 * 折叠后的清理：
 *  1. 删掉 `rN = (rN)` 这种自赋值（折叠加括号带出来的噪声）
 *  2. 去掉包住单一表达式的多余括号 `(K["x"])` → `K["x"]`
 *  3. 消除「跳到紧邻下一行」的 goto（fall-through），这是纯粹的结构噪声
 */
export function cleanup(lines) {
    let out = [];
    for (const l of lines) {
        let s = l;
        // 自赋值
        const self = s.match(/^(\s*)r(\d+) = \(r\2\)\s*$/);
        if (self) continue;
        // 只去掉「括号内恰好是一个安全表达式」的括号，一步到位；分两步会互相破坏
        s = s.replace(/\((K\[[^\]]*\]|up\[\d+\])\)/g, "$1");
        out.push(s);
    }
    // fall-through goto 消除
    const res = [];
    for (let i = 0; i < out.length; i++) {
        const g = out[i].match(/^\s*goto L(\d{4})\s*$/);
        if (g) {
            const nextLabel = out.slice(i + 1).find(x => /^L\d+:/.test(x));
            if (nextLabel && nextLabel.startsWith(`L${g[1]}:`)) continue;   // 跳的就是下一行 → 删掉
        }
        res.push(out[i]);
    }
    return res;
}
