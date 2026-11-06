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
## - Negative chances are quest drops: they roll at that chance only while an
##   active quest still needs the item (QuestLog.needs_item).

const LOOT_PATH := "res://data/classic/loot_tables.json"

static var _tables: Dictionary


## Returns an array of { "id": item id, "count": stack size }.
static func roll_creature(loot_id: int) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var entries: Array = _get_tables().creature.get(str(loot_id), [])
	_process(entries, drops)
	return drops


## What a game object (a chest, a Bundle of Wood) holds when opened, from
## gameobject_loot_template by its loot id: rolled like a creature's, its
## quest-only items only for quests underway.
static func roll_object(loot_id: int) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	_process(_get_tables().get("gameobject", {}).get(str(loot_id), []), drops)
	return drops


## Every item a game object's loot can hold, quest-only ones included.
static func object_items(loot_id: int) -> Array[int]:
	var items: Array[int] = []
	for entry: Dictionary in _get_tables().get("gameobject", {}).get(str(loot_id), []):
		if int(entry.min_or_ref) >= 0 and not int(entry.item) in items:
			items.append(int(entry.item))
	return items


## Quest-only drops (negative chances) a creature's loot can hold, including
## through references.
static func quest_items(loot_id: int) -> Array[int]:
	var items: Array[int] = []
	var pending: Array = _get_tables().creature.get(str(loot_id), []).duplicate()
	var seen := {}
	while not pending.is_empty():
		var entry: Dictionary = pending.pop_back()
		var ref := -int(entry.min_or_ref)
		if ref > 0:
			if not seen.has(ref):
				seen[ref] = true
				pending.append_array(_get_tables().reference.get(str(ref), []))
		elif float(entry.chance) < 0.0 and not int(entry.item) in items:
			items.append(int(entry.item))
	return items


## The percent chance a creature's loot holds an item, quest drops included
## (their chance as when a quest needs them). An item in a group of equal
## chances gets its share of the group; one behind a reference, the
## reference's chance times its own. For playerbots, which don't loot.
static func drop_chance(loot_id: int, item_id: int) -> float:
	return _chance_in(_get_tables().creature.get(str(loot_id), []), item_id, {})


static func _chance_in(entries: Array, item_id: int, seen: Dictionary) -> float:
	var best := 0.0
	for entry: Dictionary in entries:
		var ref := -int(entry.min_or_ref)
		var chance := absf(float(entry.chance))
		if ref > 0:
			if seen.has(ref):
				continue
			seen[ref] = true
			var inner := _chance_in(_get_tables().reference.get(str(ref), []), item_id, seen)
			best = maxf(best, inner * (chance if chance > 0.0 else 100.0) / 100.0)
		elif int(entry.item) == item_id:
			if chance == 0.0:
				var equal := entries.filter(func(e: Dictionary) -> bool: return int(e.group) == int(entry.group) and float(e.chance) == 0.0)
				chance = 100.0 / maxf(equal.size(), 1.0)
			best = maxf(best, chance)
	return best


## Every item a creature's loot can hold directly (not behind references).
static func items_of(loot_id: int) -> Array[int]:
	var items: Array[int] = []
	for entry: Dictionary in _get_tables().creature.get(str(loot_id), []):
		if int(entry.min_or_ref) > 0 and not int(entry.item) in items:
			items.append(int(entry.item))
	return items


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
			if QuestLog.needs_item(int(entry.item)):
				var quest_entry := entry.duplicate()
				quest_entry.chance = -entry.chance
				if _roll_entry(quest_entry):
					_add(quest_entry, drops)
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
