class_name BeastTrainingWindow
extends Control
## Beast Training: teaching the pet abilities the Ranger knows (from taming
## beasts that knew them, and from pet trainers), as classic's window: each
## ability its pet's family can learn, green when it can be taught now, red
## when the pet's level or training points fall short, grey once known. A
## new rank replaces the old one. The training points left are at the bottom.
## Sizes are in HUD units (1/270 of the window height), times ui_scale.

signal message(text: String, is_error: bool)

const WIDTH := 170.0
const LIST_HEIGHT := 120.0
const ROW := 11.0
const FONT_SIZE := 6
const AVAILABLE := Color(0.25, 1, 0.25)
const UNAVAILABLE := Color(1, 0.25, 0.25)
const KNOWN := Color(0.55, 0.55, 0.55)

var _player: Player
var _ui_scale := 1.0


func open(player: Player, ui_scale: float) -> void:
	_player = player
	_ui_scale = ui_scale
	visible = true
	_build()


func close() -> void:
	visible = false


func _pet() -> Pet:
	var pet := _player.pet if _player else null
	return pet if pet and is_instance_valid(pet) else null


## An ability's state for the pet: [state, why].
func _state(pet: Pet, id: int) -> Array:
	var known: Array = pet.record.get("spells", [])
	if id in known:
		return ["known", ""]
	if PetDB.required_level(id) > int(pet.record.level):
		return ["unavailable", "Pet level %d" % PetDB.required_level(id)]
	if PetDB.tp_cost(id) > pet.training_points_left():
		return ["unavailable", "%d TP" % PetDB.tp_cost(id)]
	return ["available", "%d TP" % PetDB.tp_cost(id)]


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var pet := _pet()
	size = Vector2(WIDTH, 14 + LIST_HEIGHT + 22) * _ui_scale
	UiStyle.panel(self, size / _ui_scale, _ui_scale)
	UiStyle.title(self, Vector2(5, 1.5), "Beast Training", _ui_scale)
	UiStyle.close_button(self, Vector2(WIDTH - 10, 2), _ui_scale, close)
	if pet == null:
		_text(Vector2(6, 20), "You have no pet out.", Color.WHITE)
		return
	var allowed := PetDB.family_abilities(int(pet.record.family))
	var ids: Array[int] = []
	for id: int in GameState.pet_spells:
		if id in allowed:
			ids.append(id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		var sa := SpellDB.get_spell(a)
		var sb := SpellDB.get_spell(b)
		if sa.SpellName != sb.SpellName:
			return str(sa.SpellName) < str(sb.SpellName)
		return SpellDB.rank_of(a) < SpellDB.rank_of(b))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(2, 14) * _ui_scale
	scroll.size = Vector2(WIDTH - 4, LIST_HEIGHT) * _ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.custom_minimum_size.x = (WIDTH - 12) * _ui_scale
	scroll.add_child(list)
	if ids.is_empty():
		var none := Label.new()
		none.text = "You know nothing %s can learn yet. Tame beasts that know abilities, or visit a pet trainer." % pet.record.name
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = (WIDTH - 12) * _ui_scale
		none.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		list.add_child(none)
	for id in ids:
		var state := _state(pet, id)
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(WIDTH - 12, ROW) * _ui_scale
		row.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
		row.text = "%s    %s" % [SpellDB.full_name(SpellDB.get_spell(id)), state[1]]
		var color: Color = AVAILABLE if state[0] == "available" else KNOWN if state[0] == "known" else UNAVAILABLE
		row.add_theme_color_override("font_color", color)
		row.add_theme_color_override("font_hover_color", color.lightened(0.3))
		row.pressed.connect(_teach.bind(id))
		list.add_child(row)
	_text(Vector2(6, 14 + LIST_HEIGHT + 5), "%s - Level %d - Training points: %d" % [pet.record.name, int(pet.record.level), pet.training_points_left()], UiStyle.GOLD_BRIGHT)


## Teaches the pet an ability: it replaces a lower rank, costs training
## points (what's left after the old rank's, as classic), and is set to
## autocast.
func _teach(id: int) -> void:
	var pet := _pet()
	if pet == null:
		return
	var state := _state(pet, id)
	if state[0] != "available":
		message.emit("Your pet already knows that." if state[0] == "known" else "Your pet can't learn that yet.", true)
		return
	var spell := SpellDB.get_spell(id)
	var spells: Array = pet.record.get("spells", [])
	var autocast: Array = pet.record.get("autocast", [])
	var refund := 0
	for old in spells.duplicate():
		if SpellDB.get_spell(int(old)).SpellName == spell.SpellName:
			refund += PetDB.tp_cost(int(old))
			spells.erase(old)
			autocast.erase(old)
	spells.append(id)
	if not SpellDB.is_passive(spell):
		autocast.append(id)
	pet.record.spells = spells
	pet.record.autocast = autocast
	pet.record.tp_used = maxi(int(pet.record.get("tp_used", 0)) - refund, 0) + PetDB.tp_cost(id)
	pet.apply_stats()
	message.emit("%s has learned %s." % [pet.record.name, SpellDB.full_name(spell)], false)
	Sfx.play("level_up")
	_build.call_deferred()


func _text(at: Vector2, text: String, color: Color) -> Label:
	var label := Label.new()
	label.position = at * _ui_scale
	label.text = text
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
