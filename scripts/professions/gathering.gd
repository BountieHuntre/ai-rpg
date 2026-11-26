class_name Gathering
extends RefCounted
## Gathering a herb or ore node (GatherNode), as classic's Spell::EffectOpenLock
## with a Lock needing Herbalism or Mining: the profession at the node's
## skill (counting racial bonuses), its tool in the bags (a Mining Pick), and
## within reach; a cast of the profession's rank spell (Herb Gathering,
## Mining); then the node opens, and the skill may rise
## (Player::UpdateGatherSkill, with the pure skill).

## Classic INTERACTION_DISTANCE, in yards.
static var REACH := 5.0


## Why `unit` can't gather `node` now, or "".
static func problem(unit: PlayerUnit, node: GatherNode) -> String:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return "That's gone."
	var profile := unit.profile
	var name := node.profession()
	if not Professions.knows(profile, name):
		return "Requires %s" % Professions.title(name)
	if Professions.value(profile, name) < node.skill_needed():
		return "Requires %s %d" % [Professions.title(name), node.skill_needed()]
	# Tools (the player's; bots carry theirs, as their gear isn't in the bags).
	if profile == GameState:
		for tool: Variant in ProfessionDB.profession(name).get("tools", []):
			if Inventory.count_item(int(tool)) == 0:
				return "Requires %s" % str(ItemDB.get_item(int(tool)).get("name", "a tool"))
	if unit.global_position.distance_to(node.global_position) > REACH:
		return "You are too far away."
	return ""


## The rank spell a profession casts to gather (its highest known rank).
static func gather_spell(profile: CharacterProfile, name: String) -> Dictionary:
	var rank := Professions.rank_of(profile, name)
	var ranks := Professions.ranks(name)
	return SpellDB.get_spell(int(ranks[rank - 1].spell)) if rank > 0 else {}


## Starts gathering: a cast, after which `opened` is called with the node
## (if it still holds anything). Returns a problem, or "".
static func start(unit: PlayerUnit, node: GatherNode, opened: Callable) -> String:
	var why := problem(unit, node)
	if not why.is_empty():
		return why
	var spell := gather_spell(unit.profile, node.profession())
	var caster: SpellCaster = unit.get_node("SpellCaster")
	return caster.cast_action(spell, func() -> void:
		if finish(unit, node):
			opened.call(node))


## The cast is done: the node opens, and the skill may rise. True when it
## holds something to take.
static func finish(unit: PlayerUnit, node: GatherNode) -> bool:
	if not problem(unit, node).is_empty():
		return false
	var name := node.profession()
	var chance := Professions.gather_chance(Professions.pure_value(unit.profile, name), node.skill_needed())
	if Professions.try_raise(unit.profile, name, chance) and unit.profile == GameState:
		Chat.system("Your skill in %s has increased to %d." % [Professions.title(name), Professions.value(unit.profile, name)])
		Sfx.play("level_up")
	return node.open()
