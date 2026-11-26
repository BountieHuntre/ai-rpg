class_name Zone
extends Node3D
## What every zone shares. Zones sit side by side in their continent's world
## (World), each a square SIZE yards across around its center, in world
## coordinates, with mountains along its edges. Where two zones meet, both use
## the same mountain shape from the same noise, so the ground joins up, and a
## pass (PASSES) is cut through the mountains on both sides. -Z is north.

## Mountain noise shared by every zone, in world coordinates.
static var LAND_SEED := 1077
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
static var PASS_FLOOR := 7.0
static var PASS_SIDES := 13.0
## How high the pass climbs at the border, over the land around it.
static var PASS_CREST := 7.0
## Half the width of the gap in the edge walls where a pass crosses them.
static var PASS_GAP := 10.0
static var MOUNTAIN_HEIGHT := 38.0
static var MOUNTAIN_ROUGHNESS := 14.0
## Players can't walk past this far from the center, along each axis, except
## through a pass.
static var EDGE_INSET := 4.0

## The edge mountains wind in and out (`edge_ring`): along each side of the
## square they start anywhere from EDGE_NEAR yards in to EDGE_FAR (EDGE_FAR_SMALL
## on the 400-yard starting zones), by noise every EDGE_STEP yards, but never
## nearer than EDGE_CLEAR to anything the zone keeps clear (`edge_keep`).
static var EDGE_NEAR := 25.0
static var EDGE_FAR := 150.0
static var EDGE_FAR_SMALL := 100.0
static var EDGE_STEP := 8.0
static var EDGE_CLEAR := 15.0
static var EDGE_FULL := 6.0
## The mountains rise to full height over this many yards from where they
## start, so a deep spur is a solid ridge, not a long slope.
static var EDGE_RISE := 45.0
## Within PASS_RIDGE_SPAN yards along an edge of where a pass crosses it, the
## mountains start at least PASS_RIDGE yards in, so the pass is cut through a
## ridge and climbs gently to its crest.
static var PASS_RIDGE := 60.0
static var PASS_RIDGE_SPAN := 45.0

## Ragged places (`ragged_distance`): a circle's rim wobbles in and out by up
## to this share of its radius.
static var RAGGED := 0.3
## Rolling hills over every zone's open land (hill_height): how high they
## rise, how far apart (yards between tops, roughly), and how far they take
## to fade out round what's kept level (hill_keep).
static var HILL_HEIGHT := 20.0
## How much the hills differ in size (the smallest a share of HILL_HEIGHT),
## how far apart big and small ones lie, and the bumps over their slopes.
static var HILL_LEAST := 0.35
static var HILL_SIZE_SPACING := 420.0
static var HILL_BUMPS := 2.2
static var HILL_BUMP_SPACING := 45.0
static var HILL_SPACING := 170.0
static var HILL_FADE := 30.0
## The hills' level mask: a grid this many yards a cell.
static var HILL_CELL := 4.0

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
## The ground's colour function (build_ground's), for cave mouths' rims.
var _ground_color := Callable()
## Walled places bots go in and out of by the gate:
## [x min, z min, x max, z max, outside the gate, inside the gate].
var enclosures: Array = []


# Caves (Caves): tunnels and chambers dug into the zone's own hills and
# mountains, the ground opened where the hillside crosses the way in.

## The zone's caves (add_cave): { kind, variant, mouth (x, z), facing,
## layout (Caves.layout), base (the mouth's floor height, worked out before
## the ground is built), to_local, rect (the box it and its levelled ground
## cover), lit, creature and count (a wild cave's dwellers) }.
var caves: Array[Dictionary] = []
## Set while working out the ground without the caves (their bases).
var _caves_off := false
## The zone's hand edits (ZoneEdits: heights, cave vertices, additions,
## cuts), laid over what the code builds; and, while exporting, off.
var _edits: ZoneEdits
var _edits_off := false
## The rock texture of this land's ground (build_ground's rock_tex).
var _rock_key := "rock"
## Yards of ground kept over a cave's ceiling (raised where the hill is thin),
## and how far round it the raising eases out.
static var CAVE_COVER := 3.0
static var CAVE_RAMP := 14.0
## Within this of the mouth (along the way in, the cave's own yards) the
## ground isn't raised, so the hillside meets the tunnel there.
static var CAVE_MOUTH := 6.0
## The render layer the caves' rock is drawn on, which the sun doesn't
## light (World.build takes it out of the sun's light_cull_mask).
const CAVE_RENDER_LAYER := 1 << 2
## A cave's mouth is made new (_mouth): in its own yards, the ground's
## cells in a window hugging the tunnel (as wide as it is where it's cut and
## MOUTH_MARGIN more either side, at most MOUTH_HALF; `cave.window`), from
## MOUTH_BACK inside to MOUTH_FRONT out, are left out whole, and the cave is
## cut by an upright plane MOUTH_DEPTH inside, just within the hillside, so
## its own rock makes the mouth; a new rim joins the window's edge to the
## cut's edge, sharing both edges' points.
static var MOUTH_HALF := 9.0
static var MOUTH_MARGIN := 1.5
static var MOUTH_BACK := 2.5
static var MOUTH_DEPTH := 1.0
static var MOUTH_FRONT := 1.0
## Boxes inside the caves (Node3D, their `size` meta): the camera in one is
## indoors (main.gd), for the dark.
const CAVE_AIR_GROUP := &"cave_air"
## How many wild caves a zone gets for its size (400 yards: 2).
static var WILD_CAVES_PER_AREA := 2.0
static var WILD_CAVE_SEARCH := 400


## Adds a cave: its mouth at `mouth`, the cave running back the way `facing`
## turns -Z (yaw), of `kind` ("den" or "lair") variant `variant`. Options:
## "lit" (torches inside; lairs by default), "creature" and "count" (who
## lives in a wild cave). Call before the ground is built.
func add_cave(mouth: Vector2, facing: float, kind: String, variant: int, options := {}) -> Dictionary:
	variant = variant % int(Caves.VARIANTS[kind])
	var layout := Caves.layout(kind, variant)
	var turn := Transform3D(Basis(Vector3.UP, facing), Vector3(mouth.x, 0, mouth.y))
	var box := Rect2(Vector2(INF, INF), Vector2.ZERO)
	var corners: Rect2 = (layout.footprint as Rect2).grow(CAVE_RAMP + 4.0)
	var first := true
	for corner: Vector2 in [corners.position, corners.position + Vector2(corners.size.x, 0), corners.end, corners.position + Vector2(0, corners.size.y)]:
		var w := turn * Vector3(corner.x, 0, corner.y)
		box = Rect2(Vector2(w.x, w.z), Vector2.ZERO) if first else box.expand(Vector2(w.x, w.z))
		first = false
	# The apron before the mouth too.
	var apron := turn * Vector3(0, 0, 14.0)
	box = box.expand(Vector2(apron.x, apron.z))
	var cave := {
		"kind": kind, "variant": variant, "mouth": mouth, "facing": facing, "layout": layout, "base": NAN,
		"to_local": turn.affine_inverse(), "rect": box, "lit": bool(options.get("lit", kind == "lair")),
		"creature": int(options.get("creature", 0)), "count": int(options.get("count", 0)),
		"name": str(options.get("name", "")), "takes": options.get("takes", []),
	}
	caves.append(cave)
	return cave


## The zone's own caves: [mouth (x, z), the way the cave runs into the hill
## (a yaw: 0 runs toward +z), its place's name, lit with torches, and the
## creature entries it takes in wherever they spawn (besides the groups by
## its mouth)]. Each is a lair (Caves); the zone adds wild dens of its own.
func cave_mouths() -> Array:
	return []


