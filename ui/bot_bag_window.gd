class_name BotBagWindow
extends Control
## A party bot's bags and equipment, opened from the party window (Bag): what
## it carries (its BotBag) and what it wears. Between party members nothing
## is bought or sold: right-click its items to take them, right-click your own
## bag items (or drop the one on your cursor here) to give them, click an item
## in its bag to have it put that on, drop gear from your bags on one of its
## equipment slots to put it on there, and right-click what it wears to take
## it off into its bag. Soulbound items pass between party members too, and
## stay soulbound in its bag (it never sells or trades them away).
## Sizes are in HUD units times ui_scale.

signal message(text: String, is_error: bool)

const SLOT := 15.0
const GAP := 2.0
const COLUMNS := 4
const PAD := 4.0
const FONT_SIZE := 6
const HINT := Color(0.6, 0.6, 0.6)
const GOLD := Color(1, 0.85, 0.4)
const EQUIP_LEFT := [
	Inventory.Slot.HEAD, Inventory.Slot.NECK, Inventory.Slot.SHOULDER, Inventory.Slot.BACK,
	Inventory.Slot.CHEST, Inventory.Slot.WRIST, Inventory.Slot.HANDS, Inventory.Slot.WAIST,
	Inventory.Slot.LEGS, Inventory.Slot.FEET,
]
const EQUIP_RIGHT := [
	Inventory.Slot.FINGER_1, Inventory.Slot.FINGER_2, Inventory.Slot.TRINKET_1, Inventory.Slot.TRINKET_2,
	Inventory.Slot.MAIN_HAND, Inventory.Slot.OFF_HAND, Inventory.Slot.RANGED, Inventory.Slot.SHIRT,
	Inventory.Slot.TABARD,
]

var bot: Bot
var _inventory: InventoryUI
var _tooltip: ItemTooltip
var _ui_scale := 1.0
var _shown := ""


func setup(inventory: InventoryUI, tooltip: ItemTooltip, ui_scale: float) -> void:
	_inventory = inventory
	_tooltip = tooltip
	_ui_scale = ui_scale
	visible = false
	_inventory.give_requested.connect(_give_from_bag)


func open(with_bot: Bot) -> void:
	bot = with_bot
	visible = true
	_inventory.giving = true
	_build()


func close() -> bool:
	if not visible:
		return false
	visible = false
	bot = null
	_inventory.giving = false
	_tooltip.show_item({})
	return true


func is_open() -> bool:
	return visible


func toggle(with_bot: Bot) -> void:
	if visible and bot == with_bot:
		close()
	else:
		open(with_bot)


## Redrawn when what it carries or wears changes; closes if it leaves.
func _process(_delta: float) -> void:
	if not visible:
		return
	if bot == null or not is_instance_valid(bot) or not Party.is_member(bot):
		close()
		return
	if _snapshot() != _shown:
		_build()


func _snapshot() -> String:
	return "%s|%s|%d" % [str(bot.bag.stacks), str(bot.profile.equipment), bot.bag.money]


func _build() -> void:
	_shown = _snapshot()
	for child in get_children():
		child.queue_free()
	var equip_width := SLOT * 2 + GAP
	var bag_width := COLUMNS * SLOT + (COLUMNS - 1) * GAP
	var width := PAD * 2 + equip_width + 8 + bag_width
	var rows := maxi(EQUIP_LEFT.size(), EQUIP_RIGHT.size())
	var height := 15 + rows * (SLOT + GAP) + 28
	size = Vector2(width, height) * _ui_scale
	UiStyle.panel(self, Vector2(width, height), _ui_scale)
	UiStyle.title(self, Vector2(5, 1.5), "%s's Bags" % bot.profile.char_name, _ui_scale)
	UiStyle.close_button(self, Vector2(width - 10, 2), _ui_scale, close)
	var top := 15.0
	for i in EQUIP_LEFT.size():
		_equip_slot(Vector2(PAD, top + i * (SLOT + GAP)), EQUIP_LEFT[i])
	for i in EQUIP_RIGHT.size():
		_equip_slot(Vector2(PAD + SLOT + GAP, top + i * (SLOT + GAP)), EQUIP_RIGHT[i])
	var bag_x := PAD + equip_width + 8
	_text(Vector2(bag_x, top - 1), "Bag (%d/%d)" % [bot.bag.stacks.size(), BotBag.MAX_STACKS], GOLD)
	for i in BotBag.MAX_STACKS:
		var at := Vector2(bag_x + (i % COLUMNS) * (SLOT + GAP), top + 8 + (i / COLUMNS) * (SLOT + GAP))
		_bag_slot(at, i)
	var money_y := top + 8 + ceili(BotBag.MAX_STACKS / float(COLUMNS)) * (SLOT + GAP) + 2
	_text(Vector2(bag_x, money_y), ItemDB.money_text(bot.bag.money), GOLD)
	var hints := _text(Vector2(PAD, height - 25), "Click its items to equip, right-click to take.\nRight-click your bag items to give.\nRight-click its gear to take it off.", HINT, FONT_SIZE - 1)
	hints.size.x = (width - PAD * 2) * _ui_scale


func _box(at: Vector2) -> Control:
	var box := Control.new()
	box.position = at * _ui_scale
	box.size = Vector2.ONE * SLOT * _ui_scale
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	UiStyle.frame_box(box, _ui_scale)
	return box


