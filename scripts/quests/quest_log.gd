class_name QuestLog
extends RefCounted
## Classic quest rules, working on the quest log in GameState: who can take a
## quest, kill and item objectives, quest-only drops and turning in. Follows
## Player::CanTakeQuest, CanCompleteQuest and RewardQuest in CMaNGOS classic.

## MAX_QUEST_LOG_SIZE in classic.
const MAX_QUESTS := 20
const ERR_LOG_FULL := "Your quest log is full."
const ERR_INCOMPLETE := "You haven't finished that quest."
const ERR_CHOOSE := "Choose a reward first."
const ERR_BAGS_FULL := "Inventory is full."
const YELLOW := Color("ffd100")
const GREY := Color(0.6, 0.6, 0.6)

enum Status { UNAVAILABLE, AVAILABLE, ACTIVE, COMPLETE, DONE }
## QuestFlags: an exploration quest (CMaNGOS QUEST_FLAGS_EXPLORATION). The
## place to explore is the quest text's "explore", a named place of the zones
## (Zone.places): classic's area triggers are client data, and the world's
## places are the game's own.

## Bag counts of quest items seen last, to report progress as they change.
static var _item_counts: Dictionary


static func status(id: int) -> Status:
	if id in GameState.quests_done:
		return Status.DONE
	if GameState.quests.has(id):
		return Status.COMPLETE if is_complete(id) else Status.ACTIVE
	return Status.AVAILABLE if can_take(id) else Status.UNAVAILABLE


## Level and chain checks. Like the vale itself, these quests are open to
## every race here, unlike classic's Alliance-only starting quests.
static func can_take(id: int) -> bool:
	var quest := QuestDB.get_quest(id)
	if quest.is_empty() or id in GameState.quests_done or GameState.quests.has(id):
		return false
	if int(quest.min_level) > GameState.level:
		return false
	var prev := int(quest.prev)
	return prev <= 0 or prev in GameState.quests_done


## Classic greys out quests five or more levels below the player.
static func is_trivial(id: int) -> bool:
	return int(QuestDB.get_quest(id).get("level", 0)) <= GameState.level - 5


static func accept(id: int) -> String:
	if not can_take(id):
		return ""
	if GameState.quests.size() >= MAX_QUESTS:
		return ERR_LOG_FULL
	var quest := QuestDB.get_quest(id)
	if int(quest.source_item) > 0 and Inventory.add_item(int(quest.source_item), 1) > 0:
		return ERR_BAGS_FULL
	var kills := []
	kills.resize(quest.kills.size())
	kills.fill(0)
	GameState.quests[id] = { "kills": kills }
	if not explore_place(id).is_empty():
		GameState.quests[id].explored = false
	_remember_item_counts()
	GameState.quest_message.emit("Quest accepted: %s" % quest.title)
	GameState.quests_changed.emit()
	return ""


static func abandon(id: int) -> void:
	if GameState.quests.erase(id):
		GameState.quests_changed.emit()


static func is_complete(id: int) -> bool:
	if not GameState.quests.has(id):
		return false
	var quest := QuestDB.get_quest(id)
	var kills: Array = GameState.quests[id].kills
	for i in quest.kills.size():
		if int(kills[i]) < int(quest.kills[i][1]):
			return false
	for need: Array in quest.items:
		if Inventory.count_item(int(need[0])) < int(need[1]):
			return false
	if not explore_place(id).is_empty() and not GameState.quests[id].get("explored", false):
		return false
	return true


## The place an exploration quest sends you to, or "".
static func explore_place(id: int) -> String:
	return str(QuestDB.get_quest(id).get("explore", ""))


## A place's name as a heading: "The Old Delve", "Copperhollow".
static func place_title(place: String) -> String:
	return place[0].to_upper() + place.substr(1) if not place.is_empty() else place


