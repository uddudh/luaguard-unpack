# Luraph v15.1 分析记录（2026-10-25）

## 样本来源

- ScriptBlox 排名第一：**Moondiety Script**（3,905,035 views，20+ games）
- 链接链：`scriptblox` → `moondiety.com/loader` → `flowauth.net/v1/ui/Moondiety-Loader.lua`
- 最终脚本：**1,248,514 字节**
- 保护：**Luraph Obfuscator v15.1**（`https://lura.ph/`）

## 结构

```
Moondiety-Loader.lua
├─ local source = "\045\045\032..."   -- 312,087 字符的转义串
│   └─ 解码后 = Luraph VM 实现 + " -- This file was protected using Luraph Obfuscator v15.1"
└─ loadstring(source, "=FlowAuthUI")()
```

## 解出的 VM（`luraph_source.lua`，312,087 字节，3 行压缩）

```lua
return setmetatable({
    UW = function(j,K,Z,M,d,P,z,r,f) ... end,
    [1] = string.unpack,
    [100] = coroutine.running,
    [63] = unpack,
    [55] = typeof,
    [6] = next, [72] = select, [27] = bit32.band, [71] = bit32.bnot,
    [65] = table.create, [103] = string.byte, [93] = Vector3.new,
    [92] = buffer.readu16, [69] = buffer.readi16, [33] = buffer.writei16,
    [86] = UDim.new, [45] = string.match, [58] = pairs,
    ...
}, {}):FW()(...)
```

## VM 规模

| 项目 | 数值 |
|---|---|
| 表键（去重） | **96 个**（范围 0~127） |
| 值是函数 | 10 个 |
| 值是数据/库引用 | 86 个 |

## 主循环 `FW`

```lua
FW = function(j, ...)
  local K, Z, M, d, P, z, r, f, x, S, b, I, G = j:HW()
  local Y, y, D, w, N, c, V, u, R, e, W, _ = Z, M, d, P, z, r, f, x, S, b, I, G
  while K do
    if Y <= 20 then
      if Y <= 9 then
        if Y <= 4 then Y, y, D, w, c, R, W = j:ZW(w, R, V, W, u, c, D, Y, _, y, e)
        elseif Y <= 6 then Y, y, c, V, u = j:KW(w, u, V, c, N, y, Y)
        else Y, y, D, w, N, c, V = j:DW(Y, u, V, w, c, y, N, D) end
      ...
```

- `Y` 是 opcode
- 分发用嵌套 `if Y <= N`（二分）
- 每个 handler 返回新的状态元组

## 关键发现：字节码是运行时生成的

```lua
p = function(j, K, Z, M, d, P, z, r)
  if M <= 5 then
    local M = P - 79866              -- 长度/偏移
    local f, x, S = j[65](M), j[65](M), 1+0   -- table.create(M)
    return 2, {1-S, nil, M+0, S, K}, f, x, r
```

`[65] = table.create`，说明**没有静态字节码数据**，是运行时构造的。

这和 SparkHub 是同一类设计，但 Luraph 的 VM 实现是**明文**（33 万字符直接可读），
不需要像 Lua-Guard 那样解 AES。

## 难度对比

| 混淆器 | VM 源码 | 字节码 | 难度 |
|---|---|---|---|
| Lua-Guard | 明文（被分段+洗牌） | 静态数组（4 个） | ✅ 已攻克 |
| SparkHub | 明文 | 动态生成 | 🚧 架构清楚 |
| **Luraph v15.1** | **明文（33 万字符）** | **动态生成** | 🚧 刚看清架构 |

## 下一步

1. 提取 96 个 opcode handler 的语义
2. 理解状态元组的含义（`Y, y, D, w, N, c, V, u, R, e, W, _`）
3. 找到「字节码」的初始内容（`HW()` 返回 nil，说明在 `FW` 之前有初始化）

## 附：ScriptBlox API（可用）

```
https://scriptblox.com/api/script/search?q=<关键词>&page=N&max=20
https://scriptblox.com/api/script/<_id>          → {"script": {title, script, views, ...}}
```
需要 headers：`User-Agent`（浏览器 UA）+ `Accept: application/json` + `Referer: https://scriptblox.com/`
（空 q 返回 0 条，必须给关键词）

---

## 补充分析（2026-10-25 中午）

### handler 统计

**74 个 handler**（形如 `XX=function(j, ...)`），参数个数分布：1, 2, 3, ... 最多 21 个。

名字：`UW, X, j, Y, p, E, MW, lW, NW, i, n, m, g, W, G, x, A, Z, JW, DW, b, U, QW, a, Q, r, bW, BW, N, KW, B, f, M, I, PW, xW, K, J, F, t, ZW, kW, z, d, L, V, D, sW, T, GW, O, FW, cW, o, C, zW, u, LW, k, v, R, s, rW, q, H, yW, wW, h, YW, e, WW, eW, pW, l`

