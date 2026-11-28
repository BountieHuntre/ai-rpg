@tool
class_name ZoneRoad
extends Resource
## A road of a zone: the points it runs through, in world yards (x, z).

## A note: where it goes.
@export var name := "":
	set(value):
		name = value
		resource_name = value
@export var points := PackedVector2Array()
