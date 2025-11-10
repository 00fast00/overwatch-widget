# Overwatch

> _WARNING_: This is in development, it does not much at the moment.

A configurable/scriptable monitoring and notification engine for [Recoil Engine](https://recoilengine.org/).

## Features

- Rules for game events, resources, and unit builds
- Provides configurable alerts for economy, defenses, and critical milestones
- Shows notification stats and rule configuration
- Supports all kinds of game modes with special support for BAR Raptors and Scavengers.

## Installation & Setup

1. Copy [dist/gui_overwatch.lua](dist/gui_overwatch.lua) into your LuaUI/Widgets/ directory
2. In Skirmish mode / a widget enabled lobby / spectator mode you can enable the widget in `Settings` -> `Custom`.

## Usage

- Press `Alt+p` to toggle the log and settings panel
- Configure rules and notifications in the settings panel

## Configuration

Configuration files are stored in `LuaUI/Config/`:

- `OverwatchConfig.lua` - Config auto-generated if not present
- `OverwatchBlueprints*.lua` - Custom blueprints

## Creating Custom Blueprints

You can create custom blueprints by adding them to `LuaUI/Config/OverwatchBlueprints*.lua`. See the example files in [blueprints](blueprints/) or [lua/builtin_blueprints.lua](lua/builtin_blueprints.lua) for details.

We have an extra [doc/developer/readme.md](doc/developer/readme.md) for developers.

## Authors

- Fast

## License

GNU GPL, v2 or later
