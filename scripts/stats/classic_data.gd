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

## The game's own class names; the enum keeps classic's.
const CLASS_NAMES := {
	CharClass.WARRIOR: "Man-at-Arms", CharClass.PALADIN: "Templar", CharClass.HUNTER: "Ranger",
	CharClass.ROGUE: "Cutpurse", CharClass.PRIEST: "Cleric", CharClass.SHAMAN: "Seer",
	CharClass.MAGE: "Magus", CharClass.WARLOCK: "Hexer", CharClass.DRUID: "Wildwarden",
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


# Factions, following FactionTemplateEntry in CMaNGOS (DBCStructure.h). Creature
# reputation isn't kept, so this is the plain template-to-template reaction.

const FACTIONS_PATH := "res://data/classic/factions.json"
## CMaNGOS CREATURE_EXTRA_FLAG_NO_AGGRO_ON_SIGHT: hostile, but only fights back.
const EXTRA_FLAG_NO_AGGRO_ON_SIGHT := 0x2

enum Reaction { HOSTILE, NEUTRAL, FRIENDLY }

static var _factions: Dictionary


## How a creature's faction template regards a player of this race.
static func creature_reaction(creature_faction: int, race: Race) -> Reaction:
	var creature := _template(creature_faction)
	var player := _template(int(_get_factions().races.get(str(race), 1)))
	if _is_hostile(creature, player):
		return Reaction.HOSTILE
	if _is_friendly(creature, player):
		return Reaction.FRIENDLY
	return Reaction.NEUTRAL


## Whether a creature attacks players of this race on sight. Only creatures
## hostile to them do, and not those flagged to wait until attacked.
static func aggressive(creature: Dictionary, race: Race) -> bool:
	if int(creature.get("ExtraFlags", 0)) & EXTRA_FLAG_NO_AGGRO_ON_SIGHT:
		return false
	return creature_reaction(int(creature.get("Faction", 0)), race) == Reaction.HOSTILE


## FactionTemplateEntry::IsHostileTo: named enemies and friends first, then
## the enemy group mask against the other's group.
static func _is_hostile(this: Dictionary, other: Dictionary) -> bool:
	if int(other.faction) > 0:
		if int(other.faction) in this.enemies:
			return true
		if int(other.faction) in this.friends:
			return false
	return int(this.enemy_group) & int(other.group) != 0


## FactionTemplateEntry::IsFriendlyTo.
static func _is_friendly(this: Dictionary, other: Dictionary) -> bool:
	if int(other.faction) > 0:
		if int(other.faction) in this.enemies:
			return false
		if int(other.faction) in this.friends:
			return true
	return int(this.friend_group) & int(other.group) != 0 or int(this.group) & int(other.friend_group) != 0


static func _template(id: int) -> Dictionary:
	return _get_factions().templates.get(str(id), { "faction": 0, "group": 0, "friend_group": 0, "enemy_group": 0, "enemies": [], "friends": [] })


static func _get_factions() -> Dictionary:
	if _factions.is_empty():
		_factions = JSON.parse_string(FileAccess.get_file_as_string(FACTIONS_PATH))
	return _factions
