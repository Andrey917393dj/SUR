local UIS = game:GetService("UserInputService")
local lp = game:GetService("Players").LocalPlayer
local ch = lp.Character
if not ch then return { err = "no character" } end

local se = ch:FindFirstChild("StandEvents")
if not se then return { err = "no StandEvents" } end
local input = se:FindFirstChild("Input")
if not input then return { err = "no Input remote" } end

local vfx = game:GetService("Workspace"):FindFirstChild("Vfx")

local function snapshot()
    local t = {}
    if vfx then
        for _, c in ipairs(vfx:GetChildren()) do t[c.Name] = (t[c.Name] or 0) + 1 end
    end
    return t
end

local function diff(a, b)
    local out = {}
    for k, v in pairs(b) do
        if (a[k] or 0) ~= v then out[#out + 1] = k .. " (" .. (a[k] or 0) .. "->" .. v .. ")" end
    end
    return out
end

local before = snapshot()
local cdBefore = ch:FindFirstChild("MoveCD")
local cdBeforeVal = cdBefore and tostring(cdBefore.Value) or "nil"

-- fire one move: Q
local ok1, e1 = pcall(function()
    input:FireServer({ State = "Begin", Key = Enum.KeyCode.Q, Type = Enum.UserInputType.Keyboard })
end)
task.wait(0.15)
local ok2, e2 = pcall(function()
    input:FireServer({ State = "End", Key = Enum.KeyCode.Q, Type = Enum.UserInputType.Keyboard })
end)

task.wait(1.0)

local after = snapshot()
local cdAfter = ch:FindFirstChild("MoveCD")
local cdAfterVal = cdAfter and tostring(cdAfter.Value) or "nil"

return {
    fire_begin_ok = ok1, fire_begin_err = tostring(e1),
    fire_end_ok = ok2, fire_end_err = tostring(e2),
    movecd_before = cdBeforeVal,
    movecd_after = cdAfterVal,
    vfx_diff = diff(before, after),
    vfx_after_count = (function() local n = 0 for _, v in pairs(after) do n = n + v end return n end)(),
    stand_events_children = (function()
        local t = {}
        for _, c in ipairs(se:GetChildren()) do t[#t + 1] = c.Name .. ":" .. c.ClassName end
        return t
    end)()
}
