class_name GameMenu
extends Control
## The Esc menu: Options, log out to character select, exit the game, or go
## back. With `in_game` off it is just the Options window, for the login
## screens.

signal log_out_requested
signal exit_requested

const WIDTH := 90.0
const FONT_SIZE := 8

## Set before adding to the tree.
var in_game := true

var _panel := PanelContainer.new()
var _options := OptionsWindow.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	add_child(_panel)
	_options.visible = false
	add_child(_options)
	_options.closed.connect(func() -> void:
		# Back to the menu in game; on the login screens, closed altogether.
		_panel.visible = in_game
		visible = in_game
	)
	get_viewport().size_changed.connect(_build)
	Settings.changed.connect(func(key: String) -> void:
		if key == "ui_scale":
			_build()
	)
	_build()


## Esc: cancels an open Options window, else opens or closes the menu. On the
## login screens, opens or cancels the Options window.
func toggle() -> void:
	if _options.visible:
		_options.cancel()
		return
	if not in_game:
		open_options()
		return
	visible = not visible


func open_options() -> void:
	visible = true
	_panel.visible = false
	_options.open()


func _build() -> void:
	var ui_scale := Settings.hud_scale(get_viewport_rect().size.y)
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
	var entries := [
		["Options", open_options], ["Log Out", log_out_requested.emit],
		["Exit Game", exit_requested.emit], ["Return to Game", toggle],
	]
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(WIDTH, 13) * ui_scale
		button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * ui_scale))
		button.pressed.connect(entry[1])
		box.add_child(button)
	_panel.reset_size()
	var center := func() -> void: _panel.position = (get_viewport_rect().size - _panel.size) / 2
	center.call_deferred()
