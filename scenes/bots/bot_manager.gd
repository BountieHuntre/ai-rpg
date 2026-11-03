class_name BotManager
extends Node
## Keeps the playerbots in the world by the Playerbots options: random bots
## hunting around the zone, and the player's party members beside the player.
## Bots are lasting characters, like a server's bot accounts: their names,
## races, classes, levels, XP, and where they were and how they were doing,
## are kept in playerbots.json in the profile folder (beside the `--save=`
## file in tests), shared by every character.

## A bot came or went: the HUD watches its health and shows its name.
signal bots_changed

const FILE_NAME := "playerbots.json"
const BOT_SCENE := preload("res://scenes/bots/bot.tscn")
## Bots are of the player's faction, so they're friendly.
const ALLIANCE := [ClassicData.Race.HUMAN, ClassicData.Race.DWARF, ClassicData.Race.NIGHT_ELF, ClassicData.Race.GNOME]
const HORDE := [ClassicData.Race.ORC, ClassicData.Race.UNDEAD, ClassicData.Race.TAUREN, ClassicData.Race.TROLL]
## Seconds to wait after an option changes, so dragging a slider doesn't
## make and remove bots at every step.
const SYNC_DELAY := 0.4
## Options that change which bots are in the world.
const WORLD_OPTIONS := ["bots_enabled", "bot_count", "bot_min_level", "bot_max_level", "bot_classes"]

var _player: Player
var _world: Node3D
## Saved bots: { "name", "race", "class", "level", "xp", "state" }, the
## state from Bot.saved_state().
var _roster: Array[Dictionary] = []
## Bots in the world by name.
var _bots: Dictionary = {}
var _sync_queued := false


func setup(player: Player, world: Node3D) -> void:
	_player = player
	_world = world
	_load_roster()
	Party.clear_for_reload()
	sync()
	Settings.changed.connect(_on_setting_changed)
	Party.changed.connect(_number_party)


func _ready() -> void:
	add_to_group("bot_manager")


## A saved bot by name, whatever its case, or {}.
func entry(bot_name: String) -> Dictionary:
	for saved in _roster:
		if str(saved.name).to_lower() == bot_name.to_lower():
			return saved
	return {}


func min_level() -> int:
	return mini(Settings.get_value("bot_min_level"), Settings.get_value("bot_max_level"))


func max_level() -> int:
	return maxi(Settings.get_value("bot_min_level"), Settings.get_value("bot_max_level"))


func bots() -> Array[Bot]:
	var list: Array[Bot] = []
	for bot: Bot in _bots.values():
		list.append(bot)
	return list


## A bot in the world by name, whatever its case, or null.
func find_bot(bot_name: String) -> Bot:
	for key: String in _bots:
		if key.to_lower() == bot_name.to_lower():
			return _bots[key]
	return null


func _on_setting_changed(key: String) -> void:
	if key in WORLD_OPTIONS and not _sync_queued:
		_sync_queued = true
		get_tree().create_timer(SYNC_DELAY).timeout.connect(func() -> void:
			_sync_queued = false
			sync()
		)


## Brings the world's bots in line with the options and the saved party.
func sync() -> void:
	if not Settings.get_value("bots_enabled"):
		for bot_name: String in _bots.keys():
			_despawn(bot_name)
		Party.clear_for_reload()
		bots_changed.emit()
		return
	# The party first, beside the player.
	for bot_name in GameState.party:
		var entry := _entry(bot_name)
		if entry.is_empty():
			continue
		var bot: Bot = _bots.get(entry.name)
		if bot == null:
			bot = _spawn(entry, _near_player())
		Party.restore(bot)
	# Then random bots that fit the options, making new ones as needed.
	var wanted: int = Settings.get_value("bot_count")
	var random := _bots.keys().filter(func(bot_name: String) -> bool: return not Party.is_member(_bots[bot_name]))
	for bot_name: String in random.duplicate():
		if not _fits(_entry(bot_name)) or random.size() > wanted:
			_despawn(bot_name)
			random.erase(bot_name)
	for entry in _roster:
		if random.size() >= wanted:
			break
		if not _bots.has(entry.name) and _fits(entry):
			_spawn(entry, hunting_spot(int(entry.level)))
			random.append(entry.name)
	while random.size() < wanted:
		var entry := _new_entry()
		_spawn(entry, hunting_spot(int(entry.level)))
		random.append(entry.name)
	save_roster()
	_number_party()
	bots_changed.emit()


## Whether a saved bot can be a random bot under the current options. Bots
## below the level range move up to it; ones above it wait in the roster.
func _fits(entry: Dictionary) -> bool:
	if Settings.get_value("bot_classes") == "Templars Only" and int(entry["class"]) != ClassicData.CharClass.PALADIN:
		return false
	if int(entry.race) not in _races():
		return false
	if int(entry.level) < min_level():
		entry.level = min_level()
		entry.xp = 0
	return int(entry.level) <= max_level()


func _races() -> Array:
	return HORDE if GameState.race in HORDE else ALLIANCE


## A new bot of the player's faction: a random race and an allowed class,
## a level in the range, and a name nobody has.
func _new_entry() -> Dictionary:
	var race: int = _races().pick_random()
	var classes: Array = ClassicData.CLASS_NAMES.keys().filter(func(c: int) -> bool: return ClassicData.is_allowed(race, c))
	if Settings.get_value("bot_classes") == "Templars Only":
		race = [ClassicData.Race.HUMAN, ClassicData.Race.DWARF].pick_random() if not GameState.race in HORDE else race
		classes = [ClassicData.CharClass.PALADIN] if ClassicData.is_allowed(race, ClassicData.CharClass.PALADIN) else classes
	var entry := {
		"name": _new_name(), "race": race, "class": classes.pick_random(),
		"level": randi_range(min_level(), max_level()), "xp": 0,
	}
	_roster.append(entry)
	return entry


