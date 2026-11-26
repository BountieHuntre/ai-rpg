class_name OptionsWindow
extends PanelContainer
## The Options window, with a tab down the left for each category: Video,
## Performance, Sound, Interface, Chat, Playerbots, Key Bindings and Developer. A new category is a TABS entry plus its
## rows in CATEGORIES (or its own builder, as Key Bindings has). Changes wait
## until Apply, which applies and saves every changed option at once; Okay
## does the same and closes, Cancel drops what wasn't applied, and Defaults
## sets the open tab back (applied with the rest). In Key Bindings, click a
## key to bind a new one (Esc stops), right-click to clear it.

signal closed

static var WIDTH := 190.0
static var FONT_SIZE := 7
const GOLD := Color("ffd100")
const TEXT := Color(0.92, 0.9, 0.84)

## Each category's rows: [setting key, label, kind, choices or range].
const CATEGORIES := {
	"Video": [
		["display_mode", "Display Mode", "choice", ["Windowed", "Fullscreen", "Exclusive Fullscreen"]],
		["window_size", "Window Size", "choice", Settings.WINDOW_SIZES],
		["monitor", "Monitor", "monitor", null],
		["vsync", "Vertical Sync", "check", null],
		["max_fps", "Max Frame Rate", "fps", [0, 30, 60, 120, 144, 240]],
		["background_fps", "Background Frame Rate", "fps", [0, 10, 15, 30, 60]],
		["show_fps", "Show Frame Rate", "check", null],
		["shadow_quality", "Shadow Quality", "choice", ["Off", "Low", "Medium", "High"]],
		["view_distance", "View Distance", "choice", ["Near", "Normal", "Far", "Very Far"]],
		["field_of_view", "Field of View", "number", [50, 90, 1, "°"]],
		["environment_detail", "Environment Detail", "choice", ["Off", "Low", "Medium", "High"]],
		["ambient_occlusion", "Ambient Occlusion", "check", null],
		["bloom", "Bloom", "check", null],
		["brightness", "Brightness", "slider", [0.6, 1.4]],
		["gamma", "Gamma", "slider", [0.6, 1.6]],
		["contrast", "Contrast", "slider", [0.6, 1.4]],
		["saturation", "Saturation", "slider", [0.0, 2.0]],
	],
	# What the game's crowd-saving work does, traded against looks (main.gd
	# _apply_setting): lower is faster.
	"Performance": [
		["render_resolution", "Render Resolution", "choice", ["Low", "Medium", "High", "Ultra"]],
		["animation_quality", "Animation Quality", "choice", ["Low", "Medium", "High", "Ultra"]],
		["character_detail", "Character Detail Distance", "choice", ["Low", "Medium", "High", "Ultra"]],
		["character_shadows", "Character Shadows", "choice", ["Off", "Normal", "Full"]],
		["cloak_physics", "Cloak Physics", "choice", ["Off", "Player Only", "Everyone"]],
		["spell_effects", "Spell Effects", "choice", ["Off", "Low", "High"]],
		["light_shafts", "Light Shafts", "choice", ["Off", "Low", "High"]],
		["unit_detail_distance", "Unit Detail Distance", "choice", ["Near", "Normal", "Far"]],
		["distant_unit_updates", "Distant Unit Updates", "choice", ["Low", "Normal", "High"]],
	],
	"Sound": [
		["sound_enabled", "Enable Sound", "check", null],
		["master_volume", "Master Volume", "slider", [0.0, 1.0]],
		["effects_volume", "Sound Effects", "slider", [0.0, 1.0]],
	],
	"Interface": [
		# Classic's range: 100% already fills the window's height.
		["ui_scale", "UI Scale", "slider", [0.65, 1.0]],
		["auto_loot", "Auto Loot (Shift to choose)", "check", null],
		["npc_names", "Show NPC Names", "check", null],
		["enemy_names", "Show Enemy Names", "check", null],
		["quest_tracker", "Show Quest Tracker", "check", null],
		["bags_display", "Bags", "choice", ["Combined", "Separate"]],
		["bar_bottom_left", "Bottom Left Action Bar", "check", null],
		["bar_bottom_right", "Bottom Right Action Bar", "check", null],
		["bar_right", "Right Action Bar", "check", null],
		["bar_right_2", "Right Action Bar 2", "check", null],
		["loading_tips", "Show Loading Screen Tips", "check", null],
		["mouse_speed", "Mouse Look Speed", "slider", [0.25, 2.5]],
		["invert_mouse", "Invert Mouse", "check", null],
		["check_updates", "Check for Updates at Start", "check", null],
	],
	# Numbers are [lowest, highest, step, unit].
	"Playerbots": [
		["bots_enabled", "Enable Playerbots", "check", null],
		# 400 holds about 70 fps with both zones (BotManager.far_schedule).
		["bot_count", "Random Bots in the World", "number", [0, 400, 5, ""]],
		["bot_min_level", "Random Bot Lowest Level", "number", [1, 60, 1, ""]],
		["bot_max_level", "Random Bot Highest Level", "number", [1, 60, 1, ""]],
		["bot_quests", "Random Bots Do Quests", "check", null],
		["bot_chat", "Bot Chat", "choice", ["Off", "Quiet", "Normal", "Chatty"]],
		["bot_accept_invites", "Accept Party Invitations", "choice", ["Always", "Near My Level", "Never"]],
		["bot_assist", "Party Bots Attack", "choice", ["Assist My Target", "Defend Only", "Passive"]],
		["bot_follow_distance", "Follow Distance", "number", [2, 10, 1, " yd"]],
		["bot_heal_threshold", "Bots Heal Below", "slider", [0.3, 0.9]],
		["bot_teleport", "Teleport to Me When Left Behind", "check", null],
	],
	"Chat": [
		["chat_font", "Text Size", "choice", ["Small", "Medium", "Large", "Huge"]],
		["chat_background", "Background", "slider", [0.0, 0.9]],
		["chat_outline", "Outline Text", "check", null],
	],
	"Developer": [
		["dev_console", "Developer Console (` key)", "check", null],
		# Live: the cape changes as the slider moves (see LIVE_PREFIX).
		["cape_stiffness", "Cape Stiffness", "decimal", [0.0, 2.0, 0.05]],
		["cape_drag", "Cape Drag", "decimal", [0.0, 1.0, 0.05]],
		["cape_gravity", "Cape Weight", "decimal", [0.0, 10.0, 0.1]],
		["cape_wind", "Cape Wind (Running)", "decimal", [0.0, 1.5, 0.05]],
		["cape_turn_wind", "Cape Wind (Turning)", "decimal", [0.0, 3.0, 0.05]],
		["cape_wind_smoothing", "Cape Wind Smoothing", "decimal", [0.5, 20.0, 0.5]],
		["cape_flutter", "Cape Flutter", "decimal", [0.0, 2.0, 0.05]],
		["cape_flutter_rate", "Cape Flaps a Second", "decimal", [0.5, 6.0, 0.1]],
	],
}

static var _check_icons: Dictionary

## Options with this prefix take effect as their slider moves, to tune while
## watching (Apply saves them, Cancel puts them back).
const LIVE_PREFIX := "cape_"
## Live options' values when the window opened, for Cancel.
var _live_before: Dictionary = {}
## The title is being dragged, moving the window.
var _moving := false

const KEY_BINDINGS := "Key Bindings"
const DEVELOPER := "Developer"
## Every tunable number in the game, by system and script (Tuning).
const TUNING := "Tuning"
const TABS := ["Video", "Performance", "Sound", "Interface", "Chat", "Playerbots", KEY_BINDINGS, TUNING, DEVELOPER]
## Developer-only tabs, left out of release builds.
const DEVELOPER_TABS := [TUNING, DEVELOPER]
## One-click developer commands: [button text, console command]. "level+" is
## the next level (of the targeted playerbot, else the player's), filled in
## when pressed.
const DEV_BUTTONS := [
	["Heal", "heal"], ["Kill Target", "kill"], ["Repair Gear", "repair"],
	["Level Up", "level+"], ["+1 Gold", "money 1g"], ["Respawn Creatures", "respawn"],
	["Go to Start", "tele spawn"], ["Save Game", "save"], ["Where Am I", "pos"],
	["Reload Game", "reload"], ["Train All Spells", "trainall"], ["BiS", "bis"],
	["Randomize Bots", "randomizebots"], ["Reset Talents", "resettalents"], ["Give Bags", "givebags"],
	["Edit Zone in Blender", "editzone"],
]
const RESULT := Color(0.6, 0.9, 0.6)
## The open "Reset Character?" confirmation, or null.
var _confirm: ColorRect
## The Developer tab's "Spawn Enemy" choices: its ranks, and the level
## (0 until changed: the player's) and rank picked.
const SPAWN_RANKS := ["Normal", "Elite", "Boss"]
var _spawn_level := 0
var _spawn_rank := 0
const ERROR_COLOR := Color(1, 0.6, 0.4)
const TAB_SELECTED := Color(1, 0.85, 0.3)
static var TAB_WIDTH := 58.0
const TAB_OTHER := Color(0.6, 0.6, 0.65)
const LIST_HEIGHT := 125.0
## Every tab's page height: down to just above the buttons. Lists that scroll
## on their own (key bindings, items) grow by EXTRA_PAGE to fill it.
const PAGE_HEIGHT := 176.0
const EXTRA_PAGE := PAGE_HEIGHT - (LIST_HEIGHT + 13.0)
## Room beside a page for its scrollbar, and the result line's two rows.
static var SCROLLBAR_ROOM := 8.0
static var NOTE_HEIGHT := 20.0
const WAITING := Color(0.4, 1, 0.4)

