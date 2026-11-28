@tool
class_name ZonePlace
extends Resource
## A named place of a zone (what bots say, the world map's names, places to
## explore), or a wood (trees thin out toward its edge): a circle.

## Its name (places: as bots and the map say it, "the Old Delve"; woods: a
## note).
@export var name := "":
	set(value):
		name = value
		resource_name = value
## Its middle, in world yards (x, z; -z is north).
@export var center := Vector2.ZERO
## How far it reaches, in yards (its rim is ragged).
@export var radius := 10.0
