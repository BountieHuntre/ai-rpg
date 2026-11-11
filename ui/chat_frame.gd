class_name ChatFrame
extends Control
## The chat box in the bottom-left corner, like classic's: the Chat log with
## its colors, and Enter to type. Text goes to the current channel (Say at
## first; Say, Party, numbered channels and whispers stick, as in classic),
## or starts with a slash command: /s, /y, /p, /1 to /4, /w <name>, /r, /e,
## a few emotes (/wave, /bow...), /who, /invite, /help. Any developer console
## command works after a slash too (/additem 2589 5, /level 10). Click a name
## to whisper it, right-click it for the same menu as the player's frame.
## Shift-click an item (in the bags) or a quest (in the quest log), or a link
## in the chat, to link it; hovering a link shows the item's tooltip, or the
## quest's: its objective and who gives it.
##
## Tabs along the top, as classic's chat frames: General shows every channel
## and can't be closed; "+" adds a tab. Right-click a tab for New Tab, Edit
## Tab (its name and which channels it shows), Close Tab and Lock/Unlock
## Chat. Unlocked, drag a tab to move the chat and the corner grip to resize
## it. Tabs, place, size and lock are kept in the options (chatframe_*).
## Sizes are in HUD units, times ui_scale.

## The Text Size option, in HUD units.
const FONT_SIZES := { "Small": 6, "Medium": 7, "Large": 8, "Huge": 10 }
## The box's size until it's dragged to another (HUD units).
const DEFAULT_WIDTH := 180.0
const DEFAULT_LOG := 72.0
## The backing darkens to at least this while typing or hovered.
const ACTIVE_BACK := 0.55
const TAB_HEIGHT := 10.0
const GRIP := 7.0
const MIN_WIDTH := 100.0
const MIN_LOG := 30.0
const TAB_ACTIVE := Color(1, 0.82, 0.3)
const TAB_OTHER := Color(0.65, 0.65, 0.7)
const TAB_UNREAD := Color(1, 1, 1)
## What a tab can show: [key, name]. Lines sort into these by kind.
const CATEGORIES := [
	["say", "Say"], ["yell", "Yell"], ["emote", "Emotes"], ["party", "Party"],
	["whisper", "Whispers"], ["channel1", "1. General"], ["channel2", "2. Trade"],
	["channel3", "3. LocalDefense"], ["channel4", "4. LookingForGroup"],
	["system", "System Messages"], ["loot", "Loot"], ["error", "Errors"],
	["monster", "Creature Speech"],
]
## Right-click menu entries.
enum TabMenu { NEW, EDIT, CLOSE, LOCK }
## Previous lines kept for Up and Down.
const HISTORY := 30
## Emotes: [alone, at a target], in the game's own words.
const EMOTES := {
	"wave": ["You wave.", "You wave at %s."],
	"bow": ["You bow.", "You bow to %s."],
	"cheer": ["You cheer!", "You cheer for %s!"],
	"dance": ["You start dancing.", "You dance with %s."],
	"laugh": ["You laugh.", "You laugh at %s."],
	"thank": ["You thank everyone.", "You thank %s."],
	"hello": ["You call out a greeting.", "You greet %s."],
	"bye": ["You wave goodbye.", "You wave goodbye to %s."],
	"cry": ["You weep.", "You weep on %s's shoulder."],
	"sit": ["You sit down.", "You sit down."],
}

