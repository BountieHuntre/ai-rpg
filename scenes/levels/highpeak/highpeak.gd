class_name Highpeak
extends Zone
## The Dwarves' and Gnomes' second zone, standing in for classic's Dun Morogh:
## snowy pine valleys 1200 yards across under the mountains, for levels 6 to
## 12, east of Frosthollow over the Frozen Stair. Kettlefold, the dwarves'
## village of stone houses and the Thornbrew inn, stands in the middle;
## Steelgrip's Depot and its gnome pilots are east of it and the Amberfield
## ram ranch beyond, with the Grey Quarry of the Stonejaw troggs in the
## south-east and the shut Southgate on the eastern edge. To the west the
## Icemane trolls hold Icemane Hold, their seers pick shimmerweed on Shimmer
## Ridge south of it, and the wendigos lair in the Grizzled Den north-west of
## the village. The Icewater Tarn lies in the north with Barleyhall on its
## shore, the ruined Cogworks of the blighted gnomes in the north-west corner,
## and the road north ends at the great gate of Anvilhold. Built in code, in
## world coordinates. -Z is north.

const ZONE_NAME := "Highpeak"
const CENTER := Vector2(-100, -800)
const SIZE := 1200.0
const STEP := 2.5
const MOUNTAIN_START := 56.0
const MOUNTAIN_FULL := 6.0
const WATER_LEVEL := 1.4
const ROAD_WIDTH := 2.6
const SEED := 5201

const TOWN := Vector2(-150, -780)
const TOWN_HEIGHT := 7.0
const TOWN_FLAT := 42.0
const GRAVEYARD := Vector3(-150, TOWN_HEIGHT, -748)
const GRAVEYARD_FACING := 0.0
const TARN := Vector2(-440, -1200)
const TARN_RADIUS := 70.0