## A cave's place in the world: its own yards to the world's.
func cave_transform(cave: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, cave.facing), Vector3(cave.mouth.x, cave.base, cave.mouth.y))


func _cave_local(cave: Dictionary, x: float, z: float) -> Vector2:
	var local: Vector3 = (cave.to_local as Transform3D) * Vector3(x, 0, z)
	return Vector2(local.x, local.z)


## The floor's height inside a cave at a point, or NAN outside every cave
## (or in its rock).
func cave_floor(x: float, z: float) -> float:
	for cave: Dictionary in caves:
		if is_nan(cave.base) or not (cave.rect as Rect2).has_point(Vector2(x, z)):
			continue
		var height := Caves.floor_at(cave.layout, _cave_local(cave, x, z))
		if not is_nan(height):
			return float(cave.base) + height
	return NAN


## The ground for the caves: raised where the hill over a cave would leave
## less than CAVE_COVER over its ceiling (easing out over CAVE_RAMP), never
## over the mouth, and level with its floor on an apron before the mouth, so
## the hillside meets the way in.
func _ground_for_caves(x: float, z: float, height: float) -> float:
	for cave: Dictionary in caves:
		if is_nan(cave.base) or not (cave.rect as Rect2).has_point(Vector2(x, z)):
			continue
		var local := _cave_local(cave, x, z)
		var layout: Dictionary = cave.layout
		var base := float(cave.base)
		# Over the hollows (spread out, so the hill rounds over them), all but
		# the way in by the mouth, where the hillside meets the tunnel.
		# (Over the collar too, back to the window's edge.)
		var by_mouth := 1.0 - smoothstep(7.0, 12.0, absf(local.x))
		var deep := 1.0 - by_mouth * (1.0 - smoothstep(MOUTH_FRONT, -MOUTH_BACK, local.y))
		if deep > 0.0:
			var wanted := NAN
			var reach := 0.0
			for spread: float in [1.0, 1.6, 2.4]:
				var roof := Caves.ceiling_at(layout, local, spread)
				if not is_nan(roof):
					wanted = base + roof + CAVE_COVER
					reach = 1.0 - smoothstep(1.0, 2.4, spread)
					break
			if not is_nan(wanted) and height < wanted:
				var weight := deep * (1.0 if reach >= 1.0 else smoothstep(0.0, 1.0, reach + 0.35))
				height = lerpf(height, wanted, weight)
		# The apron before the mouth, level with its floor right up to the
		# mouth across the way in, so the grass is the floor out front and
		# the hillside rises from the mouth itself.
		var across := 1.0 - smoothstep(6.0, 10.0, absf(local.x))
		var before := smoothstep(-1.5, 1.0, local.y) * (1.0 - smoothstep(14.0, 20.0, local.y))
		var apron := maxf(across * before, 1.0 - smoothstep(5.0, 11.0, local.distance_to(Vector2(0, 9))))
		if apron > 0.0:
			height = lerpf(height, base, apron)
	return height


## Whether the ground's point (x, z, height) is in a cave's hollows: the
## ground built leaves its triangles out there (Terrain.build's `hole`), the
## opening where the hillside crosses the way in. Read from the ground's
## worker threads once the bases are settled.
func cave_hole(x: float, z: float, y: float) -> bool:
	# Inside a hand edit's cut shape.
	if _edits != null and not _edits.cuts.is_empty() and _edits.cut(Vector3(x, y, z)):
		return true
	for cave: Dictionary in caves:
		if is_nan(cave.base) or not (cave.rect as Rect2).has_point(Vector2(x, z)):
			continue
		var local := _cave_local(cave, x, z)
		# The window round the mouth, where the new mouth (_mouth) takes the
		# ground's place.
		if _in_window(cave, local):
			return true
		# Further in (never out front), wherever the ground would show inside
		# the hollows.
		var at := Vector3(local.x, y - float(cave.base), local.y)
		if local.y < -MOUTH_BACK and Caves.inside(cave.layout, at, 0.0) and at.y > Caves.floor_at(cave.layout, local) + 0.35:
			return true
	return false


## Whether a point (a cave's own yards, x and z) is in its mouth's window.
static func _in_window(cave: Dictionary, local: Vector2) -> bool:
	var window: Vector2 = cave.get("window", Vector2(-MOUTH_HALF, MOUTH_HALF))
	return local.x > window.x and local.x < window.y and local.y > -MOUTH_BACK and local.y < MOUTH_FRONT


## How many steps a mouth's rim takes from the ground to the cave, and how
## far (yards) the noise pushes its rock in or out between.
static var RIM_STEPS := 4
static var RIM_CRAG := 1.4


## How far a cave's tunnel reaches to either side where it's cut (MOUTH_DEPTH
## in), at any height between its floor and roof, plus MOUTH_MARGIN: its
## window's sides (Vector2(left, right), in its own yards).
static func _window_of(cave: Dictionary) -> Vector2:
	var layout: Dictionary = cave.layout
	var sides := Vector2.ZERO
	for side: float in [-1.0, 1.0]:
		var reach := 0.0
		var x := 0.0
		while x < MOUTH_HALF:
			var at := Vector2(side * x, -MOUTH_DEPTH)
			var low := Caves.floor_at(layout, at)
			var any := false
			if not is_nan(low):
				var y := low + 0.3
				while y < low + 8.0:
					if Caves.inside(layout, Vector3(at.x, y, at.y), 0.0):
						any = true
						break
					y += 0.5
			if any:
				reach = x
			elif x > 1.0:
				break
			x += 0.25
		var edge := minf(reach + MOUTH_MARGIN, MOUTH_HALF)
		if side < 0.0:
			sides.x = -edge
		else:
			sides.y = edge
	return sides


## Works out each cave's base (the ground at its mouth without the caves),
## once, on the main thread before the ground is built.
func _settle_caves() -> void:
	_caves_off = true
	for cave: Dictionary in caves:
		if is_nan(cave.base):
			cave.base = height_at(cave.mouth.x, cave.mouth.y)
		cave.window = _window_of(cave)
	_caves_off = false
	# No grass on the apron or in the mouth.
	for cave: Dictionary in caves:
		var apron := cave_transform(cave) * Vector3(0, 0, 4.0)
		clear_ground(Rect2(apron.x - 8.0, apron.z - 8.0, 16.0, 16.0))