var _ui_scale := 1.0
var _width := 180.0
var _log_height := 72.0
var _font_size := 7
## The typing line, a little taller than the text.
var _input_height := 12.0
## How dark the backing is when idle (the Background option).
var _background := 0.35
var _player: Player
var _social: SocialWindow
var _tooltip: ItemTooltip
## Opens the menu for a player's name in the chat (right-click).
var _name_menu: Callable
## The link under the mouse, for right-clicks.
var _hovered_link := ""
var _log := RichTextLabel.new()
var _back := ColorRect.new()
var _typed := LineEdit.new()
var _prefix := Label.new()
## The channel plain text goes to: { "kind", "channel", "target" }.
var _sticky := { "kind": "say", "channel": 0, "target": "" }
var _history: Array[String] = []
var _history_at := -1
## Tabs: { "name", "filters": [category keys] }; the first is General.
var _tabs: Array = []
var _active := 0
## Tabs with lines you haven't seen.
var _unread: Dictionary = {}
var _locked := true
var _screen := Vector2.ZERO
var _tab_bar := Control.new()
var _grip := ColorRect.new()
var _menu := PopupMenu.new()
var _menu_tab := 0
var _editor: Control
## A tab or the grip being dragged: { "what", "from", "start", "size", "moved", "tab" }.
var _drag := {}


func setup(ui_scale: float, screen: Vector2, player: Player, social: SocialWindow, tooltip: ItemTooltip, name_menu: Callable) -> void:
	_ui_scale = ui_scale
	_screen = screen
	_font_size = FONT_SIZES.get(Settings.get_value("chat_font"), 7)
	_width = DEFAULT_WIDTH
	_log_height = DEFAULT_LOG
	_input_height = _font_size + 5.0
	_background = Settings.get_value("chat_background")
	_player = player
	_social = social
	_tooltip = tooltip
	_name_menu = name_menu
	_locked = Settings.get_value("chatframe_locked")
	_load_tabs()
	# A saved place and size (moved or resized), or the bottom-left corner.
	var rect: Array = Settings.get_value("chatframe_rect")
	var at := Vector2(4, screen.y - 4 - _input_height - _log_height - TAB_HEIGHT)
	if rect.size() == 4:
		_width = clampf(float(rect[2]), MIN_WIDTH, screen.x - 8)
		_log_height = clampf(float(rect[3]), MIN_LOG, screen.y - 40)
		at = Vector2(float(rect[0]), float(rect[1]))
	position = _clamped(at) * ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade(false)
	add_child(_back)
	add_child(_tab_bar)
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", roundi(_font_size * ui_scale))
	_log.add_theme_color_override("font_shadow_color", Color.BLACK)
	_log.add_theme_constant_override("shadow_offset_x", maxi(roundi(ui_scale), 1))
	_log.add_theme_constant_override("shadow_offset_y", maxi(roundi(ui_scale), 1))
	if Settings.get_value("chat_outline"):
		_log.add_theme_color_override("font_outline_color", Color.BLACK)
		_log.add_theme_constant_override("outline_size", maxi(roundi(2 * ui_scale), 2))
	# Takes the wheel (scrolling back) and clicks on names.
	_log.mouse_filter = Control.MOUSE_FILTER_STOP
	_log.meta_underlined = false
	_log.meta_clicked.connect(_on_link_clicked)
	_log.meta_hover_started.connect(_on_link_hovered)
	_log.meta_hover_ended.connect(func(_meta: Variant) -> void:
		_hovered_link = ""
		_tooltip.show_lines([])
	)
	_log.gui_input.connect(_on_log_input)
	_log.mouse_entered.connect(func() -> void: _shade(true))
	_log.mouse_exited.connect(func() -> void: _shade(_typed.visible))
	add_child(_log)
	_grip.color = Color(1, 0.85, 0.4, 0.6)
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.gui_input.connect(_on_grip_input)
	add_child(_grip)
	_prefix.add_theme_font_size_override("font_size", roundi(_font_size * ui_scale))
	_prefix.add_theme_color_override("font_shadow_color", Color.BLACK)
	_prefix.add_theme_constant_override("shadow_offset_x", maxi(roundi(ui_scale), 1))
	_prefix.add_theme_constant_override("shadow_offset_y", maxi(roundi(ui_scale), 1))
	_prefix.visible = false
	add_child(_prefix)
	_typed.add_theme_font_size_override("font_size", roundi(_font_size * ui_scale))
	_typed.max_length = 255
	_typed.visible = false
	_typed.text_submitted.connect(_on_submitted)
	_typed.text_changed.connect(_on_text_changed)
	_typed.focus_exited.connect(close)
	add_child(_typed)
	_menu.add_theme_font_size_override("font_size", roundi(7 * ui_scale))
	_menu.id_pressed.connect(_on_tab_menu)
	add_child(_menu)
	_layout()
	_build_tabs()
	_rebuild_log()
	Chat.line_added.connect(_on_line)


