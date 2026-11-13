extends Node
## Player options, like classic's Video, Sound and Interface options and Key
## Bindings, saved to
## options.cfg in the profile folder (beside the save file for `--save=`
## runs, so tests never touch the real options). Video and sound apply here;
## the game reads the rest and listens to `changed`.

signal changed(key: String)

const FILE_NAME := "options.cfg"

const DEFAULTS := {
	# Video
	"display_mode": "Fullscreen",
	"window_size": "1920x1080",
	"monitor": 0,
	"vsync": true,
	"max_fps": 0,
	"background_fps": 30,
	"show_fps": false,
	"shadow_quality": "Medium",
	"view_distance": "Normal",
	"field_of_view": 60,
	"environment_detail": "Medium",
	"ambient_occlusion": false,
	"bloom": false,
	"brightness": 1.0,
	"gamma": 1.0,
	"contrast": 1.0,
	"saturation": 1.0,
	# Performance: how much of the game's crowd-saving work is done (main.gd
	# _apply_setting): the rows the 3D view is drawn at, how often and how
	# far characters animate and show small parts, shadows, cloaks, spell
	# effects, how far units get full updates, and the time far ones get.
	"render_resolution": "Medium",
	"animation_quality": "High",
	"character_detail": "High",
	"character_shadows": "Normal",
	"cloak_physics": "Everyone",
	"spell_effects": "High",
	"light_shafts": "High",
	"unit_detail_distance": "Normal",
	"distant_unit_updates": "Normal",
	# Sound
	"sound_enabled": true,
	"master_volume": 1.0,
	"effects_volume": 1.0,
	# Interface
	"ui_scale": 0.65,
	"auto_loot": false,
	"npc_names": true,
	"enemy_names": true,
	"quest_tracker": true,
	# Extra action bars (GameState.EXTRA_BARS): two rows above the XP bar and
	# two columns down the right side.
	"bar_bottom_left": false,
	"bar_bottom_right": false,
	"bar_right": false,
	"bar_right_2": false,
	"loading_tips": true,
	# Released builds look for a newer release on GitHub at start (Updater).
	"check_updates": true,
	# The party bar (PartyBar) shows while you have a party, unless hidden (K).
	"party_bar_shown": true,
	"mouse_speed": 1.0,
	"invert_mouse": false,
	# Playerbots, after the playerbots module's options (AiPlayerbot.* in
	# aiplayerbot.conf): how many random bots there are and at what levels,
	# and how bots in your party behave.
	"bots_enabled": true,
	"bot_count": 8,
	"bot_min_level": 1,
	"bot_max_level": 10,
	"bot_quests": true,
	"bot_chat": "Normal",
	"bot_accept_invites": "Always",
	"bot_assist": "Defend Only",
	"bot_follow_distance": 3,
	"bot_heal_threshold": 0.7,
	"bot_teleport": true,
	# Chat
	"chat_font": "Medium",
	"chat_background": 0.35,
	"chat_outline": false,
	# The chat frame's tabs, place and size (saved as you change them), and lock.
	"chatframe_tabs": [],
	"chatframe_rect": [],
	"chatframe_locked": true,
	# The spellbook's "Hide old ranks" box: only the highest known rank of each spell.
	"spellbook_hide_old_ranks": false,
	# Developer
	"dev_console": true,
	# Where the Options window was dragged to, from the middle of the screen.
	"options_window_offset": Vector2.ZERO,
	# The cape's spring physics (HumanoidModel._cape_springs, _update_cape),
	# tuned live from the Developer tab (these are the values settled on).
	"cape_stiffness": 0.0,
	"cape_drag": 0.15,
	"cape_gravity": 0.5,
	"cape_wind": 0.1,
	"cape_turn_wind": 0.15,
	"cape_wind_smoothing": 8.0,
	"cape_flutter": 0.15,
	"cape_flutter_rate": 2.0,
}

