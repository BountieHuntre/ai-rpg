class_name Zone
extends Node3D
## What every zone shares. Zones sit side by side in their continent's world
## (World), each a square SIZE yards across around its center, in world
## coordinates, with mountains along its edges. Where two zones meet, both use
## the same mountain shape from the same noise, so the ground joins up, and a
## pass (PASSES) is cut through the mountains on both sides. -Z is north.

## Mountain noise shared by every zone, in world coordinates.
const LAND_SEED := 1077
## Passes between zones, per continent (the two worlds' coordinates overlap,
## so a continent's passes never touch the other's ground): "line", points in
## world coordinates, the first end in one zone and the last in the other; and
## the border it crosses, where it climbs highest: "z" for a border running
## east-west at that z, "x" for one running north-south. The mountains are
## cut down along them and the edge walls open where they cross.
const PASSES := {
	"aldmark": [
		# Ashford Vale's bridge road south to Wexford.
		{ "line": [Vector2(2, 112), Vector2(-18, 150), Vector2(-30, 200), Vector2(-24, 250), Vector2(-8, 290)], "z": 200.0 },
		# Gravesend's road east down into Duskmoor Glades.
		{ "line": [Vector2(-2370, -4200), Vector2(-2335, -4195), Vector2(-2300, -4190), Vector2(-2265, -4185), Vector2(-2230, -4180)], "x": -2300.0 },
		# Frosthollow's Frozen Stair east up into Highpeak.
		{ "line": [Vector2(-770, -955), Vector2(-735, -958), Vector2(-700, -962), Vector2(-665, -966), Vector2(-630, -970)], "x": -700.0 },
	],
	"kareth": [
		# The Redsand Coast's road east up to Emberhollow.
		{ "line": [Vector2(2235, -1745), Vector2(2270, -1745), Vector2(2300, -1735), Vector2(2335, -1712), Vector2(2370, -1690)], "x": 2300.0 },
		# Sunfold Camp's trail north up into the Tallgrass.
		# It runs on past the Tallgrass's mountains, which reach further in
		# towards that corner, down to the plain where the road starts.
		{ "line": [Vector2(-500, 1070), Vector2(-505, 1035), Vector2(-510, 1000), Vector2(-515, 965), Vector2(-520, 930),
			Vector2(-538, 903), Vector2(-560, 875)], "z": 1000.0 },
		# Mossglen's road south down the great tree's roots onto Eldergrove Isle.
		{ "line": [Vector2(-2200, -4870), Vector2(-2203, -4835), Vector2(-2206, -4800), Vector2(-2209, -4765), Vector2(-2212, -4730)], "z": -4800.0 },
	],
}
## Half the width of a pass's flat floor, and how far its sides run up.
const PASS_FLOOR := 7.0
const PASS_SIDES := 13.0
## How high the pass climbs at the border, over the land around it.
const PASS_CREST := 7.0
## Half the width of the gap in the edge walls where a pass crosses them.
const PASS_GAP := 10.0
const MOUNTAIN_HEIGHT := 38.0
const MOUNTAIN_ROUGHNESS := 14.0
## Players can't walk past this far from the center, along each axis, except
## through a pass.
const EDGE_INSET := 4.0

## The edge mountains wind in and out (`edge_ring`): along each side of the
## square they start anywhere from EDGE_NEAR yards in to EDGE_FAR (EDGE_FAR_SMALL
## on the 400-yard starting zones), by noise every EDGE_STEP yards, but never
## nearer than EDGE_CLEAR to anything the zone keeps clear (`edge_keep`).
const EDGE_NEAR := 25.0
const EDGE_FAR := 150.0
const EDGE_FAR_SMALL := 100.0
const EDGE_STEP := 8.0
const EDGE_CLEAR := 15.0
const EDGE_FULL := 6.0
## The mountains rise to full height over this many yards from where they
## start, so a deep spur is a solid ridge, not a long slope.
const EDGE_RISE := 45.0
## Within PASS_RIDGE_SPAN yards along an edge of where a pass crosses it, the
## mountains start at least PASS_RIDGE yards in, so the pass is cut through a
## ridge and climbs gently to its crest.
const PASS_RIDGE := 60.0
const PASS_RIDGE_SPAN := 45.0

## Ragged places (`ragged_distance`): a circle's rim wobbles in and out by up
## to this share of its radius.
const RAGGED := 0.3

static var _land: FastNoiseLite
static var _ragged: FastNoiseLite
## Per side (west, east, north, south), how far in the mountains start at
## each EDGE_STEP along it, from its -x or -z end.
var _edge_depths: Array[PackedFloat32Array] = []

