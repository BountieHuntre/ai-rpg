class_name DevConsole
extends Control
## Developer console, toggled with the ` key (under Esc). Type `help` for the
## commands. Items and spells can be given by id or by (part of) their name.
## Sizes are in HUD units (1/270 of the window height), times the UI scale.

const FONT_SIZE := 7
const HEIGHT := 110.0
const MAX_LINES := 200
const BACK := Color(0.02, 0.02, 0.05, 0.88)
const ECHO := Color(0.6, 0.8, 1)
const ERROR := Color(1, 0.4, 0.35)

const COMMANDS := {
	"help": ["", "List the commands."],
	"additem": ["<id or name> [count]", "Put items in your bags."],
	"money": ["<copper, or 1g2s3c>", "Give money (negative takes it)."],
	"level": ["<1-60>", "Set your level."],
	"xp": ["<amount>", "Gain experience."],
	"heal": ["", "Full health and mana."],
	"god": ["", "Toggle taking no damage."],
	"kill": ["", "Kill your target."],
	"learn": ["<id or name>", "Learn a spell (the highest rank for a name)."],
	"trainall": ["", "Learn every spell your class trainer teaches at your level, for free."],
	"resettalents": ["", "Take back every talent point, for free."],
	"bis": ["", "Put on the best gear in the game for your class and level (BiS)."],
	"reset": ["confirm", "Start this character over at level 1 (keeps name, race and class)."],
	"speed": ["<multiplier>", "Scale your run speed (1 is normal)."],
	"tele": ["<x> <z> | spawn | <zone>", "Teleport to a map point, the start, or a zone's graveyard (ashford, harrowfield)."],
	"pos": ["", "Show your position."],
	"repair": ["", "Repair all your gear for free."],
	"respawn": ["", "Bring back every dead creature."],
	"spawn": ["[level] [normal | elite | boss]", "Spawn a random creature ahead of you, just outside its aggro range (your level and normal if left out)."],
	"save": ["", "Save the game now."],
	"clear": ["", "Clear the console."],
	"reload": ["", "Save, restart the game and come back in, picking up any changes."],
	"shipdefaults": ["[keys | clear]", "Make your current options the defaults release builds start with (editor only); keys includes key bindings."],
	"bots": ["", "List the playerbots in the world."],
	"invite": ["[name]", "Invite a playerbot (or your target) to your party."],
	"uninvite": ["<name>", "Remove a playerbot from your party."],
	"disband": ["", "Remove every playerbot from your party."],
	"summon": ["", "Bring your party's bots to you."],
	"randomizebots": ["", "Delete every playerbot but your party and friends, and make new random ones."],
}

var _player: Player
var _world: World
## Creatures made by "spawn", for their names.
var _spawned := 0
const SPAWN_RANKS := { "normal": Enemy.RANK_NORMAL, "elite": Enemy.RANK_ELITE, "boss": Enemy.RANK_BOSS }
var _save: Callable
var _bots: BotManager
var _ui_scale := 1.0
var _log := RichTextLabel.new()
var _entry := LineEdit.new()
var _history: Array[String] = []
var _history_index := 0


func setup(player: Player, world: World, save: Callable, bots: BotManager = null) -> void:
	_player = player
	_world = world
	_save = save
	_bots = bots
	add_to_group("dev_console")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := ColorRect.new()
	panel.color = BACK
	panel.name = "Panel"
	add_child(panel)
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(_log)
	_entry.placeholder_text = "Type a command, or help"
	_entry.text_submitted.connect(_on_submitted)
	_entry.gui_input.connect(_on_input_key)
	panel.add_child(_entry)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false
	_print("Developer console. Type help for the commands.", ECHO)


func _layout() -> void:
	var window := get_viewport_rect().size
	_ui_scale = Settings.hud_scale(window.y)
	var panel: ColorRect = get_node("Panel")
	panel.size = Vector2(window.x, HEIGHT * _ui_scale)
	var line := roundi((FONT_SIZE + 5) * _ui_scale)
	_log.position = Vector2(4, 2) * _ui_scale
	_log.size = Vector2(window.x - 8 * _ui_scale, panel.size.y - line - 4 * _ui_scale)
	_log.add_theme_font_size_override("normal_font_size", roundi(FONT_SIZE * _ui_scale))
	_entry.position = Vector2(2 * _ui_scale, panel.size.y - line - _ui_scale)
	_entry.size = Vector2(window.x - 4 * _ui_scale, line)
	_entry.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))


func is_open() -> bool:
	return visible


