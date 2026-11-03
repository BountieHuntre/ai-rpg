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
- Spells: `SpellDB` reads `data/classic/spells.json`; `SpellCaster` (on the Player) casts with classic checks, GCD, cooldowns and cast times, and holds each spell's effect code following CMaNGOS. Buffs are `Combatant.auras`. `GameState.known_spells` and `action_bar` are saved. UI: `ui/spell_ui.gd` (action bar 1-0,-,=; spellbook P; buff bar). Spells are learned from an `Npc` with a `trainer` (Sir Aldric Fenn) via `ui/trainer_window.gd`; its `IN_GAME` list names the spells with effect code so far, and the rest show but can't be trained. New ranks replace older ranks on the action bar (unlike classic). Paladin auras get their own stance bar above the action bar, filled automatically.
- NPCs: `scenes/npcs/npc.tscn` with `trainer` and/or `vendor` (a creature entry in `data/classic/vendors.json`). Vendors buy, sell (right-click bag items) and buy back, following CMaNGOS. Food and drink are item "Use:" spells handled by `SpellCaster.use_item`; X sits.
- Names are the game's own, not classic's: `tools/classic_db/renames.py` maps every classic item, creature, NPC and spell name to an original one when the data is exported (plain words like Wolf, Paladin and Human stay). Code that spots spell kinds by name uses the new patterns: `Oath of` seals, `Verdict` judgements, `Boon of` blessings, `... Presence` auras.
- World: `scenes/levels/ashford_vale/` is the starting area (levels 1-6), about 400 yards across, built in code from the layout constants in `ashford_vale.gd`: terrain from a height function (`scenes/levels/terrain.gd`), stream, roads, the priory, mine, brigand camp, bridge, seeded trees and rocks (`scenes/levels/props.gd`), and creature spawn groups. NPCs, sky and sun are in its `.tscn`. Saves store the zone; anything else starts at `AshfordVale.SPAWN`. Enemy node names come from the spawn layout, so changing `SPAWNS` orphans saved corpses (harmless).
- Quests: `QuestDB` joins each quest's classic rules (`data/classic/quests.json`, exported from quest_template for the ids in `extract.py`'s `QUESTS`) with the game's own title, text, giver and ender (`data/quests.json`; givers are NPC node names). `QuestLog` has the rules (taking, kill credit, quest-only drops, turning in, classic quest XP); progress is `GameState.quests` and `quests_done`, saved. UI: `ui/quest_window.gd` (talking to an NPC with quests), `ui/quest_log_ui.gd` (L), the tracker and the "!"/"?" markers in `CombatHud`. To add a quest, add its classic entry to `QUESTS`, re-export, and write its text in `data/quests.json`.
- Enemies are set by `creature_entry` (a classic creature_template id); their stats, loot, money, respawn time and wander distance come from the data. Their placeholder looks are in `Enemy.LOOKS`. Whether they attack on sight comes from their classic faction (`data/classic/factions.json`, rules in `ClassicData`): neutral ones and hostile ones flagged no-aggro only fight back, and all passive creatures show yellow.
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
- Start: `scenes/front_end/front_end.tscn` is the main scene: a pretend login (any account and password), character select and creation (classic race/class pairs, starting gear and proficiencies from `data/classic/characters.json`; only Paladins have spells). Enter World goes through `ui/loading_screen.gd` (a landscape, a tip and a progress bar; it loads on a thread, then fades out over the new world). Esc in game opens `ui/game_menu.gd` (Log Out returns to character select). Running `main.tscn` directly plays the first character.
- Saving: `GameState` saves each character (name, items, `player_state` with position, facing, health, mana) to `user://characters/<name>.json`, with a format `SAVE_VERSION`; login settings are in `user://settings.cfg`. `main.gd` saves every 30 s, after inventory changes, on level-up, death, logging out and quitting. Shift+F12 starts the current character over at level 1. Tests must pass `-- --save=<scratch file>` (one character, skips the front end) or `-- --profile=<scratch dir>` (front end with its own characters and settings) so they never touch the real saves.
- Scratch test scripts run with `-s` load before autoloads, so they must load classes that touch `GameState` (Inventory, ItemDB, LootTable) with `load()` at runtime rather than by class name.
- Dev console: ` (the key under Esc) opens `ui/dev_console.gd` in game, with commands like `additem`, `money`, `level`, `learn`, `tele`, `god` and `speed` (`help` lists them). Add a command as a `COMMANDS` entry plus a `_cmd_<name>` method. While it is open `Player.typing` stops the movement keys.
- `main.tscn` uses the WoW-style `scenes/camera/orbit_camera.tscn`, which gives the player tank controls. The fixed `game_camera.tscn` is kept for comparison and gives camera-relative movement.
