class_name Ability
extends Resource
## Data for one action bar ability.

enum Effect { DAMAGE, HEAL, STUN }

@export var display_name := ""
## Short label for the action bar, which has very little room.
@export var short_name := ""
@export var effect := Effect.DAMAGE
## Damage or healing done.
@export var power := 0
@export var mana_cost := 0
@export var cast_time := 0.0
@export var cooldown := 0.0
@export var ability_range := 2.5
@export var stun_duration := 0.0
## Above zero, damage lands when a projectile arrives. At zero it's a melee hit.
@export var projectile_speed := 0.0


func needs_target() -> bool:
	return effect != Effect.HEAL
