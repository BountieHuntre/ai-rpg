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
var _world: World
## Saved bots: { "name", "race", "class", "level", "xp", "state" }, the
## state from Bot.saved_state().
var _roster: Array[Dictionary] = []
## Bots in the world by name.
var _bots: Dictionary = {}
var _sync_queued := false
var _chatter := BotChatter.new()
var _creatures: Array = []
## Where the player is this frame, for bots asking whether they're far off.
var _player_at := Vector3.ZERO


func setup(player: Player, world: World) -> void:
	_player = player
	_world = world
	_load_roster()
	_chatter.name = "BotChatter"
	add_child(_chatter)
	_chatter.setup(self)
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


## Replaces the random bots with new ones (developer tool): every bot but
## the party's and the player's friends is deleted, roster entry and all, and
## sync makes as many new ones as the options ask for, with new names, races,
## classes and levels. Returns how many were deleted.
func randomize_bots() -> int:
	var keep: Array[String] = []
	for bot_name in GameState.party + GameState.friends:
		keep.append(str(bot_name).to_lower())
	for bot_name: String in _bots.keys():
		if not bot_name.to_lower() in keep:
			_despawn(bot_name)
	var before := _roster.size()
	_roster.assign(_roster.filter(func(entry: Dictionary) -> bool: return str(entry.name).to_lower() in keep))
	var deleted := before - _roster.size()
	sync()
	return deleted


## Whether a saved bot can be a random bot under the current options. Bots
## below the level range move up to it; ones above it wait in the roster.
func _fits(entry: Dictionary) -> bool:
	if Settings.get_value("bot_classes") != "All Classes" and not int(entry["class"]) in SpellDB.classes_with_spells():
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
	if Settings.get_value("bot_classes") != "All Classes":
		# A race that can be one of the classes with spells (Horde Templars don't exist).
		var casters := _races().filter(func(r: int) -> bool:
			return SpellDB.classes_with_spells().any(func(c: int) -> bool: return ClassicData.is_allowed(r, c)))
		race = casters.pick_random() if not casters.is_empty() else race
		classes = ClassicData.CLASS_NAMES.keys().filter(func(c: int) -> bool: return ClassicData.is_allowed(race, c))
		var with_spells := classes.filter(func(c: int) -> bool: return c in SpellDB.classes_with_spells())
		classes = with_spells if not with_spells.is_empty() else classes
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
	_restore_equipment(profile, entry.get("equipment", {}))
	var bot: Bot = BOT_SCENE.instantiate()
	bot.name = "Bot_%s" % entry.name
	bot.profile = profile
	bot.manager = self
	bot.quests = BotQuests.from_dict(entry.get("quests", {}))
	bot.bag = BotBag.from_dict(entry.get("bag", {}))
	bot.add_child(profile)
	_world.get_parent().add_child(bot)
	bot.global_position = at
	bot.facing = randf() * TAU
	bot.progression.level_cap = max_level()
	bot.restore_state(entry.get("state", {}))
	bot.progression.leveled_up.connect(_chatter.on_level.bind(bot))
	bot.revived.connect(_chatter.on_revived.bind(bot))
	bot.arrived.connect(_chatter.on_arrived.bind(bot))
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


## Gear a bot was wearing when saved (from the "bis" command, say) goes back
## on over its starting gear.
static func _restore_equipment(profile: CharacterProfile, saved: Dictionary) -> void:
	if saved.is_empty():
		return
	profile.equipment.clear()
	for key: String in saved:
		var stack: Dictionary = saved[key]
		var id := int(stack.get("id", 0))
		if not ItemDB.get_item(id).is_empty():
			profile.equipment[int(key)] = { "id": id, "count": maxi(int(stack.get("count", 1)), 1), "bound": bool(stack.get("bound", false)) }


