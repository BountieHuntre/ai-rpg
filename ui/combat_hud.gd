class_name CombatHud
extends CanvasLayer
## Unit frames, action bar, cast bar, error messages and floating numbers.
## Built in code at full window resolution, and rebuilt when the window resizes.
## Layout values are in units of 1/270 of the window height.

const BASE_HEIGHT := 270.0
const FONT_SIZE := 8
const BAR_BACK := Color(0.08, 0.08, 0.1, 0.85)
const TARGET_HEALTH := Color(0.75, 0.2, 0.2)
## The cast bar sits above the action bar and the stance bar.
const CAST_BAR_Y_FROM_BOTTOM := 68.0
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
## Show the worn gear warning at or below this share of durability.
const DURABILITY_WARNING := 0.2
const QUEST_MARKER_SIZE := 14
const TRACKER_WIDTH := 108.0
const GREY := Color(0.6, 0.6, 0.6)
const QUEST_DONE := Color(0.45, 0.9, 0.45)
## creature_template CreatureType names.
const CREATURE_TYPES := {
	1: "Beast", 2: "Dragonkin", 3: "Demon", 4: "Elemental", 5: "Giant", 6: "Undead",
	7: "Humanoid", 8: "Critter", 9: "Mechanical",
}
const QUEST_NOTE_TIME := 3.0
const NAMEPLATE_HEIGHT := 2.2
const NAMEPLATE_RANGE := 40.0

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
var _durability_warning: Label
var _banner_left := 0.0
var _target_health: ColorRect
var _target_health_text: Label
var _cast_frame: Control
var _cast_fill: Control
var _cast_name: Label
var _message: Label
var _message_left := 0.0
var _floats: Array[Dictionary] = []
var _next_float_offset := 0
## Names over creatures, colored by how they'll react: [{ combatant, label }].
var _enemy_names: Array[Dictionary] = []
var _inventory: InventoryUI
var _spells: SpellUI
var _trainer: TrainerWindow
var _trainer_npc: Node3D
var _vendor: VendorWindow
var _vendor_npc: Node3D
var _npc_names: Array[Dictionary] = []
var _quest_window: QuestWindow
var _quest_npc: Npc
var _quest_log: QuestLogUI
## Objectives of the quests underway, down the right side.
var _tracker: RichTextLabel
var _minimap: Minimap
## Quest progress ("Burrowling Runt slain: 3/10"), in yellow under messages.
var _quest_note: Label
var _quest_note_left := 0.0
var _loot_window: LootWindow
var _loot_corpse: Enemy
var _tooltip: ItemTooltip
## The creature or NPC under the mouse, described in the bottom right corner.
var _unit_tooltip: ItemTooltip
var _unit_lines: Array = []
var _loot_log: Label
## Recent loot messages as [text, seconds left].
var _log_lines: Array[Array] = []


func setup(player: Player, camera: Camera3D, game_view: SubViewportContainer) -> void:
	_player = player
	_camera = camera
	_game_view = game_view
	_build()
	get_viewport().size_changed.connect(_build)
	Settings.changed.connect(func(key: String) -> void:
		if key == "ui_scale":
			_build()
	)

	_player.spells.failed.connect(_show_message)
	_player.spells.failed.connect(func(_message: String) -> void: Sfx.play("error"))
	_player.combatant.died.connect(_show_message.bind("You died"))
	_player.progression.xp_gained.connect(func(amount: int) -> void:
		_add_float(_player.combatant, "+%d XP" % amount, Color(0.75, 0.55, 1))
	)
	_player.progression.leveled_up.connect(_on_leveled_up)
	GameState.quest_message.connect(_on_quest_message)
	# A static function stays connected across scene reloads (death, log out).
	if not GameState.inventory_changed.is_connected(QuestLog.on_inventory_changed):
		GameState.inventory_changed.connect(QuestLog.on_inventory_changed)
	GameState.quests_changed.connect(_update_tracker)
	Settings.changed.connect(func(key: String) -> void:
		if key == "quest_tracker":
			_update_tracker()
	)
	GameState.inventory_changed.connect(_update_tracker)
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


## Whether a window point is over any visible HUD control that takes the
## mouse: windows, bars and frames.
func is_over_ui(point: Vector2) -> bool:
	return _over_control(self, point)


