local API = getgenv().ArcticAPI
if not API then return { err = "ArcticAPI missing - script not loaded" } end

local A = API.audit
A.results = {}

A.run("standName()", function()
    local n = API.standName()
    return type(n) == "string" and #n > 0
end, 20, 0.1)

A.run("standAttri()", function()
    local n = API.standAttri()
    return type(n) == "string" and #n > 0
end, 20, 0.1)

A.run("moveset fetch", function()
    local m = API.moveset()
    return type(m) == "table" and #m > 0
end, 20, 0.15)

A.run("GetStandTier invoke", function()
    local t = API.invoke("GetStandTier", API.standName())
    return t ~= nil
end, 20, 0.15)

A.run("allNPCs()", function()
    local t = API.allNPCs()
    return type(t) == "table" and #t > 5
end, 20, 0.05)

A.run("worldTools()", function()
    local t = API.worldTools()
    return type(t) == "table"
end, 20, 0.05)

A.run("press M1 (punch)", function()
    return API.press(Enum.UserInputType.MouseButton1)
end, 20, 0.45)

A.run("press G (block)", function()
    return API.press(Enum.KeyCode.G, 0.15)
end, 20, 0.4)

local out = { total = #A.results }
for _, r in ipairs(A.results) do
    out[#out + 1] = string.format("%-24s %2d/%2d %dms", r.label, r.pass, r.total, r.ms)
    for _, e in ipairs(r.errors) do out[#out + 1] = "    " .. e end
end
return out