func toggle() -> void:
	visible = not visible
	_player.typing = visible
	if visible:
		_entry.grab_focus.call_deferred()
	else:
		_entry.release_focus()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_QUOTELEFT:
		# No console in release builds.
		if not Settings.developer_tools():
			return
		# The Developer options can turn the console off; it can always close.
		if visible or Settings.get_value("dev_console"):
			toggle()
		get_viewport().set_input_as_handled()
	elif visible and key and key.pressed and key.physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


## Up and Down step through earlier commands.
func _on_input_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or _history.is_empty():
		return
	if key.physical_keycode == KEY_UP:
		_history_index = maxi(_history_index - 1, 0)
	elif key.physical_keycode == KEY_DOWN:
		_history_index = mini(_history_index + 1, _history.size())
	else:
		return
	_entry.text = _history[_history_index] if _history_index < _history.size() else ""
	_entry.caret_column = _entry.text.length()
	_entry.accept_event()


func _on_submitted(text: String) -> void:
	_entry.clear()
	text = text.strip_edges()
	if text.is_empty():
		return
	_history.append(text)
	_history_index = _history.size()
	_print("> " + text, Color(0.8, 0.8, 0.8))
	run(text)


## Runs one command line, prints its result here and returns it (errors start
## with "!"). The Options window's Developer tab runs commands through this too.
func run(text: String) -> String:
	var words := text.split(" ", false)
	if words.is_empty():
		return ""
	var command := words[0].to_lower()
	var args := words.slice(1)
	if not COMMANDS.has(command):
		var unknown := "!Unknown command \"%s\". Type help for the list." % command
		_print(unknown, ERROR, true)
		return unknown
	var result: String = call("_cmd_" + command, args)
	if not result.is_empty():
		_print(result, ERROR if result.begins_with("!") else Color.WHITE, result.begins_with("!"))
	return result


func player() -> Player:
	return _player


func _print(text: String, color: Color, strip_mark := false) -> void:
	if strip_mark:
		text = text.substr(1)
	_log.push_color(color)
	_log.add_text(text + "\n")
	_log.pop()
	if _log.get_paragraph_count() > MAX_LINES:
		_log.remove_paragraph(0)


# Commands. Each returns text to show; text starting with "!" is an error.

func _cmd_help(_args: PackedStringArray) -> String:
	var lines := PackedStringArray()
	for name: String in COMMANDS:
		lines.append(" ".join([name, COMMANDS[name][0]]).strip_edges() + " - " + COMMANDS[name][1])
	return "\n".join(lines)


func _cmd_additem(args: PackedStringArray) -> String:
	if args.is_empty():
		return "!Usage: additem <id or name> [count]"
	var count := 1
	if args.size() > 1 and args[-1].is_valid_int():
		count = maxi(int(args[-1]), 1)
		args = args.slice(0, -1)
	var id := _find_item(" ".join(args))
	if id == 0:
		return "!No item matches \"%s\"." % " ".join(args)
	var left := Inventory.add_item(id, count)
	var name: String = ItemDB.get_item(id).name
	if left >= count:
		return "!Your bags are full."
	return "Added %d %s (%d)%s." % [count - left, name, id, ", bags full" if left > 0 else ""]


func _find_item(query: String) -> int:
	if query.is_valid_int():
		return int(query) if not ItemDB.get_item(int(query)).is_empty() else 0
	ItemDB.get_item(0)
	return _best_match(ItemDB._items, query, "name")


func _cmd_money(args: PackedStringArray) -> String:
	if args.is_empty():
		return "You have %s." % ItemDB.money_text(GameState.money)
	var copper := _parse_money("".join(args))
	if copper == 0:
		return "!Usage: money <copper, or 1g2s3c>"
	GameState.money = maxi(GameState.money + copper, 0)
	return "You have %s." % ItemDB.money_text(GameState.money)


static func _parse_money(text: String) -> int:
	text = text.to_lower()
	if text.is_valid_int():
		return int(text)
	var sign := -1 if text.begins_with("-") else 1
	var total := 0
	var regex := RegEx.create_from_string("(\\d+)([gsc])")
	for found in regex.search_all(text):
		total += int(found.get_string(1)) * { "g": 10000, "s": 100, "c": 1 }[found.get_string(2)]
	return total * sign


