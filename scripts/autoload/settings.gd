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
	"display_mode": "Windowed",
	"vsync": true,
	"max_fps": 0,
	"shadows": true,
	"brightness": 1.0,
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
	"loading_tips": true,
	"mouse_speed": 1.0,
	"invert_mouse": false,
	# Playerbots, after the playerbots module's options (AiPlayerbot.* in
	# aiplayerbot.conf): how many random bots there are and at what levels,
	# and how bots in your party behave.
	"bots_enabled": true,
	"bot_count": 8,
	"bot_min_level": 1,
	"bot_max_level": 6,
	"bot_classes": "All Classes",
	"bot_accept_invites": "Always",
	"bot_assist": "Assist My Target",
	"bot_follow_distance": 3,
	"bot_heal_threshold": 0.7,
	"bot_teleport": true,
	# Developer
	"dev_console": true,
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
	["spellbook", "Spellbook", "Interface"], ["quest_log", "Quest Log", "Interface"],
	["social", "Social", "Interface"],
	["ability_1", "Action Button 1", "Action Bar"], ["ability_2", "Action Button 2", "Action Bar"],
	["ability_3", "Action Button 3", "Action Bar"], ["ability_4", "Action Button 4", "Action Bar"],
	["ability_5", "Action Button 5", "Action Bar"], ["ability_6", "Action Button 6", "Action Bar"],
	["ability_7", "Action Button 7", "Action Bar"], ["ability_8", "Action Button 8", "Action Bar"],
	["ability_9", "Action Button 9", "Action Bar"], ["ability_10", "Action Button 10", "Action Bar"],
	["ability_11", "Action Button 11", "Action Bar"], ["ability_12", "Action Button 12", "Action Bar"],
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
## Keys that can't be bound: Esc opens the game menu, ` the console.
const RESERVED_KEYS := [KEY_ESCAPE, KEY_QUOTELEFT]

var _values := DEFAULTS.duplicate()
## Each action's two keys as physical keycodes, or a mouse button as its
## negative index (0 for none), from the project's input map until the player
## changes them.
var _default_keys: Dictionary


func _ready() -> void:
	for entry: Array in ACTIONS:
		_default_keys[entry[0]] = _keys_in_map(entry[0])
	_values.keys = _default_keys.duplicate(true)
	var file := ConfigFile.new()
	if file.load(_path()) == OK:
		for entry: Array in ACTIONS:
			var saved = file.get_value("keys", entry[0], null)
			if saved is Array and saved.size() == 2:
				_values.keys[entry[0]] = [int(saved[0]), int(saved[1])]
		for key: String in DEFAULTS:
			var saved = file.get_value("options", key, DEFAULTS[key])
			if typeof(saved) == typeof(DEFAULTS[key]) or (DEFAULTS[key] is float and saved is int):
				_values[key] = saved
	_apply_all()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


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
		set_value(key, values.get(key, DEFAULTS[key]))
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
	if keycode in RESERVED_KEYS:
		return ""
	var keys: Dictionary = _values.keys.duplicate(true)
	var taken_from := ""
	if keycode != 0:
		for entry: Array in ACTIONS:
			var other: Array = keys[entry[0]]
			for i in 2:
				if int(other[i]) == keycode and not (entry[0] == action and i == slot):
					other[i] = 0
					taken_from = entry[1]
	keys[action][slot] = keycode
	set_value("keys", keys)
	return taken_from


func reset_keys() -> void:
	set_value("keys", _default_keys.duplicate(true))


## A short name for a key: "W", "Space", "Num 1".
static func key_name(keycode: int) -> String:
	if keycode == 0:
		return ""
	if keycode < 0:
		return MOUSE_NAMES.get(-keycode, ["Mouse Button %d" % -keycode])[0]
	var text := OS.get_keycode_string(keycode)
	return text.replace("Kp ", "Num ")


## The label for an action's first key, for the action bar: symbols for
## punctuation, "N1" for the number pad, and at most three letters.
func key_label(action: String) -> String:
	var keys := keys_for(action)
	var keycode := int(keys[0]) if int(keys[0]) != 0 else int(keys[1])
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


func _apply_all() -> void:
	for key: String in DEFAULTS:
		_apply(key)
	_apply("keys")


## Keyboard keys of an action in the input map, as two physical keycodes.
static func _keys_in_map(action: String) -> Array:
	var keys := [0, 0]
	var i := 0
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		var mouse := event as InputEventMouseButton
		if i < 2 and (key or mouse):
			keys[i] = int(key.physical_keycode) if key else -int(mouse.button_index)
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
		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value(key) else DisplayServer.VSYNC_DISABLED)
		"max_fps":
			Engine.max_fps = int(get_value(key))
		"keys":
			# Keyboard and mouse events are replaced; gamepad ones stay.
			for action: String in _values.keys:
				for event in InputMap.action_get_events(action):
					if event is InputEventKey or event is InputEventMouseButton:
						InputMap.action_erase_event(action, event)
				for keycode in _values.keys[action]:
					if int(keycode) > 0:
						var event := InputEventKey.new()
						event.physical_keycode = int(keycode)
						InputMap.action_add_event(action, event)
					elif int(keycode) < 0:
						var event := InputEventMouseButton.new()
						event.button_index = -int(keycode) as MouseButton
						InputMap.action_add_event(action, event)
		"sound_enabled", "master_volume":
			var volume: float = get_value("master_volume")
			AudioServer.set_bus_mute(0, not get_value("sound_enabled") or volume <= 0.0)
			AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
