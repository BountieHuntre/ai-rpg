class_name PartyWindow
extends Control
## Orders for the playerbots in your party (K, the `party_commands` action),
## a small window to keep open while playing: it takes no keys, and the game
## goes on around it. A row per member, with:
##   Follow / Stay, Attack (your target), how it fights (Assist your target,
##   Defend the group, Passive), Sell (to a vendor near you: junk or
##   everything in its bag), Train (at its class trainer near you, paid from
##   its money and yours), Bag (its BotBagWindow), Rest (eat and drink now);
##   and a choice per buff category of its class (Bot.BUFF_CATEGORIES:
##   a Templar's Presence, Oath and Boon, a Cleric's Fortitude, Spirit,
##   Warding and own buffs, a Man-at-Arms' Stance and Shout).
## A last row orders everyone at once. Drag it by its title; where it was
## left is the `party_window_pos` option. Sizes in HUD units times ui_scale.

signal message(text: String, is_error: bool)
## Bag pressed for a member.
signal bag_requested(bot: Bot)

const WIDTH := 252.0
const ROW := 34.0
const PAD := 4.0
const FONT_SIZE := 6
const BUTTON_HEIGHT := 9.0
## Yards from you a vendor or trainer may be for Sell and Train.
const NEAR := 30.0
const NAME_COLOR := Color(0.67, 0.67, 1.0)
const DIM := Color(0.6, 0.6, 0.6)
const STATUS := Color(0.85, 0.8, 0.65)
const SELECTOR_WIDTH := 60.0

var _player: Player
var _ui_scale := 1.0
var _screen := Vector2.ZERO
## Per member, the controls its state shows in: { bot: { name: Control } }.
var _rows := {}
var _shown := ""
var _refresh_left := 0.0
var _dragging := false
var _drag_from := Vector2.ZERO


func setup(player: Player, ui_scale: float, screen: Vector2) -> void:
	_player = player
	_ui_scale = ui_scale
	_screen = screen
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	Party.changed.connect(func() -> void:
		if visible:
			_build())


func toggle() -> void:
	visible = not visible
	if visible:
		_build()


func close() -> bool:
	if not visible:
		return false
	visible = false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if Settings.pressed(event, "party_commands"):
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 0.25
	if _snapshot() != _shown:
		_build()
	else:
		_update()


## Who's in the party and what they can choose from: a change rebuilds.
func _snapshot() -> String:
	var parts := PackedStringArray()
	for bot in Party.members:
		if not is_instance_valid(bot):
			continue
		var options := PackedStringArray()
		for category: String in Bot.BUFF_CATEGORIES.get(bot.profile.char_class, []):
			options.append(",".join(bot.buff_options(category)))
		parts.append("%s %d %s" % [bot.profile.char_name, bot.profile.level, ";".join(options)])
	return "|".join(parts)


func _members() -> Array[Bot]:
	var list: Array[Bot] = []
	for bot in Party.members:
		if is_instance_valid(bot):
			list.append(bot)
	return list


func _build() -> void:
	_shown = _snapshot()
	_rows = {}
	for child in get_children():
		child.queue_free()
	var members := _members()
	var height := 14.0 + maxi(members.size(), 1) * ROW + (BUTTON_HEIGHT + 6 if members.size() > 1 else 0.0) + 2
	size = Vector2(WIDTH, height) * _ui_scale
	_place()
	var panel := UiStyle.panel(self, Vector2(WIDTH, height), _ui_scale)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.title(self, Vector2(5, 1.5), "Party Commands", _ui_scale)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, toggle)
	if members.is_empty():
		_text(Vector2(PAD, 16), "No playerbots in your party. Right-click one's\nframe or name to invite it.", DIM)
		return
	var y := 14.0
	for bot in members:
		_member_row(bot, y)
		y += ROW
	if members.size() > 1:
		_text(Vector2(PAD, y + 1), "Everyone:", STATUS)
		var x := PAD + 30
		x = _button("Follow", Vector2(x, y), 30, func() -> void: _for_all(func(bot: Bot) -> void: bot.follow())) + 2
		x = _button("Stay", Vector2(x, y), 26, func() -> void: _for_all(func(bot: Bot) -> void: bot.stay())) + 2
		x = _button("Attack", Vector2(x, y), 30, _attack_all) + 2
		_button("Rest", Vector2(x, y), 24, func() -> void: _for_all(func(bot: Bot) -> void: bot.rest()))
	_update()


