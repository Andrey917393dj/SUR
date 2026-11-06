-- ============================================================
-- SUR AGENT v4  |  file bridge + remote spy for Xeno (UNC full)
-- Channel:  workspace\sur_cmd.json -> workspace\sur_res.json
--           workspace\sur_beat.json (heartbeat 2s)
--
-- v4 adds over v3:
--   * SUR_AGENT.spy      - __namecall hook, logs FireServer/InvokeServer
--   * SUR_AGENT.replay   - re-fire a captured call
--   * SUR_AGENT.probe    - player data / stand / character snapshot
--   * SUR_AGENT.find     - fuzzy instance search by name fragment
--   * big payloads spill to sur_out_<id>.json instead of sur_res.json
-- ============================================================

if getgenv().SUR_AGENT and getgenv().SUR_AGENT.stop then
    pcall(getgenv().SUR_AGENT.stop)
    task.wait(0.3)
end

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local LP          = Players.LocalPlayer

local CMD  = "sur_cmd.json"
local RES  = "sur_res.json"
local BEAT = "sur_beat.json"

local AGENT = { stop = nil, version = "4.1", started = os.time() }
getgenv().SUR_AGENT = AGENT

-- ============================================================
-- serialization
-- ============================================================
local function conv(v, depth, seen)
    depth = depth or 0
    seen  = seen or {}
    local t = typeof(v)
    if t == "Instance" then
        local ok, n = pcall(function() return v:GetFullName() end)
        return ok and n or tostring(v)
    end
    if t == "EnumItem" then return tostring(v) end
    if t == "Vector3"  then return { X = v.X, Y = v.Y, Z = v.Z } end
    if t == "Vector2"  then return { X = v.X, Y = v.Y } end
    if t == "CFrame"   then
        local p = v.Position
        return { X = p.X, Y = p.Y, Z = p.Z }
    end
    if t == "Color3" then return string.format("#%02X%02X%02X",
        math.floor(v.R*255), math.floor(v.G*255), math.floor(v.B*255)) end
    if t == "function" or t == "thread" or t == "userdata" then return "<"..t..">" end
    if t == "table" then
        if seen[v] then return "<cycle>" end
        if depth > 8 then return "<deep>" end
        seen[v] = true
        local out = {}
        for k, val in pairs(v) do
            local key = (type(k) == "string" or type(k) == "number") and k or tostring(k)
            out[key] = conv(val, depth + 1, seen)
        end
        seen[v] = nil
        return out
    end
    return tostring(v)
end

local function encode(v)
    local ok, s = pcall(function() return HttpService:JSONEncode(conv(v)) end)
    if ok then return s end
    return HttpService:JSONEncode({ __unserializable = tostring(v) })
end

-- ============================================================
-- capabilities
-- ============================================================
function AGENT.caps()
    local names = {
        "writefile","readfile","isfile","isfolder","listfiles","appendfile",
        "makefolder","delfile","delfolder","getgenv","getreg","request",
        "http_request","internal_request","getscriptbytecode","getscripthash",
        "setclipboard","base64encode","base64decode","firesignal","dbgpi",
        "hookfunction","hookmetamethod","getconnections","getrawmetatable",
        "setreadonly","getnamecallmethod","setnamecallmethod","newcclosure",
        "checkcaller","firetouchinterest","saveinstance","decompile",
        "getnilinstances","getloadedmodules","getsenv","getgc","getupvalues",
        "getconstants","identifyexecutor","getexecutorname","queue_on_teleport",
        "Drawing","setthreadidentity","getthreadidentity","clonefunction",
        "setfflag","getfflag","compareinstances","isreadonly","getcallingscript",
        "getinstances","getscripts","getrunningscripts","gethiddenproperty",
        "sethiddenproperty","getconnections"
    }
    local out = {}
    local g = getgenv()
    for _, n in ipairs(names) do
        local v = g[n]
        if v == nil then
            local ok, glob = pcall(function() return _G[n] end)
            if ok then v = glob end
        end
        out[n] = v ~= nil and type(v) or false
    end
    return out
end

