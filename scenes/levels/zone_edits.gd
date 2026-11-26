class_name ZoneEdits
extends RefCounted
## Hand edits to a zone, kept as layers over what its code builds, so the zone
## is built from code every time and the edits laid back over it: changing
## the code (a new hill, a moved camp) never undoes them. Made in Blender
## (`tools/zones/zone_edit.py`, opened by the `editzone` command) and kept in
## `data/zone_edits/<zone>/`:
##   - heights.json and heights.bin: how far the ground is raised or lowered
##     at each point of a grid in world yards (Zone.carve_passes adds it, so
##     everything standing on the ground follows it);
##   - caves.json: each cave's vertices moved (tunnels, chambers, mouth and
##     rim), by where each lies in the cave's own yards;
##   - additions.json: pieces of mesh added to the world (overhangs, arches,
##     ledges, rocks), drawn as rock or, named "ground", as the ground;
##   - cuts.json: closed shapes the ground is cut away inside;
##   - rocks.json: the rocks round each cave's mouth moved, turned, scaled
##     or taken away, by their id (Zone._frame_mouth: the cave's key and the
##     rock's place in the order they're made).
## Zone borders stay as built (the Blender side keeps their height edits at
## nothing), so neighbouring zones still meet exactly.

## Where a zone's edits are kept, and where it's exported for Blender.
const EDITS_DIR := "res://data/zone_edits"
const EXPORT_DIR := "res://build/zone_edit"
## Blender, to open a zone in (the `editzone` command).
const BLENDER := "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe"
## A moved cave vertex is found again within this many yards of where the
## code puts it (two decimals of its position in the cave's own yards).
static var CAVE_KEY_PLACES := 2

var zone_key := ""
## The height grid: origin (x, z), step, columns and rows, and the heights.
var height_origin := Vector2.ZERO
var height_step := 2.0
var height_columns := 0
var height_rows := 0
var heights := PackedFloat32Array()
## By cave key: { "x,y,z": Vector3 offset } in the cave's own yards.
var cave_offsets := {}
## By rock id: { deleted, faces (its mesh as left in Blender, world yards),
## or from older saves offset: Vector3 and basis: Basis (turned and scaled
## about its middle) }.
var rocks := {}
## Added pieces and cut shapes: { name, material, faces: PackedVector3Array }.
var additions: Array = []
var cuts: Array = []
## Each cut's box, for a quick test before the full one.
var _cut_boxes: Array = []


## A zone's key for its edit folder: its name in snake case.
static func key_for(zone_name: String) -> String:
	return zone_name.to_snake_case().replace("'", "")


