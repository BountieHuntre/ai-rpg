class_name RedsandCoast
extends Zone
## The Horde's second zone on Kareth, standing in for classic's Durotar: red
## coastland a thousand yards across, for levels 6 to 12, west of Emberhollow
## over the pass. Spikewall, the Horde's palisade town, stands where the pass
## road comes down; the sea fills a bay along the south, with the Tidebone
## trolls' village on its western shore and Vazzar's Tidebone Isles offshore,
## and the Saltmarch humans' Stranded Keep on the eastern shore with their
## wrecked ship on the beach below it. The Redwater runs down from the north
## hills to the sea west of Spikewall. Inland: the tuskfolk's dry gulch and
## the Dunestride centaurs' camp in the west, the harpies' cliffs in the
## northwest, Stormcrag Ridge (lizards and an Ember Cult camp) in the north,
## the tigers' hills between, and the Ember Cult's Skull Rock cave in the
## northeast hills below the shut gate of Ironmaw Hold. Built in code from the
## layout below, in world coordinates, like Harrowfield. -Z is north.

const ZONE_NAME := "Redsand Coast"
const CENTER := Vector2(1800, -1900)
const SIZE := 1000.0
const STEP := 2.5
const MOUNTAIN_START := 56.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
## The sea's floor: shallow enough to wade, as everywhere in the game.
const SEA_BED := -0.9
const STREAM_BED := 0.2
const STREAM_WIDTH := 4.0
const ROAD_WIDTH := 2.6
const SEED := 3301

const TOWN := Vector2(2060, -1790)
const TOWN_HEIGHT := 5.0
const TOWN_FLAT := 38.0
## Spikewall's graveyard, by the north palisade.
const GRAVEYARD := Vector3(2050, TOWN_HEIGHT, -1815)
const GRAVEYARD_FACING := PI

## The shore, west to east: the sea is south of it.
const COAST := [
	Vector2(1250, -1590), Vector2(1450, -1600), Vector2(1600, -1575), Vector2(1750, -1555),
	Vector2(1900, -1580), Vector2(2050, -1600), Vector2(2200, -1590), Vector2(2350, -1595),
]

## Named places: [name, center, radius], smallest first.
const PLACES := [
	["Old Breka's hut", Vector2(1850, -1612), 10.0],
	["Old Ruzga's hut", Vector2(2020, -2020), 10.0],
	["Rezzik's wagon", Vector2(1620, -2060), 10.0],
	["the gate of Ironmaw Hold", Vector2(2235, -2325), 18.0],
	["the Stranded Keep", Vector2(2185, -1630), 22.0],
	["the Tidebone village", Vector2(1470, -1625), 26.0],
	["the Skull Rock cave", Vector2(2110, -2245), 28.0],
	["the Dunestride camp", Vector2(1400, -1880), 28.0],
	["the wreck", Vector2(2145, -1585), 30.0],
	["the Redwater mouth", Vector2(1885, -1585), 30.0],
	["Spikewall", Vector2(2060, -1790), 42.0],
	["the dry gulch", Vector2(1560, -1760), 45.0],
	["the pass", Vector2(2265, -1745), 40.0],
	["the Tidebone Isles", Vector2(1545, -1505), 70.0],
	["the tigers' hills", Vector2(1830, -2010), 80.0],
	["Stormcrag Ridge", Vector2(1730, -2240), 95.0],
	["the harpies' cliffs", Vector2(1430, -2200), 95.0],
	["the eastern shore", Vector2(2050, -1610), 120.0],
	["the western shore", Vector2(1650, -1590), 140.0],
]