-- ============================================================
-- hierarchy
-- ============================================================
function AGENT.scan(root, maxDepth, maxNodes)
    maxDepth = maxDepth or 3
    maxNodes = maxNodes or 1500
    local n = 0
    local function walk(inst, d)
        if n >= maxNodes then return "<truncated>" end
        n = n + 1
        local node = { name = inst.Name, class = inst.ClassName }
        if inst:IsA("ValueBase") then
            local ok, val = pcall(function() return inst.Value end)
            if ok then node.value = conv(val) end
        end
        if d < maxDepth then
            local kids = {}
            for _, c in ipairs(inst:GetChildren()) do
                kids[#kids+1] = walk(c, d + 1)
            end
            if #kids > 0 then node.children = kids end
        else
            local c = #inst:GetChildren()
            if c > 0 then node.child_count = c end
        end
        return node
    end
    return walk(root, 0)
end

-- fuzzy search by name fragment
function AGENT.find(fragment, rootPath, limit)
    local root = rootPath and (game:GetService(rootPath) or game) or game
    limit = limit or 200
    local out = {}
    local frag = string.lower(fragment)
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            if #out >= limit then break end
            if string.find(string.lower(d.Name), frag, 1, true) then
                out[#out+1] = { name = d.Name, class = d.ClassName, path = d:GetFullName() }
            end
        end
    end)
    return { count = #out, hits = out }
end

-- ============================================================
-- player snapshot
-- ============================================================
function AGENT.probe()
    local out = { player = LP and LP.Name, place = game.PlaceId, job = game.JobId }
    pcall(function()
        local ch = LP.Character
        if not ch then out.character = "nil (dead/loading)" return end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch:FindFirstChild("HumanoidRootPart")
        out.character = {
            health = hum and hum.Health,
            max_health = hum and hum.MaxHealth,
            walk_speed = hum and hum.WalkSpeed,
            pos = hrp and { X = hrp.Position.X, Y = hrp.Position.Y, Z = hrp.Position.Z }
        }
        local vals = {}
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("ValueBase") then
                local ok, v = pcall(function() return d.Value end)
                if ok then vals[d.Name] = conv(v) end
            end
        end
        out.character_values = vals
        local folders = {}
        for _, d in ipairs(ch:GetChildren()) do
            if d:IsA("Folder") then
                local names = {}
                for _, c in ipairs(d:GetChildren()) do names[#names+1] = c.Name end
                folders[d.Name] = names
            end
        end
        out.character_folders = folders
    end)
    pcall(function()
        local data = LP:FindFirstChild("Data")
        if data then
            local vals = {}
            for _, d in ipairs(data:GetDescendants()) do
                if d:IsA("ValueBase") then
                    local ok, v = pcall(function() return d.Value end)
                    if ok then vals[d.Name] = conv(v) end
                end
            end
            out.data = vals
        end
    end)
    pcall(function()
        if LP.Backpack then
            local tools = {}
            for _, t in ipairs(LP.Backpack:GetChildren()) do
                if t:IsA("Tool") then tools[#tools+1] = t.Name end
            end
            out.backpack = tools
        end
    end)
    return out
end

-- ============================================================
-- script inventory + bytecode dump
-- ============================================================
function AGENT.scripts()
    local out = {}
    local roots = {
        game:GetService("ReplicatedStorage"),
        game:GetService("StarterPlayer"),
        game:GetService("StarterGui"),
        game:GetService("ReplicatedFirst"),
        LP and LP:FindFirstChild("PlayerScripts"),
        LP and LP:FindFirstChild("PlayerGui"),
        game:GetService("Workspace"),
    }
    local seen = {}
    for _, root in ipairs(roots) do
        if root then
            pcall(function()
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("LuaSourceContainer") and not seen[d] then
                        seen[d] = true
                        local bc
                        if getscriptbytecode then
                            local okb, b = pcall(getscriptbytecode, d)
                            if okb and type(b) == "string" then bc = #b end
                        end
                        out[#out+1] = { path = d:GetFullName(), class = d.ClassName, bytes = bc }
                    end
                end
            end)
        end
    end
    return { count = #out, scripts = out }
end

function AGENT.dumpScript(fullPath, idx)
    if not getscriptbytecode then return { err = "getscriptbytecode missing" } end
    local ok, inst = pcall(function()
        local cur = game
        for part in string.gmatch(fullPath, "[^%.]+") do
            cur = cur:FindFirstChild(part)
            if not cur then error("not found: " .. part) end
        end
        return cur
    end)
    if not ok then return { err = "resolve failed: " .. tostring(inst) } end
    local okb, bc = pcall(getscriptbytecode, inst)
    if not okb or type(bc) ~= "string" then return { err = "bytecode failed: " .. tostring(bc) } end
    if not base64encode then return { err = "base64encode missing" } end
    local fname = string.format("sur_bc_%04d.b64", idx or 0)
    writefile(fname, base64encode(bc))
    return { file = fname, raw_bytes = #bc, path = fullPath }
end

-- ============================================================
-- DECOMPILE  (Xeno has `decompile`; Solara does not)
-- ============================================================
function AGENT.resolve(fullPath)
    local cur = game
    for part in string.gmatch(fullPath, "[^%.]+") do
        cur = cur:FindFirstChild(part)
        if not cur then error("missing: " .. part) end
    end
    return cur
end

-- decompile a list of script paths, write each to its own file
function AGENT.src(paths, prefix)
    prefix = prefix or "sur_src"
    if not decompile then return { err = "no decompile in this executor" } end
    local out = {}
    for i, path in ipairs(paths) do
        local ok, inst = pcall(AGENT.resolve, path)
        if not ok then
            out[#out+1] = { path = path, err = "resolve: " .. tostring(inst) }
        else
            local okd, src = pcall(decompile, inst)
            if okd and type(src) == "string" then
                local f = string.format("%s_%02d.lua", prefix, i)
                writefile(f, src)
                out[#out+1] = { path = path, file = f, len = #src }
            else
                out[#out+1] = { path = path, err = "decompile: " .. tostring(src) }
            end
        end
    end
    return out
end


-- Xeno lacks hookmetamethod/getrawmetatable/getnamecallmethod, so a
-- __namecall hook is impossible here. spyStart reports that honestly;
-- AGENT.src() (decompile) is the working alternative on this executor.
local SPY = { active = false, log = {}, cap = 400, count = 0 }
AGENT.spy = SPY

function AGENT.spyStart()
    if SPY.active then return { already = true, captured = SPY.count } end
    if not hookmetamethod then return { err = "no hookmetamethod in this executor" } end

    local ok, err = pcall(function()
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and (method == "FireServer" or method == "InvokeServer") then
                local args = { ... }
                SPY.count = SPY.count + 1
                if #SPY.log >= SPY.cap then table.remove(SPY.log, 1) end
                local ok2, path = pcall(function() return self:GetFullName() end)
                SPY.log[#SPY.log+1] = {
                    n = SPY.count,
                    t = os.time(),
                    m = method,
                    remote = ok2 and path or tostring(self),
                    cls = (pcall(function() return self.ClassName end)) and self.ClassName or "?",
                    args = conv(args, 0, {})
                }
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)
    if not ok then return { err = tostring(err) } end
    SPY.active = true
    return { started = true }
end

function AGENT.spyStop()
    -- hook stays installed but stops recording; safest for stability
    SPY.active = false
    return { stopped = true, captured = SPY.count }
end

function AGENT.spyGet(fromIdx)
    fromIdx = fromIdx or 1
    local out = {}
    for i = fromIdx, #SPY.log do out[#out+1] = SPY.log[i] end
    return { total = SPY.count, active = SPY.active, entries = out }
end

function AGENT.spyClear()
    SPY.log = {}
    SPY.count = 0
    return { cleared = true }
end

-- re-fire a captured call
function AGENT.replay(remotePath, args)
    local ok, inst = pcall(function()
        local cur = game
        for part in string.gmatch(remotePath, "[^%.]+") do
            cur = cur:FindFirstChild(part)
            if not cur then error("not found: " .. part) end
        end
        return cur
    end)
    if not ok then return { err = "resolve: " .. tostring(inst) } end
    local okf, res = pcall(function()
        if inst:IsA("RemoteEvent") then
            inst:FireServer(unpack(args or {}))
        elseif inst:IsA("RemoteFunction") then
            return inst:InvokeServer(unpack(args or {}))
        elseif inst:IsA("BindableEvent") then
            inst:Fire(unpack(args or {}))
        else
            error("not a remote: " .. inst.ClassName)
        end
        return true
    end)
    return { ok = okf, result = conv(res) }
end

-- ============================================================
-- runner
-- ============================================================
local function runChunk(code)
    local logs = {}
    local realPrint = print
    pcall(function()
        print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[#parts+1] = tostring(select(i, ...)) end
            logs[#logs+1] = table.concat(parts, " ")
            pcall(realPrint, ...)
        end
    end)
    local fn, compileErr = loadstring("return (function()\n" .. code .. "\nend)()")
    local ok, res
    if fn then ok, res = pcall(fn) else ok, res = false, "SYNTAX: " .. tostring(compileErr) end
    pcall(function() print = realPrint end)
    return ok, res, logs
end

local function writeAtomic(path, data)
    if isfile(path) then pcall(delfile, path) end
    writefile(path, data)
end

local function beat()
    pcall(function()
        writeAtomic(BEAT, HttpService:JSONEncode({
            t        = os.time(),
            place    = game.PlaceId,
            job      = game.JobId,
            player   = LP and LP.Name or "?",
            version  = AGENT.version,
            executor = (identifyexecutor and select(1, identifyexecutor())) or "?",
            uptime   = math.floor(os.clock()),
            spy      = SPY.count
        }))
    end)
end

beat()
AGENT.stop = function() AGENT.dead = true end

task.spawn(function()
    local lastBeat = 0
    while not AGENT.dead do
        pcall(function()
            if isfile(CMD) then
                local raw = readfile(CMD)
                pcall(delfile, CMD)
                if raw and #raw > 0 then
                    local parsed, req = pcall(function() return HttpService:JSONDecode(raw) end)
                    if parsed and req and req.code then
                        -- run in its own thread so heavy work never blocks the beat
                        task.spawn(function()
                            local ok, res, logs = runChunk(req.code)
                            local payload = encode({
                                id = req.id, ok = ok, out = conv(res), logs = logs,
                                place = game.PlaceId, player = LP and LP.Name or "?", t = os.time()
                            })
                            if #payload > 90000 then
                                local fname = "sur_out_" .. tostring(req.id) .. ".json"
                                writeAtomic(fname, payload)
                                payload = HttpService:JSONEncode({
                                    id = req.id, ok = ok, logs = logs,
                                    out = { __file = fname, size = #payload }
                                })
                            end
                            writeAtomic(RES, payload)
                        end)
                    end
                end
            end
            if os.clock() - lastBeat > 2 then
                lastBeat = os.clock()
                beat()
            end
        end)
        task.wait(0.2)
    end
end)

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "SUR Agent v4",
        Text  = "Bridge live. Xeno mode.",
        Duration = 4
    })
end)
print("[SUR Agent] v4 online | place=" .. tostring(game.PlaceId))
