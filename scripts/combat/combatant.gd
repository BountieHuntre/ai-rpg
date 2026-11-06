class_name Combatant
extends Node
## Health, mana, combat stats and auto-attack, shared by the player and
## enemies. Hits are resolved with the classic combat table in CombatRules.
## Must be a direct child of the unit's body.

signal swung(target: Combatant)
signal took_damage(amount: int, source: Combatant, crit: bool)
## A hit that was turned away entirely, such as a miss, dodge or resist.
signal avoided(text: String, source: Combatant)
signal healed(amount: int, crit: bool)
signal stunned
signal died
## A white melee swing hit (including glancing, crushing, blocked and crits).
signal auto_attack_landed(target: Combatant)
signal auras_changed
## This combatant's hit landed on a target (damage greater than zero).
signal dealt_damage(target: Combatant)
## A melee swing landed on this unit (damage shields answer it).
signal melee_hit_taken(attacker: Combatant)
## This unit blocked a melee swing, fully or partly.
signal blocked_attack(attacker: Combatant)
## This unit's damage of a school landed on a target (Leeching Embrace heals from shadow).
signal damage_done(target: Combatant, amount: int, school: int)
## This unit's melee attack was dodged, parried or blocked ("Dodge"...): Riposte
## Strike waits for a dodge.
signal attack_avoided(target: Combatant, text: String)
## Something tries to cut this unit's cast short (Hilt Strike, Shield Smash),
## locking the spell's school for `lockout` seconds if it was casting.
signal interrupt_requested(lockout: float)
## This unit's cast was cut short.
signal cast_interrupted
## A combat event for procs, as CMaNGOS ProcFlags (what happened, from this
## unit's side) and procEx (how it went: PROC_EX_*). `other` is the other
## unit, `spell` the ability or spell ({} for a plain swing).
signal proc_event(flags: int, ex: int, other: Combatant, spell: Dictionary, amount: int)

## ProcFlags (SpellDefines.h).
const PROC_KILL := 0x2
const PROC_MELEE_HIT := 0x4
const PROC_TAKEN_MELEE_HIT := 0x8
const PROC_MELEE_ABILITY := 0x10
const PROC_TAKEN_MELEE_ABILITY := 0x20
const PROC_POSITIVE_SPELL := 0x4000
const PROC_TAKEN_POSITIVE_SPELL := 0x8000
const PROC_NEGATIVE_SPELL := 0x10000
const PROC_TAKEN_NEGATIVE_SPELL := 0x20000
## procEx.
const PROC_EX_NORMAL := 0x1
const PROC_EX_CRIT := 0x2
const PROC_EX_MISS := 0x4
const PROC_EX_RESIST := 0x8
const PROC_EX_DODGE := 0x10
const PROC_EX_PARRY := 0x20
const PROC_EX_BLOCK := 0x40
## The school of the last damage this unit took, for threat by school.
var last_hit_school := 0

## Leaving combat takes this long without dealing or taking hits, while no
## enemy is chasing.
const COMBAT_TIMEOUT := 5.0
const CRUSH_MULTIPLIER := 1.5
## Rage tops out at 100 (classic's 1000 tenths).
const MAX_RAGE := 100
## Off-hand swings deal half damage (classic, before talents).
const OFF_HAND_DAMAGE := 0.5
const AURA_MOD_ROOT := 26
const AURA_MOD_SKILL := 98
const SKILL_DEFENSE := 95
const AURA_MOD_OFFHAND_DAMAGE_PCT := 122
## SPELL_AURA_MECHANIC_RESISTANCE (Iron Resolve), and the stun mechanic.
const AURA_MECHANIC_RESISTANCE := 117
const MECHANIC_STUN := 12
## SPELL_AURA_OBS_MOD_HEALTH: heals a percent of max health each tick (Bloodied Resolve).
const AURA_OBS_MOD_HEALTH := 20

@export var display_name := ""
@export var level := 1
@export var max_health := 100
@export var max_mana := 0
@export var melee_range := 2.5

var is_player := false
## True while casting a spell with a cast time. Melee swings wait until the
## cast ends, but the swing timer keeps running (Player::Update in CMaNGOS
## only swings when no non-melee spell is being cast).
var is_casting := false
## Sitting players take crits from every melee swing and stand when hit.
var sitting := false
var armor := 0
var attack_power := 0
var min_damage := 1.0
var max_damage := 2.0
var swing_interval := 2.0
## Chances in percent, before the level-difference adjustments in CombatRules.
var melee_crit := 0.0
var spell_crit := 0.0
var dodge := 0.0
var parry := 0.0
var block := 0.0
var block_value := 0

