class_name Harrowfield
extends Zone
## Farmland south of Ashford Vale over the mountain pass, for levels 6 to 12
## (Grunmaw, an elite gnoll, is 11): a big zone, a thousand yards across, as
## classic's second zones dwarf their starting valleys. The village of Wexford
## stands where the pass road comes down, with the Coombe farm and its pumpkin
## patch to the west and the west garrison at the end of that road; the Old
## Delve mine in the northwest hills and Copperhollow, a second burrowling
## mine, in the northeast hills; the Mirrow Mere to the east with fish-men on
## its shores, Thornwick Tower beyond it and the Ashwood lumber camp in the
## east woods; the Pellow vineyard south of the village; a brigand-held
## farmstead in the southwest; the stream across the south with the south
## watch at its bridge and the Reedford landing downstream; and gnolls in the
## hills south of the stream. Built in code from the layout below, in world
## coordinates, like Ashford Vale. -Z is north.

const ZONE_NAME := "Harrowfield"
const CENTER := Vector2(0, 700)
const SIZE := 1000.0
## Yards between the ground's vertices (Ashford Vale's are 2; this one is big).
const STEP := 2.5
## How far in from the edge the mountains start, and where they're full height.
const MOUNTAIN_START := 56.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const STREAM_BED := 0.2
const STREAM_WIDTH := 4.0
const ROAD_WIDTH := 2.6
const SEED := 2203

const VILLAGE := Vector2(0, 440)
const VILLAGE_HEIGHT := 5.0
const VILLAGE_FLAT := 30.0
## Wexford's churchyard, where the dead of Harrowfield come back.
const GRAVEYARD := Vector3(-18, VILLAGE_HEIGHT, 452)
const GRAVEYARD_FACING := -PI / 2

## Named places, for what playerbots say and the world map: [name, center,
## radius], smallest first, so a point is in the first place that holds it.
const PLACES := [
	["the south watch", Vector2(22, 735), 12.0],
	["the west garrison", Vector2(-420, 520), 14.0],
	["the pumpkin patch", Vector2(-200, 525), 16.0],
	["the Reedford landing", Vector2(-260, 778), 16.0],
	["Thornwick Tower", Vector2(380, 450), 18.0],
	["the mirefin village", Vector2(332, 592), 18.0],
	["the Coombe farm", Vector2(-190, 470), 22.0],
	["Grunmaw's camp", Vector2(-175, 935), 22.0],
	["the Pellow vineyard", Vector2(140, 640), 26.0],
	["the Old Delve", Vector2(-315, 335), 28.0],
	["Copperhollow", Vector2(172, 300), 28.0],
	["the brigand farmstead", Vector2(-300, 690), 28.0],
	["the Ashwood lumber camp", Vector2(380, 700), 30.0],
	["Wexford", Vector2(0, 440), 35.0],
	["the pass", Vector2(-24, 250), 35.0],
	["the Mirrow Mere", Vector2(270, 560), 70.0],
	["the west woods", Vector2(-360, 470), 70.0],
	["the west meadow", Vector2(-110, 620), 75.0],
	["the northeast woods", Vector2(330, 330), 100.0],
	["the southwest woods", Vector2(-380, 900), 100.0],
	["the gnoll hills", Vector2(0, 930), 110.0],
	["the southeast woods", Vector2(300, 880), 120.0],
]