func _member_row(bot: Bot, y: float) -> void:
	var row := {}
	_rows[bot] = row
	var class_name_text: String = ClassicData.CLASS_NAMES.get(bot.profile.char_class, "")
	_text(Vector2(PAD, y), "%s" % bot.profile.char_name, NAME_COLOR)
	_text(Vector2(PAD + 44, y), "%d %s" % [bot.profile.level, class_name_text], DIM)
	var status := _text(Vector2(PAD, y), "", STATUS)
	status.size.x = (WIDTH - PAD * 2) * _ui_scale
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.status = status
	# Orders.
	var by := y + 9
	var x := PAD
	var follow := Button.new()
	row.follow = follow
	x = _add_button(follow, "Follow", Vector2(x, by), 32, func() -> void:
		if bot.command == Bot.Command.FOLLOW:
			bot.stay()
		else:
			bot.follow()
		_update()) + 2
	x = _button("Attack", Vector2(x, by), 28, _attack.bind(bot)) + 2
	var mode := OptionButton.new()
	for each: String in Bot.BEHAVIORS:
		mode.add_item(each)
	mode.tooltip_text = "Assist: fights what you fight.\nDefend: fights what attacks the party.\nPassive: only fights back."
	mode.item_selected.connect(func(index: int) -> void: bot.behavior = Bot.BEHAVIORS[index])
	row.mode = mode
	x = _add_control(mode, Vector2(x, by), 40) + 2
	var sell := MenuButton.new()
	sell.text = "Sell"
	sell.flat = false
	sell.get_popup().add_item("Sell Junk", 0)
	sell.get_popup().add_item("Sell Everything in Its Bag", 1)
	sell.get_popup().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	sell.get_popup().id_pressed.connect(func(id: int) -> void: _sell(bot, id == 1))
	row.sell = sell
	x = _add_control(sell, Vector2(x, by), 24) + 2
	var train := Button.new()
	row.train = train
	x = _add_button(train, "Train", Vector2(x, by), 28, _train.bind(bot)) + 2
	x = _button("Bag", Vector2(x, by), 22, func() -> void: bag_requested.emit(bot)) + 2
	_button("Rest", Vector2(x, by), 24, func() -> void:
		if not bot.rest():
			message.emit("%s can't rest in a fight." % bot.profile.char_name, true))
	# Buff choices, one per category of its class.
	var buff_y := by + BUTTON_HEIGHT + 2
	x = PAD
	for category: String in Bot.BUFF_CATEGORIES.get(bot.profile.char_class, []):
		x = _buff_selector(bot, category, Vector2(x, buff_y)) + 2


## A dropdown of a category's choices: Auto, each spell it knows, None.
func _buff_selector(bot: Bot, category: String, at: Vector2) -> float:
	var picker := OptionButton.new()
	var known := bot.buff_options(category)
	var choices: Array[String] = ["Auto"]
	choices.append_array(known)
	choices.append("None")
	var single: bool = (Bot.CATEGORY_SPELLS[category] as Array).size() == 1
	for choice in choices:
		picker.add_item("%s: %s" % [category, _short(choice, category, single)])
	var current := bot.buff_choice(category)
	picker.select(maxi(choices.find(current), 0))
	picker.disabled = known.is_empty()
	picker.tooltip_text = "Which %s %s keeps up.%s" % [category.to_lower(), bot.profile.char_name,
		"\nIt knows none yet." if known.is_empty() else ""]
	picker.item_selected.connect(func(index: int) -> void:
		bot.buff_choices[category] = choices[index]
		if choices[index] == "Auto":
			bot.buff_choices.erase(category))
	return _add_control(picker, at, SELECTOR_WIDTH)


## A spell's name without its category's words: "Bulwark Presence" as
## Bulwark, "Oath of Valor" as Valor, "Greater Boon of Strength" as Greater
## Strength; a one-spell category's as On, and None as Off there.
static func _short(choice: String, category: String, single: bool) -> String:
	if choice == "Auto":
		return choice
	if single:
		return "Off" if choice == "None" else "On"
	return choice.replace(" Presence", "").replace("Oath of the ", "").replace("Oath of ", "").replace("Boon of ", "").replace(" Stance", "")


