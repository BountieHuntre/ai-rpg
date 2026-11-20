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
## While on, every Builder added to a mesh is kept in `recorded` as
## [builder, material] (the tree bake reads a tree's parts this way).
static var recording := false
static var recorded: Array = []


## A mesh under construction: flat-shaded triangles with colors, made of
## closed solids (`starts`: where each begins) that tools/models/nature/
## bake_trees.gd joins into one; an `overlay` (snow, fronds) isn't a solid
## and is laid on top as it is.
class Builder:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var starts := PackedInt32Array()
	var overlay := false

	## The next triangles are a new closed solid.
	func begin_piece() -> void:
		starts.append(points.size())

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
		if Nature.recording:
			Nature.recorded.append([self, material])
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


# Trees, each one solid mesh: their parts joined by CSG and baked to
# TREE_PATH by tools/models/nature/bake_trees.gd (variant n of a kind is
# built from TREE_SEEDS[kind] + n). Unbaked, a tree is its parts as built.

const TREE_PATH := "res://assets/models/nature/%s_%d.res"
const TREE_VARIANTS := 6
## Kinds made just once (buildings, the great tree): one variant.
const SINGLE_KINDS := ["great_tree", "bower_violet", "bower_teal", "long_bower", "moonwell_ring", "silver_gate",
	"longhouse", "totem"]


## How many variants a kind has.
static func variants_of(kind: String) -> int:
	return 1 if kind in SINGLE_KINDS else TREE_VARIANTS
const TREE_SEEDS := { "pine": 8101, "pine_snowy": 8101, "oak": 8201, "dead_tree": 8301, "palm": 8401,
	"elf_tree": 8501, "great_tree": 8601, "bower_violet": 8701, "bower_teal": 8711, "long_bower": 8721,
	"log_hut": 8801, "moonwell_ring": 8901, "silver_gate": 9001,
	"tipi_light": 9101, "tipi_dark": 9111, "longhouse": 9201, "totem": 9301 }


## The unbaked tree of a kind, built from a seed.
static func build_tree(kind: String, rng_seed: int) -> ArrayMesh:
	match kind:
		"pine":
			return _pine(rng_seed)
		"pine_snowy":
			return _pine(rng_seed, true)
		"oak":
			return _oak(rng_seed)
		"dead_tree":
			return _dead_tree(rng_seed)
		"palm":
			return _palm(rng_seed)
		"elf_tree":
			return _elf_tree(rng_seed)
		"great_tree":
			return _great_tree(rng_seed)
		"bower_violet":
			return _bower(rng_seed, Color(0.78, 0.6, 1.0))
		"bower_teal":
			return _bower(rng_seed, Color(0.5, 0.92, 0.95))
		"long_bower":
			return _long_bower(rng_seed)
		"log_hut":
			return _log_hut(rng_seed)
		"moonwell_ring":
			return _moonwell_ring(rng_seed)
		"silver_gate":
			return _silver_gate(rng_seed)
		"tipi_light":
			return _tipi(rng_seed, Color(1.0, 0.95, 0.88))
		"tipi_dark":
			return _tipi(rng_seed, Color(0.72, 0.64, 0.56))
		"longhouse":
			return _longhouse(rng_seed)
		"totem":
			return _totem(rng_seed)
	return ArrayMesh.new()


## A tree of a kind (any seed picks one of its variants): baked if it is,
## its surfaces given the shared materials their names stand for.
static func tree(kind: String, rng_seed: int) -> ArrayMesh:
	var variant := posmod(rng_seed, variants_of(kind))
	var path := TREE_PATH % [kind, variant]
	if not ResourceLoader.exists(path):
		return build_tree(kind, TREE_SEEDS[kind] + variant)
	var mesh := (load(path) as ArrayMesh).duplicate() as ArrayMesh
	for i in mesh.get_surface_count():
		var made := material_named(mesh.surface_get_name(i))
		if made:
			mesh.surface_set_material(i, made)
	return mesh


## An elven tree, a great tree (scaled up where it stands), a bower, the long
## bower, a bearfolk's log hut, a moonwell's ring or the Silverbough Gate,
## one solid each (tree).
static func elf_tree_mesh(rng_seed: int) -> ArrayMesh:
	return tree("elf_tree", rng_seed)


static func baked(kind: String, variant := 0) -> ArrayMesh:
	return tree(kind, variant)


## A pine, oak, dead tree or palm, one solid each (tree).
static func pine_mesh(rng_seed: int, snowy := false) -> ArrayMesh:
	return tree("pine_snowy" if snowy else "pine", rng_seed)


static func oak_mesh(rng_seed: int) -> ArrayMesh:
	return tree("oak", rng_seed)


static func dead_tree_mesh(rng_seed: int) -> ArrayMesh:
	return tree("dead_tree", rng_seed)


static func palm_mesh(rng_seed: int) -> ArrayMesh:
	return tree("palm", rng_seed)


## A material's name for a baked surface ("key|size|sway|sway_from"), and
## back.
static func material_name(made: ShaderMaterial) -> String:
	var texture: Texture2D = made.get_shader_parameter("albedo_tex")
	return "%s|%s|%s|%s" % [texture.resource_path.get_file().get_basename(), made.get_shader_parameter("texture_size"),
		made.get_shader_parameter("sway"), made.get_shader_parameter("sway_from")]


