-- ============================================================
-- SUR autolair — поднимает Lair Farm сразу после загрузки SUR_Message.lua.
-- Работает только через getgenv().SUR (SUR CONTROL API).
-- Всё логируется через print, чтобы было видно в F9.
-- Удалить: удали этот файл из autoexec.
-- ============================================================

local function log(msg)
    pcall(function() print("[autolair] " .. tostring(msg)) end)
end

-- 1. ждём публикации пульта основным скриптом
local t0 = os.clock()
repeat
    task.wait(0.5)
until getgenv().SUR or os.clock() - t0 > 60

if not getgenv().SUR then
    log("SUR API НЕ появился — SUR_Message.lua не загрузился")
    return
end

local SUR = getgenv().SUR
log("SUR API найден")

-- 2. даём игре досчитаться
task.wait(8)

-- 3. что вообще вокруг
local okState, st = pcall(SUR.state)
if okState and st then
    log("state: level=" .. tostring(st.level)
        .. " stand=" .. tostring(st.stand)
        .. " attri=" .. tostring(st.attri)
        .. " moves=" .. tostring(st.moves))
end

local okNpc, npcs = pcall(SUR.npcs, 400)
if okNpc and npcs then
    log("NPC в радиусе 400: " .. #npcs)
    for i = 1, math.min(#npcs, 8) do
        local n = npcs[i]
        log(string.format("  %d) %s  dist=%s done=%s quest=%s",
            i, n.name, tostring(n.dist), tostring(n.done), tostring(n.quest)))
    end
end

-- 4. выбор лейр-NPC
local picked, name = SUR.selectLair()
if not picked then
    log("лейр-NPC не найден: " .. tostring(name))
    return
end
log("выбран NPC: " .. tostring(name))

-- 5. настройки и старт
SUR.underneath(false)     -- под землю не лезем: можно провалиться
SUR.instantKill(false)    -- HP=0 = кик 267, не трогаем

local started = SUR.lairStart()
log("lairStart = " .. tostring(started))

task.wait(3)
local ok2, st2 = pcall(SUR.state)
if ok2 and st2 then
    log("после старта: lairOn=" .. tostring(st2.lairOn)
        .. " boss=" .. tostring(st2.bossAlive)
        .. " npc=" .. tostring(st2.lairNPC))
end
