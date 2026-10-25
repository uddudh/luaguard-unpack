-- 通用运行时源码捕获器（任意混淆器适用）
-- 原理：不等解密，直接挂钩 loadstring/load，抓它解密后交给引擎的源码
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")

local caps = {}
local seen = {}
local ol = loadstring
local oL = load
local function add(src, name)
    if type(src) ~= "string" or #src < 200 then return end
    local k = #src .. "|" .. src:sub(1, 80)
    if seen[k] then return end
    seen[k] = true
    caps[#caps+1] = { src = src, name = tostring(name) }
end
loadstring = function(s, n) add(s, n) return ol(s, n) end
if type(oL) == "function" and oL ~= ol then
    load = function(s, n) add(s, n) return oL(s, n) end
end
local gv = getgenv and getgenv() or nil
if gv and gv.loadstring and gv.loadstring ~= loadstring then
    local gl = gv.loadstring
    gv.loadstring = function(s, n) add(s, n) return gl(s, n) end
end

local gui = Instance.new("ScreenGui")
gui.Name = "SrcCapture"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999999
gui.Parent = pg
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 640, 0, 480)
frame.Position = UDim2.new(0.5, -320, 0.5, -240)
frame.BackgroundColor3 = Color3.fromRGB(14, 16, 21)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 32)
title.Position = UDim2.new(0, 10, 0, 6)
title.BackgroundTransparency = 1
title.Text = "源码捕获器 · 等待 loadstring"
title.TextColor3 = Color3.fromRGB(120, 220, 160)
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -130)
scroll.Position = UDim2.new(0, 10, 0, 44)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame
local lay = Instance.new("UIListLayout")
lay.Padding = UDim.new(0, 3)
lay.Parent = scroll

local function log(s, c)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -8, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = s
    l.TextColor3 = c or Color3.fromRGB(205, 210, 220)
    l.TextSize = 13
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextWrapped = false
    l.Parent = scroll
end

local function btn(text, x, w, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, w, 0, 34)
    b.Position = UDim2.new(0, x, 1, -42)
    b.BackgroundColor3 = Color3.fromRGB(52, 58, 68)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(232, 232, 236)
    b.TextSize = 14
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(cb)
    return b
end

local N = 60000
local function upload(str)
    local urls = {}
    local n = math.ceil(#str / N)
    for i = 1, n do
        local part = str:sub((i - 1) * N + 1, i * N)
        local ok, r = pcall(function()
            return request({ Url = "https://paste.rs", Method = "POST", Body = part,
                Headers = { ["Content-Type"] = "text/plain" } })
        end)
        if ok and r and tostring(r.StatusCode) == "201" then
            urls[#urls+1] = (tostring(r.Body):gsub("%s+$", ""))
        else
            urls[#urls+1] = "FAIL"
        end
        task.wait(0.15)
    end
    return urls, n
end

btn("上传全部捕获", 10, 130, function()
    if #caps == 0 then log("还没有捕获", Color3.fromRGB(240, 160, 60)) return end
    task.spawn(function()
        for i, c in ipairs(caps) do
            if c.done then
                log(("[%d] 已传过 %d 字节"):format(i, #c.src), Color3.fromRGB(140, 150, 160))
            else
                log(("[%d] 上传 %d 字节 %s"):format(i, #c.src, c.name), Color3.fromRGB(255, 220, 120))
                local urls, n = upload(c.src)
                c.done = true
                log(("    分 %d 块 → %s"):format(n, table.concat(urls, " ")), Color3.fromRGB(150, 255, 150))
            end
        end
        log("全部完成", Color3.fromRGB(150, 255, 150))
    end)
end)
btn("清空", 148, 60, function()
    for _, l in ipairs(scroll:GetChildren()) do
        if l:IsA("TextLabel") then l:Destroy() end
    end
end)
btn("关闭", 216, 60, function() pcall(function() gui:Destroy() end) end)

task.spawn(function()
    while gui.Parent do
        title.Text = ("源码捕获器 · 已捕获 %d 个"):format(#caps)
        task.wait(0.4)
    end
end)
for i, c in ipairs(caps) do
    log(("[%d] %d 字节 %s"):format(i, #c.src, c.name), Color3.fromRGB(150, 255, 150))
end
log("已挂钩 loadstring/load，运行任意保护脚本即可", Color3.fromRGB(120, 200, 240))
