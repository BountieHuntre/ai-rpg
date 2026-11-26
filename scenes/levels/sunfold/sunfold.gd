class_name SunfoldCamp
extends Zone
## The Hornkin's starting valley on Kareth, standing in for classic's Camp
## Narache: a 400-yard green hollow for levels 1 to 6, its camp of tipis, a
## longhouse and a great totem in the middle. Tallbirds graze the fields, mountain
## cougars hunt the western hills and battleboars root in the south-west;
## the Briartusk tuskfolk camp in the Thornback Ravine in the south-east under
## Chief Ragetusk. The Wellspring rises north of the camp, where the trail
## climbs the pass to the Tallgrass. Built in code, in world coordinates. -Z is north.

const ZONE_NAME := "Sunfold Camp"
const CENTER := Vector2(-500, 1200)
static var SIZE := 400.0
static var STEP := 2.0
static var WATER_LEVEL := 1.4
static var ROAD_WIDTH := 2.4
static var SEED := 4501

const HUB := Vector2(-490, 1190)
const HUB_HEIGHT := 5.0
static var HUB_FLAT := 32.0
## Where Hornkin wake and the dead of Sunfold come back: by the totem, facing north.
const GRAVEYARD := Vector3(-490, HUB_HEIGHT, 1206)
static var GRAVEYARD_FACING := 0.0
const SPRING := Vector2(-462, 1088)
static var SPRING_RADIUS := 9.0

const PLACES := [
	["the Wellspring", Vector2(-462, 1088), 14.0],
	["Sunfold Camp", Vector2(-490, 1190), 32.0],
	["the Thornback Ravine", Vector2(-400, 1332), 32.0],
	["the pass", Vector2(-510, 1000), 35.0],
	["the boar meadow", Vector2(-590, 1335), 45.0],
	["the cougar hills", Vector2(-630, 1250), 55.0],
	["the east fields", Vector2(-410, 1150), 60.0],
	["the north fields", Vector2(-590, 1100), 50.0],
]
const FLATS := [
	[Vector2(-400, 1332), 18.0, 3.0],  # the Briartusk camp in the ravine
]
static var RAVINE := 0
const HILLS := [
	[Vector2(-640, 1250), 55.0, 14.0],
	[Vector2(-360, 1290), 30.0, 10.0],
	[Vector2(-440, 1370), 30.0, 10.0],
]
const PASS_END := Vector2(-500, 1070)
const ROADS := [
	[Vector2(-490, 1158), Vector2(-480, 1110), PASS_END],
	[Vector2(-480, 1110), Vector2(-466, 1096)],
	[Vector2(-478, 1222), Vector2(-440, 1280), Vector2(-412, 1316)],
]
const SPAWNS := [
	[2955, Vector2(-415, 1145), 55.0, 10],  # Tallbird, the east fields (1-2)
	[2955, Vector2(-590, 1100), 45.0, 8],   # the north fields
	[2961, Vector2(-630, 1250), 50.0, 9],   # Mountain Cougar, the western hills (3-4)
	[2966, Vector2(-590, 1335), 45.0, 9],   # Battleboar, the boar meadow (3-4)
	[2952, Vector2(-410, 1322), 26.0, 8],   # Briartusk Tuskfolk, the ravine (3-4)
	[2953, Vector2(-396, 1336), 18.0, 5],   # Briartusk Mystic (3-4)
	[2954, Vector2(-420, 1342), 22.0, 5],   # Briartusk Warboar (4-5)
	[3229, Vector2(-402, 1330), 1.0, 1],    # "Squealer" Ragetusk (5)
	[8554, Vector2(-386, 1348), 1.0, 1],    # Chief Ragetusk (5)
]
## Water Pitchers at the Wellspring (A Humble Task).
const CHESTS := [
	[2907, Vector2(-458, 1094), 4.0, 3],
]

const ROCK := Color(0.5, 0.42, 0.36)
const HIDE := Color(0.72, 0.6, 0.42)
const DARK_HIDE := Color(0.5, 0.38, 0.26)
const POLE := Color(0.36, 0.26, 0.18)
const PAINT := [Color(0.62, 0.2, 0.15), Color(0.2, 0.35, 0.55), Color(0.85, 0.75, 0.4), Color(0.25, 0.45, 0.3)]

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
	hub_name = "Sunfold Camp"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS
	enclosures = ENCLOSURES