## A zone's edits, or null when it has none.
static func load_for(zone_name: String) -> ZoneEdits:
	var key := key_for(zone_name)
	var dir := EDITS_DIR.path_join(key)
	if not DirAccess.dir_exists_absolute(dir):
		return null
	var edits := ZoneEdits.new()
	edits.zone_key = key
	var meta: Variant = _read_json(dir.path_join("heights.json"))
	if meta is Dictionary and FileAccess.file_exists(dir.path_join("heights.bin")):
		edits.height_origin = Vector2(float(meta.origin[0]), float(meta.origin[1]))
		edits.height_step = float(meta.step)
		edits.height_columns = int(meta.columns)
		edits.height_rows = int(meta.rows)
		edits.heights = FileAccess.get_file_as_bytes(dir.path_join("heights.bin")).to_float32_array()
		if edits.heights.size() != edits.height_columns * edits.height_rows:
			push_warning("Zone edits: %s heights don't fit their grid; left out." % key)
			edits.heights = PackedFloat32Array()
	var caves = _read_json(dir.path_join("caves.json"))
	if caves is Dictionary:
		for cave_key: String in caves:
			var moved := {}
			for spot: String in caves[cave_key]:
				var offset: Array = caves[cave_key][spot]
				moved[spot] = Vector3(offset[0], offset[1], offset[2])
			edits.cave_offsets[cave_key] = moved
	var rock_edits = _read_json(dir.path_join("rocks.json"))
	if rock_edits is Dictionary:
		for id: String in rock_edits:
			var edit: Dictionary = rock_edits[id]
			var b: Array = edit.get("basis", [1, 0, 0, 0, 1, 0, 0, 0, 1])
			var o: Array = edit.get("offset", [0, 0, 0])
			edits.rocks[id] = {
				"deleted": bool(edit.get("deleted", false)), "offset": Vector3(o[0], o[1], o[2]),
				"basis": Basis(Vector3(b[0], b[1], b[2]), Vector3(b[3], b[4], b[5]), Vector3(b[6], b[7], b[8])),
			}
			# Saved as it was left in Blender: its mesh in world yards.
			if edit.has("faces"):
				var flat: Array = edit.faces
				var faces := PackedVector3Array()
				for i in range(0, flat.size() - 2, 3):
					faces.append(Vector3(flat[i], flat[i + 1], flat[i + 2]))
				edits.rocks[id]["faces"] = faces
	edits.additions = _read_pieces(dir.path_join("additions.json"))
	edits.cuts = _read_pieces(dir.path_join("cuts.json"))
	for cut: Dictionary in edits.cuts:
		var faces: PackedVector3Array = cut.faces
		var box := AABB(faces[0], Vector3.ZERO) if not faces.is_empty() else AABB()
		for point in faces:
			box = box.expand(point)
		edits._cut_boxes.append(box)
	return edits


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _read_pieces(path: String) -> Array:
	var read = _read_json(path)
	var pieces: Array = []
	if not read is Dictionary:
		return pieces
	for piece: Dictionary in read.get("pieces", []):
		var points: Array = piece.vertices
		var faces := PackedVector3Array()
		for index in piece.indices:
			var i := int(index) * 3
			faces.append(Vector3(points[i], points[i + 1], points[i + 2]))
		pieces.append({ "name": str(piece.get("name", "")), "material": str(piece.get("material", "")), "faces": faces })
	return pieces


## How far the ground is raised (or lowered) at a point, between the grid's
## points; nothing off the grid.
func height(x: float, z: float) -> float:
	if heights.is_empty():
		return 0.0
	var gx := (x - height_origin.x) / height_step
	var gz := (z - height_origin.y) / height_step
	if gx < 0.0 or gz < 0.0 or gx > height_columns - 1 or gz > height_rows - 1:
		return 0.0
	var c := mini(floori(gx), height_columns - 2)
	var r := mini(floori(gz), height_rows - 2)
	var fx := gx - c
	var fz := gz - r
	var i := r * height_columns + c
	var top := lerpf(heights[i], heights[i + 1], fx)
	var bottom := lerpf(heights[i + height_columns], heights[i + height_columns + 1], fx)
	return lerpf(top, bottom, fz)


## Whether a point is inside any cut shape (a ray straight up crosses its
## faces an odd number of times).
func cut(point: Vector3) -> bool:
	for k in cuts.size():
		var box: AABB = _cut_boxes[k]
		if not box.grow(0.01).has_point(point):
			continue
		var faces: PackedVector3Array = cuts[k].faces
		var crossings := 0
		for t in range(0, faces.size(), 3):
			if Geometry3D.ray_intersects_triangle(point, Vector3.UP, faces[t], faces[t + 1], faces[t + 2]) != null:
				crossings += 1
		if crossings % 2 == 1:
			return true
	return false


## A cave's key: its name, or for an unnamed one its kind and where its mouth
## is.
static func cave_key(cave: Dictionary) -> String:
	var name := str(cave.get("name", ""))
	if name != "":
		return name.to_snake_case().replace("'", "")
	var mouth: Vector2 = cave.mouth
	return "%s_%d_%d" % [cave.kind, roundi(mouth.x), roundi(mouth.y)]


## Where a vertex lies in a cave's own yards, as its key.
static func spot_key(local: Vector3) -> String:
	var f := "%." + str(CAVE_KEY_PLACES) + "f"
	return (f + "," + f + "," + f) % [local.x, local.y, local.z]


