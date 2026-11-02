class_name Enemy
extends CharacterBody3D
## Placeholder enemy. Chases the player once aggroed, auto-attacks in melee, and
## runs home to reset if pulled too far. When killed it leaves a lootable
## corpse, then respawns. Stats, money and loot come from the classic
## creature_template entry in data/classic/creatures.json.

enum State { IDLE, CHASE, RETURN, DEAD }

const CREATURES_PATH := "res://data/classic/creatures.json"
const CREATURE_TYPE_HUMANOID := 7
## Dead units move to this physics layer so their corpses can be clicked.
const CORPSE_LAYER := 4
const UNIT_LAYER := 2
## Creature run speed is its SpeedRun times the base run speed of 7 yards/s.
const BASE_RUN_SPEED := 7.0

@export var acceleration := 60.0
@export var gravity := 19.29
## Distance from home that makes it give up and evade.
@export var leash_radius := 60.0
@export var stop_distance := 2.0
@export var respawn_time := 60.0
## creature_template entry, such as 299 for Young Wolf.
@export var creature_entry := 299

static var _creatures: Dictionary

var state := State.IDLE
var level := 1
var elite := false
## What's left on the corpse: { "id", "count" } entries, and copper.
var loot: Array[Dictionary] = []
var loot_money := 0

var _home := Vector3.ZERO
var _data: Dictionary

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
	c.faces_point = _is_facing
	_roll_level()
	c.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void: _on_attacked())
	c.avoided.connect(func(_text: String, _source: Combatant) -> void: _on_attacked())
	c.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var destination := global_position

	match state:
		State.IDLE:
			if player and player.combatant.is_alive():
				if global_position.distance_to(player.global_position) <= aggro_radius(player.combatant.level):
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
	var run_speed: float = _data.SpeedRun * BASE_RUN_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * run_speed, acceleration * delta)
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
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _process(delta: float) -> void:
	_sparkle.visible = has_loot()
	if _sparkle.visible:
		_sparkle.rotate_y(SPARKLE_SPIN * delta)


func _respawn() -> void:
	global_position = _home
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
