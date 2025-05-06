## Custom Radio (Radio Mod)
**Custom Radio** is a mod for [Scrap Mechanic](https://store.steampowered.com/app/387990/Scrap_Mechanic/) that adds radios capable of playing both built-in and user-added music — all without replacing core game files.

## How does it work?
* Install the required dependencies:
  * [SM-DLL-Injector](https://github.com/QuestionableM/SM-DLL-Injector/releases/)
  * [SM-CustomAudioExtension](https://github.com/QuestionableM/SM-CustomAudioExtension/releases/)
* Enable the mod and [Mod Database](https://steamcommunity.com/workshop/filedetails/?id=2504530003) in your game world.

## What objects are included?
* Custom Radio
* Mini Custom Radio
* Portable Radio
* Radio Speaker
* Radio Remote Control
* Device Timer *(only works in worlds where time flows)*

## Why use Custom Radio?
* **No file replacement** — You don’t need to restart the game or replace ``.bank`` files.
* **High compatibility** — Minimal conflicts with other mods, even those using their own sounds.
* **Ease of use** — Control music with intuitive in-game devices.

## Included tracks
This beta version includes the following playlists:
* Scrap Mechanic - Radio
* Scrap Mechanic - Elevator Music
* Scrap Mechanic - North Korea
* [Phonk Radio - Radio Mod](https://en.wikipedia.org/wiki/Phonk)
* [Russian Hardbass Radio - E (RU)](https://steamcommunity.com/sharedfiles/filedetails/?id=2476541477)
* [Neon Genesis Evangelion - Shiro SAGISU](https://en.wikipedia.org/wiki/Neon_Genesis_Evangelion)
* [Compilation #1 - Korol i Shut (RU)](https://en.wikipedia.org/wiki/Korol_i_Shut)

## Want to add your own music?
You can customize the radio to play your own tracks in two ways:

### Option 1 — Manual setup
Follow [the wiki guide](https://github.com/Xrisofor/SM-RadioMod/wiki/How-to-Use-Custom-Radio) to configure ``sm_cae_config.json`` and ``custom_effects.json``.

### Option 2 — Custom Radio Manager
Use the [Custom Radio Manager](https://drive.google.com/file/d/1ndqaF3vAaxhKE7nunuXn1MYdKF-Y13Tn/view) app to:
* Automate setup
* Install required extensions
> ⚠️ Requires [Microsoft .NET Framework 4.7.2](https://dotnet.microsoft.com/ru-ru/download/dotnet-framework/net472).

> ⚠️ IMPORTANT:
> If you're using your own mod with Custom Radio, it must be published and enabled in the game.
> Otherwise, [Mod Database](https://steamcommunity.com/workshop/filedetails/?id=2504530003) will not detect or load your mod.

## Editing the Main Mod
You can manually modify the main mod files. However:
> ❗ Any **mod update or reinstallation** may **overwrite your changes**.
For long-term use, it's recommended to create your own **separate mod** that works with Custom Radio.

## Future Plans
* More music playlists
* Additional radio devices
* General bug fixes and improvements
