# 运行时源码捕获（通用解包法）

> 2026-10-25 验证成功。对任意保护方案的脚本都成立，因为它不猜加密方式，
> 而是**等脚本自己解密完、把明文交给引擎的那一刻抓下来**。

## 为什么这个方法比"反混淆"强

传统的反混淆要完整理解 VM/序列化格式，任何一处语义偏差都会跑偏
（本项目在 Luraph 上就卡在 `table.create` 收到负尺寸这种细节）。

运行时捕获绕过整个问题：

1. 让受保护的脚本在真实 Roblox 里正常执行
2. 挂钩 `loadstring` / `load`
3. 它解密后必须调用其中之一来执行源码 → 明文在此被截获
4. 分块上传，拿回本地

## 捕获点

```lua
local ol = loadstring
loadstring = function(s, n)
    if type(s) == "string" then record(s, n) end
    return ol(s, n)
end
```

同时要挂钩：

- 全局 `loadstring`
- 全局 `load`（Roblox 里 `load` 等同 `loadstring`）
- `getgenv().loadstring`（部分执行器单独暴露）

## 传输（关键：`writefile` 常常不可用）

实测环境（Delta 类执行器）：

| 能力 | 结果 |
|---|---|
| `loadstring` | 可用 |
| `game:HttpGet` / `request` / `http_request` | 可用 |
| `writefile` / `readfile` / `delfile` | **不可用** |
| `getgenv` / `gethui` | 可用 |

所以用 HTTP 回传：`POST https://paste.rs`，正文即分块内容，
响应体就是 URL。单次上限约 80 KB（96 KB 会 500），按 60 KB 切块。

```lua
local N = 60000
for i = 1, math.ceil(#src / N) do
    local part = src:sub((i - 1) * N + 1, i * N)
    local r = request({ Url = "https://paste.rs", Method = "POST", Body = part,
        Headers = { ["Content-Type"] = "text/plain" } })
    -- r.Body 是 https://paste.rs/xxxxx
end
```

⚠️ paste.rs 会**吃掉每块末尾的空白**。分块时若块尾是换行，回读会少几个字节。
本次实测：字节数与捕获长度完全一致（273441），因为损失的是纯空白且恰好不在关键位置。
要绝对保真，可在每块末尾追加一个哨兵字符（如 `\n@@EOF@@`）再在本地剥掉。

## 实战结果

目标：`moondiety.com/loader`（Luraph v15.1 保护，混淆体积 312,087 字节）

```
第 1 层：Luraph 混淆的引导脚本（312,087 字节）
        └─ 运行时 loadstring → 第 2 层明文 273,441 字节（6,553 行 / 360 个函数）
```

第 2 层是完整可读的 Moondiety UI 库源码（`return Library`），
含真实变量名与缩进，即作者原始代码。

注意：本次所处游戏**不被 Moondiety 支持**，只加载了 UI 库。
进入受支持的游戏时会出现第 3 次 `loadstring`（真正的功能脚本），
同一工具可直接捕获——捕获器记录**所有**调用，而不是只取最大的一个。

## 副作用与注意

- 替换 `loadstring` 会改变函数身份。实测本目标不受影响（脚本照常运行并弹出 UI）。
- **不要**替换 `buffer.create` / `table.create` 这类原生函数：
  实测会让同一份原始脚本走向错误路径（`invalid argument #1 to 'create' (size out of range)`），
  说明 Luraph 存在对原生函数身份的检查。**纯插入**探针（在调用点前插日志）是安全的。
- 捕获器会记录小片段（如几十字节的拼接代码）。工具里按 200 字节下限过滤。

## 相关脚本

- `tools/runtime-capture/runtime_capture.lua` —— 带 UI 的捕获器（列表 + 上传按钮）
