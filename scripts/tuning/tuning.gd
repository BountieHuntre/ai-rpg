class_name Tuning
extends RefCounted
## The game's tunable numbers: every numeric constant in its scripts is a live
## `static var` (UPPER_CASE, a plain number; `tools/tuning/make_tunable.py`
## turned the old constants into them), which the Options window's Tuning tab
## lists by system and script with a slider each (`OptionsWindow._build_tuning`)
## and changes while the game runs. Changes are the `tuning` option
## ({ "res://path.gd|NAME": value }, saved with the options, shipped by
## `shipdefaults`); a value not in it is its code's own. Values read every
## frame change at once; ones read when something is built (zones, caves,
## models) change when it's built again (the Reload button).

## Folders whose scripts are listed, and the category each folder's scripts
## fall under: the first folder name after these roots (scenes/levels/caves.gd
## is "Levels", scenes/levels/harrowfield/harrowfield.gd "Levels: Harrowfield").
const ROOTS := ["res://scenes", "res://scripts", "res://ui"]

## Each tunable value's code default, by key, recorded before it's changed.
static var _defaults: Dictionary = {}
## Every key ever changed, so dropping a change puts its default back.
static var _touched: Dictionary = {}
static var _entries: Array = []


## A value's key: "res://path.gd|NAME".
static func key_of(path: String, name: String) -> String:
	return "%s|%s" % [path, name]


## Every tunable value, found in the scripts' sources (editor and debug runs):
## { key, path, name, int (whole numbers only), comment (its ## lines),
## category, script (its file name in words) }, in file order.
static func entries() -> Array:
	if not _entries.is_empty():
		return _entries
	var pattern := RegEx.create_from_string("^static var ([A-Z][A-Z0-9_]*)\\s*(:\\s*(int|float))?\\s*:?=\\s*(-?[0-9][0-9_]*(\\.[0-9]*)?([eE]-?[0-9]+)?)")
	for root: String in ROOTS:
		var stack: Array[String] = [root]
		var files: Array[String] = []
		while not stack.is_empty():
			var dir: String = stack.pop_back()
			for sub in DirAccess.get_directories_at(dir):
				stack.append(dir.path_join(sub))
			for file in DirAccess.get_files_at(dir):
				if file.ends_with(".gd"):
					files.append(dir.path_join(file))
		files.sort()
		for path in files:
			var text := FileAccess.get_file_as_string(path)
			if text.is_empty():
				continue
			var comment: PackedStringArray = []
			for line in text.split("\n"):
				var stripped := line.strip_edges()
				if line.begins_with("##"):
					comment.append(line.substr(2).strip_edges())
					continue
				var found := pattern.search(line)
				if found != null:
					var number := found.get_string(4)
					var whole := found.get_string(3) == "int" or (found.get_string(3) == "" and not ("." in number or "e" in number.to_lower()))
					_entries.append({
						"key": key_of(path, found.get_string(1)), "path": path, "name": found.get_string(1),
						"int": whole, "comment": " ".join(comment), "category": category_of(path),
						"script": path.get_file().get_basename().capitalize(), "reload": false,
					})
				if not stripped.begins_with("##"):
					comment.clear()
	var played := _read_in_play()
	for entry: Dictionary in _entries:
		entry.reload = not played.has(entry.key)
	return _entries


# ------------------------------------------------- which values play reads

## Functions that run while the game plays, whatever calls them.
const PLAY_ROOTS := ["_process", "_physics_process", "_input", "_unhandled_input", "_unhandled_key_input",
	"_gui_input", "_draw", "_notification", "_integrate_forces"]
## Functions that shape what's built, though play calls them too (the ground's
## height, asked for again where creatures and herbs stand): the ground was
## made from them once, so values read only through them show after a reload.
const BUILD_FUNCTIONS := ["height_at", "base_height", "carve_passes", "hill_height", "hill_estimate",
	"mountain_height", "edge_ring", "_ground_for_caves", "cave_hole", "ragged_distance", "make_edges",
	"make_hill_mask", "_hill_keep_at", "color_at", "ground_color"]
## A method name defined in more scripts than this, called on something of
## unknown type, is too common to say which script's it is.
static var AMBIGUOUS := 3


