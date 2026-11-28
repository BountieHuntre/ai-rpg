class_name Icons
extends RefCounted
## Which painted icon each item and spell shows, and the icons themselves.
## An icon is a key (IconPainter: "design" or "design_variant") whose picture
## tools/icons/bake_icons.gd renders into assets/icons/<key>.png. Items pick
## theirs by kind (weapon type, armor slot and material, quality for gems and
## trim) and, for consumables, goods and quest items, by words in their name;
## spells by name (data/icons.tres, IconMaps), by family ("Boon of", "Oath of", "...
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
## Words in item names pick icons too: IconMaps.item_words (data/icons.tres).
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
			# The game's big bags: coffers and chests, and packs.
			for word: String in ["coffer", "chest"]:
				if lower.contains(word):
					return "coffer_" + quality
			for word: String in ["pack", "rucksack", "haversack", "duffel"]:
				if lower.contains(word):
					return "pack_" + quality
			for color in BAG_COLORS:
				if lower.contains(color):
					return "bag_" + color
			return "bag_brown"
		9:
			return "book"
	var by_word := IconMaps.first_match(IconMaps.current().item_words, lower)
	if by_word != "":
		return by_word
	if item_class == 0:
		return "bread"
	return "unknown"


# Spells.

## Spells by name (class spells, the creatures' spells and debuffs), weapon
## skills and words in talents' names: IconMaps (data/icons.tres). Else by
## school.
const SCHOOL_ICONS := ["strike", "bolt_gold", "fire", "poison", "frost", "shadow", "bolt_purple"]
const EFFECT_HEAL := 10


static func spell_key(spell: Dictionary) -> String:
	if spell.is_empty():
		return "unknown"
	var spell_name := str(spell.get("SpellName", ""))
	# The game's own classes' spells name their icon (ClassicData.CLASS_FILES).
	if spell.has("Icon"):
		return str(spell.Icon)
	var maps := IconMaps.current()
	if maps.spell_icons.has(spell_name):
		return maps.spell_icons[spell_name]
	if maps.weapon_skill_icons.has(spell_name):
		return maps.weapon_skill_icons[spell_name]
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
	var by_word := IconMaps.first_match(maps.talent_words, spell_name)
	if by_word != "":
		return by_word
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
## Words in creature names pick portraits: IconMaps.creature_portraits (data/icons.tres).
static var CREATURE_TYPE_BEAST := 1
static var CREATURE_TYPE_UNDEAD := 6


## The portrait key for a unit frame: a class emblem for the player and
## playerbots, a creature's kind (a fang, a fin, a brigand's kerchief), or a
## token for an NPC.
static func portrait_key(unit: Node) -> String:
	if unit is PlayerUnit:
		return CLASS_PORTRAITS.get(int((unit as PlayerUnit).profile.char_class), "strike")
	if unit is Enemy:
		var enemy := unit as Enemy
		var creature_name := enemy.combatant.display_name
		var portrait := IconMaps.first_match(IconMaps.current().creature_portraits, creature_name)
		if portrait != "":
			return portrait
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
	var maps := IconMaps.current()
	for spell_name: String in maps.spell_icons:
		keys[maps.spell_icons[spell_name]] = true
	for key: String in CLASS_PORTRAITS.values():
		keys[key] = true
	for entry in maps.creature_portraits:
		keys[entry.icon] = true
	keys["tooth_claw"] = true
	keys["banish"] = true
	for skill: String in maps.weapon_skill_icons:
		keys[maps.weapon_skill_icons[skill]] = true
	var spells: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classic/spells.json")).spells
	for id: String in spells:
		keys[spell_key(spells[id])] = true
	var out: Array[String] = []
	out.assign(keys.keys())
	out.sort()
	return out
