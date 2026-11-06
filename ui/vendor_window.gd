class_name VendorWindow
extends Control
## Classic vendor window: the vendor's stock with prices, and a Buyback tab
## with the last items sold. Click an item to buy one lot (shown as the stack
## count on its icon). While it's open, right-clicking an item in the bags
## sells it. Closes when the player walks away.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
signal hovered(item: Dictionary)

const VENDORS_PATH := "res://data/classic/vendors.json"
## Classic INTERACTION_DISTANCE, in yards.
const RANGE := 5.0
const WIDTH := 150.0
const ROW := 16.0
const ICON := 13.0
const FONT_SIZE := 6
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const PRICE := Color(1, 0.85, 0.4)
const TOO_EXPENSIVE := Color(1, 0.3, 0.3)

static var _vendors: Dictionary

var npc: Node3D

var _player: Player
var _ui_scale := 1.0
var _showing_buyback := false
var _rebuild_queued := false


static func vendor_data(entry: int) -> Dictionary:
	if _vendors.is_empty():
		_vendors = JSON.parse_string(FileAccess.get_file_as_string(VENDORS_PATH))
	return _vendors.get(str(entry), {})


func open(vendor_npc: Node3D, player: Player, ui_scale: float) -> void:
	npc = vendor_npc
	_player = player
	_ui_scale = ui_scale
	_showing_buyback = false
	visible = true
	if not GameState.money_changed.is_connected(_queue_rebuild):
		GameState.money_changed.connect(_queue_rebuild)
		GameState.inventory_changed.connect(_queue_rebuild)
	_build()


func close() -> void:
	npc = null
	visible = false
	hovered.emit({})


func _process(_delta: float) -> void:
	if npc == null:
		return
	if not is_instance_valid(npc) or _player.global_position.distance_to(npc.global_position) > RANGE:
		close()


func _queue_rebuild() -> void:
	if visible and not _rebuild_queued:
		_rebuild_queued = true
		_build.call_deferred()


## Rows are only freed through queue_free, never while handling their own click.
func _build() -> void:
	_rebuild_queued = false
	if npc == null:
		return
	for child in get_children():
		child.queue_free()
	var vendor := vendor_data(npc.vendor)
	var rows: Array = GameState.buyback if _showing_buyback else vendor.get("items", [])
	# Room under the list for the money line and the Sell Junk button.
	size = Vector2(WIDTH, 26 + maxi(rows.size(), 1) * ROW + 28) * _ui_scale
	UiStyle.panel(self, size / _ui_scale, _ui_scale)
	UiStyle.title(self, Vector2(5, 1.5), "%s - %s" % [npc.npc_name, npc.subname], _ui_scale)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, close)
	_tab(Vector2(4, 12), "Merchant", not _showing_buyback, false)
	_tab(Vector2(50, 12), "Buyback", _showing_buyback, true)

	if rows.is_empty():
		_text(self, Vector2(6, 26), "Nothing to buy back." if _showing_buyback else "", Color(0.6, 0.6, 0.6), FONT_SIZE)
	for i in rows.size():
		var y := 26.0 + i * ROW
		if _showing_buyback:
			var entry: Dictionary = rows[i]
			_add_row(y, int(entry.id), int(entry.count), int(entry.price), i)
		else:
			var item := ItemDB.get_item(int(rows[i]))
			_add_row(y, int(rows[i]), maxi(int(item.BuyCount), 1), int(item.BuyPrice), i)
	var bottom := 26 + maxi(rows.size(), 1) * ROW
	_text(self, Vector2(4, bottom), "Money: %s" % ItemDB.money_text(GameState.money), PRICE, FONT_SIZE)
	if vendor.get("repair", false):
		_add_repair_button(bottom)
	_add_sell_junk_button(bottom + 14)


## Sells every poor (grey) item in the bags at once. Each stack goes to
## buyback as if sold by hand.
func _add_sell_junk_button(at_y: float) -> void:
	var junk := Inventory.junk_refs()
	var value := 0
	for ref: Dictionary in junk:
		var stack := Inventory.stack_at(ref)
		value += int(ItemDB.get_item(stack.id).SellPrice) * int(stack.count)
	var button := Button.new()
	button.text = "Sell Junk (%s)" % ItemDB.money_text(value) if value > 0 else "Sell Junk"
	button.disabled = junk.is_empty()
	button.tooltip_text = "" if junk.is_empty() else "Sell all %d grey items in your bags" % junk.size()
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	button.position = Vector2(4, at_y - 2) * _ui_scale
	button.size = Vector2(WIDTH - 8, 12) * _ui_scale
	button.pressed.connect(func() -> void:
		var sold := 0
		for ref: Dictionary in Inventory.junk_refs():
			if Inventory.sell(ref).is_empty():
				sold += 1
		if sold > 0:
			Sfx.play("sell")
			message.emit("Sold %d junk item%s for %s." % [sold, "" if sold == 1 else "s", ItemDB.money_text(value)], false)
		_queue_rebuild()
	)
	add_child(button)


## Armorers repair everything at once, for the classic cost.
func _add_repair_button(bottom: float) -> void:
	var cost := Inventory.repair_all_cost()
	var button := Button.new()
	button.text = "Repair All (%s)" % ItemDB.money_text(cost) if cost > 0 else "Repair All"
	button.disabled = cost <= 0
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	button.position = Vector2(WIDTH - 66, bottom - 2) * _ui_scale
	button.size = Vector2(62, 12) * _ui_scale
	button.pressed.connect(func() -> void:
		var error := Inventory.repair_all()
		if error.is_empty():
			Sfx.play("coins")
		else:
			message.emit(error, true)
		_queue_rebuild()
	)
	add_child(button)


func _tab(at: Vector2, label: String, active: bool, buyback: bool) -> void:
	UiStyle.tab(self, at, Vector2(label.length() * 3.4 + 7, 9), label, active, _ui_scale, func() -> void:
		if _showing_buyback != buyback:
			_showing_buyback = buyback
			_queue_rebuild()
	, FONT_SIZE)


func _add_row(y: float, id: int, count: int, price: int, index: int) -> void:
	var item := ItemDB.get_item(id)
	var quality := ItemDB.quality_color(item)
	var row := ColorRect.new()
	row.color = Color.TRANSPARENT
	row.position = Vector2(2, y) * _ui_scale
	row.size = Vector2(WIDTH - 4, ROW - 1) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(row)
	var icon := ColorRect.new()
	icon.color = quality.darkened(0.6)
	icon.position = Vector2(1, 1) * _ui_scale
	icon.size = Vector2.ONE * ICON * _ui_scale
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	UiStyle.item_icon(icon, item, _ui_scale)
	if count > 1:
		var count_label := _text(icon, Vector2(0, ICON - 9), str(count), Color.WHITE, 5)
		count_label.size.x = (ICON - 1) * _ui_scale
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text(row, Vector2(ICON + 4, 0), item.name, quality, FONT_SIZE)
	_text(row, Vector2(ICON + 4, 7), ItemDB.money_text(price), PRICE if GameState.money >= price else TOO_EXPENSIVE, 5)
	row.mouse_entered.connect(func() -> void:
		row.color = Color(1, 1, 1, 0.08)
		hovered.emit(item)
	)
	row.mouse_exited.connect(func() -> void:
		row.color = Color.TRANSPARENT
		hovered.emit({})
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button == null or not button.pressed or not button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		var error := Inventory.buy_back(index) if _showing_buyback else Inventory.buy(id)
		if error.is_empty():
			Sfx.play("coins")
		else:
			message.emit(error, true)
		_queue_rebuild()
	)


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
