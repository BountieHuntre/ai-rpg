class_name Inventory
extends RefCounted
## Classic WoW bag and equipment rules, working on the data in GameState.
## Places in the inventory are refs:
##   { "kind": "bag", "bag": container index, "slot": i }  (0 is the backpack)
##   { "kind": "equip", "slot": Inventory.Slot }
##   { "kind": "bag_slot", "index": 0 to 3 }

enum Slot {
	HEAD, NECK, SHOULDER, BACK, CHEST, SHIRT, TABARD, WRIST, HANDS, WAIST, LEGS, FEET,
	FINGER_1, FINGER_2, TRINKET_1, TRINKET_2, MAIN_HAND, OFF_HAND, RANGED,
}
const SLOT_LABELS := {
	Slot.HEAD: "Head", Slot.NECK: "Neck", Slot.SHOULDER: "Shoulder", Slot.BACK: "Back",
	Slot.CHEST: "Chest", Slot.SHIRT: "Shirt", Slot.TABARD: "Tabard", Slot.WRIST: "Wrist",
	Slot.HANDS: "Hands", Slot.WAIST: "Waist", Slot.LEGS: "Legs", Slot.FEET: "Feet",
	Slot.FINGER_1: "Finger", Slot.FINGER_2: "Finger", Slot.TRINKET_1: "Trinket",
	Slot.TRINKET_2: "Trinket", Slot.MAIN_HAND: "Main Hand", Slot.OFF_HAND: "Off Hand",
	Slot.RANGED: "Ranged",
}

const INVTYPE_BAG := 18
const INVTYPE_TWO_HAND := 17
const INVTYPE_ONE_HAND := 13
const INVTYPE_SHIELD := 14
const INVTYPE_WEAPON := 13
const DUAL_WIELD_SPELL := 674
const ARMOR_SUBCLASS_MISC := 0
const ARMOR_SUBCLASS_PLATE := 4
const ARMOR_SUBCLASS_SHIELD := 6

## Equipment slots for each InventoryType. One-handers (13) also go in the off
## hand with Two-Weapon Fighting (classic's Dual Wield, DUAL_WIELD_SPELL).
const SLOTS_FOR_TYPE := {
	1: [Slot.HEAD], 2: [Slot.NECK], 3: [Slot.SHOULDER], 4: [Slot.SHIRT], 5: [Slot.CHEST],
	6: [Slot.WAIST], 7: [Slot.LEGS], 8: [Slot.FEET], 9: [Slot.WRIST], 10: [Slot.HANDS],
	11: [Slot.FINGER_1, Slot.FINGER_2], 12: [Slot.TRINKET_1, Slot.TRINKET_2],
	13: [Slot.MAIN_HAND], 14: [Slot.OFF_HAND], 15: [Slot.RANGED], 16: [Slot.BACK],
	17: [Slot.MAIN_HAND], 19: [Slot.TABARD], 20: [Slot.CHEST], 21: [Slot.MAIN_HAND],
	22: [Slot.OFF_HAND], 23: [Slot.OFF_HAND], 25: [Slot.RANGED], 26: [Slot.RANGED],
}


const ERR_FULL := "Inventory is full."
const ERR_WRONG_SLOT := "That item doesn't go in that slot."
const ERR_LEVEL := "You must reach level %d to use that item."
const ERR_CLASS := "You can never use that item."
const ERR_PROFICIENCY := "You do not have the required proficiency for that item."
const ERR_TWO_HANDED := "Cannot equip that with a two-handed weapon."
const ERR_BAG_NOT_EMPTY := "You can only do that with empty bags."
const ERR_BAG_IN_BAG := "Can't put non-empty bags in other bags."
const ERR_NOT_A_BAG := "That's not a bag."
const ERR_BAG_INTO_ITSELF := "You can't put a bag into itself."

const UNARMED_WEAPON := { "min": 1.0, "max": 2.0, "speed": 2.0 }