var health := 0
## Mana, or rage for a unit whose power_type is rage (the Man-at-Arms):
## max_mana is then MAX_RAGE, and it starts empty.
var mana := 0.0
var power_type := SpellDB.POWER_MANA
## Off-hand weapon (Two-Weapon Fighting): its damage range and swing time,
## 0 for none.
var off_min_damage := 0.0
var off_max_damage := 0.0
var off_swing_interval := 0.0
## Called with the target before a main-hand swing; returns true if it made
## the attack itself (Mighty Blow and Sweeping Cut replace the swing).
var swing_replacer: Callable
## Swings owed right away (Swordsman's Craft, Reckoner's Fury).
var extra_attacks := 0
var invulnerable := false
## While set, swings at this combatant whenever it is in melee range.
var attack_target: Combatant
## Optional check of whether this unit is facing a world position.
var faces_point: Callable

## Buffs and debuffs: { "spell": spell_template row, "caster": Combatant,
## "remaining": seconds (-1 until cancelled), "duration": seconds }.
var auras: Array[Dictionary] = []

var _stun_left := 0.0
var _swing_left := 0.0
var _off_swing_left := 0.0
var _combat_left := 0.0
var _since_mana_spent := INF

@onready var body: Node3D = get_parent()


func _ready() -> void:
	add_to_group("combatants")
	reset()


func reset() -> void:
	health = max_health
	mana = 0.0 if uses_rage() else max_mana
	attack_target = null
	invulnerable = false
	_stun_left = 0.0
	_combat_left = 0.0
	clear_auras()


func is_alive() -> bool:
	return health > 0


func is_stunned() -> bool:
	return _stun_left > 0.0


## Units that are stunned or dead can't dodge, parry or block.
func can_react() -> bool:
	return is_alive() and not is_stunned()


func is_in_combat() -> bool:
	return _combat_left > 0.0


func enter_combat() -> void:
	_combat_left = COMBAT_TIMEOUT


func seconds_since_mana_spent() -> float:
	return _since_mana_spent


func faces(other: Combatant) -> bool:
	return not faces_point.is_valid() or faces_point.call(other.body.global_position)


## Weapon and defense skill are always at their cap of 5 per level.
func max_skill() -> int:
	return level * 5


func weapon_skill() -> int:
	return max_skill()


## Anticipation adds defense skill (SPELL_AURA_MOD_SKILL on Defense, skill 95).
func defense_skill() -> int:
	return max_skill() + int(aura_total_exact(AURA_MOD_SKILL, SKILL_DEFENSE))


func distance_to(other: Combatant) -> float:
	return body.global_position.distance_to(other.body.global_position)


## Adds or refreshes an aura. The same spell replaces itself. Effect amounts
## are rolled once, at the caster's level, when the aura lands.
## Auras that stack (Rend Armor, up to five) add a stack instead, multiplying
## their amounts and refreshing the time.
func add_aura(spell: Dictionary, caster: Combatant) -> void:
	var stacks := 1
	var most := int(spell.get("StackAmount", 0))
	if most > 1:
		for old in auras:
			if int(old.spell.Id) == int(spell.Id) and old.caster == caster:
				stacks = mini(int(old.get("stacks", 1)) + 1, most)
	remove_aura(int(spell.Id), false)
	# The caster's talents may lengthen it or strengthen its effects, and its
	# damage over time (SpellMods DURATION, ALL_EFFECTS, DOT).
	var length := SpellDB.duration(spell, caster)
	var amounts := []
	for i in 3:
		var amount := SpellDB.effect_value(spell, i, caster.level, caster) * stacks
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) in [SpellDB.AURA_PERIODIC_DAMAGE, SpellDB.AURA_PERIODIC_LEECH]:
			amount = SpellMods.apply(caster, spell, SpellMods.DOT, amount)
		amounts.append(amount)
	var aura := { "spell": spell, "caster": caster, "remaining": length, "duration": length, "amounts": amounts }
	if stacks > 1:
		aura.stacks = stacks
	# Auras used up after a number of procs (Radiant Bulwark's blocks); talents
	# may add more (SpellMods CHARGES: Improved Shield Brace).
	if int(spell.get("ProcCharges", 0)) > 0:
		aura.charges = roundi(SpellMods.apply(caster, spell, SpellMods.CHARGES, int(spell.ProcCharges)))
	auras.append(aura)
	auras_changed.emit()


