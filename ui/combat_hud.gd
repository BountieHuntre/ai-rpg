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
## Gap from the cast bar's top to the stance bar's.
const CAST_BAR_ABOVE_STANCE := 17.0
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
## Party frames fade for members further away than this, as in classic.
const PARTY_RANGE := 40.0
const PARTY_FRAME_SIZE := Vector2(80, 25)
## A party Ranger's pet strip under its frame: its height and text size.
const PARTY_PET_STRIP := 10.0
const PET_STRIP_FONT := 5
## The player and target frames' bar width, and the least gap between a
## frame's name and its level; frames widen for longer names.
const FRAME_INNER := 84.0
## Portrait squares in the player and target frames, and in party frames.
const PORTRAIT := 31.0
const PARTY_PORTRAIT := 21.0
const NAME_LEVEL_GAP := 4.0
const PARTY_XP := Color(0.55, 0.3, 0.85)
## Unit menu entries.
enum MenuItem { WHISPER, INVITE, REMOVE, FOLLOW, STAY, TRADE, CANCEL }

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
## The Spellsword's Resonance: five gems along the player frame's foot.
var _resonance: Control
const RESONANCE_GEM := 4.2
var _player_level: Label
var _player_xp: Control
var _player_xp_text: Label
var _target_frame: Control
## The target frame's inner width (bars and name row) in HUD units, which
## grows with the target's name.
var _target_inner := FRAME_INNER
var _player_frame_width := FRAME_INNER + 6.0
var _target_name: Label
var _target_level: Label
var _banner: Label
var _durability_warning: Label
var _banner_left := 0.0
var _target_health: ColorRect
var _target_health_text: Label
var _target_mana: Control
var _target_mana_back: Control
## The unit frames' portraits, and the key the target's shows.
var _player_portrait: TextureRect
var _target_portrait: TextureRect
var _target_portrait_key := ""
var _target_health_back: Control
var _target_mana_text: Label
var _cast_frame: Control
var _cast_fill: Control
var _cast_name: Label
## The target's cast, under the target frame, so you can see what to interrupt.
var _target_cast: Control
## The target's buffs and debuffs under its frame, rebuilt when they change.
var _target_auras: Control
var _target_auras_key := ""
var _target_auras_height := 0.0
const TARGET_AURA := 10.0
const TARGET_AURAS_PER_ROW := 8
var _target_cast_fill: Control
var _target_cast_name: Label
var _message: Label
var _message_left := 0.0
var _floats: Array[Dictionary] = []
var _float_layer: Control
var _next_float_offset := 0
## Names over creatures, colored by how they'll react: [{ combatant, label }].
var _enemy_names: Array[Dictionary] = []
var _inventory: InventoryUI
var _spells: SpellUI
var _talents: TalentWindow
var _trainer: TrainerWindow
## The Ranger's Beast Training and a stable master's stable.
var _beast_training: BeastTrainingWindow
var _stable: StableWindow
var _trainer_npc: Node3D
var _vendor: VendorWindow
var _vendor_npc: Node3D
var _npc_names: Array[Dictionary] = []
var _quest_window: QuestWindow
var _quest_npc: Npc
var _quest_log: QuestLogUI
var _social: SocialWindow
## Orders for party bots (K), and a party bot's bags.
var _party_bar: PartyBar
var _bot_bag: BotBagWindow
var _world_map: WorldMap
var _micro_menu: MicroMenu
## The Main Menu button opens the game menu, which main.gd holds: it connects
## this and sets menu_open to say whether the menu is up.
signal main_menu_requested
var menu_open := func() -> bool: return false
var _trade: TradeWindow
## Objectives of the quests underway, down the right side.
var _tracker: RichTextLabel
var _minimap: Minimap
## Quest progress ("Burrowling Runt slain: 3/10"), in yellow under messages.
var _quest_note: Label
var _quest_note_left := 0.0
var _loot_window: LootWindow
var _loot_corpse: Node3D
var _tooltip: ItemTooltip
## The creature or NPC under the mouse, described in the bottom right corner.
var _unit_tooltip: ItemTooltip
var _unit_lines: Array = []
var _chat: ChatFrame
## Show Frame Rate: frames per second, in the top right corner of the screen.
const FPS_WIDTH := 30.0
var _fps: Label
## Recent loot messages as [text, seconds left].
## Party frames: { "bot", "frame", "name", "level", "health", "mana" }.
var _party_frames: Array[Dictionary] = []
## A Ranger's pet frame, under the player frame: { "frame", "name", "level",
## "health", "focus", "xp", "xp_back" }, or {} for other classes.
var _pet_frame: Dictionary = {}
var _pet_menu: PopupMenu
const PET_FRAME_SIZE := Vector2(80, 22)
const FOCUS_COLOR := Color(0.85, 0.6, 0.2)
var _unit_menu: PopupMenu
var _menu_bot: Bot
## Combatants whose hits, heals and stuns show as floating text.
var _watched: Dictionary = {}