func _new_name() -> String:
	var taken := _roster.map(func(entry: Dictionary) -> String: return str(entry.name).to_lower())
	taken.append(GameState.char_name.to_lower())
	for npc in get_tree().get_nodes_in_group("npcs"):
		taken.append(str(npc.npc_name).to_lower())
	for attempt in 200:
		var bot_name: String = FrontEnd.NAME_STARTS.pick_random() + FrontEnd.NAME_ENDS.pick_random()
		if not bot_name.to_lower() in taken and GameState.check_name(bot_name).is_empty():
			return bot_name
	return "Bot%d" % (_roster.size() + 1)


func _entry(bot_name: String) -> Dictionary:
	for entry in _roster:
		if str(entry.name) == bot_name:
			return entry
	return {}


func _spawn(entry: Dictionary, at: Vector3) -> Bot:
	var profile := CharacterProfile.new()
	profile.name = "Profile"
	profile.char_name = entry.name
	profile.race = int(entry.race) as ClassicData.Race
	profile.char_class = int(entry["class"]) as ClassicData.CharClass
	profile.level = clampi(int(entry.level), 1, ClassicData.MAX_LEVEL)
	profile.xp = int(entry.xp)
	_equip_starting_gear(profile)
	var bot: Bot = BOT_SCENE.instantiate()
	bot.name = "Bot_%s" % entry.name
	bot.profile = profile
	bot.manager = self
	bot.add_child(profile)
	_world.get_parent().add_child(bot)
	bot.global_position = at
	bot.facing = randf() * TAU
	bot.progression.level_cap = max_level()
	bot.restore_state(entry.get("state", {}))
	if Party.is_member(bot) or entry.name in GameState.party:
		bot.progression.level_cap = ClassicData.MAX_LEVEL
	_bots[entry.name] = bot
	return bot


## Bots wear their race and class's starting gear.
static func _equip_starting_gear(profile: CharacterProfile) -> void:
	var kit := ClassicData.starting_kit(profile.race, profile.char_class)
	profile.proficiencies.assign(kit.proficiencies)
	for item_entry: Array in kit.items:
		var id := int(item_entry[0])
		if int(item_entry[1]) != 1:
			continue
		var item := ItemDB.get_item(id)
		for slot: Inventory.Slot in Inventory.SLOTS_FOR_TYPE.get(int(item.InventoryType), []):
			if not profile.equipment.has(slot):
				profile.equipment[slot] = { "id": id, "count": 1, "bound": true }
				break


func _despawn(bot_name: String) -> void:
	var bot: Bot = _bots.get(bot_name)
	_bots.erase(bot_name)
	if bot == null:
		return
	_store(bot)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.forget(bot.combatant)
	if Party.is_member(bot):
		Party.members.erase(bot)
		Party.changed.emit()
	bot.queue_free()


## Copies a bot's level, XP and state back into the roster.
func _store(bot: Bot) -> void:
	var entry := _entry(bot.profile.char_name)
	if not entry.is_empty():
		entry.level = bot.profile.level
		entry.xp = bot.profile.xp
		entry.state = bot.saved_state()


func _number_party() -> void:
	for i in Party.members.size():
		Party.members[i].party_slot = i


## A point beside the player, for party members joining the world.
func _near_player() -> Vector3:
	var angle := _player.facing + PI + randf_range(-0.8, 0.8)
	return _player.global_position + Basis(Vector3.UP, angle) * Vector3.FORWARD * 2.5 + Vector3.UP * 0.3


## Somewhere in a creature spawn area suited to a level: creatures from three
## levels below to one above, or the nearest in level if none fit.
func hunting_spot(level: int) -> Vector3:
	var spawns: Array = _world.get("SPAWNS") if _world.get("SPAWNS") != null else []
	var suited := []
	var closest := []
	var closest_gap := 1000
	for spawn: Array in spawns:
		var data := Enemy.creature_data(int(spawn[0]))
		var low := int(data.get("MinLevel", 1))
		var high := int(data.get("MaxLevel", 1))
		if high >= level - 3 and low <= level + 1:
			suited.append(spawn)
		var gap := mini(absi(low - level), absi(high - level))
		if gap < closest_gap:
			closest_gap = gap
			closest = [spawn]
		elif gap == closest_gap:
			closest.append(spawn)
	var pool := suited if not suited.is_empty() else closest
	if pool.is_empty():
		return AshfordVale.SPAWN
	var spawn: Array = pool.pick_random()
	var center: Vector2 = spawn[1]
	var reach: float = spawn[2] * sqrt(randf()) * 0.8
	var angle := randf() * TAU
	var x := center.x + cos(angle) * reach
	var z := center.y + sin(angle) * reach
	return Vector3(x, _world.height_at(x, z) + 0.3, z)


func _load_roster() -> void:
	_roster.clear()
	var path := Settings.folder().path_join(FILE_NAME)
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Array:
		return
	for entry in data:
		if entry is Dictionary and entry.has("name"):
			_roster.append({
				"name": str(entry.name), "race": int(entry.race), "class": int(entry["class"]),
				"level": int(entry.level), "xp": int(entry.get("xp", 0)),
				"state": entry.get("state", {}),
			})


func save_roster() -> void:
	for bot: Bot in _bots.values():
		_store(bot)
	var file := FileAccess.open(Settings.folder().path_join(FILE_NAME), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_roster, "\t"))
