# SM-RadioMod (Custom Radio) / EN

![Mod Preview](https://github.com/Xrisofor/SM-RadioMod/blob/main/preview.jpg?raw=true)

**Custom Radio** - the same familiar in-game radio, but now with support for your own custom tracks. Listen to your favorite music anywhere, any way you want!

> **Important:** This mod is currently in **Beta**. Some features are still being worked on and may behave unpredictably. Bug reports are highly appreciated!

# Installation

- Download and install the required extensions:
  - [SM-DLL-Injector](https://github.com/QuestionableM/SM-DLL-Injector/#how-to-install)
  - [SM-CustomAudioExtension](https://github.com/QuestionableM/SM-CustomAudioExtension#how-to-download-and-enable)
- Enable **Custom Radio** in your world settings.

A detailed installation guide is available in the [README on GitHub](https://github.com/Xrisofor/SM-RadioMod/blob/main/README.md).

# Mod Contents

- **Custom Radio** - your personal media center that plays both vanilla tracks and your own custom audio files.
- **Mini Custom Radio** - a smaller version of the receiver that retains full functionality, but easily fits into the cabin of any vehicle.
- **Portable Radio** - a mobile device that lets you listen to music on the go.
- **Radio Speaker** - an auxiliary speaker to broadcast audio to remote parts of your builds or vehicles.
- **Radio Remote Control** - a tool for remotely switching tracks on a linked radio receiver.
- **Antenna** - connects to a radio receiver and broadcasts the currently playing music to a specific frequency.

# Mod Features

- **Clean Audio Integration** - music is played without replacing any vanilla Scrap Mechanic files, powered by the *SM-CustomAudioExtension* (CAE).
- **Script Control via [SComputers](https://steamcommunity.com/sharedfiles/filedetails/?id=2949350596)** - the radio supports a full API. You can write in-game Lua scripts to automate play/stop functions, switch tracks, and read the receiver's current state.
- **Survival Mode Support** - thanks to integration with [Modded Craftbot Recipes](https://steamcommunity.com/sharedfiles/filedetails/?id=2816900681), all mod components (receivers, speakers, remotes, antennas) can be crafted.
- **Custom Music Pack Support** - expand your library with ready-made music packs from other creators without conflicts or manual config file editing.
- **Wireless FM Network** - tune antennas and radio receivers to any of the 256 frequencies (0–255) to broadcast music wirelessly between your builds and vehicles.
- **Multi-Speaker Systems (Multiroom)** - connect up to 15 external speakers to a single radio. They will synchronously replicate the audio, adjusting to volume and speed (pitch) changes from the main device.
- **Full Playback Control** - a user-friendly GUI with volume control, speed adjustment (pitch), shuffle, and three repeat modes.
- **Logic System Integration** - besides computers, the radio supports standard control via triggers, sensors, buttons, timers, and driver seats.

# Adding Custom Music

Want to listen to your own tracks in-game? You can easily package them into an independent add-on. A simple and straightforward API lets you register your audio files and playlists in just a few lines of code.

A detailed, step-by-step guide with ready-to-use code examples is published on the [official project Wiki on GitHub](https://github.com/Xrisofor/SM-RadioMod/wiki).

> Please note: for your tracks to appear on the radio receivers, your custom music add-on must be enabled in the mod list of your game world.
