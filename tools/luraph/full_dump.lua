local U={"https://paste.rs/6EBBH","https://paste.rs/vMdfC","https://paste.rs/mvAbJ","https://paste.rs/3LvjP","https://paste.rs/RxVut"}
local pg=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local gui=Instance.new("ScreenGui")
gui.ResetOnSpawn=false
gui.DisplayOrder=999999
gui.Parent=pg
local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,640,0,300)
f.Position=UDim2.new(0.5,-320,0.5,-150)
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
  for _=1,3 do
    local ok,r=pcall(function()
      return request({Url="https://paste.rs",Method="POST",Body=data,
        Headers={["Content-Type"]="application/octet-stream"}})
    end)
    if ok and r then
      local u=tostring(r.Body):gsub("%s+$","")
      if u:sub(1,4)=="http" then return u end
    end
    task.wait(1)
  end
  return nil
end
__FULL=function(s)
  task.spawn(function()
    local N=45000
    local n=math.ceil(#s/N)
    log(("完整 buffer %d 字节 / %d 块"):format(#s,n),Color3.fromRGB(255,220,120))
    for i=1,n do
      local u=send(s:sub((i-1)*N+1,i*N))
      if u then log(("  块%d/%d %s"):format(i,n,u),Color3.fromRGB(150,255,150))
      else log(("  块%d 失败"):format(i),Color3.fromRGB(255,120,120)) end
      task.wait(0.5)
    end
    log("全部完成",Color3.fromRGB(150,255,150))
  end)
end
local DUMPED=false
log("下载 loader…",Color3.fromRGB(120,200,240))
task.spawn(function()
  local parts={}
  for i,u in ipairs(U) do
    local ok,r=pcall(function() return game:HttpGet(u) end)
    if not ok then log("块"..i.."失败",Color3.fromRGB(255,120,120)) return end
    parts[i]=r
  end
  local code=table.concat(parts)
  log("loader "..#code,Color3.fromRGB(200,220,200))
  local pat="else j[30](d,Z,(j[48](j[11](r,K+Z),x,j.nW[P])))"
  local k=code:find(pat,1,true)
  if not k then log("未找到解密点",Color3.fromRGB(255,120,120)) return end
  local ins="else if not DUMPED then DUMPED=true;local __ok,__s=pcall(buffer.readstring,r,0,buffer.len(r));if __ok then __FULL(__s) end end;j[30](d,Z,(j[48](j[11](r,K+Z),x,j.nW[P])))"
  code=code:sub(1,k-1)..ins..code:sub(k+#pat)
  local fn,err=loadstring(code)
  if not fn then log("编译失败: "..tostring(err):sub(1,70),Color3.fromRGB(255,120,120)) return end
  log("执行（首次解密时 dump 整个 buffer）…",Color3.fromRGB(255,220,120))
  local ok2,res=pcall(fn)
  log("结束 ok="..tostring(ok2),
      ok2 and Color3.fromRGB(150,255,150) or Color3.fromRGB(255,150,150))
  if not ok2 then log(tostring(res):sub(1,80),Color3.fromRGB(255,150,150)) end
end)
