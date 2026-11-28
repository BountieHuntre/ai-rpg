class_name DuskmoorGlades
extends Zone
## The Undead's second zone, standing in for classic's Tirisfal Glades: grey
## glades of dead farms 1200 yards across, for levels 6 to 12, east of
## Gravesend over the pass. Gallowfield, the Undead's town, stands where the
## pass road meets the crossroads. North-west are the Ashworth mills and,
## beyond, the family's manor and crypt; Lake Hollowmere lies north of the
## town with Murkfin fish-men on its shores; the Plaguewood farms and their
## pumpkin fields are to the south, the Brannick farm and the Sunward
## mission to the south-west and the Sunward watch by the pass. East are the
## Grimhide gnolls' camp and the east barricade against the plagued lands,
## and in the north-east the Sunward Crusade holds the Zealot Abbey. Built in
## code from the layout below, in world coordinates. -Z is north.

const ZONE_NAME := "Duskmoor Glades"
const CENTER := Vector2(-1700, -4200)
static var SIZE := 1200.0
static var STEP := 2.5
static var WATER_LEVEL := 1.4
static var ROAD_WIDTH := 2.6
static var SEED := 4301

const TOWN := Vector2(-1760, -4180)
const TOWN_HEIGHT := 5.0
static var TOWN_FLAT := 40.0
const GRAVEYARD := Vector3(-1786, TOWN_HEIGHT, -4152)
const GRAVEYARD_FACING := -PI / 2

const LAKE := Vector2(-1650, -4450)
const LAKE_RADIUS := 80.0
static var LAKE_BED := -0.8

var PLACES: Array = []
var FLATS: Array = []
var MILLS := 0
var MANOR := 1
var CRYPT := 2
var ABBEY := 3
var EAST_WATCH := 4
var SUNWARD_WATCH := 5
var MISSION := 6
var BRANNICK := 7
var PLAGUEWOOD := 8
var GNOLL_CAMP := 9
var BARRICADE := 10
var HILLS: Array = []
const PASS_END := Vector2(-2230, -4180)
var ROADS: Array = []
var SPAWNS: Array = []
## Chests: Duskmoor Pumpkins in the Plaguewood fields, Gloom Weed round
## Gallowfield's graveyard and Doom Weed below the abbey's rise.
var CHESTS: Array = []

const ROCK := Color(0.42, 0.41, 0.4)
const STONE := Color(0.55, 0.54, 0.52)
const DARK_STONE := Color(0.36, 0.35, 0.35)
const TIMBER := Color(0.27, 0.21, 0.17)
const PLASTER := Color(0.55, 0.53, 0.5)
const ROOF := Color(0.26, 0.2, 0.28)
const WOOD := Color(0.33, 0.25, 0.18)
const TENT := Color(0.85, 0.82, 0.75)
const TENT_RED := Color(0.62, 0.12, 0.1)
const PUMPKIN := Color(0.82, 0.46, 0.12)

var _detail := FastNoiseLite.new()
var _road_segments: Array = []


func _init() -> void:
	load_layout()
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	for line: Array in ROADS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			_road_segments.append([a, b, Rect2(a, Vector2.ZERO).expand(b)])
	continent = "aldmark"
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = TOWN
	hub_name = "Gallowfield"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS
	enclosures = ENCLOSURES


## The dead land's painted ground (Zone.build_ground's layers), as
## Gravesend's: dead grass, leaf litter, dirt, mud by the lake, rock.
const GROUND_TEXTURES := {
	"grass_tex": "dead_grass", "forest_tex": "dead_leaves", "cobble_tex": "mud",
}
## Gallowfield's buildings, timbered plaster under dark slates, open inside:
## [offset from the town's middle, size, door side, what's inside].
const TOWN_HOUSES := [
	[Vector2(18, -14), Vector3(10, 6, 14), Vector2(-1, 0), "inn"],
	[Vector2(-14, -22), Vector3(9, 5, 7), Vector2(0, 1), "hall"],
	[Vector2(-22, 14), Vector3(7, 4, 7), Vector2(1, 0), "hall"],
	[Vector2(16, 18), Vector3(8, 4, 7), Vector2(-1, 0), "cottage"],
	[Vector2(2, -26), Vector3(8, 5, 6), Vector2(0, 1), "cottage"],
]
## Walled places bots go in and out of by the door (Zone.enclosures): the
## inn and the trainers' two houses.
var ENCLOSURES: Array = []
static var DEAD_TREE_VARIANTS := 4