## Walking into the place an exploration quest underway sends you to
## explores it (classic's area trigger). `places` are the world's.
static func check_exploration(point: Vector3, places: Array) -> void:
	for id: int in GameState.quests:
		var place_name := explore_place(id)
		if place_name.is_empty() or GameState.quests[id].get("explored", false):
			continue
		for place: Array in places:
			if place[0] == place_name and Vector2(point.x, point.z).distance_to(place[1]) <= float(place[2]):
				GameState.quests[id].explored = true
				GameState.quest_message.emit("%s explored." % place_title(place_name))
				_announce_if_complete(id)
				GameState.quests_changed.emit()
				break


## The quest an item starts when used (item_template.startquest), or 0.
static func quest_from_item(item_id: int) -> int:
	return int(ItemDB.get_item(item_id).get("startquest", 0))


## Why an item's quest can't be started now, or "" when it can.
static func item_quest_error(id: int) -> String:
	match status(id):
		Status.DONE:
			return "You have completed that quest."
		Status.ACTIVE, Status.COMPLETE:
			return "You are already on that quest."
		Status.UNAVAILABLE:
			return "You can't take that quest yet."
	return ""


## Objective lines for the log and the tracker: [text, done].
static func objective_lines(id: int) -> Array:
	var quest := QuestDB.get_quest(id)
	var lines := []
	var kills: Array = GameState.quests.get(id, {}).get("kills", [])
	for i in quest.kills.size():
		var needed := int(quest.kills[i][1])
		var have := mini(int(kills[i]) if i < kills.size() else 0, needed)
		lines.append(["%s slain: %d/%d" % [creature_name(int(quest.kills[i][0])), have, needed], have >= needed])
	for need: Array in quest.items:
		var needed := int(need[1])
		var have := mini(Inventory.count_item(int(need[0])), needed)
		lines.append(["%s: %d/%d" % [ItemDB.get_item(int(need[0])).name, have, needed], have >= needed])
	var place := explore_place(id)
	if not place.is_empty():
		var explored: bool = GameState.quests.get(id, {}).get("explored", false)
		lines.append(["%s explored" % place_title(place), explored])
	return lines


## Credit for a kill, as Player::KilledMonsterCredit.
static func on_kill(creature_entry: int) -> void:
	for id: int in GameState.quests:
		var quest := QuestDB.get_quest(id)
		var kills: Array = GameState.quests[id].kills
		for i in quest.kills.size():
			var needed := int(quest.kills[i][1])
			if int(quest.kills[i][0]) == creature_entry and int(kills[i]) < needed:
				kills[i] = int(kills[i]) + 1
				GameState.quest_message.emit("%s slain: %d/%d" % [creature_name(creature_entry), kills[i], needed])
				_announce_if_complete(id)
				GameState.quests_changed.emit()


## Whether a quest-only drop should drop: an active quest still needs it.
static func needs_item(item_id: int) -> bool:
	for id: int in GameState.quests:
		for need: Array in QuestDB.get_quest(id).items:
			if int(need[0]) == item_id and Inventory.count_item(item_id) < int(need[1]):
				return true
	return false


## Reports quest item progress when bag counts go up ("Tough Wolf Meat: 3/8").
static func on_inventory_changed() -> void:
	var before := _item_counts
	_remember_item_counts()
	for id: int in GameState.quests:
		var progressed := false
		for need: Array in QuestDB.get_quest(id).items:
			var item := int(need[0])
			var needed := int(need[1])
			var now: int = _item_counts.get(item, 0)
			var was: int = before.get(item, now)
			if now > was and was < needed:
				GameState.quest_message.emit("%s: %d/%d" % [ItemDB.get_item(item).name, mini(now, needed), needed])
				progressed = true
		if progressed:
			_announce_if_complete(id)
			GameState.quests_changed.emit()