## Level areas: [center, radius, height].
const FLATS := [
	[Vector2(1470, -1625), 20.0, 2.8],   # Tidebone village
	[Vector2(2185, -1632), 16.0, 3.0],   # the Stranded Keep
	[Vector2(2092, -2236), 10.0, 9.0],   # the Skull Rock cave mouth
	[Vector2(1400, -1880), 18.0, 5.0],   # the Dunestride camp
	[Vector2(1560, -1760), 22.0, 2.5],   # the dry gulch
	[Vector2(2020, -2020), 8.0, 9.0],    # Old Ruzga's hut
	[Vector2(1620, -2060), 7.0, 6.0],    # Rezzik's wagon
	[Vector2(1850, -1612), 6.0, 2.6],    # Old Breka's hut
	[Vector2(1720, -2262), 12.0, 21.0],  # the Ember Cult's ridge camp
	[Vector2(1508, -1508), 9.0, 3.2],    # Vazzar's hut on the isle
	[Vector2(2235, -2318), 14.0, 12.0],  # before the gate of Ironmaw Hold
]
const VILLAGE := 0
const KEEP := 1
const SKULL_ROCK := 2
const CENTAUR_CAMP := 3
const GULCH := 4
const RUZGA := 5
const WAGON := 6
const BREKA := 7
const RIDGE_CAMP := 8
const ISLE_HUT := 9
const IRONMAW_GATE := 10
## Rounded hills: [center, radius, height]. The isles are hills in the sea.
const HILLS := [
	[Vector2(1730, -2240), 95.0, 22.0],  # Stormcrag Ridge
	[Vector2(2130, -2260), 55.0, 26.0],  # Skull Rock's hill
	[Vector2(1430, -2200), 85.0, 26.0],  # the harpies' cliffs
	[Vector2(2020, -2030), 30.0, 6.0],   # Old Ruzga's knoll
	[Vector2(1830, -2010), 70.0, 8.0],   # the tigers' hills
	[Vector2(1508, -1508), 32.0, 4.6],   # Tidebone Isle
	[Vector2(1600, -1490), 22.0, 3.8],   # the little isle
	[Vector2(1350, -1700), 50.0, 9.0],
]
const STREAM := [
	Vector2(1880, -2330), Vector2(1900, -2200), Vector2(1880, -2080), Vector2(1900, -1960),
	Vector2(1880, -1840), Vector2(1890, -1720), Vector2(1880, -1600), Vector2(1885, -1540),
]
## The pass east to Emberhollow (Zone.PASSES["kareth"]) starts here.
const PASS_START := Vector2(2235, -1745)
const ROADS := [
	# The pass down into Spikewall.
	[PASS_START, Vector2(2160, -1765), Vector2(2098, -1788)],
	# West from Spikewall over the Redwater to the gulch and on to the Tidebone village.
	[Vector2(2022, -1792), Vector2(1950, -1760), Vector2(1890, -1745), Vector2(1800, -1735), Vector2(1680, -1700), Vector2(1580, -1660), Vector2(1492, -1630)],
	# South to the Stranded Keep, and the track down to the Redwater mouth.
	[Vector2(2070, -1752), Vector2(2120, -1700), Vector2(2172, -1648)],
	[Vector2(1890, -1745), Vector2(1870, -1660), Vector2(1856, -1620)],
	# North to Old Ruzga's hut and Skull Rock, and the gate of Ironmaw Hold.
	[Vector2(2060, -1828), Vector2(2050, -1920), Vector2(2025, -2012)],
	[Vector2(2050, -1920), Vector2(2080, -2050), Vector2(2090, -2150), Vector2(2092, -2226)],
	[Vector2(2090, -2150), Vector2(2170, -2230), Vector2(2232, -2305)],
	# The Ridge road west: the tigers' hills, Rezzik's wagon and the centaurs.
	[Vector2(1890, -1745), Vector2(1860, -1880), Vector2(1760, -1990), Vector2(1628, -2056)],
	[Vector2(1612, -2058), Vector2(1520, -1990), Vector2(1440, -1920), Vector2(1408, -1890)],
]
## Where the Spikewall road crosses the Redwater.
const BRIDGE_X := 1890.0

