# message.txt → SUR_Message.lua

Порт исходного `message.txt` (1162 строки, 90 элементов UI) в один рабочий файл.
**Меню, кнопки, тогглы, поля и подписи не менялись** — изменена только
внутренняя реализация там, где она перестала работать после обновлений игры.

Проверка: `python tools/lua_syntax.py SUR_Message.lua` — реальный Lua-VM
(`lupa`, Lua 5.5) парсит файл без ошибок.

---

## Уязвимость, которая была и осталась

Ядро Lair Farm — прямое присваивание здоровья босса с клиента:

```lua
Workspace.Living.Boss.Humanoid.Health = 0
```

Сервер принимает эту репликацию, и лейр-босс умирает мгновенно, без боя.
В оригинале строка стояла безусловно, внутри боевого цикла. В порте она
сохранена дословно, но:

* вынесена в `killTarget()` с `pcall` и фолбэком (`TakeDamage`, `ChangeState(Dead)`);
* закрыта тогглом **Instant Boss Kill (HP = 0)**.

> [!WARNING]
> Тоггл по умолчанию **выключен**. Именно этот пакет сервер ловит как
> `Exploit Detected: Auto Lair Farm. (Error Code: 267)`. Включай осознанно.

Второй файл — `message (1).txt` — содержит ту же строку, только с проверкой
`if boss and boss:FindFirstChild("Humanoid")`. Это подтверждает, что механизм
именно такой; в порте сделана такая же защита от nil.

---

## Античит: почему кикало и что изменено

Античит **серверный**. В клиентском дампе (`dumps/Client.lua`, 351 КБ) нет ни
строки `Exploit Detected`, ни `Auto Lair`, ни `AntiCheat` — только совпадения
по именам мувов (`JSPOHKick`, `PSCKick`). Значит, клиент нечего «выключать»:
сервер смотрит на **паттерн пакетов**, а не на факт инжекта.

Что было в порте (и в оригинале `message.txt`) и как это выглядело снаружи:

| Паттерн | Было | Стало |
|---|---|---|
| запись `CFrame` | каждый тик боевого цикла, ~7 раз/с | только если отъехали > 12 студов, не чаще раза в 0.85 с |
| `AssemblyLinearVelocity = 0` | каждый тик, поверх записи позиции | **удалено полностью** |
| `Done:FireServer()` | каждые 0.6 с, метроном, без проверки дистанции | раз в 2.6–4.4 с (рандом), только в радиусе 25 студов, иначе одна перестановка |
| `Input:FireServer` (удар) | фиксированные 0.15 с | рандом 0.22–0.38 с |
| длительность сессии | бесконечная | авто-стоп через 25 минут |
| порядок | сначала удар, потом позиция | позиция **до** удара, иначе босс успевает отойти |
| `Health = 0` | каждый тик, безусловно | кулдаун 0.35 с + тоггл (по умолчанию off) |

Плюс `findLairBoss()`: раньше верили только в имя `Living.Boss`; теперь
фолбэк — любой живой `Humanoid` в `Living`, который не игрок.

Плюс «Select Lair NPC» / «Select Quest NPC» / «Select NPC» теперь берут
**ближайшего** NPC, а не последнего подходящего в списке.

---

## Lair Farm бил ВСЕХ NPC — исправлено

Регрессия, которую я сам внёс: фолбэк «любой живой `Humanoid` в `Living`,
который не игрок». Он срабатывал, когда `Living.Boss` ещё не появился, брал
первого попавшегося NPC, `holdPosition` телепортил к нему, `attackStep` бил —
NPC умирал — цикл брал следующего. Отсюда «просто всех NPC ебашит».

Что сделано:

| | |
|---|---|
| поиск босса | строго: имя `Boss` → имя содержит `boss` → **только то, что появилось в `Living` после вызова `Done`** (`snapshotLiving()` снимается до спавна) |
| цель боя | фиксируется один раз и держится, пока жива. Раньше `findLairBoss()` вызывался на каждом тике и после смерти босса перескакивал на следующего |
| ожидание | если за 12 с босс не появился — `notify` со списком того, что реально лежит в `Living`, чтобы имя босса можно было поправить по факту |

Регрессионный тест: `python tools/boss_target.py SUR_Message.lua` —
3 кейса (только обычные NPC → `nil`; появился `Boss` → `Boss`; чужое имя без
baseline → не хватает). Проходит.

---

## Quest Farm улетал в небо

После убийства цели стояло:

