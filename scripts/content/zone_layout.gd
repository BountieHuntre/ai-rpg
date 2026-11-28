@tool
class_name ZoneLayout
extends Resource
## A zone's layout (data/zones/<zone>.tres, read by ZoneLayouts): its named
## places, flats, hills, stream, roads, woods, creature spawns, chests, quest
## objects, walled places and spell focuses, in world yards. The zone's script
## builds from it (Zone.load_layout puts each list in the script's tables:
## PLACES, FLATS...), and lays out its buildings and props in code. Saved
## while the game runs (editor and debug runs), the zone is rebuilt in place.

## The zone's name, for reading (its script names it).
@export var zone_name := ""
## Named places, smallest first, so a point is in the first place that holds
## it.
@export var places: Array[ZonePlace] = []
## Level areas for camps and towns.
@export var flats: Array[ZoneArea] = []
## Rounded hills.
@export var hills: Array[ZoneArea] = []
## The stream's course, for zones with one.
@export var stream := PackedVector2Array()
@export var roads: Array[ZoneRoad] = []
## Woods: trees thin out toward their edges.
@export var woods: Array[ZonePlace] = []
## Creature spawn groups, in order (new ones last: the order names the
## creatures, and saved corpses).
@export var spawns: Array[ZoneSpawn] = []
@export var chests: Array[ZoneChest] = []
@export var quest_objects: Array[ZoneQuestObject] = []
## Walled places bots go in and out of by their gate.
@export var enclosures: Array[ZoneEnclosure] = []
## Spell focus points.
@export var spell_focuses: Array[ZoneFocus] = []


## The lists in the shapes the zone scripts' tables had, by table name.
func tables() -> Dictionary:
	return {
		"PLACES": places.map(func(p: ZonePlace) -> Array: return [p.name, p.center, p.radius]),
		"FLATS": flats.map(func(f: ZoneArea) -> Array: return [f.center, f.radius, f.height]),
		"HILLS": hills.map(func(h: ZoneArea) -> Array: return [h.center, h.radius, h.height]),
		"STREAM": Array(stream),
		"ROADS": roads.map(func(r: ZoneRoad) -> Array: return Array(r.points)),
		"WOODS": woods.map(func(w: ZonePlace) -> Array: return [w.center, w.radius]),
		"SPAWNS": spawns.map(func(s: ZoneSpawn) -> Array: return [s.entry, s.center, s.radius, s.count]),
		"CHESTS": chests.map(func(c: ZoneChest) -> Array: return [c.entry, c.center, c.radius, c.count]),
		"QUEST_OBJECTS": quest_objects.map(func(q: ZoneQuestObject) -> Array: return [q.entry, q.node_name, q.at, q.facing]),
		"ENCLOSURES": enclosures.map(func(e: ZoneEnclosure) -> Array:
			return [e.least.x, e.least.y, e.most.x, e.most.y, e.outside, e.inside]),
		"SPELL_FOCUSES": spell_focuses.map(func(f: ZoneFocus) -> Array: return [f.entry, f.at]),
	}


## The index of the flat the code names `key` (ZoneArea.key), or -1.
func flat_index(key: String) -> int:
	for i in flats.size():
		if flats[i].key == key:
			return i
	return -1
