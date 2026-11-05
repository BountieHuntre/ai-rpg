class_name BestGear
extends RefCounted
## The best equipment in the game for a character's class, build and level
## (the dev console's "bis", for the player and party bots): every item the
## character could equip now (level, class and proficiency) is scored by what the
## build wants (stat weights, armor, weapon damage per second; the build is
## the talent tree with the most points), and the best per slot is put on.
## The hands go as a set, the build's weapon style favoured: a two-hander,
## two weapons (with Two-Weapon Fighting), a weapon and shield, or a weapon
## and off-hand item. Only upgrades go on; what they replace goes to the bags
## (the player's, or a bot's BotBag).

## Weights: Strength, Agility, Stamina, Intellect, Spirit, then armor,
## health, mana, weapon damage per second and shield block value; and the
## weapon style the build plays with ("hands"): a two-hander, two weapons, a
## weapon and shield, a weapon and an off-hand item, or whatever scores best.
## By class, for each talent tree as the build's main one (the most points),
## as classic players geared them: Blademastery and Zeal swing two-handers,
## Ferocity fights with two weapons, Bulwark and Aegis tank with a shield,
## Grace, Devotion and Mercy heal with an off-hand item or shield.
const SPECS := {
	ClassicData.CharClass.WARRIOR: [
		{ "stats": [2.2, 1.6, 1.0, 0.0, 0.0], "armor": 0.03, "health": 0.1, "mana": 0.0, "dps": 14.0, "block": 0.0, "hands": "two_hand" },
		{ "stats": [2.0, 1.8, 1.0, 0.0, 0.0], "armor": 0.03, "health": 0.1, "mana": 0.0, "dps": 12.0, "block": 0.0, "hands": "dual_wield" },
		{ "stats": [1.0, 1.2, 2.2, 0.0, 0.0], "armor": 0.12, "health": 0.2, "mana": 0.0, "dps": 5.0, "block": 1.0, "hands": "shield" },
	],
	ClassicData.CharClass.PALADIN: [
		{ "stats": [0.2, 0.0, 0.8, 2.2, 1.0], "armor": 0.03, "health": 0.08, "mana": 0.15, "dps": 1.0, "block": 0.1, "hands": "off_hand" },
		{ "stats": [1.0, 0.8, 2.2, 0.8, 0.0], "armor": 0.12, "health": 0.2, "mana": 0.05, "dps": 5.0, "block": 1.0, "hands": "shield" },
		{ "stats": [2.2, 1.4, 1.0, 0.4, 0.0], "armor": 0.03, "health": 0.1, "mana": 0.03, "dps": 14.0, "block": 0.0, "hands": "two_hand" },
	],
	ClassicData.CharClass.PRIEST: [
		{ "stats": [0.0, 0.0, 1.0, 2.0, 1.6], "armor": 0.02, "health": 0.08, "mana": 0.13, "dps": 0.5, "block": 0.0, "hands": "off_hand" },
		{ "stats": [0.0, 0.0, 0.8, 2.0, 2.0], "armor": 0.02, "health": 0.07, "mana": 0.15, "dps": 0.5, "block": 0.0, "hands": "off_hand" },
		{ "stats": [0.0, 0.0, 1.3, 2.2, 1.0], "armor": 0.02, "health": 0.1, "mana": 0.12, "dps": 0.5, "block": 0.0, "hands": "any" },
	],
}
## With no talent points spent (or a tie): an all-round build per class.
const WEIGHTS := {
	ClassicData.CharClass.WARRIOR: { "stats": [2.0, 1.5, 1.3, 0.0, 0.0], "armor": 0.05, "health": 0.12, "mana": 0.0, "dps": 10.0, "block": 0.3, "hands": "any" },
	ClassicData.CharClass.PALADIN: { "stats": [1.6, 0.8, 1.2, 1.2, 0.5], "armor": 0.05, "health": 0.1, "mana": 0.08, "dps": 7.0, "block": 0.3, "hands": "any" },
	ClassicData.CharClass.PRIEST: { "stats": [0.0, 0.0, 1.0, 2.0, 1.6], "armor": 0.02, "health": 0.08, "mana": 0.13, "dps": 0.5, "block": 0.0, "hands": "any" },
}
const DEFAULT_WEIGHTS := { "stats": [1.0, 1.0, 1.0, 1.0, 1.0], "armor": 0.04, "health": 0.1, "mana": 0.07, "dps": 5.0, "block": 0.2, "hands": "any" }
## How much a build favours its own weapon style: a matching set's score is
## multiplied by this.
const STYLE_BONUS := 1.5
## ITEM_MOD stat types to Strength, Agility, Stamina, Intellect, Spirit.
const STAT_INDEX := { 4: 0, 3: 1, 7: 2, 5: 3, 6: 4 }
const INVTYPE_HELD := 23
const INVTYPE_WEAPON_OFF_HAND := 22


