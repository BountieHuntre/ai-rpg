class_name InventoryUI
extends Control
## The bags window (B) and the character window (C) with equipment slots and
## stats. Classic controls: drag an item to another slot, or click to pick it
## up and click again to put it down or swap. Right-click equips or uses an
## item from the bags, unequips equipped items, and cancels a held item.
## Dropping a held item over the world, away from every window, asks
## "Do you want to destroy ...?" as classic does.
## Slot boxes are built once and redrawn in place. Freeing a slot while it
## handles a mouse press crashes Godot, so windows are only rebuilt (deferred)
## when bags are added or removed.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
## Shift-click on an item: link it in the chat.
signal link_requested(item_id: int)
## Right-click on a bag item while trading: put it up for trade.
signal trade_requested(ref: Dictionary)

const SLOT := 16.0
const GAP := 2.0
const FONT_SIZE := 6
const BAG_COLUMNS := 4
const BACK := Color(0.08, 0.08, 0.1, 0.92)
const EMPTY_SLOT := Color(0.16, 0.16, 0.2)
const TITLE := Color(1, 0.85, 0.4)
const LEFT_SLOTS := [
	Inventory.Slot.HEAD, Inventory.Slot.NECK, Inventory.Slot.SHOULDER, Inventory.Slot.BACK,
	Inventory.Slot.CHEST, Inventory.Slot.SHIRT, Inventory.Slot.TABARD, Inventory.Slot.WRIST,
]
const RIGHT_SLOTS := [
	Inventory.Slot.HANDS, Inventory.Slot.WAIST, Inventory.Slot.LEGS, Inventory.Slot.FEET,
	Inventory.Slot.FINGER_1, Inventory.Slot.FINGER_2, Inventory.Slot.TRINKET_1, Inventory.Slot.TRINKET_2,
]
const WEAPON_SLOTS := [Inventory.Slot.MAIN_HAND, Inventory.Slot.OFF_HAND, Inventory.Slot.RANGED]

var _player: Player
var _ui_scale := 1.0
var _screen := Vector2.ZERO
var _tooltip: ItemTooltip
var _bags_window: Control
var _character_window: Control
var _stats_text: Label
var _money_text: Label
## One entry per slot box: { "box": ColorRect, "ref": inventory ref }.
var _views: Array[Dictionary] = []
## Container sizes the windows were built for. A change means a rebuild.
var _layout := ""
## Where the item on the cursor came from, or {} when nothing is held.
var _held: Dictionary = {}
var _held_icon: Control
## True while a vendor window is open: right-clicking bag items sells them.
var selling := false
## A trade window is open: right-clicked bag items go into the trade.
var trading := false
var _rebuild_queued := false
## Whether a window point is over the HUD (any window, bar or frame), set by
## the HUD. Releasing a dragged item anywhere else offers to destroy it.
var is_over_ui := func(_point: Vector2) -> bool: return false
var _destroy_prompt: Control


func setup(player: Player, ui_scale: float, screen: Vector2, tooltip: ItemTooltip, open: Dictionary) -> void:
	_player = player
	_ui_scale = ui_scale
	_screen = screen
	_tooltip = tooltip
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.money_changed.connect(func() -> void: _money_text.text = ItemDB.money_text(GameState.money))
	_rebuild()
	_bags_window.visible = open.get("bags", false)
	_character_window.visible = open.get("character", false)


func open_bags() -> void:
	_bags_window.visible = true


## Where the bags window is on screen, or an empty rect when it's closed.
func bags_rect() -> Rect2:
	return _bags_window.get_global_rect() if _bags_window and _bags_window.visible else Rect2()


func open_state() -> Dictionary:
	return { "bags": _bags_window.visible, "character": _character_window.visible }


## Esc: drops the held item, or closes open windows. Returns whether it did anything.
func close_one() -> bool:
	if _destroy_prompt:
		_answer_destroy(false)
		return true
	if not _held.is_empty():
		_set_held({})
		return true
	if _bags_window.visible or _character_window.visible:
		_bags_window.visible = false
		_character_window.visible = false
		_tooltip.show_item({})
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("bags"):
		_bags_window.visible = not _bags_window.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("character_window"):
		_character_window.visible = not _character_window.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _character_window.visible:
		_stats_text.text = _character_sheet()
	if _held_icon:
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale


func _on_inventory_changed() -> void:
	if _current_layout() != _layout:
		_queue_rebuild()
	else:
		_refresh()


