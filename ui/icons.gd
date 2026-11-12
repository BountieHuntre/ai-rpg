class_name Icons
extends RefCounted
## Which painted icon each item and spell shows, and the icons themselves.
## An icon is a key (IconPainter: "design" or "design_variant") whose picture
## tools/icons/bake_icons.gd renders into assets/icons/<key>.png. Items pick
## theirs by kind (weapon type, armor slot and material, quality for gems and
## trim) and, for consumables, goods and quest items, by words in their name;
## spells by name (CLASS_SPELLS), by family ("Boon of", "Oath of", "...
## Presence"), else by school and effect.

const DIR := "res://assets/icons/"
const QUALITY := ["poor", "common", "uncommon", "rare", "epic", "epic", "epic"]

static var _textures: Dictionary = {}


## The icon for a key, or the fallback when it hasn't been baked.
static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		var path := DIR + key + ".png"
		_textures[key] = load(path) if ResourceLoader.exists(path) else (load(DIR + "unknown.png") if ResourceLoader.exists(DIR + "unknown.png") else null)
	return _textures[key]


static func for_item(id: int) -> Texture2D:
	return texture(item_key(ItemDB.get_item(id)))


static func for_spell(id: int) -> Texture2D:
	return texture(spell_key(SpellDB.get_spell(id)))


# Items.

const WEAPONS := {
	0: "axe", 1: "greataxe", 2: "bow", 3: "gun", 4: "mace", 5: "maul", 6: "polearm", 7: "sword", 8: "greatsword",
	10: "staff", 13: "dagger", 14: "dagger", 15: "dagger", 16: "dagger", 18: "crossbow", 19: "wand", 20: "staff",
}
const SLOTS := {
	1: "helm", 3: "shoulders", 4: "shirt", 5: "chest", 20: "chest", 6: "belt", 7: "legs", 8: "boots", 9: "bracers",
	10: "gloves", 16: "cloak", 19: "chest",
}
const MATERIALS := { 1: "cloth", 2: "leather", 3: "mail", 4: "plate" }
## Words in an item's name and the icon they mean, first match wins.
const NAME_ICONS := [
	["healing potion", "potion_red"], ["mana potion", "potion_blue"], ["potion", "potion_green"], ["liquor", "bottle"],
	["scroll of strength", "scroll_strength"], ["scroll of agility", "scroll_agility"], ["scroll of intellect", "scroll_intellect"],
	["scroll of spirit", "scroll_spirit"], ["scroll of stamina", "scroll_stamina"], ["scroll of protection", "scroll_protection"],
	["milk", "flask_milk"], ["juice", "flask_juice"], ["nectar", "flask_juice"], ["water", "flask_water"], ["dew", "flask_water"],
	["cheese", "cheese"], ["brie", "cheese"], ["cheddar", "cheese"], ["swiss", "cheese"], ["sharp", "cheese"], ["mild", "cheese"],
	["pie", "pie"], ["loaf", "bread"], ["bread", "bread"], ["apple", "fruit_apple"], ["melon", "fruit_melon"], ["pumpkin", "fruit_pumpkin"],
	["mackerel", "fish"], ["snapper", "fish"], ["fish", "fish"], ["woodcap", "mushroom_brown"], ["mushroom", "mushroom"],
	["candle", "candle"], ["taper", "candle"], ["cologne", "bottle_perfume"], ["perfume", "bottle_perfume"], ["beads", "pouch"],
	["gold dust", "pouch_gold"], ["token", "token"], ["linen cloth", "cloth_linen"], ["cloth", "cloth"], ["copper ore", "ore_copper"],
	["iron ore", "ore_iron"], ["ore", "ore"], ["salt", "stone_salt"], ["stone", "stone"], ["malachite", "gem_malachite"],
	["tigerseye", "gem_tigerseye"], ["shadowgem", "gem_shadowgem"], ["pearl", "gem_pearl"], ["bruisewort", "herb_bruise"],
	["blossom", "herb_blossom"], ["sageleaf", "herb_sage"], ["thistle", "herb_thistle"], ["kelp", "herb_kelp"],
	["gold tooth", "tooth_gold"], ["tusk", "tooth_tusk"], ["claw", "tooth_claw"], ["paw", "tooth_paw"], ["foot", "tooth_paw"],
	["tooth", "tooth"], ["teeth", "tooth"], ["fang", "tooth"], ["canine", "tooth"], ["eye", "eye"], ["torn mirefin fin", "fin_torn"],
	["fin", "fin"], ["limb", "limb"], ["leg", "limb"], ["webbing", "web"], ["egg", "egg"], ["pelt", "pelt"], ["seashell", "shell"],
	["clam", "shell"], ["meat", "meat_raw"], ["haunch", "meat"], ["strip", "meat"], ["necklace", "amulet_common"],
	["collar", "collar"], ["medallion", "medallion"], ["signet", "ring_rare"], ["armband", "bracers_cloth"],
	["bandana", "bandana"], ["mask", "bandana"], ["letter", "paper_sealed"], ["note", "paper"], ["deed", "paper_sealed"],
	["cipher", "paper"], ["ledger", "paper"], ["itinerary", "paper"], ["bundle of wood", "logs"], ["quiver", "quiver"],
	["sack", "pouch"],
]
const BAG_COLORS := ["red", "blue", "green", "white", "black", "brown"]


