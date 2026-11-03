class_name Props
extends RefCounted
## Simple low-poly building blocks for levels until there are real models:
## colored boxes, roofs, trees and rocks, with collision on the world layer.

static var _materials: Dictionary


static func material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var made := StandardMaterial3D.new()
		made.albedo_color = color
		_materials[color] = made
	return _materials[color]


## A solid box with collision. `at` is the center of its base.
static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, yaw := 0.0, solid := true) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _solid(parent, at, yaw, mesh, color, _box_shape(size) if solid else null, size.y / 2.0)


## A gable roof: a prism whose ridge runs along x.
static func roof(parent: Node3D, at: Vector3, size: Vector3, color: Color, yaw := 0.0) -> Node3D:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(size.z, size.y, size.x)
	var node := _solid(parent, at, yaw, mesh, color, null, size.y / 2.0)
	node.get_child(0).rotation.y = PI / 2
	return node


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color, solid := true, top_radius := -1.0) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 8
	var shape: Shape3D = null
	if solid:
		var cylinder_shape := CylinderShape3D.new()
		cylinder_shape.radius = radius
		cylinder_shape.height = height
		shape = cylinder_shape
	return _solid(parent, at, 0.0, mesh, color, shape, height / 2.0)


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func _solid(parent: Node3D, at: Vector3, yaw: float, mesh: Mesh, color: Color, shape: Shape3D, lift: float) -> Node3D:
	var node: Node3D = StaticBody3D.new() if shape else Node3D.new()
	node.position = at
	node.rotation.y = yaw
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = material(color)
	view.position.y = lift
	node.add_child(view)
	if shape:
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = lift
		node.add_child(collision)
	parent.add_child(node)
	return node


## Many copies of one mesh, drawn in a single call.
static func scatter(parent: Node3D, mesh: Mesh, color: Color, transforms: Array[Transform3D]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var view := MultiMeshInstance3D.new()
	view.multimesh = multimesh
	view.material_override = material(color)
	parent.add_child(view)


static func cone(radius: float, height: float, segments := 7) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func blob(radius: float, segments := 7, rings := 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh
