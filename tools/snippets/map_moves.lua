-- Fire every key in the moveset, record which move the server acknowledges.
local rs = game:GetService("ReplicatedStorage")
local lp = game:GetService("Players").LocalPlayer
local ch = lp.Character
local se = ch and ch:FindFirstChild("StandEvents")
local input = se and se:FindFirstChild("Input")
local info = se and se:FindFirstChild("Info")

local ev = rs:FindFirstChild("Events")
local cd = ev and ev:FindFirstChild("CoolDownGUI")

local moveset = info:InvokeServer("Moveset")

local current = nil
local conn = cd.OnClientEvent:Connect(function(name, value)
    current = tostring(name) .. " | " .. tostring(value)
end)

local results = {}

for _, key in ipairs(moveset) do
    local isMouse = (key == Enum.UserInputType.MouseButton1 or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard
    current = nil

    pcall(function()
        input:FireServer({ State = "Begin", Key = key, Type = utype })
    end)
    task.wait(0.12)
    pcall(function()
        input:FireServer({ State = "End", Key = key, Type = utype })
    end)

    -- wait up to 2.5s for a cooldown acknowledgement
    local waited = 0
    while waited < 2.5 and current == nil do
        task.wait(0.1)
        waited = waited + 0.1
    end

    results[#results + 1] = {
        key = tostring(key),
        move = current or "NO RESPONSE"
    }
    task.wait(0.6)
end

pcall(function() conn:Disconnect() end)
return { count = #results, moves = results }
