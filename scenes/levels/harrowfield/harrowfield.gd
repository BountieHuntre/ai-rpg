class_name Harrowfield
extends Zone
## Farmland south of Ashford Vale over the mountain pass, for levels 6 to 12
## (Grunmaw, an elite gnoll, is 11). The village of Wexford stands where the
## pass road comes down, with the Coombe farm and its pumpkin patch to the
## west, the Old Delve mine in the northwest hills, the Mirrow Mere to the
## east with fish-men on its shores, a brigand-held farmstead in the
## southwest, and gnolls in the hills south of the stream. Built in code from
## the layout below, in world coordinates, like Ashford Vale. -Z is north.

const ZONE_NAME := "Harrowfield"
const CENTER := Vector2(0, 400)
const SIZE := 400.0
const STEP := 2.0
const WATER_LEVEL := 1.4
const STREAM_BED := 0.2
const STREAM_WIDTH := 4.0
const ROAD_WIDTH := 2.6
const SEED := 2203

const VILLAGE := Vector2(0, 340)
const VILLAGE_HEIGHT := 5.0
const VILLAGE_FLAT := 30.0
## Wexford's churchyard, where the dead of Harrowfield come back.
const GRAVEYARD := Vector3(-18, VILLAGE_HEIGHT, 352)
const GRAVEYARD_FACING := -PI / 2

## Named places, for what playerbots say: [name, center, radius], smallest
## first, so a point is in the first place that holds it.
const PLACES := [
	["the south watch", Vector2(8, 452), 10.0],
	["the pumpkin patch", Vector2(-75, 388), 14.0],
	["the Coombe farm", Vector2(-70, 348), 18.0],
	["Grunmaw's camp", Vector2(-70, 525), 18.0],
	["the Old Delve", Vector2(-115, 295), 22.0],
	["the brigand farmstead", Vector2(-115, 415), 22.0],
	["Wexford", Vector2(0, 340), 30.0],
	["the pass", Vector2(-24, 250), 30.0],
	["the west meadow", Vector2(-35, 420), 30.0],
	["the Mirrow Mere", Vector2(95, 395), 40.0],
	["the northeast woods", Vector2(100, 300), 40.0],
	["the gnoll hills", Vector2(0, 515), 40.0],
	["the southeast woods", Vector2(100, 495), 45.0],
]

## Level areas flattened for buildings and camps: [center, radius, height].
const FLATS := [
	[Vector2(-70, 348), 16.0, 5.0],   # Coombe farm
	[Vector2(-75, 388), 12.0, 4.6],   # pumpkin patch
	[Vector2(-115, 295), 14.0, 8.0],  # the Old Delve
	[Vector2(-115, 415), 15.0, 5.0],  # brigand farmstead
	[Vector2(-70, 525), 13.0, 7.0],   # Grunmaw's camp
	[Vector2(8, 452), 6.0, 4.0],      # south watch
	[Vector2(45, 400), 5.0, 4.0],     # watchman's hut
	[Vector2(42, 366), 8.0, 5.0],     # Wainwright cottage
]
## Rounded hills: [center, radius, height].
const HILLS := [
	[Vector2(-150, 292), 50.0, 28.0],  # the Old Delve's hill
	[Vector2(0, 525), 45.0, 8.0],      # gnoll hills
	[Vector2(150, 480), 40.0, 10.0],
	[Vector2(130, 280), 35.0, 7.0],
]
const LAKE := Vector2(95, 395)
const LAKE_RADIUS := 28.0
const LAKE_BED := -0.6
const STREAM := [
	Vector2(95, 420), Vector2(70, 455), Vector2(20, 470), Vector2(-40, 466),
	Vector2(-100, 480), Vector2(-210, 500),
]
const ROADS := [
	[Vector2(-8, 290), Vector2(0, 318)],
	[Vector2(-20, 338), Vector2(-55, 345), Vector2(-90, 322), Vector2(-112, 300)],
	[Vector2(-58, 350), Vector2(-72, 378)],
	[Vector2(0, 362), Vector2(2, 420), Vector2(5, 458), Vector2(5, 480), Vector2(-10, 505)],
	[Vector2(22, 345), Vector2(42, 372), Vector2(45, 398)],
]
## Woods: [center, radius]. Trees thin out toward the edges.
const WOODS := [
	[Vector2(100, 300), 40.0],
	[Vector2(100, 495), 45.0],
	[Vector2(-60, 268), 25.0],
	[Vector2(-150, 470), 30.0],
]
## Where the south road crosses the stream.
const BRIDGE_X := 5.0
const BRIDGE_START := 460.0
const BRIDGE_END := 478.0
const BRIDGE_RAMP := 8.0

