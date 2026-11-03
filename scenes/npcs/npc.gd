class_name Npc
extends StaticBody3D
## A friendly NPC: a class trainer, a vendor, a quest giver, or several.
## Right-click within interaction range to use them. Quests name their givers
## by the NPC's node name (see data/quests.json).

@export var npc_name := "Sir Aldric Fenn"
@export var subname := "Paladin Trainer"
## Trainer list in data/classic/spells.json, or "" for none.
@export var trainer := ""
## creature_template entry of a vendor in data/classic/vendors.json, or 0.
@export var vendor := 0


## The id quests use for this NPC: its node name.
func npc_id() -> String:
	return String(name)
