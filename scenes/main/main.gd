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
@onready var _player: Player = $GameView/GameViewport/Player
@onready var _camera: Camera3D = $GameView/GameViewport/GameCamera
@onready var _hud: CombatHud = $CombatHud

var _save_queued := false
## Covers the screen while a camera drag button is held. A captured mouse reads
## as the screen centre, and Godot updates hover from it every frame, so
## without this a window there would highlight rows and show tooltips.
var _drag_shield := Control.new()
var _menu := GameMenu.new()


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
	_restore_player()
	_restore_corpses()
	_camera.snap_to_target()
	_hud.setup(_player, _camera, _game_view)
	_player.targeting.loot_requested.connect(_hud.open_loot)
	_player.targeting.npc_clicked.connect(_hud.open_npc)
	_player.combatant.died.connect(_on_player_died)
	_player.progression.leveled_up.connect(func(_level: int) -> void: save_game())
	GameState.inventory_changed.connect(_queue_save)
	GameState.money_changed.connect(_queue_save)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 50
	add_child(menu_layer)
	menu_layer.add_child(_menu)
	_menu.log_out_requested.connect(_log_out)
	_menu.exit_requested.connect(func() -> void:
		save_game()
		get_tree().quit()
	)
	var shield_layer := CanvasLayer.new()
	shield_layer.layer = 100
	add_child(shield_layer)
	_drag_shield.set_anchors_preset(Control.PRESET_FULL_RECT)
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
			"position": [p.x, p.y, p.z], "facing": _player.facing, "health": c.health, "mana": c.mana,
			"auras": _saved_auras(c),
		}
	_store_corpses()
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


## Puts the player back where the save left them.
func _restore_player() -> void:
	var state := GameState.player_state
	if state.is_empty():
		return
	var at: Array = state.position
	_player.global_position = Vector3(at[0], at[1], at[2])
	_player.facing = float(state.facing)
	var c := _player.combatant
	# Buffs come back with the time they had left, as WoW saves auras on logout.
	for saved: Dictionary in state.get("auras", []):
		var spell := SpellDB.get_spell(int(saved.id))
		if not spell.is_empty():
			c.restore_aura(spell, c, float(saved.remaining), float(saved.duration), saved.amounts)
	c.health = clampi(int(state.health), 1, c.max_health)
	c.mana = clampf(float(state.mana), 0.0, c.max_mana)


## The player's own buffs, by spell id. Debuffs from enemies aren't kept.
func _saved_auras(c: Combatant) -> Array:
	var saved := []
	for aura in c.auras:
		# Food and drink end when you stand, so they aren't kept.
		var ends_on_standing: bool = int(aura.spell.get("AuraInterruptFlags", 0)) & SpellDB.AURA_INTERRUPT_NOT_SEATED != 0
		if aura.caster == c and not ends_on_standing:
			saved.append({ "id": int(aura.spell.Id), "remaining": aura.remaining, "duration": aura.duration, "amounts": aura.amounts })
	return saved


## Several inventory changes in a row (looting everything) save once.
func _queue_save() -> void:
	if not _save_queued:
		_save_queued = true
		get_tree().create_timer(1.0).timeout.connect(func() -> void:
			_save_queued = false
			save_game()
		)


## Picks the largest whole pixel scale that fits, then rounds the view up so it
## always covers the window instead of leaving a gap at the edges.
func _fit_game_view() -> void:
	var window := get_viewport().get_visible_rect().size
	var pixel_scale := maxi(floori(window.y / min_game_height), 1)
	_game_view.stretch_shrink = pixel_scale
	_game_view.size = (window / pixel_scale).ceil() * pixel_scale


func _on_camera_clicked(window_position: Vector2, button: MouseButton) -> void:
	_player.targeting.on_camera_clicked(window_position / _game_view.stretch_shrink, button)


## Saves and goes back to character select.
func _log_out() -> void:
	save_game()
	FrontEnd.start_at_select = true
	get_tree().change_scene_to_file("res://scenes/front_end/front_end.tscn")


## Back to the start point at full health, as when resurrecting at a graveyard.
func _on_player_died() -> void:
	GameState.player_state = {}
	_store_corpses()
	GameState.save_to_disk()
	get_tree().create_timer(RESTART_DELAY).timeout.connect(get_tree().reload_current_scene)


## During a camera drag the mouse is captured, and Godot reports a captured
## mouse at the screen centre, where windows like the vendor's would swallow
## the motion. So drags go straight to the camera, before the UI, including the
## button release that ends them.
func _process(_delta: float) -> void:
	_update_drag_shield()


func _update_drag_shield() -> void:
	_drag_shield.visible = _camera is OrbitCamera and _camera.is_dragging()


func _input(event: InputEvent) -> void:
	if _camera is OrbitCamera and _camera.is_dragging():
		var ends_drag: bool = event is InputEventMouseButton and not event.pressed
		if event is InputEventMouseMotion or ends_drag:
			_camera.handle_mouse(event)
			get_viewport().set_input_as_handled()
			_update_drag_shield()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and _camera is OrbitCamera:
		_camera.handle_mouse(event)
		# Up from the moment a drag button goes down, before any hover can happen.
		_update_drag_shield()
	elif event is InputEventKey and event.pressed and event.keycode == RESET_KEY and event.shift_pressed:
		GameState.reset_character()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause"):
		# Esc closes the menu, the loot window and other windows, then clears
		# the target, and only then opens the game menu.
		if _menu.visible:
			_menu.toggle()
		elif _hud.is_looting():
			_hud.close_loot()
		elif _hud.close_vendor() or _hud.close_trainer():
			pass
		elif _hud.close_inventory_window():
			pass
		elif _player.targeting.target:
			_player.targeting.set_target(null)
		else:
			_menu.toggle()
