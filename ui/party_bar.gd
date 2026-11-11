class_name PartyBar
extends Control
## Orders for the playerbots in your party, as a bar of icons above the menu
## buttons (MicroMenu), like classic's pet bar. It shows while you have a
## party; K (the `party_commands` action) or its menu button hides and shows
## it (the `party_bar_shown` option). It takes no keys. Rows, from the bottom:
##   orders for the member picked (or everyone): Follow, Stay, Attack (your
##   target, Bot.order_attack), how it fights (click to go through Assist,
##   Defend and Passive, Bot.behavior), Sell to a vendor near you (click:
##   junk, right-click: everything in its bag), Train at its trainer near you,
##   Bag (its BotBagWindow), Rest;
##   its buffs, a slot per category of its class (Bot.BUFF_CATEGORIES) showing
##   the spell it keeps up: click for the choices (Auto, each it knows, None)
##   in a column above, right-click for Auto;
##   the members' portraits and Everyone, to pick whom the orders are for.
## Hover anything for what it does. Sizes in HUD units times ui_scale.

signal message(text: String, is_error: bool)
signal bag_requested(bot: Bot)

const SLOT := 12.0
const GAP := 1.0
## Room between the menu buttons and the bar, and between its rows.
const ROW_GAP := 2.0
## Yards from you a vendor or trainer may be for Sell and Train.
const NEAR := 30.0
const MODE_ICONS := { "Assist": "strike", "Defend": "aegis", "Passive": "mind_calm" }
const MODE_TEXT := {
	"Assist": "Assist: fights what you fight.",
	"Defend": "Defend: fights what attacks the party.",
	"Passive": "Passive: only fights back.",
}
const EVERYONE := "Everyone"
## A role's picture and what it does.
const ROLE_ICONS := { "Tank": "shield_common", "Healer": "heal_gold", "Damage": "strike_red" }
const ROLE_TEXT := {
	"Tank": "Tank: holds the enemies' attention and takes the hits.",
	"Healer": "Healer: keeps the party alive first.",
	"Damage": "Damage: fights all out, healing only in an emergency.",
}
const DIM := Color(0.45, 0.45, 0.45)
const LIT := Color(1, 0.85, 0.4)

var _player: Player
var _tooltip: ItemTooltip
var _ui_scale := 1.0
var _left := 0.0
var _right := 0.0
var _bottom := 0.0
## Whom the orders are for: a member, or null for everyone.
var _picked: Bot
var _everyone := false
var _shown := ""
var _refresh_left := 0.0
## The buff choices open above a slot: [category] or [].
var _flyout: Array = []
## Where the open category's slot is: [bot, category, x, known, choice].
var _open_at: Array = []


func setup(player: Player, ui_scale: float, tooltip: ItemTooltip, menu: MicroMenu) -> void:
	_player = player
	_ui_scale = ui_scale
	_tooltip = tooltip
	_left = menu.left_edge
	_right = menu.right_edge
	_bottom = menu.top - ROW_GAP
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Party.changed.connect(_rebuild)
	_rebuild()


func toggle() -> void:
	Settings.set_value("party_bar_shown", not Settings.get_value("party_bar_shown"))
	Settings.save()
	_rebuild()


func is_shown() -> bool:
	return visible


func close() -> bool:
	if _flyout.is_empty():
		return false
	_flyout = []
	_rebuild()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if Settings.pressed(event, "party_commands"):
		toggle()
		get_viewport().set_input_as_handled()


## A click anywhere else closes the buff choices.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and not _flyout.is_empty():
		var over := false
		for child in get_children():
			if child is Control and (child as Control).get_global_rect().has_point(click.global_position):
				over = true
		if not over:
			_flyout = []
			_rebuild.call_deferred()


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 0.25
	if _snapshot() != _shown:
		_rebuild()


func _members() -> Array[Bot]:
	var list: Array[Bot] = []
	for bot in Party.members:
		if is_instance_valid(bot):
			list.append(bot)
	return list


## The members the orders are for.
func _targets() -> Array[Bot]:
	if _everyone or _picked == null:
		return _members()
	return [_picked]


