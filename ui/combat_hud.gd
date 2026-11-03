class_name CombatHud
extends CanvasLayer
## Unit frames, action bar, cast bar, error messages and floating numbers.
## Built in code at full window resolution, and rebuilt when the window resizes.
## Layout values are in units of 1/270 of the window height.

const BASE_HEIGHT := 270.0
const FONT_SIZE := 8
const BAR_BACK := Color(0.08, 0.08, 0.1, 0.85)
## The cast bar sits above the action bar and the stance bar.
const CAST_BAR_Y_FROM_BOTTOM := 60.0
const MESSAGE_TIME := 2.0
const FLOAT_TIME := 1.0
const FLOAT_SPEED := 18.0
const FLOAT_HEIGHT := 2.5
## Numbers cycle through these so ones landing together don't stack.
const FLOAT_OFFSETS: Array[Vector2] = [Vector2(0, 0), Vector2(-14, 4), Vector2(14, 4)]
const BAR_FONT_SIZE := 7
const XP_FONT_SIZE := 5
const CRIT_FONT_SIZE := 12
const SHEET_FONT_SIZE := 6
const LOG_TIME := 8.0
const LOG_LINES := 6
const BANNER_FONT_SIZE := 18
const BANNER_TIME := 2.5
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
var _player_level: Label
var _player_xp: Control
var _player_xp_text: Label
var _target_frame: Control
var _target_name: Label
var _target_level: Label
var _banner: Label
var _banner_left := 0.0
var _target_health: Control
var _target_health_text: Label
var _cast_frame: Control
var _cast_fill: Control
var _cast_name: Label
var _message: Label
var _message_left := 0.0
var _floats: Array[Dictionary] = []
var _next_float_offset := 0
var _enemy_bars: Array[Dictionary] = []
var _inventory: InventoryUI
var _spells: SpellUI
var _trainer: TrainerWindow
var _trainer_npc: Node3D
var _vendor: VendorWindow
var _vendor_npc: Node3D
var _npc_names: Array[Dictionary] = []
var _loot_window: LootWindow
var _loot_corpse: Enemy
var _tooltip: ItemTooltip
var _loot_log: Label
## Recent loot messages as [text, seconds left].
var _log_lines: Array[Array] = []


