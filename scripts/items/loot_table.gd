class_name LootTable
extends RefCounted
## Rolls creature loot from the classic loot tables in data/classic, following
## LootMgr.cpp in CMaNGOS classic:
## - Entries in group 0 roll independently against their chance.
## - Each other group drops at most one entry: explicitly chanced entries are
##   checked in random order against one roll, then one of the zero-chance
##   entries is picked evenly.
## - A reference (negative min count) rolls its chance, then processes the
##   referenced table max-count times.
## - Negative chances are quest drops, which need an active quest.

const LOOT_PATH := "res://data/classic/loot_tables.json"

static var _tables: Dictionary


## Returns an array of { "id": item id, "count": stack size }.
static func roll_creature(loot_id: int) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var entries: Array = _get_tables().creature.get(str(loot_id), [])
	_process(entries, drops)
	return drops


## Copper dropped, as in Loot::GenerateMoneyLoot.
static func roll_money(min_copper: int, max_copper: int) -> int:
	if max_copper <= 0:
		return 0
	if max_copper <= min_copper:
		return max_copper
	return randi_range(min_copper, max_copper)


static func _process(entries: Array, drops: Array[Dictionary]) -> void:
	var groups := {}
	for entry: Dictionary in entries:
		if entry.chance < 0.0:
			continue
		if int(entry.group) == 0:
			if _roll_entry(entry):
				_add(entry, drops)
		else:
			groups.get_or_add(int(entry.group), []).append(entry)
	for group: Array in groups.values():
		var picked := _roll_group(group, drops)
		if not picked.is_empty():
			_add(picked, drops)


static func _roll_entry(entry: Dictionary) -> bool:
	return entry.chance >= 100.0 or randf() * 100.0 < entry.chance


static func _roll_group(group: Array, drops: Array[Dictionary]) -> Dictionary:
	var explicit := group.filter(func(e: Dictionary) -> bool: return e.chance > 0.0)
	var equal := group.filter(func(e: Dictionary) -> bool: return e.chance == 0.0)
	explicit.shuffle()
	var roll := randf() * 100.0
	for entry: Dictionary in explicit:
		if entry.chance >= 100.0:
			return entry
		roll -= entry.chance
		if roll < 0.0:
			return entry
	equal.shuffle()
	for entry: Dictionary in equal:
		# Already in the loot: a 50% chance to pass it over for another.
		var duplicate := drops.any(func(d: Dictionary) -> bool: return d.id == int(entry.item))
		if duplicate and randi_range(0, 1) == 1:
			continue
		return entry
	return {}


static func _add(entry: Dictionary, drops: Array[Dictionary]) -> void:
	var min_or_ref := int(entry.min_or_ref)
	if min_or_ref < 0:
		var reference: Array = _get_tables().reference.get(str(-min_or_ref), [])
		for i in maxi(int(entry.max), 1):
			_process(reference, drops)
	else:
		drops.append({ "id": int(entry.item), "count": randi_range(min_or_ref, maxi(min_or_ref, int(entry.max))) })


static func _get_tables() -> Dictionary:
	if _tables.is_empty():
		_tables = JSON.parse_string(FileAccess.get_file_as_string(LOOT_PATH))
	return _tables