func _ready() -> void:
	Props.use_texture(STONE, "stone_wall", 4.0)
	Props.use_texture(DARK_STONE, "stone_wall", 4.0)
	Props.use_texture(ROOF, "slate", 2.5)
	Props.use_texture(PLASTER, "plaster", 3.0)
	Props.use_texture(TIMBER, "planks", 2.0)
	Props.use_texture(WOOD, "planks", 2.0)
	Props.use_texture(Buildings.FLOOR, "planks", 2.0)
	Props.use_texture(ROCK, "rock", 3.0)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
	build_water(WATER_LEVEL, true)
	build_edges()
	_build_town()
	_build_mills()
	_build_manor()
	_build_crypt()
	_build_abbey()
	_build_camps()
	_build_farms()
	_build_barricade()
	_build_trees()
	_build_rocks()
	_build_clutter()
	# A forge by the Mining trainer, for Smelting.
	build_forge(self, ground_point(-1761.3, -4151.5), 0.5236, Color(0.32, 0.32, 0.36), Color(0.3, 0.22, 0.16))
	spawn_creatures(SEED + 3, "Dusk", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


## The town, the flats, the water and the roads stay clear of the edge
## mountains.
func edge_keep_more() -> Array:
	var circles: Array = [[TOWN, TOWN_FLAT + 16.0], [LAKE, LAKE_RADIUS + 8.0]]
	for flat: Array in FLATS:
		circles.append([flat[0], flat[1] + 14.0])
	return [circles, ROADS]


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	height += mountain_height(x, z, edge_ring(point))
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = lerpf(TOWN_HEIGHT, height, smoothstep(TOWN_FLAT, TOWN_FLAT + 18.0, ragged_distance(point, TOWN, TOWN_FLAT, true)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, ragged_distance(point, flat[0], flat[1], true)))
	var lake := ragged_distance(point, LAKE, LAKE_RADIUS)
	height = minf(height, lerpf(LAKE_BED, height, smoothstep(LAKE_RADIUS, LAKE_RADIUS + 22.0, lake)))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2, limit: float) -> float:
	var best := distance_to_pass(point)
	for segment: Array in _road_segments:
		var box: Rect2 = segment[2]
		if box.grow(limit).has_point(point):
			best = minf(best, distance_to_line(point, [segment[0], segment[1]]))
	return best


## The textured ground's layers (Zone.build_ground, GROUND_TEXTURES): r dirt
## (Gallowfield, the camps, the roads, the Plaguewood fields), g mud (the
## lake's shore), b rock (steep and high ground), a dead leaves in patches
## and the southeast woods.
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var dirt := (1.0 - smoothstep(TOWN_FLAT - 6.0, TOWN_FLAT, ragged_distance(point, TOWN, TOWN_FLAT, true))) * 0.6
	for flat: Array in FLATS:
		dirt = maxf(dirt, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.7)
	var farms: Array = FLATS[PLAGUEWOOD]
	dirt = maxf(dirt, (1.0 - smoothstep(farms[1] + 20.0, farms[1] + 40.0, point.distance_to(farms[0]))) * 0.9)
	dirt = maxf(dirt, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point, ROAD_WIDTH + 1.5)))
	var mud := 1.0 - smoothstep(2.0, 3.6, y)
	var rock := maxf(smoothstep(0.84, 0.66, normal.y), smoothstep(22.0, 32.0, y))
	var patch := Zone.land_noise().get_noise_2d(x * 2.1, z * 2.1)
	var woods := 1.0 - smoothstep(60.0, 110.0, point.distance_to(Vector2(-1300, -3720)))
	var leaves := maxf(smoothstep(0.1, 0.4, patch), woods)
	return Color(dirt, mud, rock, leaves)


## The textured ground's tint: a little noise, greyed.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 0.95 + _detail.get_noise_2d(x, z) * 0.07
	return Color(shade, shade, shade * 1.02)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## The look of Duskmoor's houses: timbered plaster under dark slates.
const HOUSE_LOOK := { "wall": PLASTER, "roof": ROOF, "trim": TIMBER, "stone": DARK_STONE, "timber": true,
	"shutter": TIMBER, "cloth": Color(0.32, 0.12, 0.3) }


