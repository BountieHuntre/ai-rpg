class_name SpellDB
extends RefCounted
## Classic WoW (1.12) spell data from data/classic/spells.json: spell_template
## rows, rank chains, spell power coefficients, class trainer lists and
## starting spells, plus the small client lookup tables spells refer to.

const SPELLS_PATH := "res://data/classic/spells.json"

## Spell ids with special meaning.
const ATTACK := 6603
## Shoot: repeating shots with the ranged weapon (bow, gun, thrown weapon or
## wand), toggled like Attack and known by everyone (classic's wand Shoot id;
## classic's Shoot spells aren't in the data).
const SHOOT := 5019
## Menus of spells on one button (see is_flyout).
const BOONS := 1000001
const GREATER_BOONS := 1000002
const FLYOUTS := {
	BOONS: { "name": "Boons", "prefix": "Boon of" },
	GREATER_BOONS: { "name": "Greater Boons", "prefix": "Greater Boon of" },
}
## SpellFamilyName of the classes' own spells (mage to paladin and shaman).
## 12 is the Spellsword's, the game's own class (ClassicData.CLASS_FILES).
const CLASS_SPELL_FAMILIES := [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const LONG_BUFF_FROM := 300.0
const LONG_BUFF := 3600.0
const LONG_BUFF_DURATION_INDEX := 42
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
const AURA_MOD_INCREASE_HEALTH_PERCENT := 133
const AURA_MOD_POWER_REGEN_PERCENT := 110
## Monster Hunter and Manhunter: damage and crit damage against creature
## types (misc value a mask of 1 << (CreatureType - 1)).
const AURA_MOD_DAMAGE_DONE_VERSUS := 168
const AURA_MOD_CRIT_DAMAGE_VERSUS := 169
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
## Pets' focus (their abilities' cost).
const POWER_FOCUS := 2
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
## The game's own aura types (no classic number), for the Spellsword's
## talents: stuns and fears on the unit last this many percent shorter
## (Steadfast Glyphs), and critical strikes on it deal this many percent less
## (Rooted Stance). Read by Combatant.
const AURA_CONTROL_DURATION_PCT := 1001
const AURA_CRIT_DAMAGE_TAKEN_PCT := 1002
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
## Harrowfield adds duration 205 (27 s: its finer food and drink) and range
## 12 (5 yards, Interact Range: Grunmaw's Head Butt).
const CAST_TIMES := { 1: 0.0, 4: 1.0, 5: 2.0, 6: 5.0, 7: 10.0, 14: 3.0, 16: 1.5, 19: 2.5, 20: 2.5, 22: 3.5 }
## -1 means until cancelled.
const DURATIONS := {
	0: 0.0, 1: 10.0, 3: 60.0, 4: 120.0, 5: 300.0, 6: 600.0, 8: 15.0, 36: 1.0, 105: 9.0, 305: 14.0, 467: 22.0, 468: 26.0, 9: 30.0, 18: 20.0, 21: -1.0, 25: 180.0, 27: 3.0,
	28: 5.0, 29: 12.0, 30: 1800.0, 31: 8.0, 32: 6.0, 35: 4.0, 39: 2.0, 42: 3600.0, 64: 40.0, 85: 18.0,
	86: 21.0, 106: 24.0, 205: 27.0, 347: 900.0,
}
## The Spellsword's own: 901 (25 yards: Hurl Blade), 902 (8 to 20 yards: Phase Step).
## 114: the Ranger's shots and stings, 8 to 35 yards (SpellRange.dbc).
const RANGES := { 1: 0.0, 2: 5.0, 3: 20.0, 4: 30.0, 5: 40.0, 6: 100.0, 7: 10.0, 11: 15.0, 12: 5.0, 13: 50000.0, 35: 35.0, 95: 25.0, 114: 35.0, 901: 25.0, 902: 20.0 }
## Least ranges: Rush needs room to run.
const MIN_RANGES := { 95: 8.0, 114: 8.0, 902: 8.0 }
const RADII := { 0: 0.0, 7: 2.0, 9: 20.0, 10: 30.0, 12: 100.0, 13: 10.0, 14: 8.0 }

static var _data: Dictionary


static func get_spell(id: int) -> Dictionary:
	if id == ATTACK:
		return { "Id": ATTACK, "SpellName": "Attack", "Rank1": "", "School": 0 }
	if id == SHOOT:
		return { "Id": SHOOT, "SpellName": "Shoot", "Rank1": "", "School": 0 }
	if FLYOUTS.has(id):
		return { "Id": id, "SpellName": FLYOUTS[id].name, "Rank1": "", "School": School.HOLY, "Flyout": true }
	return _get_data().spells.get(str(id), {})


static func full_name(spell: Dictionary) -> String:
	return spell.SpellName if str(spell.Rank1).is_empty() else "%s (%s)" % [spell.SpellName, spell.Rank1]


## An effect's value at the caster's level: base points plus a die roll, plus
## RealPointsPerLevel for each level past the spell level (up to MaxLevel).
## As in Unit::CalculateSpellEffectValue. A caster's talents that change all
## of a spell's effects (SpellMods ALL_EFFECTS, and ATTACK_POWER for attack
## power auras) apply when the caster is given.
static func effect_value(spell: Dictionary, effect: int, caster_level: int, caster: Combatant = null) -> float:
	var range_ := effect_range(spell, effect, caster_level)
	var value := range_.x if range_.y <= range_.x else float(randi_range(int(range_.x), int(range_.y)))
	if caster == null:
		return value
	value = SpellMods.apply(caster, spell, SpellMods.ALL_EFFECTS, value)
	# Trailblazing: speed auras' speed.
	if int(spell.get("EffectApplyAuraName%d" % (effect + 1), 0)) == AURA_MOD_INCREASE_SPEED:
		value = SpellMods.apply(caster, spell, SpellMods.SPEED, value)
	if int(spell.get("EffectApplyAuraName%d" % (effect + 1), 0)) == AURA_MOD_ATTACK_POWER:
		value = SpellMods.apply(caster, spell, SpellMods.ATTACK_POWER, value)
	return value


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


## Cast time, duration, range and the rest take an optional caster, whose
## talents may change them (SpellMods; times in the modifiers are milliseconds).
static func cast_time(spell: Dictionary, caster: Combatant = null) -> float:
	var time: float = CAST_TIMES.get(int(spell.get("CastingTimeIndex", 1)), 0.0)
	if caster == null or time <= 0.0:
		return time
	return maxf(SpellMods.apply(caster, spell, SpellMods.CASTING_TIME, time * 1000.0) / 1000.0, 0.0)


static func duration(spell: Dictionary, caster: Combatant = null) -> float:
	var length: float = DURATIONS.get(int(spell.get("DurationIndex", 0)), 0.0)
	if caster == null or length <= 0.0:
		return length
	return maxf(SpellMods.apply(caster, spell, SpellMods.DURATION, length * 1000.0) / 1000.0, 0.0)


static func spell_range(spell: Dictionary, caster: Combatant = null) -> float:
	var reach: float = RANGES.get(int(spell.get("RangeIndex", 1)), 0.0)
	return SpellMods.apply(caster, spell, SpellMods.RANGE, reach) if caster and reach > 5.0 else reach


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


## Spells on the stance bar: Presences, Spirits, stances and forms.
static func is_stance_bar_spell(spell: Dictionary) -> bool:
	return is_paladin_aura(spell) or is_aspect(spell) or stance_form(spell) != 0


## The Ranger's Spirits (classic's Aspects): one at a time.
const ASPECTS := ["Hawk Spirit", "Monkey Spirit", "Cheetah Spirit", "Pack Spirit", "Beast Spirit", "Wild Spirit"]


static func is_aspect(spell: Dictionary) -> bool:
	return str(spell.get("SpellName", "")) in ASPECTS


## A trap object's spell and radius (spells.json "traps", from
## gameobject_template), by object entry: { "spell", "radius" }, or {}.
static func trap(entry: int) -> Dictionary:
	return _get_data().get("traps", {}).get(str(entry), {})


## Mana cost, either flat or a percentage of the caster's base mana.
## Rage costs come out in whole rage points; health costs (Blood Fury) aren't
## a power cost and come out as 0.
## A caster's talents may lower it (SpellMods COST, applied in tenths of rage
## for rage abilities, as the data has them).
static func mana_cost(spell: Dictionary, base_mana: int, caster: Combatant = null) -> int:
	if int(spell.get("PowerType", POWER_MANA)) == POWER_HEALTH:
		return 0
	var cost := float(spell.get("ManaCost", 0))
	var percent := int(spell.get("ManaCostPercentage", 0))
	if percent > 0 and not uses_rage(spell):
		cost = base_mana * percent / 100
	if caster:
		cost = maxf(SpellMods.apply(caster, spell, SpellMods.COST, cost), 0.0)
	return int(cost) / 10 if uses_rage(spell) else int(cost)


## Cooldown in seconds, not counting the global cooldown.
static func cooldown(spell: Dictionary, caster: Combatant = null) -> float:
	var ms := maxf(int(spell.get("RecoveryTime", 0)), int(spell.get("CategoryRecoveryTime", 0)))
	if caster and ms > 0.0:
		ms = maxf(SpellMods.apply(caster, spell, SpellMods.COOLDOWN, ms), 0.0)
	return ms / 1000.0


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
static func effect_radius(spell: Dictionary, effect := 0, caster: Combatant = null) -> float:
	var radius: float = RADII.get(int(spell.get("EffectRadiusIndex%d" % (effect + 1), 0)), 0.0)
	return SpellMods.apply(caster, spell, SpellMods.RADIUS, radius) if caster and radius > 0.0 else radius


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
	"hunter": ClassicData.CharClass.HUNTER,
	"spellsword": ClassicData.CharClass.SPELLSWORD,
}