static func _saved_equipment(profile: CharacterProfile) -> Dictionary:
	var saved := {}
	for slot: int in profile.equipment:
		var stack: Dictionary = profile.equipment[slot]
		if not stack.is_empty():
			saved[str(slot)] = { "id": int(stack.id), "count": int(stack.get("count", 1)), "bound": bool(stack.get("bound", false)) }
	return saved


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
	if _player and _player.targeting.target == bot:
		_player.targeting.set_target(null)
	bot.queue_free()


## Copies a bot's level, XP and state back into the roster.
func _store(bot: Bot) -> void:
	var entry := _entry(bot.profile.char_name)
	if not entry.is_empty():
		entry.level = bot.profile.level
		entry.xp = bot.profile.xp
		entry.state = bot.saved_state()
		entry.quests = bot.quests.to_dict()
		entry.bag = bot.bag.to_dict()
		entry.equipment = _saved_equipment(bot.profile)


func _number_party() -> void:
	for i in Party.members.size():
		Party.members[i].party_slot = i


## A point beside the player, for party members joining the world.
func _near_player() -> Vector3:
	var angle := _player.facing + PI + randf_range(-0.8, 0.8)
	return _player.global_position + Basis(Vector3.UP, angle) * Vector3.FORWARD * 2.5 + Vector3.UP * 0.3