func setup(player: Player, camera: Camera3D, game_view: SubViewportContainer) -> void:
	_player = player
	_camera = camera
	_game_view = game_view
	_build()
	get_viewport().size_changed.connect(_build)
	Settings.changed.connect(func(key: String) -> void:
		if key == "ui_scale" or key.begins_with("chat_") or key.begins_with("bar_"):
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
	Party.message.connect(_on_party_message)
	Party.changed.connect(_on_party_changed)
	_watch_combatants()


## Floating combat text for every combatant, the playerbots that come and go
## included.
func _watch_combatants() -> void:
	for node in get_tree().get_nodes_in_group("combatants"):
		var combatant := node as Combatant
		if _watched.has(combatant):
			continue
		_watched[combatant] = true
		var hit_color := Color(1, 0.3, 0.3) if combatant == _player.combatant else Color.WHITE
		# As in classic, only your own fight shows: hits you deal and take,
		# misses either way, heals on you, and stuns on you or your target.
		combatant.took_damage.connect(func(amount: int, source: Combatant, crit: bool) -> void:
			if _involves_player(combatant, source):
				_add_float(combatant, "%d!" % amount if crit else str(amount), hit_color, crit)
		)
		combatant.avoided.connect(func(text: String, source: Combatant) -> void:
			if _involves_player(combatant, source):
				_add_float(combatant, text, Color(0.8, 0.8, 0.8))
		)
		combatant.healed.connect(func(amount: int, crit: bool) -> void:
			if combatant == _player.combatant:
				_add_float(combatant, "+%d%s" % [amount, "!" if crit else ""], Color(0.4, 1, 0.4), crit)
		)
		combatant.cast_interrupted.connect(func() -> void:
			if combatant == _player.combatant or combatant == _player.targeting.target_combatant():
				_add_float(combatant, "Interrupted", Color(1, 0.9, 0.3))
		)
		combatant.stunned.connect(func() -> void:
			if combatant == _player.combatant or combatant == _player.targeting.target_combatant():
				_add_float(combatant, "Stunned", Color(1, 0.9, 0.3))
		)


## Whether a hit is the player's: struck or dealt by them.
func _involves_player(struck: Combatant, source: Combatant) -> bool:
	var me := _player.combatant
	return struck == me or (source != null and is_instance_valid(source) and source == me)


## Playerbots came or went: watch the new ones and redraw names and frames.
func refresh_units() -> void:
	for key: Variant in _watched.keys():
		if not is_instance_valid(key):
			_watched.erase(key)
	_watch_combatants()
	_build.call_deferred()


func _on_party_changed() -> void:
	_build.call_deferred()


func _on_party_message(text: String) -> void:
	_on_loot_message(text, false)


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
	(_player_mana as ColorRect).color = power_color(me)
	_set_bar(_player_mana, me.mana, me.max_mana)
	_player_mana_text.text = "%d/%d" % [int(me.mana), me.max_mana]
	if _resonance:
		_resonance.queue_redraw()
	_player_level.text = "Lv %d" % me.level
	# No XP bar at the level cap, as in classic.
	_player_xp.get_parent().visible = me.level < ClassicData.MAX_LEVEL
	if me.level < ClassicData.MAX_LEVEL:
		var needed := ClassicData.xp_to_next(me.level)
		_set_bar(_player_xp, GameState.xp, needed)
		_player_xp_text.text = "%d/%d XP" % [GameState.xp, needed]

	var target := _player.targeting.target_combatant()
	var npc := _player.targeting.target as Npc
	var bot := _player.targeting.target as Bot
	_target_frame.visible = target != null or npc != null or bot != null
	if bot:
		# Other players: blue name, green health bar.
		var c := bot.combatant
		_target_name.text = c.display_name
		_target_name.add_theme_color_override("font_color", Targeting.PLAYER_COLOR)
		_target_level.text = "Lv %d" % c.level
		_target_level.add_theme_color_override("font_color", Color.WHITE)
		_target_health.color = Color(0.25, 0.7, 0.25)
		_set_bar(_target_health, c.health, c.max_health)
		_target_health_text.text = "%d/%d" % [c.health, c.max_health] if c.is_alive() else "Dead"
		_show_target_mana(c)
	elif npc:
		# Friendly NPCs: green name, full bar, no level or numbers.
		_target_name.text = npc.npc_name
		_target_name.add_theme_color_override("font_color", Targeting.FRIENDLY_COLOR)
		_target_level.text = ""
		_set_bar(_target_health, 1.0, 1.0)
		_target_health.color = Targeting.FRIENDLY_COLOR.darkened(0.3)
		_target_health_text.text = ""
		_show_target_mana(null)
	elif target:
		# Creatures tapped by someone outside the party show a grey bar.
		_target_health.color = Targeting.TAPPED_COLOR.darkened(0.3) if (target.body as Enemy).is_tapped_by_others() else TARGET_HEALTH
		_target_name.text = target.display_name
		_target_name.add_theme_color_override("font_color", Targeting.name_color(target.body))
		# Bosses show "??" in red, elites a "+", as classic's frames do.
		var creature := target.body as Enemy
		_target_level.text = "Lv ??" if creature.boss else "Lv %d%s" % [target.level, "+" if creature.elite else ""]
		_target_level.add_theme_color_override("font_color", Color(1, 0.1, 0.1) if creature.boss else CombatRules.level_color(me.level, target.level))
		_set_bar(_target_health, target.health, target.max_health)
		_target_health_text.text = "%d/%d" % [target.health, target.max_health]
		_show_target_mana(target)

	if _target_frame.visible:
		_fit_target_frame()
		var shown: Node = _player.targeting.target
		var key := Icons.portrait_key(shown) if shown else "token"
		if key != _target_portrait_key:
			_target_portrait_key = key
			_target_portrait.texture = Icons.texture(key)
	_update_target_auras(target if target else (bot.combatant if bot else null))
	_update_target_cast(target if target else (bot.combatant if bot else null))

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
	_update_party_frames()
	_fps.visible = Settings.get_value("show_fps")
	if _fps.visible:
		_fps.text = "%d fps" % Engine.get_frames_per_second()
	_update_enemy_names()
	_update_unit_tooltip()
	_update_npc_names()


func _build() -> void:
	var open_windows := _inventory.open_state() if _inventory else {}
	var book_open := _spells.is_book_open() if _spells else false
	var talents_open := _talents.is_open() if _talents and is_instance_valid(_talents) else false
	var log_open := _quest_log.visible if _quest_log else false
	var social_open := _social.visible if _social else false
	var bag_bot: Bot = _bot_bag.bot if _bot_bag and _bot_bag.is_open() else null
	if _bot_bag:
		_bot_bag.close()
	var map_open := _world_map.visible if _world_map else false
	for child in get_children():
		child.free()
	_floats.clear()
	_enemy_names.clear()
	_npc_names.clear()

	var window := get_viewport().get_visible_rect().size
	_ui_scale = Settings.hud_scale(window.y)
	_width = window.x / _ui_scale
	_height = window.y / _ui_scale

	# Floating combat text sits under every frame and window.
	_float_layer = Control.new()
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)
	_build_enemy_names()
	_build_npc_names()
	_build_player_frame()
	_build_party_frames()
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
	# Left of the right action bars, when they're shown.
	var bars_width: float = SpellUI.right_bars_layout(Vector2(_width, _height)).width
	_tracker.position = Vector2(_width - Minimap.MARGIN - TRACKER_WIDTH - bars_width - (4.0 if bars_width > 0.0 else 0.0), map_corner.y + Minimap.SIZE + 4) * _ui_scale
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
	# In the very top right corner of the screen.
	_fps = _label(self, Vector2(_width - FPS_WIDTH - 1, 0), "", Color(0.6, 1, 0.6))
	_fps.add_theme_font_size_override("font_size", roundi(SHEET_FONT_SIZE * _ui_scale))
	_fps.size.x = FPS_WIDTH * _ui_scale
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps.visible = false
	_minimap = Minimap.new()
	add_child(_minimap)
	_minimap.setup(_player, _game_view.get_node("GameViewport/World"), _ui_scale, _width)
	# Left of the minimap, under the buffs.
	_durability_warning = _label(self, Vector2(map_corner.x - 50, map_corner.y + 20), "", Color.WHITE)
	_durability_warning.add_theme_font_size_override("font_size", roundi(SHEET_FONT_SIZE * _ui_scale))
	_durability_warning.visible = false
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
	_talents = TalentWindow.new()
	add_child(_talents)
	_talents.setup(_player, _ui_scale, Vector2(_width, _height), _tooltip, talents_open)
	move_child(_tooltip, -1)
	_trainer = TrainerWindow.new()
	_trainer.position = Vector2(130, 50) * _ui_scale
	_trainer.visible = false
	add_child(_trainer)
	move_child(_tooltip, -1)
	_trainer.message.connect(_on_loot_message)
	_trainer.hovered.connect(func(id: int) -> void: _tooltip.show_lines(_spells.spell_tooltip(id)))
	if _trainer_npc and is_instance_valid(_trainer_npc):
		_trainer.open(_trainer_npc, _player, _ui_scale)
	_beast_training = BeastTrainingWindow.new()
	_beast_training.position = Vector2(130, 50) * _ui_scale
	_beast_training.visible = false
	add_child(_beast_training)
	_beast_training.message.connect(_on_loot_message)
	_player.spells.ranger().beast_training_requested.connect(func() -> void: _beast_training.open(_player, _ui_scale))
	_stable = StableWindow.new()
	_stable.position = Vector2(130, 50) * _ui_scale
	_stable.visible = false
	add_child(_stable)
	_stable.message.connect(_on_loot_message)
	move_child(_tooltip, -1)
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
	_social = SocialWindow.new()
	_social.position = Vector2(4, 48) * _ui_scale
	_social.setup(_ui_scale)
	add_child(_social)
	_social.message.connect(_on_loot_message)
	var typing: bool = _chat.is_typing() if _chat and is_instance_valid(_chat) else false
	_chat = ChatFrame.new()
	add_child(_chat)
	_chat.setup(_ui_scale, Vector2(_width, _height), _player, _social, _tooltip, _open_name_menu)
	_inventory.link_requested.connect(_chat.insert_item)
	_quest_log.link_requested.connect(_chat.insert_quest)
	if typing:
		_chat.open()
	if social_open:
		_social.toggle()
	_quest_window = QuestWindow.new()
	_quest_window.position = Vector2(130, 40) * _ui_scale
	_quest_window.visible = false
	add_child(_quest_window)
	_quest_window.message.connect(_on_loot_message)
	_quest_window.hovered.connect(_tooltip.show_item)
	_quest_window.service.connect(_open_service)
	# Using an item that starts a quest offers the quest.
	_inventory.quest_item_used.connect(func(item_id: int) -> void:
		close_vendor()
		close_trainer()
		_quest_npc = null
		_quest_window.open_item(item_id, _player, _ui_scale)
	)
	_quest_window.visibility_changed.connect(func() -> void:
		if not _quest_window.visible:
			_quest_npc = null
	)
	if _quest_npc and is_instance_valid(_quest_npc):
		_quest_window.open(_quest_npc, _player, _ui_scale)
	move_child(_tooltip, -1)
	if _loot_corpse and is_instance_valid(_loot_corpse) and _loot_corpse.has_loot():
		_loot_window.open(_loot_corpse, _player, _ui_scale)
	var trading_with: Bot = _trade.bot if _trade and is_instance_valid(_trade) and _trade.is_open() else null
	if trading_with:
		_trade.cancel()
	_trade = TradeWindow.new()
	_trade.position = Vector2(130, 40) * _ui_scale
	add_child(_trade)
	_trade.setup(_player, _inventory, _ui_scale)
	_trade.message.connect(_on_loot_message)
	_trade.hovered.connect(_tooltip.show_item)
	# The menu buttons right of the action bar.
	_micro_menu = MicroMenu.new()
	add_child(_micro_menu)
	_micro_menu.setup(_ui_scale, Vector2(_width, _height), _tooltip, {
		"character_window": func() -> bool: return _inventory.open_state().get("character", false),
		"spellbook": func() -> bool: return _spells.is_book_open(),
		"talents": func() -> bool: return _talents.is_open(),
		"quest_log": func() -> bool: return _quest_log.visible,
		"social": func() -> bool: return _social.visible,
		"party_commands": func() -> bool: return _party_bar != null and _party_bar.is_shown(),
		"world_map": func() -> bool: return _world_map.visible,
		"main_menu": func() -> bool: return menu_open.call(),
	})
	_micro_menu.main_menu_requested.connect(func() -> void: main_menu_requested.emit())
	# Party commands above the menu buttons, and a party bot's bags.
	_party_bar = PartyBar.new()
	add_child(_party_bar)
	_party_bar.setup(_player, _ui_scale, _tooltip, _micro_menu)
	_party_bar.message.connect(_on_loot_message)
	_bot_bag = BotBagWindow.new()
	_bot_bag.position = Vector2(_width - 260, 60) * _ui_scale
	add_child(_bot_bag)
	_bot_bag.setup(_inventory, _tooltip, _ui_scale)
	_bot_bag.message.connect(_on_loot_message)
	_party_bar.bag_requested.connect(func(bot: Bot) -> void:
		_bot_bag.toggle(bot)
		if _bot_bag.is_open():
			# Left of your bags, their bottoms level, so items go across.
			_inventory.open_bags()
			var bags := _inventory.bags_rect()
			var room := Rect2(Vector2(_width, _height) * _ui_scale, Vector2.ZERO) if bags.size == Vector2.ZERO else bags
			_bot_bag.position = Vector2(maxf(room.position.x - _bot_bag.size.x - 3 * _ui_scale, 0.0), maxf(room.end.y - _bot_bag.size.y, 0.0)))
	if bag_bot and is_instance_valid(bag_bot):
		_bot_bag.open(bag_bot)
	move_child(_tooltip, -1)
	# The world map covers the screen, over the other windows.
	_world_map = WorldMap.new()
	add_child(_world_map)
	_world_map.setup(_player, _game_view.get_node("GameViewport/World"), _minimap, _ui_scale, Vector2(_width, _height))
	# Its quest tooltips show over it.
	move_child(_tooltip, -1)
	if map_open:
		_world_map.open()
	_unit_menu = PopupMenu.new()
	_unit_menu.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
	_unit_menu.id_pressed.connect(_on_unit_menu)
	add_child(_unit_menu)
	# The unit tooltip stays in its corner over the bags and windows, under
	# the item tooltip.
	move_child(_unit_tooltip, -1)
	move_child(_tooltip, -1)


