class_name Props
extends RefCounted
## Simple low-poly building blocks for levels until there are real models:
## colored boxes, roofs, trees and rocks, with collision on the world layer.

static var _materials: Dictionary
## Colors drawn with a painted texture instead (use_texture): color ->
## [texture key, yards it spans].
static var _textured: Dictionary = {}
## The painted textures' average colors, which a block's color is tinted
## against.
const TEXTURE_AVERAGES := {
	"stone_wall": Color(0.6, 0.58, 0.54), "roof_tiles": Color(0.5, 0.21, 0.15),
	"planks": Color(0.43, 0.3, 0.19), "rock": Color(0.42, 0.4, 0.37),
	"thatch": Color(0.62, 0.48, 0.24), "plaster": Color(0.83, 0.79, 0.69),
}
const TEXTURED_SHADER := preload("res://shaders/textured_prop.gdshader")


## Blocks of this color are drawn with a painted texture (tools/textures)
## spanning `size` yards, tinted toward the color (shaders/textured_prop).
static func use_texture(color: Color, key: String, size: float) -> void:
	_textured[color] = [key, size]


static func material(color: Color) -> Material:
	if not _materials.has(color):
		if _textured.has(color):
			var key: String = _textured[color][0]
			var average: Color = TEXTURE_AVERAGES.get(key, Color(0.5, 0.5, 0.5))
			var textured := ShaderMaterial.new()
			textured.shader = TEXTURED_SHADER
			textured.set_shader_parameter("albedo_tex", load("res://assets/textures/%s.png" % key))
			textured.set_shader_parameter("texture_size", _textured[color][1])
			textured.set_shader_parameter("tint", Vector3(color.r / average.r, color.g / average.g, color.b / average.b))
			_materials[color] = textured
		else:
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
