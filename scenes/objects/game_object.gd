class_name GameObject
extends StaticBody3D
## A thing in the world to loot, as classic's chest game objects (type 3):
## a Bundle of Wood. Its data (name, loot id, respawn time) comes from
## data/classic/gameobjects.json by `entry`. Right-click it within reach to
## open its loot (LootTable.roll_object), as a corpse: its quest-only items
## drop only for quests underway, and it sparkles and can be opened only
## while it holds something the player's quests need. Once emptied it's gone
## until its respawn time has passed. It sits on the corpse physics layer, so
## the camera's clicks find it. Playerbots take from it too (take_for_bot).

const DATA_PATH := "res://data/classic/gameobjects.json"
const TYPE_QUESTGIVER := 2
const TYPE_CHEST := 3
## Objects to use (classic's goobers): the Kolkar attack plans, taken by
## clicking; Maren's Grave, where remains are buried with an item's spell.
const TYPE_GOOBER := 10

static var _data: Dictionary

@export var entry := 0
var loot: Array[Dictionary] = []
var loot_money := 0
## Unix time it comes back, or 0 while it's there.
var respawn_at := 0.0
var _rolled := false
var _sparkle: Node3D
var _model: Node3D


static func data(id: int) -> Dictionary:
	_load()
	return _data.get(str(id), {})


## Every object entry in the data.
static func all_ids() -> Array:
	_load()
	return _data.keys().map(func(key: String) -> int: return int(key))


static func _load() -> void:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


func object_type() -> int:
	return int(data(entry).get("type", TYPE_CHEST))


func object_name() -> String:
	return str(data(entry).get("name", "Object"))


func loot_id() -> int:
	return int(data(entry).get("loot", 0))


func _ready() -> void:
	add_to_group("game_objects")
	collision_layer = Enemy.CORPSE_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.9, 1.0)
	shape.shape = box
	shape.position.y = 0.45
	add_child(shape)
	_model = _build_model()
	add_child(_model)
	_sparkle = _build_sparkle()
	add_child(_sparkle)


## A bundle of short logs tied with rope; for objects to use, by their name:
## a headstone, rolled plans on a crate, a pick in a rock.
func _build_model() -> Node3D:
	var model := Node3D.new()
	var thing := object_name()
	if "Grave" in thing:
		Props.box(model, Vector3(0, 0, -0.5), Vector3(0.9, 1.2, 0.25), Color(0.5, 0.5, 0.52), 0.0, false)
		Props.box(model, Vector3(0, 0, 0.4), Vector3(1.0, 0.2, 1.8), Color(0.32, 0.26, 0.2), 0.0, false)
		return model
	if "Attack Plan" in thing:
		Props.box(model, Vector3.ZERO, Vector3(0.9, 0.6, 0.7), Color(0.45, 0.32, 0.2), 0.0, false)
		Props.box(model, Vector3(0, 0.6, 0), Vector3(0.7, 0.05, 0.5), Color(0.85, 0.8, 0.65), 0.2, false)
		return model
	if "Pick" in thing:
		Props.cylinder(model, Vector3.ZERO, 0.6, 0.5, Color(0.42, 0.4, 0.38), false, 0.4)
		var handle := Props.box(model, Vector3(0, 0.5, 0), Vector3(0.08, 1.1, 0.08), Color(0.45, 0.31, 0.2), 0.0, false)
		handle.rotation.z = 0.4
		Props.box(model, Vector3(-0.25, 1.05, 0), Vector3(0.7, 0.1, 0.1), Color(0.35, 0.35, 0.38), 0.4, false)
		return model
	for i in 3:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.18
		log_mesh.bottom_radius = 0.18
		log_mesh.height = 1.2
		log_mesh.radial_segments = 6
		var view := MeshInstance3D.new()
		view.mesh = log_mesh
		view.material_override = Props.material(Color(0.45, 0.31, 0.2))
		view.rotation.z = PI / 2
		view.position = Vector3(0, 0.18 + (0.3 if i == 2 else 0.0), -0.19 + (0.19 if i == 2 else i * 0.38))
		model.add_child(view)
	var rope := MeshInstance3D.new()
	var band := BoxMesh.new()
	band.size = Vector3(0.12, 0.7, 0.85)
	rope.mesh = band
	rope.material_override = Props.material(Color(0.7, 0.6, 0.4))
	rope.position.y = 0.3
	model.add_child(rope)
	return model


func _build_sparkle() -> Node3D:
	var sparkle := Node3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.85, 0.3)
	mesh.material = material
	for i in 4:
		var cube := MeshInstance3D.new()
		cube.mesh = mesh
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * i / 4.0
		cube.position = Vector3(cos(angle) * 0.7, 0.6 + 0.15 * (i % 2), sin(angle) * 0.7)
		sparkle.add_child(cube)
	sparkle.visible = false
	return sparkle


func is_spawned() -> bool:
	return respawn_at <= 0.0


## Whether it holds anything the player can take now: loot left, or quest
## items a quest underway still needs.
func is_usable() -> bool:
	if not is_spawned():
		return false
	if object_type() == TYPE_GOOBER:
		return QuestLog.needs_object(-entry, 0)
	if _rolled:
		return not loot.is_empty()
	for item in LootTable.object_items(loot_id()):
		if QuestLog.needs_item(item):
			return true
	return false


func has_loot() -> bool:
	return is_spawned() and not loot.is_empty()


## Opens it: rolls its loot the first time. Returns whether there's loot.
## An object to use is used instead: a quest counts it, and it's gone until
## it respawns.
func open() -> bool:
	if not is_usable():
		return false
	if object_type() == TYPE_GOOBER:
		QuestLog.credit_object(-entry, 0)
		_despawn()
		return false
	if not _rolled:
		loot = LootTable.roll_object(loot_id())
		_rolled = true
	return has_loot()


## Whether it holds an item (for playerbots, which don't loot).
func holds(item_id: int) -> bool:
	return is_spawned() and item_id in LootTable.object_items(loot_id())


## A playerbot takes it: it's gone until it respawns.
func take_for_bot() -> void:
	_despawn()


func _wanted_by_spell() -> bool:
	for id: int in GameState.quests:
		for wanted: Array in QuestDB.get_quest(id).get("objects", []):
			if int(wanted[0]) == -entry and int(wanted[2]) != 0 and QuestLog.needs_object(-entry, int(wanted[2])):
				return true
	return false


func _despawn() -> void:
	loot.clear()
	_rolled = false
	respawn_at = Time.get_unix_time_from_system() + float(data(entry).get("respawn", 180))
	_model.visible = false
	_sparkle.visible = false
	collision_layer = 0


func _process(delta: float) -> void:
	if not is_spawned():
		if Time.get_unix_time_from_system() >= respawn_at:
			respawn_at = 0.0
			_model.visible = true
			collision_layer = Enemy.CORPSE_LAYER
		return
	# Emptied by the player: gone until it comes back.
	if _rolled and loot.is_empty():
		_despawn()
		return
	# Objects a quest wants a spell cast on (Maren's Grave) sparkle too.
	_sparkle.visible = is_usable() or (object_type() == TYPE_GOOBER and _wanted_by_spell())
	if _sparkle.visible:
		_sparkle.rotate_y(2.0 * delta)
