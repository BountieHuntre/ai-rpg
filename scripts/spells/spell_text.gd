class_name SpellText
extends RefCounted
## Spell descriptions for tooltips, in the game's own words, with the numbers
## worked out from each spell's data at the caster's level: amounts,
## durations, percentages and ranges. Every spell a player can see (trainer
## spells, item "Use:" spells, recipes) has one; anything else gets a plain
## description from its effects.

const FOOD_DRINK_PERIOD := 5.0
const RESISTANCE_SCHOOLS := { 4: "Fire", 16: "Frost", 32: "Shadow", 8: "Nature", 64: "Arcane" }


## The description for a spell, or "" for none. `caster` (a SpellCaster) gives
## numbers that depend on the caster's gear, such as Oath of Valor's damage.
static func describe(spell: Dictionary, level: int, caster: Node = null) -> String:
	var name := str(spell.get("SpellName", ""))
	var t := _Values.new(spell, level)
	for prefix in ["Pattern: ", "Plans: ", "Recipe: ", "Formula: ", "Schematic: "]:
		if name.begins_with(prefix):
			return "Teaches you how to make %s." % name.trim_prefix(prefix)
	if name.begins_with("Greater Boon of "):
		var single := _boon(name.trim_prefix("Greater "), t)
		if not single.is_empty():
			return single.trim_suffix(" One Boon per Paladin on each target.") + " Blesses everyone of the target's class in your party and raid."
	if name.begins_with("Boon of "):
		return _boon(name, t)
	if name.ends_with(" Presence"):
		return _presence(name, t)
	if name.begins_with("Oath of "):
		return _oath(name, spell, t, caster)
	match name:
		"Attack":
			return "Toggles melee attack on your target."
		"Mending Radiance":
			return "Heals a friendly target for %s." % t.amount(0)
		"Quick Radiance":
			return "Quickly heals a friendly target for %s." % t.amount(0)
		"Last Rite":
			var text := "Heals a friendly target for as much health as you have."
			# Higher ranks also give the target mana.
			return text + (" Also restores %s mana to them." % t.amount(1) if t.low(1) > 0.0 else "")
		"Verdict":
			return "Unleashes your active Oath on an enemy within 10 yards, with an effect that depends on the Oath. Your Oath stays active."
		"Stunning Gavel":
			return "Stuns an enemy for %s." % t.duration()
		"Gavel of Reckoning":
			return "Hurls a hammer at an enemy below 20%% health, dealing %s Holy damage." % t.amount(0)
		"Banishment":
			return "Smites an undead or demon enemy for %s Holy damage." % t.amount(0)
		"Radiant Fury":
			return "Sends out a burst of light, dealing %s Holy damage to every undead and demon within 20 yards." % t.amount(0)
		"Radiant Jolt":
			return "Blasts an enemy with Holy power, or mends a friendly target."
		"Radiant Bulwark":
			return "Raises your chance to block by %s%% for %s. Each block deals %s Holy damage to the attacker." % [t.amount(0), t.duration(), t.amount(1)]
		"Rebuke the Dead":
			return "Drives an undead enemy to flee for up to %s. Damage may break the effect." % t.duration()
		"Revival":
			return "Brings a dead ally back to life with %s health and %s mana. Can't be used in combat." % [t.amount(0), t.misc(0)]
		"Zealous Fervor":
			return "Your Holy spells cause %s%% more threat for %s." % [t.amount(0), t.duration()]
		"Hallowed Guard":
			return "Shields you from all physical and magical damage for %s, but you can't attack while it lasts." % t.duration()
		"Hallowed Aegis":
			return "Makes you immune to all damage for %s, though your attacks are 50%% slower while it lasts." % t.duration()
		"Hallowed Ground":
			return "Hallows the ground at your feet. Enemies standing on it take %d Holy damage over %s." % [roundi(t.low(0) * t.seconds() / t.period(0)), t.duration()]
		"Hallowed Ransom":
			return "Sacrifices yourself to save a party member: they can neither act nor be harmed for 3 min."
		"Cleansing Touch":
			return "Cleanses a friendly target of one poison and one disease."
		"Greater Cleansing":
			return "Cleanses a friendly target of one poison, one disease and one magic effect."
		"Parry":
			return "Gives you a chance to parry enemy melee attacks."
		"Plate Mail":
			return "Lets you wear plate armor."
		"Food":
			return "Restores %d health over %s. You must stay seated while eating." % [roundi(t.low(0) * t.seconds() / FOOD_DRINK_PERIOD), t.duration()]
		"Drink":
			return "Restores %d mana over %s. You must stay seated while drinking." % [roundi(t.low(0) * t.seconds() / FOOD_DRINK_PERIOD), t.duration()]
		"Healing Potion":
			return "Restores %s health." % t.amount(0)
		"Haste":
			var lasting := "" if t.seconds() < 0.0 else " for %s" % t.duration()
			return "Increases your run speed by %s%%%s." % [t.amount(0), lasting]
		"Glimmer Mark":
			return "Lowers an enemy's armor by %s for %s. They can't stealth or turn invisible while it lasts." % [t.magnitude(0), t.duration()]
		"Slipping Beads":
			return "Scatters beads under an enemy, making them %s%% less likely to hit for %s." % [t.magnitude(0), t.duration()]
		"Homing Token":
			var wait := roundi(SpellCaster.HOMING_TOKEN_COOLDOWN / 60.0)
			return "After a %d sec cast, returns you to the priory in Ashford Vale. Moving cancels it. Can be used once every %d min." % [roundi(SpellDB.cast_time(spell)), wait]
	return _generic(spell, t)


