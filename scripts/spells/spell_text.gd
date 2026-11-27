class_name SpellText
extends RefCounted
## Spell descriptions for tooltips, in the game's own words, with the numbers
## worked out from each spell's data at the caster's level: amounts,
## durations, percentages and ranges. Every spell a player can see (trainer
## spells, item "Use:" spells, recipes) has one; anything else gets a plain
## description from its effects.

static var FOOD_DRINK_PERIOD := 5.0
const RESISTANCE_SCHOOLS := { 4: "Fire", 16: "Frost", 32: "Shadow", 8: "Nature", 64: "Arcane" }


## The description for a spell, or "" for none. `caster` (a SpellCaster) gives
## numbers that depend on the caster's gear, such as Oath of Valor's damage.
## Whose tooltip is being written (describe's caster), so the numbers count
## their talents (SpellMods): cast time, duration, range, radius, cost and
## effect amounts. Null for a spell seen apart from anyone.
static var _who: Combatant
## The stacks of the aura being described (a buff's tooltip): its amounts
## are that many times the spell's.
static var _stacks := 1


static func describe(spell: Dictionary, level: int, caster: Node = null, stacks := 1) -> String:
	var stacks_before := _stacks
	_stacks = maxi(stacks, 1)
	var before := _who
	if caster is SpellCaster:
		_who = (caster as SpellCaster)._unit.combatant
	elif caster is Combatant:
		_who = caster
	else:
		_who = null
	var text := _describe(spell, level, caster)
	_who = before
	_stacks = stacks_before
	return text


static func _describe(spell: Dictionary, level: int, caster: Node) -> String:
	var name := str(spell.get("SpellName", ""))
	# Text of its own: the game's own classes' spells (ClassicData.CLASS_FILES)
	# and any spell given `text` in its design, its {placeholders} filled in.
	if spell.has("Description"):
		return fill(str(spell.Description), spell, level)
	var talent := TalentText.describe(spell, level)
	if not talent.is_empty():
		return talent
	var t := _Values.new(spell, level)
	for prefix in ["Pattern: ", "Plans: ", "Recipe: ", "Formula: ", "Schematic: "]:
		if name.begins_with(prefix):
			return "Teaches you how to make %s." % name.trim_prefix(prefix)
	# Enchanting's enchants: what they put on, and on what.
	var recipe := ProfessionDB.recipe(int(spell.get("Id", 0)))
	if recipe.has("enchant"):
		var on := name.trim_prefix("Enchant ").get_slice(" - ", 0).to_lower()
		if on.begins_with("2h "):
			on = "two-handed weapon"
		var does := Enchanting.describe(int(recipe.enchant), level)
		return "Permanently enchants a %s: %s.%s" % [on, Enchanting.line(int(recipe.enchant)), " " + does if not does.is_empty() else ""]
	if SpellDB.is_weapon_skill(int(spell.get("Id", 0))):
		return "Lets you use %s." % ("thrown weapons" if name == "Thrown" else name.to_lower())
	if name.begins_with("Greater Boon of "):
		var single := _boon(name.trim_prefix("Greater "), t)
		if not single.is_empty():
			return single.trim_suffix(" One Boon per Templar on each target.") + " Blesses everyone of the target's class in your party and raid."
	if name.begins_with("Boon of "):
		return _boon(name, t)
	if name.ends_with(" Presence"):
		return _presence(name, t)
	if name.begins_with("Oath of "):
		return _oath(name, spell, t, caster, level)
	# A Verdict's debuff or strike on its own (the target frame's debuffs).
	if name.begins_with("Verdict of "):
		var verdict := _verdict(spell, level)
		if not verdict.is_empty():
			return verdict.left(1).to_upper() + verdict.substr(1)
	var cleric := _cleric(name, spell, t)
	if not cleric.is_empty():
		return cleric
	var man_at_arms := _man_at_arms(name, spell, t)
	if not man_at_arms.is_empty():
		return man_at_arms
	var ranger := _ranger(name, spell, t, level)
	if not ranger.is_empty():
		return ranger
	var magus := _magus(name, spell, t, level)
	if not magus.is_empty():
		return magus
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
			var text := "Unleashes your active Oath on an enemy within 10 yards, with an effect that depends on the Oath. Your Oath stays active."
			# What it does now, by the Oath you have up.
			if _who:
				var oath: Dictionary = _who.find_aura(func(s: Dictionary) -> bool: return SpellDB.seal_judgement(s) != 0)
				if not oath.is_empty():
					var now := _verdict(SpellDB.get_spell(SpellDB.seal_judgement(oath.spell)), level)
					if not now.is_empty():
						text += " With %s, it %s" % [oath.spell.SpellName, now]
			return text
		"Stunning Gavel":
			return "Stuns an enemy for %s." % t.duration()
		"Heaven's Favor":
			return "Your next Mending Radiance, Quick Radiance or Radiant Jolt is sure to be a critical one."
		"Contrition":
			return "Puts an enemy into deep contrition for %s: it can't act. Any damage breaks the effect." % t.duration()
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
		# Creature spells, seen in debuff and target tooltips.
		"Flame Bolt":
			return "Hurls a bolt of fire at an enemy for %s Fire damage." % t.amount(0)
		"Rime Shroud":
			return "Armor raised by %s. Melee attackers are chilled, slowing their movement and attacks." % t.amount(0)
		"Chilled":
			return "Movement slowed by %s%% and attacks by %s%%." % [t.magnitude(1), t.magnitude(0)]
		"Prying Strike":
			return "Armor lowered by %s%%." % t.magnitude(0)
		"Back Thrust":
			return "Stabs an enemy in the back for %s%% weapon damage plus %s." % [t.amount(1), t.amount(0)]
		"Headlong Charge":
			return "Run speed raised by %s%% and melee damage by %s." % [t.amount(0), t.amount(1)]
		"Homing Token":
			var wait := roundi(SpellCaster.HOMING_TOKEN_COOLDOWN / 60.0)
			# Home is where the character's race begins, on this continent (World.start_zone_here).
			var home: Zone = World.current.start_zone_here(GameState.race) if World.current else null
			var where := "%s in %s" % [home.hub_name, home.zone_name] if home else "where you began"
			return "After a %d sec cast, returns you to %s. Moving cancels it. Can be used once every %d min." % [roundi(SpellDB.cast_time(spell)), where, wait]
	return _generic(spell, t)


