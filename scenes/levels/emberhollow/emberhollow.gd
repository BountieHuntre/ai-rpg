class_name Emberhollow
extends Zone
## The Horde's starting valley on Kareth, standing in for classic's Valley of
## Trials: a red-rock canyon 400 yards across, for levels 1 to 6. The Proving
## Ground, a palisaded orc hold, stands in the middle with its gate to the
## west, where the road runs to the pass down to the Redsand Coast. Boars root
## in the flats to the west and north, sand scorpions crawl over the Scorpion
## Rocks to the southeast, and the Ember Cult hides in its cave in the
## northeastern hill, its imps and ashstalkers round the mouth, with
## Rustpincer, an old scorpion, on the ridge to its west. Cactus groves
## (Cactus Apples, for the cook) grow round the flats. Built in code from the
## layout below, in world coordinates, like Ashford Vale. -Z is north.

const ZONE_NAME := "Emberhollow"
const CENTER := Vector2(2500, -1700)
const SIZE := 400.0
const STEP := 2.0
## How far in from the edge the canyon walls start, and where they're full
## height (as deep as every zone's, so the ground joins at the borders).
const MOUNTAIN_START := 70.0
const MOUNTAIN_FULL := 6.0
## No water in the canyon.
const WATER_LEVEL := -100.0
const ROAD_WIDTH := 2.6
const SEED := 3101

const HUB := Vector2(2510, -1690)
const HUB_HEIGHT := 6.0
const HUB_FLAT := 32.0
## The Proving Ground's palisade: x 2486..2534, z -1712..-1668, its gate in
## the west wall.
const WALL_MIN := Vector2(2486, -1712)
const WALL_MAX := Vector2(2534, -1668)
const GATE_Z := -1690.0
## Where new Horde characters start and the dead of Emberhollow come back:
## inside the gate, facing out of it (west).
const GRAVEYARD := Vector3(2497, HUB_HEIGHT, -1690)
const GRAVEYARD_FACING := PI / 2
const ENCLOSURES := [
	[2486.0, -1712.0, 2534.0, -1668.0, Vector2(2477, -1690), Vector2(2494, -1690)],
]

## Named places: [name, center, radius], smallest first.
const PLACES := [
	["the peons' camp", Vector2(2462, -1716), 10.0],
	["Tazula's camp", Vector2(2530, -1792), 10.0],
	["the Ember Cult Cave", Vector2(2612, -1797), 16.0],
	["the Proving Ground", Vector2(2510, -1690), 30.0],
	["Rustpincer's ridge", Vector2(2560, -1852), 30.0],
	["the pass", Vector2(2330, -1675), 35.0],
	["the Scorpion Rocks", Vector2(2595, -1610), 50.0],
	["the north flats", Vector2(2420, -1775), 45.0],
	["the cult's hill", Vector2(2610, -1760), 60.0],
	["the west flats", Vector2(2410, -1625), 60.0],
]

## Level areas: [center, radius, height].
const FLATS := [
	[Vector2(2611, -1796), 10.0, 8.0],  # the cave mouth
	[Vector2(2530, -1792), 8.0, 7.0],   # Tazula's camp
	[Vector2(2462, -1716), 8.0, 6.0],   # the peons' camp
]
const CAVE := 0
const CAMP := 1
const PEONS := 2
## Rounded hills: [center, radius, height].
const HILLS := [
	[Vector2(2648, -1805), 55.0, 26.0],  # the cult's hill, the cave in its west face
	[Vector2(2560, -1855), 38.0, 12.0],  # Rustpincer's ridge
	[Vector2(2600, -1600), 30.0, 6.0],   # the Scorpion Rocks
	[Vector2(2640, -1640), 26.0, 9.0],
	[Vector2(2380, -1560), 40.0, 8.0],
]
## The pass west to the Redsand Coast (Zone.PASSES["kareth"]) ends here.
const PASS_END := Vector2(2370, -1690)
const ROADS := [
	# The gate to the pass.
	[Vector2(2477, -1690), Vector2(2440, -1690), PASS_END],
	# North past the peons' camp and the north flats to Tazula's camp, then
	# east to the cave.
	[Vector2(2440, -1690), Vector2(2450, -1740), Vector2(2475, -1785), Vector2(2522, -1792)],
	[Vector2(2538, -1792), Vector2(2580, -1790), Vector2(2601, -1795)],
	# South and east to the Scorpion Rocks.
	[Vector2(2440, -1690), Vector2(2470, -1630), Vector2(2540, -1612), Vector2(2580, -1608)],
]

