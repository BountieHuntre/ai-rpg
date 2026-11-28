@tool
class_name ZoneQuestObject
extends Resource
## A thing that gives or ends a quest (a QuestObject: a body, a barrel...),
## named like an NPC so quests.json can name it.

## A note.
@export var note := "":
	set(value):
		note = value
		resource_name = value
## The game object (gameobjects.json).
@export var entry := 0
## Its node name, which quests.json names as giver or ender.
@export var node_name := ""
## Where it stands, in world yards (x, z), on the ground there.
@export var at := Vector2.ZERO
## Which way it faces (radians).
@export var facing := 0.0
