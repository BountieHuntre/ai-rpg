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


func show_item(item: Dictionary) -> void:
	visible = not item.is_empty()
	if not visible:
		return
	for child in _rows.get_children():
		child.free()
	for line: Array in ItemDB.tooltip(item):
		var row := HBoxContainer.new()
		var left := _label(line[0], line[2])
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	if not visible:
		return
	var window := get_viewport().get_visible_rect().size
	var at := get_viewport().get_mouse_position() + OFFSET * _ui_scale
	position = Vector2(clampf(at.x, 0.0, window.x - size.x), clampf(at.y, 0.0, window.y - size.y))
