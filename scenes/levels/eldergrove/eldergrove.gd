class_name EldergroveIsle
extends Zone
## The Wood Elves' second zone, standing in for classic's Teldrassil: an
## island forest 1200 yards across grown on the branches of the world-tree,
## for levels 6 to 12, south of Mossglen down the great tree's roots.
## Fernwatch, the elves' village of bowers round a moonwell, stands in the
## north middle; the Gloamrock, a sprite-haunted hill, is north-east of it,
## Lake Aleth with the barklings east, and Starbreeze, a village the
## Twistbark bearfolk have overrun, in the north-east. To the west the
## corrupted bearfolk hold the Thornbarrow Den, and the road west ends at
## the gate of Silverbough, the elves' city; the Moonwells lie south of
## Fernwatch, the Crimsonwing harpies roost in the Seers' Glade in the
## south-west, and Twistbark Hold, the bearfolk's stronghold, is in the
## south. Owls, shadecats and Silkwood spiders haunt the woods. Built in code,
## in world coordinates. -Z is north.

const ZONE_NAME := "Eldergrove Isle"
const CENTER := Vector2(-2000, -4200)
const SIZE := 1200.0
const STEP := 2.5
const MOUNTAIN_START := 56.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const ROAD_WIDTH := 2.4
const SEED := 5401

const TOWN := Vector2(-2080, -4380)
const TOWN_HEIGHT := 6.0
const TOWN_FLAT := 42.0
const GRAVEYARD := Vector3(-2080, TOWN_HEIGHT, -4350)
const GRAVEYARD_FACING := PI
const LAKE := Vector2(-1720, -4250)
const LAKE_RADIUS := 48.0

