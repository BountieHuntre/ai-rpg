@tool
class_name CharacterLooks
extends RefCounted
## Reads the races' looks (data/looks/<race>.tres, RaceLook) and the outfits'
## colours (data/looks/outfits.tres, OutfitLooks) once. ContentWatch calls
## reload_file when one is saved.

const DIR := "res://data/looks/"
const OUTFITS_PATH := "res://data/looks/outfits.tres"

static var _races: Dictionary = {}
static var _race_paths: Dictionary = {}
static var _outfits: OutfitLooks
static var _loaded := false


## A race's look; races without a file take the Human's.
static func race(name: String) -> RaceLook:
	_load()
	return _races.get(name, _races.get("human"))


## Whether a race has a file of its own.
static func has_race(name: String) -> bool:
	_load()
	return _races.has(name)


static func outfits() -> OutfitLooks:
	_load()
	return _outfits


## Reads one file again from disk (or all of them).
static func reload_file(path := "") -> void:
	if path == "" or not _loaded:
		_loaded = false
		_load(true)
		return
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is OutfitLooks:
		_outfits = resource
	elif resource is RaceLook:
		for name: String in _race_paths.keys():
			if _race_paths[name] == path:
				_races.erase(name)
				_race_paths.erase(name)
		_races[(resource as RaceLook).race] = resource
		_race_paths[(resource as RaceLook).race] = path


static func _load(fresh := false) -> void:
	if _loaded:
		return
	_loaded = true
	_races.clear()
	_race_paths.clear()
	var mode := ResourceLoader.CACHE_MODE_IGNORE if fresh else ResourceLoader.CACHE_MODE_REUSE
	for file in ResourceLoader.list_directory(DIR):
		if not file.ends_with(".tres"):
			continue
		var resource := ResourceLoader.load(DIR + file, "", mode)
		if resource is OutfitLooks:
			_outfits = resource
		elif resource is RaceLook:
			_races[(resource as RaceLook).race] = resource
			_race_paths[(resource as RaceLook).race] = DIR + file
