class_name BotProfessions
extends RefCounted
## A playerbot's professions: which two it takes (by class, the same each
## time for a name), keeping its ranks, skill and trainer recipes up as it
## levels (as its spells: a player who kept up with their trainers), and what
## it does with them out of combat: gathering herbs and ore near it (a party
## bot only near the player), skinning corpses, smelting at forges it passes,
## disenchanting the greens in its bag and enchanting its own gear. What it
## gets goes in its BotBag, so its trade chat sells it. The rules are the
## player's (Gathering, Skinning, Professions), its tools taken as carried.

## How far a bot on its own looks for a node or corpse, in yards.
static var SEARCH := 50.0
## How far from the player a party bot looks.
static var PARTY_SEARCH := 18.0
## A random bot leaves nodes within this of the player that the player can
## gather (as it leaves what the player's quests need).
static var PLAYER_CLAIM := 40.0
## How often it looks around, and what it may make, in seconds.
static var CHECK_EVERY := 2.0
## Professions take up from this level (Apprentice's).
static var FIRST_LEVEL := 5
## Its kept-up skill: this much a level, as a player who kept at it.
static var SKILL_PER_LEVEL := 5
## The quality it disenchants (greens: blues and better it keeps to trade).
static var DISENCHANT_QUALITY := 2

var bot: Bot
var node: GatherNode
var corpse: Enemy
var _check_left := 0.0
## A craft underway ({ "id", "kind": "make" | "disenchant" | "enchant", ... }).
var _making := {}
var _kills_seen := 0


## The two professions a bot takes: casters often Enchanting with Herbalism,
## Rangers Skinning, fighters the gathering ones; the same for the same name.
static func choose(profile: CharacterProfile) -> Array:
	var options: Array
	match profile.char_class:
		ClassicData.CharClass.PRIEST, ClassicData.CharClass.MAGE, ClassicData.CharClass.WARLOCK:
			options = [["enchanting", "herbalism"], ["enchanting", "herbalism"], ["herbalism", "mining"], ["herbalism", "skinning"]]
		ClassicData.CharClass.HUNTER:
			options = [["skinning", "herbalism"], ["skinning", "mining"], ["skinning", "herbalism"], ["mining", "herbalism"]]
		_:
			options = [["mining", "skinning"], ["herbalism", "skinning"], ["mining", "herbalism"], ["mining", "enchanting"]]
	return options[absi(hash(profile.char_name + ":professions")) % options.size()]


## Keeps its professions up for its level: takes them up at FIRST_LEVEL, its
## skill at least SKILL_PER_LEVEL a level (up to its rank's cap), each rank as
## soon as it qualifies, and its trainers' recipes up to its skill. Run after
## Bot.learn_spells, which starts its spells afresh, so the rank and recipe
## spells are put back.
static func keep_up(profile: CharacterProfile) -> void:
	# Ones it had (the roster's), their rank spells back.
	for name: String in Professions.known(profile):
		var have := _rank_for(name, int(profile.professions[name].max))
		if have > 0 and Professions.rank_of(profile, name) < have:
			Professions.learn_rank(profile, name, have)
	if profile.level < FIRST_LEVEL:
		_learn_recipes(profile)
		return
	for name: String in choose(profile):
		if not Professions.knows(profile, name) and Professions.known(profile).size() >= Professions.MAX_PRIMARY:
			continue
		while true:
			if Professions.knows(profile, name):
				var entry: Dictionary = profile.professions[name]
				entry.value = maxi(int(entry.value), mini(profile.level * SKILL_PER_LEVEL, int(entry.max)))
			var next := Professions.rank_of(profile, name) + 1
			if next > Professions.ranks(name).size() or not Professions.rank_problem(profile, name, next).is_empty():
				break
			Professions.learn_rank(profile, name, next)
	_learn_recipes(profile)


## The rank whose cap is `cap`, for a saved profession.
static func _rank_for(name: String, cap: int) -> int:
	var all := Professions.ranks(name)
	for i in range(all.size() - 1, -1, -1):
		if int(all[i].max) <= cap:
			return i + 1
	return 1 if not all.is_empty() else 0


