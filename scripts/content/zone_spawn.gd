@tool
class_name ZoneSpawn
extends Resource
## A group of creatures a zone spawns: so many of one creature scattered in a
## circle. Spawns keep their order (it names each creature, and saved corpses
## go by name), so add new ones last.

## A note: who and where.
@export var name := "":
	set(value):
		name = value
		resource_name = value
## The creature (creature_template id).
@export var entry := 0:
	set(value):
		entry = value
		if Engine.is_editor_hint():
			creature = _creature_name(value)
## The creature's name, for reading (worked out from the entry in the editor).
@export var creature := ""
## The circle they're scattered in: its middle in world yards (x, z), and
## radius.
@export var center := Vector2.ZERO
@export var radius := 10.0
## How many.
@export var count := 1

static var _names: Dictionary = {}


static func _creature_name(id: int) -> String:
	if _names.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/classic/creatures.json"))
		if data is Dictionary:
			for key: String in data:
				_names[int(key)] = str(data[key].get("Name", ""))
	return _names.get(id, "")
