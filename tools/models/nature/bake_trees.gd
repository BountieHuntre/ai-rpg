extends SceneTree
## Bakes the trees (Nature.build_tree: pines, snowy pines, oaks, dead trees,
## palms) into one solid mesh each: every closed part (trunk, boughs, needle
## tiers, leaf clumps, limbs) joined by a CSG union, so a tree has no seams
## or faces inside it; its shading (the builders' vertex colours) taken from
## the nearest point of the parts it was built from; overlays (snow, palm
## fronds) laid on as they are. Run it after changing a tree, then re-import:
## <console exe> --headless --path C:/ai-rpg -s res://tools/models/nature/bake_trees.gd
## ("-- --only=pine,oak" bakes just those kinds; the herbs and ore of
## gathering nodes are "herb_<name>" and "ore_<name>", Nature.node_kinds).

const NatureScript := preload("res://scenes/levels/nature.gd")


func _initialize() -> void:
	await process_frame
	var kinds: Array = NatureScript.TREE_SEEDS.keys() + NatureScript.node_kinds()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			kinds = Array(arg.trim_prefix("--only=").split(","))
	for kind: String in kinds:
		for variant in NatureScript.variants_of(kind):
			await _bake(kind, variant)
	quit()


func _bake(kind: String, variant: int) -> void:
	NatureScript.recording = true
	NatureScript.recorded.clear()
	NatureScript.build_tree(kind, NatureScript.seed_of(kind) + variant)
	NatureScript.recording = false
	var parts: Array = NatureScript.recorded.duplicate()
	var union := CSGCombiner3D.new()
	var overlays: Array = []
	for part: Array in parts:
		var builder = part[0]
		if builder.overlay:
			overlays.append(part)
			continue
		var starts: PackedInt32Array = builder.starts
		for i in starts.size():
			var from := starts[i]
			var to: int = starts[i + 1] if i + 1 < starts.size() else builder.points.size()
			if to - from < 9:
				continue
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for k in range(from, to):
				surface.add_vertex(builder.points[k])
			surface.index()
			var shape := CSGMesh3D.new()
			shape.mesh = surface.commit()
			shape.material = part[1]
			union.add_child(shape)
	root.add_child(union)
	await process_frame
	await process_frame
	var joined := union.bake_static_mesh()
	union.queue_free()
	if joined == null or joined.get_surface_count() == 0:
		push_error("%s %d didn't bake." % [kind, variant])
		return
	var mesh := ArrayMesh.new()
	for i in joined.get_surface_count():
		var made: ShaderMaterial = joined.surface_get_material(i)
		var arrays := joined.surface_get_arrays(i)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# Each point's shading from the nearest point of the parts drawn
		# with the same material.
		var source_points := PackedVector3Array()
		var source_colors := PackedColorArray()
		for part: Array in parts:
			if part[1] == made and not part[0].overlay:
				source_points.append_array(part[0].points)
				source_colors.append_array(part[0].colors)
		var colors := PackedColorArray()
		colors.resize(points.size())
		for k in points.size():
			var best := INF
			var color := Color.WHITE
			for j in source_points.size():
				var d := points[k].distance_squared_to(source_points[j])
				if d < best:
					best = d
					color = source_colors[j]
			colors[k] = color
		arrays[Mesh.ARRAY_COLOR] = colors
		for slot in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TANGENT]:
			arrays[slot] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, NatureScript.material_name(made))
	for part: Array in overlays:
		var builder = part[0]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = builder.points
		arrays[Mesh.ARRAY_NORMAL] = builder.normals
		arrays[Mesh.ARRAY_COLOR] = builder.colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_name(mesh.get_surface_count() - 1, NatureScript.material_name(part[1]))
	var path: String = NatureScript.TREE_PATH % [kind, variant]
	ResourceSaver.save(mesh, path)
	print("Baked %s: %d surfaces" % [path, mesh.get_surface_count()])