## What each placeholder a spell's own text may hold stands for (n is the
## effect, 1 to 3), for the docs and the spell editor.
const PLACEHOLDERS := {
	"amount<n>": "the effect's value at your level: \"40 to 48\", or \"40\" when it doesn't vary",
	"min<n>": "the effect's least value", "max<n>": "the effect's most value",
	"total<n>": "a periodic effect's total over the duration (\"90\")",
	"ticks<n>": "how many times a periodic effect ticks over the duration",
	"period<n>": "seconds between a periodic effect's ticks", "radius<n>": "the effect's area in yards",
	"duration": "how long it lasts (\"30 sec\", \"2 min\", \"1 hr\")", "seconds": "how long it lasts, in seconds",
	"cast": "cast time in seconds", "cooldown": "cooldown (\"6 sec\", \"2 min\")",
	"range": "range in yards", "min_range": "least range in yards",
	"cost": "its cost (\"15 rage\", \"8% of base mana\")", "chance": "its proc chance in %",
	"stacks": "how many times it stacks", "charges": "how many charges it has", "level": "your level",
	"cost_share<n>": "an energize effect's share (%) of a mana cost given back (`cost_share`)",
	"trigger<n>:<placeholder>": "a placeholder read from the spell effect n triggers: {trigger1:cost_share1}",
}


## A spell's own text with its {placeholders} (PLACEHOLDERS) filled in from
## its data at the caster's level. Anything else in braces is left as it is.
static func fill(text: String, spell: Dictionary, level: int) -> String:
	if not "{" in text:
		return text
	# {trigger1:amount1}: a placeholder of the spell the effect triggers.
	for n in 3:
		var prefix := "{trigger%d:" % (n + 1)
		var trigger := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (n + 1), 0)))
		var start := text.find(prefix)
		while start >= 0:
			var end := text.find("}", start)
			if end < 0:
				break
			var inner := "{" + text.substr(start + prefix.length(), end - start - prefix.length()) + "}"
			var filled := fill(inner, trigger, level) if not trigger.is_empty() else inner
			# Left as written when there's no such trigger or placeholder.
			var shown := text.substr(start, end - start + 1) if filled == inner else filled
			text = text.substr(0, start) + shown + text.substr(end + 1)
			start = text.find(prefix, start + shown.length())
	var t := _Values.new(spell, level)
	var values := {
		"duration": t.duration(), "seconds": _number(t.seconds()), "cast": _number(SpellDB.cast_time(spell, _who)),
		"cooldown": _Values.time_text(SpellDB.cooldown(spell, _who)), "range": _number(SpellDB.spell_range(spell, _who)),
		"min_range": _number(SpellDB.min_range(spell)), "chance": _number(SpellDB.proc_chance(spell)),
		"stacks": str(int(spell.get("StackAmount", 0))), "charges": str(int(spell.get("ProcCharges", 0))),
		"level": str(level), "cost": _cost(spell),
	}
	for n in 3:
		var span := SpellDB.effect_span(spell, n, level, _who) * _stacks
		values["amount%d" % (n + 1)] = t.amount(n)
		values["min%d" % (n + 1)] = str(roundi(absf(span.x)))
		values["max%d" % (n + 1)] = str(roundi(absf(span.y)))
		values["total%d" % (n + 1)] = t.over_time(n)
		values["ticks%d" % (n + 1)] = str(floori(t.seconds() / t.period(n) + 0.001))
		values["period%d" % (n + 1)] = _number(t.period(n))
		values["radius%d" % (n + 1)] = _number(SpellDB.effect_radius(spell, n, _who))
		values["cost_share%d" % (n + 1)] = _number(float(spell.get("EffectCostShare%d" % (n + 1), 0)))
	for key: String in values:
		text = text.replace("{%s}" % key, str(values[key]))
	return text


## "15 rage", "8% of base mana", "35 mana", or "nothing".
static func _cost(spell: Dictionary) -> String:
	var percent := int(spell.get("ManaCostPercentage", 0))
	if percent > 0:
		return "%d%% of base mana" % percent
	var cost := int(spell.get("ManaCost", 0))
	if _who and cost > 0:
		cost = roundi(maxf(SpellMods.apply(_who, spell, SpellMods.COST, cost), 0.0))
	match int(spell.get("PowerType", 0)):
		1:
			return "%s rage" % _number(cost / 10.0)
		2:
			return "%d focus" % cost
		3:
			return "%d energy" % cost
	return "%d mana" % cost if cost > 0 else "nothing"


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
	return text + " One Boon per Templar on each target."


