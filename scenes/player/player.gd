class_name Player
extends CharacterBody3D
## The player's character, with classic WoW movement. World units are yards.
## W and S run and backpedal, A and D turn, Q and E strafe, Space jumps,
## Num Lock autoruns and / toggles walking. While right-dragging the camera,
## the player faces where it looks and A and D strafe instead.
## Movement is instant, with no acceleration, and there's no steering in the
## air: a jump keeps the direction it started with.

## How squashed the placeholder model looks while sitting.
const SIT_HEIGHT := 0.55
## Placeholder looks for each race until there are models: size and body color.
const RACE_LOOKS := {
	ClassicData.Race.HUMAN: [Vector3(1, 1, 1), Color(0.25, 0.55, 0.85)],
	ClassicData.Race.ORC: [Vector3(1.15, 1.05, 1.15), Color(0.35, 0.6, 0.3)],
	ClassicData.Race.DWARF: [Vector3(1.2, 0.8, 1.2), Color(0.7, 0.4, 0.3)],
	ClassicData.Race.NIGHT_ELF: [Vector3(0.9, 1.15, 0.9), Color(0.5, 0.4, 0.75)],
	ClassicData.Race.UNDEAD: [Vector3(0.9, 0.98, 0.9), Color(0.58, 0.62, 0.56)],
	ClassicData.Race.TAUREN: [Vector3(1.35, 1.25, 1.35), Color(0.5, 0.35, 0.2)],
	ClassicData.Race.GNOME: [Vector3(0.75, 0.6, 0.75), Color(0.85, 0.55, 0.75)],
	ClassicData.Race.TROLL: [Vector3(0.95, 1.15, 0.95), Color(0.3, 0.6, 0.6)],
}
## Classic base speeds in yards per second.
const RUN_SPEED := 7.0
const WALK_SPEED := 2.5
const BACKPEDAL_SPEED := 4.5
## Keyboard turning: 180 degrees per second.
const TURN_RATE := PI
## Jump launch speed and gravity, giving classic WoW's jump arc.
const JUMP_SPEED := 7.96
const GRAVITY := 19.29

## Yaw in radians. Zero faces -Z.
var facing := 0.0
var autorunning := false
## Sitting: X toggles it; moving, jumping, casting or being hit stands up,
## and standing ends food and drink.
var sitting := false:
	set(value):
		sitting = value
		if combatant:
			combatant.sitting = value
			if not value:
				for aura in combatant.auras.duplicate():
					if int(aura.spell.get("AuraInterruptFlags", 0)) & SpellDB.AURA_INTERRUPT_NOT_SEATED:
						combatant.remove_aura(int(aura.spell.Id))
		if _visual:
			_visual.scale = race_scale(GameState.race) * Vector3(1, SIT_HEIGHT if value else 1.0, 1)
var walking := false
## True while a text field (the dev console) has the keyboard: no movement keys.
var typing := false
## Run speed multiplier, for the dev console's speed command.
var speed_scale := 1.0

@onready var combatant: Combatant = $Combatant
@onready var progression: Progression = $Progression
@onready var stats: CharacterStats = $CharacterStats
@onready var targeting: Targeting = $Targeting
@onready var spells: SpellCaster = $SpellCaster
@onready var _visual: Node3D = $Visual


static func race_scale(race: ClassicData.Race) -> Vector3:
	return RACE_LOOKS.get(race, RACE_LOOKS[ClassicData.Race.HUMAN])[0]


static func race_color(race: ClassicData.Race) -> Color:
	return RACE_LOOKS.get(race, RACE_LOOKS[ClassicData.Race.HUMAN])[1]


func _ready() -> void:
	combatant.display_name = GameState.char_name
	_visual.scale = race_scale(GameState.race)
	var body: MeshInstance3D = $Visual/Body
	var skin := StandardMaterial3D.new()
	skin.albedo_color = race_color(GameState.race)
	body.material_override = skin
	combatant.faces_point = is_facing
	combatant.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void:
		sitting = false
		Inventory.roll_hit_wear()
	)
	combatant.dealt_damage.connect(func(_target: Combatant) -> void: Inventory.roll_hit_wear())
	combatant.avoided.connect(func(text: String, _source: Combatant) -> void:
		if text == "Parry":
			Inventory.roll_avoidance_wear(Inventory.Slot.MAIN_HAND)
		elif text == "Block":
			Inventory.roll_avoidance_wear(Inventory.Slot.OFF_HAND)
	)
	combatant.died.connect(Inventory.lose_durability_on_death)


## Moving or in the air. Either interrupts casting.
func is_moving() -> bool:
	return not is_on_floor() or Vector2(velocity.x, velocity.z).length() > 0.1


## True if the point is anywhere in the half circle in front of the player.
func is_facing(point: Vector3) -> bool:
	var forward := Basis(Vector3.UP, facing) * Vector3.FORWARD
	var offset := point - global_position
	offset.y = 0.0
	return forward.dot(offset) >= 0.0


## Hides the character in first person.
func set_model_visible(value: bool) -> void:
	_visual.visible = value


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("target_next"):
		targeting.cycle()
	elif event.is_action_pressed("autorun"):
		autorunning = not autorunning
	elif event.is_action_pressed("sit"):
		sitting = not sitting
	elif event.is_action_pressed("toggle_walk"):
		walking = not walking
	elif event.is_action_pressed("move_up") or event.is_action_pressed("move_down"):
		autorunning = false
	for i in GameState.ACTION_SLOTS:
		if event.is_action_pressed("ability_%d" % (i + 1)) and GameState.action_bar[i] != 0:
			spells.cast(GameState.action_bar[i])


func _physics_process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d() as OrbitCamera
	var alive := combatant.is_alive()
	var direction := Vector3.ZERO
	if alive and camera:
		direction = _move_direction(camera, delta)
	_visual.rotation.y = facing

	if sitting and (direction != Vector3.ZERO or (not typing and Input.is_action_just_pressed("jump"))):
		sitting = false
	if is_on_floor():
		velocity.x = direction.x
		velocity.z = direction.z
		if alive and (not typing and Input.is_action_just_pressed("jump")):
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


## Velocity from the movement keys, already scaled to the right speed.
func _move_direction(camera: OrbitCamera, delta: float) -> Vector3:
	var forward := 0.0 if typing else Input.get_axis("move_down", "move_up")
	if autorunning or camera.is_auto_running():
		forward = maxf(forward, 1.0) if forward >= 0.0 else forward
	var turn := 0.0 if typing else Input.get_axis("move_left", "move_right")
	var strafe := 0.0 if typing else Input.get_axis("strafe_left", "strafe_right")

	if camera.is_steering():
		facing = camera.yaw
		strafe = clampf(strafe + turn, -1.0, 1.0)
	else:
		facing = wrapf(facing - turn * TURN_RATE * delta, -PI, PI)

	var local := Vector3(strafe, 0.0, -forward)
	if local == Vector3.ZERO:
		return Vector3.ZERO
	var speed := RUN_SPEED
	if walking:
		speed = WALK_SPEED
	elif forward < 0.0:
		speed = BACKPEDAL_SPEED
	return Basis(Vector3.UP, facing) * local.normalized() * speed * speed_scale
