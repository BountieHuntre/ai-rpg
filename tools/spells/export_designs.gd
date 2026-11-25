extends SceneTree
## Writes every class's spell design file (data/designs/<class>.json) from
## classic's spell data and the game's own class files, then reads them back
## as the game does and checks they build exactly the same spells, chains,
## trainer lists, talents, spellbook tabs, links, proc rules and coefficients.
##
## Export (overwrites the design files):
##   <console exe> --headless --path C:/ai-rpg -s res://tools/spells/export_designs.gd -- --export
## Check only (the design files against classic's data; run after editing
## a design to see what it changed from classic):
##   <console exe> --headless --path C:/ai-rpg -s res://tools/spells/export_designs.gd
## Add to each design file the spells its spells trigger that it doesn't hold
## yet (from classic's data, after the file's own spells; nothing else in the
## file changes):
##   <console exe> --headless --path C:/ai-rpg -s res://tools/spells/export_designs.gd -- --add-missing
## The professions (data/designs/professions/<name>.json, ProfessionDesigns):
## the check covers them too, their own sections against professions.json;
## `-- --export-professions` writes only them (the classes' files untouched).

const SPELLS_PATH := "res://data/classic/spells.json"
const PROFESSIONS_PATH := "res://data/classic/professions.json"
const ITEMS_PATH := "res://data/classic/items.json"


func _initialize() -> void:
	var designs = load("res://scripts/spells/spell_designs.gd")
	var data := _raw_data()
	var exporting := "--export" in OS.get_cmdline_user_args()
	var exporting_professions := exporting or "--export-professions" in OS.get_cmdline_user_args()
	if "--add-missing" in OS.get_cmdline_user_args():
		_add_missing(designs, data)
	var professions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFESSIONS_PATH))
	data.recipes = professions.recipes
	var profession_designs = load("res://scripts/professions/profession_designs.gd")
	var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ITEMS_PATH))
	for id: String in items:
		profession_designs.item_names[id] = items[id].name
	var differences := 0
	for spec: Array in designs.all_files():
		var profession := int(spec[0]) == 0
		var owned := _owned(data, int(spec[0]), str(spec[1]))
		if profession:
			owned = _profession_owned(data, professions, str(spec[1]))
		var path: String = designs.DESIGN_DIR + str(spec[2]) + ".json"
		if exporting if not profession else exporting_professions:
			var design: Dictionary = designs.encode_class(data, int(spec[0]), str(spec[1]), owned)
			if profession:
				design.erase("talents")
				design.erase("start_spells")
				design.merge(profession_designs.encode_profession(professions, str(spec[1])), true)
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(JSON.stringify(designs.whole(design), "\t", false) + "\n")
			file.close()
		var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		designs.warnings.clear()
		var built: Dictionary = designs.decode_class(read, str(spec[2]))
		for warning: String in designs.warnings:
			print("WARNING ", warning)
		var found := _compare(data, built, int(spec[0]), str(spec[1]), owned)
		if profession:
			found += _compare_profession(professions, profession_designs.decode_profession(read, str(spec[1]), built.recipes), str(spec[1]))
		differences += found
		print("%s: %d spells, %d differences" % [spec[2], owned.size(), found])
	print("DONE: %d differences" % differences)
	quit()


## spells.json with the game's own class files over it, as SpellDB reads them
## before the designs (and before lengthening buffs).
func _raw_data() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPELLS_PATH))
	for path: String in ["res://data/classes/spellsword.json"]:
		var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for key in ["spells", "chains", "start_spells", "talents", "book_tabs", "links", "trainers"]:
			(data[key] as Dictionary).merge(extra.get(key, {}), true)
	return data