## Sizes and places everything from the width and log height.
func _layout() -> void:
	var s := _ui_scale
	size = Vector2(_width, TAB_HEIGHT + _log_height + _input_height) * s
	_back.position = Vector2(0, TAB_HEIGHT) * s
	_back.size = Vector2(_width, _log_height + (_input_height if _typed.visible else 0.0)) * s
	_log.position = Vector2(2, TAB_HEIGHT) * s
	_log.size = Vector2(_width - 2, _log_height) * s
	_grip.position = Vector2(_width - GRIP, TAB_HEIGHT + _log_height - GRIP) * s
	_grip.size = Vector2(GRIP, GRIP) * s
	_grip.visible = not _locked
	_prefix.position = Vector2(2, TAB_HEIGHT + _log_height) * s
	_typed.position.y = (TAB_HEIGHT + _log_height) * s
	_typed.size = Vector2(_width - 2, _input_height) * s
	if _typed.visible:
		_show_prefix()


## Keeps the chat on screen (HUD units).
func _clamped(at: Vector2) -> Vector2:
	var full := Vector2(_width, TAB_HEIGHT + _log_height + _input_height)
	return Vector2(clampf(at.x, 0, maxf(_screen.x - full.x, 0)), clampf(at.y, 0, maxf(_screen.y - full.y, 0)))


## The backing: the Background option's darkness when idle, darker while
## hovered or typing.
func _shade(active: bool) -> void:
	var alpha := maxf(_background, ACTIVE_BACK) if active else _background
	_back.color = Color(0, 0, 0, alpha)
	_back.visible = alpha > 0.0


# Tabs.

func _load_tabs() -> void:
	_tabs = []
	for tab in Settings.get_value("chatframe_tabs"):
		if tab is Dictionary and tab.has("name"):
			_tabs.append({ "name": str(tab.name), "filters": Array(tab.get("filters", [])).map(func(f: Variant) -> String: return str(f)) })
	if _tabs.is_empty() or _tabs[0].name != "General":
		_tabs.insert(0, { "name": "General", "filters": CATEGORIES.map(func(c: Array) -> String: return c[0]) })


func _save() -> void:
	Settings.set_value("chatframe_tabs", _tabs.duplicate(true))
	Settings.set_value("chatframe_rect", [position.x / _ui_scale, position.y / _ui_scale, _width, _log_height])
	Settings.set_value("chatframe_locked", _locked)
	Settings.save()


## The category a line sorts into.
static func category(line: Dictionary) -> String:
	match str(line.kind):
		"whisper", "whisper_to":
			return "whisper"
		"channel":
			return "channel%d" % int(line.channel)
		"dev":
			return "system"
		"monster_say", "monster_emote":
			return "monster"
	return str(line.kind)


func _shows(tab: Dictionary, line: Dictionary) -> bool:
	return category(line) in tab.filters


func _rebuild_log() -> void:
	_log.clear()
	for line in Chat.lines:
		if _shows(_tabs[_active], line):
			_log.append_text(Chat.format(line) + "\n")


func _on_line(line: Dictionary) -> void:
	if _shows(_tabs[_active], line):
		_log.append_text(Chat.format(line) + "\n")
		if _log.get_paragraph_count() > Chat.MAX_LINES:
			_log.remove_paragraph(0)
	var flagged := false
	for i in _tabs.size():
		if i != _active and not _unread.has(i) and _shows(_tabs[i], line):
			_unread[i] = true
			flagged = true
	if flagged:
		_build_tabs()