static func material_named(text: String) -> ShaderMaterial:
	var parts := text.split("|")
	if parts.size() != 4:
		return null
	return material(parts[0], float(parts[1]), float(parts[2]), float(parts[3]))


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
## `shade` gives each face's color from its center and normal. Faces `cap`
## (f(center, normal) -> bool) picks go to `capped` instead (snow on top).
static func _blob(builder: Builder, subdivisions: int, form: Transform3D, noise: FastNoiseLite, lump: float, shade: Callable, capped: Builder = null, cap := Callable()) -> void:
	builder.begin_piece()
	if capped != null:
		capped.begin_piece()
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
		var into := capped if capped != null and cap.call(middle, normal) else builder
		into.tri(a, b, c, center, color, color, color)


## A tapering many-sided post from `from` to `to`.
static func _post(builder: Builder, from: Vector3, to: Vector3, bottom: float, top: float, sides: int, color: Color) -> void:
	builder.begin_piece()
	var up := (to - from).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var other := up.cross(side)
	var middle := (from + to) / 2.0
	top = maxf(top, 0.005)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side * cos(a0) + other * sin(a0)
		var d1 := side * cos(a1) + other * sin(a1)
		var lit := color.lightened(0.08) if d0.dot(Vector3(-0.6, 0.0, -0.8)) > 0.0 else color.darkened(0.1)
		builder.tri(from + d0 * bottom, from + d1 * bottom, to + d0 * top, middle, lit, lit, lit)
		builder.tri(from + d1 * bottom, to + d1 * top, to + d0 * top, middle, lit, lit, lit)
		# The ends, so it's a closed solid.
		builder.tri(from, from + d0 * bottom, from + d1 * bottom, middle, lit, lit, lit)
		builder.tri(to, to + d1 * top, to + d0 * top, middle, lit, lit, lit)


static func _noise(rng_seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng_seed
	noise.frequency = frequency
	return noise


## A broadleaf tree (an oak), about 6 yards tall: a leaning trunk with two
## or three boughs and a crown of lumpy clumps, lit on top.
static func _oak(rng_seed: int) -> ArrayMesh:
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
static func _pine(rng_seed: int, snowy := false) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var bark := Builder.new()
	var needles := Builder.new()
	var snow := Builder.new()
	snow.overlay = true
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
		needles.begin_piece()
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
			# Snow lying on the bough's top, short of its tips.
			if snowy:
				var lift := Vector3(0, 0.07, 0)
				var reach_a := rng.randf_range(0.55, 0.85)
				var reach_b := rng.randf_range(0.55, 0.85)
				var glow := clampf(0.85 + t * 0.12 + side, 0.0, 1.1)
				snow.tri(apex + lift, apex.lerp(a, reach_a) + lift, apex.lerp(b, reach_b) + lift, Vector3(0, base, 0),
					Color.WHITE * glow, Color.WHITE * (glow - 0.08), Color.WHITE * (glow - 0.08))
	var mesh := ArrayMesh.new()
	bark.add_to(mesh, material("bark", 1.6))
	needles.add_to(mesh, material("needles", 2.0, 0.18, 2.0))
	snow.add_to(mesh, material("snow", 2.0, 0.18, 2.0))
	return mesh


## A boulder about 2 yards across and 1.3 high (scaled where it's placed):
## a lumpy, flat-faced stone, sunk at the bottom, with moss on top.
## `texture` is the stone's (red_rock for the red lands, no moss on it).
static func rock_mesh(rng_seed: int, snowy := false, texture := "rock") -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 0.8)
	var stone := Builder.new()
	var snow := Builder.new()
	var squash := Vector3(rng.randf_range(0.9, 1.15), rng.randf_range(0.6, 0.75), rng.randf_range(0.85, 1.1))
	var form := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(squash), Vector3.ZERO)
	var moss := Color(0.62, 0.8, 0.45)
	var snow_cap := func(_middle: Vector3, normal: Vector3) -> bool:
		return snowy and normal.y > 0.45
	var shade := func(middle: Vector3, normal: Vector3) -> Color:
		var v := clampf(0.62 + normal.y * 0.18 + noise.get_noise_3dv(middle * 3.0) * 0.12, 0.35, 1.0)
		var color := Color(v, v, v)
		if snowy and normal.y > 0.45:
			var white := clampf(0.82 + normal.y * 0.18, 0.0, 1.0)
			return Color(white, white, white)
		if not snowy and texture == "rock" and normal.y > 0.55 and noise.get_noise_3dv(middle * 2.0 + Vector3(9, 9, 9)) > -0.15:
			color = Color(v * moss.r, v * moss.g, v * moss.b)
		return color
	_blob(stone, 1, form, noise, 0.35, shade, snow, snow_cap)
	var mesh := ArrayMesh.new()
	stone.add_to(mesh, material(texture, 2.2))
	snow.add_to(mesh, material("snow", 2.2))
	return mesh