## Creature spawns: [creature entry, center, radius, count]. New groups go
## last, so saved corpses keep their names.
const SPAWNS := [
	[3099, Vector2(1990, -1700), 55.0, 8],   # Dire Dustback Boar, round Spikewall (6-7)
	[3099, Vector2(1720, -1800), 70.0, 10],
	[3100, Vector2(1650, -1960), 70.0, 9],   # Elder Dustback Boar, inland (8-9)
	[3125, Vector2(1960, -1690), 45.0, 7],   # Clattering Scorpion (5-6)
	[3126, Vector2(1760, -1910), 60.0, 8],   # Armored Scorpion (7-8)
	[3127, Vector2(1610, -1660), 45.0, 9],   # Venomtail Scorpion, by the Tidebone village (9-10)
	[3106, Vector2(1640, -1570), 50.0, 8],   # Small Shore Crab, the western shore (5)
	[3107, Vector2(1980, -1590), 45.0, 8],   # Shore Crab, the eastern shore (7)
	[3108, Vector2(1360, -1590), 35.0, 6],   # Barnacled Shore Crab (9)
	[3103, Vector2(2010, -1575), 30.0, 6],   # Clawfolk Clacker (6)
	[3104, Vector2(1720, -1560), 30.0, 6],   # Clawfolk Shellback (6-7)
	[3105, Vector2(1420, -1575), 25.0, 5],   # Clawfolk Snapper (8)
	[3141, Vector2(1720, -1550), 10.0, 2],   # Clawfolk Elder (8-9)
	[3122, Vector2(1700, -1600), 55.0, 9],   # Redclaw Lasher, the raptors' beaches (6-7)
	[3123, Vector2(1360, -1640), 40.0, 7],   # Redclaw Reaver (8-9)
	[3121, Vector2(1830, -2010), 65.0, 9],   # Redsand Tiger, the tigers' hills (7-8)
	[3111, Vector2(1560, -1760), 20.0, 6],   # Thornhide Tuskfolk, the dry gulch (6-7)
	[3112, Vector2(1540, -1745), 18.0, 5],   # Thornhide Scout (7-8)
	[3113, Vector2(1580, -1775), 16.0, 5],   # Thornhide Dustrunner (8-9)
	[3114, Vector2(1565, -1765), 12.0, 5],   # Thornhide Warguard (9-10)
	[5826, Vector2(1555, -1770), 1.0, 1],    # Earthspeaker Grubb (9, rare)
	[5824, Vector2(1570, -1752), 1.0, 1],    # Captain Brokentusk (11, rare)
	[3115, Vector2(1440, -2180), 50.0, 6],   # Galecry Harpy, the harpies' cliffs (7-8)
	[3116, Vector2(1480, -2140), 40.0, 6],   # Galecry Raider (7-8)
	[3117, Vector2(1400, -2230), 45.0, 9],   # Galecry Savage (9-10)
	[3118, Vector2(1440, -2260), 35.0, 7],   # Galecry Stormcaller (10-11)
	[3119, Vector2(1400, -1880), 22.0, 7],   # Dunestride Drudge, the centaurs' camp (6-7)
	[3120, Vector2(1420, -1860), 30.0, 6],   # Dunestride Outrider (7-8)
	[5808, Vector2(1398, -1884), 1.0, 1],    # Warlord Hask (9, rare)
	[3128, Vector2(2165, -1655), 40.0, 10],  # Saltmarch Sailor, the Stranded Keep (5-6)
	[3129, Vector2(2187, -1630), 14.0, 8],   # Saltmarch Marine, inside its walls (6-7)
	[3192, Vector2(2190, -1628), 1.0, 1],    # Lieutenant Harwick (8)
	[5809, Vector2(2150, -1660), 1.0, 1],    # Watch Commander Pellam (9, rare)
	[3130, Vector2(1760, -2210), 60.0, 7],   # Stormback Lizard, Stormcrag Ridge (9-10)
	[3131, Vector2(1690, -2190), 45.0, 6],   # Sparkhide Lizard (10-11)
	[3196, Vector2(1720, -2262), 12.0, 4],   # Ember Cult Neophyte, the ridge camp (9-10)
	[3198, Vector2(1726, -2268), 10.0, 3],   # Ember Cult Acolyte (10-11)
	[3203, Vector2(1718, -2266), 1.0, 1],    # Grizzle Ashtongue (12)
	[3195, Vector2(2105, -2210), 22.0, 6],   # Ember Cult Thug, before Skull Rock (8-9)
	[3197, Vector2(2085, -2240), 14.0, 6],   # Ember Cult Zealot (9-10)
	[3199, Vector2(2096, -2236), 9.0, 5],    # Ember Cult Pyromancer (10-11)
	[3198, Vector2(2120, -2225), 14.0, 4],   # Ember Cult Acolyte
	[3204, Vector2(2093, -2237), 1.0, 1],    # Vozgul, in the cave mouth (14)
	[5822, Vector2(2110, -2205), 1.0, 1],    # Hexweaver Skarn (11, rare)
	[3206, Vector2(1520, -1500), 22.0, 8],   # Cursecaller Troll, the Tidebone Isles (8-9)
	[3207, Vector2(1560, -1515), 30.0, 8],   # Thralled Troll (8-9)
	[3206, Vector2(1600, -1490), 14.0, 4],   # the little isle
	[3205, Vector2(1509, -1509), 1.0, 1],    # Vazzar, at his hut (10)
	[3110, Vector2(1890, -1580), 22.0, 6],   # Mudjaw Crocodile, the Redwater mouth (9-10)
	[5823, Vector2(1620, -1670), 1.0, 1],    # Deathsting (11, rare)
]
## Chests to loot: [object entry, center, radius, count]. Tinker's Toolboxes
## on the wreck's beach, Lasher Eggs on the raptors' beaches, the harpies'
## Stolen Supply Sacks, and the Imprisoned Tidebone Troll's cage (Old Mother
## Wazi's Skull) by Vazzar's hut.
const CHESTS := [
	# The Kolkar attack plans (Thwarting Kolkar Aggression), in the Dunestride camp.
	[3189, Vector2(1400, -1880), 14.0, 1],
	[3190, Vector2(1400, -1880), 14.0, 1],
	[3192, Vector2(1400, -1880), 14.0, 1],
	[3236, Vector2(2140, -1590), 35.0, 8],
	[3240, Vector2(1700, -1600), 55.0, 8],
	[3290, Vector2(1440, -2190), 60.0, 8],
	[3237, Vector2(1500, -1513), 1.0, 1],
]