## Yellow when any equipped item is low on durability, red when one is broken.
func _update_durability_warning() -> void:
	var lowest := Inventory.lowest_durability()
	_durability_warning.visible = lowest <= DURABILITY_WARNING
	if _durability_warning.visible:
		var broken := lowest <= 0.0
		_durability_warning.text = "Gear broken" if broken else "Gear damaged"
		_durability_warning.add_theme_color_override("font_color", Color(1, 0.2, 0.2) if broken else Color(1, 0.85, 0.2))


func _build_player_frame() -> void:
	var name_label := _label(self, Vector2.ZERO, _player.combatant.display_name)
	var inner := _name_row_width(name_label, "Lv %d" % ClassicData.MAX_LEVEL, FRAME_INNER)
	name_label.queue_free()
	# The portrait on the left, the name, level and bars beside it.
	var x0 := PORTRAIT + 5.0
	_player_frame_width = x0 + inner + 3.0
	var frame := _frame(Vector2(4, 4), Vector2(_player_frame_width, 35))
	_player_portrait = _portrait(frame, Vector2(2, 2), PORTRAIT, Icons.portrait_key(_player))
	_label(frame, Vector2(x0, 0), _player.combatant.display_name)
	_player_level = _right_label(frame, Vector2(x0, 0), inner)
	_trough(frame, Vector2(x0, 12), Vector2(inner, 10))
	_player_health = _bar(frame, Vector2(x0, 12), Vector2(inner, 10), Color(0.25, 0.7, 0.25))
	_player_health_text = _bar_text(frame, Vector2(x0, 12), Vector2(inner, 10))
	_trough(frame, Vector2(x0, 23), Vector2(inner, 9))
	_player_mana = _bar(frame, Vector2(x0, 23), Vector2(inner, 9), Color(0.2, 0.4, 0.85))
	_player_mana_text = _bar_text(frame, Vector2(x0, 23), Vector2(inner, 9))
	if _player.profile.char_class == ClassicData.CharClass.SPELLSWORD:
		_resonance = Control.new()
		_resonance.position = Vector2(x0 + 2, 32.0) * _ui_scale
		_resonance.size = Vector2(5 * (RESONANCE_GEM + 1.6), RESONANCE_GEM + 1) * _ui_scale
		_resonance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_resonance.draw.connect(_draw_resonance)
		frame.add_child(_resonance)
	_build_xp_bar()


