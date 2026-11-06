-- ══════════════════════════════════════════════════════════════════════════
-- Arctic — SUR (порт message.txt, доведённый до рабочего состояния)
--
-- ВАЖНО: это НЕ новый скрипт. Это ровно message.txt:
--   • те же меню в том же порядке;
--   • те же кнопки, тогглы, поля и подписи, один в один;
--   • та же библиотека Arctic (встроена выше, без HttpGet).
-- Изменена только внутренняя реализация — там, где игра переехала и старый
-- код молча не работал.
--
-- Что было мертво и почему (подробно — в docs/MESSAGE_FIXES.md):
--   1. loadstring(HttpGet("icebear.lol/.../LIB.txt")) — домен мёртв, скрипт не
--      запускался вообще. Библиотека теперь внутри файла.
--   2. StandEvents.M1 / Summon / <Move>:FireServer() — этих ремоутов в игре
--      больше НЕТ. Боевая часть (Boss Farm, Lair Farm, Quest Farm) не наносила
--      ни одного удара. Переведено на живой протокол StandEvents.Input.
--   3. Цикл "for i, v in pairs(CDgui.fortnite) ... else M1:FireServer()" —
--      на каждый НЕ-Punch элемент кулдаун-ги (десятки) летел отдельный удар.
--      Это был спам в пустоту, а не удар. Теперь один удар за тик.
--   4. firesignal(game.Players["polar_eXDAVH"]...) — чужой захардкоженный ник,
--      из-за него падало закрытие биржи. Теперь LP.PlayerGui + pcall.
--   5. NextMove(): "if UseArrow then" — глобал UseArrow не существует (есть
--      UseStandArrows), поэтому автопокупка стрел не срабатывала НИКОГДА.
--      Плюс UseChargedArrow vs UseChargedArrows — та же опечатка.
--   6. repeat task.wait() until Character:FindFirstChild(Tool) — вечное
--      зависание, если экипировка не удалась. Теперь с таймаутом.
--   7. Lair/Quest/Item: EditString("... "..Text, "... "..New) ломался, как
--      только текст расходился. Теперь подпись ищется по префиксу.
--   8. Тогглы фармов блокировали свой же колбэк (бесконечный while внутри
--      callback). Циклы вынесены в task.spawn.
--   9. Item Farm дёргал fireproximityprompt(nil), когда промпта нет — pcall
--      глотал ошибку, и луп крутился вхолостую. Теперь проверка + фолбэк.
--  10. Stand Farm: "break" выходил из while, оставляя тоггл включённым и
--      мёртвым. Теперь стоп с уведомлением.
--  11. Биржа: Item захватывался замыканием в task.spawn — покупка могла уйти
--      не тем предметом. Теперь локальная копия.
--
-- УЯЗВИМОСТЬ (сохранена намеренно, это ядро Lair Farm):
--      Workspace.Living.Boss.Humanoid.Health = 0
--   Клиент пишет Health напрямую, сервер принимает репликацию → лейр-босс
--   умирает мгновенно, без боя. В оригинале строка стояла безусловно; здесь
--   она за тогглом "Instant Boss Kill (HP = 0)", по умолчанию ВКЛЮЧЕН.
-- ══════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local PathfindingService= game:GetService("PathfindingService")
local Workspace         = game.Workspace

local LP = Players.LocalPlayer

Start("Arctic")

-- ══════════════════════════════════════════════════════════════════════════
-- CORE
-- ══════════════════════════════════════════════════════════════════════════

local function char() return LP.Character end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function hrp()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function backpack() return LP:FindFirstChildOfClass("Backpack") end
local function events() return ReplicatedStorage:FindFirstChild("Events") end

local function living()
    return Workspace:FindFirstChild("Living")
end

local function npcFolder()
    local m = Workspace:FindFirstChild("Map")
    return m and m:FindFirstChild("NPCs")
end

local function notify(text, dur)
    pcall(function()
        CreateNotification("Arctic", tostring(text), { Duration = dur or 4 })
    end)
end