static func _presence(name: String, t: _Values) -> String:
	var text := ""
	match name:
		"Bulwark Presence":
			text = "Party members within 30 yards gain %s armor." % t.amount(0)
		"Thorned Presence":
			text = "Enemies that strike party members within 30 yards take %s Holy damage." % t.amount(0)
		"Focused Presence":
			text = "Party members within 30 yards have a %s%% chance to keep casting when hit, and resist being silenced or interrupted." % t.amount(0)
		"Hallowed Presence":
			text = "Party members within 30 yards deal %s%% more Holy damage." % t.amount(0)
		_:
			var school: String = RESISTANCE_SCHOOLS.get(int(t.spell.get("EffectMiscValue1", 0)), "")
			if school.is_empty():
				return ""
			text = "Party members within 30 yards gain %s %s resistance." % [t.amount(0), school]
	return text + " You can keep only one Presence at a time."


static func _oath(name: String, spell: Dictionary, t: _Values, caster: Node, level: int) -> String:
	# The spell each hit may fire, its chance (SpellDB.proc_chance, as rolled)
	# and how often at most.
	var proc := _Values.new(SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0))), level)
	var chance := _number(SpellDB.proc_chance(spell))
	var every := float(SpellDB.proc_info(spell).get("cooldown", 0.0))
	var limit := " (at most once every %s sec)" % _number(every) if every > 0.0 else ""
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
			text = "Swear an oath of binding for %s. Your melee hits have a %s%% chance to stun the target for %s%s." % [t.duration(), chance, proc.duration(), limit]
		"Oath of Mending":
			text = "Swear an oath of mending for %s. Your melee hits have a %s%% chance to heal you for %s%s." % [t.duration(), chance, proc.amount(0), limit]
		"Oath of Insight":
			text = "Swear an oath of insight for %s. Your melee hits have a %s%% chance to restore %s mana%s." % [t.duration(), chance, proc.amount(0), limit]
		"Oath of Dominion":
			text = "Swear an oath of dominion for %s. Your melee hits have a %s%% chance to strike again at once for %s%% of your weapon damage as Holy damage%s." % [t.duration(), chance, proc.amount(0), limit]
		_:
			return ""
	var verdict := _verdict(SpellDB.get_spell(SpellDB.seal_judgement(spell)), level)
	if not verdict.is_empty():
		text += " Verdict on your target %s" % verdict
	return text + " You can keep only one Oath at a time."


## What a Verdict does to its target, as the end of a sentence ("deals 93
## to 101 Holy damage, twice that to a stunned target."), or "".
static func _verdict(spell: Dictionary, level: int) -> String:
	if spell.is_empty():
		return ""
	var v := _Values.new(spell, level)
	match str(spell.SpellName):
		"Verdict of Valor":
			return "deals %s Holy damage." % v.amount(0)
		"Verdict of the Vanguard":
			return "makes each Holy attack on it deal up to %s more damage for %s." % [v.amount(0), v.duration()]
		"Verdict of Binding":
			return "keeps it from running away for %s." % v.duration()
		"Verdict of Mending", "Verdict of Insight":
			var gain := _Values.new(SpellDB.get_spell(SpellDB.judgement_proc_spell(int(spell.Id))), level)
			var what := "heal you for %s" % gain.amount(0) if str(spell.SpellName) == "Verdict of Mending" else "restore %s mana to you" % gain.amount(0)
			return "gives your melee hits on it a %s%% chance to %s, for %s." % [_number(minf(float(spell.get("ProcChance", 0)), 100.0)), what, v.duration()]
		"Verdict of Dominion":
			# The Verdict's dummy names its damage spell (which has the same name).
			var strike := spell
			if int(spell.get("Effect1", 0)) == SpellDB.EFFECT_DUMMY:
				strike = SpellDB.get_spell(int(spell.get("EffectBasePoints1", -1)) + 1)
			if strike.is_empty() or int(strike.get("Effect1", 0)) != SpellDB.EFFECT_SCHOOL_DAMAGE:
				return ""
			return "deals %s Holy damage, twice that to a stunned target." % _Values.new(strike, level).amount(0)
	return ""


