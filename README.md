# Arctic SUR

Скрипт для **Stand Upright: Rebooted** (place `8540168650`).

> [!IMPORTANT]
> **Главный файл — [`SUR_Message.lua`](SUR_Message.lua).**
> Это исходный `message.txt` (тот самый Arctic с Discord-ссылкой и Polarrr#1912),
> переведённый на текущий протокол игры. Меню и кнопки не менялись — починена
> только начинка. Полная таблица правок: [`docs/MESSAGE_FIXES.md`](docs/MESSAGE_FIXES.md).

---

## Быстрый старт

1. Открой Roblox → Stand Upright.
2. Инжектни executor (Xeno / Solara).
3. Вставь содержимое [`SUR_Message.lua`](SUR_Message.lua) и запусти.
4. Меню — по клавише **J**. Перетаскивание — за шапку.

Один файл, библиотека внутри, никаких `loadstring(HttpGet(...))` — интернет
для запуска не нужен (старая ссылка на `icebear.lol` мертва).

---

## Меню (как в message.txt, один в один)

| Меню | Что внутри |
|---|---|
| **Home** | Discord / контакт автора |
| **LocalPlayer** | Open Stand Storage, стрелы, рокакаки, Auto Umbrella, Anti AFK |
| **Shops** | Auto Sell Ketchup, Count, покупка 6 предметов на бирже |
| **Farm Settings** | Refresh Movesets (реальные клавиши мувсета), Use Custom Moves |
| **Boss Farm** | Distance, Underneath, три босса: Jotaro Over Heaven / Johnny Joestar / Jotaro Part 4 |
| **Lair Farm** | Select Lair NPC, Distance, Underneath, Pause, **Instant Boss Kill (HP = 0)** |
| **Quest Farm** | Select Quest NPC, Select NPC, Only Farm NPC, Distance, Underneath |
| **Item Farm** | Instant / Legit, Start Farming |
| **Teleports** | TP to player, TP above, 14 локаций, все NPC по именам из игры |
| **Stand Farm** | Search, Stand/Attribute/Split check, выбор стрел, автопокупка, вебхук, списки стендов и атрибутов |

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

Старые `StandEvents.Summon` / `StandEvents.M1` / `StandEvents.<MoveName>`
**удалены из игры** — именно поэтому message.txt не наносил ни одного удара.

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
| Y | **Timestop** | — |
| H | Timeskip | 6 |
| X | Counter | 8 |
| Z | — | — |
| G | Block | 1 |
| J | — | — |
| N | Quote | 0.5 |

Пустые ячейки (M2/F/Z/J) — мув не назначен на этом стенде.

---

## Уязвимость: мгновенная смерть лейр-босса

```lua
Workspace.Living.Boss.Humanoid.Health = 0
```

Клиент пишет Health напрямую, сервер принимает репликацию → босс умирает
мгновенно, без боя. В `message.txt` строка стояла безусловно; в порте она
вынесена в `killTarget()` (с `pcall` и фолбэком) и закрыта тогглом
**Instant Boss Kill (HP = 0)** в меню Lair Farm — по умолчанию включён.

---

## Отличия от `message.txt`

Полный разбор — [`docs/MESSAGE_FIXES.md`](docs/MESSAGE_FIXES.md). Коротко:

* библиотека встроена (старый CDN мёртв);
* боевая часть переведена на `StandEvents.Input` — фармы снова бьют;
* убраны захардкоженный ник `polar_eXDAVH`, чтение мёртвых `CDgui` / `MoveCD` / `Aura`;
* починены опечатки `UseArrow` / `UseChargedArrow`, из-за которых автопокупка
  стрел не срабатывала никогда;
* все бесконечные `repeat ... until` получили таймауты;
* циклы фармов вынесены из колбэков в `task.spawn`;
* подписи-статусы ищутся по префиксу, а не по точному имени;
* три копии одного цикла Boss Farm свёрнуты в одну функцию.

Добавлен ровно один элемент — тоггл **Instant Boss Kill (HP = 0)**.

---

## Структура репозитория

```
SUR_Message.lua          ← ГЛАВНЫЙ ФАЙЛ (запускать этот)
SUR_Message.txt          он же, для копипаста
src/message_main.lua     логика порта (message.txt)
src/build_message.py     сборка lib_fixed + message_main
src/lib_fixed.lua        библиотека Arctic с API на file scope
src/fix_lib.py           патч библиотеки
tools/lua_syntax.py      реальная проверка синтаксиса (lupa / Lua VM)
tools/luacheck_rough.py  быстрая проверка баланса блоков
tools/mock_roblox.lua    фейковый Roblox для офлайн-прогона
tools/mock_check.py      прогон скрипта в фейковом Roblox
docs/MESSAGE_FIXES.md    таблица правок message.txt
docs/AUDIT.md            результаты прогонов по 20 раз
docs/FINDINGS.md         что вскрыто в игре и как

SUR_Arctic_v2.lua        отдельная, более новая сборка (другое меню)
```

---

## Почему пришлось править библиотеку

В исходной `Lib.txt` **вся публичная API лежала внутри `Start()`**:

```lua
function Start(A, B)
    ...
    function CreateMenu(Name) ... end   -- локальная для Start!
end
```

Снаружи `CreateMenu` был `nil`. Именно поэтому старые скрипты падали с
`attempt to call a nil value` сразу после `Start()`. `src/fix_lib.py` выносит
API на file scope, а `Start()` просто заполняет `ScreenGui` / `Menus`.
Дополнительно: сайдбар получил `AutomaticCanvasSize` — иначе меню после
десятого были недоступны, — и тёмную тему с фиолетовым акцентом.

---

## Сборка

```bash
python src/build_message.py                      # SUR_Message.lua
python tools/lua_syntax.py SUR_Message.lua       # реальный парсер
python tools/luacheck_rough.py SUR_Message.lua   # баланс блоков
python tools/mock_check.py SUR_Message.lua       # прогон в фейковом Roblox
```

Мок-прогон поднимает фейковый Workspace/ReplicatedStorage/игрока, грузит скрипт
целиком, строит всё меню и прожаёт **все 107 обработчиков** (кнопки, тогглы
дважды, поля ввода). Ловит опечатки и nil-индексацию в UI-слое без запуска игры.

