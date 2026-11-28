extends SceneTree
## Writes the content resources (data/creatures/, ...) from the tables the
## scripts held before they moved out of code, so every value moved over
## exactly. Each part ran once, while its tables were still in the code:
##   <console exe> --headless --path C:/ai-rpg -s res://tools/content/extract_content.gd -- --only=creatures
## Once a part's tables are gone from the scripts it has nothing to read, and
## the resources are the source.


func _initialize() -> void:
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	if only in ["", "creatures"]:
		_creatures()
	if only in ["", "looks"]:
		_looks()
	if only in ["", "zones"]:
		_zones()
	if only in ["", "icons"]:
		_icons()
	quit()


static func file_name(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	return out.trim_prefix("_").trim_suffix("_")


func _creatures() -> void:
	var consts: Dictionary = (load("res://scenes/enemies/enemy.gd") as GDScript).get_script_constant_map()
	if not consts.has("LOOKS"):
		push_error("enemy.gd no longer holds the creature tables: data/creatures/ is the source now.")
		return
	var looks: Dictionary = consts.LOOKS
	var humans: Dictionary = consts.HUMAN_CREATURES
	var races: Dictionary = consts.CREATURE_RACES
	var models: Dictionary = consts.CREATURE_MODELS
	var brigand: Color = consts.BRIGAND_RED
	var creatures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classic/creatures.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CreatureLooks.DIR))
	var entries := {}
	for table: Dictionary in [looks, humans, models]:
		for entry: int in table:
			entries[entry] = true
	var written := 0
	for entry: int in entries:
		var look := CreatureLook.new()
		look.entry = entry
		look.creature_name = str(creatures.get(str(entry), {}).get("Name", ""))
		var gear := {}
		var fallback := Color(0.75, 0.25, 0.25)
		if humans.has(entry):
			if models.has(entry):
				push_warning("%d is in both HUMAN_CREATURES and CREATURE_MODELS; dressed wins, as in the game" % entry)
			var kind: Array = races.get(entry, ["human", brigand, true])
			look.dressed = true
			look.model = kind[0]
			look.band = kind[1]
			look.cloak = kind[2]
			gear = humans[entry]
		elif models.has(entry):
			look.model = models[entry][0]
			gear = models[entry][1]
			fallback = Color(0.6, 0.5, 0.4)
		var shape: Array = looks.get(entry, [Vector3.ONE, fallback])
		look.size = shape[0]
		look.color = shape[1]
		look.main = str(gear.get("main", ""))
		look.off = str(gear.get("off", ""))
		look.helm = str(gear.get("helm", ""))
		for key: String in gear:
			if key not in ["main", "off", "helm"] or str(gear[key]) == "" and key != "main":
				push_warning("%d: gear %s = '%s' doesn't fit" % [entry, key, gear[key]])
		var path := "%s%d_%s.tres" % [CreatureLooks.DIR, entry, file_name(look.creature_name)]
		var error := ResourceSaver.save(look, path)
		if error != OK:
			push_error("couldn't save %s: %s" % [path, error])
		written += 1
	var list := CreatureModels.new()
	var names: Array = consts.MODEL_BASE_SIZE.keys()
	for beast: String in consts.BEASTS:
		if beast not in names:
			names.append(beast)
	for model_name: String in names:
		var info := CreatureModelInfo.new()
		info.name = model_name
		info.base_size = float(consts.MODEL_BASE_SIZE.get(model_name, 1.0))
		info.beast = model_name in consts.BEASTS
		list.models.append(info)
	ResourceSaver.save(list, CreatureLooks.MODELS_PATH)
	print("creatures: %d looks, %d models" % [written, list.models.size()])