## Level areas flattened for buildings and camps: [center, radius, height].
const FLATS := [
	[Vector2(-190, 470), 16.0, 5.0],  # Coombe farm
	[Vector2(-200, 525), 12.0, 4.6],  # pumpkin patch
	[Vector2(-310, 335), 14.0, 8.0],  # the Old Delve
	[Vector2(-300, 690), 15.0, 5.0],  # brigand farmstead
	[Vector2(-175, 935), 13.0, 7.0],  # Grunmaw's camp
	[Vector2(22, 735), 6.0, 4.0],     # south watch
	[Vector2(203, 582), 5.0, 4.0],    # watchman's hut
	[Vector2(120, 500), 8.0, 5.0],    # Wainwright cottage
	[Vector2(168, 300), 14.0, 8.0],   # Copperhollow
	[Vector2(380, 700), 18.0, 5.0],   # Ashwood lumber camp
	[Vector2(380, 450), 10.0, 8.0],   # Thornwick Tower
	[Vector2(140, 640), 22.0, 4.5],   # Pellow vineyard
	[Vector2(-260, 776), 8.0, 2.6],   # Reedford landing
	[Vector2(-420, 520), 8.0, 5.5],   # west garrison
	[Vector2(332, 592), 10.0, 3.0],   # mirefin village
]
const FARM := 0
const PATCH := 1
const DELVE := 2
const FARMSTEAD := 3
const GNOLL_CAMP := 4
const SOUTH_WATCH := 5
const HUT := 6
const COTTAGE := 7
const COPPERHOLLOW := 8
const LUMBER_CAMP := 9
const TOWER := 10
const VINEYARD := 11
const LANDING := 12
const GARRISON := 13
const MIREFIN_VILLAGE := 14
## The farm's ploughed fields, round its house: center and radius.
const FIELDS := Vector2(-190, 482)
const FIELDS_RADIUS := 52.0
## Rounded hills: [center, radius, height].
const HILLS := [
	[Vector2(-345, 332), 50.0, 28.0],  # the Old Delve's hill
	[Vector2(-430, 285), 90.0, 20.0],
	[Vector2(205, 300), 50.0, 28.0],   # Copperhollow's hill
	[Vector2(300, 270), 70.0, 14.0],
	[Vector2(0, 930), 110.0, 10.0],    # gnoll hills
	[Vector2(380, 960), 80.0, 12.0],
	[Vector2(380, 450), 35.0, 6.0],    # Thornwick's knoll
	[Vector2(-120, 1060), 90.0, 9.0],
]
const LAKE := Vector2(270, 560)
const LAKE_RADIUS := 55.0
const LAKE_BED := -0.6
const STREAM := [
	Vector2(250, 612), Vector2(190, 690), Vector2(90, 745), Vector2(0, 760),
	Vector2(-120, 755), Vector2(-250, 790), Vector2(-380, 800), Vector2(-510, 830),
]
const ROADS := [
	# The pass down to Wexford.
	[Vector2(-8, 290), Vector2(-4, 360), Vector2(0, 418)],
	# West to the Coombe farm and on to the west garrison.
	[Vector2(-20, 438), Vector2(-90, 450), Vector2(-170, 462)],
	[Vector2(-210, 470), Vector2(-300, 500), Vector2(-415, 520)],
	# The farm to its pumpkin patch.
	[Vector2(-188, 486), Vector2(-198, 513)],
	# Up to the Old Delve.
	[Vector2(-110, 450), Vector2(-200, 400), Vector2(-296, 345)],
	# South over the bridge to the gnoll hills.
	[Vector2(0, 462), Vector2(4, 560), Vector2(8, 650), Vector2(10, 740), Vector2(10, 775), Vector2(0, 840), Vector2(-20, 880)],
	# East to the Wainwright cottage, then the watchman's hut by the mere.
	[Vector2(22, 445), Vector2(80, 470), Vector2(112, 495)],
	[Vector2(125, 505), Vector2(170, 545), Vector2(198, 578)],
	# Round the mere's north shore to the lumber camp, with Thornwick off it.
	[Vector2(125, 505), Vector2(200, 490), Vector2(275, 488), Vector2(345, 520), Vector2(372, 600), Vector2(380, 690)],
	[Vector2(300, 495), Vector2(372, 456)],
	# The pass road's branch east to Copperhollow.
	[Vector2(-4, 360), Vector2(60, 330), Vector2(155, 302)],
	# The vineyard, and the track west to the Reedford landing.
	[Vector2(5, 600), Vector2(120, 632)],
	[Vector2(8, 700), Vector2(-100, 720), Vector2(-255, 772)],
]
## Woods: [center, radius]. Trees thin out toward the edges.
const WOODS := [
	[Vector2(330, 330), 110.0],
	[Vector2(300, 880), 130.0],
	[Vector2(-90, 320), 45.0],
	[Vector2(-360, 470), 70.0],
	[Vector2(-380, 900), 100.0],
	[Vector2(440, 700), 60.0],
	[Vector2(150, 1010), 80.0],
	[Vector2(-60, 1120), 60.0],
]
## Where the south road crosses the stream.
const BRIDGE_X := 10.0
const BRIDGE_START := 748.0
const BRIDGE_END := 769.0
const BRIDGE_RAMP := 8.0

## Creature spawns: [creature entry, center, radius, count]. New groups go
## last, so saved corpses keep their names.
const SPAWNS := [
	[525, Vector2(90, 330), 35.0, 8],      # Mangy Wolf, north of Wexford (5-6)
	[30, Vector2(-90, 320), 25.0, 6],      # Forest Spider, the pass woods (5-6)
	[30, Vector2(-350, 460), 30.0, 6],     # Forest Spider, the west woods
	[285, Vector2(225, 535), 14.0, 6],     # Mirefin, the mere's west shore (6-7)
	[735, Vector2(285, 505), 14.0, 6],     # Mirefin Wader, its north shore (6-7)
	[285, Vector2(332, 592), 12.0, 6],     # Mirefin, the mirefin village on its east shore
	[524, Vector2(-110, 620), 45.0, 10],   # Flintback Boar, west meadow (7-8)
	[524, Vector2(80, 580), 25.0, 5],
	[390, Vector2(-200, 527), 8.0, 2],     # Fattened Hog, the pumpkin patch (7)
	[330, Vector2(-202, 523), 1.0, 1],     # Old Duchess (9)
	[390, Vector2(140, 640), 16.0, 4],     # Fattened Hog, the vineyard
	[1922, Vector2(330, 330), 60.0, 10],   # Gray Forest Wolf, northeast woods (7-8)
	[40, Vector2(-303, 340), 11.0, 5],     # Burrowling Pickman, the Old Delve (6-7)
	[476, Vector2(-316, 330), 6.0, 3],     # Burrowling Firecaller (7-8)
	[43, Vector2(-319, 342), 7.0, 4],      # Mine Spider (8-9)
	[327, Vector2(-322, 335), 1.0, 1],     # Brasstooth (8)
	[40, Vector2(175, 305), 11.0, 5],      # Burrowling Pickman, Copperhollow
	[476, Vector2(188, 297), 6.0, 3],      # Burrowling Firecaller
	[43, Vector2(186, 310), 8.0, 4],       # Mine Spider
	[116, Vector2(-295, 687), 22.0, 8],    # Brigand Cutthroat, the farmstead (8-9)
	[474, Vector2(-310, 697), 12.0, 4],    # Brigand Hedge-Mage (9-10)
	[474, Vector2(380, 452), 12.0, 4],     # Brigand Hedge-Mage, Thornwick Tower
	[116, Vector2(365, 475), 18.0, 6],     # Brigand Cutthroat, Thornwick Tower
	[822, Vector2(240, 860), 35.0, 6],     # Young Forest Bear, southeast woods (8-9)
	[822, Vector2(430, 790), 25.0, 5],     # Young Forest Bear, by the lumber camp
	[118, Vector2(340, 880), 55.0, 10],    # Prowler, southeast woods (9-10)
	[118, Vector2(430, 640), 30.0, 6],     # Prowler, by the lumber camp
	[732, Vector2(-130, 760), 25.0, 6],    # Mirefin Lurker, down the stream (9-10)
	[732, Vector2(-300, 808), 20.0, 5],    # Mirefin Lurker, by the Reedford landing
	[46, Vector2(150, 715), 18.0, 6],      # Mirefin Forager, up the stream (9-10)
	[97, Vector2(-40, 905), 35.0, 9],      # Ditchjaw Runt, gnoll hills (8-9)
	[478, Vector2(80, 925), 30.0, 6],      # Ditchjaw Outrider (9-10)
	[97, Vector2(150, 990), 30.0, 6],      # Ditchjaw Runt, south of the hills
	[117, Vector2(-172, 932), 14.0, 6],    # Ditchjaw Brute, Grunmaw's camp (11-12)
	[448, Vector2(-178, 938), 1.0, 1],     # Grunmaw (11, elite)
	[1922, Vector2(-380, 900), 50.0, 8],   # Gray Forest Wolf, southwest woods
	[473, Vector2(380, 457), 1.0, 1],      # Odo the Collector, at Thornwick Tower's door (10)
]

