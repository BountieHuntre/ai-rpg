class_name BotBag
extends RefCounted
## A playerbot's bag and purse: the loot and money from its own kills, which
## it sells to the player in trade and talks about in Trade chat. Bots ask a
## few times the vendor price for what they sell and a little over it for
## what they buy, each bot its own rates, and remember prices they quote or
## agree in chat. Saved in the bot's roster entry.

## Stacks it keeps; when full, the cheapest goes to a vendor.
const MAX_STACKS := 12
## Item bonding that can't be traded: binds when picked up, quest items.
const UNTRADEABLE := [1, 4]
## What bots pay for items: their own rate over the vendor price, and the
## most they'll go to when haggled.
const BUY_RATE_MIN := 1.1
const BUY_RATE_MAX := 1.4
const BUY_CEILING := 1.6
## The least they'll sell for, haggled down: times the vendor price.
const SELL_FLOOR := 1.5

## { "id", "count" } stacks.
var stacks: Array[Dictionary] = []
## Copper.
var money := 0
## How many times the vendor price it asks.
var markup := randf_range(2.0, 4.0)
## How many times the vendor price it pays.
var buy_rate := randf_range(BUY_RATE_MIN, BUY_RATE_MAX)
## Prices it has quoted or agreed, per item, copper each: what it'll pay the
## player ("buy") and what it'll sell for ("sell"). Trades use them.
var quotes := { "buy": {}, "sell": {} }


## Grey (poor quality) items, equipment included: trash, worth only what a
## vendor pays. Bots sell it to vendors, don't offer it, and won't pay more.
static func is_trash(id: int) -> bool:
	return int(ItemDB.get_item(id).get("Quality", 1)) == ItemDB.Quality.POOR


func has_trash() -> bool:
	return stacks.any(func(stack: Dictionary) -> bool: return is_trash(int(stack.id)))


## Sells every trash stack to a vendor. Returns the copper it got.
func sell_trash() -> int:
	var gained := 0
	for i in range(stacks.size() - 1, -1, -1):
		if is_trash(int(stacks[i].id)):
			gained += _vendor_value(stacks[i])
			stacks.remove_at(i)
	money += gained
	return gained


## Sells the junk: [items sold, copper gained].
func sell_trash_count() -> Array:
	var count := 0
	for stack in stacks:
		if is_trash(int(stack.id)):
			count += int(stack.count)
	return [count, sell_trash()]


## Sells everything a vendor will buy but soulbound things (party members'
## gear passed to it): [items sold, copper gained].
func sell_all() -> Array:
	var count := 0
	var gained := 0
	for i in range(stacks.size() - 1, -1, -1):
		var value := _vendor_value(stacks[i])
		if value > 0 and not is_bound(stacks[i]):
			count += int(stacks[i].count)
			gained += value
			stacks.remove_at(i)
	money += gained
	return [count, gained]


## Room for a stack of this item: an existing stack with space, or a free
## place among its STACKS.
func has_room(id: int, count: int, bound := false) -> bool:
	var stack_size := maxi(int(ItemDB.get_item(id).get("stackable", 1)), 1)
	var space := (MAX_STACKS - stacks.size()) * stack_size
	for stack in stacks:
		if int(stack.id) == id and is_bound(stack) == bound:
			space += stack_size - int(stack.count)
	return space >= count


## Soulbound: passed to it by a party member (who may take it back), never
## sold to anyone else or offered in trade.
static func is_bound(stack: Dictionary) -> bool:
	return bool(stack.get("bound", false))


static func can_trade(id: int) -> bool:
	return not int(ItemDB.get_item(id).get("bonding", 0)) in UNTRADEABLE


func count_of(id: int) -> int:
	var total := 0
	for stack in stacks:
		if int(stack.id) == id:
			total += int(stack.count)
	return total


## Soulbound stacks keep to themselves, marked "bound".
func add(id: int, count: int, bound := false) -> void:
	var stack_size := maxi(int(ItemDB.get_item(id).get("stackable", 1)), 1)
	for stack in stacks:
		if count > 0 and int(stack.id) == id and is_bound(stack) == bound and int(stack.count) < stack_size:
			var moved := mini(stack_size - int(stack.count), count)
			stack.count = int(stack.count) + moved
			count -= moved
	while count > 0:
		var moved := mini(stack_size, count)
		var stack := { "id": id, "count": moved }
		if bound:
			stack.bound = true
		stacks.append(stack)
		count -= moved
	_make_room()


