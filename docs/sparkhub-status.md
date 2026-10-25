# SparkHub_Loader.lua 逆向进展（2026-10-25）

## 文件
- 来源：https://raw.githubusercontent.com/ultimatep568/Spark-Hub/refs/heads/main/SparkHub_Loader.lua
- 大小：177,658 字节，2 行
- 本地：`spark/loader.lua`
- **不是 Lua-Guard**，是另一套 VM 混淆（疑似 IronBrew2 系）

## 已确认的结构

```
return(function(...)
  local K = { ...1131 个字符串... }      -- 字符串池
  -- 洗牌：三次数组反转
  for P,x in ipairs({{1,1057},{1,529},{530,1057}}) do
    while x[1] < x[2] do
      K[x[1]],K[x[2]],x[1],x[2] = K[x[2]],K[x[1]],x[1]+1,x[2]-1
    end
  end
  local function P(P) return K[P - 28546] end   -- 索引函数
  do
    local P = table.concat
    local x = type
    local k = string.char
    local t = { ...64 个字符→数字映射... }    -- base64 变体字符表
    ...
  end
  ...
  return (W(10913423, {}))(k(m))              -- VM 构造并调用
end)({...}, unpack or table[...], getfenv() or _ENV, select, getmetatable, setmetatable, newproxy)
```

## 字符串解码器（已还原）

主循环里：
```lua
while e <= x do
  local K = I(q, e, e)          -- 读一个字符
  local P = t[K]                -- 字符 → 0..63
  if P then
    G = G + P * (64 ^ (3 - w))  -- base64 累加
    w = w + 1
    if w == 4 then
      w = 0
      C(X, k(floor(G/65536), floor((G%65536)/256), G%256))   -- 4 字符 → 3 字节
      G = 0
    end
  elseif K == "=" then
    C(X, k(floor(G/65536)))     -- padding → 末字节
    ...
  end
end
```
常量：base=64，每 4 字符一个 24 位数。

## VM 核心

- `x` 是 VM 执行器，签名：`function(m,k,K,B,D,I,t,b,L,G,z,V,r,q,O,X,C,w,R,j,Y,x,W,a,e)`（25 参数）
- 所有函数都是 `local k=G(P); local t=function(...) return x(K,{...},P,k) end`
- `m=math.floor`、`C=table.insert`（在 do 块内）

## 卡点（当前）

1. **字符串表解码出乱码**：虽然 t 表解析出 64 项、算法也还原了，但 K 元素解码后不是可读文本。
   怀疑：t 表的数值求值有误，或 K 元素本身不是直接 base64（需另一种预处理）。
2. **动态运行**：用 Lua 5.4 + 打桩可以跑到 VM 内部（string.char 被调 2773 次，
   抓到 9666 字节，其中混有 `workspace`、`getexecutorname`、`gmatch`、`tostring` 等 API 名），
   但 VM 主函数的参数链是动态构造的，逐个报 nil（k → w → Q ...）。

## 下一步建议

1. 先修 t 表的求值（用 Lua 本身求值，而不是 JS 手写表达式解析）
2. 或者放弃静态解字符串表，改为**完整跑 VM**（需要精确的闭包环境）
3. VM 的 opcode 表 `t`（另一个 t）和字节码 `q` 还没定位

## 对比 Lua-Guard

| | Lua-Guard | 这个 |
|---|---|---|
| 字符串 | AES，能完整还原 | base64 变体 + 洗牌，待解 |
| VM | 静态数组（op/a/b/c） | 动态构造，参数链层层传递 |
| 难度 | 已攻克 | 明显更高，需要更多时间 |