func _cmd_level(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_int():
		return "!Usage: level <1-%d>" % ClassicData.MAX_LEVEL
	var level := clampi(int(args[0]), 1, ClassicData.MAX_LEVEL)
	GameState.level = level
	GameState.xp = 0
	_player.stats.refresh()
	_player.combatant.health = _player.combatant.max_health
	if _player.combatant.has_mana():
		_player.combatant.mana = _player.combatant.max_mana
	_player.progression.leveled_up.emit(level)
	return "You are now level %d." % level


func _cmd_xp(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_int():
		return "!Usage: xp <amount>"
	_player.progression.add_xp(int(args[0]))
	return "Level %d, %d / %d XP." % [GameState.level, GameState.xp, _player.progression.xp_to_next()]


func _cmd_heal(_args: PackedStringArray) -> String:
	var c := _player.combatant
	if not c.is_alive():
		return "!You are dead."
	c.health = c.max_health
	c.mana = c.max_mana
	return "Fully healed."


func _cmd_god(_args: PackedStringArray) -> String:
	_player.combatant.invulnerable = not _player.combatant.invulnerable
	return "God mode %s." % ("on" if _player.combatant.invulnerable else "off")


func _cmd_kill(_args: PackedStringArray) -> String:
	var target := _player.targeting.target_combatant()
	if target == null or not target.is_alive():
		return "!You have no living target."
	target.take_damage(target.health, _player.combatant)
	return "Killed %s." % target.display_name


func _cmd_learn(args: PackedStringArray) -> String:
	if args.is_empty():
		return "!Usage: learn <id or name>"
	var query := " ".join(args)
	var id := 0
	if query.is_valid_int():
		id = int(query) if not SpellDB.get_spell(int(query)).is_empty() else 0
	else:
		id = _best_match(SpellDB._get_data().spells, query, "SpellName", "SpellLevel")
	if id == 0:
		return "!No spell matches \"%s\"." % query
	var learned := SpellCaster.learn([id])
	if learned.is_empty():
		return "You already know %s." % SpellDB.full_name(SpellDB.get_spell(id))
	return "Learned %s (%d)." % [learned[0], id]


## Everything the class trainer would teach now, rank by rank, as if trained
## in order: the trainer's own rules (level, previous rank, race), no cost.
func _cmd_trainall(_args: PackedStringArray) -> String:
	var list := SpellDB.class_trainer_list(GameState.char_class, GameState.race)
	if list.is_empty():
		return "!Your class has no trainer spells yet."
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.level) < int(b.level))
	var learned: Array[String] = []
	# Learning a rank can make the next one available, so go round until nothing changes.
	var changed := true
	while changed:
		changed = false
		for entry: Dictionary in list:
			if TrainerWindow.entry_state(entry)[0] == "available":
				learned.append_array(SpellCaster.learn(entry.spells))
				changed = true
	if learned.is_empty():
		return "Nothing new to learn at level %d." % GameState.level
	GameState.inventory_changed.emit()
	return "Learned %d spell%s: %s." % [learned.size(), "" if learned.size() == 1 else "s", ", ".join(learned)]


func _cmd_bis(_args: PackedStringArray) -> String:
	var lines: Array[String] = [_bis_line(BestGear.equip_best(), "You're", "You")]
	# Party bots gear up too, by their own builds.
	for member: Node in Party.members:
		var bot := member as Bot
		if bot == null:
			continue
		var result := BestGear.equip_best(bot.profile, bot.bag)
		bot.stats.refresh()
		lines.append(_bis_line(result, "%s is" % bot.profile.char_name, bot.profile.char_name))
	return "
".join(lines)


func _bis_line(result: Dictionary, who_is: String, who: String) -> String:
	var equipped: Array = result.equipped
	var note := " (%d left off: no bag room for what they'd replace)" % result.no_room if result.no_room > 0 else ""
	var build := " for %s" % result.tree if not str(result.tree).is_empty() else ""
	if equipped.is_empty():
		return "%s already in the best gear%s%s." % [who_is, build, note]
	return "%s equipped %d item%s%s: %s%s." % [who, equipped.size(), "" if equipped.size() == 1 else "s", build, ", ".join(equipped), note]


func _cmd_resettalents(_args: PackedStringArray) -> String:
	var spent := Talents.spent(GameState)
	Talents.reset(GameState)
	GameState.inventory_changed.emit()
	return "Took back %d talent point%s." % [spent, "" if spent == 1 else "s"]


## Starts the character over, as Shift+F12 does. Asks for "confirm" first.
func _cmd_reset(args: PackedStringArray) -> String:
	if args.is_empty() or args[0] != "confirm":
		return "!This starts %s over at level 1: items, money, quests and spells are lost. Type \"reset confirm\" to do it." % GameState.char_name
	GameState.reset_character()
	get_tree().reload_current_scene.call_deferred()
	return "Starting %s over." % GameState.char_name


