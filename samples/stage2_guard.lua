local credential=...
local type,pcall,error,tostring,tonumber=type,pcall,error,tostring,tonumber
local rawset,getfenv=rawset,getfenv
local globals,host=_G,game
local byte,gsub,find=string.byte,string.gsub,string.find
local wait=type(task)=="table"and task.wait
local clock=os.clock
local compile=loadstring
local function member(value,key)
local ok,result=pcall(function()return value[key]end)
if ok then return result end
end
local keyless=false
if keyless then
credential=""
elseif type(credential)~="string"then
for lv=2,4 do
local f,sc=pcall(getfenv,lv)
local v=f and type(sc)=="table"and member(sc,"script_key")
if type(v)=="string"then credential=v;pcall(rawset,sc,"script_key",nil);break end
end
end
local spawn=member(task,"spawn")
local fetch=member(host,"HttpGet")
local ok,senv=pcall(function()return getfenv()end)
if not ok or type(senv)~="table"then senv=globals end
local ok,environment=pcall(function()return getgenv()end)
if not ok or type(environment)~="table"then environment=senv end
local function global(key)return member(environment,key)or member(senv,key)or member(globals,key)end
local sample=20
local platform="?"
pcall(function()
local input=host:GetService("UserInputService")
platform=input.TouchEnabled and not input.KeyboardEnabled and"m"or"d"
end)
local function ms(x)return math.floor(x*1000+.5)end
local reqs,seen={},{}
local function add(fn,name)
if type(fn)=="function"and not seen[fn]then seen[fn]=true;reqs[#reqs+1]={fn,name}end
end
add(global("request"),"request")
add(global("http_request"),"http_request")
add(global("httpRequest"),"httpRequest")
add(global("httprequest"),"httprequest")
add(member(global("http"),"request"),"http.request")
add(member(global("syn"),"request"),"syn.request")
local bt=member(global("buffer"),"tostring")
local url="\104\116\116\112\115\58\47\47\102\108\111\119\97\117\116\104\46\110\101\116\47\97\115\115\101\116\115\47\102\108\111\119\97\117\116\104\47\115\104\97\50\53\54\47\100\99\54\53\97\102\55\56\54\57\56\50\56\55\98\99\50\49\53\49\98\97\102\100\98\100\54\55\49\53\52\48\54\100\53\51\53\102\102\53\100\52\98\102\51\54\53\55\50\50\100\56\102\54\54\102\102\48\97\102\51\101\55\98\47\118\52\95\98\111\111\116\115\116\114\97\112\112\101\114\95\109\97\114\98\101\103\46\108\117\97"
local fallback="\104\116\116\112\115\58\47\47\51\55\46\49\56\55\46\49\51\54\46\49\56\55\47\97\115\115\101\116\115\47\102\108\111\119\97\117\116\104\47\115\104\97\50\53\54\47\100\99\54\53\97\102\55\56\54\57\56\50\56\55\98\99\50\49\53\49\98\97\102\100\98\100\54\55\49\53\52\48\54\100\53\51\53\102\102\53\100\52\98\102\51\54\53\55\50\50\100\56\102\54\54\102\102\48\97\102\51\101\55\98\47\118\52\95\98\111\111\116\115\116\114\97\112\112\101\114\95\109\97\114\98\101\103\46\108\117\97"
local fresh=url.."?retry=5121624c37823a1c"
local retry=gsub(url,"/sha256/[a-f0-9]+/","/").."?retry=5121624c37823a1c"
local expected=632423
local runtime,reason,issue,pr=nil,nil,"timed out",0
local transport,issueTransport="HttpGet","HttpGet"
local function problem(message,rank)
if rank>=pr then issue,pr,issueTransport=message,rank,transport end
end
local arrived,ck,cm=0,0,0
local function accept(value)
local began=clock()
if type(value)=="buffer"then local ok,text=pcall(bt,value);value=ok and text or nil end
if type(value)~="string"then problem("unsupported response body",1);return end
if #value~=expected then
if #value<1024 and find(value,"Failed to send HTTP request.",1,true)then
problem(find(value,"timed out",1,true)and"HTTP request timed out"or"HTTP request failed",2)
else problem("received "..#value.." bytes; expected "..expected,2)end
return
end
local s1,s2,i=1.0,0.0,1
while i+7<=#value do
local a,b,c,d,e,f,g,h=byte(value,i,i+7)
s2=(s2+8*s1+8*a+7*b+6*c+5*d+4*e+3*f+2*g+h)%65521
s1=(s1+a+b+c+d+e+f+g+h)%65521;i=i+8
end
while i<=#value do s1=(s1+byte(value,i))%65521;s2=(s2+s1)%65521;i=i+1 end
if s2*65536.0+s1~=3646516830 then problem("runtime checksum mismatch",3);return end
local t=clock();ck=t-began
local ok,compiled,detail=pcall(compile,value,"=FlowAuthRuntime")
local text=not(ok and type(compiled)=="function")and tostring(ok and detail or compiled)
if text and not(find(text,"FlowAuthRuntime:")or find(text,"xpected")or find(text,"syntax"))then
if wait then pcall(wait,1.5)end
ok,compiled,detail=pcall(compile,value,"=FlowAuthRuntime")
end
cm=clock()-t
if ok and type(compiled)=="function"then runtime=compiled;return true end
reason=(ok and detail or compiled)or"compiler returned no function";issueTransport=transport
return false
end
local cs={{fetch,"HttpGet",url}}
if fallback~=""then cs[#cs+1]={fetch,"HttpGet",fallback,true}end
for i=1,#reqs do
local candidate=reqs[i]
if fallback~=""then cs[#cs+1]={candidate[1],candidate[2],fallback,true}end
cs[#cs+1]={candidate[1],candidate[2],fresh}
end
cs[#cs+1]={fetch,"HttpGet",retry}
local started,ni,ls,idle=clock(),1,0,0
local js,shut,alternate={},false,false
local asynchronous=type(spawn)=="function"and type(wait)=="function"
local function launch()
local candidate=cs[ni];ni=ni+1;ls=clock()
local job={name=candidate[2],alternate=candidate[4]};js[#js+1]=job
local function run()
if shut or job.started then return end
job.started=true
local ok,response
if job.name=="HttpGet"then ok,response=pcall(candidate[1],host,candidate[3])
else ok,response=pcall(candidate[1],{Url=candidate[3],Method="GET"})end
if not shut then job.ok,job.response,job.done=ok,response,true end
end
if asynchronous then
local ok,thread=pcall(spawn,run);job.thread=ok and thread or nil
if not job.started and type(job.thread)~="thread"then asynchronous=false;run()end
else run()end
end
launch()
for poll=1,4000 do
local active,completed=0,false
for i=1,#js do
local job=js[i]
if not job.done then active=active+1
elseif not job.read then
job.read=true;completed=true;transport=job.name;arrived=clock()-started
local response=job.response;job.response=nil
if not job.ok then problem("request failed",1)
elseif type(response)=="table"then
local status=tonumber(member(response,"StatusCode")or member(response,"status_code")or member(response,"Status")or member(response,"status"))or 0
local success=member(response,"Success");if success==nil then success=member(response,"success")end
if status==0 and success==true then status=200 end
if success==false and status<400 then status=500 end
if status>=200 and status<300 then accept(member(response,"Body")or member(response,"body")or member(response,"ResponseBody")or member(response,"response_body"))
else problem("HTTP "..status,2)end
else accept(response)end
if runtime or reason then alternate=job.alternate;break end
end
end
if runtime or reason or(active==0 and ni>#cs)then break end
local t=clock()
if t-started-idle>=40 then problem("HTTP download timed out after 40 seconds",4);break end
if ni<=#cs and(active==0 or(active<2 and(completed or t-ls>=8)))then launch()
elseif not pcall(wait,.03)then problem("HTTP download wait unavailable",4);break
else idle=idle+math.max(clock()-t-1,0)end
end
shut=true
for i=1,#js do js[i].response=nil end
local function send(base,path,body,delay)
local query="?p="..gsub('{"protocol":3,"loader_hash":"\97\48\51\57\54\97\102\48\98\97\52\48\101\55\53\51\52\51\55\102\99\48\52\56\55\54\98\50\51\56\49\99","\108\97\117\110\99\104\95\116\105\99\107\101\116":"\118\50\58\110\67\55\75\88\70\109\76\83\120\108\105\120\83\54\66\58\81\118\118\118\97\50\105\69\102\120\83\111\99\45\76\72\103\87\84\74\79\119\58\110\101\80\114\67\53\45\71\54\75\112\103\108\69\82\70\72\113\81\102\113\82\45\48\101\101\105\85\99\68\85\72\67\112\95\70\86\79\97\85\83\108\86\105\74\113\48\81\87\52\57\95\76\116\71\78\114\97\95\85\73\89\45\55\87\78\82\74\120\73\95\100\87\119\68\89\79\69\103\82\78\82\114\114\66\116\78\49\114\57\84\55\116\57\107\73\104\112\80\88\80\56\97\66\81\108\112\103\72\82\116\89\90\114\77\78\102\70\89\113\73\74\110\101\102\111\51\48\70\70\77\72\88\100\55\57\50\120\114\53\118\113\121\85\82\90\86\88\115\105\66\99\100\90\118\85\106\88\52\115\108\97\70\112\51\71\105\105\53\111\117\75\119\65\57\112\70\103\104\69\68\66\97\72\119\69\99\122\102\97\74\80\87\121\95\99\54\83\51\85","stage":"'..body,"[^%w]",function(c)return string.format("%%%02X",byte(c))end)
pcall(spawn,function()
if delay then pcall(wait,delay)end
local target=gsub(base,"/assets/.*",path)..query
if not pcall(fetch,host,target)and reqs[1]then pcall(reqs[1][1],{Url=target,Method="GET"})end
end)
end
if not runtime then
pcall(function()
local text=gsub(issueTransport..": "..tostring(reason or issue),"[^%w .:;,()=/_-]","?")
local body=(reason and"launcher_load"or"launcher_download")..'","executor":"launcher","diag":["pf='..platform..'"],"error":"'..string.sub(text,1,160)..'"}'
for _,base in ipairs{url,fallback}do
if base~=""then send(base,"/v1/telemetry/executor",body)end
end
end)
if reason then error("FlowAuth runtime compilation failed: "..tostring(reason),0)end
error("FlowAuth runtime download failed ("..issueTransport.."): "..tostring(issue)..". Please run the loader again.",0)
end
if sample>0 and spawn and math.random(sample)==1 then
pcall(send,alternate and fallback or url,"/v1/telemetry/load",'load","pf":"'..platform..'","tp":"'..transport..'","fb":'..(alternate and 1 or 0)..',"tr":'..#js..',"dl":'..ms(arrived)..',"ck":'..ms(ck)..',"cm":'..ms(cm)..',"w":'..sample..'}',2)
end
if asynchronous then pcall(wait)end
local handoff=alternate and {"\115\117\121\121\226\196\150\8\157\86\66\232\0\94\170\67\114\142\82\118\161\172\115\145\43\224\61\85\158\122\225\168\202\102\4\84\104\32\211\235\77\234\83\66\38\82\70\164\244\238\135\100\61\128\49\125\35\230\224\170\33\220\43\112\210\223\161\29\138\43\28\95\245\59\11\229\201\78\84\207\222\254\210\237\51\10\235\159\253\223\44\121\238\236\163\245\221\126\42\114\245\53\250\131\245\230\28\18\82\109\243\83\93\111\55\156\138\2\160\37\220\225\75\241\33\209\39\190\105\71\45\111\224\52\184\132\100\81\97\103\174\36\22\175\120\177\140\159\68\84\39\255\101\110\97\23\28\51\210\15\224\92\173\110\16\19\58\188\14\119\3\157\112\97\150\17\121\112\221\229\65\69\71\138\244\20\149\130\178\236\11\215\115\239\14\193\92\84\52\180\64\153\99\154\41\150\182\33\193\52\53\49\199\112\250\29\77\189\83\115\128\140\199\178\198\187\106\15\202\173\69\3\188\20\18\103\181\137\128\193\104\87\90\69\55\135\95\133\83\53\42\118\138\125\226\140\113\182\178\244\42\236\99\189\86\34\222\247\221\19\173\49\119\255\123\254\86\170\29\137\5\128\50\91\230\169\204\225\12\180\47\195\158\90\72\126\42\96\138\186\33\219\212\116\68\241\249",1947936303,1126064727} or {"\56\203\8\92\118\223\51\50\59\229\207\72\20\176\245\104\240\221\89\229\67\98\223\171\17\174\119\190\126\229\114\65\4\222\139\14\41\29\138\234\225\52\85\156\197\11\161\204\188\94\14\166\146\90\92\99\157\246\163\83\141\221\153\177\134\80\26\176\219\191\187\118\101\109\118\159\33\147\249\152\154\228\53\70\46\36\168\220\198\219\143\254\71\47\88\43\183\130\255\158\49\99\238\142\229\219\93\192\47\87\27\0\34\174\234\83\220\37\233\16\20\161\26\218\129\203\238\35\52\250\112\63\130\82\126\132\155\107\209\133\128\157\19\94\253\119\212\47\97\4\131\129\149\141\66\181\195\209\177\121\152\127\141\186\58\164\137\91\254\179\86\36\61\228\65\15\153\7\157\119\213\81\162\148\153\116\255\46\232\244\103\56\144\16\114\213\254\16\175\31\43\192\66\133\58\51\28\129\2\121\28\231\118\75\173\45\79\137\37\165\211\172\134\240\247\199\253\223\122\65\74\127\195\25\176\157\77\240\248\217\140\32\30\48\93\192\68\225\176\55\153\236\14\75\58\224\5\196\88\127\171\197\41\73\209\130\197\179\211\53\42\140\135\147\196\89\60\59\177\159\112\197\95\5\41\57\29\29\35\73\25\71\56\231\29\217\168\74\195\153\121\199\175\215\110",2627335265,839083110}
local function publish(target)
if type(target)=="table"then pcall(rawset,target,"_bsdata0",handoff)end
end
publish(environment)
publish(globals)
_bsdata0=handoff
pcall(function()publish(getfenv(runtime))end)
handoff=nil
return runtime(credential)
