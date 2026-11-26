class_name Caves
extends RefCounted
## Caves grown from a seed, dug into the zones' own hills and mountains: a
## winding tunnel and lopsided chambers, baked (tools/models/nature/bake_caves.gd)
## as one mesh, the inside of the hollows (their CSG union, less the rock
## left standing in them, turned inward): walls, ceilings and the floor. The
## zone puts it under ground high enough to cover it and opens the ground
## where the hillside crosses the tunnel (Zone.cave_hole). Each variant is
## made the same way every time from its kind and number, so the game reads
## where its floor and ceiling lie and where its creatures, ore, chest and
## torches go from the same layout the bake made.
##
## In a variant's own yards the mouth is at the origin and the cave runs back
## along -Z. Its floor is the bottom of the hollows: each hollow is a lumpy
## dome on a flat base at the path's floor there, so where domes overlap the
## floor steps, and the path rises and falls along the way.
## Kinds: "den" (a short tunnel to one chamber, for wild caves) and "lair"
## (a longer tunnel forking to three chambers and a dead end or two, for the
## named caves and mines).

const BAKED_PATH := "res://assets/models/caves/%s_%d.res"
const VARIANTS := { "den": 8, "lair": 5 }
## Yards between the domes along a tunnel.
static var STEP := 3.0
## How far the path may turn each step, and how far from its first heading.
static var TURN := 0.3
static var WANDER := 1.1
## How much the floor may rise or fall each step, and in all.
static var FLOOR_STEP := 0.22
static var FLOOR_RANGE := 1.4
## How wide and high the tunnels run (they pinch and bulge between).
const TUNNEL_WIDTH := Vector2(7.0, 11.0)
const TUNNEL_HEIGHT := Vector2(5.0, 7.5)

static var _cache := {}


## A variant's layout (cached): its hollows ("voids": [center at the floor,
## half width, half length, height, heading], the floor at center.y), its
## chambers ([center, radius]), spots ("creatures", "ore" [point, inward],
## "chest", "torches" [the tunnel's middle at torch height, the side its wall
## is]) and dust boxes ([center, size]), its footprint (a
## Rect2 in x, z) and lowest floor, and the points just inside and outside
## the mouth. With `meshes` it also gives the CSG parts (bake only).
static func layout(kind: String, variant: int, meshes := false) -> Dictionary:
	var key := "%s_%d" % [kind, variant]
	if not meshes and _cache.has(key):
		return _cache[key]
	var made := _generate(kind, variant, meshes)
	if not meshes:
		_cache[key] = made
	return made


## The floor's height (in the variant's yards) at a point inside it, or NAN
## where the point is in the rock or outside.
static func floor_at(cave: Dictionary, point: Vector2) -> float:
	var best := NAN
	for hollow: Array in cave.voids:
		var c: Vector3 = hollow[0]
		var heading: float = hollow[4]
		var along := Vector2(sin(heading), -cos(heading))
		var across := Vector2(cos(heading), sin(heading))
		var d := point - Vector2(c.x, c.z)
		var u := d.dot(across) / (float(hollow[1]) * 0.85)
		var v := d.dot(along) / (float(hollow[2]) * 0.85)
		if u * u + v * v <= 1.0 and (is_nan(best) or c.y < best):
			best = c.y
	return best


## The ceiling's height (in the variant's yards) over a point inside it, or
## NAN outside its hollows: each dome's roof as an ellipsoid's.
static func ceiling_at(cave: Dictionary, point: Vector2, spread := 1.0) -> float:
	var best := NAN
	for hollow: Array in cave.voids:
		var c: Vector3 = hollow[0]
		var heading: float = hollow[4]
		var along := Vector2(sin(heading), -cos(heading))
		var across := Vector2(cos(heading), sin(heading))
		var d := point - Vector2(c.x, c.z)
		var u := d.dot(across) / (float(hollow[1]) * spread)
		var v := d.dot(along) / (float(hollow[2]) * spread)
		var r := u * u + v * v
		if r <= 1.0:
			var top := c.y + float(hollow[3]) * sqrt(1.0 - r)
			if is_nan(best) or top > best:
				best = top
	return best