func _current_layout() -> String:
	return str(GameState.containers.map(func(container: Array) -> int: return container.size()))


func _queue_rebuild() -> void:
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	var open := open_state() if _bags_window else {}
	for child in get_children():
		child.queue_free()
	_views.clear()
	_held_icon = null
	_destroy_prompt = null
	_build_character_window()
	_build_bags_window()
	_layout = _current_layout()
	if not open.is_empty():
		_bags_window.visible = open.bags
		_character_window.visible = open.character
	_set_held(_held if not _held.is_empty() and not Inventory.stack_at(_held).is_empty() else {})


## Redraws every slot and the money from the current inventory.
func _refresh() -> void:
	for view in _views:
		_draw_view(view)
	_money_text.text = ItemDB.money_text(GameState.money)


# Windows.

func _build_character_window() -> void:
	var width := SLOT * 2 + GAP * 4 + 118.0
	var rows := LEFT_SLOTS.size()
	var height := 14.0 + rows * (SLOT + GAP) + SLOT + GAP * 3
	_character_window = _panel(Vector2(4, 50), Vector2(width, height))
	_text(_character_window, Vector2(4, 1), "Character (C)", TITLE, 7)
	for i in rows:
		var y := 14.0 + i * (SLOT + GAP)
		_slot(_character_window, Vector2(GAP, y), Inventory.equip_ref(LEFT_SLOTS[i]))
		_slot(_character_window, Vector2(width - SLOT - GAP, y), Inventory.equip_ref(RIGHT_SLOTS[i]))
	var weapons_y := 14.0 + rows * (SLOT + GAP)
	var weapons_x := (width - 3 * SLOT - 2 * GAP) / 2.0
	for i in WEAPON_SLOTS.size():
		_slot(_character_window, Vector2(weapons_x + i * (SLOT + GAP), weapons_y), Inventory.equip_ref(WEAPON_SLOTS[i]))
	_stats_text = _text(_character_window, Vector2(SLOT + GAP * 3, 13), "", Color.WHITE, FONT_SIZE)
	_character_window.visible = false


func _build_bags_window() -> void:
	var width := BAG_COLUMNS * (SLOT + GAP) + GAP
	var rows := 0
	for container: Array in GameState.containers:
		rows += ceili(container.size() / float(BAG_COLUMNS))
	var bag_gaps := 0
	for i in range(1, GameState.containers.size()):
		if not GameState.containers[i].is_empty():
			bag_gaps += 1
	var height := 14.0 + (SLOT + GAP) + 4.0 + rows * (SLOT + GAP) + bag_gaps * 4.0 + 12.0
	# Left of the right action bars, when they're shown.
	var at := Vector2(_screen.x - width - 4 - SpellUI.right_bars_layout(_screen).width, _screen.y - height - 40)
	_bags_window = _panel(at, Vector2(width, height))
	_text(_bags_window, Vector2(4, 1), "Bags (B)", TITLE, 7)
	# Bag slots along the top, as on the classic bag bar.
	for i in GameState.BAG_SLOTS:
		_slot(_bags_window, Vector2(GAP + i * (SLOT + GAP), 13), Inventory.bag_slot_ref(i))
	var y := 13.0 + SLOT + GAP + 4.0
	for bag in GameState.containers.size():
		var container: Array = GameState.containers[bag]
		if container.is_empty():
			continue
		if bag > 0:
			y += 4.0
		for i in container.size():
			var column := i % BAG_COLUMNS
			if i > 0 and column == 0:
				y += SLOT + GAP
			_slot(_bags_window, Vector2(GAP + column * (SLOT + GAP), y), Inventory.bag_ref(bag, i))
		y += SLOT + GAP
	_money_text = _text(_bags_window, Vector2(4, y), ItemDB.money_text(GameState.money), Color(1, 0.85, 0.4), FONT_SIZE)
	_bags_window.visible = false


