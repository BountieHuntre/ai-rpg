class_name Frosthollow
extends Zone
## The Dwarves' and Gnomes' starting valley in Aldmark's mountains, standing in
## for classic's Coldridge Valley: a 400-yard snowbound hollow for levels 1 to
## 6. The Hollow Hall, the dwarves' stone hall with its smithy, stands in the
## middle, its doors facing south; Tavin's hunting camp is to the west and
## Gerrin's camp in the north-west under the Troll Caves, where the Icemane whelps and Grisknar the
## Cold hole up. The Stonejaw troggs dig in the north-east, and the road climbs the
## Frozen Stair there, east through the pass into Highpeak. Ragged wolves and
## crag boars roam the snow. Built in code, in world coordinates. -Z is north.

const ZONE_NAME := "Frosthollow"
const CENTER := Vector2(-900, -1000)
const SIZE := 400.0
const STEP := 2.0
const MOUNTAIN_START := 62.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 0.4
const ROAD_WIDTH := 2.4
const SEED := 5101

const HUB := Vector2(-890, -1000)
const HUB_HEIGHT := 6.0
const HUB_FLAT := 34.0
## Where Dwarves and Gnomes wake and the dead of Frosthollow come back: before
## the hall's doors, facing south.
const GRAVEYARD := Vector3(-890, HUB_HEIGHT, -980)
const GRAVEYARD_FACING := PI

const PLACES := [
	["Tavin's camp", Vector2(-1010, -990), 12.0],
	["Gerrin's camp", Vector2(-960, -1105), 12.0],
	["the Hollow Hall", Vector2(-890, -1000), 34.0],
	["the Troll Caves", Vector2(-1010, -1150), 30.0],
	["the Frozen Stair", Vector2(-765, -950), 30.0],
	["the trogg diggings", Vector2(-805, -1065), 45.0],
	["the wolf hollow", Vector2(-930, -885), 50.0],
	["the boar slopes", Vector2(-1035, -930), 45.0],
]
const FLATS := [
	[Vector2(-1010, -990), 9.0, 5.0],    # Tavin's camp
	[Vector2(-960, -1105), 9.0, 5.0],    # Gerrin's camp
	[Vector2(-1010, -1150), 16.0, 6.0],  # before the Troll Caves
	[Vector2(-805, -1065), 16.0, 4.5],   # the trogg diggings
]
const TAVIN := 0
const GERRIN := 1
const CAVES := 2
const DIGGINGS := 3
const HILLS := [
	[Vector2(-1030, -1185), 40.0, 20.0],  # the hill the Troll Caves run into
	[Vector2(-890, -1060), 30.0, 12.0],   # the rise behind the Hollow Hall
	[Vector2(-780, -1110), 30.0, 10.0],
	[Vector2(-1060, -880), 40.0, 10.0],
]
const PASS_END := Vector2(-770, -955)
const ROADS := [
	[Vector2(-870, -990), Vector2(-820, -970), PASS_END],
	[Vector2(-910, -995), Vector2(-960, -992), Vector2(-1000, -990)],
	[Vector2(-905, -1012), Vector2(-935, -1060), Vector2(-958, -1098)],
	[Vector2(-965, -1112), Vector2(-990, -1135)],
	[Vector2(-860, -1012), Vector2(-830, -1045)],
]
const SPAWNS := [
	[705, Vector2(-850, -905), 40.0, 10],    # Ragged Young Wolf (1-2)
	[705, Vector2(-950, -1055), 35.0, 6],
	[704, Vector2(-1000, -905), 45.0, 8],    # Ragged Timber Wolf (2-3)
	[708, Vector2(-1045, -955), 40.0, 9],    # Small Crag Boar (3)
	[708, Vector2(-935, -885), 40.0, 6],
	[707, Vector2(-820, -1055), 40.0, 9],    # Stonejaw Trogg, the diggings (1-2)
	[724, Vector2(-790, -1090), 35.0, 8],    # Burly Stonejaw Trogg (2-3)
	[1718, Vector2(-775, -935), 28.0, 6],    # Stonejaw Raider, the Frozen Stair (3-4)
	[706, Vector2(-1000, -1135), 35.0, 12],  # Icemane Troll Whelp, the Troll Caves (3-4)
	[946, Vector2(-1015, -1155), 16.0, 4],   # Icemane Novice (3-4)
	[808, Vector2(-1022, -1168), 1.0, 1],    # Grisknar the Cold (5)
]
## Fenwick's lost things (A Refugee's Quandary): his box by the troll caves, his
## chest in the diggings, his bucket of bolts on the Frozen Stair.
const CHESTS := [
	[148499, Vector2(-985, -1128), 6.0, 1],
	[178084, Vector2(-800, -1075), 6.0, 1],
	[178085, Vector2(-782, -945), 6.0, 1],
]