func _over_control(node: Node, point: Vector2) -> bool:
	for child in node.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and control.get_global_rect().has_point(point):
			return true
		if _over_control(control, point):
			return true
	return false


## A click on the world with an item on the cursor asks to destroy it.
## Returns whether it did, so the click doesn't also pick a target.
func drop_held_item() -> bool:
	return _inventory.drop_held_on_world()


func _process(delta: float) -> void:
	if not _player:
		return
	var me := _player.combatant
	_set_bar(_player_health, me.health, me.max_health)
	_player_health_text.text = "%d/%d" % [me.health, me.max_health]
	_set_bar(_player_mana, me.mana, me.max_mana)
	_player_mana_text.text = "%d/%d" % [int(me.mana), me.max_mana]
	_player_level.text = "Lv %d" % me.level
	# No XP bar at the level cap, as in classic.
	_player_xp.get_parent().visible = me.level < ClassicData.MAX_LEVEL
	if me.level < ClassicData.MAX_LEVEL:
		var needed := ClassicData.xp_to_next(me.level)
		_set_bar(_player_xp, GameState.xp, needed)
		_player_xp_text.text = "%d/%d XP" % [GameState.xp, needed]

	var target := _player.targeting.target_combatant()
	var npc := _player.targeting.target as Npc
	_target_frame.visible = target != null or npc != null
	if npc:
		# Friendly NPCs: green name, full bar, no level or numbers.
		_target_name.text = npc.npc_name
		_target_name.add_theme_color_override("font_color", Targeting.FRIENDLY_COLOR)
		_target_level.text = ""
		_set_bar(_target_health, 1.0, 1.0)
		_target_health.color = Targeting.FRIENDLY_COLOR.darkened(0.3)
		_target_health_text.text = ""
	elif target:
		_target_health.color = TARGET_HEALTH
		_target_name.text = target.display_name
		_target_name.add_theme_color_override("font_color", Targeting.name_color(target.body))
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
	_quest_note_left -= delta
	_quest_note.visible = _quest_note_left > 0.0
	_banner_left -= delta
	_banner.visible = _banner_left > 0.0
	_update_durability_warning()
	_update_floats(delta)
	_update_enemy_names()
	_update_unit_tooltip()
	_update_npc_names()
	_update_loot_log(delta)


