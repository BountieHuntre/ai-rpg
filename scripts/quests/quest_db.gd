class_name QuestDB
extends RefCounted
## Quests: the classic rules each one is built on (data/classic/quests.json,
## from CMaNGOS quest_template) joined with the game's own title, text and
## quest givers (data/quests.json). Givers and enders are NPC node names.

const RULES_PATH := "res://data/classic/quests.json"
const TEXT_PATH := "res://data/quests.json"

static var _quests: Dictionary


static func get_quest(id: int) -> Dictionary:
	return _get_quests().get(id, {})


static func all_ids() -> Array:
	return _get_quests().keys()


## Quest XP, as Quest::XPValue in CMaNGOS classic: a full value from
## RewMoneyMaxLevel and the quest level, cut down when the player is 6 or more
## levels above the quest.
static func xp_value(quest: Dictionary, player_level: int) -> int:
	var base := float(quest.money_max_level)
	if base <= 0.0:
		return 0
	var quest_level := int(quest.level)
	var full := base
	if quest_level >= 15:
		full = base / 6.0
	elif quest_level == 14:
		full = base / 4.8
	elif quest_level == 13:
		full = base / 3.666
	elif quest_level == 12:
		full = base / 2.4
	elif quest_level == 11:
		full = base / 1.2
	elif quest_level >= 1:
		full = base / 0.6
	var above := player_level - quest_level
	var factor := 1.0
	if above >= 10:
		factor = 0.1
	elif above >= 6:
		factor = 1.0 - (above - 5) * 0.2
	return ceili(full * factor)


static func _get_quests() -> Dictionary:
	if _quests.is_empty():
		var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
		var texts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEXT_PATH))
		for key: String in texts:
			if not rules.has(key):
				push_error("Quest %s has text but no rules in %s" % [key, RULES_PATH])
				continue
			var quest: Dictionary = rules[key].duplicate(true)
			quest.merge(texts[key])
			quest.id = int(key)
			_quests[int(key)] = quest
	return _quests