## The tab row: each tab's name (gold when open, white with unread lines),
## then "+" for a new one.
func _build_tabs() -> void:
	for child in _tab_bar.get_children():
		child.queue_free()
	var x := 0.0
	for i in _tabs.size() + 1:
		var adding := i == _tabs.size()
		var text := "+" if adding else str(_tabs[i].name)
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", roundi(6 * _ui_scale))
		var color := TAB_OTHER
		if not adding and i == _active:
			color = TAB_ACTIVE
		elif _unread.has(i):
			color = TAB_UNREAD
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		var width := maxf(label.get_minimum_size().x / _ui_scale + 8, 12)
		var tab := ColorRect.new()
		tab.color = Color(0, 0, 0, 0.6 if i == _active else 0.35)
		tab.position = Vector2(x, 0) * _ui_scale
		tab.size = Vector2(width, TAB_HEIGHT - 1) * _ui_scale
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.gui_input.connect(_on_tab_input.bind(i))
		label.position = Vector2(4, 0) * _ui_scale
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.add_child(label)
		_tab_bar.add_child(tab)
		x += width + 1


func _select(index: int) -> void:
	_active = clampi(index, 0, _tabs.size() - 1)
	_unread.erase(_active)
	_build_tabs()
	_rebuild_log()


## Click a tab to open it, drag it to move the chat (unlocked), right-click
## for the tab menu; "+" adds a tab.
func _on_tab_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_drag = { "what": "move", "from": click.global_position, "start": position, "moved": false, "tab": index }
		else:
			var moved: bool = _drag.get("moved", false)
			_drag = {}
			if moved:
				_save()
			elif index == _tabs.size():
				_new_tab()
			else:
				_select(index)
		accept_event()
	elif click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT:
		_menu_tab = mini(index, _tabs.size() - 1)
		_open_menu()
		accept_event()
	elif motion and _drag.get("what") == "move":
		var offset: Vector2 = motion.global_position - _drag.from
		if not _locked and (_drag.moved or offset.length() > 4.0):
			_drag.moved = true
			position = _clamped((_drag.start + offset) / _ui_scale) * _ui_scale
		accept_event()


## Dragging the corner grip resizes the chat (unlocked).
func _on_grip_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var motion := event as InputEventMouseMotion
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed:
			_drag = { "what": "size", "from": click.global_position, "size": Vector2(_width, _log_height) }
		else:
			_drag = {}
			_save()
		accept_event()
	elif motion and _drag.get("what") == "size" and not _locked:
		var grown: Vector2 = _drag.size + (motion.global_position - _drag.from) / _ui_scale
		var top := position.y / _ui_scale
		_width = clampf(grown.x, MIN_WIDTH, _screen.x - position.x / _ui_scale)
		_log_height = clampf(grown.y, MIN_LOG, _screen.y - top - TAB_HEIGHT - _input_height)
		_layout()
		accept_event()


func _open_menu() -> void:
	_menu.clear()
	_menu.add_item("New Tab", TabMenu.NEW)
	_menu.add_item("Edit Tab", TabMenu.EDIT)
	_menu.add_item("Close Tab", TabMenu.CLOSE)
	_menu.set_item_disabled(_menu.get_item_index(TabMenu.CLOSE), _menu_tab == 0)
	_menu.add_separator()
	_menu.add_item("Unlock Chat" if _locked else "Lock Chat", TabMenu.LOCK)
	_menu.reset_size()
	_menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _on_tab_menu(id: int) -> void:
	match id:
		TabMenu.NEW:
			_new_tab()
		TabMenu.EDIT:
			_edit_tab(_menu_tab)
		TabMenu.CLOSE:
			if _menu_tab > 0:
				_tabs.remove_at(_menu_tab)
				_unread.clear()
				_close_editor()
				_select(0 if _active == _menu_tab else (_active - 1 if _active > _menu_tab else _active))
				_save()
		TabMenu.LOCK:
			_locked = not _locked
			_layout()
			_save()
			Chat.system("Chat %s. %s" % ["locked" if _locked else "unlocked", "" if _locked else "Drag a tab to move it, the corner to resize it."])