## Sum of an aura type's amounts, optionally only effects whose misc value
## (a school mask for resistances, damage taken and immunities) overlaps mask.
func aura_total(aura_type: int, misc_mask := -1) -> float:
	var total := 0.0
	for aura in auras:
		for i in 3:
			if int(aura.spell["EffectApplyAuraName%d" % (i + 1)]) != aura_type:
				continue
			if misc_mask >= 0 and int(aura.spell["EffectMiscValue%d" % (i + 1)]) & misc_mask == 0:
				continue
			total += aura.amounts[i]
	return total


## Sum of an aura type's amounts whose misc value is exactly misc (a stat
## index for Litany of Fortitude; -1 there means every stat).
func aura_total_exact(aura_type: int, misc: int) -> float:
	var total := 0.0
	for aura in auras:
		for i in 3:
			if int(aura.spell["EffectApplyAuraName%d" % (i + 1)]) == aura_type and int(aura.spell["EffectMiscValue%d" % (i + 1)]) == misc:
				total += aura.amounts[i]
	return total


## The strongest (most negative) amount of an aura type, or 0: slows don't add up.
func aura_lowest(aura_type: int) -> float:
	var lowest := 0.0
	for aura in auras:
		for i in 3:
			if int(aura.spell["EffectApplyAuraName%d" % (i + 1)]) == aura_type:
				lowest = minf(lowest, aura.amounts[i])
	return lowest


func uses_rage() -> bool:
	return power_type == SpellDB.POWER_RAGE


## Whether this unit has mana (not rage) to drink for and run out of.
func has_mana() -> bool:
	return max_mana > 0 and not uses_rage()


## Rage from a hit dealt (7.5 parts) or taken (2.5 parts) for its damage, as
## Player::RewardRage in CMaNGOS classic: damage / conversion * parts, the
## conversion growing with level.
func reward_rage(damage: int, dealt: bool) -> void:
	if not uses_rage() or damage <= 0:
		return
	var conversion := 0.0091107836 * level * level + 3.225598133 * level + 4.2652911
	gain_rage(damage / conversion * (7.5 if dealt else 2.5))


func gain_rage(amount: float) -> void:
	mana = clampf(mana + amount, 0.0, max_mana)


## Taunted units must attack whoever taunted them (Goad, Daring Roar).
func taunted_by() -> Combatant:
	for aura in auras:
		if SpellDB.has_effect(aura.spell, SpellDB.AURA_MOD_TAUNT, true) and is_instance_valid(aura.caster) and aura.caster.is_alive():
			return aura.caster
	return null


## Threat this unit causes with a school, as a factor (stances, Stubborn
## Defiance, Quiet Resolve: SPELL_AURA_MOD_THREAT by school; Shadow Kinship's
## threat modifier on Shadow spells).
func threat_multiplier(school := 0) -> float:
	var percent := aura_total(SpellDB.AURA_MOD_THREAT, 1 << school)
	if school == SpellDB.School.SHADOW:
		for aura in auras:
			for i in 3:
				var kind := int(aura.spell.get("EffectApplyAuraName%d" % (i + 1), 0))
				if kind == SpellMods.AURA_PCT and int(aura.spell.get("EffectMiscValue%d" % (i + 1), -1)) == SpellMods.THREAT:
					percent += aura.amounts[i]
	return maxf(1.0 + percent / 100.0, 0.0)


## Armor less any armor debuffs (Rend Armor), and percentage changes (Death
## Craving). A player's own armor auras are counted in CharacterStats.
func effective_armor() -> float:
	var total := float(armor)
	if not is_player:
		total += aura_total(SpellDB.AURA_MOD_RESISTANCE, 1)
	total *= 1.0 + aura_total(SpellDB.AURA_MOD_RESISTANCE_PCT, 1) / 100.0
	return maxf(total, 0.0)


## Rooted units can't move (Improved Hobble), but can still fight.
func is_rooted() -> bool:
	return has_aura_type(AURA_MOD_ROOT)


## Feared units run from whoever frightened them and can't fight.
func is_feared() -> bool:
	return has_aura_type(SpellDB.AURA_MOD_FEAR)


## The unit that feared this one, or null.
func fear_source() -> Combatant:
	for aura in auras:
		if SpellDB.has_effect(aura.spell, SpellDB.AURA_MOD_FEAR, true) and is_instance_valid(aura.caster):
			return aura.caster
	return null


