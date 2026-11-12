class_name Npc
extends StaticBody3D
## A friendly NPC: a class trainer, a vendor, a quest giver, or several.
## Right-click within interaction range to use them. Quests name their givers
## by the NPC's node name (see data/quests.json).

@export var npc_name := "Sir Aldric Fenn"
@export var subname := "Templar Trainer"
## Trainer list in data/classic/spells.json, or "" for none.
@export var trainer := ""
## creature_template entry of a vendor in data/classic/vendors.json, or 0.
@export var vendor := 0


## How the NPC looks (HumanoidModel); empty for a look of its own from its
## name.
@export var appearance: Dictionary = {}
## Its race's model (HumanoidModel.RACE_MODELS' names: "human", "orc", "troll"...).
@export var race := "human"
## A beast's model instead (BeastModel species: "tiger" for Mist), its coat
## colour and size.
@export var beast := ""
@export var beast_color := Color(0.5, 0.5, 0.5)
@export var beast_size := 1.0
## The classic creature it stands for, when quests count it (a Lazy Peon,
## woken with Awaken Peon), or 0.
@export var creature_entry := 0
## Asleep on the ground until woken (QuestSpells: Awaken Peon); it gets up,
## complains, and dozes off again after WAKE_TIME.
@export var sleeping := false
## The escort quest (938, Mist) it follows the player on once taken, until
## the quest's ender is reached (its event) or it's lost (ESCORT_LOST yards
## behind, or the player dies), when the quest fails; then it walks home.
@export var escort := 0

const WAKE_TIME := 120.0
const WAKE_LINES := ["Ow! Okay, okay, I'm going!", "Hey! I was just resting my eyes!", "All right, all right, back to work..."]
## Escorts keep this far behind the player, walk at walking pace and run to
## catch up, and reach the ender within ESCORT_END yards.
const ESCORT_GAP := 3.0
const ESCORT_END := 8.0
const ESCORT_LOST := 60.0

var _model: Node3D
var _awake_left := 0.0
var _home: Vector3
var _home_yaw := 0.0
var _walking_home := false


func _ready() -> void:
	# NPCs wear their race's model (Humans unless set) in clothes for their
	# trade, in place of the placeholder capsule.
	for part in ["Body", "Tabard"]:
		if has_node(part):
			get_node(part).visible = false
	Targeting.mark_unit(self)
	_home = position
	_home_yaw = rotation.y
	if not beast.is_empty():
		var animal := BeastModel.new()
		animal.species = beast
		animal.colors = BeastModel.coat_colors(beast_color, beast)
		animal.scale = Vector3.ONE * beast_size
		add_child(animal)
		_model = animal
	else:
		var model := HumanoidModel.new()
		model.race = race
		add_child(model)
		model.set_appearance(appearance if not appearance.is_empty() else HumanoidModel.random_appearance(hash(npc_name)))
		model.outfit = HumanoidModel.outfit_for(trainer, hash(npc_name))
		model.show_equipment({})
		_model = model
	if sleeping:
		_pose.call_deferred("sit")
	set_physics_process(sleeping or escort != 0)
	if escort != 0:
		GameState.quest_accepted.connect(func(id: int) -> void:
			if id == escort:
				_walking_home = false)


func _pose(state: String) -> void:
	if _model and _model.has_method("pose"):
		_model.pose(state)


## Whether Awaken Peon can wake it: it's asleep.
func can_be_woken() -> bool:
	return sleeping and _awake_left <= 0.0


## Woken by Awaken Peon: it stands, grumbles, and sleeps again later.
func wake() -> void:
	_awake_left = WAKE_TIME
	_pose("idle")
	Chat.monster(npc_name, WAKE_LINES[randi() % WAKE_LINES.size()], global_position)


func _physics_process(delta: float) -> void:
	if sleeping and _awake_left > 0.0:
		_awake_left -= delta
		if _awake_left <= 0.0:
			_pose("sit")
	if escort != 0:
		_escort(delta)


## Follows the player while its escort quest is underway; brings it to an
## end at the ender, or fails it when lost.
func _escort(delta: float) -> void:
	var state: Dictionary = GameState.quests.get(escort, {})
	var going: bool = not state.is_empty() and not state.get("failed", false) and not state.get("event", false)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target := _home
	if going and player:
		var ender := get_parent().get_node_or_null(str(QuestDB.get_quest(escort).get("ender", "")))
		var behind := global_position.distance_to(player.global_position)
		var dead: bool = player.get("combatant") != null and not player.combatant.is_alive()
		if dead or behind > ESCORT_LOST:
			QuestLog.fail(escort)
			_walking_home = true
			return
		if ender and global_position.distance_to(ender.global_position) <= ESCORT_END:
			QuestLog.complete_event(escort)
			_walking_home = true
			return
		target = player.global_position
	elif not _walking_home:
		return
	var offset := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var gap := ESCORT_GAP if going else 0.5
	if offset.length() <= gap:
		_pose("idle")
		if not going:
			_walking_home = false
			rotation.y = _home_yaw
		return
	var speed := 2.5 if offset.length() < 12.0 or not going else 7.0
	var step := offset.normalized() * minf(speed * delta, offset.length() - gap)
	var next := global_position + step
	if World.current:
		next.y = World.current.height_at(next.x, next.z)
	global_position = next
	rotation.y = atan2(-offset.x, -offset.z)
	_pose("walk")


## The id quests use for this NPC: its node name.
func npc_id() -> String:
	return String(name)
