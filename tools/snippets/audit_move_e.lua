-- Single-move audit x20 (long cooldown).
local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing" } end

local A = API.audit
A.results = {}

A.run("ACK barrage (E)", function()
    API.ackReset()
    local ok = API.press(Enum.KeyCode.E)
    if not ok then return false end
    local move = API.ackWait(1.2)
    return move ~= nil
end, 20, 7.3)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-24s %2d/%2d %dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