## Creature spawns: [creature entry, center, radius, count]. New groups go
## last, so saved corpses keep their names.
const SPAWNS := [
	[525, Vector2(40, 282), 20.0, 6],     # Mangy Wolf, north of the mere road (5-6)
	[30, Vector2(-60, 270), 16.0, 5],     # Forest Spider, the pass woods (5-6)
	[285, Vector2(72, 380), 12.0, 6],     # Mirefin, the mere's west shore (6-7)
	[735, Vector2(110, 368), 12.0, 5],    # Mirefin Wader, its north shore (6-7)
	[524, Vector2(-38, 422), 26.0, 8],    # Flintback Boar, west meadow (7-8)
	[524, Vector2(40, 425), 16.0, 4],
	[390, Vector2(-75, 390), 8.0, 2],     # Fattened Hog, the pumpkin patch (7)
	[330, Vector2(-77, 386), 1.0, 1],     # Old Duchess (9)
	[1922, Vector2(100, 300), 30.0, 8],   # Gray Forest Wolf, northeast woods (7-8)
	[40, Vector2(-108, 300), 11.0, 5],    # Burrowling Pickman, the Old Delve (6-7)
	[476, Vector2(-121, 290), 6.0, 3],    # Burrowling Firecaller (7-8)
	[43, Vector2(-124, 302), 7.0, 4],     # Mine Spider (8-9)
	[327, Vector2(-127, 295), 1.0, 1],    # Brasstooth (8)
	[116, Vector2(-110, 412), 14.0, 7],   # Brigand Cutthroat, the farmstead (8-9)
	[474, Vector2(-122, 422), 9.0, 4],    # Brigand Hedge-Mage (9-10)
	[822, Vector2(80, 512), 20.0, 5],     # Young Forest Bear, southeast woods (8-9)
	[118, Vector2(112, 482), 28.0, 8],    # Prowler (9-10)
	[732, Vector2(-50, 472), 14.0, 5],    # Mirefin Lurker, down the stream (9-10)
	[46, Vector2(55, 462), 12.0, 5],      # Mirefin Forager (9-10)
	[97, Vector2(-20, 512), 18.0, 7],     # Ditchjaw Runt, gnoll hills (8-9)
	[478, Vector2(32, 520), 15.0, 5],     # Ditchjaw Outrider (9-10)
	[117, Vector2(-68, 523), 11.0, 5],    # Ditchjaw Brute, Grunmaw's camp (11-12)
	[448, Vector2(-72, 528), 1.0, 1],     # Grunmaw (11, elite)
]

const GRASS := Color(0.42, 0.58, 0.26)
const FIELD := Color(0.62, 0.58, 0.3)
const FOREST_FLOOR := Color(0.26, 0.4, 0.19)
const ROCK := Color(0.47, 0.45, 0.42)
const DIRT := Color(0.55, 0.42, 0.28)
const MUD := Color(0.42, 0.36, 0.27)
const COBBLE := Color(0.58, 0.55, 0.48)
const STONE := Color(0.66, 0.63, 0.58)
const DARK_STONE := Color(0.45, 0.43, 0.41)
const PLASTER := Color(0.85, 0.8, 0.68)
const THATCH := Color(0.7, 0.58, 0.32)
const ROOF := Color(0.5, 0.25, 0.18)
const WOOD := Color(0.45, 0.31, 0.2)
const DARK_WOOD := Color(0.3, 0.2, 0.13)
const CANVAS := Color(0.62, 0.55, 0.42)
const PUMPKIN := Color(0.85, 0.48, 0.12)

var _detail := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = VILLAGE
	places = PLACES
	spawns = SPAWNS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_village()
	_build_farm()
	_build_cottage()
	_build_mine()
	_build_farmstead()
	_build_gnoll_camp()
	_build_watch_posts()
	_build_bridge()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Harrow", [], WATER_LEVEL)


# Shape of the land.

