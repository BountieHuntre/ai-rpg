class_name MicroMenu
extends Control
## The menu buttons right of the action bar, like classic's micro menu:
## Character Info, Spellbook & Abilities, Talents, Quest Log, Socials, World
## Map and Main Menu. Each is half an action button wide and nearly as tall,
## with a little picture drawn in code, sits pushed in while its window is
## open, and names itself and its key on hover. Clicking one does what its key
## does (it sends the key binding's action), so the windows need nothing new;
## Main Menu asks the HUD to open the game menu. When the row doesn't fit
## right of the bar, the buttons wrap onto a second row above. Sizes are in
## HUD units, times ui_scale.

signal main_menu_requested

const WIDTH := SpellUI.SLOT / 2.0
const HEIGHT := SpellUI.SLOT - 2.0
const GAP := 1.0
## Room between the action bar and the first button.
const BAR_GAP := 4.0
## [tooltip name, key binding action (empty for Main Menu), picture].
const BUTTONS := [
	["Character Info", "character_window", "character"],
	["Spellbook & Abilities", "spellbook", "book"],
	["Talents", "talents", "talents"],
	["Quest Log", "quest_log", "quest"],
	["Socials", "social", "social"],
	["World Map", "world_map", "map"],
	["Main Menu", "", "menu"],
]
const FACE := Color(0.32, 0.12, 0.1)
const FACE_DARK := Color(0.16, 0.06, 0.05)
const EDGE := Color(0.62, 0.5, 0.3)
const EDGE_LIT := Color(1, 0.85, 0.4)
const OUTLINE := Color(0.05, 0.04, 0.03)

var _ui_scale := 1.0
var _tooltip: ItemTooltip
## Whether each button's window is open, by action: Callable() -> bool.
var _open_checks: Dictionary = {}
var _buttons: Array[Control] = []
var _hovered := -1


## `screen` is the HUD's size in HUD units; `open_checks` maps a button's
## action ("main_menu" for Main Menu) to a Callable saying whether its window
## is open.
func setup(ui_scale: float, screen: Vector2, tooltip: ItemTooltip, open_checks: Dictionary) -> void:
	_ui_scale = ui_scale
	_tooltip = tooltip
	_open_checks = open_checks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_right := (screen.x + GameState.ACTION_SLOTS * (SpellUI.SLOT + SpellUI.GAP) - SpellUI.GAP) / 2.0
	var left := bar_right + BAR_GAP
	var room := screen.x - Minimap.MARGIN - left
	var per_row := clampi(floori((room + GAP) / (WIDTH + GAP)), 1, BUTTONS.size())
	var bottom := SpellUI.bottom_row_y(screen.y, 0) + SpellUI.SLOT
	for i in BUTTONS.size():
		var row := i / per_row
		var column := i % per_row
		var button := Control.new()
		button.position = Vector2(left + column * (WIDTH + GAP), bottom - HEIGHT - row * (HEIGHT + GAP)) * ui_scale
		button.size = Vector2(WIDTH, HEIGHT) * ui_scale
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.draw.connect(_draw_button.bind(button, i))
		button.mouse_entered.connect(_on_hover.bind(i))
		button.mouse_exited.connect(_on_hover.bind(-1))
		button.gui_input.connect(_on_input.bind(i))
		add_child(button)
		_buttons.append(button)


func _process(_delta: float) -> void:
	# Pushed in while its window is open: redrawn as windows open and close.
	for button in _buttons:
		button.queue_redraw()
	# Covered by a window it opened (the world map), the button is no longer
	# under the mouse, though the mouse hasn't moved: its tooltip goes.
	if _hovered >= 0 and get_viewport().gui_get_hovered_control() != _buttons[_hovered]:
		_on_hover(-1)


func _is_open(index: int) -> bool:
	var action: String = BUTTONS[index][1]
	var check: Callable = _open_checks.get(action if action != "" else "main_menu", Callable())
	return check.is_valid() and bool(check.call())


func _on_hover(index: int) -> void:
	_hovered = index
	if _tooltip == null:
		return
	if index < 0:
		_tooltip.show_lines([])
		return
	var action: String = BUTTONS[index][1]
	var key := "Escape" if action == "" else Settings.key_name(int(Settings.keys_for(action)[0]))
	var title: String = BUTTONS[index][0]
	_tooltip.show_lines([[title + (" (%s)" % key if key != "" else ""), "", Color.WHITE]])


func _on_input(event: InputEvent, index: int) -> void:
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	accept_event()
	var action: String = BUTTONS[index][1]
	if action == "":
		main_menu_requested.emit()
		return
	# Does what the key does.
	for pressed in [true, false]:
		var press := InputEventAction.new()
		press.action = action
		press.pressed = pressed
		Input.parse_input_event(press)