## The id of the entry whose `field` matches the query: an exact name first,
## then the shortest name containing it. Ties go to the highest `rank_field`.
func _best_match(table: Dictionary, query: String, field: String, rank_field := "") -> int:
	query = query.to_lower()
	var best := 0
	var best_score := INF
	for key: String in table:
		var name := str(table[key].get(field, "")).to_lower()
		if not name.contains(query):
			continue
		var rank := int(table[key].get(rank_field, 0)) if not rank_field.is_empty() else 0
		# Exact match, then shorter name, then higher rank.
		var score := (0.0 if name == query else 1e6) + name.length() * 1000.0 - rank
		if score < best_score:
			best = int(key)
			best_score = score
	return best


func _cmd_speed(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_float():
		return "Speed is x%.2f." % _player.speed_scale
	_player.speed_scale = clampf(float(args[0]), 0.1, 20.0)
	return "Speed is x%.2f." % _player.speed_scale


func _cmd_tele(args: PackedStringArray) -> String:
	var at := AshfordVale.SPAWN
	if args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
		var x := float(args[0])
		var z := float(args[1])
		at = Vector3(x, _world.height_at(x, z) + 0.5, z)
	elif args.size() >= 1 and args[0].to_lower() != "spawn":
		var wanted := " ".join(args).to_lower()
		var found: Zone = null
		for zone in _world.zones:
			if zone.zone_name.to_lower().begins_with(wanted):
				found = zone
		if found == null:
			return "!Usage: tele <x> <z>, tele spawn, or tele <zone>"
		at = found.graveyard + Vector3.UP * 0.5
	elif args.size() != 1:
		return "!Usage: tele <x> <z>, tele spawn, or tele <zone>"
	_player.global_position = at
	_player.velocity = Vector3.ZERO
	return "Teleported to %.1f, %.1f." % [at.x, at.z]


## A random creature of the zone's kinds at a level and rank, straight ahead
## and 8 yards beyond the range it would attack from. It stands still, and its
## corpse is gone for good after 5 minutes (it isn't saved).
func _cmd_spawn(args: PackedStringArray) -> String:
	var level := GameState.level
	var rank := Enemy.RANK_NORMAL
	for arg in args:
		var word := arg.to_lower()
		if word.is_valid_int():
			level = clampi(int(word), 1, ClassicData.MAX_LEVEL + 3)
		elif SPAWN_RANKS.has(word):
			rank = SPAWN_RANKS[word]
		else:
			return "!Usage: spawn [level] [normal | elite | boss]"
	var entries := Enemy.creature_entries()
	if entries.is_empty() or _world == null:
		return "!No creatures to spawn here."
	var enemy: Enemy = AshfordVale.ENEMY_SCENE.instantiate()
	enemy.creature_entry = entries.pick_random()
	enemy.level_override = level
	enemy.rank_override = rank
	enemy.temporary = true
	enemy.respawn_override = 300.0
	enemy.wander_override = 0.0
	_spawned += 1
	enemy.name = "Spawned_%d" % _spawned
	# Classic aggro range: 20 yards at the same level, a yard less per level
	# you're above it, a yard more per level below (Enemy.aggro_radius).
	var reach := maxf(20.0 - maxi(GameState.level - level, -25), 5.0) + 8.0
	var at := _player.global_position
	for turn in 8:
		var angle := _player.facing + turn * TAU / 8.0
		var point := _player.global_position + Basis(Vector3.UP, angle) * Vector3.FORWARD * reach
		if _world.height_at(point.x, point.z) > AshfordVale.WATER_LEVEL + 0.3:
			at = Vector3(point.x, _world.height_at(point.x, point.z) + 0.1, point.z)
			break
	enemy.position = at
	var zone := _world.zone_at(at)
	var creatures := zone.get_node_or_null("Creatures") if zone else null
	(creatures if creatures else _world).add_child(enemy)
	var kind := "" if rank == Enemy.RANK_NORMAL else (" boss" if rank == Enemy.RANK_BOSS else " elite")
	return "Spawned a level %d%s %s %d yards away." % [enemy.level, kind, enemy.combatant.display_name, roundi(_player.global_position.distance_to(at))]


func _cmd_pos(_args: PackedStringArray) -> String:
	var p := _player.global_position
	return "x %.1f  y %.1f  z %.1f  facing %d°" % [p.x, p.y, p.z, roundi(rad_to_deg(_player.facing))]


func _cmd_repair(_args: PackedStringArray) -> String:
	var money := GameState.money
	GameState.money += Inventory.repair_all_cost()
	var error := Inventory.repair_all()
	GameState.money = money
	return "!" + error if not error.is_empty() else "All gear repaired."


func _cmd_respawn(_args: PackedStringArray) -> String:
	var count := 0
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.state == Enemy.State.DEAD:
			enemy.respawn_at = 0.0
			count += 1
	return "Respawning %d creatures." % count


func _cmd_shipdefaults(args: PackedStringArray) -> String:
	if "clear" in args:
		return Settings.clear_shipped()
	return Settings.write_shipped("keys" in args)


func _cmd_bots(_args: PackedStringArray) -> String:
	if _bots == null or _bots.bots().is_empty():
		return "No playerbots in the world."
	var lines := PackedStringArray()
	for bot in _bots.bots():
		var where := "party" if Party.is_member(bot) else "%d yd away" % _player.global_position.distance_to(bot.global_position)
		lines.append("%s: level %d %s %s, %s%s" % [
			bot.profile.char_name, bot.profile.level, ClassicData.RACE_NAMES[bot.profile.race],
			ClassicData.CLASS_NAMES[bot.profile.char_class], where, "" if bot.combatant.is_alive() else ", dead",
		])
	return "\n".join(lines)


## A bot named in the arguments, or the targeted one.
func _bot_from(args: PackedStringArray) -> Bot:
	if args.is_empty():
		return _player.targeting.target as Bot
	return _bots.find_bot(args[0]) if _bots else null


func _cmd_invite(args: PackedStringArray) -> String:
	var bot := _bot_from(args)
	if bot == null:
		return "!No such playerbot. Target one, or give a name (see bots)."
	Party.invite(bot)
	return "Invited %s." % bot.profile.char_name


func _cmd_uninvite(args: PackedStringArray) -> String:
	var bot := _bot_from(args)
	if bot == null or not Party.is_member(bot):
		return "!That playerbot isn't in your party."
	Party.remove(bot)
	return "Removed %s." % bot.profile.char_name


func _cmd_disband(_args: PackedStringArray) -> String:
	Party.disband()
	return "Party disbanded."


func _cmd_summon(_args: PackedStringArray) -> String:
	for bot in Party.members:
		bot.global_position = _player.global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2))
		bot.velocity = Vector3.ZERO
	return "Summoned %d bots." % Party.members.size()