## The continent the zone is on (World.CONTINENTS), for its passes.
var continent := "aldmark"
## The zone's name, its center (x, z) and width in yards, set by each zone.
var zone_name := ""
var center := Vector2.ZERO
var size := 400.0
## Where the dead of this zone come back, and the way they face.
var graveyard := Vector3.ZERO
var graveyard_facing := 0.0
## The middle of the zone's main settlement: directions to places are from here.
var hub := Vector2.ZERO
## What the settlement is called, for directions ("west of Wexford").
var hub_name := ""
## Named places: [name, center, radius], smallest first.
var places: Array = []
## Creature spawns: [creature entry, center, radius, count].
var spawns: Array = []
## Game objects: quest givers and enders that are things [object entry,
## node name (quests' giver or ender), point (x, z), facing], and chests to
## loot scattered round a spot [object entry, center, radius, count].
var quest_objects: Array = []
var chests: Array = []
## Spell focus objects (gameobjects.json "focus"): [object entry, point (x, z)],
## invisible, beside what they stand for (a moonwell, a well).
var spell_focuses: Array = []
## Forges (Smelting's spell focus 3) by their points (x, z): add_forge.
var forges: Array[Vector2] = []
## The zone's herbs and ore (GatherNodes), once its creatures are spawned.
var gather_field: GatherNodes
## The ground's layers function (build_ground's `weights`), for telling
## grass from rock and roads.
var _weights := Callable()
## Walled places bots go in and out of by the gate:
## [x min, z min, x max, z max, outside the gate, inside the gate].
var enclosures: Array = []


static func land_noise() -> FastNoiseLite:
	if _land == null:
		_land = FastNoiseLite.new()
		_land.seed = LAND_SEED
		_land.frequency = 0.008
		_land.fractal_octaves = 4
	return _land


## The noise ragged places' rims follow.
static func ragged_noise() -> FastNoiseLite:
	if _ragged == null:
		_ragged = FastNoiseLite.new()
		_ragged.seed = LAND_SEED + 7
		_ragged.frequency = 1.0
		_ragged.fractal_type = FastNoiseLite.FRACTAL_NONE
	return _ragged


## How far a point is from a ragged place's middle, as a share of what it
## would be from a round one: the circle of `radius` round `spot` has its rim
## wobbled in and out by up to RAGGED of the radius, by noise along it, so a
## flat, field, lake, wood or hill has a natural outline. Used everywhere the
## place is tested, so the ground, its layers, trees and grass agree. With
## `grow` the rim only reaches further out (flats under buildings).
static func ragged_distance(point: Vector2, spot: Vector2, radius: float, grow := false) -> float:
	var offset := point - spot
	var length := offset.length()
	if length < 0.001:
		return 0.0
	# Round a small ring in the noise, the same size for every place, so each
	# has a few broad lobes whatever its size; where it lies picks which.
	var n := clampf(ragged_noise().get_noise_2dv(spot / 40.0 + offset / length * 0.5) * 1.2, -0.5, 0.5)
	var wobble := 1.0 + (RAGGED * (n + 0.5) if grow else RAGGED * 2.0 * n)
	return length / wobble


## Whether a point (x, z) is in this zone's square.
func contains(point: Vector2) -> bool:
	var half := size / 2.0
	return absf(point.x - center.x) <= half and absf(point.y - center.y) <= half


## The ground's height. Each zone gives its own.
func height_at(_x: float, _z: float) -> float:
	return 0.0


## The land with no features: gentle rolling ground.
static func base_height(x: float, z: float) -> float:
	return land_noise().get_noise_2d(x, z) * 3.0 + 4.5


## The mountains at a point, `ring` being how far up them it is (0 to 1).
static func mountain_height(x: float, z: float, ring: float) -> float:
	return ring * (MOUNTAIN_HEIGHT + land_noise().get_noise_2d(x * 3.1, z * 3.1) * MOUNTAIN_ROUGHNESS)


## How far up the edge mountains a point is (0 to 1): each side's ring by
## its winding depth there (`_edge_depths`), joined so corners round off.
## Heights at the square's edge are full mountain on every side, so zones
## still meet exactly.
func edge_ring(point: Vector2) -> float:
	if _edge_depths.is_empty():
		make_edges()
	var local := point - center
	var half := size / 2.0
	var open := 1.0
	for side in 4:
		var inward: float
		var along: float
		match side:
			0:
				inward = local.x + half
				along = local.y + half
			1:
				inward = half - local.x
				along = local.y + half
			2:
				inward = local.y + half
				along = local.x + half
			_:
				inward = half - local.y
				along = local.x + half
		var depths := _edge_depths[side]
		var at := clampf(along / EDGE_STEP, 0.0, depths.size() - 1.0)
		var i := mini(int(at), depths.size() - 2)
		var depth := lerpf(depths[i], depths[i + 1], at - i)
		var t := clampf((depth - inward) / minf(EDGE_RISE, maxf(depth - EDGE_FULL, 1.0)), 0.0, 1.0)
		open *= 1.0 - t * t * (3.0 - 2.0 * t)
	return 1.0 - open