## The values (by key) that code running during play reads: in a function
## reached from the engine's per-frame, input and drawing callbacks, signal
## handlers (connected methods, `_on_` methods, lambdas passed to connect)
## and whatever they call, by name. The rest are read only as things are
## made or set up (zones, models, a node's _ready), so changing them shows
## after a reload (or on things made afterwards). A close guess from the
## sources, not a proof.
static func _read_in_play() -> Dictionary:
	var scripts := {}
	var by_class := {}
	var defining := {}
	var call := RegEx.create_from_string("(?:([A-Za-z_][A-Za-z0-9_]*)\\s*\\.\\s*)?([a-z_][A-Za-z0-9_]*)\\s*\\(")
	var connected := RegEx.create_from_string("(?:connect|Callable)\\(\\s*(?:self\\s*,\\s*\")?([a-z_][A-Za-z0-9_]*)")
	for entry_root: String in ROOTS:
		var stack: Array[String] = [entry_root]
		while not stack.is_empty():
			var dir: String = stack.pop_back()
			for sub in DirAccess.get_directories_at(dir):
				stack.append(dir.path_join(sub))
			for file in DirAccess.get_files_at(dir):
				if not file.ends_with(".gd"):
					continue
				var path := dir.path_join(file)
				var info := _parse(FileAccess.get_file_as_string(path))
				scripts[path] = info
				if info["class_name"] != "":
					by_class[info["class_name"]] = path
				for name: String in info["functions"]:
					if not defining.has(name):
						defining[name] = []
					(defining[name] as Array).append(path)
	# Each script's family: its ancestors and descendants.
	var parent := {}
	for path: String in scripts:
		var extends_name: String = scripts[path]["extends"]
		if by_class.has(extends_name):
			parent[path] = by_class[extends_name]
		elif extends_name.ends_with(".gd"):
			var target := extends_name if extends_name.begins_with("res://") else path.get_base_dir().path_join(extends_name)
			if scripts.has(target):
				parent[path] = target
	var family := {}
	for path: String in scripts:
		var members := [path]
		var up: String = path
		while parent.has(up) and not members.has(parent[up]):
			up = parent[up]
			members.append(up)
		family[path] = members
	for path: String in scripts:
		for member: String in (family[path] as Array).duplicate():
			if member != path and not (family[member] as Array).has(path):
				(family[member] as Array).append(path)
	# Every function reached from play, as "path|name"; lambdas passed to
	# connect are pieces of play of their own.
	var queue: Array = []
	for path: String in scripts:
		var info: Dictionary = scripts[path]
		for name: String in info["functions"]:
			if name in PLAY_ROOTS or name.begins_with("_on_"):
				queue.append([path, name])
			for found in connected.search_all(info["functions"][name]):
				for target: String in family[path]:
					if (scripts[target]["functions"] as Dictionary).has(found.get_string(1)):
						queue.append([target, found.get_string(1)])
		for i in (info["lambdas"] as Array).size():
			queue.append([path, "#lambda%d" % i])
	var reached := {}
	var played_text := {}
	while not queue.is_empty():
		var at: Array = queue.pop_back()
		var path: String = at[0]
		var name: String = at[1]
		if reached.has(path + "|" + name) or name in BUILD_FUNCTIONS:
			continue
		reached[path + "|" + name] = true
		var info: Dictionary = scripts[path]
		var body: String = info["lambdas"][int(name.substr(7))] if name.begins_with("#lambda") else info["functions"].get(name, "")
		if not played_text.has(path):
			played_text[path] = []
		# A plain Array: a PackedStringArray is copied when cast, so appending
		# to it here would keep nothing.
		(played_text[path] as Array).append(body)
		for found in call.search_all(body):
			var qualifier := found.get_string(1)
			var called := found.get_string(2)
			if not defining.has(called):
				continue
			var targets: Array = []
			if qualifier == "" or qualifier == "self" or qualifier == "super":
				targets = (family[path] as Array).filter(func(p: String) -> bool: return (scripts[p]["functions"] as Dictionary).has(called))
			elif by_class.has(qualifier):
				targets = (family[by_class[qualifier]] as Array).filter(func(p: String) -> bool: return (scripts[p]["functions"] as Dictionary).has(called))
			elif (defining[called] as Array).size() <= AMBIGUOUS:
				targets = defining[called]
			for target: String in targets:
				queue.append([target, called])
	# A value is read in play where its name is used in played code of its
	# script's family, or anywhere as `Something.NAME`.
	var everywhere := ""
	for path: String in played_text:
		everywhere += "\n".join(played_text[path]) + "\n"
	var played := {}
	for path: String in scripts:
		var own := ""
		for member: String in family[path]:
			if played_text.has(member):
				own += "\n".join(played_text[member]) + "\n"
		for name: String in scripts[path]["values"]:
			var bare := RegEx.create_from_string("(?<![A-Za-z0-9_.])%s(?![A-Za-z0-9_])" % name)
			var dotted := RegEx.create_from_string("\\.%s(?![A-Za-z0-9_])" % name)
			if bare.search(own) != null or dotted.search(everywhere) != null:
				played[key_of(path, name)] = true
	return played


