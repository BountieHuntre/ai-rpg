extends Node
## Root scene: wires the camera, player and HUD together, keeps the low-res game
## view fitted to the window, and handles global input.

const RESTART_DELAY := 3.0
## Saves this often, as well as on loot, level-up, quitting and death.
const AUTOSAVE_INTERVAL := 30.0
## Shift+F12 deletes the save and starts a new character.
const RESET_KEY := KEY_F12

## The game renders at whole-number pixel scales, showing at least this many
## rows. Raise it for smaller pixels: at 810p, 270 gives 3x, 405 gives 2x.
@export var min_game_height := 270

@onready var _game_view: SubViewportContainer = $GameView
@onready var _world: World = $GameView/GameViewport/World
@onready var _player: Player = $GameView/GameViewport/Player
@onready var _camera: Camera3D = $GameView/GameViewport/GameCamera
@onready var _hud: CombatHud = $CombatHud

var _save_queued := false
## Covers the screen while a camera drag button is held. A captured mouse reads
## as the screen centre, and Godot updates hover from it every frame, so
## without this a window there would highlight rows and show tooltips.
var _drag_shield := Control.new()
var _menu := GameMenu.new()
var _console := DevConsole.new()
var _bots := BotManager.new()


## Runs before the player and HUD are ready. Started straight from the editor,
## with no character picked, it plays the first one (or makes one).
func _enter_tree() -> void:
	if GameState.has_character():
		return
	var characters := GameState.list_characters()
	if characters.is_empty():
		GameState.create_character("Hero", ClassicData.Race.HUMAN, ClassicData.CharClass.PALADIN)
	else:
		GameState.select_character(characters[0].path)


func _ready() -> void:
	_camera.target = _player
	_camera.snap_to_target()
	if _camera is OrbitCamera:
		_camera.clicked.connect(_on_camera_clicked)
	get_viewport().size_changed.connect(_fit_game_view)
	_fit_game_view()
	Settings.changed.connect(_apply_setting)
	for key in Settings.WORLD_OPTIONS:
		_apply_setting(key)
	_restore_player()
	_restore_corpses()
	_camera.snap_to_target()
	# Bots first, so the HUD finds them.
	_bots.name = "BotManager"
	add_child(_bots)
	_bots.setup(_player, _world)
	# Buffs the bots put on the player and each other find their casters.
	Combatant.relink_auras(get_tree())
	_hud.menu_open = func() -> bool: return _menu.visible
	_hud.main_menu_requested.connect(func() -> void: _menu.toggle())
	_hud.setup(_player, _camera, _game_view)
	_bots.bots_changed.connect(_hud.refresh_units)
	_player.targeting.loot_requested.connect(_hud.open_loot)
	_player.targeting.npc_clicked.connect(_hud.open_npc)
	_player.combatant.died.connect(_on_player_died)
	_player.progression.leveled_up.connect(func(_level: int) -> void: save_game())
	GameState.inventory_changed.connect(_queue_save)
	GameState.money_changed.connect(_queue_save)
	GameState.friends_changed.connect(_queue_save)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 50
	add_child(menu_layer)
	menu_layer.add_child(_menu)
	var console_layer := CanvasLayer.new()
	console_layer.layer = 40
	add_child(console_layer)
	console_layer.add_child(_console)
	_console.setup(_player, _world, save_game, _bots)
	_menu.set_console(_console)
	_menu.log_out_requested.connect(_log_out)
	_menu.exit_requested.connect(func() -> void:
		save_game()
		get_tree().quit()
	)
	var shield_layer := CanvasLayer.new()
	shield_layer.layer = 100
	add_child(shield_layer)
	_drag_shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_shield.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_shield.visible = false
	shield_layer.add_child(_drag_shield)
	var autosave := Timer.new()
	autosave.wait_time = AUTOSAVE_INTERVAL
	autosave.timeout.connect(save_game)
	add_child(autosave)
	autosave.start()


func save_game() -> void:
	var c := _player.combatant
	if c.is_alive():
		var p := _player.global_position
		GameState.player_state = {
			"zone": _world.zone_at(p).zone_name, "position": [p.x, p.y, p.z], "facing": _player.facing, "health": c.health, "mana": c.mana,
			"auras": c.saved_auras(),
			"item_cooldowns": _player.spells.saved_item_cooldowns(),
		}
	_store_corpses()
	_bots.save_roster()
	GameState.save_to_disk()


## Dead enemies keep their corpse, loot and respawn time across restarts,
## keyed by node name.
func _store_corpses() -> void:
	var corpses := {}
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		var corpse := enemy.corpse_state()
		if not corpse.is_empty():
			corpses[String(enemy.name)] = corpse
	GameState.world_state = { "corpses": corpses }