## What the edge mountains keep clear of: circles [center, radius] and
## lines (each a list of points). By default the zone's places (not the
## big ones, woods and hills that may run up into the mountains), spawns,
## walled places, things to use, chests, graveyard and the ends of its
## passes; a zone adds its flats, lakes, fields and roads (`edge_keep_more`).
func edge_keep() -> Array:
	var circles: Array = []
	var lines: Array = []
	for place: Array in places:
		if float(place[2]) <= 40.0:
			circles.append([place[1], place[2]])
	# Creatures may roam the foot of a slope: a spawn keeps its middle clear.
	for spawn: Array in spawns:
		circles.append([spawn[1], spawn[2] * 0.5])
	for wall: Array in enclosures:
		var box := Rect2(wall[0], wall[1], wall[2] - wall[0], wall[3] - wall[1])
		circles.append([box.get_center(), box.size.length() / 2.0])
	for thing: Array in quest_objects:
		circles.append([thing[2], 6.0])
	for chest: Array in chests:
		circles.append([chest[1], chest[2]])
	circles.append([Vector2(graveyard.x, graveyard.z), 12.0])
	# A pass cuts through the mountains: only its two ends are kept clear,
	# so the valley reaches the road on each side.
	for line: Dictionary in passes():
		var points: Array = line.line
		circles.append([points[0], 10.0])
		circles.append([points[-1], 10.0])
	var more := edge_keep_more()
	circles.append_array(more[0])
	lines.append_array(more[1])
	return [circles, lines]


## A zone's own things the edge mountains keep clear of: [circles, lines].
func edge_keep_more() -> Array:
	return [[], []]


## Works out each side's winding depths (`edge_ring`): noise by the world
## position along it, pulled in short of anything kept clear, then smoothed
## so the pulling leaves no kinks.
func make_edges() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = hash(zone_name) & 0xFFFF
	noise.frequency = 1.0 / 130.0
	noise.fractal_octaves = 3
	var far := EDGE_FAR if size > 500.0 else EDGE_FAR_SMALL
	var keep := edge_keep()
	# Nothing reaching into a pass's way counts (a place named for it, a
	# road into it): the pass cuts its own way. Its two ends do.
	var ends: Array[Vector2] = []
	for each: Dictionary in passes():
		ends.append(each.line[0])
		ends.append(each.line[-1])
	var circles: Array = []
	for circle: Array in keep[0]:
		if circle[0] in ends or distance_to_pass(circle[0]) > float(circle[1]) + PASS_FLOOR + PASS_SIDES:
			circles.append(circle)
	for line: Array in keep[1]:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var steps := maxi(1, int(a.distance_to(b) / 6.0))
			for k in steps + 1:
				# Not where it runs into a pass, which cuts its own way.
				var spot := a.lerp(b, float(k) / steps)
				if distance_to_pass(spot) > PASS_FLOOR + PASS_SIDES + 10.0:
					circles.append([spot, 8.0])
	var half := size / 2.0
	var count := int(size / EDGE_STEP) + 1
	var depths: Array[PackedFloat32Array] = []
	for side in 4:
		var row := PackedFloat32Array()
		var limit := PackedFloat32Array()
		row.resize(count)
		limit.resize(count)
		for i in count:
			var along := i * EDGE_STEP - half
			var edge: Vector2
			match side:
				0: edge = center + Vector2(-half, along)
				1: edge = center + Vector2(half, along)
				2: edge = center + Vector2(along, -half)
				_: edge = center + Vector2(along, half)
			var n := clampf((noise.get_noise_2dv(edge) + 0.55) / 1.1, 0.0, 1.0)
			row[i] = lerpf(EDGE_NEAR, far, n)
			var allowed := far
			for circle: Array in circles:
				var spot: Vector2 = circle[0] - center
				var inward: float
				var lateral: float
				match side:
					0:
						inward = spot.x + half
						lateral = absf(spot.y - along)
					1:
						inward = half - spot.x
						lateral = absf(spot.y - along)
					2:
						inward = spot.y + half
						lateral = absf(spot.x - along)
					_:
						inward = half - spot.y
						lateral = absf(spot.x - along)
				# The mountains stop short of the circle, grown by EDGE_CLEAR:
				# a round notch where it comes near.
				# Not something beyond this edge (a pass's far end, in the
				# neighbouring zone).
				var reach: float = circle[1] + EDGE_CLEAR
				if lateral < reach and inward > 0.0:
					allowed = minf(allowed, inward - sqrt(reach * reach - lateral * lateral))
			limit[i] = maxf(allowed, EDGE_FULL + 6.0)
			row[i] = minf(row[i], limit[i])
		for pass_count in 2:
			var smooth := row.duplicate()
			for i in count:
				var total := 0.0
				var weight := 0.0
				for k in range(-2, 3):
					var j := clampi(i + k, 0, count - 1)
					total += row[j]
					weight += 1.0
				smooth[i] = minf(total / weight, limit[i])
			row = smooth
		# A ridge where a pass crosses this side.
		var a: Vector2 = center + [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, -half), Vector2(-half, half)][side]
		var b: Vector2 = center + [Vector2(-half, half), Vector2(half, half), Vector2(half, -half), Vector2(half, half)][side]
		for each: Dictionary in passes():
			var line: Array = each.line
			for k in line.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(a, b, line[k], line[k + 1])
				if hit == null:
					continue
				var at: float = (hit as Vector2).distance_to(a)
				for i in count:
					var lateral := absf(i * EDGE_STEP - at)
					if lateral < PASS_RIDGE_SPAN:
						var ridge := PASS_RIDGE * _bump(lateral / PASS_RIDGE_SPAN * 0.5)
						row[i] = maxf(row[i], minf(ridge, limit[i]))
		depths.append(row)
	_edge_depths = depths


