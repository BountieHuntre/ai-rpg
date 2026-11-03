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
	_player.targeting.npc_clicked.connect(_hud.open_trainer)
	_player.combatant.died.connect(_on_player_died)
	_player.progression.leveled_up.connect(func(_level: int) -> void: save_game())
	GameState.inventory_changed.connect(_queue_save)
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
		if aura.caster == c:
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


## Back to the start point at full health, as when resurrecting at a graveyard.
func _on_player_died() -> void:
	GameState.player_state = {}
	_store_corpses()
	GameState.save_to_disk()
	get_tree().create_timer(RESTART_DELAY).timeout.connect(get_tree().reload_current_scene)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and _camera is OrbitCamera:
		_camera.handle_mouse(event)
	elif event is InputEventKey and event.pressed and event.keycode == RESET_KEY and event.shift_pressed:
		GameState.reset_character()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause"):
		# Esc closes the loot window, then clears the target, then quits until a
		# real pause menu exists.
		if _hud.is_looting():
			_hud.close_loot()
		elif _hud.close_trainer():
			pass
		elif _hud.close_inventory_window():
			pass
		elif _player.targeting.target:
			_player.targeting.set_target(null)
		else:
			save_game()
			get_tree().quit()