const SNOW := Color(0.8, 0.82, 0.87)
const BLUE_SNOW := Color(0.64, 0.7, 0.82)
const PATH := Color(0.56, 0.5, 0.44)
const ROCK := Color(0.46, 0.46, 0.5)
const STONE := Color(0.55, 0.53, 0.5)
const DARK_STONE := Color(0.36, 0.35, 0.36)
const SLATE := Color(0.3, 0.32, 0.38)
const TIMBER := Color(0.4, 0.28, 0.18)
const CANVAS := Color(0.62, 0.55, 0.42)
const PINE := Color(0.2, 0.34, 0.28)

var _detail := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	continent = "aldmark"
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = HUB
	hub_name = "the Hollow Hall"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_edges()
	_build_hall()
	_build_camps()
	_build_caves()
	_build_diggings()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Frosthollow", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z) + 1.5
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	var half := SIZE / 2.0
	height += mountain_height(x, z, smoothstep(half - MOUNTAIN_START, half - MOUNTAIN_FULL, reach))
	for hill: Array in HILLS:
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, point.distance_to(HUB)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 12.0, point.distance_to(flat[0])))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.04
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var color := SNOW.lerp(BLUE_SNOW, smoothstep(0.0, 0.5, patch))
	color = color.lerp(PATH, (1.0 - smoothstep(HUB_FLAT - 12.0, HUB_FLAT - 6.0, point.distance_to(HUB))) * 0.7)
	for flat: Array in FLATS:
		color = color.lerp(PATH, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.5)
	color = color.lerp(PATH, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point)))
	color = color.lerp(ROCK, smoothstep(0.82, 0.6, normal.y))
	color = color.lerp(SNOW, smoothstep(30.0, 40.0, y) * 0.8)
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).
func _cave_mouth(parent: Node3D, at: Vector3, yaw: float, width := 5.0) -> void:
	var mouth := Node3D.new()
	mouth.position = at
	mouth.rotation.y = yaw
	parent.add_child(mouth)
	Props.box(mouth, Vector3(0, 0, 1.0), Vector3(width, 4.0, 2.0), Color(0.06, 0.06, 0.08), 0.0, false)
	for side in [-1, 1]:
		Props.box(mouth, Vector3(side * (width / 2.0 + 0.8), 0, 0), Vector3(1.8, 5.0, 3.0), ROCK)
	Props.box(mouth, Vector3(0, 4.0, 0), Vector3(width + 3.4, 1.6, 3.0), ROCK, 0.0, false)


# The Hollow Hall: a long stone hall with a slate roof, its great doors facing
# south onto the yard, a forge and anvil by its east end and braziers.

func _build_hall() -> void:
	var hall := Node3D.new()
	hall.name = "HollowHall"
	add_child(hall)
	var t := HUB
	var y := HUB_HEIGHT
	Props.box(hall, _near(t, Vector2(0, -26), y), Vector3(30, 7, 12), STONE)
	Props.roof(hall, _near(t, Vector2(0, -26), y + 7), Vector3(32, 4, 13.5), SLATE)
	Props.box(hall, _near(t, Vector2(0, -19.9), y), Vector3(5, 5, 0.3), TIMBER, 0.0, false)
	for side in [-1, 1]:
		Props.box(hall, _near(t, Vector2(side * 4.5, -19.5), y), Vector3(1.4, 6.5, 1.4), DARK_STONE)
		Props.box(hall, _near(t, Vector2(side * 16, -26), y + 7), Vector3(1.6, 5.5, 1.6), DARK_STONE)
	# The smithy: a stone forge and an anvil under a lean-to.
	Props.box(hall, _near(t, Vector2(22, -14), y), Vector3(3, 2, 3), DARK_STONE)
	Props.box(hall, _near(t, Vector2(22, -14), y + 2), Vector3(1.6, 3.5, 1.6), DARK_STONE, 0.0, false)
	Props.box(hall, _near(t, Vector2(18, -10), y), Vector3(1.2, 0.9, 0.6), Color(0.28, 0.28, 0.3))
	Props.roof(hall, _near(t, Vector2(21, -12), y + 3.4), Vector3(8, 1.6, 7), SLATE)
	for post in [Vector2(17.5, -8.8), Vector2(24.5, -8.8)]:
		Props.box(hall, _near(t, post, y), Vector3(0.3, 3.4, 0.3), TIMBER, 0.0, false)
	torch(hall, _near(t, Vector2(22, -12.4), y + 2.0), 6.0)
	# A pair of houses for the hall's folk.
	for house in [Vector2(-24, -4), Vector2(26, 8)]:
		Props.box(hall, _near(t, house, y), Vector3(8, 4, 7), STONE)
		Props.roof(hall, _near(t, house, y + 4), Vector3(9, 2.4, 8), SLATE)
	for brazier in [Vector2(-8, -14), Vector2(8, -14), Vector2(-10, 14), Vector2(10, 14)]:
		Props.cylinder(hall, _near(t, brazier, y), 0.6, 1.0, DARK_STONE, false, 0.8)
		torch(hall, _near(t, brazier, y + 1.0), 7.0)