func _build() -> void:
	var open_windows := _inventory.open_state() if _inventory else {}
	var book_open := _spells.is_book_open() if _spells else false
	var log_open := _quest_log.visible if _quest_log else false
	for child in get_children():
		child.free()
	_floats.clear()
	_enemy_names.clear()
	_npc_names.clear()

	var window := get_viewport().get_visible_rect().size
	_ui_scale = Settings.hud_scale(window.y)
	_width = window.x / _ui_scale
	_height = window.y / _ui_scale

	_build_enemy_names()
	_build_npc_names()
	_build_player_frame()
	_build_target_frame()
	_build_cast_bar()
	_message = _label(self, Vector2(0, 34), "", Color(1, 0.35, 0.3))
	_message.size.x = window.x
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_note = _label(self, Vector2(0, 44), "", QuestLog.YELLOW)
	_quest_note.size.x = window.x
	_quest_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_note.visible = false
	_tracker = RichTextLabel.new()
	_tracker.bbcode_enabled = true
	_tracker.fit_content = true
	_tracker.scroll_active = false
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under the minimap, its right edge in line with the minimap's.
	var map_corner := Minimap.corner(_width)
	_tracker.position = Vector2(_width - Minimap.MARGIN - TRACKER_WIDTH, map_corner.y + Minimap.SIZE + 4) * _ui_scale
	_tracker.size = Vector2(TRACKER_WIDTH, 0) * _ui_scale
	_tracker.add_theme_font_size_override("normal_font_size", roundi(SHEET_FONT_SIZE * _ui_scale))
	_tracker.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tracker.add_theme_constant_override("shadow_offset_x", maxi(roundi(_ui_scale), 1))
	_tracker.add_theme_constant_override("shadow_offset_y", maxi(roundi(_ui_scale), 1))
	add_child(_tracker)
	_update_tracker()
	_banner = _label(self, Vector2(0, 60), "", Color(1, 0.85, 0.3))
	_banner.add_theme_font_size_override("font_size", roundi(BANNER_FONT_SIZE * _ui_scale))
	_banner.size.x = window.x
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	_minimap = Minimap.new()
	add_child(_minimap)
	_minimap.setup(_player, _game_view.get_node("GameViewport/World"), _ui_scale, _width)
	# Left of the minimap, under the buffs.
	_durability_warning = _label(self, Vector2(map_corner.x - 50, map_corner.y + 20), "", Color.WHITE)
	_durability_warning.add_theme_font_size_override("font_size", roundi(SHEET_FONT_SIZE * _ui_scale))
	_durability_warning.visible = false
	_loot_log = _label(self, Vector2(4, _height - 60), "", Color(0.4, 0.75, 1))
	_loot_log.add_theme_font_size_override("font_size", roundi(SHEET_FONT_SIZE * _ui_scale))
	_loot_window = LootWindow.new()
	_loot_window.position = Vector2(130, 60) * _ui_scale
	_loot_window.visible = false
	add_child(_loot_window)
	_loot_window.message.connect(_on_loot_message)
	_loot_window.closed.connect(func() -> void: _loot_corpse = null)
	_inventory = InventoryUI.new()
	_inventory.is_over_ui = is_over_ui
	add_child(_inventory)
	_spells = SpellUI.new()
	add_child(_spells)
	_tooltip = ItemTooltip.new()
	_tooltip.setup(_ui_scale)
	add_child(_tooltip)
	_minimap.tooltip = _tooltip
	_unit_tooltip = ItemTooltip.new()
	_unit_tooltip.anchored = true
	_unit_tooltip.setup(_ui_scale)
	add_child(_unit_tooltip)
	_unit_lines = []
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
	_quest_log = QuestLogUI.new()
	_quest_log.position = Vector2(4, 48) * _ui_scale
	_quest_log.setup(_ui_scale)
	add_child(_quest_log)
	_quest_log.hovered.connect(_tooltip.show_item)
	if log_open:
		_quest_log.toggle()
	_quest_window = QuestWindow.new()
	_quest_window.position = Vector2(130, 40) * _ui_scale
	_quest_window.visible = false
	add_child(_quest_window)
	_quest_window.message.connect(_on_loot_message)
	_quest_window.hovered.connect(_tooltip.show_item)
	_quest_window.service.connect(_open_service)
	_quest_window.visibility_changed.connect(func() -> void:
		if not _quest_window.visible:
			_quest_npc = null
	)
	if _quest_npc and is_instance_valid(_quest_npc):
		_quest_window.open(_quest_npc, _player, _ui_scale)
	move_child(_tooltip, -1)
	if _loot_corpse and is_instance_valid(_loot_corpse) and _loot_corpse.has_loot():
		_loot_window.open(_loot_corpse, _player, _ui_scale)


## Yellow when any equipped item is low on durability, red when one is broken.
func _update_durability_warning() -> void:
	var lowest := Inventory.lowest_durability()
	_durability_warning.visible = lowest <= DURABILITY_WARNING
	if _durability_warning.visible:
		var broken := lowest <= 0.0
		_durability_warning.text = "Gear broken" if broken else "Gear damaged"
		_durability_warning.add_theme_color_override("font_color", Color(1, 0.2, 0.2) if broken else Color(1, 0.85, 0.2))


func _build_player_frame() -> void:
	var frame := _frame(Vector2(4, 4), Vector2(90, 35))
	_label(frame, Vector2(3, 0), _player.combatant.display_name)
	_player_level = _right_label(frame, Vector2(3, 0), 84)
	_player_health = _bar(frame, Vector2(3, 12), Vector2(84, 10), Color(0.25, 0.7, 0.25))
	_player_health_text = _bar_text(frame, Vector2(3, 12), Vector2(84, 10))
	_player_mana = _bar(frame, Vector2(3, 23), Vector2(84, 9), Color(0.2, 0.4, 0.85))
	_player_mana_text = _bar_text(frame, Vector2(3, 23), Vector2(84, 9))
	_build_xp_bar()