## Wild caves dug into the zone's slopes: a den with its mouth on a slope
## and running uphill into ground that already covers most of it (the rest
## is raised), away from what's kept clear, water, the borders and each
## other; WILD_CAVES_PER_AREA for 400 by 400 yards, home to the creature
## whose spawn is nearest. Run once the hills are known.
func _place_wild_caves() -> void:
	var wanted := mini(roundi(WILD_CAVES_PER_AREA * size * size / (400.0 * 400.0)), 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(zone_name + ":caves"))
	var keep: Array = edge_keep()[0]
	var half := size / 2.0
	var placed := 0
	for attempt in WILD_CAVE_SEARCH * 3:
		if placed >= wanted:
			break
		var point := center + Vector2(rng.randf_range(-half + 50.0, half - 50.0), rng.randf_range(-half + 50.0, half - 50.0))
		if keep.any(func(circle: Array) -> bool: return point.distance_to(circle[0]) < float(circle[1]) + 25.0):
			continue
		if caves.any(func(other: Dictionary) -> bool: return point.distance_to(other.mouth) < 100.0):
			continue
		var y := height_at(point.x, point.y)
		if y - base_height(point.x, point.y) < -0.5:
			continue
		# Uphill, and steep enough to dig into.
		var slope := Vector2(height_at(point.x + 2.0, point.y) - height_at(point.x - 2.0, point.y),
			height_at(point.x, point.y + 2.0) - height_at(point.x, point.y - 2.0)) / 4.0
		if slope.length() < 0.22 or slope.length() > 1.2:
			continue
		var uphill := slope.normalized()
		var facing := atan2(-uphill.x, -uphill.y)
		var variant := rng.randi_range(0, int(Caves.VARIANTS.den) - 1)
		var layout := Caves.layout("den", variant)
		# The ground must already cover most of it, and it must stay in the zone.
		var turn := Transform3D(Basis(Vector3.UP, facing), Vector3(point.x, y, point.y))
		var covered := 0
		var counted := 0
		var outside := false
		for hollow: Array in layout.voids:
			var c: Vector3 = hollow[0]
			if c.z > -CAVE_MOUTH:
				continue
			var w := turn * c
			if not Rect2(center - Vector2.ONE * (half - 30.0), Vector2.ONE * (size - 60.0)).has_point(Vector2(w.x, w.z)):
				outside = true
				break
			counted += 1
			if height_at(w.x, w.z) >= w.y + float(hollow[3]) + 1.0:
				covered += 1
		if outside or counted == 0 or covered < counted * 0.6:
			continue
		var nearest := 0
		var best := INF
		for spawn: Array in spawns:
			var d := point.distance_to(spawn[1])
			if d < best:
				best = d
				nearest = int(spawn[0])
		if nearest == 0:
			continue
		add_cave(point, facing, "den", variant, { "creature": nearest, "count": rng.randi_range(3, 4), "lit": false })
		placed += 1


## The caves' walls, darkness, torches, rocks round their mouths and the
## way in for bots; nature cleared from their mouths, and creatures moved in
## (spawn_creatures runs it first).
func build_caves() -> void:
	if caves.is_empty():
		return
	var root := Node3D.new()
	root.name = "Caves"
	add_child(root)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/textured_prop.gdshader")
	material.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % _rock_key))
	material.set_shader_parameter("texture_size", 5.0)
	material.set_shader_parameter("tint", Vector3(0.9, 0.9, 0.9))
	enclosures = enclosures.duplicate()
	var noise := FastNoiseLite.new()
	noise.seed = absi(hash(zone_name))
	noise.frequency = 0.32
	for cave: Dictionary in caves:
		var place := cave_transform(cave)
		var mesh: Mesh = load(Caves.BAKED_PATH % [cave.kind, cave.variant])
		if mesh == null:
			continue
		# The cave behind an upright plane MOUTH_DEPTH in, cut exactly, and a
		# new mouth in front of it (_mouth).
		var faces := mesh.get_faces()
		for i in faces.size():
			faces[i] = place * faces[i]
		var clipped := _clip_behind(faces, cave)
		var kept: PackedVector3Array = clipped[0]
		var rim: Array = _mouth(cave, clipped[1], noise)
		# As the code built it (one side of the rim), for the Blender export;
		# then the hand edits' moved vertices (ZoneEdits).
		var built := kept.duplicate()
		var rim_faces: PackedVector3Array = rim[0]
		for t in range(0, rim_faces.size(), 6):
			built.append_array([rim_faces[t], rim_faces[t + 1], rim_faces[t + 2]])
		cave.built_faces = built
		if _edits != null:
			kept = _edits.move_cave_faces(cave, kept)
			rim[0] = _edits.move_cave_faces(cave, rim_faces)
		_draw_rim(root, rim[0], rim[1], material)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Each face its own normal, so the texture's projection follows it.
		surface.set_smooth_group(-1)
		for point in kept:
			surface.add_vertex(point)
		surface.generate_normals()
		var view := MeshInstance3D.new()
		view.mesh = surface.commit()
		view.material_override = material
		# It faces inward, so from the sun its roof is a back face: shadows
		# from both sides, or the sun lights the floor through it. And the sun
		# leaves its rock alone altogether (CAVE_RENDER_LAYER), as shadows
		# leak where floor meets wall: torches and the sky's dim ambient light
		# it.
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		view.layers = CAVE_RENDER_LAYER
		root.add_child(view)
		var shape := ConcavePolygonShape3D.new()
		var solid := kept.duplicate()
		solid.append_array(rim[0])
		shape.set_faces(solid)
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		var body := StaticBody3D.new()
		body.add_child(collision)
		root.add_child(body)
		var layout: Dictionary = cave.layout
		# Its rock as placed, for setting things against it (ore veins).
		cave.faces = solid
		_frame_mouth(root, cave, place, material, noise)
		# Dark inside, as rooms are, with no haze: boxes that only say the
		# camera is indoors (CAVE_AIR_GROUP, main.gd's indoor ambient), not
		# the rooms' dust, so the sun at the mouth lights no fog.
		for box: Array in layout.dust:
			var air := Node3D.new()
			air.name = "Air"
			air.transform = place * Transform3D(Basis(), box[0])
			air.set_meta("size", box[1])
			air.add_to_group(CAVE_AIR_GROUP)
			root.add_child(air)
		if cave.lit:
			# Torches on the walls, found by a ray from the tunnel's middle to
			# the rock; a campfire on the first chamber's floor.
			for spot: Array in layout.torches:
				var from := place * (spot[0] as Vector3)
				var way := (place.basis * (spot[1] as Vector3)).normalized()
				var hit := _ray_to_faces(from, way, kept)
				if not hit.is_empty():
					wall_torch(root, hit[0], hit[1], 9.0)
			var fire := place * (layout.campfire as Vector3)
			campfire(root, Vector3(fire.x, ground_height(fire.x, fire.z, fire.y), fire.z), 11.0)
		# A strongbox at the back, there about half the time.
		var chest := GameObject.new()
		chest.entry = GameObject.TREASURE[0] if continent == "aldmark" else GameObject.TREASURE[1]
		chest.chance = 0.5
		var spot := place * (layout.chest as Vector3)
		chest.position = Vector3(spot.x, ground_height(spot.x, spot.z, spot.y), spot.z)
		chest.rotation.y = float(cave.facing) + PI
		root.add_child(chest)
		# Bots go in and out by the mouth.
		var hollow: Rect2 = layout.footprint
		var low := Vector2(INF, INF)
		var high := -low
		for corner: Vector2 in [hollow.position, hollow.position + Vector2(hollow.size.x, 0), hollow.end, hollow.position + Vector2(0, hollow.size.y)]:
			var w := place * Vector3(corner.x, 0, corner.y)
			low = low.min(Vector2(w.x, w.z))
			high = high.max(Vector2(w.x, w.z))
		var outside := place * (layout.outside as Vector3)
		var inside := place * (layout.inside as Vector3)
		enclosures.append([low.x, low.y, high.x, high.y, Vector2(outside.x, outside.z), Vector2(inside.x, inside.z)])
	_clear_nature_in_caves(root)
	_move_spawns_into_caves()


