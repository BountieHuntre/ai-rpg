class_name Combatant
extends Node
## Health, mana, stuns and auto-attack, shared by the player and enemies.
## Must be a direct child of the unit's body.

signal swung(target: Combatant)
signal took_damage(amount: int, source: Combatant)
signal healed(amount: int)
signal stunned
signal died

@export var display_name := ""
@export var max_health := 100
@export var max_mana := 0
@export var mana_regen := 0.0
@export var melee_damage := 5
@export var melee_range := 2.5
@export var swing_interval := 2.0

var health := 0
var mana := 0.0
var invulnerable := false
## While set, swings at this combatant whenever it is in melee range.
var attack_target: Combatant
## Optional extra check before a swing. Takes the target's position.
var can_swing_at: Callable

var _stun_left := 0.0
var _swing_left := 0.0

@onready var body: Node3D = get_parent()


func _ready() -> void:
	add_to_group("combatants")
	reset()


func reset() -> void:
	health = max_health
	mana = max_mana
	attack_target = null
	invulnerable = false
	_stun_left = 0.0


func is_alive() -> bool:
	return health > 0


func is_stunned() -> bool:
	return _stun_left > 0.0


func distance_to(other: Combatant) -> float:
	return body.global_position.distance_to(other.body.global_position)


func take_damage(amount: int, source: Combatant) -> void:
	if not is_alive() or invulnerable:
		return
	health = maxi(health - amount, 0)
	took_damage.emit(amount, source)
	if health == 0:
		attack_target = null
		died.emit()


func heal(amount: int) -> void:
	if not is_alive():
		return
	health = mini(health + amount, max_health)
	healed.emit(amount)


func stun(duration: float) -> void:
	if not is_alive() or invulnerable:
		return
	_stun_left = maxf(_stun_left, duration)
	stunned.emit()


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	mana = minf(mana + mana_regen * delta, max_mana)
	_stun_left = maxf(_stun_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)

	if attack_target and not attack_target.is_alive():
		attack_target = null
	if attack_target and not is_stunned() and _swing_left == 0.0:
		var allowed: bool = not can_swing_at.is_valid() or can_swing_at.call(attack_target.body.global_position)
		if allowed and distance_to(attack_target) <= melee_range:
			swung.emit(attack_target)
			attack_target.take_damage(melee_damage, self)
			_swing_left = swing_interval
