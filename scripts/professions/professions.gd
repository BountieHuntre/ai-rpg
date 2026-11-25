class_name Professions
extends RefCounted
## Classic 1.12's profession rules, for any CharacterProfile (the player's
## GameState or a bot's): learning a rank (Apprentice, Journeyman, Expert,
## Artisan) from a trainer, at most two primary professions (all four here
## are), unlearning, recipes, and the skill-up chances of CMaNGOS's
## Player::UpdateGatherSkill and UpdateCraftSkill (SkillGainChance, with the
## server's default chances). A profile's `professions` holds each one it
## knows by name: { "value": skill, "max": its rank's cap }. Rank spells and
## recipes go in its known_spells like any spell.

## At most this many primary professions (classic's MaxPrimaryTradeSkill).
const MAX_PRIMARY := 2
## CONFIG_UINT32_SKILL_CHANCE_ORANGE, YELLOW, GREEN, GREY: per mille after x10.
const CHANCE_ORANGE := 100
const CHANCE_YELLOW := 75
const CHANCE_GREEN := 25
const CHANCE_GREY := 0
## Racial skill bonuses (classic's Tauren Cultivation is the Hornkin's):
## race -> { profession: bonus }, added to the skill used, never to the one
## that rises.
const RACIAL_BONUS := { ClassicData.Race.TAUREN: { "herbalism": 15 } }


static func knows(profile: CharacterProfile, name: String) -> bool:
	return profile.professions.has(name)


## The professions a profile knows, in NAMES' order.
static func known(profile: CharacterProfile) -> Array[String]:
	var found: Array[String] = []
	for name: String in ProfessionDB.NAMES:
		if knows(profile, name):
			found.append(name)
	return found


## The skill as it rises (without racial bonuses), or 0.
static func pure_value(profile: CharacterProfile, name: String) -> int:
	return int(profile.professions.get(name, {}).get("value", 0))


## The skill used for what it can gather or make: its value plus any racial
## bonus.
static func value(profile: CharacterProfile, name: String) -> int:
	if not knows(profile, name):
		return 0
	return pure_value(profile, name) + racial_bonus(profile, name)


static func racial_bonus(profile: CharacterProfile, name: String) -> int:
	return int(RACIAL_BONUS.get(profile.race, {}).get(name, 0))


static func max_value(profile: CharacterProfile, name: String) -> int:
	return int(profile.professions.get(name, {}).get("max", 0))


## The profession's rank entries (ProfessionDB), Apprentice first.
static func ranks(name: String) -> Array:
	return ProfessionDB.profession(name).get("ranks", [])


## Which rank of `name` the profile has: 0 for none, 1 Apprentice ... 4 Artisan.
static func rank_of(profile: CharacterProfile, name: String) -> int:
	var all := ranks(name)
	for i in range(all.size() - 1, -1, -1):
		if int(all[i].spell) in profile.known_spells:
			return i + 1
	return 0


static func rank_name(name: String, rank: int) -> String:
	var all := ranks(name)
	return str(all[rank - 1].rank) if rank >= 1 and rank <= all.size() else ""


## The profession and rank (1-4) a spell teaches, or ["", 0].
static func rank_spell(spell_id: int) -> Array:
	for name: String in ProfessionDB.NAMES:
		var all := ranks(name)
		for i in all.size():
			if int(all[i].spell) == spell_id:
				return [name, i + 1]
	return ["", 0]


## The profession a spell belongs to, as a rank, a recipe or a spell learned
## with it (Find Herbs, Disenchant), or "".
static func profession_of_spell(spell_id: int) -> String:
	var as_rank: String = rank_spell(spell_id)[0]
	if as_rank != "":
		return as_rank
	var recipe := ProfessionDB.recipe(spell_id)
	if not recipe.is_empty():
		return str(recipe.profession)
	for name: String in ProfessionDB.NAMES:
		if spell_id in (ProfessionDB.profession(name).get("start", []) as Array).map(func(s: Variant) -> int: return int(s)):
			return name
	return ""


static func is_recipe(spell_id: int) -> bool:
	return not ProfessionDB.recipe(spell_id).is_empty()


