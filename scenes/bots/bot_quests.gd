class_name BotQuests
extends RefCounted
## A playerbot's quest log: the same quests and classic rules as the player's
## (QuestLog), kept apart. Kill objectives count the bot's own kills; item
## objectives roll the creature's classic drop chance for the item, since bots
## don't loot. Saved in the bot's roster entry.

## Bots keep a short log so they finish what they take.
const MAX_ACTIVE := 3

## Quest id -> { "kills": [count per kill objective], "items": [count per item objective] }.
var active: Dictionary = {}
var done: Array[int] = []


func can_take(id: int, level: int) -> bool:
	var quest := QuestDB.get_quest(id)
	if quest.is_empty() or id in done or active.has(id) or active.size() >= MAX_ACTIVE:
		return false
	# Grey quests are taken too: they open the chains behind them.
	if int(quest.min_level) > level:
		return false
	var prev := int(quest.prev)
	return prev <= 0 or prev in done


func accept(id: int) -> void:
	var quest := QuestDB.get_quest(id)
	var kills := []
	kills.resize(quest.kills.size())
	kills.fill(0)
	var items := []
	items.resize(quest.items.size())
	items.fill(0)
	active[id] = { "kills": kills, "items": items }


func is_complete(id: int) -> bool:
	if not active.has(id):
		return false
	var quest := QuestDB.get_quest(id)
	var progress: Dictionary = active[id]
	for i in quest.kills.size():
		if int(progress.kills[i]) < int(quest.kills[i][1]):
			return false
	for i in quest.items.size():
		if int(progress.items[i]) < int(quest.items[i][1]):
			return false
	return true


## The first finished quest, or 0.
func finished() -> int:
	for id: int in active:
		if is_complete(id):
			return id
	return 0


## Turns a quest in and returns its classic XP for the bot's level.
func turn_in(id: int, level: int) -> int:
	active.erase(id)
	done.append(id)
	return QuestDB.xp_value(QuestDB.get_quest(id), level)


## Kill credit and quest drops for a creature the bot killed.
func on_kill(creature_entry: int) -> void:
	var loot_id := int(Enemy.creature_data(creature_entry).get("LootId", 0))
	for id: int in active:
		var quest := QuestDB.get_quest(id)
		var progress: Dictionary = active[id]
		for i in quest.kills.size():
			if int(quest.kills[i][0]) == creature_entry:
				progress.kills[i] = mini(int(progress.kills[i]) + 1, int(quest.kills[i][1]))
		for i in quest.items.size():
			var item := int(quest.items[i][0])
			if int(progress.items[i]) < int(quest.items[i][1]) and randf() * 100.0 < LootTable.drop_chance(loot_id, item):
				progress.items[i] = int(progress.items[i]) + 1


## Creature entries the active quests still need: to kill, or that drop a
## wanted item.
func wanted_creatures(spawn_entries: Array) -> Array[int]:
	var wanted: Array[int] = []
	for id: int in active:
		var quest := QuestDB.get_quest(id)
		var progress: Dictionary = active[id]
		for i in quest.kills.size():
			if int(progress.kills[i]) < int(quest.kills[i][1]) and not int(quest.kills[i][0]) in wanted:
				wanted.append(int(quest.kills[i][0]))
		for i in quest.items.size():
			if int(progress.items[i]) >= int(quest.items[i][1]):
				continue
			for entry: int in spawn_entries:
				var loot_id := int(Enemy.creature_data(entry).get("LootId", 0))
				if not entry in wanted and LootTable.drop_chance(loot_id, int(quest.items[i][0])) > 0.0:
					wanted.append(entry)
	return wanted


## How far along a quest is, 0 to 1, over all its objectives.
func progress(id: int) -> float:
	if not active.has(id):
		return 0.0
	var quest := QuestDB.get_quest(id)
	var have := 0
	var need := 0
	for i in quest.kills.size():
		need += int(quest.kills[i][1])
		have += mini(int(active[id].kills[i]), int(quest.kills[i][1]))
	for i in quest.items.size():
		need += int(quest.items[i][1])
		have += mini(int(active[id].items[i]), int(quest.items[i][1]))
	return 1.0 if need == 0 else float(have) / need


## Item ids its quests still need and it has none of yet.
func items_needed() -> Array[int]:
	var items: Array[int] = []
	for id: int in active:
		var quest := QuestDB.get_quest(id)
		for i in quest.items.size():
			if int(active[id].items[i]) == 0:
				items.append(int(quest.items[i][0]))
	return items


## What it's on, for its tooltip: the first quest's title, or "".
func current_title() -> String:
	for id: int in active:
		return str(QuestDB.get_quest(id).get("title", ""))
	return ""


func to_dict() -> Dictionary:
	var saved := {}
	for id: int in active:
		saved[str(id)] = active[id]
	return { "active": saved, "done": done }


static func from_dict(data: Dictionary) -> BotQuests:
	var quests := BotQuests.new()
	var saved: Dictionary = data.get("active", {})
	for key: String in saved:
		if QuestDB.get_quest(int(key)).is_empty():
			continue
		quests.active[int(key)] = {
			"kills": saved[key].get("kills", []).map(func(n: Variant) -> int: return int(n)),
			"items": saved[key].get("items", []).map(func(n: Variant) -> int: return int(n)),
		}
	quests.done.assign(data.get("done", []).map(func(id: Variant) -> int: return int(id)))
	return quests
