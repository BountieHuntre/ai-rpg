extends Node
## Root scene: wires the camera, player and HUD together, keeps the low-res game
## view fitted to the window, and handles global input.

const RESTART_DELAY := 3.0

## The game renders at whole-number pixel scales, showing at least this many
## rows. Raise it for smaller pixels: at 810p, 270 gives 3x, 405 gives 2x.
@export var min_game_height := 270

@onready var _game_view: SubViewportContainer = $GameView
@onready var _player: Player = $GameView/GameViewport/Player
@onready var _camera: Camera3D = $GameView/GameViewport/GameCamera
@onready var _hud: CombatHud = $CombatHud


func _ready() -> void:
	_camera.target = _player
	_camera.snap_to_target()
	if _camera is OrbitCamera:
		_camera.clicked.connect(_on_camera_clicked)
	get_viewport().size_changed.connect(_fit_game_view)
	_fit_game_view()
	_hud.setup(_player, _camera, _game_view)
	_player.combatant.died.connect(_on_player_died)


## Picks the largest whole pixel scale that fits, then rounds the view up so it
## always covers the window instead of leaving a gap at the edges.
func _fit_game_view() -> void:
	var window := get_viewport().get_visible_rect().size
	var pixel_scale := maxi(floori(window.y / min_game_height), 1)
	_game_view.stretch_shrink = pixel_scale
	_game_view.size = (window / pixel_scale).ceil() * pixel_scale


func _on_camera_clicked(window_position: Vector2, button: MouseButton) -> void:
	_player.targeting.on_camera_clicked(window_position / _game_view.stretch_shrink, button)


func _on_player_died() -> void:
	get_tree().create_timer(RESTART_DELAY).timeout.connect(get_tree().reload_current_scene)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and _camera is OrbitCamera:
		_camera.handle_mouse(event)
	elif event.is_action_pressed("pause"):
		# Esc clears the target first, then quits until a real pause menu exists.
		if _player.targeting.target:
			_player.targeting.set_target(null)
		else:
			get_tree().quit()