func _character_sheet() -> String:
	var c := _player.combatant
	var s := _player.stats
	var lines := PackedStringArray()
	lines.append("Level %d %s %s" % [c.level, ClassicData.RACE_NAMES[s.race], ClassicData.CLASS_NAMES[s.char_class]])
	for i in ClassicData.STAT_NAMES.size():
		var bonus := int(s.gear_stats[i])
		lines.append("%s: %d%s" % [ClassicData.STAT_NAMES[i], s.stats[i], " (+%d)" % bonus if bonus > 0 else ""])
	lines.append("Health %d  Mana %d" % [c.max_health, c.max_mana])
	lines.append("Armor %d (%.1f%%)" % [c.armor, CombatRules.armor_reduction(c.armor, c.level) * 100.0])
	lines.append("Attack Power %d" % c.attack_power)
	var bonus_damage := c.attack_power / 14.0 * c.swing_interval
	lines.append("Damage %d-%d  Speed %.2f" % [floori(c.min_damage + bonus_damage), floori(c.max_damage + bonus_damage), c.swing_interval])
	lines.append("Crit %.2f%%  Spell %.2f%%" % [c.melee_crit, c.spell_crit])
	lines.append("Dodge %.2f%%  Parry %.2f%%" % [c.dodge, c.parry])
	lines.append("Block %.2f%% (%d)" % [c.block, c.block_value])
	lines.append("Mana regen %.1f / 2s" % s.current_mana_per_tick())
	lines.append("Health regen %.1f / 2s" % (0.0 if c.is_in_combat() else s.health_per_tick))
	return "\n".join(lines)


# Slots, clicks and dragging.

func _slot(parent: Control, at: Vector2, ref: Dictionary) -> void:
	var box := ColorRect.new()
	box.position = at * _ui_scale
	box.size = Vector2.ONE * SLOT * _ui_scale
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	var view := { "box": box, "ref": ref }
	_views.append(view)
	_draw_view(view)
	box.mouse_entered.connect(func() -> void:
		var current := Inventory.stack_at(ref)
		_tooltip.show_item({} if current.is_empty() else ItemDB.get_item(current.id), current.get("bound", false), int(current.get("durability", -1)), ref.kind == "bag", int(current.get("count", 1)))
	)
	box.mouse_exited.connect(func() -> void: _tooltip.show_item({}))
	box.gui_input.connect(func(event: InputEvent) -> void: _on_slot_input(event, ref))


## Draws a slot's contents. Only the box's decorations are replaced, never the
## box itself, which may be handling input right now.
func _draw_view(view: Dictionary) -> void:
	var box: ColorRect = view.box
	var ref: Dictionary = view.ref
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var stack := Inventory.stack_at(ref)
	if stack.is_empty():
		box.color = EMPTY_SLOT
		if ref.kind == "equip":
			_text(box, Vector2(1, 4), str(Inventory.SLOT_LABELS[ref.slot]).substr(0, 3), Color(0.45, 0.45, 0.5), 5)
		elif ref.kind == "bag_slot":
			_text(box, Vector2(1, 4), "Bag", Color(0.45, 0.45, 0.5), 5)
	else:
		_draw_item(box, ItemDB.get_item(stack.id), stack.count)
	box.modulate = Color(1, 1, 1, 0.35) if _held == ref else Color.WHITE


func _on_slot_input(event: InputEvent, ref: Dictionary) -> void:
	var button := event as InputEventMouseButton
	if button == null or _destroy_prompt:
		return
	var error := ""
	if button.button_index == MOUSE_BUTTON_LEFT and button.pressed and button.shift_pressed and _held.is_empty():
		var stack := Inventory.stack_at(ref)
		if not stack.is_empty():
			link_requested.emit(int(stack.id))
		return
	if button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		if _held.is_empty():
			if not Inventory.stack_at(ref).is_empty():
				_set_held(ref)
				Sfx.play("loot")
			return
		var from := _held
		_set_held({})
		error = Inventory.move(from, ref)
	elif button.button_index == MOUSE_BUTTON_LEFT:
		# Godot sends the release to the slot that was pressed. A release over
		# a different slot finishes a drag; over the same slot the item stays
		# on the cursor for click-to-place.
		var target := _view_at(button.global_position)
		if not _held.is_empty() and target.is_empty() and not is_over_ui.call(button.global_position):
			drop_held_on_world()
			get_viewport().set_input_as_handled()
			return
		if _held.is_empty() or target.is_empty() or target.ref == _held:
			return
		var from := _held
		_set_held({})
		error = Inventory.move(from, target.ref)
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		if not _held.is_empty():
			_set_held({})
			return
		match ref.kind:
			"bag":
				error = _right_click_bag_item(ref)
			"equip":
				error = Inventory.unequip(ref.slot)
	else:
		return
	_tooltip.show_item({})
	if not error.is_empty():
		message.emit(error, true)
	get_viewport().set_input_as_handled()