const SAND := Color(0.76, 0.52, 0.34)
const BEACH := Color(0.86, 0.74, 0.52)
const DRY_GRASS := Color(0.64, 0.57, 0.33)
const OCHRE := Color(0.8, 0.6, 0.36)
const RED_ROCK := Color(0.58, 0.32, 0.22)
const DARK_ROCK := Color(0.42, 0.25, 0.19)
const PACKED_EARTH := Color(0.62, 0.45, 0.3)
const ROAD := Color(0.68, 0.52, 0.36)
const MUD := Color(0.45, 0.34, 0.24)
const HIDE := Color(0.62, 0.48, 0.32)
const DARK_HIDE := Color(0.42, 0.3, 0.2)
const LOG := Color(0.4, 0.27, 0.17)
const BONE := Color(0.88, 0.84, 0.72)
const STONE := Color(0.62, 0.6, 0.56)
const DARK_STONE := Color(0.42, 0.41, 0.4)
const THATCH := Color(0.72, 0.62, 0.36)
const BAMBOO := Color(0.6, 0.55, 0.3)
const CACTUS := Color(0.32, 0.5, 0.26)
const THORN := Color(0.42, 0.38, 0.22)
const BANNER := Color(0.62, 0.12, 0.1)
const SAIL := Color(0.86, 0.84, 0.76)
const IRON := Color(0.32, 0.3, 0.3)

var _detail := FastNoiseLite.new()
var _road_segments: Array = []


func _init() -> void:
	_detail.seed = SEED + 1
	_detail.frequency = 0.06
	for line: Array in ROADS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			_road_segments.append([a, b, Rect2(a, Vector2.ZERO).expand(b)])
	continent = "kareth"
	zone_name = ZONE_NAME
	center = CENTER
	size = SIZE
	graveyard = GRAVEYARD
	graveyard_facing = GRAVEYARD_FACING
	hub = TOWN
	hub_name = "Spikewall"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_town()
	_build_village()
	_build_isles()
	_build_keep()
	_build_wreck()
	_build_skull_rock()
	_build_camps()
	_build_ironmaw_gate()
	_build_bridge()
	_build_cacti()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Redsand", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


# Shape of the land.

func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	for hill: Array in HILLS:
		if hill[2] < 5.0:
			continue
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	# The sea south of the shore, the isles rising out of it.
	var sea := smoothstep(-8.0, 26.0, z - _coast_z(x))
	height = lerpf(height, SEA_BED, sea)
	for hill: Array in HILLS:
		if hill[2] < 5.0:
			height = maxf(height, lerpf(SEA_BED, hill[2], _bump(point.distance_to(hill[0]) / hill[1])))
	height = lerpf(TOWN_HEIGHT, height, smoothstep(TOWN_FLAT, TOWN_FLAT + 18.0, point.distance_to(TOWN)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	var stream := distance_to_line(point, STREAM)
	height = minf(height, lerpf(STREAM_BED, height, smoothstep(STREAM_WIDTH, STREAM_WIDTH + 7.0, stream)))
	# Mountains round the edges last, as deep as every zone's, so the ground
	# joins at the borders whatever is near them.
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	var half := SIZE / 2.0
	height += mountain_height(x, z, smoothstep(half - MOUNTAIN_START, half - MOUNTAIN_FULL, reach))
	return carve_passes(x, z, height)


## The shore's z at an x (COAST).
func _coast_z(x: float) -> float:
	for i in COAST.size() - 1:
		var a: Vector2 = COAST[i]
		var b: Vector2 = COAST[i + 1]
		if x <= b.x or i == COAST.size() - 2:
			var t := clampf((x - a.x) / (b.x - a.x), 0.0, 1.0)
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, t))
	return COAST[0].y


func _road_distance(point: Vector2, limit: float) -> float:
	var best := distance_to_pass(point)
	for segment: Array in _road_segments:
		var box: Rect2 = segment[2]
		if box.grow(limit).has_point(point):
			best = minf(best, distance_to_line(point, [segment[0], segment[1]]))
	return best


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.07
	var patch := Zone.land_noise().get_noise_2d(x * 2.3, z * 2.3)
	var color := SAND.lerp(DRY_GRASS, smoothstep(0.05, 0.35, patch) * 0.7)
	color = color.lerp(OCHRE, smoothstep(-0.1, -0.4, patch) * 0.6)
	color = color.lerp(BEACH, 1.0 - smoothstep(1.6, 3.4, y))
	color = color.lerp(PACKED_EARTH, 1.0 - smoothstep(TOWN_FLAT - 6.0, TOWN_FLAT, point.distance_to(TOWN)))
	for flat: Array in FLATS:
		color = color.lerp(PACKED_EARTH, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.7)
	color = color.lerp(ROAD, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point, ROAD_WIDTH + 1.0)))
	color = color.lerp(MUD, 1.0 - smoothstep(STREAM_WIDTH + 1.0, STREAM_WIDTH + 4.0, distance_to_line(point, STREAM)))
	color = color.lerp(RED_ROCK, smoothstep(0.84, 0.66, normal.y))
	color = color.lerp(RED_ROCK, smoothstep(22.0, 32.0, y))
	return Color(color.r + shade, color.g + shade * 0.8, color.b + shade * 0.6)


## A point on the ground near a place, for the builders.
func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


# Spikewall: the Horde's town where the pass road comes down. A palisade
# along its north and its sides, round huts, the commander's longhouse, the
# inn, a smithy, two watchtowers and the graveyard by the north wall.

