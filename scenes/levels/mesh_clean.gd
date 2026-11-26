class_name MeshClean
extends RefCounted
## Tidies a triangle soup where it was cut and joined (a cave's mouth: the
## tunnel cut at the hillside and the rim zipped to it): collapses edges
## shorter than MIN_EDGE, which takes the slivers and scraps with them,
## never moving a locked point (seams other meshes share) and never folding
## a face over or pinching the surface (each collapse checked first). Each
## triangle keeps its tag (which mesh it's drawn in), and a value carried per
## point (the rim's share of ground and rock) goes with the point kept.

## Edges shorter than this (yards) are collapsed.
static var MIN_EDGE := 0.45
## A collapse is refused if it turns a face more than this far round (its
## normal's dot with the old one below it).
static var MIN_TURN := 0.3
## Points this near (yards) are one point.
static var WELD := 0.001


## Cleans `faces` (triangles), keeping `tags` per triangle and `values` per
## corner (by corner, as the faces are). Points whose keys are in `locked`
## (Vector3i of the position in thousandths) stay. Returns
## [faces, tags, values].
static func clean(faces: PackedVector3Array, tags: PackedInt32Array, values: PackedFloat32Array, locked: Dictionary) -> Array:
	# Points welded, triangles as index triples.
	var index_of := {}
	var points: Array[Vector3] = []
	var point_values: Array[float] = []
	var tris: Array = []
	for t in range(0, faces.size(), 3):
		var tri := []
		for k in 3:
			var key := key_of(faces[t + k])
			if not index_of.has(key):
				index_of[key] = points.size()
				points.append(faces[t + k])
				point_values.append(values[t + k] if values.size() > t + k else 0.0)
			tri.append(index_of[key])
		if tri[0] != tri[1] and tri[1] != tri[2] and tri[0] != tri[2]:
			tris.append([tri[0], tri[1], tri[2], tags[t / 3] if tags.size() > t / 3 else 0])
	var pinned := {}
	for key: Vector3i in locked:
		if index_of.has(key):
			pinned[index_of[key]] = true
	# Which triangles each point is in.
	var around: Array = []
	around.resize(points.size())
	for i in points.size():
		around[i] = []
	for f in tris.size():
		for k in 3:
			(around[tris[f][k]] as Array).append(f)
	var alive: Array[bool] = []
	alive.resize(tris.size())
	alive.fill(true)
	# Short edges, shortest first.
	var edges: Array = []
	var seen := {}
	for f in tris.size():
		for k in 3:
			var a: int = tris[f][k]
			var b: int = tris[f][(k + 1) % 3]
			var id := Vector2i(mini(a, b), maxi(a, b))
			if seen.has(id):
				continue
			seen[id] = true
			var length := points[a].distance_to(points[b])
			if length < MIN_EDGE:
				edges.append([length, a, b])
	edges.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var gone := {}
	for edge: Array in edges:
		var a: int = edge[1]
		var b: int = edge[2]
		if gone.has(a) or gone.has(b) or (pinned.has(a) and pinned.has(b)):
			continue
		# Keep the pinned one where it is; else meet in the middle.
		var keep := a
		var drop := b
		if pinned.has(b):
			keep = b
			drop = a
		var to := points[keep] if pinned.has(keep) else (points[a] + points[b]) / 2.0
		if not _can_collapse(keep, drop, to, points, tris, around, alive):
			continue
		# Merge: drop's triangles now use keep; the two along the edge go.
		for f: int in around[drop]:
			if not alive[f]:
				continue
			var tri: Array = tris[f]
			if keep in [tri[0], tri[1], tri[2]]:
				alive[f] = false
				continue
			for k in 3:
				if tri[k] == drop:
					tri[k] = keep
			(around[keep] as Array).append(f)
		points[keep] = to
		gone[drop] = true
	_smooth(points, tris, alive, pinned)
	_flip_edges(points, tris, alive, pinned)
	var out_faces := PackedVector3Array()
	var out_tags := PackedInt32Array()
	var out_values := PackedFloat32Array()
	for f in tris.size():
		if not alive[f]:
			continue
		var tri: Array = tris[f]
		for k in 3:
			out_faces.append(points[tri[k]])
			out_values.append(point_values[tri[k]])
		out_tags.append(tri[3])
	return [out_faces, out_tags, out_values]