## A new character's proficiencies and starting items for their race and
## class. As in Player::Create in CMaNGOS, each item is equipped if it can be
## (bags into bag slots), and goes in the bags otherwise.
static func start_character(state: Node) -> void:
	var kit := ClassicData.starting_kit(state.race, state.char_class)
	state.proficiencies.assign(kit.proficiencies)
	for entry: Array in kit.items:
		var id := int(entry[0])
		var count := int(entry[1])
		if count == 1 and _equip_new(id):
			continue
		add_item(id, count)


static func _equip_new(id: int) -> bool:
	var item := ItemDB.get_item(id)
	if int(item.InventoryType) == INVTYPE_BAG:
		for i in GameState.bags.size():
			if GameState.bags[i].is_empty():
				_set_stack(bag_slot_ref(i), _stack(id, 1, false))
				return true
		return false
	if not can_use(item).is_empty():
		return false
	for slot: Slot in SLOTS_FOR_TYPE.get(int(item.InventoryType), []):
		if GameState.equipment.get(slot, {}).is_empty():
			var stack := _stack(id, 1, false)
			_bind_on_equip(stack)
			GameState.equipment[slot] = stack
			return true
	return false


# Reading.

static func stack_at(ref: Dictionary) -> Dictionary:
	match ref.kind:
		"bag":
			return GameState.containers[ref.bag][ref.slot]
		"equip":
			return GameState.equipment.get(ref.slot, {})
		"bag_slot":
			return GameState.bags[ref.index]
	return {}


static func bag_ref(bag: int, slot: int) -> Dictionary:
	return { "kind": "bag", "bag": bag, "slot": slot }


static func equip_ref(slot: Slot) -> Dictionary:
	return { "kind": "equip", "slot": slot }


static func bag_slot_ref(index: int) -> Dictionary:
	return { "kind": "bag_slot", "index": index }


static func free_slots() -> int:
	var free := 0
	for container: Array in GameState.containers:
		for stack: Dictionary in container:
			if stack.is_empty():
				free += 1
	return free


static func is_two_hander(stack: Dictionary) -> bool:
	return not stack.is_empty() and int(ItemDB.get_item(stack.id).InventoryType) == INVTYPE_TWO_HAND


# Changing.

## Adds items, filling existing stacks first, then empty slots in bag order.
## Returns how many didn't fit.
static func add_item(id: int, count: int, bound := false) -> int:
	var stack_size := maxi(int(ItemDB.get_item(id).get("stackable", 1)), 1)
	for container: Array in GameState.containers:
		for stack: Dictionary in container:
			if count > 0 and not stack.is_empty() and stack.id == id and stack.count < stack_size:
				var moved := mini(stack_size - stack.count, count)
				stack.count += moved
				count -= moved
	for container: Array in GameState.containers:
		for i in container.size():
			if count > 0 and container[i].is_empty():
				var moved := mini(stack_size, count)
				container[i] = _stack(id, moved, bound)
				count -= moved
	GameState.inventory_changed.emit()
	return count


## How many of an item are in the bags.
static func count_item(id: int) -> int:
	var total := 0
	for container: Array in GameState.containers:
		for stack: Dictionary in container:
			if not stack.is_empty() and stack.id == id:
				total += int(stack.count)
	return total


## Takes up to `count` of an item out of the bags, last stacks first.
static func remove_items(id: int, count: int) -> void:
	for b in range(GameState.containers.size() - 1, -1, -1):
		var container: Array = GameState.containers[b]
		for i in range(container.size() - 1, -1, -1):
			var stack: Dictionary = container[i]
			if count > 0 and not stack.is_empty() and stack.id == id:
				var taken := mini(int(stack.count), count)
				stack.count -= taken
				count -= taken
				if stack.count <= 0:
					container[i] = {}
	GameState.inventory_changed.emit()


