class_name SocialWindow
extends Control
## The Social window (O), like classic's: a Friends tab listing the friends
## list with each friend's level, class and zone (or Offline), and a Who tab
## listing every player in the zone (playerbots) with level, race and class,
## filtered by a search box. Friends are kept per character
## (GameState.friends). Sizes are in HUD units, times ui_scale.

## Lines for the HUD's message log ("Aldric is already your friend.").
signal message(text: String, is_error: bool)

const WIDTH := 170.0
const LIST_HEIGHT := 112.0
const ROW := 10.0
const FONT_SIZE := 6
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const HEADING := Color(1, 0.85, 0.4)
const TEXT := Color(0.92, 0.9, 0.84)
const GREY := Color(0.55, 0.55, 0.55)
const SELECTED := Color(1, 1, 1, 0.12)
const TAB_SELECTED := Color(1, 0.85, 0.3)
const TAB_OTHER := Color(0.6, 0.6, 0.65)
const FRIENDS := "Friends"
const WHO := "Who"
## Classic's friends list holds 50.
const MAX_FRIENDS := 50

var _ui_scale := 1.0
var _tab := FRIENDS
var _selected := ""
var _filter := ""
var _adding := false
var _refresh_left := 0.0


func setup(ui_scale: float) -> void:
	_ui_scale = ui_scale
	visible = false


func toggle() -> void:
	visible = not visible
	_adding = false
	if visible:
		_build()


func close() -> bool:
	if not visible:
		return false
	toggle()
	return true


func show_tab(tab: String) -> void:
	_tab = tab
	_selected = ""
	_adding = false
	visible = true
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("social"):
		toggle()
		get_viewport().set_input_as_handled()


## Levels, zones and who's about change: redraw every second while open.
func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0 and not _adding and not get_viewport().gui_get_focus_owner() is LineEdit:
		_refresh_left = 1.0
		_build()


func _manager() -> BotManager:
	return get_tree().get_first_node_in_group("bot_manager") as BotManager


## Every player in the zone: the playerbots in the world, by name.
func _online() -> Array[Bot]:
	var manager := _manager()
	var list: Array[Bot] = manager.bots() if manager else []
	list.sort_custom(func(a: Bot, b: Bot) -> bool: return a.profile.char_name < b.profile.char_name)
	return list


func _build() -> void:
	for child in get_children():
		child.queue_free()
	size = Vector2(WIDTH, 14 + 12 + LIST_HEIGHT + 34) * _ui_scale
	var back := ColorRect.new()
	back.color = BACK
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	_text(self, Vector2(4, 1), "Social", HEADING, 7)
	var close_button := _text(self, Vector2(WIDTH - 9, 1), "x", Color(0.9, 0.4, 0.4), 7)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			toggle.call_deferred()
	)
	var x := 4.0
	for tab in [FRIENDS, WHO]:
		var button := _button(tab, Vector2(x, 13), Vector2(40, 10), show_tab.bind(tab))
		button.add_theme_color_override("font_color", TAB_SELECTED if tab == _tab else TAB_OTHER)
		x += 42
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 26 + ROW) * _ui_scale
	scroll.size = Vector2(WIDTH - 8, LIST_HEIGHT - ROW) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.custom_minimum_size.x = (WIDTH - 14) * _ui_scale
	scroll.add_child(rows)
	add_child(scroll)
	if _tab == FRIENDS:
		_build_friends(rows)
	else:
		_build_who(rows)


# Friends.

func _build_friends(rows: VBoxContainer) -> void:
	_columns(["Name", "Level", "Class", "Zone"])
	var online := {}
	for bot in _online():
		online[bot.profile.char_name] = bot
	if GameState.friends.is_empty():
		_note(rows, "Your friends list is empty. Add friends here, or from Who.")
	for friend_name in GameState.friends:
		var bot: Bot = online.get(friend_name)
		if bot:
			_row(rows, friend_name, [friend_name, str(bot.profile.level), ClassicData.CLASS_NAMES[bot.profile.char_class], AshfordVale.ZONE_NAME], TEXT)
		else:
			var entry := _manager().entry(friend_name) if _manager() else {}
			var known := not entry.is_empty()
			var level := str(entry.level) if known else ""
			var class_name_text: String = ClassicData.CLASS_NAMES.get(int(entry["class"]), "") if known else ""
			_row(rows, friend_name, [friend_name, level, class_name_text, "Offline"], GREY)
	var bottom := 30 + LIST_HEIGHT
	if _adding:
		var field := LineEdit.new()
		field.placeholder_text = "Friend's name"
		field.position = Vector2(4, bottom) * _ui_scale
		field.size = Vector2(WIDTH - 60, 12) * _ui_scale
		field.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		field.max_length = GameState.NAME_MAX
		field.text_submitted.connect(func(text: String) -> void: _add_friend(text))
		_hold_keys(field)
		add_child(field)
		field.grab_focus.call_deferred()
		_button("Add", Vector2(WIDTH - 54, bottom), Vector2(24, 12), func() -> void: _add_friend(field.text))
		_button("Cancel", Vector2(WIDTH - 28, bottom), Vector2(24, 12), func() -> void:
			_adding = false
			_build()
		)
		return
	_button("Add Friend", Vector2(4, bottom), Vector2(50, 12), func() -> void:
		_adding = true
		_build()
	)
	_button("Remove Friend", Vector2(57, bottom), Vector2(56, 12), _remove_friend)
	_button("Invite", Vector2(116, bottom), Vector2(50, 12), _invite_selected)


