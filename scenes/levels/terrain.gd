class_name Terrain
extends StaticBody3D
## Ground built from a height function: a grid mesh with vertex colors and a
## matching trimesh collision shape on the world layer.

## Builds the ground over a square `size` yards across, centered on `center`
## (x, z), with a vertex every `step` yards. `height` is f(x, z) -> float and
## `color` is f(x, z, height, normal) -> Color; both are called from worker
## threads, a row at a time on each, so they must only read. `weights`, if
## given, is f(x, z, height, normal) -> Color of a textured ground's layers
## (shaders/terrain.gdshader: r dirt, g cobbles, b rock, a forest floor),
## stored in UV and UV2.
## `across`, if given, is f(x, z) -> float of the ground on both sides of
## the edges (this zone's inside, a neighbour's beyond): the edge points'
## normals are taken from it, so zones side by side shade their shared edge
## alike and no outline is drawn along the border.
func build(size: float, step: float, height: Callable, color: Callable, material: Material, center := Vector2.ZERO, weights := Callable(), across := Callable()) -> void:
	var cells := roundi(size / step)
	var width := cells + 1
	var half := size / 2.0
	var origin := center - Vector2(half, half)
	# Heights, a row per task. Each task fills its own row: packed arrays are
	# copied into lambdas, so the rows are kept in an Array.
	var height_rows := []
	height_rows.resize(width)
	parallel(width, func(row: int) -> void:
		var line := PackedFloat32Array()
		line.resize(width)
		var z := origin.y + row * step
		for column in width:
			line[column] = height.call(origin.x + column * step, z)
		height_rows[row] = line
	)
	_cells = cells
	_step = step
	_origin = origin
	_heights = PackedFloat32Array()
	for line: PackedFloat32Array in height_rows:
		_heights.append_array(line)
	# Points, normals and colors, a row per task.
	var rows := []
	rows.resize(width)
	var heights := _heights
	parallel(width, func(row: int) -> void:
		var points := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var uv2s := PackedVector2Array()
		points.resize(width)
		normals.resize(width)
		colors.resize(width)
		if weights.is_valid():
			uvs.resize(width)
			uv2s.resize(width)
		var z := origin.y + row * step
		for column in width:
			var y := heights[row * width + column]
			var x := origin.x + column * step
			var left := heights[row * width + maxi(column - 1, 0)]
			var right := heights[row * width + mini(column + 1, cells)]
			var up := heights[maxi(row - 1, 0) * width + column]
			var down := heights[mini(row + 1, cells) * width + column]
			var normal := Vector3(left - right, 2.0 * step, up - down).normalized()
			points[column] = Vector3(x, y, z)
			normals[column] = normal
			colors[column] = color.call(x, z, y, normal)
			if weights.is_valid():
				var layers: Color = weights.call(x, z, y, normal)
				uvs[column] = Vector2(layers.r, layers.g)
				uv2s[column] = Vector2(layers.b, layers.a)
		rows[row] = [points, normals, colors, uvs, uv2s]
	)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for row: Array in rows:
		points.append_array(row[0])
		normals.append_array(row[1])
		colors.append_array(row[2])
		uvs.append_array(row[3])
		uv2s.append_array(row[4])
	# Two triangles a quad: a b c and b d c. Cells along the edges also take
	# the points where a neighbouring zone's grid meets the edge (`_edge_points`),
	# so both zones' ground shares the same points along their border and
	# joins in one piece, with no cracks between grids of different steps.
	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var i := 0
	# Packed arrays are copied into lambdas, so the extra points are listed
	# in an Array and filled in after.
	var extra: Array[Vector2] = []
	var extra_indices := PackedInt32Array()
	var add_point := func(x: float, z: float) -> int:
		extra.append(Vector2(x, z))
		return width * width + extra.size() - 1
	for row in cells:
		for column in cells:
			var a := row * width + column
			var c := a + width
			var x0 := origin.x + column * step
			var z0 := origin.y + row * step
			var top := _edge_points(x0, x0 + step) if row == 0 else []
			var right := _edge_points(z0, z0 + step) if column == cells - 1 else []
			var bottom := _edge_points(x0, x0 + step) if row == cells - 1 else []
			var left := _edge_points(z0, z0 + step) if column == 0 else []
			if top.is_empty() and right.is_empty() and bottom.is_empty() and left.is_empty():
				indices[i] = a
				indices[i + 1] = a + 1
				indices[i + 2] = c
				indices[i + 3] = a + 1
				indices[i + 4] = c + 1
				indices[i + 5] = c
				i += 6
				continue
			# The cell's outline, round from a: a, along the top, b, down the
			# right, d, back along the bottom, c, up the left.
			var outline: Array[int] = [a]
			for x: float in top:
				outline.append(add_point.call(x, z0))
			var corner_b := outline.size()
			outline.append(a + 1)
			for z: float in right:
				outline.append(add_point.call(x0 + step, z))
			var corner_d := outline.size()
			outline.append(c + 1)
			bottom.reverse()
			for x: float in bottom:
				outline.append(add_point.call(x, z0 + step))
			var corner_c := outline.size()
			outline.append(c)
			left.reverse()
			for z: float in left:
				outline.append(add_point.call(x0, z))
			# A fan from the corner whose sides have no extra points (the
			# outline is convex, so any such corner will do).
			var start := 0
			if not (top.is_empty() and left.is_empty()):
				if top.is_empty() and right.is_empty():
					start = corner_b
				elif right.is_empty() and bottom.is_empty():
					start = corner_d
				else:
					start = corner_c
			var count := outline.size()
			for k in range(1, count - 1):
				extra_indices.append_array([outline[start], outline[(start + k) % count], outline[(start + k + 1) % count]])
	indices.resize(i)
	indices.append_array(extra_indices)
	var slope_of := across if across.is_valid() else height
	for at in extra:
		points.append(Vector3(at.x, height.call(at.x, at.y), at.y))
		normals.append(Vector3.UP)
		colors.append(Color())
		if weights.is_valid():
			uvs.append(Vector2.ZERO)
			uv2s.append(Vector2.ZERO)
	# Every point on the edges: its normal from the ground on both sides,
	# and its color and layers again for it.
	var edge: Array[int] = []
	for k in width:
		edge.append_array([k, cells * width + k, k * width, k * width + cells])
	for k in extra.size():
		edge.append(width * width + k)
	for index in edge:
		var at := points[index]
		var normal := _edge_normal(slope_of, at.x, at.z)
		normals[index] = normal
		colors[index] = color.call(at.x, at.z, at.y, normal)
		if weights.is_valid():
			var layers: Color = weights.call(at.x, at.z, at.y, normal)
			uvs[index] = Vector2(layers.r, layers.g)
			uv2s[index] = Vector2(layers.b, layers.a)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	if weights.is_valid():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	add_child(view)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	add_child(shape)