## The spells a class holds: what its trainer teaches, its talents' ranks,
## its start spells, its spellbook's, the whole chains of all those, and the
## spells they're linked to.
func _owned(data: Dictionary, class_id: int, trainer: String) -> Array:
	var ids := {}
	for entry: Dictionary in data.trainers.get(trainer, []):
		ids[int(entry.teach)] = true
		for id: Variant in entry.spells:
			ids[int(id)] = true
	for tree: Dictionary in data.talents.get(str(class_id), []):
		for talent: Dictionary in tree.talents:
			for id: Variant in talent.ranks:
				ids[int(id)] = true
	for key: String in data.start_spells:
		if key.split("-")[1] == str(class_id):
			for id: Variant in data.start_spells[key]:
				ids[int(id)] = true
	for id: String in data.book_tabs.get(str(class_id), {}):
		ids[int(id)] = true
	var firsts := {}
	for id: int in ids:
		if data.chains.has(str(id)):
			firsts[int(data.chains[str(id)].first)] = true
	for id: String in data.chains:
		if firsts.has(int(data.chains[id].first)):
			ids[int(id)] = true
	for id: int in ids.keys():
		if data.links.has(str(id)):
			ids[int(data.links[str(id)])] = true
	_add_triggers(data.spells, ids)
	var out := []
	for id: int in ids:
		if data.spells.has(str(id)):
			out.append(id)
	return out


## Adds to `ids` the spells its spells trigger (EffectTriggerSpell: a proc's
## buff, a periodic trigger's spell), and theirs, while classic's data has them.
func _add_triggers(spells: Dictionary, ids: Dictionary) -> void:
	var queue := ids.keys()
	while not queue.is_empty():
		var id := int(queue.pop_back())
		var row: Dictionary = spells.get(str(id), {})
		for n in [1, 2, 3]:
			var trigger := int(row.get("EffectTriggerSpell%d" % n, 0))
			if trigger != 0 and not ids.has(trigger) and spells.has(str(trigger)):
				ids[trigger] = true
				queue.append(trigger)


## --add-missing: each design file gets the spells its own spells trigger
## that it doesn't hold, encoded from classic's data, after its spells.
func _add_missing(designs: Variant, data: Dictionary) -> void:
	for spec: Array in designs.CLASSES:
		var path: String = designs.DESIGN_DIR + str(spec[2]) + ".json"
		var design: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var built: Dictionary = designs.decode_class(design, str(spec[2]))
		var held := {}
		for id: String in built.spells:
			held[int(id)] = true
		var wanted := held.duplicate()
		var merged: Dictionary = data.spells.duplicate()
		merged.merge(built.spells, true)
		_add_triggers(merged, wanted)
		var missing := []
		for id: int in wanted:
			if not held.has(id) and data.spells.has(str(id)):
				missing.append(id)
		missing.sort()
		if missing.is_empty():
			print("%s: nothing missing" % spec[2])
			continue
		var added: Dictionary = designs.encode_class(data, int(spec[0]), str(spec[1]), missing)
		var groups: Array = design.get("spells", [])
		groups.append_array(added.spells)
		design.spells = groups
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(designs.whole(design), "\t", false) + "\n")
		file.close()
		print("%s: added %d spells in %d groups: %s" % [spec[2], missing.size(), added.spells.size(),
			", ".join(added.spells.map(func(g: Dictionary) -> String: return str(g.name)))])


## A profession's spells: its trainer list's, the spells learned with it,
## its ranks, its recipes, its enchants' proc and equip spells, and what
## those trigger.
func _profession_owned(data: Dictionary, professions: Dictionary, name: String) -> Array:
	var ids := {}
	for id: int in _owned(data, 0, name):
		ids[id] = true
	var prof: Dictionary = professions.professions[name]
	for id: Variant in prof.start:
		ids[int(id)] = true
	for rank: Dictionary in prof.ranks:
		ids[int(rank.spell)] = true
	for id: String in professions.recipes:
		var recipe: Dictionary = professions.recipes[id]
		if recipe.profession != name:
			continue
		ids[int(id)] = true
		var enchant: Dictionary = professions.enchants.get(str(int(recipe.get("enchant", 0))), {})
		for effect: Array in enchant.get("effects", []):
			if int(effect[0]) in [1, 3]:
				ids[int(effect[3])] = true
	_add_triggers(data.spells, ids)
	var out := []
	for id: int in ids:
		if data.spells.has(str(id)):
			out.append(id)
	return out