func _equip_slot(at: Vector2, slot: int) -> void:
	var box := _box(at)
	var worn: Dictionary = bot.profile.equipment.get(slot, {})
	if not worn.is_empty():
		UiStyle.item_icon(box, ItemDB.get_item(int(worn.id)), _ui_scale)
	box.mouse_entered.connect(func() -> void:
		if worn.is_empty():
			_tooltip.show_lines([[Inventory.SLOT_LABELS[slot], "", Color.WHITE]])
		else:
			_tooltip.show_item(ItemDB.get_item(int(worn.id)), bool(worn.get("bound", false)), -1, false))
	box.mouse_exited.connect(func() -> void: _tooltip.show_item({}))
	box.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click == null or not click.pressed:
			return
		if click.button_index == MOUSE_BUTTON_RIGHT and _inventory.held_ref().is_empty():
			_report(BotGear.unequip(bot, slot))
		elif click.button_index == MOUSE_BUTTON_LEFT and not _inventory.held_ref().is_empty():
			# Gear from your bags put straight on.
			var ref := _inventory.held_ref()
			_inventory.clear_held()
			_equip_from_bag.call_deferred(ref, slot)
		accept_event())


func _bag_slot(at: Vector2, index: int) -> void:
	var box := _box(at)
	if index >= bot.bag.stacks.size():
		box.gui_input.connect(_on_empty_input)
		return
	var stack: Dictionary = bot.bag.stacks[index]
	var item := ItemDB.get_item(int(stack.id))
	UiStyle.item_icon(box, item, _ui_scale)
	if int(stack.count) > 1:
		UiStyle.count_label(box, int(stack.count), _ui_scale)
	box.mouse_entered.connect(func() -> void:
		var lines: Array = ItemDB.tooltip(item, BotBag.is_bound(stack), -1, int(stack.count))
		if BotGear.slots_for(item, bot.profile).size() > 0:
			var why := BotGear.why_not(item, bot.profile)
			lines.append(["Click: equip on %s" % bot.profile.char_name if why.is_empty() else why, "", Color(0.4, 0.9, 0.4) if why.is_empty() else Color(1, 0.4, 0.4)])
		lines.append(["Right-click: take", "", HINT])
		_tooltip.show_lines(lines))
	box.mouse_exited.connect(func() -> void: _tooltip.show_item({}))
	box.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click == null or not click.pressed:
			return
		if not _inventory.held_ref().is_empty() and click.button_index == MOUSE_BUTTON_LEFT:
			_on_empty_input(event)
			return
		if click.button_index == MOUSE_BUTTON_RIGHT:
			_take(index)
		elif click.button_index == MOUSE_BUTTON_LEFT:
			_equip_from_own_bag(index)
		accept_event())


## Dropping the item on your cursor into its bag gives it.
func _on_empty_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and not _inventory.held_ref().is_empty():
		var ref := _inventory.held_ref()
		_inventory.clear_held()
		_give_from_bag.call_deferred(ref)
		accept_event()


## One of its bag items into your bags.
func _take(index: int) -> void:
	if index >= bot.bag.stacks.size():
		return
	var stack: Dictionary = bot.bag.stacks[index]
	var id := int(stack.id)
	var count := int(stack.count)
	var bound := BotBag.is_bound(stack)
	var left := Inventory.add_item(id, count, bound)
	if left >= count:
		_report(Inventory.ERR_FULL)
		return
	bot.bag.remove(id, count - left, bound)
	Sfx.play("loot")
	_build()


## Your bag item into its bag.
func _give_from_bag(ref: Dictionary) -> void:
	if bot == null:
		return
	var stack := Inventory.stack_at(ref)
	if stack.is_empty() or ref.get("kind") != "bag":
		return
	var bound := bool(stack.get("bound", false))
	if not bot.bag.has_room(int(stack.id), int(stack.count), bound):
		_report(BotGear.ERR_BAG_FULL % bot.profile.char_name)
		return
	Inventory.take_stack(ref)
	bot.bag.add(int(stack.id), int(stack.count), bound)
	Sfx.play("loot")
	_build()


## Gear from your bags put on it, in a slot (or where it goes).
func _equip_from_bag(ref: Dictionary, slot := -1) -> void:
	var stack := Inventory.stack_at(ref)
	if stack.is_empty() or ref.get("kind") != "bag":
		return
	var problem := BotGear.equip(bot, stack, slot)
	if problem.is_empty():
		Inventory.remove_one(ref)
		Sfx.play("loot")
	_report(problem)
	_build()


## An item from its own bag put on.
func _equip_from_own_bag(index: int) -> void:
	var id := int(bot.bag.stacks[index].id)
	var bound := BotBag.is_bound(bot.bag.stacks[index])
	# Out of the bag first, so what it takes off has its place.
	bot.bag.remove(id, 1, bound)
	var problem := BotGear.equip(bot, { "id": id, "count": 1, "bound": bound })
	if problem.is_empty():
		Sfx.play("loot")
		GameState.inventory_changed.emit()
	else:
		bot.bag.add(id, 1, bound)
	_report(problem)
	_build()


func _report(problem: String) -> void:
	if not problem.is_empty():
		message.emit(problem, true)


func _text(at: Vector2, text: String, color: Color, font_size := FONT_SIZE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at * _ui_scale
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
