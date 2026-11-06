-- ============================================================
-- SUR autodiag — ТОЛЬКО диагностика. Ничего не запускает.
--
-- Раньше этот файл сам поднимал Lair Farm при каждой загрузке — из-за этого
-- фарм стартовал без ведома игрока. Теперь он лишь пишет в F9, что видит.
--
-- Хочешь фарм — нажми "Begin Lair Farm" в меню Lair Farm, или выполни:
--     getgenv().SUR.selectLair(); getgenv().SUR.lairStart()
--
-- Удалить: удали этот файл из autoexec.
-- ============================================================

local function log(msg)
    pcall(function() print("[autodiag] " .. tostring(msg)) end)
end

local t0 = os.clock()
repeat
    task.wait(0.5)
until getgenv().SUR or os.clock() - t0 > 60

if not getgenv().SUR then
    log("SUR API не появился — SUR_Message.lua не загрузился")
    return
end

local SUR = getgenv().SUR
task.wait(6)

local ok, st = pcall(SUR.state)
if ok and st then
    log("level=" .. tostring(st.level)
        .. " stand=" .. tostring(st.stand)
        .. " attri=" .. tostring(st.attri)
        .. " moves=" .. tostring(st.moves)
        .. " boss=" .. tostring(st.bossAlive))
end

local okN, npcs = pcall(SUR.npcs, 400)
if okN and npcs then
    log("NPC рядом: " .. #npcs)
    for i = 1, math.min(#npcs, 5) do
        local n = npcs[i]
        log(string.format("  %s dist=%s done=%s", n.name, tostring(n.dist), tostring(n.done)))
    end
end

log("готово. фарм НЕ запущен — жми 'Begin Lair Farm' сам.")