func _draw_button(button: Control, index: int) -> void:
	var s := _ui_scale
	var pushed := _is_open(index)
	var lit := _hovered == index
	var area := Rect2(Vector2.ZERO, button.size)
	# A dark outline, a gold-brown edge, and a face shaded dark at the bottom
	# (lighter at the top), as classic's red-brown buttons.
	button.draw_rect(area, OUTLINE)
	button.draw_rect(area.grow(-maxf(s * 0.5, 1.0)), EDGE_LIT if lit else EDGE)
	var face := area.grow(-maxf(s * 1.2, 1.0))
	var bands := 6
	for band in bands:
		var t := float(band) / (bands - 1)
		var color := FACE.lerp(FACE_DARK, t if not pushed else 1.0 - t)
		button.draw_rect(Rect2(face.position + Vector2(0, face.size.y * band / bands), Vector2(face.size.x, ceilf(face.size.y / bands))), color)
	# The picture, nudged down and right while pushed in.
	var center := face.get_center() + (Vector2(0.5, 0.7) * s if pushed else Vector2.ZERO)
	match str(BUTTONS[index][2]):
		"character":
			_draw_bust(button, center + Vector2(0, 1) * s, Color(0.85, 0.68, 0.5), Color(0.45, 0.32, 0.6))
		"book":
			var cover := Rect2(center - Vector2(3, 4.5) * s, Vector2(6, 9) * s)
			button.draw_rect(cover, Color(0.6, 0.12, 0.1))
			button.draw_rect(Rect2(cover.position, Vector2(1.2, 9) * s), Color(0.95, 0.75, 0.3))
			button.draw_rect(Rect2(cover.position + Vector2(2.4, 2) * s, Vector2(2.6, 0.8) * s), Color(0.95, 0.75, 0.3))
			button.draw_rect(cover, OUTLINE, false, maxf(s * 0.5, 1.0))
		"talents":
			# A little tree of three points, as talent trees branch.
			var top := center + Vector2(0, -3.5) * s
			var low_left := center + Vector2(-2.5, 3) * s
			var low_right := center + Vector2(2.5, 3) * s
			var width := maxf(s * 0.8, 1.0)
			button.draw_line(top, center, EDGE_LIT, width)
			button.draw_line(center, low_left, EDGE_LIT, width)
			button.draw_line(center, low_right, EDGE_LIT, width)
			for point in [top, center, low_left, low_right]:
				button.draw_circle(point, 1.4 * s, Color(0.35, 0.75, 1))
		"quest":
			var paper := Rect2(center - Vector2(3.2, 4.5) * s, Vector2(6.4, 9) * s)
			button.draw_rect(paper, Color(0.85, 0.75, 0.5))
			button.draw_rect(Rect2(center - Vector2(0.7, 3.4) * s, Vector2(1.4, 4.6) * s), Color(1, 0.82, 0.1))
			button.draw_rect(Rect2(center + Vector2(-0.7, 2.1) * s, Vector2(1.4, 1.4) * s), Color(1, 0.82, 0.1))
			button.draw_rect(paper, OUTLINE, false, maxf(s * 0.5, 1.0))
		"social":
			_draw_bust(button, center + Vector2(-1.6, 1.6) * s, Color(0.85, 0.68, 0.5), Color(0.25, 0.45, 0.25), 0.75)
			_draw_bust(button, center + Vector2(1.6, 0.4) * s, Color(0.8, 0.62, 0.45), Color(0.3, 0.35, 0.6), 0.75)
		"map":
			var radius := 3.6 * s
			button.draw_circle(center, radius, Color(0.2, 0.4, 0.75))
			button.draw_circle(center + Vector2(-1.2, -1) * s, 1.6 * s, Color(0.3, 0.6, 0.25))
			button.draw_circle(center + Vector2(1.5, 1.4) * s, 1.2 * s, Color(0.3, 0.6, 0.25))
			button.draw_arc(center, radius, 0.0, TAU, 20, OUTLINE, maxf(s * 0.5, 1.0))
		"menu":
			# A gold crest.
			var crest := PackedVector2Array([
				center + Vector2(-3.2, -4) * s, center + Vector2(3.2, -4) * s,
				center + Vector2(3.2, 0.5) * s, center + Vector2(0, 4.5) * s, center + Vector2(-3.2, 0.5) * s,
			])
			button.draw_colored_polygon(crest, Color(0.95, 0.75, 0.25))
			button.draw_polyline(crest + PackedVector2Array([crest[0]]), OUTLINE, maxf(s * 0.5, 1.0))
			button.draw_line(center + Vector2(0, -3) * s, center + Vector2(0, 2.5) * s, Color(0.5, 0.15, 0.1), maxf(s * 0.9, 1.0))
	if lit:
		button.draw_rect(face, Color(1, 1, 1, 0.12))


## A head and shoulders, for the character and social pictures.
func _draw_bust(button: Control, at: Vector2, skin: Color, clothes: Color, scale := 1.0) -> void:
	var s := _ui_scale * scale
	button.draw_circle(at + Vector2(0, 3.2) * s, 3.4 * s, clothes)
	button.draw_rect(Rect2(at + Vector2(-3.4, 3.2) * s, Vector2(6.8, 2.2) * s), clothes)
	button.draw_circle(at + Vector2(0, -1.6) * s, 2.3 * s, skin)
