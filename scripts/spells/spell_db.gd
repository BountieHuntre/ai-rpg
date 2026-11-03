class_name SpellDB
extends RefCounted
## Classic WoW (1.12) spell data from data/classic/spells.json: spell_template
## rows, rank chains, spell power coefficients, class trainer lists and
## starting spells, plus the small client lookup tables spells refer to.

const SPELLS_PATH := "res://data/classic/spells.json"

## Spell ids with special meaning.
const ATTACK := 6603
const HOLY_LIGHT_HEAL := 19968

enum School { PHYSICAL, HOLY, FIRE, NATURE, FROST, SHADOW, ARCANE }
const SCHOOL_NAMES := ["Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane"]

## spell_template Effect values used here.
const EFFECT_SCHOOL_DAMAGE := 2
const EFFECT_DUMMY := 3
const EFFECT_APPLY_AURA := 6
const EFFECT_HEAL := 10
const EFFECT_PERSISTENT_AREA_AURA := 27
const EFFECT_ENERGIZE := 30
const EFFECT_WEAPON_PERCENT_DAMAGE := 31
const EFFECT_APPLY_AREA_AURA := 35
const EFFECT_PROFICIENCY := 60
const EFFECT_SCRIPT := 77
const EFFECT_RESURRECT := 113
## Aura types (EffectApplyAuraName) used here.
const AURA_PERIODIC_DAMAGE := 3
const AURA_DUMMY := 4
const AURA_MOD_ATTACK_SPEED := 9
const AURA_MOD_STUN := 12
const AURA_MOD_DAMAGE_TAKEN := 14
const AURA_DAMAGE_SHIELD := 15
const AURA_PERIODIC_ENERGIZE := 24
const AURA_MOD_RESISTANCE := 22
const AURA_MOD_PACIFY := 25
const AURA_SCHOOL_IMMUNITY := 39
const AURA_PROC_TRIGGER_SPELL := 42
const AURA_PROC_TRIGGER_DAMAGE := 43
const AURA_MOD_BLOCK_PERCENT := 51
const AURA_MOD_ATTACK_POWER := 99
const AURA_MOD_TOTAL_STAT_PERCENTAGE := 137
const AURA_MOD_MELEE_HASTE := 138
const AURA_RESIST_PUSHBACK := 149
## Food (health) and drink (mana per 5 seconds).
const AURA_MOD_REGEN := 84
const AURA_MOD_POWER_REGEN := 85
## AuraInterruptFlags: the aura ends when the unit stands up.
const AURA_INTERRUPT_NOT_SEATED := 0x80
const EFFECT_DISPEL := 38
const EFFECT_HEAL_MAX_HEALTH := 67
## Attributes / AttributesEx flags.
const ATTR_PASSIVE := 0x40
const ATTR_CANT_USE_IN_COMBAT := 0x10000000
const ATTR_EX_DRAIN_ALL_POWER := 0x2
## Implicit targets.
const TARGET_SELF := 1
const TARGET_ENEMY := 6
const TARGET_FRIEND := 21
## Enemies around the caster, and any unit (Holy Shock: a foe or a friend).
const TARGET_ENEMIES_AROUND := 22
const TARGET_ANY := 25
## creature_template CreatureType values some spells care about.
const CREATURE_DEMON := 3
const CREATURE_UNDEAD := 6
## AttributesEx2 / AttributesEx3 flags.
const ATTR_EX2_CANT_CRIT := 0x20000000
const ATTR_EX3_ALWAYS_HIT := 0x40000
const ATTR_EX3_DEATH_PERSISTENT := 0x100000
## SPELL_AURA_MOD_SHAPESHIFT: stances and forms.
const AURA_MOD_SHAPESHIFT := 36