## This zone's continent's passes (PASSES).
func passes() -> Array:
	return PASSES.get(continent, [])


## Cuts the passes into a height: a road-wide floor a little above the land
## around, its sides easing up into the mountains, highest at the border.
## Every zone's height ends here, so it also makes the last yards before the
## border the same in every zone.
func carve_passes(x: float, z: float, height: float) -> float:
	var point := Vector2(x, z)
	# Within EDGE_FULL of the border the ground is plain full mountain, which
	# every zone works out alike, so neighbours meet exactly whatever either
	# has near its edge (a gate's flat, a raised upland). The passes are cut
	# after, alike on both sides.
	var local := point - center
	var inward := size / 2.0 - maxf(absf(local.x), absf(local.y))
	if inward < EDGE_FULL:
		var border := base_height(x, z) + mountain_height(x, z, 1.0)
		height = lerpf(border, height, smoothstep(0.0, EDGE_FULL, inward))
	for each: Dictionary in passes():
		var line: Array = each.line
		var along := Vector2.ZERO
		var distance := INF
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
			var d := point.distance_to(a + (b - a) * t)
			if d < distance:
				distance = d
				along = a + (b - a) * t
		if distance > PASS_FLOOR + PASS_SIDES:
			continue
		var from_border := absf(along.y - float(each.z)) if each.has("z") else absf(along.x - float(each.x))
		# The crest grows with how far into the mountains the road is, so it
		# climbs over the whole rise, not up the mountains' foot.
		var rise := 1.0 if from_border < EDGE_FULL else edge_ring(along)
		var crest := PASS_CREST * _bump(from_border / 70.0) * rise
		var floor_height := base_height(along.x, along.y) + crest
		var cut := lerpf(floor_height, height, smoothstep(PASS_FLOOR, PASS_FLOOR + PASS_SIDES, distance))
		height = minf(height, cut)
	return height


## 1 at the middle, easing to 0 at t = 1.
static func _bump(t: float) -> float:
	return (cos(t * PI) + 1.0) / 2.0 if t < 1.0 else 0.0


