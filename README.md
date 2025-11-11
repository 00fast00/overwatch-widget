# Overwatch

A scriptable notification engine for the [Recoil Engine](https://recoilengine.org/).

[2025-11-11-preview.webm](https://github.com/user-attachments/assets/df685b5c-7513-41bd-82bb-760f577181b6)

## Features

- Run's as spec or any custom widget enabled lobby
- Rules for game events, resources, and unit builds
- Does console, uilog (panel), sound, ping, command (/say a:) and marquee messages
- Should work with any game/mod that runs with the `Recoil Engine` but that's untested.

## State

The widget has been tested a lot, still needs more testing before beeing published on Discord Widgets.
For development news see the Github issues.

## TL;DR

Overwatch combines [Blueprints](https://github.com/00fast00/overwatch-widget/tree/main/doc/developer#blueprint) (lua logic) with `Configs` and routes the results to [Channels](https://github.com/00fast00/overwatch-widget/tree/main/doc/developer#channel).

Examples:

- Blueprints: https://github.com/00fast00/overwatch-widget/blob/main/lua/builtin_blueprints/units.lua
- Config: https://github.com/00fast00/overwatch-widget/blob/main/configs/OverwatchConfig.20builtin.lua

## Installation & Setup

1. Copy [dist/overwatch.lua](dist/overwatch.lua) into your `LuaUI/Widgets/` directory
2. In Skirmish mode / a widget enabled lobby / spectator mode you can enable the widget in `Settings` -> `Custom`.

## Usage

- Press `Alt+p` to toggle the log and settings panel
- Configure rules and notifications in the settings panel

## Configuration

Configuration files are stored in `LuaUI/Config/`:

- `OverwatchConfig.lua` - Config auto-generated if not present
- `OverwatchBlueprints*.lua` - Custom blueprints

## Creating Custom Blueprints

You can create custom blueprints by adding them to `LuaUI/Config/OverwatchBlueprints*.lua`.  
See the example files in [blueprints](blueprints/) or [lua/builtin_blueprints/](lua/builtin_blueprints/) for details.

We have an extra [doc/developer/readme.md](doc/developer/readme.md) for developers.

## Credits

### Authors

- Fast

### Others

- [BAR contributers](https://github.com/beyond-all-reason/Beyond-All-Reason/graphs/contributors) : We reuse various parts here or look at that code for inspiration.
- [@goldjee](https://github.com/goldjee) : Initial inspiration for using RmlUI and parts from https://github.com/goldjee/BAR-Widgets/tree/main/raptor-panel

## License

GNU GPL, v2 or later