func _looks() -> void:
	var consts: Dictionary = (load("res://scenes/characters/humanoid_model.gd") as GDScript).get_script_constant_map()
	if not consts.has("RACE_SKINS"):
		push_error("humanoid_model.gd no longer holds the look tables: data/looks/ is the source now.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CharacterLooks.DIR))
	var races := ["human", "dwarf", "gnome"]
	for table: String in ["RACE_SKINS", "RACE_HAIRS", "RACE_EYES", "TUSK_COLORS", "RACE_OPTIONS"]:
		for race: String in consts[table]:
			if race not in races:
				races.append(race)
	for race: String in races:
		var look := RaceLook.new()
		look.race = race
		look.skins = PackedColorArray(consts.RACE_SKINS.get(race, consts.SKIN_COLORS))
		look.hair_colors = PackedColorArray(consts.RACE_HAIRS.get(race, consts.HAIR_COLORS))
		look.eye_color = consts.RACE_EYES.get(race, consts.EYE_COLOR)
		look.glowing_eyes = race in ["undead", "wood_elf", "barkling"]
		look.tusk_color = consts.TUSK_COLORS.get(race, consts.TUSK_COLOR)
		var options: Dictionary = consts.RACE_OPTIONS.get(race, {})
		if options.has("feature"):
			look.feature_title = options.feature[0]
			look.feature_names = PackedStringArray(options.feature[1])
		if options.has("marks"):
			look.marks_title = options.marks[0]
			look.marks_names = PackedStringArray(options.marks[1])
		look.paint = options.get("paint", Color(0.6, 0.1, 0.08))
		ResourceSaver.save(look, "%s%s.tres" % [CharacterLooks.DIR, race])
	var outfits := OutfitLooks.new()
	outfits.cloth = PackedColorArray(consts.CLOTH)
	outfits.leather = PackedColorArray(consts.LEATHER)
	outfits.mail = PackedColorArray(consts.MAIL)
	outfits.plate = PackedColorArray(consts.PLATE)
	for word: String in consts.NAME_COLORS:
		outfits.name_colors[word] = consts.NAME_COLORS[word]
	outfits.gem_colors = PackedColorArray(consts.GEM_COLORS)
	outfits.smallclothes = consts.SMALLCLOTHES
	outfits.trim = consts.TRIM_COLOR
	outfits.wood = consts.WOOD
	outfits.steel = consts.STEEL
	outfits.strap = consts.STRAP_COLOR
	outfits.parchment = consts.PARCHMENT
	# What outfit_for's match held, trade by trade.
	var P := OutfitLooks.Pattern
	var trades := [
		[["paladin"], "plate", [], 0.0, [P.PLATE, P.BANDED], true, 0.15, true],
		[["warrior", "weapons"], "mail", [], 0.0, [P.CHAIN, P.SCALE], false, 0.0, false],
		[["priest"], "none", [Color(0.88, 0.86, 0.8), Color(0.75, 0.65, 0.4), Color(0.55, 0.15, 0.15)], 0.0, [], true, 0.0, true],
		[["spellsword"], "none", [Color(0.25, 0.3, 0.55)], 0.0, [P.QUILTED], false, 0.0, false],
		[["mage"], "none", [Color(0.2, 0.25, 0.55), Color(0.35, 0.2, 0.5), Color(0.5, 0.15, 0.18)], 0.0, [P.STRIPES], true, 0.0, true],
		[["mining"], "leather", [], 0.25, [P.STUDDED], false, 0.0, false],
		[["herbalism"], "none", [Color(0.3, 0.45, 0.25), Color(0.4, 0.5, 0.3), Color(0.25, 0.38, 0.3)], 0.0, [], false, 0.0, false],
		[["skinning"], "leather", [], 0.0, [P.TOOLED], false, 0.0, false],
		[["enchanting"], "none", [Color(0.42, 0.25, 0.55), Color(0.3, 0.22, 0.5)], 0.0, [], true, 0.0, true],
	]
	for row: Array in trades:
		var outfit := TradeOutfit.new()
		outfit.trades = PackedStringArray(row[0])
		outfit.body_palette = row[1]
		outfit.body_colors = PackedColorArray(row[2])
		outfit.body_darken = row[3]
		var patterns: Array[int] = []
		patterns.assign(row[4])
		outfit.body_patterns = patterns
		outfit.legs_like_body = row[5]
		outfit.legs_darken = row[6]
		outfit.legs_pattern_like_body = row[7]
		outfits.trades.append(outfit)
	ResourceSaver.save(outfits, CharacterLooks.OUTFITS_PATH)
	print("looks: %d races and the outfits" % races.size())


## The zones' layout tables, with each entry's comment from
## build/zone_notes.json (tools/content/zone_notes.py) as its name.
func _zones() -> void:
	var notes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://build/zone_notes.json"))
	var creatures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/classic/creatures.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ZoneLayouts.DIR))
	for folder in DirAccess.get_directories_at("res://scenes/levels"):
		var script_path := "res://scenes/levels/%s/%s.gd" % [folder, folder]
		if not FileAccess.file_exists(script_path):
			continue
		var c: Dictionary = (load(script_path) as GDScript).get_script_constant_map()
		if not c.has("PLACES"):
			push_error("%s no longer holds its layout: data/zones/ is the source now." % folder)
			continue
		var zone_notes: Dictionary = notes.get(folder, {})
		var note := func(table: String, i: int) -> String:
			var list: Array = zone_notes.get(table, [])
			return str(list[i]) if i < list.size() else ""
		var layout := ZoneLayout.new()
		layout.zone_name = c.get("ZONE_NAME", folder)
		for row: Array in c.get("PLACES", []):
			var place := ZonePlace.new()
			place.name = row[0]
			place.center = row[1]
			place.radius = row[2]
			layout.places.append(place)
		var keys: Dictionary = zone_notes.get("FLAT_KEYS", {})
		if folder == "ashford_vale":
			keys = { "0": "MINE", "1": "BRIGAND_CAMP" }
		var flats: Array = c.get("FLATS", [])
		for i in flats.size():
			var flat := ZoneArea.new()
			flat.name = note.call("FLATS", i)
			flat.key = str(keys.get(str(i), ""))
			flat.center = flats[i][0]
			flat.radius = flats[i][1]
			flat.height = flats[i][2]
			layout.flats.append(flat)
		var hills: Array = c.get("HILLS", [])
		for i in hills.size():
			var hill := ZoneArea.new()
			hill.name = note.call("HILLS", i)
			hill.center = hills[i][0]
			hill.radius = hills[i][1]
			hill.height = hills[i][2]
			layout.hills.append(hill)
		layout.stream = PackedVector2Array(c.get("STREAM", []))
		var roads: Array = c.get("ROADS", [])
		for i in roads.size():
			var road := ZoneRoad.new()
			road.name = note.call("ROADS", i)
			road.points = PackedVector2Array(roads[i])
			layout.roads.append(road)
		var woods: Array = c.get("WOODS", [])
		for i in woods.size():
			var wood := ZonePlace.new()
			wood.name = note.call("WOODS", i)
			wood.center = woods[i][0]
			wood.radius = woods[i][1]
			layout.woods.append(wood)
		var spawns: Array = c.get("SPAWNS", [])
		for i in spawns.size():
			var spawn := ZoneSpawn.new()
			spawn.name = note.call("SPAWNS", i)
			spawn.entry = spawns[i][0]
			spawn.creature = str(creatures.get(str(spawns[i][0]), {}).get("Name", ""))
			spawn.center = spawns[i][1]
			spawn.radius = spawns[i][2]
			spawn.count = spawns[i][3]
			if spawns[i].size() != 4:
				push_error("%s spawn %d has %d fields" % [folder, i, spawns[i].size()])
			layout.spawns.append(spawn)
		var chests: Array = c.get("CHESTS", [])
		for i in chests.size():
			var chest := ZoneChest.new()
			chest.name = note.call("CHESTS", i)
			chest.entry = chests[i][0]
			chest.center = chests[i][1]
			chest.radius = chests[i][2]
			chest.count = chests[i][3]
			layout.chests.append(chest)
		var things: Array = c.get("QUEST_OBJECTS", [])
		for i in things.size():
			var thing := ZoneQuestObject.new()
			thing.note = note.call("QUEST_OBJECTS", i)
			thing.entry = things[i][0]
			thing.node_name = things[i][1]
			thing.at = things[i][2]
			thing.facing = things[i][3]
			layout.quest_objects.append(thing)
		var walls: Array = c.get("ENCLOSURES", [])
		for i in walls.size():
			var wall := ZoneEnclosure.new()
			wall.name = note.call("ENCLOSURES", i)
			wall.least = Vector2(walls[i][0], walls[i][1])
			wall.most = Vector2(walls[i][2], walls[i][3])
			wall.outside = walls[i][4]
			wall.inside = walls[i][5]
			layout.enclosures.append(wall)
		var focuses: Array = c.get("SPELL_FOCUSES", [])
		for i in focuses.size():
			var focus := ZoneFocus.new()
			focus.name = note.call("SPELL_FOCUSES", i)
			focus.entry = focuses[i][0]
			focus.at = focuses[i][1]
			layout.spell_focuses.append(focus)
		var error := ResourceSaver.save(layout, "%s%s.tres" % [ZoneLayouts.DIR, folder])
		print("zone %s: %s" % [folder, "saved" if error == OK else "error %d" % error])


## The icon maps (ui/icons.gd's name tables), in their order.
func _icons() -> void:
	var c: Dictionary = (load("res://ui/icons.gd") as GDScript).get_script_constant_map()
	if not c.has("CLASS_SPELLS"):
		push_error("icons.gd no longer holds its maps: data/icons.tres is the source now.")
		return
	var maps := IconMaps.new()
	for key: String in c.CLASS_SPELLS:
		maps.spell_icons[key] = c.CLASS_SPELLS[key]
	for key: String in c.WEAPON_SKILLS:
		maps.weapon_skill_icons[key] = c.WEAPON_SKILLS[key]
	for pair: Array in c.TALENT_WORDS:
		maps.talent_words.append(IconWord.make(pair[0], pair[1]))
	for pair: Array in c.NAME_ICONS:
		maps.item_words.append(IconWord.make(pair[0], pair[1]))
	for pair: Array in c.CREATURE_PORTRAITS:
		maps.creature_portraits.append(IconWord.make(pair[0], pair[1]))
	var error := ResourceSaver.save(maps, IconMaps.PATH)
	print("icons: ", "saved" if error == OK else "error %d" % error)