## Lit gems for each point of Resonance, dark ones for the rest.
func _draw_resonance() -> void:
	var have := _player.combatant.resonance
	var r := RESONANCE_GEM * _ui_scale / 2.0
	for i in 5:
		var center := Vector2((i * (RESONANCE_GEM + 1.6) + RESONANCE_GEM / 2.0) * _ui_scale, r + 0.5 * _ui_scale)
		var gem := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
		_resonance.draw_colored_polygon(gem, Color(0.75, 0.55, 1.0) if i < have else Color(0.12, 0.1, 0.16))
		_resonance.draw_polyline(gem + PackedVector2Array([gem[0]]), UiStyle.GOLD, maxf(_ui_scale * 0.5, 1.0))


## Width in HUD units a frame's top row needs for a name, a gap and a level
## (or other right-hand text), at least `minimum`: names are never cut off.
func _name_row_width(name_label: Label, right_text: String, minimum: float) -> float:
	var font := name_label.get_theme_font("font")
	var size := name_label.get_theme_font_size("font_size")
	var needed := font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	needed += font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return maxf(minimum, ceilf(needed / _ui_scale) + NAME_LEVEL_GAP)


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


## The target frame, with a mana bar under the health bar for targets that
## have mana. Right-click it on a playerbot for the bot's menu.
func _build_target_frame() -> void:
	# The portrait on the right, as classic's target frame has it.
	_target_frame = _frame(Vector2(4 + _player_frame_width + 6, 4), Vector2(FRAME_INNER + 8 + PORTRAIT, 35))
	_target_inner = FRAME_INNER
	_target_portrait = _portrait(_target_frame, Vector2(FRAME_INNER + 6, 2), PORTRAIT, "token")
	_target_portrait_key = ""
	_target_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_target_frame.gui_input.connect(_on_target_frame_input)
	_target_name = _label(_target_frame, Vector2(3, 0), "")
	_target_level = _right_label(_target_frame, Vector2(3, 0), 84)
	_target_health_back = _trough(_target_frame, Vector2(3, 12), Vector2(84, 10))
	_target_health = _bar(_target_frame, Vector2(3, 12), Vector2(84, 10), TARGET_HEALTH) as ColorRect
	_target_health_text = _bar_text(_target_frame, Vector2(3, 12), Vector2(84, 10))
	_target_mana_back = _trough(_target_frame, Vector2(3, 23), Vector2(84, 9))
	_target_mana = _bar(_target_frame, Vector2(3, 23), Vector2(84, 9), Color(0.2, 0.4, 0.85))
	_target_mana_text = _bar_text(_target_frame, Vector2(3, 23), Vector2(84, 9))
	_target_auras = Control.new()
	_target_auras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_target_auras)
	_target_auras_key = ""
	_target_cast = _frame(Vector2(4 + _player_frame_width + 6, 41), Vector2(FRAME_INNER + 8 + PORTRAIT, 10))
	_target_cast_fill = _bar(_target_cast, Vector2(1.5, 1.5), Vector2(FRAME_INNER + 5 + PORTRAIT, 7), Color(0.9, 0.65, 0.2))
	_target_cast_name = _bar_text(_target_cast, Vector2(1.5, 1.5), Vector2(FRAME_INNER + 5 + PORTRAIT, 7), XP_FONT_SIZE + 1)
	_target_cast.visible = false


## The spell a unit is casting and how far along, or [] when it isn't.
static func unit_cast(c: Combatant) -> Array:
	var enemy := c.body as Enemy
	if enemy and enemy.ai and not enemy.ai.casting.is_empty():
		return [enemy.ai.casting.SpellName, enemy.ai.cast_fraction()]
	# The player and playerbots each have a SpellCaster.
	var caster := c.body.get("spells") as SpellCaster if c.body is PlayerUnit else null
	if caster and not caster.casting.is_empty():
		return [caster.casting.SpellName, caster.cast_fraction()]
	return []


## Widens (or narrows back) the target frame and its cast bar so the whole
## name fits beside the level.
func _fit_target_frame() -> void:
	var inner := _name_row_width(_target_name, _target_level.text, FRAME_INNER)
	if inner == _target_inner:
		return
	var scale := inner / _target_inner
	_target_inner = inner
	_target_frame.size.x = (inner + 8.0 + PORTRAIT) * _ui_scale
	_target_portrait.get_parent().position.x = (inner + 6.0) * _ui_scale
	_target_level.size.x = inner * _ui_scale
	_target_mana_back.size.x = (inner + 1.2) * _ui_scale
	_target_health_back.size.x = (inner + 1.2) * _ui_scale
	_target_health_text.size.x = inner * _ui_scale
	_target_mana_text.size.x = inner * _ui_scale
	for fill: Control in [_target_health, _target_mana]:
		fill.set_meta("full_width", inner * _ui_scale)
		fill.size.x *= scale
	# The cast bar under it matches its width.
	_target_cast.size.x = (inner + 8.0 + PORTRAIT) * _ui_scale
	_target_cast_name.size.x = (inner + 5.0 + PORTRAIT) * _ui_scale
	_target_cast_fill.set_meta("full_width", (inner + 5.0 + PORTRAIT) * _ui_scale)


