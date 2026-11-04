# To do

## Release settings
Wait until more settings are added, then:
- A shipped defaults file, `res://default_options.cfg`, read by `Settings` over `DEFAULTS` for any option it lists. It ships with release builds; players' own `options.cfg` in `user://` still overrides it.
- A dev command (e.g. `/shipdefaults`) that writes your current in-game options into that file, with a choice of what to include (for example everything but key bindings). Editor runs only, since exported games can't write to `res://`.
- A release lockout: in release exports (`OS.is_debug_build()` false), hide the Developer options tab, turn off the `` ` `` console and developer slash commands in chat, and possibly ignore the `--save=` / `--profile=` test arguments.
- An export preset (there is none yet).
