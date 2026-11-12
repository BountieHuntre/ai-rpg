class_name Zone
extends Node3D
## What every zone shares. Zones sit side by side in their continent's world
## (World), each a square SIZE yards across around its center, in world
## coordinates, with mountains along its edges. Where two zones meet, both use
## the same mountain shape from the same noise, so the ground joins up, and a
## pass (PASSES) is cut through the mountains on both sides. -Z is north.

## Mountain noise shared by every zone, in world coordinates.
const LAND_SEED := 1077
## Passes between zones, per continent (the two worlds' coordinates overlap,
## so a continent's passes never touch the other's ground): "line", points in
## world coordinates, the first end in one zone and the last in the other; and
## the border it crosses, where it climbs highest: "z" for a border running
## east-west at that z, "x" for one running north-south. The mountains are
## cut down along them and the edge walls open where they cross.
const PASSES := {
	"aldmark": [
		# Ashford Vale's bridge road south to Wexford.
		{ "line": [Vector2(2, 112), Vector2(-18, 150), Vector2(-30, 200), Vector2(-24, 250), Vector2(-8, 290)], "z": 200.0 },
		# Gravesend's road east down into Duskmoor Glades.
		{ "line": [Vector2(-2370, -4200), Vector2(-2335, -4195), Vector2(-2300, -4190), Vector2(-2265, -4185), Vector2(-2230, -4180)], "x": -2300.0 },
		# Frosthollow's Frozen Stair east up into Highpeak.
		{ "line": [Vector2(-770, -955), Vector2(-735, -958), Vector2(-700, -962), Vector2(-665, -966), Vector2(-630, -970)], "x": -700.0 },
	],
	"kareth": [
		# The Redsand Coast's road east up to Emberhollow.
		{ "line": [Vector2(2235, -1745), Vector2(2270, -1745), Vector2(2300, -1735), Vector2(2335, -1712), Vector2(2370, -1690)], "x": 2300.0 },
		# Sunfold Camp's trail north up into the Tallgrass.
		{ "line": [Vector2(-500, 1070), Vector2(-505, 1035), Vector2(-510, 1000), Vector2(-515, 965), Vector2(-520, 930)], "z": 1000.0 },
		# Mossglen's road south down the great tree's roots onto Eldergrove Isle.
		{ "line": [Vector2(-2200, -4870), Vector2(-2203, -4835), Vector2(-2206, -4800), Vector2(-2209, -4765), Vector2(-2212, -4730)], "z": -4800.0 },
	],
}
## Half the width of a pass's flat floor, and how far its sides run up.
const PASS_FLOOR := 7.0
const PASS_SIDES := 13.0
## How high the pass climbs at the border, over the land around it.
const PASS_CREST := 7.0
## Half the width of the gap in the edge walls where a pass crosses them.
const PASS_GAP := 10.0
const MOUNTAIN_HEIGHT := 38.0
const MOUNTAIN_ROUGHNESS := 14.0
## Players can't walk past this far from the center, along each axis, except
## through a pass.
const EDGE_INSET := 4.0

static var _land: FastNoiseLite

## The continent the zone is on (World.CONTINENTS), for its passes.
var continent := "aldmark"
## The zone's name, its center (x, z) and width in yards, set by each zone.
var zone_name := ""
var center := Vector2.ZERO
var size := 400.0
## Where the dead of this zone come back, and the way they face.
var graveyard := Vector3.ZERO
var graveyard_facing := 0.0
## The middle of the zone's main settlement: directions to places are from here.
var hub := Vector2.ZERO
## What the settlement is called, for directions ("west of Wexford").
var hub_name := ""
## Named places: [name, center, radius], smallest first.
var places: Array = []
## Creature spawns: [creature entry, center, radius, count].
var spawns: Array = []
## Game objects: quest givers and enders that are things [object entry,
## node name (quests' giver or ender), point (x, z), facing], and chests to
## loot scattered round a spot [object entry, center, radius, count].
var quest_objects: Array = []
var chests: Array = []
## Spell focus objects (gameobjects.json "focus"): [object entry, point (x, z)],
## invisible, beside what they stand for (a moonwell, a well).
var spell_focuses: Array = []
## Walled places bots go in and out of by the gate:
## [x min, z min, x max, z max, outside the gate, inside the gate].
var enclosures: Array = []