## Movement speed factor from speed auras: the strongest slow (Mind Rend) and
## any speed-ups.
func speed_multiplier() -> float:
	return maxf(1.0 + aura_total(SpellDB.AURA_MOD_INCREASE_SPEED) / 100.0 + aura_lowest(SpellDB.AURA_MOD_DECREASE_SPEED) / 100.0, 0.0)


## Damage done bonus in percent for a school (Kindled Power, Shroud of Shadow).
func damage_done_percent(school: int) -> float:
	return aura_total(SpellDB.AURA_MOD_DAMAGE_PERCENT_DONE, 1 << school)


func has_aura_type(aura_type: int, misc_mask := -1) -> bool:
	for aura in auras:
		for i in 3:
			if int(aura.spell["EffectApplyAuraName%d" % (i + 1)]) == aura_type:
				if misc_mask < 0 or int(aura.spell["EffectMiscValue%d" % (i + 1)]) & misc_mask != 0:
					return true
	return false


## Divine Protection and Blessing of Protection: immune to a school.
func is_immune(school: int) -> bool:
	return has_aura_type(SpellDB.AURA_SCHOOL_IMMUNITY, 1 << school)


## Pacified units can't melee (Divine Protection, Blessing of Protection).
func is_pacified() -> bool:
	return has_aura_type(SpellDB.AURA_MOD_PACIFY)


## Puts back a saved aura with its remaining time and rolled amounts.
func restore_aura(spell: Dictionary, caster: Combatant, remaining: float, length: float, amounts: Array) -> void:
	remove_aura(int(spell.Id), false)
	auras.append({ "spell": spell, "caster": caster, "remaining": remaining, "duration": length, "amounts": amounts })
	auras_changed.emit()


func remove_aura(spell_id: int, notify := true) -> void:
	var before := auras.size()
	auras = auras.filter(func(aura: Dictionary) -> bool: return int(aura.spell.Id) != spell_id)
	if notify and auras.size() != before:
		auras_changed.emit()


func find_aura(test: Callable) -> Dictionary:
	for aura in auras:
		if test.call(aura.spell):
			return aura
	return {}


## Takes every aura off but passive talents, which belong to the character.
func clear_auras() -> void:
	var before := auras.size()
	auras = auras.filter(func(aura: Dictionary) -> bool: return aura.get("talent", false))
	if auras.size() != before:
		auras_changed.emit()


## A passive talent's aura: permanent, from the unit itself, its amounts at
## the unit's level. Talents.sync_passives puts these on and takes them off.
func add_passive_aura(spell: Dictionary) -> void:
	var amounts := []
	for i in 3:
		amounts.append(SpellDB.effect_value(spell, i, level))
	var aura := { "spell": spell, "caster": self, "remaining": -1.0, "duration": -1.0, "amounts": amounts, "talent": true }
	if int(spell.get("ProcCharges", 0)) > 0:
		aura.charges = int(spell.ProcCharges)
	auras.append(aura)


## Death removes every aura but stances, paladin auras, passive talents and
## death-persistent ones.
func _clear_auras_on_death() -> void:
	var before := auras.size()
	auras = auras.filter(func(aura: Dictionary) -> bool: return aura.get("talent", false) or SpellDB.persists_through_death(aura.spell))
	if auras.size() != before:
		auras_changed.emit()


func spend_mana(amount: int) -> void:
	if amount > 0:
		mana -= amount
		_since_mana_spent = 0.0


## Weapon damage plus the attack power bonus of AP / 14 per second of swing time.
## Flat physical damage done auras (Feeble Hex and Withering Touch lower it)
## apply too. A creature's attack power auras (Daunting Roar) count here, and
## a disarmed creature hits for half.
func roll_weapon_damage() -> float:
	var power := float(attack_power) + (0.0 if is_player else aura_total(SpellDB.AURA_MOD_ATTACK_POWER))
	var damage := randf_range(min_damage, max_damage) + maxf(power, 0.0) / 14.0 * swing_interval
	if not is_player and has_aura_type(SpellDB.AURA_MOD_DISARM):
		damage *= 0.5
	return maxf(damage + aura_total(SpellDB.AURA_MOD_DAMAGE_DONE, 1), 0.0)


