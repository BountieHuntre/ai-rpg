class_name Enemy
extends CharacterBody3D
## Placeholder enemy. Chases the player once aggroed, auto-attacks in melee, and
## runs home to reset if pulled too far. Respawns after dying.
## Combat values match a classic WoW creature_template entry.

enum State { IDLE, CHASE, RETURN, DEAD }

@export var move_speed := 3.5
@export var acceleration := 30.0
@export var gravity := 25.0
@export var aggro_radius := 8.0
@export var leash_radius := 20.0
@export var stop_distance := 2.0
@export var respawn_time := 15.0

@export_group("Creature")
@export var creature_name := "Young Wolf"
@export var level := 1
@export var health := 42
@export var min_damage := 2.0
@export var max_damage := 2.0
@export var attack_time := 2.0
@export var attack_power := 1
@export var armor := 15
## Humanoids can parry. Beasts can't.
@export var can_parry := false
@export var elite := false

var state := State.IDLE

var _home := Vector3.ZERO

@onready var combatant: Combatant = $Combatant
@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _feedback: UnitFeedback = $UnitFeedback


func _ready() -> void:
	_home = global_position
	var c := combatant
	c.display_name = creature_name
	c.level = level
	c.max_health = health
	c.min_damage = min_damage
	c.max_damage = max_damage
	c.swing_interval = attack_time
	c.attack_power = attack_power
	c.armor = armor
	c.melee_crit = CombatRules.NPC_CRIT
	c.dodge = CombatRules.NPC_AVOIDANCE
	c.parry = CombatRules.NPC_AVOIDANCE if can_parry else 0.0
	c.faces_point = _is_facing
	c.reset()
	c.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void: _on_attacked())
	c.avoided.connect(func(_text: String, _source: Combatant) -> void: _on_attacked())
	c.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var destination := global_position

	match state:
		State.IDLE:
			if player and player.combatant.is_alive():
				if global_position.distance_to(player.global_position) <= aggro_radius:
					_start_chase()
		State.CHASE:
			if not player or not player.combatant.is_alive() or global_position.distance_to(_home) > leash_radius:
				_start_return()
			else:
				combatant.attack_target = player.combatant
				combatant.enter_combat()
				player.combatant.enter_combat()
				if global_position.distance_to(player.global_position) > stop_distance:
					destination = player.global_position
				_face(player.global_position)
		State.RETURN:
			destination = _home
			if Vector2(global_position.x - _home.x, global_position.z - _home.z).length() < 0.5:
				combatant.reset()
				state = State.IDLE

	var offset := destination - global_position
	offset.y = 0.0
	var direction := offset.normalized() if state != State.DEAD and not combatant.is_stunned() else Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * move_speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


func _face(point: Vector3) -> void:
	var offset := point - global_position
	_visual.rotation.y = atan2(-offset.x, -offset.z)


func _is_facing(point: Vector3) -> bool:
	var forward := _visual.global_basis * Vector3.FORWARD
	var offset := point - global_position
	return Vector2(forward.x, forward.z).dot(Vector2(offset.x, offset.z)) >= 0.0


func _start_chase() -> void:
	Sfx.play("aggro")
	state = State.CHASE


func _start_return() -> void:
	state = State.RETURN
	combatant.attack_target = null
	combatant.invulnerable = true


func _on_attacked() -> void:
	if state == State.IDLE:
		_start_chase()


func _on_died() -> void:
	state = State.DEAD
	_collision.set_deferred("disabled", true)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.combatant.is_alive():
		player.progression.add_xp(player.progression.xp_for_kill(level, elite))
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	global_position = _home
	velocity = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_feedback.reset()
	_collision.set_deferred("disabled", false)
	combatant.reset()
	state = State.IDLE
