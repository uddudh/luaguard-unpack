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
    111: (a, b, c, K) => `r${a} = ${K(c)}`,                       // LOADK
    40: (a, b, c) => `r${c} = r${b}`,                             // MOVE
    108: (a, b, c) => `r${b} = r${a}[r${c}]`,                     // GETTABLE
    13: (a, b, c) => `r${c}[r${b}] = r${a}`,                      // SETTABLE
    37: (a, b, c) => `r${c} = _ENV[${"?"}]`,                      // GETGLOBAL
    217: (a) => `goto L${a}`,                                     // JMP
    215: (a, b, c) => `if not r${c} then goto fallthrough_end`,   // TEST
    216: (a, b, c) => `r${c} = r${c} + ${b}`,                     // ADDI
    203: (a, b, c) => `r${b} = r${c} - ${a}`,                     // SUBI
    124: (a, b, c) => `r${c} = {}`,                               // NEWTABLE
    22: (a) => `r${a} = nil`,                                     // SETNIL
    1: (a, b, c) => `r${c} = up[${a}]`,                           // GETUPVAL
    172: (a, b, c) => `up[${b}] = r${c}`,                         // SETUPVAL
    144: (a, b, c) => `r${c} = r${a} .. r${b}`,                   // CONCAT
    57: (a, b, c) => `r${c} = r${c}()`,                           // CALL0
    179: (a, b, c) => `r${c} = r${c}(r${c + 1})`,                 // CALL2
    44: (a, b, c) => `r${b} = r${b}(r${b + 1}, r${b + 2})`,       // CALL3
    26: (a, b, c) => `r${c} = rets[${a}]`,                        // GETRET
    115: (a) => `r? = closure(proto[${a}])`,                      // CLOSURE
    184: () => "-- nop",
    233: (a) => `R[${a}..] = rets`,                               // VTOB
};

// v3 (RIVALS)
const V3 = {
    178: (a, b, c, K) => `r${c} = ${K(b)}`,                       // LOADK：getK(字段B) → R[字段C]
    188: (a, b, c) => `r${c} = r${b}`,                            // MOVE
    30: (a, b, c) => `r${c} = r${b}[r${a}]`,                      // GETTABLE
    33: (a, b, c) => `r${c}[r${b}] = r${a}`,                      // SETTABLE
    107: (a, b, c) => `r${b} = _ENV[...]`,                        // GETGLOBAL
    203: (a, b, c) => `goto L${c}`,                               // JMP
    207: (a, b, c) => `if not r${a} then`,                        // TEST
    149: (a, b, c) => `r${a} = r${a} + ${c}`,                     // ADDI
    248: (a, b, c) => `r${c} = r${b} - r${a}`,                    // SUBI
    235: (a, b, c) => `r${c} = {}`,                               // NEWTABLE
    2: (a, b) => `r${b} = nil`,                                   // SETNIL
    60: (a, b, c) => `r${c} = up[${b}]`,                          // GETUPVAL
    171: (a, b, c) => `up[${c}] = r${b}`,                         // SETUPVAL
    6: (a, b, c) => `r${c} = r${a} .. r${b}`,                     // CONCAT
    238: (a, b, c) => `r${c} = r${c}()`,                          // CALL0
    141: (a, b, c) => `r${b} = r${b}(r${b + 1})`,                 // CALL2
    198: (a, b, c) => `r${c} = r${c}(r${c + 1}, r${c + 2})`,      // CALL3
    118: (a, b, c) => `r${c} = rets[${a}]`,                       // GETRET
    70: (a) => `r? = closure(proto[${a}])`,                       // CLOSURE
    73: () => "-- nop",
};

// v1 (Elton)：操作数布局又是另一套（R[c] = K[b] 这类）
const V1 = {
    57: (a, b, c, K) => `r${c} = ${K(b)}`,                        // LOADK
    13: (a, b, c) => `r${a} = r${b}`,                             // MOVE
    109: (a, b, c) => `r${b} = r${a}[r${c}]`,                     // GETTABLE
    116: (a, b, c) => `r${a}[r${c}] = r${b}`,                     // SETTABLE
    201: (a, b, c) => `r${c} = _ENV[...]`,                        // GETGLOBAL
    210: (a) => `goto L${a}`,                                     // JMP
    74: (a, b, c) => `if not r${c} then`,                         // TEST
    61: (a, b, c) => `r${b} = r${a} + r${c}`,                     // ADD
    70: (a, b, c) => `r${b} = r${a} - r${c}`,                     // SUB
    101: (a, b, c) => `r${b} = r${a} * r${c}`,                    // MUL
    213: (a, b, c) => `r${b} = r${a} / r${c}`,                    // DIV
    15: (a, b, c) => `r${a} = {}`,                                // NEWTABLE
    8: (a, b, c) => `r${c} = nil`,                                // SETNIL
    157: (a, b, c) => `r${a} = up[${c}]`,                         // GETUPVAL
    53: (a, b, c) => `up[${c}] = r${a}`,                          // SETUPVAL
    51: (a, b, c) => `r${c} = r${b} .. r${a}`,                    // CONCAT
    138: (a, b, c) => `r${b} = r${b}()`,                          // CALL0
    43: (a, b, c) => `r${b} = r${b}(r${b + 1})`,                  // CALL2
    131: (a, b, c) => `r${a} = r${a}(r${a + 1}, r${a + 2})`,      // CALL3
    93: (a, b, c) => `r${a} = rets[${b}]`,                        // GETRET
    152: (a, b, c) => `r${c} = closure(proto[${b}])`,             // CLOSURE
    212: (a) => `R[${a}..] = rets`,                               // VTOB
};

const TABLES = { v1: V1, v2: V2, v3: V3 };

/**
 * @param {object} proto  parseBlob 的结果
 * @param {string} version "v1" | "v2" | "v3"
 * @param {(i:number)=>string} constOf  常量索引 → 显示文本
 */
export function pseudocode(proto, version, constOf) {
    const T = TABLES[version] ?? {};
    const lines = [];
    const { op, a, b, c } = proto.code;
    for (let i = 0; i < op.length; i++) {
        lines.push(`L${String(i).padStart(4, "0")}:`);
        const tpl = T[op[i]];
        if (tpl) {
            lines.push(`  ${tpl(a[i], b[i], c[i], constOf)}`);
        } else {
            lines.push(`  -- op ${op[i]}  a=${a[i]} b=${b[i]} c=${c[i]}`);
        }
    }
    lines.push(`L${String(op.length).padStart(4, "0")}:`);
    lines.push("  -- end");
    return lines.join("\n");
}
