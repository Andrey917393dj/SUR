-- DIAG: why do T / H / Y lose their ack?
local API = getgenv().ArcticAPI
local LP = game:GetService("Players").LocalPlayer
local char = LP.Character
local out = {}

-- what state objects exist on the character
local kids = {}
for _, c in ipairs(char:GetChildren()) do kids[#kids + 1] = c.Name .. "[" .. c.ClassName .. "]" end
out.charChildren = kids

local aura = char:FindFirstChild("Aura")
out.aura = aura and tostring(aura.Value) or "no Aura"

local stand = char:FindFirstChild("Stand")
out.stand = stand and ("present: " .. stand.Name) or "absent"

-- does the stand child come and go?
local snap = {}
for i = 1, 12 do
    snap[#snap + 1] = i .. ":" .. (char:FindFirstChild("Stand") and "S" or "-")
        .. (char:FindFirstChild("Aura") and ("A=" .. tostring(char.Aura.Value)) or "")
    task.wait(1)
end
out.standTimeline = table.concat(snap, " ")

-- per-move ack with an explicit summon first
local function probe(key, label)
    local ok, ack = 0, 0
    local detail = {}
    for i = 1, 6 do
        API.press(Enum.KeyCode.Q)
        task.wait(1.6)
        API.ackReset()
        local p = API.press(key)
        local m = API.ackWait(3.0)
        if p then ok = ok + 1 end
        if m then ack = ack + 1 end
        detail[#detail + 1] = i .. ":press=" .. tostring(p) .. " ack=" .. tostring(m)
        task.wait(8.5)
    end
    out[label] = { press = ok, ack = ack, detail = detail }
end

probe(Enum.KeyCode.T, "T")
probe(Enum.KeyCode.H, "H")
probe(Enum.KeyCode.Y, "Y")

return out
