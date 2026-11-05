class_name TrainerWindow
extends Control
## Classic class trainer window. Lists the trainer's spells colored as in
## classic: green can be learned now, red can't yet (level, money aside), grey
## already known. Click a spell to select it and Train to buy it, or
## double-click. Closes when the player walks away.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)
signal hovered(spell_id: int)

## Classic INTERACTION_DISTANCE, in yards.
const RANGE := 5.0
## Wide enough for "Sergeant Bram Holloway - Man-at-Arms Trainer".
const WIDTH := 190.0
const LIST_HEIGHT := 150.0
const ROW := 12.0
const FONT_SIZE := 6
const BACK := Color(0.08, 0.08, 0.1, 0.94)
const AVAILABLE := Color(0.25, 1, 0.25)
const UNAVAILABLE := Color(1, 0.25, 0.25)
const USED := Color(0.55, 0.55, 0.55)
const NOT_IN_GAME := Color(0.35, 0.35, 0.4)
const SELECTED := Color(1, 1, 1, 0.12)
## Spells that need another player (a party member to protect or bring back).
## Revival (raising a party member) works; these show but can't be trained yet.
const NEEDS_PARTY := ["Hallowed Ransom", "Boon of the Martyr"]
## Spells whose effect the game doesn't have yet: taking over a creature,
## seeing through its eyes, and a well others click to heal.
const NOT_YET := ["Dominate Will", "Borrowed Eyes", "Font of Light"]

var npc: Node3D

var _player: Player
var _ui_scale := 1.0
var _rows: Array[Dictionary] = []
var _selected := -1
var _money: Label
var _details: Label
var _list: VBoxContainer


func open(trainer_npc: Node3D, player: Player, ui_scale: float) -> void:
	npc = trainer_npc
	_player = player
	_ui_scale = ui_scale
	visible = true
	_selected = -1
	_build()


func close() -> void:
	npc = null
	visible = false
	hovered.emit(0)


func _process(_delta: float) -> void:
	if npc == null:
		return
	if not is_instance_valid(npc) or _player.global_position.distance_to(npc.global_position) > RANGE:
		close()


## Entry state: "used", "available", "unavailable" or "not_in_game", plus why.
static func entry_state(entry: Dictionary) -> Array:
	var main_id: int = entry.spells[0]
	var spell := SpellDB.get_spell(main_id)
	if main_id in GameState.known_spells:
		return ["used", ""]
	if spell.SpellName in NEEDS_PARTY:
		return ["not_in_game", "Needs a party"]
	if spell.SpellName in NOT_YET:
		return ["not_in_game", "Not in the game yet"]
	if int(entry.level) > GameState.level:
		return ["unavailable", "Requires Level %d" % entry.level]
	var previous := SpellDB.previous_rank(main_id)
	if previous != 0 and not previous in GameState.known_spells and not _replaced_rank_known(previous):
		return ["unavailable", "Requires %s" % SpellDB.full_name(SpellDB.get_spell(previous))]
	return ["available", ""]


## A previous rank can be "known" through the rank that replaced it.
static func _replaced_rank_known(id: int) -> bool:
	for known: int in GameState.known_spells:
		if SpellDB.previous_rank(known) == id:
			return true
	return false


func train(index: int) -> void:
	var entry: Dictionary = _rows[index].entry
	var state := entry_state(entry)
	if state[0] != "available":
		message.emit(state[1] if not str(state[1]).is_empty() else "You already know that.", true)
		return
	if GameState.money < int(entry.cost):
		message.emit("Not enough money", true)
		return
	GameState.money -= int(entry.cost)
	for name in SpellCaster.learn(entry.spells):
		message.emit("You have learned a new spell: %s." % name, false)
	Sfx.play("level_up")
	GameState.inventory_changed.emit()
	_build.call_deferred()


