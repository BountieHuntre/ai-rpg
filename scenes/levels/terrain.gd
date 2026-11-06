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


## Smooth normal from the neighboring heights.
func _normal(points: PackedVector3Array, cells: int, row: int, column: int, step: float) -> Vector3:
	var width := cells + 1
	var left := points[row * width + maxi(column - 1, 0)].y
	var right := points[row * width + mini(column + 1, cells)].y
	var up := points[maxi(row - 1, 0) * width + column].y
	var down := points[mini(row + 1, cells) * width + column].y
	return Vector3(left - right, 2.0 * step, up - down).normalized()
