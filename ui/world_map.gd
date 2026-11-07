class_name WorldMap
extends Control
## The world map (M), like classic's: a large framed map over a darkened
## screen. It opens on the zone the player is in, showing the zone's map (the
## same top-down picture the minimap uses, Minimap.map_texture), the player's
## arrow and the party's dots, with the name of the place under the mouse
## along the top. The dropdown picks another zone or the whole world; on the
## world map the zones lie as they do in the world, and clicking one opens
## it; right-click zooms back out. Every quest giver's "!" or "?" shows, with
## the objectives of quests underway: the spawn areas of creatures they need
## (the minimap's), places to explore and chests holding what they need;
## hover one for what it is. The game carries on behind it. Sizes are in HUD
## units, times ui_scale.

const WORLD := "World"
const TITLE_BAR := 13.0
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
## What the mouse can point at: [[map position, radius, tooltip lines], ...].
var _hotspots: Array = []
var _hover_lines: Array = []


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
	var panel := UiStyle.panel(self, panel_size, ui_scale)
	panel.position = at * ui_scale
	move_child(panel, -1)
	UiStyle.title(panel, Vector2(BORDER + 1, 1.5), "World Map", ui_scale, 8)
	_picker.position = Vector2(panel_size.x / 2 - 40, 1.5) * ui_scale
	_picker.size = Vector2(80, 9) * ui_scale
	_picker.add_theme_font_size_override("font_size", roundi(6 * ui_scale))
	_picker.get_popup().add_theme_font_size_override("font_size", roundi(6 * ui_scale))
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.add_item(WORLD)
	for zone in _world.zones:
		_picker.add_item(zone.zone_name)
	_picker.item_selected.connect(func(index: int) -> void: show_view(_picker.get_item_text(index)))
	panel.add_child(_picker)
	UiStyle.close_button(panel, Vector2(panel_size.x - 11, 2), ui_scale, close)
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
	_minimap.hover_blocked = true
	show_view(_world.zone_at(_player.global_position).zone_name)


func close() -> bool:
	if not visible:
		return false
	visible = false
	_minimap.hover_blocked = false
	_show_tooltip([])
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
	if Settings.pressed(event, "world_map"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if visible:
		_map.queue_redraw()
		var lines := []
		var mouse := _map.get_local_mouse_position()
		if Rect2(Vector2.ZERO, _map.size).has_point(mouse):
			for i in range(_hotspots.size() - 1, -1, -1):
				if mouse.distance_to(_hotspots[i][0]) <= _hotspots[i][1]:
					lines = _hotspots[i][2]
					break
		_show_tooltip(lines)


func _show_tooltip(lines: Array) -> void:
	if lines != _hover_lines and _minimap.tooltip:
		_hover_lines = lines
		_minimap.tooltip.show_lines(lines)


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
	_draw_quests(font)
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


## Quest objectives, then quest givers' markers over them, each a hotspot.
func _draw_quests(font: Font) -> void:
	_hotspots = []
	var per_yard := _map.size.x / float(_bounds()[1])
	# Spawn areas of creatures quests underway need.
	for area: Array in _minimap.quest_areas():
		var point: Vector2 = area[0]
		if _on_view(Vector3(point.x, 0, point.y)):
			_hotspots.append(_area(point, float(area[1]) * per_yard, area[2]))
	# Places to explore.
	for id: int in GameState.quests:
		var place_name := QuestLog.explore_place(id)
		if place_name.is_empty() or GameState.quests[id].get("explored", false):
			continue
		for place: Array in _world.places():
			var point: Vector2 = place[1]
			if place[0] == place_name and _on_view(Vector3(point.x, 0, point.y)):
				_hotspots.append(_area(point, float(place[2]) * per_yard, [[QuestLog.place_title(place_name), "", Color.WHITE],
					[QuestDB.get_quest(id).title, "", QuestLog.YELLOW], [" - %s explored" % QuestLog.place_title(place_name), "", Minimap.GREY]]))
	# Chests holding what quests need: small gold diamonds.
	for object: GameObject in get_tree().get_nodes_in_group("game_objects"):
		if not object.is_spawned() or not object.is_usable() or not _on_view(object.global_position):
			continue
		var at := _to_map(Vector2(object.global_position.x, object.global_position.z))
		var r := 2.5 * _ui_scale
		var diamond := PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)])
		_map.draw_colored_polygon(diamond, Minimap.AREA_EDGE)
		_map.draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color.BLACK, maxf(_ui_scale * 0.6, 1.0))
		_hotspots.append([at, r + 2.0 * _ui_scale, [[object.object_name(), "", Color.WHITE], ["Holds what a quest needs", "", QuestLog.YELLOW]]])
	# Every quest giver with something for the player.
	var font_size := roundi(10 * _ui_scale)
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		var marker := QuestLog.marker(npc.npc_id())
		if str(marker[0]).is_empty() or not _on_view(npc.global_position):
			continue
		var at := _to_map(Vector2(npc.global_position.x, npc.global_position.z))
		var spot := at + Vector2(-2.5, 3.5) * _ui_scale
		_map.draw_string_outline(font, spot, marker[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(roundi(2 * _ui_scale), 2), Color.BLACK)
		_map.draw_string(font, spot, marker[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, marker[1])
		_hotspots.append([at, 5.0 * _ui_scale, Minimap.npc_lines(npc)])


## A shaded quest area (at least a few pixels across), as a hotspot.
func _area(point: Vector2, radius: float, lines: Array) -> Array:
	var at := _to_map(point)
	var r := maxf(radius, 3.0 * _ui_scale)
	_map.draw_circle(at, r, Minimap.AREA_COLOR)
	_map.draw_arc(at, r, 0.0, TAU, 32, Minimap.AREA_EDGE, maxf(_ui_scale, 1.0))
	return [at, r, lines]


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