## Labels and what can be pressed, as things are now.
func _update() -> void:
	var vendor := _near_vendor()
	for bot: Bot in _rows:
		if not is_instance_valid(bot):
			continue
		var row: Dictionary = _rows[bot]
		var following := bot.command == Bot.Command.FOLLOW
		(row.follow as Button).text = "Following" if following else "Staying"
		(row.follow as Button).tooltip_text = "Click to have %s %s." % [bot.profile.char_name, "stay here" if following else "follow you"]
		(row.mode as OptionButton).select(Bot.BEHAVIORS.find(bot.fight_mode()))
		var sell := row.sell as MenuButton
		sell.disabled = vendor == null
		sell.tooltip_text = "Sell to %s." % vendor.npc_name if vendor else "Stand near a vendor to sell."
		var train := row.train as Button
		var trainer := _near_trainer(bot)
		var wanted := bot.spells_to_train().size()
		train.disabled = trainer == null or wanted == 0
		if wanted == 0:
			train.tooltip_text = "Nothing new to learn."
		elif trainer == null:
			train.tooltip_text = "%d spell%s to learn, %s. Stand near a %s trainer." % [wanted, "" if wanted == 1 else "s", ItemDB.money_text(bot.training_cost()), ClassicData.CLASS_NAMES.get(bot.profile.char_class, "")]
		else:
			train.tooltip_text = "Learn %d spell%s from %s for %s." % [wanted, "" if wanted == 1 else "s", trainer.npc_name, ItemDB.money_text(bot.training_cost())]
		(row.status as Label).text = _status(bot)


func _status(bot: Bot) -> String:
	if not bot.combatant.is_alive():
		return "Dead"
	match bot.errand():
		"sell":
			return "Off to sell"
		"train":
			return "Off to train"
	if bot.combatant.is_in_combat():
		return "Fighting"
	if bot.sitting:
		return "Resting"
	return ""


func _for_all(order: Callable) -> void:
	for bot in _members():
		order.call(bot)
	_update()


## Your target, if it's something to fight.
func _target() -> Combatant:
	var target := _player.targeting.target_combatant()
	if target == null or not target.is_alive() or not target.body is Enemy:
		message.emit("You have no target to attack.", true)
		return null
	return target


func _attack(bot: Bot) -> void:
	var target := _target()
	if target:
		bot.order_attack(target)


func _attack_all() -> void:
	var target := _target()
	if target:
		_for_all(func(bot: Bot) -> void: bot.order_attack(target))


func _sell(bot: Bot, everything: bool) -> void:
	var vendor := _near_vendor()
	if vendor == null:
		message.emit("There's no vendor near you.", true)
		return
	bot.send_to_vendor(vendor, everything)
	_update()


func _train(bot: Bot) -> void:
	var trainer := _near_trainer(bot)
	if trainer == null:
		message.emit("There's no %s trainer near you." % ClassicData.CLASS_NAMES.get(bot.profile.char_class, ""), true)
		return
	bot.send_to_trainer(trainer)
	_update()


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


# Where it sits: dragged by its title, remembered as an option.

func _place() -> void:
	var saved: Variant = Settings.get_value("party_window_pos")
	var at := Vector2(_screen.x - WIDTH - 100, 120)
	if saved is Array and saved.size() == 2:
		at = Vector2(float(saved[0]), float(saved[1]))
	at.x = clampf(at.x, 0.0, _screen.x - WIDTH)
	at.y = clampf(at.y, 0.0, _screen.y - 20)
	position = at * _ui_scale


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.button_index == MOUSE_BUTTON_LEFT:
		if click.pressed and click.position.y < UiStyle.TITLE_BAND * _ui_scale:
			_dragging = true
			_drag_from = click.global_position - global_position
		elif not click.pressed and _dragging:
			_dragging = false
			var at := position / _ui_scale
			Settings.set_value("party_window_pos", [roundf(at.x), roundf(at.y)])
			Settings.save()
		accept_event()
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		position = motion.global_position - _drag_from
		accept_event()


# Building.

func _button(text: String, at: Vector2, width: float, pressed: Callable) -> float:
	return _add_button(Button.new(), text, at, width, pressed)


func _add_button(button: Button, text: String, at: Vector2, width: float, pressed: Callable) -> float:
	button.text = text
	button.pressed.connect(pressed)
	return _add_control(button, at, width)


## Places a control; no focus, so keys keep playing the game. Returns the x
## after it.
func _add_control(control: Control, at: Vector2, width: float) -> float:
	control.focus_mode = Control.FOCUS_NONE
	control.position = at * _ui_scale
	control.size = Vector2(width, BUTTON_HEIGHT) * _ui_scale
	control.custom_minimum_size = control.size
	if control is Button:
		(control as Button).clip_text = true
	control.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	if control is OptionButton:
		(control as OptionButton).get_popup().add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		(control as OptionButton).fit_to_longest_item = false
	add_child(control)
	return at.x + width


func _text(at: Vector2, text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at * _ui_scale
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