## Cleric spells, or "" for other names.
static func _cleric(name: String, spell: Dictionary, t: _Values) -> String:
	var linked := _Values.new(SpellDB.get_spell(SpellDB.linked_spell(int(spell.get("Id", 0)))), t.level)
	match name:
		"Lesser Mending", "Mending", "Greater Mending":
			return "Heals a friendly target for %s." % t.amount(0)
		"Swift Mending":
			return "Quickly heals a friendly target for %s." % t.amount(0)
		"Desperate Plea":
			return "Instantly heals you for %s." % t.amount(0)
		"Communal Mending":
			return "Heals every party member within 30 yards for %s." % t.amount(0)
		"Lingering Grace":
			return "Heals a friendly target for %s over %s." % [t.over_time(0), t.duration()]
		"Chastise":
			return "Strikes an enemy with holy light for %s Holy damage." % t.amount(0)
		"Sacred Flame":
			return "Burns an enemy with holy fire for %s Holy damage, and %s more over %s." % [t.amount(0), t.over_time(1), t.duration()]
		"Mind Lash":
			return "Lashes an enemy's mind for %s Shadow damage." % t.amount(0)
		"Gnawing Shadow":
			return "A shadow gnaws at an enemy for %s Shadow damage over %s." % [t.over_time(0), t.duration()]
		"Ravening Blight":
			return "A blight eats at an enemy for %s Shadow damage over %s, and heals you for the damage it deals." % [t.over_time(0), t.duration()]
		"Mind Rend":
			return "Rends an enemy's mind for %s Shadow damage over %s, slowing them by %s%% while you channel. Moving ends it." % [t.over_time(0), t.duration(), t.magnitude(1)]
		"Falling Stars":
			return "Calls down stars on an enemy for %s Arcane damage over %s while you channel. Moving ends it." % [t.over_time(0), t.duration()]
		"Blessed Burst":
			var heal := linked.amount(0) if not linked.spell.is_empty() else "some"
			return "A burst of holy light deals %s Holy damage to enemies within 10 yards and heals party members within 10 yards for %s. Causes no threat." % [t.amount(0), heal]
		"Mana Scorch":
			return "Burns away %s of an enemy's mana; they take half the burned amount as damage." % t.amount(0)
		"Litany of Fortitude":
			return "Increases a friendly target's Stamina by %s for %s." % [t.amount(0), t.duration()]
		"Uplifted Spirit":
			return "Increases a friendly target's Spirit by %s for %s." % [t.amount(0), t.duration()]
		"Communal Spirit":
			return "Increases the Spirit of everyone in your party by %s for %s." % [t.amount(0), t.duration()]
		"Shadow Warding":
			return "Increases a friendly target's Shadow resistance by %s for %s." % [t.amount(0), t.duration()]
		"Inner Flame":
			return "Increases your armor by %s for %s or %d melee hits taken." % [t.amount(0), t.duration(), int(spell.get("ProcCharges", 0))]
		"Sanctified Ward":
			return "Wards a friendly target, absorbing %s damage for %s. The target can't be warded again for 15 sec." % [t.amount(0), t.duration()]
		"Spent Soul":
			return "Can't be given a Sanctified Ward."
		"Veil of Humility":
			return "Fades from your enemies' notice, lowering your threat by %s for %s." % [t.magnitude(0), t.duration()]
		"Rite of Return":
			return "Brings a dead ally back to life with %s health and %s mana. Can't be used in combat." % [t.amount(0), t.misc(0)]
		"Purge Sickness":
			return "Cures a friendly target of one disease."
		"Cleanse Sickness":
			return "Cures a friendly target of one disease, and of another every 5 sec for %s." % t.duration()
		"Unweave":
			return "Removes a harmful magic effect from a friendly target, or a magic buff from an enemy."
		"Dread Wail":
			return "Lets out a terrible wail: up to %d enemies within 8 yards flee in fear for %s. Damage may break the effect." % [SpellCaster.MAX_FEAR_TARGETS, t.duration()]
		"Bind the Dead":
			return "Binds an undead enemy in place for up to %s. Damage breaks the effect." % t.duration()
		"Calm Mind":
			return "Calms a humanoid enemy for %s, so it notices you %s yards closer than before." % [t.duration(), t.magnitude(0)]
		"Featherfall":
			return "You fall slowly for %s. Taking damage ends it." % t.duration()
		"Stillness":
			return "Your next spell costs no mana and has a %d%% greater chance to be a critical strike." % roundi(SpellCaster.STILLNESS_CRIT)
		"Hush":
			return "Silences an enemy for %s, so it can't cast." % t.duration()
		"Leeching Embrace":
			return "Embraces an enemy for %s: your Shadow damage to it heals your party for %d%% of the damage." % [t.duration(), roundi(SpellCaster.EMBRACE_SHARE * 100.0)]
		"Kindled Power":
			return "Kindles a friendly target's power, increasing their spell damage and healing by %s%% for %s." % [t.amount(0), t.duration()]
		"Shroud of Shadow":
			return "Wraps you in shadow: your Shadow damage rises by %s%% and physical damage taken falls by %s%%, but you can't cast Holy spells. Cast again to leave it." % [t.amount(1), t.magnitude(2)]
		"Mana Rebuke":
			return "For %s, each spell that hits you burns %s of the caster's mana." % [t.duration(), _Values.new(SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0))), t.level).amount(0)]
		"Dread Ward":
			return "Wards a friendly target against the next fear effect, for %s." % t.duration()
		"Moon's Grace":
			return "Raises your chance to dodge by %s%% for %s." % [t.amount(1), t.duration()]
		"Withering Touch":
			if linked.spell.is_empty():
				return ""
			return "The next enemy to strike you in melee within %s takes %s Shadow damage, and its melee damage falls by %s for %s." % [t.duration(), linked.amount(0), linked.magnitude(1), linked.duration()]
		"Feeble Hex":
			return "Hexes an enemy for %s: its melee damage falls by %s and healing it receives by %s%%." % [t.duration(), t.magnitude(0), t.magnitude(1)]
		"Umbral Guard":
			if linked.spell.is_empty():
				return ""
			return "Surrounds you with shadows for %s. Each of the next %d attacks against you deals %s Shadow damage to the attacker." % [t.duration(), int(spell.get("ProcCharges", 0)), linked.amount(0)]
		"Borrowed Eyes":
			return "Lets you see through a target's eyes for %s. (Not in the game yet.)" % t.duration()
		"Dominate Will":
			return "Takes control of a humanoid's mind for up to %s. (Not in the game yet.)" % t.duration()
		"Font of Light":
			return "Raises a font of light that party members can use to heal. (Not in the game yet.)"
	return ""