## Whether a point (the variant's yards) is in a hollow: over its floor and
## under its ceiling, with `margin` to spare.
static func inside(cave: Dictionary, point: Vector3, margin := 0.0) -> bool:
	var flat := Vector2(point.x, point.z)
	var low := floor_at(cave, flat)
	if is_nan(low):
		return false
	return point.y > low - margin and point.y < ceiling_at(cave, flat, 1.05) + margin


# Growing a variant.

static func _generate(kind: String, variant: int, meshes: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(kind)) + variant * 7919
	var noise := FastNoiseLite.new()
	noise.seed = rng.seed
	noise.frequency = 0.32
	var cave := {
		"voids": [], "chambers": [], "creatures": [], "ore": [], "chest": Vector3.ZERO, "torches": [],
		"dust": [], "parts": [], "pillars": [],
	}
	# The way in: straight for a few steps from in front of the mound, so the
	# mouth opens cleanly, then wandering.
	var main := _walk(rng, Vector3(0, 0, 6.0), 0.0, rng.randf_range(18.0, 26.0) if kind == "den" else rng.randf_range(30.0, 40.0), 3)
	_tunnel(cave, rng, main, true)
	var first := _chamber(cave, rng, main, rng.randf_range(11.0, 14.0))
	var deepest := first
	if kind == "lair":
		# On past the first chamber to the deepest, and a side passage off the
		# way in to a third.
		var last: Dictionary = main.back()
		var on := _walk(rng, first.exit, last.heading + rng.randf_range(-0.8, 0.8), rng.randf_range(12.0, 20.0), 0, first.center.y)
		_tunnel(cave, rng, on, false)
		deepest = _chamber(cave, rng, on, rng.randf_range(12.0, 16.0))
		var fork: Dictionary = main[int(main.size() * rng.randf_range(0.45, 0.65))]
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var branch := _walk(rng, fork.point, fork.heading + side * rng.randf_range(0.9, 1.4), rng.randf_range(12.0, 20.0), 0, fork.point.y)
		_tunnel(cave, rng, branch, false)
		_chamber(cave, rng, branch, rng.randf_range(9.0, 12.0))
		# A dead end or two.
		for i in rng.randi_range(1, 2):
			var from: Dictionary = main[rng.randi_range(4, main.size() - 2)]
			var alcove := _walk(rng, from.point, from.heading + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(1.0, 1.6), rng.randf_range(6.0, 10.0), 0, from.point.y)
			_tunnel(cave, rng, alcove, false)
	cave.chest = deepest.back
	# What it covers, and its lowest floor.
	var box := Rect2()
	var lowest := 0.0
	var first_box := true
	for hollow: Array in cave.voids:
		var c: Vector3 = hollow[0]
		var r := maxf(float(hollow[1]), float(hollow[2]))
		var each := Rect2(c.x - r, c.z - r, r * 2.0, r * 2.0)
		box = each if first_box else box.merge(each)
		first_box = false
		lowest = minf(lowest, c.y)
	cave.footprint = box
	cave.lowest = lowest
	cave.outside = Vector3(0, 0, 12.0)
	cave.inside = (main[mini(5, main.size() - 1)].point as Vector3)
	# Where things stand: each on open floor, clear of the rock left
	# standing and of each other (the campfire first, in the first chamber).
	var fire := _clear_spot(cave, first.center, 1.5, [])
	cave.campfire = fire
	var keep_off := [[fire, 2.4]]
	cave.chest = _clear_spot(cave, cave.chest, 0.9, keep_off)
	keep_off.append([cave.chest, 1.4])
	var spots: Array = []
	for spot: Vector3 in cave.creatures:
		spots.append(_clear_spot(cave, spot, 0.6, keep_off))
	cave.creatures = spots
	# Veins at the foot of the chamber walls, as classic's: out from a
	# chamber's middle to where its floor meets the wall.
	var veins: Array = []
	for vein: Array in cave.ore:
		var out: Vector3 = -(vein[1] as Vector3)
		var foot := _wall_foot(cave, vein[0], out, keep_off)
		veins.append([foot, -out])
		# Veins keep apart.
		keep_off.append([foot, 2.5])
	cave.ore = veins
	if meshes:
		_meshes(cave, noise, rng)
	return cave


