-- RECON 2: per-stand movesets + stand model inventory
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local LP = game:GetService("Players").LocalPlayer
local out = {}

local me = WS:FindFirstChild("Living") and WS.Living:FindFirstChild(LP.Name)
local SE = me and me:FindFirstChild("StandEvents")
local info = SE and SE:FindFirstChild("Info")
if not info then return { err = "no StandEvents.Info" } end

-- 1. plain moveset
local ok, m = pcall(function() return info:InvokeServer("Moveset") end)
out.moveset = { ok = ok, value = m }

-- 2. does Info accept a stand code as a second argument?
local snc = RS:FindFirstChild("StandNameConvert")
local codes = {}
if snc then
    for _, v in ipairs(snc:GetChildren()) do codes[#codes + 1] = v.Name end
end
out.standCount = #codes

local tries = {}
for i = 1, math.min(6, #codes) do
    local code = codes[i]
    local ok2, r2 = pcall(function() return info:InvokeServer("Moveset", code) end)
    tries[#tries + 1] = code .. " -> ok=" .. tostring(ok2) .. " " .. tostring(r2)
end
out.movesetWithArg = tries

-- 3. what other Info commands exist (probe common keys)
local probes = {}
for _, k in ipairs({ "Moveset", "Stand", "Name", "Tier", "Attri", "Stats", "Info", "Data" }) do
    local ok3, r3 = pcall(function() return info:InvokeServer(k) end)
    probes[#probes + 1] = k .. " -> ok=" .. tostring(ok3) .. " " .. tostring(r3)
end
out.infoProbes = probes

-- 4. stand models present in the server right now
local living = WS:FindFirstChild("Living")
local models = {}
if living then
    for _, plr in ipairs(living:GetChildren()) do
        local st = plr:FindFirstChild("Stand")
        if st then
            local d = plr:FindFirstChild("Data")
            local sv = d and d:FindFirstChild("Stand")
            models[#models + 1] = plr.Name .. " | " .. tostring(sv and sv.Value)
                .. " | model=" .. st.Name .. " parts=" .. #st:GetDescendants()
        end
    end
end
out.standModels = { count = #models, list = models }

return out