## A cave's faces with its moved vertices moved (world yards in and out).
func move_cave_faces(cave: Dictionary, faces: PackedVector3Array) -> PackedVector3Array:
	var moved: Dictionary = cave_offsets.get(cave_key(cave), {})
	if moved.is_empty():
		return faces
	var to_local: Transform3D = cave.to_local
	var to_world := to_local.affine_inverse()
	var out := faces.duplicate()
	for i in out.size():
		var local := to_local * out[i]
		var key := spot_key(local)
		if moved.has(key):
			out[i] = to_world * (local + (moved[key] as Vector3))
	return out


# ---------------------------------------------------------------- export

## Writes a zone out for Blender (EXPORT_DIR/<zone>/): its ground grid's
## heights as the code makes them and as edited, which points are locked
## (the border), and each cave's faces as built (with their place in the
## cave's own yards). The Blender script reads these and the edit layers.
static func export(zone: Zone) -> String:
	var key := key_for(zone.zone_name)
	var out := ProjectSettings.globalize_path(EXPORT_DIR.path_join(key))
	DirAccess.make_dir_recursive_absolute(out)
	var ground: Terrain = zone._ground
	if ground == null:
		return "%s has no ground built." % zone.zone_name
	var columns := ground._cells + 1
	var origin := ground._origin
	var step := ground._step
	var base := PackedFloat32Array()
	base.resize(columns * columns)
	zone._edits_off = true
	for r in columns:
		for c in columns:
			base[r * columns + c] = zone.height_at(origin.x + c * step, origin.y + r * step)
	zone._edits_off = false
	var file := FileAccess.open(out.path_join("base_heights.bin"), FileAccess.WRITE)
	file.store_buffer(base.to_byte_array())
	file.close()
	var caves: Array = []
	for cave: Dictionary in zone.caves:
		if not cave.has("built_faces"):
			continue
		var faces: PackedVector3Array = cave.built_faces
		var to_local: Transform3D = cave.to_local
		var local := PackedFloat32Array()
		for point in faces:
			var l := to_local * point
			local.append_array([l.x, l.y, l.z])
		var name := cave_key(cave)
		var cave_file := FileAccess.open(out.path_join("cave_%s.bin" % name), FileAccess.WRITE)
		cave_file.store_buffer(local.to_byte_array())
		cave_file.close()
		var world := to_local.affine_inverse()
		caves.append({ "key": name, "file": "cave_%s.bin" % name, "to_world": [
			world.basis.x.x, world.basis.x.y, world.basis.x.z, world.basis.y.x, world.basis.y.y, world.basis.y.z,
			world.basis.z.x, world.basis.z.y, world.basis.z.z, world.origin.x, world.origin.y, world.origin.z] })
	# The rocks round the mouths: each one's middle, and its shape about it.
	var rocks: Array = []
	for cave: Dictionary in zone.caves:
		for rock: Dictionary in cave.get("rocks", []):
			var center: Vector3 = rock.center
			var faces: PackedVector3Array = (rock.mesh as Mesh).get_faces()
			var points: Array = []
			for point in faces:
				var l := point - center
				points.append_array([l.x, l.y, l.z])
			rocks.append({ "id": rock.id, "center": [center.x, center.y, center.z], "triangles": points })
	var rock_file := FileAccess.open(out.path_join("rocks.json"), FileAccess.WRITE)
	rock_file.store_string(JSON.stringify(rocks))
	rock_file.close()
	var meta := {
		"zone": zone.zone_name, "key": key, "origin": [origin.x, origin.y], "step": step,
		"columns": columns, "rows": columns, "edits": ProjectSettings.globalize_path(EDITS_DIR.path_join(key)),
		"caves": caves, "key_places": CAVE_KEY_PLACES,
	}
	var meta_file := FileAccess.open(out.path_join("zone.json"), FileAccess.WRITE)
	meta_file.store_string(JSON.stringify(meta, "\t"))
	meta_file.close()
	return out
