extends SceneTree
## Renders every icon the game uses (Icons.all_keys) into assets/icons/ as
## 128 by 128 PNGs: IconPainter draws each at 512 by 512 (its 256 space
## doubled) with 2D MSAA, and the picture is shrunk with Lanczos, which
## smooths its edges. Run with a window (it renders):
##   <console exe> --path C:/ai-rpg -s res://tools/icons/bake_icons.gd
## then re-import. Pass "-- --sheet=<png>" to also write a contact sheet of
## them all, and "-- --only=key,key" to bake just those.

const SIZE := 128
const RENDER := 512


func _initialize() -> void:
	await process_frame
	# Scripts run with -s load before the autoloads, so the game's classes are
	# loaded now, once they're there.
	var icons: GDScript = load("res://ui/icons.gd")
	var painter_script: GDScript = load("res://tools/icons/icon_painter.gd")
	var args := OS.get_cmdline_user_args()
	var keys: Array[String] = []
	var sheet_path := ""
	for arg in args:
		if arg.begins_with("--only="):
			keys.assign(arg.trim_prefix("--only=").split(","))
		elif arg.begins_with("--sheet="):
			sheet_path = arg.trim_prefix("--sheet=")
	if keys.is_empty():
		keys = icons.all_keys()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(icons.DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RENDER, RENDER)
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await process_frame
	viewport.canvas_transform = Transform2D(0.0, Vector2.ONE * RENDER / 256.0, 0.0, Vector2.ZERO)
	var painter: Node2D = painter_script.new()
	viewport.add_child(painter)
	var images: Array[Image] = []
	for key in keys:
		painter.key = key
		painter.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		image.save_png(ProjectSettings.globalize_path(icons.DIR + key + ".png"))
		images.append(image)
	print("Baked %d icons into %s" % [keys.size(), icons.DIR])
	if not sheet_path.is_empty():
		var columns := 16
		var cell := 72
		var rows := ceili(keys.size() / float(columns))
		var sheet := Image.create(columns * cell, rows * cell, false, Image.FORMAT_RGBA8)
		sheet.fill(Color(0.17, 0.2, 0.15))
		for i in images.size():
			var small := images[i].duplicate() as Image
			small.convert(Image.FORMAT_RGBA8)
			small.resize(64, 64, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(small, Rect2i(0, 0, 64, 64), Vector2i((i % columns) * cell + 4, (i / columns) * cell + 4))
		sheet.save_png(sheet_path)
		print("Contact sheet: ", sheet_path)
	quit()