## Everything the bar shows: a change redraws it.
func _snapshot() -> String:
	var parts := PackedStringArray([str(Settings.get_value("party_bar_shown")), str(_everyone), str(_flyout),
		str(_near_vendor() != null)])
	for bot in _members():
		var options := PackedStringArray()
		for category: String in Bot.BUFF_CATEGORIES.get(bot.profile.char_class, []):
			options.append("%s=%s:%s" % [category, bot.buff_choice(category), ",".join(bot.buff_options(category))])
		parts.append("%s %s %s %d %d %s %s %s %d %s %s" % [bot.role, bot.current_role(), bot.profile.char_name, bot.profile.level, bot.command, bot.fight_mode(),
			bot.errand(), str(bot == _picked), bot.spells_to_train().size(), str(_near_trainer(bot) != null), ";".join(options)])
	return "|".join(parts)


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var members := _members()
	if _picked != null and not members.has(_picked):
		_picked = null
	if _picked == null and not _everyone and not members.is_empty():
		_picked = members[0]
	visible = not members.is_empty() and Settings.get_value("party_bar_shown")
	_shown = _snapshot()
	if not visible:
		return
	var targets := _targets()
	var one: Bot = _picked if not _everyone else null
	_open_at = []
	# Orders, the bottom row.
	var y := _bottom - SLOT
	var x := _left
	var following := targets.all(func(bot: Bot) -> bool: return bot.command == Bot.Command.FOLLOW)
	var staying := targets.all(func(bot: Bot) -> bool: return bot.command == Bot.Command.STAY)
	x = _slot(x, y, "charge", following, true, ["Follow", "Follow you."], func(_right_click: bool) -> void:
		for bot in _targets():
			bot.follow())
	x = _slot(x, y, "ground", staying, true, ["Stay", "Stay where %s." % ("they are" if one == null else "it is")], func(_right_click: bool) -> void:
		for bot in _targets():
			bot.stay())
	x = _slot(x, y, "attack", false, true, ["Attack", "Attack your target."], _attack)
	var mode: String = targets[0].fight_mode() if not targets.is_empty() else "Defend"
	x = _slot(x, y, MODE_ICONS[mode], false, true, [mode, MODE_TEXT[mode], "Click for the next way to fight."], func(right_click: bool) -> void:
		var next: String = Bot.BEHAVIORS[(Bot.BEHAVIORS.find(mode) + (Bot.BEHAVIORS.size() - 1 if right_click else 1)) % Bot.BEHAVIORS.size()]
		for bot in _targets():
			bot.behavior = next)
	# Its role, for one member whose class has more than one.
	if one and one.roles().size() > 1:
		x = _role_slot(one, x, y)
	var vendor := _near_vendor()
	x = _slot(x, y, "coin", false, vendor != null,
		["Sell", "Sell junk to %s.\nRight-click: sell everything in the bag." % vendor.npc_name if vendor else "Stand near a vendor to sell."], _sell)
	var wanted := 0
	var trainable := false
	for bot in targets:
		var count := bot.spells_to_train().size()
		wanted += count
		trainable = trainable or (count > 0 and _near_trainer(bot) != null)
	var train_text := "Nothing new to learn."
	if wanted > 0:
		train_text = ("Learn new spells (%d) at the trainer." % wanted) if trainable else "%d spell%s to learn: stand near a trainer for %s." % [wanted, "" if wanted == 1 else "s", "its class" if one else "their classes"]
		if one:
			train_text += "\nCosts %s." % ItemDB.money_text(one.training_cost())
	var train_box := _slot_box(x, y)
	x = _slot(x, y, "book", wanted > 0, trainable, ["Train", train_text], _train, train_box)
	if wanted > 0:
		UiStyle.count_label(train_box, wanted, _ui_scale, 5)
	if one:
		x = _slot(x, y, "bag_brown", false, true, ["%s's Bags" % one.profile.char_name, "Give, take and equip items."], func(_right_click: bool) -> void: bag_requested.emit(one))
	x = _slot(x, y, "bread", targets.any(func(bot: Bot) -> bool: return bot.sitting), true, ["Rest", "Eat and drink now."], func(_right_click: bool) -> void:
		for bot in _targets():
			if not bot.rest():
				message.emit("%s can't rest in a fight." % bot.profile.char_name, true))
	# Buffs, for one member.
	if one and Bot.BUFF_CATEGORIES.has(one.profile.char_class):
		y -= SLOT + ROW_GAP
		x = _left
		for category: String in Bot.BUFF_CATEGORIES[one.profile.char_class]:
			x = _buff_slot(one, category, x, y)
	# Whom for: portraits, then Everyone.
	y -= SLOT + ROW_GAP
	x = _left
	for bot in members:
		x = _portrait(bot, x, y)
	if members.size() > 1:
		_slot(x, y, "token", _everyone, true, [EVERYONE, "Give orders to the whole party."], func(_right_click: bool) -> void:
			_everyone = true
			_flyout = []
			_rebuild())
	_draw_flyout(y - ROW_GAP + GAP)


