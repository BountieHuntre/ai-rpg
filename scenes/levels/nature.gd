class_name Nature
extends RefCounted
## Trees, rocks and grass for the zones, built in code: low-poly meshes
## with shading baked into their vertex colors (light tops, dark undersides,
## moss on rocks) under a painted texture (shaders/nature.gdshader), and
## crossed cards for grass and flowers (shaders/grass_card.gdshader). Each
## kind comes in a few variants from a seed. Many copies are drawn as
## MultiMeshes in square chunks (scatter), so chunks out of view are culled.

const TEXTURES := "res://assets/textures/%s.png"
const NATURE_SHADER := preload("res://shaders/nature.gdshader")
const CARD_SHADER := preload("res://shaders/grass_card.gdshader")

static var _materials: Dictionary = {}


## A mesh under construction: flat-shaded triangles with colors.
class Builder:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	## A triangle facing away from `inside`, with a color per corner.
	func tri(a: Vector3, b: Vector3, c: Vector3, inside: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var normal := (c - a).cross(b - a)
		if normal.dot((a + b + c) / 3.0 - inside) < 0.0:
			var swap := b
			b = c
			c = swap
			var swap_color := cb
			cb = cc
			cc = swap_color
			normal = -normal
		normal = normal.normalized()
		points.append_array([a, b, c])
		normals.append_array([normal, normal, normal])
		colors.append_array([ca, cb, cc])

	func add_to(mesh: ArrayMesh, material: Material) -> void:
		if points.is_empty():
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)


# Materials.

static func material(key: String, texture_size: float, sway := 0.0, sway_from := 1.5) -> ShaderMaterial:
	var id := "%s/%s/%s" % [key, texture_size, sway]
	if not _materials.has(id):
		var made := ShaderMaterial.new()
		made.shader = NATURE_SHADER
		made.set_shader_parameter("albedo_tex", load(TEXTURES % key))
		made.set_shader_parameter("texture_size", texture_size)
		made.set_shader_parameter("sway", sway)
		made.set_shader_parameter("sway_from", sway_from)
		_materials[id] = made
	return _materials[id]


## A grass or flower card's material: its texture and the ground's patches.
static func card_material(key: String, patches: Texture2D, sway := 0.08) -> ShaderMaterial:
	var id := "card/%s/%s" % [key, sway]
	if not _materials.has(id):
		var made := ShaderMaterial.new()
		made.shader = CARD_SHADER
		made.set_shader_parameter("albedo_tex", load(TEXTURES % key))
		made.set_shader_parameter("patch_noise", patches)
		made.set_shader_parameter("sway", sway)
		_materials[id] = made
	return _materials[id]


# Shapes.

