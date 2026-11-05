-- Batch E: M1 combo-aware + useTool, 20x each.
local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing" } end
local A = API.audit
A.results = {}

-- M1 with the plain gap used in batch A (0.45s) -> known to drop every 6th hit.
A.run("M1 gap 0.45 (ack)", function()
    API.ackReset()
    local ok = API.press(Enum.UserInputType.MouseButton1)
    if not ok then return false end
    return API.ackWait(0.9) ~= nil
end, 20, 0.45)

-- M1 with a combo-aware gap: the client combo window closes after 5 hits.
A.run("M1 gap 0.85 (ack)", function()
    API.ackReset()
    local ok = API.press(Enum.UserInputType.MouseButton1)
    if not ok then return false end
    return API.ackWait(0.9) ~= nil
end, 20, 0.85)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-22s %2d/%2d %6dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