## Creature spawns: [creature entry, center, radius, count]. New groups go
## last, so saved corpses keep their names.
const SPAWNS := [
	[3098, Vector2(2405, -1625), 45.0, 10],  # Dustback Boar, the west flats (1-2)
	[3098, Vector2(2410, -1770), 35.0, 8],   # the north flats
	[3098, Vector2(2475, -1625), 22.0, 5],
	[3124, Vector2(2592, -1612), 40.0, 10],  # Sand Scorpion, the Scorpion Rocks (3)
	[3124, Vector2(2630, -1660), 22.0, 5],
	[3101, Vector2(2578, -1776), 26.0, 10],  # Ember Imp, before the cave (3-4)
	[3101, Vector2(2632, -1748), 18.0, 5],
	[3102, Vector2(2602, -1732), 20.0, 5],   # Ashstalker, the cult's hill (3-4)
	[3281, Vector2(2560, -1853), 1.0, 1],    # Rustpincer, on his ridge (4)
	[3183, Vector2(2613, -1797), 1.0, 1],    # Vurrok Cinderhand, in the cave mouth (5)
]
## Cactus Apples to pick (Cactus Apple Bake): [object entry, center, radius, count].
const CHESTS := [
	[178087, Vector2(2606, -1793), 1.0, 1],
	[171938, Vector2(2425, -1640), 50.0, 9],
	[171938, Vector2(2465, -1790), 35.0, 6],
]

const SAND := Color(0.74, 0.5, 0.32)
const DRY_GRASS := Color(0.64, 0.56, 0.32)
const OCHRE := Color(0.8, 0.6, 0.36)
const RED_ROCK := Color(0.58, 0.32, 0.22)
const DARK_ROCK := Color(0.42, 0.25, 0.19)
const PACKED_EARTH := Color(0.62, 0.45, 0.3)
const ROAD := Color(0.68, 0.52, 0.36)
const HIDE := Color(0.62, 0.48, 0.32)
const DARK_HIDE := Color(0.42, 0.3, 0.2)
const LOG := Color(0.4, 0.27, 0.17)
const BONE := Color(0.88, 0.84, 0.72)
const CACTUS := Color(0.32, 0.5, 0.26)
const THORN := Color(0.42, 0.38, 0.22)
const BANNER := Color(0.62, 0.12, 0.1)

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
	hub_name = "the Proving Ground"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS
	enclosures = ENCLOSURES


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_edges()
	_build_proving_ground()
	_build_camps()
	_build_cave()
	_build_cacti()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Ember", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


# Shape of the land.

func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	# Canyon walls round the edges, as deep as every zone's at the border.
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	var half := SIZE / 2.0
	height += mountain_height(x, z, smoothstep(half - MOUNTAIN_START, half - MOUNTAIN_FULL, reach))
	for hill: Array in HILLS:
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, _wall_distance(point)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	return carve_passes(x, z, height)


