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
static var SIZE := 1200.0
static var STEP := 2.5
static var WATER_LEVEL := 1.4
static var ROAD_WIDTH := 2.4
static var SEED := 5401

const TOWN := Vector2(-2080, -4380)
const TOWN_HEIGHT := 6.0
static var TOWN_FLAT := 42.0
const GRAVEYARD := Vector3(-2080, TOWN_HEIGHT, -4350)
const GRAVEYARD_FACING := PI
const LAKE := Vector2(-1720, -4250)
const LAKE_RADIUS := 48.0

var PLACES: Array = []
var FLATS: Array = []
var GLOAMROCK := 0
var STARBREEZE := 1
var DEN := 2
var MOONWELLS := 3
var HOLD := 4
var GLADE := 5
var GATE := 6
var DENALAN := 7
var HILLS: Array = []
const PASS_END := Vector2(-2212, -4730)
var ROADS: Array = []
var SPAWNS: Array = []
## Denalor's Planter, by his camp (Planting the Heart).
var QUEST_OBJECTS: Array = []
## The moonwells Crown of the Earth's phials are filled at: Starbreeze's, the
## Pale Pools at the Moonwells, and the Seers' Glade's.
var SPELL_FOCUSES: Array = []
## Fel Cones through the woods round Fernwatch, Barkling Sprouts on the lake
## shore, the four chests of the Relics of Wakening in the Thornbarrow Den and
## Tallon's dresser in his bower.
var CHESTS: Array = []

const ROCK := Color(0.36, 0.36, 0.44)
const PALE_WOOD := Color(0.6, 0.52, 0.48)
const MOONWATER := Color(0.55, 0.8, 0.95)
const LOGS := Color(0.38, 0.28, 0.2)

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
	quest_objects = QUEST_OBJECTS
	spell_focuses = SPELL_FOCUSES


## The elven woods' painted ground, as Mossglen's (Zone.build_ground).
const GROUND_TEXTURES := {
	"grass_tex": "elf_grass", "forest_tex": "moss_floor", "dirt_tex": "elf_path", "rock_tex": "blue_rock",
}


## The caves dug into this zone's hills (Zone.cave_mouths).
func cave_mouths() -> Array:
	return [[(FLATS[GLOAMROCK][0] as Vector2) + Vector2(6.0, -14.0), atan2(6.0, -14.0), "the Gloamrock", true],
		[(FLATS[DEN][0] as Vector2) + Vector2(-12.0, -12.0), -PI * 0.75, "the Thornbarrow Den", false]]

func _ready() -> void:
	Props.use_texture(ROCK, "blue_rock", 3.0)
	Props.use_texture(PALE_WOOD, "pale_bark", 2.0)
	Props.use_texture(LOGS, "bark", 2.0)
	build_ground(STEP, _ground_tint, _ground_layers, GROUND_TEXTURES)
	build_water(WATER_LEVEL, true)
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
	# A forge by the Mining trainer, for Smelting.
	build_forge(self, ground_point(-2054.8, -4363.6), 0.5236, Color(0.55, 0.6, 0.68), Color(0.6, 0.6, 0.62))
	spawn_creatures(SEED + 3, "Eldergrove", [], WATER_LEVEL)
	spawn_objects(SEED + 6, WATER_LEVEL)


## The town, the flats, the water and the roads stay clear of the edge
## mountains.
func edge_keep_more() -> Array:
	var circles: Array = [[TOWN, TOWN_FLAT + 16.0], [LAKE, LAKE_RADIUS + 8.0]]
	for flat: Array in FLATS:
		circles.append([flat[0], flat[1] + 14.0])
	return [circles, ROADS]


func height_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var height := base_height(x, z)
	height += mountain_height(x, z, edge_ring(point))
	for hill: Array in HILLS:
		height += hill[2] * _bump(ragged_distance(point, hill[0], hill[1]) / hill[1])
	height = minf(height, lerpf(-2.0, height, smoothstep(LAKE_RADIUS * 0.7, LAKE_RADIUS, ragged_distance(point, LAKE, LAKE_RADIUS))))
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
## paths (roads, Fernwatch, the camps), b rock (steep and high ground), a
## moss in patches.
func _ground_layers(x: float, z: float, y: float, normal: Vector3) -> Color:
	var point := Vector2(x, z)
	var path := 1.0 - smoothstep(ROAD_WIDTH, ROAD_WIDTH + 1.5, _road_distance(point, ROAD_WIDTH + 1.5))
	path = maxf(path, (1.0 - smoothstep(TOWN_FLAT - 14.0, TOWN_FLAT - 6.0, ragged_distance(point, TOWN, TOWN_FLAT, true))) * 0.5)
	for flat: Array in FLATS:
		path = maxf(path, (1.0 - smoothstep(flat[1] - 4.0, flat[1] + 2.0, ragged_distance(point, flat[0], flat[1], true))) * 0.6)
	var rock := maxf(smoothstep(0.84, 0.62, normal.y), smoothstep(26.0, 36.0, y))
	var patch := Zone.land_noise().get_noise_2d(x * 2.0, z * 2.0)
	var moss := smoothstep(-0.05, -0.4, patch)
	return Color(path, 0.0, rock, moss)


