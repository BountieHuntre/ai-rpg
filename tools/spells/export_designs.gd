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

const SPELLS_PATH := "res://data/classic/spells.json"


func _initialize() -> void:
	var designs = load("res://scripts/spells/spell_designs.gd")
	var data := _raw_data()
	var exporting := "--export" in OS.get_cmdline_user_args()
	var differences := 0
	for spec: Array in designs.CLASSES:
		var owned := _owned(data, int(spec[0]), str(spec[1]))
		var path: String = designs.DESIGN_DIR + str(spec[2]) + ".json"
		if exporting:
			var design: Dictionary = designs.encode_class(data, int(spec[0]), str(spec[1]), owned)
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(JSON.stringify(designs.whole(design), "\t", false) + "\n")
			file.close()
		var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		designs.warnings.clear()
		var built: Dictionary = designs.decode_class(read, str(spec[2]))
		for warning: String in designs.warnings:
			print("WARNING ", warning)
		var found := _compare(data, built, int(spec[0]), str(spec[1]), owned)
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
	var out := []
	for id: int in ids:
		if data.spells.has(str(id)):
			out.append(id)
	return out


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
