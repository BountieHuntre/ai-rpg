class_name GatherNode
extends StaticBody3D
## A herb or ore node (classic's herb and mineral veins, gameobject type 3
## with a Lock needing Herbalism or Mining): its entry is a node of
## ProfessionDB (name, skill needed, loot). Right-click it to gather
## (Gathering): a cast, then its loot opens like a corpse's, rolled from its
## node loot. Emptied, it's gone, and its GatherNodes field brings one back
## after its respawn time, at another spot. It sits on the corpse layer, so
## the camera's clicks find it.

## Further than this from the camera it isn't drawn.
static var DRAW_RANGE := 110.0
static var HERB_SCALE := 1.8

var entry := 0
## "herb" or "ore".
var kind := "herb"
var loot: Array[Dictionary] = []
var loot_money := 0
## The GatherNodes that placed it, told when it's emptied.
var field: Node
var _rolled := false


func data() -> Dictionary:
	return ProfessionDB.node(entry)


func node_name() -> String:
	return str(data().get("name", "Herb" if kind == "herb" else "Mineral Vein"))


## The profession that gathers it.
func profession() -> String:
	return "herbalism" if kind == "herb" else "mining"


func skill_needed() -> int:
	return int(data().get("skill", 1))


func _ready() -> void:
	add_to_group("gather_nodes")
	collision_layer = Enemy.CORPSE_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.0, 1.4) if kind == "ore" else Vector3(0.9, 0.8, 0.9)
	shape.shape = box
	shape.position.y = box.size.y / 2.0
	add_child(shape)
	var view := MeshInstance3D.new()
	view.name = "Model"
	view.mesh = Nature.node_mesh(node_name(), kind)
	# Herbs drawn bigger than life, so they show over the grass.
	if kind == "herb":
		view.scale = Vector3.ONE * HERB_SCALE
	view.visibility_range_end = DRAW_RANGE
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "herb" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(view)
	set_process(false)


func has_loot() -> bool:
	return _rolled and not loot.is_empty()


## Gathered: rolls its loot (once). Returns whether there's any.
func open() -> bool:
	if not _rolled:
		loot = LootTable.roll_entries(ProfessionDB.node_loot(int(data().get("loot", entry))))
		_rolled = true
		set_process(true)
	return has_loot()


## Taken by a playerbot, which doesn't loot: the loot goes to it whole.
func take_all() -> Array[Dictionary]:
	open()
	var taken := loot.duplicate()
	loot.clear()
	return taken


func _process(_delta: float) -> void:
	# Emptied: gone, the field bringing one back later somewhere else.
	if _rolled and loot.is_empty():
		set_process(false)
		if field:
			field.emptied(self)
		queue_free()