## A bush about a yard and a half across: a few low leafy clumps on the
## ground, lit on top.
## `leaves` is its leaves' texture (elf_leaves in the elven woods).
static func bush_mesh(rng_seed: int, snowy := false, leaves_key := "leaves") -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 1.2)
	var leaves := Builder.new()
	var snow := Builder.new()
	var clumps := rng.randi_range(3, 5)
	var hue := rng.randf_range(-0.04, 0.05)
	for i in clumps:
		var angle := rng.randf() * TAU
		var spread := rng.randf_range(0.0, 0.55) if i > 0 else 0.0
		var radius := rng.randf_range(0.45, 0.7)
		var at := Vector3(cos(angle) * spread, radius * 0.55, sin(angle) * spread)
		var form := Transform3D(Basis().scaled(Vector3(radius, radius * 0.8, radius)), at)
		var snow_cap := func(_middle: Vector3, normal: Vector3) -> bool:
			return snowy and normal.y > 0.5
		var shade := func(middle: Vector3, normal: Vector3) -> Color:
			if snowy and normal.y > 0.5:
				var white := clampf(0.85 + normal.y * 0.15, 0.0, 1.0)
				return Color(white, white, white)
			var v := clampf(0.5 + middle.y * 0.32 + normal.y * 0.1 + rng.randf_range(-0.05, 0.05), 0.3, 1.0)
			return Color(v + hue, v, v - hue)
		_blob(leaves, 1, form, noise, 0.25, shade, snow, snow_cap)
	var mesh := ArrayMesh.new()
	leaves.add_to(mesh, material(leaves_key, 1.6, 0.25, 0.3))
	snow.add_to(mesh, material("snow", 1.6, 0.25, 0.3))
	return mesh


## How many cacti there are, baked to CACTUS_PATH by
## tools/models/nature/bake_cacti.gd: each one solid, its trunk and arms
## joined by CSG (cactus_parts), so it's one mesh with no seams.
const CACTUS_VARIANTS := 6
const CACTUS_SEED := 7301
const CACTUS_PATH := "res://assets/models/nature/cactus_%d.res"


## A cactus (variant 0 to CACTUS_VARIANTS - 1): the baked mesh with the
## cactus skin, or its parts unjoined while it isn't baked.
static func cactus_mesh(variant: int) -> ArrayMesh:
	var path := CACTUS_PATH % variant
	var mesh: ArrayMesh
	if ResourceLoader.exists(path):
		mesh = (load(path) as ArrayMesh).duplicate()
	else:
		mesh = ArrayMesh.new()
		for part: ArrayMesh in cactus_parts(CACTUS_SEED + variant):
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, part.surface_get_arrays(0))
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, material("cactus", 1.0))
	return mesh


## A cactus about 3 yards tall as closed solids to be joined: a ribbed
## trunk with a rounded top and up to two arms, each one tube that runs out
## of the trunk, bends up round a curved elbow and ends rounded.
static func cactus_parts(rng_seed: int) -> Array[ArrayMesh]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var parts: Array[ArrayMesh] = []
	var height := rng.randf_range(2.4, 3.4)
	var radius := rng.randf_range(0.28, 0.36)
	parts.append(_tube([Vector3(0, -0.3, 0), Vector3(0, height * 0.5, 0), Vector3(0, height, 0)],
		[radius, radius * 0.97, radius * 0.92], 10))
	var arms := rng.randi_range(1, 2)
	var turn := rng.randf() * TAU
	for i in arms:
		var out := Vector3(cos(turn + PI * i), 0, sin(turn + PI * i))
		var r := radius * rng.randf_range(0.58, 0.68)
		var from := Vector3(0, rng.randf_range(height * 0.35, height * 0.6), 0)
		var reach := rng.randf_range(0.7, 0.95)
		var bend := r * 1.4
		var path: Array[Vector3] = [from, from + out * (reach - bend)]
		var corner := from + out * (reach - bend) + Vector3.UP * bend
		for k in range(1, 5):
			var angle := PI / 2.0 * k / 4.0
			path.append(corner - Vector3.UP * cos(angle) * bend + out * sin(angle) * bend)
		path.append(path[path.size() - 1] + Vector3.UP * rng.randf_range(0.6, 1.1))
		var radii: Array[float] = []
		for k in path.size():
			radii.append(r * (1.0 if k < path.size() - 1 else 0.92))
		parts.append(_tube(path, radii, 8))
	return parts


