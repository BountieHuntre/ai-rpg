class_name TalentText
extends RefCounted
## Descriptions for passive talents, in the game's own words, worked out from
## their data: spell modifiers name the spells they change (found by their
## family mask among the class's trainable spells and talent abilities), stat
## talents say what they raise, and the talents that fire from combat have a
## line each. SpellText.describe asks here first for passive talent spells.

const WEAPONS := {
	"axe": "with axes", "polearm": "with polearms", "two-handed": "with two-handed weapons",
	"one-handed": "with one-handed melee weapons", "wand": "with wands",
}
## What each school mask means for talents that name schools.
const SCHOOLS := { 2: "Holy", 32: "Shadow", 98: "Holy, Shadow and Arcane", 126: "spell", 127: "all" }

static var _player_spells: Dictionary = {}
static var _talent_ranks: Dictionary = {}


## The talent's description, or "" for spells that aren't passive talents.
static func describe(spell: Dictionary, level: int) -> String:
	if not SpellDB.is_passive(spell) or not is_talent_rank(int(spell.get("Id", 0))):
		return ""
	var special := _special(spell, level)
	if not special.is_empty():
		return special
	var parts := PackedStringArray()
	for i in 3:
		var text := _effect(spell, i, level)
		if not text.is_empty() and not text in parts:
			parts.append(text)
	return " ".join(parts)


static func is_talent_rank(id: int) -> bool:
	if _talent_ranks.is_empty():
		for char_class in SpellDB.TRAINER_CLASSES.values():
			for tree: Dictionary in Talents.trees(int(char_class)):
				for talent: Dictionary in tree.talents:
					for rank_id in talent.ranks:
						_talent_ranks[int(rank_id)] = true
	return _talent_ranks.has(id)


