class_name Ability
extends Resource
## Data for one action bar ability.

enum Effect { DAMAGE, HEAL, STUN }
## Physical abilities use the melee combat table and armor. Other schools are
## spells: they can be resisted, crit for 1.5x and ignore armor.
enum School { PHYSICAL, HOLY, FIRE, NATURE, FROST, SHADOW, ARCANE }

@export var display_name := ""
## Short label for the action bar, which has very little room.
@export var short_name := ""
@export var effect := Effect.DAMAGE
@export var school := School.PHYSICAL
## Damage or healing done, rolled between power and power_max.
@export var power := 0
## At or below power, the amount is always exactly power.
@export var power_max := 0
## Adds a normal weapon swing's damage, like Heroic Strike.
@export var adds_weapon_damage := false
@export var mana_cost := 0
@export var cast_time := 0.0
@export var cooldown := 0.0
@export var ability_range := 2.5
@export var stun_duration := 0.0
## Above zero, damage lands when a projectile arrives. At zero it's a melee hit.
@export var projectile_speed := 0.0


func needs_target() -> bool:
	return effect != Effect.HEAL


func is_spell() -> bool:
	return school != School.PHYSICAL


func roll_amount(user: Combatant) -> float:
	var amount := float(randi_range(power, maxi(power, power_max)))
	if adds_weapon_damage:
		amount += user.roll_weapon_damage()
	return amount