const PLACES := [
	["Old Rimebeard's cave", Vector2(-268, -1098), 10.0],
	["the Southgate", Vector2(452, -900), 22.0],
	["the Anvilhold Gate", Vector2(-330, -1360), 24.0],
	["Steelgrip's Depot", Vector2(60, -830), 24.0],
	["Barleyhall", Vector2(-330, -1215), 24.0],
	["the Grizzled Den", Vector2(-290, -1080), 30.0],
	["Amberfield Ranch", Vector2(230, -650), 30.0],
	["Shimmer Ridge", Vector2(-380, -420), 30.0],
	["Icemane Hold", Vector2(-530, -570), 34.0],
	["the Cogworks", Vector2(-600, -1300), 36.0],
	["the Grey Quarry", Vector2(330, -360), 40.0],
	["Kettlefold", Vector2(-150, -780), 44.0],
	["the Frozen Stair", Vector2(-660, -965), 40.0],
	["the Icewater Tarn", TARN, 80.0],
	["the eastern pines", Vector2(250, -1050), 180.0],
	["the southern vales", Vector2(-50, -400), 180.0],
	["the western snows", Vector2(-400, -850), 160.0],
]
const FLATS := [
	[Vector2(60, -830), 18.0, 7.0],      # Steelgrip's Depot
	[Vector2(230, -650), 22.0, 6.0],     # Amberfield Ranch
	[Vector2(330, -360), 30.0, 4.0],     # the Grey Quarry, dug down
	[Vector2(-530, -570), 24.0, 9.0],    # Icemane Hold
	[Vector2(-380, -420), 14.0, 12.0],   # Shimmer Ridge, on its ridge
	[Vector2(-290, -1080), 18.0, 8.0],   # the Grizzled Den
	[Vector2(-330, -1215), 18.0, 4.0],   # Barleyhall, on the tarn's shore
	[Vector2(-600, -1300), 26.0, 8.0],   # the Cogworks
	[Vector2(-330, -1360), 16.0, 9.0],   # the Anvilhold Gate
	[Vector2(452, -900), 14.0, 8.0],     # the Southgate
	[Vector2(400, -990), 8.0, 7.0],      # the downed pilot's wreck
]
const DEPOT := 0
const RANCH := 1
const QUARRY := 2
const HOLD := 3
const RIDGE := 4
const DEN := 5
const BARLEYHALL := 6
const COGWORKS := 7
const GATE := 8
const SOUTHGATE := 9
const WRECK := 10
const HILLS := [
	[Vector2(-380, -420), 45.0, 10.0],   # Shimmer Ridge
	[Vector2(-560, -540), 60.0, 16.0],   # the cliffs behind Icemane Hold
	[Vector2(-268, -1120), 26.0, 14.0],  # Old Rimebeard's knoll
	[Vector2(-640, -1340), 60.0, 14.0],
	[Vector2(380, -330), 60.0, 10.0],    # the quarry's rim
	[Vector2(100, -1150), 90.0, 10.0],
	[Vector2(-60, -500), 80.0, 8.0],
]
const PASS_END := Vector2(-630, -970)
const ROADS := [
	# The Frozen Stair down into Kettlefold, and on east to the depot.
	[PASS_END, Vector2(-500, -930), Vector2(-330, -850), Vector2(-190, -790)],
	[Vector2(-110, -790), Vector2(-10, -815), Vector2(44, -828)],
	# North to Barleyhall and the Anvilhold Gate.
	[Vector2(-170, -820), Vector2(-240, -980), Vector2(-310, -1196)],
	[Vector2(-240, -980), Vector2(-300, -1180), Vector2(-330, -1344)],
	# The Cogworks, off the gate road.
	[Vector2(-330, -1300), Vector2(-450, -1310), Vector2(-574, -1300)],
	# East past the ranch to the Southgate; south-east to the quarry.
	[Vector2(76, -830), Vector2(220, -860), Vector2(360, -890), Vector2(438, -900)],
	[Vector2(-120, -750), Vector2(60, -700), Vector2(210, -660)],
	[Vector2(240, -630), Vector2(300, -500), Vector2(320, -390)],
	# South-west to Icemane Hold and Shimmer Ridge.
	[Vector2(-180, -750), Vector2(-350, -650), Vector2(-506, -580)],
	[Vector2(-350, -650), Vector2(-380, -434)],
]
const SPAWNS := [
	[1125, Vector2(-260, -690), 80.0, 10],   # Crag Boar (5-6)
	[1125, Vector2(-40, -950), 70.0, 8],
	[1128, Vector2(-200, -1000), 70.0, 8],   # Young Black Bear (5-6)
	[1199, Vector2(-460, -850), 60.0, 7],    # Juvenile Snow Leopard (5-6)
	[1126, Vector2(110, -1000), 90.0, 9],    # Large Crag Boar (6-7)
	[1138, Vector2(-400, -700), 60.0, 6],    # Snow Tracker Wolf (6-7)
	[1131, Vector2(-80, -1160), 90.0, 9],    # Winter Wolf (7-8)
	[1127, Vector2(150, -560), 100.0, 10],   # Elder Crag Boar (7-8)
	[1127, Vector2(380, -760), 70.0, 6],
	[1196, Vector2(260, -1100), 100.0, 9],   # Ice Claw Bear (7-8)
	[1201, Vector2(-20, -480), 100.0, 9],    # Snow Leopard (7-8)
	[1201, Vector2(-520, -1000), 60.0, 5],
	[1133, Vector2(-40, -1260), 40.0, 3],    # Starving Winter Wolf (8)
	[1132, Vector2(10, -1250), 50.0, 1],     # Old Greyfang (10, rare)
	[1134, Vector2(-310, -1060), 30.0, 6],   # Young Wendigo, the Grizzled Den (5-6)
	[1135, Vector2(-285, -1080), 30.0, 8],   # Wendigo (6-7)
	[1137, Vector2(-276, -1092), 1.0, 1],    # Ulfar the Howler (9, rare)
	[1271, Vector2(-268, -1094), 1.0, 1],    # Old Rimebeard, at his cave (11)
	[1120, Vector2(-500, -590), 36.0, 7],    # Icemane Troll, Icemane Hold (7-8)
	[1123, Vector2(-530, -560), 30.0, 7],    # Icemane Headhunter (8-9)
	[1122, Vector2(-552, -545), 20.0, 5],    # Icemane Hideskinner (9-10)
	[1124, Vector2(-540, -600), 26.0, 5],    # Icemane Shadowcaster (9-10)
	[1121, Vector2(-420, -660), 60.0, 5],    # Icemane Snowstrider (8-9)
	[1260, Vector2(-560, -535), 1.0, 1],     # Great Father Hrimnar (11, rare)
	[1397, Vector2(-380, -420), 26.0, 7],    # Icemane Seer, Shimmer Ridge (8-9)
	[1211, Vector2(-595, -1290), 36.0, 10],  # Blighted Gnome, the Cogworks (8-9)
	[8503, Vector2(-612, -1312), 1.0, 1],    # Gibbletock (11, rare)
	[1115, Vector2(300, -400), 36.0, 8],     # Stonejaw Skullthumper, the Grey Quarry (8-9)
	[1117, Vector2(350, -350), 36.0, 10],    # Stonejaw Bonesnapper (9-10)
	[1116, Vector2(310, -330), 26.0, 5],     # Stonejaw Ambusher (9-10)
	[1118, Vector2(360, -320), 18.0, 3],     # Stonejaw Backbreaker (11)
	[1119, Vector2(372, -312), 1.0, 1],      # Skullgrinder (12, rare)
	[1689, Vector2(300, -520), 60.0, 6],     # Scarred Crag Boar (9-10)
	[1388, Vector2(262, -612), 1.0, 1],      # Vaskar, by the ranch (11)
	[1961, Vector2(425, -1010), 1.0, 1],     # Scabclaw, by the wreck (11)
	[1130, Vector2(120, -1220), 60.0, 1],    # Rimeclaw (12, rare)
]
## A Dwarven Corpse: the lost pilot, by her wrecked flying machine.
const QUEST_OBJECTS := [
	[2059, "HildrasCorpse", Vector2(404, -986), 0.6],
	[269, "GuardedBarrel", BARREL, 0.0],
	[270, "UnguardedBarrel", BARREL, 0.0],
]
## The Thunder Ale barrel beside the inn: guarded by Jarvik Kegsworth until a
## Thunder Ale (Distracting Jarvik) draws him off to the inn door for
## UNGUARDED_TIME, while the unguarded barrel (Bitter Rivals' end, Return to
## Maddoc's start) stands there instead, as classic's script swaps them.
const BARREL := Vector2(-134, -808)
const JARVIK_POST := Vector3(-130, 7, -805)
const JARVIK_DRINKING := Vector3(-146, 7, -797)
const UNGUARDED_TIME := 90.0
## Mackellen's Meat Locker in Old Rimebeard's cave, the Shimmerweed Baskets on
## Shimmer Ridge and the Ammo Crate in the quarry.
const CHESTS := [
	[272, Vector2(-262, -1092), 1.0, 1],
	[276, Vector2(-380, -420), 18.0, 5],
	[176785, Vector2(362, -334), 2.0, 1],
]