## A trainer's whole list. Pass a race to leave out other races' spells
## (entries with a "races" list, such as the Cleric's racial spells), and a
## class to leave out what it can't learn (entries with a "classes" mask: the
## Weapon Master's skills).
static func trainer_list(trainer: String, race := 0, char_class := 0) -> Array:
	var list: Array = _get_data().trainers.get(trainer, [])
	if race == 0 and char_class == 0:
		return list
	return list.filter(func(entry: Dictionary) -> bool:
		if race != 0 and entry.has("races") and not race in (entry.races as Array).map(func(r: Variant) -> int: return int(r)):
			return false
		return char_class == 0 or not entry.has("classes") or int(entry.classes) & (1 << (char_class - 1)) != 0)


## The Weapon Master's trainer, which teaches every class the weapon skills
## it may learn (classic's weapon masters joined).
const WEAPON_TRAINER := "weapons"
## The pet trainer's list: abilities a Ranger learns to teach their pet.
const PET_TRAINER := "pet"


## A weapon skill (One-Handed Swords...): taught by the Weapon Master, and
## left out of the spellbook as classic does.
static func is_weapon_skill(id: int) -> bool:
	if _weapon_skills.is_empty():
		for entry: Dictionary in trainer_list(WEAPON_TRAINER):
			for spell_id in entry.spells:
				_weapon_skills[int(spell_id)] = true
	return _weapon_skills.has(id)

