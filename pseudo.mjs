/**
 * 线性伪代码生成器。
 *
 * 把每条指令翻译成一行 Lua 风格的语句，跳转用标签表示。这不是反编译器
 * （不做控制流重建、不给变量起名），但人类可以直接顺着读逻辑。
 *
 * 每个版本的 handler 操作数位置不同，所以模板按版本分开放在 PSEUDO 里。
 * 模板函数签名 (a, b, c, K) → 字符串；K(i) 会返回带常量注释的取值表达式。
 */

// v2 (Hood Rivals)：操作数位置按 handler 实读的
const V2 = {
    LOADK: (a, b, c, K) => `r${a} = ${K(c)}`,
    MOVE: (a, b, c) => `r${c} = r${b}`,
    GETTABLE: (a, b, c) => `r${b} = r${a}[r${c}]`,
    SETTABLE: (a, b, c) => `r${c}[r${b}] = r${a}`,
    GETGLOBAL: (a, b, c, K) => `r${b} = _ENV[${K(c)}]`,
    // VM 的 pc 是 1-based，数组索引是 0-based，所以目标要减 1
    JMP: (a) => `goto L${String(a - 1).padStart(4, "0")}`,
    TEST: (a, b, c) => `if not r${c} then`,
    ADDI: (a, b, c) => `r${c} = r${c} + ${b}`,
    SUBI: (a, b, c) => `r${b} = r${c} - ${a}`,
    NEWTABLE: (a, b, c) => `r${c} = {}`,
    SETNIL: (a) => `r${a} = nil`,
    GETUPVAL: (a, b, c) => `r${c} = up[${a}]`,
    SETUPVAL: (a, b, c) => `up[${b}] = r${c}`,
    CONCAT: (a, b, c) => `r${c} = r${a} .. r${b}`,
    CALL0: (a, b, c) => `r${c} = r${c}()`,
    CALL2: (a, b, c) => `r${c} = r${c}(r${c + 1})`,
    CALL3: (a, b, c) => `r${b} = r${b}(r${b + 1}, r${b + 2})`,
    GETRET: (a, b, c) => `r${c} = rets[${a}]`,
    NOP: () => `-- nop`,
    VTOB: (a) => `r[${a}..] = rets`,
    NOT: (a, b, c) => `r${b} = not r${a}   -- mode ${c % 3 + 1}`,
    CLOSEUPS: (a, b) => `closeupvals(r${b}..)`,
    VARARG: (a, b, c) => `-- vararg: build arg table (mode ${b % 3 + 1})`,
    CALL2DISCARD: (a) => `r${a}(r${a + 1})   -- discard`,
    CALL2M: (a, b) => `rets = r${b}(r${b + 1})`,
    CLOSURE: (a, b) => `r${b} = closure(proto[${a}])`,
    ARITH: (a, b, c) => `r${b} = r${a} <op> r${c}   -- mode ${c % 6 + 1}: + - * / % ^`,
    CALL3DISCARD: (a, b) => `r${b}(r${b + 1}, r${b + 2})   -- discard`,
    CALL0M: (a, b, c) => `rets = r${c}()`,
    CALL0DISCARD: (a, b, c) => `r${c}()   -- discard`,
    CALL3M: (a, b) => `rets = r${b}(r${b + 1}, r${b + 2})`,
    CMP: (a, b, c) => `if r${b} <op> r${c} then   -- mode ${b % 3 + 1}: == < <=`,
    CALLMULTI: (a, b, c) => `-- callmulti: build arg table (mode ${b % 3 + 1})`,
};