## A character's build (the player's by default): the weights of the talent
## tree with the most points (none spent, or a tie: the class's all-round
## weights), with "tree" its name.
static func spec(who: CharacterProfile = null) -> Dictionary:
	if who == null:
		who = GameState
	var trees := Talents.trees(who.char_class)
	var best := -1
	var most := 0
	var tied := false
	for i in trees.size():
		var points := Talents.spent_in(who, trees[i])
		if points > most:
			most = points
			best = i
			tied = false
		elif points == most and points > 0:
			tied = true
	var specs: Array = SPECS.get(who.char_class, [])
	if best < 0 or tied or best >= specs.size():
		return (WEIGHTS.get(who.char_class, DEFAULT_WEIGHTS) as Dictionary).merged({ "tree": "" })
	return (specs[best] as Dictionary).merged({ "tree": trees[best].name })


## What a build makes of an item: higher is better, 0 for nothing useful.
static func score(item: Dictionary, w: Dictionary) -> float:
	var total := float(item.get("armor", 0)) * float(w.armor)
	for stat: Array in item.get("stats", []):
		var kind := int(stat[0])
		if STAT_INDEX.has(kind):
			total += float(stat[1]) * float(w.stats[STAT_INDEX[kind]])
		elif kind == 1:
			total += float(stat[1]) * float(w.health)
		elif kind == 0:
			total += float(stat[1]) * float(w.mana)
	var delay := int(item.get("delay", 0))
	if int(item.get("dmg_max1", 0)) > 0 and delay > 0:
		var dps := (float(item.dmg_min1) + float(item.dmg_max1)) / 2.0 / (delay / 1000.0)
		total += dps * float(w.dps)
	total += float(item.get("block", 0)) * float(w.block)
	return total


## What the two hands together are worth to the build: their scores, raised
## when they're the build's weapon style.
static func hands_value(main_id: int, off_id: int, w: Dictionary) -> float:
	var main := ItemDB.get_item(main_id) if main_id != 0 else {}
	var off := ItemDB.get_item(off_id) if off_id != 0 else {}
	var value := (score(main, w) if not main.is_empty() else 0.0) + (score(off, w) if not off.is_empty() else 0.0)
	return value * (STYLE_BONUS if matches_style(main_id, off_id, w) else 1.0)


## Whether the two hands are the build's weapon style.
static func matches_style(main_id: int, off_id: int, w: Dictionary) -> bool:
	var main := ItemDB.get_item(main_id) if main_id != 0 else {}
	var off := ItemDB.get_item(off_id) if off_id != 0 else {}
	var two_handed := not main.is_empty() and int(main.InventoryType) == Inventory.INVTYPE_TWO_HAND
	var off_weapon := not off.is_empty() and int(off["class"]) == ItemDB.ITEM_CLASS_WEAPON
	var shield := not off.is_empty() and int(off.InventoryType) == Inventory.INVTYPE_SHIELD
	var matches := false
	match str(w.hands):
		"two_hand":
			matches = two_handed
		"dual_wield":
			matches = off_weapon
		"shield":
			matches = shield
		"off_hand":
			matches = not off.is_empty() and not off_weapon
	return matches


## Whether the character could put the item on now: an equippable item of
## its level, class and proficiencies (Inventory.can_use, for any profile).
static func _usable(item: Dictionary, who: CharacterProfile) -> bool:
	return Inventory.SLOTS_FOR_TYPE.has(int(item.get("InventoryType", 0))) and _can_use(item, who)