## Rebindable actions in the Key Bindings window: [action, label, section].
## Esc (the game menu) stays fixed, as do the developer console and Shift+F12.
const ACTIONS := [
	["move_up", "Move Forward", "Movement"], ["move_down", "Move Backward", "Movement"],
	["move_left", "Turn Left", "Movement"], ["move_right", "Turn Right", "Movement"],
	["strafe_left", "Strafe Left", "Movement"], ["strafe_right", "Strafe Right", "Movement"],
	["jump", "Jump", "Movement"], ["autorun", "Toggle Autorun", "Movement"],
	["toggle_walk", "Toggle Run/Walk", "Movement"], ["sit", "Sit/Stand", "Movement"],
	["target_next", "Target Nearest Enemy", "Targeting"],
	["bags", "Open All Bags", "Interface"], ["character_window", "Character Info", "Interface"],
	["spellbook", "Spellbook", "Interface"], ["talents", "Talents", "Interface"],
	["quest_log", "Quest Log", "Interface"],
	["social", "Social", "Interface"], ["world_map", "World Map", "Interface"],
	["party_commands", "Show/Hide Party Bar", "Interface"],
	["ability_1", "Action Button 1", "Action Bar"], ["ability_2", "Action Button 2", "Action Bar"],
	["ability_3", "Action Button 3", "Action Bar"], ["ability_4", "Action Button 4", "Action Bar"],
	["ability_5", "Action Button 5", "Action Bar"], ["ability_6", "Action Button 6", "Action Bar"],
	["ability_7", "Action Button 7", "Action Bar"], ["ability_8", "Action Button 8", "Action Bar"],
	["ability_9", "Action Button 9", "Action Bar"], ["ability_10", "Action Button 10", "Action Bar"],
	["ability_11", "Action Button 11", "Action Bar"], ["ability_12", "Action Button 12", "Action Bar"],
	["bottom_left_1", "Bottom Left Bar Button 1", "Bottom Left Action Bar"], ["bottom_left_2", "Bottom Left Bar Button 2", "Bottom Left Action Bar"],
	["bottom_left_3", "Bottom Left Bar Button 3", "Bottom Left Action Bar"], ["bottom_left_4", "Bottom Left Bar Button 4", "Bottom Left Action Bar"],
	["bottom_left_5", "Bottom Left Bar Button 5", "Bottom Left Action Bar"], ["bottom_left_6", "Bottom Left Bar Button 6", "Bottom Left Action Bar"],
	["bottom_left_7", "Bottom Left Bar Button 7", "Bottom Left Action Bar"], ["bottom_left_8", "Bottom Left Bar Button 8", "Bottom Left Action Bar"],
	["bottom_left_9", "Bottom Left Bar Button 9", "Bottom Left Action Bar"], ["bottom_left_10", "Bottom Left Bar Button 10", "Bottom Left Action Bar"],
	["bottom_left_11", "Bottom Left Bar Button 11", "Bottom Left Action Bar"], ["bottom_left_12", "Bottom Left Bar Button 12", "Bottom Left Action Bar"],
	["bottom_right_1", "Bottom Right Bar Button 1", "Bottom Right Action Bar"], ["bottom_right_2", "Bottom Right Bar Button 2", "Bottom Right Action Bar"],
	["bottom_right_3", "Bottom Right Bar Button 3", "Bottom Right Action Bar"], ["bottom_right_4", "Bottom Right Bar Button 4", "Bottom Right Action Bar"],
	["bottom_right_5", "Bottom Right Bar Button 5", "Bottom Right Action Bar"], ["bottom_right_6", "Bottom Right Bar Button 6", "Bottom Right Action Bar"],
	["bottom_right_7", "Bottom Right Bar Button 7", "Bottom Right Action Bar"], ["bottom_right_8", "Bottom Right Bar Button 8", "Bottom Right Action Bar"],
	["bottom_right_9", "Bottom Right Bar Button 9", "Bottom Right Action Bar"], ["bottom_right_10", "Bottom Right Bar Button 10", "Bottom Right Action Bar"],
	["bottom_right_11", "Bottom Right Bar Button 11", "Bottom Right Action Bar"], ["bottom_right_12", "Bottom Right Bar Button 12", "Bottom Right Action Bar"],
	["right_1", "Right Bar Button 1", "Right Action Bar"], ["right_2", "Right Bar Button 2", "Right Action Bar"],
	["right_3", "Right Bar Button 3", "Right Action Bar"], ["right_4", "Right Bar Button 4", "Right Action Bar"],
	["right_5", "Right Bar Button 5", "Right Action Bar"], ["right_6", "Right Bar Button 6", "Right Action Bar"],
	["right_7", "Right Bar Button 7", "Right Action Bar"], ["right_8", "Right Bar Button 8", "Right Action Bar"],
	["right_9", "Right Bar Button 9", "Right Action Bar"], ["right_10", "Right Bar Button 10", "Right Action Bar"],
	["right_11", "Right Bar Button 11", "Right Action Bar"], ["right_12", "Right Bar Button 12", "Right Action Bar"],
	["right_2_1", "Right 2 Bar Button 1", "Right 2 Action Bar"], ["right_2_2", "Right 2 Bar Button 2", "Right 2 Action Bar"],
	["right_2_3", "Right 2 Bar Button 3", "Right 2 Action Bar"], ["right_2_4", "Right 2 Bar Button 4", "Right 2 Action Bar"],
	["right_2_5", "Right 2 Bar Button 5", "Right 2 Action Bar"], ["right_2_6", "Right 2 Bar Button 6", "Right 2 Action Bar"],
	["right_2_7", "Right 2 Bar Button 7", "Right 2 Action Bar"], ["right_2_8", "Right 2 Bar Button 8", "Right 2 Action Bar"],
	["right_2_9", "Right 2 Bar Button 9", "Right 2 Action Bar"], ["right_2_10", "Right 2 Bar Button 10", "Right 2 Action Bar"],
	["right_2_11", "Right 2 Bar Button 11", "Right 2 Action Bar"], ["right_2_12", "Right 2 Bar Button 12", "Right 2 Action Bar"],
]
const SHORT_KEYS := {
	KEY_MINUS: "-", KEY_EQUAL: "=", KEY_SLASH: "/", KEY_BACKSLASH: "\\", KEY_COMMA: ",",
	KEY_PERIOD: ".", KEY_SEMICOLON: ";", KEY_APOSTROPHE: "'", KEY_BRACKETLEFT: "[",
	KEY_BRACKETRIGHT: "]", KEY_SPACE: "Spc", KEY_SHIFT: "Sh", KEY_CTRL: "Ctl", KEY_ALT: "Alt",
}
## Mouse buttons that can be bound, stored as negative button indexes beside
## keycodes. Left and right stay with the camera and clicking, as in classic.
const BINDABLE_MOUSE := [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
## Names as classic numbers them: the side buttons are 4 and 5.
const MOUSE_NAMES := {
	MOUSE_BUTTON_MIDDLE: ["Middle Mouse", "M3"], MOUSE_BUTTON_XBUTTON1: ["Mouse Button 4", "M4"],
	MOUSE_BUTTON_XBUTTON2: ["Mouse Button 5", "M5"],
}
## Modifiers a binding can hold with its key (Shift-1, Ctrl-Mouse Button 4):
## Godot's key modifier masks, or'd into the binding's keycode (or into the
## button index of a mouse binding, which is stored negated).
const MODIFIER_MASK := KEY_MASK_SHIFT | KEY_MASK_CTRL | KEY_MASK_ALT
const MODIFIER_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
## Keys that can't be bound: Esc opens the game menu, ` the console, and /
## opens the chat with a slash typed (walking is on Numpad /, as in classic).
const RESERVED_KEYS := [KEY_ESCAPE, KEY_QUOTELEFT, KEY_SLASH]

## The defaults this build starts with: DEFAULTS with the shipped file
## (default_options.cfg) over them. Defaults buttons go back to these.
var _defaults := DEFAULTS.duplicate(true)
var _values := DEFAULTS.duplicate(true)
## The project's own key bindings, before any shipped ones.
var _project_keys: Dictionary
## `-- --pretend-release`: an editor run behaves as a release build (no
## developer tools), to try it out. Test arguments still work.
var _pretend_release := false
## Each action's two keys as physical keycodes, or a mouse button as its
## negative index (0 for none), from the project's input map until the player
## changes them.
var _default_keys: Dictionary


func _ready() -> void:
	_pretend_release = "--pretend-release" in OS.get_cmdline_user_args()
	# Every window's own controls in the Gothic gilt style (UiStyle): merged
	# into the default theme every control falls back to, as a theme on the
	# root window doesn't reach controls under non-Control nodes (CanvasLayers).
	ThemeDB.get_default_theme().merge_with(UiStyle.theme())
	for entry: Array in ACTIONS:
		# The extra action bars' buttons aren't in project.godot: unbound to start.
		if not InputMap.has_action(entry[0]):
			InputMap.add_action(entry[0])
		_default_keys[entry[0]] = _keys_in_map(entry[0])
	_project_keys = _default_keys.duplicate(true)
	# The shipped defaults first, then the player's own options over them.
	var shipped := ConfigFile.new()
	if shipped.load(SHIPPED_PATH) == OK:
		_read_into(shipped, _defaults, _default_keys)
	_values = _defaults.duplicate(true)
	_values.keys = _default_keys.duplicate(true)
	var file := ConfigFile.new()
	if file.load(_path()) == OK:
		_read_into(file, _values, _values.keys)
	_apply_all()


## Choices saved under an older name.
const RENAMED_CHOICES := {}


## Reads an options file's [options] and [keys] into values and bindings,
## keeping only options that exist and have the right type.
func _read_into(file: ConfigFile, values: Dictionary, keys: Dictionary) -> void:
	for entry: Array in ACTIONS:
		# Only what the file has: asking for a missing entry logs an error.
		if not file.has_section_key("keys", entry[0]):
			continue
		var saved = file.get_value("keys", entry[0])
		if saved is Array and saved.size() == 2:
			# Bindings saved before a key was reserved (/ for walking) let it go.
			keys[entry[0]] = [_unreserved(int(saved[0])), _unreserved(int(saved[1]))]
	for key: String in DEFAULTS:
		if not file.has_section_key("options", key):
			continue
		var saved = file.get_value("options", key)
		if (typeof(saved) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and saved is int)):
			values[key] = RENAMED_CHOICES.get(saved, saved) if saved is String else saved