## Whether these [[id, count], ...] would all fit in the bags together.
static func has_room_for_all(items: Array) -> bool:
	var free := free_slots()
	var needed := 0
	for entry: Array in items:
		var id := int(entry[0])
		var count := int(entry[1])
		var stack_size := maxi(int(ItemDB.get_item(id).get("stackable", 1)), 1)
		# Room on existing stacks first.
		for container: Array in GameState.containers:
			for stack: Dictionary in container:
				if not stack.is_empty() and stack.id == id:
					count -= maxi(stack_size - int(stack.count), 0)
		if count > 0:
			needed += ceili(float(count) / stack_size)
	return needed <= free


## Right-click "use" on a bag slot: equips gear into its slot (a free one if
## there's a choice) and puts bags into the first empty bag slot.
static func use_from_bag(ref: Dictionary) -> String:
	var stack := stack_at(ref)
	if stack.is_empty():
		return ""
	var item := ItemDB.get_item(stack.id)
	if int(item.InventoryType) == INVTYPE_BAG:
		for i in GameState.BAG_SLOTS:
			if GameState.bags[i].is_empty():
				return move(ref, bag_slot_ref(i))
		return move(ref, bag_slot_ref(0))
	var slots: Array = SLOTS_FOR_TYPE.get(int(item.InventoryType), [])
	if slots.is_empty():
		return ""
	for slot: Slot in slots:
		if GameState.equipment.get(slot, {}).is_empty():
			return move(ref, equip_ref(slot))
	return move(ref, equip_ref(slots[0]))


## Right-click on equipment: moves it to the first free bag slot.
static func unequip(slot: Slot) -> String:
	if GameState.equipment.get(slot, {}).is_empty():
		return ""
	var free := _first_free_slot()
	if free.is_empty():
		return ERR_FULL
	return move(equip_ref(slot), free)


## Moves or swaps the stacks at two places, merging same-item stacks.
## Returns an error message, or "" on success.
static func move(from: Dictionary, to: Dictionary) -> String:
	if from == to:
		return ""
	var moving := stack_at(from)
	var other := stack_at(to)
	if moving.is_empty():
		return ""
	var problem := _check_place(moving, to, from)
	if problem.is_empty() and not other.is_empty():
		problem = _check_place(other, from, to)
	if not problem.is_empty():
		return problem

	# Merge stacks of the same item between bag slots.
	if from.kind == "bag" and to.kind == "bag" and not other.is_empty() and other.id == moving.id:
		var stack_size := maxi(int(ItemDB.get_item(moving.id).stackable), 1)
		if other.count < stack_size:
			var moved := mini(stack_size - other.count, moving.count)
			other.count += moved
			moving.count -= moved
			if moving.count == 0:
				_set_stack(from, {})
			GameState.inventory_changed.emit()
			return ""

	# A two-hander pushes the off-hand item into the bags.
	var off_hand: Dictionary = GameState.equipment.get(Slot.OFF_HAND, {})
	var pushes_off_hand: bool = to.kind == "equip" and to.slot == Slot.MAIN_HAND and is_two_hander(moving) and not off_hand.is_empty()
	if pushes_off_hand:
		var free := free_slots() + (1 if from.kind == "bag" and other.is_empty() else 0)
		if free < 1:
			return ERR_FULL

	_set_stack(from, other)
	_set_stack(to, moving)
	if to.kind == "equip":
		_bind_on_equip(moving)
	if pushes_off_hand:
		GameState.equipment.erase(Slot.OFF_HAND)
		_set_stack(_first_free_slot(), off_hand)
	GameState.inventory_changed.emit()
	return ""


