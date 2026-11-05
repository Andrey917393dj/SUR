-- Long-cooldown moves. Physics: 8s cooldown x 20 = ~170s per move.
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

local which = (getgenv and getgenv().AUDIT_SLOT) or 1
if which == 1 then
    auditMove("ACK counter (X)", Enum.KeyCode.X, 8.3)
    auditMove("ACK bearing (T)", Enum.KeyCode.T, 8.3)
else
    auditMove("ACK heavy (R)", Enum.KeyCode.R, 8.3)
    auditMove("ACK barrage (E)", Enum.KeyCode.E, 7.3)
end

local out = { slot = which, total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-24s %2d/%2d %dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
