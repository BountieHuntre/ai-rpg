class_name Npc
extends StaticBody3D
## A friendly NPC: a class trainer, a vendor, or both. Right-click within
## interaction range to use them.

@export var npc_name := "Brother Wilhelm"
@export var subname := "Paladin Trainer"
## Trainer list in data/classic/spells.json, or "" for none.
@export var trainer := ""
## creature_template entry of a vendor in data/classic/vendors.json, or 0.
@export var vendor := 0
