extends SceneTree
## Bakes the caves (Caves.layout's CSG parts) into one mesh each: the
## hollows joined by a CSG union, the rock left standing in them
## (stalagmites, stalactites, pillars) cut out, and the whole turned inward,
## so it is the cave's walls, ceilings and floor seen from inside, with no
## seams, then cleaned in Blender (clean_caves.py: the CSG's slivers and scraps
## collapsed, smoothed a touch, kept sealed). Flat-shaded, saved to
## Caves.BAKED_PATH. Run it after changing Caves, then re-import:
## <console exe> --headless --path C:/ai-rpg -s res://tools/models/nature/bake_caves.gd
## ("-- --only=den_0,lair_2" bakes just those).

const CavesScript := preload("res://scenes/levels/caves.gd")


## Blender, which cleans each cave's mesh (tools/models/nature/clean_caves.py:
## welds, collapses the CSG's slivers and scraps, smooths a touch, keeps it
## sealed); without it the caves are saved as the CSG made them.
const BLENDER := "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe"
const RAW_DIR := "res://build/caves_raw"


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/caves"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAW_DIR))
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
	var baked: Array = []
	for kind: String in CavesScript.VARIANTS:
		for variant in int(CavesScript.VARIANTS[kind]):
			if only.is_empty() or "%s_%d" % [kind, variant] in only:
				var points: PackedVector3Array = await _bake(kind, variant)
				if not points.is_empty():
					baked.append([kind, variant, points])
	# Each written out raw, cleaned in Blender in one run, and read back.
	var pairs: PackedStringArray = []
	for cave: Array in baked:
		var raw := ProjectSettings.globalize_path(RAW_DIR.path_join("%s_%d.obj" % [cave[0], cave[1]]))
		_write_obj(raw, cave[2])
		pairs.append_array([raw, raw.trim_suffix(".obj") + "_clean.obj"])
	var cleaned := FileAccess.file_exists(BLENDER)
	if cleaned:
		var output: Array = []
		OS.execute(BLENDER, PackedStringArray(["--background", "--factory-startup", "--python",
			ProjectSettings.globalize_path("res://tools/models/nature/clean_caves.py"), "--"]) + pairs, output, true)
		for line in "
".join(PackedStringArray(output)).split("
"):
			if line.begins_with("CLEANED") or "skipped" in line:
				print(line.get_slice("caves_raw/", 1) if "caves_raw/" in line else line)
	else:
		push_warning("No Blender at %s: the caves are saved uncleaned." % BLENDER)
	for i in baked.size():
		var cave: Array = baked[i]
		var points: PackedVector3Array = cave[2]
		if cleaned and FileAccess.file_exists(pairs[i * 2 + 1]):
			points = _read_obj(pairs[i * 2 + 1])
		_save(cave[0], cave[1], points)
	quit()


## A cave's hollows joined and turned inward, as triangles (empty if the CSG
## made nothing).
func _bake(kind: String, variant: int) -> PackedVector3Array:
	var cave: Dictionary = CavesScript.layout(kind, variant, true)
	var root_csg := CSGCombiner3D.new()
	# The hollows, then the rock standing in them cut out.
	for wanted: String in ["add", "cut"]:
		for part: Array in cave.parts:
			if part[1] != wanted:
				continue
			var shape := CSGMesh3D.new()
			shape.mesh = part[0]
			shape.operation = CSGShape3D.OPERATION_SUBTRACTION if wanted == "cut" else CSGShape3D.OPERATION_UNION
			root_csg.add_child(shape)
	root.add_child(root_csg)
	await process_frame
	await process_frame
	var joined := root_csg.bake_static_mesh()
	root_csg.queue_free()
	if joined == null or joined.get_surface_count() == 0:
		push_error("cave %s %d didn't bake." % [kind, variant])
		return PackedVector3Array()
	var surface := SurfaceTool.new()
	surface.create_from(joined, 0)
	surface.deindex()
	# Turned inward: seen from inside the hollows.
	var arrays := surface.commit_to_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for t in range(0, points.size(), 3):
		var swap := points[t + 1]
		points[t + 1] = points[t + 2]
		points[t + 2] = swap
	return points


## Saves a cave's triangles flat-shaded to Caves.BAKED_PATH.
func _save(kind: String, variant: int, points: PackedVector3Array) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat: each face its own normal (shared points aren't averaged, which
	# turned the feet of walls toward the floor and stretched their texture).
	surface.set_smooth_group(-1)
	for point in points:
		surface.add_vertex(point)
	surface.generate_normals()
	var mesh := surface.commit()
	var path: String = CavesScript.BAKED_PATH % [kind, variant]
	ResourceSaver.save(mesh, path)
	print("Baked %s: %d triangles" % [path, mesh.surface_get_array_len(0) / 3])


func _write_obj(path: String, points: PackedVector3Array) -> void:
	var lines := PackedStringArray()
	for p in points:
		lines.append("v %f %f %f" % [p.x, p.y, p.z])
	for t in range(0, points.size(), 3):
		lines.append("f %d %d %d" % [t + 1, t + 2, t + 3])
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("
".join(lines))
	file.close()


## An OBJ's triangles, in order.
func _read_obj(path: String) -> PackedVector3Array:
	var verts: Array[Vector3] = []
	var points := PackedVector3Array()
	for line in FileAccess.get_file_as_string(path).split("
"):
		var parts := line.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		if parts[0] == "v":
			verts.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
		elif parts[0] == "f":
			for k in range(2, parts.size() - 1):
				for index in [parts[1], parts[k], parts[k + 1]]:
					points.append(verts[int(String(index).get_slice("/", 0)) - 1])
	return points