## The in-game developer console the Developer tab runs commands through, or
## null on the login screens.
var console: DevConsole

## The Developer tab is showing its item list instead of its commands.
var _item_list := false
## The Developer tab is showing its spell editor (a class's design file,
## SpellDesigns): the class's file name, the search, and the entry shown
## ("spell:<n>" for the nth spell group, "tree:<n>" for a talent tree,
## "enchant:<n>" for a profession's nth enchant).
var _spell_editor := false
var _edit_class := "man_at_arms"
var _edit_filter := ""
var _edit_entry := ""
var _item_filter := ""
## The item search's filters and sort (kept while the window is open):
## category (ITEM_CATEGORIES), type and slot within it ("" for any), quality
## (-1 for any), sort (ITEM_SORTS), its direction, and usable gear only.
var _item_category := "All"
var _item_type := ""
var _item_slot := ""
var _item_quality := -1
var _item_sort := "Name"
var _item_sort_down := false
var _item_usable := false
## Item classes by category; "Other" is everything not named here.
const ITEM_CATEGORIES := {
	"All": [], "Weapons": [2], "Armor": [4], "Consumables": [0], "Containers": [1, 11],
	"Trade Goods": [7], "Recipes": [9], "Quest Items": [12], "Other": [],
}
const ITEM_SORTS := ["Name", "Required Level", "Item Level", "Quality", "Item ID"]
const QUALITY_NAMES := ["Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary"]
## Weapon subclasses with their hands (the rest are ItemDB.WEAPON_TYPES).
const WEAPON_TYPE_NAMES := {
	0: "One-Handed Axe", 1: "Two-Handed Axe", 4: "One-Handed Mace", 5: "Two-Handed Mace",
	7: "One-Handed Sword", 8: "Two-Handed Sword",
}
const ARMOR_TYPE_NAMES := { 0: "Miscellaneous", 1: "Cloth", 2: "Leather", 3: "Mail", 4: "Plate", 5: "Buckler", 6: "Shield" }
const CONSUMABLE_TYPE_NAMES := {
	0: "Food & Drink", 1: "Potion", 2: "Elixir", 3: "Flask", 4: "Scroll", 5: "Food", 6: "Item Enhancement", 7: "Bandage",
}
var _item_tooltip: ItemTooltip

var _category := "Video"
## Options changed in the window but not yet applied: key -> value.
var _pending: Dictionary = {}
## The key bindings as edited in the window, applied with the rest.
var _keys: Dictionary = {}
var _apply_button: Button
var _ui_scale := 1.0
## The key being rebound: [action, slot], or [] when not waiting for a key.
var _binding := []
## A modifier key pressed while waiting for a key, bound if let go alone.
var _modifier_down := 0
var _note: Label
## The Key Bindings tab's buttons by action, [first key, second key], updated
## in place so the list keeps its scroll position.
var _key_buttons: Dictionary


func open(category := "Video") -> void:
	_category = category
	_pending.clear()
	_live_before.clear()
	_keys = Settings.snapshot_keys()
	_binding = []
	visible = true
	_build()


## Switches tab. Changes on other tabs stay until Okay or Cancel.
func show_tab(category: String) -> void:
	_category = category
	_item_list = false
	_spell_editor = false
	_binding = []
	_build()


## Applies and saves every changed option.
func apply() -> void:
	var rebuild := _pending.has("ui_scale")
	for key: String in _pending:
		Settings.set_value(key, _pending[key])
	_pending.clear()
	_live_before.clear()
	if _keys != Settings.snapshot_keys():
		Settings.set_value("keys", _keys.duplicate(true))
	Settings.save()
	# A new UI Scale resizes this window too.
	if rebuild and visible:
		_build()
	_update_apply()


func okay() -> void:
	apply()
	_close()


## Drops what wasn't applied. Esc first closes the reset confirmation.
func cancel() -> void:
	if close_confirm():
		return
	_pending.clear()
	for key: String in _live_before:
		Settings.set_value(key, _live_before[key])
	# Moving the window saves the options; saved again so a live preview
	# that was cancelled isn't kept on disk.
	if not _live_before.is_empty():
		Settings.save()
	_live_before.clear()
	_close()


func _exit_tree() -> void:
	close_confirm()


func defaults() -> void:
	if _category == KEY_BINDINGS:
		_keys = Settings.default_keys()
	elif _category == TUNING:
		_set_tuning({})
	else:
		for row: Array in CATEGORIES[_category]:
			_set_pending(row[0], Settings.default_value(row[0]))
	_binding = []
	_build()


## An option as shown in the window: changed but not applied, or its setting.
func _value(key: String) -> Variant:
	return _pending.get(key, Settings.get_value(key))


func _set_pending(key: String, value: Variant) -> void:
	if Settings.get_value(key) == value:
		_pending.erase(key)
	else:
		_pending[key] = value
	_update_apply()


func _has_changes() -> bool:
	return not _pending.is_empty() or _keys != Settings.snapshot_keys()


func _update_apply() -> void:
	if _apply_button and is_instance_valid(_apply_button):
		_apply_button.disabled = not _has_changes()


## While waiting for a key, the next key or bindable mouse button pressed is
## the binding, with the Shift, Ctrl and Alt held (Shift-1). Left and right
## clicks still work the window.
func _input(event: InputEvent) -> void:
	_release_text_focus(event)
	if not visible or _binding.is_empty():
		return
	var code := 0
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key and key.pressed and not key.echo:
		if int(key.physical_keycode) in Settings.MODIFIER_KEYS:
			# Shift, Ctrl or Alt alone binds when let go without another key;
			# with one, it's that key's modifier (Shift-1).
			_modifier_down = int(key.physical_keycode)
			get_viewport().set_input_as_handled()
			return
		code = Settings.binding_of(key)
	elif key and not key.pressed and int(key.physical_keycode) == _modifier_down:
		code = _modifier_down
	elif mouse and mouse.pressed and mouse.button_index in Settings.BINDABLE_MOUSE:
		code = Settings.binding_of(mouse)
	if code == 0:
		return
	_modifier_down = 0
	get_viewport().set_input_as_handled()
	var action: String = _binding[0]
	var slot: int = _binding[1]
	_binding = []
	var note := ""
	if code == KEY_ESCAPE:
		note = ""
	elif Settings.is_reserved(code):
		note = "%s can't be bound." % Settings.key_name(code)
	else:
		var taken_from := Settings.bind_in(_keys, action, slot, code)
		_update_apply()
		if not taken_from.is_empty():
			note = "%s unbound from %s." % [Settings.key_name(code), taken_from]
	_refresh_keys()
	_note.text = note


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		var keys: Array = _keys.get(action, [0, 0])
		for slot in 2:
			var button: Button = _key_buttons[action][slot]
			if not is_instance_valid(button):
				continue
			var waiting := _binding == [action, slot]
			button.text = "Press a key" if waiting else Settings.key_name(int(keys[slot]))
			if waiting:
				button.add_theme_color_override("font_color", WAITING)
			else:
				button.remove_theme_color_override("font_color")


func _close() -> void:
	close_confirm()
	_binding = []
	_item_list = false
	_spell_editor = false
	if _item_tooltip:
		_item_tooltip.show_item({})
	visible = false
	closed.emit()


