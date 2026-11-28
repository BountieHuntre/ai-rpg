@tool
class_name CreatureLook
extends Resource
## How one creature looks: its size and colour, the model it's shown as and
## what it holds. One file per creature in data/creatures/, named
## <entry>_<name>.tres; CreatureLooks reads them all. Saved while the game
## runs (editor and debug runs), living creatures of the entry take it at once.

## The creature_template id this look is for.
@export var entry := 0
## Its name in the game, for finding the file (the game takes names from the
## creature data, not from here).
@export var creature_name := ""
## Its size: without a model, the capsule's scale (beasts lie along their
## length); with one, x over the model's base size (data/creatures/models.tres)
## scales the model.
@export var size := Vector3.ONE
## Its colour: the capsule's, a beast's coat, a humanoid creature's skin.
@export var color := Color(0.75, 0.25, 0.25)
## The model it's shown as (data/creatures/models.tres lists them, and the
## playable races' models for dressed creatures); none for the capsule.
@export var model := ""
## Dressed as a person of the model's race: a face of its own, gear, a band's
## colour on its head and chest (the brigands' red takes a leather chest) and
## a cloak; size is ignored.
@export var dressed := false
## A dressed creature's band colour (hood, chest, cloak).
@export var band := Color(0.55, 0.12, 0.1)
## A dressed creature wears a cloak in its band's colour (when it has no helm).
@export var cloak := true
@export_group("Gear")
## The weapon in its main hand: a Main_<shape> of the character models
## (sword, axe2h, staff...), or none for bare hands. Humanoid creatures only.
@export var main := ""
## What it holds in its off hand: an Off_<shape> or Shield_<shape> part.
@export var off := ""
## Its helm: a Helm_<shape> part.
@export var helm := ""

const RACES := ["human", "dwarf", "gnome", "orc", "wood_elf", "undead", "troll", "hornkin"]
const MAIN_SHAPES := ["sword", "sword_broad", "sword_curved", "sword_short", "sword_ornate", "sword2h", "sword2h_claymore",
	"sword2h_great", "sword2h_ornate", "axe", "axe_hatchet", "axe_double", "axe_pick", "axe2h", "axe2h_bearded", "axe2h_cleaver",
	"mace", "mace_club", "mace_hammer", "mace_spiked", "mace_scepter", "mace2h", "mace2h_maul", "mace2h_club", "mace2h_shovel",
	"dagger", "dagger_knife", "dagger_curved", "dagger_stiletto", "staff", "staff_gnarled", "staff_quarter", "staff_runed",
	"polearm", "polearm_halberd", "polearm_glaive", "wand", "fist"]
const OFF_PARTS := ["Off_sword", "Off_axe", "Off_mace", "Off_dagger", "Off_fist", "Off_orb", "Shield_round", "Shield_kite",
	"Shield_heater", "Shield_buckler", "Shield_tower"]
const HELM_PARTS := ["Helm_hood", "Helm_hat", "Helm_cap", "Helm_capflaps", "Helm_coif", "Helm_nasal", "Helm_plate",
	"Helm_plate_visor", "Helm_mask"]


## Dropdowns in the Inspector (any other value can still be typed).
func _validate_property(property: Dictionary) -> void:
	match property.name:
		"model":
			var names: Array = [""]
			names.append_array(CreatureLooks.model_names())
			for race: String in RACES:
				if race not in names:
					names.append(race)
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = ",".join(names)
		"main":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = "," + ",".join(MAIN_SHAPES)
		"off":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = "," + ",".join(OFF_PARTS)
		"helm":
			property.hint = PROPERTY_HINT_ENUM_SUGGESTION
			property.hint_string = "," + ",".join(HELM_PARTS)


## What the model holds, as HumanoidModel.creature_gear takes it.
func gear() -> Dictionary:
	var out := { "main": main }
	if off != "":
		out["off"] = off
	if helm != "":
		out["helm"] = helm
	return out
