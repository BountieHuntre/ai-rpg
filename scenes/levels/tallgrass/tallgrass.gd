class_name Tallgrass
extends Zone
## The Hornkin's second zone, standing in for classic's Mulgore: rolling
## grassland 1200 yards across, for levels 6 to 12, north of Sunfold Camp over
## the pass. Longhorn Village, the Hornkin's town of tipis and longhouses,
## stands in the middle south; the Seers' wells are to the north, the Ochre
## Stones (an old burial ground the Briartusk dig in) to the east, the
## Goldtooth goblins' derrick in the north-east, the Skyrend harpies' cliffs
## in the west, the Dustmane gnolls at Ashmane Rock in the south-west, and the
## mesas of Windspire in the north-west, where the Hornkin's capital will
## stand. Wolves, cougars, tallbirds and swoops roam everywhere. Built in code,
## in world coordinates. -Z is north.

const ZONE_NAME := "The Tallgrass"
const CENTER := Vector2(-900, 400)
const SIZE := 1200.0
const STEP := 2.5
const MOUNTAIN_START := 56.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const ROAD_WIDTH := 2.6
const SEED := 4701

const TOWN := Vector2(-760, 640)
const TOWN_HEIGHT := 6.0
const TOWN_FLAT := 40.0
const GRAVEYARD := Vector3(-772, TOWN_HEIGHT, 668)
const GRAVEYARD_FACING := 0.0

const PLACES := [
	["the Seers' wells", Vector2(-900, 185), 16.0],
	["the Ochre Stones", Vector2(-430, 270), 24.0],
	["the Goldtooth Derrick", Vector2(-450, -60), 26.0],
	["Ashmane Rock", Vector2(-1300, 820), 26.0],
	["Longhorn Village", Vector2(-760, 640), 42.0],
	["the pass", Vector2(-515, 960), 35.0],
	["the Windspire lifts", Vector2(-1200, -40), 40.0],
	["the Skyrend cliffs", Vector2(-1380, 420), 90.0],
	["the Windspire mesas", Vector2(-1260, -110), 110.0],
	["the eastern plains", Vector2(-550, 450), 160.0],
	["the western plains", Vector2(-1050, 450), 160.0],
]
const FLATS := [
	[Vector2(-900, 185), 12.0, 7.0],    # the Seers' wells
	[Vector2(-430, 270), 20.0, 7.0],    # the Ochre Stones
	[Vector2(-450, -60), 22.0, 6.0],    # the Goldtooth Derrick
	[Vector2(-1300, 820), 18.0, 7.0],   # Ashmane Rock
	[Vector2(-1200, -40), 14.0, 6.0],   # the Windspire lifts
]
const WELLS := 0
const STONES := 1
const DERRICK := 2
const ASHMANE := 3
const LIFTS := 4
const HILLS := [
	[Vector2(-1380, 420), 90.0, 24.0],  # the Skyrend cliffs
	[Vector2(-1310, 860), 40.0, 10.0],
	[Vector2(-600, 150), 70.0, 8.0],
	[Vector2(-1000, 820), 70.0, 7.0],
]
## Mesas: [center, radius, height], flat on top.
const MESAS := [
	[Vector2(-1300, -120), 80.0, 36.0],
	[Vector2(-1130, -150), 50.0, 30.0],
]
const PASS_END := Vector2(-520, 930)
const ROADS := [
	# The pass road up to Longhorn Village.
	[PASS_END, Vector2(-600, 820), Vector2(-728, 666)],
	# North to the Seers' wells, and on to the derrick.
	[Vector2(-770, 600), Vector2(-820, 420), Vector2(-890, 196)],
	[Vector2(-890, 175), Vector2(-700, 80), Vector2(-470, -42)],
	# East to the Ochre Stones, west to Ashmane Rock, north-west to the lifts.
	[Vector2(-720, 630), Vector2(-600, 500), Vector2(-446, 282)],
	[Vector2(-800, 650), Vector2(-1000, 720), Vector2(-1284, 812)],
	[Vector2(-820, 420), Vector2(-1000, 200), Vector2(-1190, -28)],
]
const SPAWNS := [
	[2958, Vector2(-700, 420), 90.0, 10],    # Prairie Wolf (5-6)
	[2959, Vector2(-1000, 300), 100.0, 10],  # Prairie Stalker (7-8)
	[2960, Vector2(-520, 520), 80.0, 8],     # Prairie Wolf Alpha (9-10)
	[2956, Vector2(-900, 720), 100.0, 10],   # Adult Tallbird (6-7)
	[2957, Vector2(-1100, 120), 90.0, 8],    # Elder Tallbird (8-9)
	[3035, Vector2(-640, 200), 90.0, 10],    # Flatland Cougar (7-8)
	[3566, Vector2(-1200, 600), 90.0, 8],    # Flatland Prowler (9-10)
	[2969, Vector2(-1050, 820), 80.0, 8],    # Wiry Swoop (5-6)
	[2970, Vector2(-600, 820), 80.0, 8],     # Swoop (7-8)
	[2971, Vector2(-1200, 250), 70.0, 6],    # Taloned Swoop (8-9)
	[2962, Vector2(-1380, 450), 50.0, 9],    # Skyrend Harpy, the cliffs (7-8)
	[2963, Vector2(-1400, 390), 40.0, 7],    # Skyrend Wind Witch (8-9)
	[2949, Vector2(-1300, 820), 22.0, 8],    # Dustmane Tanner, Ashmane Rock (5-6)
	[2950, Vector2(-1280, 840), 22.0, 8],    # Dustmane Skinner (6-7)
	[2951, Vector2(-1320, 800), 22.0, 6],    # Dustmane Poacher (7-8)
	[5786, Vector2(-1302, 818), 1.0, 1],     # Crookspear (9, rare)
	[3232, Vector2(-430, 270), 22.0, 9],     # Briartusk Interloper, the Ochre Stones (9-10)
	[2978, Vector2(-450, -60), 32.0, 10],    # Goldtooth Worker, the derrick (8-9)
	[2979, Vector2(-440, -70), 22.0, 6],     # Goldtooth Overseer (9-10)
	[3051, Vector2(-452, -64), 1.0, 1],      # Supervisor Fizzwick (12)
	[3068, Vector2(-900, 450), 150.0, 1],    # Thunderstrider (9, rare)
	[3056, Vector2(-800, 100), 100.0, 1],    # Pale Howler (12, rare)
]
## The Well Stones and Amberseed of the Rite of Vision, at the Seers' wells.
const CHESTS := [
	[2910, Vector2(-905, 188), 6.0, 3],
	[2912, Vector2(-880, 240), 30.0, 6],
]

