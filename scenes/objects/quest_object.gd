class_name QuestObject
extends Npc
## A quest giver or ender that's a thing, not a person, as classic's quest
## giver game objects (type 2): A half-eaten body, Aldous's corpse. Its name
## comes from data/classic/gameobjects.json by `entry`; quests name it by its
## node name like any NPC. It has no title or nameplate, only its quest
## marker, and is built in code: a body lying on the ground.

@export var entry := 0


func _ready() -> void:
	add_to_group("npcs")
	npc_name = GameObject.data(entry).get("name", "Object")
	subname = ""
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.5, 1.9)
	shape.shape = box
	shape.position.y = 0.25
	add_child(shape)
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
