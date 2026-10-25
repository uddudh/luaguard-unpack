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
