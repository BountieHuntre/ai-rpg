class_name Gravesend
extends Zone
## The Undead's starting valley in Aldmark's grey north, standing in for
## classic's Deathknell: a 400-yard glade of dead trees round the ruined
## Gravesend Chapel, for levels 1 to 6. The risen wake in the chapel yard and
## its graveyard; zombies shamble in the old field to the southeast, the
## Rattlebone skeletons haunt the old crypts to the west, scavengers and
## gloombats roam the glade, Duskweb spiders nest in the Webbed Vault in the
## northern hill, and the Sunward Crusade has pitched a camp in the
## southeast. The road east runs down the pass to Duskmoor Glades. Built in
## code from the layout below, in world coordinates. -Z is north.

const ZONE_NAME := "Gravesend"
const CENTER := Vector2(-2500, -4200)
const SIZE := 400.0
const STEP := 2.0
const MOUNTAIN_START := 64.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := -100.0
const ROAD_WIDTH := 2.4
const SEED := 4101

const HUB := Vector2(-2510, -4205)
const HUB_HEIGHT := 5.0
const HUB_FLAT := 34.0
## The chapel yard's broken wall: x -2542..-2478, z -4237..-4173.
const YARD_MIN := Vector2(-2542, -4237)
const YARD_MAX := Vector2(-2478, -4173)
## Where the Undead rise and the dead of Gravesend come back, facing east.
const GRAVEYARD := Vector3(-2524, HUB_HEIGHT, -4190)
const GRAVEYARD_FACING := -PI / 2

const PLACES := [
	["the old crypts", Vector2(-2618, -4262), 14.0],
	["the Webbed Vault", Vector2(-2562, -4338), 16.0],
	["the Sunward camp", Vector2(-2400, -4082), 20.0],
	["the Gravesend Chapel", Vector2(-2510, -4205), 34.0],
	["the ruined hamlet", Vector2(-2450, -4225), 35.0],
	["the old field", Vector2(-2450, -4140), 40.0],
	["the pass", Vector2(-2330, -4195), 35.0],
	["the north glade", Vector2(-2450, -4310), 60.0],
]
const FLATS := [
	[Vector2(-2618, -4262), 9.0, 7.0],   # the old crypts
	[Vector2(-2562, -4336), 9.0, 8.0],   # the Webbed Vault's mouth
	[Vector2(-2400, -4082), 16.0, 4.0],  # the Sunward camp
]
const CRYPTS := 0
const VAULT := 1
const CAMP := 2
const HILLS := [
	[Vector2(-2585, -4365), 48.0, 24.0],  # the Webbed Vault's hill
	[Vector2(-2640, -4270), 34.0, 12.0],  # the crypts' knoll
	[Vector2(-2370, -4300), 40.0, 9.0],
	[Vector2(-2600, -4110), 40.0, 8.0],
]
const PASS_END := Vector2(-2370, -4200)
const ROADS := [
	[Vector2(-2478, -4205), Vector2(-2420, -4202), PASS_END],
	[Vector2(-2542, -4210), Vector2(-2585, -4240), Vector2(-2610, -4258)],
	[Vector2(-2512, -4237), Vector2(-2530, -4290), Vector2(-2556, -4328)],
	[Vector2(-2500, -4173), Vector2(-2450, -4120), Vector2(-2412, -4090)],
]
const SPAWNS := [
	[1501, Vector2(-2470, -4130), 32.0, 8],  # Mindless Zombie, the old field (1-2)
	[1502, Vector2(-2425, -4150), 28.0, 8],  # Wretched Zombie (1-2)
	[1890, Vector2(-2595, -4248), 26.0, 8],  # Rattlebone Skeleton, the old crypts (2-3)
	[1508, Vector2(-2460, -4290), 40.0, 7],  # Young Scavenger, the north glade (1-2)
	[1509, Vector2(-2570, -4110), 34.0, 6],  # Ragged Scavenger (2-3)
	[1512, Vector2(-2390, -4255), 38.0, 7],  # Gloombat (1-2)
	[1513, Vector2(-2420, -4330), 30.0, 6],  # Mangy Gloombat (3-4)
	[1504, Vector2(-2535, -4318), 24.0, 8],  # Young Duskweb Spider, before the vault (2-3)
	[1505, Vector2(-2566, -4342), 10.0, 6],  # Duskweb Spider, the vault's mouth (3-4)
	[1688, Vector2(-2568, -4344), 1.0, 1],   # Duskweb Matriarch (5)
	[1506, Vector2(-2405, -4085), 18.0, 6],  # Sunward Convert, the Sunward camp (3-4)
	[1507, Vector2(-2396, -4078), 12.0, 5],  # Sunward Initiate (4-5)
	[1667, Vector2(-2400, -4074), 1.0, 1],   # Merrick Vossen (5)
	[1919, Vector2(-2455, -4235), 16.0, 1],  # Samuel Pell, the ruined hamlet (5)
]
## Equipment Boxes in the ruined hamlet (Scavenging Gravesend).
const CHESTS := [
	[164662, Vector2(-2450, -4225), 32.0, 8],
	# Maren's Grave (Maren's Last Wish), among the chapel's graves.
	[178090, Vector2(-2536, -4176), 1.0, 1],
]

