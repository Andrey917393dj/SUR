-- Batch B: heavy hitters E (Barrage) + R (Heavy Punch), 20x each.
local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing" } end
local A = API.audit
A.results = {}

local function move(label, key, acks, gap, wait)
    A.run(label, function()
        if acks then
            API.ackReset()
            local ok = API.press(key)
            if not ok then return false end
            return API.ackWait(wait or 1.5) ~= nil
        end
        return API.press(key) == true
    end, 20, gap)
end

move("E Barrage (ack)",    Enum.KeyCode.E, true, 7.30, 2.0)
move("R Heavy Punch (ack)",Enum.KeyCode.R, true, 8.30, 2.0)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-22s %2d/%2d %6dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