static func item_key(item: Dictionary) -> String:
	if item.is_empty():
		return "unknown"
	var item_class := int(item.get("class", 0))
	var subclass := int(item.get("subclass", 0))
	var quality: String = QUALITY[clampi(int(item.get("Quality", 1)), 0, QUALITY.size() - 1)]
	var lower := str(item.get("name", "")).to_lower()
	match item_class:
		2:
			return "%s_%s" % [WEAPONS.get(subclass, "sword"), quality]
		4:
			var slot := int(item.get("InventoryType", 0))
			if subclass == 6 or slot == 14:
				return "shield_%s" % ("wood" if quality == "poor" else quality)
			match slot:
				2:
					return "amulet_" + quality
				11:
					return "ring_" + quality
				12:
					return "trinket"
				23:
					return "orb"
			if SLOTS.has(slot):
				return "%s_%s_%s" % [SLOTS[slot], MATERIALS.get(subclass, "cloth"), quality]
		1:
			for color in BAG_COLORS:
				if lower.contains(color):
					return "bag_" + color
			return "bag_brown"
		9:
			return "book"
	for entry: Array in NAME_ICONS:
		if lower.contains(entry[0]):
			return entry[1]
	if item_class == 0:
		return "bread"
	return "unknown"


# Spells.

## Class spells by name, and the creatures' spells and debuffs.
const CLASS_SPELLS := {
	# The Ranger's.
	"Auto Shot": "bow_common", "Talon Strike": "strike", "Hawk Spirit": "feather", "Monkey Spirit": "parry_red", "Cheetah Spirit": "charge", "Pack Spirit": "shout_gold", "Beast Spirit": "tooth_paw", "Wild Spirit": "herb_sage", "Adder Sting": "poison", "Stinger Venom": "hex", "Asp Sting": "mind", "Drake Sting": "mind_calm", "Quarry's Mark": "eye", "Glimmer Shot": "bolt_blue", "Hobbling Shot": "hobble", "Careful Shot": "bow_uncommon", "Spread Shot": "quiver", "Taunting Shot": "taunt", "Scattering Shot": "stun", "Arrow Rain": "stars", "Crippling Cut": "limb", "Weasel Bite": "tooth", "Counterattack": "parry", "Break Away": "ward", "Still as Death": "shadow", "Quick Fire": "zeal", "Frighten Beast": "fear", "Creature Lore": "book", "Distant Gaze": "eye", "Flare": "fire", "Burning Trap": "burn", "Frostbind Trap": "frost", "Rime Trap": "frost", "Blast Trap": "fire", "Mend Companion": "heal_green", "Sharpshooter's Aura": "presence_focused", "Beast's Eyes": "eye", "Track Beasts": "tooth_paw", "Track Humanoids": "eye", "Track Undead": "shadow", "Track Hidden": "eye", "Track Elementals": "stone", "Track Demons": "fire", "Track Giants": "slam", "Track Dragonkin": "fin",
	# Ranger talents and what they bring.
	"Hardiness Training": "heart", "Tough Hide": "pelt", "Improved Revive Companion": "revive", "Trailblazing": "charge", "Beast Swiftness": "tooth_paw", "Unbound Fury": "tooth_claw", "Wild Ferocity": "tooth_claw", "Kindred Bond": "heal_green", "Menace": "tooth_tusk", "Beast Discipline": "tooth_gold", "Frenzy": "rage", "Frenzied Strikes": "rage", "Beast Fury": "tooth_claw",
	"Efficiency": "quiver", "Deadly Aim": "bow_uncommon", "Keen Sight": "eye", "Grievous Shots": "bleed", "Barrage": "quiver", "Ranged Weapon Mastery": "gun_uncommon", "Quick Shots": "feather",
	"Monster Hunter": "tooth_paw", "Manhunter": "execute", "Ensnaring Traps": "frost", "Brutal Strikes": "strike_red", "Cunning Traps": "burn", "Hardy": "heart", "Slipstep": "parry_red", "Trap Craft": "ground", "Sure Step": "boots_leather_common", "Predator's Instinct": "strike_red", "Quick Reflexes": "scroll_agility",
	"Attack": "attack", "Shoot": "bow_common", "Mighty Blow": "strike", "Heavy Swing": "heavy", "Sweeping Cut": "cyclone", "Cyclone Strike": "cyclone",
	"Rush": "charge", "Cut Off": "charge", "Vanguard Stance": "stance_vanguard", "Bastion Stance": "stance_bastion",
	"Fury Stance": "stance_fury", "Rallying Cry": "shout_red", "Daunting Roar": "shout_dark", "Cowing Roar": "shout_dark",
	"Daring Roar": "shout_gold", "Gash": "bleed", "Grievous Strike": "bleed", "Rend Armor": "bleed", "Ground Slam": "slam",
	"Shield Smash": "bash", "Shield Crush": "bash_red", "Shield Brace": "aegis", "Wall of Steel": "aegis", "Goad": "taunt",
	"Taunting Blow": "taunt", "Parry": "parry", "Riposte Strike": "parry_red", "Retort": "parry", "Reprisal": "parry_red",
	"Hilt Strike": "hilt", "Hobble": "hobble", "Finishing Blow": "execute", "Blood Fury": "rage", "Unbridled Rage": "rage",
	"Bloodlust Strike": "strike_red", "Abandon": "rage", "Wrest Weapon": "disarm", "Two-Weapon Fighting": "dual",
	"Verdict": "verdict", "Stunning Gavel": "gavel", "Gavel of Reckoning": "gavel", "Mending Radiance": "heal_gold",
	"Quick Radiance": "heal_white", "Last Rite": "heal_gold", "Hallowed Ransom": "heal_white", "Cleansing Touch": "cleanse",
	"Greater Cleansing": "cleanse", "Purge Sickness": "cleanse", "Cleanse Sickness": "cleanse", "Unweave": "cleanse",
	"Revival": "revive", "Rite of Return": "revive", "Hallowed Guard": "aegis", "Hallowed Aegis": "aegis",
	"Radiant Bulwark": "aegis", "Hallowed Ground": "ground", "Banishment": "banish", "Rebuke the Dead": "banish",
	"Bind the Dead": "banish", "Zealous Fervor": "zeal", "Radiant Fury": "zeal", "Radiant Jolt": "bolt_gold",
	"Chastise": "bolt_gold", "Sacred Flame": "flame_gold", "Blessed Burst": "bolt_white", "Plate Mail": "chest_plate_common",
	"Litany of Fortitude": "heart", "Uplifted Spirit": "flame_blue", "Communal Spirit": "flame_blue", "Inner Flame": "flame_orange",
	"Moon's Grace": "bolt_blue", "Lesser Mending": "heal_gold", "Mending": "heal_gold", "Greater Mending": "heal_gold",
	"Swift Mending": "heal_white", "Desperate Plea": "heal_white", "Communal Mending": "heal_green", "Lingering Grace": "renew",
	"Sanctified Ward": "ward", "Dread Ward": "ward_dread", "Umbral Guard": "ward_umbral", "Shadow Warding": "ward_shadow",
	"Gnawing Shadow": "shadow", "Withering Touch": "shadow", "Ravening Blight": "poison", "Mind Rend": "mind",
	"Mind Lash": "mind", "Calm Mind": "mind_calm", "Borrowed Eyes": "mind", "Dominate Will": "mind", "Dread Wail": "fear",
	"Veil of Humility": "fear", "Feeble Hex": "hex", "Falling Stars": "stars", "Mana Scorch": "burn", "Mana Rebuke": "burn",
	"Featherfall": "feather", "Font of Light": "font",
	"Poison": "poison", "Poison Proc": "poison", "Flame Bolt": "fire", "Rime Bolt": "frost", "Rime Shroud": "frost",
	"Chilled": "frost", "Thrash": "rage", "Prying Strike": "bleed", "Head Butt": "stun", "Low Jab": "stun",
	"Back Thrust": "strike", "Snap Kick": "hilt", "Headlong Charge": "charge", "Food": "bread", "Drink": "flask_water",
	"Healing Potion": "potion_red", "Restore Mana": "potion_blue",
}
const WEAPON_SKILLS := {
	"One-Handed Axes": "axe_common", "Two-Handed Axes": "greataxe_common", "One-Handed Maces": "mace_common",
	"Two-Handed Maces": "maul_common", "One-Handed Swords": "sword_common", "Two-Handed Swords": "greatsword_common",
	"Staves": "staff_common", "Bows": "bow_common", "Guns": "gun_common", "Daggers": "dagger_common", "Thrown": "dagger_common",
	"Crossbows": "crossbow_common", "Fist Weapons": "dagger_common", "Polearms": "polearm_common", "Wands": "wand_common",
}
## Words in a talent's (or passive's) name and the icon they mean.
const TALENT_WORDS := [
	["Axeman", "axe_common"], ["Maceman", "mace_common"], ["Swordsman", "sword_common"], ["Polearm", "polearm_common"],
	["Two-Handed", "greatsword_common"], ["One-Handed", "sword_common"], ["Two-Weapon", "dual"], ["Shield", "bash"],
	["Toughness", "aegis"], ["Deflection", "parry"], ["Anticipation", "parry"], ["Precision", "parry"], ["Tooth", "parry_red"],
	["Resolve", "heart"], ["Will", "heart"], ["Defiance", "aegis"], ["Stand", "aegis"], ["Guard", "aegis"], ["Discipline", "stance_vanguard"],
	["Wrath", "rage"], ["Rage", "rage"], ["Fury", "rage"], ["Frenzy", "rage"], ["Craving", "rage"], ["Bloodied", "rage"], ["Anger", "rage"],
	["Voice", "shout_red"], ["Howl", "shout_dark"], ["Edge", "strike"], ["Thrust", "strike"], ["Wounds", "bleed"], ["Swings", "cyclone"],
	["Blow", "strike_red"], ["Presence", "presence_bulwark"], ["Zeal", "zeal"], ["Justice", "verdict"], ["Rebuke", "verdict"],
	["Certainty", "verdict"], ["Contrition", "verdict"], ["Spellward", "ward"], ["Hearten", "heart"], ["Martyr", "boon_martyr"],
	["Thrift", "bolt_blue"], ["Kindled", "flame_orange"], ["Scorching", "flame_gold"], ["Spirit", "flame_blue"],
	["Mending", "heal_gold"], ["Recovery", "heal_green"], ["Prayer", "heal_white"], ["Grace", "renew"],
	["Shadow", "shadow"], ["Gloom", "shadow"], ["Leeching", "shadow"], ["Harvest", "shadow"], ["Hush", "fear"],
	["Intellect", "bolt_blue"], ["Mind", "mind_calm"], ["Wandwork", "wand_common"], ["Stillness", "mind_calm"],
	["Contemplation", "mind_calm"], ["Calm", "mind_calm"], ["Focus", "mind_calm"], ["Strength", "boon_strength"],
	["Faith", "heal_gold"], ["Favor", "heal_gold"], ["Power", "bolt_gold"], ["Light", "bolt_gold"], ["Sacred", "bolt_gold"],
	["Blessed", "heal_gold"], ["Radiance", "heal_gold"], ["Mastery", "heal_gold"],
]
const SCHOOL_ICONS := ["strike", "bolt_gold", "fire", "poison", "frost", "shadow", "bolt_purple"]
const EFFECT_HEAL := 10