## A profession's own sections read back against professions.json: its
## ranks and tools, recipes, nodes and their loot, skinning and disenchanting
## loot, enchants.
func _compare_profession(classic: Dictionary, built: Dictionary, name: String) -> int:
	var designs = load("res://scripts/spells/spell_designs.gd")
	var w := func(value: Variant) -> String: return JSON.stringify(designs.whole(value), "", true)
	var found := 0
	if w.call(classic.professions[name]) != w.call(built.professions[name]):
		found += 1
		print("  %s's ranks, start spells or tools differ" % name)
	for table: String in ["recipes", "nodes", "skinning_loot", "disenchant_loot", "enchants"]:
		var mine := {}
		for id: String in classic[table]:
			var row: Variant = classic[table][id]
			var belongs: bool = (table == "recipes" and row.profession == name) 				or (table == "nodes" and row.kind == { "herbalism": "herb", "mining": "ore" }.get(name, "")) 				or (table == "skinning_loot" and name == "skinning") or (table == "disenchant_loot" and name == "enchanting") 				or (table == "enchants" and name == "enchanting")
			if belongs:
				mine[id] = row
		for id: String in mine:
			if not built[table].has(id) or w.call(mine[id]) != w.call(built[table][id]):
				found += 1
				if found <= 8:
					print("  %s %s %s differs: %s -> %s" % [name, table, id, w.call(mine[id]).left(160), w.call(built[table].get(id, null)).left(160)])
		for id: String in built[table]:
			if not mine.has(id):
				found += 1
				print("  %s %s %s added" % [name, table, id])
	for id: String in built.node_loot:
		if w.call(classic.node_loot.get(id, [])) != w.call(built.node_loot[id]):
			found += 1
			print("  %s node loot %s differs" % [name, id])
	return found


var _whole: Callable


func _compare(data: Dictionary, built: Dictionary, class_id: int, trainer: String, owned: Array) -> int:
	var designs = load("res://scripts/spells/spell_designs.gd")
	_whole = func(value: Variant) -> Variant: return designs.whole(value)
	data = _whole.call(data)
	built = _whole.call(built)
	var found := 0
	for id: int in owned:
		# Every field the classic row has must be there, as code reads them
		# straight (spell["EffectApplyAuraName2"]).
		var built_row: Dictionary = built.spells.get(str(id), {})
		if built_row.is_empty():
			found += 1
			print("  spell %d %s: removed from the design" % [id, data.spells[str(id)].SpellName])
			continue
		for key: String in data.spells[str(id)]:
			if not built_row.has(key):
				found += 1
				print("  spell %d has no %s" % [id, key])
				break
		var a := _normal(data.spells[str(id)])
		var b := _normal(built_row)
		if a != b:
			found += 1
			if found <= 6:
				print("  spell %d %s differs:" % [id, data.spells[str(id)].SpellName])
				for key: String in a:
					if str(a[key]) != str(b.get(key, null)):
						print("    %s: %s -> %s" % [key, a[key], b.get(key, null)])
				for key: String in b:
					if not a.has(key):
						print("    %s: (none) -> %s" % [key, b[key]])
		for table: String in ["chains", "links", "procs", "bonus", "judgement_procs", "holy_shock", "seal_of_righteousness_procs"]:
			var x: Variant = _whole.call(data.get(table, {}).get(str(id), null))
			var y: Variant = _whole.call(built.get(table, {}).get(str(id), null))
			if str(x) != str(y) and not (x == null and y == null):
				found += 1
				print("  %s of %d: %s -> %s" % [table, id, x, y])
	var tabs_a: Dictionary = data.book_tabs.get(str(class_id), {})
	if str(_sorted(tabs_a)) != str(_sorted(built.book_tabs)):
		found += 1
		print("  book tabs differ")
	var trainer_a := _entries(data.trainers.get(trainer, []))
	var trainer_b := _entries(built.trainer)
	if trainer_a != trainer_b:
		found += 1
		print("  trainer list differs: %d against %d entries" % [trainer_a.size(), trainer_b.size()])
	if str(data.talents.get(str(class_id), [])) != str(built.talents):
		found += 1
		print("  talents differ")
	var starts := {}
	for key: String in data.start_spells:
		if key.split("-")[1] == str(class_id):
			starts[key] = data.start_spells[key]
	if str(_sorted(starts)) != str(_sorted(built.start_spells)):
		found += 1
		print("  start spells differ")
	return found


