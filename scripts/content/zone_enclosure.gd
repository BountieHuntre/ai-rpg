@tool
class_name ZoneEnclosure
extends Resource
## A walled place bots go in and out of by its gate (a yard, a building).

## A note: what it is and where its door is.
@export var name := "":
	set(value):
		name = value
		resource_name = value
## Its corners in world yards: least x and z, most x and z.
@export var least := Vector2.ZERO
@export var most := Vector2.ZERO
## Just outside the gate, and just inside it.
@export var outside := Vector2.ZERO
@export var inside := Vector2.ZERO
