class_name QuestWindow
extends Control
## Classic quest dialog with an NPC. The first page lists the NPC's quests (and
## their trainer or vendor services); an NPC with a single quest and nothing
## else opens straight to it. A new quest shows its text, objectives and
## rewards with Accept. One underway shows what's still needed, and a finished
## one shows the rewards to choose from and Complete Quest. Closes when the
## player walks away.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
signal hovered(item: Dictionary)
## The player picked "Browse goods" or "Train": kind is "vendor" or "trainer".
signal service(npc: Npc, kind: String)

## Classic INTERACTION_DISTANCE, in yards.
const RANGE := 5.0
const WIDTH := 180.0
const BODY_HEIGHT := 168.0
const FONT_SIZE := 6
const TITLE_SIZE := 8
const ICON := 13.0
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const GOLD := Color("ffd100")
const TEXT := Color(0.92, 0.9, 0.84)
const HEADING := Color(1, 0.85, 0.4)
const GREY := Color(0.6, 0.6, 0.6)
const SELECTED := Color(1, 1, 1, 0.15)

enum Page { LIST, DETAILS, PROGRESS, REWARD }

var npc: Npc

var _player: Player
var _ui_scale := 1.0
var _page := Page.LIST
var _quest_id := 0
var _choice := -1
var _choice_rows: Array[ColorRect] = []
var _body: VBoxContainer


func open(quest_npc: Npc, player: Player, ui_scale: float) -> void:
	npc = quest_npc
	_player = player
	_ui_scale = ui_scale
	visible = true
	var entries := QuestLog.for_npc(npc.npc_id())
	if entries.size() == 1 and _services().is_empty():
		show_quest(entries[0].id)
	else:
		_show(Page.LIST)


func close() -> void:
	npc = null
	visible = false
	hovered.emit({})


func _process(_delta: float) -> void:
	if npc == null:
		return
	if not is_instance_valid(npc) or _player.global_position.distance_to(npc.global_position) > RANGE:
		close()


## Opens the right page for a quest: its offer, what's still needed, or its
## rewards. Quests that only ask you to talk, or to kill, go straight to the
## rewards once done, as in classic.
func show_quest(id: int) -> void:
	_quest_id = id
	_choice = -1
	match QuestLog.status(id):
		QuestLog.Status.AVAILABLE:
			_show(Page.DETAILS)
		QuestLog.Status.COMPLETE:
			_show(Page.PROGRESS if not QuestDB.get_quest(id).items.is_empty() else Page.REWARD)
		QuestLog.Status.ACTIVE:
			_show(Page.PROGRESS)
		_:
			_show(Page.LIST)


func accept() -> void:
	var error := QuestLog.accept(_quest_id)
	if not error.is_empty():
		message.emit(error, true)
		return
	Sfx.play("loot")
	close()


func complete() -> void:
	var error := QuestLog.complete(_quest_id, _choice, _player.progression)
	if not error.is_empty():
		message.emit(error, true)
		return
	Sfx.play("level_up")
	# Classic offers the next quest in a chain straight away.
	if QuestLog.for_npc(npc.npc_id()).is_empty():
		close()
	else:
		_show(Page.LIST)


func _services() -> Array[String]:
	var services: Array[String] = []
	if npc.vendor != 0:
		services.append("vendor")
	if not npc.trainer.is_empty():
		services.append("trainer")
	return services


func _show(page: Page) -> void:
	_page = page
	_build.call_deferred()


func _build() -> void:
	if npc == null:
		return
	for child in get_children():
		child.queue_free()
	_choice_rows.clear()
	hovered.emit({})
	size = Vector2(WIDTH, 14 + BODY_HEIGHT + 20) * _ui_scale
	var back := ColorRect.new()
	back.color = BACK
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	_text(self, Vector2(4, 1), npc.npc_name, HEADING, 7)
	var close_button := _text(self, Vector2(WIDTH - 9, 1), "x", Color(0.9, 0.4, 0.4), 7)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(4, 14) * _ui_scale
	scroll.size = Vector2(WIDTH - 8, BODY_HEIGHT) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", roundi(2 * _ui_scale))
	_body.custom_minimum_size.x = (WIDTH - 16) * _ui_scale
	scroll.add_child(_body)
	match _page:
		Page.LIST:
			_build_list()
		Page.DETAILS:
			_build_details()
		Page.PROGRESS:
			_build_progress()
		Page.REWARD:
			_build_reward()


func _build_list() -> void:
	_para("Well met, %s. What brings you to me?" % GameState.char_name, TEXT)
	var entries := QuestLog.for_npc(npc.npc_id())
	if not entries.is_empty():
		_para("Quests", HEADING)
	for entry: Dictionary in entries:
		var id: int = entry.id
		var marker := "?" if entry.status != QuestLog.Status.AVAILABLE else "!"
		var color := GREY if entry.status == QuestLog.Status.ACTIVE or QuestLog.is_trivial(id) else GOLD
		_link("%s  %s" % [marker, QuestDB.get_quest(id).title], color, func() -> void: show_quest(id))
	for kind in _services():
		var label := "Let me browse your goods." if kind == "vendor" else "I would like to train."
		_link(label, TEXT, func() -> void:
			var chosen := npc
			close()
			service.emit(chosen, kind)
		)
	_buttons([["Goodbye", close]])