## Man-at-Arms abilities, or "" for other names.
## The Ranger's spells (classic's Hunter's).
static func _ranger(name: String, spell: Dictionary, t: _Values, level: int) -> String:
	if name.begins_with("Track "):
		var kind := name.trim_prefix("Track ").to_lower()
		if kind == "hidden":
			return "Lets you see hidden enemies more easily. Only one tracking can be active at a time."
		return "Shows nearby %s on the minimap. Only one tracking can be active at a time." % kind
	if RangerAbilities.is_trap(spell):
		var trap := _Values.new({}, level)
		for i in 3:
			if int(spell.get("Effect%d" % (i + 1), 0)) == RangerAbilities.EFFECT_SUMMON_OBJECT:
				trap = _Values.new(SpellDB.get_spell(int(SpellDB.trap(int(spell.get("EffectMiscValue%d" % (i + 1), 0))).get("spell", 0))), level)
		var lasts := "Traps last 1 min and can only be set out of combat. Only one trap can be set at a time."
		match name:
			"Burning Trap":
				return "Sets a trap that sets the first enemy to come near ablaze, dealing %s Fire damage over %s. %s" % [trap.over_time(0), trap.duration(), lasts]
			"Frostbind Trap":
				return "Sets a trap that freezes the first enemy to come near solid for up to %s. Any damage breaks the ice. %s" % [trap.duration(), lasts]
			"Rime Trap":
				return "Sets a trap that covers the ground in ice when an enemy comes near, slowing every enemy on it by %s%% for %s. %s" % [trap.magnitude(0), trap.duration(), lasts]
			"Blast Trap":
				return "Sets a trap that explodes when an enemy comes near, dealing %s Fire damage to enemies around it and %s more over %s. %s" % [trap.amount(0), trap.over_time(1), trap.duration(), lasts]
	match name:
		"Auto Shot":
			return "Shoots your target with your ranged weapon again and again until you stop. You must stand still to shoot, and be at least 8 yards away."
		"Talon Strike":
			return "Your next melee swing deals %s more damage." % t.amount(0)
		"Hawk Spirit":
			return "Takes on the spirit of the hawk, raising your ranged attack power by %s. Only one Spirit can be active at a time." % t.amount(0)
		"Monkey Spirit":
			return "Takes on the spirit of the monkey, raising your chance to dodge by %s%%. Only one Spirit can be active at a time." % t.amount(0)
		"Cheetah Spirit":
			return "Takes on the spirit of the cheetah, raising your run speed by %s%%. Being hit dazes you. Only one Spirit can be active at a time." % t.amount(0)
		"Pack Spirit":
			return "Takes on the spirit of the pack, raising the run speed of you and your party within 20 yards by %s%%. Anyone hit is dazed. Only one Spirit can be active at a time." % t.amount(0)
		"Beast Spirit":
			return "Takes on the spirit of the beast: beasts can't track you, and your melee attacks do more damage to them. Only one Spirit can be active at a time."
		"Wild Spirit":
			return "Takes on the spirit of the wild, raising the Nature resistance of you and your party within 20 yards by %s. Only one Spirit can be active at a time." % t.amount(0)
		"Adder Sting":
			return "Stings the target, dealing %s Nature damage over %s. Only one Sting per Ranger can be active on a target." % [t.over_time(0), t.duration()]
		"Stinger Venom":
			return "Stings the target, lowering its Strength and Agility by %s for %s. Only one Sting per Ranger can be active on a target." % [t.magnitude(0), t.duration()]
		"Asp Sting":
			return "Stings the target, draining %s mana over %s and giving you half. Only one Sting per Ranger can be active on a target." % [t.over_time(0), t.duration()]
		"Drake Sting":
			# The sleep, or the poison that follows it (its linked spell).
			if SpellDB.has_effect(spell, SpellDB.AURA_PERIODIC_DAMAGE, true):
				return "Poisoned: %s Nature damage over %s." % [t.over_time(0), t.duration()]
			var poison := _Values.new(SpellDB.get_spell(SpellDB.linked_spell(int(spell.Id))), level)
			return "Stings the target, putting it to sleep for %s. Any damage wakes it. When it wakes, a poison deals %s Nature damage over %s. Can't be used in combat." % [t.duration(), poison.over_time(0), poison.duration()]
		"Quarry's Mark":
			return "Marks an enemy for %s. Anyone shooting at it has %s more ranged attack power against it." % [t.duration(), t.amount(1)]
		"Glimmer Shot":
			return "An instant shot that deals %s Arcane damage." % t.amount(0)
		"Hobbling Shot":
			return "Hobbles the target, slowing its movement by %s%% for %s." % [t.magnitude(0), t.duration()]
		"Careful Shot":
			return "A slow, careful shot that deals %s more damage than a normal shot." % t.amount(0)
		"Spread Shot":
			return "Fires several arrows at once, hitting the target and up to two enemies near it, each for %s more damage than a normal shot." % t.amount(0)
		"Taunting Shot":
			return "A shot that does no damage but draws a great deal of threat (%s) from the target." % t.amount(0)
		"Scattering Shot":
			return "A short-range shot that deals %s%% weapon damage and confuses the target for %s. Any damage ends it." % [t.amount(0), t.duration()]
		"Arrow Rain":
			return "Rains arrows on the target's ground, dealing %s Arcane damage to every enemy there each second for %s while you channel." % [t.amount(0), t.duration()]
		"Crippling Cut":
			return "Strikes an enemy, slowing its movement by %s%% for %s." % [t.magnitude(0), t.duration()]
		"Weasel Bite":
			return "A strike for %s damage, which you can use only after the enemy dodges." % t.amount(0)
		"Counterattack":
			return "A strike for %s damage that roots the enemy for %s, which you can use only after you parry." % [t.amount(0), t.duration()]
		"Break Away":
			return "Tries to break away from the enemy in melee, lowering your threat with it by %s." % t.magnitude(0)
		"Still as Death":
			return "You drop to the ground, still as death. Enemies forget you and turn away, until you move. Lasts up to %s." % t.duration()
		"Quick Fire":
			return "Fires faster: your ranged attacks are %s%% quicker for %s." % [t.amount(0), t.duration()]
		"Frighten Beast":
			return "Scares a beast, making it flee for up to %s. Damage may break the effect." % t.duration()
		"Creature Lore":
			return "Studies a beast, learning what it is and what it can do."
		"Distant Gaze":
			return "Sends your sight far out over the land for up to %s. Moving brings it back." % t.duration()
		"Flare":
			return "Lights up the area with a burst of fire, showing anything hiding there."
		"Sharpshooter's Aura":
			return "Raises your attack power and ranged attack power by %s." % t.amount(0)
		"Menace":
			if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
				return "Stunned."
			return "Your pet's next hit within %s stuns its target for 3 sec and draws its attention." % t.duration()
		"Beast Fury":
			return "Sends your pet into a fury for %s: it deals %s%% more damage and can't be stunned." % [t.duration(), t.amount(1)]
		"Slipstep":
			return "Raises your chance to dodge and parry by %s%% for %s." % [t.amount(0), t.duration()]
		"Frenzied Strikes":
			return "Attack speed raised by %s%%." % t.amount(0)
		"Quick Shots":
			return "Ranged attack speed raised by %s%%." % t.amount(0)
	return ""