// v3 (RIVALS)
const V3 = {
    LOADK: (a, b, c, K) => `r${c} = ${K(b)}`,
    MOVE: (a, b, c) => `r${c} = r${b}`,
    GETTABLE: (a, b, c) => `r${c} = r${b}[r${a}]`,
    SETTABLE: (a, b, c) => `r${c}[r${b}] = r${a}`,
    GETGLOBAL: (a, b, c, K) => `r${b} = _ENV[${K(c)}]`,
    // 同上：pc 1-based → 索引 0-based
    JMP: (a, b, c) => `goto L${String(c - 1).padStart(4, "0")}`,
    TEST: (a, b, c) => `if not r${a} then`,
    SUBI: (a, b, c) => `r${c} = r${a} - r${b}`,        // handler: R[k]=R-O → R[c]=a-b
    NEWTABLE: (a, b, c) => `r${c} = {}`,
    SETNIL: (a, b) => `r${b} = nil`,
    GETUPVAL: (a, b, c) => `r${b} = up[${a}]`,        // up[R] → R[O]
    SETUPVAL: (a, b, c) => `up[${c}] = r${a}`,        // up[k] ← R[R]
    CONCAT: (a, b, c) => `r${c} = r${a} .. r${b}`,
    CALL0: (a, b, c) => `r${c} = r${c}()`,
    CALL2: (a, b, c) => `r${b} = r${b}(r${b + 1})`,
    CALL3: (a, b, c) => `r${c} = r${c}(r${c + 1}, r${c + 2})`,
    GETRET: (a, b, c) => `r${c} = rets[${a}]`,
    CLOSURE: (a, b, c) => `r${c} = closure(proto[${b}])`,
    NOP: () => `-- nop`,
    VTOB: (a, b, c) => `r[${c}..] = rets`,
    VARARG: (a, b, c) => `-- vararg: build arg table (mode ${b % 3 + 1})`,
    CLOSEUPS: (a, b, c) => `closeupvals(r${c}..)`,
    CALL3M: (a, b, c) => `rets = r${b}(r${b + 1}, r${b + 2})`,
    CALL2M: (a, b, c) => `rets = r${b}(r${b + 1})`,
    CALL0M: (a, b, c) => `rets = r${c}()`,
    CALL3DISCARD: (a, b, c) => `r${c}(r${c + 1}, r${c + 2})   -- discard`,
    ARITH: (a, b, c) => `r${b} = r${a} <op> r${c}   -- mode ${c % 6 + 1}`,
    CMP: (a, b, c) => `if r${b} <op> r${c} then   -- mode ${b % 3 + 1}`,  // R[O] vs R[k]
    CALL2DISCARD: (a, b, c) => `r${c}(r${c + 1})   -- discard`,
    CALL0DISCARD: (a, b) => `r${b}()   -- discard`,
    NOT: (a, b, c) => `r${b} = not r${a}   -- mode ${c % 3 + 1}`,  // R[O]=not R[R]
    CALLMULTI: (a, b, c) => `-- callmulti: build arg table (mode ${b % 3 + 1})`,
};

