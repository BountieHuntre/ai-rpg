class_name ClassicData
extends RefCounted
## Classic WoW (patch 1.12) player tables and class constants.
## See data/classic/SOURCE.md for where the numbers come from.

enum CharClass { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
enum Race { HUMAN = 1, ORC = 2, DWARF = 3, NIGHT_ELF = 4, UNDEAD = 5, TAUREN = 6, GNOME = 7, TROLL = 8 }
enum Stat { STRENGTH, AGILITY, STAMINA, INTELLECT, SPIRIT }

const MAX_LEVEL := 60
const TABLES_PATH := "res://data/classic/player_tables.json"
const CHARACTERS_PATH := "res://data/classic/characters.json"

const CLASS_NAMES := {
	CharClass.WARRIOR: "Warrior", CharClass.PALADIN: "Paladin", CharClass.HUNTER: "Hunter",
	CharClass.ROGUE: "Rogue", CharClass.PRIEST: "Priest", CharClass.SHAMAN: "Shaman",
	CharClass.MAGE: "Mage", CharClass.WARLOCK: "Warlock", CharClass.DRUID: "Druid",
}
const RACE_NAMES := {
	Race.HUMAN: "Human", Race.ORC: "Orc", Race.DWARF: "Dwarf", Race.NIGHT_ELF: "Wood Elf",
	Race.UNDEAD: "Undead", Race.TAUREN: "Hornkin", Race.GNOME: "Gnome", Race.TROLL: "Troll",
}
const STAT_NAMES := ["Strength", "Agility", "Stamina", "Intellect", "Spirit"]

static var _tables: Dictionary
static var _characters: Dictionary


static func base_stats(race: Race, char_class: CharClass, level: int) -> Array:
	return _get_tables().level_stats["%d-%d" % [race, char_class]][_index(level)]


static func base_health(char_class: CharClass, level: int) -> int:
	return int(_get_tables().class_stats[str(char_class)][_index(level)][0])


static func base_mana(char_class: CharClass, level: int) -> int:
	return int(_get_tables().class_stats[str(char_class)][_index(level)][1])


## XP needed to go from this level to the next. Zero at the level cap.
static func xp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(_get_tables().xp_to_next[level - 1])


static func _index(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL) - 1


## Whether classic allows this race and class together (Human Paladin yes,
## Orc Paladin no). Every allowed pair has base stats in player_levelstats.
static func is_allowed(race: Race, char_class: CharClass) -> bool:
	return _get_tables().level_stats.has("%d-%d" % [race, char_class])


## A new character's items ([[id, count], ...]) and proficiencies
## ("item class:subclass") for this race and class.
static func starting_kit(race: Race, char_class: CharClass) -> Dictionary:
	if _characters.is_empty():
		_characters = JSON.parse_string(FileAccess.get_file_as_string(CHARACTERS_PATH))
	return _characters.get("%d-%d" % [race, char_class], { "items": [], "proficiencies": [] })


static func _get_tables() -> Dictionary:
	if _tables.is_empty():
		_tables = JSON.parse_string(FileAccess.get_file_as_string(TABLES_PATH))
	return _tables
