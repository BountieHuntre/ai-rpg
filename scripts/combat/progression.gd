class_name Progression
extends Node
## The player's XP and level. Each level raises max health, max mana and all
## damage and healing, and fully restores the player.
## Must be a sibling of the player's Combatant.

signal xp_gained(amount: int)
signal leveled_up(new_level: int)

const MAX_LEVEL := 20
const HEALTH_PER_LEVEL := 15
const MANA_PER_LEVEL := 10
const POWER_PER_LEVEL := 0.1
## Kill XP drops by this much per level the player is above the enemy, so
## enemies five or more levels below give nothing.
const XP_PENALTY_PER_LEVEL := 0.2

var level: int:
	get:
		return GameState.level

var _base_health := 0
var _base_mana := 0

@onready var _combatant: Combatant = $"../Combatant"


func _ready() -> void:
	_base_health = _combatant.max_health
	_base_mana = _combatant.max_mana
	_apply_level()
	_combatant.reset()


static func xp_to_next(from_level: int) -> int:
	return roundi(100.0 * pow(from_level, 1.5))


func xp_for_kill(enemy_level: int) -> int:
	var base := 30 + 10 * enemy_level
	var levels_above := maxi(level - enemy_level, 0)
	return roundi(base * clampf(1.0 - XP_PENALTY_PER_LEVEL * levels_above, 0.0, 1.0))


func add_xp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	GameState.xp += amount
	xp_gained.emit(amount)
	while level < MAX_LEVEL and GameState.xp >= xp_to_next(level):
		GameState.xp -= xp_to_next(level)
		GameState.level += 1
		_apply_level()
		_combatant.health = _combatant.max_health
		_combatant.mana = _combatant.max_mana
		leveled_up.emit(level)
	if level >= MAX_LEVEL:
		GameState.xp = 0


func _apply_level() -> void:
	var gained := level - 1
	_combatant.level = level
	_combatant.max_health = _base_health + HEALTH_PER_LEVEL * gained
	_combatant.max_mana = _base_mana + MANA_PER_LEVEL * gained
	_combatant.power_multiplier = 1.0 + POWER_PER_LEVEL * gained