```lua
p.CFrame = CFrame.new(p.Position + Vector3.new(0, 0, 1000))
p.CFrame = CFrame.new(p.Position + Vector3.new(0, 10, 0))
```

Второй `CFrame` читал **уже изменённую** позицию, поэтому персонаж оказывался
на `+1010` студов по вертикали и падал. Теперь база запоминается до первого
прыжка, возврат идёт в исходную точку.

---

## Автозапуск фарма убран из autoexec

`01_SUR_autolair.lua` сам поднимал Lair Farm при каждой загрузке скрипта.
Переименован в `01_SUR_autodiag.lua` и теперь **только пишет в F9**: уровень,
стенд, атрибут, мувсет, живого босса и ближайших NPC. Фарм не запускает —
стартует только по кнопке `Begin Lair Farm`.

Честно: это снижает шанс детекта, а не «обходит» его гарантированно. Логика
сервера с клиента не читается — её нельзя проверить, не поймав кик.

---

## Таблица багов

| # | Место | Что было | Почему не работало | Что сделано |
|---|---|---|---|---|
| 1 | строка 1 | `loadstring(game:HttpGetAsync("https://icebear.lol/StandUpright/LIB.txt"))()` | домен мёртв — скрипт не запускался вообще | библиотека встроена в файл |
| 2 | все фармы | `StandEvents.M1:FireServer()`, `StandEvents.Summon:FireServer()`, `v:FireServer(true)` | этих ремоутов в игре больше нет — **ноль урона** | живой протокол `StandEvents.Input:FireServer({State, Key, Type})` |
| 3 | все фармы | `for i, v in pairs(CDgui.fortnite) ... else M1:FireServer() end` | на каждый НЕ-Punch элемент кулдаун-ги (десятки) летел отдельный «удар» — спам в пустоту | один удар за тик, `CDgui` не читается |
| 4 | Shops | `firesignal(game.Players["polar_eXDAVH"].PlayerGui...)` | чужой захардкоженный ник — падало на закрытии биржи | `LP.PlayerGui` + `pcall` + фолбэк без `firesignal` |
| 5 | Stand Farm | `if UseArrow then` | глобал `UseArrow` не существует (есть `UseStandArrows`) — автопокупка стрел **никогда** | правильное имя |
| 6 | Stand Farm | `elseif UseChargedArrow then` | та же опечатка (`UseChargedArrows`) | исправлено |
| 7 | NextMove | `repeat task.wait() until Character:FindFirstChild(Tool)` | вечное зависание, если экипировка не удалась | `WaitForChild(name, 3)` + выход |
| 8 | NextMove | `repeat ... until StandName.TextLabel.Text ~= "None"` | мог крутиться бесконечно, если стрела не сработала | лимит 40 попыток × 0.5с |
| 9 | Lair / Quest | `EditString("Selected Lair NPC: "..Text, ...)` | ломалось, как только текст расходился на символ — подпись замирала | поиск подписи по префиксу (`setNote`) |
| 10 | LocalPlayer, Shops, все фармы | `while flag do ... end` прямо в колбэке тоггла | цикл блокировал свой же колбэк | все циклы в `task.spawn` |
| 11 | Item Farm | `fireproximityprompt(ProximityPrompt)` при `nil` | `pcall` глотал ошибку, луп крутился вхолостую | проверка + фолбэк `InputHoldBegin/End` |
| 12 | Item Farm | скан только `Workspace.Vfx` | если предмет в `Workspace.Items` — не находился | `Vfx` + `Items` |
| 13 | Item Farm | `Humanoid.MoveToFinished:Wait()` | вечное ожидание, если дойти нельзя | `:Wait(3)` |
| 14 | Stand Farm | `break` из `while` | тоггл оставался включённым, а цикл уже мёртвый | честный стоп + уведомление |
| 15 | Stand Farm | Refresh Movesets перебирал `RemoteEvent`'ы `Character.StandEvents` | их нет — список мувов всегда пустой | `StandEvents.Info:InvokeServer("Moveset")` |
| 16 | Shops | `task.spawn(function() local Item = AllItems[i] ... end)` | замыкание могло захватить не тот индекс — покупка не тем предметом | локальная копия на итерацию |
| 17 | Shops | `NPCs.StockMarket.Head.CFrame` | падало, если у NPC нет `Head` | `Head` или `HumanoidRootPart`, плюс проверка |
| 18 | Teleports | `Players[Fill(A)].Character...` | `Fill` возвращает ввод как есть при промахе → ошибка по nil | проверка игрока и персонажа |
| 19 | Teleports | кнопки NPC создавались в `task.spawn` с замыканием на `v` | могло телепортировать не к тому NPC | локальная копия `npc` |
| 20 | Quest Farm | `if SelectedQuestNPC and SelectedNPC ~= "None" or OnlyFarmNPC == true and ...` | приоритет `and`/`or` читался не так, как задумано | явные скобки |
| 21 | Quest Farm | `v.Humanoid.Health` без проверки | ошибка, если у модели нет Humanoid | `FindFirstChildOfClass("Humanoid")` |
| 22 | Quest Farm | вложенные `for i, v in pairs(...)` затеняли внешний `v` | обращения после цикла шли не к той модели | переименовано в `target` |
| 23 | Lair Farm | `repeat TriggerLair() until Living:FindFirstChild("Boss")` | вечный цикл, если босс не спавнится | таймаут 25с |
| 24 | Lair / Quest | `SelectedLairNPC:GetChildren()` при `nil` | ошибка ловилась `pcall`, луп умирал молча | проверка + уведомление |
| 25 | Boss Farm | один и тот же цикл скопирован трижды (JOH / Johnny / AJP4) | ~300 строк дубля, три источника рассинхрона | одна `bossFarm(model, label)` |
| 26 | Boss Farm, Lair, Quest | `Character:FindFirstChild("Aura").Value` | падало, если `Aura` нет | проверка `Character.Stand` + троттлинг `Q` |
| 27 | Boss Farm | `Character.MoveCD.Value` | мёртвое поле, гейт кулдауна не работал | убран (сервер сам держит кулдаун) |
| 28 | Shops | `CreateNote(..., "Shops", {})` | лишний аргумент у функции с двумя параметрами | убран |
| 29 | Stand Farm | `Request(Embed)` без проверки, что `request` вообще есть | ошибка внутри цикла роллов | `webhookSend()` c проверкой |
| 30 | Stand Farm | в `Ignore` две строки в битом mojibake | не могли совпасть ни с одним стендом | удалена одна мёртвая строка |
| 31 | Stand Farm | дубли тогглов атрибутов | если на доске два одинаковых атрибута | дедуп по имени |