const SNOW := Color(0.8, 0.82, 0.87)
const BLUE_SNOW := Color(0.64, 0.7, 0.82)
const PATH := Color(0.56, 0.5, 0.44)
const ROCK := Color(0.46, 0.46, 0.5)
const QUARRY_ROCK := Color(0.52, 0.48, 0.44)
const STONE := Color(0.55, 0.53, 0.5)
const DARK_STONE := Color(0.36, 0.35, 0.36)
const SLATE := Color(0.3, 0.32, 0.38)
const TIMBER := Color(0.4, 0.28, 0.18)
const CANVAS := Color(0.62, 0.55, 0.42)
const BRASS := Color(0.7, 0.55, 0.25)
const IRON := Color(0.32, 0.32, 0.34)
const PINE := Color(0.2, 0.34, 0.28)

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
	hub_name = "Kettlefold"
	places = PLACES
	spawns = SPAWNS
	quest_objects = QUEST_OBJECTS
	chests = CHESTS


func _ready() -> void:
	build_ground(STEP, _ground_color)
	build_water(WATER_LEVEL)
	build_edges()
	_build_village()
	_build_depot()
	_build_ranch()
	_build_quarry()
	_build_hold()
	_build_den()
	_build_barleyhall()
	_build_cogworks()
	_build_gates()
	_build_wreck()
	_build_trees()
	_build_rocks()
	_build_clutter()
	spawn_creatures(SEED + 3, "Highpeak", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)
	_guard_barrel(true)
	GameState.quest_turned_in.connect(func(id: int) -> void:
		if id == 308:
			_unguarded_left = UNGUARDED_TIME
			_guard_barrel(false))


