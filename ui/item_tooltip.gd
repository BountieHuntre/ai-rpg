class_name ItemTooltip
extends PanelContainer
## Classic item tooltip that follows the mouse. Each row has a left column and
## an optional right-aligned column, as in WoW ("Two-Hand ... Mace").

const WIDTH := 120.0
const FONT_SIZE := 7
const OFFSET := Vector2(10, 10)

var _rows := VBoxContainer.new()
var _ui_scale := 1.0


func setup(ui_scale: float) -> void:
	_ui_scale = ui_scale
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.12, 0.95)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_border_width_all(maxi(roundi(ui_scale), 1))
	style.set_content_margin_all(4 * ui_scale)
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.custom_minimum_size.x = WIDTH * ui_scale
	_rows.add_theme_constant_override("separation", 0)
	add_child(_rows)
	visible = false


func show_item(item: Dictionary, soulbound := false) -> void:
	show_lines([] if item.is_empty() else ItemDB.tooltip(item, soulbound))


## Shows rows of [left text, right text, color], or hides for an empty list.
func show_lines(lines: Array) -> void:
	# While the camera drags, the captured mouse reads as the screen centre,
	# which can sit over a window's rows. No tooltips until the drag ends.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		lines = []
	visible = not lines.is_empty()
	if not visible:
		return
	for child in _rows.get_children():
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
			var right := _label(line[1], line[2])
			right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(right)
		_rows.add_child(row)
	reset_size()


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
	var window := get_viewport().get_visible_rect().size
	var at := get_viewport().get_mouse_position() + OFFSET * _ui_scale
	position = Vector2(clampf(at.x, 0.0, window.x - size.x), clampf(at.y, 0.0, window.y - size.y))
