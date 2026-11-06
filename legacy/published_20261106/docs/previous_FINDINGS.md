# Что вскрыто в игре

Place `8540168650`, аккаунт `FrigoCamelo1502`, стенд `SPTW_R`, атрибут `Godly`,
тир `A+`, уровень 213.

Метод: executor → `decompile` клиентских скриптов + чтение живого дерева.
Никаких догадок.

---

## 1. Боевая система переехала

Старые скрипты дёргали `StandEvents.Summon`, `StandEvents.M1`,
`StandEvents.Barrage`. **Этих ремоутов больше нет.**

У персонажа сейчас ровно два:

```
Workspace.Living.<ник>.StandEvents.Input   → RemoteEvent
Workspace.Living.<ник>.StandEvents.Info    → RemoteFunction
```

Протокол, снятый из декомпилированного `StandInput`:

```lua
StandEvents.Input:FireServer({
    State = "Begin",                     -- или "End"
    Key   = Enum.KeyCode.Q,
    Type  = Enum.UserInputType.Keyboard
})
```

Клиент перед отправкой фильтрует клавиши через
`table.find(Moveset, key)`, список отдаёт сервер:

```lua
local moveset = StandEvents.Info:InvokeServer("Moveset")
```

---

## 2. Подтверждение от сервера

```lua
ReplicatedStorage.Events.CoolDownGUI.OnClientEvent:Connect(function(moveName, cooldown)
    -- "Punch", 0.35
end)
```

Это единственный честный способ проверить, что мув реально принят.

Но акк присылают **не все** мувы. Замер по всем 14 клавишам:

| Акк приходит | Мувы |
|---|---|
| да | `Punch`, `Summon`, `Barrage`, `Heavy Punch`, `Timeskip`, `Timestop`, `Block`, `Quote` |
| нет | `Counter` (X), `Bearing Shots` (T), `Z`, `F`, `J` |

При этом `press()` у них проходит: `press=true, err=nil, ack=nil`.
Значит критерий PASS надо делить: где акк есть — ждём акк, где нет — `press()==true`.


---

## 3. NPC

68 NPC, у каждого `Done:RemoteEvent`, у многих `QuestDone:RemoteEvent`,
и `Talk:ProximityPrompt`.

```lua
Workspace.Map.NPCs.<Имя>.Done:FireServer()
Workspace.Map.NPCs.<Имя>.QuestDone:FireServer()
```

| NPC | Ремоуты |
|---|---|
| `admpn` | Done — Stand Storage |
| `Merchant120`, `Merchant500`, `MerchantAU`, `Merchant1st` | Done, QuestDone |
| `CandyMerchant` | Done, QuestDone |
| `Giorno`, `Giorno2`, `DIO`, `Diavolo`, `Funny Valentine` | Done, QuestDone |
| `Koichi`, `Josuke`, `Okayasu`, `Rohan`, `Kirito` | Done, QuestDone |
| `TidesQuest`, `aLLmemester`, `Scared Noob`, `SWAT` | Done, QuestDone |
| `BobBallin`, `Jonathan Joestar` | **Interacted** (не Done) |
| `StockMarket`, `Qtaro Cujoh`, `Sports Maxx`, `TowhOH`, `Bum NPC` | без ремоутов |

---

## 4. Экономика

```lua
Events.BuyItem:FireServer("MerchantAU", "Option2")
Events.SellKetchup:FireServer("One")            -- или "Lots"
Events.buyGyroHorseSpin:FireServer("Spin")      -- или "Horse"
Events.GetStandTier:InvokeServer("SPTW_R")
Events.SwitchStand:FireServer("Slot1")          -- Slot1..Slot5, "SpecSlot2"
```

> [!WARNING]
> В старой `message.txt` был `"Merchantlvl120"`, а живой NPC называется
> `Merchant120`. Опечатка = мёртвая кнопка. Такие ловились по всей кодовой базе.

---

## 5. Предметы

Два разных слоя, их легко спутать:

| Слой | Где | Когда есть |
|---|---|---|
| Сам предмет (`Tool`) | `Workspace.Items`, `Workspace.Vfx` | только пока заспавнен |
| Точка спавна | `Workspace.ItemPromptHolder` (`Part` + `ProximityPrompt`) | всегда, 30–35 штук |

`Workspace.Items` на клиенте чаще всего **пустой** — сервер не держит предметы
в мире постоянно. Поэтому «список предметов» = 0 это норма, а не поломка.
Стабильно читаются только `ItemPromptHolder`:

```
ProximityPrompt.ActionText   = "Pick Up?"
ProximityPrompt.ObjectText   = "Item"
ProximityPrompt.HoldDuration = 0.5
ProximityPrompt.MaxActivationDistance = 16
```

Проверено и **не работает** с клиента:

- `prompt:InputHoldBegin()` + `InputHoldEnd()` → `ok=true`, но подбора нет
  (сервер валидирует ввод).
- `firetouchinterest(hrp, holder, 0/1)` → `ok=true`, подбора нет
  (у `ItemPromptHolder` нет детей-TouchPart).

Рабочий путь — только реальный подбор в игре, дальше через бэкпак:

```lua
Humanoid:EquipTool(Backpack["Stand Arrow"])
Character["Stand Arrow"].Use:FireServer()
Events.UseItem:FireServer("Stand Arrow")
```

Работает для: `Stand Arrow`, `Charged Arrow`, `Requiem Arrow`,
`Rokakaka`, `Rotten Rokakaka`, `New Rokakaka`, `Kars Mask`, `Dio's Diary`,
`Green Baby`, `Ketchup`.


---

## 6. Служебные ремоуты

| Ремоут | Класс | Что |
|---|---|---|
| `CoolDownGUI` | RemoteEvent | подтверждение мува |
| `LairStart` / `LairClear` | RemoteEvent | лейр |
| `UseItem` | RemoteEvent | использование предмета |
| `SummonPacket` | RemoteEvent | пакет призыва |
| `TradeEvents.TradeComm` | RemoteEvent | трейд |
| `Client.Item_Index` | RemoteEvent | индексация предметов |
| `CheckCMD` | RemoteEvent | карточка игрока в чате (не админка) |
| `Request` | RemoteFunction | универсальный запрос |
| `Proxy` | RemoteFunction | обёртка |

Всего в `ReplicatedStorage.Events` — 108 ремоутов.

---

## 7. Ловушки, на которых падали прошлые версии

1. **`StandEvents.Summon` больше нет.** Все боевые кнопки старых скриптов были мёртвые.
2. **`Merchantlvl120` вместо `Merchant120`.** Магазин не открывался.
3. **Вся API библиотеки лежала внутри `Start()`.** Снаружи `CreateMenu` был `nil`,
   скрипт падал на первой же кнопке.
4. **`loadstring(HttpGet("icebear.lol/..."))`** — библиотека тянулась с чужого
   сервера. Умрёт хост — умрёт скрипт. Теперь библиотека внутри файла.
5. **`pcall` вокруг всего** глотал ошибки: сканер возвращал пустые массивы,
   и это выглядело как «в игре ничего нет».
