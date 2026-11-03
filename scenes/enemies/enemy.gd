class_name Enemy
extends CharacterBody3D
## Placeholder enemy. Wanders near its spawn point, chases the player once
## aggroed, auto-attacks in melee, and runs home to reset if pulled too far.
## When killed it leaves a lootable corpse, then respawns. Stats, money, loot,
## respawn time and wander distance come from the classic creature entry in
## data/classic/creatures.json.

enum State { IDLE, CHASE, RETURN, DEAD }

const CREATURES_PATH := "res://data/classic/creatures.json"
const CREATURE_TYPE_HUMANOID := 7
## Dead units move to this physics layer so their corpses can be clicked.
const CORPSE_LAYER := 4
const UNIT_LAYER := 2
## Creature run speed is its SpeedRun times the base run speed of 7 yards/s,
## and walk speed its SpeedWalk times 2.5 yards/s.
const BASE_RUN_SPEED := 7.0
const BASE_WALK_SPEED := 2.5
## RandomMovementGenerator in CMaNGOS: wait 0.5 to 10 s between wanders.
const WANDER_PAUSE_MIN := 0.5
const WANDER_PAUSE_MAX := 10.0
const CREATURE_TYPE_BEAST := 1
## Placeholder looks until there are models: [size, body color]. Beasts lie
## along their length.
const LOOKS := {
	299: [Vector3(0.75, 0.75, 0.75), Color(0.55, 0.55, 0.58)],
	69: [Vector3(0.9, 0.9, 0.9), Color(0.42, 0.36, 0.3)],
	113: [Vector3(1.0, 0.85, 1.0), Color(0.45, 0.3, 0.22)],
	6: [Vector3(0.65, 0.65, 0.65), Color(0.75, 0.55, 0.3)],
	257: [Vector3(0.75, 0.75, 0.75), Color(0.7, 0.5, 0.28)],
	80: [Vector3(0.8, 0.8, 0.8), Color(0.62, 0.45, 0.25)],
	475: [Vector3(0.85, 0.85, 0.85), Color(0.55, 0.38, 0.22)],
	38: [Vector3(1.0, 1.0, 1.0), Color(0.6, 0.15, 0.15)],
}

@export var acceleration := 60.0
@export var gravity := 19.29
## Seconds to respawn and yards to wander; below zero takes the classic
## spawn's values from the data.
@export var respawn_override := -1.0
@export var wander_override := -1.0
## Distance from home that makes it give up and evade.
@export var leash_radius := 60.0
@export var stop_distance := 2.0
var respawn_time := 180.0
## creature_template entry, such as 299 for Young Wolf.
@export var creature_entry := 299

static var _creatures: Dictionary

var state := State.IDLE
var level := 1
var elite := false
## What's left on the corpse: { "id", "count" } entries, and copper.
var loot: Array[Dictionary] = []
var loot_money := 0
## Unix time (seconds) when a dead enemy comes back. Real time, so it keeps
## counting while the game is closed, like a classic server's respawn timer.
var respawn_at := 0.0

var _home := Vector3.ZERO
var _data: Dictionary
var _wander_distance := 0.0
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0

@onready var combatant: Combatant = $Combatant
@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _feedback: UnitFeedback = $UnitFeedback
@onready var _sparkle := _build_sparkle()

const SPARKLE_SPIN := 2.0


func _ready() -> void:
	_home = global_position
	if _creatures.is_empty():
		_creatures = JSON.parse_string(FileAccess.get_file_as_string(CREATURES_PATH))
	_data = _creatures[str(creature_entry)]
	var c := combatant
	c.display_name = _data.Name
	c.min_damage = _data.MinMeleeDmg
	c.max_damage = _data.MaxMeleeDmg
	c.swing_interval = _data.MeleeBaseAttackTime / 1000.0
	c.attack_power = int(_data.MeleeAttackPower)
	c.armor = int(_data.Armor)
	c.melee_crit = CombatRules.NPC_CRIT
	c.dodge = CombatRules.NPC_AVOIDANCE
	c.parry = CombatRules.NPC_AVOIDANCE if int(_data.CreatureType) == CREATURE_TYPE_HUMANOID else 0.0
	elite = int(_data.Rank) > 0
	respawn_time = respawn_override if respawn_override >= 0.0 else float(_data.get("Respawn", 180))
	_wander_distance = wander_override if wander_override >= 0.0 else float(_data.get("Wander", 0))
	_wander_target = _home
	_wander_wait = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
	_apply_look()
	c.faces_point = _is_facing
	_roll_level()
	c.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void: _on_attacked())
	c.avoided.connect(func(_text: String, _source: Combatant) -> void: _on_attacked())
	c.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var destination := global_position

	var speed: float = _data.SpeedRun * BASE_RUN_SPEED
	match state:
		State.IDLE:
			if player and player.combatant.is_alive() and is_aggressive():
				if global_position.distance_to(player.global_position) <= aggro_radius(player.combatant.level):
					_start_chase()
			if state == State.IDLE:
				destination = _wander(delta)
				speed = _data.SpeedWalk * BASE_WALK_SPEED
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
				_wander_target = _home

	var offset := destination - global_position
	offset.y = 0.0
	var direction := offset.normalized() if state != State.DEAD and not combatant.is_stunned() else Vector3.ZERO
	if state in [State.IDLE, State.RETURN] and direction != Vector3.ZERO:
		_face(global_position + direction)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