## Weapon damage with the attack power bonus at a normalized speed (2.4 s for
## one-handers, 3.3 s for two-handers, 1.7 s for daggers), as abilities with
## SPELL_EFFECT_NORMALIZED_WEAPON_DMG roll it.
func roll_normalized_damage(speed: float) -> float:
	var damage := randf_range(min_damage, max_damage) + attack_power / 14.0 * speed
	return maxf(damage + aura_total(SpellDB.AURA_MOD_DAMAGE_DONE, 1), 0.0)


## Resolves a melee weapon attack from an ability (Mighty Blow, Riposte
## Strike): the yellow table, armor, and no rage. Returns whether it landed.
## `dodgeable` false leaves dodge, parry and block out (Riposte Strike).
## `spell` is the ability: talents may add to its crit chance (SpellMods).
func strike(target: Combatant, damage: float, dodgeable := true, spell: Dictionary = {}) -> bool:
	var extra_crit := SpellMods.flat(self, spell, SpellMods.CRITICAL_CHANCE)
	var outcome := CombatRules.roll_melee_ability(self, target, extra_crit)
	if not dodgeable and outcome in [CombatRules.Outcome.DODGE, CombatRules.Outcome.PARRY, CombatRules.Outcome.BLOCK]:
		outcome = CombatRules.Outcome.CRIT if randf() * 100.0 < CombatRules.melee_crit_chance(self, target) + extra_crit else CombatRules.Outcome.HIT
	return _resolve_melee(target, damage, outcome, false, spell)


## Resolves a melee ability against the target. Returns whether it landed.
func strike_with_ability(target: Combatant, damage: float) -> bool:
	return _resolve_melee(target, damage, CombatRules.roll_melee_ability(self, target))


## Resolves a harmful spell of a school (a SpellDB.School) against the
## target. Returns whether it landed.
func hit_with_spell(target: Combatant, damage: float, school := 0) -> bool:
	_engage(target)
	var outcome := CombatRules.roll_spell(self, target)
	if outcome == CombatRules.Outcome.RESIST:
		target.avoid(CombatRules.OUTCOME_TEXT[outcome], self)
		return false
	var crit := outcome == CombatRules.Outcome.CRIT
	var dealt := roundi(damage * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0))
	target.take_damage(dealt, self, crit, school)
	var ex := PROC_EX_CRIT if crit else PROC_EX_NORMAL
	proc_event.emit(PROC_NEGATIVE_SPELL, ex, target, {"School": school}, dealt)
	target.proc_event.emit(PROC_TAKEN_NEGATIVE_SPELL, ex, self, {"School": school}, dealt)
	return true


## `spell` is the heal, for the healer's procs (Hearten, Inner Light).
func heal_with_spell(amount: float, healer: Combatant = null, extra_crit := 0.0, spell: Dictionary = {}) -> void:
	var crit := CombatRules.roll_heal(healer if healer else self, extra_crit) == CombatRules.Outcome.CRIT
	if healer:
		var ex := PROC_EX_CRIT if crit else PROC_EX_NORMAL
		healer.proc_event.emit(PROC_POSITIVE_SPELL, ex, self, spell, roundi(amount))
		proc_event.emit(PROC_TAKEN_POSITIVE_SPELL, ex, healer, spell, roundi(amount))
	# Kindled Power raises healing done.
	if healer:
		amount *= 1.0 + healer.aura_total(SpellDB.AURA_MOD_HEALING_DONE_PERCENT) / 100.0
	heal(roundi(amount * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)), crit, healer)


## School is a SpellDB.School. Flat "damage taken" auras for that school (such
## as Judgement of the Crusader for Holy) add to the hit.
func take_damage(amount: int, source: Combatant, crit := false, school := 0) -> void:
	if not is_alive() or invulnerable:
		return
	if is_immune(school):
		avoid("Immune", source)
		return
	amount += int(aura_total(SpellDB.AURA_MOD_DAMAGE_TAKEN, 1 << school))
	# Percentage damage done (Kindled Power, Shroud of Shadow) and taken.
	var percent := 1.0 + aura_total(SpellDB.AURA_MOD_DAMAGE_PERCENT_TAKEN, 1 << school) / 100.0
	if source and is_instance_valid(source):
		percent *= 1.0 + source.damage_done_percent(school) / 100.0
	amount = maxi(roundi(amount * percent), 0)
	amount = _absorb(amount, school, source)
	enter_combat()
	if amount <= 0:
		return
	health = maxi(health - amount, 0)
	last_hit_school = school
	reward_rage(amount, false)
	took_damage.emit(amount, source, crit)
	if source and is_instance_valid(source) and amount > 0:
		source.dealt_damage.emit(self)
		source.damage_done.emit(self, amount, school)
	_break_on_damage(amount)
	if health == 0:
		attack_target = null
		_clear_auras_on_death()
		died.emit()
		if source and is_instance_valid(source):
			source.proc_event.emit(PROC_KILL, PROC_EX_NORMAL, self, {}, amount)


