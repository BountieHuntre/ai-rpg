@tool
class_name IconMaps
extends Resource
## Which painted icon things show (data/icons.tres, read by Icons): icon keys
## are the names of the PNGs in assets/icons/ (painted by
## tools/icons/icon_painter.gd; bake new ones with tools/icons/bake_icons.gd).
## Word lists are tried in order, the first word found winning, so put a
## longer phrase before a shorter one it holds ("healing potion" before
## "potion"); a new entry goes last. Saved while the game runs (editor and
## debug runs), the interface is drawn again with them.

const PATH := "res://data/icons.tres"

## Spells by their exact name (class spells, and the creatures' spells and
## debuffs). Spells not named here go by family ("Boon of", "Oath of", "...
## Stance"), then talent_words, then their school.
@export var spell_icons: Dictionary[String, String] = {}
## Weapon skill spells by name (Swords, Bows...).
@export var weapon_skill_icons: Dictionary[String, String] = {}
## Words in a talent's or passive's name (tried in order).
@export var talent_words: Array[IconWord] = []
## Words in an item's name, lower case (tried in order), for items that
## aren't weapons, armour or bags.
@export var item_words: Array[IconWord] = []
## Words in a creature's name and its unit frame portrait (tried in order),
## before its kind (beast, undead).
@export var creature_portraits: Array[IconWord] = []

static var _current: IconMaps


## The maps in play.
static func current() -> IconMaps:
	if not _current:
		_current = ResourceLoader.load(PATH) as IconMaps
		if not _current:
			_current = IconMaps.new()
	return _current


## The icon of the first entry whose word `text` holds, or "".
static func first_match(entries: Array[IconWord], text: String) -> String:
	for entry in entries:
		if text.contains(entry.word):
			return entry.icon
	return ""


## Reads the file again from disk (ContentWatch).
static func reload_file() -> void:
	_current = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as IconMaps
