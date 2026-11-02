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
- `scripts/autoload/`: global singletons. `Sfx.play(name)` plays a sound, with names mapped to files in `sfx.gd`
- `assets/audio/rpg_sfx/`: CC0 sound pack, see its `LICENSE.txt`
- `shaders/`, `ui/`, `assets/{models,textures,audio,fonts}/`

## Conventions
- Typed GDScript, tabs, tunable values as `@export`.
- The 3D game renders in `GameView/GameViewport` at a whole-number pixel scale, at least `min_game_height` rows tall (set on the `Main` node). The look depends on this low resolution.
- The HUD draws at full window resolution, outside the game view. Its layout is in units of 1/270 of the window height.
- Outlines come from `shaders/pixelart_stylizer.gdshader` (MIT, by Leo Peltola) on a plane attached to the game camera. It needs Forward+. Tune them in `shaders/outline_material.tres`.
- Input actions are defined in `project.godot`: `move_*`, `strafe_*`, `target_next`, `ability_1` to `ability_4`, `interact`, `pause`.
- Combat is WoW-style tab-targeting. Physics layers: 1 is world, 2 is units.
- `main.tscn` uses the WoW-style `scenes/camera/orbit_camera.tscn`, which gives the player tank controls. The fixed `game_camera.tscn` is kept for comparison and gives camera-relative movement.