## Absorb shields (Sanctified Ward) soak damage of their schools until used up.
func _absorb(amount: int, school: int, source: Combatant) -> int:
	for aura in auras.duplicate():
		var spell: Dictionary = aura.spell
		for i in 3:
			if amount <= 0 or int(spell["EffectApplyAuraName%d" % (i + 1)]) != SpellDB.AURA_SCHOOL_ABSORB:
				continue
			if int(spell["EffectMiscValue%d" % (i + 1)]) & (1 << school) == 0:
				continue
			var soaked := mini(amount, int(aura.amounts[i]))
			aura.amounts[i] -= soaked
			amount -= soaked
			if amount <= 0:
				avoid("Absorb", source)
			if aura.amounts[i] <= 0:
				remove_aura(int(spell.Id))
	return amount


## Damage ends auras that break on it (Bind the Dead, Featherfall), and may
## break fear: the chance is the damage over 25 per level less 150 (at least
## 50), as HandleRemoveByDamageChanceProc in CMaNGOS.
func _break_on_damage(amount: int) -> void:
	if not is_alive():
		return
	var limit := 25.0 * level - 150.0 if level > 8 else 50.0
	for aura in auras.duplicate():
		var spell: Dictionary = aura.spell
		var breaks := int(spell.get("AuraInterruptFlags", 0)) & SpellDB.AURA_INTERRUPT_DAMAGE != 0
		if SpellDB.has_effect(spell, SpellDB.AURA_MOD_FEAR, true) and randf() * 100.0 < amount / limit * 100.0:
			breaks = true
		if breaks:
			remove_aura(int(spell.Id))
			if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
				_stun_left = 0.0


func avoid(text: String, source: Combatant) -> void:
	if is_alive() and not invulnerable:
		enter_combat()
		avoided.emit(text, source)


## The healer, when there is one, draws threat from the creatures fighting
## this unit.
func heal(amount: int, crit := false, healer: Combatant = null) -> void:
	if not is_alive():
		return
	# Feeble Hex lowers healing taken.
	amount = maxi(roundi(amount * (1.0 + aura_total(SpellDB.AURA_MOD_HEALING_PCT) / 100.0)), 0)
	var gained := mini(amount, max_health - health)
	health = mini(health + amount, max_health)
	healed.emit(amount, crit)
	if healer and healer.is_player and is_player and gained > 0:
		Enemy.add_heal_threat(self, healer, gained)


## Interrupts the spell this unit is casting, if any (an effect like Hilt
## Strike's): its school is locked for `lockout` seconds.
func interrupt_cast(lockout := 0.0) -> void:
	if is_alive() and is_casting:
		interrupt_requested.emit(lockout)


func stun(duration: float) -> void:
	if not is_alive() or invulnerable:
		return
	# Iron Resolve and Unbending Will: a chance to shrug stuns off.
	if randf() * 100.0 < aura_total_exact(AURA_MECHANIC_RESISTANCE, MECHANIC_STUN):
		avoid("Resist", null)
		return
	_stun_left = maxf(_stun_left, duration)
	stunned.emit()


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_stun_left = maxf(_stun_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)
	_combat_left = maxf(_combat_left - delta, 0.0)
	_off_swing_left = maxf(_off_swing_left - delta, 0.0)
	_since_mana_spent += delta
	_tick_auras(delta)

	if attack_target and (not is_instance_valid(attack_target) or not attack_target.is_alive()):
		attack_target = null
	var can_swing := attack_target and not is_stunned() and not is_pacified() and not is_feared() and not is_casting
	if can_swing and extra_attacks > 0 and distance_to(attack_target) <= melee_range:
		extra_attacks -= 1
		swung.emit(attack_target)
		var extra_target := attack_target
		if _resolve_melee(extra_target, roll_weapon_damage(), CombatRules.roll_auto_attack(self, extra_target), true):
			auto_attack_landed.emit(extra_target)
	elif not can_swing:
		extra_attacks = 0
	if can_swing and attack_target and faces(attack_target) and distance_to(attack_target) <= melee_range:
		if _swing_left == 0.0:
			swung.emit(attack_target)
			var target := attack_target
			if not (swing_replacer.is_valid() and swing_replacer.call(target)):
				if _resolve_melee(target, roll_weapon_damage(), CombatRules.roll_auto_attack(self, target), true):
					auto_attack_landed.emit(target)
			_swing_left = swing_interval * _creature_swing_factor()
		# The off hand swings on its own timer, for half damage.
		if off_swing_interval > 0.0 and _off_swing_left == 0.0 and attack_target:
			var target := attack_target
			# Two-Weapon Craft raises the off hand's share (SPELL_AURA_MOD_OFFHAND_DAMAGE_PCT).
			var share := OFF_HAND_DAMAGE * (1.0 + aura_total(AURA_MOD_OFFHAND_DAMAGE_PCT) / 100.0)
			var damage := (randf_range(off_min_damage, off_max_damage) + attack_power / 14.0 * off_swing_interval) * share
			if _resolve_melee(target, damage, CombatRules.roll_auto_attack(self, target), true):
				auto_attack_landed.emit(target)
			_off_swing_left = off_swing_interval


