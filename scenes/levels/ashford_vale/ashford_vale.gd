class_name AshfordVale
extends Zone
## The starting area: a forest valley ringed by mountains, about 400 yards
## across, for levels 1 to 6 (the burrowlings' Firecallers by the mine are 7-8). Ashford Priory stands in the middle, with
## wolves in the meadow and woods, burrowlings at their mine to the west,
## brigands camped to the southeast and boars in the southwest hills.
## Everything but the NPCs, light and sky is built here from the layout below,
## the same way every time. -Z is north.

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")

const ZONE_NAME := "Ashford Vale"
const SIZE := 400.0
const STEP := 2.0
## Players can't walk past this, and the mountains rise before it.
const EDGE := 196.0
const WATER_LEVEL := 1.4
const STREAM_BED := 0.2
const STREAM_WIDTH := 4.0
const ROAD_WIDTH := 2.6
const SEED := 1077

const PRIORY := Vector2(0, 0)
const PRIORY_HEIGHT := 4.5
const PRIORY_FLAT := 34.0
## Where new characters start, and where the dead come back.
const SPAWN := Vector3(0, PRIORY_HEIGHT, 12)
const SPAWN_FACING := PI
## Walled places that playerbots go in and out of by their gate:
## [x min, z min, x max, z max, outside the gate, inside the gate].
const ENCLOSURES := [
	[-24.0, -20.0, 24.0, 22.0, Vector2(0, 27), Vector2(0, 17)],  # the priory, gate in the south wall
]

## Named places, for what playerbots say: [name, center, radius], smallest
## first, so a point is in the first place that holds it.
const PLACES := [
	["the bridge", Vector2(0, 86), 9.0],
	["the priory", Vector2(0, 0), 30.0],
	["the mine", Vector2(-98, 5), 22.0],
	["the brigand camp", Vector2(105, 135), 24.0],
	["the mine road", Vector2(-45, 28), 22.0],
	["the meadow", Vector2(30, 52), 30.0],
	["the boar hills", Vector2(-95, 135), 45.0],
	["the east woods", Vector2(110, -20), 70.0],
	["the north woods", Vector2(0, -115), 75.0],
]

## Level areas flattened for camps: [center, radius, height].
const FLATS := [
	[Vector2(-98, 5), 16.0, 6.0],   # Burrowling mine
	[Vector2(105, 135), 16.0, 5.0], # Brigand camp
]
## Rounded hills: [center, radius, height].
const HILLS := [
	[Vector2(-150, 5), 55.0, 26.0],  # The mine hill
	[Vector2(-95, 135), 45.0, 9.0],  # Boar hills
	[Vector2(60, -150), 50.0, 14.0],
	[Vector2(150, 40), 35.0, 8.0],
]
const STREAM := [
	Vector2(-210, 40), Vector2(-120, 55), Vector2(-40, 78), Vector2(0, 86),
	Vector2(50, 80), Vector2(110, 100), Vector2(210, 150),
]
const ROADS := [
	[Vector2(0, 22), Vector2(0, 60), Vector2(0, 86), Vector2(2, 112)],
	[Vector2(0, 52), Vector2(-40, 40), Vector2(-80, 15), Vector2(-100, 5)],
	[Vector2(2, 112), Vector2(50, 128), Vector2(100, 135)],
	[Vector2(0, 40), Vector2(50, 20), Vector2(95, 0)],
]
## Woods: [center, radius]. Trees thin out toward the edges.
const WOODS := [
	[Vector2(110, -20), 70.0],
	[Vector2(0, -115), 75.0],
	[Vector2(-60, -60), 40.0],
	[Vector2(150, 90), 35.0],
]
## Creatures that never attack on sight here, whatever their classic faction:
## every burrowling (Runt, Digger, Hauler, Delver, Pickman, Firecaller), so
## the mine is safe to learn on.
const PASSIVE_CREATURES := [6, 257, 80, 475, 40, 476]
## Creature spawns: [creature entry, center, radius, count].
const SPAWNS := [
	[299, Vector2(35, 50), 22.0, 7],    # Young Wolf, meadow
	[299, Vector2(-25, 64), 14.0, 4],
	[6, Vector2(-45, 28), 18.0, 7],     # Burrowling Runt, on the mine road
	[69, Vector2(100, -15), 40.0, 9],   # Timber Wolf, east woods
	[69, Vector2(15, -105), 35.0, 6],   # north woods
	[257, Vector2(-92, 8), 13.0, 6],    # Burrowling Digger, mine camp
	[80, Vector2(-94, 24), 10.0, 5],    # Burrowling Hauler
	[80, Vector2(-98, -10), 9.0, 3],
	[475, Vector2(-106, -2), 6.0, 4],   # Burrowling Delver, by the mine
	[38, Vector2(105, 135), 15.0, 9],   # Masked Brigand, brigand camp
	[113, Vector2(-90, 130), 35.0, 8],  # Ridgetusk Boar, southwest hills
	# New groups go last, so saved corpses keep their names.
	[40, Vector2(-101, 14), 9.0, 4],    # Burrowling Pickman, mine camp (6-7)
	[476, Vector2(-108, 0), 6.0, 3],    # Burrowling Firecaller, by the mine (7-8)
	[94, Vector2(110, 140), 12.0, 5],   # Brigand Footpad, brigand camp (5-6)
]

