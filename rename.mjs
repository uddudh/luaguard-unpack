/**
 * 寄存器命名：把 rN 换成有意义的别名。
 *
 * 不是还原原始变量名（那信息在编译时已丢失），而是根据「这个寄存器第一次是怎么被
 * 赋值的」给它一个语义化名字，让输出从寄存器流水账变成可读代码：
 *
 *   r2 = up[1]                →  env1
 *   r3 = K["KillAuraEnabled"] →  c_KillAuraEnabled
 *   r1 = r2[r3]               →  t1
 *   r1 = r1(r2, r3)           →  fn1
 *
 * 规则保守：只改名字，不改结构；名字冲突时加序号。
 */

/** 从一条语句里判断目标寄存器应该叫什么 */
function guessName(expr, used) {
    let base = null;
    let m;
    if ((m = expr.match(/^up\[(\d+)\]$/))) base = `env${m[1]}`;
    else if ((m = expr.match(/^K\["([A-Za-z_][A-Za-z0-9_]*)"\]$/))) base = `c_${m[1]}`;
    else if (/^K\[\d+\]$/.test(expr)) base = "const";
    else if (/^\{/.test(expr)) base = "tbl";
    else if (/^closure\(/.test(expr)) base = "fn";
    else if (/^rets\[/.test(expr)) base = "ret";
    else if (/^K\["/.test(expr)) base = "str";
    else if (/^true$|^false$|^nil$/.test(expr)) base = "flag";
    else if (/^-?\d+(\.\d+)?$/.test(expr)) base = "num";
    else if (/^not /.test(expr)) base = "flag";
    else if (/ [\+\-\*\/%^] /.test(expr)) base = "num";
    else if (/^\.\.$| \.\. /.test(expr)) base = "str";
    else if (/^r\d+\(|^r\d+\[|\($/.test(expr)) base = "t";
    if (!base) return null;
    // 去重
    let name = base, n = 2;
    while (used.has(name)) name = base + (n++);
    used.add(name);
    return name;
}

/**
 * @param {string[]} lines  structured 输出的行
 * @returns {string[]}
 */
export function renameRegisters(allLines) {
    // 按标签切块，每块独立命名（块内寄存器基本不复用，跨块则会反复复用）
    const blocks = [];
    let cur = [];
    for (const l of allLines) {
        if (/^L\d+:/.test(l)) { if (cur.length) blocks.push(cur); cur = [l]; }
        else cur.push(l);
    }
    if (cur.length) blocks.push(cur);
    return blocks.flatMap(renameBlock);
}

function renameBlock(lines) {
    // 统计每个寄存器被赋值的次数。寄存器在 Lua 里会被反复复用，
    // 给「被复用」的寄存器起统一名字会产生严重误导（同一个名字两处含义不同），
    // 所以只命名全程只赋值一次的寄存器。
    const defCount = new Map();
    const firstExpr = new Map();
    for (const line of lines) {
        const m = line.match(/^\s*r(\d+) = (.+?)(?:\s+;.*)?$/);
        if (!m) continue;
        const [, reg, expr] = m;
        defCount.set(reg, (defCount.get(reg) || 0) + 1);
        if (!firstExpr.has(reg)) firstExpr.set(reg, expr);
    }
    const used = new Set();
    const nameOf = new Map();
    for (const [reg, expr] of firstExpr) {
        if (defCount.get(reg) !== 1) continue;      // 被复用 → 不命名
        const nm = guessName(expr.trim(), used);
        if (nm) nameOf.set(reg, nm);
    }
    if (!nameOf.size) return lines;

    return lines.map(line => {
        // 保护 K[...]、up[...]、Lxxxx 里的数字不被误替换
        // 只匹配「r 后面跟数字」的寄存器；K[2]、up[3] 里的数字前面没有 r，自然不会命中
        return line.replace(/\br(\d+)\b/g, (whole, d) => {
            const nm = nameOf.get(d);
            return nm ? nm : whole;
        });
    });
}
