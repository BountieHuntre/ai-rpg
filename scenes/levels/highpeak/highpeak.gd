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
static var SIZE := 1200.0
static var STEP := 2.5
static var WATER_LEVEL := 1.4
static var ROAD_WIDTH := 2.6
static var SEED := 5201

const TOWN := Vector2(-150, -780)
const TOWN_HEIGHT := 7.0
static var TOWN_FLAT := 42.0
const GRAVEYARD := Vector3(-150, TOWN_HEIGHT, -748)
static var GRAVEYARD_FACING := 0.0
const TARN := Vector2(-440, -1200)
static var TARN_RADIUS := 70.0

var PLACES: Array = []
var FLATS: Array = []
var DEPOT := 0
var RANCH := 1
var QUARRY := 2
var HOLD := 3
var RIDGE := 4
var DEN := 5
var BARLEYHALL := 6
var COGWORKS := 7
var GATE := 8
var SOUTHGATE := 9
var WRECK := 10
var HILLS: Array = []
const PASS_END := Vector2(-630, -970)
var ROADS: Array = []
var SPAWNS: Array = []
## A Dwarven Corpse: the lost pilot, by her wrecked flying machine.
var QUEST_OBJECTS: Array = []
## The Thunder Ale barrel beside the inn: guarded by Jarvik Kegsworth until a
## Thunder Ale (Distracting Jarvik) draws him off to the inn door for
## UNGUARDED_TIME, while the unguarded barrel (Bitter Rivals' end, Return to
## Maddoc's start) stands there instead, as classic's script swaps them.
const BARREL := Vector2(-134, -808)
const JARVIK_POST := Vector3(-130, 7, -805)
const JARVIK_DRINKING := Vector3(-146, 7, -797)
static var UNGUARDED_TIME := 90.0
## Mackellen's Meat Locker in Old Rimebeard's cave, the Shimmerweed Baskets on
## Shimmer Ridge and the Ammo Crate in the quarry.
var CHESTS: Array = []

## Walled places bots go in and out of by the door (Zone.enclosures):
## Kettlefold's inn and its three houses with trainers inside.
var ENCLOSURES: Array = []

const ROCK := Color(0.46, 0.46, 0.5)
const QUARRY_ROCK := Color(0.52, 0.48, 0.44)
const STONE := Color(0.55, 0.53, 0.5)
const DARK_STONE := Color(0.36, 0.35, 0.36)
const SLATE := Color(0.3, 0.32, 0.38)
const TIMBER := Color(0.4, 0.28, 0.18)
const CANVAS := Color(0.62, 0.55, 0.42)
const BRASS := Color(0.7, 0.55, 0.25)
const IRON := Color(0.32, 0.32, 0.34)

## Kettlefold's stone buildings: stone under snowy slates, timber trim.
const STONE_LOOK := { "wall": STONE, "roof": SLATE, "trim": TIMBER, "stone": DARK_STONE, "shutter": TIMBER,
	"cloth": Color(0.2, 0.3, 0.55) }

var _detail := FastNoiseLite.new()
var _road_segments: Array = []


func _init() -> void:
	load_layout()
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
	enclosures = ENCLOSURES


## The snow land's painted ground, as Frosthollow's (Zone.build_ground).
const GROUND_TEXTURES := {
	"grass_tex": "snow", "forest_tex": "frozen_heath", "dirt_tex": "frozen_dirt", "rock_tex": "snow_rock",
}


## The caves dug into this zone's hills (Zone.cave_mouths).
func cave_mouths() -> Array:
	return [[(FLATS[QUARRY][0] as Vector2) + Vector2(-18.0, 18.0), atan2(-18.0, 18.0), "the Grey Quarry", true],
		[(FLATS[HOLD][0] as Vector2) + Vector2(-14.0, 14.0), -PI / 4.0, "Icemane Hold", false],
		[Vector2(-268.0, -1099.0), PI, "the Grizzled Den", false]]

func _ready() -> void:
	Props.use_texture(STONE, "stone_wall", 4.0)
	Props.use_texture(DARK_STONE, "stone_wall", 4.0)
	Props.use_texture(SLATE, "slate_snow", 2.5)
	Props.use_texture(TIMBER, "planks", 2.0)
	Props.use_texture(Buildings.FLOOR, "planks", 2.0)
	Props.use_texture(ROCK, "snow_rock", 3.0)
	Props.use_texture(QUARRY_ROCK, "rock", 3.0)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
	build_water(WATER_LEVEL, true)
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