## The recipes its professions' trainers teach up to its skill.
static func _learn_recipes(profile: CharacterProfile) -> void:
	var ids: Array[int] = []
	for name: String in Professions.known(profile):
		var skill := Professions.pure_value(profile, name)
		for entry: Dictionary in SpellDB.trainer_list(name):
			if int(entry.get("skill", 0)) > skill or int(entry.get("level", 0)) > profile.level:
				continue
			for id: Variant in entry.spells:
				if Professions.is_recipe(int(id)) and not int(id) in profile.known_spells:
					ids.append(int(id))
	Professions.learn_spells(profile, ids)


## Out of combat: works its professions. True while it's busy with them
## (walking to a node or corpse, casting), so it does nothing else.
func step(in_party: bool) -> bool:
	if bot.profile.professions.is_empty():
		return false
	if not bot.spells.casting.is_empty():
		return true
	# A kill of its own: a corpse to skin, so it looks at once.
	if bot.kills != _kills_seen:
		_kills_seen = bot.kills
		_check_left = 0.0
	_check_left -= Bot.THINK_INTERVAL
	if _check_left <= 0.0:
		_check_left = CHECK_EVERY
		_look_around(in_party)
	# Something to make here (cheap to check, so every think, as it passes a
	# forge): it stops, then casts; far off it's made at once.
	if _making.is_empty() and (_check_left == CHECK_EVERY or _at_forge()):
		_making = _what_to_make()
	if not _making.is_empty():
		bot._has_destination = false
		var making := _making
		if bot._far:
			_making = {}
			(making.done as Callable).call()
			return true
		if bot.is_moving():
			return true
		_making = {}
		if _cast(int(making.spell), making.done):
			return true
	if corpse != null and _skin_step():
		return true
	if node != null and _gather_step():
		return true
	return false


## Drops what it was after (it died, or the fight took it elsewhere).
func forget() -> void:
	_release()
	node = null
	corpse = null
	_making = {}


func _release() -> void:
	if is_instance_valid(node) and node.has_meta("bot") and node.get_meta("bot") == bot:
		node.remove_meta("bot")


# Finding something to do.

func _look_around(in_party: bool) -> void:
	var center := bot.global_position
	var radius := SEARCH
	var player := bot._leader()
	if in_party:
		if player == null:
			return
		center = player.global_position
		radius = PARTY_SEARCH
	if not _valid_corpse(corpse):
		corpse = _find_corpse(center, radius, in_party, player)
	if not _valid_node(node):
		_release()
		node = _find_node(center, radius, in_party, player)
		if node:
			node.set_meta("bot", bot)


## (Untyped: what it was after may have been freed, gathered by someone else.)
func _valid_node(candidate: Variant) -> bool:
	return is_instance_valid(candidate) and (candidate as GatherNode).is_inside_tree() and not (candidate as GatherNode).is_queued_for_deletion()


func _valid_corpse(candidate: Variant) -> bool:
	return is_instance_valid(candidate) and (candidate as Enemy).skinnable()


## The nearest node it has the skill for, that no other bot is after and,
## for a bot on its own, that the player near it couldn't gather instead.
func _find_node(center: Vector3, radius: float, in_party: bool, player: Player) -> GatherNode:
	var profile := bot.profile
	var best: GatherNode = null
	var best_distance := radius
	for candidate: Node in bot.get_tree().get_nodes_in_group("gather_nodes"):
		var gather := candidate as GatherNode
		var distance := center.distance_to(gather.global_position)
		if distance >= best_distance or not _valid_node(gather):
			continue
		var name := gather.profession()
		if not Professions.knows(profile, name) or Professions.value(profile, name) < gather.skill_needed():
			continue
		var claim: Variant = gather.get_meta("bot") if gather.has_meta("bot") else null
		if claim != null and claim != bot and is_instance_valid(claim) and (claim as Bot).professions.node == gather:
			continue
		if not in_party and player and _players(player, name, gather.skill_needed(), gather.global_position):
			continue
		if bot.manager and not bot.manager.reachable(bot.global_position, gather.global_position):
			continue
		best = gather
		best_distance = distance
	return best


