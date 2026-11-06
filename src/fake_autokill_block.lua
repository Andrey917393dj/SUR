-- ══════════════════════════════════════════════════════════════════════════
-- FAKE PROFILE  (local /check fields + fake stand model)
-- Player.Data.Stand / .Attri / .GUID and Character.Stats.AttackDmg,
-- Character.DmgBoostAttri / Humanoid.MaxHealth are read by the saved client.
-- HUD: PlayerGui.PlayerGUI.ingame.Stats. StandNameConvert maps code to name.
-- These writes change this client's view, not server ownership or other clients.
-- ══════════════════════════════════════════════════════════════════════════
local Fake, AutoKill, fakeStop

do
local function installFakeTargetBlock()
Fake = {
    active = false, stand = nil, attri = nil, guid = nil,
    health = nil, dmg = nil, boost = nil,
    saved = {}, clamped = {}, hud = {}, character = nil, removing = nil,
    model = nil, relCFrame = nil, modelEnabled = false, modelCode = nil, side = 1,
}

local function dataValue(name)
    local d = LP:FindFirstChild("Data")
    local value = d and d:FindFirstChild(name)
    return value and value:IsA("ValueBase") and value or nil
end

local function statsFolder()
    local c = char()
    return c and c:FindFirstChild("Stats")
end