## Puts the item up for trade, sells to an open vendor, uses consumables, or
## equips gear and bags.
func _right_click_bag_item(ref: Dictionary) -> String:
	if trading:
		trade_requested.emit(ref)
		return ""
	if selling:
		var sold := Inventory.sell(ref)
		if sold.is_empty():
			Sfx.play("sell")
		return sold
	var stack := Inventory.stack_at(ref)
	if not stack.is_empty() and int(ItemDB.get_item(stack.id).get("spellid_1", 0)) > 0:
		return _player.spells.use_item(ref)
	return Inventory.use_from_bag(ref)


## Asks to destroy the held item, for a drop or click over the world. Returns
## whether an item was held. Bags in the bag slots are just put back.
## The bag or equipment slot of the item on the cursor, or {}.
func held_ref() -> Dictionary:
	return _held


func clear_held() -> void:
	_set_held({})


func drop_held_on_world() -> bool:
	if _held.is_empty() or _destroy_prompt:
		return not _held.is_empty()
	if _held.kind == "bag_slot":
		_set_held({})
		return true
	var stack := Inventory.stack_at(_held)
	if not Inventory.can_destroy(int(stack.id)):
		# Put back where it came from.
		_set_held({})
		message.emit(Inventory.ERR_CANT_DESTROY, true)
		return true
	var item := ItemDB.get_item(stack.id)
	var what: String = item.name if int(stack.count) <= 1 else "%d %s" % [stack.count, item.name]
	_tooltip.show_item({})
	_destroy_prompt = _panel(Vector2.ZERO, Vector2(150, 40))
	_destroy_prompt.name = "DestroyPrompt"
	_destroy_prompt.position = (get_viewport_rect().size - _destroy_prompt.size) / 2 - Vector2(0, 40) * _ui_scale
	var question := _text(_destroy_prompt, Vector2(4, 4), "Do you want to destroy %s?" % what, Color.WHITE, FONT_SIZE)
	question.size.x = 142 * _ui_scale
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		var choice := Button.new()
		choice.text = ["Yes", "No"][i]
		choice.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		choice.position = Vector2(30 + i * 52, 24) * _ui_scale
		choice.size = Vector2(38, 12) * _ui_scale
		var destroy := i == 0
		# Deferred: the prompt is freed in answer, and a button can't be freed
		# while it handles its own press.
		choice.pressed.connect(func() -> void: _answer_destroy.call_deferred(destroy))
		_destroy_prompt.add_child(choice)
	return true


func _answer_destroy(destroy: bool) -> void:
	if not _destroy_prompt:
		return
	_destroy_prompt.queue_free()
	_destroy_prompt = null
	var ref := _held
	_set_held({})
	if destroy and not ref.is_empty():
		Inventory.destroy(ref)


func _view_at(point: Vector2) -> Dictionary:
	for view in _views:
		var box: ColorRect = view.box
		if box.is_visible_in_tree() and box.get_global_rect().has_point(point):
			return view
	return {}


func _set_held(ref: Dictionary) -> void:
	_held = ref
	if _held_icon:
		_held_icon.queue_free()
		_held_icon = null
	if not ref.is_empty():
		var stack := Inventory.stack_at(ref)
		_held_icon = ColorRect.new()
		_held_icon.size = Vector2.ONE * SLOT * _ui_scale
		_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_draw_item(_held_icon, ItemDB.get_item(stack.id), stack.count)
		add_child(_held_icon)
		_held_icon.position = get_viewport().get_mouse_position() + Vector2(4, 4) * _ui_scale
	_refresh()


func _draw_item(box: ColorRect, item: Dictionary, count: int) -> void:
	var quality := ItemDB.quality_color(item)
	box.color = quality.darkened(0.6)
	var border := ReferenceRect.new()
	border.border_color = quality
	border.border_width = maxf(_ui_scale, 1.0)
	border.editor_only = false
	border.size = box.size
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(border)
	_text(box, Vector2(1, 1), _initials(item.name), Color.WHITE, 6)
	if count > 1:
		_text(box, Vector2(SLOT - 7, SLOT - 9), str(count), Color.WHITE, 6)


## "Battleworn Hammer" -> "BH", standing in for an icon.
func _initials(name: String) -> String:
	var letters := ""
	for word in name.split(" ", false):
		if word[0] == word[0].to_upper() and word[0] != "'":
			letters += word[0]
	return letters.substr(0, 2)


func _panel(at: Vector2, panel_size: Vector2) -> Control:
	var panel := ColorRect.new()
	panel.color = BACK
	panel.position = at * _ui_scale
	panel.size = panel_size * _ui_scale
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	return panel


func _text(parent: Node, at: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
	parent.add_child(label)
	return label