## Distance from the palisade's rectangle (0 inside it), plus its half-depth,
## so the hold's flat follows the walls.
func _wall_distance(point: Vector2) -> float:
	var middle := (WALL_MIN + WALL_MAX) / 2.0
	var half := (WALL_MAX - WALL_MIN) / 2.0
	var outside := Vector2(maxf(absf(point.x - middle.x) - half.x, 0.0), maxf(absf(point.y - middle.y) - half.y, 0.0))
	return outside.length() + half.x


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.07
	var patch := Zone.land_noise().get_noise_2d(x * 2.3, z * 2.3)
	var color := SAND.lerp(DRY_GRASS, smoothstep(0.05, 0.35, patch) * 0.7)
	color = color.lerp(OCHRE, smoothstep(-0.1, -0.4, patch) * 0.6)
	color = color.lerp(PACKED_EARTH, 1.0 - smoothstep(24.0, 30.0, _wall_distance(point)))
	for flat: Array in FLATS:
		color = color.lerp(PACKED_EARTH, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.8)
	color = color.lerp(ROAD, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point)))
	color = color.lerp(RED_ROCK, smoothstep(0.84, 0.66, normal.y))
	color = color.lerp(RED_ROCK, smoothstep(20.0, 30.0, y))
	return Color(color.r + shade, color.g + shade * 0.8, color.b + shade * 0.6)


# The Proving Ground: a palisade of sharpened logs round a yard of round,
# hide-roofed huts, the commander's great hut to the north, a war drum, a
# cook fire and a tent smithy.

func _build_proving_ground() -> void:
	var hold := Node3D.new()
	hold.name = "ProvingGround"
	add_child(hold)
	var y := HUB_HEIGHT
	# The palisade, with the gate gap in the west wall.
	palisade(hold, Vector2(WALL_MIN.x, WALL_MIN.y), Vector2(WALL_MAX.x, WALL_MIN.y), y, LOG)
	palisade(hold, Vector2(WALL_MAX.x, WALL_MIN.y), Vector2(WALL_MAX.x, WALL_MAX.y), y, LOG)
	palisade(hold, Vector2(WALL_MIN.x, WALL_MAX.y), Vector2(WALL_MAX.x, WALL_MAX.y), y, LOG)
	palisade(hold, Vector2(WALL_MIN.x, WALL_MIN.y), Vector2(WALL_MIN.x, GATE_Z - 4.0), y, LOG)
	palisade(hold, Vector2(WALL_MIN.x, GATE_Z + 4.0), Vector2(WALL_MIN.x, WALL_MAX.y), y, LOG)
	# Gate posts with skulls, and a banner over the gap.
	for side in [-1, 1]:
		Props.box(hold, Vector3(WALL_MIN.x, y, GATE_Z + side * 4.5), Vector3(1.2, 7, 1.2), LOG)
		Props.cylinder(hold, Vector3(WALL_MIN.x, y + 7, GATE_Z + side * 4.5), 0.45, 0.6, BONE, false)
	Props.box(hold, Vector3(WALL_MIN.x, y + 6.2, GATE_Z), Vector3(0.6, 0.6, 10), LOG, 0.0, false)
	Props.box(hold, Vector3(WALL_MIN.x - 0.2, y + 4.2, GATE_Z), Vector3(0.1, 2.0, 2.2), BANNER, 0.0, false)
	# The commander's great hut to the north, and smaller huts round the yard.
	round_hut(hold, Vector2(2510, -1704), 6.5, y, LOG, HIDE, BONE)
	for hut in [Vector2(2492, -1704), Vector2(2528, -1704), Vector2(2528, -1676), Vector2(2492, -1676)]:
		round_hut(hold, hut, 3.6, y, LOG, HIDE, BONE)
	# The war drum in the middle of the yard.
	Props.cylinder(hold, Vector3(2512, y, -1689), 1.3, 1.6, DARK_HIDE)
	Props.cylinder(hold, Vector3(2512, y + 1.6, -1689), 1.35, 0.15, HIDE, false)
	# The cook's fire to the south, with a spit.
	Props.cylinder(hold, Vector3(2506, y, -1678), 1.0, 0.3, DARK_ROCK, false)
	torch(hold, Vector3(2506, y + 0.6, -1678), 6.0)
	for side in [-1, 1]:
		Props.box(hold, Vector3(2506 + side * 1.3, y, -1678), Vector3(0.15, 1.6, 0.15), LOG, 0.0, false)
	Props.box(hold, Vector3(2506, y + 1.5, -1678), Vector3(2.8, 0.12, 0.12), LOG, 0.0, false)
	# The tent smithy against the east wall: a hide roof on posts, a forge and an anvil.
	for post in [Vector2(2524, -1695), Vector2(2531, -1695), Vector2(2524, -1686), Vector2(2531, -1686)]:
		Props.box(hold, Vector3(post.x, y, post.y), Vector3(0.4, 3.6, 0.4), LOG)
	Props.roof(hold, Vector3(2527.5, y + 3.6, -1690.5), Vector3(9, 2, 9), HIDE, PI / 2)
	Props.box(hold, Vector3(2530, y, -1691), Vector3(2.4, 1.8, 2.2), DARK_ROCK)
	Props.box(hold, Vector3(2526, y, -1688), Vector3(1.1, 0.9, 0.6), Color(0.25, 0.25, 0.28))
	# Racks and crates by the trainers.
	for crate in [Vector2(2489, -1696), Vector2(2489.6, -1694.8), Vector2(2531, -1680)]:
		Props.box(hold, Vector3(crate.x, y, crate.y), Vector3(1, 1, 1), LOG)
	torch(hold, Vector3(2488, y + 2.4, -1685))
	torch(hold, Vector3(2532, y + 2.4, -1705))


