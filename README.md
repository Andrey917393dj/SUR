# Arctic SUR

Скрипт для **Stand Upright: Rebooted** (place `8540168650`), переписанный с нуля
по живому дереву игры, а не по догадкам.

> [!IMPORTANT]
> Предыдущие версии (`message.txt`, `merged_script_fixed.lua`, `SUR_Arctic_Main.lua`)
> **мертвы в боевой части**: после обновления игра убрала ремоуты
> `StandEvents.Summon`, `StandEvents.M1`, `StandEvents.Barrage` и т.д.
> Этот скрипт работает на новом протоколе `StandEvents.Input`.

---

## Быстрый старт

1. Открой Roblox → Stand Upright.
2. Инжектни любой executor (Xeno / Solara).
3. Вставь содержимое [`SUR_Arctic_v2.lua`](SUR_Arctic_v2.lua) и запусти.
4. Меню — по клавише **J**. Перетаскивание — за шапку.

Один файл, библиотека внутри, никаких `loadstring(HttpGet(...))` — интернет
для запуска не нужен.

---

## Меню

| Меню | Что внутри |
|---|---|
| **Home** | снапшот игрока, запуск полного аудита ×20 |
| **Combat** | Auto Attack, Auto Barrage, Auto Heavy, все мувы по кнопке |
| **NPC & Quest** | `Done` / `QuestDone` на любом NPC, на всех сразу, авто-луп |
| **Shop** | `BuyItem`, скупка кетчупа, Auto Sell Ketchup со счётчиком |
| **Stand** | слоты 1–5, SpecSlot2, тир, стрелы и рокакаки |
| **Stand Farm** | луп роллов, вайтлисты стендов и атрибутов, авто-покупка, вебхук |
| **Items** | предметы в мире, точки спавна, авто-подбор, TP к спавнам |
| **Item Farm** | Instant / Legit / Start |
| **Teleports** | 14 именованных локаций + 3 Dark Entrance + 41 NPC |
| **Boss Farm** | 8 пресетов боссов + кастомный таргет |
| **Quest Farm** | NPC, gap, QuestDone/Done |
| **Lair Farm** | таргет, паузы, `LairStart` / `LairClear` |
| **Farm Settings** | Refresh Movesets, Use Custom Moves, список тяжёлых клавиш |
| **Player** | Speed, Jump, Fly (WASD), Noclip |
| **LocalPlayer** | Open Stand Storage, Anti AFK, Auto Umbrella, Reset |
| **Visuals** | ESP на игроков/мобов и NPC |
| **Fake** | фейк-стенд, атрибут, статы, `/check` |
| **Diagnostics** | проверка ремоутов, персонажа, мира |

---

## Боевая система

Игра перешла на единый ввод. Проверено декомпиляцией `StandInput` и живьём:

```lua
StandEvents.Input:FireServer({
    State = "Begin",                     -- затем "End"
    Key   = Enum.KeyCode.Q,
    Type  = Enum.UserInputType.Keyboard
})
```

Список разрешённых клавиш отдаёт сама игра:

```lua
local moveset = StandEvents.Info:InvokeServer("Moveset")
```

Снятая карта для `SPTW_R`:

| Клавиша | Мув | Кулдаун |
|---|---|---|
| M1 | Punch | 0.35 |
| M2 | — | — |
| Q | Summon | 1.5 |
| E | Barrage | 7 |
| R | Heavy Punch | 8 |
| F | — | — |
| T | Bearing Shots | 8 |
| Y | **Timestop** | — (акк приходит, числа нет) |
| H | Timeskip | 6 |
| X | Counter | 8 |
| Z | — | — |
| G | Block | 1 |
| J | — | — |
| N | Quote | 0.5 |

Пустые ячейки (M2/F/Z/J) — мув не назначен на этом стенде.

### Проверка действий

Сервер сам подтверждает принятый мув:

```lua
ReplicatedStorage.Events.CoolDownGUI.OnClientEvent:Connect(function(moveName, cooldown)
    -- "Punch", 0.35
end)
```

Скрипт использует это как критерий PASS в аудите: не «не упало», а
«сервер ответил». Но акк присылают **не все** мувы — только M1, Q, E, R, H, Y, G, N.
У X, T, Z, F, J акка нет, поэтому для них PASS — успешный `press()`.

---

## Fake — подмена профиля

