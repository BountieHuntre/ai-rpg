@tool
class_name OutfitLooks
extends Resource
## The colours gear and clothes are drawn in (data/looks/outfits.tres, read by
## CharacterLooks): armour palettes, colour words in item names, gems, metal
## and wood, and what each trade's NPCs wear. Saved while the game runs
## (editor and debug runs), every character model re-colours.

## The patterns under gear's colours, in HumanoidModel.Pattern's order.
enum Pattern { NONE, WEAVE, QUILTED, STRIPES, LEATHER, STUDDED, TOOLED, CHAIN, SCALE, PLATE, BANDED, WOOD, PLANKS,
	WRAP, BRUSHED, HAMMERED }

## Armour colours by type, one picked per item.
@export var cloth := PackedColorArray()
@export var leather := PackedColorArray()
@export var mail := PackedColorArray()
@export var plate := PackedColorArray()
## Words in an item's name that set its colour ("crimson", "azure"...).
@export var name_colors: Dictionary[String, Color] = {}
## Gems by item quality (poor, common, uncommon, rare, epic, legendary).
@export var gem_colors := PackedColorArray()
## Bare legs.
@export var smallclothes := Color(0.62, 0.58, 0.5)
## Gilt trim on fine gear.
@export var trim := Color(0.72, 0.56, 0.26)
## Wooden hafts, staves and plain shields.
@export var wood := Color(0.4, 0.26, 0.13)
## Plain steel blades.
@export var steel := Color(0.72, 0.74, 0.78)
## Leather bindings and straps.
@export var strap := Color(0.28, 0.19, 0.11)
## A book's pages, a plain shield's device.
@export var parchment := Color(0.86, 0.8, 0.64)
## What each trade's NPCs wear.
@export var trades: Array[TradeOutfit] = []


## The palette by its name (TradeOutfit.body_palette).
func palette(name: String) -> PackedColorArray:
	match name:
		"cloth":
			return cloth
		"leather":
			return leather
		"mail":
			return mail
		"plate":
			return plate
	return PackedColorArray()


## The outfit for a trade, or null.
func for_trade(trade: String) -> TradeOutfit:
	for outfit in trades:
		if trade in outfit.trades:
			return outfit
	return null
