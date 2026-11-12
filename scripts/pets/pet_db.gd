class_name PetDB
extends RefCounted
## The Ranger's pets' data (data/classic/pets.json, from CMaNGOS
## pet_levelstats and pet_familystats and the client's CreatureFamily and
## CreatureSpellData): stats by level, each family's modifiers, size and
## abilities, and the abilities each wild beast knows. Rules from CMaNGOS
## Pet::InitStatsForLevel (HUNTER_PET) and Pet::GivePetXP, without classic's
## happiness and loyalty (unlike classic: training points are what a pet of
## the top loyalty gets, 5 a level).

const PATH := "res://data/classic/pets.json"
## Creature template flag: a Ranger can tame it (CREATURE_TYPEFLAGS_TAMEABLE).
const TAMEABLE := 0x1
## Training points a level: classic's level x (loyalty - 1) at the top
## loyalty, 6.
const TP_PER_LEVEL := 5
## Hunter pets swing every 2 seconds whatever they were (Pet::InitStatsForLevel).
const ATTACK_TIME := 2.0
## Pets' focus: a hundred, coming back 24 every 4 seconds (Pet::Regenerate).
const MAX_FOCUS := 100
const FOCUS_PER_SECOND := 6.0
## Passive abilities (Great Stamina, Natural Armor, the resistances) cost
## this many training points a rank; others 1 at their first rank and 3 more
## for each rank after (as classic's Bite and Claw). The exact costs were in
## 1.12's SkillLineAbility, which the data sources no longer have, so these
## are close to classic, not classic's own.
const PASSIVE_TP_PER_RANK := 5

static var _data: Dictionary


static func _table() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


## [health, armor, Strength, Agility, Stamina, Intellect, Spirit] at a level.
static func level_stats(level: int) -> Array:
	var table: Array = _table().level_stats
	return table[clampi(level, 1, table.size()) - 1]


static func family(family_id: int) -> Dictionary:
	return _table().families.get(str(family_id), {})


static func family_name(family_id: int) -> String:
	return str(family(family_id).get("name", "Beast"))


## Every ability (every rank) a family can learn.
static func family_abilities(family_id: int) -> Array:
	# JSON's numbers are floats: as ints, so `in` finds them.
	return family(family_id).get("abilities", []).map(func(id: Variant) -> int: return int(id))


## Whether a creature can be tamed: flagged tameable, of a pet family.
static func is_tameable(entry: int) -> bool:
	var data := Enemy.creature_data(entry)
	return int(data.get("CreatureTypeFlags", 0)) & TAMEABLE != 0 and not family(int(data.get("Family", 0))).is_empty()


## The abilities a wild beast knows (its PetSpellDataId's spells), which its
## tamer learns to teach: the ones its family can have.
static func creature_abilities(entry: int) -> Array:
	var data := Enemy.creature_data(entry)
	var spells: Array = _table().spell_data.get(str(int(data.get("PetSpellDataId", 0))), [])
	var allowed := family_abilities(int(data.get("Family", 0)))
	return spells.filter(func(id: Variant) -> bool: return int(id) in allowed).map(func(id: Variant) -> int: return int(id))


## XP to the next level: the player's, times PET_XP_FACTOR.
static func xp_to_next(level: int) -> int:
	return maxi(roundi(ClassicData.xp_to_next(level) * float(_table().get("xp_factor", 0.05))), 1)


static func training_points(level: int) -> int:
	return level * TP_PER_LEVEL


## Training points to teach a spell.
static func tp_cost(spell_id: int) -> int:
	var spell := SpellDB.get_spell(spell_id)
	var rank := maxi(SpellDB.rank_of(spell_id), 1)
	if SpellDB.is_passive(spell):
		return PASSIVE_TP_PER_RANK * rank
	return 1 + 3 * (rank - 1)


## A pet's level the spell needs (its SpellLevel).
static func required_level(spell_id: int) -> int:
	return int(SpellDB.get_spell(spell_id).get("SpellLevel", 1))


## A new pet's record from a tamed creature: its entry, name, level,
## family and the abilities it knew.
static func new_record(entry: int, level: int) -> Dictionary:
	var data := Enemy.creature_data(entry)
	var spells := creature_abilities(entry)
	return {
		"entry": entry, "name": str(data.get("Name", "Pet")), "level": level, "xp": 0,
		"family": int(data.get("Family", 0)), "spells": spells, "autocast": spells.filter(func(id: int) -> bool: return not SpellDB.is_passive(SpellDB.get_spell(id))),
		"tp_used": 0, "health": -1, "focus": MAX_FOCUS, "dead": false, "mode": "defensive",
	}
