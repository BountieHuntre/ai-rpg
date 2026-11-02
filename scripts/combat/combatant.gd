class_name Combatant
extends Node
## Health, mana, combat stats and auto-attack, shared by the player and
## enemies. Hits are resolved with the classic combat table in CombatRules.
## Must be a direct child of the unit's body.

signal swung(target: Combatant)
signal took_damage(amount: int, source: Combatant, crit: bool)
## A hit that was turned away entirely, such as a miss, dodge or resist.
signal avoided(text: String, source: Combatant)
signal healed(amount: int, crit: bool)
signal stunned
signal died
## A white melee swing hit (including glancing, crushing, blocked and crits).
signal auto_attack_landed(target: Combatant)
signal auras_changed

## Leaving combat takes this long without dealing or taking hits, while no
## enemy is chasing.
const COMBAT_TIMEOUT := 5.0
const CRUSH_MULTIPLIER := 1.5

@export var display_name := ""
@export var level := 1
@export var max_health := 100
@export var max_mana := 0
@export var melee_range := 2.5

var is_player := false
var armor := 0
var attack_power := 0
var min_damage := 1.0
var max_damage := 2.0
var swing_interval := 2.0
## Chances in percent, before the level-difference adjustments in CombatRules.
var melee_crit := 0.0
var spell_crit := 0.0
var dodge := 0.0
var parry := 0.0
var block := 0.0
var block_value := 0

var health := 0
var mana := 0.0
var invulnerable := false
## While set, swings at this combatant whenever it is in melee range.
var attack_target: Combatant
## Optional check of whether this unit is facing a world position.
var faces_point: Callable

## Buffs and debuffs: { "spell": spell_template row, "caster": Combatant,
## "remaining": seconds (-1 until cancelled), "duration": seconds }.
var auras: Array[Dictionary] = []

var _stun_left := 0.0
var _swing_left := 0.0
var _combat_left := 0.0
var _since_mana_spent := INF

@onready var body: Node3D = get_parent()


func _ready() -> void:
	add_to_group("combatants")
	reset()


func reset() -> void:
	health = max_health
	mana = max_mana
	attack_target = null
	invulnerable = false
	_stun_left = 0.0
	_combat_left = 0.0
	clear_auras()


func is_alive() -> bool:
	return health > 0


func is_stunned() -> bool:
	return _stun_left > 0.0


## Units that are stunned or dead can't dodge, parry or block.
func can_react() -> bool:
	return is_alive() and not is_stunned()


func is_in_combat() -> bool:
	return _combat_left > 0.0


func enter_combat() -> void:
	_combat_left = COMBAT_TIMEOUT


func seconds_since_mana_spent() -> float:
	return _since_mana_spent


func faces(other: Combatant) -> bool:
	return not faces_point.is_valid() or faces_point.call(other.body.global_position)


## Weapon and defense skill are always at their cap of 5 per level.
func max_skill() -> int:
	return level * 5


func weapon_skill() -> int:
	return max_skill()


func defense_skill() -> int:
	return max_skill()


func distance_to(other: Combatant) -> float:
	return body.global_position.distance_to(other.body.global_position)


## Adds or refreshes an aura. The same spell replaces itself.
func add_aura(spell: Dictionary, caster: Combatant) -> void:
	remove_aura(int(spell.Id), false)
	var length := SpellDB.duration(spell)
	auras.append({ "spell": spell, "caster": caster, "remaining": length, "duration": length })
	auras_changed.emit()


func remove_aura(spell_id: int, notify := true) -> void:
	var before := auras.size()
	auras = auras.filter(func(aura: Dictionary) -> bool: return int(aura.spell.Id) != spell_id)
	if notify and auras.size() != before:
		auras_changed.emit()


func find_aura(test: Callable) -> Dictionary:
	for aura in auras:
		if test.call(aura.spell):
			return aura
	return {}


func clear_auras() -> void:
	if not auras.is_empty():
		auras.clear()
		auras_changed.emit()


func spend_mana(amount: int) -> void:
	if amount > 0:
		mana -= amount
		_since_mana_spent = 0.0


