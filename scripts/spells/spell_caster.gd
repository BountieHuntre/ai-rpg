class_name SpellCaster
extends Node
## Casts the player's classic WoW spells: checks, global cooldown, cooldowns,
## cast times and the effects of each Paladin spell. Formulas follow the
## CMaNGOS classic code; see data/classic/SOURCE.md.
## Must be a child of the Player.

signal failed(message: String)

## Classic error messages.
const ERR_NOT_READY := "Spell is not ready yet."
const ERR_IN_PROGRESS := "Another action is in progress"
const ERR_NO_MANA := "Not enough mana"
const ERR_NO_TARGET := "You have no target."
const ERR_RANGE := "Out of range."
const ERR_FACING := "Target needs to be in front of you."
const ERR_LINE_OF_SIGHT := "Target not in line of sight"
const ERR_MOVING := "Can't do that while moving"
const ERR_DEAD_TARGET := "Invalid target"

const WORLD_LAYER := 1
const EYE_HEIGHT := 1.2

## The spell being cast, or {} when not casting.
var casting: Dictionary = {}

var _cast_left := 0.0
var _cast_total := 0.0
var _cast_target: Combatant
var _gcd_left := 0.0
var _gcd_total := 1.5
## Spell id -> seconds of cooldown left.
var _cooldowns: Dictionary = {}

@onready var _player: Player = get_parent()


func _ready() -> void:
	# The Player's own @onready references aren't set yet while children are readied.
	var combatant: Combatant = $"../Combatant"
	combatant.auto_attack_landed.connect(_on_auto_attack_landed)


## Starts casting a known spell, or reports why it can't.
func cast(id: int) -> void:
	var me := _player.combatant
	if not me.is_alive() or not id in GameState.known_spells:
		return
	if id == SpellDB.ATTACK:
		_toggle_attack()
		return
	var spell := SpellDB.get_spell(id)
	var target := _pick_target(spell)
	var problem := _find_problem(spell, target, true)
	if not problem.is_empty():
		failed.emit(problem)
		return
	var gcd := SpellDB.global_cooldown(spell)
	if gcd > 0.0:
		_gcd_left = gcd
		_gcd_total = gcd
	var time := SpellDB.cast_time(spell)
	if time > 0.0:
		Sfx.play("cast")
		casting = spell
		_cast_left = time
		_cast_total = time
		_cast_target = target
	else:
		_finish(spell, target)


func cast_fraction() -> float:
	return 1.0 - _cast_left / _cast_total if not casting.is_empty() else 0.0


## How much of a spell's cooldown (or the global cooldown) is left, 1 to 0.
func cooldown_fraction(id: int) -> float:
	var spell := SpellDB.get_spell(id)
	var fraction := 0.0
	if SpellDB.global_cooldown(spell) > 0.0:
		fraction = _gcd_left / _gcd_total
	var total := SpellDB.cooldown(spell)
	if total > 0.0:
		fraction = maxf(fraction, _cooldowns.get(id, 0.0) / total)
	return fraction


func mana_cost(spell: Dictionary) -> int:
	return SpellDB.mana_cost(spell, ClassicData.base_mana(GameState.char_class, GameState.level))


## Whether the current target is out of the spell's range, for the action bar.
func out_of_range(id: int) -> bool:
	var spell := SpellDB.get_spell(id)
	if id == SpellDB.ATTACK or SpellDB.target_type(spell) != SpellDB.TARGET_ENEMY:
		return false
	var target := _player.targeting.target_combatant()
	return target != null and _player.combatant.distance_to(target) > SpellDB.spell_range(spell)


func _physics_process(delta: float) -> void:
	_gcd_left = maxf(_gcd_left - delta, 0.0)
	for id: int in _cooldowns.keys():
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)
	if casting.is_empty():
		return
	if _player.is_moving() or not _player.combatant.is_alive():
		casting = {}
		failed.emit("Interrupted")
		return
	_cast_left -= delta
	if _cast_left <= 0.0:
		var spell := casting
		casting = {}
		var problem := _find_problem(spell, _cast_target, false)
		if problem.is_empty():
			_finish(spell, _cast_target)
		else:
			failed.emit(problem)


func _toggle_attack() -> void:
	var me := _player.combatant
	if me.attack_target:
		me.attack_target = null
		return
	var target := _player.targeting.target_combatant()
	if target == null or not target.is_alive():
		failed.emit(ERR_NO_TARGET)
		return
	me.attack_target = target


