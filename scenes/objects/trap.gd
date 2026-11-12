class_name Trap
extends Node3D
## A Ranger's trap (classic's trap game objects, type 6): set at the Ranger's
## feet, it arms after ARM_TIME, then fires its spell (spells.json "traps": a
## Burning Trap's fire, a Frostbind Trap's freeze, a Rime Trap's slowing
## ground, a Blast Trap's blast) on the first living enemy within its radius,
## and is used up. Unsprung, it's gone after its lifetime. Its spell is cast
## by the Ranger: damage and threat are theirs.

## Seconds before it can be sprung (classic's trap arming time).
const ARM_TIME := 2.0
## How long an unsprung trap lasts, at least (classic: one minute).
const LIFETIME := 60.0
## Area effects (a Rime Trap's ice, a Blast Trap's burning ground) last their
## spell's duration and hit everything inside each tick.
const AREA_TICK := 1.0

var spell: Dictionary = {}
var radius := 5.0
var owner_unit: PlayerUnit
var lifetime := LIFETIME
var _age := 0.0
## Once sprung, an area effect's ground: seconds left and to the next tick.
var _area_left := 0.0
var _area_tick := 0.0
var _model: Node3D


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_model = Node3D.new()
	add_child(_model)
	var color := Vfx.school_color(int(spell.get("School", 0)))
	Props.cylinder(_model, Vector3.ZERO, 0.45, 0.08, Color(0.3, 0.28, 0.25), false)
	for i in 6:
		var angle := TAU * i / 6.0
		var tooth := Props.box(_model, Vector3(cos(angle) * 0.4, 0.05, sin(angle) * 0.4), Vector3(0.06, 0.18, 0.06), color, 0.0, false)
		tooth.rotation.z = 0.3


func _physics_process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(owner_unit):
		queue_free()
		return
	if _area_left > 0.0:
		_tick_area(delta)
		return
	if _age >= lifetime:
		queue_free()
		return
	if _age < ARM_TIME:
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.global_position.distance_to(global_position) <= radius:
			_spring(enemy)
			return


## The first enemy steps on it: its spell goes off.
func _spring(enemy: Enemy) -> void:
	var caster: Combatant = owner_unit.combatant
	var level := owner_unit.profile.level
	Sfx.play_at("bolt_hit", global_position)
	Vfx.burst(self, global_position + Vector3.UP * 0.3, Vfx.school_color(int(spell.get("School", 0))), 14, 4.0, 0.12)
	enemy.provoke(caster)
	if SpellDB.has_effect(spell, SpellDB.EFFECT_PERSISTENT_AREA_AURA):
		# Rime Trap's ice and Blast Trap's flames: the ground around it, a
		# while; the Blast Trap's blast hits at once too.
		for i in 3:
			if int(spell.get("Effect%d" % (i + 1), 0)) == SpellDB.EFFECT_SCHOOL_DAMAGE:
				_hit_area(func(target: Combatant) -> void:
					target.take_damage(roundi(SpellDB.effect_value(spell, i, level, caster)), caster, false, int(spell.get("School", 0))))
		_area_left = maxf(SpellDB.duration(spell, caster), AREA_TICK)
		_area_tick = 0.0
		_model.visible = false
		_hit_area(_entrap)
		return
	# Burning Trap's fire and Frostbind Trap's freeze: on the enemy itself.
	enemy.combatant.add_aura(spell, caster)
	if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
		enemy.combatant.stun(SpellDB.duration(spell, caster))
	_entrap(enemy.combatant)
	queue_free()


## Ensnaring Traps: a chance (its ProcChance) that what the trap hits is
## rooted (its trigger spell). Frostbind Trap's freeze needs no root.
func _entrap(target: Combatant) -> void:
	var caster: Combatant = owner_unit.combatant
	if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true) or not target.is_alive():
		return
	var talent := caster.find_aura(func(other: Dictionary) -> bool: return str(other.SpellName) == "Ensnaring Traps")
	if talent.is_empty() or randf() * 100.0 >= float(talent.spell.get("ProcChance", 0)):
		return
	var root := SpellDB.get_spell(int(talent.spell.get("EffectTriggerSpell1", 0)))
	if not root.is_empty():
		target.add_aura(root, caster)


func _tick_area(delta: float) -> void:
	_area_left -= delta
	_area_tick -= delta
	if _area_left <= 0.0:
		queue_free()
		return
	if _area_tick > 0.0:
		return
	_area_tick = AREA_TICK
	var caster: Combatant = owner_unit.combatant
	var level := owner_unit.profile.level
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) != SpellDB.EFFECT_PERSISTENT_AREA_AURA:
			continue
		match int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)):
			SpellDB.AURA_PERIODIC_DAMAGE:
				var amount := roundi(SpellDB.effect_value(spell, i, level, caster))
				_hit_area(func(target: Combatant) -> void: target.take_damage(amount, caster, false, int(spell.get("School", 0))))
			SpellDB.AURA_MOD_DECREASE_SPEED:
				_hit_area(func(target: Combatant) -> void:
					if target.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == int(spell.Id)).is_empty():
						target.add_aura(spell, caster))
	Vfx.burst(self, global_position + Vector3.UP * 0.2, Vfx.school_color(int(spell.get("School", 0))), 6, 2.0, 0.1)


func _hit_area(action: Callable) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.global_position.distance_to(global_position) <= radius:
			action.call(enemy.combatant)