func _slot_box(x: float, y: float) -> Control:
	var box := Control.new()
	box.position = Vector2(x, y) * _ui_scale
	box.size = Vector2.ONE * SLOT * _ui_scale
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	return box


## An icon button; `lit` frames it gold, `enabled` false greys it. Returns
## the x after it.
func _slot(x: float, y: float, key: String, lit: bool, enabled: bool, lines: Array, pressed: Callable, box: Control = null) -> float:
	if box == null:
		box = _slot_box(x, y)
	UiStyle.frame_box(box, _ui_scale)
	var view := UiStyle.icon(box, Icons.texture(key), maxf(roundf(_ui_scale * 1.2), 2.0))
	_finish(box, view, lit, enabled, lines, pressed)
	return x + SLOT + GAP


func _finish(box: Control, view: Control, lit: bool, enabled: bool, lines: Array, pressed: Callable) -> void:
	if not enabled:
		view.modulate = DIM
	if lit:
		var edge := ReferenceRect.new()
		edge.border_color = LIT
		edge.border_width = maxf(_ui_scale * 0.8, 1.0)
		edge.editor_only = false
		edge.size = box.size
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(edge)
	var tip: Array = []
	for i in lines.size():
		for line: String in str(lines[i]).split("\n"):
			tip.append([line, "", Color.WHITE if i == 0 else Color(0.85, 0.8, 0.65)])
	box.mouse_entered.connect(func() -> void: _tooltip.show_lines(tip))
	box.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
	box.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click == null or not click.pressed or not click.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			return
		accept_event()
		if enabled:
			pressed.call(click.button_index == MOUSE_BUTTON_RIGHT)
			_rebuild.call_deferred())


## The member's role: click for the next its class can play (Auto, then
## each), right-click for Auto. Auto shows the role it takes, marked A.
func _role_slot(bot: Bot, x: float, y: float) -> float:
	var shown := bot.current_role()
	var box := _slot_box(x, y)
	var choices: Array = [""] + bot.roles()
	var lines := ["Role: %s%s" % [shown, " (Auto)" if bot.role.is_empty() else ""], ROLE_TEXT.get(shown, ""),
		"Click for the next role, right-click for Auto. Its talents follow its role."]
	x = _slot(x, y, ROLE_ICONS.get(shown, "strike"), false, true, lines, func(right_click: bool) -> void:
		if right_click:
			bot.set_role("")
		else:
			bot.set_role(choices[(choices.find(bot.role) + 1) % choices.size()]), box)
	if bot.role.is_empty():
		_corner(box, "A")
	return x


func _portrait(bot: Bot, x: float, y: float) -> float:
	var picked := bot == _picked and not _everyone
	return _slot(x, y, Icons.portrait_key(bot), picked, true,
		["%s" % bot.profile.char_name, "Level %d %s" % [bot.profile.level, ClassicData.CLASS_NAMES.get(bot.profile.char_class, "")], "Click to give it orders."],
		func(_right_click: bool) -> void:
			_picked = bot
			_everyone = false
			_flyout = [])


## A buff category's slot: the spell kept up (Auto shows what it would
## choose, marked A; None an empty slot), and its choices above when open.
func _buff_slot(bot: Bot, category: String, x: float, y: float) -> float:
	var known := bot.buff_options(category)
	var choice := bot.buff_choice(category)
	var box := _slot_box(x, y)
	var shown := choice
	if choice == "Auto":
		shown = _auto_pick(bot, category, known)
	var view: Control
	if shown == "None" or shown.is_empty():
		UiStyle.frame_box(box, _ui_scale)
		view = _letter(box, category.substr(0, 1))
	else:
		UiStyle.spell_icon(box, bot.profile.best_rank(shown), _ui_scale)
		view = box.get_child(box.get_child_count() - 1)
	if choice == "Auto" and not known.is_empty():
		_corner(box, "A")
	var open := _flyout == [category]
	var lines := ["%s: %s" % [category, choice], "Which %s %s keeps up." % [category.to_lower(), bot.profile.char_name],
		"It knows none yet." if known.is_empty() else "Click to choose. Right-click: Auto."]
	_finish(box, view, open, not known.is_empty(), lines, func(right_click: bool) -> void:
		if right_click:
			bot.buff_choices.erase(category)
			_flyout = []
		else:
			_flyout = [] if open else [category])
	if open:
		_open_at = [bot, category, x, known, choice]
	return x + SLOT + GAP