static func land_noise() -> FastNoiseLite:
	if _land == null:
		_land = FastNoiseLite.new()
		_land.seed = LAND_SEED
		_land.frequency = 0.008
		_land.fractal_octaves = 4
	return _land


## Whether a point (x, z) is in this zone's square.
func contains(point: Vector2) -> bool:
	var half := size / 2.0
	return absf(point.x - center.x) <= half and absf(point.y - center.y) <= half


## The ground's height. Each zone gives its own.
func height_at(_x: float, _z: float) -> float:
	return 0.0


## The land with no features: gentle rolling ground.
static func base_height(x: float, z: float) -> float:
	return land_noise().get_noise_2d(x, z) * 3.0 + 4.5


## The mountains at a point, `ring` being how far up them it is (0 to 1).
static func mountain_height(x: float, z: float, ring: float) -> float:
	return ring * (MOUNTAIN_HEIGHT + land_noise().get_noise_2d(x * 3.1, z * 3.1) * MOUNTAIN_ROUGHNESS)


## This zone's continent's passes (PASSES).
func passes() -> Array:
	return PASSES.get(continent, [])


## Cuts the passes into a height: a road-wide floor a little above the land
## around, its sides easing up into the mountains, highest at the border.
func carve_passes(x: float, z: float, height: float) -> float:
	var point := Vector2(x, z)
	for each: Dictionary in passes():
		var line: Array = each.line
		var along := Vector2.ZERO
		var distance := INF
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			var d := point.distance_to(a + (b - a) * t)
			if d < distance:
				distance = d
				along = a + (b - a) * t
		if distance > PASS_FLOOR + PASS_SIDES:
			continue
		var from_border := absf(along.y - float(each.z)) if each.has("z") else absf(along.x - float(each.x))
		var crest := PASS_CREST * _bump(from_border / 70.0)
		var floor_height := base_height(along.x, along.y) + crest
		var cut := lerpf(floor_height, height, smoothstep(PASS_FLOOR, PASS_FLOOR + PASS_SIDES, distance))
		height = minf(height, cut)
	return height


## 1 at the middle, easing to 0 at t = 1.
static func _bump(t: float) -> float:
	return (cos(t * PI) + 1.0) / 2.0 if t < 1.0 else 0.0


static func distance_to_line(point: Vector2, line: Array) -> float:
	var best := INF
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, point.distance_to(a + (b - a) * t))
	return best


## Distance to the nearest pass.
func distance_to_pass(point: Vector2) -> float:
	var best := INF
	for each: Dictionary in passes():
		best = minf(best, distance_to_line(point, each.line))
	return best


func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


## Ground over the zone's square, colored by `color` (f(x, z, y, normal)).
func build_ground(step: float, color: Callable) -> void:
	var ground := Terrain.new()
	ground.name = "Ground"
	add_child(ground)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	# The shared noise is made now, before the worker threads read it.
	land_noise()
	ground.build(size, step, height_at, color, material, center)
	_ground = ground


var _ground: Terrain


## The height of the ground as built (Terrain.sample), once it is; before
## that, the height function.
func ground_height(x: float, z: float) -> float:
	return _ground.sample(x, z) if _ground else height_at(x, z)


## Water at a height over the zone's square.
func build_water(level: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.22, 0.42, 0.62, 0.75)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.2
	plane.material = water
	var view := MeshInstance3D.new()
	view.name = "Water"
	view.mesh = plane
	view.position = Vector3(center.x, level, center.y)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## Invisible walls round the zone's square, open where a pass crosses them.
