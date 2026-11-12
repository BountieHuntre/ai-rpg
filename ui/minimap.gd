class_name Minimap
extends Control
## Round minimap in the top right corner, north up, centred on the player with
## an arrow for their facing. The zone the player is in is rendered once from
## above (with the creatures and characters hidden) into a texture the map
## scrolls over, and swapped for the next zone's when they cross into it.
## Quest givers show their "!" or "?", and the spawn areas of creatures a
## quest underway still needs are shaded; turn-ins and areas out of range sit
## on the rim, but quests to take show only when they're on the map (the world
## map shows them all).
## The mouse wheel over it zooms; hovering a quest area or giver shows what
## it's for. Sizes are in HUD units times ui_scale.

## Diameter in HUD units, and the gap to the screen's top right corner.
## Tracked creatures' dots (the Ranger's Track Beasts...).
const TRACKED_COLOR := Color(1.0, 0.85, 0.3)
const SIZE := 72.0
const MARGIN := 4.0
## Room above the map for the zone name.
const TITLE := 9.0
## Yards from the centre to the rim at each zoom level.
const ZOOMS := [45.0, 70.0, 110.0]
## Pixels across a 400-yard zone's map; bigger zones get more, up to
## MAX_MAP_PIXELS, so every map is as sharp.
const MAP_PIXELS := 1024
const MAX_MAP_PIXELS := 4096
const AREA_COLOR := Color(1, 0.82, 0.2, 0.28)
const AREA_EDGE := Color(1, 0.82, 0.2, 0.8)
const BORDER := Color(0.55, 0.5, 0.38)
const OUTSIDE := Color(0.08, 0.1, 0.08)
const GREY := Color(0.6, 0.6, 0.6)
const DONE := Color(0.45, 0.9, 0.45)
## Creatures made by the dev console's "spawn".
const SPAWNED_COLOR := Color(1, 0.25, 0.2)

## Captured zone maps by zone name, kept across HUD rebuilds and reloads.
static var _maps: Dictionary
static var _zoom := 1

var _player: Player
var _world: World
## The zone shown, and its name over the map.
var _zone: Zone
var _zone_label := Label.new()
var _ui_scale := 1.0
## Draws a circle that clips the map and markers to it.
var _mask := Control.new()
var _map_rect := ColorRect.new()
var _overlay := Control.new()
## Quest spawn areas to shade: [center (x, z), radius in yards, tooltip rows].
var _areas: Array = []
## Where the last drawing put each hoverable thing: [local position, radius in
## pixels, tooltip rows]. Later entries are on top.
var _hotspots: Array = []
## Where hover text goes; set by the HUD.
var tooltip: ItemTooltip
var _hover_lines: Array = []
## Set while the world map is open over it, so hovering doesn't show its tooltips.
var hover_blocked := false


## The minimap's top left corner on screen, in HUD units, for laying out the
## buffs and tracker around it.
static func corner(screen_width: float) -> Vector2:
	return Vector2(screen_width - SIZE - MARGIN, MARGIN + TITLE)


func setup(player: Player, world: World, ui_scale: float, screen_width: float) -> void:
	_player = player
	_world = world
	_ui_scale = ui_scale
	position = corner(screen_width) * ui_scale
	size = Vector2.ONE * SIZE * ui_scale
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The map and markers are drawn only inside the circle the mask draws.
	_mask.size = size
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_mask.draw.connect(func() -> void: _mask.draw_circle(size / 2.0, size.x / 2.0, Color.WHITE))
	add_child(_mask)
	_map_rect.size = size
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = _map_shader()
	_map_rect.material = material
	_mask.add_child(_map_rect)
	_overlay.size = size
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_mask.add_child(_overlay)
	var rim := Control.new()
	rim.size = size
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.draw.connect(_draw_rim.bind(rim))
	add_child(rim)
	var zone := _zone_label
	zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone.add_theme_font_size_override("font_size", roundi(6 * ui_scale))
	zone.add_theme_color_override("font_color", Color("ffd100"))
	zone.add_theme_color_override("font_shadow_color", Color.BLACK)
	zone.add_theme_constant_override("shadow_offset_x", maxi(roundi(ui_scale), 1))
	zone.add_theme_constant_override("shadow_offset_y", maxi(roundi(ui_scale), 1))
	zone.position = Vector2(-10, -TITLE) * ui_scale
	zone.size = Vector2(SIZE + 20, TITLE) * ui_scale
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zone)
	GameState.quests_changed.connect(_update_areas)
	GameState.inventory_changed.connect(_update_areas)
	_update_areas()
	_show_zone()