func setup(player: Player, camera: Camera3D, game_view: SubViewportContainer) -> void:
	_player = player
	_camera = camera
	_game_view = game_view
	_build()
	get_viewport().size_changed.connect(_build)

	_player.spells.failed.connect(_show_message)
	_player.spells.failed.connect(func(_message: String) -> void: Sfx.play("error"))
	_player.combatant.died.connect(_show_message.bind("You died"))
	_player.progression.xp_gained.connect(func(amount: int) -> void:
		_add_float(_player.combatant, "+%d XP" % amount, Color(0.75, 0.55, 1))
	)
	_player.progression.leveled_up.connect(_on_leveled_up)
	for node in get_tree().get_nodes_in_group("combatants"):
		var combatant := node as Combatant
		var hit_color := Color(1, 0.3, 0.3) if combatant == _player.combatant else Color.WHITE
		combatant.took_damage.connect(func(amount: int, _source: Combatant, crit: bool) -> void:
			_add_float(combatant, "%d!" % amount if crit else str(amount), hit_color, crit)
		)
		combatant.avoided.connect(func(text: String, _source: Combatant) -> void:
			_add_float(combatant, text, Color(0.8, 0.8, 0.8))
		)
		combatant.healed.connect(func(amount: int, crit: bool) -> void:
			_add_float(combatant, "+%d%s" % [amount, "!" if crit else ""], Color(0.4, 1, 0.4), crit)
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
	_player_level.text = "Lv %d" % me.level
	if me.level >= ClassicData.MAX_LEVEL:
		_set_bar(_player_xp, 1.0, 1.0)
		_player_xp_text.text = "Max level"
	else:
		var needed := ClassicData.xp_to_next(me.level)
		_set_bar(_player_xp, GameState.xp, needed)
		_player_xp_text.text = "%d/%d XP" % [GameState.xp, needed]

	var target := _player.targeting.target_combatant()
	_target_frame.visible = target != null
	if target:
		_target_name.text = target.display_name
		_target_level.text = "Lv %d" % target.level
		_target_level.add_theme_color_override("font_color", CombatRules.level_color(me.level, target.level))
		_set_bar(_target_health, target.health, target.max_health)
		_target_health_text.text = "%d/%d" % [target.health, target.max_health]

	var casting: Dictionary = _player.spells.casting
	_cast_frame.visible = not casting.is_empty()
	if not casting.is_empty():
		_cast_name.text = casting.SpellName
		_set_bar(_cast_fill, _player.spells.cast_fraction(), 1.0)

	_message_left -= delta
	_message.visible = _message_left > 0.0
	_banner_left -= delta
	_banner.visible = _banner_left > 0.0
	_update_floats(delta)
	_update_enemy_bars()
	_update_npc_names()
	_update_loot_log(delta)


func _build() -> void:
	var open_windows := _inventory.open_state() if _inventory else {}
	var book_open := _spells.is_book_open() if _spells else false
	for child in get_children():
		child.free()
	_floats.clear()
	_enemy_bars.clear()
	_npc_names.clear()

	var window := get_viewport().get_visible_rect().size
	_ui_scale = maxf(window.y / BASE_HEIGHT, 1.0)
	_width = window.x / _ui_scale
	_height = window.y / _ui_scale

	_build_enemy_bars()
	_build_npc_names()
	_build_player_frame()
	_build_target_frame()
	_build_cast_bar()
	_message = _label(self, Vector2(0, 34), "", Color(1, 0.35, 0.3))
	_message.size.x = window.x
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner = _label(self, Vector2(0, 60), "", Color(1, 0.85, 0.3))
	_banner.add_theme_font_size_override("font_size", roundi(BANNER_FONT_SIZE * _ui_scale))
	_banner.size.x = window.x
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	_loot_log = _label(self, Vector2(4, _height - 60), "", Color(0.4, 0.75, 1))
	_loot_log.add_theme_font_size_override("font_size", roundi(SHEET_FONT_SIZE * _ui_scale))
	_loot_window = LootWindow.new()
	_loot_window.position = Vector2(130, 60) * _ui_scale
	_loot_window.visible = false
	add_child(_loot_window)
	_loot_window.message.connect(_on_loot_message)
	_loot_window.closed.connect(func() -> void: _loot_corpse = null)
	_inventory = InventoryUI.new()
	add_child(_inventory)
	_spells = SpellUI.new()
	add_child(_spells)
	_tooltip = ItemTooltip.new()
	_tooltip.setup(_ui_scale)
	add_child(_tooltip)
	_loot_window.hovered.connect(_tooltip.show_item)
	_inventory.setup(_player, _ui_scale, Vector2(_width, _height), _tooltip, open_windows)
	_inventory.message.connect(_on_loot_message)
	_spells.setup(_player, _ui_scale, Vector2(_width, _height), _tooltip, book_open)
	_trainer = TrainerWindow.new()
	_trainer.position = Vector2(130, 50) * _ui_scale
	_trainer.visible = false
	add_child(_trainer)
	move_child(_tooltip, -1)
	_trainer.message.connect(_on_loot_message)
	_trainer.hovered.connect(func(id: int) -> void: _tooltip.show_lines(_spells.spell_tooltip(id)))
	if _trainer_npc and is_instance_valid(_trainer_npc):
		_trainer.open(_trainer_npc, _player, _ui_scale)
	_vendor = VendorWindow.new()
	_vendor.position = Vector2(130, 50) * _ui_scale
	_vendor.visible = false
	add_child(_vendor)
	move_child(_tooltip, -1)
	_vendor.message.connect(_on_loot_message)
	_vendor.hovered.connect(_tooltip.show_item)
	_vendor.visibility_changed.connect(func() -> void:
		_inventory.selling = _vendor.visible
		if not _vendor.visible:
			_vendor_npc = null
	)
	if _vendor_npc and is_instance_valid(_vendor_npc):
		_vendor.open(_vendor_npc, _player, _ui_scale)
		_inventory.selling = true
	if _loot_corpse and is_instance_valid(_loot_corpse) and _loot_corpse.has_loot():
		_loot_window.open(_loot_corpse, _player, _ui_scale)


func _build_player_frame() -> void:
	var frame := _frame(Vector2(4, 4), Vector2(90, 41))
	_label(frame, Vector2(3, 0), _player.combatant.display_name)
	_player_level = _right_label(frame, Vector2(3, 0), 84)
	_player_health = _bar(frame, Vector2(3, 12), Vector2(84, 10), Color(0.25, 0.7, 0.25))
	_player_health_text = _bar_text(frame, Vector2(3, 12), Vector2(84, 10))
	_player_mana = _bar(frame, Vector2(3, 23), Vector2(84, 9), Color(0.2, 0.4, 0.85))
	_player_mana_text = _bar_text(frame, Vector2(3, 23), Vector2(84, 9))
	_rect(frame, Vector2(3, 33), Vector2(84, 6), Color(0.15, 0.1, 0.2))
	_player_xp = _bar(frame, Vector2(3, 33), Vector2(84, 6), Color(0.55, 0.3, 0.85))
	_player_xp_text = _bar_text(frame, Vector2(3, 33), Vector2(84, 6), XP_FONT_SIZE)


func _build_target_frame() -> void:
	_target_frame = _frame(Vector2(100, 4), Vector2(90, 24))
	_target_name = _label(_target_frame, Vector2(3, 0), "")
	_target_level = _right_label(_target_frame, Vector2(3, 0), 84)
	_target_health = _bar(_target_frame, Vector2(3, 12), Vector2(84, 10), Color(0.75, 0.2, 0.2))
	_target_health_text = _bar_text(_target_frame, Vector2(3, 12), Vector2(84, 10))


func _build_cast_bar() -> void:
	_cast_frame = _frame(Vector2((_width - 120) / 2.0, _height - CAST_BAR_Y_FROM_BOTTOM), Vector2(120, 12))
	_cast_fill = _bar(_cast_frame, Vector2(1, 1), Vector2(118, 10), Color(0.9, 0.65, 0.2))
	_cast_name = _bar_text(_cast_frame, Vector2(1, 1), Vector2(118, 10))
	_cast_frame.visible = false


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME


func _add_float(combatant: Combatant, text: String, color: Color, big := false) -> void:
	var label := _label(self, Vector2.ZERO, text, color)
	if big:
		label.add_theme_font_size_override("font_size", roundi(CRIT_FONT_SIZE * _ui_scale))
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


## Friendly NPC names in green, with their title below, as in classic.
func _build_npc_names() -> void:
	for npc: Node in get_tree().get_nodes_in_group("npcs"):
		var name_label := _label(self, Vector2.ZERO, "%s
<%s>" % [npc.npc_name, npc.subname], Color(0.25, 1, 0.25))
		name_label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_npc_names.append({ "npc": npc, "label": name_label })


func _update_npc_names() -> void:
	for entry in _npc_names:
		var npc: Node3D = entry.npc
		var label: Label = entry.label
		var world := npc.global_position + Vector3.UP * ENEMY_BAR_HEIGHT
		label.visible = not _camera.is_position_behind(world) and _camera.global_position.distance_to(world) <= ENEMY_BAR_RANGE
		if label.visible:
			var on_window: Vector2 = _camera.unproject_position(world) * _game_view.stretch_shrink
			label.position = on_window - Vector2(label.size.x / 2.0, label.size.y)


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


func _right_label(parent: Node, label_position: Vector2, width: float) -> Label:
	var label := _label(parent, label_position, "")
	label.size.x = width * _ui_scale
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


## WoW-style difficulty colors for a level difference (enemy minus player).
## Gray enemies give no XP.
func open_loot(corpse: Enemy, take_all: bool) -> void:
	if _player.global_position.distance_to(corpse.global_position) > LootWindow.LOOT_RANGE:
		_show_message("You are too far away.")
		Sfx.play("error")
		return
	if take_all:
		for text in LootWindow.take_all(corpse):
			_on_loot_message(text, text == "Inventory is full.")
		return
	_loot_corpse = corpse
	_loot_window.open(corpse, _player, _ui_scale)


## Right-clicked a friendly NPC: opens its vendor or trainer window. Opening a
## vendor also opens the bags, as in classic.
func open_npc(npc: Npc) -> void:
	if _player.global_position.distance_to(npc.global_position) > TrainerWindow.RANGE:
		_show_message("You are too far away.")
		Sfx.play("error")
		return
	if npc.vendor != 0:
		_vendor_npc = npc
		_vendor.open(npc, _player, _ui_scale)
		_inventory.selling = true
		_inventory.open_bags()
	elif not npc.trainer.is_empty():
		_trainer_npc = npc
		_trainer.open(npc, _player, _ui_scale)


func close_vendor() -> bool:
	if not _vendor.visible:
		return false
	_vendor.close()
	return true


func close_trainer() -> bool:
	if not _trainer.visible:
		return false
	_trainer.close()
	_trainer_npc = null
	return true


func close_loot() -> void:
	_loot_window.close()


func is_looting() -> bool:
	return _loot_window.visible


func _on_loot_message(text: String, is_error: bool) -> void:
	if is_error:
		_show_message(text)
		Sfx.play("error")
		return
	_log_lines.append([text, LOG_TIME])
	if _log_lines.size() > LOG_LINES:
		_log_lines.pop_front()


func _update_loot_log(delta: float) -> void:
	for line in _log_lines:
		line[1] -= delta
	_log_lines = _log_lines.filter(func(line: Array) -> bool: return line[1] > 0.0)
	var texts := PackedStringArray()
	for line in _log_lines:
		texts.append(line[0])
	_loot_log.text = "\n".join(texts)
	_loot_log.position.y = _height * _ui_scale - _loot_log.get_minimum_size().y - 4 * _ui_scale


## Esc handling: drops a held item or spell, or closes the bag, character and
## spellbook windows.
func close_inventory_window() -> bool:
	return _spells.close_one() or _inventory.close_one()


func _on_leveled_up(new_level: int) -> void:
	_banner.text = "Level %d!" % new_level
	_banner_left = BANNER_TIME
	Sfx.play("level_up")


## A smaller label centered on a bar of the given position and size.
func _bar_text(parent: Node, bar_position: Vector2, bar_size: Vector2, font_size := BAR_FONT_SIZE) -> Label:
	var label := _label(parent, bar_position, "")
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
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
