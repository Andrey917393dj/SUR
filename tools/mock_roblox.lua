-- Mock Roblox runtime for offline smoke-testing the script.
-- Not a Roblox emulator: it covers only the API surface this script touches.
-- UI callbacks and spawned work use a deterministic coroutine scheduler; time
-- advances only when the caller requests it. Budget exhaustion is a failure.
local REAL = _ENV
local M = {}
local unpack, pack = table.unpack, table.pack
local current
local MIN_WAIT = 1 / 60

local function capture(ctx, err)
    ctx.errors[#ctx.errors + 1] = tostring(err)
end
local function newContext()
    return {time = 0, serial = 0, tasks = {}, engineTimers = {}, connections = {}, errors = {}, warnings = {}, prints = {}, remotes = {}}
end
local function detachWait(rec)
    if rec.signal then rec.signal._waiters[rec.co] = nil; rec.signal = nil end
end
local resumeTask
local function taskRecord(ctx, co)
    local rec = ctx.tasks[co]
    if not rec then
        ctx.serial = ctx.serial + 1
        rec = {co = co, order = ctx.serial}
        ctx.tasks[co] = rec
    end
    return rec
end
local function cancelTask(ctx, co)
    local rec = ctx.tasks[co]
    if rec then detachWait(rec); ctx.tasks[co] = nil end
    if type(co) == "thread" and coroutine.status(co) == "suspended" and coroutine.close then
        local ok, err = coroutine.close(co)
        if not ok then capture(ctx, err) end
    end
end
resumeTask = function(ctx, rec, args)
    if ctx.tasks[rec.co] ~= rec then return true end
    detachWait(rec)
    rec.due, rec.args = nil, nil
    local exhausted = false
    debug.sethook(rec.co, function()
        if not exhausted then capture(ctx, "mock coroutine instruction budget exhausted"); exhausted = true end
        error("mock coroutine instruction budget exhausted", 0)
    end, "", 1000000)
    local result = pack(coroutine.resume(rec.co, unpack(args or {}, 1, (args and args.n) or 0)))
    debug.sethook(rec.co)
    if not result[1] then
        ctx.tasks[rec.co] = nil
        if not exhausted then capture(ctx, debug.traceback(rec.co, tostring(result[2]))) end
        return false
    end
    if exhausted then
        cancelTask(ctx, rec.co)
        return false
    end
    if coroutine.status(rec.co) == "dead" then ctx.tasks[rec.co] = nil; return true end
    local request = result[2]
    if type(request) == "table" and request.kind == "signal" then
        rec.signal = request.signal
        rec.signal._waiters[rec.co] = rec
        rec.due = request.timeout and (ctx.time + math.max(MIN_WAIT, request.timeout)) or nil
    else
        local seconds = type(request) == "table" and request.seconds or MIN_WAIT
        rec.started = ctx.time
        rec.due = ctx.time + math.max(MIN_WAIT, tonumber(seconds) or MIN_WAIT)
    end
    return true
end
local function spawnTask(ctx, fn, ...)
    assert(type(fn) == "function" or type(fn) == "thread", "task.spawn expects function or thread")
    local co = type(fn) == "thread" and fn or coroutine.create(fn)
    local rec = taskRecord(ctx, co)
    resumeTask(ctx, rec, pack(...))
    return co
end
local function scheduledTask(ctx, delay, fn, ...)
    assert(type(fn) == "function" or type(fn) == "thread", "task scheduling expects function or thread")
    local co = type(fn) == "thread" and fn or coroutine.create(fn)
    local rec = taskRecord(ctx, co)
    rec.due, rec.args = ctx.time + math.max(0, tonumber(delay) or 0), pack(...)
    return co
end
local function advanceContext(ctx, seconds, budget)
    local stop = ctx.time + math.max(0, tonumber(seconds) or 0)
    local resumes, clean = 0, true
    budget = math.max(0, tonumber(budget) or 10000)
    while true do
        local nextRec
        for _, rec in pairs(ctx.tasks) do
            if rec.due and rec.due <= stop and (not nextRec or rec.due < nextRec.due or (rec.due == nextRec.due and rec.order < nextRec.order)) then nextRec = rec end
        end
        for timer in pairs(ctx.engineTimers) do
            if timer.due <= stop and (not nextRec or timer.due < nextRec.due or (timer.due == nextRec.due and timer.order < nextRec.order)) then nextRec = timer end
        end
        if not nextRec then ctx.time = stop; return clean, resumes end
        if resumes >= budget then capture(ctx, "scheduler resume budget exhausted"); return false, resumes end
        ctx.time = nextRec.due
        resumes = resumes + 1
        if nextRec.engine then
            ctx.engineTimers[nextRec] = nil
            local ok, err = pcall(nextRec.fn)
            if not ok then capture(ctx, err); clean = false end
        else
            local args = nextRec.args
            if not args then
                if nextRec.signal then args = pack(nil)
                else args = pack(ctx.time - (nextRec.started or ctx.time)) end
            end
            if not resumeTask(ctx, nextRec, args) then clean = false end
        end
    end
end
function M.advance(seconds, maxResumes)
    assert(current, "mock.run must create a runtime first")
    return advanceContext(current, seconds, maxResumes)
end
function M.runUntilIdle(maxResumes)
    assert(current, "mock.run must create a runtime first")
    local count, budget = 0, maxResumes or 10000
    while next(current.tasks) or next(current.engineTimers) do
        local due
        for _, rec in pairs(current.tasks) do if rec.due and (not due or rec.due < due) then due = rec.due end end
        for timer in pairs(current.engineTimers) do if not due or timer.due < due then due = timer.due end end
        if not due then capture(current, "scheduler blocked on unfired signal"); return false, count end
        local ok, n = advanceContext(current, due-current.time, budget-count)
        count = count + n
        if not ok then return false, count end
    end
    return true, count
end
function M.activeTasks()
    local n = 0
    for co in pairs(current and current.tasks or {}) do if coroutine.status(co) ~= "dead" then n = n + 1 end end
    return n
end
function M.activeConnections()
    local n = 0
    for conn in pairs(current and current.connections or {}) do if conn.Connected then n = n + 1 end end
    return n
end

local function signal(ctx)
    local s = {_ctx = ctx or current, _handlers = {}, _waiters = {}, _destroyed = false, __type = "RBXScriptSignal"}
    function s:Connect(fn)
        assert(type(fn) == "function", "Connect expects function")
        assert(not self._destroyed, "cannot connect destroyed signal")
        local conn = {Connected = true, __type = "RBXScriptConnection", _fn = fn}
        function conn:Disconnect()
            if not self.Connected then return end
            self.Connected = false
            s._ctx.connections[self] = nil
            for i = #s._handlers, 1, -1 do if s._handlers[i] == self then table.remove(s._handlers, i) end end
        end
        s._handlers[#s._handlers + 1] = conn
        s._ctx.connections[conn] = true
        return conn
    end
    function s:Once(fn)
        local conn = self:Connect(fn); conn._once = true; return conn
    end
    function s:Wait(timeout)
        assert(coroutine.isyieldable(), "Signal:Wait requires a coroutine")
        return coroutine.yield({kind = "signal", signal = self, timeout = timeout})
    end
    function s:Fire(...)
        if self._destroyed then return end
        local args, handlers, waiters = pack(...), {}, {}
        for i, conn in ipairs(self._handlers) do handlers[i] = conn end
        for _, rec in pairs(self._waiters) do waiters[#waiters+1] = rec end
        table.sort(waiters, function(a,b) return a.order < b.order end)
        for _, rec in ipairs(waiters) do resumeTask(self._ctx, rec, args) end
        for _, conn in ipairs(handlers) do
            if conn.Connected then
                if conn._once then conn:Disconnect() end
                spawnTask(self._ctx, conn._fn, unpack(args, 1, args.n))
            end
        end
    end
    function s:Count() return #self._handlers end
    function s:Destroy()
        local handlers = {}; for i,c in ipairs(self._handlers) do handlers[i] = c end
        for _, c in ipairs(handlers) do c:Disconnect() end
        local waiters = {}; for co in pairs(self._waiters) do waiters[#waiters+1] = co end
        for _, co in ipairs(waiters) do cancelTask(self._ctx, co) end
        self._destroyed = true
    end
    return s
end
M.signal = signal

-- Value types preserve Roblox normalization and rigid-transform composition.
local V3 = {}
local function v3(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,__type="Vector3"}, V3) end
V3.__add = function(a,b) return v3(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V3.__sub = function(a,b) return v3(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V3.__unm = function(a) return v3(-a.X,-a.Y,-a.Z) end
V3.__mul = function(a,b)
    if type(a)=="number" then return v3(a*b.X,a*b.Y,a*b.Z) end
    if type(b)=="number" then return v3(a.X*b,a.Y*b,a.Z*b) end
    return v3(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
V3.__div = function(a,b)
    if type(b)=="number" then return v3(a.X/b,a.Y/b,a.Z/b) end
    return v3(a.X/b.X,a.Y/b.Y,a.Z/b.Z)
end
V3.__eq = function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
V3.__tostring = function(a) return string.format("%g, %g, %g",a.X,a.Y,a.Z) end
function V3:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function V3:Cross(b) return v3(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function V3:Lerp(b,t) return self+(b-self)*t end
V3.__index = function(a,k)
    if k=="Magnitude" then return math.sqrt(a:Dot(a)) end
    if k=="Unit" then local m=a.Magnitude; return m>0 and a/m or v3() end
    return V3[k]
end
local CFM = {}
local function matrix(x,y,z,r)
    return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,_r=r or {1,0,0,0,1,0,0,0,1},__type="CFrame"},CFM)
end
local function rotate(a,b)
    local r=a._r
    return v3(r[1]*b.X+r[2]*b.Y+r[3]*b.Z,r[4]*b.X+r[5]*b.Y+r[6]*b.Z,r[7]*b.X+r[8]*b.Y+r[9]*b.Z)
end
CFM.__mul = function(a,b)
    if getmetatable(b)==V3 then return a.Position+rotate(a,b) end
    assert(getmetatable(b)==CFM, "CFrame multiplication expects CFrame or Vector3")
    local p=a*b.Position; local ar,br,r=a._r,b._r,{}
    for i=0,2 do for j=1,3 do r[i*3+j]=ar[i*3+1]*br[j]+ar[i*3+2]*br[3+j]+ar[i*3+3]*br[6+j] end end
    return matrix(p.X,p.Y,p.Z,r)
end
CFM.__add = function(a,b) return matrix(a.X+b.X,a.Y+b.Y,a.Z+b.Z,a._r) end
CFM.__sub = function(a,b) return matrix(a.X-b.X,a.Y-b.Y,a.Z-b.Z,a._r) end
CFM.__eq = function(a,b)
    if a.X~=b.X or a.Y~=b.Y or a.Z~=b.Z then return false end
    for i=1,9 do if a._r[i]~=b._r[i] then return false end end
    return true
end
CFM.__tostring = function(a) return "CFrame("..tostring(a.Position)..")" end
function CFM:Inverse()
    local r=self._r; local inv=matrix(0,0,0,{r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]})
    local p=rotate(inv,-self.Position); inv.X,inv.Y,inv.Z=p.X,p.Y,p.Z; return inv
end
function CFM:ToObjectSpace(b) return self:Inverse()*b end
function CFM:ToWorldSpace(b) return self*b end
function CFM:PointToObjectSpace(b) return self:Inverse()*b end
function CFM:PointToWorldSpace(b) return self*b end
function CFM:VectorToObjectSpace(b) return rotate(self:Inverse(),b) end
function CFM:VectorToWorldSpace(b) return rotate(self,b) end
function CFM:GetComponents() return self.X,self.Y,self.Z,unpack(self._r) end
CFM.__index = function(a,k)
    if k=="Position" or k=="p" then return v3(a.X,a.Y,a.Z) end
    local r=a._r
    if k=="LookVector" then return v3(-r[3],-r[6],-r[9]) end
    if k=="RightVector" then return v3(r[1],r[4],r[7]) end
    if k=="UpVector" then return v3(r[2],r[5],r[8]) end
    if k=="Rotation" then return matrix(0,0,0,r) end
    return CFM[k]
end
local CFrame = {}
function CFrame.lookAt(position,target,up)
    local back=(position-target).Unit
    if back.Magnitude==0 then return matrix(position.X,position.Y,position.Z) end
    local right=(up or v3(0,1,0)):Cross(back).Unit
    if right.Magnitude==0 then right=v3(1,0,0) end
    local actualUp=back:Cross(right)
    return matrix(position.X,position.Y,position.Z,{right.X,actualUp.X,back.X,right.Y,actualUp.Y,back.Y,right.Z,actualUp.Z,back.Z})
end
function CFrame.new(x,y,z,...)
    if getmetatable(x)==V3 then
        if getmetatable(y)==V3 then return CFrame.lookAt(x,y) end
        return matrix(x.X,x.Y,x.Z)
    end
    local r=pack(...); return matrix(x,y,z,r.n==9 and r or nil)
end
function CFrame.Angles(x,y,z)
    local sx,cx,sy,cy,sz,cz=math.sin(x),math.cos(x),math.sin(y),math.cos(y),math.sin(z),math.cos(z)
    return matrix(0,0,0,{cy*cz,-cy*sz,sy,cx*sz+sx*sy*cz,cx*cz-sx*sy*sz,-sx*cy,sx*sz-cx*sy*cz,sx*cz+cx*sy*sz,cx*cy})
end
CFrame.fromEulerAnglesXYZ=CFrame.Angles
CFrame.identity=matrix()
local function color(r,g,b) return {R=r or 0,G=g or 0,B=b or 0,__type="Color3"} end
local Color3={new=color,fromRGB=function(r,g,b) return color(r/255,g/255,b/255) end}
local UDim={new=function(s,o) return {Scale=s or 0,Offset=o or 0,__type="UDim"} end}
local UDim2={new=function(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo),__type="UDim2"} end}
UDim2.fromOffset=function(x,y) return UDim2.new(0,x,0,y) end
UDim2.fromScale=function(x,y) return UDim2.new(x,0,y,0) end
local Vector2={new=function(x,y) return {X=x or 0,Y=y or 0,__type="Vector2"} end}

local ENUM_MT = {__tostring=function(item) return "Enum."..item.EnumType.Name.."."..item.Name end}
local function makeEnum()
    local enum = {}
    local knownKeys = {Unknown=true,Space=true,Escape=true,Return=true,Tab=true,Backspace=true,LeftShift=true,RightShift=true,LeftControl=true,RightControl=true,LeftAlt=true,RightAlt=true,Up=true,Down=true,Left=true,Right=true,Slash=true,BackSlash=true,Semicolon=true,Quote=true,Backquote=true,Comma=true,Period=true,Minus=true,Equals=true,LeftBracket=true,RightBracket=true,Insert=true,Delete=true,Home=true,End=true,PageUp=true,PageDown=true,CapsLock=true}
    for c=65,90 do knownKeys[string.char(c)]=true end
    for _,key in ipairs({"Zero","One","Two","Three","Four","Five","Six","Seven","Eight","Nine"}) do knownKeys[key]=true end
    for i=1,12 do knownKeys["F"..i]=true end
    return setmetatable(enum,{__index=function(t,name)
        local typ,cache={Name=name,__type="Enum"},{}
        setmetatable(typ,{__index=function(_,key)
            if key=="GetEnumItems" then return function() local out={}; for _,v in pairs(cache) do out[#out+1]=v end; return out end end
            if name=="KeyCode" and not knownKeys[key] then return nil end
            if not cache[key] then cache[key]=setmetatable({Name=key,Value=0,EnumType=typ,__type="EnumItem"},ENUM_MT) end
            return cache[key]
        end,__tostring=function() return "Enum."..name end})
        rawset(t,name,typ); return typ
    end})
end
local BASE = {TextButton="GuiButton",ImageButton="GuiButton",GuiButton="GuiObject",TextLabel="GuiObject",TextBox="GuiObject",Frame="GuiObject",ScrollingFrame="GuiObject",ImageLabel="GuiObject",ViewportFrame="GuiObject",GuiObject="GuiBase2d",ScreenGui="LayerCollector",BillboardGui="LayerCollector",SurfaceGui="LayerCollector",LayerCollector="GuiBase2d",GuiBase2d="Instance",Part="BasePart",MeshPart="BasePart",UnionOperation="BasePart",WedgePart="BasePart",BasePart="PVInstance",Model="PVInstance",Workspace="Model",PVInstance="Instance",BoolValue="ValueBase",StringValue="ValueBase",IntValue="ValueBase",NumberValue="ValueBase",ObjectValue="ValueBase",CFrameValue="ValueBase",Vector3Value="ValueBase",Color3Value="ValueBase",ValueBase="Instance",LocalScript="LuaSourceContainer",Script="LuaSourceContainer",ModuleScript="LuaSourceContainer",LuaSourceContainer="Instance",Motor6D="JointInstance",Weld="JointInstance",JointInstance="Instance",Beam="Instance",Trail="Instance",ParticleEmitter="Instance",WeldConstraint="Instance"}
local EVENTS = {MouseButton1Down=true,MouseButton1Up=true,MouseButton1Click=true,MouseButton2Down=true,MouseButton2Click=true,MouseEnter=true,MouseLeave=true,FocusLost=true,Focused=true,InputBegan=true,InputChanged=true,InputEnded=true,Idled=true,Changed=true,MoveToFinished=true,Activated=true,Deactivated=true,Equipped=true,Unequipped=true,ChildAdded=true,ChildRemoved=true,DescendantAdded=true,DescendantRemoving=true,AncestryChanged=true,Destroying=true,OnClientEvent=true,OnServerEvent=true,Touched=true,TouchEnded=true,CharacterAdded=true,CharacterRemoving=true,HealthChanged=true,Died=true,Triggered=true,Ended=true,Completed=true}
-- Constraint classes used to verify external attachment sanitization.
for _, class in ipairs({"AlignPosition","AlignOrientation","BallSocketConstraint","HingeConstraint","RopeConstraint","RodConstraint","SpringConstraint","PrismaticConstraint","CylindricalConstraint","UniversalConstraint","RigidConstraint","PlaneConstraint","LinearVelocity","AngularVelocity","VectorForce","Torque","LineForce"}) do BASE[class]="Constraint" end
BASE.Constraint,BASE.Attachment,BASE.Bone="Instance","Instance","Attachment"
local METHODS, newInstance = {}, nil
local function isInstance(o) return type(o)=="table" and rawget(o,"__isInstance")==true end
local function emit(o,key,...)
    local s=rawget(o,"__events")[key]
    if s then s:Fire(...) end
end
local function changed(o,key,value)
    local s=rawget(o,"__propertySignals")[key]
    if s then s:Fire() end
    emit(o,"Changed",o:IsA("ValueBase") and key=="Value" and value or key)
end
local function setParent(o,p)
    assert(p==nil or isInstance(p), "Parent must be an Instance or nil")
    assert(p~=o and not (p and p:IsDescendantOf(o)), "cyclic Parent")
    local props=rawget(o,"__props"); local old=props.Parent
    if old==p then return end
    local moved={o}; for _,v in ipairs(o:GetDescendants()) do moved[#moved+1]=v end
    local ancestor=old
    while ancestor do for _,v in ipairs(moved) do emit(ancestor,"DescendantRemoving",v) end; ancestor=ancestor.Parent end
    if old then
        local kids=rawget(old,"__kids")
        for i=#kids,1,-1 do if kids[i]==o then table.remove(kids,i) end end
    end
    props.Parent=p
    if p then table.insert(rawget(p,"__kids"),o) end
    if old then emit(old,"ChildRemoved",o) end
    if p then emit(p,"ChildAdded",o) end
    changed(o,"Parent",p)
    for _,v in ipairs(moved) do emit(v,"AncestryChanged",v,v.Parent) end
    ancestor=p
    while ancestor do for _,v in ipairs(moved) do emit(ancestor,"DescendantAdded",v) end; ancestor=ancestor.Parent end
end
newInstance = function(class,name,ctx)
    ctx=ctx or current; assert(ctx,"Instance requires runtime context")
    local props={Name=name or class,ClassName=class,Archivable=true}
    local o={__isInstance=true,__type="Instance",__props=props,__kids={},__events={},__propertySignals={},__attributeSignals={},__attributes={},__ctx=ctx,__destroyed=false}
    local mt={}
    mt.__index=function(t,k)
        if props[k]~=nil then return props[k] end -- test overrides precede built-in methods
        if k=="Parent" or k=="PrimaryPart" or k=="Character" or k=="Part0" or k=="Part1" or k=="Attachment0" or k=="Attachment1" then return nil end
        if METHODS[k] then return METHODS[k] end
        if EVENTS[k] then
            if not o.__events[k] then o.__events[k]=signal(ctx) end
            return o.__events[k]
        end
        for _,ch in ipairs(o.__kids) do if ch.Name==k then return ch end end
        return nil
    end
    mt.__newindex=function(t,k,v)
        if k=="Parent" then setParent(o,v); return end
        local old=props[k]
        if old==v then return end
        if k=="Character" and class=="Player" and old then emit(o,"CharacterRemoving",old) end
        if k=="Health" and class=="Humanoid" then v=math.max(0,math.min(tonumber(v) or 0,props.MaxHealth or 100)) end
        props[k]=v
        if k=="CFrame" and o:IsA("BasePart") then props.Position=v.Position; changed(o,"Position",props.Position) end
        if k=="Position" and o:IsA("BasePart") then props.CFrame=matrix(v.X,v.Y,v.Z,props.CFrame._r); changed(o,"CFrame",props.CFrame) end
        if k=="MaxHealth" and class=="Humanoid" and props.Health>v then o.Health=v end
        changed(o,k,v)
        if k=="Health" and class=="Humanoid" then emit(o,"HealthChanged",v); if old and old>0 and v<=0 then emit(o,"Died") end end
        if k=="Character" and class=="Player" and v then emit(o,"CharacterAdded",v) end
    end
    mt.__tostring=function(t) return t.Name end
    setmetatable(o,mt)
    if o:IsA("BasePart") then
        props.CFrame,props.Position,props.Size=matrix(),v3(),v3(4,1,2)
        props.Anchored,props.CanCollide,props.CanTouch,props.CanQuery=false,true,true,true
        props.Transparency,props.LocalTransparencyModifier=0,0
        props.AssemblyLinearVelocity,props.AssemblyAngularVelocity=v3(),v3()
        props.Color,props.Material=color(0.64,0.64,0.64),ctx.Enum.Material.Plastic
    end
    if o:IsA("GuiObject") then
        props.Visible,props.Active,props.LayoutOrder=true,false,0
        props.Size,props.Position=UDim2.new(),UDim2.new()
        props.AbsoluteSize,props.AbsolutePosition=Vector2.new(400,300),Vector2.new()
        props.BackgroundColor3,props.BackgroundTransparency=color(1,1,1),0
        props.Text,props.TextColor3,props.TextSize="",color(),14
        props.TextTransparency,props.Rotation,props.ZIndex=0,0,1
    end
    if o:IsA("LayerCollector") then props.Enabled,props.ResetOnSpawn=true,true end
    if class=="StringValue" then props.Value="" end
    if class=="NumberValue" or class=="IntValue" then props.Value=0 end
    if class=="BoolValue" then props.Value=false end
    if class=="Vector3Value" then props.Value=v3() end
    if class=="CFrameValue" then props.Value=matrix() end
    if class=="Humanoid" then props.Health,props.MaxHealth,props.WalkSpeed,props.JumpPower,props.AutoRotate=100,100,16,50,true end
    if class=="Tool" then props.Enabled,props.RequiresHandle=true,true end
    if class=="ProximityPrompt" then props.Enabled,props.HoldDuration,props.MaxActivationDistance=true,0,10 end
    if class=="UIListLayout" then props.AbsoluteContentSize=Vector2.new(200,0) end
    if class=="Camera" then props.CFrame,props.ViewportSize=matrix(0,5,20),Vector2.new(1280,720) end
    return o
end
function METHODS:IsA(class)
    if class=="Instance" then return true end
    local c=self.ClassName
    while c do if c==class then return true end; c=BASE[c] end
    return false
end
function METHODS:GetChildren() local out={}; for i,v in ipairs(self.__kids) do out[i]=v end; return out end
function METHODS:GetDescendants()
    local out={}
    local function walk(o) for _,ch in ipairs(o.__kids) do out[#out+1]=ch; walk(ch) end end
    walk(self); return out
end
function METHODS:FindFirstChild(name,recursive)
    for _,ch in ipairs(self.__kids) do if ch.Name==name then return ch end end
    if recursive then for _,ch in ipairs(self.__kids) do local found=ch:FindFirstChild(name,true); if found then return found end end end
end
function METHODS:FindFirstChildOfClass(class)
    for _,ch in ipairs(self.__kids) do if ch.ClassName==class then return ch end end
end
function METHODS:FindFirstChildWhichIsA(class,recursive)
    for _,ch in ipairs(self.__kids) do if ch:IsA(class) then return ch end end
    if recursive then for _,ch in ipairs(self.__kids) do local found=ch:FindFirstChildWhichIsA(class,true); if found then return found end end end
end
function METHODS:FindFirstAncestor(name)
    local p=self.Parent; while p do if p.Name==name then return p end; p=p.Parent end
end
function METHODS:FindFirstAncestorOfClass(class)
    local p=self.Parent; while p do if p.ClassName==class then return p end; p=p.Parent end
end
function METHODS:FindFirstAncestorWhichIsA(class)
    local p=self.Parent; while p do if p:IsA(class) then return p end; p=p.Parent end
end
function METHODS:IsDescendantOf(other)
    local p=self.Parent; while p do if p==other then return true end; p=p.Parent end; return false
end
function METHODS:GetFullName()
    local out,p={},self; while p do table.insert(out,1,p.Name); p=p.Parent end; return table.concat(out,".")
end
function METHODS:WaitForChild(name,timeout)
    local child=self:FindFirstChild(name); if child then return child end
    assert(coroutine.isyieldable(), "WaitForChild requires scheduled coroutine: "..tostring(name))
    local deadline=timeout and (self.__ctx.time+timeout)
    while not child do
        local remaining=deadline and (deadline-self.__ctx.time)
        if remaining and remaining<=0 then return nil end
        self.ChildAdded:Wait(remaining)
        child=self:FindFirstChild(name)
    end
    return child
end
function METHODS:GetPropertyChangedSignal(key)
    if not self.__propertySignals[key] then self.__propertySignals[key]=signal(self.__ctx) end
    return self.__propertySignals[key]
end
function METHODS:GetAttribute(key) return self.__attributes[key] end
function METHODS:GetAttributes() local out={}; for k,v in pairs(self.__attributes) do out[k]=v end; return out end
function METHODS:SetAttribute(key,value)
    if self.__attributes[key]==value then return end
    self.__attributes[key]=value
    if self.__attributeSignals[key] then self.__attributeSignals[key]:Fire() end
end
function METHODS:GetAttributeChangedSignal(key)
    if not self.__attributeSignals[key] then self.__attributeSignals[key]=signal(self.__ctx) end
    return self.__attributeSignals[key]
end
function METHODS:Destroy()
    if self.__destroyed then return end
    self.__destroyed=true; emit(self,"Destroying")
    for _,ch in ipairs(self:GetChildren()) do ch:Destroy() end
    self.Parent=nil
    for _,group in ipairs({self.__events,self.__propertySignals,self.__attributeSignals}) do for _,s in pairs(group) do s:Destroy() end end
end
METHODS.Remove=METHODS.Destroy
function METHODS:ClearAllChildren() for _,ch in ipairs(self:GetChildren()) do ch:Destroy() end end
function METHODS:Clone()
    if not self.Archivable then return nil end
    local map={}
    local function allocate(old)
        local copy=newInstance(old.ClassName,old.Name,old.__ctx); map[old]=copy
        for _,ch in ipairs(old.__kids) do if ch.Archivable then allocate(ch).Parent=copy end end
        return copy
    end
    local root=allocate(self)
    local seen={}
    local function value(v)
        if isInstance(v) then return map[v] or v end
        if type(v)~="table" or v.__type then return v end
        if seen[v] then return seen[v] end
        local copy={}; seen[v]=copy; for k,item in pairs(v) do copy[value(k)]=value(item) end; return copy
    end
    for old,copy in pairs(map) do
        for key,v in pairs(old.__props) do if key~="Parent" then copy.__props[key]=value(v) end end
        for key,v in pairs(old.__attributes) do copy.__attributes[key]=value(v) end
    end
    return root
end
function METHODS:GetPivot()
    if self:IsA("BasePart") then return self.CFrame end
    local part=self.PrimaryPart or self:FindFirstChild("HumanoidRootPart") or self:FindFirstChildWhichIsA("BasePart",true)
    return part and part.CFrame or self.__props._pivot or matrix()
end
function METHODS:PivotTo(target)
    if self:IsA("BasePart") then self.CFrame=target; return end
    local delta=target*self:GetPivot():Inverse()
    for _,part in ipairs(self:GetDescendants()) do if part:IsA("BasePart") then part.CFrame=delta*part.CFrame end end
    self.__props._pivot=target
end
METHODS.SetPrimaryPartCFrame=METHODS.PivotTo
function METHODS:GetPlayers()
    local out={}; for _,p in ipairs(self:GetChildren()) do if p:IsA("Player") then out[#out+1]=p end end; return out
end
function METHODS:GetPlayerFromCharacter(character)
    for _,p in ipairs(self:GetPlayers()) do if p.Character==character then return p end end
end
function METHODS:GetMouse()
    if not self.__props._mouse then self.__props._mouse={X=0,Y=0,Hit=matrix(),Button1Down=signal(self.__ctx),Button2Down=signal(self.__ctx)} end
    return self.__props._mouse
end
function METHODS:EquipTool(tool)
    assert(isInstance(tool) and tool:IsA("Tool"), "EquipTool expects Tool")
    local char=self.Parent; if not char then return end
    local player=self.__ctx.services.Players:GetPlayerFromCharacter(char)
    if player then for _,other in ipairs(char:GetChildren()) do if other:IsA("Tool") and other~=tool then other.Parent=player.Backpack; emit(other,"Unequipped") end end end
    tool.Parent=char; emit(tool,"Equipped")
end
function METHODS:UnequipTools()
    local player=self.__ctx.services.Players:GetPlayerFromCharacter(self.Parent)
    if player then for _,tool in ipairs(self.Parent:GetChildren()) do if tool:IsA("Tool") then tool.Parent=player.Backpack; emit(tool,"Unequipped") end end end
end
function METHODS:MoveTo(position)
    self.__props.WalkToPoint=position
    local root=self.Parent and self.Parent:FindFirstChild("HumanoidRootPart")
    if root then root.Position=position end
    emit(self,"MoveToFinished",true)
end
function METHODS:ChangeState(state) self.__props.State=state end
function METHODS:GetState() return self.__props.State or self.__ctx.Enum.HumanoidStateType.Running end
function METHODS:TakeDamage(n) self.Health=self.Health-n end
function METHODS:Activate() emit(self,"Activated") end
function METHODS:FireServer(...) self.__ctx.remotes[#self.__ctx.remotes+1]={instance=self,args=pack(...)} end
function METHODS:InvokeServer(...)
    self.__ctx.remotes[#self.__ctx.remotes+1]={instance=self,args=pack(...)}
    if self.Name=="Info" then return {self.__ctx.Enum.KeyCode.E,self.__ctx.Enum.KeyCode.R,self.__ctx.Enum.UserInputType.MouseButton1} end
    return {}
end
function METHODS:InputHoldBegin() self.__props._holding=true end
function METHODS:InputHoldEnd() self.__props._holding=false; emit(self,"Triggered",self.__ctx.services.Players.LocalPlayer) end
function METHODS:Play() self.__props.Playing=true end
function METHODS:Stop() self.__props.Playing=false end
function METHODS:LoadAnimation(animation)
    local track=newInstance("AnimationTrack","AnimationTrack",self.__ctx); track.Animation=animation; return track
end
function METHODS:GetMass() return 1 end
function METHODS:SetCore(key,value)
    self.__ctx.notifications[#self.__ctx.notifications+1]={key=key,value=value}
end
function METHODS:SetCoreGuiEnabled(key,value) self.__props[key.Name or key]=value end
function METHODS:CaptureFocus() self.__ctx.focusedTextBox=self; emit(self,"Focused") end
function METHODS:ReleaseFocus(enter) self.__ctx.focusedTextBox=nil; emit(self,"FocusLost",enter or false) end
function METHODS:IsFocused() return self.__ctx.focusedTextBox==self end
function METHODS:ViewportPointToRay(x,y)
    return {Origin=self.CFrame.Position,Direction=self.CFrame.LookVector,__type="Ray"}
end
METHODS.ScreenPointToRay=METHODS.ViewportPointToRay
function METHODS:WorldToViewportPoint(point) return v3(point.X,point.Y,1),true end
function METHODS:Raycast(origin,direction,params)
    local result=self.__ctx.raycastResult
    if type(result)=="function" then return result(origin,direction,params) end
    if result then return result end
    local target=self.__ctx.services.Players.LocalPlayer:GetMouse().Target
    if target then return {Instance=target,Position=target.Position or origin,Normal=v3(0,1,0)} end
end
M.newInstance=newInstance

-- Services and fixtures used by the client and regression cases.
local function build(ctx)
    ctx.Enum=makeEnum(); ctx.services={}; ctx.notifications={}
    local function add(class,name,parent,value)
        local obj=newInstance(class,name,ctx)
        if value~=nil then obj.Value=value end
        if parent then obj.Parent=parent end
        return obj
    end
    local workspace=add("Workspace","Workspace")
    local rs=add("ReplicatedStorage","ReplicatedStorage")
    local players=add("Players","Players")
    for name,obj in pairs({Workspace=workspace,ReplicatedStorage=rs,Players=players,CoreGui=add("CoreGui","CoreGui"),StarterGui=add("StarterGui","StarterGui"),Lighting=add("Lighting","Lighting")}) do ctx.services[name]=obj end
    local map=add("Folder","Map",workspace)
    local npcs=add("Folder","NPCs",map)
    local function provider(name,label)
        local model=add("Model",name,npcs)
        add("Part","HumanoidRootPart",model)
        local head=add("Part","Head",model); head.Position=v3(0,5,0)
        for _,n in ipairs({"Main","Sub"}) do local bb=add("BillboardGui",n,head); local text=add("TextLabel","Text",bb); text.Text=n=="Main" and (label or name) or "" end
        add("RemoteEvent","Done",model); add("RemoteEvent","QuestDone",model)
        return model
    end
    for _,spec in ipairs({{"admpn","Admpn"},{"StockMarket","Stock Market"},{"MerchantAU","Merchant"},{"Merchant120","Merchant 120"},{"LairNPC","Lair Host"},{"Gyro","Gyro Zeppeli"}}) do provider(unpack(spec)) end
    for i=1,6 do provider("QuestNPC"..i,"Quest NPC "..i) end
    local boards=add("Folder","ChancesBoards",map)
    local attr=add("Model","AttributeChances",boards)
    local surface=add("Part","newSurface",attr)
    local scroll=add("ScrollingFrame","ScrollFrame",surface)
    for _,text in ipairs({"Glass Cannon 1%","Power 5%","Speed 4%","Power 5%"}) do local l=add("TextLabel",text,scroll); l.Text=text end
    add("Folder","Living",workspace); add("Folder","Items",workspace); add("Folder","Vfx",workspace)
    local events=add("Folder","Events",rs)
    for _,n in ipairs({"UseItem","SellKetchup","BuyItem","SM_Event","SwitchStand","GetStandTier","CoolDownGUI","CheckCMD","LairStart","LairClear","NpcPrompt","PressedPlay"}) do add("RemoteEvent",n,events) end
    local convert=add("Folder","StandNameConvert",rs)
    for _,spec in ipairs({{"None","None"},{"SP","Star Platinum"},{"SPTW_R","Star Platinum: The World Requiem"},{"TW","The World"},{"CD","Crazy Diamond"},{"GE","Gold Experience"},{"KC","King Crimson"},{"MIH","Made in Heaven"},{"TuskAct1","Tusk Act 1"},{"TuskAct2","Tusk Act 2"},{"TuskAct3","Tusk Act 3"},{"TuskAct4","Tusk Act 4"},{"Tusk","Tusk"}}) do add("StringValue",spec[1],convert,spec[2]) end
    local stands=add("Folder","StandModels",rs)
    for _,code in ipairs({"SP","TW","Tusk"}) do
        local model=add("Model",code,stands)
        local root=add("Part","HumanoidRootPart",model); model.PrimaryPart=root
        local head=add("Part","Head",model); head.Position=v3(0,2,0)
        local joint=add("Motor6D","Neck",root); joint.Part0=root; joint.Part1=head
        add("Humanoid","Humanoid",model); add("LocalScript","LocalController",model)
    end
    local lp=add("Player","TestPlayer",players); lp.DisplayName="Test Player"; lp.UserId=12345
    players.LocalPlayer=lp
    local data=add("Folder","Data",lp)
    add("StringValue","Stand",data,"None"); add("StringValue","Attri",data,"None"); add("StringValue","GUID",data,"0000")
    local backpack=add("Backpack","Backpack",lp)
    add("Tool","Umbrella",backpack)
    local character=add("Model","TestPlayer",workspace)
    local humanoid=add("Humanoid","Humanoid",character)
    local root=add("Part","HumanoidRootPart",character); character.PrimaryPart=root
    local head=add("Part","Head",character); head.Position=v3(0,2,0)
    local standEvents=add("Folder","StandEvents",character)
    add("RemoteEvent","Input",standEvents); add("RemoteFunction","Info",standEvents)
    local stats=add("Folder","Stats",character)
    add("NumberValue","AttackDmg",stats,10); add("NumberValue","DmgBoostAttri",character,1)
    add("BoolValue","Aura",character,false)
    lp.Character=character
    local pg=add("PlayerGui","PlayerGui",lp)
    local hud=add("ScreenGui","PlayerGUI",pg)
    local ingame=add("Frame","ingame",hud)
    local hudStats=add("Frame","Stats",ingame)
    for _,spec in ipairs({{"StandName","None"},{"Attri","None"},{"StandHealth","100"},{"StandDamage","10"},{"GUID","0000"}}) do
        local holder=add("Frame",spec[1],hudStats)
        local nested=add("Frame",spec[1]=="StandName" and "Name_" or "Value",holder)
        local label=add("TextLabel","TextLabel",nested); label.Text=spec[2]
    end
    local camera=add("Camera","Camera",workspace); workspace.CurrentCamera=camera
    ctx.services.UserInputService={InputBegan=signal(ctx),InputChanged=signal(ctx),InputEnded=signal(ctx),
        GetFocusedTextBox=function() return ctx.focusedTextBox end,GetMouseLocation=function() return Vector2.new(640,360) end,
        IsKeyDown=function() return false end,TouchEnabled=false,KeyboardEnabled=true,MouseEnabled=true}
    ctx.services.RunService={Heartbeat=signal(ctx),RenderStepped=signal(ctx),Stepped=signal(ctx),IsClient=function() return true end,IsServer=function() return false end}
    ctx.services.TweenService={Create=function(_,target,info,goals)
        local tween={Completed=signal(ctx),PlaybackState=ctx.Enum.PlaybackState.Begin}
        function tween:Play() for k,v in pairs(goals) do target[k]=v end; self.PlaybackState=ctx.Enum.PlaybackState.Completed; self.Completed:Fire(self.PlaybackState) end
        function tween:Cancel() self.PlaybackState=ctx.Enum.PlaybackState.Cancelled end
        function tween:Destroy() self.Completed:Destroy() end
        return tween
    end}
    ctx.services.Debris={AddItem=function(_,obj,seconds)
        -- Debris is an engine-owned expiry, not a task.spawn client thread.
        ctx.serial=ctx.serial+1
        local timer={engine=true,due=ctx.time+math.max(0,seconds or 0),order=ctx.serial,fn=function() obj:Destroy() end}
        ctx.engineTimers[timer]=true
    end}
    ctx.services.PathfindingService={CreatePath=function()
        local path={Status=ctx.Enum.PathStatus.Success,Blocked=signal(ctx)}
        function path:ComputeAsync(start,finish) self._finish=finish end
        function path:GetWaypoints() return self._finish and {{Position=self._finish,Action=ctx.Enum.PathWaypointAction.Walk}} or {} end
        function path:Destroy() self.Blocked:Destroy() end
        return path
    end}
    ctx.services.HttpService={JSONEncode=function() return "{}" end,JSONDecode=function() return {} end,GenerateGUID=function() return "00000000-0000-0000-0000-000000000000" end}
    ctx.services.VirtualUser={CaptureController=function() end,Button2Down=function() end,Button2Up=function() end}
    local game={PlaceId=8540168650,JobId="offline-mock",Workspace=workspace,Players=players}
    function game:GetService(name)
        if not ctx.services[name] then ctx.services[name]=add(name,name) end
        return ctx.services[name]
    end
    function game:IsLoaded() return true end
    function game:HttpGet() error("HTTP is not available in offline mock") end
    ctx.workspace,ctx.game,ctx.player=workspace,game,lp
    return game,workspace
end
local function makeEnvironment(ctx)
    local game,workspace=build(ctx)
    local task={}
    function task.spawn(fn,...) return spawnTask(ctx,fn,...) end
    function task.defer(fn,...) return scheduledTask(ctx,0,fn,...) end
    function task.delay(seconds,fn,...) return scheduledTask(ctx,seconds,fn,...) end
    function task.cancel(co) cancelTask(ctx,co) end
    function task.wait(seconds)
        assert(coroutine.isyieldable(),"task.wait requires a scheduled coroutine")
        return coroutine.yield({kind="time",seconds=seconds})
    end
    local mathLib=setmetatable({clamp=function(v,a,b) return math.max(a,math.min(b,v)) end,round=function(v) return math.floor(v+0.5) end},{__index=REAL.math})
    local tableLib=setmetatable({
        find=function(t,value,start) for i=start or 1,#t do if t[i]==value then return i end end end,
        clear=function(t) for k in pairs(t) do t[k]=nil end end,
        clone=function(t) local out={}; for k,v in pairs(t) do out[k]=v end; return out end,
        create=function(n,value) local out={}; for i=1,n do out[i]=value end; return out end,
        freeze=function(t) return t end,isfrozen=function() return false end,
    },{__index=REAL.table})
    local stringLib=setmetatable({split=function(text,sep)
        sep=sep or ","; local out={}; local start=1
        if sep=="" then for i=1,#text do out[i]=text:sub(i,i) end; return out end
        while true do local first,last=string.find(text,sep,start,true); if not first then out[#out+1]=text:sub(start); break end; out[#out+1]=text:sub(start,first-1); start=last+1 end
        return out
    end},{__index=REAL.string})
    local env
    local function message(store,...) local out={}; for i=1,select("#",...) do out[i]=tostring(select(i,...)) end; store[#store+1]=table.concat(out,"\t") end
    env=setmetatable({game=game,workspace=workspace,Workspace=workspace,task=task,wait=task.wait,spawn=task.spawn,delay=task.delay,
        Instance={new=function(class,parent) local obj=newInstance(class,class,ctx); if parent then obj.Parent=parent end; return obj end},
        Enum=ctx.Enum,Vector3={new=v3,zero=v3(),one=v3(1,1,1)},Vector2=Vector2,CFrame=CFrame,UDim=UDim,UDim2=UDim2,Color3=Color3,
        TweenInfo={new=function(...) return {args=pack(...),__type="TweenInfo"} end},RaycastParams={new=function() return {FilterDescendantsInstances={},FilterType=ctx.Enum.RaycastFilterType.Exclude,__type="RaycastParams"} end},
        Ray={new=function(origin,direction) return {Origin=origin,Direction=direction,__type="Ray"} end},
        math=mathLib,table=tableLib,string=stringLib,unpack=unpack,
        os=setmetatable({clock=function() return ctx.time end,time=function() return math.floor(ctx.time) end},{__index=REAL.os}),
        tick=function() return ctx.time end,time=function() return ctx.time end,
        warn=function(...) message(ctx.warnings,...) end,print=function(...) message(ctx.prints,...) end,
        typeof=function(v) return type(v)=="table" and (v.__type or (isInstance(v) and "Instance")) or type(v) end,
        getgenv=function() return env end,shared={},
        fireproximityprompt=function(prompt) prompt:InputHoldBegin(); prompt:InputHoldEnd() end,
        firesignal=function(s,...) s:Fire(...) end,
        setclipboard=function(text) ctx.clipboard=text end,
        request=function() error("HTTP requests are not available in offline mock") end,
        http_request=function() error("HTTP requests are not available in offline mock") end,
        gethui=nil,
    },{__index=REAL})
    env.syn={request=env.request}
    env.loadstring=function(src,name) return load(src,name or "mock-loadstring","t",env) end
    env._G=env
    ctx.env=env
    return env
end
local function fireControls(ctx)
    local gui=ctx.env.ArcticScreenGui
    if not gui then return 0 end
    local fired=0
    for _,control in ipairs(gui:GetDescendants()) do
        if not control.__destroyed then
            if control:IsA("TextButton") then
                local event=control.__events.MouseButton1Down
                if event and event:Count()>0 then fired=fired+1; event:Fire(); event:Fire() end
            elseif control:IsA("TextBox") then
                local event=control.__events.FocusLost
                if event and event:Count()>0 then fired=fired+1; event:Fire(true) end
            end
        end
    end
    return fired
end
local function executeSource(ctx,src,clickAll)
    local chunk,err=load(src,"SUR","t",ctx.env)
    if not chunk then capture(ctx,err); return false,err,ctx.errors end
    local co=coroutine.create(chunk)
    local ok=resumeTask(ctx,taskRecord(ctx,co),pack())
    if not ok then return false,ctx.errors[#ctx.errors],ctx.errors end
    if coroutine.status(co)~="dead" then
        local advanced=advanceContext(ctx,60,10000)
        if not advanced or coroutine.status(co)~="dead" then
            err="source did not finish within mock load budget"; capture(ctx,err); return false,err,ctx.errors
        end
    end
    M.clicked=clickAll and fireControls(ctx) or 0
    return #ctx.errors==0,ctx.errors[1],ctx.errors
end
function M.run(src,clickAll)
    current=newContext()
    M.errors,M.warnings=current.errors,current.warnings
    M.env=makeEnvironment(current); M.workspace=current.workspace
    M.notifications,M.remotes,M.prints=current.notifications,current.remotes,current.prints
    return executeSource(current,src,clickAll==true)
end
function M.reload(src,clickAll)
    assert(current,"mock.run must create a runtime first")
    return executeSource(current,src,clickAll==true)
end
function M.setRaycastResult(result) assert(current,"mock.run first"); current.raycastResult=result end
function M.setFocusedTextBox(box) assert(current,"mock.run first"); current.focusedTextBox=box end
function M.now() return current and current.time or 0 end
return M
