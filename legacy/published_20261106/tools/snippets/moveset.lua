local lp = game:GetService("Players").LocalPlayer
local out = { player = lp.Name }

local ch = lp.Character
if not ch then return { err = "no character" } end

local se = ch:FindFirstChild("StandEvents")
if se then
    local info = se:FindFirstChild("Info")
    if info and info:IsA("RemoteFunction") then
        local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
        out.moveset_ok = ok
        out.moveset = res
        local ok2, res2 = pcall(function() return info:InvokeServer("Stand") end)
        out.stand_probe = { ok = ok2, value = res2 }
    end
    out.stand_events = {}
    for _, c in ipairs(se:GetChildren()) do
        out.stand_events[#out.stand_events + 1] = c.Name .. ":" .. c.ClassName
    end
end

-- character value objects
local vals = {}
for _, d in ipairs(ch:GetDescendants()) do
    if d:IsA("ValueBase") then
        local ok, v = pcall(function() return d.Value end)
        if ok then vals[d.Name] = tostring(v) end
    end
end
out.character_values = vals

-- player Data folder
local data = lp:FindFirstChild("Data")
if data then
    local dv = {}
    for _, d in ipairs(data:GetDescendants()) do
        if d:IsA("ValueBase") then
            local ok, v = pcall(function() return d.Value end)
            if ok then dv[d.Name] = tostring(v) end
        end
    end
    out.data = dv
end

return out
