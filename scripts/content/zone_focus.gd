@tool
class_name ZoneFocus
extends Resource
## A spell focus point (a quest's moonwell or well): the game object a
## quest item's spell needs to be near.

## A note.
@export var name := "":
	set(value):
		name = value
		resource_name = value
## The spell focus object (gameobjects.json).
@export var entry := 0
@export var at := Vector2.ZERO
