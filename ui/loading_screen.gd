class_name LoadingScreen
extends CanvasLayer
## Classic-style loading screen shown on Enter World: a landscape, a tip and
## a progress bar. It loads the game scene on a thread, swaps to it, and
## stays on top until the world has drawn a few frames, then fades out.
## Sizes are in HUD units (1/270 of the window height).

const FONT_SIZE := 8
const BAR_SIZE := Vector2(240, 9)
## Share of the bar for loading files; building the world fills the rest.
const LOAD_SHARE := 0.6
## Frames to keep covering the new world while it warms up (shaders, first draw).
const SETTLE_FRAMES := 8
const FADE_TIME := 0.35
const TIPS := [
	"Right-click a creature to attack it, or a townsperson to speak with them.",
	"Creatures shown in yellow won't attack unless provoked.",
	"Sit down (X) before eating or drinking.",
	"Hugh Stannard at the priory will mend your worn gear, for a price.",
	"Shift and right-click a corpse to take everything at once.",
	"Press B for your bags, C for your character and P for your spellbook.",
	"Creatures far below your level give no experience.",
	"Drag an item out of your bags to destroy it.",
]

var _root := Control.new()
var _fill := ColorRect.new()
var _status := Label.new()
var _ui_scale := 1.0
var _progress := 0.0


## Shows the screen over everything and starts loading `scene_path`.
static func enter(tree: SceneTree, scene_path: String) -> void:
	var screen := LoadingScreen.new()
	screen.layer = 200
	tree.root.add_child(screen)
	screen._build()
	screen._load.call_deferred(scene_path)


func _build() -> void:
	var window := get_viewport().get_visible_rect().size
	_ui_scale = Settings.hud_scale(window.y)
	# The tip and bar keep their place at the bottom whatever the UI Scale.
	var bottom := window.y / _ui_scale - 270.0
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.1, 0.16, 0.2))
	gradient.set_color(1, Color(0.06, 0.1, 0.07))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(sky)
	_draw_hills(window)

	var tip := _label(TIPS[randi() % TIPS.size()] if Settings.get_value("loading_tips") else "", Color(0.9, 0.88, 0.8), FONT_SIZE)
	tip.size.x = window.x
	tip.position = Vector2(0, (205 + bottom) * _ui_scale)

	var bar_size := BAR_SIZE * _ui_scale
	var frame := ColorRect.new()
	frame.color = Color(0.55, 0.5, 0.35)
	frame.size = bar_size + Vector2.ONE * 2 * maxf(_ui_scale, 1.0)
	frame.position = Vector2((window.x - frame.size.x) / 2, (222 + bottom) * _ui_scale)
	_root.add_child(frame)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.04, 0.03)
	back.size = bar_size
	back.position = Vector2.ONE * maxf(_ui_scale, 1.0)
	frame.add_child(back)
	_fill.color = Color(0.75, 0.55, 0.1)
	_fill.size = Vector2(0, bar_size.y)
	back.add_child(_fill)
	_status = _label("Loading", Color(0.75, 0.75, 0.7), FONT_SIZE - 2)
	_status.size.x = window.x
	_status.position = Vector2(0, (234 + bottom) * _ui_scale)


## Rolling hills and a few pines in silhouette, standing in for zone art.
func _draw_hills(window: Vector2) -> void:
	var layers := [[0.62, 0.1, Color(0.13, 0.2, 0.18)], [0.7, 0.07, Color(0.09, 0.15, 0.11)], [0.8, 0.05, Color(0.06, 0.1, 0.07)]]
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for i in layers.size():
		var base: float = layers[i][0] * window.y
		var height: float = layers[i][1] * window.y
		var points := PackedVector2Array([Vector2(0, window.y)])
		var steps := 48
		for step in steps + 1:
			var x := window.x * step / steps
			var y := base - height * (0.5 + 0.5 * sin(x / window.x * TAU * (1.3 + i * 0.7) + i * 2.0))
			points.append(Vector2(x, y))
			# Pines along the ridge.
			if random.randf() < 0.35:
				var tree_height := height * random.randf_range(0.4, 0.8)
				var tree := Polygon2D.new()
				tree.polygon = PackedVector2Array([Vector2(x - tree_height * 0.25, y + 2), Vector2(x, y - tree_height), Vector2(x + tree_height * 0.25, y + 2)])
				tree.color = layers[i][2]
				_root.add_child(tree)
		points.append(Vector2(window.x, window.y))
		var hill := Polygon2D.new()
		hill.polygon = points
		hill.color = layers[i][2]
		_root.add_child(hill)


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
	_root.add_child(label)
	return label


func _set_progress(value: float) -> void:
	_progress = maxf(_progress, value)
	_fill.size.x = BAR_SIZE.x * _ui_scale * clampf(_progress, 0.0, 1.0)


func _load(scene_path: String) -> void:
	var tree := get_tree()
	ResourceLoader.load_threaded_request(scene_path)
	var progress := []
	while ResourceLoader.load_threaded_get_status(scene_path, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_set_progress(float(progress[0]) * LOAD_SHARE)
		await tree.process_frame
	var scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if scene == null:
		_status.text = "Couldn't load the world."
		return
	_set_progress(LOAD_SHARE)
	_status.text = "Entering world"
	# Two frames so the bar draws before building the world blocks a moment.
	await tree.process_frame
	await tree.process_frame
	tree.change_scene_to_packed(scene)
	await tree.process_frame
	_set_progress(0.9)
	for i in SETTLE_FRAMES:
		await tree.process_frame
	_set_progress(1.0)
	await tree.process_frame
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := create_tween()
	fade.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	await fade.finished
	queue_free()