## A skinnable corpse near: its own kill on its own; in a party, one the
## player can't skin themselves.
func _find_corpse(center: Vector3, radius: float, in_party: bool, player: Player) -> Enemy:
	var profile := bot.profile
	if not Professions.knows(profile, "skinning"):
		return null
	var skill := Professions.value(profile, "skinning")
	var best: Enemy = null
	var best_distance := radius
	var creatures: Array = bot.manager.creatures_near(center, radius) if bot.manager else bot.get_tree().get_nodes_in_group("enemies")
	for candidate: Variant in creatures:
		var enemy := candidate as Enemy
		if enemy == null or not enemy.skinnable() or skill < Skinning.needed(enemy.level, skill):
			continue
		var distance := center.distance_to(enemy.global_position)
		if distance >= best_distance:
			continue
		if in_party:
			if player and _players(player, "skinning", Skinning.needed(enemy.level, Professions.value(player.profile, "skinning")), enemy.global_position):
				continue
		elif enemy.tapped_by != bot.combatant:
			continue
		best = enemy
		best_distance = distance
	return best


## Whether the player near `at` could take it themselves.
func _players(player: Player, name: String, needed: int, at: Vector3) -> bool:
	return player.global_position.distance_to(at) <= PLAYER_CLAIM and Professions.knows(player.profile, name) \
		and Professions.value(player.profile, name) >= needed


# Gathering and skinning.

func _gather_step() -> bool:
	if not _valid_node(node):
		node = null
		return false
	if bot.global_position.distance_to(node.global_position) > Gathering.REACH - 1.5:
		bot._go_to(node.global_position)
		return true
	bot._has_destination = false
	# Far off, it takes the node at once (no cast to tick).
	if bot._far:
		if Gathering.finish(bot, node):
			_take_node(node)
		node = null
		return true
	if bot.is_moving():
		return true
	var target := node
	var why := Gathering.start(bot, target, func(opened: GatherNode) -> void: _take_node(opened))
	if not why.is_empty() and why != SpellCaster.ERR_MOVING:
		_release()
		node = null
	return true


func _take_node(gathered: GatherNode) -> void:
	for drop: Dictionary in gathered.take_all():
		if BotBag.can_trade(int(drop.id)):
			bot.bag.add(int(drop.id), int(drop.count))
	if node == gathered:
		node = null


func _skin_step() -> bool:
	if not _valid_corpse(corpse):
		corpse = null
		return false
	if bot.global_position.distance_to(corpse.global_position) > Skinning.REACH - 1.5:
		bot._go_to(corpse.global_position)
		return true
	bot._has_destination = false
	if bot._far:
		if Skinning.finish(bot, corpse):
			_take_skin(corpse)
		corpse = null
		return true
	if bot.is_moving():
		return true
	var why := Skinning.start(bot, corpse, func(skinned: Enemy) -> void: _take_skin(skinned))
	if not why.is_empty() and why != SpellCaster.ERR_MOVING:
		corpse = null
	return true


func _take_skin(skinned: Enemy) -> void:
	for drop: Dictionary in skinned.loot:
		if BotBag.can_trade(int(drop.id)):
			bot.bag.add(int(drop.id), int(drop.count))
	skinned.loot.clear()
	skinned._check_skinned_empty()
	if corpse == skinned:
		corpse = null


# Making things.

## Beside a forge with Mining (where smelting is checked every think).
func _at_forge() -> bool:
	return Professions.knows(bot.profile, "mining") and bot.manager != null 		and bot.manager._world.spell_focus_near(World.FORGE_FOCUS, bot.global_position)


## What it can make now, one at a time, each a cast: smelting at a forge
## it's beside, disenchanting a green, or enchanting its own gear, as
## { "spell", "done" }, or {}.
func _what_to_make() -> Dictionary:
	if bot.combatant.is_in_combat():
		return {}
	var profile := bot.profile
	if Professions.knows(profile, "mining") and bot.manager and bot.manager._world.spell_focus_near(World.FORGE_FOCUS, bot.global_position):
		for id: int in _known_recipes("mining"):
			var recipe := ProfessionDB.recipe(id)
			if recipe.has("makes") and _has_reagents(recipe):
				return { "spell": id, "done": func() -> void: _made(id, recipe) }
	if Professions.knows(profile, "enchanting"):
		var green := _green_to_disenchant()
		var disenchant := _disenchant_spell()
		if green > 0 and disenchant > 0:
			return { "spell": disenchant, "done": func() -> void: _disenchanted(green) }
		for id: int in _known_recipes("enchanting"):
			var recipe := ProfessionDB.recipe(id)
			if not recipe.has("enchant") or bool(recipe.get("temporary", false)) or not _has_reagents(recipe):
				continue
			var slot := _slot_for(id)
			if slot >= 0:
				return { "spell": id, "done": func() -> void: _enchanted(id, recipe, slot) }
	return {}