var _unguarded_left := 0.0


func _process(delta: float) -> void:
	if _unguarded_left > 0.0:
		_unguarded_left -= delta
		if _unguarded_left <= 0.0:
			_guard_barrel(true)


## Jarvik at his post with the guarded barrel, or off drinking at the inn door
## with the unguarded one there.
func _guard_barrel(guarded: bool) -> void:
	var objects := get_node_or_null("Objects")
	if objects:
		objects.get_node("GuardedBarrel").set_present(guarded)
		objects.get_node("UnguardedBarrel").set_present(not guarded)
	var jarvik := get_node_or_null("JarvikKegsworth") as Node3D
	if jarvik:
		jarvik.position = JARVIK_POST if guarded else JARVIK_DRINKING
		jarvik.rotation.y = PI / 2 if guarded else PI


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z) + 1.5
	var offset := point - CENTER
	var reach := lerpf(offset.length(), maxf(absf(offset.x), absf(offset.y)), 0.6)
	var half := SIZE / 2.0
	height += mountain_height(x, z, smoothstep(half - MOUNTAIN_START, half - MOUNTAIN_FULL, reach))
	for hill: Array in HILLS:
		height += hill[2] * _bump(point.distance_to(hill[0]) / hill[1])
	height = minf(height, lerpf(-2.0, height, smoothstep(TARN_RADIUS * 0.7, TARN_RADIUS, point.distance_to(TARN))))
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
	var shade := _detail.get_noise_2d(x, z) * 0.04
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var color := SNOW.lerp(BLUE_SNOW, smoothstep(0.0, 0.5, patch))
	color = color.lerp(PATH, (1.0 - smoothstep(TOWN_FLAT - 12.0, TOWN_FLAT - 4.0, point.distance_to(TOWN))) * 0.7)
	var quarry: Array = FLATS[QUARRY]
	color = color.lerp(QUARRY_ROCK, 1.0 - smoothstep(quarry[1] - 4.0, quarry[1] + 8.0, point.distance_to(quarry[0])))
	for flat: Array in FLATS:
		color = color.lerp(PATH, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, point.distance_to(flat[0]))) * 0.4)
	color = color.lerp(PATH, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.0, _road_distance(point, ROAD_WIDTH + 1.0)))
	color = color.lerp(Color(0.6, 0.66, 0.72), 1.0 - smoothstep(WATER_LEVEL, WATER_LEVEL + 1.0, y))
	color = color.lerp(ROCK, smoothstep(0.82, 0.6, normal.y))
	color = color.lerp(SNOW, smoothstep(32.0, 42.0, y) * 0.8)
	return Color(color.r + shade, color.g + shade, color.b + shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A dwarven house: stone walls under a slate roof, a chimney at one end.
func _house(parent: Node3D, at: Vector3, length: float, depth: float, yaw := 0.0) -> void:
	Props.box(parent, at, Vector3(length, 4.2, depth), STONE, yaw)
	Props.roof(parent, at + Vector3(0, 4.2, 0), Vector3(length + 1.0, 2.6, depth + 1.0), SLATE, yaw)
	var chimney := Vector3(cos(yaw), 0, -sin(yaw)) * (length / 2.0 - 1.0)
	Props.box(parent, at + chimney + Vector3(0, 4.2, 0), Vector3(1.2, 3.6, 1.2), DARK_STONE, yaw, false)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).
