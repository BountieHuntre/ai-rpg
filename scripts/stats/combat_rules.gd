class_name CombatRules
extends RefCounted
## Classic WoW (1.12) combat table, damage and XP rules, following the CMaNGOS
## classic and vmangos server code. All chances are in percent.

enum Outcome { HIT, MISS, DODGE, PARRY, BLOCK, GLANCE, CRIT, CRUSH, RESIST }

const OUTCOME_TEXT := {
	Outcome.MISS: "Miss", Outcome.DODGE: "Dodge", Outcome.PARRY: "Parry",
	Outcome.BLOCK: "Block", Outcome.RESIST: "Resist",
}
const MELEE_CRIT_MULTIPLIER := 2.0
const SPELL_CRIT_MULTIPLIER := 1.5
const BASE_MELEE_MISS := 5.0
const BASE_SPELL_MISS := 4.0
## NPCs that can dodge, parry or block all start at this chance.
const NPC_AVOIDANCE := 5.0
const NPC_CRIT := 5.0


## Fraction of physical damage armor removes, capped at 75%.
static func armor_reduction(armor: int, attacker_level: int) -> float:
	var value := 0.1 * maxi(armor, 0) / (8.5 * attacker_level + 40.0)
	return clampf(value / (1.0 + value), 0.0, 0.75)


static func reduce_by_armor(damage: float, victim: Combatant, attacker: Combatant) -> float:
	return maxf(damage * (1.0 - armor_reduction(int(victim.effective_armor()), attacker.level)), 1.0)


## White melee swing: one roll over miss, dodge, parry, block, glance, crit,
## crush and hit, in that order.
static func roll_auto_attack(attacker: Combatant, victim: Combatant) -> Outcome:
	# Melee swings at a sitting player always crit (RollMeleeOutcomeAgainst).
	if victim.is_player and victim.sitting:
		return Outcome.MISS if randf() * 100.0 < miss_chance(attacker, victim, false) else Outcome.CRIT
	var sides := [
		[Outcome.MISS, miss_chance(attacker, victim, false)],
		[Outcome.DODGE, dodge_chance(attacker, victim)],
		[Outcome.PARRY, parry_chance(attacker, victim)],
		[Outcome.BLOCK, block_chance(attacker, victim)],
		[Outcome.GLANCE, glance_chance(attacker, victim)],
		[Outcome.CRIT, melee_crit_chance(attacker, victim)],
		[Outcome.CRUSH, crush_chance(attacker, victim)],
	]
	return _roll(sides)


## A shot from a bow, gun or thrown weapon: one roll over miss, block, crit
## and hit (ranged attacks can't be dodged or parried here).
static func roll_ranged(attacker: Combatant, victim: Combatant) -> Outcome:
	return _roll([
		[Outcome.MISS, miss_chance(attacker, victim, true)],
		[Outcome.BLOCK, block_chance(attacker, victim)],
		[Outcome.CRIT, melee_crit_chance(attacker, victim)],
	])


## Melee ability ("yellow" attack): one roll for miss, dodge, parry and block,
## then a separate crit roll if it lands.
## Extra crit chance in percent comes from talents (Improved Riposte Strike).
static func roll_melee_ability(attacker: Combatant, victim: Combatant, extra_crit := 0.0) -> Outcome:
	var sides := [
		[Outcome.MISS, miss_chance(attacker, victim, true)],
		[Outcome.DODGE, dodge_chance(attacker, victim)],
		[Outcome.PARRY, parry_chance(attacker, victim)],
		[Outcome.BLOCK, block_chance(attacker, victim)],
	]
	var outcome := _roll(sides)
	if outcome == Outcome.HIT and _chance(melee_crit_chance(attacker, victim) + extra_crit):
		return Outcome.CRIT
	return outcome


## Harmful spell: a resist roll (spell miss and resist share one side before
## WotLK), then a crit roll.
## `spell` lets talents lower the chance to be resisted (Gloom Focus).
static func roll_spell(caster: Combatant, victim: Combatant, spell: Dictionary = {}) -> Outcome:
	if _chance(spell_miss_chance(caster, victim) - SpellMods.flat(caster, spell, SpellMods.RESIST_MISS_CHANCE)):
		return Outcome.RESIST
	if _chance(caster.spell_crit):
		return Outcome.CRIT
	return Outcome.HIT


## Extra crit chance in percent (Stillness adds 25 to the next spell).
static func roll_heal(caster: Combatant, extra_crit := 0.0) -> Outcome:
	return Outcome.CRIT if _chance(caster.spell_crit + extra_crit) else Outcome.HIT


const DUAL_WIELD_MISS := 19.0


const AURA_MOD_HIT_CHANCE := 54


static func miss_chance(attacker: Combatant, victim: Combatant, ability: bool) -> float:
	var chance := BASE_MELEE_MISS
	var difference := victim.defense_skill() - attacker.weapon_skill()
	var factor := 0.04
	if not victim.is_player and difference > 0:
		if difference > 10:
			chance += 10 * 0.1
			difference -= 10
			factor = 0.4
			chance += difference * 0.2
		else:
			factor = 0.1
	chance += difference * factor
	# Swinging two weapons misses 19% more often with white swings.
	if not ability and attacker.off_swing_interval > 0.0:
		chance += DUAL_WIELD_MISS
	# Precision: melee hit chance (SPELL_AURA_MOD_HIT_CHANCE).
	chance -= attacker.aura_total(AURA_MOD_HIT_CHANCE)
	var minimum := 1.0 if difference > 10 else 0.0
	return clampf(chance, minimum, 100.0)


