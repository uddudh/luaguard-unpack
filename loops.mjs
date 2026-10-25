/**
 * 自然循环识别（基于回边，简化版）。
 *
 * 做法：
 *   1. 找出所有回边（跳转目标 <= 当前位置），每条回边定义一个循环
 *      header = 目标，latch = 回边所在位置
 *   2. 按区间大小排序，从最内层开始，把嵌套关系整理成「区间 → 深度」
 *   3. 输出时按深度缩进
 *
 * 不做：循环出口分析、break/continue 识别、for 循环还原。只提供结构骨架。
 */

/** @returns {Array<{header:number, latch:number, depth:number}>} 由外到内排序的循环区间 */
export function findLoops(proto, version, opNames) {
    const { op, a, c } = proto.code;
    const n = op.length;
    const JT = version === "v3" ? c : a;          // 跳转目标字段
    const backEdges = [];
    for (let i = 0; i < n; i++) {
        const nm = opNames?.[op[i]];
        // v1 的数值 for 用 FORLOOP/FORPREP 自己跳转（目标在 c 字段）
        if (nm === "FORLOOP" || nm === "FORPREP") {
            const t = c[i] - 1;
            if (t >= 0 && t <= i) backEdges.push({ header: t, latch: i });
            continue;
        }
        if (nm !== "JMP") continue;
        const t = JT[i] - 1;                      // 1-based → 0-based
        if (t >= 0 && t <= i) backEdges.push({ header: t, latch: i });
    }
    if (!backEdges.length) return [];

    // 同一个 header 只保留最外层的那个（最远的 latch）
    const byHeader = new Map();
    for (const e of backEdges) {
        const cur = byHeader.get(e.header);
        if (!cur || e.latch > cur.latch) byHeader.set(e.header, e);
    }
    let loops = [...byHeader.values()];
    // 去掉被更大区间完全覆盖的（它们只是同一循环里的多回边）
    loops.sort((x, y) => (y.latch - y.header) - (x.latch - x.header));
    const kept = [];
    for (const l of loops) {
        if (kept.some(k => l.header >= k.header && l.latch <= k.latch)) continue;
        kept.push(l);
    }
    // 只保留「互相嵌套或完全不相交」的区间。交叉（部分重叠）说明回边判断有误，
    // 那种情况宁可不标，也不要画出不存在的结构。
    const disjoint = [];
    for (const l of kept) {
        const clash = disjoint.some(k => {
            const nested = (l.header >= k.header && l.latch <= k.latch) || (k.header >= l.header && k.latch <= l.latch);
            const apart = l.latch < k.header || k.latch < l.header;
            return !nested && !apart;
        });
        if (!clash) disjoint.push(l);
    }
    const finalLoops = disjoint;

    // 计算嵌套深度
    for (const l of finalLoops) {
        l.depth = finalLoops.filter(k => k !== l && l.header >= k.header && l.latch <= k.latch).length;
    }
    finalLoops.sort((x, y) => x.header - y.header);
    return finalLoops;
}

/** 某条指令属于第几层循环（用于缩进） */
export function depthAt(loops, i) {
    let d = 0;
    for (const l of loops) if (i >= l.header && i <= l.latch) d++;
    return d;
}