## A timbered house, open inside, its door on `door_side`; returns the room.
func _house(kit: BuildingKit, at: Vector3, size: Vector3, door_side: Vector2, storeys := 1) -> Dictionary:
	return Buildings.house(kit, at, size, 0.0, HOUSE_LOOK, door_side, 0.0, storeys, true, true)


func _grave(parent: Node3D, at: Vector2, y: float, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(-0.2, 0.2)
	var stone := Props.box(parent, Vector3(at.x, y, at.y), Vector3(0.9, 1.1 + rng.randf() * 0.5, 0.25), DARK_STONE, yaw, false)
	stone.rotation.x = rng.randf_range(-0.25, 0.15)


# Gallowfield: timbered houses round a crossroads, open inside: the inn
# with its keeper behind the bar, the trainers' two houses, cottages; the
# graveyard and a gallows on the green.

func _build_town() -> void:
	var town := Node3D.new()
	town.name = "Gallowfield"
	add_child(town)
	var t := TOWN
	var y := TOWN_HEIGHT
	var kit := BuildingKit.new(town, "Buildings")
	for house: Array in TOWN_HOUSES:
		var room := _house(kit, _near(t, house[0], y), house[1], house[2])
		Buildings.furnish(kit, room, house[3], HOUSE_LOOK)
	# The gallows on the green.
	for post in [Vector2(-3, 6), Vector2(3, 6)]:
		kit.block(_near(t, post, y), Vector3(0.4, 4.6, 0.4), TIMBER, 0.0, true)
	kit.block(_near(t, Vector2(0, 6), y + 4.4), Vector3(6.6, 0.4, 0.4), TIMBER)
	kit.block(_near(t, Vector2(0, 6), y + 1.2), Vector3(4, 0.2, 2.4), WOOD, 0.0, true)
	for post in [Vector2(-1.8, 5), Vector2(1.8, 5), Vector2(-1.8, 7), Vector2(1.8, 7)]:
		kit.block(_near(t, post, y), Vector3(0.2, 1.2, 0.2), TIMBER)
	kit.finish()
	# The graveyard west of the green.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	for row in 3:
		for col in 5:
			var at := t + Vector2(-34 + col * 4.0, 18 + row * 5.0)
			if at.distance_to(Vector2(GRAVEYARD.x, GRAVEYARD.z)) > 3.0:
				_grave(town, at, y, rng)
	for lamp in [Vector2(10, -4), Vector2(-10, -4), Vector2(10, 10), Vector2(-10, 10)]:
		Props.box(town, _near(t, lamp, y), Vector3(0.25, 3, 0.25), TIMBER, 0.0, false)
		torch(town, _near(t, lamp, y + 3.2), 6.0)


# The Ashworth mills: a stone mill and a windmill by the stream's ford.

func _build_mills() -> void:
	var mills := Node3D.new()
	mills.name = "Mills"
	add_child(mills)
	var flat: Array = FLATS[MILLS]
	var m: Vector2 = flat[0]
	var y: float = flat[2]
	var kit := BuildingKit.new(mills, "Buildings")
	var mill := _house(kit, _near(m, Vector2(-6, 0), y), Vector3(10, 6, 8), Vector2(0, 1))
	Buildings.furnish(kit, mill, "cottage", HOUSE_LOOK)
	kit.finish()
	Props.cylinder(mills, _near(m, Vector2(10, -6), y), 3.2, 10, STONE, true, 2.4)
	Props.roof(mills, _near(m, Vector2(10, -6), y + 10), Vector3(5, 3, 5), ROOF)
	for blade in 4:
		var sail := Props.box(mills, _near(m, Vector2(10, -2.6), y + 9), Vector3(0.4, 7, 1.2), WOOD, 0.0, false)
		sail.rotation.z = blade * PI / 2 + 0.3
	for crate in [Vector2(-12, 6), Vector2(-11, 7.2), Vector2(2, 8)]:
		Props.box(mills, _near(m, crate, y), Vector3(1, 1, 1), WOOD)


func _build_manor() -> void:
	var manor := Node3D.new()
	manor.name = "Manor"
	add_child(manor)
	var flat: Array = FLATS[MANOR]
	var kit := BuildingKit.new(manor, "Buildings")
	var hall := _house(kit, _near(flat[0], Vector2(0, -4), flat[2]), Vector3(14, 8, 10), Vector2(0, 1), 2)
	Buildings.furnish(kit, hall, "hall", HOUSE_LOOK)
	kit.finish()


func _build_crypt() -> void:
	var crypt := Node3D.new()
	crypt.name = "Crypt"
	add_child(crypt)
	var flat: Array = FLATS[CRYPT]
	var at: Vector2 = flat[0] + Vector2(-2, -6)
	var y: float = flat[2]
	Props.box(crypt, Vector3(at.x, y, at.y), Vector3(8, 5, 6), DARK_STONE)
	Props.box(crypt, Vector3(at.x, y, at.y + 3.05), Vector3(2.4, 3.2, 0.2), Color(0.05, 0.05, 0.06), 0.0, false)
	Props.roof(crypt, Vector3(at.x, y + 5, at.y), Vector3(9, 2.4, 7), DARK_STONE)


# The Zealot Abbey: the Sunward Crusade's walled stone abbey on its rise.

func _build_abbey() -> void:
	var abbey := Node3D.new()
	abbey.name = "ZealotAbbey"
	add_child(abbey)
	var flat: Array = FLATS[ABBEY]
	var a: Vector2 = flat[0]
	var y: float = flat[2]
	var kit := BuildingKit.new(abbey, "Buildings")
	var look := { "wall": STONE, "roof": ROOF, "trim": WOOD, "stone": DARK_STONE }
	Buildings.chapel(kit, _near(a, Vector2(0, -8), y), Vector3(22, 12, 16), 0.0, look, Vector2(0, 1), Vector2(-9, -4), 6.0, 24.0)
	for side in [-1, 1]:
		Buildings.wall(kit, _near(a, Vector2(side * 16, 6), y), Vector3(1.2, 4, 20), STONE, DARK_STONE)
	kit.finish()
	for banner in [Vector2(-3, 0.5), Vector2(3, 0.5)]:
		Props.box(abbey, _near(a, banner, y + 6), Vector3(1.4, 3, 0.1), TENT_RED, 0.0, false)
	torch(abbey, _near(a, Vector2(-2.2, 0.6), y + 2.6))
	torch(abbey, _near(a, Vector2(2.2, 0.6), y + 2.6))


# The Sunward watch, mission and east watch: tents round fires; the Grimhide
# gnolls' hide huts.

func _build_camps() -> void:
	var camps := Node3D.new()
	camps.name = "Camps"
	add_child(camps)
	for index in [SUNWARD_WATCH, MISSION, EAST_WATCH]:
		var flat: Array = FLATS[index]
		var c: Vector2 = flat[0]
		var y: float = flat[2]
		var count := 4 if index != EAST_WATCH else 2
		for i in count:
			var angle := TAU * i / count + 0.4
			var at := c + Vector2(cos(angle), sin(angle)) * (9.0 if index != EAST_WATCH else 6.0)
			Props.roof(camps, Vector3(at.x, y, at.y), Vector3(4, 2.8, 3.6), TENT if i % 2 == 0 else TENT_RED, -angle)
		Props.box(camps, Vector3(c.x + 2, y, c.y - 2), Vector3(0.25, 5, 0.25), WOOD, 0.0, false)
		Props.box(camps, Vector3(c.x + 2.7, y + 3.4, c.y - 2), Vector3(1.2, 1.6, 0.1), TENT_RED, 0.0, false)
		torch(camps, Vector3(c.x, y + 0.5, c.y), 6.0)
	var gnolls: Array = FLATS[GNOLL_CAMP]
	for i in 4:
		var angle := TAU * i / 4.0
		var at: Vector2 = gnolls[0] + Vector2(cos(angle), sin(angle)) * 10.0
		Props.roof(camps, Vector3(at.x, gnolls[2], at.y), Vector3(4.4, 2.6, 3.8), Color(0.4, 0.32, 0.24), -angle)
	torch(camps, _near(gnolls[0], Vector2.ZERO, gnolls[2] + 0.5), 6.0)


# The Plaguewood farms and the Brannick farm: farmhouses, fences and
# pumpkin rows.

func _build_farms() -> void:
	var farms := Node3D.new()
	farms.name = "Farms"
	add_child(farms)
	var plague: Array = FLATS[PLAGUEWOOD]
	var kit := BuildingKit.new(farms, "Buildings")
	for home in [_house(kit, _near(plague[0], Vector2(-14, -10), plague[2]), Vector3(9, 5, 7), Vector2(0, 1)),
			_house(kit, _near(plague[0], Vector2(14, -14), plague[2]), Vector3(10, 4, 7), Vector2(0, 1))]:
		Buildings.furnish(kit, home, "cottage", HOUSE_LOOK)
	var pumpkins: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 9
	for row in 6:
		for col in 10:
			var at: Vector2 = plague[0] + Vector2(-18 + col * 4.0 + rng.randf_range(-1, 1), 4 + row * 3.5)
			pumpkins.append(Transform3D(Basis().scaled(Vector3(1, 0.75, 1) * rng.randf_range(0.7, 1.1)), Vector3(at.x, height_at(at.x, at.y) + 0.25, at.y)))
	Props.scatter(farms, Props.blob(0.45, 7, 4), PUMPKIN, pumpkins)
	var brannick: Array = FLATS[BRANNICK]
	var farmhouse := _house(kit, _near(brannick[0], Vector2(0, -6), brannick[2]), Vector3(10, 5, 8), Vector2(0, 1))
	Buildings.furnish(kit, farmhouse, "cottage", HOUSE_LOOK)
	Buildings.barn(kit, _near(brannick[0], Vector2(12, 4), brannick[2]), Vector3(8, 4, 6), 0.0, WOOD, TIMBER, ROOF, -1.0)
	kit.finish()


# The east barricade: a line of sharpened stakes and carts across the road.

func _build_barricade() -> void:
	var barricade := Node3D.new()
	barricade.name = "Barricade"
	add_child(barricade)
	var flat: Array = FLATS[BARRICADE]
	palisade(barricade, flat[0] + Vector2(-4, -14), flat[0] + Vector2(-4, -3), flat[2], TIMBER, 2.6)
	palisade(barricade, flat[0] + Vector2(-4, 3), flat[0] + Vector2(-4, 14), flat[2], TIMBER, 2.6)
	Props.box(barricade, _near(flat[0], Vector2(0, -6), flat[2]), Vector3(2.2, 1.4, 4), WOOD, 0.3)


func _clear(point: Vector2) -> bool:
	if ragged_distance(point, TOWN, TOWN_FLAT, true) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	if ragged_distance(point, LAKE, LAKE_RADIUS) < LAKE_RADIUS + 8.0:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return true


## Dead trees, bare and crooked, and dark pines, thicker in the southeast
## woods and on the hills, never on bare rock.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var dead := variant_lists(DEAD_TREE_VARIANTS)
	var pines := variant_lists(TREE_VARIANTS)
	var unused := variant_lists(TREE_VARIANTS)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 16000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 28.0 or not _clear(point):
			continue
		var woods := 1.0 - smoothstep(60.0, 110.0, point.distance_to(Vector2(-1300, -3720)))
		if rng.randf() > 0.05 + 0.25 * woods + 0.15 * smoothstep(8.0, 16.0, y) or shows_rock(point, y, _ground_layers):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		if rng.randf() < 0.6:
			dead[rng.randi_range(0, DEAD_TREE_VARIANTS - 1)].append(base)
		else:
			pines[rng.randi_range(0, TREE_VARIANTS - 1)].append(base)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	# Added once its shapes are in.
	add_child(trees)
	draw_trees(trees, pines, unused, SEED)
	for i in DEAD_TREE_VARIANTS:
		Nature.scatter(trees, Nature.dead_tree_mesh(SEED + 70 + i), dead[i])


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
	var edge := SIZE / 2.0 - 6.0
	for attempt in 4000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.04 + 0.4 * smoothstep(9.0, 20.0, y) or not _clear(point):
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
	draw_rocks(rocks, placed, SEED)


## Dead grass and dead bushes, made near the camera (Zone.add_nature_clutter).
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 3, false, true)


## Dead grass, thick on open ground and thin under the trees; none on the
## roads, the fields, the shore or rock. Called from a worker thread: it
## only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.8 or y > 22.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3 or layers.r > 0.4 or layers.g > 0.4:
		return []
	if rng.randf() > lerpf(0.6, 0.2, layers.a):
		return []
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return ["dead_blades", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.15)), Vector3(point.x, y - 0.05, point.y))]


## A dead bush now and then.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.05:
		return []
	var y := ground_height(point.x, point.y)
	if y < 3.6 or y > 22.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.7, 1.2)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.7, 0.9), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## Open ground: not on roads, in Gallowfield or on the camps.
func _clear_for_clutter(point: Vector2) -> bool:
	if ragged_distance(point, TOWN, TOWN_FLAT, true) < TOWN_FLAT - 2.0 or _road_distance(point, ROAD_WIDTH + 1.0) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