const GRASS := Color(0.4, 0.45, 0.33)
const DEAD_GRASS := Color(0.5, 0.47, 0.36)
const SOIL := Color(0.3, 0.27, 0.23)
const PATH := Color(0.47, 0.45, 0.42)
const ROCK := Color(0.42, 0.41, 0.4)
const STONE := Color(0.55, 0.54, 0.52)
const DARK_STONE := Color(0.36, 0.35, 0.35)
const BARK := Color(0.24, 0.2, 0.17)
const ROOF := Color(0.3, 0.27, 0.27)
const WOOD := Color(0.33, 0.25, 0.18)
const TENT := Color(0.85, 0.82, 0.75)
const TENT_RED := Color(0.62, 0.12, 0.1)

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
	hub_name = "the Gravesend Chapel"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_edges()
	_build_chapel()
	_build_crypts()
	_build_vault()
	_build_hamlet()
	_build_camp()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Grave", [], WATER_LEVEL)
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
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, _yard_distance(point)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	return carve_passes(x, z, height)


func _yard_distance(point: Vector2) -> float:
	var middle := (YARD_MIN + YARD_MAX) / 2.0
	var half := (YARD_MAX - YARD_MIN) / 2.0
	var outside := Vector2(maxf(absf(point.x - middle.x) - half.x, 0.0), maxf(absf(point.y - middle.y) - half.y, 0.0))
	return outside.length() + half.x