func _sorted(d: Dictionary) -> Array:
	var keys := d.keys()
	keys.sort()
	return keys.map(func(k: Variant) -> String: return "%s=%s" % [k, d[k]])


func _entries(list: Array) -> Array:
	var out := list.map(func(e: Dictionary) -> String: return str(_sorted(e)))
	out.sort()
	return out


## A spell row by what it means: index fields as their seconds and yards,
## each effect's amount as its least and most, defaults dropped.
func _normal(row: Dictionary) -> Dictionary:
	var db = load("res://scripts/spells/spell_db.gd")
	var out := {}
	for key: String in row:
		out[key] = row[key]
	var cast_index := int(out.get("CastingTimeIndex", 1))
	out.erase("CastingTimeIndex")
	out.Cast = out.get("CastTime", db.CAST_TIMES.get(cast_index, "index %d" % cast_index))
	out.erase("CastTime")
	var duration_index := int(out.get("DurationIndex", 0))
	out.erase("DurationIndex")
	out.Length = out.get("Duration", db.DURATIONS.get(duration_index, "index %d" % duration_index))
	out.erase("Duration")
	var range_index := int(out.get("RangeIndex", 1))
	out.erase("RangeIndex")
	out.Reach = [out.get("Range", db.RANGES.get(range_index, "index %d" % range_index)), out.get("MinRange", db.MIN_RANGES.get(range_index, 0.0))]
	out.erase("Range")
	out.erase("MinRange")
	if not out.has("EquippedItemClass"):
		out.EquippedItemClass = -1
	for n in [1, 2, 3]:
		var effect := int(out.get("Effect%d" % n, 0))
		var base := int(out.get("EffectBasePoints%d" % n, 0))
		var dice := int(out.get("EffectBaseDice%d" % n, 0))
		var sides := int(out.get("EffectDieSides%d" % n, 0))
		for field: String in ["EffectBasePoints", "EffectDieSides"]:
			out.erase(field + str(n))
		if effect != 0:
			out["Amount%d" % n] = [base + dice, base + maxi(dice, sides)]
			var radius := int(out.get("EffectRadiusIndex%d" % n, 0))
			out["Radius%d" % n] = out.get("EffectRadius%d" % n, db.RADII.get(radius, "index %d" % radius))
		else:
			out.erase("DmgMultiplier%d" % n)
			out.erase("EffectBaseDice%d" % n)
		out.erase("EffectRadiusIndex%d" % n)
		out.erase("EffectRadius%d" % n)
	for key: String in out.keys():
		var value: Variant = out[key]
		if value == null or str(value) == "" or str(value) == "0" or (value is float and value == 0.0) \
				or (key.begins_with("DmgMultiplier") and float(value) == 1.0) or (key == "EquippedItemClass" and int(value) == -1) \
				or (key == "PowerType" and int(value) == 0):
			out.erase(key)
		elif value is float and value == floorf(value):
			out[key] = int(value)
	return out