## The capitalized name for showing: "Herbalism".
static func title(name: String) -> String:
	return name.capitalize()


## Why the profile can't learn rank `rank` (1-4) of `name` now, or "".
static func rank_problem(profile: CharacterProfile, name: String, rank: int) -> String:
	var all := ranks(name)
	if rank < 1 or rank > all.size():
		return "No such rank"
	var entry: Dictionary = all[rank - 1]
	var have := rank_of(profile, name)
	if have >= rank:
		return "Already known"
	if rank > 1 and have < rank - 1:
		return "Requires %s %s" % [rank_name(name, rank - 1), title(name)]
	if rank == 1 and known(profile).size() >= MAX_PRIMARY:
		return "You can only learn two professions."
	if profile.level < int(entry.level):
		return "Requires Level %d" % int(entry.level)
	if pure_value(profile, name) < int(entry.skill):
		return "Requires %s (%d)" % [title(name), int(entry.skill)]
	return ""


## Learns rank `rank` of `name`, rules aside (the trainer checks them): the
## rank spell replaces the one before, the cap rises, and an Apprentice
## starts at 1 knowing the spells learned with the profession. Returns the
## names of the spells learned, for the chat.
static func learn_rank(profile: CharacterProfile, name: String, rank: int) -> Array[String]:
	var all := ranks(name)
	var learned: Array[String] = []
	if rank < 1 or rank > all.size():
		return learned
	for i in all.size():
		profile.known_spells.erase(int(all[i].spell))
	profile.known_spells.append(int(all[rank - 1].spell))
	var entry: Dictionary = profile.professions.get(name, { "value": 1, "max": 0 })
	entry.value = maxi(int(entry.value), 1)
	entry.max = maxi(int(entry.max), int(all[rank - 1].max))
	profile.professions[name] = entry
	learned.append("%s %s" % [rank_name(name, rank), title(name)])
	var start: Array[int] = []
	for id: Variant in ProfessionDB.profession(name).get("start", []):
		if not int(id) in profile.known_spells:
			start.append(int(id))
	learned.append_array(learn_spells(profile, start))
	_changed(profile)
	return learned


## Teaches spells (recipes, Find Herbs...), the player's through
## SpellCaster.learn so they reach the spellbook and bar as other spells do.
static func learn_spells(profile: CharacterProfile, ids: Array[int]) -> Array[String]:
	if ids.is_empty():
		return []
	if profile == GameState:
		return SpellCaster.learn(ids)
	var learned: Array[String] = []
	for id in ids:
		if not id in profile.known_spells:
			profile.known_spells.append(id)
			learned.append(SpellDB.full_name(SpellDB.get_spell(id)))
	return learned


## Forgets a profession: its skill, its rank, its recipes and the spells
## learned with it, as classic's unlearning does.
static func unlearn(profile: CharacterProfile, name: String) -> void:
	if not knows(profile, name):
		return
	profile.professions.erase(name)
	var gone := {}
	for entry: Dictionary in ranks(name):
		gone[int(entry.spell)] = true
	for id in ProfessionDB.recipes_of(name):
		gone[id] = true
	for id: Variant in ProfessionDB.profession(name).get("start", []):
		gone[int(id)] = true
	var kept: Array[int] = []
	for id in profile.known_spells:
		if not gone.has(id):
			kept.append(id)
	profile.known_spells = kept
	if profile == GameState:
		for i in GameState.action_bar.size():
			if gone.has(GameState.action_bar[i]):
				GameState.action_bar[i] = 0
	_changed(profile)


## Sets a profession's skill (dev tools), raising its cap to fit.
static func set_value(profile: CharacterProfile, name: String, skill: int) -> void:
	if not knows(profile, name):
		return
	var entry: Dictionary = profile.professions[name]
	entry.value = clampi(skill, 1, 300)
	entry.max = maxi(int(entry.max), int(entry.value))
	_changed(profile)