func _build_town() -> void:
	var town := Node3D.new()
	town.name = "Spikewall"
	add_child(town)
	var t := TOWN
	var y := TOWN_HEIGHT
	palisade(town, t + Vector2(-34, -30), t + Vector2(34, -30), y, LOG)
	palisade(town, t + Vector2(-34, -30), t + Vector2(-34, -6), y, LOG)
	palisade(town, t + Vector2(34, -30), t + Vector2(34, -10), y, LOG)
	# The commander's longhouse to the north.
	Props.box(town, _near(t, Vector2(0, -20), y), Vector3(16, 4, 8), LOG)
	Props.roof(town, _near(t, Vector2(0, -20), y + 4), Vector3(17, 3.5, 9.5), HIDE)
	Props.box(town, _near(t, Vector2(0, -15.9), y), Vector3(2.4, 3.2, 0.3), DARK_HIDE, 0.0, false)
	Props.box(town, _near(t, Vector2(-0.2, -15.6), y + 4.5), Vector3(0.1, 2.0, 2.2), BANNER, 0.0, false)
	# The inn to the east: a long hut with a hide roof.
	Props.box(town, _near(t, Vector2(22, -4), y), Vector3(9, 4, 14), LOG)
	Props.roof(town, _near(t, Vector2(22, -4), y + 4), Vector3(15, 3.5, 10), HIDE, PI / 2)
	Props.box(town, _near(t, Vector2(17.4, -2), y), Vector3(0.3, 2.8, 1.8), DARK_HIDE, 0.0, false)
	# Round huts round the yard.
	for hut in [Vector2(-22, -14), Vector2(-24, 6), Vector2(-10, 20), Vector2(14, 20), Vector2(20, -20)]:
		round_hut(town, t + hut, 4.0, y, LOG, HIDE, BONE)
	# The smithy to the west: a hide roof on posts over a forge and an anvil.
	for post in [Vector2(-18, -6), Vector2(-10, -6), Vector2(-18, 1), Vector2(-10, 1)]:
		Props.box(town, _near(t, post, y), Vector3(0.4, 3.6, 0.4), LOG)
	Props.roof(town, _near(t, Vector2(-14, -2.5), y + 3.6), Vector3(9, 2, 8), HIDE, PI / 2)
	Props.box(town, _near(t, Vector2(-16.5, -4), y), Vector3(2.4, 1.8, 2.2), DARK_ROCK)
	Props.box(town, _near(t, Vector2(-12, 0), y), Vector3(1.1, 0.9, 0.6), IRON)
	# Watchtowers at the pass road and the west road.
	for tower in [Vector2(34, 2), Vector2(-36, 2)]:
		for corner in [Vector2(-1.5, -1.5), Vector2(1.5, -1.5), Vector2(-1.5, 1.5), Vector2(1.5, 1.5)]:
			Props.box(town, _near(t, tower + corner, y), Vector3(0.4, 8, 0.4), LOG)
		Props.box(town, _near(t, tower, y + 7), Vector3(4, 0.4, 4), LOG, 0.0, false)
		Props.roof(town, _near(t, tower, y + 8.6), Vector3(4.6, 2, 4.6), HIDE)
	# The graveyard by the north wall: cairns and grave markers.
	for grave in [Vector2(-14, -26), Vector2(-10, -26), Vector2(-6, -26), Vector2(-14, -23), Vector2(-10, -23)]:
		Props.cylinder(town, _near(t, grave, y), 0.6, 0.6, DARK_ROCK, false)
		Props.box(town, _near(t, grave + Vector2(0, -0.6), y), Vector3(0.2, 1.4, 0.2), BONE, 0.0, false)
	# A war drum and the cook's fire in the yard.
	Props.cylinder(town, _near(t, Vector2(4, -4), y), 1.3, 1.6, DARK_HIDE)
	Props.cylinder(town, _near(t, Vector2(-4, 10), y), 1.0, 0.3, DARK_ROCK, false)
	torch(town, _near(t, Vector2(-4, 10), y + 0.6), 6.0)
	for torch_at in [Vector2(16.8, -6), Vector2(-6, -16), Vector2(30, -26)]:
		torch(town, _near(t, torch_at, y + 2.4))