## Quest givers and enders that are things: [object entry, node name, point,
## facing]. The lost watchmen of the Fishy Peril chain: a half-eaten body on
## the mere's north shore, and Aldous in the mirefin village.
const QUEST_OBJECTS := [
	[55, "HalfEatenBody", Vector2(245, 497), 0.6],
	[56, "AldousCorpse", Vector2(338, 594), 2.2],
]
## Chests to loot: [object entry, center, radius, count]. Bundles of Wood
## round the Ashwood lumber camp, for A Bundle of Trouble.
const CHESTS := [
	[176793, Vector2(385, 700), 45.0, 12],
]

const ROCK := Color(0.47, 0.45, 0.42)
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
## Where flowers grow thick.
var _meadow := FastNoiseLite.new()


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	_meadow.seed = SEED + 5
	_meadow.frequency = 0.03
	for line: Array in ROADS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			_road_segments.append([a, b, Rect2(a, Vector2.ZERO).expand(b)])
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = VILLAGE
	hub_name = "Wexford"
	places = PLACES
	spawns = SPAWNS
	quest_objects = QUEST_OBJECTS
	chests = CHESTS


func _ready() -> void:
	# Stone, plaster, thatch, roofs and wood with painted textures.
	Props.use_texture(STONE, "stone_wall", 4.0)
	Props.use_texture(DARK_STONE, "stone_wall", 4.0)
	Props.use_texture(PLASTER, "plaster", 4.0)
	Props.use_texture(THATCH, "thatch", 3.0)
	Props.use_texture(ROOF, "roof_tiles", 2.5)
	Props.use_texture(WOOD, "planks", 2.0)
	Props.use_texture(DARK_WOOD, "planks", 2.0)
	Props.use_texture(ROCK, "rock", 3.0)
	build_ground(STEP, _ground_tint, _ground_layers)
	build_water(WATER_LEVEL, true)
	build_edges()
	_build_village()
	_build_farm()
	_build_cottage()
	_build_mine(FLATS[DELVE], -1, "OldDelve")
	_build_mine(FLATS[COPPERHOLLOW], 1, "Copperhollow")
	_build_farmstead()
	_build_gnoll_camp()
	_build_watch_posts()
	_build_bridge()
	_build_lumber_camp()
	_build_tower()
	_build_vineyard()
	_build_landing()
	_build_garrison()
	_build_mirefin_village()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Harrow", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


# Shape of the land.

func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	# Mountains round the edges, squarer than the vale's ring, so the
	# farmland reaches further into the corners. They're as deep as the
	# vale's (MOUNTAIN_START yards), however big the zone, so where the two
	# meet the ground is the same.
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	var half := SIZE / 2.0
	height += mountain_height(x, z, smoothstep(half - MOUNTAIN_START, half - MOUNTAIN_FULL, reach))
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


## The textured ground's layers (Zone.build_ground): dirt (roads, camps, the furrows of the Coombe fields, mud
## by the stream and the mere), cobbles (Wexford's green), rock (steep and
## high ground) and forest floor (the woods).
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	# The Coombe fields are ploughed soil (their wheat is clutter, _grass_at).
	var dirt := _field(point) * 0.95
	for flat: Array in FLATS:
		dirt = maxf(dirt, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.7)
	var road := minf(distance_to_pass(point), _road_distance(point, ROAD_WIDTH + 2.0))
	dirt = maxf(dirt, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, road))
	dirt = maxf(dirt, _mud(point))
	var cobbles := 1.0 - smoothstep(20.0, 24.0, point.distance_to(VILLAGE))
	var rock := maxf(smoothstep(0.82, 0.68, normal.y), smoothstep(24.0, 34.0, y))
	return Color(dirt, cobbles, rock, _woods_density(point))


## Wet ground by the stream and the mere.
func _mud(point: Vector2) -> float:
	var water := minf(distance_to_line(point, STREAM) - STREAM_WIDTH, point.distance_to(LAKE) - LAKE_RADIUS)
	return 1.0 - smoothstep(1.0, 4.0, water)


## The textured ground's tint: a little noise, and darker mud and ploughed
## soil.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := 1.0 + _detail.get_noise_2d(x, z) * 0.08 - _mud(point) * 0.3 - _field(point) * 0.15
	return Color(shade, shade, shade)


## Distance to the nearest road, or INF when none is within `reach`: only
## the segments whose box (grown by `reach`) holds the point are measured.
## Made in _init, before any worker thread reads it.
var _road_segments: Array = []


func _road_distance(point: Vector2, reach: float) -> float:
	var best := INF
	for segment: Array in _road_segments:
		if not (segment[2] as Rect2).grow(reach).has_point(point):
			continue
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, point.distance_to(a + (b - a) * t))
	return best


func _woods_density(point: Vector2) -> float:
	var density := 0.0
	for wood: Array in WOODS:
		density = maxf(density, 1.0 - smoothstep(wood[1] * 0.5, wood[1], point.distance_to(wood[0])))
	return density


