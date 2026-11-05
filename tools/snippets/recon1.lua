-- RECON 1: stands, data folder, character stand model, write-stick test
local RS = game:GetService("ReplicatedStorage")
local LP = game:GetService("Players").LocalPlayer
local out = {}

-- 1. every stand name the client knows
local snc = RS:FindFirstChild("StandNameConvert")
if snc then
    local t = {}
    for _, v in ipairs(snc:GetChildren()) do
        t[#t + 1] = v.Name .. " => " .. tostring(v.Value)
    end
    out.standNameConvert = { count = #t, list = t }
else
    out.standNameConvert = "missing"
end

-- 2. module containers
local function kids(inst)
    local t = {}
    if not inst then return t end
    for _, c in ipairs(inst:GetChildren()) do t[#t + 1] = c.Name .. "[" .. c.ClassName .. "]" end
    return t
end
out.rs_children = kids(RS)
out.modules = kids(RS:FindFirstChild("Modules"))
out.meshes = kids(RS:FindFirstChild("Meshes"))

-- 3. player data
local data = LP:FindFirstChild("Data")
if data then
    local t = {}
    for _, v in ipairs(data:GetChildren()) do
        t[#t + 1] = v.Name .. "[" .. v.ClassName .. "]=" .. tostring(v.Value)
    end
    out.data = t
else
    out.data = "missing"
end

-- 4. character + stand model
local char = LP.Character
out.char_children = kids(char)
local stand = char and char:FindFirstChild("Stand")
if stand then
    out.stand_model = { name = stand.Name, class = stand.ClassName, kids = kids(stand) }
else
    out.stand_model = "no Stand child on character"
end
out.living_self = kids(game.Workspace:FindFirstChild("Living") and game.Workspace.Living:FindFirstChild(LP.Name))

-- 5. does a local write to Data stick?
if data and data:FindFirstChild("Stand") then
    local sv = data.Stand
    local orig = sv:GetAttribute("SUR_orig") or sv.Value
    sv:SetAttribute("SUR_orig", orig)
    sv.Value = "SUR_PROBE_VALUE"
    task.wait(1.2)
    out.write_stick = { after = tostring(sv.Value), stuck = sv.Value == "SUR_PROBE_VALUE" }
    sv.Value = orig
else
    out.write_stick = "no Data.Stand"
end

return out
