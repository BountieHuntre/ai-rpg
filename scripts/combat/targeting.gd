class_name Targeting
extends Node
## Tracks the player's current target (a creature, an NPC or a playerbot) and
## draws the ring under it.

signal loot_requested(corpse: Enemy, take_all: bool)
## Right-click on a friendly NPC.
signal npc_clicked(npc: Node3D)

const UNIT_LAYER := 2
const HOSTILE_COLOR := Color(0.8, 0.2, 0.2)
const NEUTRAL_COLOR := Color(0.95, 0.8, 0.15)
const FRIENDLY_COLOR := Color(0.25, 1, 0.25)
## Other players' names, as classic shows friendly players.
const PLAYER_COLOR := Color(0.35, 0.6, 1)
## Creatures someone outside your group tapped.
const TAPPED_COLOR := Color(0.6, 0.6, 0.6)
## In combat with the target, the ring flashes red this many times a second.
const COMBAT_FLASH_RATE := 2.0

@export var tab_range := 40.0

## An Enemy, a friendly Npc or a Bot.
var target: Node3D

@onready var _player: Player = get_parent()
@onready var _ring: MeshInstance3D = $Ring
var _ring_material := StandardMaterial3D.new()
var _flash_time := 0.0


## The target's Combatant if it's a creature, or null.
func target_combatant() -> Combatant:
	var enemy := target as Enemy
	return enemy.combatant if enemy else null


## The targeted playerbot's Combatant (alive or dead), or null.
func friendly_combatant() -> Combatant:
	var bot := target as Bot
	return bot.combatant if bot else null


## Reaction colors: red for creatures that attack on sight, yellow for
## passive ones that only fight back, green for friendly NPCs.
static func reaction_color(unit: Node) -> Color:
	if unit is Npc or unit is PlayerUnit:
		return FRIENDLY_COLOR
	var enemy := unit as Enemy
	if enemy and not enemy.is_aggressive():
		return NEUTRAL_COLOR
	return HOSTILE_COLOR


## The same reactions as text colors, brighter so names read well: red for
## aggressive creatures, yellow for passive ones, green for friendly NPCs.
static func name_color(unit: Node) -> Color:
	if unit is Npc:
		return FRIENDLY_COLOR
	if unit is PlayerUnit:
		return PLAYER_COLOR
	var enemy := unit as Enemy
	if enemy and enemy.is_tapped_by_others():
		return TAPPED_COLOR
	if enemy and not enemy.is_aggressive():
		return Color(1, 0.85, 0.15)
	return Color(1, 0.25, 0.2)


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


## The creature, corpse or NPC under a point of the game view, or null.
func unit_at(screen_position: Vector2) -> Node3D:
	var camera := _player.get_viewport().get_camera_3d()
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * camera.far
	var query := PhysicsRayQueryParameters3D.create(from, to, UNIT_LAYER | Enemy.CORPSE_LAYER)
	query.exclude = [_player.get_rid()]
	return _player.get_world_3d().direct_space_state.intersect_ray(query).get("collider") as Node3D


## As in classic: left click selects the creature or NPC under the cursor.
## Right click also acts on it: attacks a creature, talks to an NPC, loots a
## corpse.
func on_camera_clicked(screen_position: Vector2, button: MouseButton) -> void:
	var collider := unit_at(screen_position)
	if collider is Npc:
		set_target(collider)
		if button == MOUSE_BUTTON_RIGHT:
			npc_clicked.emit(collider)
		return
	# Clicking a playerbot only targets it: its menu is on the target and
	# party frames.
	if collider is Bot:
		set_target(collider)
		return
	var enemy := collider as Enemy
	if not enemy:
		return
	if not enemy.combatant.is_alive():
		# Right-clicking a corpse loots it. Shift loots everything at once.
		if button == MOUSE_BUTTON_RIGHT and enemy.has_loot():
			# Shift does the opposite of the Auto Loot option, as in classic.
			loot_requested.emit(enemy, Input.is_key_pressed(KEY_SHIFT) != Settings.get_value("auto_loot"))
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
	return _player.combatant.attack_target == enemy.combatant or (enemy.state == Enemy.State.CHASE and enemy.threat.has(_player.combatant))


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