func _cave_mouth(parent: Node3D, at: Vector3, yaw: float, width := 5.0) -> void:
	var mouth := Node3D.new()
	mouth.position = at
	mouth.rotation.y = yaw
	parent.add_child(mouth)
	Props.box(mouth, Vector3(0, 0, 1.0), Vector3(width, 4.0, 2.0), Color(0.06, 0.06, 0.08), 0.0, false)
	for side in [-1, 1]:
		Props.box(mouth, Vector3(side * (width / 2.0 + 0.8), 0, 0), Vector3(1.8, 5.0, 3.0), ROCK)
	Props.box(mouth, Vector3(0, 4.0, 0), Vector3(width + 3.4, 1.6, 3.0), ROCK, 0.0, false)


## A great dwarven gate: two towers, a lintel and shut iron doors, facing `yaw`.
func _great_gate(parent: Node3D, at: Vector3, yaw: float) -> void:
	var gate := Node3D.new()
	gate.position = at
	gate.rotation.y = yaw
	parent.add_child(gate)
	for side in [-1, 1]:
		Props.box(gate, Vector3(side * 8, 0, 0), Vector3(5, 14, 6), DARK_STONE)
		Props.roof(gate, Vector3(side * 8, 14, 0), Vector3(6, 3, 7), SLATE)
	Props.box(gate, Vector3(0, 10, 0), Vector3(11, 3, 5), DARK_STONE, 0.0, false)
	Props.box(gate, Vector3(0, 0, 0.5), Vector3(11, 10, 1.0), IRON)
	for brazier in [-12, 12]:
		Props.cylinder(gate, Vector3(brazier, 0, -4), 0.7, 1.2, DARK_STONE, false, 0.9)
		torch(gate, Vector3(brazier, 1.2, -4), 8.0)


# Kettlefold: stone houses round a yard, the Thornbrew inn to the north, a
# smithy, a well, and the graveyard's cairns south of the yard.

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Kettlefold"
	add_child(village)
	var t := TOWN
	var y := TOWN_HEIGHT
	# The inn, the biggest house, with a brew kettle by its door.
	_house(village, _near(t, Vector2(0, -26), y), 22.0, 12.0)
	Props.cylinder(village, _near(t, Vector2(14, -18), y), 1.6, 2.2, BRASS)
	_house(village, _near(t, Vector2(-28, -6), y), 12.0, 9.0, PI / 2)
	_house(village, _near(t, Vector2(28, -8), y), 10.0, 8.0, PI / 2)
	_house(village, _near(t, Vector2(-26, 22), y), 10.0, 8.0)
	# The smithy: a forge and anvil under a lean-to.
	Props.box(village, _near(t, Vector2(26, 16), y), Vector3(3, 2, 3), DARK_STONE)
	Props.box(village, _near(t, Vector2(26, 16), y + 2), Vector3(1.6, 3.4, 1.6), DARK_STONE, 0.0, false)
	Props.box(village, _near(t, Vector2(22, 20), y), Vector3(1.2, 0.9, 0.6), IRON)
	Props.roof(village, _near(t, Vector2(25, 18), y + 3.4), Vector3(8, 1.6, 7), SLATE)
	torch(village, _near(t, Vector2(26, 17.6), y + 2.0), 6.0)
	# The well and the yard's braziers.
	Props.cylinder(village, _near(t, Vector2(0, 0), y), 1.3, 1.0, STONE)
	for side in [-1, 1]:
		Props.box(village, _near(t, Vector2(side * 1.1, 0), y), Vector3(0.2, 2.4, 0.2), TIMBER, 0.0, false)
	Props.roof(village, _near(t, Vector2(0, 0), y + 2.4), Vector3(3, 0.9, 2.4), SLATE)
	for brazier in [Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12)]:
		Props.cylinder(village, _near(t, brazier, y), 0.6, 1.0, DARK_STONE, false, 0.8)
		torch(village, _near(t, brazier, y + 1.0), 7.0)
	for cairn in [Vector2(-6, 38), Vector2(0, 40), Vector2(6, 38)]:
		Props.cylinder(village, _near(t, cairn, y), 0.7, 0.8, DARK_STONE, false, 0.3)


