# Overwatch

A scriptable notification engine for the [Recoil Engine](https://recoilengine.org/).

[2025-11-11-preview.webm](https://github.com/user-attachments/assets/df685b5c-7513-41bd-82bb-760f577181b6)

## Features

- Rules for game events, resources, and unit builds
- Does console, uilog (panel), sound, ping, command (/say a:) and marquee messages

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

## Authors

- Fast

## License

GNU GPL, v2 or later
