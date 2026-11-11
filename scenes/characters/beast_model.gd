class_name BeastModel
extends Node3D
## A beast's model: wolf, boar, bear or spider (assets/models/<species>/<species>.glb,
## built by tools/models/beasts/build_beasts.py), coloured from slot colours by
## shaders/character.gdshader like HumanoidModel, and animated from the
## creature it stands for: idle, ready, walk, run, attack, hit, death, dead.
## Lighter than HumanoidModel: one mesh and an AnimationPlayer crossfading
## between animations, advanced by hand less often the further off it is.

const SHADER := preload("res://shaders/character.gdshader")
const LOOPS := ["idle", "ready", "walk", "run", "dead"]
## Speeds the walk and run cycles were made for, in yards per second.
const WALK_SPEED := 2.5
const RUN_SPEED := 7.0
const BLEND := 0.15

static var _scenes: Dictionary = {}

## "wolf", "boar", "bear" or "spider". Set before adding.
var species := "wolf"
## Slot (HumanoidModel's enum) -> colour.
var colors: Dictionary = {}
var _material := ShaderMaterial.new()
var _player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _body: CharacterBody3D
var _combatant: Combatant
var _anim_time := 0.0
var _loop := ""
## Seconds left of a one-shot (attack, hit, death) before loops resume.
var _busy := 0.0


func _init() -> void:
	name = "Model"
	_material.shader = SHADER


func _ready() -> void:
	if not _scenes.has(species):
		var scene: PackedScene = load("res://assets/models/%s/%s.glb" % [species, species])
		var probe: Node = scene.instantiate()
		var player: AnimationPlayer = probe.get_node("AnimationPlayer")
		for anim_name in player.get_animation_list():
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPS else Animation.LOOP_NONE
		probe.free()
		_scenes[species] = scene
	var model: Node3D = _scenes[species].instantiate()
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = _material
		mesh.layers = Targeting.UNIT_RENDER_LAYER
		_meshes.append(mesh)
	_player = model.get_node("AnimationPlayer")
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim_time = randf() * 0.1
	var slots := PackedColorArray()
	slots.resize(HumanoidModel.SLOT_COUNT)
	slots.fill(Color.WHITE)
	for slot: int in colors:
		slots[slot] = (colors[slot] as Color).srgb_to_linear()
	_material.set_shader_parameter("slot_colors", slots)
	_play_loop("idle")


## The coat, markings, belly, eyes and teeth/tusks from one coat colour.
static func coat_colors(coat: Color, species_name: String) -> Dictionary:
	return {
		HumanoidModel.SKIN: coat,
		HumanoidModel.HAIR: coat.darkened(0.45),
		HumanoidModel.CHEST: coat.lightened(0.3) if species_name != "spider" else coat.darkened(0.2),
		HumanoidModel.EYES: Color(0.9, 0.2, 0.1) if species_name == "spider" else Color(0.08, 0.06, 0.05),
		HumanoidModel.TRIM: Color(0.92, 0.88, 0.76),
	}


func attach_creature(body: CharacterBody3D, c: Combatant) -> void:
	_body = body
	_combatant = c
	c.swung.connect(func(_target: Combatant) -> void: _one_shot("attack"))
	c.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void:
		if _busy <= 0.0 and c.is_alive():
			_one_shot("hit"))
	c.died.connect(func() -> void:
		_one_shot("death")
		_loop = "dead")


func set_animating(on: bool) -> void:
	set_process(on)


func set_corpse(on: bool) -> void:
	_material.set_shader_parameter("tint", Color(0.3, 0.28, 0.28, 0.7) if on else Color(0, 0, 0, 0))


func set_flash(on: bool) -> void:
	_material.set_shader_parameter("flash", 1.0 if on else 0.0)


## Shows the creature as already dead (a corpse restored from a save).
func show_dead() -> void:
	_busy = 0.0
	_loop = ""
	_play_loop("dead")


func _process(delta: float) -> void:
	if _combatant:
		_update_state(delta)
	_advance(delta)


func _update_state(delta: float) -> void:
	_busy -= delta
	if _busy > 0.0:
		return
	var c := _combatant
	if not c.is_alive():
		_play_loop("dead")
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	if speed > 0.3:
		var running := speed >= 4.0
		_play_loop("run" if running else "walk")
		_player.speed_scale = clampf(speed / (RUN_SPEED if running else WALK_SPEED), 0.4, 2.0)
		return
	_player.speed_scale = 1.0
	_play_loop("ready" if c.is_in_combat() else "idle")


func _play_loop(anim: String) -> void:
	if anim == _loop and _player.current_animation == anim:
		return
	_loop = anim
	_player.play(anim, BLEND)


func _one_shot(anim: String) -> void:
	if not _player or not _player.has_animation(anim):
		return
	_player.speed_scale = 1.0
	_player.play(anim, BLEND * 0.5)
	_busy = _player.get_animation(anim).length
	if anim == "death":
		_player.queue("dead")


## As HumanoidModel._advance: every frame close by, less often further off,
## twice a second out of view.
func _advance(delta: float) -> void:
	_anim_time += delta
	var interval := 0.0
	var camera := get_viewport().get_camera_3d()
	if camera:
		var distance := camera.global_position.distance_to(global_position)
		if not camera.is_position_in_frustum(global_position + Vector3.UP * 0.5) and distance > 3.0:
			interval = HumanoidModel.OFF_SCREEN_STEP
		else:
			for band: Vector2 in HumanoidModel.ANIM_STEPS:
				if distance > band.x:
					interval = band.y
	if _anim_time >= interval:
		_player.advance(_anim_time)
		_anim_time = 0.0
