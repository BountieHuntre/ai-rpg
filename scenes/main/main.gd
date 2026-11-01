extends Node3D
## Root scene: wires the camera to the player and handles global input.

@onready var _player: Player = $Player
@onready var _camera: GameCamera = $GameCamera


func _ready() -> void:
	_camera.target = _player
	_camera.global_position = _camera.global_basis.z * _camera.distance + _player.global_position


func _unhandled_input(event: InputEvent) -> void:
	# Quits until a real pause menu exists.
	if event.is_action_pressed("pause"):
		get_tree().quit()