func _build() -> void:
	# Scaled when opened, not while the UI Scale slider is dragged.
	_ui_scale = Settings.hud_scale(get_viewport_rect().size.y)
	for child in get_children():
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.082, 0.1, 0.96)
	style.border_color = UiStyle.GOLD
	style.set_border_width_all(maxi(roundi(_ui_scale / 2), 1))
	style.set_corner_radius_all(roundi(UiStyle.ROUNDING * _ui_scale / 2.0))
	style.set_content_margin_all(6 * _ui_scale)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	add_child(box)
	var title := _label("Options", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Drag the title to move the window.
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	title.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title.gui_input.connect(_on_title_input)
	box.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", roundi(6 * _ui_scale))
	box.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	tabs.custom_minimum_size.x = TAB_WIDTH * _ui_scale
	body.add_child(tabs)
	# Release builds have no Developer tab.
	for tab: String in TABS.filter(func(t: String) -> bool: return not t in DEVELOPER_TABS or Settings.developer_tools()):
		var button := _button(tab, show_tab.bind(tab))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var selected := tab == _category
		button.add_theme_color_override("font_color", TAB_SELECTED if selected else TAB_OTHER)
		button.add_theme_color_override("font_hover_color", TAB_SELECTED)
		if selected:
			button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
		tabs.add_child(button)
	# Every tab gets the same space, so the window is always one size; longer
	# pages scroll.
	var page := ScrollContainer.new()
	page.custom_minimum_size = Vector2(WIDTH + 30 + SCROLLBAR_ROOM, PAGE_HEIGHT) * _ui_scale
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(page)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	content.custom_minimum_size.x = (WIDTH + 30) * _ui_scale
	page.add_child(content)
	# Results sit between Defaults and Apply: two lines, cut short beyond
	# that, so they can't stretch the window.
	_note = _label("", ERROR_COLOR)
	_note.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.max_lines_visible = 2
	_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.custom_minimum_size = Vector2(10, NOTE_HEIGHT) * _ui_scale
	if _category == KEY_BINDINGS:
		_build_keys(content)
	elif _category == TUNING:
		_build_tuning(content)
	elif not (_category == DEVELOPER and (_item_list or _spell_editor)):
		# The item search has the page to itself (no console or cape options).
		for row: Array in CATEGORIES[_category]:
			content.add_child(_row(row))
	if _category == DEVELOPER:
		_build_developer(content)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	box.add_child(buttons)
	buttons.add_child(_button("Defaults", defaults))
	buttons.add_child(_note)
	_apply_button = _button("Apply", apply)
	buttons.add_child(_apply_button)
	_update_apply()
	buttons.add_child(_button("Okay", okay))
	buttons.add_child(_button("Cancel", cancel))
	reset_size()
	_place.call_deferred()


## In the middle of the screen, moved by where it was last dragged to
## (the options_window_offset option), kept on screen.
func _place() -> void:
	var screen := get_viewport_rect().size
	var middle := (screen - size) / 2
	var offset: Vector2 = Settings.get_value("options_window_offset")
	position = (middle + offset).clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))


func _on_title_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_moving = button.pressed
		if not button.pressed:
			# Saved at once: it isn't one of the changes waiting for Apply.
			Settings.save()
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion and _moving:
		var offset: Vector2 = Settings.get_value("options_window_offset")
		var screen := get_viewport_rect().size
		# Only as far as keeps it on screen.
		var wanted := (position + motion.relative).clamp(Vector2.ZERO, (screen - size).max(Vector2.ZERO))
		offset += wanted - position
		position = wanted
		Settings.set_value("options_window_offset", offset)
		accept_event()


