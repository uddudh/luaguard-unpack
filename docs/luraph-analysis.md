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