## Weapon damage plus the attack power bonus of AP / 14 per second of swing time.
func roll_weapon_damage() -> float:
	return randf_range(min_damage, max_damage) + attack_power / 14.0 * swing_interval


## Resolves a melee ability against the target. Returns whether it landed.
func strike_with_ability(target: Combatant, damage: float) -> bool:
	return _resolve_melee(target, damage, CombatRules.roll_melee_ability(self, target))


## Resolves a harmful spell against the target. Returns whether it landed.
func hit_with_spell(target: Combatant, damage: float) -> bool:
	_engage(target)
	var outcome := CombatRules.roll_spell(self, target)
	if outcome == CombatRules.Outcome.RESIST:
		target.avoid(CombatRules.OUTCOME_TEXT[outcome], self)
		return false
	var crit := outcome == CombatRules.Outcome.CRIT
	target.take_damage(roundi(damage * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)), self, crit)
	return true


func heal_with_spell(amount: float) -> void:
	var crit := CombatRules.roll_heal(self) == CombatRules.Outcome.CRIT
	heal(roundi(amount * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)), crit)


func take_damage(amount: int, source: Combatant, crit := false) -> void:
	if not is_alive() or invulnerable:
		return
	enter_combat()
	health = maxi(health - amount, 0)
	took_damage.emit(amount, source, crit)
	if health == 0:
		attack_target = null
		clear_auras()
		died.emit()


func avoid(text: String, source: Combatant) -> void:
	if is_alive() and not invulnerable:
		enter_combat()
		avoided.emit(text, source)


func heal(amount: int, crit := false) -> void:
	if not is_alive():
		return
	health = mini(health + amount, max_health)
	healed.emit(amount, crit)


func stun(duration: float) -> void:
	if not is_alive() or invulnerable:
		return
	_stun_left = maxf(_stun_left, duration)
	stunned.emit()


func _physics_process(delta: float) -> void:
	if not is_alive():
		return
	_stun_left = maxf(_stun_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)
	_combat_left = maxf(_combat_left - delta, 0.0)
	_since_mana_spent += delta
	_tick_auras(delta)

	if attack_target and not attack_target.is_alive():
		attack_target = null
	if attack_target and not is_stunned() and _swing_left == 0.0:
		if faces(attack_target) and distance_to(attack_target) <= melee_range:
			swung.emit(attack_target)
			var target := attack_target
			if _resolve_melee(target, roll_weapon_damage(), CombatRules.roll_auto_attack(self, target)):
				auto_attack_landed.emit(target)
			_swing_left = swing_interval


func _tick_auras(delta: float) -> void:
	var expired := false
	for aura in auras:
		if aura.remaining > 0.0:
			aura.remaining -= delta
			expired = expired or aura.remaining <= 0.0
	if expired:
		# A negative duration means the aura lasts until cancelled.
		auras = auras.filter(func(aura: Dictionary) -> bool: return aura.duration < 0.0 or aura.remaining > 0.0)
		auras_changed.emit()


func _engage(target: Combatant) -> void:
	enter_combat()
	target.enter_combat()


func _resolve_melee(target: Combatant, damage: float, outcome: CombatRules.Outcome) -> bool:
	_engage(target)
	match outcome:
		CombatRules.Outcome.MISS, CombatRules.Outcome.DODGE, CombatRules.Outcome.PARRY:
			target.avoid(CombatRules.OUTCOME_TEXT[outcome], self)
			return false
		CombatRules.Outcome.GLANCE:
			damage *= CombatRules.glance_multiplier(self, target)
		CombatRules.Outcome.CRIT:
			damage *= CombatRules.MELEE_CRIT_MULTIPLIER
		CombatRules.Outcome.CRUSH:
			damage *= CRUSH_MULTIPLIER
	damage = CombatRules.reduce_by_armor(damage, target, self)
	if outcome == CombatRules.Outcome.BLOCK:
		damage = maxf(damage - target.block_value, 0.0)
		if damage <= 0.0:
			target.avoid(CombatRules.OUTCOME_TEXT[outcome], self)
			return true
	target.take_damage(roundi(damage), self, outcome == CombatRules.Outcome.CRIT)
	return true
