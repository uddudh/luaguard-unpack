# VEIL 分析记录（2026-10-25）

## 样本

- ScriptBlox：`VEIL | Silent Aim, ESP, Anti Katana 2024`
- 1,813,524 字节，2 行
- 14 个 local function，27 个 while，3 个 repeat/until
- 2,467 个数字转义

## 结构

```lua
return(function(...)
  local _4f,_5n,_3k,_6n = string.rep, pcall, string.char, bit32.rshift
  local _7x,_1s,_0d = string.gsub, bit32.extract, bit32.band
  local _2j,_0n = assert, table.concat
  local _5q,_5k = bit32.byteswap, bit32.bxor
  local _5a = [==[ ... 1,786,105 字符的超长字符串 ... ]==]   -- 加密的字节码/数据
  ...
end)(...)
```

## 密钥派生（自引用）

```lua
local _5j = 0
for _0l1 = 1, #_5a do
  _5j = (string.byte(_5a, _0l1) + _5j) % 4294967296
end
local _6e = bit32.band(_5j, 255)      -- 密钥 = 数据校验和 & 255
```

**密钥由数据自身的校验和决定**，所以不能直接从文件里读出密钥——必须先算校验和。

## 字符串混淆方式

```lua
local _1b = string.char(110)                                    -- "n"
local _4q = string.char(115)                                    -- "s"
local _2c = string.char(bit32.bxor(237,_6e), bxor(245,_6e), bxor(235,_6e))
local _7d = string.char(108,111,97,100,115,116,114,105,110,103) -- "loadstring"
local _1e = string.char(105,110,116,111)                        -- "into"
```

即：要么是纯常量，要么是 `char(bxor(常量, 密钥))`。

## 已解出的字符串（部分）

```
"n", "=", "loadstring", "into", "function", "table", "_G", "debug",
"getfenv", "info", "info"
```

（求值器还有小 bug，部分字节为 0，但关键标识符已能认出）

## 与已知格式对比

| 格式 | 数据存放 | 密钥 |
|---|---|---|
| Lua-Guard | base64 分段 | sha256(salt:id:runtime) |
| SparkHub | 无静态数据（硬编码状态机） | 无 |
| Luraph | 无静态数据（buffer 运行时构造） | 无 |
| **VEIL** | **1.78 MB 超长字符串** | **数据自身校验和** |

**VEIL 是唯一保留「大块静态数据」的现代混淆器**，这意味着它可能比 SparkHub/Luraph 更容易解。

## 下一步

1. 修求值器（处理 `//` 整除和位运算细节）
2. 解完所有字符串
3. 看 `_5a` 加密数据怎么用（可能有 XOR 循环）

---

## 三层加密完整还原（2026-10-25 傍晚）

### 第 0 层：数据本体

```lua
local _5a = [==[ ... 1,786,105 字符 ... ]==]
```

### 第 1 层：自定义 Base-N 解码（`_7n`）

```lua
local function _7n(s0)
  s0 = string.gsub(s0, "[%s]", "")          -- 去掉所有空白（_4r = "[%s]"）
  local base = (string.byte(s0,1) % 46) + 63   -- 基数 63~108
  local M, OFF = 63, 42
  local tt = {}
  for i = 1, #s0, 5 do
    local c1,c2,c3,c4,c5 = string.byte(s0, i, i+4)
    local V = (M*(c5-OFF)) % base
    V = V + base * ((((c4-OFF)*M) % base) +
        base * (((M*(c3-OFF)) % base) +
        base * ((((c2-OFF)*M) % base) +
        base * ((M*(c1-OFF)) % base))))
    tt[#tt+1] = string.char(V>>24, V>>16, V>>8, V)
  end
  return string.sub(table.concat(tt), 1, #rs - 5)
end
```

**实测**：1,786,105 字符 → **1,428,879 字节**

### 第 2 层：链式 XOR（CBC 模式）+ 替换表（`_1n`）

```lua
local function _1n(d0)
  local nn = #d0
  local bi = buffer.fromstring(d0)
  local bo = buffer.create(nn)
  local pv, ix, off = 0, 0, 0
  while off+4 <= nn do
    local wd = buffer.readu32(bi, off)
    local e1 = (wd>>0) & 255
    local e2 = (wd>>8) & 255
    local e3 = (wd>>16) & 255
    local e4 = (wd>>24) & 255
    -- 链式异或：每个字节和上一字节异或
    local q1 = bxor(bxor(e1, _5v[(ix%_1t)+1]), pv)
    local q2 = bxor(bxor(e2, _5v[((1+ix)%_1t)+1]), e1)
    local q3 = bxor(bxor(e3, _5v[((ix+2)%_1t)+1]), e2)
    local q4 = bxor(bxor(e4, _5v[((ix+3)%_1t)+1]), e3)
    -- 替换表 _8m + 特殊字节顺序！
    buffer.writeu32(bo, off,
      _8m[q2+1]*256 + _8m[q4+1]*16777216 + _8m[q3+1]*65536 + _8m[q1+1])
    pv = e4; ix = ix + 4; off = off + 4
  end
  ...
end
```

**注意字节顺序**：`q2*256 + q4*16777216 + q3*65536 + q1`
（不是标准的 q1<<24|q2<<16|q3<<8|q4）