## Puts up the map and name of the zone the player is in, rendering the map
## the first time.
func _show_zone() -> void:
	_zone = _world.zone_at(_player.global_position)
	_zone_label.text = _zone.zone_name
	var material := _map_rect.material as ShaderMaterial
	var map: Texture2D = _maps.get(_zone.zone_name)
	if map:
		material.set_shader_parameter("map", map)
	else:
		# Rendered now, or after one the world map asked for first.
		map_texture(_zone)


func _process(_delta: float) -> void:
	if not _player:
		return
	if not _zone.contains(Vector2(_player.global_position.x, _player.global_position.z)) and not _capturing:
		_show_zone()
	var material := _map_rect.material as ShaderMaterial
	var zone_size := _zone.size
	var p := _player.global_position
	material.set_shader_parameter("center", Vector2((p.x - _zone.center.x) / zone_size + 0.5, (p.z - _zone.center.y) / zone_size + 0.5))
	material.set_shader_parameter("radius", ZOOMS[_zoom] / zone_size)
	_overlay.queue_redraw()
	_update_hover()


## Shows what the quest area or giver under the mouse is for, in the item
## tooltip, and clears it when the mouse leaves.
func _update_hover() -> void:
	var lines := []
	var mouse := _overlay.get_local_mouse_position()
	var center := _overlay.size / 2.0
	if not hover_blocked and mouse.distance_to(center) <= center.x and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		for i in range(_hotspots.size() - 1, -1, -1):
			var spot: Array = _hotspots[i]
			if mouse.distance_to(spot[0]) <= spot[1]:
				lines = spot[2]
				break
	if lines != _hover_lines and tooltip:
		_hover_lines = lines
		tooltip.show_lines(lines)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom = clampi(_zoom + (-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 0, ZOOMS.size() - 1)
		accept_event()


func _draw_rim(rim: Control) -> void:
	var center := rim.size / 2.0
	draw_arc_on(rim, center, center.x, BORDER, maxf(2.0 * _ui_scale, 2.0))
	var font := rim.get_theme_default_font()
	var at := Vector2(center.x - 2 * _ui_scale, 7 * _ui_scale)
	rim.draw_string_outline(font, at, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(6 * _ui_scale), maxi(roundi(_ui_scale), 1), Color.BLACK)
	rim.draw_string(font, at, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(6 * _ui_scale), Color.WHITE)


static func draw_arc_on(item: CanvasItem, center: Vector2, radius: float, color: Color, width: float) -> void:
	item.draw_arc(center, radius - width / 2.0, 0.0, TAU, 64, color, width, true)


func _draw_overlay() -> void:
	var center := _overlay.size / 2.0
	var view := ZOOMS[_zoom] as float
	var scale := center.x / view
	var here := Vector2(_player.global_position.x, _player.global_position.z)
	_hotspots = []
	for area: Array in _areas:
		var offset: Vector2 = area[0] - here
		var radius: float = area[1]
		if offset.length() - radius < view:
			_overlay.draw_circle(center + offset * scale, radius * scale, AREA_COLOR)
			_overlay.draw_arc(center + offset * scale, radius * scale, 0.0, TAU, 32, AREA_EDGE, maxf(_ui_scale, 1.0))
			_hotspots.append([center + offset * scale, radius * scale, area[2]])
		else:
			# Off the map: a dot on the rim, pointing the way.
			var dot := center + offset.normalized() * (center.x - 4 * _ui_scale)
			_overlay.draw_circle(dot, 2.5 * _ui_scale, AREA_EDGE)
			_hotspots.append([dot, 4.0 * _ui_scale, area[2]])
	var font := _overlay.get_theme_default_font()
	for npc: Npc in get_tree().get_nodes_in_group("npcs"):
		var marker := QuestLog.marker(npc.npc_id())
		var offset := Vector2(npc.global_position.x, npc.global_position.z) - here
		var at := center + offset * scale
		var off_map := offset.length() * scale > center.x - 5 * _ui_scale
		if off_map:
			# Quests to take only show near by; turn-ins point the way.
			if marker[0] == "!":
				continue
			at = center + offset.normalized() * (center.x - 5 * _ui_scale)
		if str(marker[0]).is_empty():
			if offset.length() < view:
				_overlay.draw_circle(at, 1.5 * _ui_scale, Targeting.FRIENDLY_COLOR)
			continue
		_hotspots.append([at, 5.0 * _ui_scale, npc_lines(npc)])
		var font_size := roundi(9 * _ui_scale)
		_overlay.draw_string_outline(font, at + Vector2(-2.5, 3.5) * _ui_scale, marker[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(roundi(2 * _ui_scale), 2), Color.BLACK)
		_overlay.draw_string(font, at + Vector2(-2.5, 3.5) * _ui_scale, marker[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, marker[1])
	# Creatures made by the dev console's "spawn": red dots (bigger for elites
	# and bosses, grey once dead), on the rim when off the map; hover for which.
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.temporary:
			continue
		var offset := Vector2(enemy.global_position.x, enemy.global_position.z) - here
		var at := center + offset * scale
		if offset.length() * scale > center.x - 3 * _ui_scale:
			at = center + offset.normalized() * (center.x - 3 * _ui_scale)
		var alive := enemy.combatant.is_alive()
		var radius := (2.6 if enemy.boss else 2.2 if enemy.elite else 1.8) * _ui_scale
		_overlay.draw_circle(at, radius + maxf(_ui_scale * 0.6, 1.0), Color.BLACK)
		_overlay.draw_circle(at, radius, SPAWNED_COLOR if alive else GREY)
		var rank := " (Boss)" if enemy.boss else " (Elite)" if enemy.elite else ""
		_hotspots.append([at, radius + 2.0 * _ui_scale, [[enemy.combatant.display_name, "", SPAWNED_COLOR if alive else GREY],
			["Level %s%s" % ["??" if enemy.boss else str(enemy.level), rank], "" if alive else "Dead", Color.WHITE]]])
	# The Ranger's tracking (Track Beasts...): creatures of the tracked type on
	# the map, as yellow-edged dots; hover for which.
	var tracked: int = _player.spells.tracked_type() if _player.spells else 0
	if tracked != 0:
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.temporary or not enemy.combatant.is_alive() or int(Enemy.creature_data(enemy.creature_entry).get("CreatureType", 0)) != tracked:
				continue
			var offset := Vector2(enemy.global_position.x, enemy.global_position.z) - here
			if offset.length() > view:
				continue
			var at := center + offset * scale
			_overlay.draw_circle(at, 2.0 * _ui_scale, Color.BLACK)
			_overlay.draw_circle(at, 1.5 * _ui_scale, TRACKED_COLOR)
			_hotspots.append([at, 3.0 * _ui_scale, [[enemy.combatant.display_name, "", TRACKED_COLOR], ["Level %d" % enemy.level, "", Color.WHITE]]])
	# Party members: blue dots, on the rim when off the map.
	for bot in Party.members:
		if not is_instance_valid(bot):
			continue
		var offset := Vector2(bot.global_position.x, bot.global_position.z) - here
		var at := center + offset * scale
		if offset.length() * scale > center.x - 3 * _ui_scale:
			at = center + offset.normalized() * (center.x - 3 * _ui_scale)
		_overlay.draw_circle(at, 2.0 * _ui_scale, Targeting.PLAYER_COLOR)
	# The player: an arrow pointing the way they face (facing 0 is north).
	var forward := Vector2(-sin(_player.facing), -cos(_player.facing))
	var side := Vector2(-forward.y, forward.x)
	var tip := center + forward * 5.0 * _ui_scale
	var back := center - forward * 3.0 * _ui_scale
	var arrow := PackedVector2Array([tip, back + side * 3.5 * _ui_scale, center - forward * 1.5 * _ui_scale, back - side * 3.5 * _ui_scale])
	_overlay.draw_colored_polygon(arrow, Color.WHITE)
	_overlay.draw_polyline(arrow + PackedVector2Array([tip]), Color.BLACK, maxf(_ui_scale * 0.6, 1.0))


## The quest areas shown: [[center (x, z), radius, tooltip lines], ...].
func quest_areas() -> Array:
	return _areas


## Spawn areas of creatures that quests underway still need: ones to kill, and
## ones that drop a quest item still wanted.
func _update_areas() -> void:
	_areas = []
	var spawns: Array = _world.spawns()
	var wanted := {}
	for id: int in GameState.quests:
		var quest := QuestDB.get_quest(id)
		var lines := QuestLog.objective_lines(id)
		for i in quest.kills.size():
			if not lines[i][1]:
				wanted[int(quest.kills[i][0])] = true
		for j in quest.items.size():
			if lines[quest.kills.size() + j][1]:
				continue
			var item := int(quest.items[j][0])
			for spawn: Array in spawns:
				var loot := int(Enemy.creature_data(int(spawn[0])).get("LootId", 0))
				if item in LootTable.quest_items(loot):
					wanted[int(spawn[0])] = true
	for spawn: Array in spawns:
		var entry := int(spawn[0])
		if wanted.has(entry):
			_areas.append([spawn[1], float(spawn[2]), area_lines(entry)])


## Tooltip for a quest area: the creature, then each quest it counts toward
## with the objectives involved.
static func area_lines(entry: int) -> Array:
	var data := Enemy.creature_data(entry)
	var lines := [[str(data.get("Name", "")), "", Color.WHITE]]
	for quest: Array in QuestLog.objectives_for_creature(entry, int(data.get("LootId", 0))):
		lines.append([quest[0], "", QuestLog.YELLOW])
		for objective: Array in quest[1]:
			lines.append([" - " + objective[0], "", DONE if objective[1] else GREY])
	return lines


## Tooltip for a quest giver: their name and title, then their quests with
## what each is waiting on.
static func npc_lines(npc: Npc) -> Array:
	var lines := [[npc.npc_name, "", Targeting.FRIENDLY_COLOR], ["<%s>" % npc.subname, "", Color.WHITE]]
	for entry: Dictionary in QuestLog.for_npc(npc.npc_id()):
		var quest := QuestDB.get_quest(entry.id)
		var state := { QuestLog.Status.COMPLETE: "Ready to turn in", QuestLog.Status.AVAILABLE: "New quest", QuestLog.Status.ACTIVE: "In progress" }
		lines.append([quest.title, state.get(entry.status, ""), QuestLog.YELLOW])
	return lines


## Whether a zone's map is being rendered.
var _capturing := false
## Zones waiting for their map to be rendered (the world map asks for them).
var _queue: Array[Zone] = []
## A zone's map has been rendered.
signal map_ready(zone_name: String)


## A zone's rendered map, or null while it's being rendered (map_ready says
## when it's there).
func map_texture(zone: Zone) -> Texture2D:
	var map: Texture2D = _maps.get(zone.zone_name)
	if map == null and not zone in _queue:
		_queue.append(zone)
		_next_capture()
	return map


func _next_capture() -> void:
	if _capturing or _queue.is_empty():
		return
	var zone: Zone = _queue.pop_front()
	if _maps.has(zone.zone_name):
		_next_capture()
	else:
		_capture(zone, _map_rect.material as ShaderMaterial)


## Renders the zone from straight above once, with every creature, character
## and the camera's effects hidden, and keeps the picture.
func _capture(zone: Zone, material: ShaderMaterial) -> void:
	_capturing = true
	var viewport := SubViewport.new()
	var pixels := mini(roundi(MAP_PIXELS * zone.size / 400.0), MAX_MAP_PIXELS)
	viewport.size = Vector2i(pixels, pixels)
	viewport.world_3d = _world.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = zone.size
	camera.position = Vector3(zone.center.x, 150, zone.center.y)
	camera.rotation.x = -PI / 2.0
	camera.far = 400.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = OUTSIDE
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	camera.environment = environment
	viewport.add_child(camera)
	add_child(viewport)
	var hidden: Array[Node3D] = []
	for group in ["enemies", "npcs", "player", "bots"]:
		for node: Node3D in get_tree().get_nodes_in_group(group):
			if node.visible:
				node.visible = false
				hidden.append(node)
	for node in _player.get_viewport().get_camera_3d().get_children():
		if node is Node3D and node.visible:
			node.visible = false
			hidden.append(node)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	for node in hidden:
		if is_instance_valid(node):
			node.visible = true
	viewport.queue_free()
	var map := ImageTexture.create_from_image(image)
	_maps[zone.zone_name] = map
	_capturing = false
	if is_instance_valid(material) and zone == _zone:
		material.set_shader_parameter("map", map)
	map_ready.emit(zone.zone_name)
	_next_capture()


static func _map_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform sampler2D map : filter_linear, repeat_disable;
uniform vec2 center = vec2(0.5);
uniform float radius = 0.2;
uniform vec4 outside : source_color = vec4(0.08, 0.1, 0.08, 1.0);

void fragment() {
	vec2 uv = center + (UV * 2.0 - 1.0) * radius;
	bool off_map = uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0;
	COLOR = off_map ? outside : texture(map, uv);
}
"""
	return shader
