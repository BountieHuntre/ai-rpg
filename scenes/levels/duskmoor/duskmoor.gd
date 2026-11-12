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
const SIZE := 1200.0
const STEP := 2.5
const MOUNTAIN_START := 56.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const ROAD_WIDTH := 2.6
const SEED := 4301

const TOWN := Vector2(-1760, -4180)
const TOWN_HEIGHT := 5.0
const TOWN_FLAT := 40.0
const GRAVEYARD := Vector3(-1786, TOWN_HEIGHT, -4152)
const GRAVEYARD_FACING := -PI / 2

const LAKE := Vector2(-1650, -4450)
const LAKE_RADIUS := 80.0
const LAKE_BED := -0.8

const PLACES := [
	["the Ashworth crypt", Vector2(-2180, -4700), 14.0],
	["the east watch", Vector2(-1300, -4100), 16.0],
	["the Sunward mission", Vector2(-2050, -3800), 20.0],
	["the Ashworth manor", Vector2(-2050, -4650), 20.0],
	["the Grimhide camp", Vector2(-1310, -4380), 24.0],
	["the Sunward watch", Vector2(-2100, -4320), 24.0],
	["the Brannick farm", Vector2(-2150, -3720), 26.0],
	["the Ashworth mills", Vector2(-1950, -4550), 30.0],
	["the Zealot Abbey", Vector2(-1250, -4650), 38.0],
	["Gallowfield", Vector2(-1760, -4180), 42.0],
	["the east barricade", Vector2(-1190, -3980), 45.0],
	["the pass", Vector2(-2265, -4185), 40.0],
	["the Plaguewood farms", Vector2(-1720, -3800), 70.0],
	["Lake Hollowmere", Vector2(-1650, -4450), 95.0],
	["the southeast woods", Vector2(-1300, -3720), 90.0],
]
const FLATS := [
	[Vector2(-1950, -4550), 22.0, 6.0],   # the Ashworth mills
	[Vector2(-2050, -4650), 15.0, 7.0],   # the Ashworth manor
	[Vector2(-2180, -4700), 10.0, 8.0],   # the Ashworth crypt
	[Vector2(-1250, -4650), 30.0, 9.0],   # the Zealot Abbey
	[Vector2(-1300, -4100), 12.0, 6.0],   # the east watch
	[Vector2(-2100, -4320), 18.0, 6.0],   # the Sunward watch
	[Vector2(-2050, -3800), 16.0, 5.0],   # the Sunward mission
	[Vector2(-2150, -3720), 18.0, 4.0],   # the Brannick farm
	[Vector2(-1700, -3800), 30.0, 4.0],   # the Plaguewood farms
	[Vector2(-1310, -4380), 18.0, 7.0],   # the Grimhide camp
	[Vector2(-1190, -3980), 16.0, 5.0],   # the east barricade
]
const MILLS := 0
const MANOR := 1
const CRYPT := 2
const ABBEY := 3
const EAST_WATCH := 4
const SUNWARD_WATCH := 5
const MISSION := 6
const BRANNICK := 7
const PLAGUEWOOD := 8
const GNOLL_CAMP := 9
const BARRICADE := 10
const HILLS := [
	[Vector2(-1250, -4700), 90.0, 14.0],  # the abbey's rise
	[Vector2(-2150, -4720), 70.0, 16.0],  # the crypt's hill
	[Vector2(-1320, -4390), 50.0, 8.0],
	[Vector2(-2000, -4000), 80.0, 7.0],
	[Vector2(-1450, -3850), 70.0, 9.0],
	[Vector2(-1850, -4720), 60.0, 10.0],
]
const PASS_END := Vector2(-2230, -4180)
const ROADS := [
	# The pass road east to Gallowfield, and on east past the gnolls to the abbey.
	[PASS_END, Vector2(-2050, -4180), Vector2(-1802, -4180)],
	[Vector2(-1718, -4182), Vector2(-1600, -4200), Vector2(-1450, -4300), Vector2(-1360, -4470), Vector2(-1265, -4615)],
	[Vector2(-1450, -4300), Vector2(-1325, -4372)],
	# North to the mills, the manor and the crypt.
	[Vector2(-1770, -4222), Vector2(-1850, -4400), Vector2(-1935, -4530)],
	[Vector2(-1965, -4572), Vector2(-2040, -4640), Vector2(-2170, -4695)],
	# South to the Plaguewood farms, and south-west to the mission and the Brannick farm.
	[Vector2(-1758, -4140), Vector2(-1740, -3950), Vector2(-1705, -3828)],
	[Vector2(-1740, -3950), Vector2(-2000, -3850), Vector2(-2040, -3812)],
	[Vector2(-2000, -3850), Vector2(-2135, -3735)],
	# East to the east watch and the barricade.
	[Vector2(-1600, -4200), Vector2(-1400, -4100), Vector2(-1310, -4100)],
	[Vector2(-1400, -4100), Vector2(-1280, -4030), Vector2(-1200, -3985)],
	# The pass road's branch north to the Sunward watch.
	[Vector2(-2120, -4180), Vector2(-2105, -4302)],
]
const SPAWNS := [
	[1535, Vector2(-2100, -4320), 22.0, 10],  # Sunward Warrior, the Sunward watch (6-7)
	[1536, Vector2(-2050, -3800), 20.0, 8],   # Sunward Missionary, the mission (7-8)
	[1662, Vector2(-2052, -3798), 1.0, 1],    # Captain Lisette (9)
	[1537, Vector2(-1320, -4560), 70.0, 12],  # Sunward Zealot, before the abbey (8-9)
	[1538, Vector2(-1245, -4645), 26.0, 8],   # Sunward Friar, the abbey (9-10)
	[1539, Vector2(-1265, -4625), 18.0, 5],   # Sunward Neophyte (10-11)
	[1540, Vector2(-1250, -4660), 14.0, 6],   # Sunward Vanguard (10-11)
	[1665, Vector2(-1250, -4672), 1.0, 1],    # Captain Merrin, at the abbey door (12)
	[1660, Vector2(-1250, -4670), 3.0, 2],    # Sunward Bodyguard
	[1664, Vector2(-1300, -4100), 1.0, 1],    # Captain Vossel, the east watch (11)
	[1538, Vector2(-1305, -4095), 10.0, 3],   # Sunward Friar, with him
	[1520, Vector2(-1950, -4560), 40.0, 10],  # Rattlebone Soldier, the mills (6-7)
	[1522, Vector2(-1900, -4600), 38.0, 10],  # Hollow-Eye Bonecaster (7-8)
	[1523, Vector2(-1990, -4610), 32.0, 8],   # Cracked Skull Soldier (8-9)
	[1657, Vector2(-1955, -4545), 1.0, 1],    # Dorian Ashworth, in the mill (9)
	[1654, Vector2(-2055, -4655), 1.0, 1],    # Gerran Ashworth, the manor (10)
	[1655, Vector2(-2045, -4645), 1.0, 1],    # Nessa Ashworth (10)
	[1656, Vector2(-2060, -4640), 1.0, 1],    # Thomas Ashworth (10)
	[1531, Vector2(-1990, -4590), 40.0, 2],   # Lost Soul (6, rare)
	[1534, Vector2(-2170, -4690), 24.0, 8],   # Wailing Ancestor, the crypt (9-10)
	[1530, Vector2(-2190, -4710), 24.0, 8],   # Rotting Ancestor (10-11)
	[1658, Vector2(-2186, -4704), 1.0, 1],    # Captain Morrow, in the crypt's mouth (12)
	[1543, Vector2(-1575, -4400), 28.0, 8],   # Murkfin Puddlejumper, the lake (7-8)
	[1544, Vector2(-1720, -4500), 28.0, 6],   # Murkfin Oracle (8-9)
	[1545, Vector2(-1600, -4520), 28.0, 8],   # Murkfin Muckdweller (9-10)
	[1958, Vector2(-1730, -4390), 24.0, 5],   # Murkfin Tidecaller (9-10)
	[1957, Vector2(-1565, -4480), 24.0, 5],   # Murkfin Shorecreeper (9-10)
	[1909, Vector2(-1680, -4370), 22.0, 4],   # Murkfin Lakestalker (10-11)
	[1910, Vector2(-1700, -4520), 1.0, 1],    # Mudgill (10, rare)
	[1525, Vector2(-1650, -3820), 55.0, 10],  # Rotting Dead, the Plaguewood farms (5-6)
	[1526, Vector2(-1800, -3780), 45.0, 10],  # Ravaged Corpse (6-7)
	[1934, Vector2(-2150, -3720), 20.0, 6],   # Duskmoor Farmer, the Brannick farm (6-7)
	[1935, Vector2(-2140, -3710), 16.0, 5],   # Duskmoor Farmhand (5-6)
	[1936, Vector2(-2152, -3722), 1.0, 1],    # Farmer Brannick (8)
	[1674, Vector2(-1310, -4380), 18.0, 8],   # Grimhide Gnoll, their camp (6-7)
	[1941, Vector2(-1360, -4420), 30.0, 10],  # Grimhide Graverobber (6-7)
	[1675, Vector2(-1290, -4350), 20.0, 6],   # Grimhide Mongrel (7-8)
	[1753, Vector2(-1305, -4385), 1.0, 1],    # Rotjaw (10)
	[1529, Vector2(-1210, -3950), 28.0, 8],   # Bleeding Horror, the east barricade (9-10)
	[1532, Vector2(-1220, -4020), 28.0, 8],   # Wandering Spirit (10-11)
	[1547, Vector2(-1960, -4100), 80.0, 10],  # Decrepit Darkhound (5-6)
	[1548, Vector2(-1500, -4000), 90.0, 10],  # Cursed Darkhound (7-8)
	[1549, Vector2(-1350, -3800), 50.0, 6],   # Ravenous Darkhound (9-10)
	[10356, Vector2(-1500, -4000), 60.0, 1],  # Grimfang (10, rare)
	[1553, Vector2(-1450, -4250), 70.0, 8],   # Greater Gloombat (6-7)
	[1554, Vector2(-1900, -3950), 70.0, 8],   # Vampiric Gloombat (8-9)
	[10357, Vector2(-1900, -3950), 50.0, 1],  # Old Needlewing (11, rare)
	[1555, Vector2(-1300, -3720), 50.0, 8],   # Vicious Duskweb Spider, the southeast woods (9-10)
]
## Chests: Duskmoor Pumpkins in the Plaguewood fields, Gloom Weed round
## Gallowfield's graveyard and Doom Weed below the abbey's rise.
const CHESTS := [
	[375, Vector2(-1700, -3795), 30.0, 10],
	[175566, Vector2(-1840, -4250), 40.0, 8],
	[176753, Vector2(-1400, -4520), 45.0, 8],
]