# The Tidebone trolls' village on the western shore: stilt huts of bamboo and
# thatch, a totem, and the healer's drying racks.

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "TideboneVillage"
	add_child(village)
	var flat: Array = FLATS[VILLAGE]
	var v: Vector2 = flat[0]
	var y: float = flat[2]
	for hut in [[Vector2(-12, -8), 0.3], [Vector2(10, -10), -0.4], [Vector2(-14, 8), 1.2], [Vector2(12, 9), -1.0], [Vector2(0, -16), 0.0]]:
		_stilt_hut(village, v + hut[0], y, hut[1])
	Props.box(village, _near(v, Vector2(0, 0), y), Vector3(0.6, 5, 0.6), BAMBOO)
	Props.cylinder(village, _near(v, Vector2(0, 0), y + 5), 0.6, 1.0, BONE, false)
	for rack in [Vector2(5, 3), Vector2(7, 3)]:
		Props.box(village, _near(v, rack, y), Vector3(0.15, 2, 0.15), BAMBOO, 0.0, false)
	Props.box(village, _near(v, Vector2(6, 3), y + 1.8), Vector3(2.4, 0.1, 0.1), BAMBOO, 0.0, false)
	Props.cylinder(village, _near(v, Vector2(-3, 4), y), 0.9, 0.3, DARK_ROCK, false)
	torch(village, _near(v, Vector2(-3, 4), y + 0.5), 6.0)


## A troll hut: a thatched cone on a platform on four bamboo stilts.
func _stilt_hut(parent: Node3D, at: Vector2, y: float, yaw: float) -> void:
	for corner: Vector2 in [Vector2(-1.8, -1.8), Vector2(1.8, -1.8), Vector2(-1.8, 1.8), Vector2(1.8, 1.8)]:
		var c := corner.rotated(yaw)
		Props.box(parent, Vector3(at.x + c.x, y, at.y + c.y), Vector3(0.3, 1.6, 0.3), BAMBOO)
	Props.box(parent, Vector3(at.x, y + 1.6, at.y), Vector3(4.4, 0.3, 4.4), BAMBOO, yaw)
	Props.cylinder(parent, Vector3(at.x, y + 1.9, at.y), 1.9, 1.8, BAMBOO)
	var roof := MeshInstance3D.new()
	roof.mesh = Props.cone(2.8, 2.6, 8)
	roof.material_override = Props.material(THATCH)
	roof.position = Vector3(at.x, y + 3.7 + 1.3, at.y)
	parent.add_child(roof)


# Vazzar's isles: his hut and fetish posts on the big isle.

func _build_isles() -> void:
	var isles := Node3D.new()
	isles.name = "TideboneIsles"
	add_child(isles)
	var flat: Array = FLATS[ISLE_HUT]
	_stilt_hut(isles, flat[0] + Vector2(4, -3), flat[2], 0.6)
	for post in [Vector2(-6, 4), Vector2(8, 6), Vector2(-2, -9)]:
		Props.box(isles, _near(flat[0], post, flat[2]), Vector3(0.4, 3.2, 0.4), DARK_HIDE, 0.0, false)
		Props.cylinder(isles, _near(flat[0], post, flat[2] + 3.2), 0.4, 0.5, BONE, false)
	torch(isles, _near(flat[0], Vector2(0, 2), flat[2] + 0.5), 6.0)


# The Saltmarch humans' Stranded Keep: a stone tower inside a low wall on
# the eastern shore.

func _build_keep() -> void:
	var keep := Node3D.new()
	keep.name = "StrandedKeep"
	add_child(keep)
	var flat: Array = FLATS[KEEP]
	var k: Vector2 = flat[0]
	var y: float = flat[2]
	Props.box(keep, _near(k, Vector2(0, -13), y), Vector3(26, 3.5, 1.2), STONE)
	Props.box(keep, _near(k, Vector2(-13, 0), y), Vector3(1.2, 3.5, 26), STONE)
	Props.box(keep, _near(k, Vector2(13, 0), y), Vector3(1.2, 3.5, 26), STONE)
	for side in [-1, 1]:
		Props.box(keep, _near(k, Vector2(side * 8, 13), y), Vector3(10, 3.5, 1.2), STONE)
	Props.box(keep, _near(k, Vector2(5, -5), y), Vector3(8, 12, 8), STONE)
	Props.box(keep, _near(k, Vector2(5, -5), y + 12), Vector3(9, 1, 9), DARK_STONE, 0.0, false)
	Props.box(keep, _near(k, Vector2(5, -0.9), y), Vector3(2, 3, 0.3), LOG, 0.0, false)
	Props.box(keep, _near(k, Vector2(5, -5), y + 13), Vector3(0.2, 4, 0.2), LOG, 0.0, false)
	Props.box(keep, _near(k, Vector2(5.8, -5), y + 15.5), Vector3(1.4, 1.0, 0.1), Color(0.2, 0.3, 0.6), 0.0, false)
	for crate in [Vector2(-6, 4), Vector2(-5, 5.2), Vector2(-8, -6)]:
		Props.box(keep, _near(k, crate, y), Vector3(1.1, 1.1, 1.1), LOG)
	torch(keep, _near(k, Vector2(-2, 12), y + 2.6))


# The Saltmarch ship wrecked on the beach below the keep, keel up.