## A closed tube along `path` with a radius at each point and `sides` sides:
## a flat end at the start, a dome at the end. Rings turn with the path
## (parallel transport), so bends don't twist.
static func _tube(path: Array, radii: Array, sides: int) -> ArrayMesh:
	var points := PackedVector3Array()
	var indices := PackedInt32Array()
	var first: Vector3 = path[0]
	var heading: Vector3 = ((path[1] as Vector3) - first).normalized()
	var across := heading.cross(Vector3.FORWARD if absf(heading.z) < 0.9 else Vector3.RIGHT).normalized()
	# The path with its dome: rings shrinking to a point past the last.
	var centers: Array[Vector3] = []
	var sizes: Array[float] = []
	for k in path.size():
		centers.append(path[k])
		sizes.append(radii[k])
	var last: Vector3 = path[path.size() - 1]
	var tip_heading := (last - (path[path.size() - 2] as Vector3)).normalized()
	var end_radius: float = radii[radii.size() - 1]
	for step in [0.45, 0.75, 0.93]:
		centers.append(last + tip_heading * end_radius * step)
		sizes.append(end_radius * sqrt(1.0 - step * step))
	var rings := centers.size()
	for k in rings:
		var forward := ((centers[mini(k + 1, rings - 1)] - centers[maxi(k - 1, 0)])).normalized()
		# Parallel transport: keep `across` square to the path as it turns.
		across = (across - forward * across.dot(forward)).normalized()
		var other := forward.cross(across)
		for j in sides:
			var angle := TAU * j / sides
			points.append(centers[k] + (across * cos(angle) + other * sin(angle)) * sizes[k])
	for k in rings - 1:
		for j in sides:
			var a := k * sides + j
			var b := k * sides + (j + 1) % sides
			var c := a + sides
			var d := b + sides
			indices.append_array([a, c, b, b, c, d])
	# The flat start and the dome's point.
	var start := points.size()
	points.append(first)
	var tip := points.size()
	points.append(centers[rings - 1] + tip_heading * end_radius * 0.07)
	for j in sides:
		indices.append_array([start, j, (j + 1) % sides])
		var a := (rings - 1) * sides + j
		var b := (rings - 1) * sides + (j + 1) % sides
		indices.append_array([a, tip, b])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		surface.add_vertex(points[index])
	surface.index()
	surface.generate_normals()
	return surface.commit()


## A dead bush about a yard and a half across: bare, twisted grey twigs
## forking out of the ground, no leaves (the red lands).
static func dead_bush_mesh(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var wood := Builder.new()
	var stems := rng.randi_range(4, 6)
	for i in stems:
		var angle := TAU * i / stems + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0, sin(angle))
		_twig(wood, rng, Vector3(0, -0.1, 0), (out * rng.randf_range(0.4, 0.8) + Vector3.UP).normalized(),
			rng.randf_range(0.5, 0.75), 0.06, 3)
	var mesh := ArrayMesh.new()
	wood.add_to(mesh, material("bark", 0.8))
	return mesh


## A closed box, a piece of its own: its middle, size, and a turn about up.
static func _box(builder: Builder, middle: Vector3, size: Vector3, color: Color, yaw := 0.0) -> void:
	builder.begin_piece()
	var basis := Basis(Vector3.UP, yaw)
	var half := size / 2.0
	var corners: Array[Vector3] = []
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				corners.append(middle + basis * Vector3(x * half.x, y * half.y, z * half.z))
	# Corners indexed by (x, y, z) bits: 4x + 2y + z.
	for quad in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		var top := color.lightened(0.08) if quad == [2, 3, 7, 6] else color
		builder.tri(corners[quad[0]], corners[quad[1]], corners[quad[2]], middle, top, top, top)
		builder.tri(corners[quad[0]], corners[quad[2]], corners[quad[3]], middle, top, top, top)


## An elven tree about 9 yards tall: a tall silver trunk, two or three boughs
## and a crown of broad, flattened tiers of teal leaves.
static func _elf_tree(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 0.9)
	var bark := Builder.new()
	var leaves := Builder.new()
	var height := rng.randf_range(6.0, 7.5)
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3))
	var top := Vector3(0, height, 0) + lean
	_post(bark, Vector3(0, -0.3, 0), top, 0.5, 0.28, 8, Color(0.85, 0.85, 0.85))
	for i in 4:
		var angle := TAU * i / 4.0 + rng.randf()
		var out := Vector3(cos(angle), 0, sin(angle))
		_post(bark, out * 0.25 + Vector3(0, -0.2, 0), out * 0.85 + Vector3(0, -0.15, 0), 0.2, 0.05, 5, Color(0.75, 0.75, 0.75))
	var boughs := rng.randi_range(2, 3)
	for i in boughs:
		var angle := TAU * i / boughs + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0, sin(angle))
		_post(bark, top - Vector3(0, 1.8, 0), top + out * 1.6 + Vector3(0, 0.4, 0), 0.18, 0.08, 5, Color(0.8, 0.8, 0.8))
	var tiers := 3
	for tier in tiers:
		var t := float(tier) / (tiers - 1)
		var radius := lerpf(2.8, 1.6, t) * rng.randf_range(0.9, 1.1)
		var at := top + Vector3(rng.randf_range(-0.3, 0.3), -0.6 + tier * 1.3, rng.randf_range(-0.3, 0.3))
		var form := Transform3D(Basis().scaled(Vector3(radius, radius * 0.38, radius)), at)
		var hue := rng.randf_range(-0.04, 0.04)
		_blob(leaves, 1, form, noise, 0.2, func(middle: Vector3, normal: Vector3) -> Color:
			var v := clampf(0.55 + t * 0.25 + normal.y * 0.15 + rng.randf_range(-0.05, 0.05), 0.3, 1.0)
			return Color(v + hue, v, v + hue * 0.5))
	var mesh := ArrayMesh.new()
	bark.add_to(mesh, material("pale_bark", 1.6))
	leaves.add_to(mesh, material("elf_leaves", 2.2, 0.25, 4.0))
	return mesh


