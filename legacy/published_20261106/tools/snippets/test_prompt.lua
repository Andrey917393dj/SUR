-- Probe: can we trigger item ProximityPrompts from the client?
local WS = game:GetService("Workspace")
local LP = game:GetService("Players").LocalPlayer
local char = LP.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")

local holders = {}
for _, d in ipairs(WS:GetChildren()) do
    if d.Name == "ItemPromptHolder" then
        local p = d:FindFirstChildOfClass("ProximityPrompt")
        if p then holders[#holders + 1] = { part = d, prompt = p } end
    end
end

local out = { holders = #holders }
if #holders == 0 or not hrp then return out end

local function backpackNames()
    local t = {}
    for _, v in ipairs(LP.Backpack:GetChildren()) do t[#t + 1] = v.Name end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then t[#t + 1] = v.Name end
    end
    table.sort(t)
    return t
end

local before = table.concat(backpackNames(), ",")

local target = holders[1]
hrp.CFrame = CFrame.new(target.part.Position + Vector3.new(0, 3, 0))
task.wait(0.6)

local results = {}
local ok, err = pcall(function() target.prompt:InputHoldBegin() end)
results[#results + 1] = "InputHoldBegin ok=" .. tostring(ok) .. " err=" .. tostring(err)
task.wait(0.8)
local ok2, err2 = pcall(function() target.prompt:InputHoldEnd() end)
results[#results + 1] = "InputHoldEnd ok=" .. tostring(ok2) .. " err=" .. tostring(err2)
task.wait(1.0)

local after = table.concat(backpackNames(), ",")
results[#results + 1] = "before=" .. before
results[#results + 1] = "after =" .. after
results[#results + 1] = "changed=" .. tostring(before ~= after)

out.log = results
return out