static func _can_use(item: Dictionary, who: CharacterProfile) -> bool:
	if item.is_empty() or int(item.RequiredLevel) > who.level:
		return false
	var class_mask := int(item.AllowableClass)
	if class_mask > 0 and (class_mask & (1 << (who.char_class - 1))) == 0:
		return false
	var item_class := int(item["class"])
	var subclass := int(item.subclass)
	if item_class == ItemDB.ITEM_CLASS_WEAPON or (item_class == ItemDB.ITEM_CLASS_ARMOR and subclass != Inventory.ARMOR_SUBCLASS_MISC):
		return "%d:%d" % [item_class, subclass] in who.proficiencies
	return true


## The best item id per equipment slot, by score.
static func pick(w: Dictionary = {}, who: CharacterProfile = null) -> Dictionary:
	if who == null:
		who = GameState
	if w.is_empty():
		w = spec(who)
	var best := {}
	var rings: Array = []
	var trinkets: Array = []
	var two_hand := [0, 0.0]
	var one_hands: Array = []
	var off_hands: Array = []
	var dual_wield := Inventory.DUAL_WIELD_SPELL in who.known_spells
	for id: int in ItemDB.all_ids():
		var item := ItemDB.get_item(id)
		if not _usable(item, who):
			continue
		var value := score(item, w)
		if value <= 0.0:
			continue
		var kind := int(item.InventoryType)
		match kind:
			11:
				rings.append([id, value])
			12:
				trinkets.append([id, value])
			Inventory.INVTYPE_TWO_HAND:
				if value > two_hand[1]:
					two_hand = [id, value]
			Inventory.INVTYPE_ONE_HAND, 21:
				one_hands.append([id, value])
				if kind == Inventory.INVTYPE_ONE_HAND and dual_wield:
					off_hands.append([id, value])
			Inventory.INVTYPE_SHIELD, INVTYPE_WEAPON_OFF_HAND, INVTYPE_HELD:
				off_hands.append([id, value])
			_:
				var slot: int = Inventory.SLOTS_FOR_TYPE[kind][0]
				if value > best.get(slot, [0, 0.0])[1]:
					best[slot] = [id, value]
	var by_value := func(a: Array, b: Array) -> bool: return a[1] > b[1]
	rings.sort_custom(by_value)
	trinkets.sort_custom(by_value)
	off_hands.sort_custom(by_value)
	var picked := {}
	for slot: int in best:
		picked[slot] = best[slot][0]
	for i in mini(rings.size(), 2):
		picked[Inventory.Slot.FINGER_1 + i] = rings[i][0]
	for i in mini(trinkets.size(), 2):
		picked[Inventory.Slot.TRINKET_1 + i] = trinkets[i][0]
	# The hands as a set: a two-hander, or the best one-hander alone or with
	# the best off-hand of each kind (shield, held item, second weapon),
	# whichever the build values most (hands_value favours its style).
	one_hands.sort_custom(by_value)
	var sets: Array = []
	if two_hand[0] != 0:
		sets.append([two_hand[0], 0])
	var main_id: int = one_hands[0][0] if not one_hands.is_empty() else 0
	if main_id != 0:
		sets.append([main_id, 0])
		var best_of_kind := {}
		for candidate: Array in off_hands:
			if candidate[0] == main_id:
				continue
			var off_item := ItemDB.get_item(int(candidate[0]))
			var off_kind := "weapon" if int(off_item["class"]) == ItemDB.ITEM_CLASS_WEAPON else str(off_item.InventoryType)
			if not best_of_kind.has(off_kind):
				best_of_kind[off_kind] = candidate[0]
		for off_id: int in best_of_kind.values():
			sets.append([main_id, off_id])
	# The build's own style wins when there's a set of it at all (Zeal swings
	# a two-hander even if a better one-hander exists); otherwise the best.
	var styled := sets.filter(func(hand_set: Array) -> bool: return matches_style(hand_set[0], hand_set[1], w))
	if not styled.is_empty():
		sets = styled
	var best_set: Array = []
	for hand_set: Array in sets:
		if best_set.is_empty() or hands_value(hand_set[0], hand_set[1], w) > hands_value(best_set[0], best_set[1], w):
			best_set = hand_set
	if not best_set.is_empty():
		picked[Inventory.Slot.MAIN_HAND] = best_set[0]
		if best_set[1] != 0:
			picked[Inventory.Slot.OFF_HAND] = best_set[1]
	return picked