# Steelgrip's Depot: a hangar of brass and iron with a flying machine before it.

func _build_depot() -> void:
	var depot := Node3D.new()
	depot.name = "Depot"
	add_child(depot)
	var flat: Array = FLATS[DEPOT]
	var d: Vector2 = flat[0]
	var y: float = flat[2]
	Props.box(depot, _near(d, Vector2(0, -8), y), Vector3(14, 6, 9), STONE)
	Props.roof(depot, _near(d, Vector2(0, -8), y + 6), Vector3(15, 2.4, 10), IRON)
	_flying_machine(depot, _near(d, Vector2(2, 6), y), 0.4)
	Props.box(depot, _near(d, Vector2(-8, 4), y), Vector3(1.4, 1.2, 1.4), TIMBER)
	torch(depot, _near(d, Vector2(-5, -2), y + 0.6), 6.0)


## A gnomish flying machine: a brass body, stubby wings and a propeller.
func _flying_machine(parent: Node3D, at: Vector3, yaw: float, wrecked := false) -> void:
	var craft := Node3D.new()
	craft.position = at
	craft.rotation = Vector3(0.3 if wrecked else 0.0, yaw, 0.4 if wrecked else 0.0)
	parent.add_child(craft)
	Props.box(craft, Vector3(0, 0.6, 0), Vector3(1.8, 1.4, 4.0), BRASS)
	Props.box(craft, Vector3(0, 1.4, 0.4), Vector3(6.0 if not wrecked else 3.0, 0.2, 1.4), CANVAS, 0.0, false)
	Props.box(craft, Vector3(0, 1.2, -2.2), Vector3(0.2, 2.2, 0.2), IRON, 0.0, false)


# Amberfield Ranch: a farmhouse, a barn and fenced pens for the rams.

func _build_ranch() -> void:
	var ranch := Node3D.new()
	ranch.name = "Ranch"
	add_child(ranch)
	var flat: Array = FLATS[RANCH]
	var r: Vector2 = flat[0]
	var y: float = flat[2]
	_house(ranch, _near(r, Vector2(-8, -8), y), 10.0, 8.0)
	Props.box(ranch, _near(r, Vector2(10, -6), y), Vector3(10, 5, 8), TIMBER)
	Props.roof(ranch, _near(r, Vector2(10, -6), y + 5), Vector3(11, 3, 9), SLATE)
	for i in 8:
		var at := r + Vector2(-12 + i * 3.4, 12)
		Props.box(ranch, Vector3(at.x, y, at.y), Vector3(0.25, 1.2, 0.25), TIMBER, 0.0, false)
	Props.box(ranch, _near(r, Vector2(0, 12), y + 0.9), Vector3(24, 0.15, 0.15), TIMBER, 0.0, false)


# The Grey Quarry: terraces cut into the rim, trogg-dug burrows and a crane.

func _build_quarry() -> void:
	var quarry := Node3D.new()
	quarry.name = "Quarry"
	add_child(quarry)
	var flat: Array = FLATS[QUARRY]
	var q: Vector2 = flat[0]
	var y: float = flat[2]
	var blocks: Array[Transform3D] = []
	for i in 10:
		var angle := TAU * i / 10.0
		var at := q + Vector2(cos(angle), sin(angle)) * 22.0
		blocks.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3(2.0, 1.4, 1.4)), Vector3(at.x, y + 0.7, at.y)))
	Props.scatter(quarry, BoxMesh.new(), QUARRY_ROCK, blocks)
	for burrow in [Vector2(-18, 18), Vector2(16, 22), Vector2(26, -6)]:
		_cave_mouth(quarry, _near(q, burrow, y), atan2(burrow.x, burrow.y), 4.0)
	Props.box(quarry, _near(q, Vector2(-6, -20), y), Vector3(0.6, 9, 0.6), TIMBER, 0.0, false)
	Props.box(quarry, _near(q, Vector2(-3, -20), y + 8.6), Vector3(7, 0.4, 0.4), TIMBER, 0.0, false)
	# The dwarves' camp at the quarry's edge.
	Props.roof(quarry, _near(q, Vector2(-26, -18), y), Vector3(4, 2.6, 4.5), CANVAS, 0.6)
	torch(quarry, _near(q, Vector2(-22, -14), y + 0.6), 6.0)


