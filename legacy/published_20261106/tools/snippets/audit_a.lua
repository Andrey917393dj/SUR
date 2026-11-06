-- Batch A: fast / utility moves, 20x each.
-- PASS rule: moves that the server ACKs (CoolDownGUI) must produce an ack.
--            moves that never ack are PASS on press()==true.
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

move("M1 Punch (ack)",     Enum.UserInputType.MouseButton1, true,  0.45, 0.9)
move("Q Summon (ack)",     Enum.KeyCode.Q,                  true,  1.70, 1.5)
move("G Block (ack)",      Enum.KeyCode.G,                  true,  1.20, 1.0)
move("N Quote (ack)",      Enum.KeyCode.N,                  true,  0.80, 1.0)
move("X Counter (press)",  Enum.KeyCode.X,                  false, 1.20)
move("Z (press)",          Enum.KeyCode.Z,                  false, 1.20)
move("F (press)",          Enum.KeyCode.F,                  false, 1.20)
move("J (press)",          Enum.KeyCode.J,                  false, 1.20)

A.run("moveset fetch", function()
    local m = API.moveset()
    return type(m) == "table" and #m > 0
end, 20, 0.20)

A.run("GetStandTier", function()
    local v = API.invoke("GetStandTier", API.standName())
    return v ~= nil
end, 20, 0.20)

A.run("standName()", function() return API.standName() ~= nil end, 20, 0.10)
A.run("standAttri()", function() return API.standAttri() ~= nil end, 20, 0.10)
A.run("allNPCs()", function()
    local n = API.allNPCs()
    return type(n) == "table" and #n > 0
end, 20, 0.15)
A.run("worldTools()", function()
    local t = API.worldTools()
    return type(t) == "table" and #t > 0
end, 20, 0.15)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-22s %2d/%2d %6dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