static func _man_at_arms(name: String, spell: Dictionary, t: _Values) -> String:
	var lasts := t.duration()
	match name:
		"Vanguard Stance":
			return "A balanced fighting stance that draws less threat. Changing stance loses your rage."
		"Bastion Stance":
			return "A guarded stance: you take 10% less damage and deal 10% less, and draw 30% more threat. Changing stance loses your rage."
		"Fury Stance":
			return "A reckless stance: 3% more chance to crit, but you take 10% more damage and draw less threat. Changing stance loses your rage."
		"Mighty Blow":
			return "Your next melee swing deals %s more damage." % t.amount(0)
		"Sweeping Cut":
			return "Your next melee swing hits the target and an enemy beside it, each for weapon damage plus %s." % t.amount(0)
		"Heavy Swing":
			return "Winds up a heavy swing for weapon damage plus %s." % t.amount(0)
		"Riposte Strike":
			return "Usable for 5 sec after the target dodges: strikes for weapon damage plus %s. Can't be dodged, parried or blocked." % t.amount(0)
		"Retort":
			return "Usable for 5 sec after you block, dodge or parry: strikes back for %s damage." % t.amount(0)
		"Finishing Blow":
			return "Finishes off an enemy below 20%% health for %s damage, plus %s for each point of rage left after the cost. Uses all your rage." % [t.amount(0), _number(float(spell.get("DmgMultiplier1", 0.3)) * 10.0)]
		"Grievous Strike":
			return "A grievous strike for weapon damage plus %s. The target receives 50%% less healing for %s." % [t.amount(1), lasts]
		"Bloodlust Strike":
			return "Strikes for damage equal to %s%% of your attack power." % t.amount(0)
		"Shield Crush":
			return "Smashes an enemy with your shield for %s damage, and strips a magic effect from it." % t.amount(1)
		"Cyclone Strike":
			return "Spins, striking up to %d enemies within 8 yards with your weapon." % WarriorAbilities.MAX_AREA_TARGETS
		"Ground Slam":
			return "Slams the ground, dealing %s damage to up to %d enemies within 8 yards and slowing their attacks by %s%% for %s." % [t.amount(0), WarriorAbilities.MAX_AREA_TARGETS, t.magnitude(1), lasts]
		"Gash":
			return "Wounds an enemy for %s damage over %s." % [t.over_time(0), lasts]
		"Hobble":
			return "Strikes an enemy for %s damage and slows its movement by %s%% for %s." % [t.amount(0), t.magnitude(1), lasts]
		"Rend Armor":
			return "Lowers an enemy's armor by %s for %s. Stacks up to %d times." % [t.magnitude(0), lasts, int(spell.get("StackAmount", 1))]
		"Wrest Weapon":
			return "Wrests the weapon from an enemy for %s, halving its melee damage." % lasts
		"Shield Smash", "Hilt Strike":
			return "Strikes an enemy for %s damage and interrupts its spellcasting, keeping it from casting spells of that school for %s." % [t.amount(1 if name == "Shield Smash" else 0), lasts]
		"Stunning Blow":
			return "Stuns an enemy for %s." % lasts
		"Taunting Blow":
			return "A taunting strike for %s damage that makes the enemy attack you for %s." % [t.amount(0), lasts]
		"Goad":
			return "Goads an enemy into attacking you for %s, putting you at the top of its threat." % lasts
		"Daring Roar":
			return "Dares every enemy within 10 yards to attack you for %s." % lasts
		"Rush":
			return "Rushes an enemy 8 to 25 yards away, stunning it for 1 sec and gaining %d rage. Can't be used in combat." % roundi(t.low(1) / 10.0)
		"Cut Off":
			return "Rushes an enemy 8 to 25 yards away even in combat, stunning it for 3 sec."
		"Rallying Cry":
			return "Raises the attack power of party members within 20 yards by %s for %s." % [t.amount(0), lasts]
		"Daunting Roar":
			return "Lowers the attack power of enemies within 10 yards by %s for %s." % [t.magnitude(0), lasts]
		"Crippling Howl":
			return "Slows every enemy within 10 yards by %s%% for %s." % [t.magnitude(0), lasts]
		"Cowing Roar":
			return "Your target cowers in place, and up to %d enemies nearby flee in fear, for %s." % [WarriorAbilities.MAX_FEAR_TARGETS, lasts]
		"Blood Fury":
			return "Gains %d rage at the cost of some health, then 10 more over 10 sec." % roundi(t.low(0) / 10.0)
		"Shield Brace":
			return "Raises your chance to block by %s%% for %s or one block." % [t.amount(0), lasts]
		"Wall of Steel":
			return "Reduces all damage you take by %s%% for %s." % [t.magnitude(0), lasts]
		"Reprisal":
			return "For %s, strikes back at each melee attack from in front of you, up to %d times." % [lasts, int(spell.get("ProcCharges", 0))]
		"Unbridled Rage":
			return "You can't be frightened for %s." % lasts
		"Abandon":
			return "For %s your attacks are far more likely to crit, but you take %s%% more damage. You can't be frightened." % [lasts, t.amount(1)]
		"Death Craving":
			return "For %s your physical damage rises by %s%% and you can't be frightened, but your armor falls by %s%%." % [lasts, t.amount(0), t.magnitude(2)]
		"Final Stand":
			return "Raises your maximum health by %d%% for 20 sec." % roundi(WarriorAbilities.FINAL_STAND_SHARE * 100.0)
		"Wide Swings":
			return "Your next %d melee hits also strike another enemy beside you." % int(spell.get("ProcCharges", 0))
		"Two-Weapon Fighting":
			return "Lets you fight with a one-handed weapon in each hand. The off hand hits for half damage."
	return ""


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