## The textured ground's tint: a little noise.
func _ground_tint(x: float, z: float, _y: float, _normal: Vector3) -> Color:
	var shade := 1.0 + _detail.get_noise_2d(x, z) * 0.06
	return Color(shade, shade, shade)


func _near(at: Vector2, offset: Vector2, y: float) -> Vector3:
	return Vector3(at.x + offset.x, y, at.y + offset.y)


## A cave mouth: a dark opening framed in rough stone, facing `yaw` (0 faces north).



## An elven bower (one solid, Nature's), violet or teal, turned by `yaw`.
func _bower(parent: Node3D, at: Vector3, violet: bool, yaw := 0.0) -> void:
	place_baked(parent, "bower_violet" if violet else "bower_teal", Transform3D(Basis(Vector3.UP, yaw), at))


## A moonwell: a ring of pale stones (one solid, Nature's "moonwell_ring")
## round still, glowing water.
func _moonwell(parent: Node3D, at: Vector3, radius: float) -> void:
	place_baked(parent, "moonwell_ring", Transform3D(Basis().scaled(Vector3(radius, 1.0, radius)), at))
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius - 0.3
	disc.bottom_radius = radius - 0.3
	disc.height = 0.1
	water.mesh = disc
	var glow := StandardMaterial3D.new()
	glow.albedo_color = MOONWATER
	glow.emission_enabled = true
	glow.emission = MOONWATER
	glow.emission_energy_multiplier = 0.6
	water.material_override = glow
	water.position = at + Vector3(0, 0.55, 0)
	parent.add_child(water)
	var light := OmniLight3D.new()
	light.light_color = MOONWATER
	light.omni_range = radius * 4.0
	light.light_energy = 0.8
	light.position = at + Vector3(0, 2.0, 0)
	parent.add_child(light)


## A bearfolk hut (one solid, Nature's "log_hut"), its doorway facing `yaw`.
func _log_hut(parent: Node3D, at: Vector3, radius: float, yaw := 0.0) -> void:
	place_baked(parent, "log_hut", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * radius / 3.0), at))


# Fernwatch: bowers in a ring round a moonwell, the inn's long bower to the
# north and lanterns on posts.

func _build_town() -> void:
	var town := Node3D.new()
	town.name = "Fernwatch"
	add_child(town)
	var t := TOWN
	var y := TOWN_HEIGHT
	_moonwell(town, _near(t, Vector2(0, 0), y), 3.6)
	# The inn: a long open bower (one solid, Nature's "long_bower").
	place_baked(town, "long_bower", Transform3D(Basis(), _near(t, Vector2(0, -26), y)))
	for i in 7:
		var angle := TAU * i / 7.0 + 0.35
		var at := t + Vector2(cos(angle), sin(angle)) * 24.0
		if at.y < t.y - 14.0 and absf(at.x - t.x) < 14.0:
			continue
		_bower(town, Vector3(at.x, y, at.y), i % 2 == 0, -angle)
	for lamp in [Vector2(-8, 8), Vector2(8, 8), Vector2(-12, -10), Vector2(12, -10), Vector2(0, 30)]:
		Props.box(town, _near(t, lamp, y), Vector3(0.25, 2.4, 0.25), PALE_WOOD, 0.0, false)
		torch(town, _near(t, lamp, y + 2.4), 6.0)


# The Gloamrock: a mossy crag with a cave the sprites have taken.

func _build_gloamrock() -> void:
	var rock := Node3D.new()
	rock.name = "Gloamrock"
	add_child(rock)
	var flat: Array = FLATS[GLOAMROCK]
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
			_bower(village, Vector3(at.x, flat[2], at.y), false, -angle)
		else:
			Props.cylinder(village, Vector3(at.x, flat[2], at.y), 3.2, 0.4, PALE_WOOD.darkened(0.3))
	_log_hut(village, _near(flat[0], Vector2(0, 0), flat[2]), 3.0)
	_moonwell(village, _near(flat[0], Vector2(-8, 8), flat[2]), 2.6)
	torch(village, _near(flat[0], Vector2(4, 4), flat[2] + 0.5), 6.0)


# The Thornbarrow Den: the old druids' barrow, a mound with a stone door, and
# the bearfolk's huts before it.