const GRASS := Color(0.4, 0.45, 0.33)
const DEAD_GRASS := Color(0.5, 0.47, 0.36)
const FIELD := Color(0.42, 0.36, 0.26)
const SOIL := Color(0.3, 0.27, 0.23)
const PATH := Color(0.47, 0.45, 0.42)
const MUD := Color(0.33, 0.31, 0.27)
const ROCK := Color(0.42, 0.41, 0.4)
const STONE := Color(0.55, 0.54, 0.52)
const DARK_STONE := Color(0.36, 0.35, 0.35)
const BARK := Color(0.24, 0.2, 0.17)
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


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
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
	spawn_creatures(SEED + 3, "Dusk", [], WATER_LEVEL)
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
	height = lerpf(TOWN_HEIGHT, height, smoothstep(TOWN_FLAT, TOWN_FLAT + 18.0, point.distance_to(TOWN)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, point.distance_to(flat[0])))
	var lake := point.distance_to(LAKE)
	height = minf(height, lerpf(LAKE_BED, height, smoothstep(LAKE_RADIUS, LAKE_RADIUS + 22.0, lake)))
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
	var shade := _detail.get_noise_2d(x, z) * 0.06
	var patch := Zone.land_noise().get_noise_2d(x * 2.1, z * 2.1)
	var color := GRASS.lerp(DEAD_GRASS, smoothstep(0.0, 0.35, patch))
	var farms: Array = FLATS[PLAGUEWOOD]
	color = color.lerp(FIELD, (1.0 - smoothstep(farms[1] + 20.0, farms[1] + 40.0, point.distance_to(farms[0]))) * 0.9)
	color = color.lerp(SOIL, 1.0 - smoothstep(TOWN_FLAT - 6.0, TOWN_FLAT, point.distance_to(TOWN)))
	for flat: Array in FLATS:
		color = color.lerp(SOIL, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.7)
	color = color.lerp(PATH, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point, ROAD_WIDTH + 1.0)))
	color = color.lerp(MUD, 1.0 - smoothstep(2.0, 3.6, y))
	color = color.lerp(ROCK, smoothstep(0.84, 0.66, normal.y))
	color = color.lerp(ROCK, smoothstep(22.0, 32.0, y))
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A timbered house: plaster walls with dark beams under a steep dark roof.
func _house(parent: Node3D, at: Vector3, size: Vector3, yaw := 0.0) -> void:
	Props.box(parent, at, size, PLASTER, yaw)
	Props.roof(parent, at + Vector3(0, size.y, 0), Vector3(size.x + 1, size.y * 0.7, size.z + 1), ROOF, yaw)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var c := Vector2(corner.x * size.x / 2, corner.y * size.z / 2).rotated(-yaw)
		Props.box(parent, at + Vector3(c.x, 0, c.y), Vector3(0.35, size.y, 0.35), TIMBER, yaw, false)


