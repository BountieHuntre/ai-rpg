extends CharacterProfile
## The player's character, progress and items, saved to disk. Lives outside
## the scene so it survives the restart after death.
## Item stacks are dictionaries: { "id": item id, "count": n, "bound": bool },
## or {} for an empty slot. Inventory rules live in Inventory.
## Each character has a save file in user://characters/, picked on the
## character select screen. Pass `-- --save=<path>` on the command line to play
## one character from that file instead, or `-- --profile=<dir>` to keep the
## characters and login settings in another folder. Both keep tests away from
## the real saves.

signal inventory_changed
signal spells_changed
signal money_changed
signal quests_changed
signal friends_changed
## Quest progress lines ("Burrowling Runt slain: 3/10") for the HUD.
signal quest_message(text: String)
## A quest taken and one handed in (escorts set off on the first; the Thunder
## Ale barrel goes unguarded on the second).
signal quest_accepted(id: int)
signal quest_turned_in(id: int)

## The classic backpack has 16 slots, plus four bag slots.
const BACKPACK_SLOTS := 16
const BAG_SLOTS := 4
const ACTION_SLOTS := 12
## The extra action bars after the main one, as their options and key binding
## names say them ("bar_" + name, name + "_1"...). Each has ACTION_SLOTS slots,
## kept in action_bar after the main bar's, in this order.
const EXTRA_BARS := ["bottom_left", "bottom_right", "right", "right_2"]
const ALL_SLOTS := ACTION_SLOTS * (1 + 4)
## Where the single save lived before there were several characters.
const OLD_SAVE_PATH := "user://character.json"
## Classic name rules (ObjectMgr::CheckPlayerName in CMaNGOS): 2 to 12 letters.
const NAME_MIN := 2
const NAME_MAX := 12
const ERR_NAME_EMPTY := "Enter a name for your character."
const ERR_NAME_SHORT := "Names must be at least 2 characters long."
const ERR_NAME_LONG := "Names must be no more than 12 characters long."
const ERR_NAME_LETTERS := "Names can only contain letters."
const ERR_NAME_TAKEN := "That name is unavailable."
## Bump when the save format changes, and convert older saves in _apply_save.
const SAVE_VERSION := 1
## What the last unlearning of talents cost, in copper (Talents.reset_cost).
var talent_reset_cost := 0

## Name, race, class, level, XP, proficiencies, equipment and known spells
## are in CharacterProfile.
## Money in copper. Changing it emits money_changed.
var money := 0:
	set(value):
		money = value
		money_changed.emit()
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
## Quests in the log by id: { "kills": [count per kill objective] }. QuestLog
## holds the rules.
var quests: Dictionary = {}
## Ids of quests turned in.
var quests_done: Array[int] = []
## Recently sold stacks (newest first), with "price" in copper. Not saved:
## classic clears buyback on logout.
var buyback: Array[Dictionary] = []
## Spell id in each of the 12 action bar slots, or 0 for empty.
var action_bar: Array[int] = []
## Names of the playerbots in the player's party, kept across logging out.
var party: Array[String] = []
## The friends list (the Social window): player names.
var friends: Array[String] = []

## The current character's save file; empty until one is picked.
var save_path := ""
## Set by `--save=`: play that one file, with no character select.
var single_save := false
## `-- --resume=<name>` skips the login and enters the world as that character,
## as the developer console's reload command does after restarting.
var resume_name := ""
## Holds characters/, settings.cfg, options.cfg and playerbots.json: user://
## for released games, DEV_PROFILE for editor and debug runs, so developing
## never touches the saves of the game as players get it. Set by `--profile=`.
var profile_dir := "user://"
var characters_dir := "user://characters"
const DEV_PROFILE := "user://dev/"
## What the developer profile starts with, copied from the release profile.
const PROFILE_FILES := ["settings.cfg", "options.cfg", "playerbots.json"]
## When the current character was created, to keep the character list in order.
var _created := 0


func _init() -> void:
	# Release builds ignore the test arguments: they always use the player's
	# own saves.
	var args := OS.get_cmdline_user_args() if OS.is_debug_build() else PackedStringArray()
	if OS.is_debug_build():
		_use_dev_profile()
	for arg in args:
		if arg.begins_with("--save="):
			save_path = arg.trim_prefix("--save=")
			single_save = true
		elif arg.begins_with("--profile="):
			profile_dir = arg.trim_prefix("--profile=")
			characters_dir = profile_dir.path_join("characters")
		elif arg.begins_with("--resume="):
			resume_name = arg.trim_prefix("--resume=")
	_reset_items()


func _ready() -> void:
	if single_save:
		if not load_from_disk():
			char_name = "Hero"
			Inventory.start_character(self)
			_start_spells()
	else:
		_move_old_save()


## Whether a character has been picked or created this session.
func has_character() -> bool:
	return not save_path.is_empty()


# Characters.