const GRASS := Color(0.42, 0.55, 0.28)
const GOLD_GRASS := Color(0.62, 0.6, 0.32)
const DIRT := Color(0.55, 0.42, 0.28)
const ROCK := Color(0.55, 0.42, 0.34)
const OCHRE := Color(0.72, 0.42, 0.24)
const HIDE := Color(0.72, 0.6, 0.42)
const DARK_HIDE := Color(0.5, 0.38, 0.26)
const POLE := Color(0.36, 0.26, 0.18)
const IRON := Color(0.32, 0.3, 0.3)
const PAINT := [Color(0.62, 0.2, 0.15), Color(0.2, 0.35, 0.55), Color(0.85, 0.75, 0.4), Color(0.25, 0.45, 0.3)]

var _detail := FastNoiseLite.new()
var _road_segments: Array = []


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	for line: Array in ROADS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			_road_segments.append([a, b, Rect2(a, Vector2.ZERO).expand(b)])
	continent = "kareth"
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = TOWN
	hub_name = "Longhorn Village"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_village()
	_build_wells()
	_build_stones()
	_build_derrick()
	_build_ashmane()
	_build_lifts()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Tallgrass", [], WATER_LEVEL)
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
	# Mesas: steep sides up to a flat top.
	for mesa: Array in MESAS:
		height = maxf(height, base_height(x, z) + mesa[2] * (1.0 - smoothstep(mesa[1] * 0.75, mesa[1], point.distance_to(mesa[0]))))
	height = lerpf(TOWN_HEIGHT, height, smoothstep(TOWN_FLAT, TOWN_FLAT + 18.0, point.distance_to(TOWN)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2, limit: float) -> float:
	var best := distance_to_pass(point)
	for segment: Array in _road_segments:
		var box: Rect2 = segment[2]
		if box.grow(limit).has_point(point):
			best = minf(best, distance_to_line(point, [segment[0], segment[1]]))
	return best


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.06
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var color := GRASS.lerp(GOLD_GRASS, smoothstep(0.0, 0.4, patch))
	color = color.lerp(DIRT, 1.0 - smoothstep(TOWN_FLAT - 8.0, TOWN_FLAT - 2.0, point.distance_to(TOWN)))
	var stones: Array = FLATS[STONES]
	color = color.lerp(OCHRE, 1.0 - smoothstep(stones[1] - 2.0, stones[1] + 10.0, point.distance_to(stones[0])))
	for flat: Array in FLATS:
		color = color.lerp(DIRT, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.6)
	color = color.lerp(DIRT, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point, ROAD_WIDTH + 1.0)))
	color = color.lerp(ROCK, smoothstep(0.84, 0.62, normal.y))
	color = color.lerp(ROCK, smoothstep(24.0, 34.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A Hornkin longhouse: hide walls under a long hide roof.
func _longhouse(parent: Node3D, at: Vector3, length: float, yaw := 0.0) -> void:
	Props.box(parent, at, Vector3(length, 3.6, 7), DARK_HIDE, yaw)
	Props.roof(parent, at + Vector3(0, 3.6, 0), Vector3(length + 1.0, 3.2, 8.4), HIDE, yaw)


# Longhorn Village: tipis and longhouses round a great totem, the inn
# longhouse, a well and the graveyard of cairns.

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "LonghornVillage"
	add_child(village)
	var t := TOWN
	var y := TOWN_HEIGHT
	_longhouse(village, _near(t, Vector2(0, -22), y), 18.0)        # the chief's longhouse
	_longhouse(village, _near(t, Vector2(24, -4), y), 14.0, PI / 2)  # the inn
	_longhouse(village, _near(t, Vector2(-24, -4), y), 12.0, PI / 2)
	for i in 6:
		var angle := TAU * i / 6.0 + 0.9
		var at := t + Vector2(cos(angle), sin(angle)) * 30.0
		if angle > PI * 0.35 and angle < PI * 0.65:
			continue
		tipi(village, at, y, 3.2, HIDE if i % 2 == 0 else DARK_HIDE, POLE)
	totem(village, t + Vector2(0, 2), y, 10.0, PAINT)
	Props.cylinder(village, _near(t, Vector2(8, 12), y), 1.2, 1.0, ROCK)
	for side in [-1, 1]:
		Props.box(village, _near(t, Vector2(8 + side * 1.0, 12), y), Vector3(0.2, 2.4, 0.2), POLE, 0.0, false)
	Props.roof(village, _near(t, Vector2(8, 12), y + 2.4), Vector3(2.8, 0.9, 2.2), HIDE)
	for cairn in [Vector2(-16, 26), Vector2(-12, 30), Vector2(-8, 26), Vector2(-16, 32)]:
		Props.cylinder(village, _near(t, cairn, y), 0.7, 0.8, ROCK, false, 0.3)
	for fire in [Vector2(-6, 12), Vector2(12, -12)]:
		torch(village, _near(t, fire, y + 0.6), 7.0)


func _build_wells() -> void:
	var wells := Node3D.new()
	wells.name = "SeersWells"
	add_child(wells)
	var flat: Array = FLATS[WELLS]
	for at in [Vector2(-4, 0), Vector2(5, 3)]:
		Props.cylinder(wells, _near(flat[0], at, flat[2]), 1.4, 0.9, ROCK)
	totem(wells, flat[0] + Vector2(0, -8), flat[2], 6.0, PAINT)
	tipi(wells, flat[0] + Vector2(-7, 7), flat[2], 2.6, HIDE, POLE)


# The Ochre Stones: a ring of red standing stones round an old burial ground.

func _build_stones() -> void:
	var stones := Node3D.new()
	stones.name = "OchreStones"
	add_child(stones)
	var flat: Array = FLATS[STONES]
	for i in 9:
		var angle := TAU * i / 9.0
		var at: Vector2 = flat[0] + Vector2(cos(angle), sin(angle)) * 14.0
		Props.box(stones, Vector3(at.x, flat[2], at.y), Vector3(1.6, 4.5 + (i % 3), 1.2), OCHRE, -angle)
	for grave in [Vector2(-4, 0), Vector2(3, -4), Vector2(2, 5)]:
		Props.box(stones, _near(flat[0], grave, flat[2]), Vector3(2.2, 0.4, 1.0), DARK_HIDE, 0.4, false)


# The Goldtooth goblins' oil derrick: a lattice tower over a tank and pipes.

func _build_derrick() -> void:
	var derrick := Node3D.new()
	derrick.name = "Derrick"
	add_child(derrick)
	var flat: Array = FLATS[DERRICK]
	var d: Vector2 = flat[0]
	var y: float = flat[2]
	for corner in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
		var leg := Props.box(derrick, _near(d, corner, y), Vector3(0.4, 16, 0.4), IRON)
		leg.rotation = Vector3(corner.y * 0.03, 0, -corner.x * 0.03)
	for level in [4.0, 8.0, 12.0]:
		Props.box(derrick, _near(d, Vector2.ZERO, y + level), Vector3(6.4 - level * 0.3, 0.3, 6.4 - level * 0.3), IRON, 0.0, false)
	Props.cylinder(derrick, _near(d, Vector2(10, 4), y), 3.0, 4, Color(0.45, 0.4, 0.3))
	Props.box(derrick, _near(d, Vector2(5, 2), y + 1), Vector3(8, 0.5, 0.5), IRON, 0.3, false)
	for shack in [Vector2(-12, 6), Vector2(-8, -12)]:
		Props.box(derrick, _near(d, shack, y), Vector3(5, 3, 4), Color(0.5, 0.45, 0.35))
		Props.roof(derrick, _near(d, shack, y + 3), Vector3(5.6, 1.4, 4.6), IRON)


func _build_ashmane() -> void:
	var camp := Node3D.new()
	camp.name = "AshmaneRock"
	add_child(camp)
	var flat: Array = FLATS[ASHMANE]
	for i in 4:
		var angle := TAU * i / 4.0 + 0.2
		var at: Vector2 = flat[0] + Vector2(cos(angle), sin(angle)) * 10.0
		Props.roof(camp, Vector3(at.x, flat[2], at.y), Vector3(4.4, 2.6, 3.8), Color(0.45, 0.35, 0.25), -angle)
	torch(camp, _near(flat[0], Vector2.ZERO, flat[2] + 0.5), 6.0)


# The Windspire lifts: a wooden platform and rope at the foot of the mesas,
# where the capital's lifts will run.

func _build_lifts() -> void:
	var lifts := Node3D.new()
	lifts.name = "Lifts"
	add_child(lifts)
	var flat: Array = FLATS[LIFTS]
	var at: Vector2 = flat[0] + Vector2(-6, -10)
	Props.box(lifts, Vector3(at.x, flat[2], at.y), Vector3(5, 0.5, 5), POLE)
	for corner in [Vector2(-2.3, -2.3), Vector2(2.3, -2.3), Vector2(-2.3, 2.3), Vector2(2.3, 2.3)]:
		Props.box(lifts, Vector3(at.x + corner.x, flat[2], at.y + corner.y), Vector3(0.3, 30, 0.3), POLE, 0.0, false)
	totem(lifts, flat[0] + Vector2(6, 4), flat[2], 7.0, PAINT)


func _clear(point: Vector2) -> bool:
	if point.distance_to(TOWN) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.45
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 9000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 30.0 or not _clear(point) or rng.randf() > 0.03 + 0.15 * smoothstep(9.0, 18.0, y):
			continue
		var size := rng.randf_range(0.8, 1.4)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		trunks.append(base * Transform3D(Basis(), Vector3(0, 1.4, 0)))
		crowns.append(base * Transform3D(Basis().scaled(Vector3(1.4, 0.65, 1.4)), Vector3(0, 4.0, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.4
	trunk.height = 2.8
	trunk.radial_segments = 6
	add_child(trees)
	Props.scatter(trees, trunk, POLE, trunks)
	Props.scatter(trees, Props.blob(2.2), Color(0.32, 0.5, 0.24), crowns)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 3000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.03 + 0.4 * smoothstep(10.0, 22.0, y) or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.6, 2.4), rng.randf_range(0.4, 1.6), rng.randf_range(0.6, 2.4))
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


func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var grass: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 40000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.5 or y > 24.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.06:
			flowers.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), at + Vector3.UP * 0.25))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(1.0, 1.9), 1)), at + Vector3.UP * 0.2))
	add_clutter(clutter, Props.cone(0.16, 0.42, 4), Color(0.5, 0.6, 0.3), grass)
	add_clutter(clutter, Props.blob(0.09, 5, 3), Color(0.92, 0.75, 0.3), flowers)
