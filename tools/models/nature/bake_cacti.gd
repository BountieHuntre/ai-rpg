extends SceneTree
## Bakes the cacti (Nature.cactus_parts) into one solid mesh each: the trunk
## and arms joined by a CSG union, so a cactus has no seams or faces inside
## it. Run it after changing cactus_parts, then re-import:
## <console exe> --headless --path C:/ai-rpg -s res://tools/models/nature/bake_cacti.gd

const NatureScript := preload("res://scenes/levels/nature.gd")


func _initialize() -> void:
	await process_frame
	for variant in NatureScript.CACTUS_VARIANTS:
		var union := CSGCombiner3D.new()
		for part: ArrayMesh in NatureScript.cactus_parts(NatureScript.CACTUS_SEED + variant):
			var shape := CSGMesh3D.new()
			shape.mesh = part
			union.add_child(shape)
		root.add_child(union)
		await process_frame
		await process_frame
		var mesh := union.bake_static_mesh()
		if mesh == null or mesh.get_surface_count() == 0:
			push_error("Cactus %d didn't bake." % variant)
		else:
			var path: String = NatureScript.CACTUS_PATH % variant
			ResourceSaver.save(mesh, path)
			print("Baked %s: %d vertices" % [path, mesh.surface_get_array_len(0)])
		union.queue_free()
	quit()
