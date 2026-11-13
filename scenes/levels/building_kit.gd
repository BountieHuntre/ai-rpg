class_name BuildingKit
extends RefCounted
## Builds one place's buildings out of blocks, beams, wedges and cylinders,
## merged into one mesh per color (so a whole village is a few draw calls)
## with collision boxes on one body. Colors go through Props.material, so a
## color with a painted texture (Props.use_texture) is drawn with it.
## Shapes are placed in `frame`, which the Buildings helpers set to each
## building's base and facing; finish() adds it all to the parent.

var frame := Transform3D.IDENTITY
var _parent: Node3D
var _name: String
## color -> Surface
var _surfaces := {}


## One color's triangles.
class Surface:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()

	func add(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
		points.append_array([a, b, c])
		normals.append_array([normal, normal, normal])
var _body := StaticBody3D.new()
## Lights to add: [position, color, range, energy].
var _lights: Array = []
## Ground the buildings stand on (world squares), where no grass grows.
var footprints: Array[Rect2] = []


## Marks a building's footprint (`size` x by z round `base`, turned by
## `yaw`) as built on: the zone grows no grass or bushes there.
func footprint(base: Vector3, size: Vector3, yaw: float) -> void:
	var half := Vector2(size.x, size.z) / 2.0 + Vector2(0.6, 0.6)
	var square := Rect2(Vector2(base.x, base.z), Vector2.ZERO)
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		square = square.expand(Vector2(base.x, base.z) + (corner as Vector2).rotated(-yaw))
	footprints.append(square)


func _init(parent: Node3D, node_name: String) -> void:
	_parent = parent
	_name = node_name


## A box by its center, in `frame`, turned by `turn`; `solid` gives it a
## collision box too.
func box(center: Vector3, size: Vector3, color: Color, turn := Basis(), solid := false) -> void:
	var basis := frame.basis * turn
	var at := frame * center
	var half := size / 2.0
	var faces := [
		[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD],
		[Vector3.UP, Vector3.BACK, Vector3.RIGHT], [Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT],
		[Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
	]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var middle := n * half
		var du := u * half
		var dv := v * half
		var corners := [middle - du - dv, middle + du - dv, middle + du + dv, middle - du + dv]
		var world: Array[Vector3] = []
		for corner: Vector3 in corners:
			world.append(at + basis * corner)
		_quad(color, world, (basis * n).normalized())
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.transform = Transform3D(basis.orthonormalized(), at)
		_body.add_child(collision)


## Collision only: a box by its center, in `frame` (furniture drawn from
## thinner parts).
func collider(center: Vector3, size: Vector3, turn := Basis()) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D((frame.basis * turn).orthonormalized(), frame * center)
	_body.add_child(collision)


## A box standing on `base` (the middle of its bottom), as Props.box.
func block(base: Vector3, size: Vector3, color: Color, yaw := 0.0, solid := false) -> void:
	box(base + Vector3(0, size.y / 2.0, 0), size, color, Basis(Vector3.UP, yaw), solid)


## A square beam from one point to another, `thickness` across.
func beam(from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.001:
		return
	var y := along / length
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	box((from + to) / 2.0, Vector3(thickness, length, thickness), color, Basis(x, y, z))


## A wedge: a triangle `width` across and `height` tall (apex in the middle)
## standing on `base`, `depth` thick along z. Gable ends.
func wedge(base: Vector3, width: float, height: float, depth: float, color: Color, solid := false) -> void:
	var w := width / 2.0
	var d := depth / 2.0
	var a := [base + Vector3(-w, 0, d), base + Vector3(w, 0, d), base + Vector3(0, height, d)]
	var b := [base + Vector3(-w, 0, -d), base + Vector3(w, 0, -d), base + Vector3(0, height, -d)]
	var world_a: Array[Vector3] = []
	var world_b: Array[Vector3] = []
	for p: Vector3 in a:
		world_a.append(frame * p)
	for p: Vector3 in b:
		world_b.append(frame * p)
	var front := (frame.basis * Vector3.BACK).normalized()
	_tri(color, world_a[0], world_a[1], world_a[2], front)
	_tri(color, world_b[1], world_b[0], world_b[2], -front)
	# The two sloping sides and the bottom.
	for edge in [[0, 2], [2, 1], [1, 0]]:
		var p0 := world_a[edge[0]]
		var p1 := world_a[edge[1]]
		var q0 := world_b[edge[0]]
		var q1 := world_b[edge[1]]
		var normal := (p1 - p0).cross(q0 - p0).normalized()
		var center := (world_a[0] + world_a[1] + world_a[2]) / 3.0
		if normal.dot((p0 + p1) / 2.0 - center) < 0.0:
			normal = -normal
		_quad(color, [p0, p1, q1, q0], normal)
	if solid:
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		points.append_array(world_a)
		points.append_array(world_b)
		shape.points = points
		var collision := CollisionShape3D.new()
		collision.shape = shape
		_body.add_child(collision)


## A warm light (a hearth, candles, a room's glow), in `frame`.
func light(at: Vector3, color: Color, light_range: float, energy: float) -> void:
	_lights.append([frame * at, color, light_range, energy])


## A cylinder (or cone, or frustum) standing on `base`.
func cylinder(base: Vector3, radius: float, height: float, color: Color, sides := 10, top_radius := -1.0, solid := false) -> void:
	var top := radius if top_radius < 0.0 else top_radius
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p := [base + d0 * radius, base + d1 * radius, base + d1 * top + Vector3.UP * height, base + d0 * top + Vector3.UP * height]
		var world: Array[Vector3] = []
		for q: Vector3 in p:
			world.append(frame * q)
		var mid := (d0 + d1).normalized()
		var slope := Vector3(mid.x, (radius - top) / maxf(height, 0.001), mid.z).normalized()
		_quad(color, world, (frame.basis * slope).normalized())
		if top > 0.0:
			_tri(color, frame * (base + Vector3.UP * height), frame * (base + d1 * top + Vector3.UP * height), frame * (base + d0 * top + Vector3.UP * height), (frame.basis * Vector3.UP).normalized())
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = frame * (base + Vector3.UP * height / 2.0)
		_body.add_child(collision)


func _quad(color: Color, corners: Array, normal: Vector3) -> void:
	_tri(color, corners[0], corners[1], corners[2], normal)
	_tri(color, corners[0], corners[2], corners[3], normal)


## A triangle facing `normal` (wound so its front faces that way).
func _tri(color: Color, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if not _surfaces.has(color):
		_surfaces[color] = Surface.new()
	# Godot's front faces are clockwise seen from the front: (c - a) x (b - a)
	# points out of them.
	if (c - a).cross(b - a).dot(normal) < 0.0:
		var swap := b
		b = c
		c = swap
	(_surfaces[color] as Surface).add(a, b, c, normal)


## Adds the merged meshes and the collision to the parent.
func finish() -> Node3D:
	var root := Node3D.new()
	root.name = _name
	var mesh := ArrayMesh.new()
	for color: Color in _surfaces:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var surface: Surface = _surfaces[color]
		arrays[Mesh.ARRAY_VERTEX] = surface.points
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Props.material(color))
	var view := MeshInstance3D.new()
	view.name = "Mesh"
	view.mesh = mesh
	root.add_child(view)
	# Shapes are in before the body joins the world (adding them after
	# rebuilds the body each time).
	if _body.get_child_count() > 0:
		root.add_child(_body)
	# The zone this is in keeps the ground under the buildings clear.
	var zone: Node = _parent
	while zone and not zone is Zone:
		zone = zone.get_parent()
	if zone:
		for square in footprints:
			(zone as Zone).clear_ground(square)
	for made: Array in _lights:
		var lamp := OmniLight3D.new()
		lamp.position = made[0]
		lamp.light_color = made[1]
		lamp.omni_range = made[2]
		lamp.light_energy = made[3]
		lamp.shadow_enabled = false
		root.add_child(lamp)
	_parent.add_child(root)
	return root