## Client DBC lookup tables, for the indexes classic Paladin spells use.
## Values match the classic spell tooltips (Holy Light 2.5 s, Flash of Light
## 1.5 s, seals 30 s, Hammer of Justice rank 1 3 s, Judgement 10 yards).
## Cast times and durations in seconds, ranges and radii in yards.
const CAST_TIMES := { 1: 0.0, 4: 1.0, 5: 2.0, 7: 10.0, 16: 1.5, 20: 2.5 }
## -1 means until cancelled.
const DURATIONS := {
	0: 0.0, 1: 10.0, 5: 300.0, 8: 15.0, 9: 30.0, 18: 20.0, 21: -1.0, 25: 180.0, 27: 3.0,
	28: 5.0, 29: 12.0, 30: 1800.0, 31: 8.0, 32: 6.0, 35: 4.0, 39: 2.0, 85: 18.0, 86: 21.0, 347: 900.0,
}
const RANGES := { 1: 0.0, 2: 5.0, 3: 20.0, 4: 30.0, 5: 40.0, 6: 100.0, 7: 10.0, 13: 50000.0 }
const RADII := { 0: 0.0, 9: 20.0, 10: 30.0, 12: 100.0, 14: 8.0 }

static var _data: Dictionary


static func get_spell(id: int) -> Dictionary:
	if id == ATTACK:
		return { "Id": ATTACK, "SpellName": "Attack", "Rank1": "", "School": 0 }
	return _get_data().spells.get(str(id), {})


static func full_name(spell: Dictionary) -> String:
	return spell.SpellName if str(spell.Rank1).is_empty() else "%s (%s)" % [spell.SpellName, spell.Rank1]


## An effect's value at the caster's level: base points plus a die roll, plus
## RealPointsPerLevel for each level past the spell level (up to MaxLevel).
## As in Unit::CalculateSpellEffectValue.
static func effect_value(spell: Dictionary, effect: int, caster_level: int) -> float:
	var range_ := effect_range(spell, effect, caster_level)
	return range_.x if range_.y <= range_.x else float(randi_range(int(range_.x), int(range_.y)))


## The lowest and highest value an effect can roll at a level.
static func effect_range(spell: Dictionary, effect: int, caster_level: int) -> Vector2:
	var i := effect + 1
	var level := caster_level
	if int(spell.MaxLevel) > 0:
		level = mini(level, int(spell.MaxLevel))
	var levels_over := maxi(level, int(spell.BaseLevel)) - int(spell.SpellLevel)
	var base := float(spell["EffectBasePoints%d" % i]) + float(spell["EffectRealPointsPerLevel%d" % i]) * levels_over
	var low := int(spell["EffectBaseDice%d" % i])
	var high := maxi(int(spell["EffectDieSides%d" % i]), low)
	return Vector2(floorf(base) + low, floorf(base) + high)


static func cast_time(spell: Dictionary) -> float:
	return CAST_TIMES.get(int(spell.get("CastingTimeIndex", 1)), 0.0)


static func duration(spell: Dictionary) -> float:
	return DURATIONS.get(int(spell.get("DurationIndex", 0)), 0.0)


static func spell_range(spell: Dictionary) -> float:
	return RANGES.get(int(spell.get("RangeIndex", 1)), 0.0)


## Mana cost, either flat or a percentage of the caster's base mana.
static func mana_cost(spell: Dictionary, base_mana: int) -> int:
	var percent := int(spell.get("ManaCostPercentage", 0))
	if percent > 0:
		return base_mana * percent / 100
	return int(spell.get("ManaCost", 0))


## Cooldown in seconds, not counting the global cooldown.
static func cooldown(spell: Dictionary) -> float:
	return maxf(int(spell.get("RecoveryTime", 0)), int(spell.get("CategoryRecoveryTime", 0))) / 1000.0


static func global_cooldown(spell: Dictionary) -> float:
	return int(spell.get("StartRecoveryTime", 0)) / 1000.0


static func target_type(spell: Dictionary) -> int:
	return int(spell.get("EffectImplicitTargetA1", TARGET_SELF))


