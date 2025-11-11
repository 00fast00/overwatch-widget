# Developer Guide

## Project Structure

- `library/`
  - `BAR/`: Type definitions from Beyond-All-Reason project. [source](https://github.com/beyond-all-reason/Beyond-All-Reason/blob/25b67298a2d4f9d97ed3ccd27c48a82256ae9c5c/types)
  - `BAR_LuaUI/`: Definitions specific for BAR Widget development, also here to provide a nice list of dependencies instead of suppressing warnings.
- `configs/`: Configurations files you can test out `*01debug.lua` and `*99fast.lua` are the only ones of any use.
- `scripts/`
  - `build.sh`: Build, watch, commmit - all in one.
- `lua/`: All source code that will be bundled to `dist/`
  - `builtin_blueprints/`: Blueprints shipped with the widget.
  - `channels/`: Notification channels
  - `core/`: Reusable components, some depend on each other.
  - `ui/`: UI variants currently "only" RmlUi.
  - `main.lua`: Main entry point.
- `vendor/`: External resources.
  - `lua/i18n/`: https://travis-ci.org/kikito/i18n.lua we only use `interpolate` of it.
  - `recoil-lua-library`: LuaDoc typdefs for Recoil.

## Build System

### What is this approach?

This project uses a **modular development approach** with a bundling step:

1. We write code in multiple separate files (modules) for better organization
2. Each module handles a specific feature or component
3. The bundler [luapack](https://github.com/00fast00/luapack) combines all these files into a single widget file
4. This final bundled file is what gets loaded by the game

Think of it like building with LEGO - we create individual pieces separately, then connect them together to make the final product. This is similar to how modern web development works with tools like Webpack or Rollup.

### Benefits

- Modular approach: Enables clean code organization with proper separation of concerns and explicit dependencies
- LuaDoc annotations: All functions, classes, and parameters are documented with type information
- Zero diagnostic errors: Strict type checking with lua-language-server helps catch issues early
- Reusable components: Well-organized library structure in `ui/core/` promotes code reuse
- Separation of UI and logic: Clean separation between game logic and presentation layer

### Tradeoffs

- Documentation overhead: Having LuaDoc for everything requires more initial development time
- Debugging complexity: Working with bundled code makes runtime debugging more challenging
- Learning curve: New developers need to understand the modular architecture and typing system
- Build step requirement: Changes require rebuilding before testing
- Increased boilerplate: More code is needed for proper typing and module structure

### How the bundling works

1. You write code in separate files in the `lua/` directory
2. The main entry point is `lua/main.lua`
3. When you run `build.sh build`, it:
   - Replaces `local IS_RELEASE = false` with true for release builds
   - Starts luapack with `lua/main.lua`
   - Follows all `require()` statements to find dependencies
   - Combines everything into a single file with proper scoping
   - Outputs the result to `dist/overwatch.lua` and `dist/debug/overwatch.lua`

4. The bundled file is what you copy to your game's widget directory

### Install

See [luapack](https://github.com/00fast00/luapack)

### Usage

```bash
./scripts/build.sh [debug|release|watch|watch-release|build|commit|build-commit]
```

### Development workflow

1. Edit files in the `src/` directory
2. Run `scripts/build.sh all` or `scripts/build.sh watch`
3. The bundled widget appears in `dist/debug/overwatch.lua`
4. Copy or symlink this file to your game's widget directory for testing

## Debugging / Testing Tipps

- It helps a lot to have BAR in devmode installed, see: https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/README.md
- Reenable in `Settings->Custom` to load again. Devmode does autoreload them somehow.
- Use a second instance of your editor to open `dist` so you aren't getting masses of diagnostic errors.
- Use these in `springsettings.cfg` to have a full infolog.txt
  ```ini
  LogFlush = 1
  LogFlushLevel = 0
  LogRepeatLimit = 0
  ServerLogDebugMessages = 1
  ServerLogInfoMessages = 1
  ```

## Core Concepts

### GameContext

Global game state and context information

GameContext tracks game-wide state like time, PVE mode, boss status, and provides utility methods for checking game conditions.

_Code: [src/lib/GameContext.lua](src/lib/GameContext.lua)_

### TeamContext

TeamContext provides access to team-specific data and resources.

_Code: [src/lib/TeamContext.lua](src/lib/TeamContext.lua)_

### Blueprint

The logic of a rule that defines conditions and alerts for game events that should be monitored.
Each blueprint can be instantiated with specific configurations.

A blueprint **MUST** be stateless, meaning it should not store any data except in the provided `state`. Blueprints might run with different sets of configurations and teams, all mixed together.

_Code: [Definition](src/defs.lua) | [Examples](src/builtinBlueprints.lua)_

### RuleConfig

The configuration settings for a rule

RuleConfig defines how a rule should behave, including notification settings, cooldown periods, and custom parameters.

_Code: [src/defs.lua](src/defs.lua)_

### RuleState

Maintains the runtime state information for a rule instance.

_Code: [src/defs.lua](src/defs.lua)_

### Channel

Notification channels for the resulting notifications.

_Code: [Example](src/Channel/Console.lua)_

## Notification

### Interval-Based

```text
    +--------------------------------------------+
    |        Blueprint + RuleConfig              |
    |                  (Rule)                    |
    +------------------------+-------------------+
                         |
                         v
                +----------------+       <----------------<
                |                |                        |
                v                v                        |
+-----------------------+   +-----------------------+     |
|  Contexts             |   |      RuleState        |     |
|  (Game + Team)        |   |  (per Rule and Team)  |     |
+-----------+-----------+   +-----------+-----------+     |
             \                          /                 |
              \                        /                  |
               v                      v                   |
            +--------------------------------+            |
            |           trigger()            |            |
            +--------------------------------+            |
                           |                              |
                           v                              |
            +--------------------------------+            |
            |           dispatch()           |            |
            +--------------------------------+            |
                           |                              |
                           v                              |
            +--------------------------------+            |
            |   Channels (Console, etc.)     |  >---------^
            +--------------------------------+
```

Process flow:
1. A `Blueprint` (rule logic) is combined with a `RuleConfig` (settings)
2. The rule evaluates using game and team context plus its state
3. `trigger()` may generates notification(s) and runs dispatch().
4. The notification is distributed to configured channels
5. Repeat at step 2.

### Event-Based



## Resources

### Lua

- Awesome list: https://github.com/LewisJEllis/awesome-lua
- Style guide: http://lua-users.org/wiki/LuaStyleGuide
- LuaDoc / lua-language-server: https://luals.github.io/wiki/

### BAR

- BAR unit list: https://github.com/beyond-all-reason/Beyond-All-Reason/blob/master/language/en/units.json

### Recoil

- Recoil API: https://beyond-all-reason.github.io/RecoilEngine/docs/lua-api/

### RmlUi Development

- https://mikke89.github.io/RmlUiDoc/
- https://github.com/mikke89/RmlUi/tree/master/Samples