## Where the floor meets the wall going out from `from` along `out` (from
## the chamber's middle, through `from`): the last open step before the
## floor ends, steps or the roof comes low, kept off standing rock and
## `avoid`; turning a little either way when the wall there is blocked.
static func _wall_foot(cave: Dictionary, from: Vector3, out: Vector3, avoid: Array) -> Vector3:
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var way := out.rotated(Vector3.UP, turn)
		var start := from - way * 4.0
		var start_floor := floor_at(cave, Vector2(start.x, start.z))
		if is_nan(start_floor):
			start = from
			start_floor = floor_at(cave, Vector2(from.x, from.z))
			if is_nan(start_floor):
				continue
		var last := Vector3.INF
		for k in 60:
			var at := start + way * (k * 0.3)
			var low := floor_at(cave, Vector2(at.x, at.z))
			if is_nan(low) or absf(low - start_floor) > 1.2 or ceiling_at(cave, Vector2(at.x, at.z)) - low < 1.6:
				break
			last = Vector3(at.x, low, at.z)
		if last == Vector3.INF:
			continue
		if _open(cave, last - way * 0.5, 0.4, avoid):
			return last
	return from


## The nearest spot to `around` with open floor `radius` round it, clear of
## stalagmites and pillars and of `avoid` ([point, how near]): `around` if it
## is, else rings of tries farther out; `around` when none is.
static func _clear_spot(cave: Dictionary, around: Vector3, radius: float, avoid: Array) -> Vector3:
	for ring in 6:
		var tries := 1 if ring == 0 else 10
		for k in tries:
			var angle := TAU * k / tries + ring * 0.37
			var at := around + Vector3(cos(angle), 0, sin(angle)) * ring * 1.4
			var floor_y := floor_at(cave, Vector2(at.x, at.z))
			if is_nan(floor_y):
				continue
			at.y = floor_y
			if _open(cave, at, radius, avoid):
				return at
	return around


## Open floor `radius` round a point: floor and headroom all round, and no
## standing rock or `avoid` too near.
static func _open(cave: Dictionary, at: Vector3, radius: float, avoid: Array) -> bool:
	for k in 8:
		var angle := TAU * k / 8.0
		var edge := Vector2(at.x, at.z) + Vector2(cos(angle), sin(angle)) * radius * 1.3
		var low := floor_at(cave, edge)
		if is_nan(low) or absf(low - at.y) > 0.6 or ceiling_at(cave, edge) - low < 2.2:
			return false
	for standing: Array in cave.pillars:
		# Stalactites hang from the roof; the rest stand on the floor.
		if str(standing[0]) == "tite":
			continue
		var base: Vector3 = standing[1]
		if Vector2(base.x - at.x, base.z - at.z).length() < float(standing[2]) + radius + 0.4:
			return false
	for other: Array in avoid:
		if Vector2((other[0] as Vector3).x - at.x, (other[0] as Vector3).z - at.z).length() < float(other[1]) + radius:
			return false
	return true


## A wandering path: a step every STEP yards from `start`, turning a little
## each step (not at all for the first `straight`), within WANDER of its
## first heading, the floor rising and falling. Each step is { point,
## heading }.
static func _walk(rng: RandomNumberGenerator, start: Vector3, heading: float, length: float, straight: int, floor_start := 0.0) -> Array:
	var steps: Array = []
	var point := Vector3(start.x, floor_start, start.z)
	var turn := heading
	var floor_y := floor_start
	for i in maxi(int(length / STEP), 2):
		if i >= straight:
			turn = clampf(turn + rng.randf_range(-TURN, TURN), heading - WANDER, heading + WANDER)
			# Side ways keep back from the hillside: drifting near the mouth's
			# line, they turn in again.
			if straight == 0 and point.z > -12.0:
				turn = lerp_angle(turn, 0.0, 0.6)
			floor_y = clampf(floor_y + rng.randf_range(-FLOOR_STEP, FLOOR_STEP), -FLOOR_RANGE, FLOOR_RANGE)
		steps.append({ "point": Vector3(point.x, floor_y, point.z), "heading": turn })
		point += Vector3(sin(turn), 0, -cos(turn)) * STEP
	return steps