## A summary of every saved character, oldest first:
## [{ "name", "race", "class", "level", "path" }].
func list_characters() -> Array[Dictionary]:
	var characters: Array[Dictionary] = []
	for file in DirAccess.get_files_at(characters_dir):
		if not file.ends_with(".json"):
			continue
		var path := characters_dir.path_join(file)
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and data.has("name"):
			characters.append({
				"name": str(data.name), "race": int(data.race), "class": int(data["class"]),
				"level": int(data.level), "path": path, "created": int(data.get("created", 0)),
				"appearance": data.get("appearance", {}), "equipment": _read_equipment(data.get("equipment", {})),
			})
	characters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.created < b.created)
	return characters


## Classic name formatting: the first letter capitalized, the rest lower case.
static func format_name(name: String) -> String:
	name = name.strip_edges().to_lower()
	return name.left(1).to_upper() + name.substr(1)


## Returns an error message, or "" when the name can be used.
func check_name(name: String) -> String:
	name = format_name(name)
	if name.is_empty():
		return ERR_NAME_EMPTY
	if name.length() < NAME_MIN:
		return ERR_NAME_SHORT
	if name.length() > NAME_MAX:
		return ERR_NAME_LONG
	var letters := RegEx.create_from_string("^[A-Za-z]+$")
	if letters.search(name) == null:
		return ERR_NAME_LETTERS
	if FileAccess.file_exists(_character_path(name)):
		return ERR_NAME_TAKEN
	return ""


## Makes a new level 1 character and saves it. Returns an error message, or "".
func create_character(name: String, new_race: ClassicData.Race, new_class: ClassicData.CharClass, look := {}) -> String:
	var error := check_name(name)
	if not error.is_empty():
		return error
	char_name = format_name(name)
	race = new_race
	char_class = new_class
	appearance = look.duplicate()
	_created = int(Time.get_unix_time_from_system())
	save_path = _character_path(char_name)
	_start_fresh()
	save_to_disk()
	return ""


## Makes a saved character the current one. Returns false if it can't be read.
func select_character(path: String) -> bool:
	save_path = path
	return load_from_disk()


func delete_character(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if path == save_path:
		save_path = ""


func _character_path(name: String) -> String:
	return characters_dir.path_join(name.to_lower() + ".json")


## Editor and debug runs keep their own profile. The first time, it starts as
## a copy of the release profile (characters, options, login and playerbots),
## after which the two go their own ways.
func _use_dev_profile() -> void:
	profile_dir = DEV_PROFILE
	characters_dir = DEV_PROFILE.path_join("characters")
	if DirAccess.dir_exists_absolute(DEV_PROFILE):
		return
	DirAccess.make_dir_recursive_absolute(characters_dir)
	for file: String in PROFILE_FILES:
		if FileAccess.file_exists("user://" + file):
			DirAccess.copy_absolute("user://" + file, DEV_PROFILE + file)
	if DirAccess.dir_exists_absolute("user://characters"):
		for file in DirAccess.get_files_at("user://characters"):
			DirAccess.copy_absolute("user://characters/" + file, characters_dir.path_join(file))


## The save from before character select becomes a character named Hero.
func _move_old_save() -> void:
	DirAccess.make_dir_recursive_absolute(characters_dir)
	if profile_dir != "user://" or not FileAccess.file_exists(OLD_SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(OLD_SAVE_PATH))
	if data is Dictionary and not data.has("name"):
		data.name = "Hero"
		var file := FileAccess.open(_character_path("Hero"), FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data, "\t"))
			file.close()
			DirAccess.remove_absolute(OLD_SAVE_PATH)


## The key binding action for an action bar slot: ability_1... for the main
## bar, bottom_left_1... for the extra ones.
static func slot_action(slot: int) -> String:
	var bar := slot / ACTION_SLOTS
	var name: String = "ability" if bar == 0 else EXTRA_BARS[bar - 1]
	return "%s_%d" % [name, slot % ACTION_SLOTS + 1]


## Whether an action bar is shown: the main one (0) always, the others by option.
static func bar_shown(bar: int) -> bool:
	return bar == 0 or bool(Settings.get_value("bar_" + EXTRA_BARS[bar - 1]))


## The slots of the bars that are shown, main bar first.
static func shown_slots() -> Array[int]:
	var slots: Array[int] = []
	for bar in 1 + EXTRA_BARS.size():
		if bar_shown(bar):
			for i in ACTION_SLOTS:
				slots.append(bar * ACTION_SLOTS + i)
	return slots


