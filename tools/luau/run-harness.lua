-- bit32 stub（Lua 5.4 原生位运算）
bit32 = {}
local M32 = 0xFFFFFFFF
local function norm(x) return x & M32 end
function bit32.band(...) local r = -1; for _,v in ipairs({...}) do r = r & norm(v) end; return norm(r) end
function bit32.bor(...) local r = 0; for _,v in ipairs({...}) do r = r | norm(v) end; return norm(r) end
function bit32.bxor(...) local r = 0; for _,v in ipairs({...}) do r = r ~ norm(v) end; return norm(r) end
function bit32.bnot(x) return norm(~norm(x)) end
function bit32.lshift(x,n) return norm(norm(x) << (n % 32)) end
function bit32.rshift(x,n) return norm(norm(x) >> (n % 32)) end
function bit32.arshift(x,n) local v = norm(x); if v >= 0x80000000 then v = v - 0x100000000 end; return norm(math.floor(v / (2 ^ (n % 32)))) end
function bit32.extract(x,f,w) w = w or 1; return (norm(x) >> (f % 32)) & ((1 << w) - 1) end
function bit32.replace(x,v,f,w) w = w or 1; local mask = ((1 << w) - 1) << (f % 32); return norm((norm(x) & ~mask) | ((norm(v) << (f % 32)) & mask)) end
function bit32.byteswap(x) local v = norm(x); return norm(((v & 0xFF) << 24) | ((v & 0xFF00) << 8) | ((v >> 8) & 0xFF00) | ((v >> 24) & 0xFF)) end
function bit32.lrotate(x,n) n = n % 32; local v = norm(x); return norm((v << n) | (v >> (32 - n))) end
function bit32.rrotate(x,n) n = n % 32; local v = norm(x); return norm((v >> n) | (v << (32 - n))) end
function bit32.countlz(x) local v = norm(x); if v == 0 then return 32 end; local n = 0; while (v & 0x80000000) == 0 do v = (v << 1) & M32; n = n + 1 end; return n end
function bit32.countrz(x) local v = norm(x); if v == 0 then return 32 end; local n = 0; while (v & 1) == 0 do v = v >> 1; n = n + 1 end; return n end

-- vector stub
vector = {}
function vector.create(x,y,z) return {X=x or 0, Y=y or 0, Z=z or 0} end
function vector.magnitude(v) return math.sqrt((v.X or 0)^2 + (v.Y or 0)^2 + (v.Z or 0)^2) end
function vector.normalize(v) local m = vector.magnitude(v); if m == 0 then return {X=0,Y=0,Z=0} end; return {X=(v.X or 0)/m, Y=(v.Y or 0)/m, Z=(v.Z or 0)/m} end
function vector.cross(a,b) return {X=(a.Y or 0)*(b.Z or 0)-(a.Z or 0)*(b.Y or 0), Y=(a.Z or 0)*(b.X or 0)-(a.X or 0)*(b.Z or 0), Z=(a.X or 0)*(b.Y or 0)-(a.Y or 0)*(b.X or 0)} end
function vector.dot(a,b) return (a.X or 0)*(b.X or 0)+(a.Y or 0)*(b.Y or 0)+(a.Z or 0)*(b.Z or 0) end
function vector.angle(a,b) local d = vector.dot(a,b); local ma, mb = vector.magnitude(a), vector.magnitude(b); if ma*mb == 0 then return 0 end; return math.acos(math.max(-1,math.min(1,d/(ma*mb)))) end
function vector.abs(v) return {X=math.abs(v.X or 0), Y=math.abs(v.Y or 0), Z=math.abs(v.Z or 0)} end
function vector.floor(v) return {X=math.floor(v.X or 0), Y=math.floor(v.Y or 0), Z=math.floor(v.Z or 0)} end
function vector.ceil(v) return {X=math.ceil(v.X or 0), Y=math.ceil(v.Y or 0), Z=math.ceil(v.Z or 0)} end
function vector.min(...) local r={X=math.huge,Y=math.huge,Z=math.huge}; for _,v in ipairs({...}) do r.X=math.min(r.X,v.X or 0); r.Y=math.min(r.Y,v.Y or 0); r.Z=math.min(r.Z,v.Z or 0) end; return r end
function vector.max(...) local r={X=-math.huge,Y=-math.huge,Z=-math.huge}; for _,v in ipairs({...}) do r.X=math.max(r.X,v.X or 0); r.Y=math.max(r.Y,v.Y or 0); r.Z=math.max(r.Z,v.Z or 0) end; return r end
vector.zero = {X=0,Y=0,Z=0}
vector.one = {X=1,Y=1,Z=1}

-- 其余 stub（复用之前的）
local function mkInst(name)
    local t = {Name=name, ClassName=name}
    return setmetatable(t, {
        __index = function(self,k)
            if k=="FindFirstChild" then return function() return nil end end
            if k=="WaitForChild" then return function() return nil end end
            if k=="GetChildren" then return function() return {} end end
            if k=="IsA" then return function() return false end end
            return mkInst(name.."."..tostring(k))
        end,
        __newindex = function() end,
    })
end
game = mkInst("Game")
game.GetService = function(self,n) return mkInst(n) end
game.IsLoaded = function() return true end
game.Loaded = {Wait=function() end}
game.HttpGet = function() error("blocked") end
workspace = mkInst("Workspace")
Instance = {new=function(c) return mkInst(c) end}
Enum = setmetatable({},{__index=function() return setmetatable({},{__index=function() return 0 end}) end})
UDim = {new=function() return {} end}
UDim2 = {new=function() return {} end}
Vector2 = {new=function() return {} end}
Vector3 = {new=function() return {} end}
Color3 = {new=function() return {} end}
ColorSequence = {new=function() return {} end}
ColorSequenceKeypoint = {new=function() return {} end}
NumberSequence = {new=function() return {} end}
NumberSequenceKeypoint = {new=function() return {} end}
TweenInfo = {new=function() return {} end}
typeof = function(x) return type(x) end
newproxy = function() return setmetatable({},{}) end
task = {wait=function() end, spawn=function() end, delay=function() end}