## Whether the stack can go into a place, given where it's coming from.
static func _check_place(stack: Dictionary, place: Dictionary, coming_from: Dictionary) -> String:
	var item := ItemDB.get_item(stack.id)
	match place.kind:
		"equip":
			var dual_wield: bool = int(item.InventoryType) == INVTYPE_WEAPON and place.slot == Slot.OFF_HAND and DUAL_WIELD_SPELL in GameState.known_spells
			if not (place.slot in SLOTS_FOR_TYPE.get(int(item.InventoryType), [])) and not dual_wield:
				return ERR_WRONG_SLOT
			var problem := can_use(item)
			if not problem.is_empty():
				return problem
			if place.slot == Slot.OFF_HAND and is_two_hander(GameState.equipment.get(Slot.MAIN_HAND, {})):
				if not (coming_from.kind == "equip" and coming_from.slot == Slot.MAIN_HAND):
					return ERR_TWO_HANDED
		"bag_slot":
			if int(item.InventoryType) != INVTYPE_BAG:
				return ERR_NOT_A_BAG
			if coming_from.kind == "bag" and coming_from.bag == place.index + 1:
				return ERR_BAG_INTO_ITSELF
			if not _bag_is_empty(place.index):
				return ERR_BAG_NOT_EMPTY
		"bag":
			if place.slot >= GameState.containers[place.bag].size():
				return ERR_WRONG_SLOT
			if coming_from.kind == "bag_slot":
				if not _bag_is_empty(coming_from.index):
					return ERR_BAG_NOT_EMPTY
				if place.bag == coming_from.index + 1:
					return ERR_BAG_INTO_ITSELF
	return ""


## Level, class and proficiency checks for equipping an item.
static func can_use(item: Dictionary) -> String:
	if int(item.RequiredLevel) > GameState.level:
		return ERR_LEVEL % item.RequiredLevel
	var class_mask := int(item.AllowableClass)
	if class_mask > 0 and (class_mask & (1 << (GameState.char_class - 1))) == 0:
		return ERR_CLASS
	if not has_proficiency(item):
		return ERR_PROFICIENCY
	return ""


## Whether the character has the skill for a weapon or armor type.
## Miscellaneous armor (rings, cloaks...) and other items need none.
static func has_proficiency(item: Dictionary) -> bool:
	var item_class := int(item["class"])
	var subclass := int(item.subclass)
	if item_class == ItemDB.ITEM_CLASS_WEAPON or (item_class == ItemDB.ITEM_CLASS_ARMOR and subclass != ARMOR_SUBCLASS_MISC):
		return "%d:%d" % [item_class, subclass] in GameState.proficiencies
	return true


## Totals from everything equipped (the player's gear, or a bot's), for
## CharacterStats.
static func gear_totals(equipment: Dictionary) -> Dictionary:
	var stats := [0, 0, 0, 0, 0]
	var totals := { "stats": stats, "armor": 0, "health": 0, "mana": 0, "block": 0, "has_shield": false, "weapon": UNARMED_WEAPON }
	# ITEM_MOD stat types: 3 Agility, 4 Strength, 5 Intellect, 6 Spirit, 7 Stamina.
	var stat_index := { 4: ClassicData.Stat.STRENGTH, 3: ClassicData.Stat.AGILITY, 7: ClassicData.Stat.STAMINA, 5: ClassicData.Stat.INTELLECT, 6: ClassicData.Stat.SPIRIT }
	for slot: Slot in equipment:
		var stack: Dictionary = equipment[slot]
		# Broken gear (0 durability) gives no stats, armor or weapon damage.
		if stack.is_empty() or is_broken(stack):
			continue
		var item := ItemDB.get_item(stack.id)
		totals.armor += int(item.armor)
		for stat: Array in item.stats:
			var kind := int(stat[0])
			if stat_index.has(kind):
				stats[stat_index[kind]] += int(stat[1])
			elif kind == 1:
				totals.health += int(stat[1])
			elif kind == 0:
				totals.mana += int(stat[1])
		if slot == Slot.MAIN_HAND and int(item.dmg_max1) > 0:
			totals.weapon = { "min": float(item.dmg_min1), "max": float(item.dmg_max1), "speed": int(item.delay) / 1000.0 }
		if slot == Slot.OFF_HAND and int(item.dmg_max1) > 0 and int(item["class"]) == ItemDB.ITEM_CLASS_WEAPON:
			totals.off_weapon = { "min": float(item.dmg_min1), "max": float(item.dmg_max1), "speed": int(item.delay) / 1000.0 }
		if slot == Slot.RANGED and int(item.dmg_max1) > 0 and int(item["class"]) == ItemDB.ITEM_CLASS_WEAPON:
			totals.ranged = ranged_weapon(item)
		if slot == Slot.OFF_HAND and int(item.subclass) == ARMOR_SUBCLASS_SHIELD and int(item["class"]) == ItemDB.ITEM_CLASS_ARMOR:
			totals.has_shield = true
			totals.block += int(item.block)
	return totals