## Raises a profession's skill by `step` up to its cap; true if it rose.
static func raise(profile: CharacterProfile, name: String, step := 1) -> bool:
	if not knows(profile, name):
		return false
	var entry: Dictionary = profile.professions[name]
	if int(entry.value) >= int(entry.max):
		return false
	entry.value = mini(int(entry.value) + step, int(entry.max))
	_changed(profile)
	return true


## CMaNGOS Player::SkillGainChance: the chance (per mille) of a skill-up at
## `skill` for something grey from `grey`, green from `green`, yellow from
## `yellow` and orange below.
static func gain_chance(skill: int, grey: int, green: int, yellow: int) -> int:
	if skill >= grey:
		return CHANCE_GREY * 10
	if skill >= green:
		return CHANCE_GREEN * 10
	if skill >= yellow:
		return CHANCE_YELLOW * 10
	return CHANCE_ORANGE * 10


## UpdateCraftSkill's chance for a recipe: its levels are [orange, yellow,
## green, grey] (SkillLineAbility's yellow and grey, green halfway).
static func craft_chance(skill: int, recipe: Dictionary) -> int:
	var levels: Array = recipe.get("levels", [])
	if levels.size() < 4:
		return 0
	return gain_chance(skill, int(levels[3]), int(levels[2]), int(levels[1]))


## UpdateGatherSkill's chance for a node or corpse needing `needed`: yellow
## 25 over it, green 50, grey 100.
static func gather_chance(skill: int, needed: int) -> int:
	return gain_chance(skill, needed + 100, needed + 50, needed + 25)


## The difficulty colour of gathering at `needed` with `skill` (as the
## chances: orange, yellow, green, grey), or "red" when it can't be done.
static func gather_color(skill: int, needed: int) -> String:
	if skill < needed:
		return "red"
	if skill >= needed + 100:
		return "grey"
	if skill >= needed + 50:
		return "green"
	if skill >= needed + 25:
		return "yellow"
	return "orange"


## A recipe's colour at `skill`: red below what it needs, then orange,
## yellow, green and grey by its levels.
static func recipe_color(skill: int, recipe: Dictionary) -> String:
	var levels: Array = recipe.get("levels", [])
	if skill < int(recipe.get("skill", 1)):
		return "red"
	if levels.size() < 4:
		return "grey"
	if skill >= int(levels[3]):
		return "grey"
	if skill >= int(levels[2]):
		return "green"
	if skill >= int(levels[1]):
		return "yellow"
	return "orange"


## UpdateSkillPro: rolls 1-1000 against the chance and raises the skill
## when it falls within; true when it rose.
static func try_raise(profile: CharacterProfile, name: String, chance: int) -> bool:
	if chance <= 0 or randi_range(1, 1000) > chance:
		return false
	return raise(profile, name)


## Every profession at its rank's cap (dev tools).
static func max_all(profile: CharacterProfile) -> void:
	for name in known(profile):
		set_value(profile, name, max_value(profile, name))


## Every recipe of a profession (dev tools), or of every known one.
static func learn_all_recipes(profile: CharacterProfile, only := "") -> Array[String]:
	var ids: Array[int] = []
	for name in known(profile):
		if only != "" and name != only:
			continue
		for id in ProfessionDB.recipes_of(name):
			if not id in profile.known_spells:
				ids.append(id)
	return learn_spells(profile, ids)


## The profession named by a word the player typed ("herb", "Mining"), or "".
static func find(word: String) -> String:
	var lower := word.to_lower()
	for name: String in ProfessionDB.NAMES:
		if name.begins_with(lower) or lower.begins_with(name):
			return name
	return ""


## A trainer list name that is a profession's.
static func is_trainer(trainer: String) -> bool:
	return trainer in ProfessionDB.NAMES


## Saved professions read back ({ name: { value, max } }).
static func read_saved(saved: Variant) -> Dictionary:
	var out := {}
	if saved is Dictionary:
		for name: String in saved:
			if name in ProfessionDB.NAMES and saved[name] is Dictionary:
				out[name] = { "value": int(saved[name].get("value", 1)), "max": int(saved[name].get("max", 75)) }
	return out


static func _changed(profile: CharacterProfile) -> void:
	if profile == GameState:
		GameState.spells_changed.emit()
		GameState.professions_changed.emit()
