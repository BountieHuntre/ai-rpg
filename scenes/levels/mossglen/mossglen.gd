class_name Mossglen
extends Zone
## The Wood Elves' starting glen on Kareth, standing in for classic's
## Shadowglen: a 400-yard moonlit hollow for levels 1 to 6 at the foot of the
## Elderbough, the great tree in its middle, with a moonwell at its roots and
## the elves' bowers round it. Young shadecats and thistle boars roam the
## glen, fenlings creep about the Shadowrock in the south-west, and Silkwood
## spiders nest in the Silkhollow, the cave in the south-east, under Sissith
## the Vile. The road runs south down the roots of the world-tree onto
## Eldergrove Isle.
## Built in code, in world coordinates. -Z is north.

const ZONE_NAME := "Mossglen"
const CENTER := Vector2(-2200, -5000)
const SIZE := 400.0
const STEP := 2.0
const MOUNTAIN_START := 62.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const ROAD_WIDTH := 2.2
const SEED := 5301

const HUB := Vector2(-2200, -5010)
const HUB_HEIGHT := 5.0
const HUB_FLAT := 36.0
## The Elderbough's trunk, in the middle of the hub.
const TREE_RADIUS := 9.0
## Where Wood Elves wake and the dead of Mossglen come back: by the moonwell,
## south of the great tree, facing south.
const GRAVEYARD := Vector3(-2200, HUB_HEIGHT, -4984)
const GRAVEYARD_FACING := PI
const POND := Vector2(-2130, -5000)
const POND_RADIUS := 12.0

const PLACES := [
	["the moonwell", Vector2(-2200, -4990), 6.0],
	["the lily pool", POND, 16.0],
	["Thalindra's grove", Vector2(-2290, -5020), 12.0],
	["the Silkhollow", Vector2(-2090, -4900), 28.0],
	["the Shadowrock", Vector2(-2320, -4945), 28.0],
	["the Elderbough", HUB, 36.0],
	["the pass", Vector2(-2205, -4810), 30.0],
	["the northern glades", Vector2(-2160, -5120), 60.0],
	["the eastern glades", Vector2(-2090, -5040), 50.0],
	["the western glades", Vector2(-2280, -5080), 50.0],
]
const FLATS := [
	[Vector2(-2090, -4900), 12.0, 8.0],   # before the Silkhollow
	[Vector2(-2320, -4945), 12.0, 7.0],   # before the Shadowrock
	[Vector2(-2290, -5020), 8.0, 5.0],    # Thalindra's grove
]
const SILKHOLLOW := 0
const SHADOWROCK := 1
const GROVE := 2
const HILLS := [
	[Vector2(-2070, -4880), 36.0, 18.0],  # the Silkhollow's hill
	[Vector2(-2345, -4925), 34.0, 16.0],  # the Shadowrock
	[Vector2(-2120, -5120), 40.0, 8.0],
]
const PASS_END := Vector2(-2200, -4870)
const ROADS := [
	[Vector2(-2186, -5040), Vector2(-2170, -5080), Vector2(-2160, -5120)],
	[Vector2(-2204, -4974), Vector2(-2200, -4930), PASS_END],
	[Vector2(-2180, -4980), Vector2(-2130, -4940), Vector2(-2098, -4908)],
	[Vector2(-2220, -4985), Vector2(-2270, -4965), Vector2(-2312, -4950)],
	[Vector2(-2230, -5012), Vector2(-2282, -5020)],
]
const SPAWNS := [
	[2031, Vector2(-2140, -5070), 55.0, 10],  # Young Shadecat (1-2)
	[1984, Vector2(-2260, -5080), 45.0, 9],   # Young Thistle Boar (1-2)
	[2032, Vector2(-2090, -5120), 45.0, 9],   # Mangy Shadecat (2-3)
	[1985, Vector2(-2200, -5140), 45.0, 9],   # Thistle Boar (2-3)
	[1985, Vector2(-2300, -5130), 30.0, 4],
	[1989, Vector2(-2300, -4980), 35.0, 10],  # Fenkin, round the Shadowrock (3-4)
	[1988, Vector2(-2320, -4935), 18.0, 6],   # Fenling (2-3)
	[1986, Vector2(-2090, -4900), 22.0, 12],  # Silkwood Spider, the Silkhollow (3-4)
	[1994, Vector2(-2078, -4888), 1.0, 1],    # Sissith the Vile (5)
]
## Silkwood Eggs in the Silkhollow, Hyacinth Mushrooms round the Shadowrock,
## Moonpetal Lilies at the lily pool.
const CHESTS := [
	[4406, Vector2(-2086, -4893), 8.0, 3],
	[152094, Vector2(-2300, -4975), 30.0, 6],
	[152095, POND, POND_RADIUS + 3.0, 5],
]

