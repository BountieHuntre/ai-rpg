class_name LootWindow
extends Control
## Classic-style loot window for a corpse: money first, then one row per item.
## Click a row to take it. Hovering an item shows its tooltip. Closes itself
## when the corpse is empty, respawns or the player walks away.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
signal hovered(item: Dictionary, soulbound: bool)
signal closed

## Classic INTERACTION_DISTANCE, in yards (one game unit).
const LOOT_RANGE := 5.0
const WIDTH := 110.0
const ROW_HEIGHT := 16.0
const ICON_SIZE := 13.0
const FONT_SIZE := 7
const BACK := Color(0.08, 0.08, 0.1, 0.92)
const ROW_HOVER := Color(1, 1, 1, 0.08)
const COPPER_COLOR := Color(0.85, 0.55, 0.25)

var corpse: Enemy

var _player: Player
var _ui_scale := 1.0


func open(new_corpse: Enemy, player: Player, ui_scale: float) -> void:
	corpse = new_corpse
	_player = player
	_ui_scale = ui_scale
	visible = true
	_rebuild()


func close() -> void:
	if corpse == null:
		return
	corpse = null
	visible = false
	hovered.emit({}, false)
	closed.emit()


## Takes the money and every item that fits, as with shift-click looting.
static func take_all(target: Enemy) -> Array[String]:
	var messages: Array[String] = []
	if target.loot_money > 0:
		messages.append(_take_money(target))
	while not target.loot.is_empty():
		var result := _take_item(target, 0)
		messages.append(result)
		if result == "Inventory is full.":
			break
	return messages


static func _take_money(target: Enemy) -> String:
	var amount := target.loot_money
	target.loot_money = 0
	Sfx.play("coins")
	# In a party the money is split between the members nearby.
	if not Party.members.is_empty():
		var share := Party.money_share(amount, target.global_position)
		GameState.money += share
		return "Your share of the loot is %s." % ItemDB.money_words(share)
	GameState.money += amount
	return "You loot %s" % ItemDB.money_words(amount)


static func _take_item(target: Enemy, index: int) -> String:
	var drop: Dictionary = target.loot[index]
	var left := GameState.add_item(drop.id, drop.count)
	var taken: int = drop.count - left
	if taken == 0:
		return "Inventory is full."
	if left > 0:
		drop.count = left
	else:
		target.loot.remove_at(index)
	Sfx.play("loot")
	var item := ItemDB.get_item(drop.id)
	return "You receive loot: [%s]%s." % [item.name, "x%d" % taken if taken > 1 else ""]


func _process(_delta: float) -> void:
	if corpse == null:
		return
	if not is_instance_valid(corpse) or not corpse.has_loot() or not _player.combatant.is_alive():
		close()
	elif _player.global_position.distance_to(corpse.global_position) > LOOT_RANGE:
		close()


func _refresh() -> void:
	if corpse and is_instance_valid(corpse) and corpse.has_loot():
		_rebuild()
	else:
		close()


func _rebuild() -> void:
	for child in get_children():
		child.free()
	var rows := corpse.loot.size() + (1 if corpse.loot_money > 0 else 0)
	size = Vector2(WIDTH, 14.0 + rows * ROW_HEIGHT + 3.0) * _ui_scale
	var back := ColorRect.new()
	back.color = BACK
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	_add_label(self, Vector2(4, 1), "Loot", Color(1, 0.85, 0.4))
	var close_button := _add_label(self, Vector2(WIDTH - 9, 1), "x", Color(0.9, 0.4, 0.4))
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_click(event):
			close()
	)

	var y := 14.0
	if corpse.loot_money > 0:
		_add_row(y, COPPER_COLOR, ItemDB.money_text(corpse.loot_money), Color(1, 1, 1), 1, func() -> void:
			if corpse.loot_money > 0:
				message.emit(_take_money(corpse), false)
		, {})
		y += ROW_HEIGHT
	for i in corpse.loot.size():
		var drop: Dictionary = corpse.loot[i]
		var item := ItemDB.get_item(drop.id)
		_add_row(y, ItemDB.quality_color(item), item.name, ItemDB.quality_color(item), drop.count, func() -> void:
			var index := corpse.loot.find(drop)
			if index >= 0:
				var result := _take_item(corpse, index)
				message.emit(result, result == "Inventory is full.")
		, item)
		y += ROW_HEIGHT


func _add_row(y: float, icon_color: Color, text: String, text_color: Color, count: int, on_click: Callable, item: Dictionary) -> void:
	var row := ColorRect.new()
	row.color = Color.TRANSPARENT
	row.position = Vector2(2, y) * _ui_scale
	row.size = Vector2(WIDTH - 4, ROW_HEIGHT - 1) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)
	var icon := ColorRect.new()
	icon.color = icon_color.darkened(0.55)
	icon.position = Vector2(1, 1) * _ui_scale
	icon.size = Vector2.ONE * ICON_SIZE * _ui_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var border := ReferenceRect.new()
	border.border_color = icon_color
	border.border_width = maxf(_ui_scale, 1.0)
	border.editor_only = false
	border.size = icon.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.add_child(border)
	if count > 1:
		_add_label(icon, Vector2(ICON_SIZE - 7, ICON_SIZE - 10), str(count), Color.WHITE)
	_add_label(row, Vector2(ICON_SIZE + 4, 2), text, text_color)
	row.mouse_entered.connect(func() -> void:
		row.color = ROW_HOVER
		hovered.emit(item, false)
	)
	row.mouse_exited.connect(func() -> void:
		row.color = Color.TRANSPARENT
		hovered.emit({}, false)
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if _is_click(event):
			on_click.call()
			hovered.emit({}, false)
			# The row can't be freed while it's handling its own input.
			_refresh.call_deferred()
	)


func _add_label(parent: Node, at: Vector2, text: String, color: Color) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
	parent.add_child(label)
	return label


func _is_click(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
