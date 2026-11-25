class_name LootBundle
extends Node3D
## Loot that isn't on a corpse or chest (what a disenchanted item breaks
## into): it rides on the player, the loot window opens on it like a corpse,
## and it's gone once emptied.

var loot: Array[Dictionary] = []
var loot_money := 0


func has_loot() -> bool:
	return loot_money > 0 or not loot.is_empty()


func _process(_delta: float) -> void:
	if not has_loot():
		queue_free()