## Where ore grows in the caves: each one's veins at the foot of its
## chamber walls, on its floor, as [point, yaw facing out of the wall]
## (GatherNodes puts nodes there first).
func cave_ore_spots() -> Array:
	var spots: Array = []
	for cave: Dictionary in caves:
		if is_nan(cave.base):
			continue
		var place := cave_transform(cave)
		var faces: PackedVector3Array = cave.get("faces", PackedVector3Array())
		var placed: Array[Vector3] = []
		for vein: Array in cave.layout.ore:
			var at := place * (vein[0] as Vector3)
			var inward := (place.basis * (vein[1] as Vector3)).normalized()
			# Right against the rock: rays out to the placed walls (passing the
			# floor's humps and steps) a yard over the floor, the nearest one
			# that's clear of the other veins, the vein set a little short of it.
			var best := Vector3.INF
			var best_in := inward
			for k in 8:
				var way := (-inward).rotated(Vector3.UP, TAU * k / 8.0)
				var hit := _ray_to_faces(at + Vector3(0, 1.0, 0), way, faces, true)
				if hit.is_empty():
					continue
				var foot := (hit[0] as Vector3) - way * 0.45
				if placed.any(func(other: Vector3) -> bool: return other.distance_to(foot) < 3.0):
					continue
				if best == Vector3.INF or at.distance_to(foot) < at.distance_to(best):
					best = foot
					best_in = -way
			if best != Vector3.INF:
				at = best
				inward = best_in
			placed.append(at)
			spots.append([Vector3(at.x, ground_height(at.x, at.z, at.y), at.z), atan2(inward.x, inward.z)])
	return spots


## The nearest of `faces` (triangles, world yards) a ray meets within 22
## yards: [point, the face's normal turned back toward the ray], or [].
## With `walls_only` faces no steeper than a slope (the floor's humps) are
## passed through.
static func _ray_to_faces(from: Vector3, way: Vector3, faces: PackedVector3Array, walls_only := false) -> Array:
	var best := 22.0
	var found := []
	for t in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(from, way, faces[t], faces[t + 1], faces[t + 2])
		if hit == null:
			continue
		var distance := from.distance_to(hit)
		if distance < best:
			var normal := (faces[t + 1] - faces[t]).cross(faces[t + 2] - faces[t]).normalized()
			if walls_only and absf(normal.y) > 0.6:
				continue
			best = distance
			if normal.dot(way) > 0.0:
				normal = -normal
			found = [hit, normal]
	return found


## A torch fixed to a wall at `at`, leaning out along `out` (the wall's
## normal, kept level): an iron bracket, a stick and its flame, with a light
## that lights the place, not the air.
func wall_torch(parent: Node3D, at: Vector3, out: Vector3, light_range := 8.0) -> void:
	out.y = 0.0
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var torch_root := Node3D.new()
	torch_root.name = "WallTorch"
	torch_root.position = at
	torch_root.basis = Basis.looking_at(-out)
	parent.add_child(torch_root)
	Props.box(torch_root, Vector3(0, -0.24, 0.04), Vector3(0.14, 0.24, 0.12), Color(0.2, 0.2, 0.22), 0.0, false)
	# The stick stands on its foot at the bracket (Props.box places a box by
	# its bottom) and leans out; its head is a dark wrap at its tip, and the
	# fire burns from the head's middle.
	var foot := Vector3(0, -0.2, 0.18)
	var lean := Basis(Vector3.RIGHT, 0.45)
	var stick := Props.box(torch_root, foot, Vector3(0.08, 0.6, 0.08), Color(0.35, 0.22, 0.12), 0.0, false)
	stick.rotation.x = 0.45
	var head := Props.box(torch_root, foot + lean * Vector3(0, 0.5, 0), Vector3(0.12, 0.14, 0.12), Color(0.2, 0.13, 0.08), 0.0, false)
	head.rotation.x = 0.45
	Fire.make(torch_root, foot + lean * Vector3(0, 0.57, 0), 0.3, light_range)


## A campfire on the ground at `at`: a ring of stones, crossed logs and a
## fire burning on them, with a low flickering light.
func campfire(parent: Node3D, at: Vector3, light_range := 10.0) -> void:
	var fire := Node3D.new()
	fire.name = "Campfire"
	fire.position = at
	parent.add_child(fire)
	for i in 8:
		var angle := TAU * i / 8.0
		Props.box(fire, Vector3(cos(angle), 0, sin(angle)) * 0.75, Vector3(0.32, 0.22, 0.28), Color(0.38, 0.36, 0.34), angle, false)
	for i in 3:
		var log_box := Props.box(fire, Vector3(0, 0.08, 0), Vector3(1.0, 0.16, 0.16), Color(0.32, 0.2, 0.11), TAU * i / 3.0, false)
		log_box.rotation.z = 0.25
	# Burning on the logs (Fire: flames, embers, smoke and a flickering light).
	Fire.make(fire, Vector3(0, 0.12, 0), 0.7, light_range, 1.4, Color(1.0, 0.6, 0.3))


## The hand edits' added pieces (ZoneEdits.additions): each drawn as rock, or
## as the ground (its colour and layers there) when its material is named
## "ground", with collision from its faces.
func _build_edit_additions() -> void:
	if _edits == null or _edits.additions.is_empty():
		return
	var root := Node3D.new()
	root.name = "EditAdditions"
	add_child(root)
	var rock := ShaderMaterial.new()
	rock.shader = load("res://shaders/textured_prop.gdshader")
	rock.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % _rock_key))
	rock.set_shader_parameter("texture_size", 5.0)
	rock.set_shader_parameter("tint", Vector3(0.9, 0.9, 0.9))
	var body := StaticBody3D.new()
	root.add_child(body)
	for piece: Dictionary in _edits.additions:
		var faces: PackedVector3Array = piece.faces
		if faces.is_empty():
			continue
		if "ground" in str(piece.material).to_lower():
			var shares := PackedFloat32Array()
			shares.resize(faces.size())
			_draw_rim(root, faces, shares, rock)
		else:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_smooth_group(-1)
			for point in faces:
				surface.add_vertex(point)
			surface.generate_normals()
			var view := MeshInstance3D.new()
			view.name = str(piece.name)
			view.mesh = surface.commit()
			view.material_override = rock
			root.add_child(view)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)


## Yards apart the rocks framing a cave's mouth lie along its edge, how big
## they are (least and most), and how far into the hillside each is sunk (a
## share of its size).
static var MOUTH_ROCK_SPACING := 1.7
static var MOUTH_ROCK_LEAST := 0.45
static var MOUTH_ROCK_MOST := 2.6
static var MOUTH_ROCK_SINK := 0.6
## How the sizes lean small: 1 spreads them evenly, more gives many small
## rocks and a few big crags.
static var MOUTH_ROCK_SKEW := 1.8
## Rocks running on down each side of the mouth onto the ground at its foot.
static var MOUTH_FOOT_ROCKS := 3
## The share of places along the edge that get a rock (the rest are gaps).
static var MOUTH_ROCK_CHANCE := 0.8
## How far (yards) each rock is pushed out from the opening, a share of its
## size, so none hangs into the way in.
static var MOUTH_ROCK_OUT := 0.45
## Height (yards over the floor) below which the edge across the way in gets
## no rocks.
static var MOUTH_ROCK_DOORSTEP := 1.0
## Boulders on the ground beside the mouth (besides the frame), least and most.
static var MOUTH_BOULDERS_LEAST := 2
static var MOUTH_BOULDERS_MOST := 4


