# AI RPG

3D pixel art action RPG built with Godot 4.6 (Forward+, Jolt physics).

## Running
- Editor/game: `D:\Godot_v4.6\Godot_v4.6-stable_win64.exe`
- Console build, for logs and scripted checks: `D:\Godot_v4.6\Godot_v4.6-stable_win64_console.exe`
- Run the game: `<console exe> --path C:/ai-rpg`
- Re-import after adding files: `<console exe> --headless --path C:/ai-rpg --import`

## Layout
- `scenes/<area>/`: scenes with their scripts beside them (`main`, `player`, `levels`, `camera`)
- `scripts/autoload/`: global singletons
- `shaders/`, `ui/`, `assets/{models,textures,audio,fonts}/`

## Conventions
- Typed GDScript, tabs, tunable values as `@export`.
- Internal resolution is 480x270, integer-scaled. The look depends on this low resolution, so don't raise it.
- Outlines come from `shaders/pixelart_stylizer.gdshader` (MIT, by Leo Peltola) on a plane attached to the game camera. It needs Forward+.
- Input actions are defined in `project.godot`: `move_*`, `attack`, `dodge`, `interact`, `pause`.