func _update_target_cast(c: Combatant) -> void:
	var cast := unit_cast(c) if c and c.is_alive() else []
	_target_cast.visible = not cast.is_empty() and _target_frame.visible
	if _target_cast.visible:
		# Under the target's buffs and debuffs.
		_target_cast.position.y = _target_frame.position.y + _target_frame.size.y + (2.0 + _target_auras_height) * _ui_scale
		_target_cast_name.text = cast[0]
		_set_bar(_target_cast_fill, cast[1], 1.0)


## The target's buffs (first row) and debuffs (second) under its frame, as
## in classic: what enemies of the target put on it are debuffs, and the
## player's own debuffs are framed gold. Hover one for what it does and the
## time left. Passive effects aren't shown.
func _update_target_auras(c: Combatant) -> void:
	var shown: Array = []
	if c and is_instance_valid(c) and c.is_alive() and _target_frame.visible:
		for aura in c.auras:
			if aura.get("talent", false) or SpellDB.is_passive(aura.spell):
				continue
			shown.append(aura)
	var key := str(c.get_instance_id() if c else 0) + ":" + ",".join(shown.map(func(aura: Dictionary) -> String: return str(int(aura.spell.Id))))
	if key != _target_auras_key:
		_target_auras_key = key
		_build_target_auras(c, shown)
	_target_auras.position = Vector2(_target_frame.position.x, _target_frame.position.y + _target_frame.size.y + 2.0 * _ui_scale)
	for icon in _target_auras.get_children():
		if icon.has_meta("aura") and icon.has_meta("time"):
			var aura: Dictionary = icon.get_meta("aura")
			var remaining: float = aura.remaining
			(icon.get_meta("time") as Label).text = "" if remaining < 0.0 else ("%dm" % ceili(remaining / 60.0) if remaining >= 60.0 else "%d" % ceili(remaining))


func _build_target_auras(c: Combatant, shown: Array) -> void:
	for child in _target_auras.get_children():
		child.free()
	_target_auras_height = 0.0
	if shown.is_empty():
		return
	var buffs: Array = []
	var debuffs: Array = []
	for aura: Dictionary in shown:
		var caster: Combatant = aura.caster if is_instance_valid(aura.caster) else null
		# Harmful: from the other side (a player unit on a creature, or a
		# creature on a player unit).
		var harmful := caster != null and caster.is_player != c.is_player
		(debuffs if harmful else buffs).append(aura)
	var row := 0
	for list: Array in [buffs, debuffs]:
		if list.is_empty():
			continue
		for i in list.size():
			var aura: Dictionary = list[i]
			var box := ColorRect.new()
			box.position = Vector2((i % TARGET_AURAS_PER_ROW) * (TARGET_AURA + 1), (row + i / TARGET_AURAS_PER_ROW) * (TARGET_AURA + 6)) * _ui_scale
			box.size = Vector2.ONE * TARGET_AURA * _ui_scale
			box.mouse_filter = Control.MOUSE_FILTER_STOP
			_target_auras.add_child(box)
			_spells._draw_icon(box, int(aura.spell.Id))
			if aura.caster == _player.combatant and list == debuffs:
				var mine := ReferenceRect.new()
				mine.border_color = Color(1, 0.82, 0.25)
				mine.border_width = maxf(_ui_scale, 1.0)
				mine.editor_only = false
				mine.size = box.size
				mine.mouse_filter = Control.MOUSE_FILTER_IGNORE
				box.add_child(mine)
			var time := _label(box, Vector2(0, TARGET_AURA - 1), "")
			time.add_theme_font_size_override("font_size", roundi(5 * _ui_scale))
			box.set_meta("aura", aura)
			box.set_meta("time", time)
			var spell: Dictionary = aura.spell
			var level := c.level
			box.mouse_entered.connect(func() -> void:
				var lines: Array = [[str(spell.SpellName), "", Color.WHITE]]
				var text := SpellText.describe(spell, level)
				if not text.is_empty():
					lines.append([text, "", SpellUI.DESCRIPTION])
				if aura.remaining >= 0.0:
					lines.append(["%d sec remaining" % ceili(aura.remaining), "", SpellUI.DESCRIPTION])
				_tooltip.show_lines(lines))
			box.mouse_exited.connect(func() -> void: _tooltip.show_lines([]))
		row += ceili(list.size() / float(TARGET_AURAS_PER_ROW))
	_target_auras_height = row * (TARGET_AURA + 6)


## Mana bars are blue, rage bars red (classic's power colors).
static func power_color(c: Combatant) -> Color:
	return Color(0.8, 0.15, 0.15) if c.uses_rage() else Color(0.2, 0.4, 0.85)


## Shows the target's mana, shrinking the frame when it has none.
func _show_target_mana(c: Combatant) -> void:
	var has_mana := c != null and c.max_mana > 0
	_target_mana_back.visible = has_mana
	_target_mana.visible = has_mana
	_target_mana_text.visible = has_mana
	# The frame keeps its height (its portrait fills it); without mana the
	# health bar takes the mana bar's room.
	var health_height := 10.0 if has_mana else 20.0
	_target_health.size.y = health_height * _ui_scale
	_target_health_back.size.y = (health_height + 1.2) * _ui_scale
	_target_health_text.position.y = (12.0 + health_height / 2.0) * _ui_scale - _target_health_text.get_minimum_size().y / 2.0
	if has_mana:
		(_target_mana as ColorRect).color = power_color(c)
		_set_bar(_target_mana, c.mana, c.max_mana)
		_target_mana_text.text = "%d/%d" % [int(c.mana), c.max_mana]


func _on_target_frame_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var bot := _player.targeting.target as Bot
	if click and click.pressed and click.button_index == MOUSE_BUTTON_RIGHT and bot:
		open_unit_menu(bot)


func _build_cast_bar() -> void:
	# Above the stance bar, which moves up with the bottom extra action bars.
	var cast_y := minf(_height - CAST_BAR_Y_FROM_BOTTOM, SpellUI.stance_top(_height) - CAST_BAR_ABOVE_STANCE)
	_cast_frame = _frame(Vector2((_width - 120) / 2.0, cast_y), Vector2(120, 12))
	_cast_fill = _bar(_cast_frame, Vector2(1, 1), Vector2(118, 10), Color(0.9, 0.65, 0.2))
	_cast_name = _bar_text(_cast_frame, Vector2(1, 1), Vector2(118, 10))
	_cast_frame.visible = false


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_TIME