## Rocks round a cave's mouth: a frame of jagged crags (Caves.crag), many
## small and a few big, set deep into the hillside along the edge where the
## rim meets the ground (`rim_edge`, from _mouth), each pushed out from the
## opening, with gaps, none on the doorstep across the way in, running on
## down each side onto the ground at its foot; and a few boulders on the
## ground beside the mouth.
func _frame_mouth(parent: Node3D, cave: Dictionary, place: Transform3D, material: Material, noise: FastNoiseLite) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(cave.mouth))
	var body := StaticBody3D.new()
	var to_local: Transform3D = cave.to_local
	var base := float(cave.base)
	var window: Vector2 = cave.get("window", Vector2(-MOUTH_HALF, MOUTH_HALF))
	var doorway := maxf(absf(window.x), absf(window.y)) - MOUTH_MARGIN + 0.5
	var spots: Array = []
	# Along the edge, every MOUTH_ROCK_SPACING yards.
	var edge: Array = cave.get("rim_edge", [])
	var walked := 0.0
	var next := rng.randf_range(0.0, MOUTH_ROCK_SPACING)
	for k in edge.size():
		var a: Vector3 = edge[k]
		var b: Vector3 = edge[(k + 1) % edge.size()]
		var length := a.distance_to(b)
		while next <= walked + length:
			var at := a.lerp(b, (next - walked) / maxf(length, 0.001))
			next += MOUTH_ROCK_SPACING * rng.randf_range(0.7, 1.3)
			if rng.randf() > MOUTH_ROCK_CHANCE:
				continue
			var l := to_local * at
			if l.y - base < MOUTH_ROCK_DOORSTEP and absf(l.x) < doorway:
				continue
			var size := lerpf(MOUTH_ROCK_LEAST, MOUTH_ROCK_MOST, pow(rng.randf(), MOUTH_ROCK_SKEW))
			# Out from the opening's middle, across the hillside.
			var out := Vector3(l.x, l.y - base - 2.8, 0.0)
			out = out.normalized() if out.length() > 0.01 else Vector3.UP
			var local := l + out * size * MOUTH_ROCK_OUT
			local.y -= size * MOUTH_ROCK_SINK
			spots.append([to_local.affine_inverse() * local, size, true])
		walked += length
	# On down each side to the foot of the mouth and out onto the ground,
	# clear of the doorway, against the hillside.
	for side: float in [-1.0, 1.0]:
		var x := doorway + 0.6
		for k in MOUTH_FOOT_ROCKS:
			var size := lerpf(MOUTH_ROCK_LEAST, MOUTH_ROCK_MOST, pow(rng.randf(), MOUTH_ROCK_SKEW))
			x += size * rng.randf_range(0.5, 0.9)
			var w := to_local.affine_inverse() * Vector3(side * x, base, rng.randf_range(-1.5, 0.5))
			w.y = ground_height(w.x, w.z) - size * MOUTH_ROCK_SINK * 0.8
			spots.append([w, size, true])
			x += size * rng.randf_range(0.4, 0.8)
	# Boulders on the ground beside the mouth.
	for k in rng.randi_range(MOUTH_BOULDERS_LEAST, MOUTH_BOULDERS_MOST):
		var side := 1.0 if k % 2 == 0 else -1.0
		var w := place * Vector3(side * rng.randf_range(5.5, 8.0), 0, rng.randf_range(2.0, 7.0))
		var size := rng.randf_range(0.8, 1.6)
		w.y = ground_height(w.x, w.z) + size * 0.15
		spots.append([w, size, false])
	for spot: Array in spots:
		var size: float = spot[1]
		var radii := Vector3(size * rng.randf_range(0.8, 1.4), size * rng.randf_range(0.6, 1.1), size * rng.randf_range(0.8, 1.4))
		# The frame jagged and split (Caves.crag); the boulders worn round.
		var lump := Caves.crag(spot[0], radii, rng.randf() * TAU, noise) if spot[2] else Caves.rock(spot[0], radii, rng.randf() * TAU, noise)
		var view := MeshInstance3D.new()
		view.mesh = lump
		view.material_override = material
		view.layers = CAVE_RENDER_LAYER | 1
		parent.add_child(view)
		var shape := CollisionShape3D.new()
		shape.shape = lump.create_convex_shape()
		body.add_child(shape)
	parent.add_child(body)


## A cave mouth's rim, drawn with the ground's own material: each point
## coloured and layered as the ground would be there (its edge on the
## ground exactly as the ground's), turning to rock as it goes in (`shares`,
## 0 at the ground to 1 at the cave). Without a textured ground, the cave's
## rock.
func _draw_rim(parent: Node3D, faces: PackedVector3Array, shares: PackedFloat32Array, rock: Material) -> void:
	if faces.is_empty():
		return
	var ground_material: Material = null
	if _ground != null:
		for child in _ground.get_children():
			if child is MeshInstance3D:
				ground_material = (child as MeshInstance3D).mesh.surface_get_material(0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var textured := ground_material != null and _weights.is_valid() and _ground_color.is_valid()
	var step := _ground._step if _ground != null else 2.0
	for k in faces.size():
		var p := faces[k]
		if textured:
			var normal := Vector3(height_at(p.x - step, p.z) - height_at(p.x + step, p.z), 2.0 * step, height_at(p.x, p.z - step) - height_at(p.x, p.z + step)).normalized()
			var share := smoothstep(0.0, 0.7, shares[k])
			var layers: Color = _weights.call(p.x, p.z, p.y, normal)
			layers.b = lerpf(layers.b, 1.0, share)
			surface.set_uv(Vector2(layers.r, layers.g))
			surface.set_uv2(Vector2(layers.b, layers.a))
			surface.set_color(_ground_color.call(p.x, p.z, p.y, normal))
		surface.add_vertex(p)
	surface.generate_normals()
	var view := MeshInstance3D.new()
	view.name = "Rim"
	view.mesh = surface.commit()
	view.material_override = ground_material if textured else rock
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	parent.add_child(view)


## A cave's faces cut by the upright plane MOUTH_DEPTH inside its mouth:
## the part behind it, triangles crossing it split exactly, and the cut's
## edge as segments in the plane. [faces, segments].
func _clip_behind(faces: PackedVector3Array, cave: Dictionary) -> Array:
	var to_local: Transform3D = cave.to_local
	var kept := PackedVector3Array()
	var segments: Array = []
	# Where an edge meets the plane, worked out the same way from either face
	# that has it, so neighbours share the point exactly.
	var meet := func(p: Vector3, q: Vector3, dp: float, dq: float) -> Vector3:
		if str(p) > str(q):
			return q.lerp(p, dq / (dq - dp))
		return p.lerp(q, dp / (dp - dq))
	for t in range(0, faces.size(), 3):
		var tri := [faces[t], faces[t + 1], faces[t + 2]]
		var d := [(to_local * (tri[0] as Vector3)).z + MOUTH_DEPTH, (to_local * (tri[1] as Vector3)).z + MOUTH_DEPTH, (to_local * (tri[2] as Vector3)).z + MOUTH_DEPTH]
		var behind := 0
		for k in 3:
			if float(d[k]) < 0.0:
				behind += 1
		if behind == 3:
			kept.append_array([tri[0], tri[1], tri[2]])
			continue
		if behind == 0:
			continue
		# The part behind the plane, its corners in order.
		var polygon: Array = []
		var cut: Array = []
		for k in 3:
			var p: Vector3 = tri[k]
			var q: Vector3 = tri[(k + 1) % 3]
			var dp: float = d[k]
			var dq: float = d[(k + 1) % 3]
			if dp < 0.0:
				polygon.append(p)
			if (dp < 0.0) != (dq < 0.0):
				var on: Vector3 = meet.call(p, q, dp, dq)
				polygon.append(on)
				cut.append(on)
		for k in range(1, polygon.size() - 1):
			kept.append_array([polygon[0], polygon[k], polygon[k + 1]])
		if cut.size() == 2:
			segments.append(cut)
	return [kept, segments]


## The ground's cells in a cave's mouth window (by their middles), as grid
## cells (column, row), as Terrain.build left them out.
func _window_cells(cave: Dictionary) -> Dictionary:
	var cells := {}
	if _ground == null:
		return cells
	var origin := _ground._origin
	var step := _ground._step
	var count := _ground._cells
	var rect: Rect2 = cave.rect
	var low := Vector2i(clampi(floori((rect.position.x - origin.x) / step), 0, count - 1), clampi(floori((rect.position.y - origin.y) / step), 0, count - 1))
	var high := Vector2i(clampi(ceili((rect.end.x - origin.x) / step), 0, count - 1), clampi(ceili((rect.end.y - origin.y) / step), 0, count - 1))
	for row in range(low.y, high.y + 1):
		for column in range(low.x, high.x + 1):
			if _in_window(cave, _cave_local(cave, origin.x + (column + 0.5) * step, origin.y + (row + 0.5) * step)):
				cells[Vector2i(column, row)] = true
	return cells


## A closed loop from segments sharing their ends (points matched to a
## thousandth of a yard): the longest, in order.
static func _chain(segments: Array) -> Array:
	var key := func(point: Vector3) -> Vector3i: return Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))
	var links := {}
	for segment: Array in segments:
		for k in 2:
			var here: Vector3i = key.call(segment[k])
			if not links.has(here):
				links[here] = []
			(links[here] as Array).append(segment[1 - k])
	var used := {}
	var best: Array = []
	for start_key: Vector3i in links:
		if used.has(start_key):
			continue
		var loop: Array = []
		var current_key := start_key
		var current: Vector3 = Vector3.ZERO
		var previous_key := Vector3i(2147483647, 0, 0)
		for segment: Array in segments:
			if key.call(segment[0]) == start_key:
				current = segment[0]
				break
			if key.call(segment[1]) == start_key:
				current = segment[1]
				break
		while not used.has(current_key):
			used[current_key] = true
			loop.append(current)
			var next: Variant = null
			for candidate: Vector3 in links[current_key]:
				var candidate_key: Vector3i = key.call(candidate)
				if candidate_key != previous_key and not used.has(candidate_key):
					next = candidate
					break
			if next == null:
				break
			previous_key = current_key
			current = next
			current_key = key.call(next)
		if loop.size() > best.size():
			best = loop
	return best


