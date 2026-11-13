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
func build(size: float, step: float, height: Callable, color: Callable, material: Material, center := Vector2.ZERO, weights := Callable()) -> void:
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
	# Two triangles a quad: a b c and b d c.
	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var i := 0
	for row in cells:
		for column in cells:
			var a := row * width + column
			var c := a + width
			indices[i] = a
			indices[i + 1] = a + 1
			indices[i + 2] = c
			indices[i + 3] = a + 1
			indices[i + 4] = c + 1
			indices[i + 5] = c
			i += 6
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