## Classic starting spells, plus Attack, laid out on the action bar.
func _start_spells() -> void:
	known_spells.assign([SpellDB.ATTACK, SpellDB.SHOOT] + SpellDB.start_spells(race, char_class))
	talents = {}
	talent_reset_cost = 0
	action_bar.clear()
	action_bar.resize(ALL_SLOTS)
	action_bar.fill(0)
	# Stances have the stance bar, and passives (Parry) no button; Shoot is in
	# the spellbook, for those who carry a ranged weapon.
	var slot := 0
	for id in known_spells:
		var spell := SpellDB.get_spell(id)
		if id != SpellDB.SHOOT and not SpellDB.is_stance_bar_spell(spell) and not SpellDB.is_passive(spell):
			action_bar[slot] = id
			slot += 1


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
		"name": char_name,
		"created": _created,
		"race": race,
		"class": char_class,
		"appearance": appearance,
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
		"talents": talents,
		"talent_reset_cost": talent_reset_cost,
		"action_bar": action_bar,
		"quests": quests,
		"quests_done": quests_done,
		"party": party,
		"friends": friends,
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


## Starts the current character over at level 1, keeping name, race and class.
func reset_character() -> void:
	_start_fresh()
	save_to_disk()


func _start_fresh() -> void:
	level = 1
	xp = 0
	money = 0
	player_state = {}
	world_state = {}
	quests = {}
	quests_done.clear()
	party.clear()
	friends.clear()
	buyback.clear()
	_reset_items()
	Inventory.start_character(self)
	_start_spells()


func _apply_save(data: Dictionary) -> void:
	char_name = str(data.get("name", "Hero"))
	_created = int(data.get("created", 0))
	buyback.clear()
	race = int(data.race) as ClassicData.Race
	char_class = int(data["class"]) as ClassicData.CharClass
	appearance = data.get("appearance", {}) if data.get("appearance") is Dictionary else {}
	level = clampi(int(data.level), 1, ClassicData.MAX_LEVEL)
	xp = int(data.xp)
	money = int(data.money)
	proficiencies.assign(data.proficiencies)
	# JSON turns ints into floats and dictionary keys into strings.
	equipment = {}
	for slot: String in data.equipment:
		var worn := _read_stack(data.equipment[slot])
		if not worn.is_empty():
			equipment[int(slot)] = worn
	bags.assign(data.bags.map(_read_stack))
	containers = data.containers.map(func(container: Array) -> Array: return container.map(_read_stack))
	player_state = data.get("player", {})
	world_state = data.get("world", {})
	quests = {}
	var saved_quests: Dictionary = data.get("quests", {})
	for id: String in saved_quests:
		quests[int(id)] = { "kills": saved_quests[id].kills.map(func(count: float) -> int: return int(count)) }
		if saved_quests[id].has("explored"):
			quests[int(id)].explored = bool(saved_quests[id].explored)
	quests_done.assign(data.get("quests_done", []).map(func(id: float) -> int: return int(id)))
	party.assign(data.get("party", []))
	friends.assign(data.get("friends", []))
	# Saves from before spells existed start with the class's starting spells.
	if data.has("spells"):
		known_spells.assign(data.spells.map(func(id: float) -> int: return int(id)))
		action_bar.assign(data.action_bar.map(func(id: float) -> int: return int(id)))
		# Saves from before the extra bars have only the main bar's slots.
		if action_bar.size() < ALL_SLOTS:
			var had := action_bar.size()
			action_bar.resize(ALL_SLOTS)
			for i in range(had, ALL_SLOTS):
				action_bar[i] = 0
		# Everyone knows Shoot (characters from before it had none).
		if not SpellDB.SHOOT in known_spells:
			known_spells.append(SpellDB.SHOOT)
		# Older characters started with passives (Parry) on the bar.
		for i in action_bar.size():
			if action_bar[i] > 0 and SpellDB.is_passive(SpellDB.get_spell(action_bar[i])):
				action_bar[i] = 0
	else:
		_start_spells()
	# Ranks in each talent; saves from before talents have none.
	talents = {}
	var saved_talents: Dictionary = data.get("talents", {})
	for key: String in saved_talents:
		talents[key] = int(saved_talents[key])
	talent_reset_cost = int(data.get("talent_reset_cost", 0))
	Talents.validate(self)


## Saved equipment ({ "slot": stack }) as Inventory.Slot -> stack.
func _read_equipment(saved) -> Dictionary:
	var out := {}
	if saved is Dictionary:
		for slot: String in saved:
			var worn := _read_stack(saved[slot])
			if not worn.is_empty():
				out[int(slot)] = worn
	return out


func _read_stack(stack: Dictionary) -> Dictionary:
	# Items no longer in the game (arrows and shot) are gone.
	if stack.is_empty() or ItemDB.get_item(int(stack.get("id", 0))).is_empty():
		return {}
	var read := { "id": int(stack.id), "count": int(stack.count), "bound": bool(stack.get("bound", false)) }
	if stack.has("durability"):
		read.durability = int(stack.durability)
	return read


func _reset_items() -> void:
	proficiencies.clear()
	equipment = {}
	bags.clear()
	bags.resize(BAG_SLOTS)
	bags.fill({})
	containers = [[], [], [], [], []]
	containers[0].resize(BACKPACK_SLOTS)
	containers[0].fill({})