## A new tab showing what you say and hear from people, opened for editing.
func _new_tab() -> void:
	_tabs.append({ "name": "Tab %d" % (_tabs.size() + 1), "filters": ["say", "yell", "emote", "party", "whisper"] })
	_select(_tabs.size() - 1)
	_save()
	_edit_tab(_tabs.size() - 1)


## The tab editor beside the chat: its name (General keeps its own) and a
## checkbox for each kind of line it shows.
func _edit_tab(index: int) -> void:
	_close_editor()
	var tab: Dictionary = _tabs[index]
	var row := 11.0
	var height := 30.0 + CATEGORIES.size() * row + 16
	_editor = Control.new()
	_editor.position = Vector2(_width + 4, TAB_HEIGHT + _log_height - height) * _ui_scale
	_editor.size = Vector2(110, height) * _ui_scale
	var back := ColorRect.new()
	back.color = Color(0.08, 0.08, 0.1, 0.95)
	back.size = _editor.size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	_editor.add_child(back)
	var title := Label.new()
	title.text = "Tab Settings"
	title.position = Vector2(4, 1) * _ui_scale
	title.add_theme_font_size_override("font_size", roundi(7 * _ui_scale))
	title.add_theme_color_override("font_color", TAB_ACTIVE)
	_editor.add_child(title)
	var name_field := LineEdit.new()
	name_field.text = tab.name
	name_field.editable = index > 0
	name_field.max_length = 16
	name_field.position = Vector2(4, 13) * _ui_scale
	name_field.size = Vector2(102, 12) * _ui_scale
	name_field.add_theme_font_size_override("font_size", roundi(6 * _ui_scale))
	name_field.text_changed.connect(func(text: String) -> void:
		tab.name = text.strip_edges() if not text.strip_edges().is_empty() else "Tab"
		_build_tabs()
		_save()
	)
	name_field.focus_entered.connect(func() -> void:
		if _player:
			_player.typing = true
	)
	name_field.focus_exited.connect(func() -> void:
		if _player:
			_player.typing = false
	)
	_editor.add_child(name_field)
	for i in CATEGORIES.size():
		var key: String = CATEGORIES[i][0]
		var check := CheckBox.new()
		check.text = CATEGORIES[i][1]
		check.button_pressed = key in tab.filters
		check.position = Vector2(4, 28 + i * row) * _ui_scale
		check.add_theme_font_size_override("font_size", roundi(6 * _ui_scale))
		check.focus_mode = Control.FOCUS_NONE
		OptionsWindow.style_check(check, _ui_scale)
		check.toggled.connect(func(on: bool) -> void:
			if on and not key in tab.filters:
				tab.filters.append(key)
			elif not on:
				tab.filters.erase(key)
			if index == _active:
				_rebuild_log()
			_save()
		)
		_editor.add_child(check)
	var done := Button.new()
	done.text = "Done"
	done.position = Vector2(4, height - 15) * _ui_scale
	done.size = Vector2(102, 12) * _ui_scale
	done.add_theme_font_size_override("font_size", roundi(6 * _ui_scale))
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(_close_editor)
	_editor.add_child(done)
	add_child(_editor)


func _close_editor() -> void:
	if _editor and is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null


func is_typing() -> bool:
	return _typed.visible


## Enter opens the input line, and / opens it with the slash typed, ready
## for a command; Esc closes it; Up and Down recall lines.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_ENTER, KEY_KP_ENTER] and not _typed.visible:
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_ESCAPE and _editor and not _typed.visible:
		_close_editor()
		get_viewport().set_input_as_handled()
		return
	if not _typed.visible:
		# Before anything else takes the key, unless another text box has it.
		if key.physical_keycode == KEY_SLASH and not key.echo and not get_viewport().gui_get_focus_owner() is LineEdit:
			open("/")
			get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif key.keycode in [KEY_UP, KEY_DOWN] and not _history.is_empty():
		_history_at = clampi(_history_at + (-1 if key.keycode == KEY_UP else 1), 0, _history.size())
		_typed.text = _history[_history_at] if _history_at < _history.size() else ""
		_typed.caret_column = _typed.text.length()
		get_viewport().set_input_as_handled()


