class_name GameCamera
extends Camera3D
## Fixed-angle orthographic camera that smoothly follows a target.

@export var target: Node3D
@export var distance := 30.0
@export var follow_speed := 8.0


func _ready() -> void:
	if target:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if target:
		var weight := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(_desired_position(), weight)


func _desired_position() -> Vector3:
	return target.global_position + global_basis.z * distance
