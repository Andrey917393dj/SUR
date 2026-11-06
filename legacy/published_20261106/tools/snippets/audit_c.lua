-- Batch C: T (Bearing Shots), H (Timeskip), Y (Timestop), 20x each.
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

move("T Bearing Shots (ack)", Enum.KeyCode.T, true, 8.30, 2.0)
move("H Timeskip (ack)",      Enum.KeyCode.H, true, 6.30, 2.0)
move("Y Timestop (ack)",      Enum.KeyCode.Y, true, 6.30, 2.0)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-24s %2d/%2d %6dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
