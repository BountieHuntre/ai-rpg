class_name CombatHud
extends CanvasLayer
## Unit frames, action bar, cast bar, error messages and floating numbers.
## Built in code at full window resolution, and rebuilt when the window resizes.
## Layout values are in units of 1/270 of the window height.

const BASE_HEIGHT := 270.0
const FONT_SIZE := 8
const BAR_BACK := Color(0.08, 0.08, 0.1, 0.85)
const SLOT_SIZE := 30.0
const SLOT_GAP := 3.0
const MESSAGE_TIME := 2.0
const FLOAT_TIME := 1.0
const FLOAT_SPEED := 18.0
const FLOAT_HEIGHT := 2.5
## Numbers cycle through these so ones landing together don't stack.
const FLOAT_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(-14, 4), Vector2(14, 4)]
const BAR_FONT_SIZE := 7
const ENEMY_BAR_SIZE := Vector2(28, 4)
const ENEMY_BAR_HEIGHT := 2.2
const ENEMY_BAR_RANGE := 40.0

var _player: Player
var _camera: Camera3D
var _game_view: SubViewportContainer
var _ui_scale := 1.0
var _width := 480.0
var _height := BASE_HEIGHT

var _player_health: Control
var _player_health_text: Label
var _player_mana: Control
var _player_mana_text: Label
var _target_frame: Control
var _target_name: Label
var _target_health: Control
var _target_health_text: Label
var _cast_frame: Control
var _cast_fill: Control
var _cast_name: Label
var _message: Label
var _message_left := 0.0
var _slots: Array[Dictionary] = []
var _floats: Array[Dictionary] = []
var _next_float_offset := 0
var _enemy_bars: Array[Dictionary] = []


func setup(player: Player, camera: Camera3D, game_view: SubViewportContainer) -> void:
	_player = player
	_camera = camera
	_game_view = game_view
	_build()
	get_viewport().size_changed.connect(_build)

	_player.caster.failed.connect(_show_message)
	_player.combatant.died.connect(_show_message.bind("You died"))
	for node in get_tree().get_nodes_in_group("combatants"):
		var combatant := node as Combatant
		var hit_color := Color(1, 0.3, 0.3) if combatant == _player.combatant else Color.WHITE
		combatant.took_damage.connect(func(amount: int, _source: Combatant) -> void:
			_add_float(combatant, str(amount), hit_color)
		)
		combatant.healed.connect(func(amount: int) -> void:
			_add_float(combatant, "+%d" % amount, Color(0.4, 1, 0.4))
		)
		combatant.stunned.connect(func() -> void:
			_add_float(combatant, "Stunned", Color(1, 0.9, 0.3))
		)


func _process(delta: float) -> void:
	if not _player:
		return
	var me := _player.combatant
	_set_bar(_player_health, me.health, me.max_health)
	_player_health_text.text = "%d/%d" % [me.health, me.max_health]
	_set_bar(_player_mana, me.mana, me.max_mana)
	_player_mana_text.text = "%d/%d" % [int(me.mana), me.max_mana]

	var target := _player.targeting.target_combatant()
	_target_frame.visible = target != null
	if target:
		_target_name.text = target.display_name
		_set_bar(_target_health, target.health, target.max_health)
		_target_health_text.text = "%d/%d" % [target.health, target.max_health]

	var casting := _player.caster.casting
	_cast_frame.visible = casting != null
	if casting:
		_cast_name.text = casting.display_name
		_set_bar(_cast_fill, _player.caster.cast_fraction(), 1.0)

	for i in _slots.size():
		var overlay: Control = _slots[i].overlay
		var height := SLOT_SIZE * _ui_scale * _player.caster.cooldown_fraction(i)
		overlay.position.y = SLOT_SIZE * _ui_scale - height
		overlay.size.y = height
		_slots[i].no_mana.visible = me.mana < _player.caster.abilities[i].mana_cost

	_message_left -= delta
	_message.visible = _message_left > 0.0
	_update_floats(delta)
	_update_enemy_bars()


func _build() -> void:
	for child in get_children():
		child.free()
	_slots.clear()
	_floats.clear()
	_enemy_bars.clear()

	var window := get_viewport().get_visible_rect().size
	_ui_scale = maxf(window.y / BASE_HEIGHT, 1.0)
	_width = window.x / _ui_scale
	_height = window.y / _ui_scale

	_build_enemy_bars()
	_build_player_frame()
	_build_target_frame()
	_build_action_bar()
	_build_cast_bar()
	_message = _label(self, Vector2(0, 34), "", Color(1, 0.35, 0.3))
	_message.size.x = window.x
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_player_frame() -> void:
	var frame := _frame(Vector2(4, 4), Vector2(90, 34))
	_label(frame, Vector2(3, 0), _player.combatant.display_name)
	_player_health = _bar(frame, Vector2(3, 12), Vector2(84, 10), Color(0.25, 0.7, 0.25))
	_player_health_text = _bar_text(frame, Vector2(3, 12), Vector2(84, 10))
	_player_mana = _bar(frame, Vector2(3, 23), Vector2(84, 9), Color(0.2, 0.4, 0.85))
	_player_mana_text = _bar_text(frame, Vector2(3, 23), Vector2(84, 9))


