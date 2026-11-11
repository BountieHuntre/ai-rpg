class_name World
extends Node3D
## One continent's zones, side by side, with the sky and sun they share. The
## game has two continents (docs/world/), each a world of its own: only the
## zones of the continent the character is on are built (CONTINENTS), as
## children made when the World enters the tree. A point belongs to the zone
## whose square holds it. What's asked of "the world" (the ground's height,
## named places, creature spawns, walled places) is answered from the zone in
## question, or from all of them together.

## Each continent's zones: zone name -> scene. A zone whose scene isn't there
## yet is left out.
const CONTINENTS := {
	"aldmark": {
		"Ashford Vale": "res://scenes/levels/ashford_vale/ashford_vale.tscn",
		"Harrowfield": "res://scenes/levels/harrowfield/harrowfield.tscn",
	},
	"kareth": {
		"Emberhollow": "res://scenes/levels/emberhollow/emberhollow.tscn",
		"Redsand Coast": "res://scenes/levels/redsand_coast/redsand_coast.tscn",
	},
}
const DEFAULT_CONTINENT := "aldmark"
## Where each race begins: the Alliance in Ashford Vale, the Horde in
## Emberhollow (until the Undead's and Hornkin's own valleys are built).
## A start whose zone isn't built yet falls back to Ashford Vale.
const START_ZONES := {
	ClassicData.Race.HUMAN: "Ashford Vale", ClassicData.Race.DWARF: "Ashford Vale",
	ClassicData.Race.GNOME: "Ashford Vale", ClassicData.Race.NIGHT_ELF: "Ashford Vale",
	ClassicData.Race.ORC: "Emberhollow", ClassicData.Race.TROLL: "Emberhollow",
	ClassicData.Race.UNDEAD: "Emberhollow", ClassicData.Race.TAUREN: "Emberhollow",
}
const FALLBACK_START := "Ashford Vale"

var zones: Array[Zone] = []
## The continent built here (CONTINENTS).
var continent := DEFAULT_CONTINENT
## The world in play, for what needs the ground's height without a path to it.
static var current: World


func _enter_tree() -> void:
	current = self
	if zones.is_empty():
		build(continent_for(GameState.player_state, GameState.race))


## Makes the zones of a continent (once, before any are there).
func build(which: String) -> void:
	continent = which if CONTINENTS.has(which) else DEFAULT_CONTINENT
	for zone_name: String in CONTINENTS[continent]:
		var path: String = CONTINENTS[continent][zone_name]
		if ResourceLoader.exists(path):
			add_child(load(path).instantiate())


## Whether a zone's scene exists (it's built).
static func zone_exists(zone_name: String) -> bool:
	var which := continent_of(zone_name)
	return which != "" and ResourceLoader.exists(CONTINENTS[which][zone_name])


## The continent a zone is on, or "" for none.
static func continent_of(zone_name: String) -> String:
	for which: String in CONTINENTS:
		for each: String in CONTINENTS[which]:
			if each.to_lower() == zone_name.to_lower():
				return which
	return ""


## Every zone's name, on every continent, built or not.
static func all_zone_names() -> Array[String]:
	var names: Array[String] = []
	for which: String in CONTINENTS:
		for each: String in CONTINENTS[which]:
			names.append(each)
	return names


## The zone a race begins in (built).
static func start_zone(race: int) -> String:
	var zone_name: String = START_ZONES.get(race, FALLBACK_START)
	return zone_name if zone_exists(zone_name) else FALLBACK_START


## The continent a saved player is on: the save's, else the race's start's
## for a new character, else (saves from before continents) Aldmark.
static func continent_for(player_state: Dictionary, race: int) -> String:
	if player_state.has("continent") and CONTINENTS.has(str(player_state.continent)):
		return str(player_state.continent)
	if player_state.is_empty():
		return continent_of(start_zone(race))
	return DEFAULT_CONTINENT


## The race's start zone here, or else this continent's first zone.
func start_zone_here(race: int) -> Zone:
	var zone := zone_named(start_zone(race))
	return zone if zone else zones[0]


func _exit_tree() -> void:
	if current == self:
		current = null


func _init() -> void:
	child_entered_tree.connect(func(node: Node) -> void:
		if node is Zone and not zones.has(node):
			zones.append(node)
	)


## The zone a point is in: the one whose square holds it, else the nearest.
func zone_at(point: Vector3) -> Zone:
	var flat := Vector2(point.x, point.z)
	var best: Zone = null
	var best_distance := INF
	for zone in zones:
		if zone.contains(flat):
			return zone
		var distance := zone.center.distance_to(flat)
		if distance < best_distance:
			best_distance = distance
			best = zone
	return best


func zone_named(zone_name: String) -> Zone:
	for zone in zones:
		if zone.zone_name.to_lower() == zone_name.to_lower():
			return zone
	return null


func height_at(x: float, z: float) -> float:
	return zone_at(Vector3(x, 0, z)).ground_height(x, z)


func set_clutter(level: String) -> void:
	for zone in zones:
		zone.set_clutter(level)


## Every zone's named places, spawns and walled places.
func places() -> Array:
	var all := []
	for zone in zones:
		all.append_array(zone.places)
	return all


func spawns() -> Array:
	var all := []
	for zone in zones:
		all.append_array(zone.spawns)
	return all


func enclosures() -> Array:
	var all := []
	for zone in zones:
		all.append_array(zone.enclosures)
	return all


## The points of the pass between two zones, from the first to the second,
## or empty if no pass joins them.
func pass_between(from: Zone, to: Zone) -> Array[Vector2]:
	for each: Dictionary in Zone.PASSES.get(continent, []):
		var line: Array = each.line
		var first: Vector2 = line[0]
		var last: Vector2 = line[line.size() - 1]
		var points: Array[Vector2] = []
		points.assign(line)
		if from.contains(first) and to.contains(last):
			return points
		if from.contains(last) and to.contains(first):
			points.reverse()
			return points
	return []
