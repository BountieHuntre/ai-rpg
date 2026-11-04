class_name SpellDB
extends RefCounted
## Classic WoW (1.12) spell data from data/classic/spells.json: spell_template
## rows, rank chains, spell power coefficients, class trainer lists and
## starting spells, plus the small client lookup tables spells refer to.

const SPELLS_PATH := "res://data/classic/spells.json"

## Spell ids with special meaning.
const ATTACK := 6603
const HOLY_LIGHT_HEAL := 19968
## Spent Soul, which Sanctified Ward leaves on its target.
const WEAKENED_SOUL := 6788

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
const AURA_MOD_THREAT := 10
const AURA_MOD_TAUNT := 11
const AURA_MOD_INCREASE_HEALTH := 34
const AURA_MOD_CRIT_PERCENT := 52
const AURA_MOD_DISARM := 67
const AURA_MOD_RESISTANCE_PCT := 101
const AURA_MOD_FEAR := 7
const AURA_PERIODIC_HEAL := 8
const AURA_MOD_DAMAGE_DONE := 13
const AURA_PERIODIC_TRIGGER_SPELL := 23
const AURA_MOD_SILENCE := 27
const AURA_MOD_STAT := 29
const AURA_MOD_INCREASE_SPEED := 31
const AURA_MOD_DECREASE_SPEED := 33
const AURA_MOD_DODGE_PERCENT := 49
const AURA_PERIODIC_LEECH := 53
const AURA_SCHOOL_ABSORB := 69
const AURA_MECHANIC_IMMUNITY := 77
const AURA_MOD_DAMAGE_PERCENT_DONE := 79
const AURA_MOD_DAMAGE_PERCENT_TAKEN := 87
const AURA_MOD_DETECT_RANGE := 91
const AURA_MOD_TOTAL_THREAT := 103
const AURA_FEATHER_FALL := 105
const AURA_ADD_FLAT_MODIFIER := 107
const AURA_ADD_PCT_MODIFIER := 108
const AURA_MOD_HEALING_PCT := 118
const AURA_MOD_HEALING_DONE_PERCENT := 136
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
## Melee abilities: weapon damage plus a bonus (Mighty Blow), the same with
## the weapon speed normalized (Riposte Strike), a charge, a taunt, an
## interrupt and a triggered spell.
const EFFECT_WEAPON_DAMAGE_NOSCHOOL := 17
const EFFECT_NORMALIZED_WEAPON_DMG := 121
const EFFECT_CHARGE := 96
const EFFECT_ATTACK_ME := 114
const EFFECT_INTERRUPT_CAST := 68
const EFFECT_TRIGGER_SPELL := 64
## Spell power types: mana, rage, and health (Blood Fury costs health).
const POWER_MANA := 0
const POWER_RAGE := 1
const POWER_HEALTH := 4294967294
const EFFECT_POWER_BURN := 62
## AuraInterruptFlags: the aura ends when the unit takes damage.
const AURA_INTERRUPT_DAMAGE := 0x2
const EFFECT_HEAL_MAX_HEALTH := 67
## Attributes / AttributesEx flags.
const ATTR_PASSIVE := 0x40
## Mighty Blow and Sweeping Cut wait for the next melee swing.
const ATTR_ON_NEXT_SWING := 0x4
const ATTR_CANT_USE_IN_COMBAT := 0x10000000
const ATTR_EX_DRAIN_ALL_POWER := 0x2
## Channeled spells: the caster holds still while the effect lasts.
const ATTR_EX_CHANNELED_1 := 0x4
const ATTR_EX_CHANNELED_2 := 0x40
## Implicit targets.
const TARGET_SELF := 1
const TARGET_ENEMY := 6
const TARGET_FRIEND := 21
## The caster's party around them (Prayer of Healing), enemies around the
## caster, the caster's party (Prayer of Spirit), and any unit (Holy Shock: a
## foe or a friend).
const TARGET_PARTY_AROUND := 20
const TARGET_ENEMIES_AROUND := 22
const TARGET_PARTY := 37
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
## Cleric spells add 14 (3 s: Mending), 19 (2.5 s: Chastise), 22 (3.5 s:
## Sacred Flame), and durations 3 (1 min), 4 (2 min), 6 (10 min), 42 (1 hour),
## 64 (40 s: Bind the Dead rank 2) and 106 (24 s: Ravening Blight). The
## Man-at-Arms adds durations 36 (1 s: Rush Stun), 105 (9 s: Gash rank 1) and
## 305, 467, 468 (14, 22 and 26 s: Ground Slam), and range 95 (8 to 25 yards).
const CAST_TIMES := { 1: 0.0, 4: 1.0, 5: 2.0, 7: 10.0, 14: 3.0, 16: 1.5, 19: 2.5, 20: 2.5, 22: 3.5 }
## -1 means until cancelled.
const DURATIONS := {
	0: 0.0, 1: 10.0, 3: 60.0, 4: 120.0, 5: 300.0, 6: 600.0, 8: 15.0, 36: 1.0, 105: 9.0, 305: 14.0, 467: 22.0, 468: 26.0, 9: 30.0, 18: 20.0, 21: -1.0, 25: 180.0, 27: 3.0,
	28: 5.0, 29: 12.0, 30: 1800.0, 31: 8.0, 32: 6.0, 35: 4.0, 39: 2.0, 42: 3600.0, 64: 40.0, 85: 18.0,
	86: 21.0, 106: 24.0, 347: 900.0,
}
const RANGES := { 1: 0.0, 2: 5.0, 3: 20.0, 4: 30.0, 5: 40.0, 6: 100.0, 7: 10.0, 13: 50000.0, 95: 25.0 }
## Least ranges: Rush needs room to run.
const MIN_RANGES := { 95: 8.0 }
const RADII := { 0: 0.0, 7: 2.0, 9: 20.0, 10: 30.0, 12: 100.0, 13: 10.0, 14: 8.0 }

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


