@tool
class_name CreatureModelInfo
extends Resource
## One creature model (data/creatures/models.tres): its name, how big it is at
## scale 1 and whether it's a BeastModel (else a HumanoidModel of its race).

## The model's name: a BeastModel species or a humanoid race of the build
## scripts.
@export var name := ""
## How big the model is at scale 1, in a CreatureLook's size terms, so a
## creature's model is scaled by its size.x over this.
@export var base_size := 1.0
## A BeastModel (made by tools/models/beasts/build_beasts.py), coloured from
## the creature's colour; else a HumanoidModel (tools/models/human/build_human.py).
@export var beast := false