static func distance_to_line(point: Vector2, line: Array) -> float:
	var best := INF
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var b: Vector2 = line[i + 1]
		var t := clampf((point - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		best = minf(best, point.distance_to(a + (b - a) * t))
	return best


## Distance to the nearest pass.
func distance_to_pass(point: Vector2) -> float:
	var best := INF
	for each: Dictionary in passes():
		best = minf(best, distance_to_line(point, each.line))
	return best


func ground_point(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


## Ground over the zone's square, colored by `color` (f(x, z, y, normal)).
## With `weights` (f(x, z, y, normal) -> Color of dirt, cobbles, rock and
## forest floor) it's textured (terrain_material), and `color` tints it.
## `textures` replaces the textured ground's layers (TERRAIN_TEXTURES keys
## to painted texture names) for a land of its own, such as snow.
func build_ground(step: float, color: Callable, weights := Callable(), textures := {}) -> void:
	var ground := Terrain.new()
	ground.name = "Ground"
	add_child(ground)
	var material: Material
	if weights.is_valid():
		material = terrain_material(textures)
	else:
		var flat := StandardMaterial3D.new()
		flat.vertex_color_use_as_albedo = true
		flat.vertex_color_is_srgb = true
		material = flat
	# The shared noise and the winding edges are made now, before the worker
	# threads read them.
	land_noise()
	ragged_noise()
	if _edge_depths.is_empty():
		make_edges()
	ground.build(size, step, height_at, color, material, center, weights, _ground_across)
	_ground = ground
	_weights = weights


func ground_weights() -> Callable:
	return _weights


## The herbs and ore that grow here, by kind ("herb", "ore"): node entry ->
## weight. Starting zones have the first herbs (Pale Sageleaf, Meadow
## Blossom, Earthroot) and copper; the zones past them add Mageblossom,
## Briarthorn, tin and a little silver, as classic's second zones do. A zone
## may override it.
func gather_kinds() -> Dictionary:
	if zone_name in World.START_ZONES.values():
		return { "herb": { 1617: 40, 1618: 40, 1619: 20 }, "ore": { 1731: 100 } }
	return { "herb": { 1617: 22, 1618: 22, 1619: 20, 1620: 20, 1621: 16 }, "ore": { 1731: 62, 1732: 32, 1733: 6 } }


## A forge here (at its middle): Smelting works within FORGE_RADIUS of it.
func add_forge(point: Vector3) -> void:
	forges.append(Vector2(point.x, point.z))


## Reach of a forge (classic spell focus radius).
const FORGE_RADIUS := 10.0


## A small stone forge with its hood, glowing coals and an anvil beside it,
## for towns without a smithy, facing `facing`; it counts as a forge.
func build_forge(parent: Node3D, point: Vector3, facing: float, stone: Color, wood: Color) -> void:
	var kit := BuildingKit.new(parent, "Forge")
	var basis := Basis(Vector3.UP, facing)
	var at := func(x: float, z: float, up := 0.0) -> Vector3: return point + basis * Vector3(x, up, z)
	kit.block(at.call(0, 0), Vector3(2.4, 1.4, 2.0), stone, facing, true)
	kit.block(at.call(0, 0, 1.4), Vector3(1.8, 0.12, 1.5), Color(0.55, 0.2, 0.08), facing)
	kit.cylinder(at.call(0, 0, 2.4), 1.1, 1.4, stone, 4, 0.3)
	kit.block(at.call(0, 0, 3.6), Vector3(0.6, 1.8, 0.6), stone, facing)
	kit.block(at.call(0, 2.2), Vector3(0.6, 0.6, 0.45), wood, facing, true)
	kit.block(at.call(0, 2.2, 0.6), Vector3(1.1, 0.3, 0.5), Color(0.25, 0.25, 0.28), facing)
	kit.finish()
	clear_ground(Rect2(Vector2(point.x, point.z) - Vector2(2.5, 2.5), Vector2(5, 5)))
	add_forge(point)


## The ground's height function inside the zone, and the neighbouring zone's
## beyond its edges (so the edges' slopes are worked out alike on both sides).
func _ground_across(x: float, z: float) -> float:
	var point := Vector2(x, z)
	if not contains(point) and get_parent():
		for other in get_parent().get_children():
			if other is Zone and other != self and other.contains(point):
				return other.height_at(x, z)
	return height_at(x, z)


const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const TERRAIN_TEXTURES := {
	"grass_tex": "grass", "forest_tex": "forest_floor", "dirt_tex": "dirt",
	"cobble_tex": "cobbles", "rock_tex": "rock",
}


## The textured ground's material (shaders/terrain.gdshader), with the
## painted textures (tools/textures) and a seamless noise for its borders.
static func terrain_material(textures := {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	for uniform: String in TERRAIN_TEXTURES:
		var key: String = textures.get(uniform, TERRAIN_TEXTURES[uniform])
		material.set_shader_parameter(uniform, load("res://assets/textures/%s.png" % key))
	material.set_shader_parameter("blend_noise", patch_noise())
	return material


static var _patch_noise: NoiseTexture2D


## A seamless noise texture the ground and its grass share, for ragged
## borders and large light and dark patches.
static func patch_noise() -> NoiseTexture2D:
	if _patch_noise == null:
		var noise := FastNoiseLite.new()
		noise.seed = LAND_SEED
		noise.frequency = 0.02
		noise.fractal_octaves = 3
		_patch_noise = NoiseTexture2D.new()
		_patch_noise.width = 256
		_patch_noise.height = 256
		_patch_noise.seamless = true
		_patch_noise.generate_mipmaps = true
		_patch_noise.noise = noise
	return _patch_noise


static var _patch_image: Image


## The patch noise at a point of the ground as the terrain shader reads it
## (its `blend_noise` at `uv`, repeating, filtered between texels).
static func patch_value(uv: Vector2) -> float:
	if _patch_image == null:
		var texture := patch_noise()
		# The same image the texture makes (its defaults: no invert, 2D, a
		# skirt of 0.1, normalized).
		_patch_image = texture.noise.get_seamless_image(texture.width, texture.height, false, false, 0.1, true)
	var size := Vector2(_patch_image.get_width(), _patch_image.get_height())
	var at := Vector2(fposmod(uv.x, 1.0), fposmod(uv.y, 1.0)) * size - Vector2(0.5, 0.5)
	var x0 := floori(at.x)
	var y0 := floori(at.y)
	var f := at - Vector2(x0, y0)
	var w := int(size.x)
	var h := int(size.y)
	var a := _patch_image.get_pixel(posmod(x0, w), posmod(y0, h)).r
	var b := _patch_image.get_pixel(posmod(x0 + 1, w), posmod(y0, h)).r
	var c := _patch_image.get_pixel(posmod(x0, w), posmod(y0 + 1, h)).r
	var d := _patch_image.get_pixel(posmod(x0 + 1, w), posmod(y0 + 1, h)).r
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## Whether the textured ground shows rock at a point (its `weights`, the
## zone's layers function, read as shaders/terrain.gdshader does: rock takes
## over where its weight beats the noise), rather than grass or dirt. Trees
## don't grow there.
func shows_rock(point: Vector2, y: float, weights: Callable) -> bool:
	var step := 1.0
	var normal := Vector3(height_at(point.x - step, point.y) - height_at(point.x + step, point.y), 2.0 * step,
		height_at(point.x, point.y - step) - height_at(point.x, point.y + step)).normalized()
	var rock: float = (weights.call(point.x, point.y, y, normal) as Color).b
	if rock <= 0.001:
		return false
	if rock >= 0.999:
		return true
	var threshold := lerpf(0.2, 0.8, patch_value(point * 0.11))
	return rock > threshold


var _ground: Terrain


## The height of the ground as built (Terrain.sample), once it is; before
## that, the height function.
func ground_height(x: float, z: float) -> float:
	return _ground.sample(x, z) if _ground else height_at(x, z)


## Water at a height over the zone's square.
## `styled` draws it with the pixel-art water shader (shaders/water.gdshader:
## depth color, ripples, foam), else a flat see-through blue.
func build_water(level: float, styled := false) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	if styled:
		var shaded := ShaderMaterial.new()
		shaded.shader = WATER_SHADER
		shaded.set_shader_parameter("ripple_noise", patch_noise())
		plane.material = shaded
	else:
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.22, 0.42, 0.62, 0.75)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.roughness = 0.2
		plane.material = water
	var view := MeshInstance3D.new()
	view.name = "Water"
	view.mesh = plane
	view.position = Vector3(center.x, level, center.y)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## Invisible walls round the zone's square, open where a pass crosses them.
func build_edges() -> void:
	var walls := StaticBody3D.new()
	walls.name = "Edges"
	add_child(walls)
	var half := size / 2.0 - EDGE_INSET
	# Each side as a line from one corner to the next.
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for side in 4:
		var a: Vector2 = center + corners[side]
		var b: Vector2 = center + corners[(side + 1) % 4]
		var gaps: Array[float] = []
		for each: Dictionary in passes():
			var line: Array = each.line
			for i in line.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(a, b, line[i], line[i + 1])
				if hit != null:
					gaps.append((hit as Vector2).distance_to(a))
		gaps.sort()
		var length := a.distance_to(b)
		var start := 0.0
		for gap in gaps + [length + PASS_GAP]:
			var end: float = gap - PASS_GAP
			if end > start:
				_wall(walls, a.lerp(b, (start + end) / 2.0 / length), end - start, b - a)
			start = gap + PASS_GAP


func _wall(parent: StaticBody3D, at: Vector2, length: float, direction: Vector2) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 200.0, 2.0)
	shape.shape = box
	shape.position = Vector3(at.x, 50.0, at.y)
	shape.rotation.y = -direction.angle()
	parent.add_child(shape)


## A 5 yard wide walkway whose top runs from one point to the other.
func plank(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var thickness := 0.4
	var length := from.distance_to(to)
	var slope := atan2(to.y - from.y, to.z - from.z)
	var body := StaticBody3D.new()
	body.position = (from + to) / 2.0
	# Turning about +X lowers the +Z end, so a rise toward +Z is a negative angle.
	body.rotation.x = -slope
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5, thickness, length)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = Props.material(Color(0.45, 0.31, 0.2))
	view.position.y = -thickness / 2.0
	body.add_child(view)
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -thickness / 2.0
	body.add_child(collision)
	parent.add_child(body)


## A row of sharpened logs from one point to another, `height` tall (the
## Horde's palisades).
func palisade(parent: Node3D, from: Vector2, to: Vector2, y: float, color: Color, height := 4.5) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / length
	Props.box(parent, Vector3((from.x + to.x) / 2, y, (from.y + to.y) / 2), Vector3(length, height, 0.9), color, -direction.angle())
	var steps := int(length / 1.5)
	var tips: Array[Transform3D] = []
	for i in steps + 1:
		var at := from.lerp(to, float(i) / maxf(steps, 1))
		tips.append(Transform3D(Basis(), Vector3(at.x, y + height + 0.5, at.y)))
	Props.scatter(parent, Props.cone(0.5, 1.2, 5), color, tips)


## A round Horde hut: low log walls under a tall hide roof, a bone spike on top.
func round_hut(parent: Node3D, at: Vector2, radius: float, y: float, wall: Color, roof_color: Color, spike: Color) -> void:
	Props.cylinder(parent, Vector3(at.x, y, at.y), radius, 2.6, wall)
	var roof := MeshInstance3D.new()
	roof.mesh = Props.cone(radius * 1.25, radius * 1.1, 8)
	roof.material_override = Props.material(roof_color)
	roof.position = Vector3(at.x, y + 2.6 + radius * 0.55, at.y)
	parent.add_child(roof)
	Props.box(parent, Vector3(at.x, y + 2.6 + radius * 1.1, at.y), Vector3(0.25, 1.6, 0.25), spike, 0.0, false)


## A Hornkin tipi `radius` round (one solid, Nature's: light or dark hides
## by `hide`), its door turned toward `facing` (x, z) or south.
func tipi(parent: Node3D, at: Vector2, y: float, radius: float, hide: Color, _pole: Color, facing := Vector2.ZERO) -> void:
	var yaw := 0.0 if facing == Vector2.ZERO else atan2((facing - at).x, (facing - at).y)
	var kind := "tipi_light" if hide.get_luminance() > 0.5 else "tipi_dark"
	place_baked(parent, kind, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * radius / 3.0), Vector3(at.x, y, at.y)),
		true, int(absf(at.x * 7.0 + at.y * 13.0)))


## A great totem `height` tall (one solid, Nature's, painted in the Hornkin's
## colours).
func totem(parent: Node3D, at: Vector2, y: float, height: float, _colors: Array) -> void:
	place_baked(parent, "totem", Transform3D(Basis().scaled(Vector3.ONE * height / 8.0), Vector3(at.x, y, at.y)))


func torch(parent: Node3D, at: Vector3, light_range := 4.0) -> void:
	var flame := MeshInstance3D.new()
	flame.mesh = Props.blob(0.25, 5, 3)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.6, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.5, 0.15)
	glow.emission_energy_multiplier = 2.0
	flame.material_override = glow
	flame.position = at
	parent.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.35)
	light.omni_range = light_range
	light.position = at + Vector3(0, 0.3, 0)
	parent.add_child(light)