---

## Что осталось ровно как было

* Порядок меню: Home → LocalPlayer → Shops → Farm Settings → Boss Farm →
  Lair Farm → Quest Farm → Item Farm → Teleports → Stand Farm.
* Все 90 элементов: те же названия, те же места, те же подписи-заметки.
* Все координаты телепортов (14 локаций) — символ в символ.
* Список `Ignore` для Stand Farm, список предметов биржи, список атрибутов.
* Логика Stand Farm: Stand Check / Attribute Check / Split Checking, выбор
  стрел, автопокупка, вебхук.
* Логика Item Farm: Instant / Legit, путь по waypoint'ам, `WalkSpeed 30`.

Добавлен ровно один элемент — тоггл **Instant Boss Kill (HP = 0)** в Lair Farm,
чтобы эксплойт был явным и отключаемым.

---

## Сборка

```bash
python src/build_message.py      # lib_fixed + message_main -> SUR_Message.lua
python tools/lua_syntax.py SUR_Message.lua
python tools/luacheck_rough.py SUR_Message.lua
```

---

## Проверка без игры

1. **Синтаксис** — `tools/lua_syntax.py` грузит файл в настоящую Lua-VM
   (`lupa`, Lua 5.5). Чисто.
2. **Баланс блоков** — `tools/luacheck_rough.py`. Чисто.
3. **Мок-прогон** — `tools/mock_check.py` поднимает фейковый Roblox
   (`tools/mock_roblox.lua`): Workspace с `Map.NPCs`, `Living`, `Items`, `Vfx`,
   `ChancesBoards`, `ReplicatedStorage.Events`, `StandNameConvert`, игрок с
   `Data` / `Backpack` / `Character.StandEvents`, сервисы, сигналы.
   Скрипт в нём **загружается целиком и строит всё меню**, после чего
   прожатие получают все 107 обработчиков (каждая кнопка, каждый тоггл дважды,
   каждое поле ввода).

```
load + UI build: OK  (107 handlers fired)
```

Это ловит опечатки, nil-индексацию и неверные аргументы в UI-слое. Чего это
не ловит: серверную логику игры — реальные ремоуты, урон, спавн боссов.
Это только живой запуск.