## An icosphere of radius 1: [points, faces as index triples].
static func icosphere(subdivisions: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var points: Array[Vector3] = []
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
			Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
			Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		points.append(p.normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for level in subdivisions:
		var middles := {}
		var finer := []
		for face: Array in faces:
			var m := []
			for k in 3:
				var a: int = face[k]
				var b: int = face[(k + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not middles.has(key):
					points.append(((points[a] + points[b]) / 2.0).normalized())
					middles[key] = points.size() - 1
				m.append(middles[key])
			finer.append_array([[face[0], m[0], m[2]], [face[1], m[1], m[0]], [face[2], m[2], m[1]], [m[0], m[1], m[2]]])
		faces = finer
	return [points, faces]


## A lumpy blob: an icosphere pushed in and out by noise, placed by `form`;
## `shade` gives each face's color from its center and normal.
static func _blob(builder: Builder, subdivisions: int, form: Transform3D, noise: FastNoiseLite, lump: float, shade: Callable) -> void:
	var sphere := icosphere(subdivisions)
	var points: Array = sphere[0]
	var placed: Array[Vector3] = []
	for p: Vector3 in points:
		var push := 1.0 + noise.get_noise_3dv(form * p * 1.7) * lump
		placed.append(form * (p * push))
	var center := form.origin
	for face: Array in sphere[1]:
		var a: Vector3 = placed[face[0]]
		var b: Vector3 = placed[face[1]]
		var c: Vector3 = placed[face[2]]
		var middle := (a + b + c) / 3.0
		var normal := (c - a).cross(b - a).normalized()
		if normal.dot(middle - center) < 0.0:
			normal = -normal
		var color: Color = shade.call(middle, normal)
		builder.tri(a, b, c, center, color, color, color)


## A tapering many-sided post from `from` to `to`.
static func _post(builder: Builder, from: Vector3, to: Vector3, bottom: float, top: float, sides: int, color: Color) -> void:
	var up := (to - from).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var other := up.cross(side)
	var middle := (from + to) / 2.0
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side * cos(a0) + other * sin(a0)
		var d1 := side * cos(a1) + other * sin(a1)
		var lit := color.lightened(0.08) if d0.dot(Vector3(-0.6, 0.0, -0.8)) > 0.0 else color.darkened(0.1)
		builder.tri(from + d0 * bottom, from + d1 * bottom, to + d0 * top, middle, lit, lit, lit)
		builder.tri(from + d1 * bottom, to + d1 * top, to + d0 * top, middle, lit, lit, lit)


static func _noise(rng_seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = frequency
	return noise


## A broadleaf tree (an oak), about 6 yards tall: a leaning trunk with two
## or three boughs and a crown of lumpy clumps, lit on top.
static func oak_mesh(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 0.9)
	var bark := Builder.new()
	var leaves := Builder.new()
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.25, 0.25))
	var top := Vector3(0, 2.9, 0) + lean
	_post(bark, Vector3(0, -0.3, 0), top, 0.42, 0.26, 7, Color(0.8, 0.8, 0.8))
	# Root flares.
	for i in 3:
		var angle := TAU * i / 3.0 + rng.randf()
		var out := Vector3(cos(angle), 0, sin(angle))
		_post(bark, out * 0.2 + Vector3(0, -0.2, 0), out * 0.62 + Vector3(0, -0.15, 0), 0.16, 0.05, 4, Color(0.7, 0.7, 0.7))
	var crown := top + Vector3(0, 1.3, 0)
	var boughs := rng.randi_range(2, 3)
	for i in boughs:
		var angle := TAU * i / boughs + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0, sin(angle))
		_post(bark, top - Vector3(0, 0.6, 0), crown + out * 1.1 + Vector3(0, 0.1, 0), 0.16, 0.08, 5, Color(0.75, 0.75, 0.75))
	var clumps := rng.randi_range(6, 8)
	var low := crown.y - 1.6
	var high := crown.y + 2.0
	for i in clumps:
		var angle := rng.randf() * TAU
		var spread := rng.randf_range(0.3, 1.4) if i > 0 else 0.0
		var at := crown + Vector3(cos(angle) * spread, rng.randf_range(-0.4, 0.8) + (0.6 if i == 0 else 0.0), sin(angle) * spread)
		var radius := rng.randf_range(1.0, 1.45) if i > 0 else 1.5
		var hue := rng.randf_range(-0.05, 0.05)
		var form := Transform3D(Basis().scaled(Vector3(radius, radius * 0.85, radius)), at)
		_blob(leaves, 1, form, noise, 0.22, func(middle: Vector3, normal: Vector3) -> Color:
			var height := clampf((middle.y - low) / (high - low), 0.0, 1.0)
			var v := clampf(0.5 + height * 0.42 + normal.y * 0.08 + rng.randf_range(-0.06, 0.06), 0.3, 1.0)
			return Color(v + hue, v, v - hue))
	var mesh := ArrayMesh.new()
	bark.add_to(mesh, material("bark", 1.6))
	leaves.add_to(mesh, material("leaves", 2.2, 0.3, 2.5))
	return mesh


## A pine, about 7.5 yards tall: a thin trunk under five drooping tiers of
## jagged boughs, darker inside and underneath.
static func pine_mesh(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var bark := Builder.new()
	var needles := Builder.new()
	var height := rng.randf_range(7.0, 8.0)
	_post(bark, Vector3(0, -0.3, 0), Vector3(0, height - 0.5, 0), 0.32, 0.06, 6, Color(0.7, 0.7, 0.7))
	var tiers := 5
	var spokes := 11
	for tier in tiers:
		var t := float(tier) / (tiers - 1)
		var base := lerpf(1.5, height - 1.9, t)
		var radius := lerpf(2.3, 0.75, t) * rng.randf_range(0.92, 1.08)
		var rise := lerpf(1.9, 1.5, t)
		var apex := Vector3(0, base + rise, 0)
		var under := Vector3(0, base + 0.35, 0)
		var twist := rng.randf() * TAU
		var ring: Array[Vector3] = []
		for k in spokes:
			var angle := twist + TAU * k / spokes
			var reach := radius * (1.0 if k % 2 == 0 else rng.randf_range(0.68, 0.8))
			var droop := -0.3 if k % 2 == 0 else 0.0
			ring.append(Vector3(cos(angle) * reach, base + droop + rng.randf_range(-0.08, 0.08), sin(angle) * reach))
		var lit := clampf(0.62 + t * 0.3, 0.0, 1.0)
		for k in spokes:
			var a := ring[k]
			var b := ring[(k + 1) % spokes]
			var tip_a := lit * (1.0 if k % 2 == 0 else 0.85)
			var tip_b := lit * (1.0 if (k + 1) % 2 == 0 else 0.85)
			var side := clampf(0.5 + 0.5 * Vector2(a.x, a.z).normalized().dot(Vector2(-0.6, -0.8)), 0.0, 1.0) * 0.12
			needles.tri(apex, a, b, Vector3(0, base, 0), Color.WHITE * (lit + 0.05 + side), Color.WHITE * (tip_a + side), Color.WHITE * (tip_b + side))
			needles.tri(under, b, a, Vector3(0, base + rise, 0), Color.WHITE * 0.35, Color.WHITE * 0.5, Color.WHITE * 0.5)
	var mesh := ArrayMesh.new()
	bark.add_to(mesh, material("bark", 1.6))
	needles.add_to(mesh, material("needles", 2.0, 0.18, 2.0))
	return mesh


## A boulder about 2 yards across and 1.3 high (scaled where it's placed):
## a lumpy, flat-faced stone, sunk at the bottom, with moss on top.
static func rock_mesh(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 0.8)
	var stone := Builder.new()
	var squash := Vector3(rng.randf_range(0.9, 1.15), rng.randf_range(0.6, 0.75), rng.randf_range(0.85, 1.1))
	var form := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(squash), Vector3.ZERO)
	var moss := Color(0.62, 0.8, 0.45)
	_blob(stone, 1, form, noise, 0.35, func(middle: Vector3, normal: Vector3) -> Color:
		var v := clampf(0.62 + normal.y * 0.18 + noise.get_noise_3dv(middle * 3.0) * 0.12, 0.35, 1.0)
		var color := Color(v, v, v)
		if normal.y > 0.55 and noise.get_noise_3dv(middle * 2.0 + Vector3(9, 9, 9)) > -0.15:
			color = Color(v * moss.r, v * moss.g, v * moss.b)
		return color)
	var mesh := ArrayMesh.new()
	stone.add_to(mesh, material("rock", 2.2))
	return mesh


## A bush about a yard and a half across: a few low leafy clumps on the
## ground, lit on top.
static func bush_mesh(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 1.2)
	var leaves := Builder.new()
	var clumps := rng.randi_range(3, 5)
	var hue := rng.randf_range(-0.04, 0.05)
	for i in clumps:
		var angle := rng.randf() * TAU
		var spread := rng.randf_range(0.0, 0.55) if i > 0 else 0.0
		var radius := rng.randf_range(0.45, 0.7)
		var at := Vector3(cos(angle) * spread, radius * 0.55, sin(angle) * spread)
		var form := Transform3D(Basis().scaled(Vector3(radius, radius * 0.8, radius)), at)
		_blob(leaves, 1, form, noise, 0.25, func(middle: Vector3, normal: Vector3) -> Color:
			var v := clampf(0.5 + middle.y * 0.32 + normal.y * 0.1 + rng.randf_range(-0.05, 0.05), 0.3, 1.0)
			return Color(v + hue, v, v - hue))
	var mesh := ArrayMesh.new()
	leaves.add_to(mesh, material("leaves", 1.6, 0.25, 0.3))
	return mesh


## A clump card: `planes` crossed quads `width` wide and `height` tall,
## standing on the ground, their normals up so they're lit like it.
static func card_mesh(width: float, height: float, planes := 3) -> ArrayMesh:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in planes:
		var angle := PI * i / planes
		var across := Vector3(cos(angle), 0, sin(angle)) * width / 2.0
		var start := points.size()
		points.append_array([-across + Vector3.UP * height, across + Vector3.UP * height, across, -across])
		uvs.append_array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		for k in 4:
			normals.append(Vector3.UP)
		indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Placing.

## Many copies of a mesh as MultiMeshes in square chunks `chunk` yards
## across, drawn to `range_end` yards (0 for always). Returns the chunks.
static func scatter(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], chunk := 48.0, range_end := 0.0, shadows := true, material_override: Material = null) -> Array[MultiMeshInstance3D]:
	var groups := {}
	for each in transforms:
		var key := Vector2i(floori(each.origin.x / chunk), floori(each.origin.z / chunk))
		if not groups.has(key):
			groups[key] = []
		groups[key].append(each)
	var made: Array[MultiMeshInstance3D] = []
	for key: Vector2i in groups:
		var list: Array = groups[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = list.size()
		for i in list.size():
			multimesh.set_instance_transform(i, list[i])
		var view := MultiMeshInstance3D.new()
		view.multimesh = multimesh
		if material_override:
			view.material_override = material_override
		if range_end > 0.0:
			view.visibility_range_end = range_end
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(view)
		made.append(view)
	return made


## Shuffles in place with a seeded generator (so drawing a share of a
## chunk thins it evenly).
static func shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap
