-- Probe: touch-based pickup via firetouchinterest on ItemPromptHolder
local WS = game:GetService("Workspace")
local LP = game:GetService("Players").LocalPlayer
local char = LP.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
local out = {}

local holders = {}
for _, d in ipairs(WS:GetChildren()) do
    if d.Name == "ItemPromptHolder" then holders[#holders + 1] = d end
end
out.holders = #holders
if #holders < 2 or not hrp then return out end

local function bag()
    local t = {}
    for _, v in ipairs(LP.Backpack:GetChildren()) do t[#t + 1] = v.Name end
    for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then t[#t + 1] = v.Name end end
    table.sort(t)
    return table.concat(t, ",")
end

local before = bag()
local target = holders[2]
hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
task.wait(0.6)

local ok, err = pcall(function() firetouchinterest(hrp, target, 0) end)
out.t1 = "touch0 ok=" .. tostring(ok) .. " err=" .. tostring(err)
task.wait(0.5)
pcall(function() firetouchinterest(hrp, target, 1) end)
task.wait(1.0)

local after = bag()
out.before = before
out.after = after
out.changed = tostring(before ~= after)

-- also list any prompt-based remotes on the holder
local t = {}
for _, c in ipairs(target:GetChildren()) do t[#t + 1] = c.Name .. "[" .. c.ClassName .. "]" end
out.holderChildren = table.concat(t, ",")
return out