## The shipped defaults, read over DEFAULTS in every build.
const SHIPPED_PATH := "res://default_options.cfg"
## Options that belong to one machine, never shipped.
const NOT_SHIPPED := ["monitor", "chatframe_rect"]


## An option's default in this build (the shipped one, if any).
func default_value(key: String) -> Variant:
	return _defaults.get(key, DEFAULTS.get(key))


## Developer tools (the console, the Developer options, developer chat
## commands, Shift+F12): in editor runs and debug exports, not in release.
func developer_tools() -> bool:
	return OS.is_debug_build() and not _pretend_release


## Writes the current options into the shipped defaults file, as the options
## a release build starts with: every option that differs from the code's
## DEFAULTS (not the machine's own monitor and chat placement), and the key
## bindings too if asked. Only from the editor, which can write the project's
## files. Returns what it did.
func write_shipped(with_keys: bool) -> String:
	if not OS.has_feature("editor"):
		return "!Only from the editor: exported games can't change their own files."
	var file := ConfigFile.new()
	var written := 0
	for key: String in DEFAULTS:
		if key in NOT_SHIPPED or _values[key] == DEFAULTS[key]:
			continue
		file.set_value("options", key, _values[key])
		written += 1
	var bindings := 0
	if with_keys:
		for action: String in _values.keys:
			if _values.keys[action] != _project_keys.get(action):
				file.set_value("keys", action, _values.keys[action])
				bindings += 1
	var error := file.save(ProjectSettings.globalize_path(SHIPPED_PATH))
	if error != OK:
		return "!Couldn't write %s: %s" % [SHIPPED_PATH, error_string(error)]
	return "Shipped defaults written to %s: %d option%s%s. Release builds start with these." % [
		SHIPPED_PATH, written, "" if written == 1 else "s",
		", %d key binding%s" % [bindings, "" if bindings == 1 else "s"] if with_keys else " (key bindings left as they are)"]


