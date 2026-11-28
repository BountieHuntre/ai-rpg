@tool
class_name ZoneChest
extends Resource
## Chests (or other game objects that are opened) a zone scatters in a circle.

## A note.
@export var name := "":
	set(value):
		name = value
		resource_name = value
## The game object (gameobject_template id in data/classic/gameobjects.json).
@export var entry := 0
## The circle they're scattered in: its middle in world yards (x, z), and
## radius.
@export var center := Vector2.ZERO
@export var radius := 10.0
## How many.
@export var count := 1