## Its recipes of a profession, the hardest first.
func _known_recipes(name: String) -> Array[int]:
	var ids: Array[int] = []
	for id: int in bot.profile.known_spells:
		var recipe := ProfessionDB.recipe(id)
		if str(recipe.get("profession", "")) == name:
			ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool: return int(ProfessionDB.recipe(a).skill) > int(ProfessionDB.recipe(b).skill))
	return ids


func _has_reagents(recipe: Dictionary) -> bool:
	for reagent: Array in recipe.get("reagents", []):
		if bot.bag.count_of(int(reagent[0])) < int(reagent[1]):
			return false
	return not recipe.get("reagents", []).is_empty()


func _use_reagents(recipe: Dictionary) -> bool:
	if not _has_reagents(recipe):
		return false
	for reagent: Array in recipe.reagents:
		bot.bag.remove(int(reagent[0]), int(reagent[1]))
	return true


func _cast(spell_id: int, done: Callable) -> bool:
	return bot.spells.cast_action(SpellDB.get_spell(spell_id), done).is_empty()


## A craft done: the skill may rise as the player's does.
func _skill_up(recipe: Dictionary) -> void:
	var name := str(recipe.profession)
	Professions.try_raise(bot.profile, name, Professions.craft_chance(Professions.pure_value(bot.profile, name), recipe))
	_learn_recipes(bot.profile)


func _made(id: int, recipe: Dictionary) -> void:
	if not _use_reagents(recipe):
		return
	var makes: Array = recipe.makes
	bot.bag.add(int(makes[0]), maxi(int(makes[1]), 1))
	_skill_up(recipe)


## A green in its bag it has the skill to disenchant, or 0.
func _green_to_disenchant() -> int:
	var skill := Professions.value(bot.profile, "enchanting")
	for stack: Dictionary in bot.bag.stacks:
		if BotBag.is_bound(stack):
			continue
		var item := ItemDB.get_item(int(stack.id))
		if int(item.get("Quality", 0)) == DISENCHANT_QUALITY and int(item.get("DisenchantID", 0)) > 0 \
				and int(item.get("RequiredDisenchantSkill", 0)) <= skill and int(item.get("RequiredDisenchantSkill", 0)) >= 0 \
				and not ProfessionDB.disenchant_loot(int(item.DisenchantID)).is_empty():
			return int(stack.id)
	return 0


func _disenchant_spell() -> int:
	for id: int in bot.profile.known_spells:
		if SpellDB.has_effect(SpellDB.get_spell(id), Enchanting.EFFECT_DISENCHANT):
			return id
	return 0


func _disenchanted(id: int) -> void:
	if bot.bag.count_of(id) <= 0:
		return
	bot.bag.remove(id, 1)
	for drop: Dictionary in LootTable.roll_entries(ProfessionDB.disenchant_loot(int(ItemDB.get_item(id).DisenchantID))):
		bot.bag.add(int(drop.id), int(drop.count))


## The equipment slot an enchant recipe fits with nothing on it yet, or -1.
func _slot_for(recipe_id: int) -> int:
	var spell := SpellDB.get_spell(recipe_id)
	for slot: int in bot.profile.equipment:
		var stack: Dictionary = bot.profile.equipment[slot]
		if stack.is_empty() or stack.has("enchant"):
			continue
		if Enchanting.fits(spell, ItemDB.get_item(int(stack.id))):
			return slot
	return -1


func _enchanted(id: int, recipe: Dictionary, slot: int) -> void:
	var stack: Dictionary = bot.profile.equipment.get(slot, {})
	if stack.is_empty() or stack.has("enchant") or not _use_reagents(recipe):
		return
	stack.enchant = int(recipe.enchant)
	stack.bound = true
	bot.stats.refresh()
	_skill_up(recipe)