func _add_float(combatant: Combatant, text: String, color: Color, big := false) -> void:
	var label := _label(_float_layer, Vector2.ZERO, text, color)
	if big:
		label.add_theme_font_size_override("font_size", roundi(CRIT_FONT_SIZE * _ui_scale))
	label.visible = false
	var world_position := combatant.body.get_global_transform_interpolated().origin + Vector3.UP * FLOAT_HEIGHT
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
	# Every creature and playerbot has a label: the far ones (most of them,
	# with hundreds of bots) are skipped on distance alone, and a label's
	# colour is set only when it changes (setting it re-lays the label out).
	var shown: bool = Settings.get_value("enemy_names")
	var eye := _camera.global_position
	var reach := NAMEPLATE_RANGE * NAMEPLATE_RANGE
	for entry in _enemy_names:
		var label: Label = entry.label
		if not is_instance_valid(entry.combatant):
			label.visible = false
			continue
		var combatant: Combatant = entry.combatant
		# Where the unit is drawn (physics interpolation), so the label keeps up.
		var world: Vector3 = combatant.body.get_global_transform_interpolated().origin + Vector3.UP * NAMEPLATE_HEIGHT
		# (A tamed creature has left the world: hidden.)
		if not shown or eye.distance_squared_to(world) > reach or not combatant.is_alive() or not combatant.body.visible or _camera.is_position_behind(world):
			label.visible = false
			continue
		label.visible = true
		var on_window: Vector2 = _camera.unproject_position(world) * _game_view.stretch_shrink
		label.position = on_window - Vector2(label.size.x / 2.0, label.size.y)
		# Grey once someone outside the party taps it.
		var color := Targeting.name_color(combatant.body)
		if color != entry.get("color", Color.TRANSPARENT):
			entry.color = color
			label.add_theme_color_override("font_color", color)


## The party under the player frame: each member's name, level, health,
## mana and XP (no XP bar at the level cap). Click one to target it, right-click for its menu.
func _build_party_frames() -> void:
	_party_frames.clear()
	var inner := PARTY_FRAME_SIZE.x - 6
	for bot in Party.members:
		var probe := _label(self, Vector2.ZERO, bot.profile.char_name)
		probe.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
		inner = _name_row_width(probe, "Lv %d" % ClassicData.MAX_LEVEL, inner)
		probe.queue_free()
	# Each with a small portrait on the left, like the player's frame.
	var x0 := PARTY_PORTRAIT + 4.0
	var frame_size := Vector2(x0 + inner + 3, PARTY_FRAME_SIZE.y)
	# A Ranger's pet frame comes first, right under the player's.
	var top := 43.0
	_pet_frame = {}
	if GameState.char_class == ClassicData.CharClass.HUNTER:
		_build_pet_frame(Vector2(4, top), Vector2(frame_size.x, PET_FRAME_SIZE.y), x0, inner)
		top += PET_FRAME_SIZE.y + 3
	var y := top
	for i in Party.members.size():
		var bot := Party.members[i]
		var frame := _frame(Vector2(4, y), frame_size)
		frame.mouse_filter = Control.MOUSE_FILTER_STOP
		frame.gui_input.connect(_on_party_frame_input.bind(bot))
		_portrait(frame, Vector2(2, 2), PARTY_PORTRAIT, Icons.portrait_key(bot))
		var name_label := _label(frame, Vector2(x0, -1), bot.profile.char_name)
		name_label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
		var level := _right_label(frame, Vector2(x0, -1), inner)
		level.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
		_trough(frame, Vector2(x0, 10), Vector2(inner, 6))
		var health := _bar(frame, Vector2(x0, 10), Vector2(inner, 6), Color(0.25, 0.7, 0.25))
		var mana := _bar(frame, Vector2(x0, 17), Vector2(inner, 3), Color(0.2, 0.4, 0.85))
		var xp_back := _trough(frame, Vector2(x0, 21), Vector2(inner, 2))
		var xp := _bar(frame, Vector2(x0, 21), Vector2(inner, 2), PARTY_XP)
		var entry := { "bot": bot, "frame": frame, "name": name_label, "level": level, "health": health, "mana": mana, "xp": xp, "xp_back": xp_back }
		y += PARTY_FRAME_SIZE.y + 3
		# A Ranger's pet: a strip under its frame, its name and health.
		if bot.profile.char_class == ClassicData.CharClass.HUNTER:
			var strip := _frame(Vector2(4 + x0, y - 2), Vector2(inner + 3, PARTY_PET_STRIP))
			strip.mouse_filter = Control.MOUSE_FILTER_STOP
			strip.gui_input.connect(_on_party_pet_input.bind(bot))
			var pet_name := _label(strip, Vector2(2, -2), "")
			pet_name.add_theme_font_size_override("font_size", roundi(PET_STRIP_FONT * _ui_scale))
			pet_name.size.x = (inner - 1) * _ui_scale
			pet_name.clip_text = true
			pet_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			_trough(strip, Vector2(2, PARTY_PET_STRIP - 4), Vector2(inner - 1, 2))
			entry.pet_health = _bar(strip, Vector2(2, PARTY_PET_STRIP - 4), Vector2(inner - 1, 2), Color(0.25, 0.7, 0.25))
			entry.pet_name = pet_name
			entry.pet_strip = strip
			y += PARTY_PET_STRIP + 1
		_party_frames.append(entry)


## The pet frame: portrait, name, level, health, focus and XP; click to
## target the pet, right-click to abandon it.
func _build_pet_frame(at: Vector2, frame_size: Vector2, x0: float, inner: float) -> void:
	var frame := _frame(at, frame_size)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.gui_input.connect(_on_pet_frame_input)
	_portrait(frame, Vector2(2, 2), PARTY_PORTRAIT - 3, "tooth_claw")
	var name_label := _label(frame, Vector2(x0, -1), "")
	name_label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
	# Long beast names stop short of the level.
	name_label.size.x = (inner - 16) * _ui_scale
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var level := _right_label(frame, Vector2(x0, -1), inner)
	level.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
	_trough(frame, Vector2(x0, 10), Vector2(inner, 5))
	var health := _bar(frame, Vector2(x0, 10), Vector2(inner, 5), Color(0.25, 0.7, 0.25))
	var focus := _bar(frame, Vector2(x0, 16), Vector2(inner, 3), FOCUS_COLOR)
	var xp_back := _trough(frame, Vector2(x0, 19.5), Vector2(inner, 1.5))
	var xp := _bar(frame, Vector2(x0, 19.5), Vector2(inner, 1.5), PARTY_XP)
	_pet_frame = { "frame": frame, "name": name_label, "level": level, "health": health, "focus": focus, "xp": xp, "xp_back": xp_back }
	if _pet_menu == null:
		_pet_menu = PopupMenu.new()
		add_child(_pet_menu)
		_pet_menu.id_pressed.connect(_on_pet_menu)