static func dodge_chance(attacker: Combatant, victim: Combatant) -> float:
	if victim.dodge < 0.005 or not victim.can_react():
		return 0.0
	# Players can't dodge attacks from behind.
	if victim.is_player and not victim.faces(attacker):
		return 0.0
	var difference := victim.defense_skill() - attacker.weapon_skill()
	var factor := 0.1 if not victim.is_player and difference > 0 else 0.04
	return clampf(victim.dodge + difference * factor, 0.0, 100.0)


static func parry_chance(attacker: Combatant, victim: Combatant) -> float:
	if victim.parry < 0.005 or not victim.can_react() or not victim.faces(attacker):
		return 0.0
	var difference := victim.defense_skill() - attacker.weapon_skill()
	var factor := 0.04
	if not victim.is_player and difference > 0:
		factor = 0.6 if difference > 10 else 0.1
	return clampf(victim.parry + difference * factor, 0.0, 100.0)


static func block_chance(attacker: Combatant, victim: Combatant) -> float:
	if victim.block < 0.005 or not victim.can_react() or not victim.faces(attacker):
		return 0.0
	var difference := victim.defense_skill() - attacker.weapon_skill()
	var factor := 0.0 if not victim.is_player and difference > 0 else 0.04
	return clampf(victim.block + difference * factor, 0.0, 100.0)


## Players glancing NPCs above level 10.
static func glance_chance(attacker: Combatant, victim: Combatant) -> float:
	if not attacker.is_player or victim.is_player or victim.level <= 10:
		return 0.0
	var skill := mini(attacker.weapon_skill(), attacker.max_skill())
	return clampf(10.0 + (victim.defense_skill() - skill) * 2.0, 0.0, 100.0)


## Damage multiplier for a glancing blow, rolled between the low and high ends.
static func glance_multiplier(attacker: Combatant, victim: Combatant) -> float:
	var difference := victim.defense_skill() - attacker.weapon_skill()
	if difference < 0:
		return 1.0
	var high := clampf(1.2 - 0.03 * difference, 0.2, 0.99)
	var low := clampf(1.3 - 0.05 * difference, 0.01, minf(0.91, high))
	return randi_range(roundi(low * 100), roundi(high * 100)) * 0.01


static func melee_crit_chance(attacker: Combatant, victim: Combatant) -> float:
	if attacker.melee_crit < 0.005:
		return 0.0
	var difference := attacker.max_skill() - victim.defense_skill()
	if not victim.is_player:
		difference = attacker.weapon_skill() - victim.defense_skill()
	# Crit suppression: against NPCs each level of difference is 1% crit.
	var factor := 0.04 if victim.is_player else 0.2
	return clampf(attacker.melee_crit + difference * factor, 0.0, 100.0)


## NPCs crushing players whose defense is 15 or more below their weapon skill.
static func crush_chance(attacker: Combatant, victim: Combatant) -> float:
	if attacker.is_player or not victim.is_player:
		return 0.0
	var deficit := attacker.weapon_skill() - mini(victim.defense_skill(), victim.max_skill())
	return clampf(2.0 * deficit - 15.0, 0.0, 100.0) if deficit >= 15 else 0.0


static func spell_miss_chance(caster: Combatant, victim: Combatant) -> float:
	var chance := BASE_SPELL_MISS
	var difference := victim.level - caster.level
	if difference > 2:
		chance += 2.0
		chance += (difference - 2) * (7.0 if victim.is_player else 11.0)
	else:
		chance += difference
	return clampf(chance, 1.0, 100.0)


# XP, from Formulas.h.

static func gray_level(player_level: int) -> int:
	if player_level <= 5:
		return 0
	if player_level <= 39:
		return player_level - 5 - player_level / 10
	return player_level - 1 - player_level / 5


static func zero_difference(player_level: int) -> int:
	for step: Array in [[8, 5], [10, 6], [12, 7], [16, 8], [20, 9], [30, 11], [40, 12], [45, 13], [50, 14], [55, 15], [60, 16]]:
		if player_level < step[0]:
			return step[1]
	return 17


static func kill_xp(player_level: int, mob_level: int, elite := false) -> int:
	var factor := 0.0
	if mob_level >= player_level:
		factor = 1.0 + 0.05 * mini(mob_level - player_level, 4)
	elif mob_level > gray_level(player_level):
		var zd := zero_difference(player_level)
		factor = float(zd + mob_level - player_level) / zd
	var xp := (player_level * 5 + 45) * factor
	if elite:
		xp *= 2.0
	return _round_half_even(xp)


## Classic level colors for a mob as seen by the player.
static func level_color(player_level: int, mob_level: int) -> Color:
	if mob_level >= player_level + 5:
		return Color(1, 0.1, 0.1)
	if mob_level >= player_level + 3:
		return Color(1, 0.5, 0.25)
	if mob_level >= player_level - 2:
		return Color(1, 1, 0)
	if mob_level > gray_level(player_level):
		return Color(0.25, 0.75, 0.25)
	return Color(0.5, 0.5, 0.5)


static func _roll(sides: Array) -> Outcome:
	var roll := randf() * 100.0
	var total := 0.0
	for side: Array in sides:
		total += side[1]
		if roll < total:
			return side[0]
	return Outcome.HIT


## Matches std::nearbyint in the server code: halves round to the even number.
static func _round_half_even(value: float) -> int:
	var low := floori(value)
	var fraction := value - low
	if is_equal_approx(fraction, 0.5):
		return low if low % 2 == 0 else low + 1
	return roundi(value)


static func _chance(percent: float) -> bool:
	return randf() * 100.0 < percent