## Ground clutter for the Environment Detail option: share of the tufts and
## flowers drawn.
const CLUTTER_SHARE := { "Off": 0.0, "Low": 0.33, "Medium": 0.66, "High": 1.0 }

var _clutter: Array[MultiMeshInstance3D] = []


func add_clutter(parent: Node3D, mesh: Mesh, color: Color, transforms: Array[Transform3D]) -> void:
	Props.scatter(parent, mesh, color, transforms)
	var view := parent.get_child(parent.get_child_count() - 1) as MultiMeshInstance3D
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clutter.append(view)


## The textured zones' nature (Nature): tree, rock and bush shapes in a few
## variants each, grass and flower cards drawn to CARD_RANGE yards (they
## shrink away before that), bushes to BUSH_RANGE.
const TREE_VARIANTS := 4
const ROCK_VARIANTS := 5
const BUSH_VARIANTS := 4
const CARD_RANGE := 62.0
const BUSH_RANGE := 140.0
## The kinds a zone's grass place function can make (add_nature_clutter).
const CARD_KINDS := ["grass", "tall", "flowers_yellow", "flowers_white", "flowers_blue", "ferns", "wheat",
	"frost_grass", "heather", "dry_grass", "dead_blades", "elf_blades", "plains_blades"]

var _clutter_share := 0.66
## Ground built on (BuildingKit footprints): no grass or bushes there.
var _cleared: Array[Rect2] = []


