class_name Enemy
extends CharacterBody3D
## Placeholder enemy. Wanders near its spawn point, chases whoever it has the
## most threat on (the player or a playerbot), auto-attacks in melee, and runs
## home to reset if pulled too far. When killed it leaves a corpse, lootable
## if the player's group tapped it, then respawns. Stats, money, loot,
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
## ThreatManager in CMaNGOS: a creature changes victim only when another unit
## has 110% of the current victim's threat in melee range, 130% beyond it.
const THREAT_SWITCH_MELEE := 1.1
const THREAT_SWITCH_RANGED := 1.3
## Healing draws half its amount as threat (HostileRefManager::threatAssist).
const HEAL_THREAT := 0.5
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
## Never attacks on sight, whatever its classic faction: it only fights back.
@export var passive := false
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
## Threat on each player unit fighting it: Combatant -> threat.
var threat: Dictionary = {}
## The first player unit to strike it. Its group gets the kill: XP, quest
## credit and the loot. Others see the creature grey.
var tapped_by: Combatant
var _victim: Combatant

var _home := Vector3.ZERO
var _data: Dictionary
var _wander_distance := 0.0
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0

@onready var combatant: Combatant = $Combatant
@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D
## The standing shape, put back on respawn.
@onready var _standing_shape: Shape3D = _collision.shape
@onready var _standing_transform: Transform3D = _collision.transform
@onready var _feedback: UnitFeedback = $UnitFeedback
@onready var _sparkle := _build_sparkle()

const SPARKLE_SPIN := 2.0
## Extra yards around a corpse's body that still count as clicking it.
const CORPSE_CLICK_MARGIN := 0.2


## A creature_template entry's data from data/classic/creatures.json.
static func creature_data(entry: int) -> Dictionary:
	if _creatures.is_empty():
		_creatures = JSON.parse_string(FileAccess.get_file_as_string(CREATURES_PATH))
	return _creatures.get(str(entry), {})


func _ready() -> void:
	_home = global_position
	_data = creature_data(creature_entry)
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
	c.took_damage.connect(func(amount: int, source: Combatant, _crit: bool) -> void: _on_attacked(source, amount))
	c.avoided.connect(func(_text: String, source: Combatant) -> void: _on_attacked(source, 0))
	c.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	# Corpses stay where they fell: no gravity or sliding with the corpse shape.
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return
	var destination := global_position

	var speed: float = _data.SpeedRun * BASE_RUN_SPEED
	match state:
		State.IDLE:
			if is_aggressive():
				for node in get_tree().get_nodes_in_group("player_units"):
					var unit := node as PlayerUnit
					if unit.combatant.is_alive() and global_position.distance_to(unit.global_position) <= aggro_radius(unit.combatant.level):
						add_threat(unit.combatant, 0.0)
						_start_chase()
						break
			if state == State.IDLE:
				destination = _wander(delta)
				speed = _data.SpeedWalk * BASE_WALK_SPEED
		State.CHASE:
			_victim = _pick_victim()
			if _victim == null or global_position.distance_to(_home) > leash_radius:
				_start_return()
			else:
				var at := _victim.body.global_position
				combatant.attack_target = _victim
				combatant.enter_combat()
				_victim.enter_combat()
				if global_position.distance_to(at) > stop_distance:
					destination = at
				_face(at)
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
		# Dead beasts roll onto their side rather than tipping up on end.
		_feedback.fall_axis = "z"
	_visual.scale = look[0]


func _face(point: Vector3) -> void:
	var offset := point - global_position
	_visual.rotation.y = atan2(-offset.x, -offset.z)


func _is_facing(point: Vector3) -> bool:
	var forward := _visual.global_basis * Vector3.FORWARD
	var offset := point - global_position
	return Vector2(forward.x, forward.z).dot(Vector2(offset.x, offset.z)) >= 0.0


func _start_chase() -> void:
	Sfx.play_at("aggro", global_position)
	state = State.CHASE


func _start_return() -> void:
	state = State.RETURN
	combatant.attack_target = null
	combatant.invulnerable = true
	threat.clear()
	tapped_by = null
	_victim = null


## Adds threat on a player unit, putting it on the threat list.
func add_threat(unit: Combatant, amount: float) -> void:
	if unit == null or not unit.is_player or state == State.DEAD:
		return
	threat[unit] = threat.get(unit, 0.0) + amount