const GRASS := Color(0.24, 0.36, 0.3)
const BLUE_GRASS := Color(0.3, 0.33, 0.38)
const MOSS := Color(0.3, 0.42, 0.26)
const PATH := Color(0.42, 0.36, 0.34)
const ROCK := Color(0.36, 0.36, 0.44)
const BARK := Color(0.32, 0.26, 0.3)
const PALE_WOOD := Color(0.6, 0.52, 0.48)
const LEAVES := Color(0.24, 0.4, 0.34)
const VIOLET := Color(0.42, 0.3, 0.55)
const TEAL := Color(0.2, 0.45, 0.5)
const MOONWATER := Color(0.55, 0.8, 0.95)

var _detail := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	continent = "kareth"
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = HUB
	hub_name = "the Elderbough"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS
	# The moonwell at the Elderbough's roots (Crown of the Earth).
	spell_focuses = [[19549, Vector2(-2200, -4992)]]


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_elderbough()
	_build_caves()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Mossglen", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	var half := SIZE / 2.0
	height += mountain_height(x, z, smoothstep(half - MOUNTAIN_START, half - MOUNTAIN_FULL, reach))
	for hill: Array in HILLS:
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, point.distance_to(HUB)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 12.0, point.distance_to(flat[0])))
	height = minf(height, lerpf(0.2, height, smoothstep(POND_RADIUS, POND_RADIUS + 8.0, point.distance_to(POND))))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.05
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var color := GRASS.lerp(BLUE_GRASS, smoothstep(0.0, 0.5, patch)).lerp(MOSS, smoothstep(-0.1, -0.5, patch))
	color = color.lerp(PATH, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point)))
	for flat: Array in FLATS:
		color = color.lerp(PATH, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.4)
	color = color.lerp(ROCK, smoothstep(0.84, 0.64, normal.y))
	color = color.lerp(ROCK, smoothstep(24.0, 34.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).
func _cave_mouth(parent: Node3D, at: Vector3, yaw: float, width := 5.0) -> void:
	var mouth := Node3D.new()
	mouth.position = at
	mouth.rotation.y = yaw
	parent.add_child(mouth)
	Props.box(mouth, Vector3(0, 0, 1.0), Vector3(width, 4.0, 2.0), Color(0.04, 0.04, 0.07), 0.0, false)
	for side in [-1, 1]:
		Props.box(mouth, Vector3(side * (width / 2.0 + 0.8), 0, 0), Vector3(1.8, 5.0, 3.0), ROCK)
	Props.box(mouth, Vector3(0, 4.0, 0), Vector3(width + 3.4, 1.6, 3.0), ROCK, 0.0, false)


## An elven bower: a round wooden floor under a sweeping violet roof on posts.
func _bower(parent: Node3D, at: Vector3, radius: float, roof_color: Color) -> void:
	Props.cylinder(parent, at, radius, 0.4, PALE_WOOD)
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		Props.box(parent, at + Vector3(cos(angle), 0, sin(angle)) * (radius - 0.5), Vector3(0.3, 3.2, 0.3), PALE_WOOD, 0.0, false)
	Props.cylinder(parent, at + Vector3(0, 3.2, 0), radius + 0.8, 1.6, roof_color, false, 0.2)


## A moonwell: a ring of pale stone round still, glowing water.
func _moonwell(parent: Node3D, at: Vector3, radius: float) -> void:
	Props.cylinder(parent, at, radius, 0.7, PALE_WOOD.lightened(0.3))
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius - 0.5
	disc.bottom_radius = radius - 0.5
	disc.height = 0.1
	water.mesh = disc
	var glow := StandardMaterial3D.new()
	glow.albedo_color = MOONWATER
	glow.emission_enabled = true
	glow.emission = MOONWATER
	glow.emission_energy_multiplier = 0.6
	water.material_override = glow
	water.position = at + Vector3(0, 0.72, 0)
	parent.add_child(water)
	var light := OmniLight3D.new()
	light.light_color = MOONWATER
	light.omni_range = radius * 4.0
	light.light_energy = 0.8
	light.position = at + Vector3(0, 2.0, 0)
	parent.add_child(light)


# The Elderbough: a vast trunk rising out of the glen with roots spread round
# it and a crown of leaves far overhead, a moonwell at its foot and the elves'
# bowers in a ring.

func _build_elderbough() -> void:
	var tree := Node3D.new()
	tree.name = "Elderbough"
	add_child(tree)
	var t := HUB
	var y := HUB_HEIGHT
	Props.cylinder(tree, _near(t, Vector2(0, -12), y - 1.0), TREE_RADIUS, 70.0, BARK, true, TREE_RADIUS * 0.6)
	for i in 7:
		var angle := TAU * i / 7.0 + 0.3
		var root := Props.box(tree, _near(t, Vector2(0, -12) + Vector2(cos(angle), sin(angle)) * (TREE_RADIUS + 2.0), y - 0.6), Vector3(3.0, 2.4, 7.0), BARK, -angle + PI / 2, false)
		root.rotation.x = 0.15
	var crowns: Array[Transform3D] = []
	for i in 9:
		var angle := TAU * i / 9.0
		var reach := 14.0 + (i % 3) * 5.0
		crowns.append(Transform3D(Basis().scaled(Vector3(1.4, 0.6, 1.4)), _near(t, Vector2(0, -12) + Vector2(cos(angle), sin(angle)) * reach, y + 58.0 + (i % 2) * 6.0)))
	crowns.append(Transform3D(Basis().scaled(Vector3(1.8, 0.8, 1.8)), _near(t, Vector2(0, -12), y + 70.0)))
	Props.scatter(tree, Props.blob(12.0), LEAVES, crowns)
	_moonwell(tree, _near(t, Vector2(0, 18), y), 3.2)
	for i in 6:
		var angle := TAU * i / 6.0 + 0.5
		var at := t + Vector2(0, -12) + Vector2(cos(angle), sin(angle)) * 26.0
		if at.y > t.y + 6.0 and absf(at.x - t.x) < 10.0:
			continue
		_bower(tree, Vector3(at.x, y, at.y), 3.6, VIOLET if i % 2 == 0 else TEAL)
	for lamp in [Vector2(-8, 10), Vector2(8, 10), Vector2(-14, -2), Vector2(14, -2)]:
		Props.box(tree, _near(t, lamp, y), Vector3(0.25, 2.4, 0.25), PALE_WOOD, 0.0, false)
		torch(tree, _near(t, lamp, y + 2.4), 6.0)
	var grove: Array = FLATS[GROVE]
	for i in 5:
		var angle := TAU * i / 5.0
		Props.cylinder(tree, _near(grove[0], Vector2(cos(angle), sin(angle)) * 6.0, grove[2]), 0.4, 1.2, PALE_WOOD.lightened(0.2), false, 0.3)


func _build_caves() -> void:
	var caves := Node3D.new()
	caves.name = "Caves"
	add_child(caves)
	var silk: Array = FLATS[SILKHOLLOW]
	_cave_mouth(caves, _near(silk[0], Vector2(8, 8), silk[2]), PI / 4.0, 6.0)
	var webs: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 9
	for i in 10:
		var at: Vector2 = silk[0] + Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
		webs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(2.4, 2.0, 0.05)), Vector3(at.x, silk[2] + 1.2, at.y)))
	Props.scatter(caves, BoxMesh.new(), Color(0.86, 0.86, 0.9), webs)
	var shadow: Array = FLATS[SHADOWROCK]
	_cave_mouth(caves, _near(shadow[0], Vector2(-8, 8), shadow[2]), -PI / 4.0, 5.0)


