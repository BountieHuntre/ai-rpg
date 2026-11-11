class_name ItemDB
extends RefCounted
## Classic WoW item data from data/classic/items.json, plus the classic item
## tooltip, quality colors and money formatting.

const ITEMS_PATH := "res://data/classic/items.json"

enum Quality { POOR, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const QUALITY_COLORS := {
	Quality.POOR: Color("9d9d9d"), Quality.COMMON: Color("ffffff"), Quality.UNCOMMON: Color("1eff00"),
	Quality.RARE: Color("0070dd"), Quality.EPIC: Color("a335ee"), Quality.LEGENDARY: Color("ff8000"),
}

const ITEM_CLASS_WEAPON := 2
const ITEM_CLASS_ARMOR := 4

const SLOT_NAMES := {
	1: "Head", 2: "Neck", 3: "Shoulder", 4: "Shirt", 5: "Chest", 6: "Waist", 7: "Legs", 8: "Feet",
	9: "Wrist", 10: "Hands", 11: "Finger", 12: "Trinket", 13: "One-Hand", 14: "Off Hand", 15: "Ranged",
	16: "Back", 17: "Two-Hand", 19: "Tabard", 20: "Chest", 21: "Main Hand", 22: "Off Hand",
	23: "Held In Off-hand", 25: "Thrown", 26: "Ranged",
}
const WEAPON_TYPES := {
	0: "Axe", 1: "Axe", 2: "Bow", 3: "Gun", 4: "Mace", 5: "Mace", 6: "Polearm", 7: "Sword", 8: "Sword",
	10: "Staff", 13: "Fist Weapon", 14: "Miscellaneous", 15: "Dagger", 16: "Thrown", 18: "Crossbow",
	19: "Wand", 20: "Fishing Pole",
}
const ARMOR_TYPES := { 1: "Cloth", 2: "Leather", 3: "Mail", 4: "Plate", 5: "Buckler", 6: "Shield" }
const STAT_MODS := { 0: "Mana", 1: "Health", 3: "Agility", 4: "Strength", 5: "Intellect", 6: "Spirit", 7: "Stamina" }
## Every playable class in an AllowableClass mask. Items allowing all of them
## show no "Classes:" line.
## Every class, the Spellsword (10) included.
const ALL_CLASSES_MASK := 2015
## Unmet requirements show in this red, as in the classic tooltip.
const UNMET := Color(1, 0.13, 0.13)
## Stat changes when comparing items.
## Item spell lines, by spelltrigger_1: use, equip, chance on hit, learn.
const USE_COLOR := Color(0.12, 1, 0)
const SPELL_TRIGGERS := { 0: "Use", 1: "Equip", 2: "Chance on hit", 6: "Use" }
const GAIN := Color(0.15, 1, 0.15)
const LOSS := Color(1, 0.2, 0.2)
const BONDING := { 1: "Binds when picked up", 2: "Binds when equipped", 3: "Binds when used", 4: "Quest Item" }

static var _items: Dictionary


static func get_item(id: int) -> Dictionary:
	if _items.is_empty():
		_items = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	return _items.get(str(id), {})


## Every item id in the game.
static func all_ids() -> Array:
	get_item(0)
	return _items.keys().map(func(key: String) -> int: return int(key))


static var _by_name: Dictionary


## An item's id by its exact name (any case), or 0: "[Wool Scraps]" typed
## into the chat becomes a link.
static func find_by_name(item_name: String) -> int:
	if _by_name.is_empty():
		get_item(0)
		for key: String in _items:
			_by_name[str(_items[key].get("name", "")).to_lower()] = int(key)
	return int(_by_name.get(item_name.to_lower(), 0))


static func quality_color(item: Dictionary) -> Color:
	return QUALITY_COLORS.get(int(item.get("Quality", 1)), Color.WHITE)


## "1g 2s 3c", leaving out empty units.
static func money_text(copper: int) -> String:
	var parts := PackedStringArray()
	if copper >= 10000:
		parts.append("%dg" % (copper / 10000))
	if copper % 10000 >= 100:
		parts.append("%ds" % (copper % 10000 / 100))
	if copper % 100 > 0 or parts.is_empty():
		parts.append("%dc" % (copper % 100))
	return " ".join(parts)


## Classic loot message wording for money: "5 Copper", "1 Silver, 20 Copper".
static func money_words(copper: int) -> String:
	var parts := PackedStringArray()
	if copper >= 10000:
		parts.append("%d Gold" % (copper / 10000))
	if copper % 10000 >= 100:
		parts.append("%d Silver" % (copper % 10000 / 100))
	if copper % 100 > 0:
		parts.append("%d Copper" % (copper % 100))
	return ", ".join(parts)


## The classic tooltip as rows of [left text, right text, color], with an
## optional fourth entry coloring the right text on its own. Soulbound
## replaces the binding line once the item has bound. Whatever stops the
## character equipping it is red: the weapon or armor type without the
## proficiency, the classes line, the level.
static func tooltip(item: Dictionary, soulbound := false, current_durability := -1, count := 1) -> Array[Array]:
	var lines: Array[Array] = []
	lines.append([item.name, "", quality_color(item)])
	if soulbound:
		lines.append(_line("Soulbound"))
	elif BONDING.has(int(item.bonding)):
		lines.append(_line(BONDING[int(item.bonding)]))
	# Items that start a quest when used, as classic's tooltip says.
	if int(item.get("startquest", 0)) > 0:
		lines.append(_line("This Item Begins a Quest"))
	var item_class := int(item["class"])
	var slot: String = SLOT_NAMES.get(int(item.InventoryType), "")
	var kind := ""
	if item_class == ITEM_CLASS_WEAPON:
		kind = WEAPON_TYPES.get(int(item.subclass), "")
	elif item_class == ITEM_CLASS_ARMOR:
		kind = ARMOR_TYPES.get(int(item.subclass), "")
	if not slot.is_empty():
		lines.append([slot, kind, Color.WHITE, Color.WHITE if Inventory.has_proficiency(item) else UNMET])
	if int(item.dmg_max1) > 0:
		var speed := int(item.delay) / 1000.0
		lines.append(_line("%d - %d Damage" % [item.dmg_min1, item.dmg_max1], "Speed %.2f" % speed))
		var dps := (float(item.dmg_min1) + float(item.dmg_max1)) / 2.0 / speed
		lines.append(_line("(%.1f damage per second)" % dps))
	if int(item.armor) > 0:
		lines.append(_line("%d Armor" % item.armor))
	if int(item.block) > 0:
		lines.append(_line("%d Block" % item.block))
	for stat: Array in item.stats:
		var value := int(stat[1])
		lines.append(_line("%s%d %s" % ["+" if value > 0 else "", value, STAT_MODS.get(int(stat[0]), "?")]))
	if int(item.ContainerSlots) > 0:
		lines.append(_line("%d Slot Bag" % item.ContainerSlots))
	if int(item.MaxDurability) > 0:
		var current := int(item.MaxDurability) if current_durability < 0 else current_durability
		var color := Color(1, 0.13, 0.13) if current == 0 else Color.WHITE
		lines.append(["Durability %d / %d" % [current, item.MaxDurability], "", color])
	var class_mask := int(item.AllowableClass)
	if class_mask > 0 and class_mask & ALL_CLASSES_MASK != ALL_CLASSES_MASK:
		var names := PackedStringArray()
		for id: int in ClassicData.CLASS_NAMES:
			if class_mask & (1 << (id - 1)):
				names.append(ClassicData.CLASS_NAMES[id])
		var allowed := class_mask & (1 << (GameState.char_class - 1)) != 0
		lines.append(["Classes: " + ", ".join(names), "", Color.WHITE if allowed else UNMET])
	if int(item.RequiredLevel) > 1:
		var color := Color.WHITE if int(item.RequiredLevel) <= GameState.level else UNMET
		lines.append(["Requires Level %d" % item.RequiredLevel, "", color])
	# The item's spell in green, as in classic: "Use:" for ones you use (and
	# recipes you learn), "Equip:" for ones it gives while worn, "Chance on
	# hit:" for weapon procs.
	var item_spell := int(item.get("spellid_1", 0))
	var trigger: String = SPELL_TRIGGERS.get(int(item.get("spelltrigger_1", 0)), "")
	if item_spell > 0 and not trigger.is_empty():
		var text := SpellText.describe(SpellDB.get_spell(item_spell), GameState.level)
		if not text.is_empty():
			lines.append(["%s: %s" % [trigger, text], "", USE_COLOR])
	if not str(item.description).is_empty():
		lines.append(["\"%s\"" % item.description, "", Color("ffd100")])
	# What a vendor pays: for the whole stack, and each when there are several.
	var sell := int(item.SellPrice)
	if sell > 0:
		var each := " (%s each)" % money_text(sell) if count > 1 else ""
		lines.append(["Sell Price: %s%s" % [money_text(sell * count), each], "", Color.WHITE])
	return lines


## The stats an item gives, for comparing: { stat name: amount }, in tooltip
## order. Weapons count by damage per second.
static func stat_values(item: Dictionary) -> Dictionary:
	var values := {}
	if int(item.get("dmg_max1", 0)) > 0 and int(item.get("delay", 0)) > 0:
		values["Damage Per Second"] = (float(item.dmg_min1) + float(item.dmg_max1)) / 2.0 / (int(item.delay) / 1000.0)
	if int(item.get("armor", 0)) > 0:
		values["Armor"] = float(item.armor)
	if int(item.get("block", 0)) > 0:
		values["Block"] = float(item.block)
	for stat: Array in item.get("stats", []):
		var name: String = STAT_MODS.get(int(stat[0]), "")
		if not name.is_empty():
			values[name] = values.get(name, 0.0) + float(stat[1])
	return values


## Tooltip rows for swapping `current` out for `item`: each stat that changes,
## green for a gain and red for a loss. Empty when nothing changes.
static func stat_change_lines(item: Dictionary, current: Dictionary) -> Array:
	var new_values := stat_values(item)
	var old_values := stat_values(current)
	var names: Array = new_values.keys()
	for name: String in old_values:
		if not name in names:
			names.append(name)
	var lines := []
	for name: String in names:
		var change: float = new_values.get(name, 0.0) - old_values.get(name, 0.0)
		if is_zero_approx(snappedf(change, 0.1)):
			continue
		var amount := ("%+.1f" % change) if name == "Damage Per Second" else ("%+d" % roundi(change))
		lines.append(["%s %s" % [amount, name], "", GAIN if change > 0.0 else LOSS])
	return lines


static func _line(left: String, right := "") -> Array:
	return [left, right, Color.WHITE]
