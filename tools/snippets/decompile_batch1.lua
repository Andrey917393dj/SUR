local targets = {
    "StarterPlayer.StarterPlayerScripts.Client",
    "StarterPlayer.StarterPlayerScripts.EffectsHandler",
    "StarterPlayer.StarterPlayerScripts.ClientUsage",
    "StarterPlayer.StarterPlayerScripts.newSprintHandler",
}

local results = {}
for i, path in ipairs(targets) do
    local ok, inst = pcall(function()
        local cur = game
        for part in string.gmatch(path, "[^%.]+") do
            cur = cur:FindFirstChild(part)
            if not cur then error("missing: " .. part) end
        end
        return cur
    end)
    if not ok then
        results[#results + 1] = { path = path, err = "resolve: " .. tostring(inst) }
    else
        local okd, src = pcall(decompile, inst)
        if okd and type(src) == "string" then
            local f = string.format("sur_src_%02d.lua", i)
            writefile(f, src)
            results[#results + 1] = { path = path, file = f, len = #src }
        else
            results[#results + 1] = { path = path, err = "decompile: " .. tostring(src) }
        end
    end
end
return results