Всё, что печатает карточка `/check`, читается из объектов, которые клиент
уже держит у себя:

```lua
Player.Data.Stand / .Attri / .GUID
Character.Stats.AttackDmg
Character.DmgBoostAttri
Humanoid.MaxHealth
ReplicatedStorage.StandNameConvert[code].Value   -- pretty-имя
```

Меню **Fake** подменяет эти пять полей и держит их циклом `0.2s`, чтобы сервер
не откатил. OFF — восстанавливает снапшот. Кнопка **Print what /check will show**
печатает точную реконструкцию карточки.

**Fake stand model** клонирует модель стенда из `Workspace.Living.<ник>.Stand`,
глушит скрипты, якорит парты, ставит рядом с HRP и каждый тик держит через
`PivotTo` — стенд стоит и едет за игроком.

> [!NOTE]
> Подмена локальная: `/check` на своём клиенте показывает фейк, у других
> игроков остаются серверные значения.

---

## Аудит

Кнопка **Home → Run Full Audit (x20)** или извне через `getgenv().ArcticAPI`.

Каждая функция прогоняется 20 раз, между итерациями выдерживается реальный
кулдаун мува. Полная таблица — в [`docs/AUDIT.md`](docs/AUDIT.md).

Коротко:

| Блок | Результат |
|---|---|
| `Q` Summon, `G` Block, `N` Quote | 20/20 |
| `E` Barrage, `R` Heavy Punch | 19/20 (один сетевой таймаут) |
| `M1` Punch | 17/20 — лимит комбо, не баг |
| `X`, `Z`, `F`, `J` (press-only) | 20/20 |
| данные, NPC, телепорты, ESP, speed/jump/fly/noclip | 20/20 |

---

## Структура репозитория

```
SUR_Arctic_v2.lua     готовый однофайловый билд (это и запускать)
lib/ArcticLib.lua     библиотека отдельно, если нужна сама по себе
src/lib.lua           оригинальная библиотека (как была)
src/lib_fixed.lua     она же, но с API на file scope (см. ниже)
src/main.lua          логика скрипта
src/build.py          сборка lib_fixed + main -> SUR_Arctic_v2.lua
src/fix_lib.py        патч библиотеки
tools/sur_agent.lua   мост в игру (для отладки через файлы)
tools/sur_agent.py    драйвер моста
tools/snippets/       разовые запросы к игре
docs/FINDINGS.md      что вскрыто в игре и как
docs/AUDIT.md         результаты прогонов
```

---

## Почему пришлось править библиотеку

В исходной `Lib.txt` **вся публичная API лежала внутри `Start()`**:

```lua
function Start(A, B)
    ...
    function CreateMenu(Name) ... end   -- локальная для Start!
    function CreateButton(...) ... end
end
```

Снаружи `CreateMenu` был `nil`. Именно поэтому старые скрипты падали с
`attempt to call a nil value` сразу после `Start()`. `src/fix_lib.py`
выносит API на file scope, а `Start()` просто заполняет `ScreenGui`/`Menus`.

---

## Сборка

```bash
python src/fix_lib.py     # lib.lua -> lib_fixed.lua
python src/build.py       # lib_fixed + main -> SUR_Arctic_v2.lua
```

---

## Отладка через мост

Если нужно посмотреть игру изнутри:

```bash
python tools/sur_agent.py install     # кладёт агент в autoexec executor'а
python tools/sur_agent.py status      # жив ли, какой place/job
python tools/sur_agent.py probe       # стенд, статы, бэкпак
python tools/sur_agent.py scan ReplicatedStorage 3
python tools/sur_agent.py exec "return game.PlaceId"
python tools/sur_agent.py exec -f tools/snippets/recon1.lua --timeout 300
```

Канал: `workspace/sur_cmd.json` → игра → `workspace/sur_res.json`.

---

## API наружу

`getgenv().ArcticAPI` — всё управляемое извне:

```
press moveset standName standAttri fire invoke fireNPC npcRemote allNPCs
tpToNPC tpToPosition worldTools itemSpawns useTool audit ack ackReset ackWait
mods esp refreshESP clearESP setSpeed setJump startFly stopFly startNoclip stopNoclip
fake fakeStart fakeStop fakeApply fakeStandSpawn fakeStandClear
standCatalog standPretty attriCatalog dataValue statsFolder
farm farmStart farmStop farmStep landmarks
```