## Trains everything available, cheapest level first, as long as the money
## lasts. Learning a rank can make the next one available, so it goes round
## until nothing more can be trained.
func train_all() -> void:
	var learned := 0
	var spent := 0
	var short := false
	var changed := true
	while changed:
		changed = false
		for row: Dictionary in _rows:
			var entry: Dictionary = row.entry
			if entry_state(entry)[0] != "available":
				continue
			if GameState.money < int(entry.cost):
				short = true
				continue
			GameState.money -= int(entry.cost)
			spent += int(entry.cost)
			for name in SpellCaster.learn(entry.spells):
				message.emit("You have learned a new spell: %s." % name, false)
				learned += 1
			changed = true
	if learned == 0:
		message.emit("Not enough money" if short else "There's nothing new to train.", true)
		return
	if short:
		message.emit("Not enough money for the rest.", true)
	Sfx.play("level_up")
	GameState.inventory_changed.emit()
	_build.call_deferred()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()
	var list := SpellDB.trainer_list(npc.trainer, GameState.race)
	# Classic trainers only teach their own class.
	var trainer_class := int(SpellDB.TRAINER_CLASSES.get(npc.trainer, 0))
	size = Vector2(WIDTH, 14 + LIST_HEIGHT + 30) * _ui_scale
	var back := ColorRect.new()
	back.color = BACK
	back.size = size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(back)
	_text(self, Vector2(4, 1), "%s - %s" % [npc.npc_name, npc.subname], Color(1, 0.85, 0.4), 7)
	var close_button := _text(self, Vector2(WIDTH - 9, 1), "x", Color(0.9, 0.4, 0.4), 7)
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close()
	)

	if trainer_class != GameState.char_class:
		var refusal := _text(self, Vector2(6, 20), "I can only train %s. Seek out a trainer of your own calling." % ClassicData.class_plural(trainer_class), Color.WHITE, FONT_SIZE)
		refusal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		refusal.custom_minimum_size.x = (WIDTH - 12) * _ui_scale
		size.y = 50 * _ui_scale
		back.size = size
		_rows.clear()
		return
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(2, 14) * _ui_scale
	scroll.size = Vector2(WIDTH - 4, LIST_HEIGHT) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.custom_minimum_size.x = (WIDTH - 12) * _ui_scale
	scroll.add_child(_list)
	# Classic lists available spells first, then unavailable, then known ones.
	var order := { "available": 0, "unavailable": 1, "not_in_game": 2, "used": 3 }
	var sorted := list.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var state_a: int = order[entry_state(a)[0]]
		var state_b: int = order[entry_state(b)[0]]
		return state_a < state_b if state_a != state_b else int(a.level) < int(b.level)
	)
	for entry: Dictionary in sorted:
		_add_row(entry)

	_details = _text(self, Vector2(4, 16 + LIST_HEIGHT), "", Color.WHITE, FONT_SIZE)
	_money = _text(self, Vector2(4, 24 + LIST_HEIGHT), "Money: %s" % ItemDB.money_text(GameState.money), Color(1, 0.85, 0.4), FONT_SIZE)
	var train_button := Button.new()
	train_button.text = "Train"
	train_button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	train_button.position = Vector2(WIDTH - 40, 18 + LIST_HEIGHT) * _ui_scale
	train_button.size = Vector2(36, 12) * _ui_scale
	train_button.pressed.connect(func() -> void:
		if _selected >= 0:
			train(_selected)
	)
	add_child(train_button)
	var all_button := Button.new()
	all_button.text = "Train All"
	all_button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	all_button.position = Vector2(WIDTH - 82, 18 + LIST_HEIGHT) * _ui_scale
	all_button.size = Vector2(40, 12) * _ui_scale
	all_button.disabled = not _rows.any(func(row: Dictionary) -> bool: return entry_state(row.entry)[0] == "available")
	all_button.pressed.connect(train_all)
	add_child(all_button)
	# Unlearning talents, at the class's own trainer: a second click confirms.
	if Talents.spent(GameState) > 0:
		var cost := Talents.reset_cost(GameState.talent_reset_cost)
		var unlearn := Button.new()
		unlearn.text = "Unlearn Talents"
		unlearn.add_theme_font_size_override("font_size", roundi((FONT_SIZE - 1) * _ui_scale))
		# Under Train All and Train.
		unlearn.position = Vector2(WIDTH - 82, 31 + LIST_HEIGHT) * _ui_scale
		unlearn.size = Vector2(78, 11) * _ui_scale
		unlearn.pressed.connect(func() -> void:
			if not unlearn.has_meta("confirm"):
				unlearn.set_meta("confirm", true)
				unlearn.text = "Pay %s?" % ItemDB.money_text(cost)
				return
			if GameState.money < cost:
				message.emit("Not enough money", true)
				return
			GameState.money -= cost
			GameState.talent_reset_cost = cost
			Talents.reset(GameState)
			message.emit("Your talents have been unlearned.", false)
			Sfx.play("level_up")
			GameState.inventory_changed.emit()
			_build.call_deferred()
		)
		add_child(unlearn)
	_select(_selected if _selected < _rows.size() else -1)


func _add_row(entry: Dictionary) -> void:
	var state := entry_state(entry)
	var spell := SpellDB.get_spell(entry.spells[0])
	var color: Color = { "available": AVAILABLE, "unavailable": UNAVAILABLE, "used": USED, "not_in_game": NOT_IN_GAME }[state[0]]
	var row := ColorRect.new()
	row.color = Color.TRANSPARENT
	row.custom_minimum_size = Vector2(WIDTH - 12, ROW) * _ui_scale
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	_list.add_child(row)
	_text(row, Vector2(2, 1), SpellDB.full_name(spell), color, FONT_SIZE)
	var level_text := _text(row, Vector2(WIDTH - 40, 1), "Lv %d" % entry.level, color, FONT_SIZE)
	level_text.size.x = 26 * _ui_scale
	level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var index := _rows.size()
	_rows.append({ "entry": entry, "row": row, "state": state })
	row.mouse_entered.connect(func() -> void: hovered.emit(int(entry.spells[0])))
	row.mouse_exited.connect(func() -> void: hovered.emit(0))
	row.gui_input.connect(func(event: InputEvent) -> void:
		var button := event as InputEventMouseButton
		if button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_select(index)
			if button.double_click:
				train(index)
	)


func _select(index: int) -> void:
	_selected = index
	for i in _rows.size():
		_rows[i].row.color = SELECTED if i == index else Color.TRANSPARENT
	if index < 0:
		_details.text = "Select a spell to train."
		return
	var entry: Dictionary = _rows[index].entry
	var state: Array = _rows[index].state
	var cost := "Cost: %s" % ItemDB.money_text(int(entry.cost))
	# First ranks that are talents in classic are taught here for free.
	if entry.get("talent", false):
		cost = "Free (a talent in classic)"
	elif entry.get("quest", false):
		cost = "Free (a quest reward in classic)"
	_details.text = cost if str(state[1]).is_empty() else "%s   %s" % [cost, state[1]]


func _text(parent: Node, at: Vector2, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	label.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
	parent.add_child(label)
	return label