## A point `offset` (x, z) from a place's center, at a height.
static func _near(place: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(place.x + offset.x, y, place.y + offset.y)


# Wexford: an inn, a chapel with its churchyard, cottages and a well round a
# cobbled green.

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Wexford"
	add_child(village)
	var v := VILLAGE
	var y := VILLAGE_HEIGHT
	# The Harrow Inn, east of the green, two storeys with its door to the west.
	Props.box(village, _near(v, Vector2(18, -10), y), Vector3(10, 7, 14), PLASTER)
	Props.roof(village, _near(v, Vector2(18, -10), y + 7), Vector3(11, 4, 15), ROOF)
	Props.box(village, _near(v, Vector2(12.9, -8), y), Vector3(0.3, 2.6, 1.6), DARK_WOOD, 0.0, false)
	Props.box(village, _near(v, Vector2(13, -12), y + 2.8), Vector3(0.2, 1, 1.6), DARK_WOOD, 0.0, false)
	for beam in [-16.0, -10.0, -4.0]:
		Props.box(village, _near(v, Vector2(12.9, beam), y), Vector3(0.25, 7, 0.3), DARK_WOOD, 0.0, false)
	# The chapel north of the green, its churchyard to the west.
	Props.box(village, _near(v, Vector2(-13, -22), y), Vector3(8, 6, 12), STONE)
	Props.roof(village, _near(v, Vector2(-13, -22), y + 6), Vector3(13, 3, 9), ROOF, PI / 2)
	Props.box(village, _near(v, Vector2(-13, -15.9), y), Vector3(2.2, 3.4, 0.3), DARK_WOOD, 0.0, false)
	Props.box(village, _near(v, Vector2(-13, -28.5), y), Vector3(3, 10, 3), STONE)
	Props.roof(village, _near(v, Vector2(-13, -28.5), y + 10), Vector3(3.6, 2.5, 3.6), ROOF)
	for stone in [Vector2(-22, 6), Vector2(-25, 9), Vector2(-22, 12), Vector2(-25, 15), Vector2(-28, 6), Vector2(-28, 12)]:
		Props.box(village, _near(v, stone, y), Vector3(0.9, 1.1, 0.25), DARK_STONE, 0.0, false)
	for post in [Vector2(-31, 3), Vector2(-31, 19), Vector2(-19, 3), Vector2(-19, 19)]:
		Props.box(village, _near(v, post, y), Vector3(0.4, 1.2, 0.4), DARK_WOOD, 0.0, false)
	# Cottages round the green.
	for cottage in [[Vector2(-18, -6), 0.0], [Vector2(-12, 28), PI / 2], [Vector2(16, 20), 0.0]]:
		Props.box(village, _near(v, cottage[0], y), Vector3(7, 4, 6), PLASTER, cottage[1])
		Props.roof(village, _near(v, cottage[0], y + 4), Vector3(8, 3, 7), THATCH, cottage[1])
	# The tanner's stall, a well, and the marshal's banner on the green.
	Props.box(village, _near(v, Vector2(-11, 5), y), Vector3(1.4, 1, 4), WOOD)
	Props.box(village, _near(v, Vector2(-11.6, 5), y + 3), Vector3(2.2, 0.2, 4.6), CANVAS, 0.0, false)
	for post in [Vector2(-12.3, 3), Vector2(-12.3, 7)]:
		Props.box(village, _near(v, post, y), Vector3(0.25, 3, 0.25), DARK_WOOD, 0.0, false)
	Props.cylinder(village, _near(v, Vector2(6, 8), y), 1.2, 1.0, DARK_STONE)
	for side in [-1, 1]:
		Props.box(village, _near(v, Vector2(6 + side * 1.0, 8), y), Vector3(0.2, 2.6, 0.2), DARK_WOOD, 0.0, false)
	Props.roof(village, _near(v, Vector2(6, 8), y + 2.6), Vector3(2.8, 0.9, 2.2), THATCH)
	Props.box(village, _near(v, Vector2(-2, 8), y), Vector3(0.25, 5, 0.25), DARK_WOOD, 0.0, false)
	Props.box(village, _near(v, Vector2(-1.3, 8), y + 3.2), Vector3(1.2, 1.6, 0.1), Color(0.2, 0.3, 0.6), 0.0, false)
	torch(village, _near(v, Vector2(12.6, -5.5), y + 2.6))
	torch(village, _near(v, Vector2(-10.5, -15.5), y + 2.4))
	# The smithy east of the well: a stone forge under a lean-to roof, with an
	# anvil out front, where the weaponsmith and the Man-at-Arms trainer stand.
	Props.box(village, _near(v, Vector2(25, 7), y), Vector3(6, 4.5, 5), DARK_STONE)
	Props.roof(village, _near(v, Vector2(25, 7), y + 4.5), Vector3(7, 2, 6), ROOF, PI / 2)
	Props.box(village, _near(v, Vector2(21.6, 7), y), Vector3(0.8, 1.4, 2.4), Color(0.12, 0.1, 0.1))
	torch(village, _near(v, Vector2(21.4, 7), y + 0.9), 5.0)
	Props.box(village, _near(v, Vector2(19.5, 11), y), Vector3(0.7, 0.8, 0.5), DARK_STONE)
	Props.box(village, _near(v, Vector2(19.5, 11), y + 0.8), Vector3(1.1, 0.3, 0.5), Color(0.25, 0.25, 0.28), 0.0, false)
	for rack in [3.0, 4.0, 5.0]:
		Props.box(village, _near(v, Vector2(21.8, rack + 1.5), y), Vector3(0.1, 1.6, 0.1), Color(0.6, 0.6, 0.65), 0.2, false)


# The Coombe farm: a farmhouse, a barn and a fenced pumpkin patch to the south.

func _build_farm() -> void:
	var farm := Node3D.new()
	farm.name = "CoombeFarm"
	add_child(farm)
	var at: Vector2 = FLATS[FARM][0]
	var y: float = FLATS[FARM][2]
	Props.box(farm, _near(at, Vector2(-4, -6), y), Vector3(9, 4.5, 7), PLASTER)
	Props.roof(farm, _near(at, Vector2(-4, -6), y + 4.5), Vector3(10, 3.5, 8), THATCH)
	Props.box(farm, _near(at, Vector2(8, -2), y), Vector3(7, 5, 10), WOOD)
	Props.roof(farm, _near(at, Vector2(8, -2), y + 5), Vector3(8, 3, 11), DARK_WOOD, PI / 2)
	for bale in [Vector2(3, 5), Vector2(4.5, 5.5), Vector2(3.6, 6.6)]:
		Props.cylinder(farm, _near(at, bale, y), 0.7, 0.9, THATCH, false)
	var patch: Vector2 = FLATS[PATCH][0]
	var patch_y: float = FLATS[PATCH][2]
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 5
	for i in 22:
		var spot := patch + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		Props.cylinder(farm, Vector3(spot.x, patch_y, spot.y), rng.randf_range(0.3, 0.55), 0.5, PUMPKIN, false)
	# A low fence round the patch, open toward the farm.
	for side in 4:
		var angle := side * PI / 2
		var along := Vector2(cos(angle), sin(angle))
		var across := Vector2(-along.y, along.x)
		for step in range(-5, 6):
			if side == 3 and absi(step) <= 1:
				continue
			var spot := patch + along * 11.0 + across * step * 2.0
			Props.box(farm, Vector3(spot.x, patch_y, spot.y), Vector3(0.25, 1.0, 0.25), WOOD, 0.0, false)


func _build_cottage() -> void:
	var cottage := Node3D.new()
	cottage.name = "WainwrightCottage"
	add_child(cottage)
	var at: Vector2 = FLATS[COTTAGE][0]
	var y: float = FLATS[COTTAGE][2]
	Props.box(cottage, _near(at, Vector2(3, -2), y), Vector3(6, 4, 6), PLASTER, 0.4)
	Props.roof(cottage, _near(at, Vector2(3, -2), y + 4), Vector3(7, 3, 7), THATCH, 0.4)
	Props.box(cottage, _near(at, Vector2(-3, 3), y), Vector3(2, 1, 1.2), WOOD)


## A mine dug into a hill beside its flat: `side` -1 for a hill to the west
## (the Old Delve), 1 for one to the east (Copperhollow).
func _build_mine(flat: Array, side: int, node_name: String) -> void:
	var mine := Node3D.new()
	mine.name = node_name
	add_child(mine)
	var at: Vector2 = flat[0]
	var y: float = flat[2]
	var x := at.x + side * 14.0
	var z := at.y
	Props.box(mine, Vector3(x + side * 3.5, y, z), Vector3(7, 5, 5), Color(0.05, 0.04, 0.04))
	for end in [-1, 1]:
		Props.box(mine, Vector3(x, y, z + end * 2.7), Vector3(0.6, 4.6, 0.6), DARK_WOOD)
	Props.box(mine, Vector3(x, y + 4.6, z), Vector3(0.8, 0.6, 6.2), DARK_WOOD, 0.0, false)
	Props.box(mine, _near(at, Vector2(side * 3, -7), y), Vector3(1.6, 1.2, 2.4), WOOD)
	for pile in [Vector2(side * 6, 10), Vector2(-side * 9, -5)]:
		Props.cylinder(mine, _near(at, pile, y), 1.6, 1.4, ROCK, true, 0.3)
	for end in [-1, 1]:
		torch(mine, Vector3(x - side * 0.4, y + 2.8, z + end * 3.2))


# The brigands' farmstead: a burned-out house and barn they've taken over.

func _build_farmstead() -> void:
	var farmstead := Node3D.new()
	farmstead.name = "BrigandFarmstead"
	add_child(farmstead)
	var at: Vector2 = FLATS[FARMSTEAD][0]
	var y: float = FLATS[FARMSTEAD][2]
	var charred := Color(0.22, 0.19, 0.17)
	# The house's walls without a roof.
	Props.box(farmstead, _near(at, Vector2(-5, -7), y), Vector3(9, 3.5, 0.6), charred)
	Props.box(farmstead, _near(at, Vector2(-9.2, -4), y), Vector3(0.6, 2.5, 6), charred)
	Props.box(farmstead, _near(at, Vector2(-0.8, -5), y), Vector3(0.6, 3, 4), charred)
	Props.box(farmstead, _near(at, Vector2(8, 2), y), Vector3(6, 4, 8), WOOD)
	Props.roof(farmstead, _near(at, Vector2(8, 2), y + 4), Vector3(7, 2.5, 9), DARK_WOOD, PI / 2)
	Props.roof(farmstead, _near(at, Vector2(-3, 7), y), Vector3(4, 2.6, 3.4), Color(0.45, 0.18, 0.15), 0.3)
	Props.cylinder(farmstead, _near(at, Vector2.ZERO, y), 1.0, 0.3, DARK_STONE, false)
	torch(farmstead, _near(at, Vector2.ZERO, y + 0.6), 6.0)
	for crate in [Vector2(4, -4), Vector2(5, -3), Vector2(-5, 3)]:
		Props.box(farmstead, _near(at, crate, y), Vector3(1, 1, 1), WOOD)


func _build_gnoll_camp() -> void:
	var camp := Node3D.new()
	camp.name = "GrunmawCamp"
	add_child(camp)
	var at: Vector2 = FLATS[GNOLL_CAMP][0]
	var y: float = FLATS[GNOLL_CAMP][2]
	for i in 3:
		var angle := TAU * i / 3.0 + 1.0
		var spot := at + Vector2(cos(angle), sin(angle)) * 7.0
		Props.roof(camp, Vector3(spot.x, y, spot.y), Vector3(4, 3, 4), Color(0.5, 0.4, 0.3), -angle)
	Props.cylinder(camp, _near(at, Vector2.ZERO, y), 1.0, 0.3, DARK_STONE, false)
	torch(camp, _near(at, Vector2.ZERO, y + 0.6), 6.0)
	for bone in [Vector2(3, 2), Vector2(-2, 4), Vector2(4, -3)]:
		Props.box(camp, _near(at, bone, y), Vector3(1.2, 0.2, 0.2), STONE, bone.x, false)


## A wooden watchtower on four posts, with a roof: the south watch and the
## west garrison.
func _watchtower(parent: Node3D, at: Vector2, y: float, height: float, width: float) -> void:
	var half := width / 2.0 - 0.3
	for corner in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
		Props.box(parent, _near(at, corner, y), Vector3(0.4, height, 0.4), DARK_WOOD)
	Props.box(parent, _near(at, Vector2.ZERO, y + height), Vector3(width, 0.3, width), WOOD, 0.0, false)
	Props.roof(parent, _near(at, Vector2.ZERO, y + height + 1.2), Vector3(width + 0.4, 1.6, width + 0.4), ROOF)


## The south watch by the bridge and the watchman's hut by the mere.
func _build_watch_posts() -> void:
	var posts := Node3D.new()
	posts.name = "WatchPosts"
	add_child(posts)
	var watch: Vector2 = FLATS[SOUTH_WATCH][0]
	var y: float = FLATS[SOUTH_WATCH][2]
	_watchtower(posts, watch + Vector2(3, -3), y, 5.0, 3.8)
	torch(posts, _near(watch, Vector2(1, -1), y + 2.4))
	var hut: Vector2 = FLATS[HUT][0]
	var hut_y: float = FLATS[HUT][2]
	Props.box(posts, _near(hut, Vector2(-3, 0), hut_y), Vector3(4, 3, 4), WOOD)
	Props.roof(posts, _near(hut, Vector2(-3, 0), hut_y + 3), Vector3(5, 2, 5), THATCH)


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


# The Ashwood lumber camp: tents, log piles, a saw horse and stumps in a
# clearing in the east woods.

func _build_lumber_camp() -> void:
	var camp := Node3D.new()
	camp.name = "AshwoodLumberCamp"
	add_child(camp)
	var at: Vector2 = FLATS[LUMBER_CAMP][0]
	var y: float = FLATS[LUMBER_CAMP][2]
	for tent in [[Vector2(-9, -6), 0.2], [Vector2(-9, 5), -0.2], [Vector2(-2, -11), PI / 2]]:
		Props.roof(camp, _near(at, tent[0], y), Vector3(5, 3, 4), CANVAS, tent[1])
	# Log piles, three logs under two under one.
	for pile in [Vector2(6, -6), Vector2(7, 4)]:
		for layer in 3:
			for log_index in 3 - layer:
				var across := (log_index - (2 - layer) / 2.0) * 0.8
				Props.box(camp, _near(at, pile + Vector2(0, across), y + layer * 0.7), Vector3(6, 0.7, 0.7), WOOD, 0.0, layer == 0)
	# A saw horse with a log on it.
	Props.box(camp, _near(at, Vector2(0, 8), y), Vector3(1.2, 1.0, 3.0), DARK_WOOD)
	Props.box(camp, _near(at, Vector2(0, 8), y + 1.0), Vector3(5, 0.6, 0.6), WOOD, 0.0, false)
	Props.cylinder(camp, _near(at, Vector2(-3, 0), y), 0.9, 0.3, DARK_STONE, false)
	torch(camp, _near(at, Vector2(-3, 0), y + 0.6), 6.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 7
	for i in 14:
		var angle := rng.randf() * TAU
		var spot := at + Vector2(cos(angle), sin(angle)) * rng.randf_range(12.0, 22.0)
		var ground := height_at(spot.x, spot.y)
		Props.cylinder(camp, Vector3(spot.x, ground, spot.y), rng.randf_range(0.4, 0.6), 0.6, WOOD)


# Thornwick Tower: a round stone tower on a knoll east of the mere, which
# brigand hedge-mages have taken.

func _build_tower() -> void:
	var tower := Node3D.new()
	tower.name = "ThornwickTower"
	add_child(tower)
	var at: Vector2 = FLATS[TOWER][0]
	var y: float = FLATS[TOWER][2]
	Props.cylinder(tower, _near(at, Vector2.ZERO, y), 4.0, 16.0, STONE)
	Props.cylinder(tower, _near(at, Vector2.ZERO, y + 16.0), 4.8, 5.0, ROOF, false, 0.0)
	# Its door to the south, and dark windows up its side.
	Props.box(tower, _near(at, Vector2(0, 3.9), y), Vector3(1.8, 3.0, 0.4), DARK_WOOD, 0.0, false)
	for window in [[Vector2(0, 3.95), 7.0], [Vector2(3.95, 0), 10.0], [Vector2(-3.95, 0), 12.0], [Vector2(0, -3.95), 9.0]]:
		var spot: Vector2 = window[0]
		Props.box(tower, _near(at, spot, y + window[1]), Vector3(0.8 if spot.x == 0.0 else 0.3, 1.2, 0.3 if spot.x == 0.0 else 0.8), Color(0.08, 0.07, 0.1), 0.0, false)
	for crate in [Vector2(5, 5), Vector2(6, 4), Vector2(-5, 6)]:
		Props.box(tower, _near(at, crate, y), Vector3(1, 1, 1), WOOD)
	torch(tower, _near(at, Vector2(1.6, 4.6), y + 2.4))


# The Pellow vineyard: rows of vines on posts, and the press house.

func _build_vineyard() -> void:
	var vineyard := Node3D.new()
	vineyard.name = "PellowVineyard"
	add_child(vineyard)
	var at: Vector2 = FLATS[VINEYARD][0]
	var y: float = FLATS[VINEYARD][2]
	var leaves: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for row in range(-2, 3):
		for column in range(-4, 5):
			var spot := at + Vector2(column * 4.0, row * 5.0 + 3.0)
			posts.append(Transform3D(Basis(), Vector3(spot.x, y + 0.8, spot.y)))
			leaves.append(Transform3D(Basis().scaled(Vector3(3.6, 0.9, 0.8)), Vector3(spot.x, y + 1.2, spot.y)))
	var post := BoxMesh.new()
	post.size = Vector3(0.2, 1.6, 0.2)
	Props.scatter(vineyard, post, DARK_WOOD, posts)
	var leaf := BoxMesh.new()
	leaf.size = Vector3.ONE
	Props.scatter(vineyard, leaf, Color(0.28, 0.48, 0.2), leaves)
	Props.box(vineyard, _near(at, Vector2(0, -16), y), Vector3(7, 3.5, 5), PLASTER)
	Props.roof(vineyard, _near(at, Vector2(0, -16), y + 3.5), Vector3(8, 2.5, 6), ROOF)
	for barrel in [Vector2(5, -15), Vector2(5, -17), Vector2(6.2, -16)]:
		Props.cylinder(vineyard, _near(at, barrel, y), 0.5, 1.0, WOOD)


# The Reedford landing: a dock on the stream's north bank, a shed and a boat.

func _build_landing() -> void:
	var landing := Node3D.new()
	landing.name = "ReedfordLanding"
	add_child(landing)
	var at: Vector2 = FLATS[LANDING][0]
	var y: float = FLATS[LANDING][2]
	var deck := y + 0.3
	plank(landing, Vector3(at.x, deck, at.y + 4.0), Vector3(at.x, deck, at.y + 15.0))
	for z in [8.0, 11.5, 15.0]:
		for side in [-1, 1]:
			Props.box(landing, Vector3(at.x + side * 2.3, STREAM_BED - 1.0, at.y + z), Vector3(0.4, deck - STREAM_BED + 1.6, 0.4), DARK_WOOD, 0.0, false)
	Props.box(landing, _near(at, Vector2(-5, -3), y), Vector3(4, 3, 4), WOOD)
	Props.roof(landing, _near(at, Vector2(-5, -3), y + 3), Vector3(5, 1.8, 5), THATCH)
	Props.box(landing, Vector3(at.x + 4.0, WATER_LEVEL - 0.3, at.y + 12.0), Vector3(1.6, 0.7, 4.2), WOOD, 0.0, false)
	for crate in [Vector2(3, -2), Vector2(4, -1)]:
		Props.box(landing, _near(at, crate, y), Vector3(1, 1, 1), WOOD)


# The west garrison: a tall watchtower and a short palisade at the end of
# the west road.

func _build_garrison() -> void:
	var garrison := Node3D.new()
	garrison.name = "WestGarrison"
	add_child(garrison)
	var at: Vector2 = FLATS[GARRISON][0]
	var y: float = FLATS[GARRISON][2]
	_watchtower(garrison, at + Vector2(-2, -3), y, 8.0, 5.0)
	for i in 7:
		Props.box(garrison, _near(at, Vector2(-6, -6 + i * 2.0), y), Vector3(0.6, 2.4, 0.6), DARK_WOOD)
	Props.box(garrison, _near(at, Vector2(2, -4), y), Vector3(0.25, 5, 0.25), DARK_WOOD, 0.0, false)
	Props.box(garrison, _near(at, Vector2(2.7, -4), y + 3.2), Vector3(1.2, 1.6, 0.1), Color(0.2, 0.3, 0.6), 0.0, false)
	torch(garrison, _near(at, Vector2(1, 1), y + 2.4))


# The mirefin village: reed huts and drying racks on the mere's east shore.

func _build_mirefin_village() -> void:
	var village := Node3D.new()
	village.name = "MirefinVillage"
	add_child(village)
	var at: Vector2 = FLATS[MIREFIN_VILLAGE][0]
	var y: float = FLATS[MIREFIN_VILLAGE][2]
	var reed := Color(0.55, 0.5, 0.3)
	for hut in [Vector2(-5, -4), Vector2(4, -6), Vector2(6, 4), Vector2(-6, 5)]:
		Props.cylinder(village, _near(at, hut, y), 1.7, 2.4, reed, true, 0.25)
	for rack in [Vector2(0, -1), Vector2(1, 6)]:
		for side in [-1, 1]:
			Props.box(village, _near(at, rack + Vector2(side * 1.2, 0), y), Vector3(0.15, 1.4, 0.15), DARK_WOOD, 0.0, false)
		Props.box(village, _near(at, rack, y + 1.3), Vector3(2.6, 0.12, 0.12), DARK_WOOD, 0.0, false)
		Props.box(village, _near(at, rack, y + 0.7), Vector3(1.8, 0.5, 0.08), Color(0.4, 0.5, 0.45), 0.0, false)


# Woods and scattered trees, placed by a seeded random walk over the map. The
# attempts scale with the zone's area, so it's as wooded as the vale.

## Placement attempts per 400 by 400 yards (Ashford Vale's size).
const TREE_ATTEMPTS := 7000
const ROCK_ATTEMPTS := 1500


func _area_share() -> float:
	return SIZE * SIZE / (400.0 * 400.0)


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	var half := SIZE / 2.0 - EDGE_INSET
	return CENTER + Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))


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
	for attempt in roundi(TREE_ATTEMPTS * _area_share()):
		var point := _random_point(rng)
		var chance := 0.02 + 0.55 * _woods_density(point)
		var y := height_at(point.x, point.y)
		chance += 0.25 * smoothstep(8.0, 14.0, y) * (1.0 - smoothstep(26.0, 32.0, y))
		if rng.randf() > chance or not _clear_for_tree(point, y):
			continue
		var tree_size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tree_size), Vector3(point.x, y, point.y))
		var pine := y > 12.0 or rng.randf() < 0.2
		(pines if pine else oaks)[rng.randi_range(0, TREE_VARIANTS - 1)].append(base)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	# Added once its shapes are in: adding shapes to a body in the world
	# rebuilds the body each time.
	add_child(trees)
	draw_trees(trees, pines, oaks, SEED)


