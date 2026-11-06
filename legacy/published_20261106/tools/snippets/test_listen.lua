-- Listen to server->client remotes, fire a move, see what the server answers.
local rs = game:GetService("ReplicatedStorage")
local lp = game:GetService("Players").LocalPlayer
local ch = lp.Character
local se = ch and ch:FindFirstChild("StandEvents")
local input = se and se:FindFirstChild("Input")

local watch = {
    "CoolDownGUI", "Vfx", "StatsUpdate", "Quote", "GeneralNotif", "CashNotif",
    "ItemNotifEvent", "CamShake", "NewBarrageEffect", "Afterimage", "Effects",
    "ReplicateFX", "TSEffect", "TimeskipEffect", "Visible", "PromptGui"
}

local log = {}
local conns = {}

local ev = rs:FindFirstChild("Events")
if ev then
    for _, name in ipairs(watch) do
        local r = ev:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then
            conns[#conns + 1] = r.OnClientEvent:Connect(function(...)
                local parts = {}
                local n = select("#", ...)
                for i = 1, math.min(n, 6) do
                    local v = select(i, ...)
                    local ok, s = pcall(function() return tostring(v) end)
                    parts[#parts + 1] = ok and s or "?"
                end
                log[#log + 1] = name .. "(" .. n .. "): " .. table.concat(parts, " | ")
            end)
        end
    end
end

task.wait(0.5)
local baseline = #log

-- fire M1 (basic attack) then Q
local fired = {}
for _, key in ipairs({ Enum.UserInputType.MouseButton1, Enum.KeyCode.Q }) do
    local ok1 = pcall(function()
        input:FireServer({ State = "Begin", Key = key, Type = key == Enum.UserInputType.MouseButton1
            and Enum.UserInputType.MouseButton1 or Enum.UserInputType.Keyboard })
    end)
    task.wait(0.2)
    pcall(function()
        input:FireServer({ State = "End", Key = key, Type = key == Enum.UserInputType.MouseButton1
            and Enum.UserInputType.MouseButton1 or Enum.UserInputType.Keyboard })
    end)
    fired[#fired + 1] = tostring(key) .. "=" .. tostring(ok1)
    task.wait(1.2)
end

task.wait(0.5)
for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

local tail = {}
for i = baseline + 1, #log do tail[#tail + 1] = log[i] end

return {
    fired = fired,
    ambient_before = baseline,
    responses = tail,
    response_count = #tail
}
