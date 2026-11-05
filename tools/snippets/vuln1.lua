-- VULN PROBE 1: quest state, shop validation, ketchup, free items
local RS = game:GetService("ReplicatedStorage")
local LP = game:GetService("Players").LocalPlayer
local EV = RS:WaitForChild("Events")
local out = {}

local function dataVal(n)
    local d = LP:FindFirstChild("Data")
    return d and d:FindFirstChild(n)
end
local function cash() return dataVal("Cash") and dataVal("Cash").Value or -1 end
local function exp()  return dataVal("Exp")  and dataVal("Exp").Value  or -1 end
local function lvl()  return dataVal("Level") and dataVal("Level").Value or -1 end

out.before = { cash = cash(), exp = exp(), level = lvl() }

-- ── 1. quest catalogue (replicated, so we can read rewards) ────
local Q = RS:FindFirstChild("Quests")
if Q then
    local list = {}
    for _, q in ipairs(Q:GetChildren()) do
        local function v(n) local x = q:FindFirstChild(n) return x and x.Value end
        list[#list + 1] = {
            name = q.Name,
            type = tostring(v("Type")),
            enemy = tostring(v("Enemy")),
            kills = v("Kills"),
            max = v("MaxKills"),
            cash = v("CashReward"),
            exp = v("ExpReward"),
            done = v("Completed"),
        }
    end
    out.quests = { count = #list, list = list }
else
    out.quests = "no ReplicatedStorage.Quests"
end

-- ── 2. can the client force a quest complete? ──────────────────
if Q then
    local probe
    for _, q in ipairs(Q:GetChildren()) do
        local k, m = q:FindFirstChild("Kills"), q:FindFirstChild("MaxKills")
        if k and m and k:IsA("NumberValue") and m:IsA("NumberValue")
           and k.Value < m.Value then probe = q break end
    end
    if probe then
        local k, m = probe.Kills, probe.MaxKills
        local orig = k.Value
        k.Value = m.Value
        task.wait(0.8)
        out.questWrite = {
            quest = probe.Name,
            orig = orig,
            max = m.Value,
            after = k.Value,
            stuck = k.Value == m.Value,
            completed = probe:FindFirstChild("Completed") and probe.Completed.Value,
        }
        k.Value = orig
    else
        out.questWrite = "no incomplete quest with Kills/MaxKills"
    end
end

-- ── 3. shop validation: garbage args must not cost anything ────
local function tryFire(name, ...)
    local r = EV:FindFirstChild(name)
    if not r then return name .. ": missing" end
    local args = { ... }
    local ok, err = pcall(function() r:FireServer(unpack(args)) end)
    return name .. ": ok=" .. tostring(ok) .. " err=" .. tostring(err)
end

local c0 = cash()
out.buyInvalid = tryFire("BuyItem", "NOPE_SHOP_ZZZ", "NOPE_OPTION")
task.wait(0.8)
out.buyInvalidCash = { before = c0, after = cash(), delta = cash() - c0 }

local c1 = cash()
out.buyEmpty = tryFire("BuyItem")
task.wait(0.8)
out.buyEmptyCash = { before = c1, after = cash(), delta = cash() - c1 }

-- ── 4. ketchup sell ───────────────────────────────────────────
local bag = {}
for _, t in ipairs(LP.Backpack:GetChildren()) do bag[#bag + 1] = t.Name end
out.backpack = bag
local hasK = false
for _, n in ipairs(bag) do if n == "Ketchup" then hasK = true end end

if hasK then
    local c2 = cash()
    out.sellKetchup = tryFire("SellKetchup", "Lots")
    task.wait(1.0)
    out.sellKetchupCash = { before = c2, after = cash(), delta = cash() - c2 }
else
    out.sellKetchup = "no Ketchup in backpack"
end

-- ── 5. free item remotes ──────────────────────────────────────
local free = {}
for _, r in ipairs(EV:GetChildren()) do
    if r.Name == "GiveFreeItem" then
        local ok, err = pcall(function() r:FireServer() end)
        free[#free + 1] = "fired ok=" .. tostring(ok) .. " err=" .. tostring(err)
    end
end
task.wait(0.8)
out.giveFreeItem = free

out.after = { cash = cash(), exp = exp(), level = lvl() }
return out