## A great tree at 1/9 of the Elderbough's size (scaled up where it stands):
## a vast trunk on spreading roots, thick boughs and a broad crown.
static func _great_tree(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, 0.6)
	var bark := Builder.new()
	var leaves := Builder.new()
	var height := 7.0
	var top := Vector3(0, height, 0)
	_post(bark, Vector3(0, -0.4, 0), top, 1.0, 0.6, 12, Color(0.85, 0.85, 0.85))
	for i in 7:
		var angle := TAU * i / 7.0 + 0.3
		var out := Vector3(cos(angle), 0, sin(angle))
		_post(bark, out * 0.5 + Vector3(0, 0.8, 0), out * 1.9 + Vector3(0, -0.3, 0), 0.45, 0.12, 6, Color(0.75, 0.75, 0.75))
	for i in 5:
		var angle := TAU * i / 5.0 + rng.randf_range(-0.3, 0.3)
		var out := Vector3(cos(angle), 0, sin(angle))
		var reach := rng.randf_range(1.6, 2.3)
		_post(bark, top - Vector3(0, 1.4, 0), top + out * reach + Vector3(0, 0.9, 0), 0.4, 0.2, 7, Color(0.8, 0.8, 0.8))
		var form := Transform3D(Basis().scaled(Vector3(1.6, 0.7, 1.6)), top + out * reach + Vector3(0, 1.3, 0))
		_blob(leaves, 1, form, noise, 0.2, func(_middle: Vector3, normal: Vector3) -> Color:
			var v := clampf(0.6 + normal.y * 0.2 + rng.randf_range(-0.05, 0.05), 0.3, 1.0)
			return Color(v, v, v))
	var crown := Transform3D(Basis().scaled(Vector3(2.0, 0.9, 2.0)), top + Vector3(0, 1.8, 0))
	_blob(leaves, 1, crown, noise, 0.2, func(_middle: Vector3, normal: Vector3) -> Color:
		var v := clampf(0.7 + normal.y * 0.2, 0.3, 1.0)
		return Color(v, v, v))
	var mesh := ArrayMesh.new()
	bark.add_to(mesh, material("pale_bark", 0.6))
	leaves.add_to(mesh, material("elf_leaves", 0.8))
	return mesh


## An elven bower about 3.6 yards round: a round floor of planks, four posts
## and a sweeping roof of leaf shingles in `tint`.
static func _bower(rng_seed: int, tint: Color) -> ArrayMesh:
	var wood := Builder.new()
	var floor := Builder.new()
	var roof := Builder.new()
	var radius := 3.6
	_post(floor, Vector3(0, -0.3, 0), Vector3(0, 0.4, 0), radius, radius, 12, Color(0.9, 0.9, 0.9))
	for i in 4:
		var angle := TAU * i / 4.0 + PI / 4.0
		var at := Vector3(cos(angle), 0, sin(angle)) * (radius - 0.5)
		_post(wood, at + Vector3(0, 0.2, 0), at + Vector3(0, 3.4, 0), 0.18, 0.15, 6, Color(0.9, 0.9, 0.9))
	_post(roof, Vector3(0, 3.2, 0), Vector3(0, 4.0, 0), radius + 0.8, radius * 0.6, 12, tint * 0.9)
	_post(roof, Vector3(0, 4.0, 0), Vector3(0, 5.2, 0), radius * 0.6, 0.15, 12, tint)
	_post(wood, Vector3(0, 5.0, 0), Vector3(0, 6.0, 0), 0.12, 0.02, 5, Color(0.95, 0.95, 0.95))
	var mesh := ArrayMesh.new()
	floor.add_to(mesh, material("planks", 1.5))
	wood.add_to(mesh, material("pale_bark", 1.2))
	roof.add_to(mesh, material("elf_roof", 1.4))
	return mesh


## Fernwatch's inn: a long open bower, 18 by 9, a plank floor, posts and a
## sweeping violet roof.
static func _long_bower(rng_seed: int) -> ArrayMesh:
	var wood := Builder.new()
	var floor := Builder.new()
	var roof := Builder.new()
	_box(floor, Vector3(0, 0.0, 0), Vector3(18, 0.8, 9), Color(0.9, 0.9, 0.9))
	for x in [-8.5, -2.8, 2.8, 8.5]:
		for z in [-4.0, 4.0]:
			_post(wood, Vector3(x, 0.3, z), Vector3(x, 3.9, z), 0.2, 0.17, 6, Color(0.9, 0.9, 0.9))
	var violet := Color(0.78, 0.6, 1.0)
	# The roof: two sweeping slopes meeting at a ridge, as boxes tilted.
	for side in [-1.0, 1.0]:
		roof.begin_piece()
		var eave := Vector3(0, 3.6, side * 5.8)
		var ridge := Vector3(0, 6.2, 0)
		var corners: Array[Vector3] = []
		for x in [-10.0, 10.0]:
			corners.append(Vector3(x, eave.y, eave.z))
			corners.append(Vector3(x, ridge.y, ridge.z))
			corners.append(Vector3(x, eave.y + 0.35, eave.z))
			corners.append(Vector3(x, ridge.y + 0.35, ridge.z))
		var inside := Vector3(0, 4.9, side * 2.9)
		for quad in [[0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5], [0, 2, 3, 1], [4, 5, 7, 6]]:
			var c := violet * (1.0 if quad == [2, 6, 7, 3] else 0.7)
			roof.tri(corners[quad[0]], corners[quad[1]], corners[quad[2]], inside, c, c, c)
			roof.tri(corners[quad[0]], corners[quad[2]], corners[quad[3]], inside, c, c, c)
	_box(wood, Vector3(0, 6.3, 0), Vector3(20.4, 0.3, 0.4), Color(0.95, 0.95, 0.95))
	var mesh := ArrayMesh.new()
	floor.add_to(mesh, material("planks", 1.5))
	wood.add_to(mesh, material("pale_bark", 1.2))
	roof.add_to(mesh, material("elf_roof", 1.4))
	return mesh


