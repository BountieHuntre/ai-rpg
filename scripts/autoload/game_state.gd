extends Node
## The player's character, progress and items, saved to disk. Lives outside
## the scene so it survives the restart after death.
## Item stacks are dictionaries: { "id": item id, "count": n, "bound": bool },
## or {} for an empty slot. Inventory rules live in Inventory.
## The save file is user://character.json. Pass `-- --save=<path>` on the
## command line to use another file, which keeps tests away from the real save.

signal inventory_changed
signal spells_changed
signal money_changed

## The classic backpack has 16 slots, plus four bag slots.
const BACKPACK_SLOTS := 16
const BAG_SLOTS := 4
const ACTION_SLOTS := 12
const SAVE_PATH := "user://character.json"
## Bump when the save format changes, and convert older saves in _apply_save.
const SAVE_VERSION := 1

var race := ClassicData.Race.HUMAN
var char_class := ClassicData.CharClass.PALADIN
var level := 1
var xp := 0
## Money in copper. Changing it emits money_changed.
var money := 0:
	set(value):
		money = value
		money_changed.emit()
## Weapon and armor types the character can use, as "class:subclass" keys.
var proficiencies: Array[String] = []
## Inventory.Slot -> item stack.
var equipment: Dictionary = {}
## The bags in the four bag slots.
var bags: Array[Dictionary] = []
## Contents of the backpack (index 0) and each bag (1 to 4).
var containers: Array = []
## Where the player was and how they were doing when last saved:
## { "position": [x, y, z], "facing": radians, "health": n, "mana": n }.
## Empty for a new character.
var player_state: Dictionary = {}
## The world around the player: { "corpses": { enemy name: corpse state } }.
var world_state: Dictionary = {}
## Spell ids the character knows, every rank included.
var known_spells: Array[int] = []
## Spell id in each of the 12 action bar slots, or 0 for empty.
var action_bar: Array[int] = []

var save_path := SAVE_PATH


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
	_reset_items()


func _ready() -> void:
	if not load_from_disk():
		Inventory.start_character(self)
		_start_spells()


## Classic starting spells, plus Attack, laid out on the action bar.
func _start_spells() -> void:
	known_spells.assign([SpellDB.ATTACK] + SpellDB.start_spells(race, char_class))
	action_bar.clear()
	action_bar.resize(ACTION_SLOTS)
	action_bar.fill(0)
	for i in known_spells.size():
		action_bar[i] = known_spells[i]


func add_item(id: int, count: int, bound := false) -> int:
	return Inventory.add_item(id, count, bound)


func free_slots() -> int:
	return Inventory.free_slots()


func total_slots() -> int:
	var total := 0
	for container: Array in containers:
		total += container.size()
	return total


## Writes the save to a temporary file first, so a crash mid-write can't
## destroy the previous save.
func save_to_disk() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"race": race,
		"class": char_class,
		"level": level,
		"xp": xp,
		"money": money,
		"proficiencies": proficiencies,
		"equipment": equipment,
		"bags": bags,
		"containers": containers,
		"player": player_state,
		"world": world_state,
		"spells": known_spells,
		"action_bar": action_bar,
	}
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't write save %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var error := DirAccess.rename_absolute(temp_path, save_path)
	if error != OK:
		push_error("Couldn't replace save %s: %s" % [save_path, error_string(error)])
		return false
	return true


## Returns false when there's no save, or it can't be read.
func load_from_disk() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or int(data.get("version", 0)) > SAVE_VERSION:
		push_error("Ignoring unreadable save %s" % save_path)
		return false
	_apply_save(data)
	return true


## Starts a fresh character and removes the save.
func reset_character() -> void:
	race = ClassicData.Race.HUMAN
	char_class = ClassicData.CharClass.PALADIN
	level = 1
	xp = 0
	money = 0
	player_state = {}
	world_state = {}
	_reset_items()
	Inventory.start_character(self)
	_start_spells()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func _apply_save(data: Dictionary) -> void:
	race = int(data.race) as ClassicData.Race
	char_class = int(data["class"]) as ClassicData.CharClass
	level = clampi(int(data.level), 1, ClassicData.MAX_LEVEL)
	xp = int(data.xp)
	money = int(data.money)
	proficiencies.assign(data.proficiencies)
	# JSON turns ints into floats and dictionary keys into strings.
	equipment = {}
	for slot: String in data.equipment:
		equipment[int(slot)] = _read_stack(data.equipment[slot])
	bags.assign(data.bags.map(_read_stack))
	containers = data.containers.map(func(container: Array) -> Array: return container.map(_read_stack))
	player_state = data.get("player", {})
	world_state = data.get("world", {})
	# Saves from before spells existed start with the class's starting spells.
	if data.has("spells"):
		known_spells.assign(data.spells.map(func(id: float) -> int: return int(id)))
		action_bar.assign(data.action_bar.map(func(id: float) -> int: return int(id)))
	else:
		_start_spells()


func _read_stack(stack: Dictionary) -> Dictionary:
	if stack.is_empty():
		return {}
	return { "id": int(stack.id), "count": int(stack.count), "bound": bool(stack.get("bound", false)) }


func _reset_items() -> void:
	proficiencies.clear()
	equipment = {}
	bags.clear()
	bags.resize(BAG_SLOTS)
	bags.fill({})
	containers = [[], [], [], [], []]
	containers[0].resize(BACKPACK_SLOTS)
	containers[0].fill({})