## Deletes the shipped defaults file, so builds start from the code's DEFAULTS.
func clear_shipped() -> String:
	if not OS.has_feature("editor"):
		return "!Only from the editor."
	var path := ProjectSettings.globalize_path(SHIPPED_PATH)
	if not FileAccess.file_exists(path):
		return "There are no shipped defaults."
	DirAccess.remove_absolute(path)
	return "Shipped defaults removed; builds start from the code's defaults."


func get_value(key: String) -> Variant:
	return _values.get(key, default_value(key))


## Changes an option and applies it now. `save()` keeps it.
func set_value(key: String, value: Variant) -> void:
	if _values.get(key) == value:
		return
	_values[key] = value
	_apply(key)
	changed.emit(key)


## Screen pixels per HUD unit (1/270 of the window height at UI Scale 100%),
## for the in-game interface.
func hud_scale(window_height: float) -> float:
	return maxf(window_height / 270.0, 1.0) * float(get_value("ui_scale"))


func snapshot() -> Dictionary:
	return _values.duplicate()


## Puts back every option from a snapshot (Cancel), or the defaults.
func restore(values: Dictionary) -> void:
	for key: String in DEFAULTS:
		set_value(key, values.get(key, default_value(key)))
	set_value("keys", values.get("keys", _default_keys).duplicate(true))