func _clear_for_tree(point: Vector2, y: float) -> bool:
	if y < WATER_LEVEL + 0.6 or y > 34.0:
		return false
	if point.distance_to(VILLAGE) < VILLAGE_FLAT + 4.0 or point.distance_to(LAKE) < LAKE_RADIUS + 4.0:
		return false
	if distance_to_line(point, STREAM) < STREAM_WIDTH + 4.0 or distance_to_pass(point) < PASS_FLOOR + 3.0:
		return false
	if point.distance_to(FIELDS) < FIELDS_RADIUS - 2.0:
		return false
	if _road_distance(point, ROAD_WIDTH + 2.5) < ROAD_WIDTH + 2.5:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return point.distance_to(Vector2(BRIDGE_X, (BRIDGE_START + BRIDGE_END) / 2.0)) > 16.0


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
	for attempt in roundi(ROCK_ATTEMPTS * _area_share()):
		var point := _random_point(rng)
		var y := height_at(point.x, point.y)
		var chance := 0.03 + 0.4 * smoothstep(9.0, 20.0, y)
		if rng.randf() > chance or not _clear_for_tree(point, minf(y, 30.0)):
			continue
		var rock_size := Vector3(rng.randf_range(0.6, 2.2), rng.randf_range(0.4, 1.4), rng.randf_range(0.6, 2.2))
		placed[rng.randi_range(0, ROCK_VARIANTS - 1)].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(rock_size), Vector3(point.x, y + rock_size.y * 0.15, point.y)))
		if rock_size.x > 1.2 and rock_size.z > 1.2:
			var collision := CollisionShape3D.new()
			var shape := SphereShape3D.new()
			shape.radius = minf(rock_size.x, rock_size.z) * 0.8
			collision.shape = shape
			collision.position = Vector3(point.x, y, point.y)
			rocks.add_child(collision)
	# Added once its shapes are in: adding shapes to a body in the world
	# rebuilds the body each time.
	add_child(rocks)
	draw_rocks(rocks, placed, SEED)


