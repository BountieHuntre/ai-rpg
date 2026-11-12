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
const SIZE := 400.0
const STEP := 2.0
const MOUNTAIN_START := 62.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const ROAD_WIDTH := 2.4
const SEED := 4501

const HUB := Vector2(-490, 1190)
const HUB_HEIGHT := 5.0
const HUB_FLAT := 32.0
## Where Hornkin wake and the dead of Sunfold come back: by the totem, facing north.
const GRAVEYARD := Vector3(-490, HUB_HEIGHT, 1206)
const GRAVEYARD_FACING := 0.0
const SPRING := Vector2(-462, 1088)
const SPRING_RADIUS := 9.0

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
const RAVINE := 0
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

const GRASS := Color(0.42, 0.55, 0.28)
const GOLD_GRASS := Color(0.62, 0.6, 0.32)
const DIRT := Color(0.55, 0.42, 0.28)
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


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_camp()
	_build_ravine()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Sunfold", [], WATER_LEVEL)
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
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	height = minf(height, lerpf(0.4, height, smoothstep(SPRING_RADIUS, SPRING_RADIUS + 8.0, point.distance_to(SPRING))))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.06
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var color := GRASS.lerp(GOLD_GRASS, smoothstep(0.0, 0.4, patch))
	color = color.lerp(DIRT, 1.0 - smoothstep(HUB_FLAT - 10.0, HUB_FLAT - 4.0, point.distance_to(HUB)))
	for flat: Array in FLATS:
		color = color.lerp(DIRT, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.8)
	color = color.lerp(DIRT, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point)))
	color = color.lerp(ROCK, smoothstep(0.84, 0.66, normal.y))
	color = color.lerp(ROCK, smoothstep(22.0, 32.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


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
		tipi(camp, at, y, 3.0, HIDE if i % 2 == 0 else DARK_HIDE, POLE)
	Props.box(camp, Vector3(HUB.x, y, HUB.y - 14), Vector3(14, 3.6, 6), DARK_HIDE)
	Props.roof(camp, Vector3(HUB.x, y + 3.6, HUB.y - 14), Vector3(15, 3, 7.5), HIDE)
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
	if point.distance_to(HUB) < HUB_FLAT + 3.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	if point.distance_to(SPRING) < SPRING_RADIUS + 6.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


## A few lone round trees on the grass, thicker on the hills.
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
	var edge := SIZE / 2.0 - 8.0
	for attempt in 1500:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 26.0 or not _clear(point) or rng.randf() > 0.04 + 0.2 * smoothstep(8.0, 16.0, y):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		trunks.append(base * Transform3D(Basis(), Vector3(0, 1.4, 0)))
		crowns.append(base * Transform3D(Basis().scaled(Vector3(1.3, 0.7, 1.3)), Vector3(0, 4.0, 0)))
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
	var edge := SIZE / 2.0 - 4.0
	for attempt in 1000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if rng.randf() > 0.04 + 0.4 * smoothstep(9.0, 20.0, y) or not _clear(point):
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


func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var grass: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 14000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.06:
			flowers.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), at + Vector3.UP * 0.25))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(1.0, 1.8), 1)), at + Vector3.UP * 0.2))
	add_clutter(clutter, Props.cone(0.16, 0.4, 4), Color(0.5, 0.6, 0.3), grass)
	add_clutter(clutter, Props.blob(0.09, 5, 3), Color(0.92, 0.75, 0.3), flowers)
