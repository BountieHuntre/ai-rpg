class_name QuestObject
extends Npc
## A quest giver or ender that's a thing, not a person, as classic's quest
## giver game objects (type 2): A half-eaten body, Aldous's corpse, the Thunder
## Ale barrels, Denalor's Planter. Its name comes from
## data/classic/gameobjects.json by `entry`; quests name it by its node name
## like any NPC. It has no title or nameplate, only its quest marker, and is
## built in code by its name: a barrel, a planter, else a body lying on the
## ground. `set_present` takes it out of the world for a while (the
## unguarded barrel, there only while its guard is away).

@export var entry := 0


func _ready() -> void:
	add_to_group("npcs")
	set_physics_process(false)
	npc_name = GameObject.data(entry).get("name", "Object")
	subname = ""
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	shape.shape = box
	add_child(shape)
	if "Barrel" in npc_name:
		box.size = Vector3(1.2, 1.4, 1.2)
		shape.position.y = 0.7
		Props.cylinder(self, Vector3.ZERO, 0.6, 1.4, Color(0.45, 0.3, 0.18), false, 0.55)
		for band in [0.25, 1.15]:
			Props.cylinder(self, Vector3(0, band, 0), 0.62, 0.08, Color(0.3, 0.3, 0.32), false)
		return
	if "Planter" in npc_name:
		box.size = Vector3(1.6, 0.8, 1.6)
		shape.position.y = 0.4
		Props.box(self, Vector3.ZERO, Vector3(1.6, 0.8, 1.6), Color(0.5, 0.42, 0.36), 0.0, false)
		Props.box(self, Vector3(0, 0.8, 0), Vector3(1.4, 0.05, 1.4), Color(0.25, 0.2, 0.15), 0.0, false)
		return
	box.size = Vector3(0.7, 0.5, 1.9)
	shape.position.y = 0.25
	# A body lying on its back, in a dark cloak, with a pale face.
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.32
	capsule.height = 1.7
	body.mesh = capsule
	body.material_override = Props.material(Color(0.3, 0.3, 0.36))
	body.rotation.x = PI / 2
	body.position.y = 0.3
	add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = Props.blob(0.2, 6, 4)
	head.material_override = Props.material(Color(0.75, 0.66, 0.58))
	head.position = Vector3(0, 0.35, -0.75)
	add_child(head)
	var stain := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.4, 2.2)
	stain.mesh = plane
	stain.material_override = Props.material(Color(0.35, 0.08, 0.06))
	stain.position.y = 0.03
	add_child(stain)


## Puts it in the world or takes it out: seen, clicked and asked for quests
## only while present.
func set_present(present: bool) -> void:
	visible = present
	collision_layer = 2 if present else 0
	if present:
		add_to_group("npcs")
	elif is_in_group("npcs"):
		remove_from_group("npcs")
	QuestLog.clear_cache()