static func spell_key(spell: Dictionary) -> String:
	if spell.is_empty():
		return "unknown"
	var spell_name := str(spell.get("SpellName", ""))
	# The game's own classes' spells name their icon (ClassicData.CLASS_FILES).
	if spell.has("Icon"):
		return str(spell.Icon)
	if CLASS_SPELLS.has(spell_name):
		return CLASS_SPELLS[spell_name]
	if WEAPON_SKILLS.has(spell_name):
		return WEAPON_SKILLS[spell_name]
	if spell_name.begins_with("Boon of ") or spell_name.begins_with("Greater Boon of "):
		var word := spell_name.get_slice(" of ", 1).replace("the ", "").to_lower()
		return "boon_" + word
	if spell_name.begins_with("Oath of "):
		return "oath_" + spell_name.get_slice(" of ", 1).replace("the ", "").to_lower()
	if spell_name.ends_with(" Presence"):
		return "presence_" + spell_name.get_slice(" ", 0).to_lower()
	if spell_name.ends_with(" Stance"):
		return "stance_" + spell_name.get_slice(" ", 0).to_lower()
	if spell_name.begins_with("Boons") or spell_name.begins_with("Greater Boons"):
		return "boon_radiance"
	# "Improved Mighty Blow" shows Mighty Blow's icon.
	if spell_name.begins_with("Improved "):
		var base := spell.duplicate()
		base.SpellName = spell_name.trim_prefix("Improved ")
		var base_key := spell_key(base)
		if base_key != "passive":
			return base_key
	if int(spell.get("Effect1", 0)) == EFFECT_HEAL:
		return "heal_gold"
	# Talents and other passives by the words in their names.
	for entry: Array in TALENT_WORDS:
		if spell_name.contains(entry[0]):
			return entry[1]
	if SpellDB.is_passive(spell):
		return "passive"
	var school := int(spell.get("School", 0))
	return SCHOOL_ICONS[clampi(school, 0, SCHOOL_ICONS.size() - 1)]