func _restore_corpses() -> void:
	var corpses: Dictionary = GameState.world_state.get("corpses", {})
	for enemy: Enemy in get_tree().get_nodes_in_group("enemies"):
		if corpses.has(String(enemy.name)):
			enemy.restore_corpse(corpses[String(enemy.name)])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## Puts the player back where the save left them. The dead come back at the
## graveyard of the zone they died in; new characters and saves from a zone
## that isn't there start at the priory.
func _restore_player() -> void:
	var state := GameState.player_state
	var zone := _world.zone_named(str(state.get("zone", "")))
	if zone == null or not state.has("position"):
		var graveyard := _world.zone_named(str(state.get("graveyard", "")))
		if graveyard == null:
			graveyard = _world.zone_named(AshfordVale.ZONE_NAME)
		_player.global_position = graveyard.graveyard
		_player.facing = graveyard.graveyard_facing
	else:
		var at: Array = state.position
		_player.global_position = Vector3(at[0], maxf(at[1], _world.height_at(at[0], at[2])), at[2])
		_player.facing = float(state.facing)
	_zone_name = _world.zone_at(_player.global_position).zone_name
	if zone == null:
		_hud.show_banner.call_deferred(_zone_name)
	var c := _player.combatant
	_player.spells.restore_item_cooldowns(state.get("item_cooldowns", {}))
	# Buffs come back with the time they had left, as WoW saves auras on logout.
	c.restore_saved_auras(state.get("auras", []))
	# New characters and the freshly resurrected start full.
	if state.has("health"):
		c.health = clampi(int(state.health), 1, c.max_health)
		c.mana = clampf(float(state.mana), 0.0, c.max_mana)


## The player's own buffs, by spell id. Debuffs from enemies aren't kept.
## Several inventory changes in a row (looting everything) save once.
func _queue_save() -> void:
	if not _save_queued:
		_save_queued = true
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			_save_queued = false
			save_game()
		)


## Shadow Quality: [shadow distance in yards, shadow map size].
const SHADOW_QUALITY := { "Low": [45.0, 1024], "Medium": [90.0, 2048], "High": [150.0, 4096] }
## View Distance: [camera far in yards, fog density], the fog thick enough to
## hide where drawing stops.
const VIEW_DISTANCE := { "Near": [120.0, 0.0045], "Normal": [200.0, 0.0025], "Far": [300.0, 0.0016], "Very Far": [420.0, 0.0011] }


