class_name WorldMap
extends Control
## The world map (M), like classic's: a large framed map over a darkened
## screen. It opens on the zone the player is in, showing the zone's map (the
## same top-down picture the minimap uses, Minimap.map_texture), the player's
## arrow and the party's dots, with the name of the place under the mouse
## along the top. The dropdown picks another zone or the whole world; on the
## world map the zones lie as they do in the world, and clicking one opens
## it; right-click zooms back out. The game carries on behind it. Sizes are in
## HUD units, times ui_scale.

const WORLD := "World"
const TITLE_BAR := 16.0
const BORDER := 4.0
const BACK := Color(0.08, 0.07, 0.06, 0.97)
const FRAME := Color(0.55, 0.45, 0.25)
const DIM := Color(0, 0, 0, 0.55)
const GOLD := Color("ffd100")
const ZONE_EDGE := Color(1, 0.82, 0.2, 0.9)
const PLAYER_ARROW := Color(1, 0.85, 0.2)
const LOADING := Color(0.7, 0.7, 0.7)

var _player: Player
var _world: World
var _minimap: Minimap
var _ui_scale := 1.0
## The zone shown, or WORLD.
var _view := ""
var _map := Control.new()
var _picker := OptionButton.new()
## Map side in HUD units.
var _side := 200.0


func setup(player: Player, world: World, minimap: Minimap, ui_scale: float, screen: Vector2) -> void:
	_player = player
	_world = world
	_minimap = minimap
	_ui_scale = ui_scale
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = screen * ui_scale
	_minimap.map_ready.connect(func(_zone_name: String) -> void: _map.queue_redraw())
	var dim := ColorRect.new()
	dim.color = DIM
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	_side = floorf(minf(screen.y - TITLE_BAR - BORDER * 2 - 16, screen.x - BORDER * 2 - 16))
	var panel_size := Vector2(_side + BORDER * 2, _side + TITLE_BAR + BORDER)
	var at := ((screen - panel_size) / 2.0).floor()
	var frame := ColorRect.new()
	frame.color = FRAME
	frame.position = (at - Vector2.ONE) * ui_scale
	frame.size = (panel_size + Vector2.ONE * 2) * ui_scale
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(frame)
	var panel := ColorRect.new()
	panel.color = BACK
	panel.position = Vector2.ONE * ui_scale
	panel.size = panel_size * ui_scale
	frame.add_child(panel)
	var title := _text(panel, Vector2(BORDER, 2), "World Map", GOLD, 8)
	title.size.x = 60 * ui_scale
	_picker.position = Vector2(panel_size.x / 2 - 40, 2) * ui_scale
	_picker.size = Vector2(80, 12) * ui_scale
	_picker.add_theme_font_size_override("font_size", roundi(6 * ui_scale))
	_picker.get_popup().add_theme_font_size_override("font_size", roundi(6 * ui_scale))
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.add_item(WORLD)
	for zone in _world.zones:
		_picker.add_item(zone.zone_name)
	_picker.item_selected.connect(func(index: int) -> void: show_view(_picker.get_item_text(index)))
	panel.add_child(_picker)
	var close_button := _text(panel, Vector2(panel_size.x - 10, 1), "x", Color(0.9, 0.4, 0.4), 8)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close.call_deferred()
	)
	_map.position = Vector2(BORDER, TITLE_BAR) * ui_scale
	_map.size = Vector2.ONE * _side * ui_scale
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	panel.add_child(_map)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Opens on the zone the player is in.
func open() -> void:
	visible = true
	show_view(_world.zone_at(_player.global_position).zone_name)


func close() -> bool:
	if not visible:
		return false
	visible = false
	return true


func is_open() -> bool:
	return visible