# Portraits.

## A class's emblem, for the portraits of the player and playerbots.
const CLASS_PORTRAITS := {
	1: "stance_vanguard", 2: "boon_radiance", 3: "bow_common", 4: "dagger_common", 5: "heal_white",
	7: "frost", 8: "fire", 9: "shadow", 10: "sword_rare", 11: "renew",
}
## Words in a creature's name and its portrait, then its kind.
const CREATURE_PORTRAITS := [
	["Mirefin", "fin"], ["Ditchjaw", "tooth_paw"], ["Grunmaw", "tooth_paw"], ["Burrowling", "candle"], ["Brasstooth", "tooth_gold"],
	["Brigand", "bandana"], ["Collector", "ring_rare"], ["Spider", "limb"], ["Wolf", "tooth"], ["Prowler", "tooth_claw"],
	["Bear", "tooth_paw"], ["Boar", "tooth_tusk"], ["Hog", "tooth_tusk"], ["Duchess", "tooth_tusk"], ["Rabbit", "tooth_paw"],
]
const CREATURE_TYPE_BEAST := 1
const CREATURE_TYPE_UNDEAD := 6


## The portrait key for a unit frame: a class emblem for the player and
## playerbots, a creature's kind (a fang, a fin, a brigand's kerchief), or a
## token for an NPC.
static func portrait_key(unit: Node) -> String:
	if unit is PlayerUnit:
		return CLASS_PORTRAITS.get(int((unit as PlayerUnit).profile.char_class), "strike")
	if unit is Enemy:
		var enemy := unit as Enemy
		var creature_name := enemy.combatant.display_name
		for entry: Array in CREATURE_PORTRAITS:
			if creature_name.contains(entry[0]):
				return entry[1]
		var kind := int(Enemy.creature_data(enemy.creature_entry).get("CreatureType", 0))
		if kind == CREATURE_TYPE_BEAST:
			return "tooth_claw"
		if kind == CREATURE_TYPE_UNDEAD:
			return "banish"
		return "strike"
	return "token"


## Every icon key the game can ask for, for the bake: every item's, every
## spell's, and the fixed ones.
static func all_keys() -> Array[String]:
	var keys := { "unknown": true, "attack": true, "passive": true, "coin": true }
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classic/items.json"))
	for id: String in items:
		keys[item_key(items[id])] = true
	for spell_name: String in CLASS_SPELLS:
		keys[CLASS_SPELLS[spell_name]] = true
	for key: String in CLASS_PORTRAITS.values():
		keys[key] = true
	for entry: Array in CREATURE_PORTRAITS:
		keys[entry[1]] = true
	keys["tooth_claw"] = true
	keys["banish"] = true
	for skill: String in WEAPON_SKILLS:
		keys[WEAPON_SKILLS[skill]] = true
	var spells: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classic/spells.json")).spells
	for id: String in spells:
		keys[spell_key(spells[id])] = true
	var out: Array[String] = []
	out.assign(keys.keys())
	out.sort()
	return out