## The town, the flats, the water and the roads stay clear of the edge
## mountains.
func edge_keep_more() -> Array:
	var circles: Array = [[TOWN, TOWN_FLAT + 16.0], [TARN, TARN_RADIUS + 8.0]]
	for flat: Array in FLATS:
		circles.append([flat[0], flat[1] + 14.0])
	return [circles, ROADS]


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	# The snowy uplands sit a little higher, but not under the edge
	# mountains, so at the borders the ground is every zone's.
	var ring := edge_ring(point)
	var height := base_height(x, z) + 1.5 * (1.0 - ring)
	height += mountain_height(x, z, ring)
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = minf(height, lerpf(-2.0, height, smoothstep(TARN_RADIUS * 0.7, TARN_RADIUS, ragged_distance(point, TARN, TARN_RADIUS))))
	height = lerpf(TOWN_HEIGHT, height, smoothstep(TOWN_FLAT, TOWN_FLAT + 18.0, ragged_distance(point, TOWN, TOWN_FLAT, true)))
	for flat: Array in FLATS:
		height = lerpf(flat[2], height, smoothstep(flat[1], flat[1] + 14.0, ragged_distance(point, flat[0], flat[1], true)))
	return carve_passes(x, z, height)


func _road_distance(point: Vector2, limit: float) -> float:
	var best := distance_to_pass(point)
	for segment: Array in _road_segments:
		var box: Rect2 = segment[2]
		if box.grow(limit).has_point(point):
			best = minf(best, distance_to_line(point, [segment[0], segment[1]]))
	return best


## The textured ground's layers (Zone.build_ground, GROUND_TEXTURES): r the
## trodden paths (Kettlefold, the camps, the roads, the tarn's shore), g the
## village's cobbled yard, b rock (steep ground and the quarry's floor), a
## frozen heath (thin snow on the lower ground, in patches).
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var path := (1.0 - smoothstep(TOWN_FLAT - 12.0, TOWN_FLAT - 4.0, ragged_distance(point, TOWN, TOWN_FLAT, true))) * 0.55
	for flat: Array in FLATS:
		path = maxf(path, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.6)
	path = maxf(path, 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point, ROAD_WIDTH + 1.5)))
	path = maxf(path, 1.0 - smoothstep(WATER_LEVEL + 0.2, WATER_LEVEL + 1.2, y))
	var yard := 1.0 - smoothstep(13.0, 17.0, point.distance_to(TOWN))
	var quarry: Array = FLATS[QUARRY]
	var rock := maxf(smoothstep(0.8, 0.62, normal.y), 1.0 - smoothstep(quarry[1] - 4.0, quarry[1] + 8.0, point.distance_to(quarry[0])))
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var heath := smoothstep(-0.05, 0.35, patch) * (1.0 - smoothstep(14.0, 22.0, y))
	return Color(path, yard, rock, heath)


## The textured ground's tint: a little noise, and the quarry's floor warmer
## (its rock is the plain grey rock, not the frosted).
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 1.0 + _detail.get_noise_2d(x, z) * 0.06
	return Color(shade, shade, shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A dwarven house: stone walls under a snowy slate roof, open inside
## (Buildings.house), its door on `door_side`; returns the room.
func _house(kit: BuildingKit, at: Vector3, size: Vector3, door_side: Vector2) -> Dictionary:
	return Buildings.house(kit, at, size, 0.0, STONE_LOOK, door_side, 0.0, 1, true, true)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).



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


# Kettlefold: stone houses round a cobbled yard, open inside: the Thornbrew
# inn to the north (its keeper behind the bar), the trainers' houses west,
# east and south-west of the yard; a smithy, a well, braziers, and the
# graveyard's cairns south of the yard.

