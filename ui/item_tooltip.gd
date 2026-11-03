class_name ItemTooltip
extends PanelContainer
## Classic item tooltip that follows the mouse. Each row has a left column and
## an optional right-aligned column, as in WoW ("Two-Hand ... Mace"). Gear
## also shows what is equipped in its slots beside it, headed "Currently
## Equipped", like the classic shopping tooltips.

const WIDTH := 120.0
const FONT_SIZE := 7
const OFFSET := Vector2(10, 10)
const COMPARE_HEADER := Color(0.5, 0.5, 0.5)

var _rows := VBoxContainer.new()
var _ui_scale := 1.0
## Up to two panels for the equipped items, placed beside the main one.
var _compare: Array[PanelContainer] = []


func setup(ui_scale: float) -> void:
	_ui_scale = ui_scale
	_style(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_rows(_rows)
	add_child(_rows)
	for i in 2:
		var panel := PanelContainer.new()
		_style(panel)
		# Placed by hand beside the main panel, not laid out inside it.
		panel.top_level = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rows := VBoxContainer.new()
		_setup_rows(rows)
		panel.add_child(rows)
		panel.visible = false
		add_child(panel)
		_compare.append(panel)
	visible = false


func _style(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.12, 0.95)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_border_width_all(maxi(roundi(_ui_scale), 1))
	style.set_content_margin_all(4 * _ui_scale)
	panel.add_theme_stylebox_override("panel", style)


func _setup_rows(rows: VBoxContainer) -> void:
	rows.custom_minimum_size.x = WIDTH * _ui_scale
	rows.add_theme_constant_override("separation", 0)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows an item. With `compare`, gear also shows the items equipped in the
## slots it would go in; equipment slots themselves pass false.
func show_item(item: Dictionary, soulbound := false, current_durability := -1, compare := true) -> void:
	show_lines([] if item.is_empty() else ItemDB.tooltip(item, soulbound, current_durability))
	if visible and compare:
		_show_compare(item)


## Shows rows of [left text, right text, color], or hides for an empty list.
func show_lines(lines: Array) -> void:
	for panel in _compare:
		panel.visible = false
	# While the camera drags, the captured mouse reads as the screen centre,
	# which can sit over a window's rows. No tooltips until the drag ends.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		lines = []
	visible = not lines.is_empty()
	if not visible:
		return
	_fill(_rows, lines)
	reset_size()


func _show_compare(item: Dictionary) -> void:
	var stacks := equipped_for(item)
	for i in mini(stacks.size(), _compare.size()):
		var stack: Dictionary = stacks[i]
		var lines: Array = [["Currently Equipped", "", COMPARE_HEADER]]
		lines.append_array(ItemDB.tooltip(ItemDB.get_item(stack.id), stack.get("bound", false), int(stack.get("durability", -1))))
		_fill(_compare[i].get_child(0), lines)
		_compare[i].visible = true
		_compare[i].reset_size()
	_place()


## The equipped stacks an item would replace: both rings or trinkets, the
## off hand as well for a two-hander, and a two-hander for an off-hand item.
static func equipped_for(item: Dictionary) -> Array[Dictionary]:
	var type := int(item.get("InventoryType", 0))
	var slots: Array = Inventory.SLOTS_FOR_TYPE.get(type, []).duplicate()
	if type == Inventory.INVTYPE_TWO_HAND:
		slots.append(Inventory.Slot.OFF_HAND)
	elif Inventory.Slot.OFF_HAND in slots and Inventory.is_two_hander(GameState.equipment.get(Inventory.Slot.MAIN_HAND, {})):
		slots.push_front(Inventory.Slot.MAIN_HAND)
	var stacks: Array[Dictionary] = []
	for slot: int in slots:
		var stack: Dictionary = GameState.equipment.get(slot, {})
		if not stack.is_empty():
			stacks.append(stack)
	return stacks


func _fill(rows: VBoxContainer, lines: Array) -> void:
	for child in rows.get_children():
		child.free()
	for line: Array in lines:
		var row := HBoxContainer.new()
		var left := _label(line[0], line[2])
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if str(line[1]).is_empty():
			# Long single-column lines, like spell descriptions, wrap.
			left.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			left.custom_minimum_size.x = WIDTH * _ui_scale
		row.add_child(left)
		if not str(line[1]).is_empty():
			var right := _label(line[1], line[3] if line.size() > 3 else line[2])
			right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(right)
		rows.add_child(row)


func _label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	return label


func _process(_delta: float) -> void:
	if visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		visible = false
	if not visible:
		return
	_place()


## Follows the mouse, with the equipped items to the right, or to the left
## when there is no room.
func _place() -> void:
	var window := get_viewport().get_visible_rect().size
	var at := get_viewport().get_mouse_position() + OFFSET * _ui_scale
	var shown := _compare.filter(func(panel: PanelContainer) -> bool: return panel.visible)
	var extra := 0.0
	for panel: PanelContainer in shown:
		extra += panel.size.x
	var x := clampf(at.x, 0.0, window.x - size.x)
	var compare_x := x + size.x
	if compare_x + extra > window.x:
		compare_x = x - extra
		if compare_x < 0.0:
			# Not enough room on either side: shift the main panel over.
			x = clampf(window.x - size.x - extra, 0.0, window.x)
			compare_x = x + size.x
	position = Vector2(x, clampf(at.y, 0.0, window.y - size.y))
	for panel: PanelContainer in shown:
		panel.global_position = Vector2(compare_x, clampf(position.y, 0.0, window.y - panel.size.y))
		compare_x += panel.size.x