func open(text := "") -> void:
	_typed.visible = true
	_shade(true)
	# The dark backing reaches down behind the input line while typing.
	_layout()
	_typed.text = text
	_history_at = _history.size()
	_show_prefix()
	_typed.grab_focus()
	_typed.caret_column = text.length()
	if _player:
		_player.typing = true


func close() -> void:
	if not _typed.visible:
		return
	_typed.visible = false
	_prefix.visible = false
	_shade(false)
	_layout()
	_typed.release_focus()
	if _player:
		_player.typing = false


## A name whispers; shift on an item link puts it in the line being typed.
func _on_link_clicked(meta: Variant) -> void:
	var link := str(meta)
	if link.begins_with("item:"):
		if Input.is_key_pressed(KEY_SHIFT):
			insert_item(int(link.substr(5)))
	elif link.begins_with("quest:"):
		if Input.is_key_pressed(KEY_SHIFT):
			insert_quest(int(link.substr(6)))
	elif link.begins_with("player:"):
		whisper_to(link.substr(7))


func _on_link_hovered(meta: Variant) -> void:
	_hovered_link = str(meta)
	if _hovered_link.begins_with("item:"):
		_tooltip.show_item(ItemDB.get_item(int(_hovered_link.substr(5))))
	elif _hovered_link.begins_with("quest:"):
		_tooltip.show_lines(quest_tooltip(int(_hovered_link.substr(6))))
	else:
		_tooltip.show_lines([])


## Right-click on a player's name: their menu, as on their frame.
func _on_log_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and _hovered_link.begins_with("player:"):
		_name_menu.call(_hovered_link.substr(7))
		accept_event()


## Adds an item's link to the line being typed, opening the chat if needed,
## as shift-clicking an item does in classic.
func insert_item(id: int) -> void:
	var item := ItemDB.get_item(id)
	if item.is_empty():
		return
	if not _typed.visible:
		open()
	_typed.insert_text_at_caret("[%s]" % item.name)
	_typed.grab_focus()


## Adds a quest's link to the line being typed (shift-clicking it in the
## quest log or the chat).
func insert_quest(id: int) -> void:
	var quest := QuestDB.get_quest(id)
	if quest.is_empty():
		return
	if not _typed.visible:
		open()
	_typed.insert_text_at_caret("[%s]" % quest.title)
	_typed.grab_focus()


## A quest link's tooltip: the title in its difficulty color, its level, the
## objective, who gives it and where, and how it stands for you.
func quest_tooltip(id: int) -> Array:
	var quest := QuestDB.get_quest(id)
	if quest.is_empty():
		return []
	var level := int(quest.get("level", 1))
	var lines: Array = [[str(quest.title), "", CombatRules.level_color(GameState.level, level)]]
	lines.append(["Level %d" % level, "", Color.WHITE])
	if int(quest.get("min_level", 1)) > GameState.level:
		lines.append(["Requires Level %d" % int(quest.min_level), "", Color(1, 0.13, 0.13)])
	lines.append([str(quest.get("objectives", "")), "", Color(1, 0.82, 0)])
	var giver := _npc(str(quest.get("giver", "")))
	if giver:
		var manager := get_tree().get_first_node_in_group("bot_manager") as BotManager
		var place := manager.place_at(giver.global_position) if manager else ""
		lines.append(["Quest giver: %s%s" % [giver.npc_name, ", " + place if not place.is_empty() else ""], "", Color.WHITE])
	match QuestLog.status(id):
		QuestLog.Status.DONE:
			lines.append(["Completed", "", Color(0.45, 0.9, 0.45)])
		QuestLog.Status.ACTIVE, QuestLog.Status.COMPLETE:
			lines.append(["In your quest log", "", Color(0.45, 0.9, 0.45)])
	return lines