func _clear(point: Vector2) -> bool:
	if point.distance_to(HUB) < HUB_FLAT + 3.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	if point.distance_to(POND) < POND_RADIUS + 3.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


## Tall elven trees: pale-barked trunks under broad crowns.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.6
	trunk_shape.height = 6.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in 1600:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 28.0 or not _clear(point) or rng.randf() > 0.1 + 0.15 * smoothstep(8.0, 16.0, y):
			continue
		var size := rng.randf_range(0.9, 1.5)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		trunks.append(base * Transform3D(Basis(), Vector3(0, 3.0, 0)))
		crowns.append(base * Transform3D(Basis().scaled(Vector3(1.4, 0.75, 1.4)), Vector3(0, 7.0, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 3.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3
	trunk.bottom_radius = 0.55
	trunk.height = 6.0
	trunk.radial_segments = 6
	add_child(trees)
	Props.scatter(trees, trunk, PALE_WOOD.darkened(0.2), trunks)
	Props.scatter(trees, Props.blob(2.8), LEAVES, crowns)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 800:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.03 + 0.4 * smoothstep(10.0, 22.0, y) or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.4), rng.randf_range(0.6, 2.2))
		placed.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(size), Vector3(point.x, y + size.y * 0.3, point.y)))
		if size.x > 1.2 and size.z > 1.2:
			var collision := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = minf(size.x, size.z) * 0.8
			collision.shape = shape
			collision.position = Vector3(point.x, y, point.y)
			rocks.add_child(collision)
	add_child(rocks)
	Props.scatter(rocks, Props.blob(1.0, 6, 3), ROCK, placed)


## Ferns and blue-white moonflowers.
func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var ferns: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 14000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.08:
			flowers.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), at + Vector3.UP * 0.25))
		else:
			ferns.append(Transform3D(spin.scaled(Vector3(1.3, rng.randf_range(0.8, 1.4), 1.3)), at + Vector3.UP * 0.2))
	add_clutter(clutter, Props.cone(0.22, 0.4, 5), Color(0.26, 0.46, 0.34), ferns)
	add_clutter(clutter, Props.blob(0.1, 5, 3), Color(0.7, 0.8, 0.98), flowers)
