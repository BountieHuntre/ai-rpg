class_name UiStyle
extends RefCounted
## The look every window, frame and button shares: Gothic gilt. Near-black
## panels edged with a thin gold line and a darker gold line just inside it,
## corners rounded a little, a title band in Cinzel, gold-edged buttons and
## tabs, and dark slots with the same double line. Windows build their parts
## from here (panel, title, close_button, slot_frame), and theme() styles
## Godot's own controls (buttons, text fields, lists, scroll bars, menus)
## everywhere: Settings puts it on the root window.

const BACK := Color(0.09, 0.082, 0.1, 1.0)
const BAND := Color(0.13, 0.115, 0.135, 1.0)
const GOLD := Color("a8843a")
const GOLD_DARK := Color("6a5326")
const GOLD_BRIGHT := Color("e6c876")
const TITLE := Color("e6c876")
const TEXT := Color("cfc6b4")
const DIM := Color("7d7462")
const SLOT := Color(0.043, 0.039, 0.047, 1.0)
const BUTTON := Color("2a2116")
const BUTTON_HOVER := Color("3a2d1a")
const BUTTON_PRESSED := Color("17110a")
const SELECTED := Color(0.9, 0.75, 0.4, 0.14)
## Height of a window's title band, in HUD units.
const TITLE_BAND := 12.0
## Corner rounding, in pixels at UI scale 1.
const ROUNDING := 3.0

const TITLE_FONT_PATH := "res://assets/fonts/cinzel/Cinzel-VariableFont_wght.ttf"
static var _title_font: Font
static var _theme: Theme


## Cinzel, a little bold, for titles and headings.
static func title_font() -> Font:
	if _title_font == null:
		var file := load(TITLE_FONT_PATH) as FontFile
		var variation := FontVariation.new()
		variation.base_font = file
		variation.variation_opentype = { "wght": 600 }
		_title_font = variation
	return _title_font


## A window's background: a GiltPanel `size_units` big (HUD units), with a
## title band when `band` is true. It catches the mouse, as the old
## backgrounds did. Added as the parent's first child.
static func panel(parent: Node, size_units: Vector2, ui_scale: float, band := true) -> GiltPanel:
	var back := GiltPanel.new()
	back.ui_scale = ui_scale
	back.band = band
	back.size = size_units * ui_scale
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(back)
	parent.move_child(back, 0)
	return back


## A window title in the band: Cinzel in gold, with a shadow.
static func title(parent: Control, at_units: Vector2, text: String, ui_scale: float, font_size := 7) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at_units * ui_scale + Vector2(0, -0.5 * ui_scale)
	label.add_theme_font_override("font", title_font())
	label.add_theme_font_size_override("font_size", roundi(font_size * ui_scale))
	label.add_theme_color_override("font_color", TITLE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(ui_scale * 0.6), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(ui_scale * 0.6), 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## The close button at a window's top right: a small gilt square with a
## cross, brighter under the mouse. `pressed` runs on a left click.
static func close_button(parent: Control, at_units: Vector2, ui_scale: float, pressed: Callable) -> Control:
	var button := CloseCross.new()
	button.ui_scale = ui_scale
	button.position = at_units * ui_scale
	button.size = Vector2.ONE * 8.0 * ui_scale
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			pressed.call_deferred()
	)
	parent.add_child(button)
	return button


## The frame an icon sits in (action bar, bags, loot, rewards): a dark slot
## with the double gold line, drawn by the returned control under its
## children. `size_units` in HUD units.
static func slot_frame(parent: Control, at_units: Vector2, size_units: float, ui_scale: float) -> SlotFrame:
	var frame := SlotFrame.new()
	frame.ui_scale = ui_scale
	frame.position = at_units * ui_scale
	frame.size = Vector2.ONE * size_units * ui_scale
	parent.add_child(frame)
	return frame


## A tab: a small gilt-edged panel, brighter when it's the one showing,
## with its label. `pressed` runs on a left click. Sizes in HUD units.
static func tab(parent: Control, at_units: Vector2, size_units: Vector2, text: String, selected: bool, ui_scale: float, pressed: Callable, font_size := 6) -> Panel:
	var line := maxi(roundi(ui_scale * 0.5), 1)
	var rounding := roundi(ROUNDING * ui_scale / 2.0)
	var panel := Panel.new()
	panel.position = at_units * ui_scale
	panel.size = size_units * ui_scale
	panel.add_theme_stylebox_override("panel", _box(BUTTON_HOVER if selected else BUTTON, GOLD if selected else GOLD_DARK, line, rounding))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := Label.new()
	label.text = text
	label.position = Vector2(3, 0.5) * ui_scale
	label.add_theme_font_size_override("font_size", roundi(font_size * ui_scale))
	label.add_theme_color_override("font_color", GOLD_BRIGHT if selected else DIM)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			pressed.call_deferred()
	)
	parent.add_child(panel)
	return panel


