class_name OptionsWindow
extends PanelContainer
## The Options window, with a tab down the left for each category: Video,
## Sound, Interface, Chat, Playerbots, Key Bindings and Developer. A new category is a TABS entry plus its
## rows in CATEGORIES (or its own builder, as Key Bindings has). Changes wait
## until Apply, which applies and saves every changed option at once; Okay
## does the same and closes, Cancel drops what wasn't applied, and Defaults
## sets the open tab back (applied with the rest). In Key Bindings, click a
## key to bind a new one (Esc stops), right-click to clear it.

signal closed

const WIDTH := 190.0
const FONT_SIZE := 7
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
		["bar_bottom_left", "Bottom Left Action Bar", "check", null],
		["bar_bottom_right", "Bottom Right Action Bar", "check", null],
		["bar_right", "Right Action Bar", "check", null],
		["bar_right_2", "Right Action Bar 2", "check", null],
		["loading_tips", "Show Loading Screen Tips", "check", null],
		["mouse_speed", "Mouse Look Speed", "slider", [0.25, 2.5]],
		["invert_mouse", "Invert Mouse", "check", null],
	],
	# Numbers are [lowest, highest, step, unit].
	"Playerbots": [
		["bots_enabled", "Enable Playerbots", "check", null],
		# 400 holds about 70 fps with both zones (BotManager.far_schedule).
		["bot_count", "Random Bots in the World", "number", [0, 400, 5, ""]],
		["bot_min_level", "Random Bot Lowest Level", "number", [1, 60, 1, ""]],
		["bot_max_level", "Random Bot Highest Level", "number", [1, 60, 1, ""]],
		["bot_classes", "Bot Classes", "choice", ["All Classes", "Classes With Spells"]],
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
	],
}

static var _check_icons: Dictionary

const KEY_BINDINGS := "Key Bindings"
const DEVELOPER := "Developer"
const TABS := ["Video", "Sound", "Interface", "Chat", "Playerbots", KEY_BINDINGS, DEVELOPER]
## One-click developer commands: [button text, console command]. "level+" is
## the next level, filled in when pressed.
const DEV_BUTTONS := [
	["Heal", "heal"], ["Kill Target", "kill"], ["Repair Gear", "repair"],
	["Level Up", "level+"], ["+1 Gold", "money 1g"], ["Respawn Creatures", "respawn"],
	["Go to Start", "tele spawn"], ["Save Game", "save"], ["Where Am I", "pos"],
	["Reload Game", "reload"], ["Train All Spells", "trainall"], ["BiS", "bis"],
	["Randomize Bots", "randomizebots"],
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
const TAB_WIDTH := 58.0
const TAB_OTHER := Color(0.6, 0.6, 0.65)
const LIST_HEIGHT := 125.0
## Every tab's page height: down to just above the buttons. Lists that scroll
## on their own (key bindings, items) grow by EXTRA_PAGE to fill it.
const PAGE_HEIGHT := 176.0
const EXTRA_PAGE := PAGE_HEIGHT - (LIST_HEIGHT + 13.0)
## Room beside a page for its scrollbar, and the result line's two rows.
const SCROLLBAR_ROOM := 8.0
const NOTE_HEIGHT := 20.0
const WAITING := Color(0.4, 1, 0.4)

## The in-game developer console the Developer tab runs commands through, or
## null on the login screens.
var console: DevConsole

## The Developer tab is showing its item list instead of its commands.
var _item_list := false
var _item_filter := ""
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
var _note: Label
## The Key Bindings tab's buttons by action, [first key, second key], updated
## in place so the list keeps its scroll position.
var _key_buttons: Dictionary


func open(category := "Video") -> void:
	_category = category
	_pending.clear()
	_keys = Settings.snapshot_keys()
	_binding = []
	visible = true
	_build()


## Switches tab. Changes on other tabs stay until Okay or Cancel.
func show_tab(category: String) -> void:
	_category = category
	_item_list = false
	_binding = []
	_build()


## Applies and saves every changed option.
func apply() -> void:
	var rebuild := _pending.has("ui_scale")
	for key: String in _pending:
		Settings.set_value(key, _pending[key])
	_pending.clear()
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
	_close()


func _exit_tree() -> void:
	close_confirm()


func defaults() -> void:
	if _category == KEY_BINDINGS:
		_keys = Settings.default_keys()
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
## the binding. Left and right clicks still work the window.
func _input(event: InputEvent) -> void:
	if not visible or _binding.is_empty():
		return
	var code := 0
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	if key and key.pressed and not key.echo:
		code = int(key.physical_keycode)
	elif mouse and mouse.pressed and mouse.button_index in Settings.BINDABLE_MOUSE:
		code = -int(mouse.button_index)
	if code == 0:
		return
	get_viewport().set_input_as_handled()
	var action: String = _binding[0]
	var slot: int = _binding[1]
	_binding = []
	var note := ""
	if code == KEY_ESCAPE:
		note = ""
	elif code in Settings.RESERVED_KEYS:
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
	style.bg_color = Color(0.04, 0.04, 0.12, 0.96)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_border_width_all(maxi(roundi(_ui_scale / 2), 1))
	style.set_content_margin_all(6 * _ui_scale)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	add_child(box)
	var title := _label("Options", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", roundi(6 * _ui_scale))
	box.add_child(body)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	tabs.custom_minimum_size.x = TAB_WIDTH * _ui_scale
	body.add_child(tabs)
	# Release builds have no Developer tab.
	for tab: String in TABS.filter(func(t: String) -> bool: return t != DEVELOPER or Settings.developer_tools()):
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
	else:
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
	var center := func() -> void: position = (get_viewport_rect().size - size) / 2
	center.call_deferred()


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
				line = "level %d" % (GameState.level + 1)
			_show_result(console.run(line))
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	content.add_child(grid)
	content.add_child(_spawn_row(console))
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
	content.add_child(_button("Add Items...", func() -> void:
		_item_list = true
		_note.text = ""
		_build()
	))
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
	style.bg_color = Color(0.04, 0.04, 0.12, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(maxi(roundi(_ui_scale / 2), 1))
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
	var scroll := ScrollContainer.new()
	# Short enough that the page itself needn't scroll as well.
	scroll.custom_minimum_size = Vector2(WIDTH + 30, LIST_HEIGHT - 24 + EXTRA_PAGE) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.custom_minimum_size.x = (WIDTH + 22) * _ui_scale
	scroll.add_child(list)
	var fill := func() -> void:
		for child in list.get_children():
			child.queue_free()
		for item: Dictionary in _items_matching(_item_filter):
			list.add_child(_item_row(item))
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
		return query.is_empty() or str(item.name).to_lower().contains(query) or str(int(item.entry)) == query
	)
	matching.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.name) < str(b.name))
	return matching


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
		_note.text = ""
		_refresh_keys()
	)
	return button


func _row(row: Array) -> Control:
	var key: String = row[0]
	var line := HBoxContainer.new()
	line.custom_minimum_size.x = WIDTH * _ui_scale
	var label := _label(row[1], TEXT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