## A cave's new mouth: the surface joining the edge of the window the
## ground left out (a loop of the ground's own edge points, round the cut
## cells) to the cave's cut edge (a loop in the plane MOUTH_DEPTH inside).
## Both loops start at their bottom middle (the floor's middle, the window's
## front middle) and run the same way round; their points are paired by how
## far round each loop they are, so nothing crosses, and both loops' points
## are shared exactly: the ground, the mouth and the cave are one surface.
## Both sides, as it's seen from in and out.
func _mouth(cave: Dictionary, segments: Array, noise: FastNoiseLite) -> Array:
	var surface := PackedVector3Array()
	var cells := _window_cells(cave)
	if cells.is_empty() or segments.is_empty():
		return [surface, PackedFloat32Array()]
	var to_local: Transform3D = cave.to_local
	var base := float(cave.base)
	# The window's edge: each cut cell's sides, the ones two cut cells share
	# cancelled, chained round.
	var origin := _ground._origin
	var step := _ground._step
	var width := _ground._cells + 1
	var heights: PackedFloat32Array = _ground._heights
	var corner_at := func(at: Vector2i) -> Vector3:
		return Vector3(origin.x + at.x * step, heights[at.y * width + at.x], origin.y + at.y * step)
	var sides := {}
	for cell: Vector2i in cells:
		var corners := [cell, cell + Vector2i(1, 0), cell + Vector2i(1, 1), cell + Vector2i(0, 1)]
		for k in 4:
			var a: Vector2i = corners[k]
			var b: Vector2i = corners[(k + 1) % 4]
			var reverse := str([b, a])
			if sides.has(reverse):
				sides.erase(reverse)
			else:
				sides[str([a, b])] = [a, b]
	var window_segments: Array = []
	for pair: Array in sides.values():
		window_segments.append([corner_at.call(pair[0]), corner_at.call(pair[1])])
	var outer := _chain(window_segments)
	var inner := _chain(segments)
	if outer.size() < 3 or inner.size() < 3:
		return [surface, PackedFloat32Array()]
	# Both from their bottom middle, the same way round (toward the cave's +x
	# first).
	var start_outer := 0
	var start_inner := 0
	var best_outer := INF
	var best_inner := INF
	for k in outer.size():
		var l := to_local * (outer[k] as Vector3)
		var score := absf(l.x) + absf(l.z - MOUTH_FRONT) * 2.0
		if score < best_outer:
			best_outer = score
			start_outer = k
	for k in inner.size():
		var l := to_local * (inner[k] as Vector3)
		var score := absf(l.x) + (l.y - base) * 3.0
		if score < best_inner:
			best_inner = score
			start_inner = k
	outer = outer.slice(start_outer) + outer.slice(0, start_outer)
	inner = inner.slice(start_inner) + inner.slice(0, start_inner)
	# Where the rim meets the hillside, for the rocks framing it (_frame_mouth).
	cave.rim_edge = outer.duplicate()
	for loop: Array in [outer, inner]:
		var ahead := to_local * (loop[mini(2, loop.size() - 1)] as Vector3)
		var first := to_local * (loop[0] as Vector3)
		if ahead.x < first.x:
			var rest := loop.slice(1)
			rest.reverse()
			loop.resize(1)
			loop.append_array(rest)
	# How far round each loop each point is (0 to 1).
	var round_of := func(loop: Array) -> Array:
		var lengths: Array = [0.0]
		for k in loop.size():
			lengths.append(float(lengths[k]) + (loop[k] as Vector3).distance_to(loop[(k + 1) % loop.size()]))
		var total: float = lengths.back()
		return lengths.map(func(length: float) -> float: return length / total)
	var t_outer: Array = round_of.call(outer)
	var t_inner: Array = round_of.call(inner)
	# Rungs from the window's edge to the cut's, zipped all the way round
	# back to the start.
	var rungs: Array = [[outer[0], inner[0]]]
	var i := 0
	var j := 0
	while i < outer.size() or j < inner.size():
		if j >= inner.size() or (i < outer.size() and float(t_outer[i + 1]) <= float(t_inner[j + 1])):
			i += 1
		else:
			j += 1
		rungs.append([outer[i % outer.size()], inner[j % inner.size()]])
	# Each rung in RIM_STEPS, its middle pushed in or out from the tunnel's
	# middle by the noise (never on the floor, never at its ends), so the
	# rim is craggy rock while both edges stay shared.
	var to_world := to_local.affine_inverse()
	var points: Array = []
	for rung: Array in rungs:
		var row: Array = []
		for m in RIM_STEPS + 1:
			var along := float(m) / RIM_STEPS
			var p: Vector3 = (rung[0] as Vector3).lerp(rung[1], along)
			if m > 0 and m < RIM_STEPS:
				var l := to_local * p
				var radial := Vector3(l.x, l.y - base - 2.8, 0.0)
				if radial.length() > 0.01:
					var lift := smoothstep(0.5, 2.0, l.y - base)
					p += to_world.basis * radial.normalized() * noise.get_noise_3dv(p * 1.6) * RIM_CRAG * sin(PI * along) * lift
			row.append(p)
		points.append(row)
	var shares := PackedFloat32Array()
	for r in range(rungs.size() - 1):
		var a: Array = points[r]
		var b: Array = points[r + 1]
		for m in RIM_STEPS:
			var s0 := float(m) / RIM_STEPS
			var s1 := float(m + 1) / RIM_STEPS
			for tri: Array in [[a[m], b[m], b[m + 1], s0, s0, s1], [a[m], b[m + 1], a[m + 1], s0, s1, s1]]:
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				if p0.distance_squared_to(p1) < 1e-8 or p1.distance_squared_to(p2) < 1e-8 or p0.distance_squared_to(p2) < 1e-8:
					continue
				surface.append_array([p0, p1, p2, p0, p2, p1])
				shares.append_array([tri[3], tri[4], tri[5], tri[3], tri[5], tri[4]])
	return [surface, shares]