# Icemane Hold: hide huts and bone fences before a cave in the cliff.

func _build_hold() -> void:
	var hold := Node3D.new()
	hold.name = "IcemaneHold"
	add_child(hold)
	var flat: Array = FLATS[HOLD]
	var h: Vector2 = flat[0]
	var y: float = flat[2]
	_cave_mouth(hold, _near(h, Vector2(-14, 14), y), -PI / 4.0, 6.0)
	for i in 4:
		var angle := TAU * i / 4.0 + 0.4
		var at := h + Vector2(cos(angle), sin(angle)) * 12.0
		Props.roof(hold, Vector3(at.x, y, at.y), Vector3(4.4, 2.8, 4.0), Color(0.6, 0.6, 0.62), -angle)
	var spikes: Array[Transform3D] = []
	for i in 12:
		var angle := TAU * i / 12.0
		var at := h + Vector2(cos(angle), sin(angle)) * 21.0
		spikes.append(Transform3D(Basis(Vector3.FORWARD, 0.3).rotated(Vector3.UP, angle), Vector3(at.x, y + 1.0, at.y)))
	Props.scatter(hold, Props.cone(0.25, 2.2, 4), Color(0.9, 0.88, 0.8), spikes)
	torch(hold, _near(h, Vector2(0, 0), y + 0.5), 7.0)
	var ridge: Array = FLATS[RIDGE]
	torch(hold, _near(ridge[0], Vector2(0, 0), ridge[2] + 0.5), 5.0)


# The Grizzled Den: wendigo hollows in the snowbank and Old Rimebeard's cave.

func _build_den() -> void:
	var den := Node3D.new()
	den.name = "GrizzledDen"
	add_child(den)
	var flat: Array = FLATS[DEN]
	_cave_mouth(den, Vector3(-268, height_at(-268, -1099), -1099), PI, 5.0)
	var bones: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 9
	for i in 14:
		var at: Vector2 = flat[0] + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		bones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.15, 0.15, rng.randf_range(0.8, 1.6))), Vector3(at.x, flat[2] + 0.1, at.y)))
	Props.scatter(den, BoxMesh.new(), Color(0.9, 0.88, 0.8), bones)


# Barleyhall: the brewers' hamlet on the tarn's shore, with a jetty.

func _build_barleyhall() -> void:
	var hamlet := Node3D.new()
	hamlet.name = "Barleyhall"
	add_child(hamlet)
	var flat: Array = FLATS[BARLEYHALL]
	var b: Vector2 = flat[0]
	var y: float = flat[2]
	_house(hamlet, _near(b, Vector2(6, -2), y), 12.0, 8.0, PI / 2)
	_house(hamlet, _near(b, Vector2(-4, 10), y), 8.0, 7.0)
	for barrel in [Vector2(-2, -4), Vector2(-3.4, -3), Vector2(-1.6, -2.2)]:
		Props.cylinder(hamlet, _near(b, barrel, y), 0.55, 1.1, TIMBER)
	plank(hamlet, _near(b, Vector2(-12, -4), y + 0.3), _near(b, Vector2(-26, -10), WATER_LEVEL + 0.4))
	torch(hamlet, _near(b, Vector2(0, 2), y + 0.6), 6.0)


# The Cogworks: the gnomes' ruined works, iron sheds and broken pipes round a
# sealed hatch into the mountain.

