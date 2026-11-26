class_name Crafting
extends RefCounted
## Making things with a recipe (Smelting a bar, an Enchanting rod or oil), as
## classic's SPELL_EFFECT_CREATE_ITEM recipes: the reagents in your bags,
## the tools (Totem1-2) carried, the spell focus near (a forge for
## Smelting), room for what it makes; a cast of the recipe's spell; then the
## reagents are used up, the item made (its count from the spell), and the
## skill may rise (Player::UpdateCraftSkill by the recipe's levels).

## SPELL_EFFECT_TRADE_SKILL: Smelting's and Enchanting's spells open the
## trade skill window.
static var EFFECT_TRADE_SKILL := 47


## How many of a recipe the bags' reagents make.
static func can_make(_unit: PlayerUnit, id: int) -> int:
	var recipe := ProfessionDB.recipe(id)
	var most := 999
	for pair: Array in recipe.get("reagents", []):
		most = mini(most, Inventory.count_item(int(pair[0])) / maxi(int(pair[1]), 1))
	return 0 if most == 999 else most


## Why the player can't make a recipe now, or "". An enchant needs the
## item it goes on (`target`, an inventory ref).
static func problem(unit: PlayerUnit, id: int, target := {}) -> String:
	var recipe := ProfessionDB.recipe(id)
	if recipe.is_empty() or not id in unit.profile.known_spells:
		return "You don't know that recipe."
	var focus := int(recipe.get("focus", 0))
	if focus != 0 and (World.current == null or not World.current.spell_focus_near(focus, unit.global_position)):
		return "Requires %s" % str(ProfessionDesigns.FOCUS.get(focus, "forge")).capitalize()
	for tool: Variant in recipe.get("tools", []):
		if Inventory.count_item(int(tool)) == 0:
			return "Requires %s" % str(ItemDB.get_item(int(tool)).get("name", "a tool"))
	for pair: Array in recipe.get("reagents", []):
		if Inventory.count_item(int(pair[0])) < int(pair[1]):
			return "Missing reagent: %s" % str(ItemDB.get_item(int(pair[0])).get("name", "?"))
	var makes: Array = recipe.get("makes", [])
	if not makes.is_empty() and not Inventory.has_room_for_all([[int(makes[0]), int(makes[1])]]):
		return "Inventory is full."
	# Last, the item an enchant goes on.
	if recipe.has("enchant"):
		return Enchanting.enchant_problem(id, target)
	return ""


## Casts a recipe (an enchant on the item at `target`); `after` is called
## once it's made. Returns a problem or "".
static func start(unit: PlayerUnit, id: int, after: Callable, target := {}) -> String:
	var why := problem(unit, id, target)
	if not why.is_empty():
		return why
	var caster: SpellCaster = unit.get_node("SpellCaster")
	return caster.cast_action(SpellDB.get_spell(id), func() -> void:
		if finish(unit, id, target):
			after.call())


## The cast is done: reagents used, the item made, the skill raised maybe.
static func finish(unit: PlayerUnit, id: int, target := {}) -> bool:
	var why := problem(unit, id, target)
	if not why.is_empty():
		Chat.system(why)
		return false
	var recipe := ProfessionDB.recipe(id)
	for pair: Array in recipe.get("reagents", []):
		Inventory.remove_items(int(pair[0]), int(pair[1]))
	if recipe.has("enchant"):
		var item := ItemDB.get_item(int(Inventory.stack_at(target).id))
		Enchanting.apply(target, int(recipe.enchant))
		Chat.system("%s is enchanted: %s." % [item.get("name", "?"), Enchanting.line(int(recipe.enchant))])
	var makes: Array = recipe.get("makes", [])
	if not makes.is_empty():
		GameState.add_item(int(makes[0]), int(makes[1]))
		var item := ItemDB.get_item(int(makes[0]))
		var count := " x%d" % int(makes[1]) if int(makes[1]) > 1 else ""
		Chat.add("loot", "You create: [%s]%s." % [item.get("name", "?"), count], "", 0, "", { str(item.get("name", "")): "item:%d" % int(makes[0]) })
	var name := str(recipe.profession)
	var chance := Professions.craft_chance(Professions.pure_value(unit.profile, name), recipe)
	if Professions.try_raise(unit.profile, name, chance):
		Chat.system("Your skill in %s has increased to %d." % [Professions.title(name), Professions.value(unit.profile, name)])
		Sfx.play("level_up")
	GameState.inventory_changed.emit()
	return true