## Trees, boulders and cacti the zone scattered in a cave's mouth or on its
## apron: their copies shrunk to nothing, their trunks' shapes gone.
func _clear_nature_in_caves(skip: Node) -> void:
	var inside := func(at: Vector3) -> bool:
		for cave: Dictionary in caves:
			if not (cave.rect as Rect2).has_point(Vector2(at.x, at.z)):
				continue
			var local := _cave_local(cave, at.x, at.z)
			if local.distance_to(Vector2(0, 6)) < 10.0 or cave_hole(at.x, at.z, at.y + 0.5):
				return true
		return false
	for node: Node in find_children("*", "MultiMeshInstance3D", true, false):
		var view := node as MultiMeshInstance3D
		var multimesh := view.multimesh
		if multimesh == null or multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var origin := view.global_transform
		for i in multimesh.instance_count:
			var t := multimesh.get_instance_transform(i)
			if inside.call(origin * t.origin):
				multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
	for node: Node in find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if skip.is_ancestor_of(shape) or not shape.get_parent() is StaticBody3D:
			continue
		if not (shape.shape is CylinderShape3D or shape.shape is SphereShape3D or shape.shape is CapsuleShape3D):
			continue
		if inside.call(shape.global_position):
			shape.queue_free()


## Creatures move into the caves: a lair takes the spawn groups whose middle
## lies within 35 yards of its mouth or over it, spread over its spots inside; a wild cave gets a group of
## its own. Each group keeps its place in `spawns` (enemy names and saved
## corpses go by it); a group in a cave carries its points as a fifth field.
func _move_spawns_into_caves() -> void:
	spawns = spawns.duplicate(true)
	var claimed := {}
	for cave: Dictionary in caves:
		var place := cave_transform(cave)
		var layout: Dictionary = cave.layout
		var points: Array = []
		for spot: Vector3 in layout.creatures:
			points.append(place * spot)
		if points.is_empty():
			continue
		if int(cave.creature) != 0:
			var mouth: Vector3 = points[0]
			spawns.append([int(cave.creature), Vector2(mouth.x, mouth.z), 0.0, int(cave.count), points.slice(maxi(points.size() - int(cave.count) - 1, 0))])
			continue
		# The groups about its mouth, or over the cave itself.
		var groups: Array[int] = []
		for i in spawns.size():
			var at: Vector2 = spawns[i][1]
			if claimed.has(i) or spawns[i].size() > 4:
				continue
			if at.distance_to(cave.mouth) < 35.0 or int(spawns[i][0]) in cave.takes or not is_nan(Caves.floor_at(layout, _cave_local(cave, at.x, at.y))):
				groups.append(i)
		var next := 0
		for i in groups:
			claimed[i] = true
			var count := int(spawns[i][3])
			var own: Array = []
			for k in count:
				own.append(points[(next + k) % points.size()])
			next += count
			spawns[i] = [spawns[i][0], Vector2((own[0] as Vector3).x, (own[0] as Vector3).z), 0.0, count, own]


static var _hill_noise: FastNoiseLite
static var _hill_size_noise: FastNoiseLite
static var _hill_bump_noise: FastNoiseLite


## Which hills are big and which small (HILL_SIZE_SPACING), and the bumps
## over their slopes (HILL_BUMP_SPACING): world-yard noise, shared.
static func hill_size_noise() -> FastNoiseLite:
	if _hill_size_noise == null:
		_hill_size_noise = FastNoiseLite.new()
		_hill_size_noise.seed = LAND_SEED + 37
		_hill_size_noise.frequency = 1.0 / HILL_SIZE_SPACING
		_hill_size_noise.fractal_octaves = 2
	return _hill_size_noise


static func hill_bump_noise() -> FastNoiseLite:
	if _hill_bump_noise == null:
		_hill_bump_noise = FastNoiseLite.new()
		_hill_bump_noise.seed = LAND_SEED + 41
		_hill_bump_noise.frequency = 1.0 / HILL_BUMP_SPACING
		_hill_bump_noise.fractal_octaves = 2
	return _hill_bump_noise


## The noise the rolling hills follow, in world yards, so neighbouring zones
## share it.
static func hill_noise() -> FastNoiseLite:
	if _hill_noise == null:
		_hill_noise = FastNoiseLite.new()
		_hill_noise.seed = LAND_SEED + 31
		_hill_noise.frequency = 1.0 / HILL_SPACING
		_hill_noise.fractal_octaves = 3
		_hill_noise.fractal_gain = 0.45
	return _hill_noise


## How much of the hills a point gets (0 to 1), from the grid made by
## make_hill_mask: none on and round what the zone keeps level.
var _hill_mask := PackedFloat32Array()
var _hill_cells := Vector2i.ZERO
var _hill_origin := Vector2.ZERO


## The rolling hills at a point, before anything else is cut: broad rounded
## rises with plains between, faded out round towns, roads, NPCs and the
## like (hill_keep), where the zone has cut the ground below its plain level
## (lakes, streams, the sea, so no water is filled in) and where it has raised
## it already (its own hills, the edge mountains). `height` is the ground
## there without them.
func hill_height(x: float, z: float, height: float) -> float:
	if _hill_mask.is_empty() or _hills_off:
		return 0.0
	var n := hill_noise().get_noise_2d(x, z)
	# Rounded tops: the shape only tops out where the noise rarely reaches,
	# so each hill peaks at its own height rather than a common plateau.
	var rise := smoothstep(-0.08, 0.65, n)
	if rise <= 0.0:
		return 0.0
	# Big hills and small ones, and bumps over their slopes.
	var size := lerpf(HILL_LEAST, 1.0, clampf(hill_size_noise().get_noise_2d(x, z) * 1.4 + 0.5, 0.0, 1.0))
	var bumps := hill_bump_noise().get_noise_2d(x, z) * HILL_BUMPS * minf(rise * 2.0, 1.0)
	var mask := _mask_at(x, z)
	# Ground cut below the plain land (water) keeps none, and ground the zone
	# has already raised (its own hills, the edge mountains) little more, so
	# they don't pile up into crags.
	var raised := height - base_height(x, z)
	mask *= smoothstep(-2.5, 0.0, raised) * (1.0 - smoothstep(3.0, 12.0, raised))
	return maxf(HILL_HEIGHT * size * rise + bumps, 0.0) * mask


## About how much the rolling hills raise a point (for the ground's layers):
## their shape and the level mask, less on the edge mountains, without the
## exact checks against the zone's own height, so it needs nothing but the
## point (safe on the ground's worker threads).
func hill_estimate(x: float, z: float) -> float:
	if _hill_mask.is_empty():
		return 0.0
	var rise := smoothstep(-0.08, 0.65, hill_noise().get_noise_2d(x, z))
	if rise <= 0.0:
		return 0.0
	var size := lerpf(HILL_LEAST, 1.0, clampf(hill_size_noise().get_noise_2d(x, z) * 1.4 + 0.5, 0.0, 1.0))
	return HILL_HEIGHT * size * rise * _mask_at(x, z) * (1.0 - edge_ring(Vector2(x, z)))


