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

const SOIL := Color(0.3, 0.27, 0.23)
const ROCK := Color(0.42, 0.41, 0.4)
const STONE := Color(0.55, 0.54, 0.52)
const DARK_STONE := Color(0.36, 0.35, 0.35)
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
	enclosures = ENCLOSURES


## The dead land's painted ground (Zone.build_ground's layers): dead grass,
## leaf litter under the trees, dirt for the yard and roads, rock.
const GROUND_TEXTURES := {
	"grass_tex": "dead_grass", "forest_tex": "dead_leaves", "cobble_tex": "mud",
}
## The chapel: its middle and size (x, height, z), its door to the east.
const CHAPEL := Vector2(-2510, -4216)
const CHAPEL_SIZE := Vector3(22, 8, 12.9)
## Walled places bots go in and out of by the gate or door (Zone.enclosures):
## the chapel yard (its gap east toward the road) and the chapel inside it.
const ENCLOSURES := [
	[-2542.0, -4237.0, -2478.0, -4173.0, Vector2(-2470, -4205), Vector2(-2486, -4205)],
	[-2521.0, -4222.5, -2499.0, -4209.5, Vector2(-2494, -4216), Vector2(-2502, -4216)],
]
const DEAD_TREE_VARIANTS := 4


func _ready() -> void:
	Props.use_texture(STONE, "stone_wall", 4.0)
	Props.use_texture(DARK_STONE, "stone_wall", 4.0)
	Props.use_texture(ROOF, "slate", 2.5)
	Props.use_texture(WOOD, "planks", 2.0)
	Props.use_texture(Buildings.FLOOR, "planks", 2.0)
	Props.use_texture(ROCK, "rock", 3.0)
	Props.use_texture(SOIL, "dirt", 2.0)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
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
	height += mountain_height(x, z, edge_ring(point))
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = lerpf(HUB_HEIGHT, height, smoothstep(HUB_FLAT, HUB_FLAT + 16.0, _yard_distance(point)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, ragged_distance(point, flat[0], flat[1], true)))
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


## The textured ground's layers (Zone.build_ground, GROUND_TEXTURES): r dirt
## (the chapel yard, the camps, the roads), b rock (steep and high ground), a
## dead leaves where the dead trees grow thick.
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var dirt := (1.0 - smoothstep(26.0, 32.0, _yard_distance(point))) * 0.6
	for flat: Array in FLATS:
		dirt = maxf(dirt, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.8)
	dirt = maxf(dirt, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point)))
	var rock := maxf(smoothstep(0.84, 0.66, normal.y), smoothstep(20.0, 30.0, y))
	var patch := Zone.land_noise().get_noise_2d(x * 2.1, z * 2.1)
	var leaves := smoothstep(0.1, 0.4, patch)
	return Color(dirt, 0.0, rock, leaves)


## The textured ground's tint: a little noise, greyed.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 0.95 + _detail.get_noise_2d(x, z) * 0.07
	return Color(shade, shade, shade * 1.02)