func snapshot_keys() -> Dictionary:
	return _values.keys.duplicate(true)


## The two keys bound to an action, as physical keycodes (0 for none).
func keys_for(action: String) -> Array:
	return _values.keys.get(action, [0, 0])


## Binds a key to one of an action's two slots (0 clears it). As in classic, a
## key taken from another action leaves that one unbound; returns its label,
## or "".
func bind_key(action: String, slot: int, keycode: int) -> String:
	var keys: Dictionary = _values.keys.duplicate(true)
	var taken_from := bind_in(keys, action, slot, keycode)
	set_value("keys", keys)
	return taken_from


## The same binding done on a copy of the bindings (the Options window's,
## until Apply). Returns the label of the action the key was taken from.
static func bind_in(keys: Dictionary, action: String, slot: int, keycode: int) -> String:
	if is_reserved(keycode):
		return ""
	var taken_from := ""
	if keycode != 0:
		for entry: Array in ACTIONS:
			var other: Array = keys[entry[0]]
			for i in 2:
				if int(other[i]) == keycode and not (entry[0] == action and i == slot):
					other[i] = 0
					taken_from = entry[1]
	keys[action][slot] = keycode
	return taken_from


func reset_keys() -> void:
	set_value("keys", _default_keys.duplicate(true))


func default_keys() -> Dictionary:
	return _default_keys.duplicate(true)


## A short name for a key: "W", "Space", "Num 1", "Shift-1", "Ctrl-Alt-Q".
static func key_name(keycode: int) -> String:
	if keycode == 0:
		return ""
	var mods := modifiers_of(keycode)
	var prefix := ("Shift-" if mods & KEY_MASK_SHIFT else "") + ("Ctrl-" if mods & KEY_MASK_CTRL else "") + ("Alt-" if mods & KEY_MASK_ALT else "")
	var code := base_of(keycode)
	if keycode < 0:
		return prefix + MOUSE_NAMES.get(code, ["Mouse Button %d" % code])[0]
	return prefix + OS.get_keycode_string(code).replace("Kp ", "Num ")


## A binding's key (or mouse button index, positive) without its modifiers.
static func base_of(binding: int) -> int:
	return absi(binding) & ~MODIFIER_MASK


## A binding's modifiers, as Godot's key modifier masks.
static func modifiers_of(binding: int) -> int:
	return absi(binding) & MODIFIER_MASK


## Whether a key can't be bound, with or without modifiers.
static func is_reserved(binding: int) -> bool:
	return binding > 0 and base_of(binding) in RESERVED_KEYS


## The binding a key or mouse press makes: its key or button with the
## modifiers held (none for the modifier keys themselves), or 0.
static func binding_of(event: InputEvent) -> int:
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key:
		var code := int(key.physical_keycode)
		return code if code in MODIFIER_KEYS else code | _event_modifiers(key)
	if mouse:
		return -(int(mouse.button_index) | _event_modifiers(mouse))
	return 0


static func _event_modifiers(event: InputEventWithModifiers) -> int:
	return (KEY_MASK_SHIFT if event.shift_pressed else 0) | (KEY_MASK_CTRL if event.ctrl_pressed else 0) | (KEY_MASK_ALT if event.alt_pressed else 0)


## The modifiers held now.
static func _held_modifiers() -> int:
	return (KEY_MASK_SHIFT if Input.is_key_pressed(KEY_SHIFT) else 0) | (KEY_MASK_CTRL if Input.is_key_pressed(KEY_CTRL) else 0) | (KEY_MASK_ALT if Input.is_key_pressed(KEY_ALT) else 0)