## Talents that fire from combat or do something of their own.
static func _special(spell: Dictionary, level: int) -> String:
	var name: String = spell.SpellName
	var chance := int(spell.get("ProcChance", 100))
	var trigger := SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0)))
	var t := func(of: Dictionary, effect: int) -> String: return str(roundi(absf(SpellDB.effect_value(of, effect, level))))
	var lasts := func(of: Dictionary) -> String: return "%d sec" % roundi(SpellDB.duration(of))
	var rank := maxi(Talents.rank_of_spell(int(spell.Id)), 1)
	match name:
		"Lingering Wounds":
			return "Your critical strikes make the target bleed for %d%% of your average melee damage over 12 sec." % (20 * rank)
		"Swordsman's Craft":
			return "Gives a %d%% chance to get an extra attack on the same target after hitting with your sword." % chance
		"Maceman's Craft":
			var ppm := float(SpellDB.proc_info(spell).get("ppm", 0.0))
			return "Gives your mace hits a chance (%s a minute) to stun the target for 3 sec." % _num(ppm)
		"Improved Hobble":
			return "Gives your Hobble a %d%% chance to root the target for 5 sec." % chance
		"Improved Retort":
			return "Gives your Retort a %d%% chance to stun the target for 3 sec." % chance
		"Improved Shield Smash":
			return "Gives your Shield Smash a %d%% chance to silence the target for 3 sec." % chance
		"Rising Wrath":
			return "After being the victim of a critical strike, your melee damage is raised by %s%% for 12 swings or 12 sec." % t.call(trigger, 0)
		"Battle Frenzy":
			return "After landing a critical strike, your next 3 swings are %s%% faster." % t.call(trigger, 0)
		"Surging Wrath":
			var ppm := float(SpellDB.proc_info(spell).get("ppm", 0.0))
			return "Gives your melee hits a chance (%s a minute) to generate 1 extra rage." % _num(ppm)
		"Bloodied Resolve":
			return "After being the victim of a critical strike, you regenerate %s%% of your health every 3 sec for 6 sec." % t.call(trigger, 0)
		"Improved Unbridled Rage":
			return "Unbridled Rage also generates %s rage." % _num(SpellDB.effect_value(trigger, 0, level) / 10.0)
		"Shield Craft":
			# The Man-at-Arms' one: block chance and rage from blocks.
			if SpellDB.has_effect(spell, SpellDB.AURA_PROC_TRIGGER_SPELL, true):
				return "Increases your chance to block by %s%%, and gives blocks a %d%% chance to generate 1 rage." % [t.call(spell, 0), chance]
		"Stance Discipline":
			return "You keep up to %d rage when you change stance." % (5 * rank)
		"Simmering Anger":
			return "Generates 1 rage every 3 sec."
		"Martyr's Calm":
			return "After being the victim of a melee critical strike, you have a %d%% chance to resist being set back by damage while casting, for 6 sec." % chance
		"Hearten":
			return "After a critical heal, your target's armor is raised by %s%% for 15 sec." % t.call(trigger, 0)
		"Shadow Snare":
			return "Gives your Shadow spells a %d%% chance to stun the target for 3 sec." % chance
		"Spirit Harvest":
			return "Gives a %d%% chance, after killing a foe worth experience, to raise your Spirit by 100%% and keep up half your mana regen while casting, for 15 sec." % chance
		"Hallowed Recovery":
			var share: Array = TalentProcs.BLESSED_RECOVERY_SHARE
			return "After being the victim of a melee critical strike, you regain %d%% of the damage over 6 sec." % roundi(share[clampi(rank, 1, share.size()) - 1] * 100.0)
		"Inner Light":
			return "After a critical heal, a %d%% chance to have the spell's mana cost refunded." % chance
		"Gloomweave":
			return "Gives your Shadow spells a %s%% chance to leave the target taking 3%% more Shadow damage for 15 sec, stacking up to 5 times." % t.call(spell, 0)
		"Wandwork":
			return "Increases the damage you deal with wands by %s%%. (There are no wands in the game yet.)" % t.call(spell, 0)
		"Lingering Spirit":
			return "On death you become a spirit that can cast for 10 sec. (Not in the game yet.)"
		"Steadfast Guard":
			return "After being the victim of a critical strike, your chance to block is raised by 30% for your next 5 blocks or 10 sec."
		"Reckoner's Fury":
			return "Gives a %d%% chance after being the victim of a critical strike to get an extra attack." % chance
		"Improved Last Rite":
			return "Last Rite also raises the target's armor from items by %s%% for 2 min." % t.call(trigger, 0)
		"Righteous Rebuke":
			return "Gives your melee hits a chance to lower the target's Strength and Agility by %s%% for 10 sec." % t.call(trigger, 0)
		"Avenging Zeal":
			return "After a critical strike, your Holy and physical damage is raised by %s%% for 8 sec." % t.call(trigger, 0)
		"Tooth for a Tooth":
			return "Spell critical hits against you deal %d%% of their damage back to the caster." % roundi(TalentProcs.EYE_FOR_AN_EYE_SHARE * 100.0 * rank)
	return ""


## One effect of a talent.
static func _effect(spell: Dictionary, i: int, level: int) -> String:
	var kind := int(spell.get("EffectApplyAuraName%d" % (i + 1), 0))
	if int(spell.get("Effect%d" % (i + 1), 0)) != SpellDB.EFFECT_APPLY_AURA:
		return ""
	var value := SpellDB.effect_value(spell, i, level)
	var amount := _num(absf(value))
	var misc := int(spell.get("EffectMiscValue%d" % (i + 1), 0))
	var more := "Increases" if value >= 0.0 else "Reduces"
	var weapon := _weapon_text(spell)
	match kind:
		SpellMods.AURA_FLAT, SpellMods.AURA_PCT:
			return _modifier(spell, i, kind == SpellMods.AURA_PCT, value)
		47:
			return "Increases your chance to parry by %s%%." % amount
		52:
			return "Increases your critical strike chance%s by %s%%." % [" " + weapon if weapon else "", amount]
		54:
			return "Increases your chance to hit with melee weapons by %s%%." % amount
		71:
			return "Increases the critical effect chance of your %s spells by %s%%." % [SCHOOLS.get(1 << misc, "Holy"), amount]
		79:
			return "%s the damage you deal%s by %s%%." % [more, " " + weapon if weapon else "", amount]
		87:
			return "Reduces all %s damage taken by %s%%." % [SCHOOLS.get(misc, "spell"), amount]
		98:
			return "Increases your Defense skill by %s." % amount
		117:
			var mechanic: String = {1: "Charm", 12: "Stun", 5: "Fear", 9: "Silence", 2: "Disorient"}.get(misc, "such")
			return "Increases your chance to resist %s effects by %s%%." % [mechanic, amount]
		122:
			return "Increases the damage done by your off-hand weapon by %s%%." % amount
		132:
			return "Increases your maximum mana by %s%%." % amount
		134:
			return "Allows %s%% of your mana regeneration to continue while casting." % amount
		137:
			var stat: String = ["Strength", "Agility", "Stamina", "Intellect", "Spirit"][clampi(misc, 0, 4)] if misc >= 0 else "attributes"
			return "%s your %s by %s%%." % [more, stat, amount]
		142:
			return "Increases your armor value from items by %s%%." % amount
		150:
			return "Increases the damage your shield blocks by %s%%." % amount
		51:
			return "Increases your chance to block by %s%%." % amount
		SpellDB.AURA_MOD_INCREASE_SPEED:
			return "Increases your movement speed by %s%%." % amount
		174:
			return "Increases your spell damage and healing by up to %s%% of your total Spirit." % amount
		SpellDB.AURA_MOD_THREAT:
			if int(spell.get("Stances", 0)) != 0:
				return "Increases the threat you cause in Bastion Stance by %s%%." % amount
			return "%s the threat caused by your %s spells by %s%%." % [more, SCHOOLS.get(misc, "spell"), amount]
	return ""