func _build_village() -> void:
	var village := Node3D.new()
	village.name = "Kettlefold"
	add_child(village)
	var kit := BuildingKit.new(village, "Buildings")
	var t := TOWN
	var y := TOWN_HEIGHT
	var inn := _house(kit, _near(t, Vector2(0, -26), y), Vector3(22, 5, 12), Vector2(0, 1))
	Buildings.furnish(kit, inn, "inn", STONE_LOOK)
	# The brew kettle by the inn's door.
	kit.cylinder(_near(t, Vector2(14, -18), y), 1.6, 2.2, BRASS, 10, -1.0, true)
	# The trainers' houses: Templar and Cleric west, Man-at-Arms and
	# Spellsword east, Ranger and pet trainer south-west.
	for house: Array in [[Vector2(-28, -6), Vector3(9, 4.5, 12), Vector2(1, 0)],
			[Vector2(28, -8), Vector3(8, 4.5, 10), Vector2(-1, 0)],
			[Vector2(-26, 22), Vector3(10, 4.5, 8), Vector2(1, 0)]]:
		_house(kit, _near(t, house[0], y), house[1], house[2])
		Buildings.rug(kit, _near(t, house[0], y + 0.1), 0.0, 3.0, 4.0, Color(0.2, 0.3, 0.55))
	# The smithy: a slate roof on posts over a forge with its hood and an anvil.
	Buildings.shed(kit, _near(t, Vector2(25, 18), y), Vector3(8, 3.6, 7), 0.0, TIMBER, SLATE)
	kit.block(_near(t, Vector2(26, 16), y), Vector3(3, 1.6, 2.5), DARK_STONE, 0.0, true)
	add_forge(_near(t, Vector2(26, 16), y))
	kit.block(_near(t, Vector2(26, 16), y + 1.6), Vector3(2.2, 0.15, 1.8), Color(0.55, 0.2, 0.08))
	kit.cylinder(_near(t, Vector2(26, 16), y + 2.6), 1.3, 1.6, DARK_STONE, 4, 0.35)
	kit.block(_near(t, Vector2(26, 16), y + 4.2), Vector3(0.7, 2.2, 0.7), DARK_STONE)
	kit.block(_near(t, Vector2(22, 20), y), Vector3(0.6, 0.6, 0.45), TIMBER, 0.0, true)
	kit.block(_near(t, Vector2(22, 20), y + 0.6), Vector3(1.2, 0.3, 0.55), IRON)
	# The well in the yard.
	Buildings.well(kit, _near(t, Vector2(0, 0), y), DARK_STONE, TIMBER, SLATE)
	kit.finish()
	torch(village, _near(t, Vector2(26, 17.6), y + 2.0), 6.0)
	for brazier in [Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12)]:
		Props.cylinder(village, _near(t, brazier, y), 0.6, 1.0, DARK_STONE, false, 0.8)
		torch(village, _near(t, brazier, y + 1.0), 7.0)
	for cairn in [Vector2(-6, 38), Vector2(0, 40), Vector2(6, 38)]:
		Props.cylinder(village, _near(t, cairn, y), 0.7, 0.8, DARK_STONE, false, 0.3)


# Steelgrip's Depot: a plank hangar under slates with its doors open on a
# flying machine.

func _build_depot() -> void:
	var depot := Node3D.new()
	depot.name = "Depot"
	add_child(depot)
	var flat: Array = FLATS[DEPOT]
	var d: Vector2 = flat[0]
	var y: float = flat[2]
	var kit := BuildingKit.new(depot, "Buildings")
	Buildings.barn(kit, _near(d, Vector2(0, -8), y), Vector3(14, 6, 9), 0.0, TIMBER, DARK_STONE, SLATE, 1.0)
	Buildings.crate(kit, _near(d, Vector2(-8, 4), y), 1.4, TIMBER, DARK_STONE)
	Buildings.barrel(kit, _near(d, Vector2(-9.6, 3), y), 0.45, 1.0, TIMBER)
	kit.finish()
	_flying_machine(depot, _near(d, Vector2(2, 6), y), 0.4)
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


# Amberfield Ranch: a stone farmhouse, open inside, a barn and fenced pens
# for the rams.

