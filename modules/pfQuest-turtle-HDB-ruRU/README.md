# pfQuest-turtle-HDB-ruRU 0.1.0

Optional Russian language pack for **pfQuest + pfQuest-turtle HDB 0.2.0-beta.4** on English 1.12 clients. Non-HDB compatibility is planned but is not supported by this release.

## Install

1. Install the matching pfQuest Turtle HDB package and its required HearthDB DLL first.
2. Extract `pfQuest-turtle-HDB-ruRU/` into `Interface/AddOns/`, beside `pfQuest/` and `pfQuest-turtle/`.
3. Fully restart the client and enable the language pack in the addon list.
4. Open the quest log and choose **Russian** from pfQuest's Translate dropdown. English remains the default. Reset Language returns to English.

## Что переводится

Выберите **Russian** в меню перевода журнала заданий. Модуль переводит доступные тексты заданий, интерфейс настроек, трекер, браузер базы данных, журнал выполненных заданий, начальный экран и подсказки pfQuest. Для возврата к английскому выберите сброс языка.

Названия и идентификаторы, используемые для поиска, сопоставления целей и подсчёта прогресса, остаются английскими. Поиск в браузере этой версии выполняется по английским названиям. Если перевод отсутствует или неоднозначен, отображается английский текст.

## Coverage and limits

- Uses the existing base and Turtle Russian quest translations, plus NPC, object, item, zone and profession display aliases and supplementary UI labels.
- Translates pfQuest-owned quest-log, settings, tracker, browser, map/minimap menu, journal, welcome and loot-panel displays. Quest IDs, hyperlinks and progress counts remain intact.
- Native world names, chat and other addons are not translated. Client-generated item stats, spell/recipe descriptions and historical changelog prose can remain English.
- Existing translations can contain incomplete, outdated or mixed-language passages. Unknown or ambiguous text falls back to English. Please report remaining gaps with the quest/item/NPC ID and a screenshot.
- This is an optional Lua text/display pack; it does not duplicate or replace the HearthDB world database. The main HDB package remains English-only.

## Credits and license

Translation datasets and UI strings derive from pfQuest and pfQuest-turtle contributors. Supplementary translations and integration: Rivi. Distributed under the included MIT license. Development inspection commands are not included.
