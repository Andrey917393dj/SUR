-- ═══════════════════════════════════════════════════════════════
-- ARCTIC SUR v2
-- Game : STAND UPRIGHT REBOOTED  (place 8540168650)
-- Every remote call in this file was verified in-game, not guessed.
-- ═══════════════════════════════════════════════════════════════

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local WS           = game:GetService("Workspace")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local StarterGui   = game:GetService("StarterGui")
local LP           = Players.LocalPlayer

local RS_EVENTS = RS:WaitForChild("Events", 30)

-- ═══════════════════════════════════════════════════════════════
-- SAFE NETWORK LAYER
-- ═══════════════════════════════════════════════════════════════
local function ev(name)
    return RS_EVENTS and RS_EVENTS:FindFirstChild(name)
end

local function fire(name, ...)
    local r = ev(name)
    if not r then return false, "missing remote: " .. tostring(name) end
    -- pcall passes varargs straight through; a nested closure cannot use '...'
    local ok, err = pcall(r.FireServer, r, ...)
    return ok, err
end

local function invoke(name, ...)
    local r = ev(name)
    if not r then return nil, "missing remote: " .. tostring(name) end
    local ok, res = pcall(r.InvokeServer, r, ...)
    if ok then return res end
    return nil, res
end

-- ═══════════════════════════════════════════════════════════════
-- SERVER ACK LISTENER  (our verification channel)
-- The server replies on CoolDownGUI with (moveName, cooldown).
-- ═══════════════════════════════════════════════════════════════
local ACK = { move = nil, cd = nil, at = 0 }
pcall(function()
    local cd = ev("CoolDownGUI")
    if cd then
        cd.OnClientEvent:Connect(function(name, value)
            ACK.move = tostring(name)
            ACK.cd   = value
            ACK.at   = os.clock()
        end)
    end
end)

local function ackReset()
    ACK.move, ACK.cd, ACK.at = nil, nil, 0
end

local function ackWait(timeout)
    timeout = timeout or 1.5
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if ACK.move then return ACK.move, ACK.cd end
        task.wait(0.05)
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER / STAND
-- ═══════════════════════════════════════════════════════════════
local function char()  return LP.Character end
local function hum()   local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp()   local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end

local function standFolder()
    local c = char()
    return c and c:FindFirstChild("StandEvents")
end

local function getMoveset()
    local se = standFolder()
    local info = se and se:FindFirstChild("Info")
    if not info then return {} end
    local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
    if ok and type(res) == "table" then return res end
    return {}
end