## Ranged weapon subclasses: how far each shoots, [range, minimum] in yards
## (classic's 35 for bows and guns, 30 for thrown weapons and wands; the dead
## zone under 8 yards for all but wands).
const RANGED_REACH := { 2: [35.0, 8.0], 3: [35.0, 8.0], 18: [35.0, 8.0], 16: [30.0, 8.0], 19: [30.0, 0.0] }
const WEAPON_SUBCLASS_WAND := 19


## A ranged weapon's shot: damage, speed, school (wands deal theirs), its kind
## (the weapon subclass) and reach.
static func ranged_weapon(item: Dictionary) -> Dictionary:
	var subclass := int(item.subclass)
	var reach: Array = RANGED_REACH.get(subclass, [30.0, 8.0])
	return {
		"min": float(item.dmg_min1), "max": float(item.dmg_max1), "speed": int(item.delay) / 1000.0,
		"school": int(item.get("dmg_type1", 0)) if subclass == WEAPON_SUBCLASS_WAND else 0, "kind": subclass,
		"range": reach[0], "min_range": reach[1],
	}


static func _stack(id: int, count: int, bound: bool) -> Dictionary:
	# Bind on pickup items are soulbound as soon as they're taken.
	var item := ItemDB.get_item(id)
	var binds := bound or int(item.get("bonding", 0)) == 1
	var stack := { "id": id, "count": count, "bound": binds }
	if int(item.get("MaxDurability", 0)) > 0:
		stack.durability = int(item.MaxDurability)
	return stack


static func _bind_on_equip(stack: Dictionary) -> void:
	if int(ItemDB.get_item(stack.id).bonding) == 2:
		stack.bound = true


static func _set_stack(ref: Dictionary, stack: Dictionary) -> void:
	match ref.kind:
		"bag":
			GameState.containers[ref.bag][ref.slot] = stack
		"equip":
			if stack.is_empty():
				GameState.equipment.erase(ref.slot)
			else:
				GameState.equipment[ref.slot] = stack
		"bag_slot":
			GameState.bags[ref.index] = stack
			_resize_container(ref.index + 1, 0 if stack.is_empty() else int(ItemDB.get_item(stack.id).ContainerSlots))


static func _resize_container(index: int, size: int) -> void:
	var container: Array = GameState.containers[index]
	container.resize(size)
	for i in size:
		if container[i] == null:
			container[i] = {}


static func _bag_is_empty(index: int) -> bool:
	for stack: Dictionary in GameState.containers[index + 1]:
		if not stack.is_empty():
			return false
	return true


static func _first_free_slot() -> Dictionary:
	for bag in GameState.containers.size():
		var container: Array = GameState.containers[bag]
		for i in container.size():
			if container[i].is_empty():
				return bag_ref(bag, i)
	return {}


# Vendors, following Player::BuyItemFromVendor and HandleSellItemOpcode in CMaNGOS.

const ERR_NO_MONEY := "You don't have enough money."
const ERR_CANT_SELL := "Can't sell that item."
## Classic keeps the last 12 items sold, for buyback until logout.
const BUYBACK_SLOTS := 12


## Takes a whole stack out of its slot (traded away), returning it.
static func take_stack(ref: Dictionary) -> Dictionary:
	var stack := stack_at(ref)
	if not stack.is_empty():
		_set_stack(ref, {})
		GameState.inventory_changed.emit()
	return stack


static func remove_one(ref: Dictionary) -> void:
	var stack := stack_at(ref)
	if stack.is_empty():
		return
	stack.count -= 1
	if stack.count <= 0:
		_set_stack(ref, {})
	GameState.inventory_changed.emit()