# The peons' camp outside the wall and Tazula's camp under the ridge.

func _build_camps() -> void:
	var camps := Node3D.new()
	camps.name = "Camps"
	add_child(camps)
	var peons: Array = FLATS[PEONS]
	var y: float = peons[2]
	for log_at in [Vector2(-3, 2), Vector2(-3, 3), Vector2(-2.5, 2.5)]:
		Props.box(camps, Vector3(peons[0].x + log_at.x, y, peons[0].y + log_at.y), Vector3(3.2, 0.5, 0.5), LOG, 0.3)
	Props.roof(camps, Vector3(peons[0].x + 3, y, peons[0].y - 1), Vector3(4, 2.4, 3.4), HIDE, 0.4)
	Props.box(camps, Vector3(peons[0].x, y, peons[0].y - 3), Vector3(1, 1, 1), LOG)
	var camp: Array = FLATS[CAMP]
	y = camp[2]
	Props.roof(camps, Vector3(camp[0].x - 2, y, camp[0].y - 1), Vector3(4, 2.4, 3.4), DARK_HIDE, 1.2)
	Props.cylinder(camps, Vector3(camp[0].x + 1.5, y, camp[0].y + 1), 0.8, 0.3, DARK_ROCK, false)
	torch(camps, Vector3(camp[0].x + 1.5, y + 0.5, camp[0].y + 1), 5.0)


# The Ember Cult's cave: a dark mouth in the west face of the hill, framed
# with bones, with the cult's braziers before it.

func _build_cave() -> void:
	var cave := Node3D.new()
	cave.name = "EmberCultCave"
	add_child(cave)
	var mouth: Array = FLATS[CAVE]
	var y: float = mouth[2]
	var x: float = mouth[0].x + 9.0
	var z: float = mouth[0].y
	Props.box(cave, Vector3(x + 3.5, y, z), Vector3(7, 6, 7), Color(0.04, 0.03, 0.03))
	for side in [-1, 1]:
		Props.box(cave, Vector3(x, y, z + side * 3.4), Vector3(0.7, 5.4, 0.7), BONE)
	Props.box(cave, Vector3(x, y + 5.4, z), Vector3(0.9, 0.7, 7.6), BONE, 0.0, false)
	for brazier in [Vector2(-4, -5), Vector2(-4, 5)]:
		Props.cylinder(cave, Vector3(x + brazier.x, y, z + brazier.y), 0.5, 1.0, DARK_ROCK)
		torch(cave, Vector3(x + brazier.x, y + 1.3, z + brazier.y), 6.0)