## Hollows along a path: domes pinching and bulging as it goes, and the rock
## round them; torches now and then on the way in.
static func _tunnel(cave: Dictionary, rng: RandomNumberGenerator, path: Array, way_in: bool) -> void:
	var phase := rng.randf() * 100.0
	for i in path.size():
		var step: Dictionary = path[i]
		var p: Vector3 = step.point
		var t := phase + i * 0.45
		var width := lerpf(TUNNEL_WIDTH.x, TUNNEL_WIDTH.y, 0.5 + 0.5 * sin(t) * cos(t * 0.37))
		var height := lerpf(TUNNEL_HEIGHT.x, TUNNEL_HEIGHT.y, 0.5 + 0.5 * sin(t * 0.71 + 1.3))
		var half := width / 2.0 * rng.randf_range(0.85, 1.15)
		cave.voids.append([p + Vector3(0, rng.randf_range(-0.12, 0.08), 0), half, maxf(half * 0.75, 3.2), height * rng.randf_range(0.9, 1.1), step.heading])
		# Torches about every 9 yards, alternating walls, past the mouth.
		if i % 3 == 0 and (i > 3 or not way_in):
			var side := 1.0 if (i / 3) % 2 == 0 else -1.0
			var across := Vector3(cos(step.heading), 0, sin(step.heading))
			cave.torches.append([p + Vector3(0, 2.0, 0), across * side])
		if i > 3 and i % 3 == 0:
			cave.creatures.append(p)
	# A dust box for the stretch, so it's dark.
	var low := Vector3(INF, INF, INF)
	var high := -low
	for step: Dictionary in path:
		var p: Vector3 = step.point
		if p.z > 2.0:
			continue
		low = low.min(p - Vector3(6, 0.5, 6))
		high = high.max(p + Vector3(6, 8.0, 6))
	if low.x < INF:
		cave.dust.append([(low + high) / 2.0, high - low])


## A lopsided chamber at the end of a path: a cluster of domes of different
## sizes leaning to one side, with low and high ceilings; big ones get
## stalagmites, stalactites and a pillar. Returns { center, exit, back }.
static func _chamber(cave: Dictionary, rng: RandomNumberGenerator, path: Array, radius: float) -> Dictionary:
	var end: Dictionary = path.back()
	var forward := Vector3(sin(end.heading), 0, -cos(end.heading))
	var across := Vector3(cos(end.heading), 0, sin(end.heading))
	var lean := (1.0 if rng.randf() < 0.5 else -1.0) * radius * rng.randf_range(0.15, 0.35)
	var center: Vector3 = end.point + forward * radius * 0.65 + across * lean
	var blobs: Array = []
	for i in rng.randi_range(3, 6):
		var angle := rng.randf() * TAU
		var offset := Vector3(cos(angle), 0, sin(angle)) * radius * rng.randf_range(0.1, 0.55)
		var half_x := radius * rng.randf_range(0.42, 0.75)
		var half_z := radius * rng.randf_range(0.4, 0.72)
		var height := rng.randf_range(6.0, 10.0)
		var at := center + offset + Vector3(0, rng.randf_range(-0.35, 0.35), 0)
		var heading := rng.randf() * TAU
		cave.voids.append([at, half_x, half_z, height, heading])
		blobs.append([at, half_x, half_z, height])
	# The first dome joins the tunnel's end to the room.
	cave.voids.append([end.point + forward * 2.0, 4.5, 4.5, 6.0, end.heading])
	cave.chambers.append([center, radius])
	# Creatures about the floor, ore against the walls.
	for blob: Array in blobs:
		cave.creatures.append(blob[0])
	for i in 2:
		var blob: Array = blobs[rng.randi_range(0, blobs.size() - 1)]
		var angle := rng.randf() * TAU
		var out := Vector3(cos(angle), 0, sin(angle))
		cave.ore.append([(blob[0] as Vector3) + out * minf(blob[1], blob[2]) * 0.62, -out])
	# Rock left standing in big rooms.
	if radius >= 11.5:
		for i in rng.randi_range(2, 5):
			var blob: Array = blobs[rng.randi_range(0, blobs.size() - 1)]
			var angle := rng.randf() * TAU
			var at: Vector3 = (blob[0] as Vector3) + Vector3(cos(angle), 0, sin(angle)) * minf(blob[1], blob[2]) * rng.randf_range(0.45, 0.75)
			cave.pillars.append(["mite", at, rng.randf_range(0.5, 1.2), rng.randf_range(1.2, 3.2)])
		for i in rng.randi_range(2, 4):
			var blob: Array = blobs[rng.randi_range(0, blobs.size() - 1)]
			var angle := rng.randf() * TAU
			var at: Vector3 = (blob[0] as Vector3) + Vector3(cos(angle), 0, sin(angle)) * minf(blob[1], blob[2]) * rng.randf_range(0.0, 0.5)
			cave.pillars.append(["tite", at + Vector3(0, float(blob[3]) * 0.75, 0), rng.randf_range(0.4, 0.9), rng.randf_range(1.5, 3.0)])
		if rng.randf() < 0.6:
			var blob: Array = blobs[rng.randi_range(0, blobs.size() - 1)]
			var angle := rng.randf() * TAU
			var at: Vector3 = (blob[0] as Vector3) + Vector3(cos(angle), 0, sin(angle)) * minf(blob[1], blob[2]) * 0.55
			cave.pillars.append(["pillar", at, rng.randf_range(1.1, 1.9), float(blob[3]) + 1.5])
	# Torches on its walls, either side.
	var turn := rng.randf() * TAU
	for k in 2:
		var angle := turn + PI * k
		cave.torches.append([center + Vector3(0, 2.2, 0), Vector3(cos(angle), 0, sin(angle))])
	# Dark inside.
	cave.dust.append([center + Vector3(0, 4.5, 0), Vector3(radius * 2.4, 11.0, radius * 2.4)])
	# The far side, for the chest: the blob furthest along.
	var back: Vector3 = blobs[0][0]
	for blob: Array in blobs:
		if (blob[0] as Vector3).dot(forward) > back.dot(forward):
			back = blob[0]
	return { "center": center, "exit": center + forward * radius * 0.5, "back": back }