## The open category's choices, in a column above the whole bar.
func _draw_flyout(top: float) -> void:
	if _open_at.is_empty():
		return
	var bot: Bot = _open_at[0]
	var category: String = _open_at[1]
	var choices: Array[String] = ["Auto"]
	choices.append_array(_open_at[3])
	choices.append("None")
	var y := top
	for each in choices:
		y -= SLOT + GAP
		_choice_slot(bot, category, each, _open_at[2], y, each == _open_at[4])


func _choice_slot(bot: Bot, category: String, choice: String, x: float, y: float, current: bool) -> void:
	var box := _slot_box(x, y)
	var view: Control
	if choice == "Auto" or choice == "None":
		UiStyle.frame_box(box, _ui_scale)
		view = _letter(box, "A" if choice == "Auto" else "-")
	else:
		UiStyle.spell_icon(box, bot.profile.best_rank(choice), _ui_scale)
		view = box.get_child(box.get_child_count() - 1)
	var text: String = { "Auto": "Auto: %s chooses." % bot.profile.char_name, "None": "None: keep none up." }.get(choice, choice)
	_finish(box, view, current, true, [text], func(_right_click: bool) -> void:
		if choice == "Auto":
			bot.buff_choices.erase(category)
		else:
			bot.buff_choices[category] = choice
		_flyout = [])


## What Auto keeps up, for its picture: the first it knows in the order it
## tries them.
static func _auto_pick(bot: Bot, category: String, known: Array[String]) -> String:
	if known.is_empty() or (category == "Warding"):
		return ""
	match category:
		"Presence":
			for name: String in Bot.PRESENCES:
				if name in known:
					return name
		"Oath":
			for name: String in Bot.OATHS:
				if name in known:
					return name
		"Boon":
			return "Boon of Strength" if "Boon of Strength" in known else known[0]
	return known[0]


func _letter(box: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size = box.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(7 * _ui_scale))
	label.add_theme_color_override("font_color", UiStyle.GOLD_BRIGHT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	return label


## A small mark in a slot's top left corner.
func _corner(box: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(1.2, -0.5) * _ui_scale
	label.add_theme_font_size_override("font_size", roundi(5 * _ui_scale))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(roundi(_ui_scale), 2))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)


# Orders.

func _attack(_right_click: bool) -> void:
	var target := _player.targeting.target_combatant()
	if target == null or not target.is_alive() or not target.body is Enemy:
		message.emit("You have no target to attack.", true)
		return
	for bot in _targets():
		bot.order_attack(target)


func _sell(everything: bool) -> void:
	var vendor := _near_vendor()
	if vendor == null:
		message.emit("There's no vendor near you.", true)
		return
	for bot in _targets():
		bot.send_to_vendor(vendor, everything)


func _train(_right_click: bool) -> void:
	var sent := false
	for bot in _targets():
		var trainer := _near_trainer(bot)
		if trainer and not bot.spells_to_train().is_empty():
			bot.send_to_trainer(trainer)
			sent = true
	if not sent:
		message.emit("There's no trainer near you with something new for them.", true)


func _near_vendor() -> Npc:
	return _nearest(func(npc: Npc) -> bool: return npc.vendor != 0)


func _near_trainer(bot: Bot) -> Npc:
	return _nearest(func(npc: Npc) -> bool:
		return SpellDB.TRAINER_CLASSES.get(npc.trainer, -1) == bot.profile.char_class)


func _nearest(test: Callable) -> Npc:
	var best: Npc = null
	var best_distance := NEAR
	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Npc
		if npc == null or not test.call(npc):
			continue
		var distance := npc.global_position.distance_to(_player.global_position)
		if distance <= best_distance:
			best = npc
			best_distance = distance
	return best
