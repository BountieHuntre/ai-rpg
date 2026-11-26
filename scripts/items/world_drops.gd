class_name WorldDrops
extends RefCounted
## The game's own world drops, rolled with a creature's classic loot: its
## bags of 14 slots and up (data/items.json, 900704-900721), which no vendor
## sells. From level 8 any creature may drop a bag of 14 to 24 slots, rarely;
## elites and rares (classic Rank 1, 2, 4) and bosses (3) also drop the big
## ones, 26 to 48 slots, more often the rarer they are. The higher the level,
## the bigger the bag can be.

## The bags by size: entry 900700 holds 6 slots, each next one 2 more.
static var FIRST_BAG := 900700
static var SMALLEST := 6
## Normal creatures from this level drop 14-24 slot bags, at this chance (%).
static var BAG_LEVEL := 8
static var BAG_CHANCE := 0.4
## Elites and rares, then bosses: their chance (%) of a 26-48 slot bag.
const BIG_BAG_CHANCE := { 1: 2.0, 2: 4.0, 4: 4.0, 3: 15.0 }


static func bag(size: int) -> int:
	return FIRST_BAG + (size - SMALLEST) / 2


## What a creature of `level` and classic `rank` drops of the world drops:
## { "id", "count" } entries, as LootTable's.
static func roll(level: int, rank: int) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if level >= BAG_LEVEL and randf() * 100.0 < BAG_CHANCE:
		drops.append({ "id": bag(_size(14, clampi(10 + level, 14, 24))), "count": 1 })
	if randf() * 100.0 < float(BIG_BAG_CHANCE.get(rank, 0.0)):
		var most := clampi((30 if rank == 3 else 20) + level, 26, 48)
		drops.append({ "id": bag(_size(26, most)), "count": 1 })
	return drops


## An even size from `least` to `most`.
static func _size(least: int, most: int) -> int:
	return least + 2 * randi_range(0, (most - least) / 2)