## The level mask at a point, bilinear in its grid.
func _mask_at(x: float, z: float) -> float:
	var g := (Vector2(x, z) - _hill_origin) / HILL_CELL
	var i := clampi(floori(g.x), 0, _hill_cells.x - 2)
	var j := clampi(floori(g.y), 0, _hill_cells.y - 2)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fz := clampf(g.y - j, 0.0, 1.0)
	var row := _hill_cells.x
	var a := lerpf(_hill_mask[j * row + i], _hill_mask[j * row + i + 1], fx)
	var b := lerpf(_hill_mask[(j + 1) * row + i], _hill_mask[(j + 1) * row + i + 1], fx)
	return lerpf(a, b, fz)


## What the hills keep level: circles [center, radius] and lines (lists of
## points): what the edge mountains keep clear of but the spawns (creatures
## may roam hills). NPCs out in the open are raised onto them instead
## (lift_npcs).
func hill_keep() -> Array:
	var keep := edge_keep()
	var circles: Array = []
	var spawn_middles := {}
	for spawn: Array in spawns:
		spawn_middles[Vector2(spawn[1])] = true
	for circle: Array in keep[0]:
		if not spawn_middles.has(Vector2(circle[0])):
			circles.append(circle)
	return [circles, keep[1]]


## Set while working out the ground without the hills (lift_npcs).
var _hills_off := false


## NPCs are placed at heights in their scenes, on the ground as it was
## without the hills: each is raised by as much as the hills add under it
## (nothing on level ground, so those on floors and counters stay put), and
## its spot to come back to with it.
func lift_npcs() -> void:
	for node: Node in find_children("*", "Npc", true, false):
		var npc := node as Npc
		var at := npc.global_position
		var with_hills := height_at(at.x, at.z)
		_hills_off = true
		var without := height_at(at.x, at.z)
		_hills_off = false
		var lift := with_hills - without
		if absf(lift) < 0.01:
			continue
		npc.global_position.y += lift
		npc._home = npc.position


## Stamps hill_keep onto the level mask, once, before the ground is built
## (its worker threads only read it).
func make_hill_mask() -> void:
	_hill_origin = center - Vector2.ONE * size / 2.0 - Vector2.ONE * HILL_CELL
	_hill_cells = Vector2i.ONE * (ceili(size / HILL_CELL) + 3)
	_hill_mask = PackedFloat32Array()
	_hill_mask.resize(_hill_cells.x * _hill_cells.y)
	_hill_mask.fill(1.0)
	var keep := hill_keep()
	for circle: Array in keep[0]:
		_stamp(circle[0], circle[0], float(circle[1]))
	for line: Array in keep[1]:
		for k in line.size() - 1:
			_stamp(line[k], line[k + 1], 6.0)


## Lowers the mask round a segment (a circle when `a` is `b`) of `radius`.
func _stamp(a: Vector2, b: Vector2, radius: float) -> void:
	var reach := radius + HILL_FADE
	var low := ((Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * reach - _hill_origin) / HILL_CELL).floor()
	var high := ((Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * reach - _hill_origin) / HILL_CELL).ceil()
	var along := b - a
	var length_squared := along.length_squared()
	for j in range(maxi(int(low.y), 0), mini(int(high.y), _hill_cells.y - 1) + 1):
		for i in range(maxi(int(low.x), 0), mini(int(high.x), _hill_cells.x - 1) + 1):
			var point := _hill_origin + Vector2(i, j) * HILL_CELL
			var t := 0.0 if length_squared < 0.001 else clampf((point - a).dot(along) / length_squared, 0.0, 1.0)
			var d := point.distance_to(a + along * t)
			if d >= reach:
				continue
			var index := j * _hill_cells.x + i
			_hill_mask[index] = minf(_hill_mask[index], smoothstep(radius, reach, d))


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
	# The rolling hills over open land (hill_height), then the ground over and
	# before the caves (_ground_for_caves), before the border and passes,
	# which are cut alike in every zone.
	height += hill_height(x, z, height)
	if not _caves_off and not caves.is_empty():
		height = _ground_for_caves(x, z, height)
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
	# Last, the hand edits' raising and lowering (ZoneEdits), nothing at the
	# border, so whatever the code makes, they lie over it.
	if _edits != null and not _edits_off:
		height += _edits.height(x, z)
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
	# The hand edits first: every height asked for from here on has them.
	_edits = ZoneEdits.load_for(zone_name)
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
	hill_noise()
	hill_size_noise()
	hill_bump_noise()
	_rock_key = str(textures.get("rock_tex", "rock"))
	if _edge_depths.is_empty():
		make_edges()
	if _hill_mask.is_empty():
		make_hill_mask()
	# The zone's own caves (cave_mouths), lairs at its old cave mouths and
	# mines, running into the hill the way the old mouth faced.
	if caves.is_empty():
		for mouth: Array in cave_mouths():
			add_cave(mouth[0], float(mouth[1]) + PI, "lair", absi(hash(str(mouth[2]))) % int(Caves.VARIANTS.lair),
				{ "name": str(mouth[2]), "lit": bool(mouth[3]) if mouth.size() > 3 else true, "takes": mouth[4] if mouth.size() > 4 else [] })
	if not caves.any(func(cave: Dictionary) -> bool: return cave.kind == "den"):
		_caves_off = true
		_place_wild_caves()
		_caves_off = false
	_settle_caves()
	# The layers see the ground's height as it was without the rolling hills,
	# so a hilltop isn't painted as the high rock meant for mountains.
	if weights.is_valid():
		var layers := weights
		weights = func(x: float, z: float, y: float, normal: Vector3) -> Color:
			return layers.call(x, z, y - hill_estimate(x, z), normal)
	ground.build(size, step, height_at, color, material, center, weights, _ground_across, cave_hole if not caves.is_empty() or (_edits != null and not _edits.cuts.is_empty()) else Callable())
	_ground = ground
	_weights = weights
	_ground_color = color
	lift_npcs()


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
static var FORGE_RADIUS := 10.0


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
func ground_height(x: float, z: float, near_y := NAN) -> float:
	var ground := _ground.sample(x, z) if _ground else height_at(x, z)
	# Over a cave: its floor for what's nearer it than the ground on top.
	if not is_nan(near_y):
		var floor_y := cave_floor(x, z)
		if not is_nan(floor_y) and absf(near_y - floor_y) < absf(near_y - ground):
			return floor_y
	return ground


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


## A flame at `at` (a torch's head, a brazier, a lamp on a post): a Fire,
## its light flickering.
func torch(parent: Node3D, at: Vector3, light_range := 4.0) -> void:
	Fire.make(parent, at - Vector3(0, 0.08, 0), 0.3, light_range)


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
static var TREE_VARIANTS := 4
static var ROCK_VARIANTS := 5
static var BUSH_VARIANTS := 4
static var CARD_RANGE := 62.0
static var BUSH_RANGE := 140.0
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
	build_caves()
	_build_edit_additions()
	gather_field = GatherNodes.populate(self, rng_seed + 77, water_level)
	var creatures := Node3D.new()
	creatures.name = "Creatures"
	add_child(creatures)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for group in spawns.size():
		var spawn: Array = spawns[group]
		var in_cave: Array = spawn[4] if spawn.size() > 4 else []
		for i in int(spawn[3]):
			var at := _spawn_point(rng, spawn[1], spawn[2], water_level)
			# In a cave: on its spots, on the cave's floor.
			if not in_cave.is_empty():
				var spot: Vector3 = in_cave[i % in_cave.size()]
				at = Vector3(spot.x, ground_height(spot.x, spot.z, spot.y), spot.z)
			var enemy: Enemy = AshfordVale.ENEMY_SCENE.instantiate()
			if not in_cave.is_empty():
				enemy.wander_override = 2.0
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