func clear_ground(square: Rect2) -> void:
	_cleared.append(square)


## Whether a point is under a building. Read from ClutterField's worker
## thread once the buildings are up.
func is_cleared(point: Vector2) -> bool:
	for square in _cleared:
		if square.has_point(point):
			return true
	return false


## One baked solid (Nature.tree: a great tree, a bower, a hut...) at `place`
## (scale and all), with collision from its own faces when `solid`.
func place_baked(parent: Node3D, kind: String, place: Transform3D, solid := true, variant := 0) -> MeshInstance3D:
	var mesh := Nature.tree(kind, variant)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.transform = place
	parent.add_child(view)
	if solid:
		var faces := mesh.get_faces()
		for i in faces.size():
			faces[i] = place * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		var body := StaticBody3D.new()
		body.add_child(collision)
		parent.add_child(body)
	return view


## A list per variant, for placing trees, rocks or bushes in.
static func variant_lists(count: int) -> Array:
	var lists := []
	for i in count:
		lists.append([] as Array[Transform3D])
	return lists


## Pines and oaks (lists per variant of where they stand) under `parent`;
## `snowy` lays snow on their boughs.
func draw_trees(parent: Node3D, pines: Array, oaks: Array, rng_seed: int, snowy := false) -> void:
	for i in TREE_VARIANTS:
		Nature.scatter(parent, Nature.pine_mesh(rng_seed + 10 + i, snowy), pines[i])
		Nature.scatter(parent, Nature.oak_mesh(rng_seed + 20 + i), oaks[i])


## Boulders; `snowy` caps them with snow rather than moss, `texture` is
## their stone.
func draw_rocks(parent: Node3D, rocks: Array, rng_seed: int, snowy := false, texture := "rock") -> void:
	for i in ROCK_VARIANTS:
		Nature.scatter(parent, Nature.rock_mesh(rng_seed + 30 + i, snowy, texture), rocks[i])