## A script's class name, what it extends, its functions' bodies by name,
## the bodies of lambdas passed to connect, and its static var names.
static func _parse(text: String) -> Dictionary:
	var info := { "class_name": "", "extends": "", "functions": {}, "lambdas": [], "values": [] }
	var current := ""
	var body: PackedStringArray = []
	var lambda_indent := -1
	var lambda: PackedStringArray = []
	var head := RegEx.create_from_string("^(?:static\\s+)?func\\s+([A-Za-z_][A-Za-z0-9_]*)")
	var value := RegEx.create_from_string("^static var ([A-Z][A-Z0-9_]*)")
	for raw in text.split("\n"):
		var line := "" if raw.strip_edges().begins_with("#") else raw.get_slice("#", 0)
		if line.begins_with("class_name "):
			info["class_name"] = line.substr(11).strip_edges().get_slice(" ", 0)
		elif line.begins_with("extends "):
			info["extends"] = line.substr(8).strip_edges().trim_prefix("\"").trim_suffix("\"")
		var found := head.search(line)
		var top := not line.strip_edges().is_empty() and not line.begins_with("\t") and not line.begins_with(" ")
		if top or found != null:
			if current != "":
				info["functions"][current] = "\n".join(body)
			if lambda_indent >= 0:
				(info["lambdas"] as Array).append("\n".join(lambda))
				lambda_indent = -1
			current = found.get_string(1) if found != null else ""
			body = PackedStringArray()
			var v := value.search(line)
			if v != null:
				(info["values"] as Array).append(v.get_string(1))
			continue
		if current == "":
			continue
		body.append(line)
		var indent := line.length() - line.lstrip("\t").length()
		if lambda_indent >= 0:
			if line.strip_edges() == "" or indent > lambda_indent:
				lambda.append(line)
				continue
			(info["lambdas"] as Array).append("\n".join(lambda))
			lambda_indent = -1
		if "connect(" in line and "func(" in line:
			lambda_indent = indent
			lambda = PackedStringArray([line.get_slice("func(", 1)])
	if current != "":
		info["functions"][current] = "\n".join(body)
	if lambda_indent >= 0:
		(info["lambdas"] as Array).append("\n".join(lambda))
	return info


## The category a script's values are listed under.
static func category_of(path: String) -> String:
	var parts := path.trim_prefix("res://").split("/")
	if parts.size() <= 2:
		return parts[0].capitalize()
	var category := parts[1].capitalize()
	if parts.size() > 3:
		category += ": " + parts[2].capitalize()
	return category


## A value as it is now.
static func value(path: String, name: String) -> Variant:
	var script := load(path) as Script
	return script.get(name) if script != null else null


## A value's code default.
static func default_of(path: String, name: String) -> Variant:
	var key := key_of(path, name)
	if not _defaults.has(key):
		_defaults[key] = value(path, name)
	return _defaults[key]


## Sets a value now (not saved: the `tuning` option is).
static func set_value(path: String, name: String, to: Variant) -> void:
	var script := load(path) as Script
	if script == null:
		return
	default_of(path, name)
	_touched[key_of(path, name)] = true
	var current: Variant = script.get(name)
	script.set(name, int(round(float(to))) if current is int else float(to))


## Applies the `tuning` option: each change it holds, and every value once
## changed but no longer in it back to its default.
static func apply(changes: Dictionary) -> void:
	for key: String in _touched.keys():
		if not changes.has(key):
			var parts := key.split("|")
			set_value(parts[0], parts[1], default_of(parts[0], parts[1]))
	for key: String in changes:
		var parts := key.split("|")
		if parts.size() == 2 and ResourceLoader.exists(parts[0]):
			set_value(parts[0], parts[1], changes[key])
