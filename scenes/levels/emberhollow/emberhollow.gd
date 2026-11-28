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
static var SIZE := 400.0
static var STEP := 2.0
## No water in the canyon.
static var WATER_LEVEL := -100.0
static var ROAD_WIDTH := 2.6
static var SEED := 3101

const HUB := Vector2(2510, -1690)
const HUB_HEIGHT := 6.0
static var HUB_FLAT := 32.0
## The Proving Ground's palisade: x 2486..2534, z -1712..-1668, its gate in
## the west wall.
const WALL_MIN := Vector2(2486, -1712)
const WALL_MAX := Vector2(2534, -1668)
static var GATE_Z := -1690.0
## Where new Horde characters start and the dead of Emberhollow come back:
## inside the gate, facing out of it (west).
const GRAVEYARD := Vector3(2497, HUB_HEIGHT, -1690)
const GRAVEYARD_FACING := PI / 2
var ENCLOSURES: Array = []

## Named places: [name, center, radius], smallest first.
var PLACES: Array = []

## Level areas: [center, radius, height].
var FLATS: Array = []
var CAVE := 0
var CAMP := 1
var PEONS := 2
## Rounded hills: [center, radius, height].
var HILLS: Array = []
## The pass west to the Redsand Coast (Zone.PASSES["kareth"]) ends here.
const PASS_END := Vector2(2370, -1690)
var ROADS: Array = []

## Creature spawns: [creature entry, center, radius, count]. New groups go
## last, so saved corpses keep their names.
var SPAWNS: Array = []
## Cactus Apples to pick (Cactus Apple Bake): [object entry, center, radius, count].
var CHESTS: Array = []

const RED_ROCK := Color(0.58, 0.32, 0.22)
const DARK_ROCK := Color(0.42, 0.25, 0.19)
const HIDE := Color(0.62, 0.48, 0.32)
const DARK_HIDE := Color(0.42, 0.3, 0.2)
const LOG := Color(0.4, 0.27, 0.17)
const BONE := Color(0.88, 0.84, 0.72)
const BANNER := Color(0.62, 0.12, 0.1)

var _detail := FastNoiseLite.new()


func _init() -> void:
	load_layout()
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


## The red land's painted ground (Zone.build_ground's layers): red earth,
## dry scrub in patches, packed red dirt for the roads and yards, red rock.
const GROUND_TEXTURES := {
	"grass_tex": "red_earth", "forest_tex": "dry_scrub", "dirt_tex": "red_dirt", "cobble_tex": "sand", "rock_tex": "red_rock",
}
## The Proving Ground's huts: [middle, radius]; the first is the commander's.
const HUTS := [
	[Vector2(2510, -1704), 6.5], [Vector2(2492, -1704), 3.6], [Vector2(2528, -1704), 3.6],
	[Vector2(2528, -1676), 3.6], [Vector2(2492, -1676), 3.6],
]
static var CACTUS_VARIANTS := 4


## The caves dug into this zone's hills (Zone.cave_mouths).
func cave_mouths() -> Array:
	var mouth: Vector2 = FLATS[CAVE][0]
	# The cult's imps live inside with Vurrok; the ashstalkers keep the hill.
	return [[mouth + Vector2(9.0, 0.0), PI / 2.0, "the Ember Cult Cave", true, [3101]]]

func _ready() -> void:
	Props.use_texture(LOG, "bark", 2.0)
	Props.use_texture(HIDE, "hide", 2.5)
	Props.use_texture(DARK_HIDE, "hide", 2.5)
	Props.use_texture(RED_ROCK, "red_rock", 3.0)
	Props.use_texture(DARK_ROCK, "red_rock", 3.0)
	Props.use_texture(Buildings.FLOOR, "planks", 2.0)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
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

## The camp, the flats and the roads stay clear of the edge
## mountains.
func edge_keep_more() -> Array:
	var circles: Array = [[HUB, HUB_FLAT + 16.0]]
	for flat: Array in FLATS:
		circles.append([flat[0], flat[1] + 14.0])
	return [circles, ROADS]


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	# Canyon walls round the edges, as deep as every zone's at the border.
	height += mountain_height(x, z, edge_ring(point))
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, _wall_distance(point)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, ragged_distance(point, flat[0], flat[1], true)))
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


## The textured ground's layers (Zone.build_ground, GROUND_TEXTURES): r
## packed dirt (the Proving Ground, the camps, the roads), b red rock (steep
## and high ground), a dry scrub in patches.
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var dirt := (1.0 - smoothstep(24.0, 30.0, _wall_distance(point))) * 0.85
	for flat: Array in FLATS:
		dirt = maxf(dirt, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.8)
	dirt = maxf(dirt, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point)))
	var rock := maxf(smoothstep(0.84, 0.66, normal.y), smoothstep(20.0, 30.0, y))
	var patch := Zone.land_noise().get_noise_2d(x * 2.3, z * 2.3)
	var scrub := smoothstep(-0.05, 0.3, patch)
	return Color(dirt, 0.0, rock, scrub)


## The textured ground's tint: a little noise.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 1.0 + _detail.get_noise_2d(x, z) * 0.07
	return Color(shade, shade, shade)


