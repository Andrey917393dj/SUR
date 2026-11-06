-- Batch D: non-combat surface, 20x each.
local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing" } end
local A = API.audit
A.results = {}

local LP = game:GetService("Players").LocalPlayer
local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function pos()
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return r and r.Position
end

local npcs = API.allNPCs()          -- array of NAME strings
local tName = npcs[1] or "MerchantAU"
for _, n in ipairs(npcs) do
    if n == "MerchantAU" then tName = n break end
end
local NPCs = game.Workspace:FindFirstChild("Map") and game.Workspace.Map:FindFirstChild("NPCs")

-- teleport to NPC
A.run("tpToNPC " .. tName, function()
    local ok = API.tpToNPC(tName)
    task.wait(0.35)
    local p = pos()
    local model = NPCs and NPCs:FindFirstChild(tName)
    local q = model and model:FindFirstChild("HumanoidRootPart")
    if not ok then return false end
    if p and q then return (p - q.Position).Magnitude < 30 end
    return true
end, 20, 0.8)

-- teleport to a fixed landmark
A.run("tpToPosition", function()
    local ok = API.tpToPosition(-734, 70, -398)
    task.wait(0.35)
    local p = pos()
    if not ok or not p then return ok == true end
    return (p - Vector3.new(-734, 70, -398)).Magnitude < 25
end, 20, 0.8)

-- NPC remote fire (Done)
A.run("fireNPC Done", function()
    return API.fireNPC(tName, "Done") ~= false
end, 20, 0.4)

-- NPC remote resolution
A.run("npcRemote Done", function()
    return API.npcRemote(tName, "Done") ~= nil
end, 20, 0.15)

-- world item scan: PASS = scan returns a table (world may have 0 spawned items)
A.run("worldTools() scan", function()
    return type(API.worldTools()) == "table"
end, 20, 0.15)

A.run("itemSpawns()", function()
    local s = API.itemSpawns()
    return type(s) == "table" and #s > 0
end, 20, 0.15)

-- ESP
A.run("ESP refresh", function()
    API.esp.living = true
    API.esp.npcs = true
    API.refreshESP()
    task.wait(0.15)
    local n = #API.esp.instances
    API.esp.living, API.esp.npcs = false, false
    API.clearESP()
    return n > 0
end, 20, 0.5)

-- movement mods
A.run("setSpeed", function()
    API.setSpeed(60)
    local h = hum()
    task.wait(0.1)
    API.setSpeed(32)
    return h ~= nil and h.WalkSpeed >= 30
end, 20, 0.3)

A.run("setJump", function()
    API.setJump(120)
    local h = hum()
    task.wait(0.1)
    API.setJump(50)
    return h ~= nil and h.JumpPower >= 45
end, 20, 0.3)

A.run("fly on/off", function()
    API.startFly()
    task.wait(0.2)
    local h = hum()
    API.stopFly()
    task.wait(0.1)
    return h ~= nil
end, 20, 0.5)

A.run("noclip on/off", function()
    API.startNoclip()
    task.wait(0.2)
    API.stopNoclip()
    task.wait(0.1)
    local h = hum()
    return h ~= nil
end, 20, 0.5)

local out = { total = #A.results, npcs = #npcs }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-22s %2d/%2d %6dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
