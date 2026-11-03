class_name PlayerUnit
extends CharacterBody3D
## A player character in the world: the Player you control, or a playerbot.
## Spells, stats and levelling work on any PlayerUnit through its profile.
## Needs Combatant and Visual children.

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

## Name, race, class, level, gear and spells: GameState for the player.
var profile: CharacterProfile
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
		if _visual and profile:
			_visual.scale = race_scale(profile.race) * Vector3(1, SIT_HEIGHT if value else 1.0, 1)

@onready var combatant: Combatant = $Combatant
@onready var _visual: Node3D = $Visual


static func race_scale(race: ClassicData.Race) -> Vector3:
	return RACE_LOOKS.get(race, RACE_LOOKS[ClassicData.Race.HUMAN])[0]


static func race_color(race: ClassicData.Race) -> Color:
	return RACE_LOOKS.get(race, RACE_LOOKS[ClassicData.Race.HUMAN])[1]


## Dresses the placeholder model for the profile's race.
func apply_race_look() -> void:
	_visual.scale = race_scale(profile.race)
	var body: MeshInstance3D = _visual.get_node("Body")
	var skin := StandardMaterial3D.new()
	skin.albedo_color = race_color(profile.race)
	body.material_override = skin


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