## A bearfolk hut: logs leaning together in a cone round a dark doorway.
static func _log_hut(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var logs := Builder.new()
	var radius := 3.0
	_post(logs, Vector3(0, -0.2, 0), Vector3(0, 3.4, 0), radius * 0.85, 0.3, 10, Color(0.6, 0.6, 0.6))
	var count := 14
	for i in count:
		var angle := TAU * i / count
		var out := Vector3(cos(angle), 0, sin(angle))
		if absf(wrapf(angle - PI / 2.0, -PI, PI)) < 0.35:
			continue
		var foot := out * (radius + rng.randf_range(-0.1, 0.2)) + Vector3(0, -0.2, 0)
		var head := out * 0.2 + Vector3(0, 4.0 + rng.randf_range(-0.2, 0.4), 0)
		_post(logs, foot, head, 0.22, 0.15, 6, Color(0.85, 0.85, 0.85) * rng.randf_range(0.85, 1.05))
	# The doorway: a dark opening in the logs to the south (+z).
	_box(logs, Vector3(0, 0.9, radius * 0.75), Vector3(1.3, 1.9, 0.6), Color(0.08, 0.06, 0.05))
	var mesh := ArrayMesh.new()
	logs.add_to(mesh, material("bark", 1.4))
	return mesh


## A moonwell's ring: pale stones round the water, with a lip on top.
static func _moonwell_ring(rng_seed: int) -> ArrayMesh:
	var stone := Builder.new()
	var count := 12
	var radius := 1.0
	for i in count:
		var angle := TAU * (i + 0.5) / count
		var at := Vector3(cos(angle), 0, sin(angle)) * radius
		_box(stone, at + Vector3(0, 0.33, 0), Vector3(0.6, 0.72, 0.3), Color(0.95, 0.95, 1.0), -angle + PI / 2.0)
	var mesh := ArrayMesh.new()
	stone.add_to(mesh, material("stone_wall", 1.2))
	return mesh


## The Silverbough Gate: two tall pale pillars, a lintel and shut doors.
static func _silver_gate(rng_seed: int) -> ArrayMesh:
	var wood := Builder.new()
	var doors := Builder.new()
	for side in [-1.0, 1.0]:
		_post(wood, Vector3(0, -0.3, side * 6.0), Vector3(0, 12.0, side * 6.0), 1.0, 0.7, 10, Color(0.95, 0.95, 0.95))
		_post(wood, Vector3(0, 12.0, side * 6.0), Vector3(0, 13.4, side * 6.0), 0.7, 0.05, 10, Color(1, 1, 1))
	_box(wood, Vector3(0, 11.7, 0), Vector3(2.0, 1.4, 14.0), Color(0.95, 0.95, 0.95))
	_box(doors, Vector3(0.6, 5.0, 0), Vector3(0.6, 10.5, 11.0), Color(0.55, 0.42, 0.75))
	var mesh := ArrayMesh.new()
	wood.add_to(mesh, material("pale_bark", 1.6))
	doors.add_to(mesh, material("planks", 1.5))
	return mesh


## The Hornkin's paints: red, blue, ochre, green.
const PAINTS := [Color(0.95, 0.4, 0.32), Color(0.45, 0.62, 0.95), Color(1.0, 0.88, 0.5), Color(0.5, 0.8, 0.55)]


## A Hornkin tipi 3 yards round: a cone of hides with a painted band and a
## door flap, its poles crossing out of the top.
static func _tipi(rng_seed: int, shade: Color) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var hide := Builder.new()
	var poles := Builder.new()
	var radius := 3.0
	var height := 6.2
	_post(hide, Vector3(0, -0.2, 0), Vector3(0, height, 0), radius, 0.2, 12, shade)
	# A painted band round it, a little proud of the hides.
	var band_low := 1.6
	var band_high := 2.3
	var r_low := lerpf(radius, 0.2, (band_low + 0.2) / (height + 0.2)) + 0.04
	var r_high := lerpf(radius, 0.2, (band_high + 0.2) / (height + 0.2)) + 0.04
	_post(hide, Vector3(0, band_low, 0), Vector3(0, band_high, 0), r_low, r_high, 12, PAINTS[rng.randi_range(0, PAINTS.size() - 1)] * shade)
	# The door flap, dark, on the south (+z).
	_box(hide, Vector3(0, 0.75, radius * 0.78), Vector3(1.1, 1.6, 0.5), Color(0.2, 0.15, 0.1))
	var apex := Vector3(0, height + 0.1, 0)
	for i in 6:
		var angle := TAU * i / 6.0 + 0.3
		var foot := Vector3(cos(angle), 0, sin(angle)) * radius * 0.97 + Vector3(0, -0.2, 0)
		var past := apex + (apex - foot).normalized() * 1.2
		_post(poles, foot, past, 0.09, 0.06, 5, Color(0.9, 0.9, 0.9))
	var mesh := ArrayMesh.new()
	hide.add_to(mesh, material("hide", 1.6))
	poles.add_to(mesh, material("bark", 0.8))
	return mesh


## A closed prism along x from -half_length to half_length: a triangle
## across it, eaves at `eave` height `width` apart, its ridge at `ridge`.
static func _prism(builder: Builder, half_length: float, width: float, eave: float, ridge: float, color: Color) -> void:
	builder.begin_piece()
	var inside := Vector3(0, (eave * 2.0 + ridge) / 3.0, 0)
	var ends: Array = []
	for x in [-half_length, half_length]:
		ends.append([Vector3(x, eave, -width / 2.0), Vector3(x, eave, width / 2.0), Vector3(x, ridge, 0)])
	var a: Array = ends[0]
	var b: Array = ends[1]
	builder.tri(a[0], a[1], a[2], inside, color, color, color)
	builder.tri(b[0], b[1], b[2], inside, color, color, color)
	for k in 3:
		var p0: Vector3 = a[k]
		var p1: Vector3 = a[(k + 1) % 3]
		var q0: Vector3 = b[k]
		var q1: Vector3 = b[(k + 1) % 3]
		var lit := color if k != 0 else color.darkened(0.3)
		builder.tri(p0, p1, q1, inside, lit, lit, lit)
		builder.tri(p0, q1, q0, inside, lit, lit, lit)


## A Hornkin longhouse you walk into, 14 by 7 (scaled to its length where it
## stands): hide walls on poles, its doorway in the middle of the south (+z)
## wall, a long hide roof and a rug on the earth floor.
static func _longhouse(rng_seed: int) -> ArrayMesh:
	var hide := Builder.new()
	var roof := Builder.new()
	var poles := Builder.new()
	var half := 7.0
	var depth := 7.0
	var wall := 3.4
	var thick := 0.35
	var walls := Color(0.78, 0.7, 0.6)
	_box(hide, Vector3(0, wall / 2.0 - 0.1, -depth / 2.0), Vector3(half * 2.0, wall + 0.2, thick), walls)
	for side in [-1.0, 1.0]:
		_box(hide, Vector3(side * (half + 0.9) / 2.0, wall / 2.0 - 0.1, depth / 2.0), Vector3(half - 0.9, wall + 0.2, thick), walls)
		_box(hide, Vector3(side * half, wall / 2.0 - 0.1, 0), Vector3(thick, wall + 0.2, depth), walls)
	_box(hide, Vector3(0, (wall + 2.6) / 2.0, depth / 2.0), Vector3(1.8, wall - 2.6, thick), walls)
	_prism(roof, half + 0.6, depth + 1.4, wall - 0.1, wall + 3.0, Color(1.0, 0.95, 0.85))
	for x in [-half, -half / 2.0, 0.0, half / 2.0, half]:
		for z in [-1.0, 1.0]:
			if x == 0.0 and z > 0.0:
				continue
			var at := Vector3(x, -0.2, z * (depth / 2.0 + 0.15))
			_post(poles, at, at + Vector3(0, wall + 0.4, 0), 0.14, 0.12, 6, Color(0.9, 0.9, 0.9))
	# Door posts either side of the doorway.
	for side in [-1.0, 1.0]:
		var at := Vector3(side * 1.0, -0.2, depth / 2.0 + 0.2)
		_post(poles, at, at + Vector3(0, 2.9, 0), 0.13, 0.11, 6, Color(0.9, 0.9, 0.9))
	# A rug on the floor.
	_box(hide, Vector3(0, 0.02, 0), Vector3(half * 1.2, 0.06, depth * 0.55), Color(0.85, 0.42, 0.32))
	var mesh := ArrayMesh.new()
	hide.add_to(mesh, material("hide", 2.0))
	roof.add_to(mesh, material("hide", 1.6))
	poles.add_to(mesh, material("bark", 0.8))
	return mesh


## A great totem 8 yards tall (scaled where it stands): four carved, painted
## blocks, each narrower and turned a little, wings spread near the top, a
## beaked head on top.
static func _totem(rng_seed: int) -> ArrayMesh:
	var wood := Builder.new()
	var block := 1.8
	for i in 4:
		var width := 1.0 - i * 0.08
		_box(wood, Vector3(0, i * block + block / 2.0 - 0.2, 0), Vector3(width, block, width), PAINTS[i % PAINTS.size()], i * 0.3)
		# A carved band where each block meets the next.
		_box(wood, Vector3(0, (i + 1) * block - 0.25, 0), Vector3(width + 0.12, 0.18, width + 0.12), Color(0.6, 0.5, 0.4), i * 0.3)
	_box(wood, Vector3(0, 6.4, 0), Vector3(2.8, 0.35, 0.4), PAINTS[0])
	_box(wood, Vector3(0, 7.4, 0.2), Vector3(0.7, 0.8, 0.9), PAINTS[2])
	_box(wood, Vector3(0, 7.25, 0.75), Vector3(0.25, 0.25, 0.5), PAINTS[0])
	var mesh := ArrayMesh.new()
	wood.add_to(mesh, material("planks", 1.2))
	return mesh


## A small round knot (a coarse ball) at a joint.
static func _knot(builder: Builder, at: Vector3, radius: float, color: Color) -> void:
	builder.begin_piece()
	var sphere := icosphere(0)
	var points: Array = sphere[0]
	for face: Array in sphere[1]:
		builder.tri(at + points[face[0]] * radius, at + points[face[1]] * radius, at + points[face[2]] * radius, at, color, color, color)


## A twig from `from` along `heading`, `length` long and `thick` at its base,
## bending a little and forking `depth` more times.
static func _twig(builder: Builder, rng: RandomNumberGenerator, from: Vector3, heading: Vector3, length: float, thick: float, depth: int) -> void:
	var bend := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.1, 0.15), rng.randf_range(-0.35, 0.35))
	var dir := (heading + bend).normalized()
	var to := from + dir * length
	var grey := Color.WHITE * rng.randf_range(0.75, 0.95)
	_post(builder, from, to, thick, thick * 0.7, 4, grey)
	if depth <= 0:
		return
	# A knot where it forks, so the joint is rounded.
	_knot(builder, to, thick * 0.8, grey)
	var forks := rng.randi_range(1, 3) if depth > 1 else rng.randi_range(1, 2)
	for i in forks:
		var side := dir.cross(Vector3.UP).normalized().rotated(dir, rng.randf() * TAU)
		_twig(builder, rng, to, (dir + side * rng.randf_range(0.4, 0.9)).normalized(), length * rng.randf_range(0.6, 0.8), thick * 0.7, depth - 1)