## Video options that live in the world: shadows, view distance, field of
## view, ground clutter, ambient occlusion, bloom and the picture's brightness,
## gamma, contrast and saturation.
func _apply_setting(key: String) -> void:
	var environment := (_world.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	match key:
		"shadow_quality":
			var quality: String = Settings.get_value(key)
			var values: Array = SHADOW_QUALITY.get(quality, SHADOW_QUALITY.Medium)
			for light in _world.find_children("*", "DirectionalLight3D", true, false):
				(light as DirectionalLight3D).shadow_enabled = quality != "Off"
				(light as DirectionalLight3D).directional_shadow_max_distance = values[0]
			RenderingServer.directional_shadow_atlas_set_size(values[1], true)
		"view_distance":
			var values: Array = VIEW_DISTANCE.get(Settings.get_value(key), VIEW_DISTANCE.Normal)
			_camera.far = values[0]
			environment.fog_density = values[1]
		"field_of_view":
			_camera.fov = float(Settings.get_value(key))
		"environment_detail":
			_world.set_clutter(Settings.get_value(key))
		"ambient_occlusion":
			environment.ssao_enabled = Settings.get_value(key)
		"bloom":
			environment.glow_enabled = Settings.get_value(key)
			environment.glow_intensity = 0.6
			environment.glow_bloom = 0.1
		"brightness", "contrast", "saturation":
			environment.adjustment_enabled = true
			environment.adjustment_brightness = Settings.get_value("brightness")
			environment.adjustment_contrast = Settings.get_value("contrast")
			environment.adjustment_saturation = Settings.get_value("saturation")
		"gamma":
			environment.adjustment_enabled = true
			environment.adjustment_color_correction = gamma_curve(Settings.get_value(key))


## Gamma as a color-correction curve: each level raised to 1 / gamma, so
## above 1 lifts the shadows and below darkens them. None at 1.
static func gamma_curve(gamma: float) -> GradientTexture1D:
	if is_equal_approx(gamma, 1.0):
		return null
	var gradient := Gradient.new()
	gradient.remove_point(1)
	gradient.remove_point(0)
	for i in 33:
		var level := i / 32.0
		var value := pow(level, 1.0 / gamma)
		gradient.add_point(level, Color(value, value, value))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 256
	return texture


## Picks the largest whole pixel scale that fits, then rounds the view up so it
## always covers the window instead of leaving a gap at the edges.
func _fit_game_view() -> void:
	var window := get_viewport().get_visible_rect().size
	var pixel_scale := maxi(floori(window.y / min_game_height), 1)
	_game_view.stretch_shrink = pixel_scale
	_game_view.size = (window / pixel_scale).ceil() * pixel_scale


func _on_camera_clicked(window_position: Vector2, button: MouseButton) -> void:
	if button == MOUSE_BUTTON_LEFT and _hud.drop_held_item():
		return
	_player.targeting.on_camera_clicked(window_position / _game_view.stretch_shrink, button)


## Saves and goes back to character select.
func _log_out() -> void:
	save_game()
	FrontEnd.start_at_select = true
	get_tree().change_scene_to_file("res://scenes/front_end/front_end.tscn")


## Back to the start point at full health, as when resurrecting at a graveyard.
func _on_player_died() -> void:
	# Only the auras that outlast death come back with you, and cooldowns keep running.
	GameState.player_state = {
		"auras": _player.combatant.saved_auras(), "item_cooldowns": _player.spells.saved_item_cooldowns(),
		"graveyard": _world.zone_at(_player.global_position).zone_name,
	}
	_store_corpses()
	_bots.save_roster()
	GameState.save_to_disk()
	get_tree().create_timer(RESTART_DELAY).timeout.connect(get_tree().reload_current_scene)


## During a camera drag the mouse is captured, and Godot reports a captured
## mouse at the screen centre, where windows like the vendor's would swallow
## the motion. So drags go straight to the camera, before the UI, including the
## button release that ends them.
func _process(delta: float) -> void:
	_update_drag_shield()
	_check_zone()
	# Exploration quests: walking into the place they send you to.
	_explore_left -= delta
	if _explore_left <= 0.0:
		_explore_left = 0.25
		QuestLog.check_exploration(_player.global_position, _world.places())


var _explore_left := 0.0


## The zone the player was last in.
var _zone_name := ""


## Crossing into another zone shows its name, as in classic.
func _check_zone() -> void:
	var zone := _world.zone_at(_player.global_position)
	if zone and zone.zone_name != _zone_name:
		_zone_name = zone.zone_name
		_hud.show_banner(_zone_name)


static func _is_wheel(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.button_index in [
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
	]


func _update_drag_shield() -> void:
	_drag_shield.visible = _camera is OrbitCamera and _camera.is_dragging()


func _input(event: InputEvent) -> void:
	# The game view ignores the mouse, so mouse buttons bound to actions
	# (autorun on mouse button 5, say) go to the player from here, before any
	# window under the pointer can take them. The Options window waiting for a
	# binding takes them first.
	var mouse := event as InputEventMouseButton
	if mouse and mouse.button_index in Settings.BINDABLE_MOUSE and not _menu.visible:
		_player.handle_action(event)
	if _camera is OrbitCamera and _camera.is_dragging():
		var ends_drag: bool = event is InputEventMouseButton and not event.pressed
		if event is InputEventMouseMotion or ends_drag:
			_camera.handle_mouse(event)
			get_viewport().set_input_as_handled()
			_update_drag_shield()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and _camera is OrbitCamera:
		# The wheel zooms only over the world itself: never while the mouse is
		# over any interface (HUD windows, menus, the console, anything added
		# later), even where a scroll list at its end lets the wheel through.
		var hovered := get_viewport().gui_get_hovered_control()
		if _is_wheel(event) and hovered != null and hovered != _drag_shield:
			return
		_camera.handle_mouse(event)
		# Up from the moment a drag button goes down, before any hover can happen.
		_update_drag_shield()

	elif event is InputEventKey and event.pressed and event.keycode == RESET_KEY and event.shift_pressed and Settings.developer_tools():
		GameState.reset_character()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause"):
		# Esc closes the menu, the loot window and other windows, then clears
		# the target, and only then opens the game menu.
		if _menu.visible:
			_menu.toggle()
		elif _hud.is_looting():
			_hud.close_loot()
		elif _hud.close_world_map() or _hud.close_trade() or _hud.close_quests() or _hud.close_social() or _hud.close_vendor() or _hud.close_trainer():
			pass
		elif _hud.close_inventory_window():
			pass
		elif _player.targeting.target:
			_player.targeting.set_target(null)
		else:
			_menu.toggle()