# Meshes (for the bake).

## The CSG parts: [mesh, operation] with operation "add" (a hollow, joined
## into the cave's space) or "cut" (rock left standing in it: stalagmites,
## stalactites, pillars). The bake turns the result inward.
static func _meshes(cave: Dictionary, noise: FastNoiseLite, _rng: RandomNumberGenerator) -> void:
	var parts: Array = []
	for hollow: Array in cave.voids:
		parts.append([_dome(hollow[0], hollow[1], hollow[2], hollow[3], hollow[4], noise), "add"])
	for standing: Array in cave.pillars:
		var at: Vector3 = standing[1]
		match str(standing[0]):
			"mite":
				parts.append([_spike(at + Vector3(0, -0.6, 0), standing[2], float(standing[3]) + 0.6, 1.0, noise), "cut"])
			"tite":
				parts.append([_spike(at + Vector3(0, 1.2, 0), standing[2], float(standing[3]) + 1.2, -1.0, noise), "cut"])
			"pillar":
				parts.append([_column(at + Vector3(0, -0.8, 0), standing[2], float(standing[3]) + 1.6, noise), "cut"])
	cave.parts = parts


## A broken rock: a coarse icosahedron stretched to `radii`, turned by
## `yaw`, pushed hard in and out by noise and cut flat underneath, so it sits
## like a fallen boulder (the rocks round a cave's mouth).
static func rock(center: Vector3, radii: Vector3, yaw: float, noise: FastNoiseLite) -> ArrayMesh:
	var sphere := _icosphere(1)
	var points: PackedVector3Array = sphere[0]
	var turn := Basis(Vector3.UP, yaw)
	for i in points.size():
		var d: Vector3 = points[i]
		var push := 1.0 + noise.get_noise_3dv(center + d * 3.7) * 0.4
		var p := turn * (d * radii * push)
		p.y = maxf(p.y, -radii.y * 0.45)
		points[i] = center + p
	# Flat normals, each face its own, for the texture's projection.
	var made := _mesh(points, sphere[1])
	var surface := SurfaceTool.new()
	surface.create_from(made, 0)
	surface.deindex()
	surface.set_smooth_group(-1)
	surface.generate_normals()
	return surface.commit()


## Flat cuts across a crag (Caves.crag), and how far each takes off, from the
## middle out (a share of its size: less is a deeper cut).
static var CRAG_CUTS := 7
static var CRAG_CUT_LEAST := 0.45
static var CRAG_CUT_MOST := 0.85
## How far a crag leans out of upright (radians, at most).
static var CRAG_LEAN := 0.5