-- 批量 Roblox API stub
Rect = {new=function(a,b,c,d) return {Min={X=a,Y=b}, Max={X=c,Y=d}} end}
Region3 = {new=function() return {} end}
CFrame = {new=function(...) return {X=0,Y=0,Z=0} end, Angles=function() return {} end, fromAxisAngle=function() return {} end, lookAt=function() return {} end}
Ray = {new=function() return {} end}
NumberRange = {new=function(a,b) return {Min=a, Max=b or a} end}
Font = {new=function() return {} end, fromEnum=function() return {} end, fromId=function() return {} end}
PhysicalProperties = {new=function() return {} end}
FontFace = {new=function() return {} end}
DateTime = {now=function() return {UnixTimestamp=os.time()} end, fromUnixTimestamp=function(t) return {UnixTimestamp=t} end}
Random = {new=function() local o={} function o:NextNumber() return math.random() end function o:NextInteger(a,b) return math.random(a,b) end return o end}
BrickColor = {new=function() return {} end, Random=function() return {} end}
Axes = {new=function() return {} end}
Faces = {new=function() return {} end}
DockWidgetPluginGuiInfo = {new=function() return {} end}
OverlapParams = {new=function() return {} end}
RaycastParams = {new=function() return {} end}
PathfindingModifier = {new=function() return {} end}
SharedTable = {new=function() return {} end, clone=function() return {} end}
Content = {fromUri=function() return {} end, fromAssetId=function() return {} end}
CatalogSearchParams = {new=function() return {} end}
TweenInfo = TweenInfo or {new=function() return {} end}
callback = {}

local bufs = setmetatable({}, {__mode="k"})
buffer = {}
function buffer.create(n) local b = {}; bufs[b] = {data = {}, size = n}; return b end
function buffer.fromstring(s) local b = {}; bufs[b] = {data = s, size = #s}; return b end
function buffer.tostring(b) local d = bufs[b]; if not d then return "" end; if type(d.data)=="string" then return d.data end; local t={} for k=1,d.size do t[k]=string.char(d.data[k] or 0) end; return table.concat(t) end
function buffer.len(b) local d = bufs[b]; return d and d.size or 0 end
local function rb(b, off, n, signed)
    local d = bufs[b]; if not d then return 0 end
    local v = 0
    for k = 0, n-1 do
        local x = type(d.data)=="string" and string.byte(d.data, off+k+1) or (d.data[off+k+1] or 0)
        v = v + x * (2 ^ (8*k))
    end
    if signed and v >= 2^(8*n-1) then v = v - 2^(8*n) end
    return v
end
local function wb(b, off, v, n)
    local d = bufs[b]; if not d then return end
    if type(d.data)=="string" then d.data = {} end
    v = v % (2^(8*n))
    for k = 0, n-1 do d.data[off+k+1] = v % 256; v = math.floor(v / 256) end
end
function buffer.readu8(b,o) return rb(b,o,1,false) end
function buffer.readi8(b,o) return rb(b,o,1,true) end
function buffer.readu16(b,o) return rb(b,o,2,false) end
function buffer.readi16(b,o) return rb(b,o,2,true) end
function buffer.readu32(b,o) return rb(b,o,4,false) end
function buffer.readi32(b,o) return rb(b,o,4,true) end
function buffer.readf32(b,o) return 0 end
function buffer.readf64(b,o) return 0 end
function buffer.writeu8(b,o,v) wb(b,o,v,1) end
function buffer.writei8(b,o,v) wb(b,o,v,1) end
function buffer.writeu16(b,o,v) wb(b,o,v,2) end
function buffer.writei16(b,o,v) wb(b,o,v,2) end
function buffer.writeu32(b,o,v) wb(b,o,v,4) end
function buffer.writei32(b,o,v) wb(b,o,v,4) end
function buffer.writef32(b,o,v) end
function buffer.writef64(b,o,v) end
function buffer.copy(t,to,s,from,n) local td,sd=bufs[t],bufs[s]; if not td or not sd then return end; for k=0,n-1 do td.data[to+k+1] = type(sd.data)=="string" and string.byte(sd.data,from+k+1) or sd.data[from+k+1] end end
function buffer.fill(b,o,v,n) local d=bufs[b]; if not d then return end; for k=0,n-1 do d.data[o+k+1] = v % 256 end end
function buffer.readstring(b,o,n) local d=bufs[b]; if not d then return "" end; local t={} for k=0,n-1 do t[#t+1]=string.char(type(d.data)=="string" and string.byte(d.data,o+k+1) or (d.data[o+k+1] or 0)) end; return table.concat(t) end
function buffer.writestring(b,o,s) local d=bufs[b]; if not d then return end; if type(d.data)=="string" then d.data={} end; for k=1,#s do d.data[o+k]=string.byte(s,k) end end

local f = assert(io.open("luraph_final4.lua","rb"))
local src = f:read("*a"); f:close()
local chunk, err = load(src, "=luraph")
if not chunk then print("编译失败:", err); os.exit(1) end
print("编译成功，执行...")
local ok, res = pcall(chunk)
print("执行:", ok, type(res))
if not ok then print("错误:", tostring(res):sub(1,300)) end
