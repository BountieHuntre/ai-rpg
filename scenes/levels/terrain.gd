class_name Terrain
extends StaticBody3D
## Ground built from a height function: a grid mesh with vertex colors and a
## matching trimesh collision shape on the world layer.

## Builds the ground over a square `size` yards across, centered on `center`
## (x, z), with a vertex every `step` yards. `height` is f(x, z) -> float and
## `color` is f(x, z, height, normal) -> Color.
func build(size: float, step: float, height: Callable, color: Callable, material: Material, center := Vector2.ZERO) -> void:
	var cells := roundi(size / step)
	var half := size / 2.0
	var points := PackedVector3Array()
	points.resize((cells + 1) * (cells + 1))
	for row in cells + 1:
		for column in cells + 1:
			var x := center.x - half + column * step
			var z := center.y - half + row * step
			points[row * (cells + 1) + column] = Vector3(x, height.call(x, z), z)
	_cells = cells
	_step = step
	_origin = center - Vector2(half, half)
	_heights.resize(points.size())
	for i in points.size():
		_heights[i] = points[i].y
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in cells + 1:
		for column in cells + 1:
			var point := points[row * (cells + 1) + column]
			var normal := _normal(points, cells, row, column, step)
			tool.set_color(color.call(point.x, point.z, point.y, normal))
			tool.set_normal(normal)
			tool.add_vertex(point)
	for row in cells:
		for column in cells:
			var a := row * (cells + 1) + column
			var b := a + 1
			var c := a + cells + 1
			var d := c + 1
			tool.add_index(a)
			tool.add_index(b)
			tool.add_index(c)
			tool.add_index(b)
			tool.add_index(d)
			tool.add_index(c)
	var mesh := tool.commit()
	mesh.surface_set_material(0, material)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	add_child(view)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	add_child(shape)


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


## Smooth normal from the neighboring heights.
func _normal(points: PackedVector3Array, cells: int, row: int, column: int, step: float) -> Vector3:
	var width := cells + 1
	var left := points[row * width + maxi(column - 1, 0)].y
	var right := points[row * width + mini(column + 1, cells)].y
	var up := points[maxi(row - 1, 0) * width + column].y
	var down := points[mini(row + 1, cells) * width + column].y
	return Vector3(left - right, 2.0 * step, up - down).normalized()