const PLACES := [
	["Denalan's camp", Vector2(-1786, -4250), 10.0],
	["the Silverbough Gate", Vector2(-2560, -4200), 20.0],
	["the Gloamrock", Vector2(-1960, -4600), 26.0],
	["Starbreeze", Vector2(-1560, -4560), 30.0],
	["the Thornbarrow Den", Vector2(-2420, -4150), 30.0],
	["the Moonwells", Vector2(-2150, -4000), 30.0],
	["Twistbark Hold", Vector2(-1900, -3760), 34.0],
	["the Seers' Glade", Vector2(-2380, -3760), 40.0],
	["Fernwatch", TOWN, 44.0],
	["the pass", Vector2(-2208, -4770), 30.0],
	["Lake Aleth", LAKE, 60.0],
	["the northern woods", Vector2(-1800, -4600), 150.0],
	["the western woods", Vector2(-2350, -4450), 150.0],
	["the southern woods", Vector2(-2000, -3900), 220.0],
]
const FLATS := [
	[Vector2(-1960, -4600), 16.0, 7.0],   # before the Gloamrock
	[Vector2(-1560, -4560), 22.0, 6.0],   # Starbreeze
	[Vector2(-2420, -4150), 20.0, 8.0],   # before the Thornbarrow Den
	[Vector2(-2150, -4000), 22.0, 5.0],   # the Moonwells
	[Vector2(-1900, -3760), 26.0, 7.0],   # Twistbark Hold
	[Vector2(-2380, -3760), 26.0, 9.0],   # the Seers' Glade
	[Vector2(-2560, -4200), 14.0, 8.0],   # the Silverbough Gate
	[Vector2(-1786, -4250), 8.0, 3.0],    # Denalan's camp on the lake shore
]
const GLOAMROCK := 0
const STARBREEZE := 1
const DEN := 2
const MOONWELLS := 3
const HOLD := 4
const GLADE := 5
const GATE := 6
const DENALAN := 7
const HILLS := [
	[Vector2(-1945, -4625), 34.0, 18.0],  # the Gloamrock
	[Vector2(-2440, -4170), 34.0, 14.0],  # the barrow mound
	[Vector2(-2400, -3720), 50.0, 8.0],
	[Vector2(-1880, -3720), 40.0, 10.0],
	[Vector2(-1600, -3900), 90.0, 10.0],
	[Vector2(-2300, -4550), 80.0, 8.0],
]
const PASS_END := Vector2(-2212, -4730)
const ROADS := [
	# Down from the pass to Fernwatch, and on south to the Moonwells and the hold.
	[PASS_END, Vector2(-2180, -4600), Vector2(-2110, -4420)],
	[Vector2(-2090, -4338), Vector2(-2130, -4200), Vector2(-2150, -4022)],
	[Vector2(-2140, -3980), Vector2(-2040, -3860), Vector2(-1920, -3786)],
	# East past the Gloamrock to Starbreeze; east to the lake.
	[Vector2(-2050, -4410), Vector2(-1960, -4580)],
	[Vector2(-1960, -4580), Vector2(-1760, -4580), Vector2(-1584, -4562)],
	[Vector2(-2040, -4370), Vector2(-1900, -4300), Vector2(-1794, -4252)],
	# West to the Thornbarrow Den and the Silverbough Gate; south-west to the glade.
	[Vector2(-2122, -4370), Vector2(-2300, -4250), Vector2(-2546, -4202)],
	[Vector2(-2300, -4250), Vector2(-2402, -4162)],
	[Vector2(-2150, -4000), Vector2(-2260, -3880), Vector2(-2360, -3784)],
]
const SPAWNS := [
	[1995, Vector2(-1950, -4500), 130.0, 12],  # Strigid Owl (5-6)
	[1998, Vector2(-2250, -4550), 120.0, 10],  # Silkwood Lurker (5-6)
	[2042, Vector2(-1820, -4450), 140.0, 12],  # Shadecat (5-6)
	[2022, Vector2(-1720, -4250), 70.0, 10],   # Barkling, Lake Aleth (5-6)
	[2002, Vector2(-1960, -4600), 22.0, 6],    # Rascal Sprite, the Gloamrock (5-6)
	[2003, Vector2(-1950, -4610), 22.0, 6],    # Shadow Sprite (5-6)
	[2004, Vector2(-1945, -4620), 18.0, 5],    # Dark Sprite (6-7)
	[2005, Vector2(-1955, -4615), 18.0, 5],    # Vicious Fenling (7)
	[2038, Vector2(-1948, -4618), 1.0, 1],     # Lord Malvenn (8)
	[14432, Vector2(-1972, -4592), 1.0, 1],    # Grubbin (6, rare)
	[2006, Vector2(-1560, -4560), 28.0, 6],    # Twistbark Ursa, Starbreeze (5-6)
	[2007, Vector2(-1570, -4550), 28.0, 8],    # Twistbark Gardener (5-6)
	[2008, Vector2(-1650, -4450), 90.0, 10],   # Twistbark Warrior (6-7)
	[7235, Vector2(-1530, -4580), 18.0, 5],    # Twistbark Mystic (6-7)
	[7234, Vector2(-1522, -4590), 1.0, 1],     # Gorvax the Dream Eater (8)
	[2152, Vector2(-2470, -4240), 40.0, 8],    # Twistbark Ambusher, the gate road (6-7)
	[1996, Vector2(-2250, -4000), 140.0, 10],  # Strigid Screecher (7-8)
	[1999, Vector2(-2300, -3950), 120.0, 9],   # Silkwood Venomfang (7-8)
	[2043, Vector2(-1850, -4000), 140.0, 10],  # Shadecat Stalker (7-8)
	[2025, Vector2(-1680, -4300), 50.0, 6],    # Barkling Ripper (7-8)
	[2027, Vector2(-1660, -4200), 40.0, 4],    # Barkling Trampler (8-9)
	[2029, Vector2(-1720, -4180), 40.0, 5],    # Barkling Mirebeast (9-10)
	[2030, Vector2(-1650, -4240), 30.0, 5],    # Elder Barkling (10-11)
	[2166, Vector2(-1662, -4272), 1.0, 1],     # Mossbrow (9)
	[2009, Vector2(-2420, -4150), 28.0, 8],    # Twistbark Shaman, the Thornbarrow Den (7-8)
	[2010, Vector2(-2415, -4140), 28.0, 8],    # Twistbark Defender (7-8)
	[2011, Vector2(-2430, -4160), 24.0, 7],    # Twistbark Augur (8-9)
	[1997, Vector2(-1600, -3850), 100.0, 8],   # Strigid Hunter (8-9)
	[2000, Vector2(-1750, -3800), 100.0, 8],   # Silkwood Silkspinner (8-9)
	[2033, Vector2(-2100, -3800), 120.0, 8],   # Elder Shadecat (8-9)
	[2001, Vector2(-1500, -3720), 50.0, 4],    # Giant Silkwood Spider (10)
	[2034, Vector2(-1550, -3700), 60.0, 5],    # Feral Shadecat (10)
	[2012, Vector2(-1900, -3760), 32.0, 6],    # Twistbark Pathfinder, Twistbark Hold (9-10)
	[2013, Vector2(-1890, -3770), 32.0, 6],    # Twistbark Avenger (9-10)
	[2014, Vector2(-1910, -3750), 24.0, 5],    # Twistbark Totemic (10-11)
	[2039, Vector2(-1904, -3742), 1.0, 1],     # Borrak the Mauler (12)
	[14429, Vector2(-1880, -3780), 1.0, 1],    # Gnashmaw (11, rare)
	[2015, Vector2(-2380, -3760), 38.0, 8],    # Crimsonwing Harpy, the Seers' Glade (8-9)
	[2017, Vector2(-2370, -3770), 38.0, 7],    # Crimsonwing Rogue (8-9)
	[2018, Vector2(-2390, -3750), 34.0, 6],    # Crimsonwing Sorceress (9-10)
	[2019, Vector2(-2360, -3740), 34.0, 5],    # Crimsonwing Fury (9-10)
	[2020, Vector2(-2400, -3770), 34.0, 6],    # Crimsonwing Wind Witch (9-10)
	[2021, Vector2(-2390, -3735), 28.0, 6],    # Crimsonwing Matriarch (11-12)
	[14431, Vector2(-2372, -3748), 1.0, 1],    # Fury Selka (8, rare)
	[14428, Vector2(-1600, -4300), 40.0, 1],   # Urgrum (7, rare)
	[14430, Vector2(-2200, -3850), 60.0, 1],   # Gloomprowl (9, rare)
]
## Fel Cones through the woods round Fernwatch, Barkling Sprouts on the lake
## shore, the four chests of the Relics of Wakening in the Thornbarrow Den and
## Tallon's dresser in his bower.
const CHESTS := [
	[1673, Vector2(-2000, -4250), 180.0, 12],
	[4608, LAKE, LAKE_RADIUS + 14.0, 12],
	[2739, Vector2(-2432, -4162), 12.0, 1],
	[2740, Vector2(-2432, -4162), 12.0, 1],
	[2741, Vector2(-2432, -4162), 12.0, 1],
	[2742, Vector2(-2432, -4162), 12.0, 1],
	[126158, Vector2(-2049, -4406), 1.0, 1],
]

