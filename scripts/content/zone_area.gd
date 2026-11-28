@tool
class_name ZoneArea
extends Resource
## A zone's level flat (for a camp or town) or rounded hill: a circle with a
## height.

## A note: what stands there.
@export var name := "":
	set(value):
		name = value
		resource_name = value
## A flat's name in the zone's code (FLATS[DELVE]): the builders place what
## stands on it by this, so keep it; none for flats the code doesn't name.
@export var key := ""
## Its middle, in world yards (x, z; -z is north).
@export var center := Vector2.ZERO
## How far it reaches, in yards (its rim is ragged).
@export var radius := 10.0
## A flat's ground height, or how high a hill rises, in yards.
@export var height := 5.0