## Ground Slam slows a creature's swings (players' haste is in CharacterStats).
func _creature_swing_factor() -> float:
	if is_player:
		return 1.0
	var haste := aura_total(SpellDB.AURA_MOD_MELEE_HASTE)
	return 1.0 / (1.0 + haste / 100.0) if haste >= 0.0 else 1.0 - haste / 100.0


const TICK_KEYS := ["tick0", "tick1", "tick2"]


func _tick_auras(delta: float) -> void:
	var expired := false
	for aura in auras.duplicate():
		_tick_periodic(aura, delta)
		if aura.remaining > 0.0:
			aura.remaining -= delta
			expired = expired or aura.remaining <= 0.0
	if expired:
		# A negative duration means the aura lasts until cancelled.
		auras = auras.filter(func(aura: Dictionary) -> bool: return aura.duration < 0.0 or aura.remaining > 0.0)
		auras_changed.emit()


## Periodic effects tick every EffectAmplitude milliseconds: mana (Boon of
## Clarity), damage and healing over time, draining life (Ravening Blight)
## and spells triggered on each tick (Cleanse Sickness).
const PERIODIC_KINDS := [
	SpellDB.AURA_PERIODIC_ENERGIZE, SpellDB.AURA_PERIODIC_DAMAGE, SpellDB.AURA_PERIODIC_HEAL,
	SpellDB.AURA_PERIODIC_LEECH, SpellDB.AURA_PERIODIC_TRIGGER_SPELL, AURA_OBS_MOD_HEALTH,
]


## Each spell's periodic effects, [index, aura kind, period], worked out once.
static var _periodic_of: Dictionary = {}


static func _periodic_effects(spell: Dictionary) -> Array:
	var id := int(spell.get("Id", 0))
	if _periodic_of.has(id):
		return _periodic_of[id]
	var effects := []
	for i in 3:
		var kind := int(spell.get("EffectApplyAuraName%d" % (i + 1), 0))
		var period := int(spell.get("EffectAmplitude%d" % (i + 1), 0)) / 1000.0
		if kind in PERIODIC_KINDS and period > 0.0:
			effects.append([i, kind, period])
	if id != 0:
		_periodic_of[id] = effects
	return effects


func _tick_periodic(aura: Dictionary, delta: float) -> void:
	var spell: Dictionary = aura.spell
	for effect: Array in _periodic_effects(spell):
		var i: int = effect[0]
		var kind: int = effect[1]
		var period: float = effect[2]
		var key: String = TICK_KEYS[i]
		aura[key] = aura.get(key, 0.0) + delta
		while aura[key] >= period:
			aura[key] -= period
			var amount: float = aura.amounts[i]
			var caster: Combatant = aura.caster if is_instance_valid(aura.caster) else null
			if kind == SpellDB.AURA_PERIODIC_ENERGIZE:
				# Rage comes in tenths (Blood Fury's misc value 1 is rage).
				var rage := int(spell.get("EffectMiscValue%d" % (i + 1), 0)) == SpellDB.POWER_RAGE
				if rage == uses_rage():
					mana = minf(mana + (amount / 10.0 if rage else amount), max_mana)
			elif not is_alive():
				return
			elif kind == SpellDB.AURA_PERIODIC_HEAL:
				heal(roundi(amount), false, caster)
			elif kind == AURA_OBS_MOD_HEALTH:
				heal(roundi(max_health * amount / 100.0), false, caster)
			elif kind == SpellDB.AURA_PERIODIC_TRIGGER_SPELL:
				_triggered(SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0))))
			else:
				var before := health
				take_damage(roundi(amount), caster, false, int(spell.get("School", 0)))
				# Draining life heals the caster by what it took, times the effect's multiplier.
				if kind == SpellDB.AURA_PERIODIC_LEECH and caster and caster.is_alive():
					var multiplier := float(spell.get("EffectMultipleValue%d" % (i + 1), 1.0))
					caster.heal(roundi((before - health) * (multiplier if multiplier > 0.0 else 1.0)), false, caster)
			if not aura in auras:
				return


