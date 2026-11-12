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
	# The game's own classes' spells carry their text (ClassicData.CLASS_FILES).
	if spell.has("Description"):
		return str(spell.Description)
	var talent := TalentText.describe(spell, level)
	if not talent.is_empty():
		return talent
	var t := _Values.new(spell, level)
	for prefix in ["Pattern: ", "Plans: ", "Recipe: ", "Formula: ", "Schematic: "]:
		if name.begins_with(prefix):
			return "Teaches you how to make %s." % name.trim_prefix(prefix)
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
		return _oath(name, spell, t, caster)
	var cleric := _cleric(name, spell, t)
	if not cleric.is_empty():
		return cleric
	var man_at_arms := _man_at_arms(name, spell, t)
	if not man_at_arms.is_empty():
		return man_at_arms
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

	## The total of a periodic effect over its duration: "90", or "84 to 90".
	func over_time(effect: int) -> String:
		var ticks := floori(seconds() / period(effect) + 0.001)
		var span := SpellDB.effect_range(spell, effect, level) * ticks
		var low_total := roundi(absf(span.x))
		var high_total := roundi(absf(span.y))
		return str(low_total) if high_total <= low_total else "%d to %d" % [low_total, high_total]

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
