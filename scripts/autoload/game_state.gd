extends Node
## The player's character and progress. Lives outside the scene so it survives
## the restart after death. Saving it to disk comes later.

## The classic backpack has 16 slots.
const BACKPACK_SLOTS := 16

var race := ClassicData.Race.HUMAN
var char_class := ClassicData.CharClass.PALADIN
var level := 1
var xp := 0
## Money in copper.
var money := 0
## One entry per backpack slot: {} when empty, else { "id", "count" }.
var backpack: Array[Dictionary] = []


func _init() -> void:
	backpack.resize(BACKPACK_SLOTS)
	backpack.fill({})


## Adds items, filling existing stacks first, then empty slots. Returns how many
## didn't fit.
func add_item(id: int, count: int) -> int:
	var stack_size := maxi(int(ItemDB.get_item(id).get("stackable", 1)), 1)
	for slot in backpack:
		if count > 0 and not slot.is_empty() and slot.id == id and slot.count < stack_size:
			var moved := mini(stack_size - slot.count, count)
			slot.count += moved
			count -= moved
	for i in backpack.size():
		if count > 0 and backpack[i].is_empty():
			var moved := mini(stack_size, count)
			backpack[i] = { "id": id, "count": moved }
			count -= moved
	return count


func free_slots() -> int:
	return backpack.filter(func(slot: Dictionary) -> bool: return slot.is_empty()).size()