func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	# Mountains round the edges, squarer than the vale's ring, so the
	# farmland reaches further into the corners.
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	height += mountain_height(x, z, smoothstep(0.78, 1.05, reach / 185.0))
	for hill: Array in HILLS:
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	height = lerpf(VILLAGE_HEIGHT, height, smoothstep(VILLAGE_FLAT, VILLAGE_FLAT + 16.0, point.distance_to(VILLAGE)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	var lake := point.distance_to(LAKE)
	height = minf(height, lerpf(LAKE_BED, height, smoothstep(LAKE_RADIUS - 8.0, LAKE_RADIUS + 6.0, lake)))
	var stream := distance_to_line(point, STREAM)
	height = minf(height, lerpf(STREAM_BED, height, smoothstep(STREAM_WIDTH, STREAM_WIDTH + 7.0, stream)))
	return carve_passes(x, z, height)


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.06
	var color := GRASS.lerp(FOREST_FLOOR, _woods_density(point))
	# Ploughed strips round the farm.
	var field := 1.0 - smoothstep(30.0, 38.0, point.distance_to(Vector2(-70, 360)))
	if field > 0.0 and fposmod(x * 0.25 + z * 0.1, 2.0) < 1.0:
		color = color.lerp(FIELD, field * 0.7)
	color = color.lerp(COBBLE, 1.0 - smoothstep(20.0, 24.0, point.distance_to(VILLAGE)))
	for flat: Array in FLATS:
		color = color.lerp(DIRT, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.6)
	var road := distance_to_pass(point)
	for line: Array in ROADS:
		road = minf(road, distance_to_line(point, line))
	color = color.lerp(DIRT, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, road))
	var water := minf(distance_to_line(point, STREAM) - STREAM_WIDTH, point.distance_to(LAKE) - LAKE_RADIUS)
	color = color.lerp(MUD, 1.0 - smoothstep(1.0, 4.0, water))
	color = color.lerp(ROCK, smoothstep(0.82, 0.68, normal.y))
	color = color.lerp(ROCK, smoothstep(24.0, 34.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _woods_density(point: Vector2) -> float:
	var density := 0.0
	for wood: Array in WOODS:
		density = maxf(density, 1.0 - smoothstep(wood[1] * 0.5, wood[1], point.distance_to(wood[0])))
	return density


# Wexford: an inn, a chapel with its churchyard, cottages and a well round a
# cobbled green.

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Wexford"
	add_child(village)
	var y := VILLAGE_HEIGHT
	# The Harrow Inn, east of the green, two storeys with its door to the west.
	Props.box(village, Vector3(18, y, 330), Vector3(10, 7, 14), PLASTER)
	Props.roof(village, Vector3(18, y + 7, 330), Vector3(11, 4, 15), ROOF)
	Props.box(village, Vector3(12.9, y, 332), Vector3(0.3, 2.6, 1.6), DARK_WOOD, 0.0, false)
	Props.box(village, Vector3(13, y + 2.8, 328), Vector3(0.2, 1, 1.6), DARK_WOOD, 0.0, false)
	for beam in [324.0, 330.0, 336.0]:
		Props.box(village, Vector3(12.9, y, beam), Vector3(0.25, 7, 0.3), DARK_WOOD, 0.0, false)
	# The chapel north of the green, its churchyard to the west.
	Props.box(village, Vector3(-13, y, 318), Vector3(8, 6, 12), STONE)
	Props.roof(village, Vector3(-13, y + 6, 318), Vector3(13, 3, 9), ROOF, PI / 2)
	Props.box(village, Vector3(-13, y, 324.1), Vector3(2.2, 3.4, 0.3), DARK_WOOD, 0.0, false)
	Props.box(village, Vector3(-13, y, 311.5), Vector3(3, 10, 3), STONE)
	Props.roof(village, Vector3(-13, y + 10, 311.5), Vector3(3.6, 2.5, 3.6), ROOF)
	for stone in [Vector2(-22, 346), Vector2(-25, 349), Vector2(-22, 352), Vector2(-25, 355), Vector2(-28, 346), Vector2(-28, 352)]:
		Props.box(village, Vector3(stone.x, y, stone.y), Vector3(0.9, 1.1, 0.25), DARK_STONE, 0.0, false)
	for post in [Vector2(-31, 343), Vector2(-31, 359), Vector2(-19, 343), Vector2(-19, 359)]:
		Props.box(village, Vector3(post.x, y, post.y), Vector3(0.4, 1.2, 0.4), DARK_WOOD, 0.0, false)
	# Cottages round the green.
	for cottage in [[Vector2(-18, 334), 0.0], [Vector2(-12, 368), PI / 2], [Vector2(16, 360), 0.0]]:
		var at: Vector2 = cottage[0]
		Props.box(village, Vector3(at.x, y, at.y), Vector3(7, 4, 6), PLASTER, cottage[1])
		Props.roof(village, Vector3(at.x, y + 4, at.y), Vector3(8, 3, 7), THATCH, cottage[1])
	# The tanner's stall, a well, and the marshal's banner on the green.
	Props.box(village, Vector3(-11, y, 345), Vector3(1.4, 1, 4), WOOD)
	Props.box(village, Vector3(-11.6, y + 3, 345), Vector3(2.2, 0.2, 4.6), CANVAS, 0.0, false)
	for post in [Vector2(-12.3, 343), Vector2(-12.3, 347)]:
		Props.box(village, Vector3(post.x, y, post.y), Vector3(0.25, 3, 0.25), DARK_WOOD, 0.0, false)
	Props.cylinder(village, Vector3(6, y, 348), 1.2, 1.0, DARK_STONE)
	for side in [-1, 1]:
		Props.box(village, Vector3(6 + side * 1.0, y, 348), Vector3(0.2, 2.6, 0.2), DARK_WOOD, 0.0, false)
	Props.roof(village, Vector3(6, y + 2.6, 348), Vector3(2.8, 0.9, 2.2), THATCH)
	Props.box(village, Vector3(-2, y, 348), Vector3(0.25, 5, 0.25), DARK_WOOD, 0.0, false)
	Props.box(village, Vector3(-1.3, y + 3.2, 348), Vector3(1.2, 1.6, 0.1), Color(0.2, 0.3, 0.6), 0.0, false)
	torch(village, Vector3(12.6, y + 2.6, 334.5))
	torch(village, Vector3(-10.5, y + 2.4, 324.5))


# The Coombe farm: a farmhouse, a barn and a fenced pumpkin patch to the south.

func _build_farm() -> void:
	var farm := Node3D.new()
	farm.name = "CoombeFarm"
	add_child(farm)
	var center: Vector2 = FLATS[0][0]
	var y: float = FLATS[0][2]
	Props.box(farm, Vector3(center.x - 4, y, center.y - 6), Vector3(9, 4.5, 7), PLASTER)
	Props.roof(farm, Vector3(center.x - 4, y + 4.5, center.y - 6), Vector3(10, 3.5, 8), THATCH)
	Props.box(farm, Vector3(center.x + 8, y, center.y - 2), Vector3(7, 5, 10), WOOD)
	Props.roof(farm, Vector3(center.x + 8, y + 5, center.y - 2), Vector3(8, 3, 11), DARK_WOOD, PI / 2)
	for bale in [Vector2(3, 5), Vector2(4.5, 5.5), Vector2(3.6, 6.6)]:
		Props.cylinder(farm, Vector3(center.x + bale.x, y, center.y + bale.y), 0.7, 0.9, THATCH, false)
	var patch: Vector2 = FLATS[1][0]
	var patch_y: float = FLATS[1][2]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 5
	for i in 22:
		var at := patch + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		Props.cylinder(farm, Vector3(at.x, patch_y, at.y), rng.randf_range(0.3, 0.55), 0.5, PUMPKIN, false)
	# A low fence round the patch, open toward the farm.
	for side in 4:
		var angle := side * PI / 2
		var along := Vector2(cos(angle), sin(angle))
		var across := Vector2(-along.y, along.x)
		for step in range(-5, 6):
			if side == 3 and absi(step) <= 1:
				continue
			var at := patch + along * 11.0 + across * step * 2.0
			Props.box(farm, Vector3(at.x, patch_y, at.y), Vector3(0.25, 1.0, 0.25), WOOD, 0.0, false)


func _build_cottage() -> void:
	var cottage := Node3D.new()
	cottage.name = "WainwrightCottage"
	add_child(cottage)
	var at: Vector2 = FLATS[7][0]
	var y: float = FLATS[7][2]
	Props.box(cottage, Vector3(at.x + 3, y, at.y - 2), Vector3(6, 4, 6), PLASTER, 0.4)
	Props.roof(cottage, Vector3(at.x + 3, y + 4, at.y - 2), Vector3(7, 3, 7), THATCH, 0.4)
	Props.box(cottage, Vector3(at.x - 3, y, at.y + 3), Vector3(2, 1, 1.2), WOOD)


# The Old Delve: a mine in the northwest hill, which the burrowlings dug into.

func _build_mine() -> void:
	var mine := Node3D.new()
	mine.name = "OldDelve"
	add_child(mine)
	var y: float = FLATS[2][2]
	var x := -129.0
	var z := 295.0
	Props.box(mine, Vector3(x - 3.5, y, z), Vector3(7, 5, 5), Color(0.05, 0.04, 0.04))
	for side in [-1, 1]:
		Props.box(mine, Vector3(x, y, z + side * 2.7), Vector3(0.6, 4.6, 0.6), DARK_WOOD)
	Props.box(mine, Vector3(x, y + 4.6, z), Vector3(0.8, 0.6, 6.2), DARK_WOOD, 0.0, false)
	Props.box(mine, Vector3(-118, y, 288), Vector3(1.6, 1.2, 2.4), WOOD)
	for pile in [Vector2(-121, 305), Vector2(-106, 290)]:
		Props.cylinder(mine, Vector3(pile.x, y, pile.y), 1.6, 1.4, ROCK, true, 0.3)
	for light in [Vector2(x + 0.4, z - 3.2), Vector2(x + 0.4, z + 3.2)]:
		torch(mine, Vector3(light.x, y + 2.8, light.y))


# The brigands' farmstead: a burned-out house and barn they've taken over.

func _build_farmstead() -> void:
	var farmstead := Node3D.new()
	farmstead.name = "BrigandFarmstead"
	add_child(farmstead)
	var center: Vector2 = FLATS[3][0]
	var y: float = FLATS[3][2]
	var charred := Color(0.22, 0.19, 0.17)
	# The house's walls without a roof.
	Props.box(farmstead, Vector3(center.x - 5, y, center.y - 7), Vector3(9, 3.5, 0.6), charred)
	Props.box(farmstead, Vector3(center.x - 9.2, y, center.y - 4), Vector3(0.6, 2.5, 6), charred)
	Props.box(farmstead, Vector3(center.x - 0.8, y, center.y - 5), Vector3(0.6, 3, 4), charred)
	Props.box(farmstead, Vector3(center.x + 8, y, center.y + 2), Vector3(6, 4, 8), WOOD)
	Props.roof(farmstead, Vector3(center.x + 8, y + 4, center.y + 2), Vector3(7, 2.5, 9), DARK_WOOD, PI / 2)
	Props.roof(farmstead, Vector3(center.x - 3, y, center.y + 7), Vector3(4, 2.6, 3.4), Color(0.45, 0.18, 0.15), 0.3)
	Props.cylinder(farmstead, Vector3(center.x, y, center.y), 1.0, 0.3, DARK_STONE, false)
	torch(farmstead, Vector3(center.x, y + 0.6, center.y), 6.0)
	for crate in [Vector2(4, -4), Vector2(5, -3), Vector2(-5, 3)]:
		Props.box(farmstead, Vector3(center.x + crate.x, y, center.y + crate.y), Vector3(1, 1, 1), WOOD)


func _build_gnoll_camp() -> void:
	var camp := Node3D.new()
	camp.name = "GrunmawCamp"
	add_child(camp)
	var center: Vector2 = FLATS[4][0]
	var y: float = FLATS[4][2]
	for i in 3:
		var angle := TAU * i / 3.0 + 1.0
		var at := center + Vector2(cos(angle), sin(angle)) * 7.0
		Props.roof(camp, Vector3(at.x, y, at.y), Vector3(4, 3, 4), Color(0.5, 0.4, 0.3), -angle)
	Props.cylinder(camp, Vector3(center.x, y, center.y), 1.0, 0.3, DARK_STONE, false)
	torch(camp, Vector3(center.x, y + 0.6, center.y), 6.0)
	for bone in [Vector2(3, 2), Vector2(-2, 4), Vector2(4, -3)]:
		Props.box(camp, Vector3(center.x + bone.x, y, center.y + bone.y), Vector3(1.2, 0.2, 0.2), STONE, bone.x, false)


## The south watch by the bridge and the watchman's hut by the mere.
func _build_watch_posts() -> void:
	var posts := Node3D.new()
	posts.name = "WatchPosts"
	add_child(posts)
	var watch: Vector2 = FLATS[5][0]
	var y: float = FLATS[5][2]
	for corner in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
		Props.box(posts, Vector3(watch.x + 3 + corner.x, y, watch.y - 3 + corner.y), Vector3(0.4, 5, 0.4), DARK_WOOD)
	Props.box(posts, Vector3(watch.x + 3, y + 5, watch.y - 3), Vector3(3.8, 0.3, 3.8), WOOD, 0.0, false)
	Props.roof(posts, Vector3(watch.x + 3, y + 6.2, watch.y - 3), Vector3(4.2, 1.6, 4.2), ROOF)
	torch(posts, Vector3(watch.x + 1, y + 2.4, watch.y - 1))
	var hut: Vector2 = FLATS[6][0]
	var hut_y: float = FLATS[6][2]
	Props.box(posts, Vector3(hut.x - 3, hut_y, hut.y), Vector3(4, 3, 4), WOOD)
	Props.roof(posts, Vector3(hut.x - 3, hut_y + 3, hut.y), Vector3(5, 2, 5), THATCH)


func _build_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "Bridge"
	add_child(bridge)
	var deck := maxf(height_at(BRIDGE_X, BRIDGE_START - 3.0), height_at(BRIDGE_X, BRIDGE_END + 3.0)) + 0.4
	var near := Vector3(BRIDGE_X, deck, BRIDGE_START)
	var far := Vector3(BRIDGE_X, deck, BRIDGE_END)
	var sink := Vector3(0, -0.5, 0)
	plank(bridge, ground_point(BRIDGE_X, BRIDGE_START - BRIDGE_RAMP) + sink, near)
	plank(bridge, near, far)
	plank(bridge, far, ground_point(BRIDGE_X, BRIDGE_END + BRIDGE_RAMP) + sink)
	for side in [-1, 1]:
		Props.box(bridge, Vector3(BRIDGE_X + side * 2.4, deck, (BRIDGE_START + BRIDGE_END) / 2), Vector3(0.25, 1.0, BRIDGE_END - BRIDGE_START), DARK_WOOD)
		for z in [BRIDGE_START, (BRIDGE_START + BRIDGE_END) / 2, BRIDGE_END]:
			Props.box(bridge, Vector3(BRIDGE_X + side * 2.4, STREAM_BED - 1.0, z), Vector3(0.5, deck - STREAM_BED + 2.0, 0.5), DARK_WOOD, 0.0, false)


# Woods and scattered trees, placed by a seeded random walk over the map.

func _random_point(rng: RandomNumberGenerator) -> Vector2:
	var half := SIZE / 2.0 - EDGE_INSET
	return CENTER + Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))


func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	add_child(trees)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pine_trunks: Array[Transform3D] = []
	var pine_lower: Array[Transform3D] = []
	var pine_upper: Array[Transform3D] = []
	var oak_trunks: Array[Transform3D] = []
	var oak_crowns: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.45
	trunk_shape.height = 4.0
	for attempt in 7000:
		var point := _random_point(rng)
		var chance := 0.02 + 0.55 * _woods_density(point)
		var y := height_at(point.x, point.y)
		chance += 0.25 * smoothstep(8.0, 14.0, y) * (1.0 - smoothstep(26.0, 32.0, y))
		if rng.randf() > chance or not _clear_for_tree(point, y):
			continue
		var tree_size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_size), Vector3(point.x, y, point.y))
		if y > 12.0 or rng.randf() < 0.2:
			pine_trunks.append(base * Transform3D(Basis(), Vector3(0, 1.0, 0)))
			pine_lower.append(base * Transform3D(Basis(), Vector3(0, 3.2, 0)))
			pine_upper.append(base * Transform3D(Basis(), Vector3(0, 5.0, 0)))
		else:
			oak_trunks.append(base * Transform3D(Basis(), Vector3(0, 1.4, 0)))
			oak_crowns.append(base * Transform3D(Basis(), Vector3(0, 4.3, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.35
	trunk.height = 2.0
	trunk.radial_segments = 6
	var oak_trunk := trunk.duplicate() as CylinderMesh
	oak_trunk.height = 2.8
	oak_trunk.top_radius = 0.3
	oak_trunk.bottom_radius = 0.45
	Props.scatter(trees, trunk, DARK_WOOD, pine_trunks)
	Props.scatter(trees, Props.cone(1.9, 3.6), Color(0.16, 0.34, 0.2), pine_lower)
	Props.scatter(trees, Props.cone(1.35, 2.8), Color(0.19, 0.39, 0.22), pine_upper)
	Props.scatter(trees, oak_trunk, WOOD, oak_trunks)
	Props.scatter(trees, Props.blob(2.3), Color(0.3, 0.5, 0.2), oak_crowns)


func _clear_for_tree(point: Vector2, y: float) -> bool:
	if y < WATER_LEVEL + 0.6 or y > 34.0:
		return false
	if point.distance_to(VILLAGE) < VILLAGE_FLAT + 4.0 or point.distance_to(LAKE) < LAKE_RADIUS + 4.0:
		return false
	if distance_to_line(point, STREAM) < STREAM_WIDTH + 4.0 or distance_to_pass(point) < PASS_FLOOR + 3.0:
		return false
	if point.distance_to(Vector2(-70, 360)) < 34.0:
		return false
	for line: Array in ROADS:
		if distance_to_line(point, line) < ROAD_WIDTH + 2.5:
			return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return point.distance_to(Vector2(BRIDGE_X, (BRIDGE_START + BRIDGE_END) / 2.0)) > 16.0


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	for attempt in 1500:
		var point := _random_point(rng)
		var y := height_at(point.x, point.y)
		var chance := 0.03 + 0.4 * smoothstep(9.0, 20.0, y)
		if rng.randf() > chance or not _clear_for_tree(point, minf(y, 30.0)):
			continue
		var rock_size := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.4), rng.randf_range(0.6, 2.2))
		placed.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(rock_size), Vector3(point.x, y + rock_size.y * 0.3, point.y)))
		if rock_size.x > 1.2 and rock_size.z > 1.2:
			var collision := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = minf(rock_size.x, rock_size.z) * 0.8
			collision.shape = shape
			collision.position = Vector3(point.x, y, point.y)
			rocks.add_child(collision)
	Props.scatter(rocks, Props.blob(1.0, 6, 3), ROCK, placed)