# The Proving Ground: a palisade of sharpened logs round a yard of round,
# hide-roofed huts you walk into (the commander's great hut to the north, the
# trainers' four round the yard, their doors to its middle), a war drum, a
# cook fire and a smithy under a hide roof.

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
	var kit := BuildingKit.new(hold, "Buildings")
	var look := { "wall": LOG, "roof": HIDE, "trim": BONE, "cloth": DARK_HIDE }
	for hut: Array in HUTS:
		var at: Vector2 = hut[0]
		var door := Vector2(0, 1) if hut[1] > 5.0 else (HUB - at).normalized()
		Buildings.round_hut(kit, Vector3(at.x, y, at.y), hut[1], 3.2, look, door)
	# The smithy against the east wall: a hide roof on posts over a forge and
	# an anvil.
	Buildings.shed(kit, Vector3(2527.5, y, -1690.5), Vector3(9, 3.6, 9), PI / 2, LOG, HIDE)
	kit.block(Vector3(2530, y, -1691), Vector3(2.4, 1.8, 2.2), DARK_ROCK, 0.0, true)
	add_forge(Vector3(2530, y, -1691))
	kit.block(Vector3(2530, y + 1.8, -1691), Vector3(1.8, 0.12, 1.6), Color(0.55, 0.2, 0.08))
	kit.block(Vector3(2526, y, -1688), Vector3(0.6, 0.6, 0.45), LOG, 0.0, true)
	kit.block(Vector3(2526, y + 0.6, -1688), Vector3(1.1, 0.3, 0.55), Color(0.25, 0.25, 0.28))
	# The war drum in the middle of the yard.
	kit.cylinder(Vector3(2512, y, -1689), 1.3, 1.6, DARK_HIDE, 12, -1.0, true)
	kit.cylinder(Vector3(2512, y + 1.6, -1689), 1.35, 0.15, HIDE, 12)
	# Racks and crates by the trainers.
	for crate in [Vector2(2489, -1696), Vector2(2489.6, -1694.8), Vector2(2531, -1680)]:
		Buildings.crate(kit, Vector3(crate.x, y, crate.y), 1.0, LOG, DARK_HIDE)
	kit.finish()
	# The cook's fire to the south, with a spit.
	Props.cylinder(hold, Vector3(2506, y, -1678), 1.0, 0.3, DARK_ROCK, false)
	torch(hold, Vector3(2506, y + 0.6, -1678), 6.0)
	for side in [-1, 1]:
		Props.box(hold, Vector3(2506 + side * 1.3, y, -1678), Vector3(0.15, 1.6, 0.15), LOG, 0.0, false)
	Props.box(hold, Vector3(2506, y + 1.5, -1678), Vector3(2.8, 0.12, 0.12), LOG, 0.0, false)
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
	for side in [-1, 1]:
		Props.box(cave, Vector3(x, y, z + side * 3.4), Vector3(0.7, 5.4, 0.7), BONE)
	Props.box(cave, Vector3(x, y + 5.4, z), Vector3(0.9, 0.7, 7.6), BONE, 0.0, false)
	for brazier in [Vector2(-4, -5), Vector2(-4, 5)]:
		Props.cylinder(cave, Vector3(x + brazier.x, y, z + brazier.y), 0.5, 1.0, DARK_ROCK)
		torch(cave, Vector3(x + brazier.x, y + 1.3, z + brazier.y), 6.0)


# Cacti, placed by a seeded random walk over the canyon, thickest in the
# groves; dead bushes come with the clutter.

func _build_cacti() -> void:
	var plants := StaticBody3D.new()
	plants.name = "Cacti"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var placed := variant_lists(CACTUS_VARIANTS)
	var stem_shape := CylinderShape3D.new()
	stem_shape.radius = 0.35
	stem_shape.height = 3.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in 2600:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 24.0 or not _clear(point) or shows_rock(point, y, _ground_layers):
			continue
		if rng.randf() > 0.02 + 0.22 * _grove_density(point):
			continue
		var size := rng.randf_range(0.8, 1.3)
		placed[rng.randi_range(0, CACTUS_VARIANTS - 1)].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y)))
		var collision := CollisionShape3D.new()
		collision.shape = stem_shape
		collision.position = Vector3(point.x, y + 1.5, point.y)
		plants.add_child(collision)
	# Added once its shapes are in.
	add_child(plants)
	for i in CACTUS_VARIANTS:
		Nature.scatter(plants, Nature.cactus_mesh((SEED + i) % Nature.CACTUS_VARIANTS), placed[i])


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
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return true


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
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
		placed[rng.randi_range(0, ROCK_VARIANTS - 1)].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(size), Vector3(point.x, y + size.y * 0.15, point.y)))
		if size.x > 1.2 and size.z > 1.2:
			var collision := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = minf(size.x, size.z) * 0.8
			collision.shape = shape
			collision.position = Vector3(point.x, y, point.y)
			rocks.add_child(collision)
	# Added once its shapes are in.
	add_child(rocks)
	draw_rocks(rocks, placed, SEED, false, "red_rock")


## Dry grass and dead bushes, made near the camera (Zone.add_nature_clutter).
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 3, false, true)


## Dry grass, thick on the scrub and thin on bare earth; none on the roads,
## yards or rock. Called from a worker thread: it only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y > 22.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3 or layers.r > 0.4:
		return []
	if rng.randf() > lerpf(0.03, 0.45, layers.a):
		return []
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return ["dry_grass", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.15)), Vector3(point.x, y - 0.05, point.y))]


## A dead bush now and then, more in the cactus groves.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.04 + 0.1 * _grove_density(point):
		return []
	var y := ground_height(point.x, point.y)
	if y > 22.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.7, 1.2)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.6, 0.85), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## Open ground: not on roads, in the Proving Ground or on the camps.
func _clear_for_clutter(point: Vector2) -> bool:
	if _wall_distance(point) < HUB_FLAT - 2.0 or _road_distance(point) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