### 密钥材料

```lua
-- 替换表（256 项）
_8m[i] = bit32.bxor(_6k[i], 125)
-- 密钥流
_5v[i] = bit32.bxor(_6m[i], 195)

-- _6k 的拼接（恰好 256 项 ✅ 已验证）
_6k = _6s + _8r + _1u + _9h + _3m + _4c + _7s
     = 41 + 11 + 12 + 8 + 13 + 107 + 64 = 256

-- _6m 的拼接
_6m = _9x + _5d + _9n + _8n + _8h
     = 6 + 4 + 1 + 3 + 10 = 24 项
```

### 已提取的所有常量表

| 表 | 项数 | 内容（前几项） |
|---|---|---|
| `_6s` | 41 | 19,210,43,0,44,65,0,103... |
| `_8r` | 11 | 9,39,30,201,176,237,78,35... |
| `_1u` | 12 | 11,240,190,12,132,51,160,241... |
| `_9h` | 8 | 104,5,140,186,48,180,0,244... |
| `_3m` | 13 | 250,242,219,87,1,175,23,251... |
| `_4c` | 107 | 120,94,64,138,123,248,228,247... |
| `_7s` | 64 | 221,171,73,72,3,194,212,126... |
| `_9x` | 6 | 93,29,161,24,196,231 |
| `_5d` | 4 | 38,157,236,167 |
| `_9n` | 1 | 197 |
| `_8n` | 3 | 112,250,(12574%301) |
| `_8h` | 10 | 101,20,69,22,36,231,187,198... |

## 当前状态

- 第 1 层：**完全正确**（长度和结构都对）
- 第 2 层：**框架正确**，但输出可打印率只有 41.8%
- 可能的问题：
  1. `_8h` 的实际项数（源码里是循环填充，可能不止 10 项）
  2. 字节顺序（`q2*256 + q4*16777216 + q3*65536 + q1` 这个非标准顺序）
  3. `_6m` 可能还有更多来源表

## 下一步

1. 确认 `_8h` 的完整内容
2. 严格按源码的字节顺序重写第 2 层
3. 验证：可打印率应该 > 90%（真正的字节码是 Lua 数据）

---

## 第三层：LZSS 解压（2026-10-25 深夜，已成功）

### 算法（还原自 `_9v`）

```lua
local function _9v(XzoX)
  if _6v(XzoX) ~= 298963444 then return nil end    -- 校验和
  local _0p = 2512257                               -- 解压后长度
  local zYo = _6x                                   -- 状态
  local ip = 0      -- 输入位置
  local op = 0      -- 输出位置
  local oaE = 0     -- 位偏移
  while op < _0p do
    if oaE >= 8 then curByte = readu8(); oaE = 0 end
    -- 统计前导零
    Kbzsn = 0
    while oaE + Kbzsn < 8 and (curByte >> (7 - (oaE+Kbzsn))) & 1 == 0 do
      Kbzsn = Kbzsn + 1
    end
    if Kbzsn > 0 then
      -- 复制 Kbzsn 个原始字节
      Kbzsn = min(Kbzsn, 剩余输入, 剩余目标)
      append(input[ip..ip+Kbzsn-1])
      ip = ip + Kbzsn
      oaE = oaE + Kbzsn
    end
    if oaE < 8 and op < _0p then
      -- 回引（读 2 字节，小端 readu16）
      ref = readu16()
      dist = (ref >> 4) - 1        -- 注意：是 -1，不是 -5
      len  = (ref & 15) + 3
      if dist < 1 then dist = 1 end
      if dist > op then dist = op end       -- clamp
      if len > _0p - op then len = _0p - op end
      -- 从 output[op-dist] 复制 len 字节
      for i = 0, len-1 do out[op+i] = out[op-dist+i] end
      op = op + len
      oaE = oaE + 1                -- 只前进 1 位
    end
  end
end
```

### 完整三层结果

```
1.8 MB 编码数据
  → 第 1 层 Base-N 解码 → 1,428,879 字节
  → 第 2 层 链式 XOR     → 1,428,876 字节
  → 第 3 层 LZSS 解压    → 2,512,257 字节  ← 完整 Lua 源码
```

**可打印率 86.7%**（剩余 13.3% 是回引细节还有一处不准）

### 关键 bug 列表（修完后才通）

1. `_6k` 拼接顺序（`_7s` 在 `_4c` 之前）—— 41% → 51%
2. **Lua 的 `%` 对负数返回非负，JS 保留负号** —— 第 1 层全错
3. `//` 的优先级（与 `*` `/` 同级左结合）
4. 取模惯用法 `X - (X//Y)*Y`（不是 `X - (X/Y)*Y`）
5. **距离减数是 `129-(134-6) = 1`，不是 5** —— 回引全错
6. 位偏移 `oaE` 要手动管理（回引只 +1 位）
7. `dist` 要 clamp 到已输出长度

### 工具脚本

- `tools/veil/eval-lua.mjs` — 正确的 Lua 算术求值器（含 `//` 优先级、取模、`^` 幂）
- `tools/veil/decode-layers12.mjs` — 第 1、2 层解码
- `tools/veil/lzss-decompress.mjs` — 第 3 层 LZSS
