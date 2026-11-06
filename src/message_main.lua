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
-- Оригинальная попытка мгновенного убийства оставлена за переключателем:
--      Workspace.Living.Boss.Humanoid.Health = 0
--   Это клиентская запись свойства. Серверный урон и награда ею не доказаны.
--   Переключатель "Instant Boss Kill (HP = 0)" по умолчанию ВЫКЛЮЧЕН.
-- ══════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local PathfindingService= game:GetService("PathfindingService")
local Workspace         = game.Workspace
local UIS               = game:GetService("UserInputService")

local LP = Players.LocalPlayer

Start("Arctic")

-- Every asynchronous action belongs to this injection and one generation.
-- Turning OFF invalidates sleeping workers before another ON can start.
local Runtime = {
    alive = true, jobs = {}, connections = {}, cleanup = {},
    errors = {}, movement = nil, tasks = {}, heldInputs = {}, heldPrompts = {}, idleRelease = nil,
    equipment = nil, movementRevision = 0,
}

local function recordError(label, err)
    local text = tostring(label) .. ": " .. tostring(err)
    Runtime.errors[#Runtime.errors + 1] = text
    if #Runtime.errors > 20 then table.remove(Runtime.errors, 1) end
    UIReport(label, err)
end

local function jobActive(job)
    return Runtime.alive and (not job or (job.active and Runtime.jobs[job.name] == job))
end

local function runAsync(callback, ...)
    if not Runtime.alive then return nil end
    local args = { ... }
    local thread = task.spawn(function()
        if not Runtime.alive then return end
        local ok, err = pcall(callback, table.unpack(args))
        Runtime.tasks[coroutine.running()] = nil
        if not ok and Runtime.alive then recordError("Task", err) end
    end)
    if thread and coroutine.status(thread) ~= "dead" then Runtime.tasks[thread] = true end
    return thread
end

local function runConnect(event, callback)
    local connection = event:Connect(function(...)
        if not Runtime.alive then return end
        local thread = coroutine.running()
        Runtime.tasks[thread] = true
        local ok, err = pcall(callback, ...)
        Runtime.tasks[thread] = nil
        if not ok and Runtime.alive then recordError("Event", err) end
    end)
    for i = #Runtime.connections, 1, -1 do
        if not Runtime.connections[i].Connected then table.remove(Runtime.connections, i) end
    end
    Runtime.connections[#Runtime.connections + 1] = connection
    return connection
end

local function addCleanup(callback)
    Runtime.cleanup[#Runtime.cleanup + 1] = callback
end

local function jobStop(name)
    local job = Runtime.jobs[name]
    if not job then return end
    job.active = false
    if Runtime.equipment and Runtime.equipment.job == job then Runtime.equipment = nil end
    for held in pairs(Runtime.heldInputs) do
        if held.job == job then
            pcall(function()
                held.remote:FireServer({ State = "End", Key = held.key, Type = held.utype })
            end)
            Runtime.heldInputs[held] = nil
        end
    end
    for prompt, owner in pairs(Runtime.heldPrompts) do
        if owner == job then
            pcall(function() prompt:InputHoldEnd() end)
            Runtime.heldPrompts[prompt] = nil
        end
    end
    Runtime.jobs[name] = nil
    for connection in pairs(job.connections or {}) do pcall(function() connection:Disconnect() end) end
    job.connections = {}
    if Runtime.movement == job then Runtime.movement = nil end
    if job.onStop then
        local ok, err = pcall(job.onStop, job)
        if not ok then recordError(name .. " stop", err) end
    end
    local thread = job.thread
    if thread and thread ~= coroutine.running() and task.cancel then
        pcall(task.cancel, thread)
        Runtime.tasks[thread] = nil
    end
end

local function jobStart(name, moves, onStop, callback)
    local existing = Runtime.jobs[name]
    if existing and jobActive(existing) then return existing end
    jobStop(name)
    if not Runtime.alive then return nil end
    if moves and Runtime.movement then jobStop(Runtime.movement.name) end
    local job = { name = name, active = true, onStop = onStop, connections = {} }
    Runtime.jobs[name] = job
    if moves then
        Runtime.movementRevision = Runtime.movementRevision + 1
        Runtime.movement = job
        if Runtime.onMovementChanged then pcall(Runtime.onMovementChanged, name) end
    end
    job.thread = runAsync(function()
        local ok, err = pcall(callback, job)
        if not ok and jobActive(job) then recordError(name, err) end
        if Runtime.jobs[name] == job then jobStop(name) end
    end)
    return job
end

local function waitActive(seconds, job)
    local deadline = os.clock() + math.max(0, seconds or 0)
    repeat
        if not jobActive(job) then return false end
        task.wait(math.min(0.1, math.max(0, deadline - os.clock())))
    until os.clock() >= deadline
    return jobActive(job)
end

local function finiteNumber(value, minimum, maximum)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    if minimum and n < minimum then return nil end
    if maximum and n > maximum then return nil end
    return n
end

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
    if not Runtime.alive then return end
    pcall(function()
        CreateNotification("Arctic", tostring(text), { Duration = dur or 4 })
    end)
end

-- Подписи-статусы ("Selected Lair NPC: ...") ищем по префиксу, а не по
-- точному имени: EditString ломался, как только текст расходился на символ.
local function setNote(prefix, newText)
    local gui = ScreenGui
    if not Runtime.alive or not (gui and gui.Parent) then return false end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= ""
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

-- Сервер берёт точку удара из клиентского "MousePos" (StandEvents.Info).
-- Пока фарм держит цель, отвечаем позицией её HumanoidRootPart — иначе удар
-- уходит в курсор и по боссу не попадает вообще.
local AimTarget = nil
local AimInfo = nil
local function setAimTarget(model)
    AimTarget = model
end
local function ensureAim()
    local se = standEvents()
    local info = se and se:FindFirstChild("Info")
    if not info or not info:IsA("RemoteFunction") then return false end
    if AimInfo == info then return true end
    AimInfo = info
    pcall(function()
        info.OnClientInvoke = function(what)
            if what == "MousePos" then
                local t = AimTarget
                local root = t and t.Parent and t:FindFirstChild("HumanoidRootPart")
                if root and root:IsA("BasePart") then return root.Position end
            end
            return nil
        end
    end)
    return AimInfo == info
end

local function press(key, hold, job)
    if not jobActive(job) then return false end
    ensureAim()
    local se = standEvents()
    local input = se and se:FindFirstChild("Input")
    if not (input and input:IsA("RemoteEvent")) then return false end
    local isMouse = (key == Enum.UserInputType.MouseButton1
                  or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard
    local packetKey = isMouse and Enum.KeyCode.Unknown or key
    local held = { remote = input, key = packetKey, utype = utype, job = job }
    Runtime.heldInputs[held] = true
    local ok = pcall(function()
        input:FireServer({ State = "Begin", Key = packetKey, Type = utype })
    end)
    if ok and hold and hold > 0 then waitActive(hold, job) end
    pcall(function()
        input:FireServer({ State = "End", Key = packetKey, Type = utype })
    end)
    Runtime.heldInputs[held] = nil
    return ok and jobActive(job)
end

local function moveset()
    local se = standEvents()
    local info = se and se:FindFirstChild("Info")
    if not info then return {} end
    local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
    if not (ok and type(res) == "table") then return {} end

    -- Accept only known keys, not arbitrary move names mapped to E.
    local out, seen, tables = {}, {}, {}
    local function add(value)
        local name
        if type(value) == "string" then
            name = value:match("([%w]+)$")
        elseif typeof(value) == "EnumItem" then
            name = value.Name
        elseif type(value) == "table" then
            if tables[value] then return end
            tables[value] = true
            add(value.Key or value.key)
            return
        end
        if name == "MouseButton1" then name = "M1" end
        if name == "MouseButton2" then name = "M2" end
        if name and KEYMAP[name] and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    for k, v in pairs(res) do
        if type(k) == "number" then add(v) else add(k); add(v) end
    end
    table.sort(out)
    return out
end

local function standCode()
    local d = LP:FindFirstChild("Data")
    local s = d and d:FindFirstChild("Stand")
    return s and tostring(s.Value) or nil
end

local function standName()
    local code = standCode()
    if code then
        local convert = ReplicatedStorage:FindFirstChild("StandNameConvert")
        local entry = convert and convert:FindFirstChild(code)
        return entry and entry:IsA("StringValue") and tostring(entry.Value) or code
    end
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
    local n = standCode()
    return n ~= nil and n ~= "" and n ~= "None"
end

-- Оригинал проверял Character.Aura.Value и падал, если Aura нет.
-- Троттлинг: Q имеет кулдаун 1.5с, спамить его каждый тик бессмысленно.
local lastSummon = -math.huge
local function summonIfNeeded(job)
    local c = char()
    if not c then return end
    if c:FindFirstChild("Stand") then return end
    if not jobActive(job) or os.clock() - lastSummon < 1.7 then return end
    lastSummon = os.clock()
    press(Enum.KeyCode.Q, 0.1, job)
end

-- ══════════════════════════════════════════════════════════════════════════
-- FARM TIMING
-- Ограничения частоты операций уменьшают повторные записи и запросы.
-- По одному клиентскому дампу нельзя установить правила серверного античита.
-- Эти интервалы не гарантируют обход проверок или отсутствие кика.
-- ══════════════════════════════════════════════════════════════════════════
local STEALTH = {
    RepositionGap  = 0.85,   -- мин. пауза между записями CFrame
    RepositionDist = 1,      -- допуск позиции; не игнорирует Underneath на 4 студa
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

-- Клиентская попытка HP=0. Успех здесь означает только локальный Health.
-- Репликация на сервер, награда и причина кика отдельно не подтверждены.
local lastKillAt = -math.huge
local function killTarget(model)
    if not Runtime.alive or not (model and model.Parent) then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
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
-- Частые записи скорости не нужны для удержания позиции.
-- Закапываемся максимум на UnderDepth, иначе проваливаемся под пол карты.
local lastPositionModel, lastPositionDistance, lastPositionUnderneath
local function holdPosition(model, distance, underneath, job)
    local p, h = hrp(), hum()
    if not jobActive(job) or not (model and model.Parent and p and h and h.Health > 0) then return false end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not (t and t:IsA("BasePart")) then return false end
    distance = finiteNumber(distance, 0.5, 100) or 4
    local depth = underneath and math.min(distance, STEALTH.UnderDepth) or 0
    local want = t.CFrame * CFrame.new(0, -depth, distance)
    local modeChanged = lastPositionModel ~= model or lastPositionDistance ~= distance or lastPositionUnderneath ~= underneath
    local facing = (p.CFrame.LookVector - want.LookVector).Magnitude < 0.1
    if not modeChanged and facing and (p.Position - want.Position).Magnitude < STEALTH.RepositionDist then return true end
    if not modeChanged and os.clock() - lastReposition < STEALTH.RepositionGap then return false end
    lastReposition = os.clock()
    lastPositionModel, lastPositionDistance, lastPositionUnderneath = model, distance, underneath
    local ok = pcall(function() p.CFrame = want end)
    return ok and jobActive(job)
end

-- One bounded approach, never a guessed or stale NPC destination.
local lastApproach = -math.huge
local function approach(model, distance, job)
    local p = hrp()
    if not jobActive(job) or not (model and model.Parent and p) then return false end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not t then return false end
    if (p.Position - t.Position).Magnitude <= distance then return true end
    if os.clock() - lastApproach < 1.2 then return false end
    lastApproach = os.clock()
    return pcall(function() p.CFrame = t.CFrame * CFrame.new(0, 0, distance) end)
end

-- Небольшой разброс интервалов ограничивает повторные действия.
local function jitter(min, max)
    return min + math.random() * (max - min)
end

-- Поиск лейр-босса.
--
-- ЖЕЛЕЗНОЕ ПРАВИЛО: только Workspace.Living.Boss. Никаких эвристик.
-- В Workspace.Living лежат МИРОВЫЕ боссы (Jotaro Over Heaven, JohnnyJoestar,
-- Alternate Jotaro Part 4) — те самые, что в Boss Farm. Любая попытка
-- «угадать» босса по имени или по факту появления хватает их, и фарм
-- уезжает из лейра в обычный мир убивать всё подряд.
--
-- Оригинальный message.txt верил ровно в имя "Boss" — и был прав.
local function findLairBoss()
    local L = living()
    if not L then return nil end

    local b = L:FindFirstChild("Boss")
    if not b or Players:GetPlayerFromCharacter(b) then return nil end

    local h = b:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end

    return b
end

-- ── настройки фармов (общие, как в оригинале) ─────────────────────────────
local AllMovesets   = {}
local ClearMoves    = {}
local UseCustomMoves = false

local function attackStep(job)
    if not jobActive(job) then return false end
    summonIfNeeded(job)
    if not jobActive(job) then return false end
    if UseCustomMoves and #AllMovesets > 0 then
        local name = AllMovesets[math.random(1, #AllMovesets)]
        return press(KEYMAP[name], 0.05, job)
    end
    return press(Enum.UserInputType.MouseButton1, 0.03, job)
end

-- ── предметы / экипировка ─────────────────────────────────────────────────
local function equipmentAcquire(job)
    local current = Runtime.equipment
    if current then return nil end
    local owner = { job = job, thread = coroutine.running() }
    Runtime.equipment = owner
    return owner
end

local function equipmentRelease(owner)
    if Runtime.equipment == owner then Runtime.equipment = nil end
end
addCleanup(function() Runtime.equipment = nil end)

-- A consumable owns equipment until confirmation, cancellation or timeout.
-- This also keeps Auto Umbrella from unequipping a delayed consumable.
local function useToolName(name, job, beforeUse)
    if not job and Runtime.movement then jobStop(Runtime.movement.name) end
    local c, h, bp = char(), hum(), backpack()
    if not jobActive(job) or not (c and h and h.Health > 0) then return false end
    local tool = (bp and bp:FindFirstChild(name)) or c:FindFirstChild(name)
    if not (tool and tool:IsA("Tool")) then notify("No " .. tostring(name) .. " in inventory", 3); return false end
    local inherited = Runtime.equipment
    local owned = inherited and inherited.job == job and inherited.thread == coroutine.running()
    local owner = owned and inherited or equipmentAcquire(job)
    if not owner then notify("Another item-use operation owns equipment", 3); return false end
    local usesStandArrow = name == "Stand Arrow" or name == "Charged Arrow" or name == "Requiem Arrow" or name == "Kars Mask"
    local removesStand = name == "Rokakaka" or name == "Rotten Rokakaka"
    local hadStand = hasStand()
    local initialStand = standCode()
    local ok, used = pcall(function()
        if tool.Parent == bp then h:EquipTool(tool) end
        local equipDeadline = os.clock() + 3
        while tool.Parent ~= c and jobActive(job) and char() == c and h.Health > 0 and os.clock() < equipDeadline do
            if beforeUse and not beforeUse() then return false end
            if not waitActive(0.05, job) then return false end
        end
        if not jobActive(job) or char() ~= c or h.Health <= 0 or tool.Parent ~= c then return false end
        if beforeUse and not beforeUse() then return false end
        local use = tool:FindFirstChild("Use")
        local ev = events()
        local useItem = ev and ev:FindFirstChild("UseItem")
        if use and use:IsA("RemoteEvent") then use:FireServer(); return true end
        tool:Activate()
        if not jobActive(job) or char() ~= c or h.Health <= 0 then return false end
        if useItem and useItem:IsA("RemoteEvent") then useItem:FireServer() end
        return true
    end)
    if ok and used == true and not owned and (usesStandArrow or removesStand) then
        local deadline = os.clock() + 8
        while Runtime.alive and Runtime.equipment == owner and char() == c and h.Health > 0 and os.clock() < deadline do
            local changed = standCode() ~= initialStand or (removesStand and hadStand and not hasStand())
                or (usesStandArrow and not hadStand and hasStand()) or tool.Parent == nil
            if changed or not waitActive(0.1, job) then break end
        end
    end
    if not owned then equipmentRelease(owner) end
    if not ok then notify("Could not use " .. tostring(name) .. ": " .. tostring(used), 4); return false end
    return used == true
end

local function fireProximity(prompt, job)
    if not jobActive(job) or not (prompt and prompt.Parent and prompt:IsA("ProximityPrompt")) then return false end
    if fireproximityprompt and pcall(fireproximityprompt, prompt) then return jobActive(job) end
    local began = pcall(function() prompt:InputHoldBegin() end)
    if not began then return false end
    Runtime.heldPrompts[prompt] = job or true
    local complete = waitActive((tonumber(prompt.HoldDuration) or 0.5) + 0.05, job)
    pcall(function() prompt:InputHoldEnd() end)
    Runtime.heldPrompts[prompt] = nil
    return complete
end

local function webhookSend(url, payload)
    if not Runtime.alive or not url or url == "" then return false end
    local req = http_request or request or HttpPost or (syn and syn.request)
    if not req then return false end
    local body = HttpService:JSONEncode(payload)
    return pcall(req, {
        Url = url, Method = "POST",
        Headers = { ["content-type"] = "application/json" },
        Body = body,
    })
end

local function tpToCF(cf, job)
    local p = hrp()
    if not Runtime.alive or not (p and cf) or (job and not jobActive(job)) then return false end
    -- A manual scripted move must not masquerade as a server entry transfer.
    -- Job-owned item/merchant movement keeps its own generation instead.
    if not job then
        Runtime.movementRevision = Runtime.movementRevision + 1
        if Runtime.onMovementChanged then pcall(Runtime.onMovementChanged, nil) end
        if Runtime.movement then
            Runtime.movement.cancelReason = "manual_teleport"
            jobStop(Runtime.movement.name)
        end
    end
    local moved = pcall(function() p.CFrame = cf end)
    if not moved then return false end
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
CreateToggle("Auto Umbrella", "LocalPlayer", function(on)
    AutoUmbrella = on == true
    if not AutoUmbrella then jobStop("umbrella"); return false end

    -- FIX: цикл блокировал собственный колбэк; вынесен в task.spawn
    jobStart("umbrella", false, function()
        AutoUmbrella = false
        SetToggle("Auto Umbrella", "LocalPlayer", false)
    end, function(job)
        while jobActive(job) do
            local c, h, bp = char(), hum(), backpack()
            local tool = bp and bp:FindFirstChild("Umbrella")
            if not Runtime.equipment and c and h and h.Health > 0 and tool and not c:FindFirstChild("Umbrella") then h:EquipTool(tool) end
            if not waitActive(0.35, job) then break end
        end
    end)
    return AutoUmbrella
end)

local AntiAFK = false
CreateToggle("Anti AFK", "LocalPlayer", function(on)
    AntiAFK = on == true
    if not AntiAFK then jobStop("idle") end
    return AntiAFK
end)

runConnect(LP.Idled, function()
    if not AntiAFK then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    jobStart("idle", false, function()
        if Runtime.idleRelease then pcall(Runtime.idleRelease); Runtime.idleRelease = nil end
    end, function(job)
        Runtime.idleRelease = function() VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame) end
        VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
        waitActive(1, job)
    end)
end)
addCleanup(function()
    if Runtime.idleRelease then pcall(Runtime.idleRelease); Runtime.idleRelease = nil end
end)

-- ══════════════════════════════════════════════════════════════════════════
-- SHOPS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Shops")
CreateNote("Selling", "Shops")

local SellKetchup = false
CreateToggle("Auto Sell Ketchup", "Shops", function(on)
    SellKetchup = on == true
    if not SellKetchup then jobStop("sell"); return false end
    local ev = events()
    local sell = ev and ev:FindFirstChild("SellKetchup")
    if not (sell and sell:IsA("RemoteEvent")) then
        SellKetchup = false
        notify("SellKetchup remote missing", 3)
        return false
    end
    jobStart("sell", false, function()
        SellKetchup = false
        SetToggle("Auto Sell Ketchup", "Shops", false)
    end, function(job)
        while jobActive(job) do
            local bp, c = backpack(), char()
            if (bp and bp:FindFirstChild("Ketchup")) or (c and c:FindFirstChild("Ketchup")) then
                sell:FireServer("Lots")
            end
            if not waitActive(0.5, job) then break end
        end
    end)
    return SellKetchup
end)

CreateNote("Autobuy Only Works For Level 200+", "Shops")

local Amount = 0
CreateTextBox("Count", "Shops", { CustomText = "Amount" }, function(A)
    local n = finiteNumber(A, 1, 100000)
    if not n then notify("Amount must be a positive finite number", 3); return end
    if n >= 1 then
        Amount = math.floor(n)
        notify("Amount Set To : " .. tostring(Amount), 3)
    else
        notify("Please Set The Number Above 0+", 3)
    end
end)

local AllItems = { "Rokakaka", "New Rokakaka", "Requiem Arrow", "Stand Arrow", "Dio's Diary", "Charged Arrow" }

-- FIX: Item захватывался замыканием внутри task.spawn (мог уйти не тот
-- предмет), плюс падало на захардкоженном нике "polar_eXDAVH".
local function buyFromStockMarket(itemName)
    if Runtime.movement then jobStop(Runtime.movement.name) end
    local c, h = char(), hum()
    if not (c and h) then return false end

    local ev = events()
    local sm = ev and ev:FindFirstChild("SM_Event")
    if not (sm and sm:IsA("RemoteEvent")) then notify("SM_Event missing", 3); return false end
    if Amount < 1 then notify("Set Count above 0 first", 3); return false end

    local nf = npcFolder()
    local market = nf and nf:FindFirstChild("StockMarket")
    local head = market and (market:FindFirstChild("Head") or market:FindFirstChild("HumanoidRootPart"))

    local oldPos = hrp() and hrp().CFrame
    if head then tpToCF(head.CFrame * CFrame.new(0, 3, 0)) end
    if not waitActive(0.4) or char() ~= c then return false end

    local sent = pcall(function() sm:FireServer("Buy", itemName, Amount) end)
    if not sent or not waitActive(0.4) then return false end

    local prompt = market and market:FindFirstChild("TalkToPrompt")
    if prompt then fireProximity(prompt) end
    if not waitActive(0.4) or char() ~= c then return false end

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
            CreateToggle(name, "Farm Settings", function(on)
                local at = table.find(AllMovesets, name)
                if on then
                    if not at then AllMovesets[#AllMovesets + 1] = name end
                elseif at then
                    table.remove(AllMovesets, at)
                end
                return on == true
            end)
        end
    end

    task.wait(0.2)
    notify(#ClearMoves .. " moves listed", 4)
end)

CreateToggle("Use Custom Moves", "Farm Settings", function(on)
    UseCustomMoves = on == true
    return UseCustomMoves
end)

-- ══════════════════════════════════════════════════════════════════════════
-- BOSS FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Boss Farm")
CreateNote("Settings", "Boss Farm")

local BossDistance = 4
CreateTextBox("Distance", "Boss Farm", {}, function(Input)
    local n = finiteNumber(Input, 0.5, 100)
    if n then BossDistance = n end
end)

local BossUnderneath = false
CreateToggle("Underneath", "Boss Farm", function(on)
    BossUnderneath = on == true
    return BossUnderneath
end)

-- Три тоггла ниже — один и тот же цикл. Оригинал копировал его трижды.
local BossOn = {}

local function bossFarm(modelName, label)
    CreateToggle(label, "Boss Farm", function(on)
        local name = "boss:" .. modelName
        BossOn[modelName] = on == true
        if not BossOn[modelName] then jobStop(name); return false end
        jobStart(name, true, function()
            BossOn[modelName] = false
            SetToggle(label, "Boss Farm", false)
        end, function(job)
            while jobActive(job) do
                local L = living()
                local boss = L and L:FindFirstChild(modelName)
                local h = boss and boss:FindFirstChildOfClass("Humanoid")
                if boss and h and h.Health > 0 and not Players:GetPlayerFromCharacter(boss) then
                    while jobActive(job) and boss.Parent == L and h.Health > 0 do
                        setAimTarget(boss)
                        if holdPosition(boss, BossDistance, BossUnderneath, job) then attackStep(job) end
                        if not waitActive(jitter(STEALTH.AttackMin, STEALTH.AttackMax), job) then break end
                    end
                end
                if not waitActive(0.5, job) then break end
            end
        end)
        return BossOn[modelName] == true
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
CreateNote("Lair status: idle", "Lair Farm")

CreateButton("Tutorial", "Lair Farm", function()
    notify("Step 1 (Quest Selection), Stand Near Lair NPC And Press 'Select Lair NPC'", 6)
end)

local SelectedLairNPC
local SelectedLairNPCText = "None"
local stopLairSelection

CreateButton("Select Lair NPC", "Lair Farm", function()
    local c, p = char(), hrp()
    local nf = npcFolder()
    if not (c and p and nf) then return end

    -- БЛИЖАЙШИЙ, а не последний в списке (в оригинале перебор оставлял
    -- случайного NPC, если рядом стояло двое).
    local best, bestDist = nil, 15
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local done = v:FindFirstChild("Done")
        if root and done and done:IsA("RemoteEvent") then
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

        if stopLairSelection then stopLairSelection() end
        SelectedLairNPC = v
        SelectedLairNPCText = pretty
        setNote("Selected Lair NPC:", "Selected Lair NPC: " .. pretty)
        notify("Lair NPC: " .. pretty, 3)
    end
end)

local LairDistance = 4
CreateNote("Farming Position", "Lair Farm")
CreateTextBox("Set Distance: ", "Lair Farm", { CustomText = "Default: 4" }, function(Input)
    local n = finiteNumber(Input, 0.5, 100)
    if n then LairDistance = n end
end)

local Underneath = false
CreateToggle("Underneath", "Lair Farm", function(on)
    Underneath = on == true
    return Underneath
end)

-- ЯДРО ЭКСПЛОЙТА: HP босса выставляется в 0 с клиента.
-- По умолчанию ВЫКЛЮЧЕН. В предыдущем прогоне наблюдался kick 267,
-- но связь конкретной записи с серверной проверкой не установлена.
local InstantBossKill = false
CreateNote("HP write is local; server kill unverified. Off by default.", "Lair Farm")
CreateToggle("Instant Boss Kill (HP = 0)", "Lair Farm", function(on)
    InstantBossKill = on == true
    notify("instant kill " .. (InstantBossKill and "ON" or "off"), 3)
    return InstantBossKill
end)

local LairArenaRadius = 500
-- Done is sent only to the explicitly selected NPC, while still in range.
-- A client snapshot does not prove that any other NPC is a lair provider.
local function selectedLairReady()
    local nf = npcFolder()
    local npc = SelectedLairNPC
    local root = npc and npc:FindFirstChild("HumanoidRootPart")
    local done = npc and npc:FindFirstChild("Done")
    return npc and npc.Parent == nf and root and done and done:IsA("RemoteEvent")
end

local function TriggerLair(force, job)
    if not jobActive(job) or not selectedLairReady() then return false end
    local p, h = hrp(), hum()
    local root = SelectedLairNPC:FindFirstChild("HumanoidRootPart")
    if not (p and h and h.Health > 0 and root) then return false end
    if (p.Position - root.Position).Magnitude > 25 then
        if job and (p.Position - root.Position).Magnitude <= LairArenaRadius then
            approach(SelectedLairNPC, 6, job)
        end
        return false
    end
    if not force and os.clock() < nextTriggerAt then return false end
    -- Квест берётся ДО телепорта: NPC с QuestDone сначала выдаёт задание,
    -- только потом Done уводит в лейр. Без этого босс бьётся вне квеста.
    local questDone = SelectedLairNPC:FindFirstChild("QuestDone")
    if questDone and questDone:IsA("RemoteEvent") then
        pcall(function() questDone:FireServer() end)
        if job then waitActive(0.35, job) end
    end
    local sent = pcall(function() SelectedLairNPC.Done:FireServer() end)
    if sent then
        lastTriggerAt = os.clock()
        nextTriggerAt = os.clock() + jitter(STEALTH.TriggerMin, STEALTH.TriggerMax)
    end
    return sent
end

local ShortPause = false
CreateToggle("Use Pausing", "Lair Farm", function(on)
    ShortPause = on == true
    return ShortPause
end)

local PauseTimer = 1
CreateTextBox("Pause Length", "Lair Farm", {}, function(Input)
    local n = finiteNumber(Input, 0, 300)
    if n then PauseTimer = n end
end)

local StartLairFarming = false
local LairState = {
    phase = "idle", stopReason = nil, detail = nil, anchor = nil, origin = nil,
    entrySent = false, entryAt = nil, arrival = nil, target = nil, targetRoot = nil, targetHum = nil,
    context = nil, probe = nil, trace = {},
}

local function lairStatus(phase, reason, detail)
    local changed = LairState.phase ~= phase or LairState.stopReason ~= reason or LairState.detail ~= detail
    LairState.phase, LairState.stopReason, LairState.detail = phase, reason, detail
    setNote("Lair status:", "Lair status: " .. phase .. (detail and (" — " .. detail) or ""))
    if changed then
        local entry = { time = os.clock(), phase = phase, reason = reason, detail = detail }
        LairState.trace[#LairState.trace + 1] = entry
        if #LairState.trace > 24 then table.remove(LairState.trace, 1) end
        print("[Arctic SUR][Lair] " .. phase .. (reason and (" / " .. reason) or "") .. (detail and (" / " .. detail) or ""))
    end
end

-- Only one exact live Living.Boss in the anchored arena; no world-name fallback.
-- Entry may correlate one observed arrival with the captured successful Done.
-- That client correlation is not proof of server arena ownership.
local function arenaBoss(anchor)
    local L = living()
    if not L then return nil end
    local found, foundRoot, foundHum
    for _, b in ipairs(L:GetChildren()) do
        if b:IsA("Model") and b.Name == "Boss" and not Players:GetPlayerFromCharacter(b) then
            local h, root = b:FindFirstChildOfClass("Humanoid"), b:FindFirstChild("HumanoidRootPart")
            if h and root and root:IsA("BasePart") and h.Health > 0 and (root.Position - anchor).Magnitude <= LairArenaRadius then
                if found then return nil, "boss_ambiguous" end
                found, foundRoot, foundHum = b, root, h
            end
        end
    end
    return found, nil, foundRoot, foundHum
end

local function lairExact(context)
    local b, root, h = context.target, context.targetRoot, context.targetHum
    return b and b.Parent == living() and b.Name == "Boss" and b:IsA("Model")
        and not Players:GetPlayerFromCharacter(b) and root and root.Parent == b and root:IsA("BasePart")
        and h and h.Parent == b and b:FindFirstChild("HumanoidRootPart") == root and b:FindFirstChildOfClass("Humanoid") == h
end

local function clearLairContext()
    local context = LairState.context
    if context and context.healthConnection then
        context.healthConnection:Disconnect()
        context.healthConnection = nil
    end
    if context and context.expiryThread and context.expiryThread ~= coroutine.running() and task.cancel then
        pcall(task.cancel, context.expiryThread)
        Runtime.tasks[context.expiryThread] = nil
    end
    LairState.context, LairState.probe = nil, nil
    LairState.target, LairState.targetRoot, LairState.targetHum = nil, nil, nil
    setAimTarget(nil)
end
addCleanup(clearLairContext)

local function lairResumeReady(p, h, character)
    local context = LairState.context
    if not context or not context.resumeUntil or os.clock() >= context.resumeUntil or os.clock() >= context.deadline
        or context.movementRevision ~= Runtime.movementRevision
        or (context.provider and context.provider ~= SelectedLairNPC)
        or context.character ~= character or context.playerRoot ~= p or context.playerHum ~= h
        or not context.anchor or not context.arrival or (not context.entrySent and not context.inplace)
        or (p.Position - context.anchor).Magnitude > LairArenaRadius + LairDistance or not lairExact(context)
        or (context.targetRoot.Position - context.anchor).Magnitude > LairArenaRadius then return false end
    local probe = context.probe
    return context.targetHum.Health > 0 or (probe and probe.model == context.target and probe.humanoid == context.targetHum
        and probe.root == context.targetRoot and probe.ownedZero and context.targetHum.Health == 0)
end

local function stopLairFarm(reason, detail)
    reason = reason or "user_off"
    StartLairFarming = false
    if reason == "user_off" and LairState.context and LairState.context.arrival and lairExact(LairState.context) then
        if not LairState.context.resumeUntil then
            LairState.context.resumeUntil = math.min(os.clock() + 120, LairState.context.deadline)
            if LairState.context.expiryThread and task.cancel then
                pcall(task.cancel, LairState.context.expiryThread)
                Runtime.tasks[LairState.context.expiryThread] = nil
            end
            local paused = LairState.context
            -- Runtime-owned passive expiry: releases only the matching paused
            -- observation; it never starts a job, moves, or sends a request.
            paused.expiryThread = runAsync(function()
                waitActive(math.max(0, paused.resumeUntil - os.clock()), nil)
                if Runtime.alive and LairState.context == paused and not Runtime.jobs.lair then clearLairContext() end
            end)
        end
    else
        clearLairContext()
    end
    if reason or LairState.phase ~= "stopped" then lairStatus("stopped", reason, detail or "Stopped") end
    local job = Runtime.jobs.lair
    if job then job.cancelReason = reason end
    jobStop("lair")
    SetToggle("Begin Lair Farm", "Lair Farm", false)
end
stopLairSelection = function() stopLairFarm("provider_changed", "Lair NPC reselected") end
-- Any newer movement owner or manual move discards a paused captured arena.
Runtime.onMovementChanged = function(name)
    if name ~= "lair" and LairState.context and not Runtime.jobs.lair then clearLairContext() end
end

local function startLairFarm()
    if StartLairFarming and Runtime.jobs.lair then return true end
    local p, h, character = hrp(), hum(), char()
    if not Runtime.alive or not (p and h and h.Health > 0) then
        clearLairContext()
        lairStatus("stopped", "not_ready", "Use a live character")
        return false
    end
    -- A valid captured arena resumes BEFORE asking for the distant/unstreamed
    -- entry provider. An unrelated nearby Boss is never resume evidence.
    local resume = lairResumeReady(p, h, character)
    local context = resume and LairState.context or nil
    if not resume then
        clearLairContext()
        local localBoss, localReason, localRoot = arenaBoss(p.Position)
        local providerReady = selectedLairReady()
        local providerRoot = providerReady and SelectedLairNPC:FindFirstChild("HumanoidRootPart") or nil
        local providerFar = providerReady and (p.Position - providerRoot.Position).Magnitude > LairArenaRadius
        local useInplace = false
        if providerReady and not providerFar then
            -- Normal fresh entry: request first, then wait for a transfer.
        elseif providerReady then
            -- A fresh injection inside a live lair cannot reach the distant
            -- provider. Farming the one exact local Boss is the original
            -- behavior; it sends no request and claims no quest acceptance.
            if localReason then
                lairStatus("stopped", localReason, "Several exact Boss models here; select the nearby NPC")
                return false
            end
            if not localBoss then
                lairStatus("stopped", "provider_far", "No valid captured arena; selected NPC is far away")
                notify("No captured arena to resume; selected entry NPC is far away.", 6)
                return false
            end
            useInplace = true
        else
            -- Without any live selection, only one close exact Boss may start.
            if localReason then
                lairStatus("stopped", localReason, "Several exact Boss models here; select the nearby NPC")
                return false
            end
            if not (localBoss and (localRoot.Position - p.Position).Magnitude <= 100) then
                lairStatus("stopped", "not_ready", "Select a nearby Lair NPC")
                notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
                return false
            end
            useInplace = true
        end
        local now = os.clock()
        if useInplace then
            context = {
                provider = providerReady and SelectedLairNPC or nil,
                providerRoot = providerRoot,
                providerDone = providerReady and SelectedLairNPC:FindFirstChild("Done") or nil,
                character = character, playerRoot = p, playerHum = h, deadline = now + STEALTH.SessionMaxMin * 60,
                origin = p.Position, entrySent = false, entryAt = nil, entryDeadline = now + 40, arrival = p.Position,
                anchor = p.Position, target = nil, targetRoot = nil, targetHum = nil, probe = nil, healthConnection = nil,
                probes = setmetatable({}, { __mode = "k" }),
                movementRevision = Runtime.movementRevision, resumeUntil = nil, inplace = true,
            }
            LairState.context = context
            LairState.origin, LairState.anchor, LairState.arrival = context.origin, context.anchor, context.arrival
            LairState.entrySent, LairState.entryAt = false, nil
            LairState.trace = {}
            sessionStart, nextTriggerAt = now, 0
            lairStatus("fight", "inplace", "Exact local Boss; no entry request sent")
        else
            context = {
                provider = SelectedLairNPC, providerRoot = providerRoot, providerDone = SelectedLairNPC:FindFirstChild("Done"),
                character = character, playerRoot = p, playerHum = h, deadline = now + STEALTH.SessionMaxMin * 60,
                origin = p.Position, entrySent = false, entryAt = nil, entryDeadline = now + 40, arrival = nil,
                anchor = nil, target = nil, targetRoot = nil, targetHum = nil, probe = nil, healthConnection = nil,
                probes = setmetatable({}, { __mode = "k" }),
                movementRevision = Runtime.movementRevision, resumeUntil = nil,
            }
            LairState.context = context
            LairState.origin, LairState.anchor, LairState.arrival = context.origin, nil, nil
            LairState.entrySent, LairState.entryAt = false, nil
            LairState.trace = {}
            sessionStart, nextTriggerAt = now, 0
            lairStatus("entry", nil, "Sending one selected entry request; waiting for arrival")
        end
    else
        context.resumeUntil = nil
        if context.expiryThread and context.expiryThread ~= coroutine.running() and task.cancel then
            pcall(task.cancel, context.expiryThread)
            Runtime.tasks[context.expiryThread] = nil
        end
        context.expiryThread = nil
        lairStatus("fight", nil, "Resumed the same exact Boss and captured arena")
    end
    StartLairFarming = true
    jobStart("lair", true, function(job)
        StartLairFarming = false
        if job.cancelReason ~= "user_off" or not context.resumeUntil or not Runtime.alive then clearLairContext() end
        if LairState.phase ~= "stopped" then
            lairStatus("stopped", job.cancelReason or "cancelled", "Lair worker cancelled")
        end
        SetToggle("Begin Lair Farm", "Lair Farm", false)
    end, function(job)
        context.movementRevision = Runtime.movementRevision
        local function exit(reason, text)
            job.cancelReason = reason
            lairStatus("stopped", reason, text)
            notify("Lair Farm: " .. text, 6)
            return false
        end
        local function targetGone()
            -- Our own HP=0 never authorizes a new request or a different arena.
            return context.target and context.target.Parent ~= living()
        end
        local function returning()
            return context.anchor and context.arrival and context.entrySent and targetGone()
                and selectedLairReady() and SelectedLairNPC == context.provider
                and context.provider:FindFirstChild("HumanoidRootPart") == context.providerRoot
                and context.provider:FindFirstChild("Done") == context.providerDone
                and (p.Position - context.origin).Magnitude <= 25 and (p.Position - context.providerRoot.Position).Magnitude <= 25
        end
        local function live()
            if not jobActive(job) or LairState.context ~= context then return false end
            if os.clock() >= context.deadline then return exit("session_limit", "session limit reached") end
            if context.provider and SelectedLairNPC ~= context.provider then return exit("provider_changed", "selected NPC changed") end
            if char() ~= character or hrp() ~= p or hum() ~= h then return exit("character_changed", "character changed") end
            if not p.Parent or not h.Parent or h.Health <= 0 then return exit("character_unavailable", "no live character") end
            if context.movementRevision ~= Runtime.movementRevision then return exit("movement_changed", "movement ownership changed") end
            if context.anchor and (p.Position - context.anchor).Magnitude > LairArenaRadius + LairDistance and not returning() then
                return exit("arena_left", "left the captured arena; stopped")
            end
            return true
        end
        local function watchTarget(candidate, root, humanoid)
            if context.healthConnection then context.healthConnection:Disconnect() end
            context.target, context.targetRoot, context.targetHum = candidate, root, humanoid
            local probe = context.probes[humanoid]
            if not probe or probe.model ~= candidate or probe.root ~= root then
                probe = { model = candidate, root = root, humanoid = humanoid, attempted = false, ownedZero = false, writing = false }
                context.probes[humanoid] = probe
            end
            if humanoid.Health > 0 then probe.ownedZero = false end
            context.probe = probe
            -- The observer also runs while manually OFF: a rebound followed by
            -- external zero cannot inherit ownership from an earlier probe.
            context.healthConnection = runConnect(humanoid.HealthChanged, function(health)
                if LairState.context ~= context or context.probe ~= probe then return end
                if health > 0 then probe.ownedZero = false end
            end)
            LairState.target, LairState.targetRoot, LairState.targetHum = candidate, root, humanoid
            LairState.probe = probe
            setAimTarget(candidate)
        end
        local function capture(candidate, root, humanoid)
            watchTarget(candidate, root, humanoid)
            context.anchor = context.arrival
            LairState.anchor = context.anchor
            lairStatus("fight", nil, "Exact Boss acquired at the observed arrival")
        end
        local function enter()
            while os.clock() < context.entryDeadline and live() do
                if not context.entrySent and (p.Position - context.origin).Magnitude > LairArenaRadius then
                    return exit("entry_unrequested", "left origin before successful entry request")
                end
                if not context.entrySent then
                    if not selectedLairReady() or context.provider:FindFirstChild("HumanoidRootPart") ~= context.providerRoot
                        or context.provider:FindFirstChild("Done") ~= context.providerDone then
                        return exit("provider_unavailable", "selected entry NPC unavailable")
                    end
                    if (p.Position - context.providerRoot.Position).Magnitude > 25 then
                        if approach(context.provider, 6, job) then
                            context.origin, LairState.origin = p.Position, p.Position
                        end
                    else
                        context.origin, LairState.origin = p.Position, p.Position
                        local ok = TriggerLair(true, job)
                        if not ok then return exit("entry_request_failed", "entry request could not be sent") end
                        context.entrySent, context.entryAt = true, os.clock()
                        LairState.entrySent, LairState.entryAt = true, context.entryAt
                        if not live() then return false end
                        lairStatus("entry", nil, "Entry request sent once; waiting for observed transfer")
                    end
                end
                if context.entrySent then
                    if context.arrival then
                        if (p.Position - context.arrival).Magnitude > LairArenaRadius then
                            return exit("entry_changed", "another displacement before Boss acquisition")
                        end
                    elseif (p.Position - context.origin).Magnitude > LairArenaRadius then
                        context.arrival, LairState.arrival = p.Position, p.Position
                        lairStatus("arrival", nil, "Observed arrival; waiting for exact nearby Boss")
                    end
                    -- An unchanged origin Boss is not a response to our request.
                    -- No arbitrary grace may commit it before a delayed transfer.
                    if context.arrival then
                        local candidate, reason, root, humanoid = arenaBoss(context.arrival)
                        if reason then return exit(reason, "several exact Boss models at the observed arrival") end
                        if candidate then capture(candidate, root, humanoid); return true end
                    end
                elseif (p.Position - context.origin).Magnitude > LairArenaRadius then
                    return exit("entry_unrequested", "left origin before successful entry request")
                end
                if not waitActive(0.1, job) then return false end
            end
            if not live() then return false end
            if not context.arrival then return exit("entry_unconfirmed", "entry request sent, but no observed transfer within 40 seconds") end
            return exit("entry_timeout", "no exact Boss at the observed arrival within 40 seconds")
        end
        local function repeatEntry()
            if not returning() then return false end
            if context.healthConnection then context.healthConnection:Disconnect(); context.healthConnection = nil end
            context.target, context.targetRoot, context.targetHum, context.probe = nil, nil, nil, nil
            context.anchor, context.arrival = nil, nil
            context.origin, context.entrySent, context.entryAt, context.entryDeadline = p.Position, false, nil, os.clock() + 40
            LairState.target, LairState.targetRoot, LairState.targetHum, LairState.probe = nil, nil, nil, nil
            LairState.anchor, LairState.arrival, LairState.origin = nil, nil, context.origin
            LairState.entrySent, LairState.entryAt = false, nil
            lairStatus("entry", "observed_return", "Old exact target removed and known entry origin reached")
            return enter()
        end
        if context.inplace then
            local localBoss, localReason, localRoot, localHum
            if context.target and lairExact(context) then
                local probe = context.probe
                if context.targetHum.Health > 0 or (probe and probe.ownedZero) then
                    localBoss, localRoot, localHum = context.target, context.targetRoot, context.targetHum
                end
            end
            if not localBoss then localBoss, localReason, localRoot, localHum = arenaBoss(context.anchor) end
            if localReason then exit(localReason, "several exact Boss models in the local arena"); return end
            if not localBoss then exit("boss_timeout", "the exact local Boss disappeared before capture"); return end
            capture(localBoss, localRoot, localHum)
        elseif not resume and not enter() then
            return
        end
        while live() do
            if returning() then
                if not repeatEntry() then return end
            end
            if ShortPause and not waitActive(PauseTimer, job) then return end
            while live() do
                if returning() then break end
                local boss, targetHum, targetRoot = context.target, context.targetHum, context.targetRoot
                if not boss or boss.Parent ~= living() then break end
                if not lairExact(context) then exit("boss_changed", "exact Boss root/Humanoid/owner changed"); return end
                if (targetRoot.Position - context.anchor).Magnitude > LairArenaRadius then
                    exit("boss_left", "Boss left the captured arena"); return
                end
                local probe = context.probe
                if targetHum.Health > 0 then probe.ownedZero = false end
                if targetHum.Health <= 0 and not probe.ownedZero then break end
                if holdPosition(boss, LairDistance, Underneath, job) then
                    if InstantBossKill and not probe.attempted and targetHum.Health > 0 then
                        probe.attempted, probe.at, probe.beforeHP, probe.writing = true, os.clock(), targetHum.Health, true
                        -- One direct local probe, not TakeDamage/Dead or a kill result.
                        local wrote = pcall(function() targetHum.Health = 0 end)
                        probe.writing = false
                        if not live() then return end
                        if not lairExact(context) then exit("boss_changed", "Boss changed during local HP probe"); return end
                        probe.ownedZero = wrote and probe.beforeHP > 0 and targetHum.Health == 0
                        probe.untilAt = probe.at + 1
                        lairStatus("probe", nil, "One local HP=0 attempt; observing the same exact target")
                    end
                    if probe.attempted and probe.ownedZero and os.clock() < probe.untilAt then
                        -- Poll with full identity/cancellation checks; do not declare
                        -- completion or repeat the provider from our own local zero.
                    else
                        if probe.attempted and not probe.fallbackLogged then
                            probe.fallbackLogged = true
                            lairStatus("fight", nil, probe.ownedZero and "Local HP=0 only; ordinary combat continues, server unconfirmed"
                                or "Local attempt unconfirmed; ordinary combat continues")
                        end
                        attackStep(job)
                    end
                end
                if not waitActive(jitter(STEALTH.AttackMin, STEALTH.AttackMax), job) then return end
            end
            if not live() then return end
            if returning() then
                if not repeatEntry() then return end
            else
                local acquisitionDeadline = os.clock() + 40
                lairStatus("acquire", nil, "Target removed or external HP=0; waiting only in captured arena")
                local nextBoss, reason, root, humanoid
                while os.clock() < acquisitionDeadline and live() do
                    if returning() then break end
                    nextBoss, reason, root, humanoid = arenaBoss(context.anchor)
                    if reason then exit(reason, "several exact Boss models in the captured arena"); return end
                    if nextBoss then break end
                    -- A missing target is not permission to teleport to the entry
                    -- provider; reentry requires an independently observed return.
                    if not waitActive(0.1, job) then return end
                end
                if not live() then return end
                if returning() then
                    if not repeatEntry() then return end
                elseif nextBoss then
                    if nextBoss == context.target then
                        -- A positive external rebound keeps the same probe ledger.
                        lairStatus("fight", nil, "Same exact target has positive health again")
                    else
                        capture(nextBoss, root, humanoid)
                    end
                else
                    exit("boss_timeout", "no new exact Boss or known entry return within 40 seconds"); return
                end
            end
        end
    end)
    return StartLairFarming
end

CreateToggle("Begin Lair Farm", "Lair Farm", function(on)
    if not on then stopLairFarm(); return false end
    return startLairFarm()
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
        local done, questDone = v:FindFirstChild("Done"), v:FindFirstChild("QuestDone")
        if root and done and done:IsA("RemoteEvent") and questDone and questDone:IsA("RemoteEvent") then
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
        local targetHum = v:FindFirstChildOfClass("Humanoid")
        if root and targetHum and targetHum.Health > 0 and v:FindFirstChild("AI") and not Players:GetPlayerFromCharacter(v) then
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
CreateToggle("Only Farm NPC", "Quest Farm", function(on)
    OnlyFarmNPC = on == true
    return OnlyFarmNPC
end)

local QuestDistance = 4
CreateNote("Farming Position", "Quest Farm")
CreateTextBox("Set Distance: ", "Quest Farm", { CustomText = "Default: 4" }, function(Input)
    local n = finiteNumber(Input, 0.5, 100)
    if n then QuestDistance = n end
end)

local QUnderneath = false
CreateToggle("Underneath", "Quest Farm", function(on)
    QUnderneath = on == true
    return QUnderneath
end)

local function TriggerQuest(job)
    if not jobActive(job) or not (SelectedQuestNPC and SelectedQuestNPC.Parent == npcFolder()) then return false end
    local root, p = SelectedQuestNPC:FindFirstChild("HumanoidRootPart"), hrp()
    local questDone, done = SelectedQuestNPC:FindFirstChild("QuestDone"), SelectedQuestNPC:FindFirstChild("Done")
    if not (root and p and questDone and done and questDone:IsA("RemoteEvent") and done:IsA("RemoteEvent")) then return false end
    if (root.Position - p.Position).Magnitude > 25 then
        if not approach(SelectedQuestNPC, 6, job) or not waitActive(0.1, job) then return false end
    end
    local currentRoot, currentHum = hrp(), hum()
    if not jobActive(job) or not (currentRoot and currentHum and currentHum.Health > 0)
        or SelectedQuestNPC.Parent ~= npcFolder()
        or SelectedQuestNPC:FindFirstChild("QuestDone") ~= questDone
        or SelectedQuestNPC:FindFirstChild("Done") ~= done
        or (root.Position - currentRoot.Position).Magnitude > 25 then return false end
    local ok1 = pcall(function() questDone:FireServer() end)
    if not jobActive(job) then return false end
    local ok2 = pcall(function() done:FireServer() end)
    return ok1 and ok2
end

local StartQuestFarming = false
CreateToggle("Begin Quest Farm", "Quest Farm", function(on)
    StartQuestFarming = on == true
    if not StartQuestFarming then jobStop("quest"); return false end
    local ready = SelectedNPC ~= "None" and (OnlyFarmNPC or (SelectedQuestNPC and SelectedQuestNPC.Parent == npcFolder()))
    if not ready then
        StartQuestFarming = false
        notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
        return false
    end
    jobStart("quest", true, function()
        StartQuestFarming = false
        SetToggle("Begin Quest Farm", "Quest Farm", false)
    end, function(job)
        while jobActive(job) do
            local L, p, myHum = living(), hrp(), hum()
            if L and p and myHum and myHum.Health > 0 then
                local target, bestDist
                for _, candidate in ipairs(L:GetChildren()) do
                    local th, root = candidate:FindFirstChildOfClass("Humanoid"), candidate:FindFirstChild("HumanoidRootPart")
                    if candidate.Name == SelectedNPC and candidate:FindFirstChild("AI") and th and root and th.Health > 0 and not Players:GetPlayerFromCharacter(candidate) then
                        local d = (p.Position - root.Position).Magnitude
                        if not bestDist or d < bestDist then target, bestDist = candidate, d end
                    end
                end
                if target then
                    if not OnlyFarmNPC and not TriggerQuest(job) then
                        notify("Quest request could not be sent; stopped.", 5)
                        break
                    end
                    local th = target:FindFirstChildOfClass("Humanoid")
                    while jobActive(job) and target.Parent == L and th and th.Health > 0 do
                        setAimTarget(target)
                        if holdPosition(target, QuestDistance, QUnderneath, job) then attackStep(job) end
                        if not waitActive(jitter(STEALTH.AttackMin, STEALTH.AttackMax), job) then break end
                    end
                    if not jobActive(job) then break end
                    if not OnlyFarmNPC then TriggerQuest(job) end
                    -- No unrelated +1000/+10 teleports after finishing or disabling.
                end
            end
            if not waitActive(0.4, job) then break end
        end
    end)
    return StartQuestFarming
end)

-- ══════════════════════════════════════════════════════════════════════════
-- ITEM FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Item Farm")
CreateNote("Farm Methods", "Item Farm")

local FarmMethod = 0
local StartFarming = false
local ItemSpeeds = {}
local startItemFarm
CreateNote("Current Method: None", "Item Farm")

local function restoreItemSpeeds()
    for humanoid, speed in pairs(ItemSpeeds) do
        if humanoid.Parent then
            pcall(function()
                if humanoid.WalkSpeed == 30 then humanoid.WalkSpeed = speed end
                local root = humanoid.Parent:FindFirstChild("HumanoidRootPart")
                if root then humanoid:MoveTo(root.Position) end
            end)
        end
    end
    ItemSpeeds = {}
end
addCleanup(restoreItemSpeeds)

local function setMethod(text)
    setNote("Current Method:", "Current Method: " .. text)
end
local function switchItemMethod(method, text)
    local running = StartFarming
    jobStop("items")
    restoreItemSpeeds()
    FarmMethod = method
    setMethod(text)
    if running and startItemFarm then
        local on = startItemFarm(true)
        SetToggle("Start Farming", "Item Farm", on)
    end
end
CreateButton("Instant", "Item Farm", function() switchItemMethod(1, "Instant") end)
CreateButton("Legit", "Item Farm", function() switchItemMethod(2, "Legit") end)

-- Only unowned world Tools; never chase another player's equipped inventory.
local function worldItem(tool)
    if not (tool and tool.Parent and tool:IsA("Tool")) then return false end
    local parent = tool.Parent
    while parent and parent ~= Workspace do
        if parent == char() or parent == backpack() or parent:IsA("Backpack") then return false end
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then return false end
        parent = parent.Parent
    end
    return parent == Workspace
end

local function itemTargets()
    local out, seen = {}, {}
    local p = hrp()
    local function consider(inst)
        if seen[inst] or not worldItem(inst) then return end
        seen[inst] = true
        local part = inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart", true)
        if not (part and part:IsA("BasePart")) then return end
        local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
        out[#out + 1] = { obj = inst, part = part, prompt = prompt }
    end
    for _, child in ipairs(Workspace:GetChildren()) do if child:IsA("Tool") then consider(child) end end
    for _, name in ipairs({ "Vfx", "Items" }) do
        local folder = Workspace:FindFirstChild(name)
        if folder then for _, child in ipairs(folder:GetDescendants()) do consider(child) end end
    end
    if p then table.sort(out, function(a, b) return (a.part.Position - p.Position).Magnitude < (b.part.Position - p.Position).Magnitude end) end
    return out
end

local function ownItem(tool)
    local bp, c = backpack(), char()
    return tool and ((bp and tool:IsDescendantOf(bp)) or (c and tool:IsDescendantOf(c)))
end

local function grabTool(t, job)
    local p, c = hrp(), char()
    if not jobActive(job) or not (p and t and t.part.Parent and worldItem(t.obj)) then return false end
    if not tpToCF(t.part.CFrame, job) or not waitActive(0.15, job) or char() ~= c then return false end
    if ownItem(t.obj) then return true end
    if not worldItem(t.obj) then return false end
    if t.prompt then fireProximity(t.prompt, job) end
    if not waitActive(0.15, job) then return false end
    return ownItem(t.obj) or t.obj.Parent == nil
end

local function moveWaypoint(h, position, job, character)
    local reached
    local connection = runConnect(h.MoveToFinished, function(ok) reached = ok end)
    job.connections[connection] = true
    h:MoveTo(position)
    local deadline = os.clock() + 3
    while reached == nil and jobActive(job) and char() == character and h.Parent == character
        and h.Health > 0 and FarmMethod == 2 and os.clock() < deadline do
        if not waitActive(0.05, job) then break end
    end
    connection:Disconnect()
    job.connections[connection] = nil
    local success = jobActive(job) and char() == character and FarmMethod == 2 and reached == true
    if not success then
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and h.Parent then h:MoveTo(root.Position) end
    end
    return success
end

local function walkAndGrab(t, job)
    local h, p, c = hum(), hrp(), char()
    if not jobActive(job) or not (h and h.Health > 0 and p and t and t.part.Parent and worldItem(t.obj)) then return false end
    local path = PathfindingService:CreatePath({ AgentCanJump = true })
    path:ComputeAsync(p.Position, t.part.Position)
    if not jobActive(job) or char() ~= c or not worldItem(t.obj) or path.Status ~= Enum.PathStatus.Success then return false end
    for _, wp in ipairs(path:GetWaypoints()) do
        if not jobActive(job) or char() ~= c or not worldItem(t.obj) or FarmMethod ~= 2 then return false end
        if wp.Action == Enum.PathWaypointAction.Jump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        if not moveWaypoint(h, wp.Position, job, c) then return false end
    end
    if not jobActive(job) or not worldItem(t.obj) then return ownItem(t.obj) end
    if t.prompt then fireProximity(t.prompt, job) end
    return ownItem(t.obj) or t.obj.Parent == nil
end

startItemFarm = function(on)
    StartFarming = on == true
    if not StartFarming then jobStop("items"); restoreItemSpeeds(); return false end
    if FarmMethod ~= 1 and FarmMethod ~= 2 then
        StartFarming = false
        notify("Select A Farm Method, And Re-Enable!")
        return false
    end
    jobStart("items", true, function()
        StartFarming = false
        SetToggle("Start Farming", "Item Farm", false)
        restoreItemSpeeds()
    end, function(job)
        while jobActive(job) do
            local h = hum()
            if h and h.Health > 0 then
                if FarmMethod == 2 then
                    if ItemSpeeds[h] == nil then ItemSpeeds[h] = h.WalkSpeed end
                    h.WalkSpeed = 30
                else
                    restoreItemSpeeds()
                end
                for _, t in ipairs(itemTargets()) do
                    if not jobActive(job) then break end
                    if FarmMethod == 1 then grabTool(t, job) else walkAndGrab(t, job) end
                    if not waitActive(0.15, job) then break end
                end
            end
            if not waitActive(FarmMethod == 1 and 0.3 or 1, job) then break end
        end
    end)
    return StartFarming
end
CreateToggle("Start Farming", "Item Farm", startItemFarm)

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
                runAsync(function()
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

local function standConfigurationChanged()
    jobStop("stand")
end

local StandCheck = false
CreateToggle("Enable Stand Check", "Stand Farm", function(on)
    standConfigurationChanged()
    StandCheck = on == true
    return StandCheck
end)

local AttributeCheck = false
CreateToggle("Enable Attribute Check", "Stand Farm", function(on)
    standConfigurationChanged()
    AttributeCheck = on == true
    return AttributeCheck
end)

local SplitChecking = false
CreateToggle("Split Checking", "Stand Farm", function(on)
    standConfigurationChanged()
    SplitChecking = on == true
    return SplitChecking
end)

CreateNote("Extra Settings", "Stand Farm")

local UseStandArrows   = true
local UseChargedArrows = false
local UseKarsMask      = false

CreateButton("Use Stand Arrows", "Stand Farm", function()
    standConfigurationChanged()
    UseStandArrows, UseChargedArrows, UseKarsMask = true, false, false
    notify("Using Stand Arrows", 3)
end)

CreateButton("Use Charged Arrows", "Stand Farm", function()
    standConfigurationChanged()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, true, false
    notify("Using Charged Arrows", 3)
end)

CreateButton("Use Kars Mask", "Stand Farm", function()
    standConfigurationChanged()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, false, true
    notify("Using Kars Mask", 3)
end)

local AutoBuyArrows = false
CreateToggle("Auto Buy Selected Arrows", "Stand Farm", function(on)
    AutoBuyArrows = on == true
    return AutoBuyArrows
end)

local AutoBuyRokakaka = false
CreateToggle("Auto Buy Rokakaka", "Stand Farm", function(on)
    AutoBuyRokakaka = on == true
    return AutoBuyRokakaka
end)

local Webhook = ""
CreateTextBox("Set Webhook", "Stand Farm", {}, function(Input)
    Webhook = Input or ""
end)

local EnableWebhook = false
CreateToggle("Enable Webhook", "Stand Farm", function(on)
    EnableWebhook = on == true
    return EnableWebhook
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
                runAsync(function()
                    CreateToggle(stand, "Stand Farm", function(on)
                        standConfigurationChanged()
                        local at = table.find(WhitelistedStands, stand)
                        if on and not at then
                            WhitelistedStands[#WhitelistedStands + 1] = stand
                        elseif not on and at then table.remove(WhitelistedStands, at) end
                        return on == true
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
                local attr = tostring(v.Text):gsub("%s*[%(%[]?[%d%.]+%%%s*[%)%]]?%s*$", ""):match("^%s*(.-)%s*$")
                if attr == "Glass" then attr = "Glass Cannon" end
                if attr and attr ~= "" and not seen[attr] then
                    seen[attr] = true
                    local name = attr
                    runAsync(function()
                        CreateToggle(name, "Stand Farm", function(on)
                            standConfigurationChanged()
                            local at = table.find(WhitelistedAttributes, name)
                            if on and not at then
                                WhitelistedAttributes[#WhitelistedAttributes + 1] = name
                            elseif not on and at then table.remove(WhitelistedAttributes, at) end
                            return on == true
                        end)
                    end)
                end
            end
        end
    end
end

local function sendRollWebhook(currentStand, currentAttri)
    if not EnableWebhook or not Runtime.alive then return end
    webhookSend(Webhook, {
        content = "@everyone```\nUsername: " .. LP.Name
               .. "\nStand: " .. currentStand
               .. "\nAttribute: " .. currentAttri .. "```",
    })
end

local function standConfigurationReady()
    return (StandCheck or AttributeCheck)
        and (not StandCheck or #WhitelistedStands > 0)
        and (not AttributeCheck or #WhitelistedAttributes > 0)
end

local function standMatches()
    local currentStand, currentAttri = standName(), standAttri()
    local check1 = StandCheck and table.find(WhitelistedStands, currentStand) ~= nil
    local check2 = AttributeCheck and table.find(WhitelistedAttributes, currentAttri) ~= nil
    local hit
    if SplitChecking then hit = check1 or check2
    elseif StandCheck and AttributeCheck then hit = check1 and check2
    else hit = check1 or check2 end
    return hit, currentStand, currentAttri
end

local function stopOnStandMatch(job)
    if not jobActive(job) then return true end
    if not standConfigurationReady() then
        jobStop("stand")
        notify("Stand Farm: checking configuration changed; stopped.", 5)
        return true
    end
    local hit, currentStand, currentAttri = standMatches()
    if not hit then return false end
    jobStop("stand")
    notify("Target roll found: " .. currentStand .. " [" .. currentAttri .. "]", 8)
    runAsync(function() sendRollWebhook(currentStand, currentAttri) end)
    return true
end

-- ── NEXT MOVE ─────────────────────────────────────────────────────────────
-- FIX: UseArrow / UseChargedArrow — несуществующие глобалы, из-за опечатки
-- автопокупка не срабатывала никогда. Плюс вечные repeat-until без таймаута.
local function rollReady(job, character)
    local h = hum()
    local data = LP:FindFirstChild("Data")
    return jobActive(job) and char() == character and h and h.Health > 0 and hrp()
        and data and data:FindFirstChild("Stand") and data:FindFirstChild("Attri")
end

local function awaitInventory(name, job, character)
    local deadline = os.clock() + 4
    while rollReady(job, character) and os.clock() < deadline do
        local bp = backpack()
        local tool = character:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
        if tool and tool:IsA("Tool") then return true end
        if not waitActive(0.1, job) then break end
    end
    return false
end

local function buyArrow(job)
    if UseKarsMask then return false, "Kars Mask auto-buy protocol is not available" end
    local ev, nf = events(), npcFolder()
    local buy = ev and ev:FindFirstChild("BuyItem")
    local charged = UseChargedArrows
    local merchant = charged and "Merchant120" or "MerchantAU"
    local npc = nf and (nf:FindFirstChild(merchant) or (charged and nf:FindFirstChild("Merchantlvl120")))
    local c = char()
    if not (buy and buy:IsA("RemoteEvent") and npc and npc:FindFirstChild("HumanoidRootPart")) or not rollReady(job, c) then return false, "Arrow merchant unavailable" end
    if not tpToCF(npc.HumanoidRootPart.CFrame, job) then return false, "Could not reach arrow merchant" end
    if not waitActive(0.5, job) or not rollReady(job, c) or stopOnStandMatch(job) then return false, "cancelled" end
    -- Merchantlvl120 is the protocol role in the saved NpcDialogue client.
    local sent = pcall(function() buy:FireServer(charged and "Merchantlvl120" or "MerchantAU", charged and "Option2" or "Option4") end)
    if not sent then return false, "Arrow purchase request failed" end
    if not awaitInventory(charged and "Charged Arrow" or "Stand Arrow", job, c) then return false, "Arrow purchase produced no item" end
    return true
end

local function buyRokakaka(job)
    local ev, nf = events(), npcFolder()
    local buy = ev and ev:FindFirstChild("BuyItem")
    local npc = nf and nf:FindFirstChild("MerchantAU")
    local c = char()
    if not (buy and buy:IsA("RemoteEvent") and npc and npc:FindFirstChild("HumanoidRootPart")) or not rollReady(job, c) then return false, "Rokakaka merchant unavailable" end
    if not tpToCF(npc.HumanoidRootPart.CFrame, job) then return false, "Could not reach Rokakaka merchant" end
    if not waitActive(0.5, job) or not rollReady(job, c) or stopOnStandMatch(job) then return false, "cancelled" end
    local sent = pcall(function() buy:FireServer("MerchantAU", "Option2") end)
    if not sent then return false, "Rokakaka purchase request failed" end
    if not awaitInventory("Rokakaka", job, c) then return false, "Rokakaka purchase produced no item" end
    return true
end

local function NextMove(job)
    local c = char()
    if not rollReady(job, c) then return false, "Character or Data unavailable" end
    local arrow = UseKarsMask and "Kars Mask" or (UseChargedArrows and "Charged Arrow" or "Stand Arrow")
    local removing = hasStand()
    local name = removing and "Rokakaka" or arrow
    local bp = backpack()
    local tool = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
    if not tool then
        if removing and AutoBuyRokakaka then return buyRokakaka(job) end
        if not removing and AutoBuyArrows then return buyArrow(job) end
        return false, "No " .. name .. " in inventory"
    end
    if not tool:IsA("Tool") then return false, name .. " is not a Tool" end
    local owner = equipmentAcquire(job)
    if not owner then return false, "Another operation owns equipment" end
    local ok, result, reason = pcall(function()
        local function beforeUse()
            return rollReady(job, c) and not stopOnStandMatch(job) and hasStand() == removing
        end
        if not useToolName(name, job, beforeUse) then return false, "Could not use " .. name end
        local deadline = os.clock() + 8
        while rollReady(job, c) and os.clock() < deadline do
            if stopOnStandMatch(job) then return true end
            if hasStand() ~= removing then return true end
            if not waitActive(0.2, job) then return false, "cancelled" end
        end
        return false, "No stand change after " .. name
    end)
    equipmentRelease(owner)
    if not ok then return false, tostring(result) end
    return result, reason
end

local StandFarm = false
local stopFakeProfile
CreateToggle("Begin Stand Farm", "Stand Farm", function(on)
    StandFarm = on == true
    if not StandFarm then jobStop("stand"); return false end
    if not standConfigurationReady() then
        StandFarm = false
        notify("Enable a check and select its target before farming.", 5)
        return false
    end
    if stopFakeProfile then stopFakeProfile() end
    jobStart("stand", true, function()
        StandFarm = false
        SetToggle("Begin Stand Farm", "Stand Farm", false)
    end, function(job)
        local failures = 0
        while jobActive(job) do
            if not standConfigurationReady() then
                notify("Stand Farm: checking configuration changed; stopped.", 5)
                break
            end
            local c = char()
            if not rollReady(job, c) then
                if not waitActive(0.5, job) then break end
            else
                if stopOnStandMatch(job) then return end
                local ok, reason = NextMove(job)
                if not jobActive(job) then break end
                if ok then failures = 0 else failures = failures + 1 end
                if failures >= 3 then notify("Stand Farm stopped: " .. tostring(reason), 6); break end
                if not waitActive(0.4, job) then break end
            end
        end
    end)
    return StandFarm
end)

-- ══════════════════════════════════════════════════════════════════════════
-- Loaded notification is emitted after every menu and the control API exist.

-- ══════════════════════════════════════════════════════════════════════════
-- BEGIN SUR FAKE TARGET BLOCK
-- Canonical implementation is inserted from src/fake_autokill_block.lua by the builder.
-- END SUR FAKE TARGET BLOCK

-- SUR CONTROL API
-- Пульт для агента/консоли. UI не трогает, меню не меняет — только дёргает
-- те же функции, что и кнопки. Нужен, чтобы фарм можно было поднять без
-- кликов по тогглам.
-- ══════════════════════════════════════════════════════════════════════════
local SUR = {}
local publicEnv = getgenv()
publicEnv.SUR = SUR

function SUR.unload()
    if not Runtime.alive then return true end
    Runtime.alive = false
    local names = {}
    for name in pairs(Runtime.jobs) do names[#names + 1] = name end
    for _, name in ipairs(names) do jobStop(name) end
    AutoUmbrella, AntiAFK, SellKetchup = false, false, false
    StartLairFarming, StartQuestFarming, StartFarming, StandFarm = false, false, false, false
    for name in pairs(BossOn) do BossOn[name] = false end
    for held in pairs(Runtime.heldInputs) do
        pcall(function() held.remote:FireServer({ State = "End", Key = held.key, Type = held.utype }) end)
    end
    Runtime.heldInputs = {}
    for prompt in pairs(Runtime.heldPrompts) do pcall(function() prompt:InputHoldEnd() end) end
    Runtime.heldPrompts = {}
    for _, connection in ipairs(Runtime.connections) do pcall(function() connection:Disconnect() end) end
    Runtime.connections = {}
    for thread in pairs(Runtime.tasks) do
        if thread ~= coroutine.running() and task.cancel then pcall(task.cancel, thread) end
    end
    Runtime.tasks = {}
    for i = #Runtime.cleanup, 1, -1 do
        local ok, err = pcall(Runtime.cleanup[i])
        if not ok then warn("[Arctic SUR] cleanup: " .. tostring(err)) end
    end
    Runtime.cleanup = {}
    UIDestroy()
    -- An old retained unload reference must never erase a newer injection.
    if publicEnv.SUR == SUR then publicEnv.SUR = nil end
    if publicEnv.SUR_unload == SUR.unload then publicEnv.SUR_unload = nil end
    return true
end
publicEnv.SUR_unload = SUR.unload

-- Local character transitions cannot carry a farm into an unrelated spawn.
runConnect(LP.CharacterRemoving, function()
    Runtime.movementRevision = Runtime.movementRevision + 1
    if not Runtime.jobs.lair then clearLairContext() end
    local job = Runtime.movement
    if job and job.name == "lair" then
        stopLairFarm("character_changed", "character changed")
    elseif job then
        jobStop(job.name)
    end
end)

stopFakeProfile = function() fakeStop() end

function SUR.state()
    local p = hrp()
    return {
        player    = LP.Name,
        level     = (function()
            local d = LP:FindFirstChild("Data")
            local l = d and d:FindFirstChild("Level")
            return l and l.Value or nil
        end)(),
        place     = game.PlaceId,
        stand     = standName(),
        attri     = standAttri(),
        moves     = #ClearMoves,
        standCode = standCode(),
        active    = Runtime.alive,
        movement  = Runtime.movement and Runtime.movement.name or nil,
        fakeOn    = Fake.active,
        autoKill  = AutoKill.enabled,
        picking   = AutoKill.picking,
        selectedTarget = AutoKill.target and AutoKill.target.Name or nil,
        position  = p and { X = p.Position.X, Y = p.Position.Y, Z = p.Position.Z } or nil,
        lairNPC   = SelectedLairNPCText,
        lairOn    = StartLairFarming,
        lairPhase = LairState.phase,
        lairStopReason = LairState.stopReason,
        lairDetail = LairState.detail,
        lairEntrySent = LairState.entrySent,
        lairProbeAttempted = LairState.probe and LairState.probe.attempted or false,
        lairLocalZeroOwned = LairState.probe and LairState.probe.ownedZero or false,
        lairResumeUntil = LairState.context and LairState.context.resumeUntil or nil,
        lairAnchor = LairState.anchor and { X = LairState.anchor.X, Y = LairState.anchor.Y, Z = LairState.anchor.Z } or nil,
        instant   = InstantBossKill,
        underneath= Underneath,
        bossAlive = (function()
            local b = StartLairFarming and LairState.target or findLairBoss()
            return b and b.Parent and b.Name or nil
        end)(),
    }
end

-- Список NPC вокруг: имя, дистанция, есть ли Done/QuestDone.
function SUR.npcs(radius)
    local p = hrp()
    local nf = npcFolder()
    local out = {}
    if not Runtime.alive or not (p and nf) then return out end
    radius = finiteNumber(radius, 1, 10000) or 400
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (p.Position - root.Position).Magnitude
            if d <= (radius or 400) then
                out[#out + 1] = {
                    name    = v.Name,
                    dist    = math.floor(d),
                    done    = v:FindFirstChild("Done") ~= nil,
                    quest   = v:FindFirstChild("QuestDone") ~= nil,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Выбор лейр-NPC: по имени (частичное совпадение) или ближайшего.
-- radius обязателен: без него можно было зацепить NPC в другой части карты
-- и уехать телепортом из лейра в обычный мир.
function SUR.selectLair(fragment, radius)
    local nf = npcFolder()
    if not nf then return false, "no Map.NPCs" end

    if not Runtime.alive then return false, "unloaded" end
    radius = finiteNumber(radius, 1, 500) or 15
    if fragment ~= nil then fragment = tostring(fragment) end
    local p = hrp()
    if not p then return false, "no character" end

    local pick, pickDist = nil, math.huge

    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local okName = (not fragment) or string.find(string.lower(v.Name), string.lower(fragment), 1, true)
        local done = v:FindFirstChild("Done")
        if root and okName and done and done:IsA("RemoteEvent") then
            local d = (p.Position - root.Position).Magnitude
            if d <= radius and d < pickDist then pick, pickDist = v, d end
        end
    end

    if not pick then return false, "no match within " .. radius .. " studs" end

    local head = pick:FindFirstChild("Head")
    local main = head and head:FindFirstChild("Main")
    local txt  = main and main:FindFirstChild("Text")

    stopLairFarm("provider_changed", "Lair NPC reselected")
    SelectedLairNPC = pick
    SelectedLairNPCText = (txt and txt.Text) or pick.Name
    setNote("Selected Lair NPC:", "Selected Lair NPC: " .. SelectedLairNPCText)
    return true, SelectedLairNPCText
end

function SUR.underneath(on)
    if not Runtime.alive then return false end
    Underneath = on ~= false
    SetToggle("Underneath", "Lair Farm", Underneath)
    return Underneath
end

function SUR.instantKill(on)
    if not Runtime.alive then return false end
    InstantBossKill = on == true
    SetToggle("Instant Boss Kill (HP = 0)", "Lair Farm", InstantBossKill)
    return InstantBossKill
end

function SUR.lairStart()
    local on = startLairFarm()
    SetToggle("Begin Lair Farm", "Lair Farm", on)
    return on
end

function SUR.lairStop()
    stopLairFarm()
    return true
end

-- Диагностика живого клиента: что реально лежит в Living и в Map.NPCs.
function SUR.scan()
    local L = living()
    local out = { living = {}, npcFolders = {}, playerGui = {} }

    if L then
        for _, m in ipairs(L:GetChildren()) do
            local h = m:FindFirstChildOfClass("Humanoid")
            out.living[#out.living + 1] = {
                name  = m.Name,
                human = h ~= nil,
                hp    = h and h.Health or nil,
                max   = h and h.MaxHealth or nil,
                root  = m:FindFirstChild("HumanoidRootPart") ~= nil,
            }
        end
    end

    local nf = npcFolder()
    if nf then
        for _, v in ipairs(nf:GetChildren()) do
            out.npcFolders[#out.npcFolders + 1] = {
                name = v.Name,
                done = v:FindFirstChild("Done") ~= nil,
            }
        end
    end

    return out
end


function SUR.diagnostics()
    local out = { active = Runtime.alive, jobs = {}, errors = {}, connections = 0, tasks = 0,
        lair = { phase = LairState.phase, stopReason = LairState.stopReason, detail = LairState.detail, trace = {} } }
    for i, entry in ipairs(LairState.trace) do
        out.lair.trace[i] = { time = entry.time, phase = entry.phase, reason = entry.reason, detail = entry.detail }
    end
    local ctx = LairState.context
    out.lair.context = ctx and {
        inplace = ctx.inplace == true, entrySent = ctx.entrySent == true,
        resumeUntil = ctx.resumeUntil, exact = lairExact(ctx),
        revision = ctx.movementRevision, currentRevision = Runtime.movementRevision,
        ownedZero = ctx.probe and ctx.probe.ownedZero or false,
        targetHealth = ctx.targetHum and ctx.targetHum.Health or nil,
    } or nil
    for name in pairs(Runtime.jobs) do out.jobs[#out.jobs + 1] = name end
    table.sort(out.jobs)
    for _, connection in ipairs(Runtime.connections) do if connection.Connected then out.connections = out.connections + 1 end end
    for thread in pairs(Runtime.tasks) do
        if coroutine.status(thread) ~= "dead" then out.tasks = out.tasks + 1 else Runtime.tasks[thread] = nil end
    end
    for i, err in ipairs(Runtime.errors) do out.errors[i] = err end
    return out
end

pcall(function()
    CreateNotification("Arctic", "Loaded. Press L to toggle.", { Duration = 6 })
end)
print("[Arctic SUR] loaded | stand=" .. standName() .. " | attri=" .. standAttri())
