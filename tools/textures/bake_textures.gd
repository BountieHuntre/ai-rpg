extends SceneTree
## Bakes TexturePainter's textures into assets/textures/ as PNGs:
##   <console exe> --headless --path C:/ai-rpg -s res://tools/textures/bake_textures.gd
## then re-import. "-- --only=key,key" bakes just those; "-- --sheet=<png>"
## also writes them side by side, each tiled 2 by 2, for looking over.

const DIR := "res://assets/textures/"


func _initialize() -> void:
	var painter: GDScript = load("res://tools/textures/texture_painter.gd")
	var keys: Array = painter.KEYS
	var sheet_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			keys = Array(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--sheet="):
			sheet_path = arg.trim_prefix("--sheet=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var images: Array[Image] = []
	for key: String in keys:
		var image: Image = painter.paint(key)
		image.save_png(ProjectSettings.globalize_path(DIR + key + ".png"))
		images.append(image)
	print("Baked %d textures into %s" % [keys.size(), DIR])
	if not sheet_path.is_empty():
		var cell := 256
		var columns := 5
		var rows := ceili(images.size() / float(columns))
		var sheet := Image.create(columns * cell, rows * cell, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.55, 0.7, 0.85))
		for i in images.size():
			var tile := images[i].duplicate() as Image
			tile.resize(cell / 2, cell / 2, Image.INTERPOLATE_NEAREST)
			for t in 4:
				sheet.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i((i % columns) * cell + (t % 2) * cell / 2, (i / columns) * cell + (t / 2) * cell / 2))
		sheet.save_png(sheet_path)
	quit()
