class_name Npc
extends StaticBody3D
## A friendly NPC: a class trainer, a vendor, a quest giver, or several.
## Right-click within interaction range to use them. Quests name their givers
## by the NPC's node name (see data/quests.json).

@export var npc_name := "Sir Aldric Fenn"
@export var subname := "Templar Trainer"
## Trainer list in data/classic/spells.json, or "" for none.
@export var trainer := ""
## creature_template entry of a vendor in data/classic/vendors.json, or 0.
@export var vendor := 0


## How the NPC looks (HumanoidModel); empty for a look of its own from its
## name.
@export var appearance: Dictionary = {}


func _ready() -> void:
	# NPCs are Humans: the model in clothes for their trade, in place of the
	# placeholder capsule.
	for part in ["Body", "Tabard"]:
		if has_node(part):
			get_node(part).visible = false
	Targeting.mark_unit(self)
	var model := HumanoidModel.new()
	add_child(model)
	model.set_appearance(appearance if not appearance.is_empty() else HumanoidModel.random_appearance(hash(npc_name)))
	model.outfit = HumanoidModel.outfit_for(trainer, hash(npc_name))
	model.show_equipment({})


## The id quests use for this NPC: its node name.
func npc_id() -> String:
	return String(name)