## Whether a binding counts as pressed with `held` modifiers down: its own
## modifiers are among them, and no other binding of the same key with more of
## them is (as classic: with Shift-1 bound, Shift-1 doesn't also press 1; with
## it unbound, it does).
func _binding_wins(binding: int, held_mods: int) -> bool:
	var mods := modifiers_of(binding)
	if mods & ~held_mods:
		return false
	var mouse := binding < 0
	for action: String in _values.keys:
		for other in _values.keys[action]:
			var o := int(other)
			if o == 0 or (o < 0) != mouse or base_of(o) != base_of(binding):
				continue
			var other_mods := modifiers_of(o)
			if other_mods != mods and other_mods & mods == mods and other_mods & ~held_mods == 0:
				return false
	return true


## Whether an input event presses an action, with the bindings' modifiers
## taken into account: use it rather than event.is_action_pressed for bound
## actions.
func pressed(event: InputEvent, action: String) -> bool:
	if not event.is_action_pressed(action):
		return false
	# Actions with fixed keys (Esc's "pause") have no bindings to weigh.
	if not _values.keys.has(action):
		return true
	var made := binding_of(event)
	if made == 0:
		# A gamepad.
		return true
	for binding in keys_for(action):
		var b := int(binding)
		if b != 0 and (b < 0) == (made < 0) and base_of(b) == base_of(made) and _binding_wins(b, modifiers_of(made)):
			return true
	return false


## Whether an action is held now, as pressed() judges it: use it rather than
## Input.is_action_pressed for bound actions.
func held(action: String) -> bool:
	if not Input.is_action_pressed(action):
		return false
	if not _values.keys.has(action):
		return true
	var mods := _held_modifiers()
	var any_down := false
	for binding in keys_for(action):
		var b := int(binding)
		if b == 0:
			continue
		var down := Input.is_mouse_button_pressed(base_of(b) as MouseButton) if b < 0 else Input.is_physical_key_pressed(base_of(b) as Key)
		if not down:
			continue
		any_down = true
		if _binding_wins(b, mods):
			return true
	# Held by a gamepad.
	return not any_down


## Input.get_axis with held().
func axis(negative: String, positive: String) -> float:
	return (Input.get_action_strength(positive) if held(positive) else 0.0) - (Input.get_action_strength(negative) if held(negative) else 0.0)


## The label for an action's first key, for the action bar: symbols for
## punctuation, "N1" for the number pad, and at most three letters.
func key_label(action: String) -> String:
	var keys := keys_for(action)
	var binding := int(keys[0]) if int(keys[0]) != 0 else int(keys[1])
	# Classic's short marks for modifiers: "s1", "c2", "a3".
	var mods := modifiers_of(binding)
	var prefix := ("s" if mods & KEY_MASK_SHIFT else "") + ("c" if mods & KEY_MASK_CTRL else "") + ("a" if mods & KEY_MASK_ALT else "")
	var keycode := -base_of(binding) if binding < 0 else base_of(binding)
	if not prefix.is_empty():
		var short := _short_key(keycode)
		return prefix + (short.substr(0, 1) if prefix.length() + short.length() > 3 else short)
	return _short_key(keycode)


## The action bar's label for a key with no modifiers.
func _short_key(keycode: int) -> String:
	if SHORT_KEYS.has(keycode):
		return SHORT_KEYS[keycode]
	if keycode < 0:
		return MOUSE_NAMES.get(-keycode, ["", "M%d" % -keycode])[1]
	var text := key_name(keycode).replace("Num ", "N")
	return text.substr(0, 3) if text.length() > 3 else text


func save() -> void:
	var file := ConfigFile.new()
	for key: String in _values:
		if key != "keys":
			file.set_value("options", key, _values[key])
	for action: String in _values.keys:
		file.set_value("keys", action, _values.keys[action])
	DirAccess.make_dir_recursive_absolute(_path().get_base_dir())
	file.save(_path())


func _path() -> String:
	return folder().path_join(FILE_NAME)


## The profile folder, or the `--save=` file's folder in tests.
func folder() -> String:
	if GameState.single_save:
		return GameState.save_path.get_base_dir()
	return GameState.profile_dir