static var _weapon_skills: Dictionary


## What a proficiency spell (Plate Mail, Two-Handed Swords...) lets you use:
## "item class:subclass" for each subclass in its mask (SPELL_EFFECT_PROFICIENCY,
## as Player::learnSpell grants it).
static func proficiencies_of(spell: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for i in range(1, 4):
		if int(spell.get("Effect%d" % i, 0)) == EFFECT_PROFICIENCY:
			var mask := int(spell.get("EquippedItemSubClassMask", 0))
			for bit in 32:
				if mask & (1 << bit) != 0:
					found.append("%d:%d" % [int(spell.EquippedItemClass), bit])
	return found


## The trainer list for a class's own trainer, for one race.
static func class_trainer_list(char_class: int, race: int) -> Array:
	var trainer: String = TRAINER_CLASSES.find_key(char_class) if TRAINER_CLASSES.values().has(char_class) else ""
	return [] if trainer.is_empty() else trainer_list(trainer, race)


## Classes with spells in the game.
static func classes_with_spells() -> Array:
	return TRAINER_CLASSES.values()


## Linked spell another spell casts (Holy Nova's heal, Touch of Weakness's damage...), or 0.
## The hidden passives every tamed pet has (spells.json "pet_passives").
static func pet_passives() -> Array[int]:
	var ids: Array[int] = []
	for id in _get_data().get("pet_passives", []):
		ids.append(int(id))
	return ids


static func linked_spell(id: int) -> int:
	return int(_get_data().get("links", {}).get(str(id), 0))


## Rank number within its chain, or 0 for spells without ranks.
static func rank_of(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("rank", 0))


static func first_rank(id: int) -> int:
	return int(_get_data().chains.get(str(id), {}).get("first", id))


## The spellbook tab a spell goes in for a class: its talent tree's index
## (by its skill line), or -1 for General.
static func book_tab(char_class: int, id: int) -> int:
	return int(_get_data().get("book_tabs", {}).get(str(char_class), {}).get(str(id), -1))


static func _get_data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(SPELLS_PATH))
		# The game's own classes, over classic's.
		for extra: Dictionary in ClassicData.class_files():
			for key in ["spells", "chains", "start_spells", "talents", "book_tabs", "links", "trainers"]:
				(_data[key] as Dictionary).merge(extra.get(key, {}), true)
		_lengthen_buffs()
	return _data