static func min_range(spell: Dictionary) -> float:
	return MIN_RANGES.get(int(spell.get("RangeIndex", 1)), 0.0)


## Whether a spell costs rage (its ManaCost is in tenths of a rage point).
static func uses_rage(spell: Dictionary) -> bool:
	return int(spell.get("PowerType", POWER_MANA)) == POWER_RAGE


## The stance (shapeshift form) a spell puts you in, or 0: 17 Vanguard, 18
## Bastion, 19 Fury, 28 Shroud of Shadow.
static func stance_form(spell: Dictionary) -> int:
	for i in 3:
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == AURA_MOD_SHAPESHIFT:
			return int(spell.get("EffectMiscValue%d" % (i + 1), 0))
	return 0


## Spells on the stance bar: Presences, stances and forms.
static func is_stance_bar_spell(spell: Dictionary) -> bool:
	return is_paladin_aura(spell) or stance_form(spell) != 0


## Mana cost, either flat or a percentage of the caster's base mana.
## Rage costs come out in whole rage points; health costs (Blood Fury) aren't
## a power cost and come out as 0.
static func mana_cost(spell: Dictionary, base_mana: int) -> int:
	if int(spell.get("PowerType", POWER_MANA)) == POWER_HEALTH:
		return 0
	if uses_rage(spell):
		return int(spell.get("ManaCost", 0)) / 10
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


static func is_channeled(spell: Dictionary) -> bool:
	return int(spell.get("AttributesEx", 0)) & (ATTR_EX_CHANNELED_1 | ATTR_EX_CHANNELED_2) != 0


## Whether a spell has an effect of a kind (an Effect value) or an aura of a
## kind (an EffectApplyAuraName value, with aura = true).
static func has_effect(spell: Dictionary, kind: int, aura := false) -> bool:
	for i in 3:
		var field := "EffectApplyAuraName%d" % (i + 1) if aura else "Effect%d" % (i + 1)
		if int(spell.get(field, 0)) == kind:
			return true
	return false


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
		# A stance's passive stays with it.
		or str(spell.get("SpellName", "")).ends_with("Stance Passive")
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


## The class each trainer list teaches (code keeps classic's class names).
const TRAINER_CLASSES := {
	"warrior": ClassicData.CharClass.WARRIOR,
	"paladin": ClassicData.CharClass.PALADIN,
	"priest": ClassicData.CharClass.PRIEST,
}


## A trainer's whole list. Pass a race to leave out other races' spells
## (entries with a "races" list, such as the Cleric's racial spells).
static func trainer_list(trainer: String, race := 0) -> Array:
	var list: Array = _get_data().trainers.get(trainer, [])
	if race == 0:
		return list
	return list.filter(func(entry: Dictionary) -> bool:
		return not entry.has("races") or race in (entry.races as Array).map(func(r: Variant) -> int: return int(r)))


## The trainer list for a class's own trainer, for one race.
static func class_trainer_list(char_class: int, race: int) -> Array:
	var trainer: String = TRAINER_CLASSES.find_key(char_class) if TRAINER_CLASSES.values().has(char_class) else ""
	return [] if trainer.is_empty() else trainer_list(trainer, race)


## Classes with spells in the game.
static func classes_with_spells() -> Array:
	return TRAINER_CLASSES.values()


## Linked spell another spell casts (Holy Nova's heal, Touch of Weakness's damage...), or 0.
static func linked_spell(id: int) -> int:
	return int(_get_data().get("links", {}).get(str(id), 0))


## Rank number within its chain, or 0 for spells without ranks.
static func rank_of(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("rank", 0))


static func first_rank(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("first", id))


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(SPELLS_PATH))
	return _data
