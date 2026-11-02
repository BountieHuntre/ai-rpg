class_name Progression
extends Node
## The player's XP and level, using the classic XP table and kill XP formula.
## Levelling up refreshes stats and fully restores the player.
## Must be a sibling of the player's Combatant and CharacterStats.

signal xp_gained(amount: int)
signal leveled_up(new_level: int)

var level: int:
	get:
		return GameState.level

@onready var _combatant: Combatant = $"../Combatant"
@onready var _stats: CharacterStats = $"../CharacterStats"


func xp_to_next() -> int:
	return ClassicData.xp_to_next(level)


func xp_for_kill(enemy_level: int, elite := false) -> int:
	return CombatRules.kill_xp(level, enemy_level, elite)


func add_xp(amount: int) -> void:
	if amount <= 0 or level >= ClassicData.MAX_LEVEL:
		return
	GameState.xp += amount
	xp_gained.emit(amount)
	while level < ClassicData.MAX_LEVEL and GameState.xp >= xp_to_next():
		GameState.xp -= xp_to_next()
		GameState.level += 1
		_stats.refresh()
		_combatant.health = _combatant.max_health
		_combatant.mana = _combatant.max_mana
		leveled_up.emit(level)
	if level >= ClassicData.MAX_LEVEL:
		GameState.xp = 0