## A grave: a headstone, sometimes leaning, on a low mound.
func _grave(parent: Node3D, at: Vector2, y: float, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(-0.2, 0.2)
	var stone := Props.box(parent, Vector3(at.x, y, at.y), Vector3(0.9, 1.1 + rng.randf() * 0.5, 0.25), DARK_STONE if rng.randf() < 0.5 else STONE, yaw, false)
	stone.rotation.x = rng.randf_range(-0.25, 0.15)
	Props.box(parent, Vector3(at.x, y, at.y + 1.0), Vector3(1.0, 0.25, 1.6), SOIL, yaw, false)


# The Gravesend Chapel, open inside: a stone nave with pews up to the altar
# at its west end, where the Dark Priest keeps and the trainers stand in the
# side aisles; its broken tower at the west end; a tumbled yard wall round
# it, graves all about.

func _build_chapel() -> void:
	var chapel := Node3D.new()
	chapel.name = "Chapel"
	add_child(chapel)
	var y := HUB_HEIGHT
	var kit := BuildingKit.new(chapel, "Buildings")
	# The yard wall in broken lengths, gapped east toward the road.
	for wall in [[Vector2(-2542, -4237), Vector2(-2510, -4237), 1.6], [Vector2(-2502, -4237), Vector2(-2478, -4237), 1.1],
			[Vector2(-2542, -4173), Vector2(-2520, -4173), 1.4], [Vector2(-2508, -4173), Vector2(-2478, -4173), 1.6],
			[Vector2(-2542, -4237), Vector2(-2542, -4173), 1.6], [Vector2(-2478, -4237), Vector2(-2478, -4212), 1.2],
			[Vector2(-2478, -4198), Vector2(-2478, -4173), 1.6]]:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var middle := (a + b) / 2.0
		kit.block(Vector3(middle.x, y - 0.2, middle.y), Vector3(a.distance_to(b), wall[2] + 0.2, 0.9), STONE, -(b - a).angle(), true)
	var look := { "wall": STONE, "roof": ROOF, "trim": WOOD, "stone": DARK_STONE }
	Buildings.chapel(kit, Vector3(CHAPEL.x, y, CHAPEL.y), CHAPEL_SIZE, 0.0, look, Vector2(1, 0), Vector2(-13.5, 0), 4.0, 14.0, true)
	kit.finish()
	# Graves in the yard.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	for row in 4:
		for col in 6:
			var at := Vector2(-2536 + col * 5.0 + rng.randf_range(-0.8, 0.8), -4200 + row * 6.0)
			if at.distance_to(Vector2(GRAVEYARD.x, GRAVEYARD.z)) > 4.0:
				_grave(chapel, at, y, rng)
	torch(chapel, Vector3(-2497.5, y + 2.4, -4219.5), 5.0)
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


# The ruined hamlet: a few roofless cottages east of the chapel, their
# walls broken to different heights, where the equipment boxes lie.

func _build_hamlet() -> void:
	var hamlet := Node3D.new()
	hamlet.name = "Hamlet"
	add_child(hamlet)
	var kit := BuildingKit.new(hamlet, "Buildings")
	for cottage in [[Vector2(-2450, -4240), 0.2], [Vector2(-2432, -4215), -0.4], [Vector2(-2466, -4210), 1.3]]:
		var at: Vector2 = cottage[0]
		var y := height_at(at.x, at.y)
		var yaw: float = cottage[1]
		for wall in [[Vector2(0, -3), Vector2(7, 0.7), 2.6], [Vector2(-3.5, 0), Vector2(0.7, 6), 1.8], [Vector2(3.5, 1), Vector2(0.7, 4), 2.2],
				[Vector2(-2.2, 3), Vector2(2.6, 0.7), 1.2]]:
			var offset: Vector2 = (wall[0] as Vector2).rotated(-yaw)
			kit.block(Vector3(at.x + offset.x, y - 0.3, at.y + offset.y), Vector3(wall[1].x, wall[2], wall[1].y), STONE, yaw, true)
		# Fallen stones.
		for i in 3:
			var stone: Vector2 = at + Vector2(-2.0 + i * 1.6, 4.4).rotated(-yaw)
			kit.block(Vector3(stone.x, y - 0.1, stone.y), Vector3(0.7, 0.4, 0.5), DARK_STONE, yaw + i)
	kit.finish()


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
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return point.distance_to(Vector2(-2450, -4225)) > 22.0


# Dead trees, bare and crooked, and the odd dark pine, never on bare rock.

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
	var edge := SIZE / 2.0 - 8.0
	for attempt in 3000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y > 26.0 or not _clear(point) or rng.randf() > 0.12 + 0.2 * smoothstep(6.0, 14.0, y) \
				or shows_rock(point, y, _ground_layers):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		if rng.randf() < 0.75:
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
	var edge := SIZE / 2.0 - 4.0
	for attempt in 1200:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if rng.randf() > 0.05 + 0.4 * smoothstep(9.0, 20.0, y) or not _clear(point):
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
## roads, the yard or rock. Called from a worker thread: it only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y > 22.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3 or layers.r > 0.4:
		return []
	if rng.randf() > lerpf(0.6, 0.2, layers.a):
		return []
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return ["dead_blades", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.15)), Vector3(point.x, y - 0.05, point.y))]


## A dead bush now and then.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.06:
		return []
	var y := ground_height(point.x, point.y)
	if y > 22.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.7, 1.2)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.7, 0.9), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## Open ground: not on roads, in the chapel yard or on the camps.
func _clear_for_clutter(point: Vector2) -> bool:
	if _yard_distance(point) < HUB_FLAT - 2.0 or _road_distance(point) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