## A dead tree about 6 yards tall: a bare, leaning trunk forking into
## crooked limbs and twigs, no leaves (the dead lands).
static func _dead_tree(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var wood := Builder.new()
	var height := rng.randf_range(3.2, 4.2)
	var lean := Vector3(rng.randf_range(-0.3, 0.3), 1.0, rng.randf_range(-0.3, 0.3)).normalized()
	var top := Vector3(0, -0.3, 0) + lean * height
	_post(wood, Vector3(0, -0.3, 0), top, 0.34, 0.18, 7, Color(0.85, 0.85, 0.85))
	var limbs := rng.randi_range(3, 5)
	for i in limbs:
		var angle := TAU * i / limbs + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(angle), 0, sin(angle))
		var from := Vector3(0, -0.3, 0) + lean * height * rng.randf_range(0.55, 1.0)
		_twig(wood, rng, from, (out * rng.randf_range(0.7, 1.2) + Vector3.UP).normalized(),
			rng.randf_range(1.2, 1.8), 0.14, 3)
	var mesh := ArrayMesh.new()
	wood.add_to(mesh, material("bark", 1.4))
	return mesh


## A rounded top on a post of `radius`: two short tapering rings and a
## low point.
static func _dome(builder: Builder, at: Vector3, radius: float, sides: int) -> void:
	_post(builder, at, at + Vector3(0, radius * 0.35, 0), radius, radius * 0.75, sides, Color(0.95, 0.95, 0.95))
	_post(builder, at + Vector3(0, radius * 0.35, 0), at + Vector3(0, radius * 0.6, 0), radius * 0.75, radius * 0.35, sides, Color(1, 1, 1))
	_post(builder, at + Vector3(0, radius * 0.6, 0), at + Vector3(0, radius * 0.7, 0), radius * 0.35, 0.02, sides, Color(1, 1, 1))


