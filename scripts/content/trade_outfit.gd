@tool
class_name TradeOutfit
extends Resource
## What NPCs of a trade wear (data/looks/outfits.tres, HumanoidModel.outfit_for):
## each NPC's colours are picked by its seed from these, over the everyday
## outfit (a cloth chest, leather legs, boots, gloves and belt).

## The trades it's for: a trainer's class ("paladin", "warrior", "mage"...),
## a profession, "weapons".
@export var trades := PackedStringArray()
## The chest's colour from an armour palette (outfits.tres's own), or none to
## pick from body_colors below (or keep the everyday cloth colour when that's
## empty too).
@export_enum("none", "cloth", "leather", "mail", "plate") var body_palette := "none"
## The chest's colours to pick from, when there's no palette.
@export var body_colors := PackedColorArray()
## How much darker the chest is than the colour picked.
@export_range(0.0, 1.0) var body_darken := 0.0
## The chest's pattern, one picked (none: the everyday cloth one); in
## OutfitLooks.Pattern's order.
@export_custom(PROPERTY_HINT_TYPE_STRING, "2/2:None,Weave,Quilted,Stripes,Leather,Studded,Tooled,Chain,Scale,Plate,Banded,Wood,Planks,Wrap,Brushed,Hammered")
var body_patterns: Array[int] = []
## The legs the chest's colour (a robe or a suit of armour) rather than leather.
@export var legs_like_body := false
## How much darker those legs are.
@export_range(0.0, 1.0) var legs_darken := 0.0
## The legs the chest's pattern rather than leather's.
@export var legs_pattern_like_body := false