## Idle wandering: walk to a random point near home, pause, pick another.
func _wander(delta: float) -> Vector3:
	if _wander_distance <= 0.0:
		return global_position
	var offset := _wander_target - global_position
	offset.y = 0.0
	if offset.length() > 0.3:
		return _wander_target
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		var angle := randf() * TAU
		var reach := sqrt(randf()) * _wander_distance
		_wander_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * reach
		_wander_wait = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
	return global_position


func _apply_look() -> void:
	var look: Array = LOOKS.get(creature_entry, [Vector3.ONE, Color(0.75, 0.25, 0.25)])
	var body: MeshInstance3D = $Visual/Body
	var skin := StandardMaterial3D.new()
	skin.albedo_color = look[1]
	body.material_override = skin
	if int(_data.CreatureType) == CREATURE_TYPE_BEAST:
		# On all fours: the capsule lies along the facing direction.
		body.rotation.x = PI / 2
		body.position = Vector3(0, 0.5, 0)
		$Visual/Nose.position = Vector3(0, 0.6, -1.0)
	_visual.scale = look[0]


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


## Whether this creature attacks the player on sight. Neutral creatures, and
## hostile ones flagged to wait, only fight back when attacked.
func is_aggressive() -> bool:
	return ClassicData.aggressive(_data, GameState.race)


func _on_attacked() -> void:
	if state == State.IDLE:
		_start_chase()


## Classic aggro radius: about 20 yards at equal level, one yard less per level
## the player is above it and one more per level below (counted up to 25),
## never under 5 yards. From Creature::GetAttackDistance in CMaNGOS.
func aggro_radius(player_level: int) -> float:
	var level_difference := maxi(player_level - level, -25)
	return maxf(20.0 - level_difference, 5.0)


func has_loot() -> bool:
	return state == State.DEAD and (loot_money > 0 or not loot.is_empty())


## Level is rolled between the template's min and max, with health scaled
## linearly between the min-level and max-level values.
func _roll_level() -> void:
	var min_level := int(_data.MinLevel)
	var max_level := int(_data.MaxLevel)
	level = randi_range(min_level, max_level)
	var t := 0.0 if max_level == min_level else float(level - min_level) / (max_level - min_level)
	combatant.level = level
	combatant.max_health = roundi(lerpf(_data.MinLevelHealth, _data.MaxLevelHealth, t))
	combatant.reset()


func _on_died() -> void:
	state = State.DEAD
	collision_layer = CORPSE_LAYER
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and player.combatant.is_alive():
		player.progression.add_xp(player.progression.xp_for_kill(level, elite))
		loot = LootTable.roll_creature(int(_data.LootId))
		loot_money = LootTable.roll_money(int(_data.MinLootGold), int(_data.MaxLootGold))
	_sparkle.visible = has_loot()
	respawn_at = Time.get_unix_time_from_system() + respawn_time


## Saved state for a dead enemy, or {} while it's alive.
func corpse_state() -> Dictionary:
	if state != State.DEAD:
		return {}
	var p := global_position
	return {
		"respawn_at": respawn_at, "level": level, "position": [p.x, p.y, p.z],
		"facing": _visual.rotation.y, "loot": loot, "money": loot_money,
	}


## Puts back a corpse from the save, unless its respawn time has passed.
func restore_corpse(saved: Dictionary) -> void:
	if float(saved.respawn_at) <= Time.get_unix_time_from_system():
		return
	level = int(saved.level)
	combatant.level = level
	combatant.health = 0
	state = State.DEAD
	collision_layer = CORPSE_LAYER
	var at: Array = saved.position
	global_position = Vector3(at[0], at[1], at[2])
	_visual.rotation.y = float(saved.facing)
	loot.assign(saved.loot.map(func(drop: Dictionary) -> Dictionary: return { "id": int(drop.id), "count": int(drop.count) }))
	loot_money = int(saved.money)
	respawn_at = float(saved.respawn_at)
	_feedback.show_dead()


func _process(delta: float) -> void:
	if state == State.DEAD and Time.get_unix_time_from_system() >= respawn_at:
		_respawn()
	_sparkle.visible = has_loot()
	if _sparkle.visible:
		_sparkle.rotate_y(SPARKLE_SPIN * delta)


func _respawn() -> void:
	global_position = _home
	_wander_target = _home
	velocity = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_feedback.reset()
	collision_layer = UNIT_LAYER
	loot.clear()
	loot_money = 0
	_roll_level()
	state = State.IDLE


## Gold cubes over a corpse that still has loot, standing in for WoW's sparkles.
func _build_sparkle() -> Node3D:
	var sparkle := Node3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.85, 0.3)
	mesh.material = material
	for i in 4:
		var cube := MeshInstance3D.new()
		cube.mesh = mesh
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * i / 4.0
		cube.position = Vector3(cos(angle) * 0.6, 0.4 + 0.15 * (i % 2), sin(angle) * 0.6)
		sparkle.add_child(cube)
	sparkle.visible = false
	add_child(sparkle)
	return sparkle