## An icon filling a slot (or any box), `inset` pixels in from its edges,
## smoothly scaled. It ignores the mouse, so the slot under it gets clicks.
static func icon(parent: Control, texture: Texture2D, inset := 2.0) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	view.position = Vector2.ONE * inset
	view.size = parent.size - Vector2.ONE * inset * 2.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	return view


## An item's icon in a box: the slot frame, its painted icon (Icons; a coin
## for {}, which is money), and an edge in its quality color for uncommon and
## better. Clears the box's own color if it's a ColorRect.
static func item_icon(box: Control, item: Dictionary, ui_scale: float) -> void:
	if box is ColorRect:
		(box as ColorRect).color = Color.TRANSPARENT
	frame_box(box, ui_scale)
	var inset := maxf(roundf(ui_scale * 1.2), 2.0)
	icon(box, Icons.texture("coin" if item.is_empty() else Icons.item_key(item)), inset)
	if int(item.get("Quality", 1)) >= 2:
		var border := ReferenceRect.new()
		border.border_color = ItemDB.quality_color(item)
		border.border_width = maxf(ui_scale * 0.6, 1.0)
		border.editor_only = false
		border.position = Vector2.ONE * inset
		border.size = box.size - border.position * 2.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(border)


## A spell's icon in a box, in its slot frame.
static func spell_icon(box: Control, spell_id: int, ui_scale: float) -> void:
	if box is ColorRect:
		(box as ColorRect).color = Color.TRANSPARENT
	frame_box(box, ui_scale)
	icon(box, Icons.texture(Icons.spell_key(SpellDB.get_spell(spell_id))), maxf(roundf(ui_scale * 1.2), 2.0))


## A slot frame filling a box that handles its own input (bag slots, action
## buttons): drawn under the box's other children, ignoring the mouse.
static func frame_box(box: Control, ui_scale: float) -> SlotFrame:
	var frame := SlotFrame.new()
	frame.ui_scale = ui_scale
	frame.size = box.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)
	box.move_child(frame, 0)
	return frame


