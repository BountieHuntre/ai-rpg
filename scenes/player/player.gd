class_name Player
extends CharacterBody3D
## Placeholder character with camera-relative movement.

@export var move_speed := 5.0
@export var acceleration := 40.0
@export var friction := 50.0
@export var turn_speed := 14.0
@export var gravity := 25.0

@onready var _visual: Node3D = $Visual


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := _camera_relative(input)

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if direction else friction
	horizontal = horizontal.move_toward(direction * move_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

	if direction:
		var facing := atan2(-direction.x, -direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, 1.0 - exp(-turn_speed * delta))


func _camera_relative(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return Vector3(input.x, 0.0, input.y)
	var right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	var back := Vector3(camera.global_basis.z.x, 0.0, camera.global_basis.z.z).normalized()
	return right * input.x + back * input.y