## The XP bar spans the action bar, just above it, below the stance bar.
func _build_xp_bar() -> void:
	var width := GameState.ACTION_SLOTS * (SpellUI.SLOT + SpellUI.GAP) - SpellUI.GAP
	var at := Vector2((_width - width) / 2.0, _height - SpellUI.SLOT - 4 - SpellUI.GAP - SpellUI.XP_BAR)
	var frame := _frame(at, Vector2(width, SpellUI.XP_BAR))
	# Part of the action bar area: the wheel over it doesn't zoom the camera.
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_rect(frame, Vector2(1, 1), Vector2(width - 2, SpellUI.XP_BAR - 2), Color(0.15, 0.1, 0.2))
	_player_xp = _bar(frame, Vector2(1, 1), Vector2(width - 2, SpellUI.XP_BAR - 2), Color(0.55, 0.3, 0.85))
	_player_xp_text = _bar_text(frame, Vector2(0, 0), Vector2(width, SpellUI.XP_BAR), XP_FONT_SIZE)


func _build_target_frame() -> void:
	_target_frame = _frame(Vector2(100, 4), Vector2(90, 24))
	_target_name = _label(_target_frame, Vector2(3, 0), "")
	_target_level = _right_label(_target_frame, Vector2(3, 0), 84)
	_target_health = _bar(_target_frame, Vector2(3, 12), Vector2(84, 10), TARGET_HEALTH) as ColorRect
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


func _update_enemy_names() -> void:
	var shown: bool = Settings.get_value("enemy_names")
	for entry in _enemy_names:
		var combatant: Combatant = entry.combatant
		var label: Label = entry.label
		var world: Vector3 = combatant.body.global_position + Vector3.UP * NAMEPLATE_HEIGHT
		label.visible = (
			shown
			and combatant.is_alive()
			and not _camera.is_position_behind(world)
			and _camera.global_position.distance_to(world) <= NAMEPLATE_RANGE
		)
		if label.visible:
			var on_window: Vector2 = _camera.unproject_position(world) * _game_view.stretch_shrink
			label.position = on_window - Vector2(label.size.x / 2.0, label.size.y)


