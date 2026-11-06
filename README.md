# SUR — исходное меню, одна текущая сборка

Built by Olivia — https://discord.gg/ojailbreaks

Порт для **Stand Upright: Rebooted**, place `8540168650`. Основа — прежнее меню Arctic: десять исходных разделов сохранены, Fake и Auto Kill добавлены по запросу. Это не новая компоновка интерфейса.

## Текущий файл

[SUR_Message.lua](file:///C:/budka/SUR/SUR_Message.lua) — самостоятельная сборка со встроенной библиотекой. [SUR_Message.txt](file:///C:/budka/SUR/SUR_Message.txt) содержит те же байты для удобного копирования; это не другая версия.

- **L** — скрыть/показать окно, кроме ввода в текстовое поле.
- **Свернуть** — только скрыть окно, функции продолжаются.
- **X** — выгрузить функции, обработчики, удержания ввода и GUI.
- Повторный запуск сначала выгружает предыдущую копию.

Roblox и Xeno открываются пользователем. Сборщик не запускает процессы и не выполняет скрипт.

## Лейр и точная цель

**Lair Farm:** выбери соседнего провайдера через `Select Lair NPC`, затем `Begin Lair Farm`. Фарм рассматривает только живую прямую модель `Boss` в текущей области; мировых боссов по похожим именам не подбирает. `Underneath` смещает позицию в локальных координатах цели. Если Boss исчезает или выходит из области, дальняя цель не подменяется.

**Auto Kill:** `Select target (click boss)` → клик непосредственно по NPC → `Auto Kill Selected`. Промах, игрок или отмена не выбирают ближайшую постороннюю модель. Используется именно выбранный экземпляр, не другой NPC с тем же именем. Телепорт должен завершиться перед локальной попыткой HP=0.

**Fake:** подмена собственного локального профиля и предпросмотр модели. Она не создаёт серверный стенд, не увеличивает серверный урон и не гарантирует изменение чужой карточки `/check`.

> [!NOTE]
> Проверки с mock подтверждают только моделируемое клиентское поведение. Серверное убийство, награда, успешный спавн лейра и отсутствие кика не следуют из локального HP=0 или успешного вызова ремоута. Текущая проверка не запускает Roblox.

## Сборка и проверки

Нужны Python и `lupa`. Команды выполняются из корня проекта.

```powershell
python -m pip install -r requirements-dev.txt
python -B src/build_message.py
python -B tools/lua_syntax.py SUR_Message.lua src/lib_fixed.lua src/message_main.lua src/fake_autokill_block.lua
python -B tools/luacheck_rough.py SUR_Message.lua
python -B tools/mock_runtime_check.py
python -B tools/mock_check.py SUR_Message.lua
python -B tools/boss_target.py SUR_Message.lua
python -B tools/regression_check.py SUR_Message.lua
python -B tools/build_check.py
```

Итоговый offline-прогон: **60 сценариев — 60 passed / 0 failed**, 140 обработчиков интерфейса, 3 проверки выбора Boss и самопроверка детерминированного mock. После выгрузки в моделируемом окружении нет живых задач, подписок, ошибок или предупреждений. Подробности — в [MESSAGE_FIXES.md](file:///C:/budka/SUR/docs/MESSAGE_FIXES.md).

Обычная сборка не меняет вкладку Xeno. Явное обновление сохранённой вкладки, без запуска:

```powershell
python -B src/build_message.py --install-xeno
```

[build_message.py](file:///C:/budka/SUR/src/build_message.py) соединяет [lib_fixed.lua](file:///C:/budka/SUR/src/lib_fixed.lua), [message_main.lua](file:///C:/budka/SUR/src/message_main.lua) и [fake_autokill_block.lua](file:///C:/budka/SUR/src/fake_autokill_block.lua). Синтаксис проверяется до перезаписи готовых файлов; сохранение — UTF-8 без BOM. Основной исходник с маркерами не предназначен для отдельного запуска.

## Архив

Старые сборки, мосты, исходники и прежняя документация лежат в [legacy](file:///C:/budka/SUR/legacy), не участвуют в текущей сборке и сохраняются с манифестом прежних путей/SHA-256. Локальный архив полнее публичного: в репозиторий попадают только прежние уже опубликованные файлы. Резервные копии вкладок Xeno, дампы и приватные рабочие каталоги не публикуются.

Актуальные изменения и границы проверки — в [MESSAGE_FIXES.md](file:///C:/budka/SUR/docs/MESSAGE_FIXES.md). [AUDIT.md](file:///C:/budka/SUR/docs/AUDIT.md) и [FINDINGS.md](file:///C:/budka/SUR/docs/FINDINGS.md) сохраняют исторические наблюдения, а не результат текущего запуска.
