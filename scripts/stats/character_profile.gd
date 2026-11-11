class_name CharacterProfile
extends Node
## Who a player character is: name, race, class, level, XP, gear and spells.
## GameState extends it for the player; each playerbot has its own. Stats,
## spells and levelling read a unit's profile, so bots follow the same rules.

var char_name := ""
var race := ClassicData.Race.HUMAN
var char_class := ClassicData.CharClass.PALADIN
var level := 1
var xp := 0
## Weapon and armor types the character can use, as "class:subclass" keys.
var proficiencies: Array[String] = []
## How the character looks (HumanoidModel: body, skin, hair, hair_color,
## face); empty for a random look from the name.
var appearance: Dictionary = {}
## Inventory.Slot -> item stack.
var equipment: Dictionary = {}
## Spell ids the character knows, every rank included.
var known_spells: Array[int] = []
## Talent id (as a string, as JSON keeps it) -> points spent in it. See Talents.
var talents: Dictionary = {}


## The highest rank of a known spell, by name, or 0.
func best_rank(spell_name: String) -> int:
	var best := 0
	for id in known_spells:
		var spell := SpellDB.get_spell(id)
		if spell.get("SpellName") == spell_name and (best == 0 or int(spell.SpellLevel) > int(SpellDB.get_spell(best).SpellLevel)):
			best = id
	return best