func _build_den() -> void:
	var den := Node3D.new()
	den.name = "ThornbarrowDen"
	add_child(den)
	var flat: Array = FLATS[DEN]
	for hut in [Vector2(10, 6), Vector2(4, 14), Vector2(14, -6)]:
		_log_hut(den, _near(flat[0], hut, flat[2]), 2.6, atan2(-hut.x, -hut.y) + PI)
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
		_log_hut(hold, _near(h, Vector2(cos(angle), sin(angle)) * 13.0, flat[2]), 3.0, -angle - PI / 2.0)
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
	# The vast old tree, one solid (Nature's great tree at four times).
	place_baked(glade, "great_tree", Transform3D(Basis().scaled(Vector3.ONE * 4.0), _near(g, Vector2(0, 8), flat[2] - 0.4)))
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
	place_baked(gate, "silver_gate", Transform3D(Basis(), at))
	for lamp in [Vector3(4, 0, -7), Vector3(4, 0, 7)]:
		Props.box(gate, at + lamp, Vector3(0.25, 2.4, 0.25), PALE_WOOD, 0.0, false)
		torch(gate, at + lamp + Vector3(0, 2.4, 0), 6.0)


func _clear(point: Vector2) -> bool:
	if ragged_distance(point, TOWN, TOWN_FLAT, true) < TOWN_FLAT + 4.0 or _road_distance(point, ROAD_WIDTH + 3.0) < ROAD_WIDTH + 2.0:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1] + 3.0:
			return false
	return true


## Tall elven trees (Nature's, one solid each), thick everywhere: the isle
## is a forest; never on bare rock.
func _build_trees() -> void:
	var trees := StaticBody3D.new()
	trees.name = "Trees"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var placed := variant_lists(TREE_VARIANTS)
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.6
	trunk_shape.height = 6.0
	var edge := SIZE / 2.0 - 10.0
	for attempt in 14000:
		var point := CENTER + Vector2(rng.randf_range(-edge, edge), rng.randf_range(-edge, edge))
		var y := height_at(point.x, point.y)
		if y < WATER_LEVEL + 0.6 or y > 30.0 or not _clear(point) or rng.randf() > 0.12 + 0.12 * smoothstep(10.0, 18.0, y) \
				or shows_rock(point, y, _ground_layers):
			continue
		var size := rng.randf_range(0.9, 1.5)
		placed[rng.randi_range(0, TREE_VARIANTS - 1)].append(
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(point.x, y, point.y)))
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = Vector3(point.x, y + 3.0, point.y)
		trees.add_child(collision)
	# Added once its shapes are in.
	add_child(trees)
	for i in TREE_VARIANTS:
		Nature.scatter(trees, Nature.elf_tree_mesh(i), placed[i])


func _build_rocks() -> void:
	var rocks := StaticBody3D.new()
	rocks.name = "Rocks"
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var placed := variant_lists(ROCK_VARIANTS)
	var edge := SIZE / 2.0 - 6.0
	for attempt in 2500:
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
	draw_rocks(rocks, placed, SEED, false, "blue_rock")


## Blue-green grass, ferns and moonflowers, and bushes, made near the camera
## (Zone.add_nature_clutter).
func _build_clutter() -> void:
	add_nature_clutter(_grass_at, _bush_at, SEED + 3, false, false, "elf_leaves")


## What grows at a point: ferns on the moss, grass elsewhere, moonflowers
## here and there; none on paths or rock. Called from a worker thread: it
## only reads.
func _grass_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.6 or y > 24.0 or not _clear_for_clutter(point):
		return []
	var layers := _ground_layers(point.x, point.y, y, _normal_at(point, y))
	if layers.b > 0.3 or layers.r > 0.4 or rng.randf() > 0.7:
		return []
	var at := Vector3(point.x, y - 0.05, point.y)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	if layers.a > 0.4 and rng.randf() < 0.5:
		return ["ferns", Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), at)]
	if rng.randf() < 0.05:
		return ["flowers_blue" if rng.randf() < 0.6 else "flowers_white", Transform3D(spin.scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), at)]
	return ["elf_blades", Transform3D(spin.scaled(Vector3(1, rng.randf_range(0.8, 1.3), 1) * rng.randf_range(0.8, 1.15)), at)]


## A bush now and then.
func _bush_at(point: Vector2, rng: RandomNumberGenerator) -> Array:
	if rng.randf() > 0.06:
		return []
	var y := ground_height(point.x, point.y)
	if y < WATER_LEVEL + 0.8 or y > 24.0 or not _clear_for_clutter(point) or _normal_at(point, y).y < 0.8:
		return []
	var size := rng.randf_range(0.8, 1.4)
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	return [str(rng.randi_range(0, BUSH_VARIANTS - 1)),
		Transform3D(spin.scaled(Vector3(size, size * rng.randf_range(0.8, 1.1), size)), Vector3(point.x, y - 0.05, point.y))]


func _normal_at(point: Vector2, y: float) -> Vector3:
	return Vector3(y - ground_height(point.x + 0.8, point.y), 0.8, y - ground_height(point.x, point.y + 0.8)).normalized()


## Open ground: not on roads, in Fernwatch or on the camps.
func _clear_for_clutter(point: Vector2) -> bool:
	if ragged_distance(point, TOWN, TOWN_FLAT, true) < TOWN_FLAT - 4.0 or _road_distance(point, ROAD_WIDTH + 1.0) < ROAD_WIDTH + 0.8:
		return false
	for flat: Array in FLATS:
		if ragged_distance(point, flat[0], flat[1], true) < flat[1]:
			return false
	return true