## Items that can't be destroyed: the Homing Token every character carries.
const UNDESTROYABLE := [6948]
const ERR_CANT_DESTROY := "You can't destroy that item."


static func can_destroy(id: int) -> bool:
	return not id in UNDESTROYABLE


## Destroys a whole stack in the bags or equipment, as dropping an item off
## the windows does in classic. Bags themselves can't be destroyed this way.
static func destroy(ref: Dictionary) -> void:
	if ref.kind == "bag_slot" or stack_at(ref).is_empty() or not can_destroy(int(stack_at(ref).id)):
		return
	_set_stack(ref, {})
	GameState.inventory_changed.emit()


## Buys one lot of an item: BuyCount items for BuyPrice copper.
static func buy(id: int) -> String:
	var item := ItemDB.get_item(id)
	var price := int(item.BuyPrice)
	var count := maxi(int(item.BuyCount), 1)
	if GameState.money < price:
		return ERR_NO_MONEY
	if not _has_room_for(id, count):
		return ERR_FULL
	GameState.money -= price
	add_item(id, count)
	return ""


## Bag places holding poor quality (grey) items a vendor will buy.
static func junk_refs() -> Array[Dictionary]:
	var refs: Array[Dictionary] = []
	for b in GameState.containers.size():
		var container: Array = GameState.containers[b]
		for i in container.size():
			var stack: Dictionary = container[i]
			if stack.is_empty():
				continue
			var item := ItemDB.get_item(stack.id)
			if int(item.get("Quality", 1)) == ItemDB.Quality.POOR and int(item.get("SellPrice", 0)) > 0:
				refs.append(bag_ref(b, i))
	return refs


## Sells a whole bag stack for SellPrice per item. It goes to buyback.
static func sell(ref: Dictionary) -> String:
	var stack := stack_at(ref)
	if stack.is_empty() or ref.kind != "bag":
		return ""
	var item := ItemDB.get_item(stack.id)
	if int(item.SellPrice) <= 0:
		return ERR_CANT_SELL
	var money := int(item.SellPrice) * int(stack.count)
	_set_stack(ref, {})
	GameState.buyback.push_front({ "id": stack.id, "count": stack.count, "bound": stack.bound, "price": money })
	if GameState.buyback.size() > BUYBACK_SLOTS:
		GameState.buyback.pop_back()
	GameState.money += money
	GameState.inventory_changed.emit()
	return ""


## Buys back a sold stack for what it sold for.
static func buy_back(index: int) -> String:
	var entry: Dictionary = GameState.buyback[index]
	if GameState.money < int(entry.price):
		return ERR_NO_MONEY
	var free := _first_free_slot()
	if free.is_empty():
		return ERR_FULL
	GameState.money -= int(entry.price)
	GameState.buyback.remove_at(index)
	_set_stack(free, { "id": entry.id, "count": entry.count, "bound": entry.bound })
	GameState.inventory_changed.emit()
	return ""


static func _has_room_for(id: int, count: int) -> bool:
	var stack_size := maxi(int(ItemDB.get_item(id).get("stackable", 1)), 1)
	var room := 0
	for container: Array in GameState.containers:
		for stack: Dictionary in container:
			if stack.is_empty():
				room += stack_size
			elif stack.id == id:
				room += maxi(stack_size - int(stack.count), 0)
	return room >= count


# Durability, following Player::DurabilityLoss and DurabilityRepair in CMaNGOS.

const DURABILITY_PATH := "res://data/classic/durability.json"
## DurabilityLossChance.Damage in the CMaNGOS config: per hit dealt or taken,
## one durability point off a random equipment slot.
const DURABILITY_LOSS_HIT_CHANCE := 0.5
## DurabilityLossChance.Parry and .Block: weapon or shield on a parry or block.
const DURABILITY_LOSS_PARRY_CHANCE := 0.05
## Equipped gear loses 10% of its maximum durability on death.
const DURABILITY_LOSS_DEATH := 0.10
const ERR_NOTHING_TO_REPAIR := "You don't need to repair anything."