## Friendly NPC names in green, with their title below, as in classic.
func _build_npc_names() -> void:
	for npc: Node in get_tree().get_nodes_in_group("npcs"):
		var name_label := _label(self, Vector2.ZERO, "%s
<%s>" % [npc.npc_name, npc.subname], Targeting.FRIENDLY_COLOR)
		name_label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var marker := _label(self, Vector2.ZERO, "", QuestLog.YELLOW)
		marker.add_theme_font_size_override("font_size", roundi(QUEST_MARKER_SIZE * _ui_scale))
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_npc_names.append({ "npc": npc, "label": name_label, "marker": marker })


func _update_npc_names() -> void:
	for entry in _npc_names:
		var npc: Node3D = entry.npc
		var label: Label = entry.label
		var world := npc.global_position + Vector3.UP * NAMEPLATE_HEIGHT
		var on_screen := not _camera.is_position_behind(world) and _camera.global_position.distance_to(world) <= NAMEPLATE_RANGE
		# With names hidden, quest markers still show, as in classic.
		label.visible = on_screen
		label.modulate.a = 1.0 if Settings.get_value("npc_names") else 0.0
		if label.visible:
			var on_window: Vector2 = _camera.unproject_position(world) * _game_view.stretch_shrink
			label.position = on_window - Vector2(label.size.x / 2.0, label.size.y)
		# "!" or "?" over quest givers, as in classic.
		var marker: Label = entry.marker
		var shown: Array = QuestLog.marker(npc.npc_id()) if label.visible else ["", Color.WHITE]
		marker.visible = not str(shown[0]).is_empty()
		if marker.visible:
			marker.text = shown[0]
			marker.add_theme_color_override("font_color", shown[1])
			marker.position = label.position + Vector2((label.size.x - marker.size.x) / 2.0, -marker.size.y + 2 * _ui_scale)


func _build_enemy_names() -> void:
	for node in get_tree().get_nodes_in_group("combatants"):
		if node != _player.combatant:
			var combatant := node as Combatant
			var label := _label(self, Vector2.ZERO, combatant.display_name, Targeting.name_color(combatant.body))
			label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_enemy_names.append({ "combatant": combatant, "label": label })


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
	if not QuestLog.for_npc(npc.npc_id()).is_empty():
		close_vendor()
		close_trainer()
		_quest_npc = npc
		_quest_window.open(npc, _player, _ui_scale)
		return
	_open_service(npc, "vendor" if npc.vendor != 0 else "trainer")


## Opens an NPC's vendor or trainer window.
func _open_service(npc: Npc, kind: String) -> void:
	if kind == "vendor" and npc.vendor != 0:
		_vendor_npc = npc
		_vendor.open(npc, _player, _ui_scale)
		_inventory.selling = true
		_inventory.open_bags()
	elif kind == "trainer" and not npc.trainer.is_empty():
		_trainer_npc = npc
		_trainer.open(npc, _player, _ui_scale)


## Describes the unit under the mouse, unless the mouse is over the HUD or
## dragging the camera. Redrawn only when its text changes.
func _update_unit_tooltip() -> void:
	var lines := []
	var mouse := get_viewport().get_mouse_position()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not is_over_ui(mouse):
		var unit := _player.targeting.unit_at(mouse / _game_view.stretch_shrink)
		if unit:
			lines = unit_tooltip(unit)
	if lines != _unit_lines:
		_unit_lines = lines
		_unit_tooltip.show_lines(lines)
	# Sits above the bags when they're open in the same corner, as in classic.
	var bags := _inventory.bags_rect()
	_unit_tooltip.anchor_lift = 0.0 if bags.size == Vector2.ZERO else get_viewport().get_visible_rect().size.y - bags.position.y


## Classic unit tooltip rows: the name in its reaction color, level and kind
## for creatures (or the title for NPCs), then any quests underway that the
## creature counts toward, with their progress.
func unit_tooltip(unit: Node3D) -> Array:
	if unit is Npc:
		var npc := unit as Npc
		return [[npc.npc_name, "", Targeting.FRIENDLY_COLOR], ["<%s>" % npc.subname, "", Color.WHITE]]
	var enemy := unit as Enemy
	if enemy == null:
		return []
	var data := Enemy.creature_data(enemy.creature_entry)
	var alive := enemy.combatant.is_alive()
	var lines := [[enemy.combatant.display_name, "", Targeting.name_color(enemy) if alive else GREY]]
	var kind: String = CREATURE_TYPES.get(int(data.get("CreatureType", 0)), "")
	var level := "Level %d%s %s" % [enemy.level, " (Elite)" if enemy.elite else "", kind]
	lines.append([level.strip_edges(), "", CombatRules.level_color(_player.combatant.level, enemy.level) if alive else GREY])
	if not alive:
		lines.append(["Corpse", "", GREY])
	for quest: Array in QuestLog.objectives_for_creature(enemy.creature_entry, int(data.get("LootId", 0))):
		lines.append([quest[0], "", Color.WHITE])
		for objective: Array in quest[1]:
			lines.append([" - " + objective[0], "", QUEST_DONE if objective[1] else GREY])
	return lines


## Esc: closes the quest window, then the quest log.
func close_quests() -> bool:
	if _quest_window.visible:
		_quest_window.close()
		return true
	return _quest_log.close()


func _on_quest_message(text: String) -> void:
	_quest_note.text = text
	_quest_note_left = QUEST_NOTE_TIME


## The tracker: each quest underway with its objectives, finished ones in
## green, as the classic quest watch.
func _update_tracker() -> void:
	if not _tracker:
		return
	_tracker.visible = Settings.get_value("quest_tracker")
	var lines := PackedStringArray()
	for id: int in GameState.quests:
		var quest := QuestDB.get_quest(id)
		var objectives := QuestLog.objective_lines(id)
		var complete := QuestLog.is_complete(id)
		lines.append("[color=#ffd100]%s[/color]%s" % [quest.title, " [color=#73e673](Complete)[/color]" if complete else ""])
		if objectives.is_empty() and complete:
			continue
		for objective: Array in objectives:
			lines.append("[color=%s]  - %s[/color]" % ["#73e673" if objective[1] else "#e6e6e6", objective[0]])
	_tracker.text = "\n".join(lines)


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
	# At the cap the XP bar goes, and the stance bar moves down into its place.
	if new_level >= ClassicData.MAX_LEVEL:
		_build.call_deferred()
	show_banner("Level %d!" % new_level)
	Sfx.play("level_up")


## Big text across the screen for a moment, like a zone name or level-up.
func show_banner(text: String) -> void:
	_banner.text = text
	_banner_left = BANNER_TIME


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
