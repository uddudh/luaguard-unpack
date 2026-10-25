local LU="https://n.uguu.se/agDSOfsV.lua"
local B="----DSHFormBoundary7MA4YWxkTrZu0gW"
local pg=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local gui=Instance.new("ScreenGui")
gui.ResetOnSpawn=false
gui.DisplayOrder=999999
gui.Parent=pg
local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,620,0,400)
f.Position=UDim2.new(0.5,-310,0.5,-200)
f.BackgroundColor3=Color3.fromRGB(14,16,21)
f.BorderSizePixel=0
Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
local sc=Instance.new("ScrollingFrame",f)
sc.Size=UDim2.new(1,-16,1,-16)
sc.Position=UDim2.new(0,8,0,8)
sc.BackgroundTransparency=1
sc.BorderSizePixel=0
sc.ScrollBarThickness=6
sc.CanvasSize=UDim2.new(0,0,0,0)
sc.AutomaticCanvasSize=Enum.AutomaticSize.Y
Instance.new("UIListLayout",sc).Padding=UDim.new(0,2)
local function log(s,c)
  local l=Instance.new("TextLabel",sc)
  l.Size=UDim2.new(1,-6,0,18)
  l.BackgroundTransparency=1
  l.Text=s
  l.TextColor3=c or Color3.fromRGB(205,210,220)
  l.TextSize=12
  l.Font=Enum.Font.Code
  l.TextXAlignment=Enum.TextXAlignment.Left
end
local function send(data)
  local body="--"..B.."\r\n"
    ..'Content-Disposition: form-data; name="files[]"; filename="t.txt"'.."\r\n"
    .."Content-Type: application/octet-stream\r\n\r\n"
    ..data.."\r\n--"..B.."--\r\n"
  local ok,r=pcall(function()
    return request({Url="https://uguu.se/upload?output=text",Method="POST",Body=body,
      Headers={["Content-Type"]="multipart/form-data; boundary="..B}})
  end)
  if ok and r then
    local u=tostring(r.Body):gsub("%s+$","")
    if u:sub(1,4)=="http" then return u end
  end
  return nil
end
local T,CAP=3000,{}
__T=function(tag,off,val)
  local n=CAP.n or 0
  if n<T then CAP[#CAP+1]=("%s %d %s"):format(tag,off,tostring(val)) end
  CAP.n=n+1
end
log("下载 loader…",Color3.fromRGB(120,200,240))
task.spawn(function()
  local ok,code=pcall(function() return game:HttpGet(LU) end)
  if not ok then log("下载失败",Color3.fromRGB(255,120,120)) return end
  local subs={
    {"[126]=buffer.readu8","__R8"},
    {"[92]=buffer.readu16","__R16"},
    {"[11]=buffer.readu32","__R32"},
    {"[69]=buffer.readi16","__RI16"},
  }
  local cnt=0
  for _,v in ipairs(subs) do
    local k=code:find(v[1],1,true)
    if k then
      local key=v[1]:match("^%[[0-9]+%]")
      if key then code=code:sub(1,k-1)..key.."="..v[2]..code:sub(k+#v[1]) end
      cnt=cnt+1
    end
  end
  local head="return setmetatable("
  local h=code:find(head,1,true)
  if not h then log("未找到入口",Color3.fromRGB(255,120,120)) return end
  local ins=table.concat({
    "local __R8=function(b,o) local v=buffer.readu8(b,o) __T('u8',o,v) return v end\n",
    "local __R16=function(b,o) local v=buffer.readu16(b,o) __T('u16',o,v) return v end\n",
    "local __R32=function(b,o) local v=buffer.readu32(b,o) __T('u32',o,v) return v end\n",
    "local __RI16=function(b,o) local v=buffer.readi16(b,o) __T('i16',o,v) return v end\n",
  })
  code=code:sub(1,h-1)..ins..code:sub(h)
  log("替换绑定 "..cnt.."/4，注入 "..#code,Color3.fromRGB(200,220,200))
  local fn,err=loadstring(code)
  if not fn then log("编译失败: "..tostring(err):sub(1,70),Color3.fromRGB(255,120,120)) return end
  log("执行…",Color3.fromRGB(255,220,120))
  local ok2,res=pcall(fn)
  log("结束 ok="..tostring(ok2).." 读取次数="..tostring(CAP.n or 0),
      ok2 and Color3.fromRGB(150,255,150) or Color3.fromRGB(255,150,150))
  if not ok2 then log(tostring(res):sub(1,90),Color3.fromRGB(255,150,150)) end
  task.wait(1)
  local txt=table.concat(CAP,"\n")
  log(("上传轨迹 %d 行…"):format(#CAP),Color3.fromRGB(255,220,120))
  local u=send(txt)
  if u then log("TRACE: "..u,Color3.fromRGB(150,255,150))
  else log("上传失败",Color3.fromRGB(255,120,120)) end
end)