func _update_pet_frame() -> void:
	if _pet_frame.is_empty():
		return
	var pet := _player.pet
	var frame: Control = _pet_frame.frame
	frame.visible = pet != null and is_instance_valid(pet)
	if not frame.visible:
		return
	var c := pet.combatant
	var alive := c.is_alive()
	(_pet_frame.name as Label).text = str(pet.record.name)
	(_pet_frame.level as Label).text = "Lv %d" % int(pet.record.level) if alive else "Dead"
	_set_bar(_pet_frame.health, c.health, c.max_health)
	_set_bar(_pet_frame.focus, c.mana, c.max_mana)
	var capped := int(pet.record.level) >= _player.profile.level
	_pet_frame.xp.visible = not capped
	_pet_frame.xp_back.visible = not capped
	if not capped:
		_set_bar(_pet_frame.xp, int(pet.record.xp), PetDB.xp_to_next(int(pet.record.level)))


func _on_pet_frame_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	var pet := _player.pet
	if click == null or not click.pressed or pet == null or not is_instance_valid(pet):
		return
	if click.button_index == MOUSE_BUTTON_RIGHT:
		_pet_menu.clear()
		_pet_menu.add_item("Abandon Pet", 0)
		_pet_menu.add_item("Cancel", 2)
		_pet_menu.reset_size()
		_pet_menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


## Abandoning asks once more, as classic does.
func _on_pet_menu(id: int) -> void:
	match id:
		0:
			_pet_menu.clear()
			_pet_menu.add_item("Abandon %s for good?" % str(GameState.pet.get("name", "your pet")), 1)
			_pet_menu.add_item("Cancel", 2)
			_pet_menu.reset_size()
			_pet_menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))
		1:
			_player.spells.ranger().abandon_pet()


func _update_party_frames() -> void:
	_update_pet_frame()
	for entry in _party_frames:
		var bot: Bot = entry.bot
		if not is_instance_valid(bot):
			continue
		var c := bot.combatant
		var alive := c.is_alive()
		entry.level.text = "Lv %d" % c.level if alive else "Dead"
		entry.name.add_theme_color_override("font_color", Color.WHITE if alive else GREY)
		_set_bar(entry.health, c.health, c.max_health)
		(entry.mana as ColorRect).color = power_color(c)
		_set_bar(entry.mana, c.mana, c.max_mana)
		entry.mana.visible = c.max_mana > 0
		var capped := bot.profile.level >= ClassicData.MAX_LEVEL
		entry.xp.visible = not capped
		entry.xp_back.visible = not capped
		if not capped:
			_set_bar(entry.xp, bot.profile.xp, ClassicData.xp_to_next(bot.profile.level))
		var far := _player.global_position.distance_to(bot.global_position) > PARTY_RANGE
		entry.frame.modulate.a = 0.5 if far else 1.0
		if entry.has("pet_strip"):
			var pet: Pet = bot.pet if bot.pet and is_instance_valid(bot.pet) else null
			var record: Dictionary = pet.record if pet else bot.pet_record
			(entry.pet_strip as Control).visible = not record.is_empty()
			if pet:
				(entry.pet_name as Label).text = "%s  Lv %d" % [record.get("name", ""), int(record.get("level", 1))] if pet.combatant.is_alive() else "%s  Dead" % record.get("name", "")
				_set_bar(entry.pet_health, pet.combatant.health, pet.combatant.max_health)
			elif not record.is_empty():
				(entry.pet_name as Label).text = "%s  %s" % [record.get("name", ""), "Dead" if record.get("dead", false) else "Away"]
				_set_bar(entry.pet_health, 0, 1)
			(entry.pet_strip as Control).modulate.a = entry.frame.modulate.a


## Clicking a party Ranger's pet strip targets the pet.
func _on_party_pet_input(event: InputEvent, bot: Bot) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and is_instance_valid(bot) and bot.pet and is_instance_valid(bot.pet):
		_player.targeting.set_target(bot.pet)


func _on_party_frame_input(event: InputEvent, bot: Bot) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and is_instance_valid(bot):
		if click.button_index == MOUSE_BUTTON_LEFT:
			_player.targeting.set_target(bot)
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			_player.targeting.set_target(bot)
			open_unit_menu(bot)


## The right-click menu for a playerbot, at the mouse: invite it, or tell a
## party member to follow or stay, or remove it.
func open_unit_menu(bot: Bot) -> void:
	_menu_bot = bot
	_unit_menu.clear()
	_unit_menu.add_item("Whisper", MenuItem.WHISPER)
	if Party.is_member(bot):
		_unit_menu.add_item("Follow", MenuItem.FOLLOW)
		_unit_menu.add_item("Stay", MenuItem.STAY)
		_unit_menu.add_item("Remove from Party", MenuItem.REMOVE)
	else:
		_unit_menu.add_item("Invite to Party", MenuItem.INVITE)
	_unit_menu.add_item("Trade", MenuItem.TRADE)
	_unit_menu.add_item("Cancel", MenuItem.CANCEL)
	_unit_menu.reset_size()
	_unit_menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _on_unit_menu(id: int) -> void:
	var bot := _menu_bot
	if bot == null or not is_instance_valid(bot):
		return
	match id:
		MenuItem.INVITE:
			Party.invite(bot)
		MenuItem.REMOVE:
			Party.remove(bot)
		MenuItem.FOLLOW:
			bot.follow()
			_on_loot_message("%s is following you." % bot.profile.char_name, false)
		MenuItem.WHISPER:
			_chat.whisper_to(bot.profile.char_name)
		MenuItem.TRADE:
			_trade.open(bot)
		MenuItem.STAY:
			bot.stay()
			_on_loot_message("%s stays here." % bot.profile.char_name, false)


## Friendly NPC names in green, with their title below, as in classic.
func _build_npc_names() -> void:
	for npc: Node in get_tree().get_nodes_in_group("npcs"):
		# Quest objects (a body) have no nameplate, only their quest marker.
		var title := "" if npc is QuestObject else "%s
<%s>" % [npc.npc_name, npc.subname]
		var name_label := _label(self, Vector2.ZERO, title, Targeting.FRIENDLY_COLOR)
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
		var world := npc.global_position + Vector3.UP * (0.9 if npc is QuestObject else NAMEPLATE_HEIGHT)
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
			if shown[1] != entry.get("color", Color.TRANSPARENT):
				entry.color = shown[1]
				marker.add_theme_color_override("font_color", shown[1])
			marker.position = label.position + Vector2((label.size.x - marker.size.x) / 2.0, -marker.size.y + 2 * _ui_scale)


