class_name CharacterPreview
extends SubViewportContainer
## A model of a character for the login screens, rendered at low resolution
## like the game. Shows the race's placeholder look from Player. It stands
## still, facing the camera, until the player drags it with the left mouse
## button to turn it.

## Screen pixels per rendered pixel.
@export var pixel_scale := 3
## Radians of turn per screen pixel dragged.
@export var drag_turn := 0.01

## Kept across previews, so rebuilding a screen (picking a race) keeps the turn.
static var _facing := PI
var _dragging := false

var _model := Node3D.new()
var _body := MeshInstance3D.new()
var _nose := MeshInstance3D.new()
var _material := StandardMaterial3D.new()
## The Human model, made when first shown.
var _human: HumanoidModel


func _ready() -> void:
	stretch = true
	stretch_shrink = pixel_scale
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	add_child(viewport)
	var camera := Camera3D.new()
	# Framed so the character fills the height, feet near the bottom edge.
	camera.fov = 30.0
	camera.position = Vector3(0, 1.5, 5.75)
	camera.rotation.x = deg_to_rad(-4.0)
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0)
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.45, 0.45, 0.6)
	viewport.add_child(environment)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.05
	ground.mesh = disc
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.25, 0.24, 0.28)
	ground.material_override = stone
	viewport.add_child(ground)
	# The same placeholder shapes as the player scene: a capsule and a nose.
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	_body.mesh = capsule
	_body.position.y = 0.9
	_body.material_override = _material
	_model.add_child(_body)
	var nose := _nose
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.25, 0.4)
	nose.mesh = box
	nose.position = Vector3(0, 1.3, -0.45)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.95, 0.75, 0.3)
	nose.material_override = gold
	_model.add_child(nose)
	_model.rotation.y = _facing
	viewport.add_child(_model)


## Shows a race: Humans as the model, with an appearance and what they wear
## (Inventory.Slot -> item stack); other races as the placeholder.
func show_race(race: ClassicData.Race, appearance := {}, equipment := {}) -> void:
	var human := race == ClassicData.Race.HUMAN
	_body.visible = not human
	_nose.visible = not human
	if human:
		_model.scale = Vector3.ONE
		if not _human:
			_human = HumanoidModel.new()
			_model.add_child(_human)
		_human.visible = true
		_human.set_appearance(appearance if not appearance.is_empty() else HumanoidModel.random_appearance(0))
		_human.show_equipment(equipment)
		return
	if _human:
		_human.visible = false
	_model.scale = Player.race_scale(race)
	_material.albedo_color = Player.race_color(race)


## What a new character of a race and class starts out wearing.
static func kit_equipment(race: ClassicData.Race, char_class: ClassicData.CharClass) -> Dictionary:
	var equipment := {}
	for entry: Array in ClassicData.starting_kit(race, char_class).items:
		var item := ItemDB.get_item(int(entry[0]))
		for slot: int in Inventory.SLOTS_FOR_TYPE.get(int(item.get("InventoryType", 0)), []):
			if not equipment.has(slot):
				equipment[slot] = { "id": int(entry[0]), "count": 1 }
				break
	return equipment


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		accept_event()
	var motion := event as InputEventMouseMotion
	if motion and _dragging:
		_facing = wrapf(_facing + motion.relative.x * drag_turn, -PI, PI)
		_model.rotation.y = _facing
		accept_event()