static func is_seal(spell: Dictionary) -> bool:
	return str(spell.SpellName).begins_with("Oath of") and int(spell.Effect1) == EFFECT_APPLY_AURA


## The judgement a seal unleashes: effect 3's base points plus one, or 0.
static func seal_judgement(seal: Dictionary) -> int:
	if int(seal.get("Effect3", 0)) == EFFECT_APPLY_AURA and int(seal.EffectApplyAuraName3) == AURA_DUMMY:
		return int(seal.EffectBasePoints3) + 1
	return 0


## Paladin auras (one at a time) and blessings (one per Paladin per target).
static func is_paladin_aura(spell: Dictionary) -> bool:
	return str(spell.SpellName).ends_with(" Presence") and int(spell.Effect1) == EFFECT_APPLY_AREA_AURA


static func is_blessing(spell: Dictionary) -> bool:
	return str(spell.SpellName).begins_with("Boon of") or str(spell.SpellName).begins_with("Greater Boon of")


## A proc's rate from spell_proc_event, for a spell or its first rank:
## { "ppm": procs per minute, "chance": percent, "cooldown": seconds }, or {}.
static func proc_info(spell: Dictionary) -> Dictionary:
	var procs: Dictionary = _get_data().get("procs", {})
	var id := int(spell.get("Id", 0))
	return procs.get(str(id), procs.get(str(first_rank(id)), {}))


## The heal or mana spell a Judgement of Light or Wisdom rank procs, or 0.
static func judgement_proc_spell(judgement_id: int) -> int:
	return int(_get_data().get("judgement_procs", {}).get(str(judgement_id), 0))


## Holy Shock's [damage spell, heal spell] for a rank.
static func holy_shock_spells(id: int) -> Array:
	return _get_data().get("holy_shock", {}).get(str(id), [])


## The radius of a spell's effect in yards.
static func effect_radius(spell: Dictionary, effect := 0) -> float:
	return RADII.get(int(spell.get("EffectRadiusIndex%d" % (effect + 1), 0)), 0.0)


static func is_passive(spell: Dictionary) -> bool:
	return int(spell.get("Attributes", 0)) & ATTR_PASSIVE != 0


## The previous rank of a spell, or 0.
static func previous_rank(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("prev", 0))


static func has_attribute_ex2(spell: Dictionary, flag: int) -> bool:
	return int(spell.get("AttributesEx2", 0)) & flag != 0


## Auras kept through death. Classic keeps only SPELL_ATTR_EX3_DEATH_PERSISTENT
## ones (Unit::RemoveAllAurasOnDeath); here paladin auras and stances stay up
## too, so they needn't be recast after every death.
static func persists_through_death(spell: Dictionary) -> bool:
	return (
		is_paladin_aura(spell)
		or has_attribute_ex3(spell, ATTR_EX3_DEATH_PERSISTENT)
		or int(spell.get("EffectApplyAuraName1", 0)) == AURA_MOD_SHAPESHIFT
	)


static func has_attribute_ex3(spell: Dictionary, flag: int) -> bool:
	return int(spell.get("AttributesEx3", 0)) & flag != 0


## Spell power coefficient for direct damage or healing, from spell_bonus_data.
static func direct_coefficient(id: int) -> float:
	return float(_get_data().bonus.get(str(id), {}).get("direct", 0.0))


static func seal_of_righteousness_proc(seal_id: int) -> int:
	return int(_get_data().seal_of_righteousness_procs.get(str(seal_id), 0))


static func start_spells(race: int, char_class: int) -> Array:
	return _get_data().start_spells.get("%d-%d" % [race, char_class], [])


static func trainer_list(trainer: String) -> Array:
	return _get_data().trainers.get(trainer, [])


## Rank number within its chain, or 0 for spells without ranks.
static func rank_of(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("rank", 0))


static func first_rank(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("first", id))


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(SPELLS_PATH))
	return _data