func _build_cogworks() -> void:
	var works := Node3D.new()
	works.name = "Cogworks"
	add_child(works)
	var flat: Array = FLATS[COGWORKS]
	var c: Vector2 = flat[0]
	var y: float = flat[2]
	Props.cylinder(works, _near(c, Vector2(-10, -14), y), 6.0, 1.2, IRON)
	Props.cylinder(works, _near(c, Vector2(-10, -14), y + 1.2), 3.0, 0.4, BRASS, false)
	for shed in [Vector2(12, -6), Vector2(8, 14), Vector2(-16, 10)]:
		Props.box(works, _near(c, shed, y), Vector3(6, 3.4, 5), IRON, 0.3)
		Props.roof(works, _near(c, shed, y + 3.4), Vector3(6.6, 1.2, 5.6), BRASS, 0.3)
	for i in 5:
		var at := c + Vector2(-4 + i * 4.5, 2 - i * 1.5)
		var pipe := Props.box(works, Vector3(at.x, y + 0.4, at.y), Vector3(0.6, 0.6, 5.0), BRASS, i * 0.6, false)
		pipe.rotation.x = 0.1 * i
	torch(works, _near(c, Vector2(0, 0), y + 0.5), 6.0)


func _build_gates() -> void:
	var gates := Node3D.new()
	gates.name = "Gates"
	add_child(gates)
	var gate: Array = FLATS[GATE]
	_great_gate(gates, _near(gate[0], Vector2(0, -8), gate[2]), 0.0)
	var southgate: Array = FLATS[SOUTHGATE]
	_great_gate(gates, _near(southgate[0], Vector2(6, 0), southgate[2]), -PI / 2)


func _build_wreck() -> void:
	var wreck := Node3D.new()
	wreck.name = "Wreck"
	add_child(wreck)
	var flat: Array = FLATS[WRECK]
	_flying_machine(wreck, _near(flat[0], Vector2(-2, -2), flat[2]), 1.2, true)


func _clear(point: Vector2) -> bool:
	if point.distance_to(TOWN) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if point.distance_to(flat[0]) < flat[1] + 3.0:
			return false
	return true


## Snowy pines, in stands and thicker on the slopes.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var caps: Array[Transform3D] = []
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 12000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		var stand := smoothstep(0.05, 0.3, Zone.land_noise().get_noise_2d(point.x * 3.0 + 400.0, point.y * 3.0))
		if y < WATER_LEVEL + 0.6 or y > 32.0 or not _clear(point) or rng.randf() > 0.02 + 0.12 * stand + 0.15 * smoothstep(10.0, 20.0, y):
			continue
		var size := rng.randf_range(0.8, 1.5)
		var base := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y))
		trunks.append(base * Transform3D(Basis(), Vector3(0, 0.9, 0)))
		crowns.append(base * Transform3D(Basis(), Vector3(0, 3.6, 0)))
		caps.append(base * Transform3D(Basis().scaled(Vector3(0.7, 0.7, 0.7)), Vector3(0, 5.4, 0)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.35
	trunk.height = 1.8
	trunk.radial_segments = 6
	add_child(trees)
	Props.scatter(trees, trunk, TIMBER, trunks)
	Props.scatter(trees, Props.cone(1.8, 4.4, 7), PINE, crowns)
	Props.scatter(trees, Props.cone(1.3, 2.6, 7), SNOW, caps)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 3000:
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
	var grass: Array[Transform3D] = []
	var heather: Array[Transform3D] = []
	var edge := SIZE / 2.0 - 6.0
	for attempt in 30000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.5 or y > 24.0 or not _clear(point):
			continue
		var spin := Basis(Vector3.UP, rng.randf() * TAU)
		var at := Vector3(point.x, y, point.y)
		if rng.randf() < 0.15:
			heather.append(Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.7, 1.2)), at + Vector3.UP * 0.15))
		else:
			grass.append(Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.4), 1)), at + Vector3.UP * 0.15))
	add_clutter(clutter, Props.cone(0.14, 0.34, 4), Color(0.6, 0.58, 0.44), grass)
	add_clutter(clutter, Props.blob(0.16, 5, 3), Color(0.7, 0.66, 0.78), heather)