func _grave(parent: Node3D, at: Vector2, y: float, rng: RandomNumberGenerator) -> void:
	var yaw := rng.randf_range(-0.2, 0.2)
	var stone := Props.box(parent, Vector3(at.x, y, at.y), Vector3(0.9, 1.1 + rng.randf() * 0.5, 0.25), DARK_STONE, yaw, false)
	stone.rotation.x = rng.randf_range(-0.25, 0.15)


# Gallowfield: timbered houses round a crossroads, the inn, the graveyard and
# a gallows on the green.

func _build_town() -> void:
	var town := Node3D.new()
	town.name = "Gallowfield"
	add_child(town)
	var t := TOWN
	var y := TOWN_HEIGHT
	_house(town, _near(t, Vector2(18, -14), y), Vector3(10, 6, 14))   # the inn
	Props.box(town, _near(t, Vector2(12.9, -12), y), Vector3(0.3, 2.6, 1.6), TIMBER, 0.0, false)
	_house(town, _near(t, Vector2(-14, -22), y), Vector3(9, 5, 7))
	_house(town, _near(t, Vector2(-22, 14), y), Vector3(7, 4, 7), PI / 2)
	_house(town, _near(t, Vector2(16, 18), y), Vector3(8, 4, 7))
	_house(town, _near(t, Vector2(2, -26), y), Vector3(8, 5, 6))
	# The gallows on the green.
	for post in [Vector2(-3, 6), Vector2(3, 6)]:
		Props.box(town, _near(t, post, y), Vector3(0.4, 4.6, 0.4), TIMBER)
	Props.box(town, _near(t, Vector2(0, 6), y + 4.4), Vector3(6.6, 0.4, 0.4), TIMBER, 0.0, false)
	Props.box(town, _near(t, Vector2(0, 6), y + 1.2), Vector3(4, 0.2, 2.4), WOOD)
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
	_house(mills, _near(m, Vector2(-6, 0), y), Vector3(10, 6, 8))
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
	_house(manor, _near(flat[0], Vector2(0, -4), flat[2]), Vector3(14, 8, 10))
	Props.box(manor, _near(flat[0], Vector2(0, 1.2), flat[2]), Vector3(2.2, 3.2, 0.3), TIMBER, 0.0, false)


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
	Props.box(abbey, _near(a, Vector2(0, -8), y), Vector3(22, 12, 16), STONE)
	Props.roof(abbey, _near(a, Vector2(0, -8), y + 12), Vector3(23, 6, 17), TENT_RED)
	Props.box(abbey, _near(a, Vector2(-9, -12), y), Vector3(6, 22, 6), STONE)
	Props.roof(abbey, _near(a, Vector2(-9, -12), y + 22), Vector3(6.6, 5, 6.6), TENT_RED)
	Props.box(abbey, _near(a, Vector2(0, 0.1), y), Vector3(3.4, 5, 0.3), WOOD, 0.0, false)
	for side in [-1, 1]:
		Props.box(abbey, _near(a, Vector2(side * 16, 6), y), Vector3(1.2, 4, 20), STONE)
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
	_house(farms, _near(plague[0], Vector2(-14, -10), plague[2]), Vector3(9, 5, 7))
	_house(farms, _near(plague[0], Vector2(14, -14), plague[2]), Vector3(7, 4, 10), PI / 2)
	var pumpkins: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 9
	for row in 6:
		for col in 10:
			var at: Vector2 = plague[0] + Vector2(-18 + col * 4.0 + rng.randf_range(-1, 1), 4 + row * 3.5)
			pumpkins.append(Transform3D(Basis().scaled(Vector3(1, 0.75, 1) * rng.randf_range(0.7, 1.1)), Vector3(at.x, height_at(at.x, at.y) + 0.25, at.y)))
	Props.scatter(farms, Props.blob(0.45, 7, 4), PUMPKIN, pumpkins)
	var brannick: Array = FLATS[BRANNICK]
	_house(farms, _near(brannick[0], Vector2(0, -6), brannick[2]), Vector3(10, 5, 8))
	Props.roof(farms, _near(brannick[0], Vector2(12, 4), brannick[2]), Vector3(8, 4, 6), ROOF)


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
	if point.distance_to(TOWN) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	if point.distance_to(LAKE) < LAKE_RADIUS + 8.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


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
	var edge := SIZE / 2.0 - 10.0
	for attempt in 16000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 28.0 or not _clear(point):
			continue
		# Thicker in the southeast woods and on the hills.
		var woods := 1.0 - smoothstep(60.0, 110.0, point.distance_to(Vector2(-1300, -3720)))
		if rng.randf() > 0.05 + 0.25 * woods + 0.15 * smoothstep(8.0, 16.0, y):
			continue
		var size := rng.randf_range(0.8, 1.3)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		if rng.randf() < 0.6:
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
	var edge := SIZE / 2.0 - 6.0
	for attempt in 4000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.04 + 0.4 * smoothstep(9.0, 20.0, y) or not _clear(point):
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
	var grass: Array[Transform3D] = []
	var mushrooms: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 36000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.5 or y > 22.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.05:
			mushrooms.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), at + Vector3.UP * 0.12))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.16, 0.32, 4), Color(0.45, 0.48, 0.34), grass)
	add_clutter(clutter, Props.blob(0.12, 5, 3), Color(0.55, 0.42, 0.55), mushrooms)
