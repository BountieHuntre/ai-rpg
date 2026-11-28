@tool
class_name ZoneLayouts
extends RefCounted
## Reads the zones' layouts (data/zones/<zone>.tres, ZoneLayout) by their
## key: the zone script's folder name (ashford_vale, harrowfield...).

const DIR := "res://data/zones/"

static var _layouts: Dictionary = {}


static func of(key: String) -> ZoneLayout:
	if not _layouts.has(key):
		var path := DIR + key + ".tres"
		_layouts[key] = ResourceLoader.load(path) as ZoneLayout if ResourceLoader.exists(path) else null
	return _layouts[key]


## Reads a layout again from disk; returns its key.
static func reload_file(path: String) -> String:
	var key := path.get_file().get_basename()
	_layouts[key] = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ZoneLayout
	return key