## Puts on the best gear where it beats what's worn. The hands go as a set,
## when the build values the new set over the worn one. Returns the names
## put on, the build's tree, and how many upgrades were left off for want
## of bag room. The player by default; a bot's profile with its BotBag
## (what it takes off goes in the bag, or is dropped if the bag is full).
static func equip_best(who: CharacterProfile = null, bag: BotBag = null) -> Dictionary:
	if who == null:
		who = GameState
	var w := spec(who)
	var picked := pick(w, who)
	var equipment: Dictionary = who.equipment
	var equipped: Array[String] = []
	var no_room := 0
	var main_slot := Inventory.Slot.MAIN_HAND
	var off_slot := Inventory.Slot.OFF_HAND
	if picked.has(main_slot):
		var worn_main: Dictionary = equipment.get(main_slot, {})
		var worn_off: Dictionary = equipment.get(off_slot, {})
		var new_off: int = picked.get(off_slot, 0)
		if hands_value(int(picked[main_slot]), new_off, w) > hands_value(_usable_id(worn_main, who), _usable_id(worn_off, who), w):
			var room := true
			for worn: Dictionary in [worn_main, worn_off]:
				if not worn.is_empty() and not _stow(worn, who, bag):
					room = false
			if room:
				equipment.erase(main_slot)
				equipment.erase(off_slot)
				for pair: Array in [[main_slot, int(picked[main_slot])], [off_slot, new_off]]:
					if pair[1] != 0:
						var stack := Inventory._stack(pair[1], 1, false)
						Inventory._bind_on_equip(stack)
						equipment[pair[0]] = stack
						equipped.append(str(ItemDB.get_item(pair[1]).name))
			else:
				no_room += 1
	for slot: int in picked:
		if slot == main_slot or slot == off_slot:
			continue
		var id: int = picked[slot]
		var current: Dictionary = equipment.get(slot, {})
		if not current.is_empty() and (int(current.id) == id or _worn_score(current, w, who) >= score(ItemDB.get_item(id), w)):
			continue
		if not current.is_empty() and not _stow(current, who, bag):
			no_room += 1
			continue
		var stack := Inventory._stack(id, 1, false)
		Inventory._bind_on_equip(stack)
		equipment[slot] = stack
		equipped.append(str(ItemDB.get_item(id).name))
	if who == GameState:
		GameState.inventory_changed.emit()
	return { "equipped": equipped, "no_room": no_room, "tree": w.tree }


## A worn stack's item id, or 0 if empty or the class can't use it.
static func _usable_id(stack: Dictionary, who: CharacterProfile) -> int:
	if stack.is_empty() or not _can_use(ItemDB.get_item(int(stack.id)), who):
		return 0
	return int(stack.id)


## What a worn piece is worth: nothing if the class can't use it.
static func _worn_score(stack: Dictionary, w: Dictionary, who: CharacterProfile) -> float:
	var item := ItemDB.get_item(int(stack.id))
	return score(item, w) if _can_use(item, who) else 0.0


## Moves a worn stack into the bags. Returns false when there's no room.
## A bot's goes in its BotBag, where a full bag makes room; soulbound pieces
## (they can't be traded) and those of a bot with no bag are dropped.
static func _stow(stack: Dictionary, who: CharacterProfile, bag: BotBag) -> bool:
	if who != GameState:
		if bag != null and not stack.get("bound", false):
			bag.add(int(stack.id), maxi(int(stack.get("count", 1)), 1))
		return true
	if Inventory.free_slots() <= 0:
		return false
	var place := Inventory._first_free_slot()
	if place.is_empty():
		return false
	Inventory._set_stack(place, stack.duplicate())
	return true
