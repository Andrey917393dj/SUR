-- Audit moves by SERVER ACKNOWLEDGEMENT (CoolDownGUI), not by "no error".
local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing" } end

local A = API.audit
A.results = {}

local function auditMove(label, key, gap, hold)
    A.run(label, function()
        API.ackReset()
        local ok = API.press(key, hold)
        if not ok then return false end
        local move = API.ackWait(1.2)
        return move ~= nil
    end, 20, gap)
end

auditMove("ACK punch (M1)", Enum.UserInputType.MouseButton1, 0.55)
auditMove("ACK summon (Q)", Enum.KeyCode.Q, 1.75)
auditMove("ACK block (G)", Enum.KeyCode.G, 1.25, 0.15)
auditMove("ACK quote (N)", Enum.KeyCode.N, 0.8)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-24s %2d/%2d %dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