## Grass, flowers, ferns and bushes, made near the camera as it goes
## (Zone.add_nature_clutter), as in Ashford Vale.
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 4)


## What grows at a point, if anything: grass on open ground and stubble in
## the fields, thin in the woods with ferns under the trees, flowers in
## meadows. Called from a worker thread: it only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var woods := _woods_density(point)
	var field := _field(point)
	if field > 0.5:
		return _wheat_at(point, rng)
	if rng.randf() > lerpf(0.9, 0.3, woods):
		return []
	var y := ground_height(point.x, point.y)
	if y > 26.0 or not _clear_for_clutter(point, y) or _steep(point, y):
		return []
	var at := Vector3(point.x, y - 0.05, point.y)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	if woods > 0.35 and rng.randf() < 0.45:
		return ["ferns", Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), at)]
	if woods < 0.3 and field < 0.1 and ((_meadow.get_noise_2dv(point) > 0.25 and rng.randf() < 0.35) or rng.randf() < 0.025):
		var kind: String = ["flowers_yellow", "flowers_white", "flowers_blue"][clampi(int((_meadow.get_noise_2dv(point * 0.37 + Vector2(500, 0)) + 1.0) * 1.5), 0, 2)]
		return [kind, Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), at)]
	if rng.randf() < 0.3:
		return ["tall", Transform3D(spin.scaled(Vector3(1, rng.randf_range(1.1, 1.5), 1) * rng.randf_range(0.9, 1.2)), at)]
	return ["grass", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.7, 1.1), 1) * rng.randf_range(0.8, 1.15)), at)]