## A palm about 6 yards tall: a leaning, curving trunk and a crown of long
## drooping fronds, seen from both sides.
static func _palm(rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var bark := Builder.new()
	var fronds := Builder.new()
	fronds.overlay = true
	var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.6, 1.4)
	var height := rng.randf_range(5.0, 6.5)
	var steps := 5
	var last := Vector3(0, -0.3, 0)
	for i in steps:
		var t := float(i + 1) / steps
		var next := Vector3(0, height * t, 0) + lean * t * t
		_post(bark, last, next, lerpf(0.28, 0.16, float(i) / steps), lerpf(0.28, 0.16, t), 6, Color(0.8, 0.8, 0.8).lightened(0.05 * (i % 2)))
		last = next
	var crown := last
	var count := rng.randi_range(7, 9)
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.2, 0.2)
		var out := Vector3(cos(angle), 0, sin(angle))
		var across := out.cross(Vector3.UP).normalized()
		var length := rng.randf_range(2.6, 3.4)
		var mid := crown + out * length * 0.5 + Vector3(0, 0.45, 0)
		var tip := crown + out * length + Vector3(0, -rng.randf_range(0.9, 1.5), 0)
		var width := rng.randf_range(0.45, 0.6)
		var lit := Color.WHITE * rng.randf_range(0.8, 1.0)
		for flip in [1.0, -1.0]:
			var under := crown + Vector3(0, -flip * 2.0, 0)
			fronds.tri(crown, mid + across * width, mid - across * width, under, lit, lit, lit)
			fronds.tri(mid + across * width, tip, mid - across * width, under, lit, lit * 0.9, lit)
	var mesh := ArrayMesh.new()
	bark.add_to(mesh, material("bark", 1.6))
	fronds.add_to(mesh, material("leaves", 1.4, 0.2, 3.0))
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
