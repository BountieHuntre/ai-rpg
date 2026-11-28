@tool
class_name RaceLook
extends Resource
## A race's colours and character-creation choices (data/looks/<race>.tres,
## read by CharacterLooks): its skins and hair colours, eyes, tusks or horns,
## and its feature and markings. A race without a file takes the Human's.
## Saved while the game runs (editor and debug runs), every model of the race
## takes it at once.

## The race's model name (human, orc, wood_elf, hornkin...).
@export var race := ""
## Skin colours to choose from (an appearance's "skin" picks one; as many as
## the Human's, so a look fits any race).
@export var skins := PackedColorArray()
## Hair colours to choose from (an appearance's "hair_color").
@export var hair_colors := PackedColorArray()
## The eyes' colour.
@export var eye_color := Color(0.1, 0.09, 0.12)
## Eyes that glow: the whites take the eye colour too (the Undead's, the Wood
## Elves', the barklings').
@export var glowing_eyes := false
## Tusks, horns and bone.
@export var tusk_color := Color(0.9, 0.86, 0.72)
@export_group("Character creation")
## What its feature is called (Tusks, Horns, Ears, Jaw), and each choice's
## name (the model's Feature0-2 / FeatureF0-2 parts); none for no choice.
@export var feature_title := ""
@export var feature_names := PackedStringArray()
## What its markings are called (War Paint, Runes, Scars), and each choice's
## name (None, then the model's Marks0-2 / MarksF0-2 parts).
@export var marks_title := ""
@export var marks_names := PackedStringArray()
## The markings' colour.
@export var paint := Color(0.6, 0.1, 0.08)