## The living unit with the most threat, keeping the current victim until
## another passes it by the classic margin.
func _pick_victim() -> Combatant:
	# Untyped: a playerbot that left the world is a freed key.
	for unit in threat.keys():
		if not is_instance_valid(unit) or not (unit as Combatant).is_alive():
			threat.erase(unit)
	if not is_instance_valid(_victim):
		_victim = null
	if threat.is_empty():
		return null
	var best: Combatant = null
	for unit: Combatant in threat:
		if best == null or threat[unit] > threat[best]:
			best = unit
	if _victim and threat.has(_victim) and best != _victim:
		var margin := THREAT_SWITCH_MELEE if combatant.distance_to(best) <= combatant.melee_range else THREAT_SWITCH_RANGED
		if threat[best] <= threat[_victim] * margin:
			return _victim
	return best


## A player unit left the world (a playerbot removed): off the threat list.
func forget(unit: Combatant) -> void:
	threat.erase(unit)
	if _victim == unit:
		_victim = null
		combatant.attack_target = null
	if tapped_by == unit:
		tapped_by = null


## Healing a unit draws threat from every creature fighting it, half the
## amount healed, split between them.
static func add_heal_threat(healed: Combatant, healer: Combatant, amount: int) -> void:
	var fighting: Array[Enemy] = []
	for node in healed.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.state == State.CHASE and enemy.threat.has(healed):
			fighting.append(enemy)
	for enemy in fighting:
		enemy.add_threat(healer, amount * HEAL_THREAT / fighting.size())


## Whether someone outside the player's group tapped it: grey to the player.
func is_tapped_by_others() -> bool:
	return tapped_by != null and is_instance_valid(tapped_by) and not Party.has_unit(tapped_by)


## Whether this creature attacks the player on sight. Neutral creatures,
## hostile ones flagged to wait, and ones set `passive` only fight back.
func is_aggressive() -> bool:
	return not passive and ClassicData.aggressive(_data, GameState.race)


func _on_attacked(source: Combatant, damage: int) -> void:
	if source == null or not source.is_player or state == State.RETURN or state == State.DEAD:
		return
	if tapped_by == null or not is_instance_valid(tapped_by):
		tapped_by = source
	add_threat(source, float(damage))
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
	combatant.max_mana = roundi(lerpf(_data.get("MinLevelMana", 0), _data.get("MaxLevelMana", 0), t))
	combatant.reset()


func _on_died() -> void:
	state = State.DEAD
	collision_layer = CORPSE_LAYER
	_fit_corpse_shape()
	# The tapping unit's group gets the kill. Loot is only kept for the
	# player's group: bots don't loot.
	if Party.reward_kill(self, tapped_by if tapped_by and is_instance_valid(tapped_by) else null):
		loot = LootTable.roll_creature(int(_data.LootId))
		loot_money = LootTable.roll_money(int(_data.MinLootGold), int(_data.MaxLootGold))
	threat.clear()
	_victim = null
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
	_fit_corpse_shape()


## Corpses lie down, so clicks (and loot) need a shape around the fallen body,
## not the standing capsule: a box around its meshes in their final pose.
func _fit_corpse_shape() -> void:
	var fall := Vector3(0.0, _visual.rotation.y, -PI / 2.0) if _feedback.fall_axis == "z" else Vector3(-PI / 2.0, _visual.rotation.y, 0.0)
	var fallen := Transform3D(Basis.from_euler(fall) * Basis.from_scale(_visual.scale), Vector3.ZERO)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		if mesh == _sparkle or _sparkle.is_ancestor_of(mesh):
			continue
		# The mesh's place in the visual, in the visual's fallen pose.
		var box := fallen * (_visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	# Half the fallen body is below the feet; the box stays above the ground.
	var bottom := maxf(bounds.position.y, 0.0)
	bounds.size.y = maxf(bounds.end.y - bottom, 0.3)
	bounds.position.y = bottom
	var shape := BoxShape3D.new()
	shape.size = bounds.size + Vector3.ONE * CORPSE_CLICK_MARGIN
	_collision.shape = shape
	_collision.transform = Transform3D(Basis.IDENTITY, bounds.get_center())


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
	_collision.shape = _standing_shape
	_collision.transform = _standing_transform
	loot.clear()
	loot_money = 0
	threat.clear()
	tapped_by = null
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