const GRASS := Color(0.24, 0.36, 0.3)
const BLUE_GRASS := Color(0.3, 0.33, 0.38)
const MOSS := Color(0.3, 0.42, 0.26)
const PATH := Color(0.42, 0.36, 0.34)
const ROCK := Color(0.36, 0.36, 0.44)
const BARK := Color(0.32, 0.26, 0.3)
const PALE_WOOD := Color(0.6, 0.52, 0.48)
const LEAVES := Color(0.24, 0.4, 0.34)
const DARK_LEAVES := Color(0.2, 0.32, 0.3)
const VIOLET := Color(0.42, 0.3, 0.55)
const TEAL := Color(0.2, 0.45, 0.5)
const MOONWATER := Color(0.55, 0.8, 0.95)
const LOGS := Color(0.38, 0.28, 0.2)

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
	hub_name = "Fernwatch"
	places = PLACES
	spawns = SPAWNS
	chests = CHESTS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_town()
	_build_gloamrock()
	_build_starbreeze()
	_build_den()
	_build_moonwells()
	_build_hold()
	_build_glade()
	_build_gate()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Eldergrove", [], WATER_LEVEL)
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
	height = minf(height, lerpf(-2.0, height, smoothstep(LAKE_RADIUS * 0.7, LAKE_RADIUS, point.distance_to(LAKE))))
	height = lerpf(TOWN_HEIGHT, height, smoothstep(TOWN_FLAT, TOWN_FLAT + 18.0, point.distance_to(TOWN)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2, limit: float) -> float:
	var best := distance_to_pass(point)
	for segment: Array in _road_segments:
		var box: Rect2 = segment[2]
		if box.grow(limit).has_point(point):
			best = minf(best, distance_to_line(point, [segment[0], segment[1]]))
	return best


func _ground_color(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var shade := _detail.get_noise_2d(x, z) * 0.05
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var color := GRASS.lerp(BLUE_GRASS, smoothstep(0.0, 0.5, patch)).lerp(MOSS, smoothstep(-0.1, -0.5, patch))
	color = color.lerp(PATH, (1.0 - smoothstep(TOWN_FLAT - 14.0, TOWN_FLAT - 6.0, point.distance_to(TOWN))) * 0.4)
	for flat: Array in FLATS:
		color = color.lerp(PATH, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.4)
	color = color.lerp(PATH, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point, ROAD_WIDTH + 1.0)))
	color = color.lerp(ROCK, smoothstep(0.84, 0.62, normal.y))
	color = color.lerp(ROCK, smoothstep(26.0, 36.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).
func _cave_mouth(parent: Node3D, at: Vector3, yaw: float, width := 5.0) -> void:
	var mouth := Node3D.new()
	mouth.position = at
	mouth.rotation.y = yaw
	parent.add_child(mouth)
	Props.box(mouth, Vector3(0, 0, 1.0), Vector3(width, 4.0, 2.0), Color(0.04, 0.04, 0.07), 0.0, false)
	for side in [-1, 1]:
		Props.box(mouth, Vector3(side * (width / 2.0 + 0.8), 0, 0), Vector3(1.8, 5.0, 3.0), ROCK)
	Props.box(mouth, Vector3(0, 4.0, 0), Vector3(width + 3.4, 1.6, 3.0), ROCK, 0.0, false)


## An elven bower: a round wooden floor under a sweeping roof on posts.
func _bower(parent: Node3D, at: Vector3, radius: float, roof_color: Color) -> void:
	Props.cylinder(parent, at, radius, 0.4, PALE_WOOD)
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		Props.box(parent, at + Vector3(cos(angle), 0, sin(angle)) * (radius - 0.5), Vector3(0.3, 3.2, 0.3), PALE_WOOD, 0.0, false)
	Props.cylinder(parent, at + Vector3(0, 3.2, 0), radius + 0.8, 1.6, roof_color, false, 0.2)


## A moonwell: a ring of pale stone round still, glowing water.
func _moonwell(parent: Node3D, at: Vector3, radius: float) -> void:
	Props.cylinder(parent, at, radius, 0.7, PALE_WOOD.lightened(0.3))
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius - 0.5
	disc.bottom_radius = radius - 0.5
	disc.height = 0.1
	water.mesh = disc
	var glow := StandardMaterial3D.new()
	glow.albedo_color = MOONWATER
	glow.emission_enabled = true
	glow.emission = MOONWATER
	glow.emission_energy_multiplier = 0.6
	water.material_override = glow
	water.position = at + Vector3(0, 0.72, 0)
	parent.add_child(water)
	var light := OmniLight3D.new()
	light.light_color = MOONWATER
	light.omni_range = radius * 4.0
	light.light_energy = 0.8
	light.position = at + Vector3(0, 2.0, 0)
	parent.add_child(light)


## A bearfolk hut: a cone of leaning logs.
func _log_hut(parent: Node3D, at: Vector3, radius: float) -> void:
	Props.cylinder(parent, at, radius, 3.6, LOGS, true, 0.3)
	Props.box(parent, at + Vector3(0, 0, radius * 0.8), Vector3(1.2, 1.8, 0.4), Color(0.08, 0.06, 0.05), 0.0, false)


# Fernwatch: bowers in a ring round a moonwell, the inn's long bower to the
# north and lanterns on posts.

func _build_town() -> void:
	var town := Node3D.new()
	town.name = "Fernwatch"
	add_child(town)
	var t := TOWN
	var y := TOWN_HEIGHT
	_moonwell(town, _near(t, Vector2(0, 0), y), 3.6)
	Props.box(town, _near(t, Vector2(0, -26), y), Vector3(18, 0.4, 9), PALE_WOOD)
	for post in [Vector2(-8.5, -30), Vector2(8.5, -30), Vector2(-8.5, -22), Vector2(8.5, -22)]:
		Props.box(town, _near(t, post, y), Vector3(0.35, 3.6, 0.35), PALE_WOOD, 0.0, false)
	Props.roof(town, _near(t, Vector2(0, -26), y + 3.6), Vector3(20, 2.6, 11), VIOLET)
	for i in 7:
		var angle := TAU * i / 7.0 + 0.35
		var at := t + Vector2(cos(angle), sin(angle)) * 24.0
		if at.y < t.y - 14.0 and absf(at.x - t.x) < 14.0:
			continue
		_bower(town, Vector3(at.x, y, at.y), 3.6, VIOLET if i % 2 == 0 else TEAL)
	for lamp in [Vector2(-8, 8), Vector2(8, 8), Vector2(-12, -10), Vector2(12, -10), Vector2(0, 30)]:
		Props.box(town, _near(t, lamp, y), Vector3(0.25, 2.4, 0.25), PALE_WOOD, 0.0, false)
		torch(town, _near(t, lamp, y + 2.4), 6.0)


# The Gloamrock: a mossy crag with a cave the sprites have taken.

func _build_gloamrock() -> void:
	var rock := Node3D.new()
	rock.name = "Gloamrock"
	add_child(rock)
	var flat: Array = FLATS[GLOAMROCK]
	_cave_mouth(rock, _near(flat[0], Vector2(6, -14), flat[2]), atan2(6.0, -14.0), 5.0)
	torch(rock, _near(flat[0], Vector2(0, 0), flat[2] + 0.5), 5.0)


# Starbreeze: elven bowers the bearfolk have overrun, their roofs torn.

func _build_starbreeze() -> void:
	var village := Node3D.new()
	village.name = "Starbreeze"
	add_child(village)
	var flat: Array = FLATS[STARBREEZE]
	for i in 5:
		var angle := TAU * i / 5.0 + 0.2
		var at: Vector2 = flat[0] + Vector2(cos(angle), sin(angle)) * 14.0
		if i % 2 == 0:
			_bower(village, Vector3(at.x, flat[2], at.y), 3.2, TEAL.darkened(0.3))
		else:
			Props.cylinder(village, Vector3(at.x, flat[2], at.y), 3.2, 0.4, PALE_WOOD.darkened(0.3))
	_log_hut(village, _near(flat[0], Vector2(0, 0), flat[2]), 3.0)
	torch(village, _near(flat[0], Vector2(4, 4), flat[2] + 0.5), 6.0)


# The Thornbarrow Den: the old druids' barrow, a mound with a stone door, and
# the bearfolk's huts before it.

func _build_den() -> void:
	var den := Node3D.new()
	den.name = "ThornbarrowDen"
	add_child(den)
	var flat: Array = FLATS[DEN]
	_cave_mouth(den, _near(flat[0], Vector2(-12, -12), flat[2]), -PI * 0.75, 6.0)
	for hut in [Vector2(10, 6), Vector2(4, 14), Vector2(14, -6)]:
		_log_hut(den, _near(flat[0], hut, flat[2]), 2.6)
	torch(den, _near(flat[0], Vector2(0, 0), flat[2] + 0.5), 6.0)


# The Moonwells: three wells in a clearing, white stones round them.

func _build_moonwells() -> void:
	var wells := Node3D.new()
	wells.name = "Moonwells"
	add_child(wells)
	var flat: Array = FLATS[MOONWELLS]
	for at in [Vector2(-8, -4), Vector2(8, -4), Vector2(0, 9)]:
		_moonwell(wells, _near(flat[0], at, flat[2]), 3.0)
	for i in 8:
		var angle := TAU * i / 8.0
		Props.box(wells, _near(flat[0], Vector2(cos(angle), sin(angle)) * 18.0, flat[2]), Vector3(1.0, 3.2, 0.8), PALE_WOOD.lightened(0.3), -angle)


# Twistbark Hold: the bearfolk's stronghold, log huts inside a ring of
# sharpened stakes, a great totem in the middle.

func _build_hold() -> void:
	var hold := Node3D.new()
	hold.name = "TwistbarkHold"
	add_child(hold)
	var flat: Array = FLATS[HOLD]
	var h: Vector2 = flat[0]
	for i in 5:
		var angle := TAU * i / 5.0 + 0.6
		_log_hut(hold, _near(h, Vector2(cos(angle), sin(angle)) * 13.0, flat[2]), 3.0)
	var stakes: Array[Transform3D] = []
	for i in 20:
		var angle := TAU * i / 20.0
		if absf(angle - PI * 1.5) < 0.3:
			continue
		var at := h + Vector2(cos(angle), sin(angle)) * 24.0
		stakes.append(Transform3D(Basis(Vector3.FORWARD, 0.25).rotated(Vector3.UP, -angle), Vector3(at.x, flat[2] + 1.2, at.y)))
	Props.scatter(hold, Props.cone(0.3, 2.6, 5), LOGS, stakes)
	totem(hold, h, flat[2], 7.0, [LOGS, Color(0.6, 0.2, 0.15), Color(0.85, 0.75, 0.4)])
	torch(hold, _near(h, Vector2(4, 4), flat[2] + 0.5), 7.0)


# The Seers' Glade: a moonwell under a vast old tree, the harpies' nests in
# its branches.

func _build_glade() -> void:
	var glade := Node3D.new()
	glade.name = "SeersGlade"
	add_child(glade)
	var flat: Array = FLATS[GLADE]
	var g: Vector2 = flat[0]
	Props.cylinder(glade, _near(g, Vector2(0, 8), flat[2] - 1.0), 4.0, 30.0, BARK, true, 2.6)
	var crowns: Array[Transform3D] = []
	for i in 6:
		var angle := TAU * i / 6.0
		crowns.append(Transform3D(Basis().scaled(Vector3(1.4, 0.6, 1.4)), _near(g, Vector2(0, 8) + Vector2(cos(angle), sin(angle)) * 8.0, flat[2] + 26.0 + (i % 2) * 3.0)))
	Props.scatter(glade, Props.blob(7.0), DARK_LEAVES, crowns)
	_moonwell(glade, _near(g, Vector2(0, -10), flat[2]), 3.2)
	var nests: Array[Transform3D] = []
	for i in 6:
		var angle := TAU * i / 6.0 + 0.5
		var at := g + Vector2(cos(angle), sin(angle)) * 16.0
		nests.append(Transform3D(Basis().scaled(Vector3(1.6, 0.5, 1.6)), Vector3(at.x, flat[2] + 0.2, at.y)))
	Props.scatter(glade, Props.blob(1.0, 7, 3), LOGS, nests)


# The Silverbough Gate: a tall arch of pale wood on the road west, where the
# way to the elves' city will open.

func _build_gate() -> void:
	var gate := Node3D.new()
	gate.name = "SilverboughGate"
	add_child(gate)
	var flat: Array = FLATS[GATE]
	var at := _near(flat[0], Vector2(-6, 0), flat[2])
	for side in [-1, 1]:
		Props.cylinder(gate, at + Vector3(0, 0, side * 6), 1.0, 12.0, PALE_WOOD, true, 0.7)
	Props.box(gate, at + Vector3(0, 11, 0), Vector3(2, 1.4, 14), PALE_WOOD, 0.0, false)
	Props.box(gate, at + Vector3(0.6, 0, 0), Vector3(0.6, 10.5, 11), VIOLET.darkened(0.3))
	for lamp in [Vector3(4, 0, -7), Vector3(4, 0, 7)]:
		Props.box(gate, at + lamp, Vector3(0.25, 2.4, 0.25), PALE_WOOD, 0.0, false)
		torch(gate, at + lamp + Vector3(0, 2.4, 0), 6.0)


func _clear(point: Vector2) -> bool:
	if point.distance_to(TOWN) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


## Tall elven trees, thick everywhere: the isle is a forest.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var dark_crowns: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.6
	trunk_shape.height = 6.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 14000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 30.0 or not _clear(point) or rng.randf() > 0.12 + 0.12 * smoothstep(10.0, 18.0, y):
			continue
		var size := rng.randf_range(0.9, 1.6)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		trunks.append(base * Transform3D(Basis(), Vector3(0, 3.0, 0)))
		var crown := base * Transform3D(Basis().scaled(Vector3(1.4, 0.75, 1.4)), Vector3(0, 7.0, 0))
		if rng.randf() < 0.4:
			dark_crowns.append(crown)
		else:
			crowns.append(crown)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 3.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.3
	trunk.bottom_radius = 0.55
	trunk.height = 6.0
	trunk.radial_segments = 6
	add_child(trees)
	Props.scatter(trees, trunk, PALE_WOOD.darkened(0.2), trunks)
	Props.scatter(trees, Props.blob(2.8), LEAVES, crowns)
	Props.scatter(trees, Props.blob(2.8), DARK_LEAVES, dark_crowns)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 2500:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.03 + 0.4 * smoothstep(11.0, 24.0, y) or not _clear(point):
			continue
		var size := Vector3(rng.randf_range(0.6, 2.4), rng.randf_range(0.4, 1.6), rng.randf_range(0.6, 2.4))
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
	var ferns: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 36000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.5 or y > 24.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.07:
			flowers.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.1)), at + Vector3.UP * 0.25))
		else:
			ferns.append(Transform3D(spin.scaled(Vector3(1.3, rng.randf_range(0.8, 1.4), 1.3)), at + Vector3.UP * 0.2))
	add_clutter(clutter, Props.cone(0.22, 0.4, 5), Color(0.26, 0.46, 0.34), ferns)
	add_clutter(clutter, Props.blob(0.1, 5, 3), Color(0.7, 0.8, 0.98), flowers)