## How far each pass pulls a free point toward the middle of its neighbours
## (a share of the way), and how many passes: a touch of flattening.
static var SMOOTH := 0.35
static var SMOOTH_PASSES := 2


## Pulls each point not pinned toward the middle of the points it shares
## faces with, SMOOTH_PASSES times.
static func _smooth(points: Array[Vector3], tris: Array, alive: Array[bool], pinned: Dictionary) -> void:
	for pass_number in SMOOTH_PASSES:
		var sums := {}
		var counts := {}
		for f in tris.size():
			if not alive[f]:
				continue
			for k in 3:
				var p: int = tris[f][k]
				if pinned.has(p):
					continue
				for j in [1, 2]:
					var q: int = tris[f][(k + j) % 3]
					sums[p] = (sums.get(p, Vector3.ZERO) as Vector3) + points[q]
					counts[p] = int(counts.get(p, 0)) + 1
		for p: int in sums:
			points[p] = points[p].lerp((sums[p] as Vector3) / float(counts[p]), SMOOTH)


## Two neighbouring faces this flat together (their normals' dot at least
## this) may have their shared edge flipped, and only if that makes their
## thinnest corner wider; passes over the whole surface.
static var FLIP_FLAT := 0.93
static var FLIP_PASSES := 4


## Flips edges between nearly flat neighbouring faces of the same tag where
## the other diagonal makes rounder triangles (the slivers a fan of points
## along a seam leaves), moving no point.
static func _flip_edges(points: Array[Vector3], tris: Array, alive: Array[bool], pinned: Dictionary) -> void:
	for pass_number in FLIP_PASSES:
		var by_edge := {}
		for f in tris.size():
			if not alive[f]:
				continue
			for k in 3:
				var a: int = tris[f][k]
				var b: int = tris[f][(k + 1) % 3]
				var id := Vector2i(mini(a, b), maxi(a, b))
				if not by_edge.has(id):
					by_edge[id] = []
				(by_edge[id] as Array).append(f)
		var flipped := 0
		var touched := {}
		for id: Vector2i in by_edge:
			var pair: Array = by_edge[id]
			if pair.size() != 2 or touched.has(pair[0]) or touched.has(pair[1]):
				continue
			var f: int = pair[0]
			var g: int = pair[1]
			if tris[f][3] != tris[g][3]:
				continue
			var a := id.x
			var b := id.y
			var c := _third(tris[f], a, b)
			var d := _third(tris[g], a, b)
			# Never onto an edge already there (two faces would double up).
			# Nor between two pinned points: faces beyond this surface may join them.
			if c == d or by_edge.has(Vector2i(mini(c, d), maxi(c, d))) or (pinned.has(c) and pinned.has(d)):
				continue
			var nf := _normal(points, tris[f])
			var ng := _normal(points, tris[g])
			if nf.dot(ng) < FLIP_FLAT:
				continue
			var now := minf(_least_angle(points[a], points[b], points[c]), _least_angle(points[a], points[b], points[d]))
			var then := minf(_least_angle(points[c], points[d], points[a]), _least_angle(points[c], points[d], points[b]))
			if then <= now + 0.02:
				continue
			# The new pair, wound as the old ones were: f went a -> b -> c in
			# some order; keep that turning for (c, d, ...) halves.
			var face_f: Array = tris[f]
			var forward := _goes(face_f, a, b)
			var new_f := [c, a, d] if forward else [a, c, d]
			var new_g := [c, d, b] if forward else [d, c, b]
			var n_new := ((points[new_f[1]] - points[new_f[0]]).cross(points[new_f[2]] - points[new_f[0]])).normalized()
			if n_new.dot(nf) < 0.0:
				new_f = [new_f[0], new_f[2], new_f[1]]
				new_g = [new_g[0], new_g[2], new_g[1]]
			tris[f] = [new_f[0], new_f[1], new_f[2], face_f[3]]
			tris[g] = [new_g[0], new_g[1], new_g[2], face_f[3]]
			touched[f] = true
			touched[g] = true
			# The new edge counts as there for the rest of this pass.
			by_edge[Vector2i(mini(c, d), maxi(c, d))] = [f, g]
			flipped += 1
		if flipped == 0:
			return


