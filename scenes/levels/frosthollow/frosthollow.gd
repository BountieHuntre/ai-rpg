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
static var SIZE := 400.0
static var STEP := 2.0
static var WATER_LEVEL := 0.4
static var ROAD_WIDTH := 2.4
static var SEED := 5101

const HUB := Vector2(-890, -1000)
const HUB_HEIGHT := 6.0
static var HUB_FLAT := 34.0
## Where Dwarves and Gnomes wake and the dead of Frosthollow come back: before
## the hall's doors, facing south.
const GRAVEYARD := Vector3(-890, HUB_HEIGHT, -980)
const GRAVEYARD_FACING := PI

var PLACES: Array = []
var FLATS: Array = []
var TAVIN := 0
var GERRIN := 1
var CAVES := 2
var DIGGINGS := 3
var HILLS: Array = []
const PASS_END := Vector2(-770, -955)
var ROADS: Array = []
var SPAWNS: Array = []
## Fenwick's lost things (A Refugee's Quandary): his box by the troll caves, his
## chest in the diggings, his bucket of bolts on the Frozen Stair.
var CHESTS: Array = []

## Walled places bots go in and out of by the door (Zone.enclosures).
var ENCLOSURES: Array = []

const ROCK := Color(0.46, 0.46, 0.5)
const STONE := Color(0.55, 0.53, 0.5)
const DARK_STONE := Color(0.36, 0.35, 0.36)
const SLATE := Color(0.3, 0.32, 0.38)
const TIMBER := Color(0.4, 0.28, 0.18)
const CANVAS := Color(0.62, 0.55, 0.42)

var _detail := FastNoiseLite.new()


func _init() -> void:
	load_layout()
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
	enclosures = ENCLOSURES


## The snow land's painted ground (Zone.build_ground's layers): snow over
## all, frozen heath where it lies thin, trodden paths, the hall's yard in
## cobbles, frosted rock on steep ground.
const GROUND_TEXTURES := {
	"grass_tex": "snow", "forest_tex": "frozen_heath", "dirt_tex": "frozen_dirt", "rock_tex": "snow_rock",
}


## The caves dug into this zone's hills (Zone.cave_mouths).
func cave_mouths() -> Array:
	return [[(FLATS[CAVES][0] as Vector2) + Vector2(-6.0, -14.0), PI, "the Troll Caves", true],
		[(FLATS[DIGGINGS][0] as Vector2) + Vector2(8.0, -15.0), PI, "the Stonejaw diggings", true]]

func _ready() -> void:
	Props.use_texture(STONE, "stone_wall", 4.0)
	Props.use_texture(DARK_STONE, "stone_wall", 4.0)
	Props.use_texture(SLATE, "slate_snow", 2.5)
	Props.use_texture(TIMBER, "planks", 2.0)
	Props.use_texture(Buildings.FLOOR, "planks", 2.0)
	Props.use_texture(ROCK, "snow_rock", 3.0)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
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


## The camp, the flats and the roads stay clear of the edge
## mountains.
func edge_keep_more() -> Array:
	var circles: Array = [[HUB, HUB_FLAT + 16.0]]
	for flat: Array in FLATS:
		circles.append([flat[0], flat[1] + 14.0])
	return [circles, ROADS]


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	# The snowy uplands sit a little higher, but not under the edge
	# mountains, so at the borders the ground is every zone's.
	var ring := edge_ring(point)
	var height := base_height(x, z) + 1.5 * (1.0 - ring)
	height += mountain_height(x, z, ring)
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, ragged_distance(point, HUB, HUB_FLAT, true)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 12.0, ragged_distance(point, flat[0], flat[1], true)))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


## The textured ground's layers (Zone.build_ground, GROUND_TEXTURES): r the
## trodden paths (the hall's grounds, the camps, the roads), g the hall's
## cobbled yard, b frosted rock (steep ground), a frozen heath (thin snow on
## the lower ground, in patches). High ground is deep snow.
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var path := (1.0 - smoothstep(HUB_FLAT - 12.0, HUB_FLAT - 6.0, ragged_distance(point, HUB, HUB_FLAT, true))) * 0.55
	for flat: Array in FLATS:
		path = maxf(path, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.8)
	path = maxf(path, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point)))
	var yard := 1.0 - smoothstep(9.0, 13.0, point.distance_to(HUB + Vector2(0, -10)))
	var rock := smoothstep(0.8, 0.62, normal.y)
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var heath := smoothstep(-0.05, 0.35, patch) * (1.0 - smoothstep(12.0, 20.0, y))
	return Color(path, yard, rock, heath)


## The textured ground's tint: a little noise.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 1.0 + _detail.get_noise_2d(x, z) * 0.06
	return Color(shade, shade, shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).



# The Hollow Hall: a long stone hall under snowy slates, open inside, its
# great doors facing south onto the yard: a long table and benches, banners
# and a hearth at its east end. Its smithy, a slate roof on posts over a forge
# and anvil, stands by its east end; two stone houses, open inside too, for
# the hall's folk, and braziers about the yard.