## A jagged, angular rock (the frame round a cave's mouth): a coarse
## icosahedron stretched to `radii`, pushed in and out by noise, then sliced
## by CRAG_CUTS flat planes at random angles, each shaving off what lies past
## it, so it breaks into sharp faces and edges like split stone; leaning a
## little and turned by `yaw`. Each face flat-shaded.
static func crag(center: Vector3, radii: Vector3, yaw: float, noise: FastNoiseLite) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(center)
	var sphere := _icosphere(1)
	var points: PackedVector3Array = sphere[0]
	var cuts: Array = []
	for k in CRAG_CUTS:
		var normal := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		cuts.append([normal, rng.randf_range(CRAG_CUT_LEAST, CRAG_CUT_MOST)])
	var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, CRAG_LEAN))
	var turn := Basis(Vector3.UP, yaw) * lean
	for i in points.size():
		var d: Vector3 = points[i]
		var p := d * (1.0 + noise.get_noise_3dv(center + d * 3.7) * 0.35)
		for cut: Array in cuts:
			var past := p.dot(cut[0]) - float(cut[1])
			if past > 0.0:
				p -= (cut[0] as Vector3) * past
		points[i] = center + turn * (p * radii)
	var made := _mesh(points, sphere[1])
	var surface := SurfaceTool.new()
	surface.create_from(made, 0)
	surface.deindex()
	surface.set_smooth_group(-1)
	surface.generate_normals()
	return surface.commit()


## A lumpy ball of rock: a subdivided icosahedron stretched to `radii` and
## pushed in and out by noise.
static func _lump(center: Vector3, radii: Vector3, noise: FastNoiseLite) -> ArrayMesh:
	var sphere := _icosphere(2)
	var points: PackedVector3Array = sphere[0]
	for i in points.size():
		var d: Vector3 = points[i]
		var p := center + d * radii
		var push := 1.0 + noise.get_noise_3dv(p * 0.6) * 0.28
		points[i] = center + d * radii * push
	return _mesh(points, sphere[1])


## A hollow's shape: a dome on a flat, slightly rubbled base at the floor,
## its rim and walls pushed in and out by noise, `half_x` across and
## `half_z` along its heading.
static func _dome(base: Vector3, half_x: float, half_z: float, height: float, heading: float, noise: FastNoiseLite) -> ArrayMesh:
	var sides := 11
	var rings := [0.0, 0.3, 0.6, 0.85]
	var across := Vector3(cos(heading), 0, sin(heading))
	var along := Vector3(sin(heading), 0, -cos(heading))
	var points := PackedVector3Array()
	var faces := PackedInt32Array()
	for ring: float in rings:
		var spread := 0.92 if ring == 0.0 else sqrt(1.0 - ring * ring) * 0.98 + 0.02
		for k in sides:
			var a := TAU * k / sides
			var flat := across * cos(a) * half_x + along * sin(a) * half_z
			var p := base + flat * spread + Vector3(0, ring * height, 0)
			var push := 1.0 + noise.get_noise_3dv(p) * 0.3
			p = base + flat * spread * push + Vector3(0, ring * height + (noise.get_noise_3dv(p + Vector3(9, 0, 0)) * 0.25 if ring > 0.0 else noise.get_noise_2d(p.x, p.z) * 0.12), 0)
			points.append(p)
	var top := points.size()
	points.append(base + Vector3(0, height * (1.0 + noise.get_noise_3dv(base) * 0.15), 0))
	var bottom := points.size()
	points.append(base + Vector3(0, noise.get_noise_2d(base.x, base.z) * 0.15, 0))
	for r in rings.size() - 1:
		for k in sides:
			var a := r * sides + k
			var b := r * sides + (k + 1) % sides
			var c := (r + 1) * sides + k
			var d := (r + 1) * sides + (k + 1) % sides
			faces.append_array([a, c, b, b, c, d])
	var last := (rings.size() - 1) * sides
	for k in sides:
		faces.append_array([last + k, top, last + (k + 1) % sides])
		faces.append_array([bottom, k, (k + 1) % sides])
	return _mesh(points, faces)