## The Magus's spells (MagusAbilities), and the effects they leave.
static func _magus(name: String, spell: Dictionary, t: _Values, level: int) -> String:
	var radius := func(effect: int) -> String: return _number(SpellDB.effect_radius(spell, effect, _who))
	if name.begins_with("Conjure "):
		var item_id := int(spell.get("EffectItemType1", 0))
		var item_name := str(ItemDB.get_item(item_id).get("name", "something"))
		if MagusAbilities._is_mana_stone(item_id):
			return "Conjures a %s, which restores mana when used. You can carry only one." % item_name
		if name == "Conjure Draught":
			return "Conjures %s %s to drink." % [t.amount(0), item_name]
		return "Conjures %s %s to eat." % [t.amount(0), item_name]
	if not MagusAbilities.is_magus_spell(spell) and not name in ["Lucid Mind", "Searing Weakness", "Deepening Chill", "Frostgrip", "Spellbreak - Silenced"]:
		return ""
	match name:
		"Arcane Wisdom":
			return "Raises a friendly target's Intellect by %s for %s." % [t.amount(0), t.duration()]
		"Rime Bolt":
			if not SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE):
				return ""
			return "Launches a bolt of frost at an enemy, dealing %s Frost damage and slowing its movement by %s%% for %s." % [t.amount(1), t.magnitude(0), t.duration()]
		"Flame Bolt", "Blazing Orb":
			if not SpellDB.has_effect(spell, SpellDB.AURA_PERIODIC_DAMAGE, true):
				return "Hurls a bolt of fire at an enemy for %s Fire damage." % t.amount(0)
			var what := "a fiery bolt" if name == "Flame Bolt" else "a great orb of fire"
			return "Hurls %s at an enemy, dealing %s Fire damage and %s more over %s." % [what, t.amount(0), t.over_time(1), t.duration()]
		"Flame Jet":
			return "Blasts an enemy with flame for %s Fire damage." % t.amount(0)
		"Searing Touch":
			return "Scorches an enemy for %s Fire damage." % t.amount(0)
		"Beastshape":
			return "Turns an enemy beast or humanoid into a sheep for up to %s. A sheep can't attack or cast, and heals quickly. Any damage breaks the effect. Only one enemy can be your sheep at a time." % t.duration()
		"Arcane Darts":
			var dart := _Values.new(SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0))), level)
			var darts := floori(t.seconds() / t.period(0) + 0.001)
			return "Looses %d darts of arcane power at an enemy over %s, each dealing %s Arcane damage. Moving ends it." % [darts, t.duration(), dart.amount(0)]
		"Arcane Dart":
			return "Deals %s Arcane damage." % t.amount(0)
		"Rime Burst":
			return "Blasts enemies within %s yards with frost for %s Frost damage, freezing them in place for up to %s. Damage may break the ice." % [radius.call(0), t.amount(0), t.duration()]
		"Arcane Nova":
			return "Releases a nova of arcane power, dealing %s Arcane damage to enemies within %s yards." % [t.amount(0), radius.call(0)]
		"Frost Fan":
			return "Blasts enemies in a cone in front of you with frost for %s Frost damage, slowing them by %s%% for %s." % [t.amount(1), t.magnitude(0), t.duration()]
		"Searing Wave":
			return "A wave of flame bursts out from you, dealing %s Fire damage to enemies within %s yards and slowing them by %s%% for %s." % [t.amount(0), radius.call(0), t.magnitude(1), t.duration()]
		"Pillar of Flame":
			return "Calls a pillar of flame down where your enemy target stands, dealing %s Fire damage to enemies within %s yards, and %s more over %s to those that stay in the flames." % [t.amount(0), radius.call(0), t.over_time(1), t.duration()]
		"Hailstorm":
			return "Calls down hail where your enemy target stands, dealing %s Frost damage over %s to enemies within %s yards while you channel." % [t.over_time(0), t.duration(), radius.call(0)]
		"Rime Shroud", "Hoarfrost Shroud":
			return "Raises your armor by %s for %s. Enemies that strike you in melee may be chilled, slowing their movement and attacks." % [t.amount(0), t.duration()]
		"Magus Armor":
			return "Raises your resistance to all magic by %s for %s, and lets %s%% of your mana regeneration go on while you cast." % [t.amount(0), t.duration(), t.amount(1)]
		"Featherdrift":
			return "You fall slowly for %s, and take no damage from falling." % t.duration()
		"Muffle Magic":
			return "Lowers the damage a friendly target takes from spells by %s, and the healing it gets from them by %s, for %s." % [t.magnitude(0), t.magnitude(1), t.duration()]
		"Magnify Magic":
			return "Raises the damage a friendly target takes from spells by %s, and the healing it gets from them by %s, for %s." % [t.amount(0), t.amount(1), t.duration()]
		"Sense Magic":
			return "Reveals the magic on an enemy for %s." % t.duration()
		"Lift Lesser Curse":
			return "Lifts one curse from a friendly target."
		"Ember Ward":
			return "Wards you against fire, absorbing %s Fire damage. Lasts %s." % [t.amount(0), t.duration()]
		"Rime Ward":
			return "Wards you against frost, absorbing %s Frost damage. Lasts %s." % [t.amount(0), t.duration()]
		"Mana Barrier":
			var per_point := _number(float(spell.get("EffectMultipleValue1", 2.0)))
			return "Shields you, absorbing %s damage for %s. Each point absorbed costs %s mana; it ends when your mana runs out." % [t.amount(0), t.duration(), per_point]
		"Ice Bulwark":
			return "Shields you in ice, absorbing %s damage. Lasts %s." % [t.amount(0), t.duration()]
		"Flicker":
			return "Teleports you up to %s yards forward, freeing you from stuns and roots." % radius.call(0)
		"Arcane Renewal":
			return "Channels for %s, regaining mana %s times as fast, and even while casting. Moving ends it." % [t.duration(), _number(1.0 + t.low(0) / 100.0)]
		"Spellbreak":
			return "Interrupts an enemy's spell, keeping it from casting spells of that school for %s." % t.duration()
		"Spellbreak - Silenced":
			return "Silenced: can't cast spells."
		"Frozen Vigil":
			return "Encases you in ice for %s: you're immune to all damage, but can't move or act. Cast it again, or cancel it, to break free." % t.duration()
		"Rime Renewal":
			return "Your Rime spells are ready to cast again."
		"Swift Mind":
			return "Your next spell with a cast time is cast instantly."
		"Arcane Ascendance":
			return "Your spells deal %s%% more damage and cost %s%% more mana for %s." % [t.amount(0), t.amount(1), t.duration()]
		"Kindling":
			return "Each fire spell you cast that doesn't crit raises the next one's chance to crit by %s%%, until %d have crit." % [_number(MagusAbilities.KINDLING_STEP), MagusAbilities.KINDLING_CRITS]
		"Lucid Mind":
			return "Your next damage or healing spell costs no mana."
		"Searing Weakness":
			return "Fire damage taken raised by %s%%." % t.amount(0)
		"Deepening Chill":
			if SpellDB.has_effect(spell, SpellDB.AURA_PROC_TRIGGER_SPELL, true):
				return ""
			return "Frost spells are %s%% more likely to crit it." % t.amount(0)
		"Frostgrip":
			if SpellDB.has_effect(spell, MagusAbilities.AURA_ADD_TARGET_TRIGGER, true):
				return ""
			return "Frozen in place."
	return ""


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
		var span := SpellDB.effect_span(spell, effect, level, SpellText._who) * SpellText._stacks
		var low := roundi(absf(span.x))
		var high := roundi(absf(span.y))
		return str(low) if high <= low else "%d to %d" % [low, high]

	func low(effect: int) -> float:
		return absf(SpellDB.effect_span(spell, effect, level, SpellText._who).x) * SpellText._stacks

	## The total of a periodic effect over its duration: "90", or "84 to 90".
	func over_time(effect: int) -> String:
		var ticks := floori(seconds() / period(effect) + 0.001)
		var span := SpellDB.effect_span(spell, effect, level, SpellText._who) * ticks * SpellText._stacks
		var low_total := roundi(absf(span.x))
		var high_total := roundi(absf(span.y))
		return str(low_total) if high_total <= low_total else "%d to %d" % [low_total, high_total]

	## The size of a reduction, as a positive number.
	func magnitude(effect: int) -> String:
		return str(roundi(low(effect)))

	func misc(effect: int) -> String:
		return str(int(spell.get("EffectMiscValue%d" % (effect + 1), 0)))

	func seconds() -> float:
		return SpellDB.duration(spell, SpellText._who)

	## Tick time of a periodic effect, in seconds.
	func period(effect: int) -> float:
		return maxf(float(spell.get("EffectAmplitude%d" % (effect + 1), 1000)) / 1000.0, 0.001)

	func duration() -> String:
		var time := seconds()
		if time < 0.0:
			return "as long as it lasts"
		return time_text(time)

	## "30 sec", "2 min", "1 hr".
	static func time_text(time: float) -> String:
		if time >= 3600.0:
			return "%s hr" % _number(time / 3600.0)
		if time >= 60.0:
			return "%s min" % _number(time / 60.0)
		return "%s sec" % _number(time)

	static func _number(value: float) -> String:
		return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
