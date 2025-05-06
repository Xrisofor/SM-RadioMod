## Custom Radio (Radio Mod)
**Custom Radio** — это мод для [Scrap Mechanic](https://store.steampowered.com/app/387990/Scrap_Mechanic/), который добавляет радиоприемники, способные воспроизводить как встроенную, так и пользовательскую музыку — без замены файлов игры.

## Как это работает?
* Установите необходимые зависимости:
  * [SM-DLL-Injector](https://github.com/QuestionableM/SM-DLL-Injector/releases/)
  * [SM-CustomAudioExtension](https://github.com/QuestionableM/SM-CustomAudioExtension/releases/)
* Активируйте мод и [Mod Database](https://steamcommunity.com/workshop/filedetails/?id=2504530003) в игровом мире.

## Какие объекты включены?
* Custom Radio
* Mini Custom Radio
* Portable Radio
* Radio Speaker
* Radio Remote Control
* Device Timer *(only works in worlds where time flows)*

## Почему стоит выбрать Custom Radio?
* **Без замены файлов** — Не нужно перезапускать игру или заменять ``.bank`` файлы.
* **Высокая совместимость** — Минимальные конфликты с другими модами, даже если они используют собственные звуки.
* **Удобство** — Управление музыкой через понятные игровые устройства.

## Какие треки включены?
Бета-версия мода включает следующие плейлисты:
* Scrap Mechanic - Radio
* Scrap Mechanic - Elevator Music
* Scrap Mechanic - North Korea
* [Phonk Radio - Radio Mod](https://en.wikipedia.org/wiki/Phonk)
* [Russian Hardbass Radio - E (RU)](https://steamcommunity.com/sharedfiles/filedetails/?id=2476541477)
* [Neon Genesis Evangelion - Shiro SAGISU](https://en.wikipedia.org/wiki/Neon_Genesis_Evangelion)
* [Compilation #1 - Korol i Shut (RU)](https://en.wikipedia.org/wiki/Korol_i_Shut)

## Хотите добавить свою музыку?
Вы можете настроить радио для воспроизведения собственных треков двумя способами:

### Вариант 1 — Ручная настройка
Следуйте [инструкции в Wiki](https://github.com/Xrisofor/SM-RadioMod/wiki/How-to-Use-Custom-Radio) для настройки ``sm_cae_config.json`` и ``custom_effects.json``.

### Вариант 2 — Custom Radio Manager
Используйте программу [Custom Radio Manager](https://drive.google.com/file/d/1ndqaF3vAaxhKE7nunuXn1MYdKF-Y13Tn/view) для:
* Автоматической настройки
* Загрузки необходимых расширений
> ⚠️ Требуется [Microsoft .NET Framework 4.7.2](https://dotnet.microsoft.com/ru-ru/download/dotnet-framework/net472).

> ⚠️ ВАЖНО:
> Если вы используете собственный мод с Custom Radio, он должен быть **опубликован и включен в мире.**
> В противном случае, [Mod Database](https://steamcommunity.com/workshop/filedetails/?id=2504530003) **не сможет его обнаружить и загрузить.**

## Редактирование основного мода
Вы можете вручную изменить файлы основного мода. Однако:
> ❗ Любое **обновление или переустановка мода** могут **удалить ваши изменения.**
Рекомендуется создать **отдельный мод**, совместимый с Custom Radio, для долговременного использования.

## Планы на будущее
* Больше музыкальных плейлистов
* Новые устройства
* Исправление ошибок и улучшения