## Developer commands, run through the console as soon as they're used (Cancel
## doesn't undo them): god mode, run speed, one-click commands, and a line for
## any console command.
func _build_developer(content: VBoxContainer) -> void:
	if console == null or console.player() == null:
		var away := _label("The commands work once you're in the world.", Color(0.7, 0.7, 0.7))
		away.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		away.custom_minimum_size.x = (WIDTH + 30) * _ui_scale
		content.add_child(away)
		return
	if _item_list:
		_build_item_list(content)
		return
	if _spell_editor:
		_build_spell_editor(content)
		return
	var player := console.player()
	var god := HBoxContainer.new()
	var god_label := _label("God Mode (take no damage)", TEXT)
	god_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	god.add_child(god_label)
	var god_check := CheckBox.new()
	style_check(god_check, _ui_scale)
	god_check.button_pressed = player.combatant.invulnerable
	god_check.toggled.connect(func(on: bool) -> void:
		if on != player.combatant.invulnerable:
			_show_result(console.run("god"))
	)
	god.add_child(god_check)
	content.add_child(god)
	var speed := HBoxContainer.new()
	var speed_label := _label("Run Speed", TEXT)
	speed_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed.add_child(speed_label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(60, 10) * _ui_scale
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = 1.0
	slider.max_value = 5.0
	slider.step = 0.5
	slider.value = player.speed_scale
	var shown := _label("x%.1f" % player.speed_scale, TEXT)
	shown.custom_minimum_size.x = 22 * _ui_scale
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		shown.text = "x%.1f" % value
		_show_result(console.run("speed %.1f" % value))
	)
	speed.add_child(slider)
	speed.add_child(shown)
	content.add_child(speed)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", roundi(3 * _ui_scale))
	grid.add_theme_constant_override("v_separation", roundi(3 * _ui_scale))
	for entry: Array in DEV_BUTTONS:
		var command: String = entry[1]
		var button := _button(entry[0], func() -> void:
			var line := command
			if command == "level+":
				# The targeted playerbot's next level, else the player's.
				var bot := console.player().targeting.target as Bot
				line = "level %d" % ((bot.profile.level if bot else GameState.level) + 1)
			_show_result(console.run(line))
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	content.add_child(grid)
	content.add_child(_spawn_row(console))
	_profession_rows(content, console)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	var field := LineEdit.new()
	field.placeholder_text = "Any command, e.g. additem 2589 5"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	# No walking while typing here.
	field.focus_entered.connect(func() -> void: player.typing = true)
	field.focus_exited.connect(func() -> void: player.typing = false)
	var run := func(_text := "") -> void:
		if not field.text.strip_edges().is_empty():
			_show_result(console.run(field.text.strip_edges()))
			field.clear()
	field.text_submitted.connect(run)
	row.add_child(field)
	row.add_child(_button("Run", run))
	content.add_child(row)
	var pages := HBoxContainer.new()
	pages.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	for page: Array in [["Add Items...", "items"], ["Edit Spells...", "spells"]]:
		var which: String = page[1]
		var open := _button(page[0], func() -> void:
			_item_list = which == "items"
			_spell_editor = which == "spells"
			_note.text = ""
			_build()
		)
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pages.add_child(open)
	content.add_child(pages)
	var reset := _button("Reset Character...", _confirm_reset)
	reset.add_theme_color_override("font_color", ERROR_COLOR)
	content.add_child(reset)


## "Spawn Enemy": a level and a rank, and a button that runs the console's
## "spawn" (a random creature ahead, just outside its aggro range). The level
## starts at the player's; both are kept while the window is open.
func _spawn_row(console: DevConsole) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	var label := _label("Spawn Enemy", TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_label("Level", TEXT))
	var level := SpinBox.new()
	level.min_value = 1
	level.max_value = ClassicData.MAX_LEVEL + 3
	level.value = _spawn_level if _spawn_level > 0 else GameState.level
	level.custom_minimum_size.x = 34 * _ui_scale
	level.get_line_edit().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	var player := console.player()
	level.get_line_edit().focus_entered.connect(func() -> void: player.typing = true)
	level.get_line_edit().focus_exited.connect(func() -> void: player.typing = false)
	level.value_changed.connect(func(value: float) -> void: _spawn_level = int(value))
	row.add_child(level)
	var rank := OptionButton.new()
	rank.custom_minimum_size.x = 46 * _ui_scale
	rank.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	rank.get_popup().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	for choice: String in SPAWN_RANKS:
		rank.add_item(choice)
	rank.select(_spawn_rank)
	rank.item_selected.connect(func(index: int) -> void: _spawn_rank = index)
	row.add_child(rank)
	row.add_child(_button("Spawn", func() -> void:
		_show_result(console.run("spawn %d %s" % [int(level.value), SPAWN_RANKS[_spawn_rank].to_lower()]))))
	return row


## The Developer tab's Professions rows: a profession to Learn (a rank at a
## time) or Unlearn, its skill on a slider applied as it moves, and Max
## Skills, Learn Recipes and Give Tools. They act on the targeted playerbot
## when one is targeted, as the console's commands do.
var _dev_profession := 0


func _profession_rows(content: VBoxContainer, console: DevConsole) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	var label := _label("Professions", TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var pick := OptionButton.new()
	pick.custom_minimum_size.x = 58 * _ui_scale
	pick.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	pick.get_popup().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	for name: String in ProfessionDB.NAMES:
		pick.add_item(Professions.title(name))
	pick.select(_dev_profession)
	row.add_child(pick)
	var chosen := func() -> String: return ProfessionDB.NAMES[pick.selected]
	var slider := HSlider.new()
	slider.min_value = 1
	slider.max_value = 300
	slider.custom_minimum_size.x = 60 * _ui_scale
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var skill_label := _label("", TEXT)
	skill_label.custom_minimum_size.x = 18 * _ui_scale
	# The slider shows the picked profession's skill, without running anything.
	var show_skill := func() -> void:
		var profile: CharacterProfile = console.player().targeting.target.profile if console.player().targeting.target is Bot else GameState
		slider.set_value_no_signal(maxi(Professions.pure_value(profile, chosen.call()), 1))
		skill_label.text = str(Professions.pure_value(profile, chosen.call()))
	pick.item_selected.connect(func(index: int) -> void:
		_dev_profession = index
		show_skill.call())
	row.add_child(_button("Learn", func() -> void:
		_show_result(console.run("profession %s" % chosen.call()))
		show_skill.call()))
	row.add_child(_button("Unlearn", func() -> void:
		_show_result(console.run("unlearnprofession %s" % chosen.call()))
		show_skill.call()))
	slider.value_changed.connect(func(value: float) -> void:
		skill_label.text = str(int(value))
		_show_result(console.run("skill %s %d" % [chosen.call(), int(value)])))
	row.add_child(slider)
	row.add_child(skill_label)
	show_skill.call()
	content.add_child(row)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	for entry: Array in [["Max Skills", "maxprofessions"], ["Learn Recipes", "learnrecipes"], ["Give Tools", "proftools"],
			["Spawn Herb", "nodes herb"], ["Spawn Ore", "nodes ore"], ["Respawn Nodes", "respawnnodes"]]:
		var command: String = entry[1]
		var button := _button(entry[0], func() -> void:
			_show_result(console.run(command))
			show_skill.call())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	content.add_child(buttons)


## Asks before starting the character over (the console's "reset confirm").
func _confirm_reset() -> void:
	close_confirm()
	_confirm = ColorRect.new()
	# Over the whole screen, dimming it: beside the window rather than in it,
	# so it doesn't stretch the window's layout.
	_confirm.color = Color(0, 0, 0, 0.5)
	_confirm.size = get_viewport_rect().size
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(_confirm)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.082, 0.1, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(maxi(roundi(_ui_scale / 2), 1))
	style.set_corner_radius_all(roundi(UiStyle.ROUNDING * _ui_scale / 2.0))
	style.set_content_margin_all(8 * _ui_scale)
	panel.add_theme_stylebox_override("panel", style)
	_confirm.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(6 * _ui_scale))
	panel.add_child(box)
	var title := _label("Reset %s?" % GameState.char_name, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var text := _label("%s starts over at level 1, keeping name, race and class. All items, money, quests, spells and experience are lost. This can't be undone." % GameState.char_name, TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 150 * _ui_scale
	box.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", roundi(6 * _ui_scale))
	var yes := _button("Reset", func() -> void:
		close_confirm()
		_show_result(console.run("reset confirm"))
	)
	yes.add_theme_color_override("font_color", ERROR_COLOR)
	buttons.add_child(yes)
	buttons.add_child(_button("Cancel", close_confirm))
	box.add_child(buttons)
	# Centered once its size is known.
	panel.resized.connect(func() -> void: panel.position = (_confirm.size - panel.size) / 2.0)


## Closes the reset confirmation, if open. Returns whether it was.
func close_confirm() -> bool:
	if _confirm == null or not is_instance_valid(_confirm):
		return false
	_confirm.queue_free()
	_confirm = null
	return true


## Every item in the game, searchable by name. Click one to put it in the bags;
## Shift-click adds a full stack. Hover for its tooltip.
## The spell editor: a class's design (data/designs, SpellDesigns) as the
## game has it, a spell group or talent tree at a time as JSON, the fields
## in docs/spells/FIELDS.md. Apply reads the changed design over the spell
## data at once (unsaved; Revert drops it), Save writes the file.
func _build_spell_editor(content: VBoxContainer) -> void:
	var player := console.player()
	var small := roundi((FONT_SIZE - 1) * _ui_scale)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	top.add_child(_button("< Back", func() -> void:
		_spell_editor = false
		_note.text = ""
		_build()
	))
	var classes := OptionButton.new()
	classes.add_theme_font_size_override("font_size", small)
	# The classes, then the professions.
	for spec: Array in SpellDesigns.all_files():
		var label := str(ClassicData.CLASS_NAMES.get(int(spec[0]), "")) if int(spec[0]) != 0 else str(spec[1]).capitalize()
		classes.add_item(label)
		classes.set_item_metadata(classes.item_count - 1, str(spec[2]))
		if str(spec[2]) == _edit_class:
			classes.select(classes.item_count - 1)
	classes.item_selected.connect(func(index: int) -> void:
		_edit_class = str(classes.get_item_metadata(index))
		_edit_entry = ""
		_build.call_deferred()
	)
	top.add_child(classes)
	var search := LineEdit.new()
	search.placeholder_text = "Search spells and talents"
	search.text = _edit_filter
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", small)
	search.focus_entered.connect(func() -> void: player.typing = true)
	search.focus_exited.connect(func() -> void: player.typing = false)
	top.add_child(search)
	content.add_child(top)
	var entries := ItemList.new()
	entries.custom_minimum_size = Vector2(WIDTH + 30, 52) * _ui_scale
	entries.add_theme_font_size_override("font_size", small)
	content.add_child(entries)
	# Line numbers down the left, as Apply Live's errors give a line.
	var text := CodeEdit.new()
	text.gutters_draw_line_numbers = true
	text.gutters_zero_pad_line_numbers = false
	text.add_theme_color_override("line_number_color", Color(0.55, 0.5, 0.4))
	# The game's theme styles TextEdit; a CodeEdit takes the same frame.
	for box in ["normal", "focus", "read_only"]:
		text.add_theme_stylebox_override(box, UiStyle.theme().get_stylebox(box, "TextEdit"))
	text.custom_minimum_size = Vector2(WIDTH + 30, LIST_HEIGHT - 86 + EXTRA_PAGE) * _ui_scale
	text.add_theme_font_size_override("font_size", small)
	text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	text.placeholder_text = "Pick a spell or a talent tree."
	text.focus_entered.connect(func() -> void: player.typing = true)
	text.focus_exited.connect(func() -> void: player.typing = false)
	content.add_child(text)
	# The list: spell groups by name with their ids, then the talent trees.
	var fill := func() -> void:
		entries.clear()
		var design := SpellDesigns.design_of(_edit_class)
		var words := _edit_filter.strip_edges().to_lower()
		var groups: Array = design.get("spells", [])
		# A profession's enchants name the spells they cast or keep up
		# (Crusader's Holy Strength), so searching an enchant finds them.
		var cast_by := {}
		for enchant: Dictionary in design.get("enchants", []):
			for effect: Dictionary in enchant.get("effects", []):
				if effect.has("spell"):
					cast_by.get_or_add(int(effect.spell), []).append(str(enchant.get("name", "")))
		for i in groups.size():
			var group: Dictionary = groups[i]
			var ids: Array[String] = []
			var by: Array = []
			for rank: Dictionary in group.get("ranks", []):
				ids.append(str(int(rank.get("id", 0))))
				by.append_array(cast_by.get(int(rank.get("id", 0)), []))
			var label := "%s  (%s)%s" % [group.get("name", "?"), ", ".join(ids), "  - " + ", ".join(by) + " enchant" if not by.is_empty() else ""]
			if words.is_empty() or words in label.to_lower():
				entries.add_item(label)
				entries.set_item_metadata(entries.item_count - 1, "spell:%d" % i)
		var trees: Array = design.get("talents", [])
		for i in trees.size():
			var label := "Talents: %s" % trees[i].get("name", "?")
			if words.is_empty() or words in label.to_lower():
				entries.add_item(label)
				entries.set_item_metadata(entries.item_count - 1, "tree:%d" % i)
		# A profession's item enchants (what they give, proc rates), after.
		var enchants: Array = design.get("enchants", [])
		for i in enchants.size():
			var label := "Enchant: %s  (%d)" % [enchants[i].get("name", "?"), int(enchants[i].get("id", 0))]
			if words.is_empty() or words in label.to_lower():
				entries.add_item(label)
				entries.set_item_metadata(entries.item_count - 1, "enchant:%d" % i)
		for n in entries.item_count:
			if entries.get_item_metadata(n) == _edit_entry:
				entries.select(n)
				entries.ensure_current_is_visible.call_deferred()
	var show_entry := func() -> void:
		var shown: Variant = _design_entry(SpellDesigns.design_of(_edit_class), _edit_entry)
		text.text = "" if shown == null else JSON.stringify(SpellDesigns.whole(shown), "\t", false)
	fill.call()
	show_entry.call()
	search.text_changed.connect(func(value: String) -> void:
		_edit_filter = value
		fill.call()
	)
	entries.item_selected.connect(func(index: int) -> void:
		_edit_entry = str(entries.get_item_metadata(index))
		show_entry.call()
	)
	# Apply: the text over the shown entry, the design read over the spells.
	var apply := func() -> bool:
		if _edit_entry.is_empty():
			_show_result("!Pick a spell or a talent tree first.")
			return false
		var json := JSON.new()
		if json.parse(text.text) != OK:
			_show_result("!Line %d: %s" % [json.get_error_line() + 1, json.get_error_message()])
			return false
		if not json.data is Dictionary:
			_show_result("!The entry must be a { ... } object.")
			return false
		var design: Dictionary = SpellDesigns.design_of(_edit_class).duplicate(true)
		var parts := _edit_entry.split(":")
		var list: Array = design.get(EDIT_SECTIONS.get(parts[0], "spells"), [])
		list[int(parts[1])] = json.data
		SpellDesigns.edited[_edit_class] = design
		var warnings := SpellDB.reload_designs()
		GameState.spells_changed.emit()
		fill.call()
		if warnings.is_empty():
			# The first rank's tooltip as it now reads.
			var ranks: Array = (json.data as Dictionary).get("ranks", [])
			var tip := ""
			if not ranks.is_empty() and ranks[0] is Dictionary:
				tip = SpellText.describe(SpellDB.get_spell(int(ranks[0].get("id", 0))), GameState.level)
			_show_result("Applied (not saved yet)." + ("" if tip.is_empty() else " Tooltip: " + tip))
		else:
			_show_result("!" + "; ".join(warnings))
		return true
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	for entry: Array in [["Apply Live", "apply"], ["Save", "save"], ["Revert", "revert"], ["New Spell", "new"],
			["Fill Text", "text"]]:
		var what: String = entry[1]
		var button := _button(entry[0], func() -> void:
			match what:
				"apply":
					apply.call()
				"save":
					if not text.text.strip_edges().is_empty() and not apply.call():
						return
					var error := SpellDesigns.save(_edit_class)
					if error.is_empty():
						SpellDesigns.edited.erase(_edit_class)
						_show_result("Saved to data/designs/%s.json." % _edit_class)
					else:
						_show_result("!" + error)
				"revert":
					SpellDesigns.edited.erase(_edit_class)
					var warnings := SpellDB.reload_designs()
					GameState.spells_changed.emit()
					fill.call()
					show_entry.call()
					_show_result("Back to the saved file." if warnings.is_empty() else "!" + "; ".join(warnings))
				"new":
					var design: Dictionary = SpellDesigns.design_of(_edit_class).duplicate(true)
					var spells: Array = design.get("spells", [])
					spells.append(_new_spell_group(SpellDesigns.free_spell_id(), _edit_class))
					design.spells = spells
					SpellDesigns.edited[_edit_class] = design
					_edit_entry = "spell:%d" % (spells.size() - 1)
					_edit_filter = ""
					search.text = ""
					fill.call()
					show_entry.call()
					_show_result("New spell added; change it, then Apply.")
				"text":
					_fill_tooltip_text(text)
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	content.add_child(buttons)


## Fill Text: gives each rank in the editor's text without a `text` of its
## own the tooltip it shows now (at the player's level), to change from there.
## Nothing is applied until Apply Live.
func _fill_tooltip_text(text: TextEdit) -> void:
	var json := JSON.new()
	if json.parse(text.text) != OK or not json.data is Dictionary or not (json.data as Dictionary).has("ranks"):
		_show_result("!Pick a spell (with valid text) first.")
		return
	var group: Dictionary = json.data
	var filled := 0
	for rank: Variant in group.ranks:
		if not rank is Dictionary or (rank as Dictionary).has("text"):
			continue
		var tip := SpellText.describe(SpellDB.get_spell(int(rank.get("id", 0))), GameState.level)
		if not tip.is_empty():
			rank.text = tip
			filled += 1
	text.text = JSON.stringify(SpellDesigns.whole(group), "\t", false)
	if filled == 0:
		_show_result("Every rank already has its own text.")
	else:
		_show_result("Filled %d rank%s' text. Put {amount1}, {duration}... for numbers that follow the spell (docs/spells/FIELDS.md), then Apply Live." % [filled, "" if filled == 1 else "s"])


## The spell group ("spell:<n>") or talent tree ("tree:<n>") of a design, or
## null.
## The editor's entry kinds and the design sections they're in.
const EDIT_SECTIONS := { "spell": "spells", "tree": "talents", "enchant": "enchants" }


func _design_entry(design: Dictionary, entry: String) -> Variant:
	var parts := entry.split(":")
	if parts.size() != 2:
		return null
	var list: Array = design.get(EDIT_SECTIONS.get(parts[0], "spells"), [])
	var n := int(parts[1])
	return list[n] if n >= 0 and n < list.size() else null


## A new spell to fill in: one rank of a fire bolt, taught at level 1 for
## nothing, in the General tab of the spellbook.
func _new_spell_group(id: int, file: String) -> Dictionary:
	var rank := { "id": id, "name": "New Spell", "rank": 1, "level": 1, "school": "fire", "damage_class": "magic",
		"cost": 10, "cast": 1.5, "range": 30, "gcd": 1.5, "speed": 20,
		"text": "Hurls a bolt of fire at the enemy for 10 to 14 fire damage.",
		"effects": [{ "type": "school_damage", "value": [10, 14], "target": "enemy" }],
		"trainer": { "level": 1, "price": 0 }, "book_tab": 0 }
	if file == "man_at_arms":
		rank.power = "rage"
	return { "name": "New Spell", "ranks": [rank] }


func _build_item_list(content: VBoxContainer) -> void:
	if _item_tooltip == null:
		_item_tooltip = ItemTooltip.new()
		_item_tooltip.setup(_ui_scale)
		# Over the window, wherever the mouse is.
		_item_tooltip.top_level = true
		_item_tooltip.z_index = 10
		add_sibling.call_deferred(_item_tooltip)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	top.add_child(_button("< Back", func() -> void:
		_item_list = false
		_item_tooltip.show_item({})
		_build()
	))
	var search := LineEdit.new()
	search.placeholder_text = "Search items"
	search.text = _item_filter
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	var player := console.player()
	search.focus_entered.connect(func() -> void: player.typing = true)
	search.focus_exited.connect(func() -> void: player.typing = false)
	top.add_child(search)
	content.add_child(top)
	# Filters: category, then its type and slot; quality, sort and its
	# direction, and usable gear only. A new category rebuilds the list's
	# choices; the rest refill it.
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	content.add_child(filters)
	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	content.add_child(more)
	var scroll := ScrollContainer.new()
	# Short enough that the page itself needn't scroll as well.
	scroll.custom_minimum_size = Vector2(WIDTH + 30, LIST_HEIGHT - 42 + EXTRA_PAGE) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.custom_minimum_size.x = (WIDTH + 22) * _ui_scale
	scroll.add_child(list)
	var count := _label("", Color(0.6, 0.6, 0.65))
	count.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	var fill := func() -> void:
		for child in list.get_children():
			child.queue_free()
		var matching := _items_matching(_item_filter)
		for item: Dictionary in matching:
			list.add_child(_item_row(item))
		count.text = "%d items" % matching.size()
	filters.add_child(_filter_menu(ITEM_CATEGORIES.keys().map(func(c: String) -> Array: return [c, c]), _item_category,
		func(value) -> void:
			_item_category = value
			_item_type = ""
			_item_slot = ""
			_build()))
	var types := _item_types(_item_category)
	if not types.is_empty():
		filters.add_child(_filter_menu([["Any Type", ""]] + types, _item_type, func(value) -> void:
			_item_type = value
			fill.call()))
	var slots := _item_slots(_item_category)
	if not slots.is_empty():
		filters.add_child(_filter_menu([["Any Slot", ""]] + slots, _item_slot, func(value) -> void:
			_item_slot = value
			fill.call()))
	var qualities := [["Any Quality", -1]]
	for i in QUALITY_NAMES.size():
		qualities.append([QUALITY_NAMES[i], i])
	more.add_child(_filter_menu(qualities, _item_quality, func(value) -> void:
		_item_quality = value
		fill.call()))
	more.add_child(_filter_menu(ITEM_SORTS.map(func(sort: String) -> Array: return ["Sort: " + sort, sort]), _item_sort,
		func(value) -> void:
			_item_sort = value
			fill.call()))
	var direction := Button.new()
	direction.text = "v" if _item_sort_down else "^"
	direction.custom_minimum_size = Vector2(14, 13) * _ui_scale
	direction.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	direction.tooltip_text = "Sort ascending or descending"
	direction.pressed.connect(func() -> void:
		_item_sort_down = not _item_sort_down
		direction.text = "v" if _item_sort_down else "^"
		fill.call())
	more.add_child(direction)
	var usable := CheckBox.new()
	usable.text = "Usable"
	usable.tooltip_text = "Only gear your class can use (any level)"
	usable.button_pressed = _item_usable
	usable.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	style_check(usable, _ui_scale)
	usable.toggled.connect(func(on: bool) -> void:
		_item_usable = on
		fill.call())
	more.add_child(usable)
	more.add_child(count)
	search.text_changed.connect(func(text: String) -> void:
		_item_filter = text
		fill.call()
	)
	fill.call()
	search.grab_focus.call_deferred()
	search.caret_column = search.text.length()


func _items_matching(filter: String) -> Array:
	ItemDB.get_item(0)
	var query := filter.strip_edges().to_lower()
	var matching := ItemDB._items.values().filter(func(item: Dictionary) -> bool:
		if not (query.is_empty() or str(item.name).to_lower().contains(query) or str(int(item.entry)) == query):
			return false
		if not _in_category(item, _item_category):
			return false
		if _item_type != "" and _item_type_key(item) != _item_type:
			return false
		if _item_slot != "" and _item_slot_name(item) != _item_slot:
			return false
		if _item_quality >= 0 and int(item.get("Quality", 1)) != _item_quality:
			return false
		if _item_usable and not _usable(item):
			return false
		return true
	)
	var key := func(item: Dictionary) -> Variant:
		match _item_sort:
			"Required Level":
				return int(item.get("RequiredLevel", 0))
			"Item Level":
				return int(item.get("ItemLevel", 0))
			"Quality":
				return int(item.get("Quality", 1))
			"Item ID":
				return int(item.entry)
		return str(item.name).to_lower()
	matching.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka = key.call(a)
		var kb = key.call(b)
		if ka == kb:
			return str(a.name) < str(b.name)
		return (ka > kb) if _item_sort_down else (ka < kb))
	return matching


## Whether an item is in a category of ITEM_CATEGORIES.
func _in_category(item: Dictionary, category: String) -> bool:
	var item_class := int(item.get("class", 0))
	if category == "All":
		return true
	if category == "Other":
		for named: String in ITEM_CATEGORIES:
			if item_class in ITEM_CATEGORIES[named]:
				return false
		return true
	return item_class in ITEM_CATEGORIES[category]


## An item's type within its category, as the Type filter names it ("" for none).
func _item_type_key(item: Dictionary) -> String:
	var subclass := int(item.get("subclass", 0))
	match int(item.get("class", 0)):
		2:
			return WEAPON_TYPE_NAMES.get(subclass, ItemDB.WEAPON_TYPES.get(subclass, "Other"))
		4:
			return ARMOR_TYPE_NAMES.get(subclass, "Other")
		0:
			return CONSUMABLE_TYPE_NAMES.get(subclass, "Other")
	return ""


## The slot an item is worn in, as the Slot filter names it ("" for none).
func _item_slot_name(item: Dictionary) -> String:
	return ItemDB.SLOT_NAMES.get(int(item.get("InventoryType", 0)), "")


## The Type filter's choices for a category: the types its items have.
func _item_types(category: String) -> Array:
	if not category in ["Weapons", "Armor", "Consumables"]:
		return []
	var found := {}
	for item: Dictionary in ItemDB._items.values():
		if _in_category(item, category):
			found[_item_type_key(item)] = true
	var names := found.keys()
	names.sort()
	return names.map(func(n: String) -> Array: return [n, n])


## The Slot filter's choices for a category: the slots its items go in.
func _item_slots(category: String) -> Array:
	if not category in ["Weapons", "Armor"]:
		return []
	var found := {}
	for item: Dictionary in ItemDB._items.values():
		if _in_category(item, category) and _item_slot_name(item) != "":
			found[_item_slot_name(item)] = true
	var names := found.keys()
	names.sort()
	return names.map(func(n: String) -> Array: return [n, n])


## Gear the player's class can use at any level: allowed to its class, with
## the skill for it (everything else counts as usable).
func _usable(item: Dictionary) -> bool:
	var mask := int(item.get("AllowableClass", -1))
	if mask > 0 and mask & (1 << (GameState.char_class - 1)) == 0:
		return false
	return Inventory.has_proficiency(item)


## A dropdown of [label, value] choices with `selected` chosen; calls back
## with the value picked.
func _filter_menu(choices: Array, selected: Variant, picked: Callable) -> OptionButton:
	var menu := OptionButton.new()
	menu.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	menu.get_popup().add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for choice: Array in choices:
		menu.add_item(str(choice[0]))
	var at := 0
	for i in choices.size():
		if choices[i][1] == selected:
			at = i
	menu.select(at)
	menu.item_selected.connect(func(index: int) -> void: picked.call(choices[index][1]))
	return menu


func _item_row(item: Dictionary) -> Control:
	var row := ColorRect.new()
	row.color = Color.TRANSPARENT
	row.custom_minimum_size = Vector2(WIDTH + 22, 11) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var quality := ItemDB.quality_color(item)
	var icon := ColorRect.new()
	icon.color = quality.darkened(0.6)
	icon.position = Vector2(1, 1) * _ui_scale
	icon.size = Vector2.ONE * 9 * _ui_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	UiStyle.item_icon(icon, item, _ui_scale)
	var title := _label(str(item.name), quality)
	title.position = Vector2(13, -1) * _ui_scale
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	var id := _label(str(int(item.entry)), Color(0.5, 0.5, 0.55))
	id.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 2) * _ui_scale))
	id.position = Vector2(WIDTH + 2, 1) * _ui_scale
	id.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(id)
	row.mouse_entered.connect(func() -> void:
		row.color = Color(1, 1, 1, 0.08)
		_item_tooltip.show_item(item)
	)
	row.mouse_exited.connect(func() -> void:
		row.color = Color.TRANSPARENT
		_item_tooltip.show_item({})
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			var count := maxi(int(item.get("stackable", 1)), 1) if click.shift_pressed else 1
			_show_result(console.run("additem %d %d" % [int(item.entry), count]))
			Sfx.play("loot")
	)
	return row