## The game's own rule (unlike classic): class buffs that last 5 minutes or
## more (Boons, Greater Boons, Litany of Fortitude, Uplifted Spirit, Inner
## Flame...) last an hour. Short ones (Boon of Shelter, shouts) are left be.
## The classic duration stays as ClassicDurationIndex.
static func _lengthen_buffs() -> void:
	for spell: Dictionary in _data.spells.values():
		var length: float = DURATIONS.get(int(spell.get("DurationIndex", 0)), 0.0)
		if int(spell.get("SpellFamilyName", 0)) in CLASS_SPELL_FAMILIES and length >= LONG_BUFF_FROM and length < LONG_BUFF 				and int(spell.get("Effect1", 0)) == EFFECT_APPLY_AURA and target_type(spell) != TARGET_ENEMY:
			spell.ClassicDurationIndex = spell.DurationIndex
			spell.DurationIndex = LONG_BUFF_DURATION_INDEX


## Spells that open a menu of others instead of casting (the action bar's
## and spellbook's "Boons" and "Greater Boons"): their own ids, which no
## classic spell uses, and the name each holds spells beginning with.
static func is_flyout(id: int) -> bool:
	return FLYOUTS.has(id)


## The spells in a flyout a character knows: the highest rank of each, by
## name.
static func flyout_spells(id: int, who: CharacterProfile) -> Array[int]:
	var found: Array[int] = []
	if not FLYOUTS.has(id):
		return found
	var names: Array[String] = []
	for known in who.known_spells:
		var spell_name := str(get_spell(known).get("SpellName", ""))
		if spell_name.begins_with(FLYOUTS[id].prefix) and not spell_name in names:
			names.append(spell_name)
	names.sort()
	for spell_name in names:
		found.append(who.best_rank(spell_name))
	return found