static func _boon(name: String, t: _Values) -> String:
	var lasts := t.duration()
	var text := ""
	match name:
		"Boon of Strength":
			text = "Increases a friendly target's attack power by %s for %s." % [t.amount(0), lasts]
		"Boon of Clarity":
			text = "Restores %s mana every 5 sec to a friendly target for %s." % [t.amount(0), lasts]
		"Boon of Radiance":
			text = "Healing received from Mending Radiance is increased by up to %s and from Quick Radiance by up to %s, for %s." % [t.amount(0), t.amount(1), lasts]
		"Boon of Quietude":
			text = "Lowers the threat a friendly target causes by %s%% for %s." % [t.magnitude(0), lasts]
		"Boon of Refuge":
			text = "Reduces damage a friendly target takes by up to %s, and enemies that strike them take %s Holy damage, for %s." % [t.magnitude(0), t.amount(1), lasts]
		"Boon of Shelter":
			text = "Protects a friendly target from all physical attacks for %s, but they can't attack in melee while it lasts." % lasts
		"Boon of Unfettering":
			text = "Frees a friendly target from effects that slow or root them, for %s." % lasts
		"Boon of the Martyr":
			text = "Redirects %s%% of the damage a party member takes to you for %s." % [t.amount(0), lasts]
		"Boon of Sovereigns":
			text = "Increases a friendly target's attributes by %s%% for %s." % [t.amount(0), lasts]
		_:
			return ""
	return text + " One Boon per Paladin on each target."


static func _presence(name: String, t: _Values) -> String:
	var text := ""
	match name:
		"Bulwark Presence":
			text = "Party members within 30 yards gain %s armor." % t.amount(0)
		"Thorned Presence":
			text = "Enemies that strike party members within 30 yards take %s Holy damage." % t.amount(0)
		"Focused Presence":
			text = "Party members within 30 yards have a %s%% chance to keep casting when hit, and resist being silenced or interrupted." % t.amount(0)
		_:
			var school: String = RESISTANCE_SCHOOLS.get(int(t.spell.get("EffectMiscValue1", 0)), "")
			if school.is_empty():
				return ""
			text = "Party members within 30 yards gain %s %s resistance." % [t.amount(0), school]
	return text + " You can keep only one Presence at a time."


static func _oath(name: String, spell: Dictionary, t: _Values, caster: Node) -> String:
	var text := ""
	match name:
		"Oath of Valor":
			if caster and SpellDB.seal_of_righteousness_proc(int(spell.Id)) != 0:
				text = "Swear an oath of valor for %s. Each melee hit deals %d extra Holy damage." % [t.duration(), caster.seal_of_righteousness_damage(spell)]
			else:
				text = "Swear an oath of valor for %s. Each melee hit deals extra Holy damage." % t.duration()
		"Oath of the Vanguard":
			text = "Swear an oath of the vanguard for %s: your attack power rises by %s and your attacks come %s%% faster, though each hit deals less damage." % [t.duration(), t.amount(0), t.amount(1)]
		"Oath of Binding":
			text = "Swear an oath of binding for %s. Your melee hits may stop the enemy from running away." % t.duration()
		"Oath of Mending":
			text = "Swear an oath of mending for %s. Your melee hits may heal you." % t.duration()
		"Oath of Insight":
			text = "Swear an oath of insight for %s. Your melee hits may restore your mana." % t.duration()
		"Oath of Dominion":
			text = "Swear an oath of dominion for %s. Your melee hits may strike again for extra Holy damage." % t.duration()
		_:
			return ""
	var judged := SpellDB.seal_judgement(spell) != 0
	return text + (" Verdict unleashes it on your target." if judged else "") + " You can keep only one Oath at a time."


## For spells with no written description: what their effects do.
static func _generic(spell: Dictionary, t: _Values) -> String:
	var parts := PackedStringArray()
	for i in 3:
		match int(spell.get("Effect%d" % (i + 1), 0)):
			2:
				parts.append("Deals %s damage." % t.amount(i))
			10:
				parts.append("Restores %s health." % t.amount(i))
			30:
				parts.append("Restores %s mana." % t.amount(i))
			36:
				parts.append("Teaches you something new.")
			38:
				parts.append("Removes a harmful effect.")
	if parts.is_empty() and t.seconds() > 0.0:
		parts.append("Lasts %s." % t.duration())
	return " ".join(parts)


## A spell's effect numbers at a level, ready for text.
class _Values:
	var spell: Dictionary
	var level: int

	func _init(spell_data: Dictionary, caster_level: int) -> void:
		spell = spell_data
		level = caster_level

	## "40 to 48", or "40" when it doesn't vary.
	func amount(effect: int) -> String:
		var span := SpellDB.effect_range(spell, effect, level)
		var low := roundi(absf(span.x))
		var high := roundi(absf(span.y))
		return str(low) if high <= low else "%d to %d" % [low, high]

	func low(effect: int) -> float:
		return absf(SpellDB.effect_range(spell, effect, level).x)

	## The size of a reduction, as a positive number.
	func magnitude(effect: int) -> String:
		return str(roundi(low(effect)))

	func misc(effect: int) -> String:
		return str(int(spell.get("EffectMiscValue%d" % (effect + 1), 0)))

	func seconds() -> float:
		return SpellDB.duration(spell)

	## Tick time of a periodic effect, in seconds.
	func period(effect: int) -> float:
		return maxf(float(spell.get("EffectAmplitude%d" % (effect + 1), 1000)) / 1000.0, 0.001)

	func duration() -> String:
		var time := seconds()
		if time < 0.0:
			return "as long as it lasts"
		if time >= 3600.0:
			return "%s hr" % _number(time / 3600.0)
		if time >= 60.0:
			return "%s min" % _number(time / 60.0)
		return "%s sec" % _number(time)

	func _number(value: float) -> String:
		return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
