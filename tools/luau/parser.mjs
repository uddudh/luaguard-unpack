/** Lua/Luau 递归下降 parser（最小实现，只为了区分语句/表达式 if） */
import { tokenize, isName, isOp } from "./tokenizer.mjs";

const BINPRI = {
    "or": [1,1], "and": [2,2],
    "<": [3,3], ">": [3,3], "<=": [3,3], ">=": [3,3], "~=": [3,3], "==": [3,3],
    "|": [4,4], "~": [5,5], "&": [6,6], "<<": [7,7], ">>": [7,7],
    "..": [9,8],   // 右结合
    "+": [10,10], "-": [10,10],
    "*": [11,11], "/": [11,11], "//": [11,11], "%": [11,11],
    "^": [14,13],  // 右结合
};
const UNARY_PRI = 12;

export class Parser {
    constructor(src) {
        this.toks = tokenize(src);
        this.pos = 0;
        this.edits = [];   // 需要转换的 if 表达式位置
    }
    cur() { return this.toks[this.pos]; }
    peek(k = 1) { return this.toks[this.pos + k]; }
    next() { return this.toks[this.pos++]; }
    check(v) { const t = this.cur(); return t && (t.value === v); }
    checkType(tp) { const t = this.cur(); return t && t.type === tp; }
    accept(v) { if (this.check(v)) { this.pos++; return true; } return false; }
    expect(v) { if (!this.accept(v)) throw new Error(`期望 ${v}，实际 ${JSON.stringify(this.cur()?.value)} @${this.cur()?.pos}`); }

