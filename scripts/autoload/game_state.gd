extends Node
## The player's character, progress and items. Lives outside the scene so it
## survives the restart after death. Saving it to disk comes later.
## Item stacks are dictionaries: { "id": item id, "count": n, "bound": bool },
## or {} for an empty slot. Inventory rules live in Inventory.

signal inventory_changed

## The classic backpack has 16 slots, plus four bag slots.
const BACKPACK_SLOTS := 16
const BAG_SLOTS := 4

var race := ClassicData.Race.HUMAN
var char_class := ClassicData.CharClass.PALADIN
var level := 1
var xp := 0
## Money in copper.
var money := 0
## Weapon and armor types the character can use, as "class:subclass" keys.
var proficiencies: Array[String] = []
## Inventory.Slot -> item stack.
var equipment: Dictionary = {}
## The bags in the four bag slots.
var bags: Array[Dictionary] = []
## Contents of the backpack (index 0) and each bag (1 to 4).
var containers: Array = []


func _init() -> void:
	bags.resize(BAG_SLOTS)
	bags.fill({})
	containers = [[], [], [], [], []]
	containers[0].resize(BACKPACK_SLOTS)
	containers[0].fill({})


func _ready() -> void:
	Inventory.start_character(self)


func add_item(id: int, count: int, bound := false) -> int:
	return Inventory.add_item(id, count, bound)


func free_slots() -> int:
	return Inventory.free_slots()


func total_slots() -> int:
	var total := 0
	for container: Array in containers:
		total += container.size()
	return total
