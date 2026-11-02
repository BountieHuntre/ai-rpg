class_name AbilityCaster
extends Node
## Runs the player's abilities: global cooldown, cooldowns, casting and the
## checks that decide whether an ability can be used.

signal failed(message: String)

const WORLD_LAYER := 1
const EYE_HEIGHT := 1.2

@export var abilities: Array[Ability] = []
@export var global_cooldown := 1.5

var casting: Ability

var _gcd_left := 0.0
var _cooldowns: Dictionary[Ability, float] = {}
var _cast_left := 0.0
var _cast_target: Combatant

@onready var _player: Player = get_parent()


func use(index: int) -> void:
	if index >= abilities.size() or not _player.combatant.is_alive():
		return
	var ability := abilities[index]
	var target: Combatant = null
	if ability.needs_target():
		target = _player.targeting.target_combatant()
	var problem := _find_problem(ability, target)
	if problem.is_empty() and casting:
		problem = "Already casting"
	if problem.is_empty() and _gcd_left > 0.0:
		problem = "Not ready yet"
	if problem.is_empty() and ability.cast_time > 0.0 and _player.is_moving():
		problem = "Can't cast while moving"
	if not problem.is_empty():
		failed.emit(problem)
		return

	_gcd_left = global_cooldown
	if target:
		_player.combatant.attack_target = target
	if ability.cast_time > 0.0:
		casting = ability
		_cast_left = ability.cast_time
		_cast_target = target
	else:
		_finish(ability, target)


## How much of the slot's cooldown remains, from 1 (just used) to 0 (ready).
func cooldown_fraction(index: int) -> float:
	var ability := abilities[index]
	var fraction := _gcd_left / global_cooldown
	if ability.cooldown > 0.0:
		fraction = maxf(fraction, _cooldowns.get(ability, 0.0) / ability.cooldown)
	return fraction


func cast_fraction() -> float:
	return 1.0 - _cast_left / casting.cast_time if casting else 0.0


func _physics_process(delta: float) -> void:
	_gcd_left = maxf(_gcd_left - delta, 0.0)
	for ability: Ability in _cooldowns:
		_cooldowns[ability] = maxf(_cooldowns[ability] - delta, 0.0)

	if not casting:
		return
	if _player.is_moving() or not _player.combatant.is_alive():
		_cancel_cast("Interrupted")
		return
	_cast_left -= delta
	if _cast_left <= 0.0:
		var ability := casting
		var target := _cast_target
		casting = null
		_cast_target = null
		var problem := _find_problem(ability, target)
		if problem.is_empty():
			_finish(ability, target)
		else:
			failed.emit(problem)


func _cancel_cast(message: String) -> void:
	casting = null
	_cast_target = null
	failed.emit(message)


## Returns why the ability can't take effect, or an empty string if it can.
func _find_problem(ability: Ability, target: Combatant) -> String:
	if _cooldowns.get(ability, 0.0) > 0.0:
		return "Not ready yet"
	if _player.combatant.mana < ability.mana_cost:
		return "Not enough mana"
	if ability.needs_target():
		if not target or not target.is_alive():
			return "No target"
		if _player.combatant.distance_to(target) > ability.ability_range:
			return "Out of range"
		if not _player.is_facing(target.body.global_position):
			return "You must face your target"
		if not _has_line_of_sight(target):
			return "Target not in line of sight"
	return ""


func _has_line_of_sight(target: Combatant) -> bool:
	var eye := Vector3.UP * EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + eye, target.body.global_position + eye, WORLD_LAYER
	)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _finish(ability: Ability, target: Combatant) -> void:
	_player.combatant.mana -= ability.mana_cost
	if ability.cooldown > 0.0:
		_cooldowns[ability] = ability.cooldown
	match ability.effect:
		Ability.Effect.DAMAGE:
			target.take_damage(ability.power, _player.combatant)
		Ability.Effect.HEAL:
			_player.combatant.heal(ability.power)
		Ability.Effect.STUN:
			target.take_damage(ability.power, _player.combatant)
			target.stun(ability.stun_duration)