## Takes some of an item, of its unbound stacks (or its bound ones).
func remove(id: int, count: int, bound := false) -> void:
	for i in range(stacks.size() - 1, -1, -1):
		if count > 0 and int(stacks[i].id) == id and is_bound(stacks[i]) == bound:
			var taken := mini(int(stacks[i].count), count)
			stacks[i].count = int(stacks[i].count) - taken
			count -= taken
			if int(stacks[i].count) <= 0:
				stacks.remove_at(i)


## Its share of a creature it killed: the loot that can change hands, and the
## money, rolled from the classic tables as the player's kills are.
func loot(enemy: Enemy) -> void:
	var data := Enemy.creature_data(enemy.creature_entry)
	for drop in LootTable.roll_creature(int(data.get("LootId", 0))):
		if can_trade(int(drop.id)):
			add(int(drop.id), int(drop.count))
	money += LootTable.roll_money(int(data.get("MinLootGold", 0)), int(data.get("MaxLootGold", 0)))


## Full bags: trash goes to a vendor first, then the cheapest stacks, for
## their sell price.
func _make_room() -> void:
	while stacks.size() > MAX_STACKS:
		var cheapest := 0
		for i in stacks.size():
			# Soulbound gear it was given goes last.
			if is_bound(stacks[i]) != is_bound(stacks[cheapest]):
				if is_bound(stacks[cheapest]):
					cheapest = i
				continue
			var trash := is_trash(int(stacks[i].id))
			var cheapest_trash := is_trash(int(stacks[cheapest].id))
			if trash != cheapest_trash:
				if trash:
					cheapest = i
			elif _vendor_value(stacks[i]) < _vendor_value(stacks[cheapest]):
				cheapest = i
		money += _vendor_value(stacks[cheapest])
		stacks.remove_at(cheapest)


static func _vendor_value(stack: Dictionary) -> int:
	return int(ItemDB.get_item(int(stack.id)).get("SellPrice", 0)) * int(stack.count)


## The stacks it would sell: things that can change hands and are worth
## something (not trash).
func for_sale() -> Array[Dictionary]:
	var goods: Array[Dictionary] = []
	for stack in stacks:
		if can_trade(int(stack.id)) and not is_bound(stack) and int(ItemDB.get_item(int(stack.id)).get("SellPrice", 0)) > 0 and not is_trash(int(stack.id)):
			goods.append(stack)
	return goods


## What it asks for some of an item: an agreed price, or its markup.
func asking_price(id: int, count: int) -> int:
	if quotes.sell.has(id):
		return int(quotes.sell[id]) * count
	return maxi(roundi(_vendor(id) * count * markup), 1)


## What it pays for some of an item: an agreed price, or its rate. 0 for
## things vendors won't take.
func buying_price(id: int, count: int) -> int:
	if quotes.buy.has(id):
		return int(quotes.buy[id]) * count
	# Trash: only what a vendor would give.
	return roundi(_vendor(id) * count * (1.0 if is_trash(id) else buy_rate))


## The most it would pay, haggled up, and the least it would sell for,
## haggled down: copper each.
func top_bid(id: int) -> int:
	return roundi(_vendor(id) * (1.0 if is_trash(id) else BUY_CEILING))


func lowest_ask(id: int) -> int:
	return maxi(roundi(_vendor(id) * SELL_FLOOR), 1)


static func _vendor(id: int) -> int:
	return int(ItemDB.get_item(id).get("SellPrice", 0))


func to_dict() -> Dictionary:
	return { "stacks": stacks, "money": money, "markup": markup, "buy_rate": buy_rate }


static func from_dict(data: Dictionary) -> BotBag:
	var bag := BotBag.new()
	for stack in data.get("stacks", []):
		if not ItemDB.get_item(int(stack.id)).is_empty():
			var kept := { "id": int(stack.id), "count": int(stack.count) }
			if bool(stack.get("bound", false)):
				kept.bound = true
			bag.stacks.append(kept)
	bag.money = int(data.get("money", 0))
	bag.markup = float(data.get("markup", bag.markup))
	bag.buy_rate = float(data.get("buy_rate", bag.buy_rate))
	return bag