static func _third(tri: Array, a: int, b: int) -> int:
	for k in 3:
		if tri[k] != a and tri[k] != b:
			return tri[k]
	return -1


## Whether a face's corners run from a to b (rather than b to a).
static func _goes(tri: Array, a: int, b: int) -> bool:
	for k in 3:
		if tri[k] == a and tri[(k + 1) % 3] == b:
			return true
	return false


static func _normal(points: Array[Vector3], tri: Array) -> Vector3:
	return (points[tri[1]] - points[tri[0]]).cross(points[tri[2]] - points[tri[0]]).normalized()


## A triangle's thinnest corner (radians).
static func _least_angle(a: Vector3, b: Vector3, c: Vector3) -> float:
	var least := PI
	for corner: Array in [[a, b, c], [b, c, a], [c, a, b]]:
		var u: Vector3 = corner[1] - corner[0]
		var w: Vector3 = corner[2] - corner[0]
		if u.length() < 1e-9 or w.length() < 1e-9:
			return 0.0
		least = minf(least, u.angle_to(w))
	return least


## Whether merging `drop` into `keep` at `to` keeps the surface whole: the
## two points share exactly the neighbours of the faces along their edge (no
## pinch), and no other face around them turns over or nearly so.
static func _can_collapse(keep: int, drop: int, to: Vector3, points: Array[Vector3], tris: Array, around: Array, alive: Array[bool]) -> bool:
	var near_keep := {}
	var near_drop := {}
	var shared_faces := 0
	for f: int in around[keep]:
		if alive[f]:
			for k in 3:
				near_keep[tris[f][k]] = true
	for f: int in around[drop]:
		if not alive[f]:
			continue
		var tri: Array = tris[f]
		if keep in [tri[0], tri[1], tri[2]]:
			shared_faces += 1
		for k in 3:
			near_drop[tri[k]] = true
	if shared_faces == 0 or shared_faces > 2:
		return false
	var common := 0
	for v: int in near_drop:
		if v != keep and v != drop and near_keep.has(v):
			common += 1
	if common != shared_faces:
		return false
	for moved: int in [keep, drop]:
		for f: int in around[moved]:
			if not alive[f]:
				continue
			var tri: Array = tris[f]
			if (keep in [tri[0], tri[1], tri[2]]) and (drop in [tri[0], tri[1], tri[2]]):
				continue
			var before := [points[tri[0]], points[tri[1]], points[tri[2]]]
			var after := before.duplicate()
			for k in 3:
				if tri[k] == keep or tri[k] == drop:
					after[k] = to
			var n0: Vector3 = ((before[1] as Vector3) - before[0]).cross((before[2] as Vector3) - before[0])
			var n1: Vector3 = ((after[1] as Vector3) - after[0]).cross((after[2] as Vector3) - after[0])
			if n0.length() < 1e-9 or n1.length() < 1e-9 or n0.normalized().dot(n1.normalized()) < MIN_TURN:
				return false
	return true


static func key_of(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / WELD), roundi(point.y / WELD), roundi(point.z / WELD)) if WELD > 0.0 else Vector3i(roundi(point.x * 1000.0), roundi(point.y * 1000.0), roundi(point.z * 1000.0))