## The plains' painted ground (Zone.build_ground's layers): green-gold
## grass, golden tall grass in patches, dirt for the camps and roads, ochre
## earth (in the cobbles' layer) at the Ochre Stones, tan rock.
const GROUND_TEXTURES := {
	"grass_tex": "plains_grass", "forest_tex": "gold_grass", "cobble_tex": "ochre_dirt", "rock_tex": "tan_rock",
}
## Walled places bots go in and out of by the door (Zone.enclosures): the
## longhouse, its doorway to the camp.
const ENCLOSURES := [
	[-497.0, 1173.0, -483.0, 1179.0, Vector2(-490, 1183), Vector2(-490, 1177)],
]
static var TREE_ATTEMPTS := 1500
static var ROCK_ATTEMPTS := 1000


func _ready() -> void:
	Props.use_texture(ROCK, "tan_rock", 3.0)
	Props.use_texture(POLE, "bark", 2.0)
	Props.use_texture(HIDE, "hide", 2.5)
	Props.use_texture(DARK_HIDE, "hide", 2.5)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
	build_water(WATER_LEVEL, true)
	build_edges()
	_build_camp()
	_build_ravine()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Sunfold", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


## The camp, the flats, the water and the roads stay clear of the edge
## mountains.
func edge_keep_more() -> Array:
	var circles: Array = [[HUB, HUB_FLAT + 16.0], [SPRING, SPRING_RADIUS + 8.0]]
	for flat: Array in FLATS:
		circles.append([flat[0], flat[1] + 14.0])
	return [circles, ROADS]


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	height += mountain_height(x, z, edge_ring(point))
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, ragged_distance(point, HUB, HUB_FLAT, true)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, ragged_distance(point, flat[0], flat[1], true)))
	height = minf(height, lerpf(0.4, height, smoothstep(SPRING_RADIUS, SPRING_RADIUS + 8.0, ragged_distance(point, SPRING, SPRING_RADIUS))))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


## The textured ground's layers (Zone.build_ground, GROUND_TEXTURES): r dirt
## (the camp, the ravine, the roads), b rock (steep and high ground), a
## golden grass in patches.
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var dirt := (1.0 - smoothstep(HUB_FLAT - 10.0, HUB_FLAT - 4.0, ragged_distance(point, HUB, HUB_FLAT, true))) * 0.7
	for flat: Array in FLATS:
		dirt = maxf(dirt, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.8)
	dirt = maxf(dirt, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point)))
	var rock := maxf(smoothstep(0.84, 0.66, normal.y), smoothstep(22.0, 32.0, y))
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var gold := smoothstep(0.0, 0.35, patch)
	return Color(dirt, 0.0, rock, gold)


## The textured ground's tint: a little noise.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 1.0 + _detail.get_noise_2d(x, z) * 0.06
	return Color(shade, shade, shade)


# Sunfold Camp: tipis in a ring round the great totem and the fire, the
# longhouse to the north and a drying rack of hides.

func _build_camp() -> void:
	var camp := Node3D.new()
	camp.name = "Camp"
	add_child(camp)
	var y := HUB_HEIGHT
	for i in 7:
		var angle := TAU * i / 7.0 + 0.5
		var at := HUB + Vector2(cos(angle), sin(angle)) * 20.0
		if at.distance_to(Vector2(-490, 1170)) < 6.0:
			continue
		tipi(camp, at, y, 3.0, HIDE if i % 2 == 0 else DARK_HIDE, POLE, HUB)
	# The longhouse to the north, its doorway to the camp: the chief and the
	# Man-at-Arms trainer keep inside.
	_longhouse(camp, Vector3(HUB.x, y, HUB.y - 14), 14.0, 0.0, 6.0)
	totem(camp, HUB + Vector2(0, 4), y, 8.0, PAINT)
	Props.cylinder(camp, Vector3(HUB.x - 6, y, HUB.y + 6), 1.0, 0.3, ROCK, false)
	torch(camp, Vector3(HUB.x - 6, y + 0.6, HUB.y + 6), 7.0)
	for post in [Vector2(8, 8), Vector2(12, 8)]:
		Props.box(camp, Vector3(HUB.x + post.x, y, HUB.y + post.y), Vector3(0.2, 2.4, 0.2), POLE, 0.0, false)
	Props.box(camp, Vector3(HUB.x + 10, y + 1.6, HUB.y + 8), Vector3(3.6, 1.4, 0.1), HIDE, 0.0, false)