func _npc(npc_id: String) -> Npc:
	for node in get_tree().get_nodes_in_group("npcs"):
		if (node as Npc).npc_id() == npc_id:
			return node
	return null


## Starts a whisper to a name (clicking it in the log).
func whisper_to(target: String) -> void:
	_sticky = { "kind": "whisper", "channel": 0, "target": target }
	open()


## "Say:", "Party:", "1. General:" or "Tell Name:" before the typing, in the
## channel's color.
func _show_prefix() -> void:
	var text := ""
	match str(_sticky.kind):
		"say":
			text = "Say:"
		"party":
			text = "Party:"
		"channel":
			text = "%d. %s:" % [int(_sticky.channel), Chat.channel_name(int(_sticky.channel))]
		"yell":
			text = "Yell:"
		"whisper":
			text = "Tell %s:" % _sticky.target
	_prefix.text = text
	_prefix.add_theme_color_override("font_color", Chat.COLORS.get(_sticky.kind, Color.WHITE))
	_prefix.visible = true
	_prefix.reset_size()
	var room := _prefix.size.x + 2 * _ui_scale
	_typed.position.x = 2 * _ui_scale + room
	_typed.size.x = (_width - 2) * _ui_scale - room


## As in classic, typing a channel command and a space ("/p ", "/2 ",
## "/w Name ") switches the line to that channel straight away.
func _on_text_changed(text: String) -> void:
	if not text.begins_with("/"):
		return
	var words := text.substr(1).split(" ")
	if words.size() < 2:
		return
	var command := words[0].to_lower()
	var used := command.length() + 2
	match command:
		"s", "say":
			_stick("say")
		"y", "yell", "sh", "shout":
			_stick("yell")
		"p", "party":
			_stick("party")
		"1", "2", "3", "4":
			_stick("channel", int(command))
		"r", "reply":
			if Chat.last_whisper_from.is_empty():
				return
			_stick("whisper", 0, Chat.last_whisper_from)
		"w", "whisper", "t", "tell", "msg", "send":
			if words.size() < 3 or words[1].is_empty():
				return
			_stick("whisper", 0, _player_name(words[1]))
			used += words[1].length() + 1
		_:
			return
	_typed.text = text.substr(used)
	_typed.caret_column = _typed.text.length()
	_show_prefix()


func _on_submitted(text: String) -> void:
	text = text.strip_edges()
	if not text.is_empty():
		_history.append(text)
		if _history.size() > HISTORY:
			_history.pop_front()
		send(text)
	close()


## Sends a typed line: a slash command, or text to the current channel.
func send(text: String) -> void:
	if not text.begins_with("/"):
		_speak(str(_sticky.kind), text, int(_sticky.channel), str(_sticky.target))
		# Yell doesn't stick, as in classic.
		if _sticky.kind == "yell":
			_stick("say")
		return
	var parts := text.substr(1).split(" ", false, 1)
	if parts.is_empty():
		return
	var command := parts[0].to_lower()
	var rest := parts[1] if parts.size() > 1 else ""
	match command:
		"s", "say":
			_stick("say")
			_speak("say", rest)
		"y", "yell", "sh", "shout":
			_speak("yell", rest)
		"p", "party":
			_stick("party")
			_speak("party", rest)
		"1", "2", "3", "4":
			_stick("channel", int(command))
			_speak("channel", rest, int(command))
		"w", "whisper", "t", "tell", "msg", "send":
			var words := rest.split(" ", false, 1)
			if words.is_empty():
				Chat.add("error", "Usage: /w <name> <message>")
				return
			_stick("whisper", 0, _player_name(words[0]))
			_speak("whisper", words[1] if words.size() > 1 else "", 0, _player_name(words[0]))
		"r", "reply":
			if Chat.last_whisper_from.is_empty():
				Chat.add("error", "No one has whispered you yet.")
				return
			_stick("whisper", 0, Chat.last_whisper_from)
			_speak("whisper", rest, 0, Chat.last_whisper_from)
		"e", "em", "emote", "me":
			if not rest.is_empty():
				Chat.add("emote", rest, GameState.char_name)
		"who":
			_social.show_who(rest)
		"invite", "inv":
			var bot := _find_bot(rest)
			if bot:
				Party.invite(bot)
			else:
				Chat.add("error", "No player named '%s' is currently playing." % rest)
		"leave", "leaveparty":
			Party.disband()
		"help", "?":
			Chat.system("Chat: /s say, /y yell, /p party, /1-/4 channels, /w <name> whisper, /r reply, /e emote, /who, /invite <name>, /leave.")
			Chat.system("Emotes: " + ", ".join(EMOTES.keys().map(func(e: String) -> String: return "/" + e)))
			if Settings.developer_tools():
				Chat.system("Any developer command works after a slash too: /help in the console (`) lists them, e.g. /additem, /level, /tele.")
		_:
			if EMOTES.has(command):
				_emote(command)
			else:
				_developer_command(text.substr(1))