## Grass, flowers and ferns, and bushes, made near the camera (ClutterField):
## `grass` is f(point, rng) -> [one of CARD_KINDS, Transform3D] or [], tried
## every yard; `bush` the same with a variant number, tried every 4 yards.
## `snowy` puts snow on the bushes; `dry` makes them dead bushes, bare twigs;
## `leaves` is the bushes' leaf texture.
func add_nature_clutter(grass: Callable, bush: Callable, rng_seed: int, snowy := false, dry := false, leaves := "leaves") -> void:
	var square := Rect2(center - Vector2.ONE * size / 2.0, Vector2.ONE * size)
	var patches := patch_noise()
	var clump := Nature.card_mesh(1.1, 0.45)
	var cards := ClutterField.new()
	cards.name = "Grass"
	cards.zone = self
	cards.area = square
	cards.rng_seed = rng_seed
	cards.reach = CARD_RANGE + 8.0
	cards.range_end = CARD_RANGE
	cards.place = grass
	cards.kinds = {
		"grass": [clump, Nature.card_material("grass_blades", patches)],
		"tall": [Nature.card_mesh(0.8, 0.75), Nature.card_material("grass_blades", patches, 0.12)],
		"flowers_yellow": [clump, Nature.card_material("flowers_yellow", patches)],
		"flowers_white": [clump, Nature.card_material("flowers_white", patches)],
		"flowers_blue": [clump, Nature.card_material("flowers_blue", patches)],
		"ferns": [Nature.card_mesh(1.3, 0.85), Nature.card_material("ferns", patches, 0.05)],
		"wheat": [Nature.card_mesh(1.0, 1.0, 2), Nature.card_material("wheat", patches, 0.1)],
		"frost_grass": [Nature.card_mesh(0.9, 0.6), Nature.card_material("frost_grass", patches, 0.1)],
		"heather": [Nature.card_mesh(0.9, 0.4), Nature.card_material("heather", patches, 0.04)],
		"dry_grass": [Nature.card_mesh(1.0, 0.55), Nature.card_material("dry_grass", patches, 0.1)],
		"dead_blades": [Nature.card_mesh(1.0, 0.5), Nature.card_material("dead_blades", patches, 0.1)],
		"elf_blades": [Nature.card_mesh(1.0, 0.55), Nature.card_material("elf_blades", patches, 0.1)],
		"plains_blades": [Nature.card_mesh(0.9, 0.85), Nature.card_material("plains_blades", patches, 0.14)],
	}
	add_child(cards)
	var bushes := ClutterField.new()
	bushes.name = "Bushes"
	bushes.zone = self
	bushes.area = square
	bushes.rng_seed = rng_seed + 1
	bushes.chunk = 48.0
	bushes.step = 4.0
	bushes.reach = BUSH_RANGE + 10.0
	bushes.range_end = BUSH_RANGE
	bushes.shadows = true
	bushes.thinned = false
	bushes.place = bush
	for i in BUSH_VARIANTS:
		bushes.kinds[str(i)] = [Nature.dead_bush_mesh(rng_seed + 40 + i) if dry else Nature.bush_mesh(rng_seed + 40 + i, snowy, leaves), null]
	add_child(bushes)


## Clutter the Environment Detail option thins (a ClutterField's chunks).
func add_clutter_view(view: MultiMeshInstance3D) -> void:
	_clutter.append(view)
	_thin(view)


func forget_clutter(view: MultiMeshInstance3D) -> void:
	_clutter.erase(view)


func _thin(view: MultiMeshInstance3D) -> void:
	view.visible = _clutter_share > 0.0
	view.multimesh.visible_instance_count = roundi(view.multimesh.instance_count * _clutter_share)


## The Environment Detail option: how much of the clutter is drawn.
func set_clutter(level: String) -> void:
	_clutter_share = CLUTTER_SHARE.get(level, 0.66)
	for view in _clutter:
		_thin(view)


## The zone's game objects (quest_objects, chests), under an Objects node.
func spawn_objects(rng_seed: int, water_level: float) -> void:
	var objects := Node3D.new()
	objects.name = "Objects"
	add_child(objects)
	for spec: Array in quest_objects:
		var thing := QuestObject.new()
		thing.name = spec[1]
		thing.entry = spec[0]
		thing.position = ground_point(spec[2].x, spec[2].y)
		thing.rotation.y = spec[3]
		objects.add_child(thing)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for group: Array in chests:
		for i in int(group[3]):
			var chest := GameObject.new()
			chest.entry = group[0]
			chest.position = _spawn_point(rng, group[1], group[2], water_level)
			chest.rotation.y = rng.randf() * TAU
			objects.add_child(chest)


## Creatures, placed the same way each time so saved corpses match by name:
## `prefix` keeps names apart between zones.
func spawn_creatures(rng_seed: int, prefix: String, passive_entries: Array, water_level: float) -> void:
	gather_field = GatherNodes.populate(self, rng_seed + 77, water_level)
	var creatures := Node3D.new()
	creatures.name = "Creatures"
	add_child(creatures)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for group in spawns.size():
		var spawn: Array = spawns[group]
		for i in int(spawn[3]):
			var at := _spawn_point(rng, spawn[1], spawn[2], water_level)
			var enemy: Enemy = AshfordVale.ENEMY_SCENE.instantiate()
			enemy.name = "%s%02d_%02d" % [prefix, group, i]
			enemy.creature_entry = spawn[0]
			enemy.passive = spawn[0] in passive_entries
			enemy.position = at + Vector3(0, 0.1, 0)
			creatures.add_child(enemy)


func _spawn_point(rng: RandomNumberGenerator, around: Vector2, radius: float, water_level: float) -> Vector3:
	var point := around
	for attempt in 20:
		var angle := rng.randf() * TAU
		point = around + Vector2(cos(angle), sin(angle)) * sqrt(rng.randf()) * radius
		if height_at(point.x, point.y) > water_level + 0.3:
			break
	return ground_point(point.x, point.y)