func build_edges() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Edges"
	add_child(walls)
	var half := size / 2.0 - EDGE_INSET
	# Each side as a line from one corner to the next.
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for side in 4:
		var a: Vector2 = center + corners[side]
		var b: Vector2 = center + corners[(side + 1) % 4]
		var gaps: Array[float] = []
		for each: Dictionary in passes():
			var line: Array = each.line
			for i in line.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(a, b, line[i], line[i + 1])
				if hit != null:
					gaps.append((hit as Vector2).distance_to(a))
		gaps.sort()
		var length := a.distance_to(b)
		var start := 0.0
		for gap in gaps + [length + PASS_GAP]:
			var end: float = gap - PASS_GAP
			if end > start:
				_wall(walls, a.lerp(b, (start + end) / 2.0 / length), end - start, b - a)
			start = gap + PASS_GAP


func _wall(parent: StaticBody3D, at: Vector2, length: float, direction: Vector2) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 200.0, 2.0)
	shape.shape = box
	shape.position = Vector3(at.x, 50.0, at.y)
	shape.rotation.y = -direction.angle()
	parent.add_child(shape)


## A 5 yard wide walkway whose top runs from one point to the other.
func plank(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var thickness := 0.4
	var length := from.distance_to(to)
	var slope := atan2(to.y - from.y, to.z - from.z)
	var body := StaticBody3D.new()
	body.position = (from + to) / 2.0
	# Turning about +X lowers the +Z end, so a rise toward +Z is a negative angle.
	body.rotation.x = -slope
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5, thickness, length)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = Props.material(Color(0.45, 0.31, 0.2))
	view.position.y = -thickness / 2.0
	body.add_child(view)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -thickness / 2.0
	body.add_child(collision)
	parent.add_child(body)


## A row of sharpened logs from one point to another, `height` tall (the
## Horde's palisades).
func palisade(parent: Node3D, from: Vector2, to: Vector2, y: float, color: Color, height := 4.5) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	Props.box(parent, Vector3((from.x + to.x) / 2, y, (from.y + to.y) / 2), Vector3(length, height, 0.9), color, -direction.angle())
	var steps := int(length / 1.5)
	var tips: Array[Transform3D] = []
	for i in steps + 1:
		var at := from.lerp(to, float(i) / maxf(steps, 1))
		tips.append(Transform3D(Basis(), Vector3(at.x, y + height + 0.5, at.y)))
	Props.scatter(parent, Props.cone(0.5, 1.2, 5), color, tips)


## A round Horde hut: low log walls under a tall hide roof, a bone spike on top.
func round_hut(parent: Node3D, at: Vector2, radius: float, y: float, wall: Color, roof_color: Color, spike: Color) -> void:
	Props.cylinder(parent, Vector3(at.x, y, at.y), radius, 2.6, wall)
	var roof := MeshInstance3D.new()
	roof.mesh = Props.cone(radius * 1.25, radius * 1.1, 8)
	roof.material_override = Props.material(roof_color)
	roof.position = Vector3(at.x, y + 2.6 + radius * 0.55, at.y)
	parent.add_child(roof)
	Props.box(parent, Vector3(at.x, y + 2.6 + radius * 1.1, at.y), Vector3(0.25, 1.6, 0.25), spike, 0.0, false)


## A Hornkin tipi: a hide cone round a frame of poles that cross at the top.
func tipi(parent: Node3D, at: Vector2, y: float, radius: float, hide: Color, pole: Color) -> void:
	var cone := MeshInstance3D.new()
	cone.mesh = Props.cone(radius, radius * 2.2, 8)
	cone.material_override = Props.material(hide)
	cone.position = Vector3(at.x, y + radius * 1.1, at.y)
	parent.add_child(cone)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius * 0.8
	cylinder.height = radius * 1.6
	shape.shape = cylinder
	shape.position = Vector3(at.x, y + radius * 0.8, at.y)
	body.add_child(shape)
	parent.add_child(body)
	for i in 4:
		var angle := TAU * i / 4.0 + 0.4
		var stick := Props.box(parent, Vector3(at.x, y + radius * 2.2, at.y), Vector3(0.12, 1.4, 0.12), pole, 0.0, false)
		stick.rotation = Vector3(cos(angle) * 0.4, 0.0, sin(angle) * 0.4)


