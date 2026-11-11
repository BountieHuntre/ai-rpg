class_name UnitFeedback
extends Node3D
## Makes combat readable on a unit: attack lunges, hit flashes, stun stars and a
## death fall. Must be a child of a unit with Combatant and Visual children.
## Flash and corpse colors are opaque because the outline shader draws over
## transparent materials.

const FLASH_TIME := 0.1
const LUNGE_DISTANCE := 0.45
const LUNGE_OUT_TIME := 0.07
const LUNGE_BACK_TIME := 0.13
const FALL_TIME := 0.35
const STAR_COUNT := 3
const STAR_RADIUS := 0.4
const STAR_HEIGHT := 2.1
const STAR_SPIN := 5.0

@export var hurt_sound := "enemy_hurt"
@export var death_sound := "enemy_die"
## Rotation axis of the death fall, in the visual's own space: X falls over
## backwards; Z rolls onto the side, for beasts already lying along the ground.
@export var fall_axis := "x"

var _flash_left := 0.0
var _dead := false
var _meshes: Array[MeshInstance3D] = []
var _flash_material := _flat_material(Color.WHITE)
var _corpse_material := _flat_material(Color(0.3, 0.28, 0.28))
var _stars := Node3D.new()
var _tween: Tween

@onready var _combatant: Combatant = $"../Combatant"
@onready var _visual: Node3D = $"../Visual"


func _ready() -> void:
	for child in _visual.get_children():
		if child is MeshInstance3D:
			_meshes.append(child)
	_build_stars()
	_combatant.took_damage.connect(_on_took_damage)
	_combatant.swung.connect(_on_swung)
	_combatant.died.connect(_on_died)
	_combatant.healed.connect(func(_amount: int, _crit: bool) -> void: _play("heal"))
	_combatant.stunned.connect(_play.bind("stun"))


## Restores the unit's normal look after it respawns.
func reset() -> void:
	_dead = false
	_flash_left = 0.0
	if _tween:
		_tween.kill()
	if _model():
		_apply_material()
		return
	_visual.position = Vector3.ZERO
	_visual.rotation.x = 0.0
	_visual.rotation.z = 0.0
	_apply_material()


## Shows the unit as an already-fallen corpse, for corpses restored from a save.
func show_dead() -> void:
	_dead = true
	if _tween:
		_tween.kill()
	if _model():
		_model().show_dead()
		_apply_material()
		return
	_visual.position = Vector3.ZERO
	_visual.set_indexed("rotation:" + fall_axis, -PI / 2.0)
	_apply_material()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_apply_material()
	_stars.visible = _combatant.is_stunned()
	if _stars.visible:
		_stars.rotate_y(STAR_SPIN * delta)


func _on_took_damage(_amount: int, _source: Combatant, _crit: bool) -> void:
	_flash_left = FLASH_TIME
	_apply_material()
	if _combatant.is_alive():
		_play(hurt_sound)


func _play(sound: String) -> void:
	Sfx.play_at(sound, _combatant.body.global_position)


func _on_swung(target: Combatant) -> void:
	_play("swing")
	# A character model swings its weapon instead of lunging.
	if _model():
		return
	var offset := target.body.global_position - _combatant.body.global_position
	offset.y = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_visual, "position", offset.normalized() * LUNGE_DISTANCE, LUNGE_OUT_TIME)
	_tween.tween_property(_visual, "position", Vector3.ZERO, LUNGE_BACK_TIME)


func _on_died() -> void:
	_play(death_sound)
	_dead = true
	_apply_material()
	if _tween:
		_tween.kill()
	if _model():
		return
	_visual.position = Vector3.ZERO
	_tween = create_tween()
	_tween.tween_property(_visual, "rotation:" + fall_axis, -PI / 2.0, FALL_TIME).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _apply_material() -> void:
	var material: Material = null
	if _flash_left > 0.0:
		material = _flash_material
	elif _dead:
		material = _corpse_material
	for mesh in _meshes:
		mesh.material_override = material
	var model := _model()
	if model:
		model.set_flash(_flash_left > 0.0)
		model.set_corpse(_dead and _flash_left <= 0.0)


## The unit's character model, when it has one (HumanoidModel).
func _model() -> HumanoidModel:
	return _visual.get_node_or_null("HumanoidModel") as HumanoidModel


func _build_stars() -> void:
	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3.ONE * 0.16
	star_mesh.material = _flat_material(Color(1, 0.9, 0.25))
	for i in STAR_COUNT:
		var star := MeshInstance3D.new()
		star.mesh = star_mesh
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * i / STAR_COUNT
		star.position = Vector3(cos(angle), 0.0, sin(angle)) * STAR_RADIUS
		_stars.add_child(star)
	_stars.position.y = STAR_HEIGHT
	_stars.visible = false
	add_child(_stars)


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material
