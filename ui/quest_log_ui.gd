class_name QuestLogUI
extends Control
## The quest log (L): quests underway on top, the selected quest's objectives,
## progress, text and rewards below, and Abandon with a confirmation.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal hovered(item: Dictionary)
## Shift-click on a quest: link it in the chat.
signal link_requested(quest_id: int)

const WIDTH := 170.0
const LIST_HEIGHT := 56.0
const DETAIL_HEIGHT := 104.0
const ROW := 10.0
const FONT_SIZE := 6
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const GOLD := Color("ffd100")
const TEXT := Color(0.92, 0.9, 0.84)
const HEADING := Color(1, 0.85, 0.4)
const GREY := Color(0.6, 0.6, 0.6)
const DONE := Color(0.45, 0.9, 0.45)
const SELECTED := Color(1, 1, 1, 0.12)

var _ui_scale := 1.0
var _selected := 0
var _rebuild_queued := false
var _confirming := false


func setup(ui_scale: float) -> void:
	_ui_scale = ui_scale
	visible = false
	GameState.quests_changed.connect(_queue_rebuild)
	GameState.inventory_changed.connect(_queue_rebuild)


func toggle() -> void:
	visible = not visible
	_confirming = false
	if visible:
		_build()
	else:
		hovered.emit({})


func close() -> bool:
	if not visible:
		return false
	toggle()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		toggle()
		get_viewport().set_input_as_handled()


func _queue_rebuild() -> void:
	if visible and not _rebuild_queued:
		_rebuild_queued = true
		_build.call_deferred()


func _ids() -> Array:
	var ids := GameState.quests.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(QuestDB.get_quest(a).level) < int(QuestDB.get_quest(b).level))
	return ids


func _build() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	var ids := _ids()
	_selected = clampi(_selected, 0, maxi(ids.size() - 1, 0))
	size = Vector2(WIDTH, 14 + LIST_HEIGHT + 4 + DETAIL_HEIGHT + 18) * _ui_scale
	var back := ColorRect.new()
	back.color = BACK
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	_text(self, Vector2(4, 1), "Quest Log", HEADING, 7)
	_text(self, Vector2(WIDTH - 40, 2), "%d/%d" % [ids.size(), QuestLog.MAX_QUESTS], GREY, FONT_SIZE)
	var close_button := _text(self, Vector2(WIDTH - 9, 1), "x", Color(0.9, 0.4, 0.4), 7)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			toggle.call_deferred()
	)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	var list_scroll := _scroll(Vector2(4, 14), Vector2(WIDTH - 8, LIST_HEIGHT), list)
	add_child(list_scroll)
	if ids.is_empty():
		_line(list, "No quests yet. Look for townsfolk with a ! over their heads.", GREY)
	for i in ids.size():
		var id: int = ids[i]
		var quest := QuestDB.get_quest(id)
		var row := ColorRect.new()
		row.color = SELECTED if i == _selected else Color.TRANSPARENT
		row.custom_minimum_size = Vector2(WIDTH - 12, ROW) * _ui_scale
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		list.add_child(row)
		var complete := QuestLog.is_complete(id)
		var color := CombatRules.level_color(GameState.level, int(quest.level))
		_text(row, Vector2(2, 1), "[%d] %s%s" % [quest.level, quest.title, " (Complete)" if complete else ""], color, FONT_SIZE)
		row.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and button.shift_pressed:
				link_requested.emit(id)
			elif button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_selected = i
				_confirming = false
				_build.call_deferred()
		)

	if ids.is_empty():
		return
	var id: int = ids[_selected]
	var quest := QuestDB.get_quest(id)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	add_child(_scroll(Vector2(4, 18 + LIST_HEIGHT), Vector2(WIDTH - 8, DETAIL_HEIGHT), detail))
	_line(detail, quest.title, GOLD, 7)
	_line(detail, quest.objectives, TEXT)
	for objective: Array in QuestLog.objective_lines(id):
		_line(detail, "  - " + objective[0], DONE if objective[1] else TEXT)
	_line(detail, "Description", HEADING, 7)
	_line(detail, str(quest.details).replace("$N", GameState.char_name), TEXT)
	var rewards: Array = quest.reward_choices + quest.reward_items
	if not rewards.is_empty() or int(quest.money) > 0:
		_line(detail, "Rewards", HEADING, 7)
		if not quest.reward_choices.is_empty():
			_line(detail, "Choose one of:", TEXT)
		for reward: Array in rewards:
			var item := ItemDB.get_item(int(reward[0]))
			var label := _line(detail, "  %s%s" % [item.name, " x%d" % reward[1] if int(reward[1]) > 1 else ""], ItemDB.quality_color(item))
			label.mouse_filter = Control.MOUSE_FILTER_STOP
			label.mouse_entered.connect(func() -> void: hovered.emit(item))
			label.mouse_exited.connect(func() -> void: hovered.emit({}))
		if int(quest.money) > 0:
			_line(detail, "Money: %s" % ItemDB.money_text(int(quest.money)), HEADING)

	var abandon := Button.new()
	abandon.text = "Abandon \"%s\"?" % quest.title if _confirming else "Abandon Quest"
	abandon.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	abandon.position = Vector2(4, 22 + LIST_HEIGHT + DETAIL_HEIGHT) * _ui_scale
	abandon.size = Vector2(WIDTH - 8, 12) * _ui_scale
	if _confirming:
		abandon.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	abandon.pressed.connect(func() -> void:
		if _confirming:
			_confirming = false
			QuestLog.abandon(id)
		else:
			_confirming = true
			_build.call_deferred()
	)
	add_child(abandon)


func _scroll(at: Vector2, scroll_size: Vector2, content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.position = at * _ui_scale
	scroll.size = scroll_size * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.custom_minimum_size.x = (scroll_size.x - 6) * _ui_scale
	scroll.add_child(content)
	return scroll


func _line(parent: Control, text: String, color: Color, font_size := FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = (WIDTH - 16) * _ui_scale
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(label, color, font_size)
	parent.add_child(label)
	return label


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
