@tool
class_name IconWord
extends Resource
## A word and the icon it picks (IconMaps' ordered lists).

## The word looked for in the name.
@export var word := "":
	set(value):
		word = value
		resource_name = "%s: %s" % [word, icon]
## The icon key (a PNG in assets/icons/).
@export var icon := "":
	set(value):
		icon = value
		resource_name = "%s: %s" % [word, icon]


static func make(word_text: String, icon_key: String) -> IconWord:
	var entry := IconWord.new()
	entry.word = word_text
	entry.icon = icon_key
	return entry
