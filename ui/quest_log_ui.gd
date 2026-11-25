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
	# Quests and bags changing (a kill, a quest item looted) only update what
	# shows them; the rows are made again only when quests come or go.
	GameState.quests_changed.connect(_queue_refresh)
	GameState.inventory_changed.connect(_queue_refresh)


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
	if Settings.pressed(event, "quest_log"):
		toggle()
		get_viewport().set_input_as_handled()


func _queue_refresh() -> void:
	if visible and not _rebuild_queued:
		_rebuild_queued = true
		_refresh.call_deferred()


func _ids() -> Array:
	var ids := GameState.quests.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return int(QuestDB.get_quest(a).level) < int(QuestDB.get_quest(b).level))
	return ids


## What's drawn, kept to update in place: the quest count, the rows
## ({ id, row, label }), the picked quest's details (their own box, made
## again only when another is picked) with its objective lines, and Abandon.
var _count_label: Label
var _list: VBoxContainer
var _row_views: Array[Dictionary] = []
var _shown_ids: Array = []
var _detail_holder: Control
var _objective_labels: Array[Label] = []
var _abandon: Button


## The frame, once on opening.
func _build() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	_row_views.clear()
	size = Vector2(WIDTH, 14 + LIST_HEIGHT + 4 + DETAIL_HEIGHT + 18) * _ui_scale
	UiStyle.panel(self, size / _ui_scale, _ui_scale)
	UiStyle.title(self, Vector2(5, 1.5), "Quest Log", _ui_scale)
	_count_label = _text(self, Vector2(WIDTH - 42, 2), "", GREY, FONT_SIZE)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, toggle)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	add_child(_scroll(Vector2(4, 14), Vector2(WIDTH - 8, LIST_HEIGHT), _list))
	_detail_holder = Control.new()
	_detail_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_holder)
	_abandon = Button.new()
	_abandon.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	_abandon.position = Vector2(4, 22 + LIST_HEIGHT + DETAIL_HEIGHT) * _ui_scale
	_abandon.size = Vector2(WIDTH - 8, 12) * _ui_scale
	_abandon.pressed.connect(func() -> void:
		if _shown_ids.is_empty():
			return
		var id: int = _shown_ids[_selected]
		if _confirming:
			_confirming = false
			QuestLog.abandon(id)
		else:
			_confirming = true
			_update_abandon())
	add_child(_abandon)
	_fill_list()


## The rows, made again when quests come or go.
func _fill_list() -> void:
	for child in _list.get_children():
		child.queue_free()
	_row_views.clear()
	var ids := _ids()
	_shown_ids = ids
	_count_label.text = "%d/%d" % [ids.size(), QuestLog.MAX_QUESTS]
	if ids.is_empty():
		_line(_list, "No quests yet. Look for townsfolk with a ! over their heads.", GREY)
	for i in ids.size():
		var id: int = ids[i]
		var row := ColorRect.new()
		row.color = Color.TRANSPARENT
		row.custom_minimum_size = Vector2(WIDTH - 12, ROW) * _ui_scale
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_list.add_child(row)
		var label := _text(row, Vector2(2, 1), "", Color.WHITE, FONT_SIZE)
		_row_views.append({ "id": id, "row": row, "label": label })
		var index := i
		row.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and button.shift_pressed:
				link_requested.emit(id)
			elif button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_confirming = false
				_select(index)
		)
	_update_rows()
	_select(clampi(_selected, 0, maxi(ids.size() - 1, 0)))


## Quests or bags changed: rows and objectives in place, unless quests came
## or went.
func _refresh() -> void:
	_rebuild_queued = false
	if not visible or _list == null or not is_instance_valid(_list):
		return
	if _ids() != _shown_ids:
		_fill_list()
		return
	_update_rows()
	if not _shown_ids.is_empty():
		var lines := QuestLog.objective_lines(int(_shown_ids[_selected]))
		for i in mini(lines.size(), _objective_labels.size()):
			_objective_labels[i].text = "  - " + str(lines[i][0])
			_objective_labels[i].add_theme_color_override("font_color", DONE if lines[i][1] else TEXT)


func _update_rows() -> void:
	for view: Dictionary in _row_views:
		var quest := QuestDB.get_quest(int(view.id))
		var label: Label = view.label
		label.text = "[%d] %s%s" % [quest.level, quest.title, " (Complete)" if QuestLog.is_complete(int(view.id)) else ""]
		label.add_theme_color_override("font_color", CombatRules.level_color(GameState.level, int(quest.level)))


func _select(index: int) -> void:
	_selected = index
	for i in _row_views.size():
		(_row_views[i].row as ColorRect).color = SELECTED if i == index else Color.TRANSPARENT
	_show_detail()
	_update_abandon()


func _update_abandon() -> void:
	_abandon.visible = not _shown_ids.is_empty()
	if _shown_ids.is_empty():
		return
	var quest := QuestDB.get_quest(int(_shown_ids[_selected]))
	_abandon.text = "Abandon \"%s\"?" % quest.title if _confirming else "Abandon Quest"
	if _confirming:
		_abandon.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	else:
		_abandon.remove_theme_color_override("font_color")


## The picked quest's text, objectives and rewards: made again only when
## another quest is picked.
func _show_detail() -> void:
	for child in _detail_holder.get_children():
		child.queue_free()
	_objective_labels.clear()
	if _shown_ids.is_empty():
		return
	var id: int = _shown_ids[_selected]
	var quest := QuestDB.get_quest(id)
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	_detail_holder.add_child(_scroll(Vector2(4, 18 + LIST_HEIGHT), Vector2(WIDTH - 8, DETAIL_HEIGHT), detail))
	_line(detail, quest.title, GOLD, 7)
	_line(detail, quest.objectives, TEXT)
	for objective: Array in QuestLog.objective_lines(id):
		_objective_labels.append(_line(detail, "  - " + objective[0], DONE if objective[1] else TEXT))
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
