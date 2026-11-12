class_name StableWindow
extends Control
## A stable master's stable (classic's): the Ranger's pet goes into a stable
## slot and comes back out. Two slots, bought one at a time; a pet in the
## stable keeps its level, abilities and training points. The slot prices are
## close to classic's, not its own (the data sources don't have them).
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)

const WIDTH := 190.0
const FONT_SIZE := 6
const ROW := 13.0
const MAX_SLOTS := 2
## The price of each slot, in copper.
const SLOT_PRICES := [500, 5000]

var npc: Node3D
var _player: Player
var _ui_scale := 1.0


func open(stable_npc: Node3D, player: Player, ui_scale: float) -> void:
	npc = stable_npc
	_player = player
	_ui_scale = ui_scale
	visible = true
	_build()


func close() -> void:
	npc = null
	visible = false


func _process(_delta: float) -> void:
	if npc and (not is_instance_valid(npc) or _player.global_position.distance_to(npc.global_position) > TrainerWindow.RANGE):
		close()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var rows := 3 + MAX_SLOTS
	size = Vector2(WIDTH, 16 + rows * ROW + 6) * _ui_scale
	UiStyle.panel(self, size / _ui_scale, _ui_scale)
	UiStyle.title(self, Vector2(5, 1.5), "Stable", _ui_scale)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, close)
	if GameState.char_class != ClassicData.CharClass.HUNTER:
		_text(Vector2(6, 18), "Only Rangers keep pets here.", Color.WHITE)
		return
	var y := 16.0
	var active := GameState.pet
	var current := "Your pet: %s" % _describe(active) if not active.is_empty() else "You have no pet."
	_text(Vector2(6, y), current, UiStyle.GOLD_BRIGHT)
	if not active.is_empty():
		_button(Vector2(WIDTH - 46, y), "Stable", _stable_pet)
	y += ROW + 3
	for i in MAX_SLOTS:
		if i < GameState.stable_slots:
			var held: Dictionary = GameState.stable[i] if i < GameState.stable.size() else {}
			_text(Vector2(6, y), "Slot %d: %s" % [i + 1, _describe(held) if not held.is_empty() else "empty"], Color.WHITE)
			if not held.is_empty():
				_button(Vector2(WIDTH - 46, y), "Take Out", _take_out.bind(i))
		elif i == GameState.stable_slots:
			_text(Vector2(6, y), "Slot %d: not bought" % (i + 1), Color(0.6, 0.6, 0.6))
			_button(Vector2(WIDTH - 46, y), "Buy %s" % _price(SLOT_PRICES[i]), _buy_slot)
		y += ROW


func _describe(record: Dictionary) -> String:
	return "%s (level %d %s)" % [record.get("name", "?"), int(record.get("level", 1)), PetDB.family_name(int(record.get("family", 0)))]


func _price(copper: int) -> String:
	return "%dg" % (copper / 10000) if copper >= 10000 else "%ds" % (copper / 100) if copper >= 100 else "%dc" % copper


## The pet goes into the first empty slot, out of the world.
func _stable_pet() -> void:
	var free := -1
	for i in GameState.stable_slots:
		if i >= GameState.stable.size() or (GameState.stable[i] as Dictionary).is_empty():
			free = i
			break
	if free < 0:
		message.emit("You have no empty stable slot.", true)
		return
	var ranger := _player.spells.ranger()
	if _player.pet and is_instance_valid(_player.pet):
		ranger._unsummon(false)
	var record: Dictionary = GameState.pet
	record.out = false
	while GameState.stable.size() <= free:
		GameState.stable.append({})
	GameState.stable[free] = record
	GameState.pet = {}
	ranger.pet_changed.emit()
	message.emit("%s is in the stable." % record.get("name", "Your pet"), false)
	_build.call_deferred()


## A stabled pet becomes the Ranger's pet again (with none out).
func _take_out(slot: int) -> void:
	if not GameState.pet.is_empty():
		message.emit("Stable your current pet first.", true)
		return
	var record: Dictionary = GameState.stable[slot]
	GameState.stable[slot] = {}
	GameState.pet = record
	_player.spells.ranger()._summon(record)
	message.emit("%s is with you again." % record.get("name", "Your pet"), false)
	_build.call_deferred()


func _buy_slot() -> void:
	var price: int = SLOT_PRICES[GameState.stable_slots]
	if GameState.money < price:
		message.emit("Not enough money", true)
		return
	GameState.money -= price
	GameState.stable_slots += 1
	GameState.money_changed.emit()
	Sfx.play("coins")
	_build.call_deferred()


func _text(at: Vector2, text: String, color: Color) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	# Text stops short of the buttons on the right.
	label.size.x = (WIDTH - 54 - at.x) * _ui_scale
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label


func _button(at: Vector2, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.position = at * _ui_scale
	button.size = Vector2(42, ROW - 2) * _ui_scale
	button.text = text
	button.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	button.pressed.connect(action)
	add_child(button)
	return button
