class_name Projectile
extends Node3D
## Flies at a combatant and runs a callback when it arrives.

const AIM_HEIGHT := 1.1

var _target: Combatant
var _speed := 0.0
var _on_hit: Callable


func launch(from: Vector3, target: Combatant, speed: float, on_hit: Callable) -> void:
	global_position = from
	_target = target
	_speed = speed
	_on_hit = on_hit


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_target) or not _target.is_alive():
		queue_free()
		return
	var aim := _target.body.global_position + Vector3.UP * AIM_HEIGHT
	var step := _speed * delta
	if global_position.distance_to(aim) <= step:
		_on_hit.call()
		queue_free()
	else:
		global_position = global_position.move_toward(aim, step)