## Waypoints from one point to another: through the pass when they're in
## different zones, through the gate of any walled place (the zones'
## enclosures) that one end is inside and the other isn't, then the point
## itself.
func route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var from_zone := _world.zone_at(from)
	var to_zone := _world.zone_at(to)
	if from_zone != to_zone:
		var pass_points := _world.pass_between(from_zone, to_zone)
		if not pass_points.is_empty():
			# Already partway along the pass: join it where it's nearest,
			# rather than going back to its start.
			var flat_from := Vector2(from.x, from.z)
			var nearest := 0
			var nearest_distance := INF
			for i in pass_points.size() - 1:
				var a: Vector2 = pass_points[i]
				var b: Vector2 = pass_points[i + 1]
				var t := clampf((flat_from - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				var distance := flat_from.distance_to(a + (b - a) * t)
				if distance < nearest_distance:
					nearest_distance = distance
					nearest = i
			if nearest_distance < Zone.PASS_FLOOR + Zone.PASS_SIDES:
				pass_points = pass_points.slice(nearest + 1)
			var path: Array[Vector3] = []
			for point in pass_points:
				path.append(Vector3(point.x, _world.height_at(point.x, point.y), point.y))
			var points := _route_in_zone(from, path[0])
			points.append_array(path.slice(1))
			points.append_array(_route_in_zone(path[path.size() - 1], to))
			return points
	return _route_in_zone(from, to)


func _route_in_zone(from: Vector3, to: Vector3) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for walls: Array in _world.enclosures():
		var inside_from := _within(walls, from)
		if inside_from == _within(walls, to):
			continue
		var outside: Vector2 = walls[4]
		var inside: Vector2 = walls[5]
		var flat: Array[Vector2] = []
		if inside_from:
			flat.append_array([inside, outside])
			var back := _around(walls, Vector2(to.x, to.z), outside)
			back.reverse()
			flat.append_array(back)
		else:
			flat.append_array(_around(walls, Vector2(from.x, from.z), outside))
			flat.append_array([outside, inside])
		for point in flat:
			points.append(Vector3(point.x, _world.height_at(point.x, point.y), point.y))
	points.append(to)
	return points


## Yards kept clear of the walls when going round them.
const WALL_MARGIN := 4.0


## Corners to go round a walled place from a point outside it to its gate,
## when the straight way would run into the walls: the nearer corner on the
## gate's side, and before it the corner behind that if that's blocked too.
func _around(walls: Array, from: Vector2, gate: Vector2) -> Array[Vector2]:
	var corners: Array[Vector2] = []
	if not _crosses(walls, from, gate):
		return corners
	var left: float = walls[0] - WALL_MARGIN
	var right: float = walls[2] + WALL_MARGIN
	var near_z: float = walls[3] + WALL_MARGIN if gate.y > walls[3] else walls[1] - WALL_MARGIN
	var far_z: float = walls[1] - WALL_MARGIN if gate.y > walls[3] else walls[3] + WALL_MARGIN
	var x := left if absf(from.x - left) < absf(from.x - right) else right
	var corner := Vector2(x, near_z)
	if _crosses(walls, from, corner):
		corners.append(Vector2(x, far_z))
	corners.append(corner)
	return corners


## Whether a straight line between two points passes through the walls
## (with a margin).
static func _crosses(walls: Array, a: Vector2, b: Vector2) -> bool:
	var low := Vector2(walls[0] - 1.5, walls[1] - 1.5)
	var high := Vector2(walls[2] + 1.5, walls[3] + 1.5)
	var box := [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, box[i], box[(i + 1) % 4]) != null:
			return true
	return false


static func _within(walls: Array, point: Vector3) -> bool:
	return point.x > walls[0] and point.z > walls[1] and point.x < walls[2] and point.z < walls[3]


## The zone's creatures. They're placed once and respawn in place, so the
## list is made once.
func creatures() -> Array:
	if _creatures.is_empty():
		_creatures = get_tree().get_nodes_in_group("enemies")
	return _creatures


## Far bots and creatures (more than Bot.FAR from the player, bots not in
## the party or a trade) are ticked here instead of every frame: in turn,
## each at most FAR_RATE times a second, until FAR_BUDGET microseconds of
## the frame are used. However many there are, they cost about the same
## frame time; with more of them each is ticked less often (its step is
## capped at FAR_MAX_STEP seconds, so a crowded world's far side runs slow).
const FAR_BUDGET := 3000
const FAR_RATE := 10.0
const FAR_MAX_STEP := 0.5
var _clock := 0.0
var _far_units: Array[Node] = []
var _far_cursor := 0


func _physics_process(delta: float) -> void:
	if _player:
		_player_at = _player.global_position
	_clock += delta
	_far_units.clear()
	for bot: Bot in _bots.values():
		var was_far := bot._far
		bot.set_far(far_from_player(bot.global_position) and not Party.is_member(bot) and not bot.trading)
		if bot._far:
			if not was_far:
				bot.far_clock = _clock
			_far_units.append(bot)
	_creature_grid.clear()
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		var key := Vector2i(floori(enemy.global_position.x / GRID), floori(enemy.global_position.z / GRID))
		if not _creature_grid.has(key):
			_creature_grid[key] = []
		_creature_grid[key].append(enemy)
		var was_far := enemy.is_far()
		enemy.set_far(far_from_player(enemy.global_position))
		if enemy.is_far():
			if not was_far:
				enemy.far_clock = _clock
			if enemy.state != Enemy.State.DEAD:
				_far_units.append(enemy)
	far_schedule()


## Creatures by square of the world, GRID yards on a side, made once a
## physics frame, for bots looking for something to fight.
const GRID := 50.0
var _creature_grid: Dictionary = {}


## The creatures in the squares within `radius` of a point (some further).
func creatures_near(point: Vector3, radius: float) -> Array:
	var near := []
	var low := Vector2i(floori((point.x - radius) / GRID), floori((point.z - radius) / GRID))
	var high := Vector2i(floori((point.x + radius) / GRID), floori((point.z + radius) / GRID))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for enemy in _creature_grid.get(Vector2i(x, z), []):
				if is_instance_valid(enemy):
					near.append(enemy)
	return near


## Ticks far units in turn within the frame's budget.
func far_schedule() -> void:
	var count := _far_units.size()
	if count == 0:
		return
	var start := Time.get_ticks_usec()
	for k in count:
		if Time.get_ticks_usec() - start > FAR_BUDGET:
			break
		_far_cursor = (_far_cursor + 1) % count
		var unit: Node = _far_units[_far_cursor]
		var waited: float = _clock - unit.far_clock
		if waited < 1.0 / FAR_RATE:
			continue
		unit.far_clock = _clock
		unit.far_tick(minf(waited, FAR_MAX_STEP))


func far_from_player(point: Vector3) -> bool:
	return point.distance_squared_to(_player_at) > Bot.FAR * Bot.FAR


## The ground's height at a point.
func ground_height(x: float, z: float) -> float:
	return _world.height_at(x, z)


## The named place a point is in (the zone's PLACES), or "".
func place_at(point: Vector3) -> String:
	for place: Array in _places():
		if Vector2(point.x, point.z).distance_to(place[1]) <= float(place[2]):
			return place[0]
	return ""


## A named place by name: [name, center, radius], or [].
func place_named(place_name: String) -> Array:
	for place: Array in _places():
		if place[0] == place_name:
			return place
	return []


## Where a named place is, from the middle of its zone's settlement (the
## priory, Wexford): "west", "southeast"...
func direction_of(place_name: String) -> String:
	for place: Array in _places():
		if place[0] == place_name:
			var zone := _world.zone_at(Vector3(place[1].x, 0, place[1].y))
			var offset: Vector2 = place[1] - zone.hub
			# -Z is north.
			var angle := fposmod(rad_to_deg(atan2(offset.x, -offset.y)), 360.0)
			return ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"][roundi(angle / 45.0) % 8]
	return ""


## The settlement of the zone a named place is in ("the priory", "Wexford"),
## which direction_of measures from.
func hub_of(place_name: String) -> String:
	for place: Array in _places():
		if place[0] == place_name:
			return _world.zone_at(Vector3(place[1].x, 0, place[1].y)).hub_name
	return ""


func place_names() -> Array:
	return _places().map(func(place: Array) -> String: return place[0])


## The named place where a creature spawns nearest a point, or "".
func spawn_place(entry: int, near: Vector3) -> String:
	var best := ""
	var best_distance := INF
	for spawn: Array in _spawns():
		if int(spawn[0]) != entry:
			continue
		var center: Vector2 = spawn[1]
		var distance := center.distance_to(Vector2(near.x, near.z))
		if distance < best_distance:
			best_distance = distance
			best = place_at(Vector3(center.x, 0, center.y))
	return best


func _places() -> Array:
	return _world.places()


## Creature entries the zone spawns.
func spawn_entries() -> Array:
	if _spawn_entries.is_empty():
		for spawn: Array in _spawns():
			if not int(spawn[0]) in _spawn_entries:
				_spawn_entries.append(int(spawn[0]))
	return _spawn_entries


var _spawn_entries := []


func _spawns() -> Array:
	return _world.spawns()


## The name of the zone a point is in.
func zone_name_at(point: Vector3) -> String:
	return _world.zone_at(point).zone_name


func has_zone(zone_name: String) -> bool:
	return _world.zone_named(zone_name) != null


## The zone the player is in.
func player_zone() -> String:
	return _world.zone_at(_player.global_position).zone_name if _player else ""


## Where the dead come back in the zone a point is in.
func graveyard_at(point: Vector3) -> Vector3:
	return _world.zone_at(point).graveyard


## Somewhere in a creature spawn area: one of the creatures a quest wants if
## given, or else one suited to a level, creatures from three levels below to
## one above, or the nearest in level if none fit.
func hunting_spot(level: int, wanted: Array[int] = []) -> Vector3:
	var spawns := _spawns()
	var quest_spawns := spawns.filter(func(spawn: Array) -> bool: return int(spawn[0]) in wanted)
	if not quest_spawns.is_empty():
		spawns = quest_spawns
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
	if not quest_spawns.is_empty():
		pool = quest_spawns
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
				"quests": entry.get("quests", {}),
				"bag": entry.get("bag", {}),
				"equipment": entry.get("equipment", {}),
			})


func save_roster() -> void:
	for bot: Bot in _bots.values():
		_store(bot)
	var file := FileAccess.open(Settings.folder().path_join(FILE_NAME), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_roster, "\t"))
