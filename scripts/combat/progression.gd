class_name Progression
extends Node
## A player character's XP and level (the player's or a playerbot's), using
## the classic XP table and kill XP formula. Levelling up refreshes stats and
## fully restores the unit. Must be a child of a PlayerUnit, beside its
## Combatant and CharacterStats.

signal xp_gained(amount: int)
signal leveled_up(new_level: int)

var level: int:
	get:
		return _profile.level
## Highest level this unit can reach: random playerbots stop at the level the
## Playerbots options allow.
var level_cap := ClassicData.MAX_LEVEL

@onready var _combatant: Combatant = $"../Combatant"
@onready var _stats: CharacterStats = $"../CharacterStats"
@onready var _profile: CharacterProfile = (get_parent() as PlayerUnit).profile


func xp_to_next() -> int:
	return ClassicData.xp_to_next(level)


func xp_for_kill(enemy_level: int, elite := false) -> int:
	return CombatRules.kill_xp(level, enemy_level, elite)


func add_xp(amount: int) -> void:
	if amount <= 0 or level >= mini(level_cap, ClassicData.MAX_LEVEL):
		return
	_profile.xp += amount
	xp_gained.emit(amount)
	while level < mini(level_cap, ClassicData.MAX_LEVEL) and _profile.xp >= xp_to_next():
		_profile.xp -= xp_to_next()
		_profile.level += 1
		_stats.refresh()
		_combatant.health = _combatant.max_health
		_combatant.mana = _combatant.max_mana
		leveled_up.emit(level)
	if level >= mini(level_cap, ClassicData.MAX_LEVEL):
		_profile.xp = 0
