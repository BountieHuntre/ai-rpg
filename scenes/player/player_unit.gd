class_name PlayerUnit
extends CharacterBody3D
## A player character in the world: the Player you control, or a playerbot.
## Spells, stats and levelling work on any PlayerUnit through its profile.
## Needs Combatant and Visual children.

## How squashed the placeholder model looks while sitting.
const SIT_HEIGHT := 0.55
## Highest falling speed under Featherfall, in yards per second.
const FEATHER_FALL_SPEED := 3.0
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

## Name, race, class, level, gear and spells: GameState for the player.
var profile: CharacterProfile
## A Ranger's pet out in the world, or null.
var pet: Pet
## Yaw in radians. Zero faces -Z.
var facing := 0.0
## Sitting: moving, jumping, casting or being hit stands up, and standing ends
## food and drink.
var sitting := false:
	set(value):
		sitting = value
		if combatant:
			combatant.sitting = value
			if not value:
				for aura in combatant.auras.duplicate():
					if int(aura.spell.get("AuraInterruptFlags", 0)) & SpellDB.AURA_INTERRUPT_NOT_SEATED:
						combatant.remove_aura(int(aura.spell.Id))
		if _visual and profile and not model:
			_visual.scale = race_scale(profile.race) * Vector3(1, SIT_HEIGHT if value else 1.0, 1)

## The character model, for races that have one (Humans); others show the
## placeholder capsule.
var model: HumanoidModel
## Classic's sheath state (HumanoidModel.Sheath): weapons put away until a
## fight draws them, as the client does: starting to attack or swinging
## draws the melee weapons, starting to shoot or a ranged ability the ranged
## one, a melee or ranged ability its own; they stay out after the fight
## until the sheathe key (Z, `toggle_sheath`) puts them away, and dying puts
## them away, as does casting a spell with a cast time (in a fight they
## come out again when it ends, straight into the hands; out of one the next
## swing draws them). Bots put theirs away a few seconds after a fight, as
## a player would (`BOT_SHEATHE_DELAY`).
var sheath_state := HumanoidModel.Sheath.UNARMED
const BOT_SHEATHE_DELAY := 5.0
var _was_attacking := false
var _was_shooting := false
var _was_casting := false
## The last change of `sheath_state` happens without a draw or sheathe
## motion (weapons back in hand after a cast in a fight); the model clears it.
var sheath_quietly := false
var _before_cast := HumanoidModel.Sheath.UNARMED
var _calm_for := 0.0

@onready var combatant: Combatant = $Combatant
@onready var _visual: Node3D = $Visual


static func race_scale(race: ClassicData.Race) -> Vector3:
	return RACE_LOOKS.get(race, RACE_LOOKS[ClassicData.Race.HUMAN])[0]


static func race_color(race: ClassicData.Race) -> Color:
	return RACE_LOOKS.get(race, RACE_LOOKS[ClassicData.Race.HUMAN])[1]


## Dresses the unit for the profile's race: its model (HumanoidModel's
## RACE_MODELS), or the placeholder capsule sized and coloured for races
## without one.
func apply_race_look() -> void:
	# Out of the target ring's projection.
	Targeting.mark_unit(_visual)
	var race_model := HumanoidModel.model_race(profile.race)
	for part in ["Body", "Nose"]:
		_visual.get_node(part).visible = race_model == ""
	if model and model.race != race_model:
		model.queue_free()
		model = null
	if race_model != "":
		_visual.scale = Vector3.ONE
		if not model:
			model = HumanoidModel.new()
			model.race = race_model
			_visual.add_child(model)
			model.attach(self)
			watch_sheath()
		if profile.appearance.is_empty():
			profile.appearance = HumanoidModel.random_appearance(hash(profile.char_name))
		model.set_appearance(profile.appearance)
		model.show_equipment(profile.equipment)
		return
	_visual.scale = race_scale(profile.race)
	var body: MeshInstance3D = _visual.get_node("Body")
	var skin := StandardMaterial3D.new()
	skin.albedo_color = race_color(profile.race)
	body.material_override = skin


## The sheathe key: weapons away, or the melee ones out.
func toggle_sheath() -> void:
	sheath_state = HumanoidModel.Sheath.MELEE if sheath_state == HumanoidModel.Sheath.UNARMED else HumanoidModel.Sheath.UNARMED


## Classic's draws: called by the model as it updates (it's only a look).
func update_sheath(delta: float) -> void:
	var c := combatant
	if not c.is_alive():
		sheath_state = HumanoidModel.Sheath.UNARMED
		return
	var attacking := c.attack_target != null
	var shooting := c.shoot_target != null
	# Casting a spell (one with a cast time or channel, not a melee or
	# ranged ability) puts the weapons away; in a fight they come out again
	# when it ends (what was in hand before, else the melee ones), out of a
	# fight the next swing draws them.
	var caster := get_node_or_null("SpellCaster")
	var spell_cast: bool = caster != null and not caster.casting.is_empty() 			and int(caster.casting.get("DmgClass", 0)) not in [2, 3]
	if spell_cast:
		if not _was_casting:
			_before_cast = sheath_state
		sheath_state = HumanoidModel.Sheath.UNARMED
	elif _was_casting and c.is_in_combat():
		sheath_state = _before_cast if _before_cast != HumanoidModel.Sheath.UNARMED else HumanoidModel.Sheath.MELEE
		sheath_quietly = true
	_was_casting = spell_cast
	if shooting and not _was_shooting:
		sheath_state = HumanoidModel.Sheath.RANGED
	elif attacking and not _was_attacking:
		sheath_state = HumanoidModel.Sheath.MELEE
	_was_attacking = attacking
	_was_shooting = shooting
	if self is Player:
		return
	if attacking or shooting or c.is_in_combat():
		_calm_for = 0.0
	else:
		_calm_for += delta
		if _calm_for >= BOT_SHEATHE_DELAY:
			sheath_state = HumanoidModel.Sheath.UNARMED


## Swings and abilities draw what they use.
func watch_sheath() -> void:
	combatant.swung.connect(func(_target: Combatant) -> void: sheath_state = HumanoidModel.Sheath.MELEE)
	combatant.off_hand_swung.connect(func(_target: Combatant) -> void: sheath_state = HumanoidModel.Sheath.MELEE)
	var caster := get_node_or_null("SpellCaster")
	if caster:
		caster.spell_finished.connect(_draw_for_spell)


## A melee ability (SpellDmgClass 2) draws the melee weapons, a ranged one
## (3) the ranged weapon.
func _draw_for_spell(spell: Dictionary) -> void:
	match int(spell.get("DmgClass", 0)):
		2:
			sheath_state = HumanoidModel.Sheath.MELEE
		3:
			sheath_state = HumanoidModel.Sheath.RANGED


## Moving or in the air. Either interrupts casting.
func is_moving() -> bool:
	return not is_on_floor() or Vector2(velocity.x, velocity.z).length() > 0.1


## True if the point is anywhere in the half circle in front of the unit.
func is_facing(point: Vector3) -> bool:
	var forward := Basis(Vector3.UP, facing) * Vector3.FORWARD
	var offset := point - global_position
	offset.y = 0.0
	return forward.dot(offset) >= 0.0


## The enemy a harmful spell goes at: the player's target, or the one a bot
## picked.
func enemy_target() -> Combatant:
	return null


## The friendly unit a helpful spell goes at, or null for the caster.
func friendly_target() -> Combatant:
	return null
