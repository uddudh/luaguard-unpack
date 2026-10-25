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

export function structured(proto, version, constOf, opNames, tpl, describe) {
    const { a, b, c, op } = proto.code;
    const n = op.length;
    const cond = COND[version] ?? {};
    const lines = [];
    const label = (i) => `L${String(i).padStart(4, "0")}`;

    // 跳转目标：无条件跳转 + 条件跳转（TEST/CMP 后紧跟的 JMP）
    const targets = new Set();
    const loopHeads = new Map();   // 目标 → 回边来源列表
    const backEdges = new Set();   // 回边所在位置
    // pc 是 1-based，转成 0-based 索引
    const jmpTargetOf = (i) => (version === "v3" ? c[i] - 1 : a[i] - 1);

    const isJmp = (i) => opNames?.[op[i]] === "JMP";
    // 目标若是另一条 JMP，沿链解析到真正的落点（防止 goto 指向被折叠掉的位置）
    const resolve = (t, depth = 0) => {
        if (depth > 16 || t < 0 || t >= n) return t;
        return isJmp(t) ? resolve(jmpTargetOf(t), depth + 1) : t;
    };

    for (let i = 0; i < n; i++) {
        const nm = opNames?.[op[i]];
        if (nm !== "JMP") continue;
        const t = resolve(jmpTargetOf(i));
        targets.add(t);
        // 目标在当前指令之前 → 这是回边，说明存在循环
        if (t <= i) {
            backEdges.add(i);
            if (!loopHeads.has(t)) loopHeads.set(t, []);
            loopHeads.get(t).push(i);
        }
    }

    let i = 0;
    while (i < n) {
        if (targets.has(i) || i === 0) {
            const heads = loopHeads.get(i);
            lines.push(`${label(i)}:${heads ? `   -- 推测是循环头（回边来自 ${heads.map(label).join(", ")}，未做支配树验证）` : ""}`);
        }
        const nm = opNames?.[op[i]];

        // TEST / CMP + 紧跟的 JMP → 一条 if
        if ((nm === "TEST" || nm === "CMP") && i + 1 < n && opNames?.[op[i + 1]] === "JMP") {
            const condExpr = cond[nm] ? cond[nm](a[i], b[i], c[i]) : null;
            // 下一条 JMP 的目标：v2 在 a 字段，v3 在 c 字段
            const jmpTarget = resolve(jmpTargetOf(i + 1));
            if (condExpr) {
                const note = describe ? describe(i) : "";
                const back = backEdges.has(i + 1) ? "   -- 推测是回边（未验证）" : "";
                lines.push(`  if not (${condExpr}) then goto ${label(jmpTarget)} end${back}${note ? "   ; " + note : ""}`);
                i += 2;
                continue;
            }
        }

        // 无条件跳转单独处理：目标要经过跳转链折叠，否则可能指向被 if 折叠掉的位置
        if (nm === "JMP") {
            lines.push(`  goto ${label(resolve(jmpTargetOf(i)))}`);
            i += 1;
            continue;
        }

        // 普通指令：套用已有模板
        const t = tpl?.[nm];
        const note = describe ? describe(i) : "";
        const stmt = t ? t(a[i], b[i], c[i], constOf) : `-- op ${op[i]}  a=${a[i]} b=${b[i]} c=${c[i]}`;
        lines.push(`  ${stmt}${note && !stmt.includes(note) ? "   ; " + note : ""}`);
        i += 1;
    }
    lines.push(`${label(n)}:`);
    lines.push("  -- end");
    return lines.join("\n");
}