### 状态元组

`FW` 主循环维护 12 个状态变量：

```lua
local Y, y, D, w, N, c, V, u, R, e, W, _ = Z, M, d, P, z, r, f, x, S, b, I, G
while K do
  if Y <= 20 then ...  -- Y 是 opcode，按数值分派
```

`Y` = 当前 opcode，其余是操作数/寄存器状态。

### 表的键（96 个）

| 键 | 值 |
|---|---|
| `[1]` | `string.unpack` |
| `[100]` | `coroutine.running` |
| `[63]` | `unpack` |
| `[55]` | `typeof` |
| `[6]` | `next` |
| `[72]` | `select` |
| `[27]` | `bit32.band` |
| `[71]` | `bit32.bnot` |
| `[65]` | `table.create` |
| `[103]` | `string.byte` |
| `[93]` | `Vector3.new` |
| `[92]` | `buffer.readu16` |
| `[69]` | `buffer.readi16` |
| `[33]` | `buffer.writei16` |
| `[86]` | `UDim.new` |
| `[45]` | `string.match` |
| `[58]` | `pairs` |
| `[74]` | `buffer.fill` |
| `[44]` | `table.move` |

其余键是 handler（函数）。

---

## 补充：字节码是 buffer（二进制），且不在静态数据里

### 关键表项

| 键 | 值 |
|---|---|
| `[126]` | `buffer.readu8` |
| `[122]` | `buffer.create` |
| `[35]` | `buffer.fromstring` |
| `[48]` | `bit32.bxor` |
| `[11]` | `buffer.readu32` |
| `[30]` | `buffer.writeu32` |
| `[107]` | `buffer.readi32` |
| `[98]` | `buffer.writebits` |

并发现常量池：

```lua
y = {64864, 1900354245, 712316133, 2327542495, 4116613560,
     1520437585, 6797871, 2705944049, 1941017714}
```

### 结论

- Luraph 完全依赖 Roblox 的 **`buffer` API**（二进制读写）
- `buffer.fromstring` 在源码里**只被定义，没有被调用**
- 所以**字节码不在这个脚本的静态数据里**——要么运行时生成，要么从网络加载

### 与 SparkHub 的对比

| 项目 | SparkHub | Luraph v15.1 |
|---|---|---|
| VM 源码 | 明文（17 万字符） | 明文（31 万字符） |
| VM 规模 | 27,117 条指令 | 74 个 handler + 96 键表 |
| 字节码 | 动态生成 | **不在静态数据里** |
| 依赖 | 纯 Lua | Roblox `buffer` API |

### 两者共通的结论

**现代混淆器都不存字节码**。它们把逻辑编译进 VM 实现，或者运行时生成。
所以「提取字节码 → 反汇编」这条传统路线**对这两者都不适用**。

真正的路线是：**理解 VM 本身在做什么**（把状态机翻译回正常代码）。

---

## 深层分析（2026-10-26 续）

### VM 结构：46 个方法

`BW` 是解压函数（163 状态机），它调用 **46 个方法**：

```
c Y z p W J x G H Z K D M U L Q r b s l k B N f j q F a h A C m t u T O o R v V i g I E d yW
```

每个方法 118-538 字符，总约 15,000 字符。

**提取结果**：`tools/luraph/vm-methods.json`（含源码）+ `vm-methods-pretty.txt`（伪代码）

### 56 个 API 映射

```
[126] = buffer.readu8     [11]  = buffer.readu32
[92]  = buffer.readu16    [107] = buffer.readi32
[30]  = buffer.writeu32   [77]  = buffer.writestring
[48]  = bit32.bxor        [85]  = bit32.bor
[27]  = bit32.band        [71]  = bit32.bnot
[49]  = string.char       [103] = string.byte
[65]  = buffer.create     [96]  = setmetatable
```

### 初始状态

```lua
c = function(j) return true, 163, nil×21; end
```

**VM 从状态 163 开始。**

### 核心阻塞：Luau 语法

Luraph 用了 **Luau 的 `if` 表达式**：

```lua
P = if f[G[P]] ~= z[P] then r[P] else P
```

标准 Lua 5.4 不支持，必须转换成：

```lua
P = (function() if f[G[P]] ~= z[P] then return r[P] else return P end end)()
```

**转换器**：`tools/luraph/luau-if-expr-converter.mjs`

**已处理**：
- 37 个 if 表达式
- 嵌套的 if 表达式
- 9 个复合赋值（`y += w` → `y = y + w`）
- 区分表达式 if（无 end）和语句 if（有 end）

**仍卡在**：分支边界的自动判断（简单表达式遇 `;` 停，复杂语句不能停）——需要真正的语法分析器。

