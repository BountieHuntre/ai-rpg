extends SceneTree
## Bakes the caves (Caves.layout's CSG parts) into one mesh each: the
## hollows joined by a CSG union, the rock left standing in them
## (stalagmites, stalactites, pillars) cut out, and the whole turned inward,
## so it is the cave's walls, ceilings and floor seen from inside, with no
## seams. Flat-shaded, saved to Caves.BAKED_PATH. Run it after changing Caves, then re-import:
## <console exe> --headless --path C:/ai-rpg -s res://tools/models/nature/bake_caves.gd
## ("-- --only=den_0,lair_2" bakes just those).

const CavesScript := preload("res://scenes/levels/caves.gd")


func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/models/caves"))
	var only: Array = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = Array(arg.trim_prefix("--only=").split(","))
	for kind: String in CavesScript.VARIANTS:
		for variant in int(CavesScript.VARIANTS[kind]):
			if only.is_empty() or "%s_%d" % [kind, variant] in only:
				await _bake(kind, variant)
	quit()


func _bake(kind: String, variant: int) -> void:
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
		return
	# Flat shading: every face its own normal.
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
	surface = SurfaceTool.new()
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