func _stick(kind: String, channel := 0, target := "") -> void:
	_sticky = { "kind": kind, "channel": channel, "target": target }


## The player's own line, shown and passed on to the bots that can hear it.
## "[Item Name]" in it becomes a link.
func _speak(kind: String, text: String, channel := 0, target := "") -> void:
	if text.is_empty():
		return
	var me := GameState.char_name
	var linked := Chat.link_text(text)
	text = linked.text
	var items: Dictionary = linked.links
	match kind:
		"party":
			if Party.members.is_empty():
				Chat.add("error", "You aren't in a party.")
				return
			Chat.add("party", text, me, 0, "", items)
		"channel":
			Chat.add("channel", text, me, channel, "", items)
			target = str(channel)
		"whisper":
			if _find_bot(target) == null:
				Chat.add("error", "No player named '%s' is currently playing." % target)
				return
			Chat.add("whisper_to", text, "", 0, target, items)
		_:
			Chat.add(kind, text, me, 0, "", items)
	Chat.player_spoke.emit(kind, text, target)


func _emote(command: String) -> void:
	var texts: Array = EMOTES[command]
	var target := _target_name()
	Chat.add("emote", texts[1] % target if not target.is_empty() else texts[0])
	if command == "sit" and _player:
		_player.sitting = true
	elif _player and _player.model:
		_player.model.emote(command)
	Chat.player_spoke.emit("emote", command, target)


func _target_name() -> String:
	var target := _player.targeting.target if _player else null
	if target is Bot:
		return (target as Bot).profile.char_name
	if target is Npc:
		return (target as Npc).npc_name
	if target is Enemy:
		return (target as Enemy).combatant.display_name
	return ""


## Developer console commands, run through the console, results in the chat.
func _developer_command(line: String) -> void:
	var console := get_tree().get_first_node_in_group("dev_console") as DevConsole
	var command := line.split(" ", false)[0].to_lower() if not line.strip_edges().is_empty() else ""
	# Release builds have no developer commands.
	if console == null or not DevConsole.COMMANDS.has(command) or not Settings.developer_tools():
		Chat.add("error", "Unknown command. Type /help for a list.")
		return
	var result := console.run(line)
	for text in result.split("\n", false):
		if text.begins_with("!"):
			Chat.add("error", text.substr(1))
		else:
			Chat.add("dev", text)


func _find_bot(bot_name: String) -> Bot:
	var manager := get_tree().get_first_node_in_group("bot_manager") as BotManager
	return manager.find_bot(bot_name.strip_edges()) if manager and not bot_name.strip_edges().is_empty() else null


## A name as the player is known by, in its saved case, if they're online.
func _player_name(typed: String) -> String:
	var bot := _find_bot(typed)
	return bot.profile.char_name if bot else typed.capitalize()
