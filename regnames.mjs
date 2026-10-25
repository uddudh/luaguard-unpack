/**
 * 寄存器来源追踪。
 *
 * 不做真正的变量重命名（那需要 SSA/数据流分析），而是追踪每个寄存器「当前的来源表达式」，
 * 然后挂在指令后面当注释。读者能直接看到：
 *
 *   r34 = r36[r37]        ; r34 = r36["getgenv"]
 *   r34(r35)              ; 调用 r36["getgenv"]
 *
 * 只在基本块内线性传播：任何写入寄存器的指令都会清掉旧来源，所以不会张冠李戴。
 */

// 各版本里「目标寄存器」和「源寄存器」的位置（实读 handler 得到）
const LAYOUT = {
    v2: {
        LOADK:        { dst: (a, b, c) => a, src: (a, b, c) => c },        // R[a] = K[c]
        MOVE:         { dst: (a, b, c) => c, src: (a, b, c) => b },
        GETTABLE:     { dst: (a, b, c) => b, src: (a, b, c) => a, key: (a, b, c) => c },
        GETGLOBAL:    { dst: (a, b, c) => b, src: (a, b, c) => c },
        GETUPVAL:     { dst: (a, b, c) => c },
        CALL0:        { ret: (a, b, c) => c, fn: (a, b, c) => c },
        CALL2:        { ret: (a, b, c) => c, fn: (a, b, c) => c },
        CALL3:        { ret: (a, b, c) => b, fn: (a, b, c) => b },
    },
    v3: {
        LOADK:        { dst: (a, b, c) => c, src: (a, b, c) => b },
        MOVE:         { dst: (a, b, c) => c, src: (a, b, c) => b },
        GETTABLE:     { dst: (a, b, c) => c, src: (a, b, c) => b, key: (a, b, c) => a },
        GETGLOBAL:    { dst: (a, b, c) => b, src: (a, b, c) => c },
        GETUPVAL:     { dst: (a, b, c) => c },
        CALL0:        { ret: (a, b, c) => c, fn: (a, b, c) => c },
        CALL2:        { ret: (a, b, c) => b, fn: (a, b, c) => b },
        CALL3:        { ret: (a, b, c) => c, fn: (a, b, c) => c },
    },
};

/** 写到这些寄存器的指令要清掉来源，避免污染后续 */
const WRITES = {
    v2: { LOADK: "dst", MOVE: "dst", GETTABLE: "dst", GETGLOBAL: "dst", GETUPVAL: "dst", NEWTABLE: "c", SETNIL: "a",
          CALL0: "ret", CALL2: "ret", CALL3: "ret", GETRET: "c", CONCAT: "c", ADDI: "c", SUBI: "b",
          NOT: "b", ARITH: "b" },
    v3: { LOADK: "dst", MOVE: "dst", GETTABLE: "dst", GETGLOBAL: "dst", GETUPVAL: "dst", NEWTABLE: "c", SETNIL: "b",
          CALL0: "ret", CALL2: "ret", CALL3: "ret", GETRET: "c", CONCAT: "c", ADDI: "a", SUBI: "c",
          NOT: "a", ARITH: "b" },
};

/**
 * 返回一个函数：给第 i 条指令生成注释文本（可能为空串）
 */
export function makeDescriber(proto, version, constOf, opNames) {
    const L = LAYOUT[version];
    const W = WRITES[version];
    if (!L || !W) return () => "";
    const { a, b, c, op } = proto.code;
    const from = new Map();   // reg -> 来源表达式
    const notes = [];         // 每条指令的注释

    for (let i = 0; i < op.length; i++) {
        const nm = opNames?.[op[i]];
        const cur = L[nm];
        let note = "";

        if (cur) {
            if (nm === "LOADK") {
                const s = constOf(cur.src(a[i], b[i], c[i]));
                from.set(cur.dst(a[i], b[i], c[i]), s);
                note = `${"r"}${cur.dst(a[i], b[i], c[i])} = ${s}`;
            } else if (nm === "MOVE") {
                const d = cur.dst(a[i], b[i], c[i]), sr = cur.src(a[i], b[i], c[i]);
                if (from.has(sr)) from.set(d, from.get(sr));
                else from.delete(d);
            } else if (nm === "GETTABLE") {
                const d = cur.dst(a[i], b[i], c[i]);
                const base = from.get(cur.src(a[i], b[i], c[i])) ?? `r${cur.src(a[i], b[i], c[i])}`;
                const key = from.get(cur.key(a[i], b[i], c[i])) ?? `r${cur.key(a[i], b[i], c[i])}`;
                from.set(d, `${base}[${key}]`);
                note = `r${d} = ${base}[${key}]`;
            } else if (nm === "CALL0" || nm === "CALL2" || nm === "CALL3") {
                const f = from.get(cur.fn(a[i], b[i], c[i]));
                if (f) note = `调用 ${f}`;
                const d = cur.ret(a[i], b[i], c[i]);
                from.delete(d);
            }
        }

        // 只有「非追踪指令」才按 WRITES 清来源；否则会把刚设好的又删掉
        if (!cur) {
            const w = W[nm];
            if (w === "a") from.delete(a[i]);
            else if (w === "b") from.delete(b[i]);
            else if (w === "c") from.delete(c[i]);
        }

        // 跳转改变了线性可达性，之后沿用旧来源就会张冠李戴——直接全部清掉
        if (nm === "JMP" || nm === "TEST" || nm === "CMP") from.clear();

        notes.push(note);
    }
    return (i) => notes[i] ?? "";
}