func show_view(view: String) -> void:
	_view = view
	for i in _picker.item_count:
		if _picker.get_item_text(i) == view:
			_picker.select(i)
	var zone := _world.zone_named(view)
	if zone:
		_minimap.map_texture(zone)
	else:
		for each in _world.zones:
			_minimap.map_texture(each)
	_map.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("world_map"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_map.queue_redraw()


# Where things are: world points (x, z) to pixels on the map and back.

## The world square the map shows: [top left (x, z), yards across].
func _bounds() -> Array:
	var zone := _world.zone_named(_view)
	if zone:
		return [zone.center - Vector2.ONE * zone.size / 2.0, zone.size]
	var low := Vector2.INF
	var high := -Vector2.INF
	for each in _world.zones:
		low = low.min(each.center - Vector2.ONE * each.size / 2.0)
		high = high.max(each.center + Vector2.ONE * each.size / 2.0)
	var across := maxf(high.x - low.x, high.y - low.y)
	# Centered in the square.
	return [(low + high) / 2.0 - Vector2.ONE * across / 2.0, across]


func _to_map(point: Vector2) -> Vector2:
	var bounds := _bounds()
	return (point - bounds[0]) / bounds[1] * _map.size


func _to_world(at: Vector2) -> Vector2:
	var bounds := _bounds()
	return bounds[0] + at / _map.size * bounds[1]


func _draw_map() -> void:
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), Minimap.OUTSIDE)
	var font := _map.get_theme_default_font()
	var mouse := _map.get_local_mouse_position()
	var hovered := Rect2(Vector2.ZERO, _map.size).has_point(mouse)
	var shown: Array[Zone] = []
	var zone := _world.zone_named(_view)
	if zone:
		shown.append(zone)
	else:
		shown.assign(_world.zones)
	var caption := ""
	for each in shown:
		var rect := Rect2(_to_map(each.center - Vector2.ONE * each.size / 2.0), Vector2.ONE * each.size / _bounds()[1] * _map.size.x)
		var texture := _minimap.map_texture(each)
		if texture:
			_map.draw_texture_rect(texture, rect, false)
		else:
			_centered(font, rect.get_center(), "Drawing the map...", LOADING, 7)
		if zone == null:
			var over := hovered and rect.has_point(mouse)
			_map.draw_rect(rect, ZONE_EDGE if over else Color(0, 0, 0, 0.6), false, maxf(_ui_scale * (1.5 if over else 1.0), 1.0))
			_centered(font, rect.get_center(), each.zone_name, GOLD, 9)
			if over:
				caption = each.zone_name
	# The place under the mouse, as classic names the area you point at.
	if zone and hovered:
		caption = zone.zone_name
		var point := _to_world(mouse)
		for place: Array in zone.places:
			if point.distance_to(place[1]) <= float(place[2]):
				caption = str(place[0]).capitalize() if str(place[0]).begins_with("the ") else str(place[0])
				break
	if caption != "":
		_centered(font, Vector2(_map.size.x / 2.0, 10 * _ui_scale), caption, GOLD, 9)
	# The party's dots, then the player's arrow on top.
	for bot in Party.members:
		if is_instance_valid(bot) and _on_view(bot.global_position):
			var at := _to_map(Vector2(bot.global_position.x, bot.global_position.z))
			_map.draw_circle(at, 2.6 * _ui_scale, Color.BLACK)
			_map.draw_circle(at, 2.0 * _ui_scale, Targeting.PLAYER_COLOR)
	if _on_view(_player.global_position):
		var center := _to_map(Vector2(_player.global_position.x, _player.global_position.z))
		var forward := Vector2(-sin(_player.facing), -cos(_player.facing))
		var side := Vector2(-forward.y, forward.x)
		var tip := center + forward * 6.0 * _ui_scale
		var back := center - forward * 3.5 * _ui_scale
		var arrow := PackedVector2Array([tip, back + side * 4.0 * _ui_scale, center - forward * 1.5 * _ui_scale, back - side * 4.0 * _ui_scale])
		_map.draw_colored_polygon(arrow, PLAYER_ARROW)
		_map.draw_polyline(arrow + PackedVector2Array([tip]), Color.BLACK, maxf(_ui_scale * 0.7, 1.0))


## Whether a point is on the zone shown (anywhere, on the world map).
func _on_view(point: Vector3) -> bool:
	var zone := _world.zone_named(_view)
	return zone == null or zone.contains(Vector2(point.x, point.z))


func _centered(font: Font, at: Vector2, text: String, color: Color, font_size: int) -> void:
	var pixels := roundi(font_size * _ui_scale)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var spot := at + Vector2(-width / 2.0, pixels / 3.0)
	_map.draw_string_outline(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, maxi(roundi(2 * _ui_scale), 2), Color.BLACK)
	_map.draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)


## Left-click a zone on the world map to open it; right-click zooms out.
func _on_map_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and _view != WORLD:
		show_view(WORLD)
	elif button.button_index == MOUSE_BUTTON_LEFT and _view == WORLD:
		var point := _to_world(button.position)
		for zone in _world.zones:
			if zone.contains(point):
				show_view(zone.zone_name)
				break


func _text(parent: Control, at: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at * _ui_scale
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
