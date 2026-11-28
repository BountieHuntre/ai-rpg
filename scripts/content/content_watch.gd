extends Node
## Content saved while the game runs takes effect at once (editor and debug
## runs only): the content folders' files are checked every CHECK_EVERY
## seconds, and a changed one is read again (CreatureLooks.reload_file...) and
## applied to what's in the world.

## How often (seconds) the content folders are checked for saved files.
static var CHECK_EVERY := 0.5

## Folders watched, each with the function that applies a saved file.
var _watched := {}
var _times := {}
var _wait := 0.0


func _ready() -> void:
	if not Settings.developer_tools():
		set_process(false)
		return
	_watched = { CreatureLooks.DIR: _creature_saved, CharacterLooks.DIR: _looks_saved, ZoneLayouts.DIR: _zone_saved, "res://data/": _data_saved }
	_scan(true)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_EVERY
	_scan(false)


func _scan(first: bool) -> void:
	for dir: String in _watched:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var path := dir + file
			var time := FileAccess.get_modified_time(path)
			if not first and _times.get(path, -1) != time:
				(_watched[dir] as Callable).call(path)
			_times[path] = time


## A creature's look (or the models' list): living and dead creatures of the
## entries it covers take it.
func _creature_saved(path: String) -> void:
	var entries := CreatureLooks.reload_file(path)
	var count := 0
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.creature_entry in entries:
			enemy.refresh_look()
			count += 1
	Chat.system("Reloaded %s (%d in the world)." % [path.get_file(), count])


## A file straight in data/: the icon maps (data/icons.tres) are read again
## and the interface drawn again with them.
func _data_saved(path: String) -> void:
	if path != IconMaps.PATH:
		return
	IconMaps.reload_file()
	for hud in get_tree().root.find_children("*", "CombatHud", true, false):
		(hud as CombatHud)._build()
	Chat.system("Reloaded %s." % path.get_file())


## A zone's layout: the zone is built again in place (World.rebuild_zone).
func _zone_saved(path: String) -> void:
	var key := ZoneLayouts.reload_file(path)
	var world := World.current
	if not world:
		return
	for zone in world.zones:
		if zone.layout_key() == key:
			Chat.system("Rebuilding %s..." % zone.zone_name)
			var started := Time.get_ticks_msec()
			var fresh := world.rebuild_zone(zone)
			if fresh:
				Chat.system("Rebuilt %s from %s (%.1f s)." % [fresh.zone_name, path.get_file(), (Time.get_ticks_msec() - started) / 1000.0])
			return


## A race's look or the outfits' colours: NPCs pick their trade's outfit
## again, dressed creatures their band's, and every character model
## re-colours.
func _looks_saved(path: String) -> void:
	CharacterLooks.reload_file(path)
	if path == CharacterLooks.OUTFITS_PATH:
		for npc: Npc in get_tree().get_nodes_in_group("npcs"):
			npc.refresh_outfit()
		for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
			var look := CreatureLooks.of(enemy.creature_entry)
			if look and look.dressed:
				enemy.refresh_look()
	var count := 0
	for model in get_tree().get_nodes_in_group("character_models"):
		if model is HumanoidModel:
			(model as HumanoidModel).refresh_looks()
			count += 1
	Chat.system("Reloaded %s (%d models)." % [path.get_file(), count])
