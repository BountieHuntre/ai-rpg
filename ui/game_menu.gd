class_name GameMenu
extends Control
## The Esc menu: log out to character select, exit the game, or go back.

signal log_out_requested
signal exit_requested

const WIDTH := 90.0
const FONT_SIZE := 8

var _panel := PanelContainer.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_child(_panel)
	get_viewport().size_changed.connect(_build)
	_build()


func toggle() -> void:
	visible = not visible


func _build() -> void:
	var ui_scale := get_viewport_rect().size.y / 270.0
	for child in _panel.get_children():
		child.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.12, 0.95)
	style.border_color = Color(0.55, 0.55, 0.6)
	style.set_border_width_all(maxi(roundi(ui_scale / 2), 1))
	style.set_content_margin_all(5 * ui_scale)
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(3 * ui_scale))
	_panel.add_child(box)
	var title := Label.new()
	title.text = "Game Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("ffd100"))
	title.add_theme_font_size_override("font_size", roundi(FONT_SIZE * ui_scale))
	box.add_child(title)
	for entry: Array in [["Log Out", log_out_requested.emit], ["Exit Game", exit_requested.emit], ["Return to Game", toggle]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(WIDTH, 13) * ui_scale
		button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * ui_scale))
		button.pressed.connect(entry[1])
		box.add_child(button)
	_panel.reset_size()
	var center := func() -> void: _panel.position = (get_viewport_rect().size - _panel.size) / 2
	center.call_deferred()
