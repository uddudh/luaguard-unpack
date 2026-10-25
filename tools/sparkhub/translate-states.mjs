/** 把 SparkHub 的状态块翻译成可读语句 */
import fs from "node:fs";

const lines = fs.readFileSync("luac_full.txt", "utf8").split("\n");
const blocks = JSON.parse(fs.readFileSync("state_blocks.json", "utf8"));
const src = fs.readFileSync("loader.lua", "latin1");

// 常量表（解释器的 1772 个常量）
let cStart = 0;
for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith("constants (1772)")) { cStart = i + 1; break; }
}
const consts = {};
for (let i = cStart; i < cStart + 1800 && i < lines.length; i++) {
    const m = lines[i].match(/^\t(\d+)\t([IF])\t(.+)$/);
    if (m) consts[+m[1]] = m[3];
}

const OP = {
    MOVE: (a,b) => `r${a} = r${b}`,
    LOADK: (a,b) => `r${a} = K[${b}]${consts[b] ? "  // " + consts[b] : ""}`,
    LOADI: (a,b) => `r${a} = ${b}`,
    GETTABLE: (a,b,c) => `r${a} = r${b}[r${c}]`,
    SETTABLE: (a,b,c) => `r${a}[r${b}] = r${c}`,
    GETUPVAL: (a,b) => `r${a} = up[${b}]`,
    CALL: (a,b,c) => `r${a} = r${a}(...)  // ${b-1} in`,
    GETI: (a,b,c) => `r${a} = r${b}[${c}]`,
    JMP: (a) => `-- goto ${a}`,
    TEST: (a,b) => `if not r${a} then`,
    TESTSET: (a,b,c) => `r${a} = r${b}`,
    EQ: (a,b,c) => `if r${a} == r${b} then`,
    LT: (a,b,c) => `if r${a} < r${b} then`,
    LE: (a,b,c) => `if r${a} <= r${b} then`,
    NEWTABLE: (a) => `r${a} = {}`,
    LOADNIL: (a,b) => `r${a}..r${a+b} = nil`,
    LOADTRUE: (a) => `r${a} = true`,
    LOADFALSE: (a) => `r${a} = false`,
    ADD: (a,b,c) => `r${a} = r${b} + r${c}`,
    SUB: (a,b,c) => `r${a} = r${b} - r${c}`,
    MUL: (a,b,c) => `r${a} = r${b} * r${c}`,
    GETRET: (a) => `r${a} = rets`,
    VARARG: (a) => `r${a} = ...`,
};

const out = [];
out.push("; SparkHub 状态机翻译");
out.push(`; 共 ${blocks.length} 个状态块`);
out.push("");

for (const b of blocks) {
    const size = b.endLine - b.startLine;
    if (size > 200) continue;   // 跳过超大块（先用小块的）
    out.push(`;; ===== 状态 ${b.state}（${size} 行）=====`);
    for (let i = b.startLine; i <= b.endLine && i < lines.length; i++) {
        const mm = lines[i].match(/^\s*\d+\s+\[\d+\]\s+(\S+)\s+(.*)$/);
        if (!mm) continue;
        const [, op, args] = mm;
        const nums = (args.match(/-?\d+/g) || []).map(Number);
        const f = OP[op];
        if (f) {
            out.push("  " + f(...nums));
        } else {
            out.push(`  -- ${op} ${args.replace(/;.*/, "").trim()}`);
        }
    }
    out.push("");
}

fs.writeFileSync("states_translated.txt", out.join("\n"));
console.log("已翻译", blocks.filter(b => b.endLine - b.startLine <= 200).length, "个状态块");
console.log("输出: states_translated.txt");
console.log("\n前 40 行:");
console.log(out.slice(0, 40).join("\n"));