func _build_ranch() -> void:
	var ranch := Node3D.new()
	ranch.name = "Ranch"
	add_child(ranch)
	var flat: Array = FLATS[RANCH]
	var r: Vector2 = flat[0]
	var y: float = flat[2]
	var kit := BuildingKit.new(ranch, "Buildings")
	var home := _house(kit, _near(r, Vector2(-8, -8), y), Vector3(10, 4.2, 8), Vector2(0, 1))
	Buildings.furnish(kit, home, "cottage", STONE_LOOK)
	Buildings.barn(kit, _near(r, Vector2(10, -6), y), Vector3(10, 5, 8), 0.0, TIMBER, DARK_STONE, SLATE, -1.0)
	for i in 8:
		var at := r + Vector2(-12 + i * 3.4, 12)
		kit.block(Vector3(at.x, y, at.y), Vector3(0.25, 1.2, 0.25), TIMBER, 0.0, true)
	kit.box(_near(r, Vector2(0, 12), y + 0.9), Vector3(24, 0.15, 0.15), TIMBER)
	kit.box(_near(r, Vector2(0, 12), y + 0.5), Vector3(24, 0.15, 0.15), TIMBER)
	kit.finish()


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
	var bones: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 9
	for i in 14:
		var at: Vector2 = flat[0] + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		bones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.15, 0.15, rng.randf_range(0.8, 1.6))), Vector3(at.x, flat[2] + 0.1, at.y)))
	Props.scatter(den, BoxMesh.new(), Color(0.9, 0.88, 0.8), bones)


# Barleyhall: the brewers' hamlet on the tarn's shore: two stone houses,
# open inside, barrels and a jetty.

func _build_barleyhall() -> void:
	var hamlet := Node3D.new()
	hamlet.name = "Barleyhall"
	add_child(hamlet)
	var flat: Array = FLATS[BARLEYHALL]
	var b: Vector2 = flat[0]
	var y: float = flat[2]
	var kit := BuildingKit.new(hamlet, "Buildings")
	var brewhouse := _house(kit, _near(b, Vector2(6, -2), y), Vector3(8, 4.2, 12), Vector2(-1, 0))
	Buildings.furnish(kit, brewhouse, "cottage", STONE_LOOK)
	var cottage := _house(kit, _near(b, Vector2(-6, 16), y), Vector3(8, 4.2, 7), Vector2(0, -1))
	Buildings.furnish(kit, cottage, "cottage", STONE_LOOK)
	for barrel in [Vector2(-2, -4), Vector2(-3.4, -3), Vector2(-1.6, -2.2)]:
		Buildings.barrel(kit, _near(b, barrel, y), 0.55, 1.1, TIMBER)
	kit.finish()
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
	if ragged_distance(point, TOWN, TOWN_FLAT, true) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return true


## Snowy pines, in stands and thicker on the slopes, never on bare rock.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var pines := variant_lists(TREE_VARIANTS)
	var unused := variant_lists(TREE_VARIANTS)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.45
	trunk_shape.height = 4.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 12000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		var stand := smoothstep(0.05, 0.3, Zone.land_noise().get_noise_2d(point.x * 3.0 + 400.0, point.y * 3.0))
		if y < WATER_LEVEL + 0.6 or y > 32.0 or not _clear(point) \
				or rng.randf() > 0.02 + 0.12 * stand + 0.15 * smoothstep(10.0, 20.0, y) \
				or shows_rock(point, y, _ground_layers):
			continue
		var size := rng.randf_range(0.75, 1.3)
		pines[rng.randi_range(0, TREE_VARIANTS - 1)].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 2.0, point.y)
		trees.add_child(collision)
	# Added once its shapes are in: adding shapes to a body in the world
	# rebuilds the body each time.
	add_child(trees)
	draw_trees(trees, pines, unused, SEED, true)


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
	var edge := SIZE / 2.0 - 6.0
	for attempt in 3000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.4 or rng.randf() > 0.03 + 0.4 * smoothstep(11.0, 24.0, y) or not _clear(point):
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
	draw_rocks(rocks, placed, SEED, true)


## Dry grass and frosted heather poking through the snow, and snowy
## bushes now and then, made near the camera (Zone.add_nature_clutter).
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 3, true)


## What grows at a point: mostly on the heath, thin on open snow, none on
## paths, rock, the shore or high ground. Called from a worker thread: it
## only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.8 or y > 24.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3 or layers.r > 0.5:
		return []
	if rng.randf() > lerpf(0.06, 0.55, layers.a):
		return []
	var at := Vector3(point.x, y - 0.05, point.y)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	if rng.randf() < 0.22:
		return ["heather", Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), at)]
	return ["frost_grass", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.15)), at)]


## A snowy bush now and then.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.05:
		return []
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.8 or y > 24.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.7, 1.3)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.8, 1.1), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## Open ground: not on roads, in the village or on the camps.
func _clear_for_clutter(point: Vector2) -> bool:
	if ragged_distance(point, TOWN, TOWN_FLAT, true) < TOWN_FLAT - 4.0 or _road_distance(point, ROAD_WIDTH + 1.0) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