// v1 (Elton)：操作数布局又是另一套（R[c] = K[b] 这类）
const V1 = {
    CALL0M: (a, b, c) => `rets = r${a}()`,
    LOADK: (a, b, c, K) => `r${c} = ${K(b)}`,
    MOVE: (a, b, c) => `r${a} = r${b}`,
    GETTABLE: (a, b, c) => `r${b} = r${a}[r${c}]`,
    SETTABLE: (a, b, c) => `r${a}[r${c}] = r${b}`,
    GETGLOBAL: (a, b, c, K) => `r${c} = _ENV[${K(a)}]`,
    JMP: (a) => `goto L${String(a - 1).padStart(4, "0")}`,
    TEST: (a, b, c) => `if not r${c} then`,
    ADD: (a, b, c) => `r${b} = r${a} + r${c}`,
    SUB: (a, b, c) => `r${b} = r${a} - r${c}`,
    MUL: (a, b, c) => `r${b} = r${a} * r${c}`,
    DIV: (a, b, c) => `r${b} = r${a} / r${c}`,
    NEWTABLE: (a) => `r${a} = {}`,
    SETNIL: (a, b, c) => `r${c} = nil`,
    GETUPVAL: (a, b, c) => `r${a} = up[${c}]`,
    SETUPVAL: (a, b, c) => `up[${c}] = r${a}`,
    CONCAT: (a, b, c) => `r${c} = r${b} .. r${a}`,
    CALL0: (a, b, c) => `r${b} = r${b}()`,
    CALL2: (a, b, c) => `r${b} = r${b}(r${b + 1})`,
    CALL3: (a, b, c) => `r${a} = r${a}(r${a + 1}, r${a + 2})`,
    GETRET: (a, b, c) => `r${a} = rets[${b}]`,
    CLOSURE: (a, b, c) => `r${c} = closure(proto[${b}])`,
    VTOB: (a) => `r[${a}..] = rets`,
    VTOA: (a, b, c) => `r${c}[${b}..] = rets`,
    LEN: (a, b, c) => `r${a} = #r${c}`,
    NOT: (a, b, c) => `r${a} = not r${c}`,
    MOD: (a, b, c) => `r${b} = r${a} % r${c}`,
    POW: (a, b, c) => `r${b} = r${a} ^ r${c}`,
    UNM: (a, b, c) => `r${a} = -r${c}`,
    LE: (a, b, c) => `if r${a} <= r${b} then`,
    LT: (a, b, c) => `if r${a} < r${b} then`,
    EQ: (a, b, c) => `if r${a} == r${b} then`,
    TESTNIL: (a, b, c) => `if r${b + 1} ~= nil then r${b} = r${b + 1}; goto L${String(a - 1).padStart(4, "0")} end`,
    FORPREP: (a, b, c) => `-- numeric for prep (r${a}, step r${a + 2})`,
    FORLOOP: (a, b, c) => `-- numeric for step`,
    VARARG: (a, b, c) => `-- vararg: build arg table`,
    COPYVARARG: (a, b, c) => `r${b}[${c}..] = ...`,
    CALLV1: (a, b, c) => `r${c} = r${c}(...)`,
    CALLV0: (a, b, c) => `r${a}(...)   -- discard`,
    CALLV1M: (a, b, c) => `rets = r${a}(...)`,
    CALL2VA: (a, b, c) => `r${a} = r${a}(r${a + 1}, ...)`,
    CALL2M: (a, b, c) => `rets = r${b}(r${b + 1}, ...)`,
    CALL3M: (a, b, c) => `rets = r${a}(r${a + 1}, r${a + 2})`,
    CALL1M: (a, b, c) => `rets = r${c}(r${c + 1})`,
    CALLMULTI: (a, b, c) => `-- callmulti: build arg table (mode ${b % 3})`,
    CALL2DISCARD: (a, b, c) => `r${a}(r${a + 1})   -- discard`,
    CALL3DISCARD: (a, b, c) => `r${a}(r${a + 1}, r${a + 2})   -- discard`,
    CALL0DISCARD: (a, b, c) => `r${a}()   -- discard`,
    METHODM: (a, b, c) => `-- method call r${b}:...(...)`,
    RETURNRANGE: (a) => `return r[${a}..]`,
};

export const TABLES = { v1: V1, v2: V2, v3: V3 };

/**
 * @param {object} proto  parseBlob 的结果
 * @param {string} version "v1" | "v2" | "v3"
 * @param {(i:number)=>string} constOf  常量索引 → 显示文本
 */
export function pseudocode(proto, version, constOf, opNames) {
    const T = TABLES[version] ?? {};
    const lines = [];
    const { op, a, b, c } = proto.code;
    for (let i = 0; i < op.length; i++) {
        lines.push(`L${String(i).padStart(4, "0")}:`);
        const nm = opNames?.[op[i]];
        const tpl = T[nm];
        if (tpl) {
            lines.push(`  ${tpl(a[i], b[i], c[i], constOf)}`);
        } else {
            lines.push(`  -- op ${op[i]}${nm ? " (" + nm + ")" : " 未命名"}  a=${a[i]} b=${b[i]} c=${c[i]}`);
        }
    }
    lines.push(`L${String(op.length).padStart(4, "0")}:`);
    lines.push("  -- end");
    return lines.join("\n").replace(/\br(\d+)\b/g, (m, d) => (Number(d) > 255 ? "r?" : m));
}