## Classic's checks: a real player, not yourself, not already listed.
func _add_friend(text: String) -> void:
	var wanted := text.strip_edges()
	if wanted.is_empty():
		return
	var manager := _manager()
	var entry := manager.entry(wanted) if manager else {}
	if wanted.to_lower() == GameState.char_name.to_lower():
		message.emit("You can't put yourself on your friends list.", true)
	elif entry.is_empty():
		message.emit("Player not found.", true)
	elif entry.name in GameState.friends:
		message.emit("%s is already your friend." % entry.name, true)
	elif GameState.friends.size() >= MAX_FRIENDS:
		message.emit("Your friends list is full.", true)
	else:
		GameState.friends.append(entry.name)
		GameState.friends_changed.emit()
		message.emit("%s added to friends." % entry.name, false)
		_selected = entry.name
	_adding = false
	_build()


func _remove_friend() -> void:
	if _selected in GameState.friends:
		GameState.friends.erase(_selected)
		GameState.friends_changed.emit()
		message.emit("%s removed from friends." % _selected, false)
		_selected = ""
		_build()


func _invite_selected() -> void:
	var manager := _manager()
	var bot := manager.find_bot(_selected) if manager and not _selected.is_empty() else null
	if bot == null:
		message.emit("Select a player who is online." if _selected.is_empty() or _tab == FRIENDS else "Player not found.", true)
		return
	Party.invite(bot)


# Who.

func _build_who(rows: VBoxContainer) -> void:
	_columns(["Name", "Level", "Race", "Class"])
	var shown := 0
	for bot in _online():
		var p := bot.profile
		var columns: Array = [p.char_name, str(p.level), ClassicData.RACE_NAMES[p.race], ClassicData.CLASS_NAMES[p.char_class]]
		if not _filter.is_empty() and not " ".join(columns).to_lower().contains(_filter.to_lower()):
			continue
		_row(rows, p.char_name, columns, TEXT)
		shown += 1
	var bottom := 30 + LIST_HEIGHT
	_text(self, Vector2(4, bottom - 9), "%d player%s found in %s" % [shown, "" if shown == 1 else "s", AshfordVale.ZONE_NAME], GREY, FONT_SIZE)
	var field := LineEdit.new()
	field.placeholder_text = "Search name, level, race or class"
	field.text = _filter
	field.position = Vector2(4, bottom) * _ui_scale
	field.size = Vector2(76, 12) * _ui_scale
	field.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	field.text_changed.connect(func(text: String) -> void:
		_filter = text
		_build.call_deferred()
		_refocus.call_deferred()
	)
	_hold_keys(field)
	add_child(field)
	_button("Add Friend", Vector2(83, bottom), Vector2(42, 12), func() -> void:
		if not _selected.is_empty():
			_add_friend(_selected)
	)
	_button("Invite", Vector2(128, bottom), Vector2(38, 12), _invite_selected)


## Typing in the search box rebuilds the window: keep typing in the new box.
func _refocus() -> void:
	for child in get_children():
		if child is LineEdit:
			child.grab_focus()
			child.caret_column = child.text.length()


# Building blocks.

## While a text box has the keyboard, the movement keys type instead.
func _hold_keys(field: LineEdit) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	field.focus_entered.connect(func() -> void: player.typing = true)
	field.focus_exited.connect(func() -> void: player.typing = false)
	field.tree_exiting.connect(func() -> void:
		if field.has_focus():
			player.typing = false
	)

func _columns(names: Array) -> void:
	var at := [2.0, 62.0, 84.0, 122.0]
	for i in names.size():
		_text(self, Vector2(4 + at[i], 26), names[i], HEADING, FONT_SIZE)


## A clickable row; the selected one is highlighted.
func _row(rows: VBoxContainer, key: String, columns: Array, color: Color) -> void:
	var row := ColorRect.new()
	row.color = SELECTED if key == _selected else Color.TRANSPARENT
	row.custom_minimum_size = Vector2(WIDTH - 14, ROW) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	rows.add_child(row)
	var at := [2.0, 62.0, 84.0, 122.0]
	for i in columns.size():
		_text(row, Vector2(at[i], 1), str(columns[i]), color, FONT_SIZE)
	row.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			_selected = key
			_build.call_deferred()
	)


func _note(rows: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = (WIDTH - 16) * _ui_scale
	_style(label, GREY, FONT_SIZE)
	rows.add_child(label)


func _button(text: String, at: Vector2, button_size: Vector2, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at * _ui_scale
	button.size = button_size * _ui_scale
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	add_child(button)
	return button


func _text(parent: Node, at: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(label, color, font_size)
	parent.add_child(label)
	return label


func _style(label: Label, color: Color, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
