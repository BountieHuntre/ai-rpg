class_name BotGear
extends RefCounted
## Putting equipment on a party bot and taking it off, by the bag and
## equipment rules the player has (Inventory): its level, class and
## proficiencies, slots for the item's type, two-handers and the off hand,
## Two-Weapon Fighting. What it takes off goes in its BotBag. Used by the bot
## bag window (BotBagWindow).

const ERR_BAG_FULL := "%s's bags are full."


## The equipment slots an item can go in for this character.
static func slots_for(item: Dictionary, who: CharacterProfile) -> Array:
	var slots: Array = Inventory.SLOTS_FOR_TYPE.get(int(item.get("InventoryType", 0)), []).duplicate()
	if int(item.get("InventoryType", 0)) == Inventory.INVTYPE_WEAPON and Inventory.DUAL_WIELD_SPELL in who.known_spells:
		slots.append(Inventory.Slot.OFF_HAND)
	return slots


## Why this character can't wear the item, or "".
static func why_not(item: Dictionary, who: CharacterProfile) -> String:
	if slots_for(item, who).is_empty():
		return "That can't be equipped."
	if int(item.RequiredLevel) > who.level:
		return "%s must reach level %d to use that." % [who.char_name, int(item.RequiredLevel)]
	var class_mask := int(item.AllowableClass)
	if class_mask > 0 and (class_mask & (1 << (who.char_class - 1))) == 0:
		return "%s can never use that." % who.char_name
	if not BestGear._can_use(item, who):
		return "%s doesn't have the proficiency for that." % who.char_name
	return ""


## Puts a stack (one item) on the bot, in `slot` if given (-1 picks one).
## What it replaces goes in its bag. Returns an error, or "".
static func equip(bot: Bot, stack: Dictionary, slot := -1) -> String:
	var who := bot.profile
	var item := ItemDB.get_item(int(stack.id))
	var problem := why_not(item, who)
	if not problem.is_empty():
		return problem
	var slots := slots_for(item, who)
	if slot >= 0 and not slot in slots:
		return Inventory.ERR_WRONG_SLOT
	if slot < 0:
		slot = slots[0]
		for each: int in slots:
			if who.equipment.get(each, {}).is_empty():
				slot = each
				break
	var main: Dictionary = who.equipment.get(Inventory.Slot.MAIN_HAND, {})
	if slot == Inventory.Slot.OFF_HAND and Inventory.is_two_hander(main):
		return Inventory.ERR_TWO_HANDED
	# What comes off: the slot's item, and the off hand for a two-hander.
	var off: Array[Dictionary] = []
	if not who.equipment.get(slot, {}).is_empty():
		off.append(who.equipment[slot])
	var two_hander := slot == Inventory.Slot.MAIN_HAND and Inventory.is_two_hander(stack)
	if two_hander and not who.equipment.get(Inventory.Slot.OFF_HAND, {}).is_empty():
		off.append(who.equipment[Inventory.Slot.OFF_HAND])
	if off.size() > BotBag.MAX_STACKS - bot.bag.stacks.size():
		return ERR_BAG_FULL % who.char_name
	for taken in off:
		bot.bag.add(int(taken.id), maxi(int(taken.get("count", 1)), 1), bool(taken.get("bound", false)))
	if two_hander:
		who.equipment.erase(Inventory.Slot.OFF_HAND)
	var worn := stack.duplicate()
	worn.count = 1
	Inventory._bind_on_equip(worn)
	who.equipment[slot] = worn
	bot.stats.refresh()
	return ""


## Takes off what's in a slot, into its bag. Returns an error, or "".
static func unequip(bot: Bot, slot: int) -> String:
	var worn: Dictionary = bot.profile.equipment.get(slot, {})
	if worn.is_empty():
		return ""
	if not bot.bag.has_room(int(worn.id), 1, bool(worn.get("bound", false))):
		return ERR_BAG_FULL % bot.profile.char_name
	bot.profile.equipment.erase(slot)
	bot.bag.add(int(worn.id), 1, bool(worn.get("bound", false)))
	bot.stats.refresh()
	return ""