## A spell an aura on this unit triggers each tick. Only dispels so far
## (Cleanse Sickness Effect): one harmful effect of the type, from a creature.
func _triggered(spell: Dictionary) -> void:
	if int(spell.get("Effect1", 0)) != SpellDB.EFFECT_DISPEL:
		return
	var kind := int(spell.get("EffectMiscValue1", 0))
	for aura in auras:
		var caster: Combatant = aura.caster
		var from_creature := caster == null or not is_instance_valid(caster) or not caster.is_player
		if from_creature and int(aura.spell.get("Dispel", 0)) == kind:
			remove_aura(int(aura.spell.Id))
			return


func _engage(target: Combatant) -> void:
	enter_combat()
	target.enter_combat()


## `white` marks an auto-attack swing, which earns rage.
func _resolve_melee(target: Combatant, damage: float, outcome: CombatRules.Outcome, white := false, spell: Dictionary = {}) -> bool:
	_engage(target)
	# Procs see a plain swing or an ability, and how it went.
	var dealt := PROC_MELEE_HIT if spell.is_empty() else PROC_MELEE_ABILITY
	var taken := PROC_TAKEN_MELEE_HIT if spell.is_empty() else PROC_TAKEN_MELEE_ABILITY
	match outcome:
		CombatRules.Outcome.MISS, CombatRules.Outcome.DODGE, CombatRules.Outcome.PARRY:
			target.avoid(CombatRules.OUTCOME_TEXT[outcome], self)
			if outcome != CombatRules.Outcome.MISS:
				attack_avoided.emit(target, CombatRules.OUTCOME_TEXT[outcome])
			var avoided_ex: int = {CombatRules.Outcome.MISS: PROC_EX_MISS, CombatRules.Outcome.DODGE: PROC_EX_DODGE}.get(outcome, PROC_EX_PARRY)
			proc_event.emit(dealt, avoided_ex, target, spell, 0)
			target.proc_event.emit(taken, avoided_ex, self, spell, 0)
			return false
		CombatRules.Outcome.GLANCE:
			damage *= CombatRules.glance_multiplier(self, target)
		CombatRules.Outcome.CRIT:
			# Deep Thrust raises an ability's crit bonus (SpellMods CRIT_DAMAGE_BONUS).
			var bonus := (CombatRules.MELEE_CRIT_MULTIPLIER - 1.0) * (1.0 + SpellMods.percent(self, spell, SpellMods.CRIT_DAMAGE_BONUS) / 100.0)
			damage *= 1.0 + bonus
		CombatRules.Outcome.CRUSH:
			damage *= CRUSH_MULTIPLIER
	damage = CombatRules.reduce_by_armor(damage, target, self)
	var ex := PROC_EX_CRIT if outcome == CombatRules.Outcome.CRIT else PROC_EX_NORMAL
	if outcome == CombatRules.Outcome.BLOCK:
		target.blocked_attack.emit(self)
		attack_avoided.emit(target, CombatRules.OUTCOME_TEXT[outcome])
		damage = maxf(damage - target.block_value, 0.0)
		ex = PROC_EX_BLOCK | (PROC_EX_NORMAL if damage > 0.0 else 0)
		if damage <= 0.0:
			target.avoid(CombatRules.OUTCOME_TEXT[outcome], self)
			proc_event.emit(dealt, ex, target, spell, 0)
			target.proc_event.emit(taken, ex, self, spell, 0)
			return true
	if white:
		reward_rage(roundi(damage), true)
	target.take_damage(roundi(damage), self, outcome == CombatRules.Outcome.CRIT)
	if target.is_alive():
		target.melee_hit_taken.emit(self)
	proc_event.emit(dealt, ex, target, spell, roundi(damage))
	target.proc_event.emit(taken, ex, self, spell, roundi(damage))
	return true