## Window sizes offered, smallest first.
const WINDOW_SIZES := ["1280x720", "1440x810", "1600x900", "1920x1080", "2560x1440"]
## Graphics options the world reads (Main applies them), so the HUD and
## camera know when to look again.
const WORLD_OPTIONS := ["render_resolution", "animation_quality", "character_detail", "character_shadows",
	"cloak_physics", "spell_effects", "light_shafts", "unit_detail_distance", "distant_unit_updates",
	"shadow_quality", "view_distance", "field_of_view", "environment_detail",
	"ambient_occlusion", "bloom", "brightness", "gamma", "contrast", "saturation"]


## The windowed size, centred on its monitor, never larger than the screen.
func _apply_window_size() -> void:
	if DisplayServer.get_name() == "headless" or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var parts := str(get_value("window_size")).split("x")
	if parts.size() != 2:
		return
	var screen := DisplayServer.window_get_current_screen()
	var room := DisplayServer.screen_get_usable_rect(screen)
	var wanted := Vector2i(mini(int(parts[0]), room.size.x), mini(int(parts[1]), room.size.y))
	DisplayServer.window_set_size(wanted)
	DisplayServer.window_set_position(room.position + (room.size - wanted) / 2)


## The frame cap: Max Frame Rate while the game has focus, Background Frame
## Rate while it doesn't (as classic's background FPS).
func _apply_frame_cap() -> void:
	var cap := int(get_value("max_fps"))
	if not _focused and int(get_value("background_fps")) > 0:
		cap = int(get_value("background_fps")) if cap == 0 else mini(cap, int(get_value("background_fps")))
	Engine.max_fps = cap


var _focused := true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = what == NOTIFICATION_APPLICATION_FOCUS_IN
		_apply_frame_cap()


func _apply_all() -> void:
	for key: String in DEFAULTS:
		_apply(key)
	_apply("keys")


## Keyboard keys of an action in the input map, as two physical keycodes.
static func _unreserved(keycode: int) -> int:
	return 0 if is_reserved(keycode) else keycode


static func _keys_in_map(action: String) -> Array:
	var keys := [0, 0]
	var i := 0
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		var mouse := event as InputEventMouseButton
		if i < 2 and (key or mouse):
			keys[i] = binding_of(event)
			i += 1
	return keys


func _apply(key: String) -> void:
	match key:
		"display_mode":
			# Headless runs have no window to change.
			if DisplayServer.get_name() == "headless":
				return
			var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
			match get_value(key):
				"Fullscreen":
					mode = DisplayServer.WINDOW_MODE_FULLSCREEN
				"Exclusive Fullscreen":
					mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			if DisplayServer.window_get_mode() != mode:
				DisplayServer.window_set_mode(mode)
			if mode == DisplayServer.WINDOW_MODE_WINDOWED:
				_apply_window_size()
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value(key) else DisplayServer.VSYNC_DISABLED)
		"max_fps", "background_fps":
			_apply_frame_cap()
		"window_size":
			_apply_window_size()
		"monitor":
			if DisplayServer.get_name() == "headless":
				return
			var screen := clampi(int(get_value(key)), 0, DisplayServer.get_screen_count() - 1)
			if DisplayServer.window_get_current_screen() != screen:
				DisplayServer.window_set_current_screen(screen)
				_apply_window_size()
		"keys":
			# Keyboard and mouse events are replaced; gamepad ones stay.
			for action: String in _values.keys:
				for event in InputMap.action_get_events(action):
					if event is InputEventKey or event is InputEventMouseButton:
						InputMap.action_erase_event(action, event)
				for keycode in _values.keys[action]:
					var binding := int(keycode)
					var event: InputEventWithModifiers
					if binding > 0:
						var key_event := InputEventKey.new()
						key_event.physical_keycode = base_of(binding) as Key
						event = key_event
					elif binding < 0:
						var mouse_event := InputEventMouseButton.new()
						mouse_event.button_index = base_of(binding) as MouseButton
						event = mouse_event
					else:
						continue
					var mods := modifiers_of(binding)
					event.shift_pressed = mods & KEY_MASK_SHIFT != 0
					event.ctrl_pressed = mods & KEY_MASK_CTRL != 0
					event.alt_pressed = mods & KEY_MASK_ALT != 0
					InputMap.action_add_event(action, event)
		"sound_enabled", "master_volume":
			var volume: float = get_value("master_volume")
			AudioServer.set_bus_mute(0, not get_value("sound_enabled") or volume <= 0.0)
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