func _build_hall() -> void:
	var hall := Node3D.new()
	hall.name = "HollowHall"
	add_child(hall)
	var kit := BuildingKit.new(hall, "Buildings")
	var t := HUB
	var y := HUB_HEIGHT
	var stone := { "wall": STONE, "roof": SLATE, "trim": TIMBER, "stone": DARK_STONE, "shutter": TIMBER,
		"cloth": Color(0.2, 0.3, 0.55) }
	var room := Buildings.house(kit, _near(t, Vector2(0, -26), y), Vector3(30, 7, 12), 0.0, stone, Vector2(0, 1), 0.0, 1, true, true)
	Buildings.furnish(kit, room, "hall", stone)
	# Squat pillars flanking the doors, and stone ends rising over the eaves.
	for side in [-1, 1]:
		kit.block(_near(t, Vector2(side * 2.6, -19.6), y), Vector3(1.4, 6.0, 1.2), DARK_STONE, 0.0, true)
		kit.block(_near(t, Vector2(side * 2.6, -19.6), y + 6.0), Vector3(1.8, 0.5, 1.6), DARK_STONE)
		kit.block(_near(t, Vector2(side * 15.6, -26), y), Vector3(1.6, 9.5, 1.6), DARK_STONE, 0.0, true)
	# The smithy: a slate roof on posts over a forge with its hood and an anvil.
	Buildings.shed(kit, _near(t, Vector2(21, -12), y), Vector3(8, 3.8, 7), 0.0, TIMBER, SLATE)
	kit.block(_near(t, Vector2(22, -14), y), Vector3(3, 1.6, 2.5), DARK_STONE, 0.0, true)
	add_forge(_near(t, Vector2(22, -14), y))
	kit.block(_near(t, Vector2(22, -14), y + 1.6), Vector3(2.2, 0.15, 1.8), Color(0.55, 0.2, 0.08))
	kit.cylinder(_near(t, Vector2(22, -14), y + 2.6), 1.3, 1.6, DARK_STONE, 4, 0.35)
	kit.block(_near(t, Vector2(22, -14), y + 4.2), Vector3(0.7, 2.4, 0.7), DARK_STONE)
	kit.block(_near(t, Vector2(18, -10), y), Vector3(0.6, 0.6, 0.45), TIMBER, 0.0, true)
	kit.block(_near(t, Vector2(18, -10), y + 0.6), Vector3(1.2, 0.3, 0.55), Color(0.25, 0.25, 0.28))
	# Two houses, their doors to the yard.
	for house: Array in [[Vector2(-24, -4), Vector2(1, 0)], [Vector2(26, 8), Vector2(-1, 0)]]:
		var home := Buildings.house(kit, _near(t, house[0], y), Vector3(8, 4, 7), 0.0, stone, house[1], 0.0, 1, true, true)
		Buildings.furnish(kit, home, "cottage", stone)
	# Crates and barrels by the smithy.
	Buildings.crate(kit, _near(t, Vector2(16, -15.5), y), 1.0, TIMBER, DARK_STONE)
	Buildings.crate(kit, _near(t, Vector2(16.2, -15.4), y + 1.0), 0.85, TIMBER, DARK_STONE, 0.4)
	Buildings.barrel(kit, _near(t, Vector2(26, -15), y), 0.45, 1.0, TIMBER)
	kit.finish()
	torch(hall, _near(t, Vector2(22, -12.4), y + 2.0), 6.0)
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
	torch(diggings, _near(flat[0], Vector2(-3, -2), flat[2] + 0.5), 6.0)


func _clear(point: Vector2) -> bool:
	if ragged_distance(point, HUB, HUB_FLAT, true) < HUB_FLAT + 3.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return true


## Snowy pines, thicker up the slopes, on snow and heath but never on bare
## rock.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pines := variant_lists(TREE_VARIANTS)
	var unused := variant_lists(TREE_VARIANTS)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.45
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in 1800:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 30.0 or not _clear(point) or rng.randf() > 0.05 + 0.25 * smoothstep(9.0, 18.0, y) \
				or shows_rock(point, y, _ground_layers):
			continue
		var size := rng.randf_range(0.75, 1.25)
		pines[rng.randi_range(0, TREE_VARIANTS - 1)].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	# Added once its shapes are in: adding shapes to a body in the world
	# rebuilds the body each time.
	add_child(trees)
	draw_trees(trees, pines, unused, SEED, true)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
	var edge := SIZE / 2.0 - 4.0
	for attempt in 1000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if rng.randf() > 0.05 + 0.4 * smoothstep(10.0, 22.0, y) or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.4), rng.randf_range(0.6, 2.2))
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
	draw_rocks(rocks, placed, SEED, true)


## Dry grass and frosted heather poking through the snow, and snowy
## bushes now and then, made near the camera (Zone.add_nature_clutter).
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 3, true)


## What grows at a point: mostly on the heath, thin on open snow, none on
## paths, rock or high ground. Called from a worker thread: it only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y > 22.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3:
		return []
	if rng.randf() > lerpf(0.06, 0.55, layers.a):
		return []
	var at := Vector3(point.x, y - 0.05, point.y)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	if rng.randf() < 0.22:
		return ["heather", Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), at)]
	return ["frost_grass", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.15)), at)]


## A snowy bush now and then.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.05:
		return []
	var y := ground_height(point.x, point.y)
	if y > 22.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.7, 1.3)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.8, 1.1), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## Open ground: not on paths, camps or the hall's grounds.
func _clear_for_clutter(point: Vector2) -> bool:
	if ragged_distance(point, HUB, HUB_FLAT, true) < HUB_FLAT - 4.0 or _road_distance(point) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
