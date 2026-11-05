-- Batch C2: T / H / Y with an explicit summon before every attempt.
-- The batch-C run showed the ack is lost when the stand has been dismissed,
-- so PASS requires: summon -> press -> ack.
local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing" } end
local A = API.audit
A.results = {}

local function move(label, key, gap, wait)
    A.run(label, function()
        API.press(Enum.KeyCode.Q)
        task.wait(1.6)
        API.ackReset()
        local ok = API.press(key)
        if not ok then return false end
        return API.ackWait(wait or 3.0) ~= nil
    end, 20, gap)
end

move("T Bearing Shots (ack)", Enum.KeyCode.T, 8.6)
move("H Timeskip (ack)",      Enum.KeyCode.H, 6.6)
move("Y Timestop (ack)",      Enum.KeyCode.Y, 6.6)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-24s %2d/%2d %6dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