## Turns a quest in: takes the required items, gives the rewards (the chosen
## one of the choices too), money and XP. Returns an error, or "".
static func complete(id: int, choice: int, progression: Progression) -> String:
	if not is_complete(id):
		return ERR_INCOMPLETE
	var quest := QuestDB.get_quest(id)
	var rewards: Array = quest.reward_items.duplicate()
	if not quest.reward_choices.is_empty():
		if choice < 0 or choice >= quest.reward_choices.size():
			return ERR_CHOOSE
		rewards.append(quest.reward_choices[choice])
	if not Inventory.has_room_for_all(rewards):
		return ERR_BAGS_FULL
	var xp := QuestDB.xp_value(quest, GameState.level)
	GameState.quests.erase(id)
	GameState.quests_done.append(id)
	for need: Array in quest.items:
		Inventory.remove_items(int(need[0]), int(need[1]))
	for reward: Array in rewards:
		Inventory.add_item(int(reward[0]), int(reward[1]))
	GameState.money += int(quest.money)
	_remember_item_counts()
	GameState.quest_message.emit("%s completed." % quest.title)
	if progression and xp > 0:
		progression.add_xp(xp)
	# Unlike classic, the party's bots get the same XP.
	Party.share_quest_xp(xp)
	GameState.quests_changed.emit()
	return ""


## The quests an NPC gives or takes: [{ "id", "status" }], turn-ins first,
## then new quests, then ones still underway.
## for_npc's answers by NPC: the HUD and minimap ask for every NPC each frame,
## and each answer checks every quest. Cleared when quests change and at
## least every CACHE_FRAMES frames (levelling makes new quests available).
static var _npc_cache: Dictionary = {}
static var _cache_frame := -1000
const CACHE_FRAMES := 15


static func clear_cache() -> void:
	_npc_cache.clear()


static func for_npc(npc_id: String) -> Array:
	var frame := Engine.get_process_frames()
	if frame - _cache_frame > CACHE_FRAMES:
		_npc_cache.clear()
		_cache_frame = frame
		if not GameState.quests_changed.is_connected(clear_cache):
			GameState.quests_changed.connect(clear_cache)
	if not _npc_cache.has(npc_id):
		_npc_cache[npc_id] = _for_npc(npc_id)
	return (_npc_cache[npc_id] as Array).duplicate()


static func _for_npc(npc_id: String) -> Array:
	var turn_in := []
	var available := []
	var underway := []
	for id: int in QuestDB.all_ids():
		var quest := QuestDB.get_quest(id)
		var state := status(id)
		if quest.ender == npc_id and state == Status.COMPLETE:
			turn_in.append({ "id": id, "status": state })
		elif quest.ender == npc_id and state == Status.ACTIVE:
			underway.append({ "id": id, "status": state })
		elif quest.giver == npc_id and state == Status.AVAILABLE:
			available.append({ "id": id, "status": state })
	return turn_in + available + underway


## The marker over an NPC as [text, color]: a yellow "?" for a quest to turn
## in, "!" for a new one (grey when trivial), a grey "?" for one underway.
static func marker(npc_id: String) -> Array:
	var entries := for_npc(npc_id)
	if entries.is_empty():
		return ["", Color.WHITE]
	var first: Dictionary = entries[0]
	match first.status:
		Status.COMPLETE:
			return ["?", YELLOW]
		Status.AVAILABLE:
			return ["!", GREY if is_trivial(first.id) else YELLOW]
	return ["?", GREY]


## Objectives of quests underway that a creature counts toward, by killing it
## or by what it drops: [[quest title, [[objective text, done], ...]], ...].
static func objectives_for_creature(creature_entry: int, loot_id: int) -> Array:
	var drops := LootTable.quest_items(loot_id)
	var result := []
	for id: int in GameState.quests:
		var quest := QuestDB.get_quest(id)
		var lines := []
		var all_lines := objective_lines(id)
		for i in quest.kills.size():
			if int(quest.kills[i][0]) == creature_entry:
				lines.append(all_lines[i])
		for i in quest.items.size():
			if int(quest.items[i][0]) in drops:
				lines.append(all_lines[quest.kills.size() + i])
		if not lines.is_empty():
			result.append([quest.title, lines])
	return result


static func creature_name(entry: int) -> String:
	return str(Enemy.creature_data(entry).get("Name", "Creature"))


static func _announce_if_complete(id: int) -> void:
	if is_complete(id):
		GameState.quest_message.emit("%s (Complete)" % QuestDB.get_quest(id).title)


static func _remember_item_counts() -> void:
	_item_counts = {}
	for id: int in GameState.quests:
		for need: Array in QuestDB.get_quest(id).items:
			_item_counts[int(need[0])] = Inventory.count_item(int(need[0]))