func _build_details() -> void:
	var quest := QuestDB.get_quest(_quest_id)
	_para(quest.title, GOLD, TITLE_SIZE)
	_para(_fill_name(quest.details), TEXT)
	_para("Quest Objectives", HEADING, 7)
	_para(quest.objectives, TEXT)
	_rewards(quest, false)
	_buttons([["Accept", accept], ["Decline", _back]])


func _build_progress() -> void:
	var quest := QuestDB.get_quest(_quest_id)
	_para(quest.title, GOLD, TITLE_SIZE)
	var text: String = quest.progress if not str(quest.progress).is_empty() else quest.objectives
	_para(_fill_name(text), TEXT)
	if not quest.items.is_empty():
		_para("Required items:", HEADING)
		for need: Array in quest.items:
			_item_row(int(need[0]), int(need[1]), -1, Inventory.count_item(int(need[0])))
	var done := QuestLog.is_complete(_quest_id)
	_buttons([["Continue", func() -> void: _show(Page.REWARD), not done], ["Goodbye", _back]])


func _build_reward() -> void:
	var quest := QuestDB.get_quest(_quest_id)
	_para(quest.title, GOLD, TITLE_SIZE)
	_para(_fill_name(quest.completion), TEXT)
	_rewards(quest, true)
	_buttons([["Complete Quest", complete]])


## The rewards: the items to choose from, the items always given, and money.
func _rewards(quest: Dictionary, choosing: bool) -> void:
	var choices: Array = quest.reward_choices
	var items: Array = quest.reward_items
	if choices.is_empty() and items.is_empty() and int(quest.money) <= 0:
		return
	_para("Rewards", HEADING, 7)
	if not choices.is_empty():
		_para("Choose one of these rewards:" if choosing else "You will be able to choose one of these rewards:", TEXT)
		for i in choices.size():
			_item_row(int(choices[i][0]), int(choices[i][1]), i if choosing else -1)
	if not items.is_empty():
		_para("You will also receive:" if not choices.is_empty() else "You will receive:", TEXT)
		for reward: Array in items:
			_item_row(int(reward[0]), int(reward[1]))
	if int(quest.money) > 0:
		_para("Money: %s" % ItemDB.money_text(int(quest.money)), HEADING)


func _back() -> void:
	if QuestLog.for_npc(npc.npc_id()).size() > 1 or not _services().is_empty():
		_show(Page.LIST)
	else:
		close()


## "$N" in quest text is the player's name, as in classic.
func _fill_name(text: String) -> String:
	return text.replace("$N", GameState.char_name)


func _para(text: String, color: Color, font_size := FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = (WIDTH - 16) * _ui_scale
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style(label, color, font_size)
	_body.add_child(label)
	return label


func _link(text: String, color: Color, pressed: Callable) -> void:
	var label := _para(text, color)
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	label.mouse_entered.connect(func() -> void: label.modulate = Color(1.3, 1.3, 1.3))
	label.mouse_exited.connect(func() -> void: label.modulate = Color.WHITE)
	label.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			pressed.call()
	)


## An item with its icon and name. `choice` >= 0 makes it selectable as a
## reward; `have` >= 0 shows "have/needed".
func _item_row(id: int, count: int, choice := -1, have := -1) -> void:
	var item := ItemDB.get_item(id)
	var row := ColorRect.new()
	row.color = Color.TRANSPARENT
	row.custom_minimum_size = Vector2(WIDTH - 16, ICON + 2) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	_body.add_child(row)
	var icon := ColorRect.new()
	var quality := ItemDB.quality_color(item)
	icon.color = quality.darkened(0.6)
	icon.position = Vector2.ONE * _ui_scale
	icon.size = Vector2.ONE * ICON * _ui_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var border := ReferenceRect.new()
	border.border_color = quality
	border.border_width = maxf(_ui_scale, 1.0)
	border.editor_only = false
	border.size = icon.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(border)
	var initials := ""
	for word in str(item.name).split(" ", false):
		if word[0] == word[0].to_upper() and word[0] != "'":
			initials += word[0]
	_text(icon, Vector2(1, 1), initials.substr(0, 2), Color.WHITE, 5)
	var amount := ""
	if have >= 0:
		amount = "  %d/%d" % [mini(have, count), count]
	elif count > 1:
		amount = "  x%d" % count
	_text(row, Vector2(ICON + 4, 3), str(item.name) + amount, quality, FONT_SIZE)
	row.mouse_entered.connect(func() -> void: hovered.emit(item))
	row.mouse_exited.connect(func() -> void: hovered.emit({}))
	if choice >= 0:
		_choice_rows.append(row)
		row.gui_input.connect(func(event: InputEvent) -> void:
			var button := event as InputEventMouseButton
			if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
				_choice = choice
				for i in _choice_rows.size():
					_choice_rows[i].color = SELECTED if i == choice else Color.TRANSPARENT
		)


## Buttons along the bottom: [text, callable, disabled].
func _buttons(buttons: Array) -> void:
	var x := WIDTH - 4.0
	for i in range(buttons.size() - 1, -1, -1):
		var entry: Array = buttons[i]
		var button := Button.new()
		button.text = entry[0]
		button.disabled = entry.size() > 2 and entry[2]
		button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		var width := 16.0 + str(entry[0]).length() * 3.6
		x -= width
		button.position = Vector2(x, 16 + BODY_HEIGHT) * _ui_scale
		button.size = Vector2(width, 12) * _ui_scale
		var action: Callable = entry[1]
		# Deferred: the page rebuild frees this button, which can't happen while
		# it handles its own press.
		button.pressed.connect(func() -> void: action.call_deferred())
		add_child(button)
		x -= 4.0


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
