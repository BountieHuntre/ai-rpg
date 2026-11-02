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
const BONDING := { 1: "Binds when picked up", 2: "Binds when equipped", 3: "Binds when used", 4: "Quest Item" }

static var _items: Dictionary


static func get_item(id: int) -> Dictionary:
	if _items.is_empty():
		_items = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	return _items.get(str(id), {})


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


## The classic tooltip as rows of [left text, right text, color].
static func tooltip(item: Dictionary) -> Array[Array]:
	var lines: Array[Array] = []
	lines.append([item.name, "", quality_color(item)])
	if BONDING.has(int(item.bonding)):
		lines.append(_line(BONDING[int(item.bonding)]))
	var item_class := int(item["class"])
	var slot: String = SLOT_NAMES.get(int(item.InventoryType), "")
	var kind := ""
	if item_class == ITEM_CLASS_WEAPON:
		kind = WEAPON_TYPES.get(int(item.subclass), "")
	elif item_class == ITEM_CLASS_ARMOR:
		kind = ARMOR_TYPES.get(int(item.subclass), "")
	if not slot.is_empty():
		lines.append(_line(slot, kind))
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
		lines.append(_line("Durability %d / %d" % [item.MaxDurability, item.MaxDurability]))
	if int(item.RequiredLevel) > 1:
		lines.append(_line("Requires Level %d" % item.RequiredLevel))
	if not str(item.description).is_empty():
		lines.append(["\"%s\"" % item.description, "", Color("ffd100")])
	return lines


static func _line(left: String, right := "") -> Array:
	return [left, right, Color.WHITE]