## Shows a command's result under the tab: green, or orange for an error.
func _show_result(result: String) -> void:
	if not is_instance_valid(_note):
		return
	var error := result.begins_with("!")
	_note.text = result.substr(1) if error else result
	_note.add_theme_color_override("font_color", ERROR_COLOR if error else RESULT)


## Every rebindable action by section, with its two keys.
func _build_keys(box: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(WIDTH + 30, LIST_HEIGHT + EXTRA_PAGE) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	list.custom_minimum_size.x = (WIDTH + 22) * _ui_scale
	scroll.add_child(list)
	_key_buttons = {}
	var section := ""
	for entry: Array in Settings.ACTIONS:
		if entry[2] != section:
			section = entry[2]
			list.add_child(_label(section, GOLD))
		var line := HBoxContainer.new()
		var label := _label("  " + entry[1], TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		var buttons := []
		for slot in 2:
			buttons.append(_key_button(entry[0], slot))
			line.add_child(buttons[slot])
		_key_buttons[entry[0]] = buttons
		list.add_child(line)
	_refresh_keys()
	var hint := _label("Click a slot, then press a key or mouse button 3-5. Right-click clears it.", Color(0.7, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = (WIDTH + 30) * _ui_scale
	hint.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	box.add_child(hint)


func _key_button(action: String, slot: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(52, 12) * _ui_scale
	button.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	button.clip_text = true
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
			_binding = []
			Settings.bind_in(_keys, action, slot, 0)
			_update_apply()
			_note.text = ""
			_refresh_keys()
	)
	button.pressed.connect(func() -> void:
		_binding = [action, slot]
		_modifier_down = 0
		_note.text = ""
		_refresh_keys()
	)
	return button


## What an option does, shown on hovering its row.
const HINTS := {
	"bags_display": "Combined: the backpack and every bag in one window. Separate: each bag its own frame, as classic's; right-click a bag slot to open or close that bag, B for all of them.",
	"render_resolution": "How many rows of pixels the world is drawn with: Low 270, Medium 405, High 540, Ultra 720. Lower is chunkier and faster.",
	"animation_quality": "How often characters and creatures further off move their limbs. Low animates distant ones less often; Ultra animates everyone within 35 yards every frame.",
	"character_detail": "How far away weapons, shields, hair, helms and capes are drawn: Low 15 yards, Medium 25, High 35, Ultra 70.",
	"character_shadows": "Off: characters cast no shadows. Normal: bodies and gear, not weapons or hair. Full: everything.",
	"cloak_physics": "Whether cloaks swing as their wearers move: for nobody, only you, or everyone.",
	"spell_effects": "Sparks, bursts and glows from attacks and spells. Low shows fewer, and only within 25 yards.",
	"light_shafts": "Sunlight streaming in through windows and doors, in the dusty air of buildings you can walk into. Drawn only in and near them; High shows crisp beams, Low softer ones for less.",
	"unit_detail_distance": "Within this distance (30, 45 or 70 yards) bots and creatures update every frame; beyond it they take turns, which saves time in crowds.",
	"distant_unit_updates": "How much of each frame goes to bots and creatures beyond the Unit Detail Distance. Higher keeps far ones livelier but costs frame rate.",
}


func _row(row: Array) -> Control:
	var key: String = row[0]
	var line := HBoxContainer.new()
	line.custom_minimum_size.x = WIDTH * _ui_scale
	var label := _label(row[1], TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if HINTS.has(key):
		line.tooltip_text = HINTS[key]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
	line.add_child(label)
	var value = _value(key)
	match row[2]:
		"check":
			var check := CheckBox.new()
			check.button_pressed = value
			style_check(check, _ui_scale)
			check.toggled.connect(func(on: bool) -> void: _set_pending(key, on))
			line.add_child(check)
		"monitor":
			# One entry per screen, found when the window opens.
			var options := OptionButton.new()
			options.custom_minimum_size.x = 80 * _ui_scale
			options.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
			options.get_popup().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
			for i in maxi(DisplayServer.get_screen_count(), 1):
				options.add_item("Monitor %d" % (i + 1))
			options.select(clampi(int(value), 0, options.item_count - 1))
			options.item_selected.connect(func(index: int) -> void: _set_pending(key, index))
			line.add_child(options)
		"choice", "fps":
			var options := OptionButton.new()
			options.custom_minimum_size.x = 80 * _ui_scale
			options.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
			options.get_popup().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
			var choices: Array = row[3]
			for choice in choices:
				var text := str(choice)
				if row[2] == "fps":
					text = "Unlimited" if int(choice) == 0 else "%d" % choice
				options.add_item(text)
			options.select(maxi(choices.find(value), 0))
			options.item_selected.connect(func(index: int) -> void: _set_pending(key, choices[index]))
			line.add_child(options)
		"slider":
			var limits: Array = row[3]
			var slider := HSlider.new()
			slider.custom_minimum_size = Vector2(60, 10) * _ui_scale
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.min_value = limits[0]
			slider.max_value = limits[1]
			slider.step = 0.05
			slider.value = value
			var shown := _label(_percent(value), TEXT)
			shown.custom_minimum_size.x = 22 * _ui_scale
			shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			slider.value_changed.connect(func(new_value: float) -> void:
				shown.text = _percent(new_value)
				_set_pending(key, new_value)
			)
			line.add_child(slider)
			line.add_child(shown)
		"decimal":
			# [min, max, step]; shown with two decimals.
			var limits: Array = row[3]
			var slider := HSlider.new()
			slider.custom_minimum_size = Vector2(60, 10) * _ui_scale
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.min_value = limits[0]
			slider.max_value = limits[1]
			slider.step = limits[2]
			slider.value = value
			var shown := _label("%.2f" % value, TEXT)
			shown.custom_minimum_size.x = 22 * _ui_scale
			shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			slider.value_changed.connect(func(new_value: float) -> void:
				shown.text = "%.2f" % new_value
				_set_pending(key, new_value)
				if key.begins_with(LIVE_PREFIX):
					if not _live_before.has(key):
						_live_before[key] = Settings.get_value(key)
					Settings.set_value(key, new_value)
			)
			line.add_child(slider)
			line.add_child(shown)
		"number":
			var limits: Array = row[3]
			var slider := HSlider.new()
			slider.custom_minimum_size = Vector2(60, 10) * _ui_scale
			slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			slider.min_value = limits[0]
			slider.max_value = limits[1]
			slider.step = limits[2]
			slider.value = value
			var unit: String = limits[3]
			var shown := _label("%d%s" % [value, unit], TEXT)
			shown.custom_minimum_size.x = 22 * _ui_scale
			shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			slider.value_changed.connect(func(new_value: float) -> void:
				shown.text = "%d%s" % [new_value, unit]
				_set_pending(key, int(new_value))
			)
			line.add_child(slider)
			line.add_child(shown)
	return line


## Gives a checkbox clearly drawn boxes: Godot's default unticked box is
## nearly invisible on dark panels.
static func style_check(check: CheckBox, ui_scale: float) -> void:
	var size := maxi(roundi(8 * ui_scale), 8)
	if not _check_icons.has(size):
		_check_icons[size] = [_check_icon(size, false), _check_icon(size, true)]
	var icons: Array = _check_icons[size]
	check.add_theme_icon_override("unchecked", icons[0])
	check.add_theme_icon_override("checked", icons[1])


static func _check_icon(size: int, ticked: bool) -> ImageTexture:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.05, 0.08))
	var border := maxi(size / 9, 1)
	var edge := Color(0.75, 0.7, 0.55)
	for i in size:
		for b in border:
			image.set_pixel(i, b, edge)
			image.set_pixel(i, size - 1 - b, edge)
			image.set_pixel(b, i, edge)
			image.set_pixel(size - 1 - b, i, edge)
	if ticked:
		var inset := border + maxi(size / 5, 1)
		image.fill_rect(Rect2i(inset, inset, size - inset * 2, size - inset * 2), GOLD)
	return ImageTexture.create_from_image(image)


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(40, 13) * _ui_scale
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	# Deferred: closing or rebuilding frees this button mid-press otherwise.
	button.pressed.connect(func() -> void: pressed.call_deferred())
	return button


# ---------------------------------------------------------------- tuning

## The Tuning tab's groups and scripts opened (by name), kept while the game
## runs; and what its search box holds.
static var _tuning_open: Dictionary = {}
static var _tuning_search := ""
## Rows of values shown, by key: [slider, number box, reset button], updated
## in place when a value changes.
var _tuning_rows: Dictionary = {}
var _tuning_quiet := false
## The mark on values read only as things are made (Tuning's `reload`), and
## what it means.
const RELOAD_COLOR := Color(0.95, 0.65, 0.35)
const RELOAD_NOTE := "Read as things are made (zones, models, effects as they start): changes show after Reload Game, or on things made afterwards."


## Every tunable number (Tuning.entries), in collapsible groups by system
## (Levels, Effects, Bots...) and then by script, each with a slider, its
## exact number and, once changed, a reset icon putting its code's value
## back. Changes take effect as they're made (Apply saves them, Cancel and
## Defaults put them back); values read when something's built need a reload.
## Developer runs only (editor saves): release builds neither show the tab
## nor apply tuning (Settings._apply).
func _build_tuning(content: VBoxContainer) -> void:
	_tuning_rows.clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	content.add_child(top)
	var search := LineEdit.new()
	search.placeholder_text = "Search names, notes and scripts"
	search.text = _tuning_search
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	top.add_child(search)
	top.add_child(_button("Reload Game", func() -> void:
		_show_result(console.run("reload") if console != null else "Reload from in the game.")
	))
	var hint := _label("Values marked reload are read as things are made (zones, caves, models): they change after Reload Game.", Color(0.7, 0.68, 0.6))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
	content.add_child(hint)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	content.add_child(list)
	search.text_changed.connect(func(text: String) -> void:
		_tuning_search = text
		_fill_tuning(list)
	)
	_fill_tuning(list)


## The groups, or with a search, every value matching it in its group.
func _fill_tuning(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()
	_tuning_rows.clear()
	var words := _tuning_search.strip_edges().to_lower()
	var groups := {}
	for entry: Dictionary in Tuning.entries():
		if not words.is_empty():
			var text := ("%s %s %s %s" % [entry.name, String(entry.name).capitalize(), entry.script, entry.comment]).to_lower()
			if not text.contains(words):
				continue
		if not groups.has(entry.category):
			groups[entry.category] = {}
		if not (groups[entry.category] as Dictionary).has(entry.script):
			groups[entry.category][entry.script] = []
		(groups[entry.category][entry.script] as Array).append(entry)
	if groups.is_empty():
		list.add_child(_label("Nothing matches.", TEXT))
		return
	var changes := _tuning_changes()
	var names := groups.keys()
	names.sort()
	for category: String in names:
		var scripts: Dictionary = groups[category]
		var count := 0
		var changed := 0
		for entries: Array in scripts.values():
			count += entries.size()
			changed += entries.filter(func(e: Dictionary) -> bool: return changes.has(e.key)).size()
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", roundi(2 * _ui_scale))
		var label := "%s (%d%s)" % [category, count, ", %d changed" % changed if changed > 0 else ""]
		list.add_child(_tuning_header(label, "c:" + category, body, 0, _fill_scripts.bind(body, category, scripts), not words.is_empty()))
		list.add_child(body)


func _fill_scripts(body: VBoxContainer, category: String, scripts: Dictionary) -> void:
	var names := scripts.keys()
	names.sort()
	var searching := not _tuning_search.strip_edges().is_empty()
	for script: String in names:
		var entries: Array = scripts[script]
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", roundi(1 * _ui_scale))
		body.add_child(_tuning_header("%s (%d)" % [script, entries.size()], "s:%s/%s" % [category, script], rows, 1, _fill_rows.bind(rows, entries), searching))
		body.add_child(rows)


func _fill_rows(rows: VBoxContainer, entries: Array) -> void:
	for entry: Dictionary in entries:
		rows.add_child(_tuning_row(entry))


## A header that opens and closes what's under it, filling it the first time
## it opens.
func _tuning_header(text: String, id: String, body: VBoxContainer, depth: int, fill: Callable, open_now: bool) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.flat = depth > 0
	button.custom_minimum_size = Vector2(40, 12) * _ui_scale
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	button.add_theme_color_override("font_color", GOLD if depth == 0 else TEXT)
	var filled := [false]
	var show := func(now_open: bool) -> void:
		button.text = "%s%s  %s" % ["      ".repeat(depth), "v" if now_open else ">", text]
		body.visible = now_open
		if now_open and not filled[0]:
			filled[0] = true
			fill.call()
	show.call(open_now or bool(_tuning_open.get(id, false)))
	button.pressed.connect(func() -> void:
		var now_open := not body.visible
		_tuning_open[id] = now_open
		show.call(now_open)
	)
	return button


## One value: its name (its notes and default on hover), a slider, its exact
## number (which can go past the slider) and a reset icon once it's changed.
func _tuning_row(entry: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", roundi(3 * _ui_scale))
	var whole: bool = entry.int
	var default_value := float(Tuning.default_of(entry.path, entry.name))
	var current := float(Tuning.value(entry.path, entry.name))
	var name_label := _label("            " + String(entry.name).capitalize(), TEXT)
	name_label.custom_minimum_size.x = 95 * _ui_scale
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var when := RELOAD_NOTE if entry.reload else "Changes as you move it."
	name_label.tooltip_text = "%s\n%s\nDefault: %s\n%s" % [entry.name, entry.comment if entry.comment != "" else "(no notes)", _tuning_text(default_value, whole), when]
	line.add_child(name_label)
	# Values read only as things are made: marked, as they show after a reload.
	if entry.reload:
		var mark := _label("reload", RELOAD_COLOR)
		mark.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
		mark.tooltip_text = RELOAD_NOTE
		mark.mouse_filter = Control.MOUSE_FILTER_PASS
		line.add_child(mark)
	var limits := _tuning_limits(default_value, whole)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(50, 10) * _ui_scale
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = limits[0]
	slider.max_value = limits[1]
	slider.step = limits[2]
	slider.allow_greater = true
	slider.allow_lesser = true
	slider.value = current
	# The wheel scrolls the page, never the value.
	slider.scrollable = false
	line.add_child(slider)
	var number := SpinBox.new()
	number.min_value = limits[0]
	number.max_value = limits[1]
	number.step = limits[2]
	number.allow_greater = true
	number.allow_lesser = true
	number.value = current
	number.custom_minimum_size.x = 40 * _ui_scale
	number.get_line_edit().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	number.gui_input.connect(_scroll_past.bind(number))
	number.get_line_edit().gui_input.connect(_scroll_past.bind(number))
	line.add_child(number)
	var reset := Button.new()
	reset.icon = _reset_icon()
	reset.tooltip_text = "Back to %s (its code's value)" % _tuning_text(default_value, whole)
	reset.custom_minimum_size = Vector2(12, 12) * _ui_scale
	reset.expand_icon = true
	line.add_child(reset)
	_tuning_rows[entry.key] = [slider, number, reset]
	_show_reset(entry.key, current, default_value)
	slider.value_changed.connect(func(to: float) -> void: _tuning_changed(entry, to))
	number.value_changed.connect(func(to: float) -> void: _tuning_changed(entry, to))
	reset.pressed.connect(func() -> void: _tuning_changed(entry, default_value))
	return line


## A value moved (slider, number or reset): changed now, kept in the tuning
## option (dropped from it at its default), and its row brought in line.
func _tuning_changed(entry: Dictionary, to: float) -> void:
	if _tuning_quiet:
		return
	var whole: bool = entry.int
	if whole:
		to = roundf(to)
	var default_value := float(Tuning.default_of(entry.path, entry.name))
	var changes := _tuning_changes().duplicate()
	if is_equal_approx(to, default_value):
		changes.erase(entry.key)
	else:
		changes[entry.key] = int(to) if whole else to
	_set_tuning(changes)
	_tuning_quiet = true
	var row: Array = _tuning_rows.get(entry.key, [])
	if not row.is_empty():
		(row[0] as HSlider).value = to
		(row[1] as SpinBox).value = to
	_tuning_quiet = false
	_show_reset(entry.key, to, default_value)


## The tuning option as it stands in the window.
func _tuning_changes() -> Dictionary:
	return _value("tuning")


## Puts the tuning option in place now (live), to be saved by Apply or put
## back by Cancel.
func _set_tuning(changes: Dictionary) -> void:
	_set_pending("tuning", changes)
	if not _live_before.has("tuning"):
		_live_before["tuning"] = Settings.get_value("tuning")
	Settings.set_value("tuning", changes)
	if changes.is_empty():
		# Defaults: every row shown back at its code's value.
		for key: String in _tuning_rows:
			var row: Array = _tuning_rows[key]
			var parts := key.split("|")
			var back := float(Tuning.default_of(parts[0], parts[1]))
			_tuning_quiet = true
			(row[0] as HSlider).value = back
			(row[1] as SpinBox).value = back
			_tuning_quiet = false
			_show_reset(key, back, back)


func _show_reset(key: String, now: float, default_value: float) -> void:
	var row: Array = _tuning_rows.get(key, [])
	if row.is_empty():
		return
	var reset: Button = row[2]
	# Kept in place (unseen) so rows don't shift as it comes and goes.
	var changed := not is_equal_approx(now, default_value)
	reset.modulate.a = 1.0 if changed else 0.0
	reset.disabled = not changed
	reset.mouse_filter = Control.MOUSE_FILTER_STOP if changed else Control.MOUSE_FILTER_IGNORE


static var _reset_texture: ImageTexture


## A small gold arrow curling back round (the reset icon), drawn in code.
static func _reset_icon() -> ImageTexture:
	if _reset_texture != null:
		return _reset_texture
	var n := 16
	var image := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var c := Vector2(7.5, 8.5)
	for y in n:
		for x in n:
			var d := Vector2(x, y) - c
			var angle := atan2(d.y, d.x)
			# A ring open at the top right, three quarters round.
			if absf(d.length() - 5.0) < 1.1 and not (angle < -0.2 and angle > -1.9):
				image.set_pixel(x, y, GOLD)
	# Its arrowhead at the open end, pointing back up.
	for p: Vector2i in [Vector2i(12, 3), Vector2i(12, 4), Vector2i(12, 5), Vector2i(13, 5), Vector2i(14, 5), Vector2i(11, 5), Vector2i(10, 5), Vector2i(13, 4), Vector2i(11, 4)]:
		image.set_pixelv(p, GOLD)
	_reset_texture = ImageTexture.create_from_image(image)
	return _reset_texture


## A slider's range for a value: 0 to four times it (both ways for negative
## values), whole steps for whole numbers, else about a hundredth of it.
static func _tuning_limits(value: float, whole: bool) -> Array:
	var size := absf(value)
	if size < 0.000001:
		return [0.0, 10.0, 1.0] if whole else [0.0, 1.0, 0.01]
	var low := 0.0 if value > 0.0 else -size * 4.0
	var high := size * 4.0
	if whole:
		return [low, maxf(high, 10.0), 1.0]
	var step := pow(10.0, floorf(log(size) / log(10.0)) - 2.0)
	return [low, high, step]


static func _tuning_text(value: float, whole: bool) -> String:
	return str(int(value)) if whole else String.num(value, 4)


## The mouse wheel over a number box scrolls the page it's on instead of
## changing the number (a SpinBox steps its value on the wheel otherwise).
func _scroll_past(event: InputEvent, box: Control) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index != MOUSE_BUTTON_WHEEL_UP and wheel.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	box.accept_event()
	var page := box.get_parent()
	while page != null and not page is ScrollContainer:
		page = page.get_parent()
	if page != null:
		var scroll := page as ScrollContainer
		var amount := scroll.get_v_scroll_bar().page / 8.0 * wheel.factor
		scroll.scroll_vertical += roundi(-amount if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else amount)


## A click anywhere but the text box being typed in (a search box, a number
## box) stops it taking typing, as a click away does in most programs. A
## number box keeps what was typed (it takes it as it lets go).
func _release_text_focus(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if not visible or click == null or not click.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if not focus is LineEdit and not focus is TextEdit:
		return
	var owner_box: Control = focus
	if focus.get_parent() is SpinBox:
		owner_box = focus.get_parent()
	if not owner_box.get_global_rect().has_point(click.position):
		focus.release_focus()