## A stalagmite (`up` 1) or stalactite (`up` -1): a lumpy cone from `base`.
static func _spike(base: Vector3, radius: float, length: float, up: float, noise: FastNoiseLite) -> ArrayMesh:
	var sides := 7
	var rings := [0.0, 0.45, 0.8]
	var points := PackedVector3Array()
	var faces := PackedInt32Array()
	for ring: float in rings:
		for k in sides:
			var a := TAU * k / sides
			var p := base + Vector3(cos(a) * radius * (1.0 - ring), ring * length * up, sin(a) * radius * (1.0 - ring))
			p += Vector3(noise.get_noise_3dv(p) * 0.15, 0, noise.get_noise_3dv(p + Vector3(5, 0, 0)) * 0.15)
			points.append(p)
	var tip := points.size()
	points.append(base + Vector3(0, length * up, 0))
	var cap := points.size()
	points.append(base)
	for r in rings.size() - 1:
		for k in sides:
			var a := r * sides + k
			var b := r * sides + (k + 1) % sides
			var c := (r + 1) * sides + k
			var d := (r + 1) * sides + (k + 1) % sides
			faces.append_array([a, c, b, b, c, d])
	var last := (rings.size() - 1) * sides
	for k in sides:
		faces.append_array([last + k, tip, last + (k + 1) % sides])
		faces.append_array([cap, k, (k + 1) % sides])
	var mesh_points := points
	# Stalactites hang: their winding turns over with them.
	if up < 0.0:
		for i in range(0, faces.size(), 3):
			var swap := faces[i + 1]
			faces[i + 1] = faces[i + 2]
			faces[i + 2] = swap
	return _mesh(mesh_points, faces)


## A rough column from floor to ceiling, narrower in the middle.
static func _column(base: Vector3, radius: float, height: float, noise: FastNoiseLite) -> ArrayMesh:
	var sides := 8
	var rings := [0.0, 0.25, 0.5, 0.75, 1.0]
	var points := PackedVector3Array()
	var faces := PackedInt32Array()
	for ring: float in rings:
		var waist := 1.0 - 0.35 * sin(ring * PI)
		for k in sides:
			var a := TAU * k / sides
			var p := base + Vector3(cos(a) * radius * waist, ring * height, sin(a) * radius * waist)
			p += Vector3(noise.get_noise_3dv(p) * 0.2, 0, noise.get_noise_3dv(p + Vector3(5, 0, 0)) * 0.2)
			points.append(p)
	var top := points.size()
	points.append(base + Vector3(0, height, 0))
	var bottom := points.size()
	points.append(base)
	for r in rings.size() - 1:
		for k in sides:
			var a := r * sides + k
			var b := r * sides + (k + 1) % sides
			var c := (r + 1) * sides + k
			var d := (r + 1) * sides + (k + 1) % sides
			faces.append_array([a, c, b, b, c, d])
	var last := (rings.size() - 1) * sides
	for k in sides:
		faces.append_array([last + k, top, last + (k + 1) % sides])
		faces.append_array([bottom, k, (k + 1) % sides])
	return _mesh(points, faces)


## A subdivided icosahedron: [unit points, faces].
static func _icosphere(levels: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var points := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for i in points.size():
		points[i] = points[i].normalized()
	var faces := PackedInt32Array([0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2,
		10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1])
	for level in levels:
		var middles := {}
		var next := PackedInt32Array()
		for f in range(0, faces.size(), 3):
			var m := []
			for e in 3:
				var a := faces[f + e]
				var b := faces[f + (e + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not middles.has(key):
					middles[key] = points.size()
					points.append(((points[a] + points[b]) / 2.0).normalized())
				m.append(middles[key])
			next.append_array([faces[f], m[0], m[2], faces[f + 1], m[1], m[0], faces[f + 2], m[2], m[1], m[0], m[1], m[2]])
		faces = next
	return [points, faces]


## A closed mesh from points and faces, turned outward (by its enclosed
## volume, as the noise may have turned a thin part over).
static func _mesh(points: PackedVector3Array, faces: PackedInt32Array) -> ArrayMesh:
	var volume := 0.0
	for f in range(0, faces.size(), 3):
		volume += points[faces[f]].dot(points[faces[f + 1]].cross(points[faces[f + 2]]))
	if volume > 0.0:
		for f in range(0, faces.size(), 3):
			var swap := faces[f + 1]
			faces[f + 1] = faces[f + 2]
			faces[f + 2] = swap
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = faces
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