## A carved totem pole of stacked blocks in turn colours.
func totem(parent: Node3D, at: Vector2, y: float, height: float, colors: Array) -> void:
	var block := height / 4.0
	for i in 4:
		Props.box(parent, Vector3(at.x, y + i * block, at.y), Vector3(1.0 - i * 0.08, block, 1.0 - i * 0.08), colors[i % colors.size()], i * 0.3, i == 0)
	Props.box(parent, Vector3(at.x, y + height * 0.8, at.y), Vector3(2.6, 0.3, 0.4), colors[0], 0.0, false)


func torch(parent: Node3D, at: Vector3, light_range := 4.0) -> void:
	var flame := MeshInstance3D.new()
	flame.mesh = Props.blob(0.25, 5, 3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.6, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.5, 0.15)
	glow.emission_energy_multiplier = 2.0
	flame.material_override = glow
	flame.position = at
	parent.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.35)
	light.omni_range = light_range
	light.position = at + Vector3(0, 0.3, 0)
	parent.add_child(light)


## Ground clutter for the Environment Detail option: share of the tufts and
## flowers drawn.
const CLUTTER_SHARE := { "Off": 0.0, "Low": 0.33, "Medium": 0.66, "High": 1.0 }

var _clutter: Array[MultiMeshInstance3D] = []


func add_clutter(parent: Node3D, mesh: Mesh, color: Color, transforms: Array[Transform3D]) -> void:
	Props.scatter(parent, mesh, color, transforms)
	var view := parent.get_child(parent.get_child_count() - 1) as MultiMeshInstance3D
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clutter.append(view)


## The Environment Detail option: how much of the clutter is drawn.
func set_clutter(level: String) -> void:
	var share: float = CLUTTER_SHARE.get(level, 0.66)
	for view in _clutter:
		view.visible = share > 0.0
		view.multimesh.visible_instance_count = roundi(view.multimesh.instance_count * share)


## The zone's game objects (quest_objects, chests), under an Objects node.
func spawn_objects(rng_seed: int, water_level: float) -> void:
	var objects := Node3D.new()
	objects.name = "Objects"
	add_child(objects)
	for spec: Array in quest_objects:
		var thing := QuestObject.new()
		thing.name = spec[1]
		thing.entry = spec[0]
		thing.position = ground_point(spec[2].x, spec[2].y)
		thing.rotation.y = spec[3]
		objects.add_child(thing)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for group: Array in chests:
		for i in int(group[3]):
			var chest := GameObject.new()
			chest.entry = group[0]
			chest.position = _spawn_point(rng, group[1], group[2], water_level)
			chest.rotation.y = rng.randf() * TAU
			objects.add_child(chest)


## Creatures, placed the same way each time so saved corpses match by name:
## `prefix` keeps names apart between zones.
func spawn_creatures(rng_seed: int, prefix: String, passive_entries: Array, water_level: float) -> void:
	var creatures := Node3D.new()
	creatures.name = "Creatures"
	add_child(creatures)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for group in spawns.size():
		var spawn: Array = spawns[group]
		for i in int(spawn[3]):
			var at := _spawn_point(rng, spawn[1], spawn[2], water_level)
			var enemy: Enemy = AshfordVale.ENEMY_SCENE.instantiate()
			enemy.name = "%s%02d_%02d" % [prefix, group, i]
			enemy.creature_entry = spawn[0]
			enemy.passive = spawn[0] in passive_entries
			enemy.position = at + Vector3(0, 0.1, 0)
			creatures.add_child(enemy)


func _spawn_point(rng: RandomNumberGenerator, around: Vector2, radius: float, water_level: float) -> Vector3:
	var point := around
	for attempt in 20:
		var angle := rng.randf() * TAU
		point = around + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * radius
		if height_at(point.x, point.y) > water_level + 0.3:
			break
	return ground_point(point.x, point.y)