    /** 表达式 */
    parseExpr(limit = 0) {
        let left = this.parseUnary();
        while (true) {
            const t = this.cur();
            if (!t) break;
            const op = t.value;
            const pri = BINPRI[op];
            if (!pri || pri[0] <= limit) break;
            this.next();
            const right = this.parseExpr(pri[1]);
            left = { type: "binop", op, left, right };
        }
        return left;
    }
    parseUnary() {
        const t = this.cur();
        if (t && (t.value === "not" || t.value === "-" || t.value === "#" || t.value === "~")) {
            this.next();
            return { type: "unop", op: t.value, expr: this.parseExpr(UNARY_PRI) };
        }
        return this.parseSimple();
    }
    parseSimple() {
        const t = this.cur();
        if (!t) throw new Error("表达式意外结束");
        // if 表达式（Luau）
        if (t.value === "if") {
            return this.parseIfExpr();
        }
        // 字面量
        if (t.type === "number") { this.next(); return { type: "number", value: t.value }; }
        if (t.type === "string") { this.next(); return { type: "string", value: t.value }; }
        if (t.value === "nil" || t.value === "true" || t.value === "false") {
            this.next(); return { type: "literal", value: t.value };
        }
        if (t.value === "...") { this.next(); return { type: "vararg" }; }
        if (t.value === "function") { this.next(); this.parseFuncBody(); return { type: "func" }; }
        if (t.value === "(") {
            this.next();
            const e = this.parseExpr();
            this.expect(")");
            return { type: "paren", expr: e };
        }
        if (t.value === "{") { return this.parseTable(); }
        // 名字 / 前缀表达式
        if (t.type === "name") {
            this.next();
            let node = { type: "name", value: t.value };
            // 后缀
            while (true) {
                const s = this.cur();
                if (!s) break;
                if (s.value === ".") { this.next(); const n = this.next(); node = { type: "member", obj: node, key: n.value }; continue; }
                if (s.value === "[") { this.next(); const k = this.parseExpr(); this.expect("]"); node = { type: "index", obj: node, key: k }; continue; }
                if (s.value === ":") { this.next(); const n = this.next(); this.parseArgs(); node = { type: "methodcall", obj: node, name: n.value }; continue; }
                if (s.value === "(" || s.value === "{" || s.type === "string") { this.parseArgs(); node = { type: "call", fn: node }; continue; }
                break;
            }
            return node;
        }
        throw new Error(`意外的 token: ${JSON.stringify(t.value)} @${t.pos}`);
    }
    parseArgs() {
        if (this.check("(")) {
            this.next();
            if (!this.check(")")) {
                do { this.parseExpr(); } while (this.accept(","));
            }
            this.expect(")");
        } else if (this.check("{")) {
            this.parseTable();
        } else if (this.checkType("string")) {
            this.next();
        }
    }
    parseTable() {
        this.expect("{");
        while (!this.check("}")) {
            if (this.check("[")) {
                this.next(); this.parseExpr(); this.expect("]"); this.expect("="); this.parseExpr();
            } else if (this.checkType("name") && isOp(this.peek(), "=")) {
                this.next(); this.next(); this.parseExpr();
            } else {
                this.parseExpr();
            }
            if (!this.accept(",") && !this.accept(";")) break;
        }
        this.expect("}");
        return { type: "table" };
    }
    /** Luau 的 if 表达式：if C then A else B（elseif 可多个） */
    parseIfExpr() {
        const startTok = this.cur();
        this.expect("if");
        const branches = [];
        const cond = this.parseExpr();
        this.expect("then");
        const a = this.parseExpr();
        branches.push({ cond, val: a });
        while (this.check("elseif")) {
            this.next();
            const c2 = this.parseExpr();
            this.expect("then");
            const v2 = this.parseExpr();
            branches.push({ cond: c2, val: v2 });
        }
        this.expect("else");
        const b = this.parseExpr();
        const endTok = this.toks[this.pos - 1];
        // 记录：这是一个「表达式 if」，需要转换成函数包装
        this.edits.push({
            startPos: startTok.pos,
            endPos: endTok.end,
            branches,
            elseVal: b,
        });
        return { type: "ifexpr", branches, elseVal: b };
    }
    parseFuncBody() {
        this.expect("(");
        while (!this.check(")")) { this.next(); if (!this.accept(",")) break; }
        this.expect(")");
        this.parseBlock();
        this.expect("end");
    }
    /** 语句 */
    parseStatement() {
        const t = this.cur();
        if (!t) return null;
        if (t.value === "if") { this.parseIfStmt(); return; }
        if (t.value === "while") { this.next(); this.parseExpr(); this.expect("do"); this.parseBlock(); this.expect("end"); return; }
        if (t.value === "for") { this.next(); while (!this.check("do")) this.next(); this.next(); this.parseBlock(); this.expect("end"); return; }
        if (t.value === "repeat") { this.next(); this.parseBlock(); this.expect("until"); this.parseExpr(); return; }
        if (t.value === "function") { this.next(); while (!this.check("(")) this.next(); this.parseFuncBody(); return; }
        if (t.value === "local") {
            this.next();
            if (this.check("function")) { this.next(); this.next(); while (!this.check("(")) this.next(); this.parseFuncBody(); return; }
            do { this.next(); } while (this.accept(","));
            if (this.accept("=")) { do { this.parseExpr(); } while (this.accept(",")); }
            return;
        }
        if (t.value === "return") {
            this.next();
            if (!this.check("end") && !this.check(";") && this.cur()) {
                do { this.parseExpr(); } while (this.accept(","));
            }
            this.accept(";");
            return;
        }
        if (t.value === "break" || t.value === "continue") { this.next(); return; }
        if (t.value === "do") { this.next(); this.parseBlock(); this.expect("end"); return; }
        if (t.value === ";") { this.next(); return; }
        // 表达式语句（赋值或调用）
        const e = this.parseExpr();
        if (this.accept("=")) {
            do { this.parseExpr(); } while (this.accept(","));
        } else if (this.cur() && [",", "="].some(v => this.check(v))) {
            while (this.accept(",")) this.parseExpr();
            this.expect("=");
            do { this.parseExpr(); } while (this.accept(","));
        }
    }
    parseIfStmt() {
        this.expect("if");
        this.parseExpr();
        this.expect("then");
        this.parseBlock();
        while (this.check("elseif")) {
            this.next(); this.parseExpr(); this.expect("then"); this.parseBlock();
        }
        if (this.accept("else")) this.parseBlock();
        this.expect("end");
    }
    parseBlock() {
        while (this.cur() && !["end", "else", "elseif", "until"].includes(this.cur().value)) {
            const before = this.pos;
            this.parseStatement();
            if (this.pos === before) { this.next(); }   // 防止死循环
        }
    }
    parseChunk() {
        while (this.cur()) {
            const before = this.pos;
            try { this.parseStatement(); } catch (e) {
                // 跳过错误的 token
                this.pos = before + 1;
            }
            if (this.pos === before) this.next();
        }
        return this.edits;
    }
}