# Cacti and thorn bushes, placed by a seeded random walk over the canyon.

func _build_cacti() -> void:
	var plants := StaticBody3D.new()
	plants.name = "Cacti"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var stems: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var stem_shape := CylinderShape3D.new()
	stem_shape.radius = 0.35
	stem_shape.height = 3.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in 2600:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 24.0 or not _clear(point):
			continue
		var grove := _grove_density(point)
		if rng.randf() > 0.04 + 0.4 * grove:
			continue
		var size := rng.randf_range(0.8, 1.4)
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		if rng.randf() < 0.55:
			var base := Transform3D(spin.scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
			stems.append(base * Transform3D(Basis(), Vector3(0, 1.4, 0)))
			for side in [-1, 1]:
				if rng.randf() < 0.7:
					arms.append(base * Transform3D(Basis(Vector3.FORWARD, side * 0.25), Vector3(side * 0.55, 1.6 + rng.randf() * 0.6, 0)))
			var collision := CollisionShape3D.new()
			collision.shape = stem_shape
			collision.position = Vector3(point.x, y + 1.5, point.y)
			plants.add_child(collision)
		else:
			bushes.append(Transform3D(spin.scaled(Vector3(size, size * 0.6, size)), Vector3(point.x, y + 0.3, point.y)))
	var stem := CylinderMesh.new()
	stem.top_radius = 0.28
	stem.bottom_radius = 0.34
	stem.height = 2.8
	stem.radial_segments = 6
	var arm := CylinderMesh.new()
	arm.top_radius = 0.18
	arm.bottom_radius = 0.2
	arm.height = 1.2
	arm.radial_segments = 5
	add_child(plants)
	Props.scatter(plants, stem, CACTUS, stems)
	Props.scatter(plants, arm, CACTUS, arms)
	Props.scatter(plants, Props.blob(0.9, 6, 3), THORN, bushes)


## The cactus groves round the flats, where the apples grow.
func _grove_density(point: Vector2) -> float:
	var density := 0.0
	for group: Array in CHESTS:
		density = maxf(density, 1.0 - smoothstep(group[2] * 0.6, group[2] * 1.2, point.distance_to(group[1])))
	return density


func _clear(point: Vector2) -> bool:
	if _wall_distance(point) < HUB_FLAT + 2.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 1400:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		var rocky := 0.05 + 0.45 * smoothstep(8.0, 18.0, y)
		# The Scorpion Rocks are rocks.
		rocky += 0.4 * (1.0 - smoothstep(30.0, 55.0, point.distance_to(Vector2(2595, -1610))))
		if rng.randf() > rocky or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.7, 2.6), rng.randf_range(0.5, 1.8), rng.randf_range(0.7, 2.6))
		placed.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(size), Vector3(point.x, y + size.y * 0.3, point.y)))
		if size.x > 1.2 and size.z > 1.2:
			var collision := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = minf(size.x, size.z) * 0.8
			collision.shape = shape
			collision.position = Vector3(point.x, y, point.y)
			rocks.add_child(collision)
	add_child(rocks)
	Props.scatter(rocks, Props.blob(1.0, 6, 3), RED_ROCK, placed)


## Dry grass tufts on open ground, only for looks (Zone.add_clutter).
func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var grass: Array[Transform3D] = []
	var pebbles: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 9000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.25:
			pebbles.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.6, 1.2)), at + Vector3.UP * 0.05))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.16, 0.32, 4), Color(0.66, 0.6, 0.34), grass)
	add_clutter(clutter, Props.blob(0.12, 5, 3), DARK_ROCK, pebbles)