## Wheat in the Coombe fields, in rows across the ploughed soil.
func _wheat_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if fposmod(point.x * 0.25 + point.y * 0.1, 1.0) > 0.45 or rng.randf() > 0.95:
		return []
	var y := ground_height(point.x, point.y)
	if not _clear_for_clutter(point, y):
		return []
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return ["wheat", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.85, 1.1), 1)), Vector3(point.x, y - 0.05, point.y))]


## A bush, now and then: thickest along the edges of the woods, none in
## the fields.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var woods := _woods_density(point)
	if rng.randf() > 0.025 + woods * (1.0 - woods) * 4.0 * 0.45 or _field(point) > 0.0:
		return []
	var y := ground_height(point.x, point.y)
	if y > 26.0 or not _clear_for_clutter(point, y) or _steep(point, y):
		return []
	var bush_size := rng.randf_range(0.8, 1.5)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)), Transform3D(spin.scaled(Vector3(bush_size, bush_size * rng.randf_range(0.8, 1.1), bush_size)), Vector3(point.x, y - 0.05, point.y))]


## Steep ground is bare rock: nothing grows on it.
func _steep(point: Vector2, y: float) -> bool:
	var slope := maxf(absf(ground_height(point.x + 0.6, point.y) - y), absf(ground_height(point.x, point.y + 0.6) - y)) / 0.6
	return slope > 0.6


## How far into the Coombe fields a point is, 0 to 1.
func _field(point: Vector2) -> float:
	return 1.0 - smoothstep(FIELDS_RADIUS - 8.0, FIELDS_RADIUS, point.distance_to(FIELDS))


## Open ground: not on roads, water, cobbles or camps.
func _clear_for_clutter(point: Vector2, y: float) -> bool:
	if y < WATER_LEVEL + 0.4 or point.distance_to(VILLAGE) < 24.0 or point.distance_to(LAKE) < LAKE_RADIUS:
		return false
	if distance_to_line(point, STREAM) < STREAM_WIDTH + 1.5 or distance_to_pass(point) < ROAD_WIDTH + 0.8:
		return false
	if _road_distance(point, ROAD_WIDTH + 0.8) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1]:
			return false
	return true