# Tavin's hunting camp and Gerrin's camp: a tent, a fire and crates each.

func _build_camps() -> void:
	var camps := Node3D.new()
	camps.name = "Camps"
	add_child(camps)
	for index in [TAVIN, GERRIN]:
		var flat: Array = FLATS[index]
		var at: Vector2 = flat[0]
		Props.roof(camps, _near(at, Vector2(-3, -3), flat[2]), Vector3(4, 2.6, 4.5), CANVAS, 0.4)
		Props.box(camps, _near(at, Vector2(3, -2), flat[2]), Vector3(1.2, 1.0, 1.2), TIMBER)
		Props.box(camps, _near(at, Vector2(4.2, -1.2), flat[2]), Vector3(1.0, 0.8, 1.0), TIMBER, 0.5)
		Props.cylinder(camps, _near(at, Vector2(0, 2), flat[2]), 0.9, 0.25, ROCK, false)
		torch(camps, _near(at, Vector2(0, 2), flat[2] + 0.5), 6.0)


# The Troll Caves: two mouths in the hill's south face, bones and a totem of
# the Icemane before them.

func _build_caves() -> void:
	var caves := Node3D.new()
	caves.name = "TrollCaves"
	add_child(caves)
	var flat: Array = FLATS[CAVES]
	var at: Vector2 = flat[0]
	_cave_mouth(caves, _near(at, Vector2(-6, -14), flat[2]), PI)
	_cave_mouth(caves, _near(at, Vector2(9, -12), flat[2]), PI, 4.0)
	Props.cylinder(caves, _near(at, Vector2(2, 4), flat[2]), 0.3, 4.0, TIMBER, true)
	var skull := MeshInstance3D.new()
	skull.mesh = Props.blob(0.45, 6, 3)
	skull.material_override = Props.material(Color(0.88, 0.85, 0.78))
	skull.position = _near(at, Vector2(2, 4), flat[2] + 4.2)
	caves.add_child(skull)
	torch(caves, _near(at, Vector2(-1, -8), flat[2] + 0.6), 6.0)


# The trogg diggings: spoil heaps, a broken cart and crude torches.

func _build_diggings() -> void:
	var diggings := Node3D.new()
	diggings.name = "Diggings"
	add_child(diggings)
	var flat: Array = FLATS[DIGGINGS]
	var heaps: Array[Transform3D] = []
	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		var at: Vector2 = flat[0] + Vector2(cos(angle), sin(angle)) * 11.0
		heaps.append(Transform3D(Basis().scaled(Vector3(2.4, 1.2, 2.4)), Vector3(at.x, flat[2], at.y)))
	Props.scatter(diggings, Props.blob(1.0, 6, 3), Color(0.42, 0.38, 0.34), heaps)
	Props.box(diggings, _near(flat[0], Vector2(2, 3), flat[2] + 0.4), Vector3(2.4, 1.0, 1.4), TIMBER, 0.6)
	_cave_mouth(diggings, _near(flat[0], Vector2(8, -15), flat[2]), PI, 4.0)
	torch(diggings, _near(flat[0], Vector2(-3, -2), flat[2] + 0.5), 6.0)


func _clear(point: Vector2) -> bool:
	if point.distance_to(HUB) < HUB_FLAT + 3.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


## Snowy pines, thicker up the slopes.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in 1800:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 30.0 or not _clear(point) or rng.randf() > 0.05 + 0.25 * smoothstep(9.0, 18.0, y):
			continue
		var size := rng.randf_range(0.8, 1.4)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		trunks.append(base * Transform3D(Basis(), Vector3(0, 0.9, 0)))
		crowns.append(base * Transform3D(Basis(), Vector3(0, 3.6, 0)))
		caps.append(base * Transform3D(Basis().scaled(Vector3(0.7, 0.7, 0.7)), Vector3(0, 5.4, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.35
	trunk.height = 1.8
	trunk.radial_segments = 6
	add_child(trees)
	Props.scatter(trees, trunk, TIMBER, trunks)
	Props.scatter(trees, Props.cone(1.8, 4.4, 7), PINE, crowns)
	Props.scatter(trees, Props.cone(1.3, 2.6, 7), SNOW, caps)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 1000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if rng.randf() > 0.05 + 0.4 * smoothstep(10.0, 22.0, y) or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.6, 2.4), rng.randf_range(0.4, 1.5), rng.randf_range(0.6, 2.4))
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


## Tufts of dry grass and frost-white heather poking through the snow.
func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var grass: Array[Transform3D] = []
	var heather: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 9000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.15:
			heather.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), at + Vector3.UP * 0.15))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.14, 0.34, 4), Color(0.6, 0.58, 0.44), grass)
	add_clutter(clutter, Props.blob(0.16, 5, 3), Color(0.7, 0.66, 0.78), heather)
