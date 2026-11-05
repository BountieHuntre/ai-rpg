extends Node
## The chat log, like classic's chat frame: say, yell, party, whispers,
## emotes, the numbered channels, and system and loot lines. The HUD's
## ChatFrame shows it; playerbots talk through it (BotChatter). Kept across
## the world reloading after death, but not saved, as in classic.

## A line was added: { "kind", "text", "sender", "channel", "target", "links" },
## links being the item and quest links in the text: { "Name": "item:id" or
## "quest:id" }.
signal line_added(line: Dictionary)
## The player said something (BotChatter answers): kind is "say", "yell",
## "party", "channel" or "whisper"; target is the whispered name or channel number.
signal player_spoke(kind: String, text: String, target: String)

## The channels everyone in the zone is in, numbered as classic numbers them.
const CHANNELS := ["General", "Trade", "LocalDefense", "LookingForGroup"]
## Classic's chat colors.
const COLORS := {
	"say": Color("ffffff"), "yell": Color("ff4040"), "party": Color("aaaaff"),
	"channel": Color("ffc0c0"), "whisper": Color("ff80ff"), "whisper_to": Color("ff80ff"),
	"emote": Color("ff8040"), "system": Color("ffff00"), "loot": Color("00aa00"),
	"error": Color("ff2020"), "dev": Color("99ccff"),
	# Creatures speaking and emoting (classic's monster say and emote).
	"monster_say": Color("ffff9f"), "monster_emote": Color("ffff9f"),
}
## Yards a /say and a /yell carry (classic's listen ranges).
const SAY_RANGE := 25.0
const YELL_RANGE := 300.0
const MAX_LINES := 200

var lines: Array[Dictionary] = []
## Who last whispered the player, for /r.
var last_whisper_from := ""


func channel_name(number: int) -> String:
	return CHANNELS[number - 1] if number >= 1 and number <= CHANNELS.size() else ""


## A channel as the chat shows it: "1. General". General and LocalDefense
## are still the zone's own channels, only the tag leaves the zone out.
func channel_title(number: int) -> String:
	return "%d. %s" % [number, channel_name(number)]


func add(kind: String, text: String, sender := "", channel := 0, target := "", links := {}) -> void:
	var line := { "kind": kind, "text": text, "sender": sender, "channel": channel, "target": target, "links": links }
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.pop_front()
	if kind == "whisper":
		last_whisper_from = sender
	line_added.emit(line)


func system(text: String) -> void:
	add("system", text)


## Speech from a unit in the world: heard only within say (or yell) range of
## the player.
func say(sender: String, text: String, at: Vector3, yell := false, links := {}) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(at) > (YELL_RANGE if yell else SAY_RANGE):
		return
	add("yell" if yell else "say", text, sender, 0, "", links)


## A creature's speech or emote ("... tries to run away in fear!"), heard
## within say range.
func monster(sender: String, text: String, at: Vector3, emote := false) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(at) > SAY_RANGE:
		return
	add("monster_emote" if emote else "monster_say", text, sender)


## Links the items and quests in text: every "[Name]" naming a real item or
## a quest's title (in any case) is spelled as it is and linked. Returns
## { "text", "links": { name: "item:id" or "quest:id" } }.
static func link_text(text: String) -> Dictionary:
	var links := {}
	var regex := RegEx.create_from_string("\\[([^\\[\\]]+)\\]")
	for found in regex.search_all(text):
		var named := found.get_string(1)
		var real_name := ""
		var id := ItemDB.find_by_name(named)
		if id != 0:
			real_name = ItemDB.get_item(id).name
			links[real_name] = "item:%d" % id
		else:
			id = quest_by_title(named)
			if id == 0:
				continue
			real_name = QuestDB.get_quest(id).title
			links[real_name] = "quest:%d" % id
		text = text.replace(found.get_string(), "[%s]" % real_name)
	return { "text": text, "links": links }


## A quest's id by its title (any case), or 0.
static func quest_by_title(title: String) -> int:
	for id: int in QuestDB.all_ids():
		if str(QuestDB.get_quest(id).title).to_lower() == title.to_lower():
			return id
	return 0


## One chat line as BBCode: sender names are links (click to whisper,
## right-click for their menu), and so are linked items, in their quality's
## color, and quests, in their difficulty's color (hover for a tooltip). Link metas are "player:Name" and "item:id".
func format(line: Dictionary) -> String:
	var color: Color = COLORS.get(line.kind, Color.WHITE)
	var text := _escape(str(line.text))
	var links: Dictionary = line.get("links", {})
	for link_name: String in links:
		var meta := str(links[link_name])
		var id := int(meta.get_slice(":", 1))
		var shade := Color.WHITE
		if meta.begins_with("item:"):
			shade = ItemDB.quality_color(ItemDB.get_item(id))
		else:
			shade = CombatRules.level_color(GameState.level, int(QuestDB.get_quest(id).get("level", 1)))
		var link := "[url=%s][color=#%s][lb]%s][/color][/url]" % [meta, shade.to_html(false), link_name]
		text = text.replace("[lb]%s]" % link_name, link)
	var sender := str(line.sender)
	var who := "[url=player:%s][lb]%s][/url]" % [sender, sender] if not sender.is_empty() else ""
	var body := ""
	match str(line.kind):
		"say":
			body = "%s says: %s" % [who, text]
		"yell":
			body = "%s yells: %s" % [who, text]
		"party":
			body = "[lb]Party] %s: %s" % [who, text]
		"channel":
			body = "[lb]%s] %s: %s" % [channel_title(int(line.channel)), who, text]
		"whisper":
			body = "%s whispers: %s" % [who, text]
		"whisper_to":
			var target := str(line.target)
			body = "To [url=player:%s][lb]%s][/url]: %s" % [target, target, text]
		"emote":
			body = "%s %s" % [sender, text] if not sender.is_empty() else text
		"monster_say":
			body = "%s says: %s" % [sender, text]
		"monster_emote":
			body = "%s %s" % [sender, text]
		_:
			body = text
	return "[color=#%s]%s[/color]" % [color.to_html(false), body]


## Square brackets in typed text would read as BBCode.
static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