local function standCatalog()
    local out = {}
    local holder = ReplicatedStorage:FindFirstChild("StandNameConvert")
    if holder then
        for _, v in ipairs(holder:GetChildren()) do
            if v:IsA("StringValue") then out[#out + 1] = { code = v.Name, pretty = tostring(v.Value) } end
        end
    end
    table.sort(out, function(a, b) return a.code < b.code end)
    return out
end

local function standPretty(code)
    local holder = ReplicatedStorage:FindFirstChild("StandNameConvert")
    local v = holder and holder:FindFirstChild(tostring(code))
    return v and v:IsA("StringValue") and tostring(v.Value) or tostring(code or "None")
end

local function attriCatalog()
    local out, seen = {}, {}
    local map = Workspace:FindFirstChild("Map")
    local boards = map and map:FindFirstChild("ChancesBoards")
    local board = boards and boards:FindFirstChild("AttributeChances")
    local surface = board and board:FindFirstChild("newSurface")
    local frame = surface and surface:FindFirstChild("ScrollFrame")
    if frame then
        for _, v in ipairs(frame:GetChildren()) do
            if v:IsA("TextLabel") then
                local name = tostring(v.Text):gsub("%s*[%(%[]?[%d%.]+%%%s*[%)%]]?%s*$", ""):match("^%s*(.-)%s*$")
                if name == "Glass" then name = "Glass Cannon" end
                if name and name ~= "" and not seen[name] then seen[name] = true; out[#out + 1] = name end
            end
        end
    end
    if #out == 0 then
        for _, holderName in ipairs({ "AttriList", "Attributes", "AttriNames", "RarityList" }) do
            local holder = ReplicatedStorage:FindFirstChild(holderName)
            if holder then
                for _, v in ipairs(holder:GetChildren()) do
                    if (v:IsA("StringValue") or v:IsA("Folder")) and not seen[v.Name] then
                        seen[v.Name] = true; out[#out + 1] = v.Name
                    end
                end
            end
        end
    end
    if #out == 0 then out = { "None", "Weak", "Normal", "Good", "Great", "Excellent", "Perfect", "Legendary", "Mythical", "Godly", "Divine" } end
    table.sort(out)
    return out
end

-- ── exact-instance/property ledger ────────────────────────────────────────
local function fakeOriginal(instance, property)
    if not instance then return nil end
    local fields = Fake.saved[instance]
    local record = fields and fields[property]
    if record then return record.original end
    local ok, value = pcall(function() return instance[property] end)
    return ok and value or nil
end

local function fakeWrite(instance, property, value)
    if not (instance and instance.Parent) or value == nil then return false end
    local fields = Fake.saved[instance]
    local record = fields and fields[property]
    local original = record and record.original
    if not record then
        local ok
        ok, original = pcall(function() return instance[property] end)
        if not ok then return false end
    else
        local ok, observed = pcall(function() return instance[property] end)
        if not ok then return false end
        if observed ~= record.last then record.original = observed end
    end
    local ok = pcall(function() instance[property] = value end)
    if not ok then return false end
    if not fields then fields = {}; Fake.saved[instance] = fields end
    if not record then record = { original = original }; fields[property] = record end
    record.last = value
    return true
end

local function restoreProperty(instance, property)
    local fields = Fake.saved[instance]
    local record = fields and fields[property]
    if not record then return end
    if instance.Parent then
        pcall(function()
            -- A later independent update is not owned by this fake session.
            if instance[property] == record.last then instance[property] = record.original end
        end)
    end
    fields[property] = nil
    if not next(fields) then Fake.saved[instance] = nil end
end

local function fakeRestore(healthCharacter)
    local entries = {}
    for instance, fields in pairs(Fake.saved) do
        for property in pairs(fields) do entries[#entries + 1] = { instance, property } end
    end
    -- Max must be restored before a Health clamp caused by changing Max.
    for _, entry in ipairs(entries) do if entry[2] == "MaxHealth" then restoreProperty(entry[1], entry[2]) end end
    for _, entry in ipairs(entries) do if entry[2] ~= "MaxHealth" then restoreProperty(entry[1], entry[2]) end end
    if not healthCharacter then healthCharacter = char() end
    for humanoid, clamp in pairs(Fake.clamped) do
        if humanoid.Parent and humanoid.Parent == healthCharacter and humanoid.Health > 0
            and humanoid.Health == clamp.after then
            pcall(function() humanoid.Health = math.min(clamp.before, humanoid.MaxHealth) end)
        end
    end
    Fake.saved, Fake.clamped, Fake.hud, Fake.character = {}, {}, {}, nil
end

-- ── панель статов слева ───────────────────────────────────────────────────
local function hudStats()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local gui = pg and pg:FindFirstChild("PlayerGUI")
    local ingame = gui and gui:FindFirstChild("ingame")
    return ingame and ingame:FindFirstChild("Stats")
end

local function standGuiName()
    local frame = hudStats()
    local holder = frame and frame:FindFirstChild("StandName")
    local label = holder and holder:FindFirstChild("TextLabel", true)
    return label and label:IsA("TextLabel") and tostring(label.Text) or standName()
end

local function hudKind(label, frame)
    local cursor = label
    while cursor and cursor ~= frame do
        local name = string.lower(cursor.Name):gsub("[%s_%-]", "")
        if name == "standname" then return "stand" end
        if name == "attri" or name == "attribute" then return "attri" end
        if name == "standhealth" or name == "maxhealth" or name == "health" then return "health" end
        if name == "standdamage" or name == "attackdmg" or name == "damage" then return "dmg" end
        if name == "guid" or name == "standguid" then return "guid" end
        cursor = cursor.Parent
    end
    return nil
end

local function hudApply()
    local frame = hudStats()
    if not frame then return end
    local st = statsFolder()
    local attack = st and st:FindFirstChild("AttackDmg")
    local boost = char() and char():FindFirstChild("DmgBoostAttri")
    local originalDmg = attack and fakeOriginal(attack, "Value")
    local originalBoost = boost and fakeOriginal(boost, "Value") or 1
    local realStand = standPretty(fakeOriginal(dataValue("Stand"), "Value") or standCode())
    local realAttr = fakeOriginal(dataValue("Attri"), "Value")
    local realHealth = fakeOriginal(hum(), "MaxHealth")
    local realDamage = originalDmg and math.floor(originalDmg * (originalBoost or 1))
    local wants = {
        stand = Fake.stand and standPretty(Fake.stand), attri = Fake.attri, guid = Fake.guid,
        health = Fake.health and tostring(Fake.health),
        dmg = (Fake.dmg ~= nil or Fake.boost ~= nil) and tostring(math.floor((Fake.dmg or originalDmg or 0) * (Fake.boost or originalBoost or 1))) or nil,
    }
    for _, label in ipairs(frame:GetDescendants()) do
        if label:IsA("TextLabel") then
            local kind = Fake.hud[label] or hudKind(label, frame)
            if not kind then
                -- Exact textual fallback only; unrelated numeric labels are untouched.
                local original = fakeOriginal(label, "Text")
                if original == realStand and Fake.stand then kind = "stand"
                elseif original == realAttr and Fake.attri then kind = "attri"
                elseif realHealth and original == tostring(realHealth) and label.Name == "StandHealth" then kind = "health"
                elseif realDamage and original == tostring(realDamage) and label.Name == "StandDamage" then kind = "dmg" end
            end
            if kind then
                Fake.hud[label] = kind
                if wants[kind] ~= nil then fakeWrite(label, "Text", tostring(wants[kind])) else restoreProperty(label, "Text") end
            end
        end
    end
end

-- ── запись / восстановление ───────────────────────────────────────────────
local function fakeApply()
    if not Fake.active or not Runtime.alive then return end
    local c = char()
    if not c or Fake.removing == c then return end
    Fake.character = c
    for _, spec in ipairs({ {"Stand", Fake.stand}, {"Attri", Fake.attri}, {"GUID", Fake.guid} }) do
        local v = dataValue(spec[1])
        if spec[2] ~= nil then fakeWrite(v, "Value", spec[2]) elseif v then restoreProperty(v, "Value") end
    end
    local st = statsFolder()
    local attack = st and st:FindFirstChild("AttackDmg")
    local boost = c:FindFirstChild("DmgBoostAttri")
    if attack then if Fake.dmg ~= nil then fakeWrite(attack, "Value", Fake.dmg) else restoreProperty(attack, "Value") end end
    if boost then if Fake.boost ~= nil then fakeWrite(boost, "Value", Fake.boost) else restoreProperty(boost, "Value") end end
    local h = hum()
    if h and h.Health > 0 then
        if Fake.health ~= nil then
            local before = h.Health
            local priorClamp = Fake.clamped[h]
            if priorClamp and before ~= priorClamp.after then Fake.clamped[h] = nil end
            if fakeWrite(h, "MaxHealth", Fake.health) then
                local after = h.Health
                if after < before and after <= Fake.health then
                    local clamp = Fake.clamped[h]
                    if not clamp then Fake.clamped[h] = { before = before, after = after } else clamp.after = after end
                end
            end
        else
            restoreProperty(h, "MaxHealth")
            local clamp = Fake.clamped[h]
            if clamp and h.Health == clamp.after and h.Health > 0 then h.Health = math.min(clamp.before, h.MaxHealth) end
            Fake.clamped[h] = nil
        end
    end
    hudApply()
end

-- ── модель фейк-стенда ────────────────────────────────────────────────────
local function fakeStandClear()
    Fake.modelEnabled = false
    jobStop("fake-model")
    local m = Fake.model
    Fake.model, Fake.relCFrame, Fake.modelCode = nil, nil, nil
    if m then pcall(function() m:Destroy() end) end
end

local function findStandSource(code)
    for _, plr in ipairs(Players:GetPlayers()) do
        local c = plr.Character
        local model = c and c:FindFirstChild("Stand")
        local d = plr:FindFirstChild("Data")
        local value = d and d:FindFirstChild("Stand")
        local actual = value and (plr == LP and fakeOriginal(value, "Value") or value.Value)
        if model and model:IsA("Model") and actual ~= nil and tostring(actual) == tostring(code) then return model end
    end
    for _, folderName in ipairs({ "Storage", "QuestAssets", "UIStorage", "Vfx" }) do
        local holder = Workspace:FindFirstChild(folderName)
        local model = holder and holder:FindFirstChild(tostring(code))
        if model and model:IsA("Model") then return model end
    end
    local model = ReplicatedStorage:FindFirstChild(tostring(code))
    return model and model:IsA("Model") and model or nil
end

local function sanitizeStand(model)
    local partCount = 0
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("LuaSourceContainer") or inst:IsA("BaseScript") or inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
            inst:Destroy()
        elseif inst:IsA("BasePart") then
            partCount = partCount + 1
            inst.Anchored, inst.CanCollide, inst.CanQuery, inst.CanTouch = true, false, false, false
        elseif inst:IsA("JointInstance") or inst:IsA("WeldConstraint") then
            local external = false
            for _, property in ipairs({ "Part0", "Part1" }) do
                local ok, value = pcall(function() return inst[property] end)
                if ok and value and not value:IsDescendantOf(model) then external = true end
            end
            if external then inst:Destroy() end
        elseif inst:IsA("Constraint") then
            local external = false
            for _, property in ipairs({ "Attachment0", "Attachment1" }) do
                local ok, value = pcall(function() return inst[property] end)
                if ok and value and not value:IsDescendantOf(model) then external = true end
            end
            if external then inst:Destroy() end
        elseif inst:IsA("ObjectValue") then
            local value = inst.Value
            if value and not value:IsDescendantOf(model) then inst.Value = nil end
        elseif inst:IsA("Humanoid") then
            inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    return partCount > 0
end

local function fakeStandWorker()
    return jobStart("fake-model", false, function()
        local model = Fake.model
        Fake.model, Fake.relCFrame, Fake.modelEnabled, Fake.modelCode = nil, nil, false, nil
        if model then pcall(function() model:Destroy() end) end
    end, function(job)
        while jobActive(job) and Fake.modelEnabled do
            local model, offset = Fake.model, Fake.relCFrame
            if not (model and model.Parent == Workspace and offset) then break end
            local root, h = hrp(), hum()
            if root and h and h.Health > 0 then
                local ok = pcall(function() model:PivotTo(root.CFrame * offset) end)
                if not ok then notify("Fake model tracking failed; cleared.", 4); break end
            end
            if not waitActive(0.1, job) then break end
        end
    end)
end

local function fakeStandSpawn(code, side)
    local root, h = hrp(), hum()
    if not Runtime.alive or not (root and h and h.Health > 0) then return false, "No live character root" end
    code = code and tostring(code) or standCode()
    if not code or code == "" or code == "None" then return false, "Select a stand code first" end
    local source = findStandSource(code)
    if not source or not source:IsA("Model") then return false, "No exact stand model for " .. code end
    if not source.Archivable then return false, "Source is not archivable" end
    local candidate
    local ok, err = pcall(function()
        candidate = source:Clone()
        if not candidate or not candidate:IsA("Model") then error("Clone did not produce a Model") end
        candidate.Name = "SUR_FakeStand"
        candidate:SetAttribute("SUR_FakePreview", true)
        if not sanitizeStand(candidate) then error("Stand clone has no BasePart") end
        local offset = CFrame.new(3 * (side or 1), 0, 0)
        candidate:PivotTo(root.CFrame * offset)
        if not Runtime.alive or root ~= hrp() or h ~= hum() or h.Health <= 0 then error("Character changed while cloning") end
        candidate.Parent = Workspace
        if candidate.Parent ~= Workspace then error("Could not parent preview") end
        local previous = Fake.model
        Fake.model, Fake.relCFrame, Fake.modelCode, Fake.side = candidate, offset, code, side or 1
        Fake.modelEnabled = true
        if previous then previous:Destroy() end
    end)
    if not ok then
        if candidate and candidate ~= Fake.model then pcall(function() candidate:Destroy() end) end
        return false, tostring(err)
    end
    fakeStandWorker()
    return Fake.model == candidate and Fake.modelEnabled
end

local function fakeStart()
    if not Runtime.alive then return false end
    if Fake.active and Runtime.jobs["fake-profile"] then return true end
    jobStop("stand")
    Fake.active = true
    jobStart("fake-profile", false, function()
        Fake.active = false
        fakeRestore()
        SetToggle("Fake Profile ON", "Fake", false)
    end, function(job)
        while jobActive(job) do
            fakeApply()
            if not waitActive(0.2, job) then break end
        end
    end)
    return Fake.active
end

fakeStop = function()
    if not Fake.active and not Runtime.jobs["fake-profile"] and not next(Fake.saved) then return false end
    Fake.active = false
    jobStop("fake-profile")
    if next(Fake.saved) or next(Fake.clamped) then fakeRestore() end
    SetToggle("Fake Profile ON", "Fake", false)
    return false
end
addCleanup(function() fakeStop(); fakeStandClear() end)

runConnect(LP.CharacterRemoving, function(character)
    -- No old character ledger is restored into a replacement character.
    Fake.removing = character
    fakeRestore(character)
end)
runConnect(LP.CharacterAdded, function(character)
    if char() == character then Fake.removing = nil end
end)

-- ── menu pickers use the original library ─────────────────────────────────
local PickerMenus = {}
local function makePicker(menuName, entries, onPick)
    if PickerMenus[menuName] then
        Delete(menuName) -- menu selector and ScrollingFrame share a name
        Delete(menuName)
    end
    PickerMenus[menuName] = true
    CreateMenu(menuName)
    CreateSearchBar(menuName)
    for _, entry in ipairs(entries) do
        local picked = entry
        if type(entry) == "table" and entry.value ~= nil then picked = entry.value end
        local label = type(entry) == "table" and (entry.label or tostring(picked)) or tostring(entry)
        CreateButton(label, menuName, function() onPick(picked) end)
    end
    local button = Handler and Handler:FindFirstChild(menuName)
    if button then
        for _, child in ipairs(Menus:GetChildren()) do if child:IsA("GuiObject") then child.Visible = child.Name == menuName end end
    end
end

local function setFakeText(field, text)
    local value = tostring(text or ""):match("^%s*(.-)%s*$")
    Fake[field] = value ~= "" and value or nil
    if Fake.active then fakeApply() end
    if field == "stand" and Fake.modelEnabled and Fake[field] ~= nil then
        local ok, err = fakeStandSpawn(Fake[field], Fake.side)
        if not ok then notify("Preview kept: " .. tostring(err), 4) end
    end
end

local function setFakeNumber(field, text, minimum)
    if tostring(text or ""):match("^%s*$") then
        Fake[field] = nil
    else
        local value = finiteNumber(text, minimum, 1000000000)
        if not value then notify("Enter a finite " .. field .. " value", 4); return end
        Fake[field] = value
    end
    if Fake.active then fakeApply() end
end

-- ── меню Fake ─────────────────────────────────────────────────────────────
CreateMenu("Fake")
CreateNote("Local Data / Stats / HUD only; no server stand or shared damage.", "Fake")
CreateToggle("Fake Profile ON", "Fake", function(on)
    if on then return fakeStart() end
    return fakeStop()
end)
CreateButton("Load from game (real values)", "Fake", function()
    Fake.stand = fakeOriginal(dataValue("Stand"), "Value")
    Fake.attri = fakeOriginal(dataValue("Attri"), "Value")
    Fake.guid = fakeOriginal(dataValue("GUID"), "Value")
    local st = statsFolder()
    Fake.dmg = fakeOriginal(st and st:FindFirstChild("AttackDmg"), "Value")
    Fake.boost = fakeOriginal(char() and char():FindFirstChild("DmgBoostAttri"), "Value")
    Fake.health = fakeOriginal(hum(), "MaxHealth")
    if Fake.active then fakeApply() end
    notify("Loaded real local values", 4)
end)
CreateTextBox("Stand Code", "Fake", { CustomText = "SPTW_R" }, function(t) setFakeText("stand", t) end)
CreateTextBox("Attribute", "Fake", { CustomText = "Godly" }, function(t) setFakeText("attri", t) end)
CreateTextBox("GUID", "Fake", { CustomText = "00000000-0000-0000-0000-000000000000" }, function(t) setFakeText("guid", t) end)
CreateTextBox("Stand Damage", "Fake", { CustomText = "9999" }, function(t) setFakeNumber("dmg", t, 0) end)
CreateTextBox("Damage Boost", "Fake", { CustomText = "9999" }, function(t) setFakeNumber("boost", t, 0) end)
CreateTextBox("Stand Health", "Fake", { CustomText = "99999" }, function(t) setFakeNumber("health", t, 1) end)
CreateButton("List all stands", "Fake", function()
    local catalog, names = standCatalog(), {}
    for i = 1, math.min(#catalog, 12) do names[#names + 1] = catalog[i].code end
    notify(#catalog .. " stands: " .. table.concat(names, ", "), 8)
end)
CreateButton("Open stand list", "Fake", function()
    local entries = {}
    for _, entry in ipairs(standCatalog()) do entries[#entries + 1] = { value = entry.code, label = entry.pretty .. " [" .. entry.code .. "]" } end
    makePicker("Fake: Stands", entries, function(code) setFakeText("stand", code) end)
end)
CreateButton("Open attribute list", "Fake", function()
    makePicker("Fake: Attributes", attriCatalog(), function(value) Fake.attri = value; if Fake.active then fakeApply() end end)
end)
CreateButton("Open stand model list", "Fake", function()
    local entries = {}
    for _, entry in ipairs(standCatalog()) do entries[#entries + 1] = entry.code end
    makePicker("Fake: Models", entries, function(code)
        local ok, err = fakeStandSpawn(code, 1)
        if not ok then notify(err, 4) end
    end)
end)
CreateButton("Fake stand model ON", "Fake", function()
    local ok, err = fakeStandSpawn(Fake.stand, 1)
    if not ok then notify(err, 4) end
end)
CreateButton("Fake stand model OFF", "Fake", function() fakeStandClear() end)
CreateButton("Read current from HUD", "Fake", function()
    print("[HUD] stand = " .. standGuiName())
    notify("HUD: " .. standGuiName(), 4)
end)
CreateButton("Print what /check will show", "Fake", function()
    local st = statsFolder()
    local attack = st and st:FindFirstChild("AttackDmg")
    local boost = char() and char():FindFirstChild("DmgBoostAttri")
    notify("Local check: stand=" .. standName() .. " attri=" .. tostring(dataValue("Attri") and dataValue("Attri").Value)
        .. " hp=" .. tostring(hum() and hum().MaxHealth) .. " dmg=" .. tostring(attack and math.floor(attack.Value * (boost and boost.Value or 1)))
        .. " guid=" .. tostring(dataValue("GUID") and dataValue("GUID").Value), 8)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- AUTO KILL — exact mouse-selected NPC, behind teleport, local Health = 0
-- ══════════════════════════════════════════════════════════════════════════
AutoKill = { enabled = false, target = nil, root = nil, humanoid = nil, behind = 6, picking = false, token = 0 }

local function isPlayerDescendant(instance)
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        if c and (instance == c or instance:IsDescendantOf(c)) then return true end
    end
    return false
end

local function isNpcModel(model)
    local L = living()
    if not (model and model:IsA("Model") and model.Parent == L and L) or isPlayerDescendant(model)
        or model == Fake.model or model:GetAttribute("SUR_FakePreview") then return false end
    local h, root = model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and root and root:IsA("BasePart") and true or false
end

local function modelFromInstance(instance)
    local L = living()
    local cursor = instance
    if not L or not cursor or isPlayerDescendant(cursor) then return nil end
    while cursor and cursor ~= L and cursor ~= Workspace do
        if cursor.Parent == L then return isNpcModel(cursor) and cursor or nil end
        cursor = cursor.Parent
    end
    return nil
end

local function selectionNote(text)
    setNote("Selected target:", "Selected target: " .. (text or "None"))
end

local function cancelPicker()
    AutoKill.token = AutoKill.token + 1
    AutoKill.picking = false
    jobStop("target-picker")
end

local function autoKillStop(clear)
    AutoKill.enabled = false
    jobStop("auto-kill")
    SetToggle("Auto Kill Selected", "Auto Kill", false)
    if clear then
        cancelPicker()
        AutoKill.target, AutoKill.root, AutoKill.humanoid = nil, nil, nil
        selectionNote(nil)
    end
end

local function selectedTargetReady(model, root, h)
    return isNpcModel(model) and AutoKill.target == model and AutoKill.root == root and AutoKill.humanoid == h
        and model:FindFirstChild("HumanoidRootPart") == root and model:FindFirstChildOfClass("Humanoid") == h
end

local function killBehind(model, root, targetHum, distance, job)
    local me, localHum, character = hrp(), hum(), char()
    if not jobActive(job) or not selectedTargetReady(model, root, targetHum) or not (me and localHum and localHum.Health > 0) then return false end
    local want = root.CFrame * CFrame.new(0, 0, distance)
    local moved = pcall(function() me.CFrame = want end)
    if not moved or not jobActive(job) or char() ~= character or hrp() ~= me or localHum.Health <= 0
        or not selectedTargetReady(model, root, targetHum) or (me.Position - want.Position).Magnitude > 1 then return false end
    -- No fallback damage/state changes. Success is local Health only.
    local ok = pcall(function() targetHum.Health = 0 end)
    return ok and targetHum.Health == 0
end

CreateMenu("Auto Kill")
CreateNote("Select target → click the boss in the world.", "Auto Kill")
CreateNote("Selected target: None", "Auto Kill")
CreateNote("HP write is local; server kill and reward are unverified.", "Auto Kill")
CreateButton("Select target (click boss)", "Auto Kill", function()
    autoKillStop(true)
    AutoKill.picking = true
    local token = AutoKill.token
    jobStart("target-picker", false, function()
        if AutoKill.token == token then AutoKill.picking = false end
    end, function(job)
        if waitActive(15, job) and AutoKill.token == token then
            AutoKill.picking = false
            notify("Target selection expired", 3)
        end
    end)
    notify("Click the NPC itself; Escape/right click cancels", 6)
end)
CreateTextBox("Behind distance", "Auto Kill", { CustomText = "6" }, function(t)
    local value = finiteNumber(t, 0.5, 100)
    if value then AutoKill.behind = value end
end)
CreateToggle("Auto Kill Selected", "Auto Kill", function(on)
    if not on then autoKillStop(false); return false end
    cancelPicker()
    local target, root, h = AutoKill.target, AutoKill.root, AutoKill.humanoid
    if not selectedTargetReady(target, root, h) or not (hrp() and hum() and hum().Health > 0) then
        autoKillStop(true)
        notify("No live exact target; select it first.", 4)
        return false
    end
    AutoKill.enabled = true
    jobStart("auto-kill", true, function()
        AutoKill.enabled = false
        SetToggle("Auto Kill Selected", "Auto Kill", false)
    end, function(job)
        if not selectedTargetReady(target, root, h) then return end
        local success = killBehind(target, root, h, AutoKill.behind, job)
        notify(success and "Local selected HP=0; server kill unconfirmed." or "Selected action failed; stopped.", 5)
    end)
    return AutoKill.enabled
end)
CreateButton("Stop Auto Kill", "Auto Kill", function() autoKillStop(true); notify("Auto Kill stopped", 3) end)

-- клик по миру = выбор цели, пока включён режим picking
runConnect(UIS.InputBegan, function(input, gameProcessed)
    if not Runtime.alive or not AutoKill.picking then return end
    if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
        autoKillStop(true); return
    end
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or UIS:GetFocusedTextBox() then return end
    local token = AutoKill.token
    local ok, mouse = pcall(function() return LP:GetMouse() end)
    local target = ok and mouse and modelFromInstance(mouse.Target) or nil
    if token ~= AutoKill.token or not Runtime.alive then return end
    cancelPicker()
    AutoKill.target = target
    AutoKill.root = target and target:FindFirstChild("HumanoidRootPart") or nil
    AutoKill.humanoid = target and target:FindFirstChildOfClass("Humanoid") or nil
    selectionNote(target and target.Name)
    notify(target and ("Target: " .. target.Name) or "Nothing selected; click the NPC itself", 4)
end)
runConnect(LP.CharacterRemoving, function() autoKillStop(true) end)
addCleanup(function() autoKillStop(true) end)
end
installFakeTargetBlock()
end -- Private Fake/Auto Kill helpers; only state and stop escape this scope.
