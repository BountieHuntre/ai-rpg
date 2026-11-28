@tool
class_name CreatureLooks
extends RefCounted
## Reads the creatures' looks (data/creatures/<entry>_<name>.tres, CreatureLook)
## and the models they use (data/creatures/models.tres) once, and hands them
## out by entry. ContentWatch calls reload_file when one is saved.

const DIR := "res://data/creatures/"
const MODELS_PATH := "res://data/creatures/models.tres"

static var _looks: Dictionary = {}
static var _paths: Dictionary = {}
static var _models: Dictionary = {}
static var _loaded := false


## The look of a creature entry, or null when it has none of its own (the
## capsule in a default colour).
static func of(entry: int) -> CreatureLook:
	_load()
	return _looks.get(entry)


## A model's base size and kind by its name, or null.
static func model(name: String) -> CreatureModelInfo:
	if _models.is_empty():
		_read_models(false)
	return _models.get(name)


static func model_names() -> Array:
	if _models.is_empty():
		_read_models(false)
	return _models.keys()


## Whether a model is a BeastModel.
static func is_beast(name: String) -> bool:
	var info := model(name)
	return info != null and info.beast


## Every entry with a look.
static func entries() -> Array:
	_load()
	return _looks.keys()


## The file a look was read from.
static func path_of(entry: int) -> String:
	_load()
	return _paths.get(entry, "")


## Reads them all again (from disk, not the cache); with a path, only that
## file. Returns the entries changed.
static func reload_file(path := "") -> Array:
	if path == "" or not _loaded:
		_loaded = false
		_load(true)
		return _looks.keys()
	if path == MODELS_PATH:
		_read_models(true)
		return _looks.keys()
	var look := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CreatureLook
	# A file renamed or its entry changed: drop the old one.
	for entry: int in _paths.keys():
		if _paths[entry] == path:
			_looks.erase(entry)
			_paths.erase(entry)
	if look:
		_looks[look.entry] = look
		_paths[look.entry] = path
		return [look.entry]
	return []


static func _load(fresh := false) -> void:
	if _loaded:
		return
	_loaded = true
	_looks.clear()
	_paths.clear()
	var mode := ResourceLoader.CACHE_MODE_IGNORE if fresh else ResourceLoader.CACHE_MODE_REUSE
	for file in ResourceLoader.list_directory(DIR):
		var path := DIR + file
		if not file.ends_with(".tres") or path == MODELS_PATH:
			continue
		var look := ResourceLoader.load(path, "", mode) as CreatureLook
		if look:
			_looks[look.entry] = look
			_paths[look.entry] = path
	_read_models(fresh)


static func _read_models(fresh: bool) -> void:
	_models.clear()
	if not ResourceLoader.exists(MODELS_PATH):
		return
	var mode := ResourceLoader.CACHE_MODE_IGNORE if fresh else ResourceLoader.CACHE_MODE_REUSE
	var models := ResourceLoader.load(MODELS_PATH, "", mode) as CreatureModels
	if models:
		for info in models.models:
			_models[info.name] = info