const GRASS := Color(0.36, 0.55, 0.25)
const FOREST_FLOOR := Color(0.26, 0.4, 0.19)
const ROCK := Color(0.47, 0.45, 0.42)
const DIRT := Color(0.55, 0.42, 0.28)
const MUD := Color(0.42, 0.36, 0.27)
const PAVING := Color(0.6, 0.57, 0.5)
const STONE := Color(0.66, 0.63, 0.58)
const DARK_STONE := Color(0.45, 0.43, 0.41)
const ROOF := Color(0.55, 0.22, 0.17)
const WOOD := Color(0.45, 0.31, 0.2)
const DARK_WOOD := Color(0.3, 0.2, 0.13)
const CANVAS := Color(0.62, 0.55, 0.42)

var _detail := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	zone_name = ZONE_NAME
	size = SIZE
	graveyard = SPAWN
	graveyard_facing = SPAWN_FACING
	hub = PRIORY
	places = PLACES
	spawns = SPAWNS
	enclosures = ENCLOSURES


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_priory()
	_build_mine()
	_build_brigand_camp()
	_build_bridge()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Creature", PASSIVE_CREATURES, WATER_LEVEL)


# Shape of the land.

func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	# Mountains all around the valley.
	height += mountain_height(x, z, smoothstep(0.78, 1.05, point.length() / 185.0))
	for hill: Array in HILLS:
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	height = lerpf(PRIORY_HEIGHT, height, smoothstep(PRIORY_FLAT, PRIORY_FLAT + 16.0, point.distance_to(PRIORY)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 16.0, point.distance_to(flat[0])))
	var stream := distance_to_line(point, STREAM)
	height = minf(height, lerpf(STREAM_BED, height, smoothstep(STREAM_WIDTH, STREAM_WIDTH + 7.0, stream)))
	# The pass south to Harrowfield.
	return carve_passes(x, z, height)


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.06
	var color := GRASS.lerp(FOREST_FLOOR, _woods_density(point))
	color = color.lerp(PAVING, 1.0 - smoothstep(26.0, 30.0, _priory_distance(point)))
	for flat: Array in FLATS:
		color = color.lerp(DIRT, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.8)
	var road := INF
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	road = minf(road, distance_to_pass(point))
	color = color.lerp(DIRT, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, road))
	color = color.lerp(MUD, 1.0 - smoothstep(STREAM_WIDTH + 1.0, STREAM_WIDTH + 4.0, distance_to_line(point, STREAM)))
	color = color.lerp(ROCK, smoothstep(0.82, 0.68, normal.y))
	color = color.lerp(ROCK, smoothstep(24.0, 34.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _woods_density(point: Vector2) -> float:
	var density := 0.0
	for wood: Array in WOODS:
		density = maxf(density, 1.0 - smoothstep(wood[1] * 0.5, wood[1], point.distance_to(wood[0])))
	return density


## Distance to the priory's walls, which form a rectangle.
func _priory_distance(point: Vector2) -> float:
	var outside := Vector2(maxf(absf(point.x) - 24.0, 0.0), maxf(absf(point.y - 1.0) - 21.0, 0.0))
	return outside.length() + 24.0


# Ashford Priory: a walled courtyard with a chapel, a hall, a smithy and a well.

func _build_priory() -> void:
	var priory := Node3D.new()
	priory.name = "Priory"
	add_child(priory)
	var y := PRIORY_HEIGHT
	# Walls around x -24..24, z -20..22, with a gate in the south wall.
	Props.box(priory, Vector3(0, y, -20), Vector3(49.5, 4, 1.5), STONE)
	Props.box(priory, Vector3(-24, y, 1), Vector3(1.5, 4, 42), STONE)
	Props.box(priory, Vector3(24, y, 1), Vector3(1.5, 4, 42), STONE)
	Props.box(priory, Vector3(-14, y, 22), Vector3(21.5, 4, 1.5), STONE)
	Props.box(priory, Vector3(14, y, 22), Vector3(21.5, 4, 1.5), STONE)
	for corner in [Vector2(-24, -20), Vector2(24, -20), Vector2(-24, 22), Vector2(24, 22)]:
		Props.box(priory, Vector3(corner.x, y, corner.y), Vector3(3.5, 6, 3.5), DARK_STONE)
	for side in [-1, 1]:
		Props.box(priory, Vector3(side * 4.5, y, 22), Vector3(3, 7, 3), DARK_STONE)
	Props.box(priory, Vector3(0, y + 5.5, 22), Vector3(6, 1.5, 1.5), DARK_STONE, 0.0, false)
	# Chapel to the north, with a bell tower.
	Props.box(priory, Vector3(0, y, -13), Vector3(16, 7, 9), STONE)
	Props.roof(priory, Vector3(0, y + 7, -13), Vector3(17, 4, 10), ROOF)
	Props.box(priory, Vector3(0, y, -8.4), Vector3(2.4, 3.6, 0.3), DARK_WOOD, 0.0, false)
	Props.box(priory, Vector3(-6.5, y, -13), Vector3(4, 13, 4), STONE)
	Props.roof(priory, Vector3(-6.5, y + 13, -13), Vector3(4.6, 3, 4.6), ROOF)
	# Hall to the east.
	Props.box(priory, Vector3(17, y, -4), Vector3(8, 5, 12), STONE)
	Props.roof(priory, Vector3(17, y + 5, -4), Vector3(13, 3, 9), ROOF, PI / 2)
	# Provisioner's stall by the hall.
	Props.box(priory, Vector3(11.5, y, 6), Vector3(1.4, 1, 4), WOOD)
	Props.box(priory, Vector3(12.5, y, 6), Vector3(0.3, 3, 4.4), DARK_WOOD, 0.0, false)
	Props.box(priory, Vector3(11.8, y + 3, 6), Vector3(2.2, 0.2, 4.6), CANVAS, 0.0, false)
	for offset in [Vector3(14, 0, 9.5), Vector3(15.2, 0, 9.8), Vector3(14.4, 1, 9.6)]:
		Props.box(priory, Vector3(0, y, 0) + offset, Vector3(1, 1, 1), WOOD)
	# Open smithy to the west: a roof on posts, a forge and an anvil.
	for post in [Vector2(-20, -6), Vector2(-12, -6), Vector2(-20, 2), Vector2(-12, 2)]:
		Props.box(priory, Vector3(post.x, y, post.y), Vector3(0.5, 4, 0.5), DARK_WOOD)
	Props.roof(priory, Vector3(-16, y + 4, -2), Vector3(9.5, 2.5, 9.5), DARK_STONE, PI / 2)
	Props.box(priory, Vector3(-18.5, y, -4), Vector3(3, 2, 2.5), DARK_STONE)
	Props.box(priory, Vector3(-13, y, 4), Vector3(1.2, 0.9, 0.6), Color(0.25, 0.25, 0.28))
	# Well in the courtyard.
	Props.cylinder(priory, Vector3(6, y, 10), 1.2, 1.0, DARK_STONE)
	for side in [-1, 1]:
		Props.box(priory, Vector3(6 + side * 1.0, y, 10), Vector3(0.2, 2.6, 0.2), DARK_WOOD, 0.0, false)
	Props.roof(priory, Vector3(6, y + 2.6, 10), Vector3(2.8, 0.9, 2.2), ROOF)


# The burrowlings' mine in the western hill, with a timber-framed entrance.

func _build_mine() -> void:
	var mine := Node3D.new()
	mine.name = "Mine"
	add_child(mine)
	var y: float = FLATS[0][2]
	var x := -113.0
	Props.box(mine, Vector3(x - 3.5, y, 5), Vector3(7, 5, 5), Color(0.05, 0.04, 0.04))
	for side in [-1, 1]:
		Props.box(mine, Vector3(x, y, 5 + side * 2.7), Vector3(0.6, 4.6, 0.6), DARK_WOOD)
	Props.box(mine, Vector3(x, y + 4.6, 5), Vector3(0.8, 0.6, 6.2), DARK_WOOD, 0.0, false)
	# Carts, ore piles and crates.
	Props.box(mine, Vector3(-104, y, 0), Vector3(1.6, 1.2, 2.4), WOOD)
	Props.box(mine, Vector3(-98, y, 14), Vector3(1.2, 1.2, 1.2), WOOD)
	Props.box(mine, Vector3(-97, y, 15.5), Vector3(1.0, 1.0, 1.0), WOOD)
	for pile in [Vector2(-107, 12), Vector2(-90, -4)]:
		Props.cylinder(mine, Vector3(pile.x, y, pile.y), 1.6, 1.4, ROCK, true, 0.3)
	for torch in [Vector2(x + 0.4, 1.8), Vector2(x + 0.4, 8.2)]:
		torch(mine, Vector3(torch.x, y + 2.8, torch.y))


# The brigands' camp: tents around a campfire.

func _build_brigand_camp() -> void:
	var camp := Node3D.new()
	camp.name = "BrigandCamp"
	add_child(camp)
	var center: Vector2 = FLATS[1][0]
	var y: float = FLATS[1][2]
	for i in 4:
		var angle := TAU * i / 4.0 + 0.4
		var at := center + Vector2(cos(angle), sin(angle)) * 8.0
		Props.roof(camp, Vector3(at.x, y, at.y), Vector3(4, 2.6, 3.4), Color(0.45, 0.18, 0.15), -angle)
	Props.cylinder(camp, Vector3(center.x, y, center.y), 1.0, 0.3, DARK_STONE, false)
	torch(camp, Vector3(center.x, y + 0.6, center.y), 6.0)
	for crate in [Vector2(5, -3), Vector2(6, -2), Vector2(-4, 5)]:
		Props.box(camp, Vector3(center.x + crate.x, y, center.y + crate.y), Vector3(1, 1, 1), WOOD)


# A wooden bridge where the south road crosses the stream, with sloped ends
# that start at ground level, since walking can't step up a ledge.

const BRIDGE_X := 0.0
const BRIDGE_START := 76.0
const BRIDGE_END := 96.0
const BRIDGE_RAMP := 9.0


func _build_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "Bridge"
	add_child(bridge)
	var deck := maxf(height_at(BRIDGE_X, BRIDGE_START - 3.0), height_at(BRIDGE_X, BRIDGE_END + 3.0)) + 0.4
	var near := Vector3(BRIDGE_X, deck, BRIDGE_START)
	var far := Vector3(BRIDGE_X, deck, BRIDGE_END)
	# The ramps start a little underground, so their ends are buried.
	var sink := Vector3(0, -0.5, 0)
	plank(bridge, ground_point(BRIDGE_X, BRIDGE_START - BRIDGE_RAMP) + sink, near)
	plank(bridge, near, far)
	plank(bridge, far, ground_point(BRIDGE_X, BRIDGE_END + BRIDGE_RAMP) + sink)
	for side in [-1, 1]:
		Props.box(bridge, Vector3(BRIDGE_X + side * 2.4, deck, (BRIDGE_START + BRIDGE_END) / 2), Vector3(0.25, 1.0, BRIDGE_END - BRIDGE_START), DARK_WOOD)
		for z in [BRIDGE_START, (BRIDGE_START + BRIDGE_END) / 2, BRIDGE_END]:
			Props.box(bridge, Vector3(BRIDGE_X + side * 2.4, STREAM_BED - 1.0, z), Vector3(0.5, deck - STREAM_BED + 2.0, 0.5), DARK_WOOD, 0.0, false)


# Woods and scattered trees, placed by a seeded random walk over the map.

func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pine_trunks: Array[Transform3D] = []
	var pine_lower: Array[Transform3D] = []
	var pine_upper: Array[Transform3D] = []
	var oak_trunks: Array[Transform3D] = []
	var oak_crowns: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.45
	trunk_shape.height = 4.0
	for attempt in 7000:
		var point := Vector2(rng.randf_range(-EDGE, EDGE), rng.randf_range(-EDGE, EDGE))
		var chance := 0.03 + 0.55 * _woods_density(point)
		var y := height_at(point.x, point.y)
		chance += 0.25 * smoothstep(8.0, 14.0, y) * (1.0 - smoothstep(26.0, 32.0, y))
		if rng.randf() > chance or not _clear_for_tree(point, y):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		var pine := y > 12.0 or point.y < -60.0 or rng.randf() < 0.3
		if pine:
			pine_trunks.append(base * Transform3D(Basis(), Vector3(0, 1.0, 0)))
			pine_lower.append(base * Transform3D(Basis(), Vector3(0, 3.2, 0)))
			pine_upper.append(base * Transform3D(Basis(), Vector3(0, 5.0, 0)))
		else:
			oak_trunks.append(base * Transform3D(Basis(), Vector3(0, 1.4, 0)))
			oak_crowns.append(base * Transform3D(Basis(), Vector3(0, 4.3, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.35
	trunk.height = 2.0
	trunk.radial_segments = 6
	var oak_trunk := trunk.duplicate() as CylinderMesh
	oak_trunk.height = 2.8
	oak_trunk.top_radius = 0.3
	oak_trunk.bottom_radius = 0.45
	# Added once its shapes are in: adding shapes to a body in the world
	# rebuilds the body each time.
	add_child(trees)
	Props.scatter(trees, trunk, DARK_WOOD, pine_trunks)
	Props.scatter(trees, Props.cone(1.9, 3.6), Color(0.16, 0.34, 0.2), pine_lower)
	Props.scatter(trees, Props.cone(1.35, 2.8), Color(0.19, 0.39, 0.22), pine_upper)
	Props.scatter(trees, oak_trunk, WOOD, oak_trunks)
	Props.scatter(trees, Props.blob(2.3), Color(0.27, 0.48, 0.2), oak_crowns)


func _clear_for_tree(point: Vector2, y: float) -> bool:
	if y < WATER_LEVEL + 0.6 or y > 34.0:
		return false
	if _priory_distance(point) < 32.0 or distance_to_line(point, STREAM) < STREAM_WIDTH + 4.0:
		return false
	if distance_to_pass(point) < PASS_FLOOR + 3.0:
		return false
	for line: Array in ROADS:
		if distance_to_line(point, line) < ROAD_WIDTH + 2.5:
			return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return point.distance_to(Vector2(0, 86)) > 16.0


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	for attempt in 1500:
		var point := Vector2(rng.randf_range(-EDGE, EDGE), rng.randf_range(-EDGE, EDGE))
		var y := height_at(point.x, point.y)
		var chance := 0.04 + 0.4 * smoothstep(9.0, 20.0, y)
		if rng.randf() > chance or not _clear_for_tree(point, minf(y, 30.0)):
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
	# Added once its shapes are in: adding shapes to a body in the world
	# rebuilds the body each time.
	add_child(rocks)
	Props.scatter(rocks, Props.blob(1.0, 6, 3), ROCK, placed)


const CLUTTER_ATTEMPTS := 16000


## Grass tufts and flowers on open ground: only for looks, so no collision
## and no shadows. Placed in random order, so drawing a share of them thins
## them evenly.
func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var grass: Array[Transform3D] = []
	var tall_grass: Array[Transform3D] = []
	var yellow: Array[Transform3D] = []
	var white: Array[Transform3D] = []
	for attempt in CLUTTER_ATTEMPTS:
		var point := Vector2(rng.randf_range(-EDGE, EDGE), rng.randf_range(-EDGE, EDGE))
		var y := height_at(point.x, point.y)
		if y > 26.0 or not _clear_for_clutter(point, y):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		var roll := rng.randf()
		if roll < 0.06:
			(yellow if rng.randf() < 0.6 else white).append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), at + Vector3.UP * 0.25))
		elif roll < 0.4:
			tall_grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(1.2, 1.8), 1)), at + Vector3.UP * 0.2))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.2), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.18, 0.3, 4), Color(0.3, 0.52, 0.22), grass)
	add_clutter(clutter, Props.cone(0.14, 0.4, 4), Color(0.36, 0.56, 0.24), tall_grass)
	add_clutter(clutter, Props.blob(0.09, 5, 3), Color(0.95, 0.82, 0.25), yellow)
	add_clutter(clutter, Props.blob(0.09, 5, 3), Color(0.92, 0.92, 0.88), white)


## Open ground: not on roads, water, paving or camps.
func _clear_for_clutter(point: Vector2, y: float) -> bool:
	if y < WATER_LEVEL + 0.4 or _priory_distance(point) < 28.0 or distance_to_line(point, STREAM) < STREAM_WIDTH + 1.5:
		return false
	if distance_to_pass(point) < ROAD_WIDTH + 0.8:
		return false
	for line: Array in ROADS:
		if distance_to_line(point, line) < ROAD_WIDTH + 0.8:
			return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1]:
			return false
	return true
