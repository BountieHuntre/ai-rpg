class_name SpellMods
extends RefCounted
## Spell modifiers: talents that change the caster's own spells (SPELL_AURA_ADD_FLAT_MODIFIER
## and ADD_PCT_MODIFIER). Each modifier names an operation (its misc value) and
## the spells it touches by a mask over their SpellFamilyFlags (its effect's
## EffectItemType), within the caster's spell family. As Player::ApplySpellMod
## in CMaNGOS: flat amounts add up, percentages add up, and the result is
## (value + flat) * (100 + percent) / 100.

## SpellModOp (SpellDefines.h).
const DAMAGE := 0
const DURATION := 1
const THREAT := 2
const ATTACK_POWER := 3
const CHARGES := 4
const RANGE := 5
const RADIUS := 6
const CRITICAL_CHANCE := 7
const ALL_EFFECTS := 8
const NOT_LOSE_CASTING_TIME := 9
const CASTING_TIME := 10
const COOLDOWN := 11
const COST := 14
const CRIT_DAMAGE_BONUS := 15
const RESIST_MISS_CHANCE := 16
const DOT := 22

const AURA_FLAT := 107
const AURA_PCT := 108


## A value of the spell after the caster's modifiers for an operation.
static func apply(caster: Combatant, spell: Dictionary, op: int, value: float) -> float:
	var totals := _totals(caster, spell, op)
	if totals.x == 0.0 and totals.y == 0.0:
		return value
	return (value + totals.x) * maxf(100.0 + totals.y, 0.0) / 100.0


## Just the flat part (for chances in percent, like crit: +x%).
static func flat(caster: Combatant, spell: Dictionary, op: int) -> float:
	return _totals(caster, spell, op).x


## Just the percentage part.
static func percent(caster: Combatant, spell: Dictionary, op: int) -> float:
	return _totals(caster, spell, op).y


## (flat, percent) of the caster's modifiers for an operation on the spell.
static func _totals(caster: Combatant, spell: Dictionary, op: int) -> Vector2:
	var totals := Vector2.ZERO
	if caster == null or not is_instance_valid(caster) or not caster.is_player or spell.is_empty():
		return totals
	var flags := int(spell.get("SpellFamilyFlags", 0))
	if flags == 0:
		return totals
	var family := int(spell.get("SpellFamilyName", 0))
	for aura in caster.auras:
		var mod: Dictionary = aura.spell
		if int(mod.get("SpellFamilyName", 0)) != family:
			continue
		for i in 3:
			var kind := int(mod.get("EffectApplyAuraName%d" % (i + 1), 0))
			if kind != AURA_FLAT and kind != AURA_PCT:
				continue
			if int(mod.get("EffectMiscValue%d" % (i + 1), -1)) != op:
				continue
			if int(mod.get("EffectItemType%d" % (i + 1), 0)) & flags == 0:
				continue
			if kind == AURA_FLAT:
				totals.x += aura.amounts[i]
			else:
				totals.y += aura.amounts[i]
	return totals