## Runs work(i) for i in 0 to count - 1 on the worker threads and waits for
## them all.
static func parallel(count: int, work: Callable) -> void:
	if OS.has_environment("AI_RPG_SERIAL"):
		for i in count:
			work.call(i)
		return
	var task := WorkerThreadPool.add_group_task(work, count)
	WorkerThreadPool.wait_for_group_task_completion(task)


## How far either side of an edge point its slope is measured, the same for
## every zone so neighbours agree.
const EDGE_SLOPE_SPAN := 1.0


static func _edge_normal(ground: Callable, x: float, z: float) -> Vector3:
	var d := EDGE_SLOPE_SPAN
	return Vector3(ground.call(x - d, z) - ground.call(x + d, z), 2.0 * d,
		ground.call(x, z - d) - ground.call(x, z + d)).normalized()


## The steps zones' grids use. Every zone's corners are at whole hundreds of
## yards, so each grid's points lie on world multiples of its step.
const ZONE_STEPS: Array[float] = [2.0, 2.5]


## The points strictly between two coordinates along an edge where any
## zone's grid has one, in order.
static func _edge_points(from: float, to: float) -> Array:
	var found: Array = []
	for each in ZONE_STEPS:
		for k in range(ceili(from / each), floori(to / each) + 1):
			var at: float = k * each
			if at > from + 0.001 and at < to - 0.001 and not found.has(at):
				found.append(at)
	found.sort()
	return found


var _heights := PackedFloat32Array()
var _cells := 0
var _step := 1.0
var _origin := Vector2.ZERO


## The height of the built ground at a point, from its own grid and on its
## triangles, so it is exactly the collision surface (and much cheaper than
## the height function). Points off the ground take its nearest edge.
func sample(x: float, z: float) -> float:
	var fx := clampf((x - _origin.x) / _step, 0.0, _cells - 0.0001)
	var fz := clampf((z - _origin.y) / _step, 0.0, _cells - 0.0001)
	var column := int(fx)
	var row := int(fz)
	fx -= column
	fz -= row
	var width := _cells + 1
	var a := _heights[row * width + column]
	var b := _heights[row * width + column + 1]
	var c := _heights[(row + 1) * width + column]
	var d := _heights[(row + 1) * width + column + 1]
	# The quad's two triangles: a b c, and b d c.
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


func is_built() -> bool:
	return _cells > 0