## A spell modifier's line: what it changes, by how much, for which spells.
static func _modifier(spell: Dictionary, i: int, percent: bool, value: float) -> String:
	var op := int(spell.get("EffectMiscValue%d" % (i + 1), 0))
	var names := _affected(spell, i)
	var amount := _num(absf(value))
	var unit := "%" if percent else ""
	var more := "Increases" if value >= 0.0 else "Reduces"
	match op:
		SpellMods.COST:
			var cost := ("%s%%" % amount) if percent else ("%s rage" % _num(absf(value) / 10.0) if _rage(spell, i) else "%s mana" % amount)
			return "Reduces the cost of your %s by %s." % [names, cost]
		SpellMods.ALL_EFFECTS:
			if percent:
				return "%s the effect of your %s by %s%%." % [more, names, amount]
			if _rage(spell, i):
				return "Your %s generates %s more rage." % [names, _num(absf(value) / 10.0)]
			return "%s the effect of your %s by %s." % [more, names, amount]
		SpellMods.CRITICAL_CHANCE:
			return "Increases the critical chance of your %s by %s%%." % [names, amount]
		SpellMods.COOLDOWN:
			return "Reduces the cooldown of your %s by %s." % [names, ("%s%%" % amount) if percent else _seconds(absf(value))]
		SpellMods.CHARGES:
			return "Your %s lasts %s more %s." % [names, amount, "hit" if absf(value) == 1.0 else "hits"]
		SpellMods.DURATION:
			return "%s the duration of your %s by %s." % [more, names, ("%s%%" % amount) if percent else _seconds(absf(value))]
		SpellMods.RADIUS:
			return "Increases the radius of your %s by %s%s." % [names, amount, unit if percent else " yd"]
		SpellMods.RANGE:
			return "Increases the range of your %s by %s%s." % [names, amount, unit if percent else " yd"]
		SpellMods.CASTING_TIME:
			return "Reduces the casting time of your %s by %s." % [names, ("%s%%" % amount) if percent else _seconds(absf(value))]
		SpellMods.DAMAGE:
			return "%s the damage of your %s by %s%s." % [more, names, amount, unit]
		SpellMods.DOT:
			return "%s the damage over time of your %s by %s%s." % [more, names, amount, unit]
		SpellMods.NOT_LOSE_CASTING_TIME:
			return "Gives a %s%% chance to avoid being set back by damage while casting your %s." % [amount, names]
		SpellMods.RESIST_MISS_CHANCE:
			return "Reduces the chance your %s are resisted by %s%%." % [names, amount]
		SpellMods.THREAT:
			return "%s the threat caused by your %s by %s%s." % [more, names, amount, unit]
		SpellMods.CRIT_DAMAGE_BONUS:
			return "Increases the critical strike damage bonus of your %s by %s%%." % [names, amount]
		SpellMods.ATTACK_POWER:
			return "Increases the attack power bonus of your %s by %s%%." % [names, amount]
	return ""


