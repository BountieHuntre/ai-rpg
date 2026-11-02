class_name Targeting
extends Node
## Tracks the player's current target and draws the ring under it.

signal loot_requested(corpse: Enemy, take_all: bool)

const UNIT_LAYER := 2

@export var tab_range := 40.0

var target: Enemy

@onready var _player: Player = get_parent()
@onready var _ring: Node3D = $Ring


func target_combatant() -> Combatant:
	return target.combatant if target else null


func set_target(enemy: Enemy) -> void:
	if enemy and enemy != target:
		Sfx.play("target")
	target = enemy
	# Auto-attack follows target changes but never starts from selecting alone.
	if _player.combatant.attack_target:
		_player.combatant.attack_target = target_combatant()


## Moves to the next enemy on screen, nearest first, as Tab does in WoW.
func cycle() -> void:
	var camera := _player.get_viewport().get_camera_3d()
	var candidates: Array[Enemy] = []
	for node in _player.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var in_range := _player.global_position.distance_to(enemy.global_position) <= tab_range
		if enemy.combatant.is_alive() and in_range and camera.is_position_in_frustum(enemy.global_position):
			candidates.append(enemy)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return _player.global_position.distance_to(a.global_position) < _player.global_position.distance_to(b.global_position)
	)
	var next := candidates.find(target) + 1
	set_target(candidates[next % candidates.size()])


## Left click selects the enemy under the cursor. Right click also attacks it.
func on_camera_clicked(screen_position: Vector2, button: MouseButton) -> void:
	var camera := _player.get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * camera.far
	var query := PhysicsRayQueryParameters3D.create(from, to, UNIT_LAYER | Enemy.CORPSE_LAYER)
	query.exclude = [_player.get_rid()]
	var enemy := _player.get_world_3d().direct_space_state.intersect_ray(query).get("collider") as Enemy
	if not enemy:
		return
	if not enemy.combatant.is_alive():
		# Right-clicking a corpse loots it. Shift loots everything at once.
		if button == MOUSE_BUTTON_RIGHT and enemy.has_loot():
			loot_requested.emit(enemy, Input.is_key_pressed(KEY_SHIFT))
		return
	set_target(enemy)
	if button == MOUSE_BUTTON_RIGHT:
		_player.combatant.attack_target = enemy.combatant


func _process(_delta: float) -> void:
	if target and not target.combatant.is_alive():
		set_target(null)
	_ring.visible = target != null
	if target:
		_ring.global_position = target.global_position + Vector3.UP * 0.05
