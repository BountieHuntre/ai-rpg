class_name Player
extends CharacterBody3D
## The player's character. Uses WoW-style tank controls with an OrbitCamera and
## camera-relative movement with any other camera.

@export var move_speed := 5.0
@export var backpedal_multiplier := 0.6
@export var acceleration := 40.0
@export var friction := 50.0
@export var turn_speed := 14.0
@export var keyboard_turn_speed := 3.0
@export var gravity := 25.0

## Yaw in radians. Zero faces -Z.
var facing := 0.0

@onready var combatant: Combatant = $Combatant
@onready var progression: Progression = $Progression
@onready var stats: CharacterStats = $CharacterStats
@onready var targeting: Targeting = $Targeting
@onready var caster: AbilityCaster = $AbilityCaster
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	combatant.faces_point = is_facing


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.1


## True if the point is anywhere in the half circle in front of the player.
func is_facing(point: Vector3) -> bool:
	var forward := Basis(Vector3.UP, facing) * Vector3.FORWARD
	var offset := point - global_position
	offset.y = 0.0
	return forward.dot(offset) >= 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("target_next"):
		targeting.cycle()
	for i in caster.abilities.size():
		if event.is_action_pressed("ability_%d" % (i + 1)):
			caster.use(i)


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var direction := Vector3.ZERO
	if not combatant.is_alive():
		pass
	elif camera is OrbitCamera:
		direction = _tank_direction(camera, delta)
		_visual.rotation.y = facing
	else:
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		direction = _camera_relative(camera, input)
		if direction:
			facing = atan2(-direction.x, -direction.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, 1.0 - exp(-turn_speed * delta))

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if direction else friction
	horizontal = horizontal.move_toward(direction * move_speed, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()


## W and S move, A and D turn, Q and E strafe. While right-dragging, the player
## faces where the camera looks and A and D strafe instead.
func _tank_direction(camera: OrbitCamera, delta: float) -> Vector3:
	var forward := Input.get_axis("move_down", "move_up")
	if camera.is_auto_running():
		forward = 1.0
	var turn := Input.get_axis("move_left", "move_right")
	var strafe := Input.get_axis("strafe_left", "strafe_right")

	if camera.is_steering():
		facing = camera.yaw
		strafe = clampf(strafe + turn, -1.0, 1.0)
	else:
		facing -= turn * keyboard_turn_speed * delta

	var local := Vector3(strafe, 0.0, -forward).limit_length()
	if forward < 0.0:
		local *= backpedal_multiplier
	return Basis(Vector3.UP, facing) * local


func _camera_relative(camera: Camera3D, input: Vector2) -> Vector3:
	if not camera:
		return Vector3(input.x, 0.0, input.y)
	var right := Vector3(camera.global_basis.x.x, 0.0, camera.global_basis.x.z).normalized()
	var back := Vector3(camera.global_basis.z.x, 0.0, camera.global_basis.z.z).normalized()
	return right * input.x + back * input.y