func _build_enemy_names() -> void:
	for node in get_tree().get_nodes_in_group("combatants"):
		if node != _player.combatant and not node.is_queued_for_deletion() and not node.get_parent().is_queued_for_deletion():
			var combatant := node as Combatant
			var label := _label(self, Vector2.ZERO, combatant.display_name, Targeting.name_color(combatant.body))
			label.add_theme_font_size_override("font_size", roundi(BAR_FONT_SIZE * _ui_scale))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_enemy_names.append({ "combatant": combatant, "label": label })


func _set_bar(fill: Control, value: float, maximum: float) -> void:
	fill.size.x = fill.get_meta("full_width") * clampf(value / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


## A unit frame, the cast bar's or the XP bar's: a gilt panel (UiStyle)
## without a title band.
func _frame(frame_position: Vector2, frame_size: Vector2) -> Control:
	var panel := UiStyle.panel(self, frame_size, _ui_scale, false)
	panel.position = frame_position * _ui_scale
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_child(panel, -1)
	return panel


## A framed portrait (UiStyle slot frame and a painted icon): returns the
## picture, whose texture the target frame swaps.
func _portrait(parent: Control, at: Vector2, side: float, key: String) -> TextureRect:
	var frame := UiStyle.slot_frame(parent, at, side, _ui_scale)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return UiStyle.icon(frame, Icons.texture(key), maxf(roundf(_ui_scale * 1.2), 2.0))


## The dark, gold-edged trough a bar fills.
func _trough(parent: Control, at: Vector2, trough_size: Vector2) -> Control:
	var back := Panel.new()
	var line := maxi(roundi(_ui_scale * 0.5), 1)
	back.add_theme_stylebox_override("panel", UiStyle._box(Color(0.03, 0.025, 0.035), UiStyle.GOLD_DARK, line, roundi(_ui_scale)))
	back.position = (at - Vector2.ONE * 0.6) * _ui_scale
	back.size = (trough_size + Vector2.ONE * 1.2) * _ui_scale
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(back)
	return back


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
func open_loot(corpse: Node3D, take_all: bool) -> void:
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
	if npc.stable:
		close_vendor()
		close_trainer()
		_stable.open(npc, _player, _ui_scale)
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


## Right-click on a player's name in the chat: the bot's menu, as on its
## frame. Nothing for yourself or a bot that isn't in the world.
func _open_name_menu(player_name: String) -> void:
	var manager := get_tree().get_first_node_in_group("bot_manager") as BotManager
	var bot := manager.find_bot(player_name) if manager else null
	if bot:
		open_unit_menu(bot)


## Classic unit tooltip rows: the name in its reaction color, level and kind
## for creatures (or the title for NPCs), then any quests underway that the
## creature counts toward, with their progress.
func unit_tooltip(unit: Node3D) -> Array:
	if unit is QuestObject:
		return [[(unit as QuestObject).npc_name, "", Color.WHITE]]
	if unit is GameObject:
		return [[(unit as GameObject).object_name(), "", Color.WHITE]]
	if unit is Npc:
		var npc := unit as Npc
		return [[npc.npc_name, "", Targeting.FRIENDLY_COLOR], ["<%s>" % npc.subname, "", Color.WHITE]]
	if unit is Bot:
		var bot := unit as Bot
		var p := bot.profile
		var lines := [
			[p.char_name, "", Targeting.PLAYER_COLOR],
			["Level %d %s %s" % [p.level, ClassicData.RACE_NAMES[p.race], ClassicData.CLASS_NAMES[p.char_class]], "", Color.WHITE],
		]
		if Party.is_member(bot):
			lines.append(["In your party", "", QUEST_DONE])
		else:
			var questing := bot.quests.current_title()
			if not questing.is_empty():
				lines.append(["Questing: %s" % questing, "", QuestLog.YELLOW])
			lines.append(["Target, then right-click its frame to invite", "", GREY])
		if not bot.combatant.is_alive():
			lines.append(["Dead", "", GREY])
		return lines
	var enemy := unit as Enemy
	if enemy == null:
		return []
	var data := Enemy.creature_data(enemy.creature_entry)
	var alive := enemy.combatant.is_alive()
	var lines := [[enemy.combatant.display_name, "", Targeting.name_color(enemy) if alive else GREY]]
	var kind: String = CREATURE_TYPES.get(int(data.get("CreatureType", 0)), "")
	var level := "Level ?? (Boss) %s" % kind if enemy.boss else "Level %d%s %s" % [enemy.level, " (Elite)" if enemy.elite else "", kind]
	lines.append([level.strip_edges(), "", CombatRules.level_color(_player.combatant.level, enemy.level) if alive else GREY])
	if not alive:
		lines.append(["Corpse", "", GREY])
	for quest: Array in QuestLog.objectives_for_creature(enemy.creature_entry, int(data.get("LootId", 0))):
		lines.append([quest[0], "", Color.WHITE])
		for objective: Array in quest[1]:
			lines.append([" - " + objective[0], "", QUEST_DONE if objective[1] else GREY])
	return lines


func close_trade() -> bool:
	if not _trade.is_open():
		return false
	_trade.cancel()
	return true


func close_party_window() -> bool:
	return _party_bar.close()


func close_bot_bag() -> bool:
	return _bot_bag.close()


func close_social() -> bool:
	return _social.close()


func close_world_map() -> bool:
	return _world_map.close()


## Esc: closes the quest window, then the quest log.
func close_quests() -> bool:
	if _quest_window.visible:
		_quest_window.close()
		return true
	return _quest_log.close()


func _on_quest_message(text: String) -> void:
	# Taking and finishing quests also go in the chat, as in classic; progress
	# only shows on screen.
	if text.begins_with("Quest accepted") or text.ends_with(" completed."):
		Chat.system(text)
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
	var closed := _beast_training.visible or _stable.visible
	_beast_training.close()
	_stable.close()
	if not _trainer.visible:
		return closed
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
	# Loot in green, everything else as a system line, in the chat.
	var loot := text.begins_with("You loot") or text.begins_with("You receive") or text.begins_with("Your share")
	Chat.add("loot" if loot else "system", text)


## Esc handling: drops a held item or spell, or closes the bag, character and
## spellbook windows.
func close_inventory_window() -> bool:
	return _spells.close_one() or _talents.close_one() or _inventory.close_one()


func _on_leveled_up(new_level: int) -> void:
	# At the cap the XP bar goes, and the stance bar moves down into its place.
	if new_level >= ClassicData.MAX_LEVEL:
		_build.call_deferred()
	show_banner("Level %d!" % new_level)
	Chat.system("Congratulations, you have reached level %d!" % new_level)
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
