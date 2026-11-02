# AI RPG

3D pixel art action RPG built with Godot 4.6 (Forward+, Jolt physics).

## Running
- Editor/game: `D:\Godot_v4.6\Godot_v4.6-stable_win64.exe`
- Console build, for logs and scripted checks: `D:\Godot_v4.6\Godot_v4.6-stable_win64_console.exe`
- Run the game: `<console exe> --path C:/ai-rpg`
- Re-import after adding files: `<console exe> --headless --path C:/ai-rpg --import`

## Layout
- `scenes/<area>/`: scenes with their scripts beside them (`main`, `player`, `enemies`, `levels`, `camera`)
- `scripts/combat/`: shared combat logic (`Combatant`, `AbilityCaster`, `Targeting`, `Ability`)
- `data/abilities/`: one `Ability` resource per ability
- `scripts/stats/`, `scripts/items/`, `data/classic/`: classic WoW 1.12 stats, combat table, XP, creatures, items and loot, with exact tables and formulas from the CMaNGOS and vmangos server code (see `data/classic/SOURCE.md`). Keep new rules faithful to classic and note the source. `tools/classic_db/extract.py` regenerates the JSON from the CMaNGOS classic database.
- Spells: `SpellDB` reads `data/classic/spells.json`; `SpellCaster` (on the Player) casts with classic checks, GCD, cooldowns and cast times, and holds each spell's effect code following CMaNGOS. Buffs are `Combatant.auras`. `GameState.known_spells` and `action_bar` are saved. UI: `ui/spell_ui.gd` (action bar 1-0,-,=; spellbook P; buff bar). Spells are learned from `TrainerNpc` (Brother Wilhelm) via `ui/trainer_window.gd`; its `IN_GAME` list names the spells with effect code so far, and the rest show but can't be trained.
- Enemies are set by `creature_entry` (a classic creature_template id); their stats, loot and money come from the data.
- `scripts/autoload/`: global singletons. `Sfx.play(name)` plays a sound, with names mapped to files in `sfx.gd`
- `assets/audio/rpg_sfx/`: CC0 sound pack, see its `LICENSE.txt`
- `shaders/`, `ui/`, `assets/{models,textures,audio,fonts}/`

## Conventions
- Typed GDScript, tabs, tunable values as `@export`.
- The 3D game renders in `GameView/GameViewport` at a whole-number pixel scale, at least `min_game_height` rows tall (set on the `Main` node). The look depends on this low resolution.
- The HUD draws at full window resolution, outside the game view. Its layout is in units of 1/270 of the window height.
- Outlines come from `shaders/pixelart_stylizer.gdshader` (MIT, by Leo Peltola) on a plane attached to the game camera. It needs Forward+. Tune them in `shaders/outline_material.tres`.
- Input actions are defined in `project.godot`: `move_*`, `strafe_*`, `target_next`, `ability_1` to `ability_4`, `interact`, `pause`.
- Combat is WoW-style tab-targeting. Physics layers: 1 is world, 2 is units, 3 is corpses.
- World units are yards. Movement follows classic: run 7, backpedal 4.5, walk 2.5, turn 180°/s, no acceleration or air control. Other keys: Space jump, Num Lock autorun, / walk, B bags, C character.
- Items live in `GameState` (equipment, bags, containers); `scripts/items/inventory.gd` holds the classic bag and equip rules. Stats from gear flow into `CharacterStats` via `GameState.inventory_changed`.
- Saving: `GameState` saves the character, items and `player_state` (position, facing, health, mana) to `user://character.json`, with a format `SAVE_VERSION`. `main.gd` saves every 30 s, after inventory changes, on level-up, death and quitting. Shift+F12 deletes the save. Tests must pass `-- --save=<scratch path>` so they never touch the real save.
- Scratch test scripts run with `-s` load before autoloads, so they must load classes that touch `GameState` (Inventory, ItemDB, LootTable) with `load()` at runtime rather than by class name.
- `main.tscn` uses the WoW-style `scenes/camera/orbit_camera.tscn`, which gives the player tank controls. The fixed `game_camera.tscn` is kept for comparison and gives camera-relative movement.