static var _durability_tables: Dictionary


static func max_durability(stack: Dictionary) -> int:
	return 0 if stack.is_empty() else int(ItemDB.get_item(stack.id).get("MaxDurability", 0))


static func durability(stack: Dictionary) -> int:
	return int(stack.get("durability", max_durability(stack)))


static func is_broken(stack: Dictionary) -> bool:
	return max_durability(stack) > 0 and durability(stack) <= 0


## The lowest durability fraction among equipped items that have durability,
## or 1.0 when nothing is worn down.
static func lowest_durability() -> float:
	var lowest := 1.0
	for stack: Dictionary in GameState.equipment.values():
		var full := max_durability(stack)
		if full > 0:
			lowest = minf(lowest, float(durability(stack)) / full)
	return lowest


static func lose_durability_points(stack: Dictionary, points: int) -> void:
	var full := max_durability(stack)
	if full <= 0:
		return
	var before := durability(stack)
	stack.durability = clampi(before - points, 0, full)
	if stack.durability != before:
		GameState.inventory_changed.emit()


## Death: every equipped item loses 10% of its maximum (at least 1 point).
static func lose_durability_on_death() -> void:
	for stack: Dictionary in GameState.equipment.values():
		var full := max_durability(stack)
		if full > 0:
			lose_durability_points(stack, maxi(int(full * DURABILITY_LOSS_DEATH), 1))


## A hit dealt or taken: a small chance to wear one point off a random slot.
## The slot is picked from all of them, so empty slots mean no wear.
static func roll_hit_wear() -> void:
	if randf() * 100.0 < DURABILITY_LOSS_HIT_CHANCE:
		var slot: Slot = Slot.values().pick_random()
		var stack: Dictionary = GameState.equipment.get(slot, {})
		if not stack.is_empty():
			lose_durability_points(stack, 1)


## A parry wears the weapon, a block the shield.
static func roll_avoidance_wear(slot: Slot) -> void:
	if randf() * 100.0 < DURABILITY_LOSS_PARRY_CHANCE:
		var stack: Dictionary = GameState.equipment.get(slot, {})
		if not stack.is_empty():
			lose_durability_points(stack, 1)


## Copper to fully repair one stack:
## lost durability * cost[item level][column] * quality modifier.
static func repair_cost(stack: Dictionary) -> int:
	var lost := max_durability(stack) - durability(stack)
	if lost <= 0:
		return 0
	if _durability_tables.is_empty():
		_durability_tables = JSON.parse_string(FileAccess.get_file_as_string(DURABILITY_PATH))
	var item := ItemDB.get_item(stack.id)
	var costs: Array = _durability_tables.costs.get(str(int(item.ItemLevel)), [])
	if costs.is_empty():
		return 0
	var column := int(item.subclass)
	if int(item["class"]) == ItemDB.ITEM_CLASS_ARMOR:
		column += 21
	var quality: float = _durability_tables.quality.get(str((int(item.Quality) + 1) * 2), 1.0)
	return maxi(int(lost * int(costs[column]) * quality), 1)


## Everything a vendor repair covers: equipped gear and everything in bags.
static func repair_all_cost() -> int:
	var total := 0
	for stack in _repairable_stacks():
		total += repair_cost(stack)
	return total


static func repair_all() -> String:
	var cost := repair_all_cost()
	if cost <= 0:
		return ERR_NOTHING_TO_REPAIR
	if GameState.money < cost:
		return ERR_NO_MONEY
	GameState.money -= cost
	for stack in _repairable_stacks():
		stack.durability = max_durability(stack)
	GameState.inventory_changed.emit()
	return ""


static func _repairable_stacks() -> Array:
	var stacks := []
	for stack: Dictionary in GameState.equipment.values():
		if max_durability(stack) > 0:
			stacks.append(stack)
	for container: Array in GameState.containers:
		for stack: Dictionary in container:
			if max_durability(stack) > 0:
				stacks.append(stack)
	return stacks