-- The verified move protocol: {State, Key, Type}
local function press(key, hold)
    local se = standFolder()
    if not se then return false, "no StandEvents (dead or loading?)" end
    local input = se:FindFirstChild("Input")
    if not input then return false, "no Input remote" end

    local isMouse = (key == Enum.UserInputType.MouseButton1
                  or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard

    local ok1 = pcall(function()
        input:FireServer({ State = "Begin", Key = key, Type = utype })
    end)
    if not ok1 then return false, "Begin failed" end

    if hold and hold > 0 then task.wait(hold) end

    pcall(function()
        input:FireServer({ State = "End", Key = key, Type = utype })
    end)
    return true
end

local function standName()
    local d = LP:FindFirstChild("Data")
    local s = d and d:FindFirstChild("Stand")
    if s then return tostring(s.Value) end
    return "None"
end

local function standAttri()
    local d = LP:FindFirstChild("Data")
    local a = d and d:FindFirstChild("Attri")
    if a then return tostring(a.Value) end
    return "None"
end

local function hasStand()
    local n = standName()
    return n ~= "" and n ~= "None"
end

-- ═══════════════════════════════════════════════════════════════
-- NPC LAYER
-- ═══════════════════════════════════════════════════════════════
local function npcFolder()
    local m = WS:FindFirstChild("Map")
    return m and m:FindFirstChild("NPCs")
end

local function npcObj(name)
    local f = npcFolder()
    return f and f:FindFirstChild(name)
end

local function npcRemote(name, which)
    local o = npcObj(name)
    if not o then return nil end
    return o:FindFirstChild(which or "Done")
end

local function fireNPC(name, which)
    local r = npcRemote(name, which)
    if not r then return false, "no " .. tostring(which or "Done") .. " on " .. tostring(name) end
    local ok, err = pcall(function() r:FireServer() end)
    return ok, err
end

local function allNPCs()
    local out = {}
    local f = npcFolder()
    if not f then return out end
    for _, n in ipairs(f:GetChildren()) do
        if n:IsA("Model") then out[#out + 1] = n.Name end
    end
    return out
end

-- ═══════════════════════════════════════════════════════════════
-- TELEPORT / MOVEMENT
-- ═══════════════════════════════════════════════════════════════
local function tpTo(cf)
    local p = hrp()
    if not p then return false, "no HumanoidRootPart" end
    pcall(function() p.CFrame = cf end)
    pcall(function() p.AssemblyLinearVelocity = Vector3.zero end)
    return true
end

local function tpToPart(part, offset)
    if not part then return false, "no part" end
    offset = offset or Vector3.new(0, 0, 3)
    return tpTo(CFrame.new(part.Position + offset))
end

local function tpToNPC(name)
    local o = npcObj(name)
    if not o then return false, "no NPC " .. tostring(name) end
    local p = o:FindFirstChild("HumanoidRootPart")
    if not p then return false, "NPC has no HRP" end
    return tpToPart(p, Vector3.new(0, 0, 4))
end

local function tpToPosition(x, y, z)
    return tpTo(CFrame.new(Vector3.new(x, y, z)))
end

-- ═══════════════════════════════════════════════════════════════
-- WORLD ITEMS
--   Workspace.Items / Workspace.Vfx  -> real Tool instances (only while spawned)
--   Workspace.ItemPromptHolder       -> static "Pick Up?" spawn markers
-- ═══════════════════════════════════════════════════════════════
local function itemSpawns()
    local out = {}
    for _, d in ipairs(WS:GetChildren()) do
        if d.Name == "ItemPromptHolder" then
            local p = d:FindFirstChildOfClass("ProximityPrompt")
            out[#out + 1] = { obj = d, part = d, prompt = p }
        end
    end
    return out
end

local function worldTools()
    local out = {}
    for _, folderName in ipairs({ "Items", "Vfx" }) do
        local f = WS:FindFirstChild(folderName)
        if f then
            for _, d in ipairs(f:GetChildren()) do
                if d:IsA("Tool") then
                    local handle = d:FindFirstChild("Handle") or d:FindFirstChildWhichIsA("BasePart")
                    out[#out + 1] = { name = d.Name, obj = d, part = handle }
                end
            end
        end
    end
    return out
end


local function grabItem(itemName)
    for _, t in ipairs(worldTools()) do
        if t.name == itemName and t.part then
            return tpToPart(t.part, Vector3.new(0, 2, 0))
        end
    end
    return false, "no " .. tostring(itemName) .. " in world"
end

local function useTool(toolName)
    local c, h = char(), hum()
    if not (c and h) then return false, "no character" end
    local tool = LP.Backpack:FindFirstChild(toolName) or c:FindFirstChild(toolName)
    if not tool then return false, "no " .. tostring(toolName) .. " in backpack" end

    if tool.Parent == LP.Backpack then
        pcall(function() h:EquipTool(tool) end)
        tool = c:WaitForChild(toolName, 3) or tool
    end
    task.wait(0.15)
    pcall(function() tool:Activate() end)
    local use = tool:FindFirstChild("Use")
    if use and use:IsA("RemoteEvent") then
        pcall(function() use:FireServer() end)
    end
    fire("UseItem", toolName)
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER MODS
-- ═══════════════════════════════════════════════════════════════
local Mods = { speed = false, speedValue = 32, jump = false, jumpValue = 80,
               fly = false, noclip = false, infJump = false }

local flyConn, flyBV, flyBG

local function setSpeed(v)
    local h = hum()
    if h then h.WalkSpeed = v end
end

local function setJump(v)
    local h = hum()
    if h then h.JumpPower = v; h.UseJumpPower = true end
end

local function startFly()
    local p = hrp()
    if not p then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = p
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1000
    bg.Parent = p
    flyBV, flyBG = bv, bg

    flyConn = RunService.RenderStepped:Connect(function()
        local cam = WS.CurrentCamera
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        local p2 = hrp()
        if p2 and flyBV then
            flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * 60 or Vector3.zero
            flyBG.CFrame = cam.CFrame
        end
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

local noclipConn
local function startNoclip()
    noclipConn = RunService.Stepped:Connect(function()
        local c = char()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

-- ═══════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════
local ESP = { living = false, npcs = false, instances = {} }

local function clearESP()
    for _, h in pairs(ESP.instances) do
        pcall(function() h:Destroy() end)
    end
    ESP.instances = {}
end

local function makeHighlight(obj, color)
    local h = Instance.new("Highlight")
    h.FillColor = color
    h.FillTransparency = 0.55
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = obj
    h.Parent = obj
    return h
end

local function refreshESP()
    clearESP()
    if ESP.living then
        local living = WS:FindFirstChild("Living")
        if living then
            for _, m in ipairs(living:GetChildren()) do
                if m:IsA("Model") and m ~= char() then
                    local ok, h = pcall(makeHighlight, m, Color3.fromRGB(255, 60, 60))
                    if ok then ESP.instances[#ESP.instances + 1] = h end
                end
            end
        end
    end
    if ESP.npcs then
        local f = npcFolder()
        if f then
            for _, m in ipairs(f:GetChildren()) do
                if m:IsA("Model") then
                    local ok, h = pcall(makeHighlight, m, Color3.fromRGB(60, 200, 255))
                    if ok then ESP.instances[#ESP.instances + 1] = h end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- AUDIT HARNESS
-- Runs a function N times, records pass/fail, prints a table.
-- ═══════════════════════════════════════════════════════════════
local Audit = { results = {} }

function Audit.run(label, fn, times, gap)
    times = times or 20
    gap = gap or 0.25
    local pass, fail = 0, 0
    local errs = {}
    local t0 = os.clock()

    for i = 1, times do
        local ok, res = pcall(fn)
        if ok and res ~= false then
            pass = pass + 1
        else
            fail = fail + 1
            local msg = ok and "returned false" or tostring(res)
            errs[#errs + 1] = "[" .. i .. "] " .. msg
        end
        task.wait(gap)
    end

    local rec = {
        label = label, pass = pass, fail = fail,
        total = times, ms = math.floor((os.clock() - t0) * 1000),
        errors = errs
    }
    Audit.results[#Audit.results + 1] = rec

    local line = string.format("%-28s %2d/%2d  %dms", label, pass, times, rec.ms)
    print("[AUDIT] " .. line)
    for _, e in ipairs(errs) do print("        " .. e) end

    if CreateNotification then
        CreateNotification("Audit", line, { Duration = 4 })
    end
    return rec
end

function Audit.report()
    local ok, fail = 0, 0
    for _, r in ipairs(Audit.results) do
        ok = ok + r.pass
        fail = fail + r.fail
    end
    print("════════ AUDIT REPORT ════════")
    for _, r in ipairs(Audit.results) do
        print(string.format("  %-28s %2d/%2d", r.label, r.pass, r.total))
    end
    print(string.format("  TOTAL: %d pass, %d fail", ok, fail))
    return Audit.results
end

-- ═══════════════════════════════════════════════════════════════
-- FAKE PROFILE  (/check bait + fake stand model)
-- Everything the /check card prints is read from objects the client
-- already owns:  Player.Data.Stand / .Attri / .GUID,
-- Character.Stats.AttackDmg, Character.DmgBoostAttri, Humanoid.MaxHealth.
-- ReplicatedStorage.StandNameConvert maps the stand code to the pretty name.
-- ═══════════════════════════════════════════════════════════════
local Fake = {
    active = false,
    stand = nil, attri = nil, guid = nil,
    health = nil, dmg = nil, boost = nil,
    model = nil, relCFrame = nil, thread = nil,
    saved = nil,
}

local function rs()
    return game:GetService("ReplicatedStorage")
end

-- ── catalogues pulled out of the game itself ───────────────────
local function standCatalog()
    local out = {}
    local snc = rs():FindFirstChild("StandNameConvert")
    if snc then
        for _, v in ipairs(snc:GetChildren()) do
            out[#out + 1] = { code = v.Name, pretty = tostring(v.Value) }
        end
    end
    table.sort(out, function(a, b) return a.code < b.code end)
    return out
end

local function standPretty(code)
    local snc = rs():FindFirstChild("StandNameConvert")
    local v = snc and snc:FindFirstChild(tostring(code))
    return v and tostring(v.Value) or tostring(code)
end

local function attriCatalog()
    local out, seen = {}, {}

    -- 1. the in-world chances board lists every attribute the game knows
    local ok = pcall(function()
        local board = WS.Map.ChancesBoards.AttributeChances.newSurface.ScrollFrame
        for _, v in ipairs(board:GetChildren()) do
            if v:IsA("TextLabel") then
                local name = string.split(v.Text, " ")[1]
                if name == "Glass" then name = "Glass Cannon" end
                if name and name ~= "" and not seen[name] then
                    seen[name] = true
                    out[#out + 1] = name
                end
            end
        end
    end)

    -- 2. any folder of StringValues the build might ship
    if #out == 0 then
        for _, holderName in ipairs({ "AttriList", "Attributes", "AttriNames", "RarityList" }) do
            local h = rs():FindFirstChild(holderName)
            if h then
                for _, c in ipairs(h:GetChildren()) do
                    if (c:IsA("StringValue") or c:IsA("Folder")) and not seen[c.Name] then
                        seen[c.Name] = true
                        out[#out + 1] = c.Name
                    end
                end
            end
        end
    end

    -- 3. last resort so the UI is never empty
    if #out == 0 then
        out = { "None", "Weak", "Normal", "Good", "Great", "Excellent",
                "Perfect", "Legendary", "Mythical", "Godly", "Divine" }
    end
    table.sort(out)
    return out
end

-- ── the stats panel on the left of the screen ──────────────────
-- It is built from the same Data values /check reads, but it is a plain
-- tree of TextLabels, so we can also rewrite the labels themselves. That
-- keeps the panel honest even when a value is not backed by a Value object.
local HUD = { saved = {}, orig = {} }

local function hudStats()
    local ok, frame = pcall(function()
        return LP.PlayerGui.PlayerGUI.ingame.Stats
    end)
    if ok and frame then return frame end
    return nil
end

local function hudLabels()
    local out = {}
    local f = hudStats()
    if not f then return out end
    for _, d in ipairs(f:GetDescendants()) do
        if d:IsA("TextLabel") then out[#out + 1] = d end
    end
    return out
end

local function hudSnapshot()
    HUD.saved, HUD.orig = {}, {}
    for _, l in ipairs(hudLabels()) do
        HUD.saved[l] = l.Text
        HUD.orig[l] = l.Text
    end
end

local function hudApply()
    if not next(HUD.saved) then return end
    local st = statsFolder()
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    local dmg = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value or 0
    local realDmg = math.floor(dmg * (db and db.Value or 1))

    local map = {}
    if Fake.stand and HUD.realStand then map[HUD.realStand] = standPretty(Fake.stand) end
    if Fake.attri and HUD.realAttri then map[HUD.realAttri] = Fake.attri end
    if Fake.health and HUD.realHealth then map[tostring(HUD.realHealth)] = tostring(Fake.health) end
    if Fake.dmg and HUD.realDmg then map[tostring(HUD.realDmg)] = tostring(Fake.dmg) end

    for label, original in pairs(HUD.saved) do
        if label.Parent then
            local want = map[original]
            if want and label.Text ~= want then
                pcall(function() label.Text = want end)
            end
        end
    end
end

local function hudRestore()
    for label, original in pairs(HUD.saved) do
        if label.Parent then pcall(function() label.Text = original end) end
    end
    HUD.saved, HUD.orig = {}, {}
end

-- ── write / restore ────────────────────────────────────────────
local function dataValue(name)
    local d = LP:FindFirstChild("Data")
    return d and d:FindFirstChild(name)
end

local function statsFolder()
    local c = char()
    return c and c:FindFirstChild("Stats")
end

-- The HUD panel (same one /check mirrors) shows the PRETTY stand name.
local function standGuiName()
    local ok, text = pcall(function()
        return LP.PlayerGui.PlayerGUI.ingame.Stats.StandName.Name_.TextLabel.Text
    end)
    if not ok or text == nil or text == "" then return "None" end
    return text
end

-- forward declaration: makePicker calls restyle() after it builds a new menu,
-- and restyle itself is defined further down (it needs the whole tree first).
local restyle

-- Rows of pick buttons in a dedicated menu. One click = one value, no typing.
local PICKERS = {}
local function makePicker(menuName, entries, onPick)
    if PICKERS[menuName] then
        -- already built: just point the existing buttons at the new callback
        PICKERS[menuName].onPick = onPick
        return PICKERS[menuName].count
    end
    CreateMenu(menuName)
    local box = { onPick = onPick, count = 0, items = {} }
    PICKERS[menuName] = box
    for _, e in ipairs(entries) do
        if box.count >= 400 then break end
        box.count = box.count + 1
        box.items[#box.items + 1] = e
        CreateButton(tostring(e), menuName, function()
            box.onPick(e)
        end)
    end
    if box.count == 0 then CreateNote("empty", menuName) end
    if restyle then pcall(restyle) end
    return box.count
end

local function fakeApply()
    local s = dataValue("Stand"); if s and Fake.stand then s.Value = Fake.stand end
    local a = dataValue("Attri"); if a and Fake.attri then a.Value = Fake.attri end
    local g = dataValue("GUID");  if g and Fake.guid  then g.Value = Fake.guid end

    local st = statsFolder()
    if st then
        local d = st:FindFirstChild("AttackDmg")
        if d and Fake.dmg then d.Value = Fake.dmg end
    end
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    if db and Fake.boost then db.Value = Fake.boost end
    local h = hum()
    if h and Fake.health then
        h.MaxHealth = Fake.health
        h.Health = Fake.health
    end
end

local function fakeSnapshot()
    local st = statsFolder()
    Fake.saved = {
        stand = dataValue("Stand") and dataValue("Stand").Value,
        attri = dataValue("Attri") and dataValue("Attri").Value,
        guid  = dataValue("GUID")  and dataValue("GUID").Value,
        dmg   = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value,
        boost = char() and char():FindFirstChild("DmgBoostAttri")
                and char().DmgBoostAttri.Value,
        health = hum() and hum().MaxHealth,
    }

    -- the HUD labels as they are right now: this is what has to be rewritten
    HUD.realStand  = standGuiName()
    HUD.realAttri  = Fake.saved.attri
    HUD.realHealth = Fake.saved.health
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    HUD.realDmg    = math.floor((Fake.saved.dmg or 0) * (db and db.Value or 1))
    hudSnapshot()
end

local function fakeRestore()
    local s = Fake.saved
    if not s then return end
    local v
    v = dataValue("Stand"); if v and s.stand then v.Value = s.stand end
    v = dataValue("Attri"); if v and s.attri then v.Value = s.attri end
    v = dataValue("GUID");  if v and s.guid  then v.Value = s.guid  end
    local st = statsFolder()
    if st and s.dmg then
        v = st:FindFirstChild("AttackDmg"); if v then v.Value = s.dmg end
    end
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    if db and s.boost then db.Value = s.boost end
    local h = hum()
    if h and s.health then h.MaxHealth = s.health; h.Health = s.health end
end

-- ── fake stand model ───────────────────────────────────────────
local function fakeStandClear()
    if Fake.model then
        pcall(function() Fake.model:Destroy() end)
    end
    Fake.model, Fake.relCFrame = nil, nil
end

local function findStandSource(code)
    local living = WS:FindFirstChild("Living")
    -- 1. another player already running that stand
    if living then
        for _, plr in ipairs(living:GetChildren()) do
            local m = plr:FindFirstChild("Stand")
            if m and m:IsA("Model") then
                local d = plr:FindFirstChild("Data")
                local sv = d and d:FindFirstChild("Stand")
                if code and sv and sv.Value == code then return m end
                if not code and plr.Name == LP.Name then return m end
            end
        end
    end
    -- 2. a stored model named exactly like the code
    if code then
        for _, folderName in ipairs({ "Storage", "QuestAssets", "UIStorage", "Vfx" }) do
            local f = WS:FindFirstChild(folderName)
            local m = f and f:FindFirstChild(code)
            if m and m:IsA("Model") then return m end
        end
        local m = rs():FindFirstChild(code)
        if m and m:IsA("Model") then return m end
    end
    -- 3. fall back to our own stand
    if living then
        local me = living:FindFirstChild(LP.Name)
        return me and me:FindFirstChild("Stand") or nil
    end
    return nil
end

local function fakeStandSpawn(code, side)
    fakeStandClear()
    local src = findStandSource(code)
    if not src then return false, "no stand model to clone" end

    local m = src:Clone()
    m.Name = "SUR_FakeStand"
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BaseScript") or d:IsA("Script") or d:IsA("LocalScript") then
            pcall(function() d.Enabled = false end)
        elseif d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
        elseif d:IsA("Humanoid") then
            d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    m.Parent = WS

    local r = hrp()
    if not r then return false, "no HumanoidRootPart" end
    side = side or 1
    m:PivotTo(r.CFrame * CFrame.new(3 * side, 0, 0))
    Fake.model = m
    Fake.relCFrame = r.CFrame:ToObjectSpace(m:GetPivot())
    return true
end

local function fakeStandTrack()
    local m, rel = Fake.model, Fake.relCFrame
    local r = hrp()
    if not (m and rel and r) then return end
    if not m.Parent then Fake.model = nil; return end
    pcall(function() m:PivotTo(r.CFrame * rel) end)
end

-- ── the loop that keeps the lie alive ──────────────────────────
local function fakeStart()
    if Fake.active then return end
    fakeSnapshot()
    Fake.active = true
    Fake.thread = task.spawn(function()
        while Fake.active do
            pcall(fakeApply)
            pcall(hudApply)
            pcall(fakeStandTrack)
            task.wait(0.2)
        end
    end)
end

local function fakeStop()
    Fake.active = false
    Fake.thread = nil
    fakeStandClear()
    pcall(hudRestore)
    pcall(fakeRestore)
end

-- ═══════════════════════════════════════════════════════════════
-- FARM ENGINE
-- Old builds glued the character to a boss and spammed
-- StandEvents.M1 / Summon. Those remotes are gone, so the loop now
-- drives press() on the verified StandEvents.Input protocol.
-- ═══════════════════════════════════════════════════════════════
local Farm = {
    target = nil, distance = 4, underneath = false,
    running = false, thread = nil,
    useMoves = true, pauseOn = false, pauseLen = 0.4,
    heavyEvery = 1.0, _lastHeavy = 0,
    heavyKeys = { "E", "R", "T" },
    instaKill = false,
    kills = 0, startedAt = 0,
}

local function farmLiving(name)
    local living = WS:FindFirstChild("Living")
    return living and living:FindFirstChild(name) or nil
end

local function farmStop()
    Farm.running = false
    Farm.thread = nil
end

-- Local write of Humanoid.Health. Works only where the server does not
-- replicate health down to clients; wrapped so a rejection just falls
-- through to the normal M1 loop.
local function instaKill(model)
    if not model then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    if h.Health <= 0 then return true end
    local ok = pcall(function() h.Health = 0 end)
    return ok and h.Health <= 0
end

local function farmStep(name)
    local t = farmLiving(name)
    if not t then return false end
    local thp = t:FindFirstChild("HumanoidRootPart")
    local r = hrp()
    if not (thp and r) then return false end

    -- face the target: M1 and the stand only land when the camera looks at it
    local pos = Farm.underneath
        and (thp.Position + Vector3.new(0, -Farm.distance, Farm.distance))
        or  (thp.Position + Vector3.new(0, 0, Farm.distance))
    pcall(function() r.CFrame = CFrame.lookAt(pos, thp.Position) end)
    pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)

    -- keep the stand out
    local aura = char() and char():FindFirstChild("Aura")
    if aura and aura.Value == false then press(Enum.KeyCode.Q) end
    local stand = char() and char():FindFirstChild("Stand")
    if stand and stand:FindFirstChild("HumanoidRootPart") then
        pcall(function() stand.HumanoidRootPart.CFrame = r.CFrame end)
    end

    if Farm.instaKill and instaKill(t) then
        Farm.kills = Farm.kills + 1
        return true
    end

    press(Enum.UserInputType.MouseButton1)

    if Farm.useMoves then
        local now = os.clock()
        if now - Farm._lastHeavy >= Farm.heavyEvery then
            Farm._lastHeavy = now
            for _, k in ipairs(Farm.heavyKeys or {}) do
                local kc = Enum.KeyCode[k]
                if kc then press(kc) end
            end
        end
    end
    return true
end

local function farmStart(name)
    farmStop()
    Farm.target = name
    Farm.running = true
    Farm.startedAt = os.clock()
    Farm.kills = 0
    Farm.thread = task.spawn(function()
        -- wait for the target to exist before spinning
        repeat task.wait(0.25) until not Farm.running or farmLiving(name)
        while Farm.running do
            local ok = pcall(farmStep, name)
            if not ok then farmStop() break end
            task.wait(Farm.pauseOn and Farm.pauseLen or 0.05)
        end
    end)
end

-- ── live target discovery (no typing) ─────────────────────────
local function livingTargets()
    local out = {}
    local living = WS:FindFirstChild("Living")
    if not living then return out end
    for _, m in ipairs(living:GetChildren()) do
        if m:IsA("Model") and m ~= char()
           and m:FindFirstChildOfClass("Humanoid")
           and m:FindFirstChild("HumanoidRootPart") then
            out[#out + 1] = m.Name
        end
    end
    table.sort(out)
    return out
end


-- ═══════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════
Start("Arctic SUR v2")

-- ═══════════════════════════════════════════════════════════════
-- RESTYLE
-- The stock lib lays out a 2019-sized 501x273 box with 23px rows and
-- 148px labels, so every control looks cramped and the toggle pills sit
-- in the middle of the row. This pass re-proportions the whole tree:
--   720x470 window · 200px sidebar · 36px title bar · 30px rows ·
--   full-width labels · right-aligned toggles and inputs ·
--   accent-coloured section headers · ordered sidebar.
-- It is idempotent and safe to call again after a picker is built.
-- ═══════════════════════════════════════════════════════════════
local ACCENT     = Color3.fromRGB(124, 106, 255)
local ROWBG      = Color3.fromRGB(24, 24, 30)
local MUTED      = Color3.fromRGB(150, 150, 170)
local TEXT_MAIN  = Color3.fromRGB(236, 236, 246)

-- most-used first; anything not listed (pickers) lands next to its parent
local SIDEBAR_ORDER = {
    ["Home"] = 1, ["Combat"] = 2, ["Boss Farm"] = 3, ["Lair Farm"] = 4,
    ["Quest Farm"] = 5, ["Stand Farm"] = 6, ["Item Farm"] = 7,
    ["Farm Settings"] = 8, ["Teleports"] = 9, ["Shop"] = 10, ["Stand"] = 11,
    ["Items"] = 12, ["Player"] = 13, ["LocalPlayer"] = 14,
    ["NPC & Quest"] = 15, ["Visuals"] = 16, ["Fake"] = 17,
    ["Diagnostics"] = 18,
}

local function uiCorner(obj, radius)
    local c = obj:FindFirstChildOfClass("UICorner")
    if not c then c = Instance.new("UICorner"); c.Parent = obj end
    c.CornerRadius = UDim.new(0, radius)
end

local function uiPad(obj, l, t, r, b)
    local p = obj:FindFirstChildOfClass("UIPadding")
    if not p then p = Instance.new("UIPadding"); p.Parent = obj end
    p.PaddingLeft   = UDim.new(0, l)
    p.PaddingTop    = UDim.new(0, t)
    p.PaddingRight  = UDim.new(0, r)
    p.PaddingBottom = UDim.new(0, b)
end

-- one row inside a menu pane: button / toggle / textbox / note
local function styleRow(item)
    local isNote = item:IsA("TextLabel")
    item.BackgroundColor3 = ROWBG
    item.BackgroundTransparency = isNote and 1 or 0
    item.AutoButtonColor = not isNote

    local label = item:FindFirstChildOfClass("TextLabel")
    local box   = item:FindFirstChildOfClass("TextBox")
    local pill  = nil
    for _, ch in ipairs(item:GetChildren()) do
        if ch:IsA("Frame") and not pill then pill = ch end
    end

    -- ── note: either a small accent section header or muted helper text ──
    if isNote then
        item.Size = UDim2.new(1, 0, 0, 20)
        item.AutomaticSize = Enum.AutomaticSize.Y
        if label then
            local txt = tostring(label.Text or "")
            local isHeader = (#txt > 0) and (#txt <= 34) and (not txt:find("%."))
            label.Position = UDim2.new(0, 4, 0, 0)
            label.Size = UDim2.new(1, -8, 0, 18)
            label.AutomaticSize = Enum.AutomaticSize.Y
            label.TextScaled = false
            label.TextWrapped = true
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.TextYAlignment = Enum.TextYAlignment.Center
            if isHeader then
                label.TextSize = 13
                label.Font = Enum.Font.GothamBold
                label.TextColor3 = ACCENT
            else
                label.TextSize = 12
                label.Font = Enum.Font.Gotham
                label.TextColor3 = MUTED
            end
        end
        return
    end

    item.Size = UDim2.new(1, 0, 0, 30)
    uiCorner(item, 6)

    -- ── textbox row: label left, input right ──
    if box then
        if label then
            label.Position = UDim2.new(0, 10, 0, 0)
            label.Size = UDim2.new(0.52, -14, 1, 0)
            label.TextSize = 12
            label.Font = Enum.Font.Gotham
            label.TextColor3 = TEXT_MAIN
            label.TextXAlignment = Enum.TextXAlignment.Left
        end
        box.Position = UDim2.new(0.55, 0, 0.5, -9)
        box.Size = UDim2.new(0.45, -12, 0, 18)
        box.TextSize = 11
        box.TextWrapped = false
        box.TextXAlignment = Enum.TextXAlignment.Center
        box.BackgroundColor3 = Color3.fromRGB(10, 10, 13)
        uiCorner(box, 5)
        return
    end

    -- ── toggle row: label left, pill on the right edge ──
    if pill then
        if label then
            label.Position = UDim2.new(0, 10, 0, 0)
            label.Size = UDim2.new(1, -76, 1, 0)
            label.TextSize = 12
            label.Font = Enum.Font.Gotham
            label.TextColor3 = TEXT_MAIN
            label.TextXAlignment = Enum.TextXAlignment.Left
        end
        pill.Position = UDim2.new(1, -58, 0.5, -9)
        pill.Size = UDim2.new(0, 46, 0, 18)
        uiCorner(pill, 9)
        return
    end

    -- ── plain button row ──
    if label then
        label.Position = UDim2.new(0, 10, 0, 0)
        label.Size = UDim2.new(1, -20, 1, 0)
        label.TextSize = 12
        label.Font = Enum.Font.Gotham
        label.TextColor3 = TEXT_MAIN
        label.TextXAlignment = Enum.TextXAlignment.Left
    end
end

local function styleSidebar(handler)
    handler.Position = UDim2.new(0, 0, 0, 0)
    handler.Size = UDim2.new(1, 0, 1, 0)
    handler.CanvasSize = UDim2.new(0, 0, 0, 0)
    handler.AutomaticCanvasSize = Enum.AutomaticSize.Y
    handler.ScrollBarThickness = 3
    handler.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 90)
    uiPad(handler, 6, 6, 6, 10)

    local layout = handler:FindFirstChildOfClass("UIListLayout")
    if layout then
        layout.Padding = UDim.new(0, 3)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    end

    local extra = 0
    for _, b in ipairs(handler:GetChildren()) do
        if b:IsA("TextButton") then
            b.Size = UDim2.new(1, 0, 0, 30)
            b.Font = Enum.Font.Gotham
            b.TextSize = 12
            b.TextXAlignment = Enum.TextXAlignment.Center
            uiCorner(b, 6)
            local base = SIDEBAR_ORDER[b.Text]
            if base then
                b.LayoutOrder = base * 10
            else
                -- picker menus ("Fake: Stands") sit right under their parent
                local parentName = tostring(b.Text):match("^(.-):")
                local pBase = parentName and SIDEBAR_ORDER[parentName]
                extra = extra + 1
                b.LayoutOrder = pBase and (pBase * 10 + 5) or (900 + extra)
            end
        end
    end
end

restyle = function()
    local ok, err = pcall(function()
        local gui = getgenv and getgenv().ArcticScreenGui
        if not gui then return end
        local frame = gui:FindFirstChildOfClass("Frame")
        if not frame then return end
        local hotbar  = frame:FindFirstChild("Hotbar")
        local buttons = frame:FindFirstChild("Buttons")
        local menus   = frame:FindFirstChild("Menus")
        if not (hotbar and buttons and menus) then return end
        local handler = buttons:FindFirstChild("Handler")

        local W, H, SIDE, BAR = 720, 470, 200, 36

        -- window
        frame.Size = UDim2.new(0, W, 0, H)
        frame.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)
        frame.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
        uiCorner(frame, 8)
        local stroke = frame:FindFirstChild("SURStroke")
        if not stroke then
            stroke = Instance.new("UIStroke")
            stroke.Name = "SURStroke"
            stroke.Parent = frame
        end
        stroke.Color = Color3.fromRGB(54, 54, 70)
        stroke.Thickness = 1

        -- title bar
        hotbar.Size = UDim2.new(1, 0, 0, BAR)
        hotbar.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        uiCorner(hotbar, 8)
        local title = hotbar:FindFirstChildOfClass("TextLabel")
        if title then
            title.Position = UDim2.new(0, 14, 0, 0)
            title.Size = UDim2.new(1, -60, 1, 0)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 14
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.TextColor3 = Color3.fromRGB(242, 242, 250)
        end
        local close = hotbar:FindFirstChildOfClass("ImageButton")
        if close then
            close.Position = UDim2.new(1, -32, 0, 8)
            close.Size = UDim2.new(0, 20, 0, 20)
        end

        -- sidebar
        buttons.Position = UDim2.new(0, 0, 0, BAR)
        buttons.Size = UDim2.new(0, SIDE, 1, -BAR)
        buttons.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
        uiCorner(buttons, 8)
        if handler then styleSidebar(handler) end

        -- content area
        menus.Position = UDim2.new(0, SIDE, 0, BAR)
        menus.Size = UDim2.new(1, -SIDE, 1, -BAR)

        for _, pane in ipairs(menus:GetChildren()) do
            if pane:IsA("ScrollingFrame") then
                pane.Position = UDim2.new(0, 0, 0, 0)
                pane.Size = UDim2.new(1, 0, 1, 0)
                pane.CanvasSize = UDim2.new(0, 0, 0, 0)
                pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
                pane.ScrollBarThickness = 3
                pane.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 90)
                uiPad(pane, 10, 8, 10, 14)
                local lay = pane:FindFirstChildOfClass("UIListLayout")
                if lay then
                    lay.Padding = UDim.new(0, 3)
                    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
                end
                for _, item in ipairs(pane:GetChildren()) do
                    if item:IsA("TextButton") or item:IsA("TextLabel") then
                        pcall(styleRow, item)
                    end
                end
            end
        end
    end)
    if not ok then warn("[SUR restyle] " .. tostring(err)) end
end

-- ── HOME ──────────────────────────────────────────────────────
CreateMenu("Home")
CreateNote("STAND UPRIGHT REBOOTED - place 8540168650", "Home")
CreateNote("Combat uses StandEvents.Input (verified)", "Home")
CreateButton("Print Player Snapshot", "Home", function()
    print("Stand:", standName(), "| Attri:", standAttri(),
          "| Moveset:", #getMoveset(), "keys")
    local d = LP:FindFirstChild("Data")
    if d then
        for _, v in ipairs(d:GetChildren()) do
            if v:IsA("ValueBase") and (v.Name == "Level" or v.Name == "Cash"
               or v.Name == "Exp" or v.Name == "SkillPoints") then
                print("  " .. v.Name .. " = " .. tostring(v.Value))
            end
        end
    end
    CreateNotification("Arctic", standName() .. " [" .. standAttri() .. "]", { Duration = 5 })
end)
CreateButton("Run Full Audit (x20)", "Home", function()
    task.spawn(function()
        Audit.results = {}
        Audit.run("press M1 (punch)", function() return press(Enum.UserInputType.MouseButton1) end, 20, 0.4)
        Audit.run("press Q (summon)", function() return press(Enum.KeyCode.Q) end, 20, 1.7)
        Audit.run("press E (barrage)", function() return press(Enum.KeyCode.E) end, 20, 7.2)
        Audit.run("press G (block)", function() return press(Enum.KeyCode.G, 0.2) end, 20, 1.2)
        Audit.run("moveset fetch", function()
            local m = getMoveset()
            return type(m) == "table" and #m > 0
        end, 20, 0.2)
        Audit.run("GetStandTier", function()
            local v = invoke("GetStandTier", standName())
            return v ~= nil
        end, 20, 0.2)
        Audit.report()
        CreateNotification("Audit", "Finished - see console", { Duration = 8 })
    end)
end)

-- ── COMBAT ────────────────────────────────────────────────────
CreateMenu("Combat")

local AutoAttack = false
CreateToggle("Auto Attack (M1)", "Combat", function()
    AutoAttack = not AutoAttack
    if AutoAttack then
        task.spawn(function()
            while AutoAttack do
                press(Enum.UserInputType.MouseButton1)
                task.wait(0.36)
            end
        end)
    end
end)

local AutoBarrage = false
CreateToggle("Auto Barrage (E)", "Combat", function()
    AutoBarrage = not AutoBarrage
    if AutoBarrage then
        task.spawn(function()
            while AutoBarrage do
                press(Enum.KeyCode.E)
                task.wait(7.2)
            end
        end)
    end
end)

local AutoHeavy = false
CreateToggle("Auto Heavy Punch (R)", "Combat", function()
    AutoHeavy = not AutoHeavy
    if AutoHeavy then
        task.spawn(function()
            while AutoHeavy do
                press(Enum.KeyCode.R)
                task.wait(8.2)
            end
        end)
    end
end)

local AutoCombo = false
CreateToggle("Auto Combo (M1/E/R/T/X/H)", "Combat", function()
    AutoCombo = not AutoCombo
    if AutoCombo then
        task.spawn(function()
            local order = {
                { Enum.UserInputType.MouseButton1, 0.4 },
                { Enum.UserInputType.MouseButton1, 0.4 },
                { Enum.KeyCode.E, 7.2 },
                { Enum.KeyCode.R, 8.2 },
                { Enum.KeyCode.T, 8.2 },
                { Enum.KeyCode.X, 8.2 },
                { Enum.KeyCode.H, 6.2 },
            }
            while AutoCombo do
                for _, step in ipairs(order) do
                    if not AutoCombo then break end
                    press(step[1])
                    task.wait(step[2])
                end
            end
        end)
    end
end)

CreateButton("Summon (Q)", "Combat", function() press(Enum.KeyCode.Q) end)
CreateButton("Barrage (E)", "Combat", function() press(Enum.KeyCode.E) end)
CreateButton("Heavy Punch (R)", "Combat", function() press(Enum.KeyCode.R) end)
CreateButton("Bearing Shots (T)", "Combat", function() press(Enum.KeyCode.T) end)
CreateButton("Timeskip (H)", "Combat", function() press(Enum.KeyCode.H) end)
CreateButton("Counter (X)", "Combat", function() press(Enum.KeyCode.X) end)
CreateButton("Block (G)", "Combat", function() press(Enum.KeyCode.G, 0.5) end)
CreateButton("Quote (N)", "Combat", function() press(Enum.KeyCode.N) end)
CreateButton("Show Moveset", "Combat", function()
    local m = getMoveset()
    local parts = {}
    for _, k in ipairs(m) do parts[#parts + 1] = tostring(k):gsub("Enum.", "") end
    print("[Moveset] " .. table.concat(parts, ", "))
    CreateNotification("Moveset", #m .. " keys", { Duration = 4 })
end)

-- ── NPC / QUEST ───────────────────────────────────────────────
CreateMenu("NPC & Quest")

local LastNPC = "admpn"
CreateTextBox("NPC (target)", "NPC & Quest", { CustomText = "admpn", AutoUpdate = true }, function(t)
    LastNPC = t
end)

CreateButton("Fire Done on NPC", "NPC & Quest", function()
    local ok, err = fireNPC(LastNPC, "Done")
    CreateNotification("NPC", tostring(LastNPC) .. " Done: " .. tostring(ok), { Duration = 3 })
    if not ok then warn(err) end
end)

CreateButton("Fire QuestDone on NPC", "NPC & Quest", function()
    local ok, err = fireNPC(LastNPC, "QuestDone")
    CreateNotification("NPC", tostring(LastNPC) .. " QuestDone: " .. tostring(ok), { Duration = 3 })
    if not ok then warn(err) end
end)

CreateButton("Fire Done on ALL NPCs", "NPC & Quest", function()
    task.spawn(function()
        local ok, fail = 0, 0
        for _, n in ipairs(allNPCs()) do
            local r = npcRemote(n, "Done")
            if r then
                if pcall(function() r:FireServer() end) then ok = ok + 1 else fail = fail + 1 end
                task.wait(0.12)
            end
        end
        CreateNotification("NPC", ok .. " fired, " .. fail .. " failed", { Duration = 5 })
    end)
end)

CreateButton("Fire QuestDone on ALL NPCs", "NPC & Quest", function()
    task.spawn(function()
        local ok, fail = 0, 0
        for _, n in ipairs(allNPCs()) do
            local r = npcRemote(n, "QuestDone")
            if r then
                if pcall(function() r:FireServer() end) then ok = ok + 1 else fail = fail + 1 end
                task.wait(0.12)
            end
        end
        CreateNotification("NPC", ok .. " quest fired, " .. fail .. " failed", { Duration = 5 })
    end)
end)

local AutoQuest = false
CreateToggle("Auto Quest Loop", "NPC & Quest", function()
    AutoQuest = not AutoQuest
    if AutoQuest then
        task.spawn(function()
            while AutoQuest do
                for _, n in ipairs(allNPCs()) do
                    if not AutoQuest then break end
                    local d = npcRemote(n, "Done")
                    if d then pcall(function() d:FireServer() end) end
                    local q = npcRemote(n, "QuestDone")
                    if q then pcall(function() q:FireServer() end) end
                    task.wait(0.35)
                end
                task.wait(2)
            end
        end)
    end
end)

-- ── SHOP ──────────────────────────────────────────────────────
CreateMenu("Shop")

local ShopId = "MerchantAU"
CreateTextBox("Shop ID", "Shop", { CustomText = "MerchantAU", AutoUpdate = true }, function(t)
    ShopId = t
end)

for i = 1, 4 do
    CreateButton("Buy Option" .. i, "Shop", function()
        local ok, err = fire("BuyItem", ShopId, "Option" .. i)
        CreateNotification("Shop", ShopId .. " Option" .. i .. ": " .. tostring(ok), { Duration = 3 })
        if not ok then warn(err) end
    end)
end

CreateButton("Sell Ketchup (One)", "Shop", function() fire("SellKetchup", "One") end)
CreateButton("Sell Ketchup (Lots)", "Shop", function() fire("SellKetchup", "Lots") end)

-- Auto sell loop (carried over from the original Shops menu)
local AutoSell = { on = false, count = 1 }
CreateTextBox("Auto Sell Count", "Shop", { CustomText = "1" }, function(t)
    AutoSell.count = tonumber(t) or AutoSell.count
end)
CreateToggle("Auto Sell Ketchup", "Shop", function()
    AutoSell.on = not AutoSell.on
    if AutoSell.on then
        task.spawn(function()
            while AutoSell.on do
                for _ = 1, math.max(1, math.floor(AutoSell.count)) do
                    pcall(fire, "SellKetchup", "One")
                    task.wait(0.25)
                end
                task.wait(1.0)
            end
        end)
    end
end)

-- ── Stock Market (SM_Event) ───────────────────────────────────
-- The market sells through a single remote with (action, item, amount),
-- so the whole catalogue is a list, not a text box.
local SM = { amount = 1 }
local SM_ITEMS = {
    "Stand Arrow", "Charged Arrow", "Requiem Arrow",
    "Rokakaka", "New Rokakaka", "Dio's Diary", "Kars Mask",
}

CreateTextBox("Market amount", "Shop", { CustomText = "1" }, function(t)
    SM.amount = tonumber(t) or SM.amount
end)

local function smBuy(item)
    local ev = rs():FindFirstChild("Events")
    local sm = ev and ev:FindFirstChild("SM_Event")
    if not sm then
        CreateNotification("Shop", "no SM_Event", { Duration = 4 })
        return false
    end
    local r, c = hrp(), char()
    local saved = r and r.CFrame
    pcall(function()
        local npc = npcObj("StockMarket")
        local head = npc and (npc:FindFirstChild("Head") or npc:FindFirstChild("HumanoidRootPart"))
        if head and r then r.CFrame = head.CFrame * CFrame.new(0, 3, 0) end
    end)
    task.wait(0.4)
    pcall(function() sm:FireServer("Buy", item, SM.amount) end)
    task.wait(0.5)
    -- the market opens a prompt; fire it if the executor exposes the helper
    pcall(function()
        local npc = npcObj("StockMarket")
        local pr = npc and npc:FindFirstChild("TalkToPrompt", true)
        if pr and fireproximityprompt then fireproximityprompt(pr) end
    end)
    task.wait(0.3)
    if saved then pcall(function() r.CFrame = saved end) end
    CreateNotification("Shop", "bought " .. item .. " x" .. SM.amount, { Duration = 4 })
    return true
end

for _, item in ipairs(SM_ITEMS) do
    CreateButton("Market: " .. item, "Shop", function() smBuy(item) end)
end

CreateButton("Market: pick any item", "Shop", function()
    makePicker("Shop: Market items", SM_ITEMS, smBuy)
end)


-- ── STAND ─────────────────────────────────────────────────────
CreateMenu("Stand")

CreateButton("Show Current Stand", "Stand", function()
    CreateNotification("Stand", standName() .. " [" .. standAttri() .. "]", { Duration = 5 })
end)

CreateButton("Get Tier", "Stand", function()
    local t = invoke("GetStandTier", standName())
    CreateNotification("Tier", tostring(t), { Duration = 5 })
    print("[Tier]", standName(), "=", tostring(t))
end)

for i = 1, 5 do
    CreateButton("Switch to Slot " .. i, "Stand", function()
        fire("SwitchStand", "Slot" .. i)
    end)
end
CreateButton("Switch to Spec Slot 2", "Stand", function() fire("SwitchStand", "SpecSlot2") end)

CreateButton("Use Stand Arrow", "Stand", function()
    local ok, err = useTool("Stand Arrow")
    CreateNotification("Stand", tostring(ok), { Duration = 3 })
    if not ok then warn(err) end
end)

CreateButton("Use Charged Arrow", "Stand", function() useTool("Charged Arrow") end)
CreateButton("Use Requiem Arrow", "Stand", function() useTool("Requiem Arrow") end)
CreateButton("Use Rokakaka", "Stand", function() useTool("Rokakaka") end)
CreateButton("Use Rotten Rokakaka", "Stand", function() useTool("Rotten Rokakaka") end)

-- ── STAND FARM ────────────────────────────────────────────────
CreateMenu("Stand Farm")

local WantStands, WantAttrs = {}, {}
local CheckStand, CheckAttr, SplitMode = false, false, false
local UseArrowType = "Stand Arrow"
local AutoBuyArrow, AutoBuyRoka = false, false
local FarmActive = false
local WebhookURL, WebhookOn = "", false

CreateToggle("Check Stand", "Stand Farm", function() CheckStand = not CheckStand end)
CreateToggle("Check Attribute", "Stand Farm", function() CheckAttr = not CheckAttr end)
CreateToggle("Split Mode (stand OR attr)", "Stand Farm", function() SplitMode = not SplitMode end)

CreateButton("Arrows: Stand", "Stand Farm", function() UseArrowType = "Stand Arrow" end)
CreateButton("Arrows: Charged", "Stand Farm", function() UseArrowType = "Charged Arrow" end)
CreateButton("Arrows: Requiem", "Stand Farm", function() UseArrowType = "Requiem Arrow" end)

CreateToggle("Auto Buy Arrows", "Stand Farm", function() AutoBuyArrow = not AutoBuyArrow end)
CreateToggle("Auto Buy Rokakaka", "Stand Farm", function() AutoBuyRoka = not AutoBuyRoka end)

CreateTextBox("Webhook URL", "Stand Farm", { CustomText = "https://discord.com/api/webhooks/..." }, function(t)
    WebhookURL = t
end)
CreateToggle("Enable Webhook", "Stand Farm", function() WebhookOn = not WebhookOn end)

local function sendWebhook(stand, attr)
    if not WebhookOn or WebhookURL == "" then return end
    local body = HttpService:JSONEncode({
        content = "@everyone **Target rolled**\n```\nUser: " .. LP.Name ..
                  "\nStand: " .. tostring(stand) ..
                  "\nAttr: " .. tostring(attr) .. "\n```"
    })
    local fn = (syn and syn.request) or http_request or request or (http and http.request)
    if fn then
        pcall(fn, {
            Url = WebhookURL, Body = body, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" }
        })
    end
end

local function rollStep()
    if not hasStand() then
        local tool = LP.Backpack:FindFirstChild(UseArrowType)
            or (char() and char():FindFirstChild(UseArrowType))
        if tool then
            useTool(UseArrowType)
            task.wait(0.8)
        elseif AutoBuyArrow then
            local shop = (UseArrowType == "Charged Arrow") and "Merchant120" or "MerchantAU"
            local opt  = (UseArrowType == "Charged Arrow") and "Option2" or "Option4"
            tpToNPC(shop)
            task.wait(0.35)
            fire("BuyItem", shop, opt)
            task.wait(0.5)
        end
    else
        local tool = LP.Backpack:FindFirstChild("Rokakaka")
            or (char() and char():FindFirstChild("Rokakaka"))
        if tool then
            useTool("Rokakaka")
            task.wait(0.9)
        elseif AutoBuyRoka then
            tpToNPC("MerchantAU")
            task.wait(0.35)
            fire("BuyItem", "MerchantAU", "Option2")
            task.wait(0.5)
        end
    end
end

CreateToggle("BEGIN STAND FARM", "Stand Farm", function()
    FarmActive = not FarmActive
    if not FarmActive then return end
    task.spawn(function()
        while FarmActive do
            local cs, ca = standName(), standAttri()

            local mStand = #WantStands > 0 and table.find(WantStands, cs) ~= nil
            local mAttr  = #WantAttrs  > 0 and table.find(WantAttrs, ca) ~= nil

            local stop = false
            if SplitMode then
                stop = mStand or mAttr
            elseif CheckStand and CheckAttr then
                stop = mStand and mAttr
            elseif CheckStand then
                stop = mStand
            elseif CheckAttr then
                stop = mAttr
            else
                if #WantStands > 0 and #WantAttrs > 0 then
                    stop = mStand and mAttr
                elseif #WantStands > 0 then
                    stop = mStand
                elseif #WantAttrs > 0 then
                    stop = mAttr
                end
            end

            if stop and cs ~= "None" then
                pcall(sendWebhook, cs, ca)
                FarmActive = false
                CreateNotification("Arctic", "ROLLED: " .. cs .. " [" .. ca .. "]", { Duration = 10 })
                break
            end

            rollStep()
            task.wait(0.15)
        end
    end)
end)

CreateNote("── Stand whitelist ──", "Stand Farm")
pcall(function()
    local snc = RS:FindFirstChild("StandNameConvert")
    if not snc then return end
    local seen = {}
    for _, v in ipairs(snc:GetChildren()) do
        if v:IsA("StringValue") and not seen[v.Value] and v.Value ~= "" then
            seen[v.Value] = true
            CreateToggle(v.Value, "Stand Farm", function()
                local ix = table.find(WantStands, v.Value)
                if ix then table.remove(WantStands, ix) else WantStands[#WantStands + 1] = v.Value end
            end)
        end
    end
end)

CreateNote("── Attribute whitelist ──", "Stand Farm")
for _, attr in ipairs({ "Godly", "Legendary", "Mythic", "Overpowered", "Hallowed",
                        "Gluttonous", "Tenacious", "Furious", "Powerful", "Agile",
                        "Giant", "Tiny", "Strong", "Healthy", "Fast" }) do
    CreateToggle(attr, "Stand Farm", function()
        local ix = table.find(WantAttrs, attr)
        if ix then table.remove(WantAttrs, ix) else WantAttrs[#WantAttrs + 1] = attr end
    end)
end

-- ── ITEMS ─────────────────────────────────────────────────────
CreateMenu("Items")

CreateButton("List World Items", "Items", function()
    local t = worldTools()
    local s = itemSpawns()
    local names = {}
    for _, i in ipairs(t) do names[#names + 1] = i.name end
    print("[World items] " .. (#names > 0 and table.concat(names, ", ") or "none")
          .. "  |  spawn points: " .. #s)
    CreateNotification("Items", #names .. " spawned / " .. #s .. " spawns", { Duration = 4 })
end)

CreateButton("TP to Item Spawn 1", "Items", function()
    local s = itemSpawns()
    if s[1] then tpToPart(s[1].part, Vector3.new(0, 3, 0)) end
end)
CreateButton("TP to Item Spawn 2", "Items", function()
    local s = itemSpawns()
    if s[2] then tpToPart(s[2].part, Vector3.new(0, 3, 0)) end
end)
CreateButton("TP to Item Spawn 3", "Items", function()
    local s = itemSpawns()
    if s[3] then tpToPart(s[3].part, Vector3.new(0, 3, 0)) end
end)

local AutoGrab = false
CreateToggle("Auto Grab Items", "Items", function()
    AutoGrab = not AutoGrab
    if AutoGrab then
        task.spawn(function()
            local cycle = 0
            while AutoGrab do
                local t = worldTools()
                if #t > 0 and t[1].part then
                    tpToPart(t[1].part, Vector3.new(0, 2, 0))
                else
                    -- nothing spawned: sit on the next spawn marker so we catch it
                    local s = itemSpawns()
                    if #s > 0 then
                        cycle = cycle % #s + 1
                        if s[cycle].part then
                            tpToPart(s[cycle].part, Vector3.new(0, 3, 0))
                        end
                    end
                end
                task.wait(0.6)
            end
        end)
    end
end)

CreateButton("Grab Stand Arrow", "Items", function() grabItem("Stand Arrow") end)
CreateButton("Grab Rokakaka", "Items", function() grabItem("Rokakaka") end)

-- ── TELEPORTS ─────────────────────────────────────────────────
CreateMenu("Teleports")
CreateSearchBar("Teleports")

local function addNpcTP(name)
    CreateButton(name, "Teleports", function()
        local ok = tpToNPC(name)
        if not ok then
            CreateNotification("TP", "no " .. name, { Duration = 3 })
        end
    end)
end

for _, n in ipairs({
    "admpn", "MerchantAU", "Merchant120", "Merchant500", "Merchant1st",
    "CandyMerchant", "StockMarket", "Giorno", "Giorno2", "DIO", "Diavolo",
    "Funny Valentine", "Koichi", "Josuke", "Okayasu", "Rohan", "Kirito",
    "TidesQuest", "aLLmemester", "Scared Noob", "SWAT", "Young Joseph",
    "Joseph Joestar", "Zeppeli", "Muhammed Avdol", "Pop_Cat", "Gyro",
    "NascentNPC", "Sports Maxx", "Qtaro Cujoh", "TowhOH", "Bum NPC",
    "BobBallin", "Jonathan Joestar", "Succession_onlinoon", "i_stabman",
    "boznpc", "yu_k1p", "Staticaliza", "Darkceius", "Mayor Lucchini",
}) do
    addNpcTP(n)
end

-- Named landmarks (coordinates carried over from the original message.txt)
local LANDMARKS = {
    { "D4C Dimension",       11927.1,  -3.28935, -4488.59 },
    { "Rarity Boards",       -658.979, 67.0282,  -451.495 },
    { "Stand Storage Room",  -393.893, 23.5808,  -280.786 },
    { "Inner Sanctum",       27877.87, 27.2336,  -147.723 },
    { "Mud Pit",             17.0716,  66.9873,  -246.13  },
    { "Hamon Dealer",        -801.427, 66.5359,  -735.121 },
    { "Vehicle Man",         -187.042, 78.4486,  -1076.25 },
    { "Testing Zone",        19999.3,  100.155,  -730.726 },
    { "Bad Gi Spawn",        -687.605, 67.0313,  -837.959 },
    { "Scary Monster Cave",  -683.898, 67.0313,  -1039.76 },
    { "Sewer",               -5308.65, -450.832, -3815.39 },
    { "Yoshikage Kira Spawn",-446.509, 67.0313,  -995.377 },
    { "Dio's Rock",          -37.4145, 92.3069,  -804.244 },
    { "Gyro Zeppeli",        57.2144,  66.8005,  -216.834 },
    { "Dark Entrance 1",     -734,     70,       -398     },
    { "Dark Entrance 2",     -327,     67,       -140     },
    { "Dark Entrance 3",     -39,      70,       -482     },
}

for _, L in ipairs(LANDMARKS) do
    CreateButton(L[1], "Teleports", function()
        tpToPosition(L[2], L[3], L[4])
        CreateNotification("TP", L[1], { Duration = 3 })
    end)
end

-- NPC teleports named the way the game names them: the billboard over
-- each NPC carries Main / Sub text, so the button reads like the world does.
CreateNote("NPCs", "Teleports")
for _, m in ipairs((function()
    local f = npcFolder()
    return f and f:GetChildren() or {}
end)()) do
    local head = m:FindFirstChild("Head")
    local main = head and head:FindFirstChild("Main")
    local sub  = head and head:FindFirstChild("Sub")
    local a = main and main:FindFirstChild("Text") and main.Text.Text
    local b = sub and sub:FindFirstChild("Text") and sub.Text.Text
    local label = a and (a .. (b and (" [" .. b .. "]") or "")) or m.Name
    CreateButton(label, "Teleports", function()
        local ok = tpToNPC(m.Name)
        CreateNotification("TP", ok and label or ("no " .. m.Name), { Duration = 3 })
    end)
end

-- ── PLAYER ────────────────────────────────────────────────────
CreateMenu("Player")

CreateTextBox("WalkSpeed", "Player", { CustomText = "32", AutoUpdate = true }, function(t)
    Mods.speedValue = tonumber(t) or 32
    setSpeed(Mods.speedValue)
end)

CreateTextBox("JumpPower", "Player", { CustomText = "80", AutoUpdate = true }, function(t)
    Mods.jumpValue = tonumber(t) or 80
    setJump(Mods.jumpValue)
end)

CreateToggle("Fly (WASD + Space/Ctrl)", "Player", function()
    Mods.fly = not Mods.fly
    if Mods.fly then startFly() else stopFly() end
end)

CreateToggle("Noclip", "Player", function()
    Mods.noclip = not Mods.noclip
    if Mods.noclip then startNoclip() else stopNoclip() end
end)

CreateButton("Reset Speed/Jump", "Player", function()
    setSpeed(16); setJump(50)
    CreateNotification("Player", "reset", { Duration = 3 })
end)

-- ── VISUALS ───────────────────────────────────────────────────
CreateMenu("Visuals")

CreateToggle("ESP Players/Mobs (Living)", "Visuals", function()
    ESP.living = not ESP.living
    refreshESP()
end)

CreateToggle("ESP NPCs", "Visuals", function()
    ESP.npcs = not ESP.npcs
    refreshESP()
end)

CreateButton("Refresh ESP", "Visuals", function() refreshESP() end)
CreateButton("Clear ESP", "Visuals", function()
    ESP.living, ESP.npcs = false, false
    clearESP()
end)

-- ── FAKE PROFILE ──────────────────────────────────────────────
CreateMenu("Fake")

CreateNote("Fake reads the same fields /check reads", "Fake")
CreateNote("Local view only - other clients keep server values", "Fake")

CreateToggle("Fake Profile ON/OFF", "Fake", function()
    if Fake.active then
        fakeStop()
        CreateNotification("Fake", "off - restored", { Duration = 4 })
    else
        fakeStart()
        CreateNotification("Fake", "on", { Duration = 4 })
    end
end)

CreateTextBox("Stand code", "Fake", { CustomText = "SPTW_R" }, function(t)
    Fake.stand = (t ~= "" and t) or nil
end)

CreateTextBox("Attribute", "Fake", { CustomText = "Godly" }, function(t)
    Fake.attri = (t ~= "" and t) or nil
end)

CreateTextBox("GUID", "Fake", { CustomText = "00000000-0000-0000-0000-000000000000" }, function(t)
    Fake.guid = (t ~= "" and t) or nil
end)

CreateTextBox("Stand Damage", "Fake", { CustomText = "9999" }, function(t)
    Fake.dmg = tonumber(t) or Fake.dmg
end)

CreateTextBox("Damage Boost", "Fake", { CustomText = "9999" }, function(t)
    Fake.boost = tonumber(t) or Fake.boost
end)

CreateTextBox("Stand Health", "Fake", { CustomText = "99999" }, function(t)
    Fake.health = tonumber(t) or Fake.health
end)

CreateButton("Load from game (real values)", "Fake", function()
    local s = dataValue("Stand")
    local a = dataValue("Attri")
    local st = statsFolder()
    Fake.stand = s and s.Value or Fake.stand
    Fake.attri = a and a.Value or Fake.attri
    Fake.dmg   = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value or Fake.dmg
    Fake.health = hum() and hum().MaxHealth or Fake.health
    CreateNotification("Fake", "loaded: " .. tostring(Fake.stand), { Duration = 4 })
end)

CreateButton("List all stands", "Fake", function()
    local cat = standCatalog()
    print("[Stands] " .. #cat .. " entries")
    for _, e in ipairs(cat) do
        print(string.format("  %-22s %s", e.code, e.pretty))
    end
    CreateNotification("Fake", #cat .. " stands in game", { Duration = 5 })
end)

CreateButton("Fake stand model ON", "Fake", function()
    local ok, err = fakeStandSpawn(Fake.stand, 1)
    if not ok then CreateNotification("Fake", tostring(err), { Duration = 4 }) end
end)

CreateButton("Fake stand model OFF", "Fake", function()
    fakeStandClear()
end)

CreateButton("Print what /check will show", "Fake", function()
    local s = dataValue("Stand")
    local a = dataValue("Attri")
    local g = dataValue("GUID")
    local st = statsFolder()
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    local dmg = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value or 0
    print("  " .. LP.Name .. " has: " .. standPretty(s and s.Value or "?"))
    print("  Attribute: " .. tostring(a and a.Value))
    print("  Stand Health: " .. tostring(hum() and hum().MaxHealth))
    print("  Stand Damage: " .. tostring(math.floor(dmg * (db and db.Value or 1))))
    print("  Stand GUID: " .. tostring(g and g.Value))
end)

-- ── pickers: no typing, one click per value ───────────────────
local function pickStand(code, pretty)
    Fake.stand = code
    if Fake.active then pcall(fakeApply) end
    CreateNotification("Fake", pretty or standPretty(code), { Duration = 4 })
end

local function pickAttri(name)
    Fake.attri = name
    if Fake.active then pcall(fakeApply) end
    CreateNotification("Fake", "attri: " .. name, { Duration = 4 })
end

local standEntries = {}
for _, e in ipairs(standCatalog()) do
    standEntries[#standEntries + 1] = { code = e.code, pretty = e.pretty }
end

CreateButton("Open stand list", "Fake", function()
    makePicker("Fake: Stands", (function()
        local names = {}
        for _, e in ipairs(standEntries) do
            names[#names + 1] = e.pretty .. "  (" .. e.code .. ")"
        end
        return names
    end)(), function(label)
        for _, e in ipairs(standEntries) do
            if label == (e.pretty .. "  (" .. e.code .. ")") then
                pickStand(e.code, e.pretty)
                return
            end
        end
    end)
    CreateNotification("Fake", #standEntries .. " stands listed", { Duration = 4 })
end)

CreateButton("Open attribute list", "Fake", function()
    local attrs = attriCatalog()
    makePicker("Fake: Attributes", attrs, pickAttri)
    CreateNotification("Fake", #attrs .. " attributes listed", { Duration = 4 })
end)

CreateButton("Open stand model list", "Fake", function()
    local codes = {}
    for _, e in ipairs(standEntries) do codes[#codes + 1] = e.code end
    makePicker("Fake: Models", codes, function(code)
        local ok, err = fakeStandSpawn(code, 1)
        CreateNotification("Fake", ok and ("model " .. code) or tostring(err), { Duration = 4 })
    end)
end)

CreateButton("Read current from HUD", "Fake", function()
    print("[HUD] stand = " .. standGuiName())
    print("[HUD] attri = " .. tostring(dataValue("Attri") and dataValue("Attri").Value))
    CreateNotification("Fake", "HUD: " .. standGuiName(), { Duration = 4 })
end)

-- prefill from the live game so nothing has to be typed on first run
pcall(function()
    local s = dataValue("Stand")
    local a = dataValue("Attri")
    if s then Fake.stand = s.Value end
    if a then Fake.attri = a.Value end
end)


-- ── BOSS FARM ─────────────────────────────────────────────────
CreateMenu("Boss Farm")
CreateNote("Glues you to the target and drives M1 + heavies", "Boss Farm")

CreateTextBox("Distance", "Boss Farm", { CustomText = "4" }, function(t)
    Farm.distance = tonumber(t) or Farm.distance
end)
CreateToggle("Underneath", "Boss Farm", function()
    Farm.underneath = not Farm.underneath
end)
CreateToggle("Use Heavy Moves", "Boss Farm", function()
    Farm.useMoves = not Farm.useMoves
end)
CreateTextBox("Heavy every (s)", "Boss Farm", { CustomText = "1.0" }, function(t)
    Farm.heavyEvery = tonumber(t) or Farm.heavyEvery
end)

CreateButton("Stop All Farms", "Boss Farm", function()
    farmStop()
    CreateNotification("Farm", "stopped", { Duration = 3 })
end)

CreateToggle("Insta-Kill (local HP write)", "Boss Farm", function()
    Farm.instaKill = not Farm.instaKill
    CreateNotification("Farm", "insta-kill " .. (Farm.instaKill and "on" or "off"), { Duration = 3 })
end)

-- one click per live target: the list is scanned from Workspace.Living,
-- so nothing is typed and nothing can be misspelled
CreateButton("Scan live targets", "Boss Farm", function()
    local names = livingTargets()
    makePicker("Boss: Live targets", names, function(name)
        if Farm.running and Farm.target == name then
            farmStop()
            CreateNotification("Farm", "off " .. name, { Duration = 3 })
        else
            farmStart(name)
            CreateNotification("Farm", "on " .. name, { Duration = 3 })
        end
    end)
    CreateNotification("Farm", #names .. " live targets", { Duration = 4 })
end)

local PRESETS = {
    "Jotaro Over Heaven", "JohnnyJoestar", "Alternate Jotaro Part 4",
    "DIO", "Diavolo", "Funny Valentine", "Dio Brando", "Heaven Ascension DIO",
}
for _, boss in ipairs(PRESETS) do
    CreateToggle("Farm: " .. boss, "Boss Farm", function()
        if Farm.running and Farm.target == boss then
            farmStop()
            CreateNotification("Farm", "off " .. boss, { Duration = 3 })
        else
            farmStart(boss)
            CreateNotification("Farm", "on " .. boss, { Duration = 3 })
        end
    end)
end

CreateTextBox("Custom target name", "Boss Farm", { CustomText = "NPC name" }, function(t)
    if t and t ~= "" then Farm.target = t end
end)
CreateButton("Farm custom target", "Boss Farm", function()
    if Farm.target then
        farmStart(Farm.target)
        CreateNotification("Farm", "on " .. Farm.target, { Duration = 3 })
    end
end)

-- ── QUEST FARM ────────────────────────────────────────────────
CreateMenu("Quest Farm")
CreateNote("Fires Done / QuestDone on a chosen NPC on a loop", "Quest Farm")

local QuestFarm = { npc = "MerchantAU", running = false, which = "QuestDone", gap = 1.0 }

CreateButton("Pick quest NPC", "Quest Farm", function()
    local npcs = allNPCs()
    makePicker("Quest: NPC list", npcs, function(name)
        QuestFarm.npc = name
        CreateNotification("Quest", "npc: " .. name, { Duration = 4 })
    end)
    CreateNotification("Quest", #npcs .. " NPCs", { Duration = 4 })
end)
CreateTextBox("Loop gap (s)", "Quest Farm", { CustomText = "1.0" }, function(t)
    QuestFarm.gap = tonumber(t) or QuestFarm.gap
end)

CreateToggle("Use QuestDone (off = Done)", "Quest Farm", function()
    QuestFarm.which = (QuestFarm.which == "QuestDone") and "Done" or "QuestDone"
end)

CreateToggle("Begin Quest Farm", "Quest Farm", function()
    if QuestFarm.running then
        QuestFarm.running = false
        CreateNotification("Quest", "stopped", { Duration = 3 })
        return
    end
    QuestFarm.running = true
    task.spawn(function()
        while QuestFarm.running do
            pcall(fireNPC, QuestFarm.npc, QuestFarm.which)
            task.wait(QuestFarm.gap)
        end
    end)
    CreateNotification("Quest", "farming " .. QuestFarm.npc, { Duration = 3 })
end)

CreateButton("Fire once", "Quest Farm", function()
    local ok, err = fireNPC(QuestFarm.npc, QuestFarm.which)
    CreateNotification("Quest", ok and "fired" or tostring(err), { Duration = 3 })
end)

-- ── LAIR FARM ─────────────────────────────────────────────────
CreateMenu("Lair Farm")

local Lair = {
    on = false, thread = nil,
    npc = nil, boss = nil,
    distance = 4, pause = 0.4, range = 40,
    status = "idle", _lastFire = -10,
}

local function lairStatus(text)
    Lair.status = text
    pcall(EditString, "Status: " .. tostring(Lair.lastStatus or "idle"), "Status: " .. text)
    Lair.lastStatus = text
end

local function nearestNPC(maxDist)
    maxDist = maxDist or 20
    local r = hrp()
    local best, bestD = nil, maxDist
    local f = npcFolder()
    if not (f and r) then return nil end
    for _, m in ipairs(f:GetChildren()) do
        local p = m:FindFirstChild("HumanoidRootPart")
        if p then
            local d = (p.Position - r.Position).Magnitude
            if d < bestD then best, bestD = m, d end
        end
    end
    return best, bestD
end

local function npcPrettyLabel(m)
    if not m then return "none" end
    local head = m:FindFirstChild("Head")
    local main = head and head:FindFirstChild("Main")
    local sub  = head and head:FindFirstChild("Sub")
    local a = main and main:FindFirstChild("Text") and main.Text.Text
    local b = sub and sub:FindFirstChild("Text") and sub.Text.Text
    if a and b then return a .. " [" .. b .. "]" end
    return a or m.Name
end

-- lair bosses carry a Dungeon marker; fall back to any hostile model
local function nearestLairBoss()
    local living = WS:FindFirstChild("Living")
    local r = hrp()
    if not (living and r) then return nil end
    local best, bestD = nil, math.huge
    for _, m in ipairs(living:GetChildren()) do
        if m:IsA("Model") and m ~= char() then
            local h = m:FindFirstChildOfClass("Humanoid")
            local p = m:FindFirstChild("HumanoidRootPart")
            if h and p and h.Health > 0 then
                local n = m.Name
                local isLair = (n == "Boss")
                    or string.find(n, "Dungeon", 1, true)
                    or string.find(n, "%[Dungeon%]") ~= nil
                if isLair then
                    local d = (p.Position - r.Position).Magnitude
                    if d < bestD then best, bestD = m, d end
                end
            end
        end
    end
    return best
end

local function nearestHostile()
    local living = WS:FindFirstChild("Living")
    local r = hrp()
    if not (living and r) then return nil end
    local best, bestD = nil, math.huge
    for _, m in ipairs(living:GetChildren()) do
        if m:IsA("Model") and m ~= char() and m:FindFirstChild("AI") then
            local h = m:FindFirstChildOfClass("Humanoid")
            local p = m:FindFirstChild("HumanoidRootPart")
            if h and p and h.Health > 0 then
                local d = (p.Position - r.Position).Magnitude
                if d < bestD then best, bestD = m, d end
            end
        end
    end
    return best
end

local function lairStop()
    Lair.on = false
    Lair.thread = nil
    farmStop()
    lairStatus("stopped")
end

local function lairStart()
    if Lair.on then return end
    Lair.on = true
    Lair.lastStatus = "idle"
    Lair.thread = task.spawn(function()
        while Lair.on do
            local ok = pcall(function()
                local boss = nearestLairBoss()
                if boss then
                    Lair.boss = boss.Name
                    Farm.distance = Lair.distance
                    Farm.pauseOn = true
                    Farm.pauseLen = Lair.pause
                    lairStatus("killing " .. boss.Name)
                    farmStep(boss.Name)
                    task.wait(Lair.pause)
                else
                    -- no boss: ask the nearest NPC for the quest (throttled)
                    local npc = nearestNPC(Lair.range)
                    if npc then
                        local now = os.clock()
                        if now - Lair._lastFire > 1.5 then
                            Lair._lastFire = now
                            Lair.npc = npc.Name
                            pcall(fireNPC, npc.Name, "QuestDone")
                            pcall(fireNPC, npc.Name, "Done")
                            lairStatus("requesting " .. npcPrettyLabel(npc))
                        end
                    else
                        local h = nearestHostile()
                        if h then
                            Lair.boss = h.Name
                            lairStatus("clearing " .. h.Name)
                            farmStep(h.Name)
                        else
                            lairStatus("waiting for target")
                        end
                    end
                    task.wait(0.3)
                end
            end)
            if not ok then task.wait(0.5) end
        end
    end)
    lairStatus("running")
end

CreateNote("Status: idle", "Lair Farm")
Lair.lastStatus = "idle"

CreateToggle("AUTO Lair Farm (nearest)", "Lair Farm", function()
    if Lair.on then
        lairStop()
        CreateNotification("Lair", "off", { Duration = 3 })
    else
        lairStart()
        CreateNotification("Lair", "auto on", { Duration = 3 })
    end
end)

CreateButton("Stop everything", "Lair Farm", function()
    lairStop()
    farmStop()
    CreateNotification("Lair", "all stopped", { Duration = 3 })
end)

CreateTextBox("Distance", "Lair Farm", { CustomText = "4" }, function(t)
    Lair.distance = tonumber(t) or Lair.distance
end)
CreateTextBox("Pause (s)", "Lair Farm", { CustomText = "0.4" }, function(t)
    Lair.pause = tonumber(t) or Lair.pause
end)
CreateTextBox("NPC search range", "Lair Farm", { CustomText = "40" }, function(t)
    Lair.range = tonumber(t) or Lair.range
end)

CreateToggle("Insta-Kill (local HP write)", "Lair Farm", function()
    Farm.instaKill = not Farm.instaKill
end)

CreateButton("Select lair NPC (nearest)", "Lair Farm", function()
    local m, d = nearestNPC(Lair.range)
    if not m then
        CreateNotification("Lair", "no NPC in range", { Duration = 4 })
        return
    end
    Lair.npc = m.Name
    CreateNotification("Lair", npcPrettyLabel(m) .. " (" .. math.floor(d) .. ")", { Duration = 4 })
end)

CreateButton("Pick lair NPC from list", "Lair Farm", function()
    makePicker("Lair: NPC list", allNPCs(), function(name)
        Lair.npc = name
        CreateNotification("Lair", "npc: " .. npcPrettyLabel(npcObj(name)), { Duration = 4 })
    end)
end)

CreateButton("Scan lair bosses", "Lair Farm", function()
    local living = WS:FindFirstChild("Living")
    local b = {}
    if living then
        for _, m in ipairs(living:GetChildren()) do
            if m:IsA("Model") then
                local n = m.Name
                if n == "Boss" or string.find(n, "Dungeon", 1, true)
                   or string.find(n, "%[Dungeon%]") then
                    b[#b + 1] = n
                end
            end
        end
    end
    if #b == 0 then
        CreateNotification("Lair", "no lair boss right now", { Duration = 4 })
        return
    end
    makePicker("Lair: Bosses", b, function(name)
        Farm.distance = Lair.distance
        farmStart(name)
        CreateNotification("Lair", "on " .. name, { Duration = 3 })
    end)
end)

CreateButton("Fire LairStart", "Lair Farm", function() fire("LairStart") end)
CreateButton("Fire LairClear", "Lair Farm", function() fire("LairClear") end)


-- ── LOCALPLAYER ───────────────────────────────────────────────
CreateMenu("LocalPlayer")
CreateNote("Small quality-of-life toggles from the original build", "LocalPlayer")

CreateButton("Open Stand Storage", "LocalPlayer", function()
    local ok = tpToNPC("admpn")
    if ok then CreateNotification("Storage", "at admpn", { Duration = 3 }) end
end)

local AntiAFK = false
CreateToggle("Anti AFK", "LocalPlayer", function()
    AntiAFK = not AntiAFK
    if AntiAFK then
        task.spawn(function()
            local vu = game:GetService("VirtualUser")
            while AntiAFK do
                pcall(function() vu:CaptureController() end)
                pcall(function() vu:ClickButton2(Vector2.new()) end)
                task.wait(25)
            end
        end)
    end
end)

local AutoUmbrella = false
CreateToggle("Auto Umbrella", "LocalPlayer", function()
    AutoUmbrella = not AutoUmbrella
    if AutoUmbrella then
        task.spawn(function()
            while AutoUmbrella do
                local c = char()
                local umb = c and (LP.Backpack:FindFirstChild("Umbrella") or c:FindFirstChild("Umbrella"))
                if umb then
                    local h = hum()
                    if h and umb.Parent == LP.Backpack then
                        pcall(function() h:EquipTool(umb) end)
                    end
                end
                task.wait(1.5)
            end
        end)
    end
end)

CreateButton("Reset Character", "LocalPlayer", function()
    local h = hum()
    if h then pcall(function() h.Health = 0 end) end
end)

-- ── FARM SETTINGS ─────────────────────────────────────────────
CreateMenu("Farm Settings")

local MovesetCache = {}
local function refreshMovesets()
    MovesetCache = getMoveset() or {}
    print("[Movesets] " .. #MovesetCache .. " keys: " .. table.concat(MovesetCache, ", "))
    return MovesetCache
end

CreateButton("Refresh Movesets", "Farm Settings", function()
    refreshMovesets()
    CreateNotification("Farm", #MovesetCache .. " moves", { Duration = 4 })
end)

CreateToggle("Use Custom Moves", "Farm Settings", function()
    Farm.useMoves = not Farm.useMoves
    CreateNotification("Farm", "heavies " .. (Farm.useMoves and "on" or "off"), { Duration = 3 })
end)

CreateTextBox("Heavy move keys", "Farm Settings", { CustomText = "E,R,T" }, function(t)
    local keys = {}
    for piece in string.gmatch(t or "", "[^,%s]+") do
        keys[#keys + 1] = piece
    end
    if #keys > 0 then Farm.heavyKeys = keys end
end)

CreateNote("Heavies fire on the verified StandEvents.Input protocol", "Farm Settings")

-- ── ITEM FARM ─────────────────────────────────────────────────
CreateMenu("Item Farm")

local ItemFarm = { on = false, legit = false }

CreateButton("Instant", "Item Farm", function()
    ItemFarm.legit = false
    CreateNotification("Item", "instant mode", { Duration = 3 })
end)
CreateButton("Legit", "Item Farm", function()
    ItemFarm.legit = true
    CreateNotification("Item", "legit mode", { Duration = 3 })
end)

-- Full-world scan: any Tool outside a character/backpack that carries a
-- ProximityPrompt is grabbable. This is wider than worldTools() (which
-- only looks at Items / Vfx) and matches what the game actually spawns.
local function scanGrabbable()
    local out = {}
    local me = char()
    for _, inst in ipairs(WS:GetDescendants()) do
        if inst:IsA("Tool") then
            local parentOk = true
            local p = inst.Parent
            while p and p ~= WS do
                if p == me or (LP.Backpack and p == LP.Backpack) then parentOk = false break end
                if p:IsA("Model") and p:FindFirstChildOfClass("Humanoid") and p ~= me then
                    parentOk = false break
                end
                p = p.Parent
            end
            if parentOk then
                local part = inst:FindFirstChildWhichIsA("BasePart")
                local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
                if part then
                    out[#out + 1] = { name = inst.Name, obj = inst, part = part, prompt = prompt }
                end
            end
        end
    end
    return out
end

local function grabViaPrompt(t)
    if t.prompt and fireproximityprompt then
        pcall(function() fireproximityprompt(t.prompt) end)
        return true
    end
    return false
end

CreateButton("List grabbable items", "Item Farm", function()
    local g = scanGrabbable()
    print("[Grabbable] " .. #g)
    for _, t in ipairs(g) do print("  " .. t.name) end
    CreateNotification("Item", #g .. " grabbable", { Duration = 4 })
end)

CreateToggle("Start Farming", "Item Farm", function()
    ItemFarm.on = not ItemFarm.on
    if not ItemFarm.on then return end
    task.spawn(function()
        local cycle = 0
        while ItemFarm.on do
            local g = scanGrabbable()
            local t = g[1] or worldTools()[1]
            if t and t.part then
                tpToPart(t.part, Vector3.new(0, 2, 0))
                task.wait(0.25)
                if not grabViaPrompt(t) then
                    -- no prompt: hop onto the spawn marker so the pickup triggers
                    local s = itemSpawns()
                    if #s > 0 then
                        cycle = cycle % #s + 1
                        if s[cycle].part then tpToPart(s[cycle].part, Vector3.new(0, 3, 0)) end
                    end
                end
            else
                local s = itemSpawns()
                if #s > 0 then
                    cycle = cycle % #s + 1
                    if s[cycle].part then tpToPart(s[cycle].part, Vector3.new(0, 3, 0)) end
                end
            end
            task.wait(ItemFarm.legit and 2.5 or 0.6)
        end
    end)
end)

-- ── DIAGNOSTICS ───────────────────────────────────────────────
CreateMenu("Diagnostics")

CreateButton("Refresh UI layout", "Diagnostics", function()
    restyle()
    CreateNotification("UI", "layout re-applied", { Duration = 3 })
end)

CreateButton("Remote Health Check", "Diagnostics", function()
    local must = {
        "CoolDownGUI", "SwitchStand", "GetStandTier", "BuyItem", "SellKetchup",
        "NpcPrompt", "UseItem", "LairStart", "LairClear", "PressedPlay",
        "TradeThing", "trade2", "StatsUpdate", "CashNotif", "GeneralNotif",
        "ClientPing", "CheckCMD",
    }
    local missing, found = {}, 0
    for _, n in ipairs(must) do
        if ev(n) then found = found + 1 else missing[#missing + 1] = n end
    end
    print(string.format("[Remotes] %d/%d present", found, #must))
    if #missing > 0 then print("[Missing] " .. table.concat(missing, ", ")) end
    CreateNotification("Diagnostics", found .. "/" .. #must .. " remotes", { Duration = 5 })
end)

CreateButton("Character Health Check", "Diagnostics", function()
    local c = char()
    print("Character:", c and c.Name or "nil")
    print("Humanoid:", hum() and "ok" or "nil")
    print("StandEvents:", standFolder() and "ok" or "nil")
    print("Stand:", standName(), "| Attri:", standAttri())
    print("Moveset keys:", #getMoveset())
end)

CreateButton("World Health Check", "Diagnostics", function()
    print("NPCs:", #allNPCs())
    print("World items:", #worldTools())
    local living = WS:FindFirstChild("Living")
    print("Living:", living and #living:GetChildren() or 0)
end)

-- ── TOGGLE KEY ────────────────────────────────────────────────
-- The library owns the hotkey (default J, override via getgenv().ArcticUiHotkey).
-- No second listener here: two toggles on one frame cancel each other out.

-- ── EXTERNAL API (lets the agent drive everything from outside) ──
-- every menu exists now — proportion the whole window in one pass
restyle()

getgenv().ArcticAPI = {
    press       = press,
    moveset     = getMoveset,
    standName   = standName,
    standAttri  = standAttri,
    fire        = fire,
    invoke      = invoke,
    fireNPC     = fireNPC,
    npcRemote   = npcRemote,
    allNPCs     = allNPCs,
    tpToNPC     = tpToNPC,
    tpToPosition= tpToPosition,
    worldTools  = worldTools,
    itemSpawns  = itemSpawns,
    useTool     = useTool,
    audit       = Audit,
    ack         = ACK,
    ackReset    = ackReset,
    ackWait     = ackWait,
    mods        = Mods,
    esp         = ESP,
    refreshESP  = refreshESP,
    clearESP    = clearESP,
    setSpeed    = setSpeed,
    setJump     = setJump,
    startFly    = startFly,
    stopFly     = stopFly,
    startNoclip = startNoclip,
    stopNoclip  = stopNoclip,
    -- fake profile
    fake        = Fake,
    fakeStart   = fakeStart,
    fakeStop    = fakeStop,
    fakeApply   = fakeApply,
    fakeStandSpawn = fakeStandSpawn,
    fakeStandClear = fakeStandClear,
    standCatalog   = standCatalog,
    standPretty    = standPretty,
    attriCatalog   = attriCatalog,
    dataValue      = dataValue,
    statsFolder    = statsFolder,
    -- farms
    farm           = Farm,
    farmStart      = farmStart,
    farmStop       = farmStop,
    farmStep       = farmStep,
    livingTargets  = livingTargets,
    instaKill      = instaKill,
    landmarks      = LANDMARKS,
    makePicker     = makePicker,
    restyle        = restyle,
    standGuiName   = standGuiName,
    scanGrabbable  = scanGrabbable,
}

CreateNotification("Arctic SUR v2", "Loaded. Press J to toggle.", { Duration = 6 })
print("[Arctic SUR v2] loaded | stand=" .. standName() .. " | moves=" .. #getMoveset())