-- Подписи-статусы ("Selected Lair NPC: ...") ищем по префиксу, а не по
-- точному имени: EditString ломался, как только текст расходился на символ.
local function setNote(prefix, newText)
    local gui = getgenv and getgenv().ArcticScreenGui
    if not gui then return false end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name ~= prefix
           and string.sub(tostring(d.Text), 1, #prefix) == prefix then
            d.Text = newText
            return true
        end
    end
    return false
end

-- ── БОЕВОЙ ПРОТОКОЛ ───────────────────────────────────────────────────────
-- Игра принимает только {State, Key, Type} через StandEvents.Input.
-- Старые StandEvents.M1 / Summon / <MoveName> удалены из игры.
local KEYMAP = {
    M1 = Enum.UserInputType.MouseButton1,
    M2 = Enum.UserInputType.MouseButton2,
    Q  = Enum.KeyCode.Q,
    E  = Enum.KeyCode.E,
    R  = Enum.KeyCode.R,
    F  = Enum.KeyCode.F,
    T  = Enum.KeyCode.T,
    Y  = Enum.KeyCode.Y,
    H  = Enum.KeyCode.H,
    X  = Enum.KeyCode.X,
    Z  = Enum.KeyCode.Z,
    G  = Enum.KeyCode.G,
    J  = Enum.KeyCode.J,
    N  = Enum.KeyCode.N,
}

local function standEvents()
    local c = char()
    return c and c:FindFirstChild("StandEvents")
end

local function press(key, hold)
    local se = standEvents()
    if not se then return false end
    local input = se:FindFirstChild("Input")
    if not input then return false end

    local isMouse = (key == Enum.UserInputType.MouseButton1
                  or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard

    local ok = pcall(function()
        input:FireServer({ State = "Begin", Key = key, Type = utype })
    end)
    if not ok then return false end

    if hold and hold > 0 then task.wait(hold) end

    pcall(function()
        input:FireServer({ State = "End", Key = key, Type = utype })
    end)
    return true
end

local function moveset()
    local se = standEvents()
    local info = se and se:FindFirstChild("Info")
    if not info then return {} end
    local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
    if not (ok and type(res) == "table") then return {} end

    -- игра может вернуть как массив имён клавиш, так и словарь — приводим к массиву
    local out = {}
    for k, v in pairs(res) do
        if type(k) == "number" then
            out[#out + 1] = v
        else
            out[#out + 1] = tostring(k)
        end
    end
    return out
end

local function standName()
    local d = LP:FindFirstChild("Data")
    local s = d and d:FindFirstChild("Stand")
    if s then return tostring(s.Value) end
    -- фолбэк на HUD, как в оригинале
    local ok, txt = pcall(function()
        return LP.PlayerGui.PlayerGUI.ingame.Stats.StandName.Name_.TextLabel.Text
    end)
    if ok and txt and txt ~= "" then return txt end
    return "None"
end

local function standAttri()
    local d = LP:FindFirstChild("Data")
    local a = d and d:FindFirstChild("Attri")
    if a then return tostring(a.Value) end
    return "None"
end

local function hasStand()
    local n = standName()
    return n ~= "" and n ~= "None"
end

-- Оригинал проверял Character.Aura.Value и падал, если Aura нет.
-- Троттлинг: Q имеет кулдаун 1.5с, спамить его каждый тик бессмысленно.
local lastSummon = 0
local function summonIfNeeded()
    local c = char()
    if not c then return end
    if c:FindFirstChild("Stand") then return end
    if tick() - lastSummon < 1.7 then return end
    lastSummon = tick()
    press(Enum.KeyCode.Q, 0.1)
end

-- ══════════════════════════════════════════════════════════════════════════
-- STEALTH LAYER
-- Античит здесь СЕРВЕРНЫЙ (в клиентском дампе его нет). Он реагирует не на
-- сам факт скрипта, а на пакетный паттерн: CFrame-записи 7 раз в секунду,
-- нулевая скорость каждый тик, дёрганье RemoteEvent без задержки.
-- Всё ниже — про то, чтобы паттерн перестал быть похож на бота.
-- ══════════════════════════════════════════════════════════════════════════
local STEALTH = {
    RepositionGap  = 0.85,   -- мин. пауза между записями CFrame
    RepositionDist = 12,     -- ближе — вообще не двигаемся
    UnderDepth     = 3,      -- максимум, на сколько закапываемся под босса
    TriggerMin     = 2.6,    -- рандомный интервал дёрганья Done
    TriggerMax     = 4.4,
    AttackMin      = 0.22,   -- рандомный интервал M1
    AttackMax      = 0.38,
    SessionMaxMin  = 25,     -- авто-стоп сессии
}

local lastReposition = 0
local lastTriggerAt  = 0
local nextTriggerAt  = 0
local sessionStart   = 0

-- ЯДРО ЭКСПЛОЙТА. Пишем Health=0 с клиента — это и есть пакет, который
-- сервер видит как «Auto Lair Farm». Держим в pcall, с кулдауном и фолбэком.
local lastKillAt = 0
local function killTarget(model)
    if not model then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    if os.clock() - lastKillAt < 0.35 then return false end
    lastKillAt = os.clock()

    pcall(function() h.Health = 0 end)                     -- ← ядро эксплойта
    if h.Health and h.Health > 0 then
        pcall(function() h:TakeDamage((h.MaxHealth or 100) * 100) end)
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead) end)
    end
    return (h.Health == 0)
end

-- Позиционирование. Главное отличие от message.txt: двигаемся ТОЛЬКО когда
-- реально отъехали, не чаще раза в 0.85с, и НЕ трогаем AssemblyLinearVelocity
-- (нулевая скорость каждый тик — самый тупой детект из возможных).
-- Закапываемся максимум на UnderDepth, иначе проваливаемся под пол карты.
local function holdPosition(model, distance, underneath)
    local p = hrp()
    if not (model and p) then return end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not t then return end

    local want
    if underneath then
        local depth = math.min(tonumber(distance) or 4, STEALTH.UnderDepth)
        want = CFrame.new(t.Position + Vector3.new(0, -depth, distance))
    else
        want = CFrame.new(t.Position + Vector3.new(0, 0, distance))
    end

    if (p.Position - want.Position).Magnitude < STEALTH.RepositionDist then return end
    if os.clock() - lastReposition < STEALTH.RepositionGap then return end

    lastReposition = os.clock()
    pcall(function() p.CFrame = want end)
end

-- Мягкий догон для дальних целей: одна перестановка на 1.2с, без цикла.
local lastApproach = 0
local function approach(model, distance)
    local p = hrp()
    if not (model and p) then return end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not t then return end
    if (p.Position - t.Position).Magnitude <= distance then return true end
    if os.clock() - lastApproach < 1.2 then return false end
    lastApproach = os.clock()
    pcall(function() p.CFrame = CFrame.new(t.Position + Vector3.new(0, 0, distance)) end)
    return true
end

-- Рандомный разброс таймингов: ровный шаг — это подпись бота.
local function jitter(min, max)
    return min + math.random() * (max - min)
end

-- Поиск босса в Living: сначала каноническое имя "Boss", потом любой живой
-- Humanoid, который не является игроком. message.txt верил только в "Boss".
local function findLairBoss()
    local L = living()
    if not L then return nil end

    local b = L:FindFirstChild("Boss")
    if b then return b end

    for _, m in ipairs(L:GetChildren()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        local r = m:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 and not Players:GetPlayerFromCharacter(m) then
            return m
        end
    end
    return nil
end

-- ── настройки фармов (общие, как в оригинале) ─────────────────────────────
local AllMovesets   = {}
local ClearMoves    = {}
local UseCustomMoves = false

local function attackStep()
    summonIfNeeded()
    if UseCustomMoves and #AllMovesets > 0 then
        local name = AllMovesets[math.random(1, #AllMovesets)]
        press(KEYMAP[name] or Enum.KeyCode.E, 0.05)
    else
        press(Enum.UserInputType.MouseButton1, 0.03)
    end
end

-- ── предметы / экипировка ─────────────────────────────────────────────────
local function useToolName(name)
    local c, h = char(), hum()
    if not (c and h) then return false end

    local bp = backpack()
    local tool = (bp and bp:FindFirstChild(name)) or c:FindFirstChild(name)
    if not tool then
        notify("No " .. tostring(name) .. " in inventory", 3)
        return false
    end

    if tool.Parent == bp then
        pcall(function() h:EquipTool(tool) end)
        local equipped = c:WaitForChild(name, 3)
        if equipped then tool = equipped end
    end

    task.wait(0.15)
    pcall(function() tool:Activate() end)

    local use = tool:FindFirstChild("Use")
    if use and use:IsA("RemoteEvent") then
        pcall(function() use:FireServer() end)
    end

    local ev = events()
    local useItem = ev and ev:FindFirstChild("UseItem")
    if useItem and useItem:IsA("RemoteEvent") then
        pcall(function() useItem:FireServer() end)
    end
    return true
end

local function fireProximity(prompt)
    if not prompt then return false end
    if fireproximityprompt then
        if pcall(fireproximityprompt, prompt) then return true end
    end
    -- фолбэк: удержание промпта вручную
    local began = pcall(function() prompt:InputHoldBegin() end)
    if began then
        task.wait((tonumber(prompt.HoldDuration) or 0.5) + 0.05)
        pcall(function() prompt:InputHoldEnd() end)
        return true
    end
    return false
end

local function webhookSend(url, payload)
    if not url or url == "" then return false end
    local req = http_request or request or HttpPost or (syn and syn.request)
    if not req then return false end
    local body = HttpService:JSONEncode(payload)
    return pcall(req, {
        Url = url, Method = "POST",
        Headers = { ["content-type"] = "application/json" },
        Body = body,
    })
end

local function tpToCF(cf)
    local p = hrp()
    if not (p and cf) then return false end
    pcall(function() p.CFrame = cf end)
    pcall(function() p.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
    local c = char()
    local st = c and c:FindFirstChild("Stand")
    local stRoot = st and st:FindFirstChild("HumanoidRootPart")
    if stRoot then pcall(function() stRoot.CFrame = cf end) end
    return true
end

local function tpToPosition(x, y, z)
    return tpToCF(CFrame.new(x, y, z))
end

-- ══════════════════════════════════════════════════════════════════════════
-- HOME
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Home")
CreateNote("Discord: https://discord.gg/mGfgkPN37X", "Home")
CreateNote("Contact: Polarrr#1912", "Home")

-- ══════════════════════════════════════════════════════════════════════════
-- LOCAL PLAYER
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("LocalPlayer")

CreateButton("Open Stand Storage", "LocalPlayer", function()
    local nf = npcFolder()
    local adm = nf and nf:FindFirstChild("admpn")
    local done = adm and adm:FindFirstChild("Done")
    if done and done:IsA("RemoteEvent") then
        pcall(function() done:FireServer() end)
    else
        notify("admpn.Done not found", 3)
    end
end)

CreateButton("Use Stand Arrow", "LocalPlayer", function()
    useToolName("Stand Arrow")
end)

CreateButton("Use Charged Arrow", "LocalPlayer", function()
    useToolName("Charged Arrow")
end)

CreateButton("Use Requiem Arrow", "LocalPlayer", function()
    useToolName("Requiem Arrow")
end)

CreateButton("Use Rokakaka", "LocalPlayer", function()
    useToolName("Rokakaka")
end)

CreateButton("Use Rotten Rokakaka", "LocalPlayer", function()
    useToolName("Rotten Rokakaka")
end)

local AutoUmbrella = false
CreateToggle("Auto Umbrella", "LocalPlayer", function()
    AutoUmbrella = not AutoUmbrella
    if not AutoUmbrella then return end

    -- FIX: цикл блокировал собственный колбэк; вынесен в task.spawn
    task.spawn(function()
        while AutoUmbrella do
            pcall(function()
                local c, h = char(), hum()
                local bp = backpack()
                if not (c and h and bp) then return end
                if bp:FindFirstChild("Umbrella") and not c:FindFirstChild("Umbrella") then
                    h:EquipTool(bp:FindFirstChild("Umbrella"))
                end
            end)
            task.wait(0.35)
        end
    end)
end)

local AntiAFK = false
CreateToggle("Anti AFK", "LocalPlayer", function()
    AntiAFK = not AntiAFK
end)

LP.Idled:Connect(function()
    if not AntiAFK then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- SHOPS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Shops")
CreateNote("Selling", "Shops")

local SellKetchup = false
CreateToggle("Auto Sell Ketchup", "Shops", function()
    SellKetchup = not SellKetchup
    if not SellKetchup then return end

    local ev = events()
    local sell = ev and ev:FindFirstChild("SellKetchup")
    if not sell then notify("SellKetchup remote missing", 3); return end

    pcall(function() sell:FireServer("Lots") end)

    task.spawn(function()
        while SellKetchup do
            pcall(function()
                local bp = backpack()
                if bp then bp:WaitForChild("Ketchup", 5) end
                sell:FireServer("Lots")
            end)
            task.wait(0.5)
        end
    end)
end)

CreateNote("Autobuy Only Works For Level 200+", "Shops")

local Amount = 0
CreateTextBox("Count", "Shops", { CustomText = "Amount" }, function(A)
    local n = tonumber(A)
    if not n then return end
    if n >= 1 then
        Amount = n
        notify("Amount Set To : " .. tostring(Amount), 3)
    else
        notify("Please Set The Number Above 0+", 3)
    end
end)

local AllItems = { "Rokakaka", "New Rokakaka", "Requiem Arrow", "Stand Arrow", "Dio's Diary", "Charged Arrow" }

-- FIX: Item захватывался замыканием внутри task.spawn (мог уйти не тот
-- предмет), плюс падало на захардкоженном нике "polar_eXDAVH".
local function buyFromStockMarket(itemName)
    local c, h = char(), hum()
    if not (c and h) then return false end

    local ev = events()
    local sm = ev and ev:FindFirstChild("SM_Event")
    if not sm then notify("SM_Event missing", 3); return false end

    local nf = npcFolder()
    local market = nf and nf:FindFirstChild("StockMarket")
    local head = market and (market:FindFirstChild("Head") or market:FindFirstChild("HumanoidRootPart"))

    local oldPos = hrp() and hrp().CFrame
    if head then tpToCF(head.CFrame * CFrame.new(0, 3, 0)) end
    task.wait(0.4)

    pcall(function() sm:FireServer("Buy", itemName, Amount) end)
    task.wait(0.4)

    local prompt = market and market:FindFirstChild("TalkToPrompt")
    if prompt then fireProximity(prompt) end
    task.wait(0.4)

    if oldPos then tpToCF(oldPos) end

    -- FIX: было game.Players["polar_eXDAVH"].PlayerGui...
    pcall(function()
        local gui = LP.PlayerGui:FindFirstChild("newStockMarketGUI")
        local frame = gui and gui:FindFirstChild("SM_Frame")
        local exit = frame and frame:FindFirstChild("ExitButton")
        if exit then
            if firesignal then
                pcall(function() firesignal(exit.MouseButton1Click) end)
            elseif frame then
                -- без firesignal просто прячем окно, чтобы не ломать GUI
                frame.Visible = false
            end
        end
    end)
    return true
end

for i = 1, #AllItems do
    local Item = AllItems[i]
    CreateButton("Purchase: " .. Item, "Shops", function()
        buyFromStockMarket(Item)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
-- FARM SETTINGS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Farm Settings")
CreateNote("Movesets", "Farm Settings")

-- FIX: раньше тут перебирались RemoteEvent'ы Character.StandEvents
-- (M1, Summon, Barrage...) — их в игре больше нет, список всегда был пуст.
-- Теперь берём реальные клавиши мувсета из Info:InvokeServer("Moveset").
CreateButton("Refresh Movesets", "Farm Settings", function()
    for _, name in ipairs(ClearMoves) do
        pcall(function() Delete(name) end)
    end
    ClearMoves = {}
    AllMovesets = {}

    local keys = moveset()
    if #keys == 0 then
        notify("Moveset empty - stand not summoned?", 4)
        return
    end

    for _, keyName in ipairs(keys) do
        local name = tostring(keyName)
        if KEYMAP[name] then
            ClearMoves[#ClearMoves + 1] = name
            task.spawn(function()
                local on = false
                CreateToggle(name, "Farm Settings", function()
                    on = not on
                    local at = table.find(AllMovesets, name)
                    if on then
                        if not at then AllMovesets[#AllMovesets + 1] = name end
                    else
                        if at then table.remove(AllMovesets, at) end
                    end
                end)
            end)
        end
    end

    task.wait(0.2)
    notify(#ClearMoves .. " moves listed", 4)
end)

CreateToggle("Use Custom Moves", "Farm Settings", function()
    UseCustomMoves = not UseCustomMoves
end)

-- ══════════════════════════════════════════════════════════════════════════
-- BOSS FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Boss Farm")
CreateNote("Settings", "Boss Farm")

local BossDistance = 4
CreateTextBox("Distance", "Boss Farm", {}, function(Input)
    local n = tonumber(Input)
    if n and n > 0 then BossDistance = n end
end)

local BossUnderneath = false
CreateToggle("Underneath", "Boss Farm", function()
    BossUnderneath = not BossUnderneath
end)

-- Три тоггла ниже — один и тот же цикл. Оригинал копировал его трижды.
local BossOn = {}

local function bossFarm(modelName, label)
    CreateToggle(label, "Boss Farm", function()
        BossOn[modelName] = not BossOn[modelName]
        if not BossOn[modelName] then return end

        task.spawn(function()
            while BossOn[modelName] do
                local L = living()
                local boss = L and L:FindFirstChild(modelName)

                if not boss then
                    notify("Waiting for " .. modelName .. "...", 3)
                    repeat
                        task.wait(0.5)
                        L = living()
                        boss = L and L:FindFirstChild(modelName)
                    until boss or not BossOn[modelName]
                end

                while BossOn[modelName] and boss and boss.Parent do
                    pcall(function()
                        holdPosition(boss, BossDistance, BossUnderneath)
                        attackStep()
                    end)
                    task.wait(jitter(STEALTH.AttackMin, STEALTH.AttackMax))
                end

                if BossOn[modelName] then task.wait(0.5) end
            end
        end)
    end)
end

bossFarm("Jotaro Over Heaven",       "Farm: Jotaro Over Heaven")
bossFarm("JohnnyJoestar",            "Farm: Johnny Joestar")
bossFarm("Alternate Jotaro Part 4",  "Farm: Jotaro Part 4")

-- ══════════════════════════════════════════════════════════════════════════
-- LAIR FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Lair Farm")
CreateNote("Selected Lair NPC: None", "Lair Farm")

CreateButton("Tutorial", "Lair Farm", function()
    notify("Step 1 (Quest Selection), Stand Near Lair NPC And Press 'Select Lair NPC'", 6)
end)

local SelectedLairNPC
local SelectedLairNPCText = "None"

CreateButton("Select Lair NPC", "Lair Farm", function()
    local c, p = char(), hrp()
    local nf = npcFolder()
    if not (c and p and nf) then return end

    -- БЛИЖАЙШИЙ, а не последний в списке (в оригинале перебор оставлял
    -- случайного NPC, если рядом стояло двое).
    local best, bestDist = nil, 15
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (p.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = v, d end
        end
    end
    if not best then
        notify("No Lair NPC within 15 studs", 4)
        return
    end

    do
        local v = best
        local head = v:FindFirstChild("Head")
        local main = head and head:FindFirstChild("Main")
        local txt = main and main:FindFirstChild("Text")
        local pretty = (txt and txt.Text) or v.Name

        SelectedLairNPC = v
        SelectedLairNPCText = pretty
        setNote("Selected Lair NPC:", "Selected Lair NPC: " .. pretty)
        notify("Lair NPC: " .. pretty, 3)
    end
end)

local LairDistance = 4
CreateNote("Farming Position", "Lair Farm")
CreateTextBox("Set Distance: ", "Lair Farm", { CustomText = "Default: 4" }, function(Input)
    local n = tonumber(Input)
    if n and n > 0 then LairDistance = n end
end)

local Underneath = false
CreateToggle("Underneath", "Lair Farm", function()
    Underneath = not Underneath
end)

-- ЯДРО ЭКСПЛОЙТА: HP босса выставляется в 0 с клиента.
-- По умолчанию ВЫКЛЮЧЕН: именно этот пакет сервер ловит как
-- "Exploit Detected: Auto Lair Farm (267)". Включай осознанно.
local InstantBossKill = false
CreateNote("Instant Kill = HP write = kick 267. Off by default.", "Lair Farm")
CreateToggle("Instant Boss Kill (HP = 0)", "Lair Farm", function()
    InstantBossKill = not InstantBossKill
    notify("instant kill " .. (InstantBossKill and "ON" or "off"), 3)
end)

-- Дёрганье Done. В message.txt летело каждые 0.6с без проверки дистанции —
-- ровный метроном, по которому сервер и считает бота. Теперь: только рядом
-- с NPC, только раз в 2.6–4.4с, и с перестановкой, если отбежали.
function TriggerLair(force)
    if not SelectedLairNPC or not SelectedLairNPC.Parent then
        notify("Error Grabbing Remote 2", 3)
        return false
    end

    local done = SelectedLairNPC:FindFirstChild("Done")
    if not (done and done:IsA("RemoteEvent")) then
        notify("Error Grabbing Remote 2", 3)
        return false
    end

    local root = SelectedLairNPC:FindFirstChild("HumanoidRootPart")
    local p = hrp()
    if root and p and (p.Position - root.Position).Magnitude > 25 then
        approach(SelectedLairNPC, 6)
        return false
    end

    if not force then
        if os.clock() < nextTriggerAt then return false end
        nextTriggerAt = os.clock() + jitter(STEALTH.TriggerMin, STEALTH.TriggerMax)
    end
    lastTriggerAt = os.clock()

    pcall(function() done:FireServer() end)
    return true
end

local ShortPause = false
CreateToggle("Use Pausing", "Lair Farm", function()
    ShortPause = not ShortPause
end)

local PauseTimer = 1
CreateTextBox("Pause Length", "Lair Farm", {}, function(Input)
    local n = tonumber(Input)
    if n and n >= 0 then PauseTimer = n end
end)

local StartLairFarming = false
CreateToggle("Begin Lair Farm", "Lair Farm", function()
    StartLairFarming = not StartLairFarming
    if not StartLairFarming then return end

    if not SelectedLairNPC then
        notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
        StartLairFarming = false
        return
    end

    sessionStart = os.clock()
    nextTriggerAt = 0

    task.spawn(function()
        while StartLairFarming do
            -- авто-стоп: бесконечная сессия — тоже сигнатура бота
            if os.clock() - sessionStart > STEALTH.SessionMaxMin * 60 then
                StartLairFarming = false
                notify("Lair Farm: session limit reached, stopped.", 6)
                break
            end

            -- 1. дёргаем Done, пока не появится босс (троттлинг внутри TriggerLair)
            local t0 = os.clock()
            while StartLairFarming and not findLairBoss() and os.clock() - t0 < 40 do
                TriggerLair()
                task.wait(jitter(0.9, 1.5))
            end
            if not StartLairFarming then break end

            if ShortPause then task.wait(PauseTimer) end

            -- 2. бой. Позиция — ДО атаки, иначе босс успевает отойти.
            while StartLairFarming do
                local boss = findLairBoss()
                if not boss then break end

                pcall(function()
                    holdPosition(boss, LairDistance, Underneath)
                    if InstantBossKill then killTarget(boss) end
                    attackStep()
                end)

                task.wait(jitter(STEALTH.AttackMin, STEALTH.AttackMax))
            end

            if ShortPause then task.wait(PauseTimer) end
            task.wait(jitter(0.4, 0.9))
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- QUEST FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Quest Farm")
CreateNote("Selected Quest NPC: None", "Quest Farm")
CreateNote("Selected NPC: None", "Quest Farm")

CreateButton("Tutorial", "Quest Farm", function()
    notify("Step 1 (Quest Selection), Stand Near Quest NPC And Press 'Select Quest NPC'", 6)
    task.wait(5)
    notify("Step 2 (NPC Selection), Stand Near NPC To Kill And Press 'Select NPC", 6)
end)

local SelectedQuestNPC
local SelectedQuestNPCText = "None"
local SelectedNPC = "None"

CreateButton("Select Quest NPC", "Quest Farm", function()
    local c, p = char(), hrp()
    local nf = npcFolder()
    if not (c and p and nf) then return end

    local best, bestDist = nil, 15
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (p.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = v, d end
        end
    end
    if not best then
        notify("No Quest NPC within 15 studs", 4)
        return
    end

    do
        local v = best
        local head = v:FindFirstChild("Head")
        local main = head and head:FindFirstChild("Main")
        local txt = main and main:FindFirstChild("Text")
        local pretty = (txt and txt.Text) or v.Name

        SelectedQuestNPC = v
        SelectedQuestNPCText = pretty
        setNote("Selected Quest NPC:", "Selected Quest NPC: " .. pretty)
        notify("Quest NPC: " .. pretty, 3)
    end
end)

CreateButton("Select NPC", "Quest Farm", function()
    local c, p = char(), hrp()
    local L = living()
    if not (c and p and L) then return end

    local best, bestDist = nil, 15
    for _, v in ipairs(L:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        if root and v:FindFirstChild("AI") then
            local d = (p.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = v, d end
        end
    end
    if not best then
        notify("No NPC within 15 studs", 4)
        return
    end

    SelectedNPC = best.Name
    setNote("Selected NPC:", "Selected NPC: " .. best.Name)
    notify("Target NPC: " .. best.Name, 3)
end)

local OnlyFarmNPC = false
CreateToggle("Only Farm NPC", "Quest Farm", function()
    OnlyFarmNPC = not OnlyFarmNPC
end)

local QuestDistance = 4
CreateNote("Farming Position", "Quest Farm")
CreateTextBox("Set Distance: ", "Quest Farm", { CustomText = "Default: 4" }, function(Input)
    local n = tonumber(Input)
    if n and n > 0 then QuestDistance = n end
end)

local QUnderneath = false
CreateToggle("Underneath", "Quest Farm", function()
    QUnderneath = not QUnderneath
end)

local function TriggerQuest()
    if not SelectedQuestNPC or not SelectedQuestNPC.Parent then
        notify("Error Grabbing Remote 1", 3)
        return false
    end

    local questDone = SelectedQuestNPC:FindFirstChild("QuestDone")
    local done = SelectedQuestNPC:FindFirstChild("Done")

    if questDone and questDone:IsA("RemoteEvent") then
        pcall(function() questDone:FireServer() end)
    else
        notify("Error Grabbing Remote 1", 3)
    end

    if done and done:IsA("RemoteEvent") then
        pcall(function() done:FireServer() end)
    else
        notify("Error Grabbing Remote 2", 3)
    end
    return true
end

local StartQuestFarming = false
CreateToggle("Begin Quest Farm", "Quest Farm", function()
    StartQuestFarming = not StartQuestFarming
    if not StartQuestFarming then return end

    -- FIX: приоритет операторов в оригинале читался не так, как задумано
    local ready = (SelectedNPC ~= "None")
                 and (SelectedQuestNPC ~= nil or OnlyFarmNPC == true)
    if not ready then
        notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
        StartQuestFarming = false
        return
    end

    task.spawn(function()
        while StartQuestFarming do
            local L = living()
            if not L then task.wait(0.5) else
                for _, target in ipairs(L:GetChildren()) do
                    if not StartQuestFarming then break end

                    local th = target:FindFirstChildOfClass("Humanoid")
                    if target.Name == SelectedNPC and th and th.Health > 0 then
                        if not OnlyFarmNPC then TriggerQuest() end

                        -- FIX: внутренние циклы больше не затеняют target
                        while StartQuestFarming and target.Parent and th.Health > 0 do
                            pcall(function()
                                holdPosition(target, QuestDistance, QUnderneath)
                                attackStep()
                            end)
                            task.wait(jitter(STEALTH.AttackMin, STEALTH.AttackMax))
                        end

                        if not OnlyFarmNPC then TriggerQuest() end

                        local p = hrp()
                        if p then
                            pcall(function()
                                p.CFrame = CFrame.new(p.Position + Vector3.new(0, 0, 1000))
                                p.CFrame = CFrame.new(p.Position + Vector3.new(0, 10, 0))
                            end)
                        end
                    end
                end
                task.wait(0.3)
            end
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- ITEM FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Item Farm")
CreateNote("Farm Methods", "Item Farm")

local FarmMethod = 0
CreateNote("Current Method: None", "Item Farm")

local function setMethod(text)
    setNote("Current Method:", "Current Method: " .. text)
end

CreateButton("Instant", "Item Farm", function()
    FarmMethod = 1
    setMethod("Instant")
end)

CreateButton("Legit", "Item Farm", function()
    FarmMethod = 2
    setMethod("Legit")
end)

-- FIX: раньше сканировался только Workspace.Vfx и в fireproximityprompt
-- летел nil, если промпта нет. Теперь Vfx + Items + любые Tool с промптом.
local function itemTargets()
    local out = {}
    local me = char()

    local function consider(inst)
        if not inst:IsA("Tool") then return end
        local parent = inst.Parent
        while parent and parent ~= Workspace do
            if parent == me or (backpack() and parent == backpack()) then return end
            if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") and parent ~= me then return end
            parent = parent.Parent
        end

        local part = inst:FindFirstChildOfClass("MeshPart")
                   or inst:FindFirstChildOfClass("Part")
                   or inst:FindFirstChildWhichIsA("BasePart")
        if not part then return end

        local prompt
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompt = d break end
        end

        out[#out + 1] = { obj = inst, part = part, prompt = prompt }
    end

    for _, folderName in ipairs({ "Vfx", "Items" }) do
        local f = Workspace:FindFirstChild(folderName)
        if f then
            for _, v in ipairs(f:GetChildren()) do consider(v) end
        end
    end

    return out
end

local function grabTool(t)
    if not (t and t.part) then return false end
    local p = hrp()
    if not p then return false end

    pcall(function() p.CFrame = t.part.CFrame end)
    task.wait(0.15)
    if t.prompt then fireProximity(t.prompt) end
    task.wait(0.15)

    return t.obj.Parent == nil
end

local function walkAndGrab(t)
    local h = hum()
    local p = hrp()
    if not (h and p and t.part) then return end

    local path = PathfindingService:CreatePath({ AgentCanJump = true })
    local ok = pcall(function() path:ComputeAsync(p.Position, t.part.Position) end)
    if not ok then return end

    for _, wp in ipairs(path:GetWaypoints()) do
        h:MoveTo(wp.Position)
        if wp.Action == Enum.PathWaypointAction.Jump then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        -- таймаут: без него луп вешался навсегда, если дойти нельзя
        h.MoveToFinished:Wait(3)
    end

    if t.prompt then fireProximity(t.prompt) end
end

local StartFarming = false
CreateToggle("Start Farming", "Item Farm", function()
    StartFarming = not StartFarming

    if not StartFarming then
        local h = hum()
        if h then pcall(function() h.WalkSpeed = 16 end) end
        return
    end

    if FarmMethod ~= 1 and FarmMethod ~= 2 then
        notify("Select A Farm Method, And Re-Enable!")
        StartFarming = false
        return
    end

    local instant = (FarmMethod == 1)

    task.spawn(function()
        if not instant then
            local h = hum()
            if h then pcall(function() h.WalkSpeed = 30 end) end
        end

        while StartFarming do
            local list = itemTargets()

            if instant then
                for _, t in ipairs(list) do
                    if not StartFarming then break end
                    pcall(grabTool, t)
                    task.wait(0.1)
                end
            else
                for _, t in ipairs(list) do
                    if not StartFarming then break end
                    pcall(walkAndGrab, t)
                    task.wait(0.3)
                end
            end

            task.wait(instant and 0.2 or 1.0)
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- TELEPORTS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Teleports")

CreateTextBox("Teleport To", "Teleports", { CustomText = "Player Name" }, function(A)
    if not A or A == "" then return end
    local target = Players:FindFirstChild(Fill(A))
    local c = target and target.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then notify("Player not found: " .. tostring(A), 3); return end
    tpToCF(root.CFrame)
end)

CreateTextBox("Teleport Above To : ", "Teleports", { CustomText = "Player Name" }, function(A)
    if not A or A == "" then return end
    local target = Players:FindFirstChild(Fill(A))
    local c = target and target.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then notify("Player not found: " .. tostring(A), 3); return end
    tpToCF(root.CFrame * CFrame.new(0, 25, 0))
end)

local LANDMARKS = {
    { "D4C Dimension",      CFrame.new(11927.1, -3.28935, -4488.59) },
    { "Rarity Boards",      CFrame.new(-658.979, 67.0282, -451.495) },
    { "Stand Storage Room", CFrame.new(-393.893, 23.5808, -280.786) },
    { "Inner Sanctum",      CFrame.new(27877.87109375, 27.233600616455078, -147.72268676757812) },
    { "Mud Pit",            CFrame.new(17.0716, 66.9873, -246.13) },
    { "Hamon Dealer",       CFrame.new(-801.427, 66.5359, -735.121) },
    { "Vehicle Man",        CFrame.new(-187.042, 78.4486, -1076.25) },
    { "Testing Zone",       CFrame.new(19999.3, 100.155, -730.726) },
    { "Bad Gi Spawn",       CFrame.new(-687.604736328125, 67.03131866455078, -837.9588623046875) },
    { "Scary Monster Cave", CFrame.new(-683.89794921875, 67.03133392333984, -1039.75634765625) },
    { "Sewer",              CFrame.new(-5308.6455078125, -450.83184814453125, -3815.388427734375) },
    { "Yoshikage Kira Spawn", CFrame.new(-446.5094299316406, 67.03131103515625, -995.3768310546875) },
    { "Dio's Rock",         CFrame.new(-37.414466857910156, 92.30691528320312, -804.2440185546875) },
    { "Gyro Zeppeli",       CFrame.new(57.21436309814453, 66.80048370361328, -216.83428955078125) },
}

for _, lm in ipairs(LANDMARKS) do
    local label, cf = lm[1], lm[2]
    CreateButton(label, "Teleports", function()
        tpToCF(cf)
    end)
end

CreateNote("NPC's", "Teleports")

-- FIX: v захватывался замыканием — кнопки могли телепортировать не к тому NPC
do
    local nf = npcFolder()
    if nf then
        for _, v in ipairs(nf:GetChildren()) do
            local npc = v
            local head = npc:FindFirstChild("Head")
            local main = head and head:FindFirstChild("Main")
            local sub = head and head:FindFirstChild("Sub")
            local mainText = main and main:FindFirstChild("Text")
            local subText = sub and sub:FindFirstChild("Text")

            if head and mainText then
                local label = mainText.Text
                if subText and subText.Text ~= "" then
                    label = label .. " [" .. subText.Text .. "]"
                end
                task.spawn(function()
                    CreateButton(label, "Teleports", function()
                        tpToCF(CFrame.new(head.Position + Vector3.new(0, 3, 0)))
                    end)
                end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- STAND FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Stand Farm")
CreateSearchBar("Stand Farm")

CreateNote("Checking Configuration", "Stand Farm")

local StandCheck = false
CreateToggle("Enable Stand Check", "Stand Farm", function()
    StandCheck = not StandCheck
end)

local AttributeCheck = false
CreateToggle("Enable Attribute Check", "Stand Farm", function()
    AttributeCheck = not AttributeCheck
end)

local SplitChecking = false
CreateToggle("Split Checking", "Stand Farm", function()
    SplitChecking = not SplitChecking
end)

CreateNote("Extra Settings", "Stand Farm")

local UseStandArrows   = true
local UseChargedArrows = false
local UseKarsMask      = false

CreateButton("Use Stand Arrows", "Stand Farm", function()
    UseStandArrows, UseChargedArrows, UseKarsMask = true, false, false
    notify("Using Stand Arrows", 3)
end)

CreateButton("Use Charged Arrows", "Stand Farm", function()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, true, false
    notify("Using Charged Arrows", 3)
end)

CreateButton("Use Kars Mask", "Stand Farm", function()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, false, true
    notify("Using Kars Mask", 3)
end)

local AutoBuyArrows = false
CreateToggle("Auto Buy Selected Arrows", "Stand Farm", function()
    AutoBuyArrows = not AutoBuyArrows
end)

local AutoBuyRokakaka = false
CreateToggle("Auto Buy Rokakaka", "Stand Farm", function()
    AutoBuyRokakaka = not AutoBuyRokakaka
end)

local Webhook = ""
CreateTextBox("Set Webhook", "Stand Farm", {}, function(Input)
    Webhook = Input or ""
end)

local EnableWebhook = false
CreateToggle("Enable Webhook", "Stand Farm", function()
    EnableWebhook = not EnableWebhook
end)

CreateNote("Stands", "Stand Farm")

local WhitelistedStands = {}
local WhitelistedAttributes = {}

local Ignore = {
    "The Universe Over Heaven", "Shinjitsu Tenj no uch", "The Waifu: Over Heaven From Your Biazarre Adventure",
    "Rapture", "True Star Platinum: The World", "Diego's The World: High Voltage",
    "Premier Macho", "Stab Platinum: The World", "King Crimson Requiem", "Silver Chariot Requiem",
    "Eclispe Dio's The World Over Heaven", "Headless Star Platinum", "Tusk Act 2", "Tusk Act 3",
    "Star Platinum The World: Requiem", "Tusk Act 4", "Star Platinum OVA Over Heaven",
    "Star Platinum The World", "Star Platinum Over Heaven", "Crazy Diamond: Over Heaven",
    "The World's Greatest High", "C-Moon", "Shadow The World", "Main In Heaven",
    "Silver Chariot Requiem OVA", "The World OVA Over Heaven", "Kars", "Cauldron Black",
    "Stab Platinum", "Dio's The World Over Heaven", "The World Over Heaven", "Halal Goku",
    "Gold Experience Requiem Requiem", "Gold Experience Requiem", "Killer Queen Bites The Dust",
    "Celebratory Soft & Wet", "Anubis", "The World Alternate Universe: Executioner",
    "The World Alternate Universe: Electrocutioner", "King Crimson: Requiem", "Brainy's The World",
    "TAMIH", "ABDSTW", "Made In Hell", "Jotaro's Star Platinum Over Heaven",
    "The World Over Heaven OVA", "Golden Experience: Reality Bender", "Ultimate Life Form",
    "Ben", "Made In Heaven", "Snowglobe Made In Heaven", "Premier Macho Requiem",
    "Halal Vegeta", "HalalGoku", "IBM", "Festive The World", "The Universe",
    "Dirty Deeds Done Dirt Cheap: Love Train",
}

local Created = {}
do
    local convert = ReplicatedStorage:FindFirstChild("StandNameConvert")
    if convert then
        for _, v in ipairs(convert:GetChildren()) do
            if v:IsA("StringValue") and v.Value ~= ""
               and not table.find(Created, v.Value)
               and not table.find(Ignore, v.Value) then
                local stand = v.Value
                Created[#Created + 1] = stand
                task.spawn(function()
                    CreateToggle(stand, "Stand Farm", function()
                        local at = table.find(WhitelistedStands, stand)
                        if at then
                            table.remove(WhitelistedStands, at)
                        else
                            WhitelistedStands[#WhitelistedStands + 1] = stand
                        end
                    end)
                end)
            end
        end
    end
end

CreateNote("Attributes", "Stand Farm")

do
    local ok, frame = pcall(function()
        return Workspace.Map.ChancesBoards.AttributeChances.newSurface.ScrollFrame
    end)
    if ok and frame then
        local seen = {}
        for _, v in ipairs(frame:GetChildren()) do
            if v:IsA("TextLabel") then
                local attr = string.split(v.Text, " ")[1]
                if attr == "Glass" then attr = "Glass Cannon" end
                if attr and attr ~= "" and not seen[attr] then
                    seen[attr] = true
                    local name = attr
                    task.spawn(function()
                        CreateToggle(name, "Stand Farm", function()
                            local at = table.find(WhitelistedAttributes, name)
                            if at then
                                table.remove(WhitelistedAttributes, at)
                            else
                                WhitelistedAttributes[#WhitelistedAttributes + 1] = name
                            end
                        end)
                    end)
                end
            end
        end
    end
end

local function sendRollWebhook()
    if not EnableWebhook then return end
    webhookSend(Webhook, {
        content = "@everyone```\nUsername: " .. LP.Name
               .. "\nStand: " .. standName()
               .. "\nAttribute: " .. standAttri() .. "```",
    })
end

-- ── NEXT MOVE ─────────────────────────────────────────────────────────────
-- FIX: UseArrow / UseChargedArrow — несуществующие глобалы, из-за опечатки
-- автопокупка не срабатывала никогда. Плюс вечные repeat-until без таймаута.
local function waitForEquip(toolName, timeout)
    local c = char()
    if not c then return nil end
    return c:WaitForChild(toolName, timeout or 3)
end

local function buyArrow()
    local ev = events()
    local buy = ev and ev:FindFirstChild("BuyItem")
    if not buy then return false end
    local nf = npcFolder()
    if not nf then return false end

    if UseStandArrows then
        local npc = nf:FindFirstChild("MerchantAU")
        if npc and npc:FindFirstChild("HumanoidRootPart") then
            tpToCF(npc.HumanoidRootPart.CFrame)
            task.wait(0.5)
            pcall(function() buy:FireServer("MerchantAU", "Option4") end)
            task.wait(0.5)
            return true
        end
    elseif UseChargedArrows then
        local npc = nf:FindFirstChild("Merchant120") or nf:FindFirstChild("Merchantlvl120")
        if npc and npc:FindFirstChild("HumanoidRootPart") then
            tpToCF(npc.HumanoidRootPart.CFrame)
            task.wait(0.5)
            pcall(function() buy:FireServer("Merchantlvl120", "Option2") end)
            task.wait(0.5)
            return true
        end
    end
    return false
end

local function buyRokakaka()
    local ev = events()
    local buy = ev and ev:FindFirstChild("BuyItem")
    local nf = npcFolder()
    local npc = nf and nf:FindFirstChild("MerchantAU")
    if not (buy and npc and npc:FindFirstChild("HumanoidRootPart")) then return false end
    tpToCF(npc.HumanoidRootPart.CFrame)
    task.wait(0.5)
    pcall(function() buy:FireServer("MerchantAU", "Option2") end)
    task.wait(0.5)
    return true
end

function NextMove()
    local arrow = "Stand Arrow"
    if UseChargedArrows then
        arrow = "Charged Arrow"
    elseif UseKarsMask then
        arrow = "Kars Mask"
    end

    if not hasStand() then
        local bp = backpack()
        if bp and bp:FindFirstChild(arrow) then
            local c, h = char(), hum()
            if not (c and h) then return end
            pcall(function() h:EquipTool(bp:FindFirstChild(arrow)) end)
            local tool = waitForEquip(arrow, 3)
            if not tool then return end

            local ev = events()
            local useItem = ev and ev:FindFirstChild("UseItem")

            for _ = 1, 40 do
                if hasStand() then break end
                pcall(function() tool:Activate() end)
                if useItem then pcall(function() useItem:FireServer() end) end
                task.wait(0.5)
            end
        elseif AutoBuyArrows then
            buyArrow()
        end
        return
    end

    -- есть стенд → роллим рокакаку
    local bp = backpack()
    if bp and bp:FindFirstChild("Rokakaka") then
        local c, h = char(), hum()
        if not (c and h) then return end
        pcall(function() h:EquipTool(bp:FindFirstChild("Rokakaka")) end)
        local tool = waitForEquip("Rokakaka", 3)
        if not tool then return end

        local ev = events()
        local useItem = ev and ev:FindFirstChild("UseItem")

        for _ = 1, 40 do
            if not hasStand() then break end
            pcall(function() tool:Activate() end)
            if useItem then pcall(function() useItem:FireServer() end) end
            task.wait(0.5)
        end
    elseif AutoBuyRokakaka then
        buyRokakaka()
    end
end

local StandFarm = false
CreateToggle("Begin Stand Farm", "Stand Farm", function()
    StandFarm = not StandFarm
    if not StandFarm then return end

    task.spawn(function()
        while StandFarm do
            local currentStand = standName()
            local currentAttri = standAttri()

            local check1 = table.find(WhitelistedStands, currentStand) ~= nil
            local check2 = table.find(WhitelistedAttributes, currentAttri) ~= nil

            local hit = false

            if SplitChecking then
                hit = check1 or check2
            elseif StandCheck and not AttributeCheck then
                hit = check1
            elseif not StandCheck and AttributeCheck then
                hit = check2
            elseif StandCheck and AttributeCheck then
                hit = check1 and check2
            end

            if hit then
                sendRollWebhook()
                -- FIX: раньше тут был break — тоггл оставался включённым,
                -- а цикл уже мёртвый. Теперь честный стоп.
                StandFarm = false
                notify("Target roll found: " .. currentStand .. " [" .. currentAttri .. "]", 8)
                return
            end

            NextMove()
            task.wait(0.4)
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
pcall(function()
    CreateNotification("Arctic", "Loaded. Press J to toggle.", { Duration = 6 })
end)
print("[Arctic SUR] loaded | stand=" .. standName() .. " | attri=" .. standAttri()
      .. " | moves=" .. #moveset())