## Harmful spells go at the current target. Friendly ones go at the target if
## it's friendly, otherwise at the caster (there are no friendly units yet).
func _pick_target(spell: Dictionary) -> Combatant:
	match SpellDB.target_type(spell):
		SpellDB.TARGET_ENEMY:
			return _player.targeting.target_combatant()
		_:
			return _player.combatant


func _find_problem(spell: Dictionary, target: Combatant, starting: bool) -> String:
	var me := _player.combatant
	if starting:
		if not casting.is_empty():
			return ERR_IN_PROGRESS
		if SpellDB.global_cooldown(spell) > 0.0 and _gcd_left > 0.0:
			return ERR_NOT_READY
		if _cooldowns.get(int(spell.Id), 0.0) > 0.0:
			return ERR_NOT_READY
		if SpellDB.cast_time(spell) > 0.0 and _player.is_moving():
			return ERR_MOVING
	if me.mana < mana_cost(spell):
		return ERR_NO_MANA
	if SpellDB.target_type(spell) == SpellDB.TARGET_ENEMY:
		if target == null:
			return ERR_NO_TARGET
		if not target.is_alive():
			return ERR_DEAD_TARGET
		if me.distance_to(target) > SpellDB.spell_range(spell):
			return ERR_RANGE
		if not _player.is_facing(target.body.global_position):
			return ERR_FACING
		if not _has_line_of_sight(target):
			return ERR_LINE_OF_SIGHT
	return ""


func _has_line_of_sight(target: Combatant) -> bool:
	var eye := Vector3.UP * EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + eye, target.body.global_position + eye, WORLD_LAYER
	)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _finish(spell: Dictionary, target: Combatant) -> void:
	var me := _player.combatant
	me.spend_mana(mana_cost(spell))
	var cooldown := SpellDB.cooldown(spell)
	if cooldown > 0.0:
		_cooldowns[int(spell.Id)] = cooldown
	if spell.SpellName == "Holy Light":
		_holy_light(spell, target)
	elif SpellDB.is_seal(spell):
		_apply_seal(spell)


## Holy Light's script effect heals through spell 19968 (SpellEffects.cpp).
func _holy_light(spell: Dictionary, target: Combatant) -> void:
	var amount := SpellDB.effect_value(spell, 0, GameState.level)
	amount += _spell_power() * SpellDB.direct_coefficient(SpellDB.HOLY_LIGHT_HEAL)
	target.heal_with_spell(amount)


## Only one seal at a time.
func _apply_seal(spell: Dictionary) -> void:
	var me := _player.combatant
	for aura in me.auras.duplicate():
		if SpellDB.is_seal(aura.spell):
			me.remove_aura(int(aura.spell.Id))
	me.add_aura(spell, me)
	Sfx.play("buff")


## Seal of Righteousness adds Holy damage to each white melee hit. The proc
## always hits and can't crit (its spell has ALWAYS_HIT and CANT_CRIT).
## Formula from Unit::HandleDummyAuraProc in CMaNGOS classic.
func _on_auto_attack_landed(target: Combatant) -> void:
	var seal := _player.combatant.find_aura(func(spell: Dictionary) -> bool:
		return SpellDB.seal_of_righteousness_proc(int(spell.Id)) != 0
	)
	if seal.is_empty() or not target.is_alive():
		return
	target.take_damage(seal_of_righteousness_damage(seal.spell), _player.combatant, false)


## Holy damage per hit for the equipped weapon.
func seal_of_righteousness_damage(seal: Dictionary) -> int:
	var amount := SpellDB.effect_value(seal, 0, GameState.level)
	var weapon: Dictionary = GameState.equipment.get(Inventory.Slot.MAIN_HAND, {})
	var item := {} if weapon.is_empty() else ItemDB.get_item(weapon.id)
	var speed := 2.0 if item.is_empty() else int(item.delay) / 1000.0
	var base: float
	if not item.is_empty() and int(item.InventoryType) == Inventory.INVTYPE_TWO_HAND:
		base = 1.20 * amount * 1.2 * 1.03 * speed / 100.0 + 1.0
	else:
		base = 0.85 * ceilf(amount * 1.2 * 1.03 * speed / 100.0) - 1.0
	var unarmed := Inventory.UNARMED_WEAPON
	var weapon_average: float = (unarmed.min + unarmed.max) / 2.0
	if not item.is_empty():
		weapon_average = (float(item.dmg_min1) + float(item.dmg_max1)) / 2.0
	return int(base + 0.03 * weapon_average) + 1


## Bonus spell damage and healing from gear. Nothing grants it yet.
func _spell_power() -> float:
	return 0.0