const CLUTTER_ATTEMPTS := 16000


## Grass tufts and flowers on open ground, as in Ashford Vale.
func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 4
	var grass: Array[Transform3D] = []
	var tall_grass: Array[Transform3D] = []
	var yellow: Array[Transform3D] = []
	var purple: Array[Transform3D] = []
	for attempt in CLUTTER_ATTEMPTS:
		var point := _random_point(rng)
		var y := height_at(point.x, point.y)
		if y > 26.0 or not _clear_for_clutter(point, y):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		var roll := rng.randf()
		if roll < 0.06:
			(yellow if rng.randf() < 0.5 else purple).append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), at + Vector3.UP * 0.25))
		elif roll < 0.4:
			tall_grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(1.2, 1.8), 1)), at + Vector3.UP * 0.2))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.2), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.18, 0.3, 4), Color(0.34, 0.55, 0.22), grass)
	add_clutter(clutter, Props.cone(0.14, 0.4, 4), Color(0.42, 0.58, 0.24), tall_grass)
	add_clutter(clutter, Props.blob(0.09, 5, 3), Color(0.95, 0.82, 0.25), yellow)
	add_clutter(clutter, Props.blob(0.09, 5, 3), Color(0.62, 0.45, 0.8), purple)


## Open ground: not on roads, water, cobbles or camps.
func _clear_for_clutter(point: Vector2, y: float) -> bool:
	if y < WATER_LEVEL + 0.4 or point.distance_to(VILLAGE) < 24.0 or point.distance_to(LAKE) < LAKE_RADIUS:
		return false
	if distance_to_line(point, STREAM) < STREAM_WIDTH + 1.5 or distance_to_pass(point) < ROAD_WIDTH + 0.8:
		return false
	for line: Array in ROADS:
		if distance_to_line(point, line) < ROAD_WIDTH + 0.8:
			return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1]:
			return false
	return true
