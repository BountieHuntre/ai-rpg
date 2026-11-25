class_name ProfessionDB
extends RefCounted
## The professions' data: data/classic/professions.json (extract.py, from the
## CMaNGOS classic database and the client's SkillLineAbility, Lock and
## SpellItemEnchantment) with the professions' design files read over it
## (ProfessionDesigns). Herbalism, Mining (with Smelting), Skinning and
## Enchanting: each one's skill line, ranks (Apprentice to Artisan, their
## caps, levels, skill needed and price), the spells learned with it and the
## tools gathering needs; recipes by spell (reagents, tools, focus, what they
## make or the enchant they put on, the Formula that teaches them, their
## skill and orange/yellow/green/grey levels); herb and ore nodes with their
## loot; skinning and disenchanting loot; and the item enchantments.

const DATA_PATH := "res://data/classic/professions.json"
## The professions by name, as the data and designs name them.
const NAMES := ["herbalism", "mining", "skinning", "enchanting"]

static var _data: Dictionary


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		ProfessionDesigns.apply(_data)
	return _data


## Reads the data again (the spell editor's Apply Live, SpellDB.reload_designs).
static func reload() -> void:
	_data = {}


static func profession(name: String) -> Dictionary:
	return data().professions.get(name, {})


## The profession whose skill line is `skill`, or "".
static func name_of_skill(skill: int) -> String:
	for name: String in NAMES:
		if int(profession(name).get("skill", 0)) == skill:
			return name
	return ""


static func recipe(spell_id: int) -> Dictionary:
	return data().recipes.get(str(spell_id), {})


## Every recipe of a profession, by spell id.
static func recipes_of(name: String) -> Array[int]:
	var found: Array[int] = []
	for id: String in data().recipes:
		if data().recipes[id].profession == name:
			found.append(int(id))
	found.sort()
	return found


static func node(entry: int) -> Dictionary:
	return data().nodes.get(str(entry), {})


## Every node of a kind ("herb" or "ore"), by entry.
static func nodes_of(kind: String) -> Array[int]:
	var found: Array[int] = []
	for id: String in data().nodes:
		if data().nodes[id].kind == kind:
			found.append(int(id))
	found.sort_custom(func(a: int, b: int) -> bool: return int(node(a).skill) < int(node(b).skill))
	return found


static func node_loot(loot_id: int) -> Array:
	return data().node_loot.get(str(loot_id), [])


static func skinning_loot(loot_id: int) -> Array:
	return data().skinning_loot.get(str(loot_id), [])


static func disenchant_loot(disenchant_id: int) -> Array:
	return data().disenchant_loot.get(str(disenchant_id), [])


static func enchant(id: int) -> Dictionary:
	return data().enchants.get(str(id), {})