func _road_distance(point: Vector2) -> float:
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	return road


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.06
	var patch := Zone.land_noise().get_noise_2d(x * 2.1, z * 2.1)
	var color := GRASS.lerp(DEAD_GRASS, smoothstep(0.0, 0.35, patch))
	color = color.lerp(SOIL, 1.0 - smoothstep(26.0, 32.0, _yard_distance(point)))
	for flat: Array in FLATS:
		color = color.lerp(SOIL, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.8)
	color = color.lerp(PATH, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point)))
	color = color.lerp(ROCK, smoothstep(0.84, 0.66, normal.y))
	color = color.lerp(ROCK, smoothstep(20.0, 30.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


## A grave: a headstone, sometimes leaning, on a low mound.
func _grave(parent: Node3D, at: Vector2, y: float, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(-0.2, 0.2)
	var stone := Props.box(parent, Vector3(at.x, y, at.y), Vector3(0.9, 1.1 + rng.randf() * 0.5, 0.25), DARK_STONE if rng.randf() < 0.5 else STONE, yaw, false)
	stone.rotation.x = rng.randf_range(-0.25, 0.15)
	Props.box(parent, Vector3(at.x, y, at.y + 1.0), Vector3(1.0, 0.25, 1.6), SOIL, yaw, false)


# The ruined chapel: a roofless nave of broken walls with a stump of a
# tower, inside a tumbled yard wall, graves all round.

func _build_chapel() -> void:
	var chapel := Node3D.new()
	chapel.name = "Chapel"
	add_child(chapel)
	var y := HUB_HEIGHT
	# The yard wall in broken lengths, gapped east toward the road.
	for wall in [[Vector2(-2542, -4237), Vector2(-2510, -4237)], [Vector2(-2502, -4237), Vector2(-2478, -4237)],
			[Vector2(-2542, -4173), Vector2(-2520, -4173)], [Vector2(-2508, -4173), Vector2(-2478, -4173)],
			[Vector2(-2542, -4237), Vector2(-2542, -4173)], [Vector2(-2478, -4237), Vector2(-2478, -4212)],
			[Vector2(-2478, -4198), Vector2(-2478, -4173)]]:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var length := a.distance_to(b)
		Props.box(chapel, Vector3((a.x + b.x) / 2, y, (a.y + b.y) / 2), Vector3(length, 1.6, 0.9), STONE, -(b - a).angle())
	# The nave: two long walls, a west end and the broken east front.
	Props.box(chapel, Vector3(-2510, y, -4222), Vector3(22, 6, 1.2), STONE)
	Props.box(chapel, Vector3(-2510, y, -4210), Vector3(22, 4, 1.2), STONE)
	Props.box(chapel, Vector3(-2521, y, -4216), Vector3(1.2, 7, 12), STONE)
	Props.box(chapel, Vector3(-2499, y, -4219.5), Vector3(1.2, 5, 4), STONE)
	Props.roof(chapel, Vector3(-2515, y + 6, -4216), Vector3(11, 3, 13), ROOF, PI / 2)
	Props.box(chapel, Vector3(-2524, y, -4226), Vector3(5, 9, 5), DARK_STONE)
	# Graves in the yard.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	for row in 4:
		for col in 6:
			var at := Vector2(-2536 + col * 5.0 + rng.randf_range(-0.8, 0.8), -4200 + row * 6.0)
			if at.distance_to(Vector2(GRAVEYARD.x, GRAVEYARD.z)) > 4.0:
				_grave(chapel, at, y, rng)
	torch(chapel, Vector3(-2499.5, y + 2.4, -4212), 5.0)
	torch(chapel, Vector3(-2479, y + 2.0, -4214), 5.0)


# The old crypts: a stone door in the knoll west of the chapel.

func _build_crypts() -> void:
	var crypts := Node3D.new()
	crypts.name = "Crypts"
	add_child(crypts)
	var flat: Array = FLATS[CRYPTS]
	var at: Vector2 = flat[0]
	var y: float = flat[2]
	Props.box(crypts, Vector3(at.x - 6, y, at.y - 2), Vector3(4, 5, 6), Color(0.05, 0.05, 0.06))
	for side in [-1, 1]:
		Props.box(crypts, Vector3(at.x - 4, y, at.y - 2 + side * 3.4), Vector3(1, 6, 1), DARK_STONE)
	Props.box(crypts, Vector3(at.x - 4, y + 6, at.y - 2), Vector3(1.4, 1, 8), DARK_STONE, 0.0, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 8
	for i in 8:
		_grave(crypts, at + Vector2(rng.randf_range(-2, 10), rng.randf_range(-10, 10)), y, rng)


# The Webbed Vault: a cave mouth in the northern hill, hung with webs.

func _build_vault() -> void:
	var vault := Node3D.new()
	vault.name = "WebbedVault"
	add_child(vault)
	var flat: Array = FLATS[VAULT]
	var at: Vector2 = flat[0] + Vector2(0, -8)
	var y: float = flat[2]
	Props.box(vault, Vector3(at.x, y, at.y), Vector3(8, 6, 5), Color(0.04, 0.04, 0.05))
	var web := Color(0.86, 0.86, 0.84)
	for strand in [[Vector3(-3, 4.5, 2.6), 0.5], [Vector3(2, 3.5, 2.6), -0.6], [Vector3(0, 5.2, 2.6), 0.1]]:
		var box := Props.box(vault, Vector3(at.x, y, at.y) + strand[0], Vector3(4, 0.06, 0.06), web, 0.0, false)
		box.rotation.z = strand[1]


# The ruined hamlet: a few roofless cottages east of the chapel, where the
# equipment boxes lie.

func _build_hamlet() -> void:
	var hamlet := Node3D.new()
	hamlet.name = "Hamlet"
	add_child(hamlet)
	for cottage in [[Vector2(-2450, -4240), 0.2], [Vector2(-2432, -4215), -0.4], [Vector2(-2466, -4210), 1.3]]:
		var at: Vector2 = cottage[0]
		var y := height_at(at.x, at.y)
		var yaw: float = cottage[1]
		for wall in [[Vector2(0, -3), Vector2(7, 0.7)], [Vector2(-3.5, 0), Vector2(0.7, 6)], [Vector2(3.5, 1), Vector2(0.7, 4)]]:
			var offset: Vector2 = (wall[0] as Vector2).rotated(-yaw)
			Props.box(hamlet, Vector3(at.x + offset.x, y - 0.3, at.y + offset.y), Vector3(wall[1].x, 2.6, wall[1].y), STONE, yaw)


# The Sunward Crusade's camp: white and red tents round a fire, with a banner.

func _build_camp() -> void:
	var camp := Node3D.new()
	camp.name = "SunwardCamp"
	add_child(camp)
	var flat: Array = FLATS[CAMP]
	var c: Vector2 = flat[0]
	var y: float = flat[2]
	for i in 4:
		var angle := TAU * i / 4.0 + 0.3
		var at := c + Vector2(cos(angle), sin(angle)) * 9.0
		Props.roof(camp, Vector3(at.x, y, at.y), Vector3(4, 2.8, 3.6), TENT if i % 2 == 0 else TENT_RED, -angle)
	Props.box(camp, Vector3(c.x + 2, y, c.y - 2), Vector3(0.25, 5, 0.25), WOOD, 0.0, false)
	Props.box(camp, Vector3(c.x + 2.7, y + 3.4, c.y - 2), Vector3(1.2, 1.6, 0.1), TENT_RED, 0.0, false)
	Props.cylinder(camp, Vector3(c.x, y, c.y), 0.9, 0.3, DARK_STONE, false)
	torch(camp, Vector3(c.x, y + 0.5, c.y), 6.0)


func _clear(point: Vector2) -> bool:
	if _yard_distance(point) < HUB_FLAT + 2.0 or _road_distance(point) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return point.distance_to(Vector2(-2450, -4225)) > 22.0


# Dead trees (bare trunks with a few crooked limbs) and the odd dark pine.

func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var limbs: Array[Transform3D] = []
	var pines: Array[Transform3D] = []
	var needles: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 8.0
	for attempt in 3000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 26.0 or not _clear(point) or rng.randf() > 0.12 + 0.2 * smoothstep(6.0, 14.0, y):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		if rng.randf() < 0.75:
			trunks.append(base * Transform3D(Basis(), Vector3(0, 2.0, 0)))
			for i in rng.randi_range(2, 3):
				var tilt := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, rng.randf_range(0.6, 1.0))
				limbs.append(base * Transform3D(tilt, Vector3(0, rng.randf_range(2.4, 3.6), 0)) * Transform3D(Basis(), Vector3(0, 0.7, 0)))
		else:
			pines.append(base * Transform3D(Basis(), Vector3(0, 1.0, 0)))
			needles.append(base * Transform3D(Basis(), Vector3(0, 3.4, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.32
	trunk.height = 4.0
	trunk.radial_segments = 6
	var limb := CylinderMesh.new()
	limb.top_radius = 0.05
	limb.bottom_radius = 0.12
	limb.height = 1.6
	limb.radial_segments = 4
	var pine_trunk := trunk.duplicate() as CylinderMesh
	pine_trunk.height = 2.0
	add_child(trees)
	Props.scatter(trees, trunk, BARK, trunks)
	Props.scatter(trees, limb, BARK, limbs)
	Props.scatter(trees, pine_trunk, BARK, pines)
	Props.scatter(trees, Props.cone(1.7, 4.0), Color(0.18, 0.26, 0.2), needles)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 1200:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if rng.randf() > 0.05 + 0.4 * smoothstep(9.0, 20.0, y) or not _clear(point):
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
	var mushrooms: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 4.0
	for attempt in 12000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.05:
			mushrooms.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), at + Vector3.UP * 0.12))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.16, 0.32, 4), Color(0.45, 0.48, 0.34), grass)
	add_clutter(clutter, Props.blob(0.12, 5, 3), Color(0.55, 0.42, 0.55), mushrooms)