func _build_wreck() -> void:
	var wreck := Node3D.new()
	wreck.name = "Wreck"
	add_child(wreck)
	var at := Vector2(2150, -1580)
	var y := WATER_LEVEL - 0.6
	Props.box(wreck, Vector3(at.x, y, at.y), Vector3(18, 3.2, 5), LOG, 0.35)
	Props.roof(wreck, Vector3(at.x, y + 3.2, at.y), Vector3(18, 1.6, 5.4), DARK_HIDE, 0.35)
	var mast := Vector3(at.x - 4, y + 1, at.y + 6)
	Props.box(wreck, mast, Vector3(12, 0.5, 0.5), LOG, -0.9, false)
	Props.box(wreck, mast + Vector3(2, 0.3, 1), Vector3(4, 0.1, 3), SAIL, -0.6, false)


# Skull Rock: the Ember Cult's cave in the northeastern hills, a skull-faced
# crag over a dark mouth.

func _build_skull_rock() -> void:
	var rock := Node3D.new()
	rock.name = "SkullRock"
	add_child(rock)
	var flat: Array = FLATS[SKULL_ROCK]
	var y: float = flat[2]
	var x: float = flat[0].x + 9.0
	var z: float = flat[0].y - 4.0
	Props.box(rock, Vector3(x + 3, y, z), Vector3(7, 6, 7), Color(0.04, 0.03, 0.03))
	# The skull: a bone-pale dome with two dark eyes over the mouth.
	Props.cylinder(rock, Vector3(x + 1, y + 6, z), 5.5, 6, BONE, false, 4.0)
	for side in [-1, 1]:
		Props.box(rock, Vector3(x - 3.4, y + 9, z + side * 2), Vector3(0.6, 1.8, 1.6), Color(0.06, 0.05, 0.05), 0.0, false)
	for brazier in [Vector2(-5, -5), Vector2(-5, 5)]:
		Props.cylinder(rock, Vector3(x + brazier.x, y, z + brazier.y), 0.5, 1.0, DARK_ROCK)
		torch(rock, Vector3(x + brazier.x, y + 1.3, z + brazier.y), 6.0)


# Smaller camps: the centaurs', the tuskfolk's gulch, Old Ruzga's and Old
# Breka's huts, Rezzik's wagon and the Ember Cult's camp on the ridge.

func _build_camps() -> void:
	var camps := Node3D.new()
	camps.name = "Camps"
	add_child(camps)
	var centaurs: Array = FLATS[CENTAUR_CAMP]
	for i in 4:
		var angle := TAU * i / 4.0 + 0.3
		var at: Vector2 = centaurs[0] + Vector2(cos(angle), sin(angle)) * 10.0
		Props.roof(camps, Vector3(at.x, centaurs[2], at.y), Vector3(5, 3.2, 4.2), Color(0.55, 0.42, 0.26), -angle)
	torch(camps, _near(centaurs[0], Vector2.ZERO, centaurs[2] + 0.5), 6.0)
	var gulch: Array = FLATS[GULCH]
	var spikes: Array[Transform3D] = []
	for i in 5:
		var angle := TAU * i / 5.0
		var at: Vector2 = gulch[0] + Vector2(cos(angle), sin(angle)) * 13.0
		var mound := MeshInstance3D.new()
		mound.mesh = Props.blob(3.0, 7, 4)
		mound.material_override = Props.material(Color(0.5, 0.36, 0.22))
		mound.scale = Vector3(1, 0.7, 1)
		mound.position = Vector3(at.x, gulch[2] + 0.6, at.y)
		camps.add_child(mound)
		spikes.append(Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(at.x, gulch[2] + 2.2, at.y)))
	Props.scatter(camps, Props.cone(0.25, 1.8, 4), BONE, spikes)
	for hut_flat in [FLATS[RUZGA], FLATS[BREKA]]:
		round_hut(camps, hut_flat[0], 3.4, hut_flat[2], LOG, DARK_HIDE, BONE)
	var wagon: Array = FLATS[WAGON]
	Props.box(camps, _near(wagon[0], Vector2(0, 0), wagon[2] + 0.6), Vector3(4.5, 1.4, 2.2), LOG, 0.3)
	Props.roof(camps, _near(wagon[0], Vector2(0, 0), wagon[2] + 2.0), Vector3(4.2, 1.6, 2.4), SAIL, 0.3)
	for wheel in [Vector2(-1.6, -1.2), Vector2(1.6, -1.2), Vector2(-1.6, 1.2), Vector2(1.6, 1.2)]:
		Props.cylinder(camps, _near(wagon[0], wheel.rotated(-0.3), wagon[2]), 0.6, 0.3, DARK_HIDE, false)
	var ridge: Array = FLATS[RIDGE_CAMP]
	for i in 3:
		var angle := TAU * i / 3.0
		var at: Vector2 = ridge[0] + Vector2(cos(angle), sin(angle)) * 7.0
		Props.roof(camps, Vector3(at.x, ridge[2], at.y), Vector3(4, 2.6, 3.4), Color(0.35, 0.12, 0.1), -angle)
	torch(camps, _near(ridge[0], Vector2.ZERO, ridge[2] + 0.5), 7.0)


# The gate of Ironmaw Hold, shut in the northeastern mountains: the capital
# itself is still to come.