func _cmd_randomizebots(_args: PackedStringArray) -> String:
	if _bots == null or not Settings.get_value("bots_enabled"):
		return "!Playerbots are turned off (Options, Playerbots)."
	var deleted := _bots.randomize_bots()
	var made := _bots.bots().filter(func(bot: Bot) -> bool: return not Party.is_member(bot)).size()
	return "Deleted %d bots; %d random bots in the world now (your party and friends kept)." % [deleted, made]


func _cmd_save(_args: PackedStringArray) -> String:
	_save.call()
	return "Saved."


## Saves, starts a fresh copy of the game with the same arguments plus
## `--resume` for this character, and quits, so every change on disk (scripts,
## scenes, data, settings) is picked up. Runs started from the editor lose
## their debugger connection.
func _cmd_reload(_args: PackedStringArray) -> String:
	_save.call()
	var pid := OS.create_process(OS.get_executable_path(), restart_args())
	if pid <= 0:
		return "!Couldn't start a new copy of the game."
	get_tree().quit.call_deferred()
	return "Reloading..."


## The command line for the restarted game: this one's, without the editor's
## debugger, plus `--resume` for the current character.
static func restart_args() -> PackedStringArray:
	var engine_args := PackedStringArray()
	var skip := false
	for arg in OS.get_cmdline_args():
		if skip:
			skip = false
			continue
		# The editor's debugger session doesn't carry over to the new process.
		if arg in ["--remote-debug", "--editor-pid"]:
			skip = true
			continue
		engine_args.append(arg)
	var user_args := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--resume="):
			user_args.append(arg)
	# One-save runs go straight into the world anyway.
	if not GameState.single_save:
		user_args.append("--resume=" + GameState.char_name)
	var args := engine_args
	# Godot takes --path out of the arguments it reports. Running from the
	# project folder (not an exported build), point the new copy at it.
	var project := ProjectSettings.globalize_path("res://")
	if not "--path" in args and not project.is_empty() and FileAccess.file_exists("res://project.godot"):
		args.insert(0, project)
		args.insert(0, "--path")
	if not user_args.is_empty():
		args.append("--")
		args.append_array(user_args)
	return args


func _cmd_clear(_args: PackedStringArray) -> String:
	_log.clear()
	return ""