# The Briartusk tuskfolk's camp in the ravine: bramble mounds and bone spikes.

func _build_ravine() -> void:
	var ravine := Node3D.new()
	ravine.name = "Ravine"
	add_child(ravine)
	var flat: Array = FLATS[RAVINE]
	var spikes: Array[Transform3D] = []
	for i in 5:
		var angle := TAU * i / 5.0
		var at: Vector2 = flat[0] + Vector2(cos(angle), sin(angle)) * 11.0
		var mound := MeshInstance3D.new()
		mound.mesh = Props.blob(2.8, 7, 4)
		mound.material_override = Props.material(Color(0.42, 0.34, 0.22))
		mound.scale = Vector3(1, 0.7, 1)
		mound.position = Vector3(at.x, flat[2] + 0.6, at.y)
		ravine.add_child(mound)
		spikes.append(Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(at.x, flat[2] + 2.1, at.y)))
	Props.scatter(ravine, Props.cone(0.25, 1.8, 4), Color(0.9, 0.86, 0.75), spikes)
	torch(ravine, Vector3(flat[0].x, flat[2] + 0.5, flat[0].y), 6.0)


func _clear(point: Vector2) -> bool:
	if ragged_distance(point, HUB, HUB_FLAT, true) < HUB_FLAT + 3.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	if ragged_distance(point, SPRING, SPRING_RADIUS) < SPRING_RADIUS + 6.0:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return true


## Round oaks on the grass and pines on the hills (Nature's, one solid
## each), never on bare rock.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pines := variant_lists(TREE_VARIANTS)
	var oaks := variant_lists(TREE_VARIANTS)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.45
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in TREE_ATTEMPTS:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 28.0 or not _clear(point) or rng.randf() > 0.03 + 0.18 * smoothstep(8.0, 16.0, y) \
				or shows_rock(point, y, _ground_layers):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		(pines if y > 12.0 and rng.randf() < 0.6 else oaks)[rng.randi_range(0, TREE_VARIANTS - 1)].append(base)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	# Added once its shapes are in.
	add_child(trees)
	draw_trees(trees, pines, oaks, SEED)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
	var edge := SIZE / 2.0 - 6.0
	for attempt in ROCK_ATTEMPTS:
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
	draw_rocks(rocks, placed, SEED, false, "tan_rock")


## Tall plains grass and yellow flowers, and bushes, made near the camera
## (Zone.add_nature_clutter).
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 3)


## What grows at a point: tall grass, thickest on the golden patches, yellow
## flowers here and there; none on paths or rock. Called from a worker
## thread: it only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.6 or y > 24.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3 or layers.r > 0.4 or layers.g > 0.4:
		return []
	if rng.randf() > lerpf(0.5, 0.85, layers.a):
		return []
	var at := Vector3(point.x, y - 0.05, point.y)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	if rng.randf() < 0.04:
		return ["flowers_yellow", Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), at)]
	return ["plains_blades", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1) * rng.randf_range(0.8, 1.15)), at)]


## A bush now and then.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.04:
		return []
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.8 or y > 24.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.8, 1.3)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.8, 1.1), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## A Hornkin longhouse you walk into (one solid, Nature's, 14 yards long,
## stretched to `length` and `depth`), its doorway turned by `yaw` (0 faces
## south), with a warm lamp inside.
func _longhouse(parent: Node3D, at: Vector3, length: float, yaw := 0.0, depth := 7.0) -> void:
	place_baked(parent, "longhouse", Transform3D(Basis(Vector3.UP, yaw) * Basis().scaled(Vector3(length / 14.0, 1.0, depth / 7.0)), at))
	# Its lamp, flickering.
	Fire.make(parent, at + Vector3(0, 2.62, 0), 0.0, length * 0.7, 0.9, Color(1.0, 0.75, 0.45))


## Open ground: not on roads, in the camp or the ravine, or by the spring.
func _clear_for_clutter(point: Vector2) -> bool:
	if ragged_distance(point, HUB, HUB_FLAT, true) < HUB_FLAT - 2.0 or _road_distance(point) < ROAD_WIDTH + 0.8:
		return false
	if ragged_distance(point, SPRING, SPRING_RADIUS) < SPRING_RADIUS + 1.0:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
