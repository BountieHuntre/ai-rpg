class_name Targeting
extends Node
## Tracks the player's current target and draws the ring under it.

signal loot_requested(corpse: Enemy, take_all: bool)
## Right-click on a friendly NPC.
signal npc_clicked(npc: Node3D)

const UNIT_LAYER := 2
const HOSTILE_COLOR := Color(0.8, 0.2, 0.2)
const NEUTRAL_COLOR := Color(0.95, 0.8, 0.15)
const FRIENDLY_COLOR := Color(0.25, 1, 0.25)
## In combat with the target, the ring flashes red this many times a second.
const COMBAT_FLASH_RATE := 2.0

@export var tab_range := 40.0

## An Enemy or a friendly Npc.
var target: Node3D

@onready var _player: Player = get_parent()
@onready var _ring: MeshInstance3D = $Ring
var _ring_material := StandardMaterial3D.new()
var _flash_time := 0.0


## The target's Combatant, or null for none or a friendly NPC.
func target_combatant() -> Combatant:
	var enemy := target as Enemy
	return enemy.combatant if enemy else null


## Reaction colors: red for creatures that attack on sight, yellow for
## passive ones that only fight back, green for friendly NPCs.
static func reaction_color(unit: Node) -> Color:
	if unit is Npc:
		return FRIENDLY_COLOR
	var enemy := unit as Enemy
	if enemy and not enemy.is_aggressive():
		return NEUTRAL_COLOR
	return HOSTILE_COLOR


func set_target(node: Node3D) -> void:
	if node and node != target:
		Sfx.play("target")
	target = node
	if target:
		_ring_material.albedo_color = reaction_color(target)
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


## As in classic: left click selects the creature or NPC under the cursor.
## Right click also acts on it: attacks a creature, talks to an NPC, loots a
## corpse.
func on_camera_clicked(screen_position: Vector2, button: MouseButton) -> void:
	var camera := _player.get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * camera.far
	var query := PhysicsRayQueryParameters3D.create(from, to, UNIT_LAYER | Enemy.CORPSE_LAYER)
	query.exclude = [_player.get_rid()]
	var collider: Object = _player.get_world_3d().direct_space_state.intersect_ray(query).get("collider")
	if collider is Npc:
		set_target(collider)
		if button == MOUSE_BUTTON_RIGHT:
			npc_clicked.emit(collider)
		return
	var enemy := collider as Enemy
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


func _ready() -> void:
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_material


## Whether the target is fighting the player: being auto-attacked, or chasing.
func in_combat_with_target() -> bool:
	var enemy := target as Enemy
	if enemy == null or not enemy.combatant.is_alive():
		return false
	return _player.combatant.attack_target == enemy.combatant or enemy.state == Enemy.State.CHASE


func _process(delta: float) -> void:
	if target is Enemy and not (target as Enemy).combatant.is_alive():
		set_target(null)
	_ring.visible = target != null
	if target:
		_ring.global_position = target.global_position + Vector3.UP * 0.05
		if in_combat_with_target():
			# Flashes between bright and dark red.
			_flash_time += delta
			var pulse := 0.5 + 0.5 * cos(_flash_time * TAU * COMBAT_FLASH_RATE)
			_ring_material.albedo_color = HOSTILE_COLOR.darkened(0.7).lerp(Color(1, 0.25, 0.2), pulse)
		else:
			_flash_time = 0.0
			_ring_material.albedo_color = reaction_color(target)