## Whether a modifier's spells cost or make rage (its amounts are tenths).
static func _rage(spell: Dictionary, i: int) -> bool:
	for id in _affected_ids(spell, i):
		if SpellDB.uses_rage(SpellDB.get_spell(id)):
			return true
	return false


## The names of the spells a modifier changes: "Mighty Blow", or "Mending,
## Lesser Mending and Greater Mending".
## Long lists say what the spells share: "Shadow spells", "instant spells".
static func _affected(spell: Dictionary, i: int) -> String:
	var names := PackedStringArray()
	var ids := _affected_ids(spell, i)
	for id in ids:
		var name := str(SpellDB.get_spell(id).SpellName)
		if not name in names:
			names.append(name)
	if names.is_empty():
		return "spells"
	if names.size() > 6:
		# Templar Oaths and their Verdicts.
		if Array(names).all(func(name: String) -> bool: return name.begins_with("Oath of") or name.begins_with("Verdict")):
			return "Oaths and Verdicts"
		var schools := {}
		var instant := true
		var rage := true
		for id in ids:
			var other := SpellDB.get_spell(id)
			schools[int(other.get("School", 0))] = true
			instant = instant and SpellDB.cast_time(other) <= 0.0
			rage = rage and SpellDB.uses_rage(other)
		if rage:
			return "abilities"
		if schools.size() == 1 and schools.keys()[0] != 0:
			return "%s spells" % SpellDB.SCHOOL_NAMES[schools.keys()[0]]
		if instant:
			return "instant spells"
		return "spells"
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[names.size() - 1]


static func _affected_ids(spell: Dictionary, i: int) -> Array[int]:
	var mask := int(spell.get("EffectItemType%d" % (i + 1), 0))
	var family := int(spell.get("SpellFamilyName", 0))
	var found: Array[int] = []
	for id: int in _player_spell_ids():
		var other := SpellDB.get_spell(id)
		if int(other.get("SpellFamilyName", 0)) == family and int(other.get("SpellFamilyFlags", 0)) & mask != 0 and not SpellDB.is_passive(other):
			found.append(id)
	return found


## First ranks of every spell a player can learn from a trainer or a talent.
static func _player_spell_ids() -> Array:
	if _player_spells.is_empty():
		for trainer: String in SpellDB.TRAINER_CLASSES:
			for entry: Dictionary in SpellDB.trainer_list(trainer):
				for id in entry.spells:
					var first := SpellDB.first_rank(int(id))
					_player_spells[first if first != 0 else int(id)] = true
		for char_class in SpellDB.TRAINER_CLASSES.values():
			for tree: Dictionary in Talents.trees(int(char_class)):
				for talent: Dictionary in tree.talents:
					_player_spells[int(talent.ranks[0])] = true
		# Verdicts come from Oaths rather than the trainer.
		for id: int in _player_spells.keys():
			var verdict := SpellDB.seal_judgement(SpellDB.get_spell(id))
			if verdict != 0:
				_player_spells[SpellDB.first_rank(verdict) if SpellDB.first_rank(verdict) != 0 else verdict] = true
	return _player_spells.keys()


static func _weapon_text(spell: Dictionary) -> String:
	var item_class := int(spell.get("EquippedItemClass", -1))
	if item_class == Talents.ITEM_CLASS_ARMOR:
		return "with a shield"
	if item_class != Talents.ITEM_CLASS_WEAPON:
		return ""
	var mask := int(spell.get("EquippedItemSubClassMask", 0))
	# Most melee weapons: no weapon worth naming.
	var kinds := 0
	for bit in 21:
		if mask & (1 << bit):
			kinds += 1
	if mask <= 0 or kinds > 4:
		return ""
	# Item subclasses: 0 one-handed axe, 1 two-handed axe, 6 polearm (17
	# spear), 19 wand...
	if mask == (1 << 0) | (1 << 1):
		return WEAPONS.axe
	if mask & (1 << 6):
		return WEAPONS.polearm
	if mask == 1 << 19:
		return WEAPONS.wand
	if mask & ((1 << 1) | (1 << 5) | (1 << 8)) and not mask & ((1 << 0) | (1 << 4) | (1 << 7)):
		return WEAPONS["two-handed"]
	return WEAPONS["one-handed"]


static func _seconds(ms: float) -> String:
	return "%s sec" % _num(ms / 1000.0)


static func _num(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