## A stack's count in a slot's bottom right corner, white with a shadow.
static func count_label(parent: Control, count: int, ui_scale: float, font_size := 6) -> Label:
	var label := Label.new()
	label.text = str(count)
	label.add_theme_font_size_override("font_size", roundi(font_size * ui_scale))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(roundi(ui_scale * 1.2), 2))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size = parent.size - Vector2(ui_scale * 1.5, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


static func _box(bg: Color, border: Color, width: int, rounding: int, margin := 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(rounding)
	box.set_content_margin_all(margin)
	box.anti_aliasing = false
	return box


## Godot's controls in the gilt style, for the root window's theme. Sizes are
## at UI scale 1; the HUD's controls set their own font sizes as before.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var rounding := roundi(ROUNDING)
	for kind in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", kind, _box(BUTTON, GOLD, 1, rounding, 4))
		t.set_stylebox("hover", kind, _box(BUTTON_HOVER, GOLD_BRIGHT, 1, rounding, 4))
		t.set_stylebox("pressed", kind, _box(BUTTON_PRESSED, GOLD, 1, rounding, 4))
		t.set_stylebox("disabled", kind, _box(Color(0.12, 0.11, 0.11), Color(0.3, 0.28, 0.24), 1, rounding, 4))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, GOLD_BRIGHT)
		t.set_color("font_hover_color", kind, Color("fff0c0"))
		t.set_color("font_pressed_color", kind, GOLD)
		t.set_color("font_disabled_color", kind, DIM)
	for kind in ["LineEdit", "TextEdit", "SpinBox"]:
		t.set_stylebox("normal", kind, _box(SLOT, GOLD_DARK, 1, rounding, 3))
		t.set_stylebox("focus", kind, _box(SLOT, GOLD, 1, rounding, 3))
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_placeholder_color", kind, DIM)
		t.set_color("caret_color", kind, GOLD_BRIGHT)
		t.set_color("selection_color", kind, Color(0.65, 0.5, 0.2, 0.5))
	t.set_stylebox("panel", "PopupMenu", _box(BACK, GOLD, 1, rounding, 4))
	t.set_stylebox("hover", "PopupMenu", _box(BUTTON_HOVER, GOLD_DARK, 1, rounding))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD_BRIGHT)
	t.set_color("font_separator_color", "PopupMenu", DIM)
	t.set_stylebox("panel", "PanelContainer", _box(BACK, GOLD, 1, rounding, 4))
	t.set_stylebox("panel", "Panel", _box(BACK, GOLD, 1, rounding))
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _box(Color(0.05, 0.045, 0.055, 0.9), Color(0, 0, 0, 0), 0, rounding))
		t.set_stylebox("grabber", bar, _box(GOLD_DARK, GOLD_DARK, 0, rounding))
		t.set_stylebox("grabber_highlight", bar, _box(GOLD, GOLD, 0, rounding))
		t.set_stylebox("grabber_pressed", bar, _box(GOLD_BRIGHT, GOLD_BRIGHT, 0, rounding))
	t.set_stylebox("slider", "HSlider", _box(SLOT, GOLD_DARK, 1, rounding, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD_DARK, GOLD_DARK, 0, rounding, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, GOLD, 0, rounding, 2))
	for kind in ["CheckBox", "CheckButton"]:
		t.set_color("font_color", kind, TEXT)
		t.set_color("font_hover_color", kind, GOLD_BRIGHT)
		t.set_stylebox("normal", kind, StyleBoxEmpty.new())
		t.set_stylebox("hover", kind, StyleBoxEmpty.new())
		t.set_stylebox("pressed", kind, StyleBoxEmpty.new())
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
	t.set_stylebox("tab_selected", "TabBar", _box(BUTTON_HOVER, GOLD, 1, rounding, 4))
	t.set_stylebox("tab_unselected", "TabBar", _box(BUTTON, GOLD_DARK, 1, rounding, 4))
	t.set_stylebox("tab_hovered", "TabBar", _box(BUTTON_HOVER, GOLD_DARK, 1, rounding, 4))
	t.set_color("font_selected_color", "TabBar", GOLD_BRIGHT)
	t.set_color("font_unselected_color", "TabBar", DIM)
	t.set_color("font_color", "Label", TEXT)
	_theme = t
	return t


## A window background: the near-black panel, its thin gold edge, a darker
## gold line just inside, and the title band along the top.
class GiltPanel extends Control:
	var ui_scale := 1.0
	var band := true

	func _draw() -> void:
		var s := maxf(ui_scale, 1.0)
		var line := maxf(roundf(ui_scale * 0.5), 1.0)
		var rounding := roundi(ROUNDING * ui_scale / 2.0)
		draw_style_box(UiStyle._box(BACK, GOLD, int(line), rounding), Rect2(Vector2.ZERO, size))
		if band:
			var band_rect := Rect2(Vector2(line, line), Vector2(size.x - line * 2, TITLE_BAND * ui_scale - line))
			draw_rect(band_rect, BAND)
			draw_rect(Rect2(Vector2(line, TITLE_BAND * ui_scale - line), Vector2(size.x - line * 2, line)), GOLD)
		var inset := line * 2.0 + floorf(s * 0.5)
		draw_rect(Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0), GOLD_DARK, false, line)


## A window's close button: a cross in a small gilt square.
class CloseCross extends Control:
	var ui_scale := 1.0
	var _hover := false

	func _ready() -> void:
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _draw() -> void:
		var line := maxf(roundf(ui_scale * 0.5), 1.0)
		draw_style_box(UiStyle._box(BUTTON_HOVER if _hover else BUTTON, GOLD_BRIGHT if _hover else GOLD, int(line), roundi(ROUNDING * ui_scale / 3.0)), Rect2(Vector2.ZERO, size))
		var pad := size.x * 0.3
		var color := Color("fff0c0") if _hover else GOLD_BRIGHT
		var width := maxf(ui_scale * 0.8, 1.0)
		draw_line(Vector2(pad, pad), size - Vector2(pad, pad), color, width, true)
		draw_line(Vector2(size.x - pad, pad), Vector2(pad, size.y - pad), color, width, true)


## An icon slot's frame: dark inside, the gold edge and darker inner line.
class SlotFrame extends Control:
	var ui_scale := 1.0

	func _draw() -> void:
		var line := maxf(roundf(ui_scale * 0.5), 1.0)
		draw_style_box(UiStyle._box(SLOT, GOLD, int(line), roundi(ROUNDING * ui_scale / 3.0)), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2.ONE * line * 2.0, size - Vector2.ONE * line * 4.0), GOLD_DARK, false, line)