### 样本

`tools/luraph/luraph_sample.lua`（Moondiety 加载器，312KB，Luraph v15.1）

---

## Luau 语法问题的完整记录（2026-10-26 晚）

### 核心阻塞

Luraph 用了 **Luau 的 `if` 表达式**：

```lua
P = if f[G[P]] ~= z[P] then r[P] else P
```

标准 Lua 5.4 不支持，必须转成：

```lua
P = (function() if f[G[P]] ~= z[P] then return r[P] else return P end end)()
```

### 为什么难：语句 if 和表达式 if 在 token 层无法区分

```lua
-- 表达式（无 end）
x = if C then A else B

-- 语句（有 end）
if C then ... end
if C then ... elseif ... end

-- 混合（最难）
then if C then local Y = ... ; return ... ; else ... end   ← 语句
then if C then A else B                                    ← 表达式
```

**判断规则（已实现）**：
1. `then` 后是 `local`/`for`/`while`/`return`/`break`/`do` → 语句 if
2. `then` 后是 `if` → 递归判断
3. `then` 分支里有顶层 `=`（赋值）→ 语句 if
4. 其余 → 表达式 if

**仍失败的场景**：深层嵌套 + 赋值 + 多语句混合。

### 已完成的工具

| 文件 | 作用 |
|---|---|
| `tools/luau/tokenizer.mjs` | Lua/Luau 词法分析器（100 行，正确分割 61,866 token） |
| `tools/luau/if-expr-converter-v4.mjs` | 基于 token 的 if 表达式转换器 |
| `tools/luau/conv51e.mjs` | 只转 [51] 主函数（用于隔离测试） |

### 尝试过的失败方案

1. **正则替换**：遇到嵌套就错
2. **Luau WASM**：`Luau.Web.js`（4.2MB Emscripten）能加载，但抓不到导出函数（`WebAssembly.instantiate` 被内部包装，无法拦截）
3. **Luau 官方 release**：只有 macOS/Ubuntu/Windows/Web 版本，无 ARM64

### 下一步（给未来的自己）

**需要真正的 Lua/Luau 语法分析器**（parser + AST），约 500-800 行：
- 词法：已有（tokenizer.mjs）
- 语法：需要递归下降解析语句/表达式
- 出 AST 后，判断 `if` 表达式变得**确定**（AST 节点类型）

**或者**：找个能在 aarch64 上跑的 Luau 编译版本（自己编译 Luau 源码）。

---

## 🎉 突破：语法层完全打通（2026-10-26 晚）

### 成果

```
luraph_source.lua (312 KB)
  → tokenizer.mjs（100 行词法分析）
  → parser.mjs（200 行递归下降语法分析）
  → 37 个 if 表达式转换
  → 9 个复合赋值转换
  → luraph_final4.lua (314 KB)
  → ✅ 编译成功（Lua 5.4）
```

**这是第一次让 Luraph 的代码通过标准 Lua 的语法检查。**

### 核心技术：递归下降 parser

**之前一直失败的原因**：用字符串匹配判断「语句 if vs 表达式 if」——不可靠。

**解法**：真正的语法分析。

```javascript
parseStatement()  // 语句：if/while/for/function/local/return
parseExpr()       // 表达式：if 表达式只在这里出现

// 关键：then 后面调哪个函数，由上下文决定
parseIfStmt() {
    this.expect("if");
    this.parseExpr();      // 条件（表达式）
    this.expect("then");
    this.parseBlock();     // ← 语句块！不是表达式
    ...
}
```

**关键洞察**：`then` 后面调 `parseExpr()`（表达式）还是 `parseStatement()`（语句），由**上下文**决定——这是字符匹配永远做不到的。

### 剩余的运行时问题

**编译成功但执行失败**：

```
attempt to call a nil value (field 'integer index')
```

**原因**：Luraph 依赖 Roblox 的 `buffer` API（userdata），用 Lua 表模拟不精确。

**需要**：
1. 精确的 `buffer` 实现（字节序、边界、signed/unsigned）
2. `coroutine` 行为对齐（Lua 5.4 vs Roblox）
3. 其他 Roblox API 细节

**这些是工程活，不是算法难题。**

### 工具清单

| 文件 | 作用 |
|---|---|
| `tools/luau/tokenizer.mjs` | 词法分析（100 行） |
| `tools/luau/parser.mjs` | **递归下降 parser（200 行，核心）** |
| `tools/luau/convert-recursive.mjs` | 递归转换器（内层优先） |
| `tools/luau/fix-nested.mjs` | 处理残留的嵌套 if 表达式 |
| `tools/luau/fix-compound.mjs` | 复合赋值转换 |
| `tools/luau/run-harness.lua` | Roblox API stub + 运行测试 |