func _build_ironmaw_gate() -> void:
	var gate := Node3D.new()
	gate.name = "IronmawGate"
	add_child(gate)
	var flat: Array = FLATS[IRONMAW_GATE]
	var at: Vector2 = flat[0] + Vector2(6, -9)
	var y: float = flat[2]
	var yaw := -0.8
	for side in [-1, 1]:
		var tower := at + Vector2(side * 9, 0).rotated(-yaw)
		Props.box(gate, Vector3(tower.x, y, tower.y), Vector3(5, 16, 5), DARK_ROCK, yaw)
		Props.roof(gate, Vector3(tower.x, y + 16, tower.y), Vector3(5.6, 3, 5.6), DARK_HIDE, yaw)
	Props.box(gate, Vector3(at.x, y, at.y), Vector3(13, 11, 1.6), IRON, yaw)
	Props.box(gate, Vector3(at.x, y + 11, at.y), Vector3(14, 2, 2.4), DARK_ROCK, yaw)
	torch(gate, Vector3(at.x + 2, y + 6, at.y + 3), 8.0)


# A plank bridge where the Spikewall road crosses the Redwater.

func _build_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "Bridge"
	add_child(bridge)
	var z := -1745.0
	var west := BRIDGE_X - 12.0
	var east := BRIDGE_X + 12.0
	var deck := maxf(height_at(west, z), height_at(east, z)) + 0.4
	var sink := Vector3(0, -0.5, 0)
	plank(bridge, ground_point(west - 8.0, z) + sink, Vector3(west, deck, z))
	plank(bridge, Vector3(west, deck, z), Vector3(east, deck, z))
	plank(bridge, Vector3(east, deck, z), ground_point(east + 8.0, z) + sink)


# Cacti and thorn bushes, placed by a seeded random walk over the land.

func _build_cacti() -> void:
	var plants := StaticBody3D.new()
	plants.name = "Cacti"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var stems: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var palms: Array[Transform3D] = []
	var fronds: Array[Transform3D] = []
	var stem_shape := CylinderShape3D.new()
	stem_shape.radius = 0.35
	stem_shape.height = 3.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 9000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 26.0 or not _clear(point):
			continue
		if rng.randf() > 0.09:
			continue
		var size := rng.randf_range(0.8, 1.4)
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var base := Transform3D(spin.scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		var collide := false
		if y < 3.6 and rng.randf() < 0.6:
			# Palms by the shore.
			palms.append(base * Transform3D(Basis(), Vector3(0, 2.4, 0)))
			fronds.append(base * Transform3D(Basis().scaled(Vector3(1, 0.4, 1)), Vector3(0, 4.9, 0)))
			collide = true
		elif rng.randf() < 0.5:
			stems.append(base * Transform3D(Basis(), Vector3(0, 1.4, 0)))
			for side in [-1, 1]:
				if rng.randf() < 0.7:
					arms.append(base * Transform3D(Basis(Vector3.FORWARD, side * 0.25), Vector3(side * 0.55, 1.6 + rng.randf() * 0.6, 0)))
			collide = true
		else:
			bushes.append(Transform3D(spin.scaled(Vector3(size, size * 0.6, size)), Vector3(point.x, y + 0.3, point.y)))
		if collide:
			var collision := CollisionShape3D.new()
			collision.shape = stem_shape
			collision.position = Vector3(point.x, y + 1.5, point.y)
			plants.add_child(collision)
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
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 4.8
	trunk.radial_segments = 6
	add_child(plants)
	Props.scatter(plants, stem, CACTUS, stems)
	Props.scatter(plants, arm, CACTUS, arms)
	Props.scatter(plants, Props.blob(0.9, 6, 3), THORN, bushes)
	Props.scatter(plants, trunk, LOG, palms)
	Props.scatter(plants, Props.blob(2.2, 7, 3), Color(0.3, 0.5, 0.22), fronds)


func _clear(point: Vector2) -> bool:
	if point.distance_to(TOWN) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	if distance_to_line(point, STREAM) < STREAM_WIDTH + 3.0:
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
	var edge := SIZE / 2.0 - 6.0
	for attempt in 4000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.05 + 0.45 * smoothstep(8.0, 20.0, y) or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.7, 2.8), rng.randf_range(0.5, 1.9), rng.randf_range(0.7, 2.8))
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


const CLUTTER_ATTEMPTS := 30000


## Dry grass tufts and pebbles on open ground, only for looks.
func _build_clutter() -> void:
	var clutter := Node3D.new()
	clutter.name = "Clutter"
	add_child(clutter)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var grass: Array[Transform3D] = []
	var pebbles: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in CLUTTER_ATTEMPTS:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.5 or y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.25:
			pebbles.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.6, 1.2)), at + Vector3.UP * 0.05))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.16, 0.32, 4), Color(0.66, 0.6, 0.34), grass)
	add_clutter(clutter, Props.blob(0.12, 5, 3), DARK_ROCK, pebbles)
