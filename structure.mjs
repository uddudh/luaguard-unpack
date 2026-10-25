/**
 * 控制流“半结构化”重建。
 *
 * 这个 VM 的条件跳转是「测试 + 下一条 JMP」两连：TEST/CMP 为真时 pc+2（跳过 JMP），
 * 为假时执行 JMP。所以一条 if 语句正好对应这两条指令：
 *
 *   TEST r5
 *   JMP  L0180        →   if not r5 then goto L0180 end
 *
 * 剩下的是基本块标签和无条件跳转。这不是真反编译（不重建 while/for、不做支配树），
 * 但输出的已经是 Lua 语句而不是指令流。
 */

// 各版本条件指令的操作数位置（实读 handler 得到）
const COND = {
    v2: {
        TEST: (a, b, c) => `r${c}`,
        CMP: (a, b, c) => {
            const m = b % 3 + 1;                       // 模式在 b 上
            const ops = { 1: "==", 2: "<", 3: "<=" };
            return `r${b} ${ops[m]} r${a}`;
        },
    },
    v3: {
        TEST: (a, b, c) => `r${a}`,
        CMP: (a, b, c) => {
            const m = b % 3 + 1;                       // 模式在 b 上
            const ops = { 1: "==", 2: "<", 3: "<=" };
            return `r${a} ${ops[m]} r${c}`;
        },
    },
    v1: {
        TEST: (a, b, c) => `r${c}`,
        CMP: (a, b, c) => `r${b} <op> r${a}   -- v1 CMP`,   // v1 的 CMP 有两个 opcode，暂不合并
    },
};

export function structured(proto, version, constOf, opNames, tpl) {
    const { a, b, c, op } = proto.code;
    const n = op.length;
    const cond = COND[version] ?? {};
    const lines = [];
    const label = (i) => `L${String(i).padStart(4, "0")}`;

    // 先收集所有跳转目标，用来判断哪些位置需要标签
    const targets = new Set();
    for (let i = 0; i < n; i++) {
        const nm = opNames?.[op[i]];
        if (nm === "JMP") targets.add(a[i]);            // v2 JMP 目标在 a；v3 在 c，下面兜底
        if (nm === "JMP") targets.add(c[i]);
    }

    let i = 0;
    while (i < n) {
        if (targets.has(i) || i === 0) lines.push(`${label(i)}:`);
        const nm = opNames?.[op[i]];

        // TEST / CMP + 紧跟的 JMP → 一条 if
        if ((nm === "TEST" || nm === "CMP") && i + 1 < n && opNames?.[op[i + 1]] === "JMP") {
            const condExpr = cond[nm] ? cond[nm](a[i], b[i], c[i]) : null;
            // 下一条 JMP 的目标：v2 在 a 字段，v3 在 c 字段
            const jmpTarget = opNames ? (version === "v3" ? c[i + 1] : a[i + 1]) : a[i + 1];
            if (condExpr) {
                lines.push(`  if not (${condExpr}) then goto ${label(jmpTarget)} end`);
                i += 2;
                continue;
            }
        }

        // 普通指令：套用已有模板
        const t = tpl?.[nm];
        lines.push(t ? `  ${t(a[i], b[i], c[i], constOf)}` : `  -- op ${op[i]}  a=${a[i]} b=${b[i]} c=${c[i]}`);
        i += 1;
    }
    lines.push(`${label(n)}:`);
    lines.push("  -- end");
    return lines.join("\n");
}