func _build_target_frame() -> void:
	_target_frame = _frame(Vector2(100, 4), Vector2(90, 24))
	_target_name = _label(_target_frame, Vector2(3, 0), "")
	_target_health = _bar(_target_frame, Vector2(3, 12), Vector2(84, 10), Color(0.75, 0.2, 0.2))
	_target_health_text = _bar_text(_target_frame, Vector2(3, 12), Vector2(84, 10))


func _build_action_bar() -> void:
	var abilities := _player.caster.abilities
	var width := abilities.size() * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	var left := (_width - width) / 2.0
	for i in abilities.size():
		var slot := _frame(Vector2(left + i * (SLOT_SIZE + SLOT_GAP), _height - SLOT_SIZE - 4), Vector2.ONE * SLOT_SIZE)
		_label(slot, Vector2(2, -1), str(i + 1), Color(1, 0.85, 0.4))
		_label(slot, Vector2(2, 17), abilities[i].short_name)
		var no_mana := _rect(slot, Vector2.ZERO, Vector2.ONE * SLOT_SIZE, Color(0.1, 0.1, 0.5, 0.55))
		var overlay := _rect(slot, Vector2.ZERO, Vector2(SLOT_SIZE, 0), Color(0, 0, 0, 0.65))
		_slots.append({ "overlay": overlay, "no_mana": no_mana })


func _build_cast_bar() -> void:
	_cast_frame = _frame(Vector2((_width - 120) / 2.0, _height - SLOT_SIZE - 20), Vector2(120, 12))
	_cast_fill = _bar(_cast_frame, Vector2(1, 1), Vector2(118, 10), Color(0.9, 0.65, 0.2))
	_cast_name = _bar_text(_cast_frame, Vector2(1, 1), Vector2(118, 10))
	_cast_frame.visible = false


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME


func _add_float(combatant: Combatant, text: String, color: Color) -> void:
	var label := _label(self, Vector2.ZERO, text, color)
	label.visible = false
	var world_position := combatant.body.global_position + Vector3.UP * FLOAT_HEIGHT
	_floats.append({ "label": label, "world": world_position, "age": 0.0, "offset": FLOAT_OFFSETS[_next_float_offset] })
	_next_float_offset = (_next_float_offset + 1) % FLOAT_OFFSETS.size()


func _update_floats(delta: float) -> void:
	for i in range(_floats.size() - 1, -1, -1):
		var entry := _floats[i]
		entry.age += delta
		var label: Label = entry.label
		if entry.age >= FLOAT_TIME:
			label.queue_free()
			_floats.remove_at(i)
			continue
		label.visible = not _camera.is_position_behind(entry.world)
		# The camera projects into the game view's low-res pixels.
		var on_window: Vector2 = _camera.unproject_position(entry.world) * _game_view.stretch_shrink
		var drift: Vector2 = entry.offset + Vector2(0, -entry.age * FLOAT_SPEED)
		label.position = on_window + drift * _ui_scale - Vector2(label.size.x / 2.0, 0)


func _update_enemy_bars() -> void:
	for entry in _enemy_bars:
		var combatant: Combatant = entry.combatant
		var frame: Control = entry.frame
		var world: Vector3 = combatant.body.global_position + Vector3.UP * ENEMY_BAR_HEIGHT
		frame.visible = (
			combatant.is_alive()
			and not _camera.is_position_behind(world)
			and _camera.global_position.distance_to(world) <= ENEMY_BAR_RANGE
		)
		if frame.visible:
			_set_bar(entry.fill, combatant.health, combatant.max_health)
			var on_window: Vector2 = _camera.unproject_position(world) * _game_view.stretch_shrink
			frame.position = on_window - Vector2(frame.size.x / 2.0, frame.size.y)


func _build_enemy_bars() -> void:
	for node in get_tree().get_nodes_in_group("combatants"):
		if node != _player.combatant:
			var frame := _frame(Vector2.ZERO, ENEMY_BAR_SIZE)
			var fill := _bar(frame, Vector2(1, 1), ENEMY_BAR_SIZE - Vector2(2, 2), Color(0.8, 0.2, 0.2))
			_enemy_bars.append({ "combatant": node, "frame": frame, "fill": fill })


func _set_bar(fill: Control, value: float, maximum: float) -> void:
	fill.size.x = fill.get_meta("full_width") * clampf(value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


func _frame(frame_position: Vector2, frame_size: Vector2) -> Control:
	return _rect(self, frame_position, frame_size, BAR_BACK)


func _bar(parent: Node, bar_position: Vector2, bar_size: Vector2, color: Color) -> Control:
	var fill := _rect(parent, bar_position, bar_size, color)
	fill.set_meta("full_width", bar_size.x * _ui_scale)
	return fill


func _rect(parent: Node, rect_position: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = rect_position * _ui_scale
	rect.size = rect_size * _ui_scale
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


## A smaller label centered on a bar of the given position and size.
func _bar_text(parent: Node, bar_position: Vector2, bar_size: Vector2) -> Label:
	var label := _label(parent, bar_position, "")
	label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size.x = bar_size.x * _ui_scale
	var center_y := (bar_position.y + bar_size.y / 2.0) * _ui_scale
	label.position.y = center_y - label.get_minimum_size().y / 2.0
	return label


func _label(parent: Node, label_position: Vector2, text: String, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.position = label_position * _ui_scale
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", roundi(FONT_SIZE * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	var shadow := maxi(roundi(_ui_scale), 1)
	label.add_theme_constant_override("shadow_offset_x", shadow)
	label.add_theme_constant_override("shadow_offset_y", shadow)
	parent.add_child(label)
	return label
