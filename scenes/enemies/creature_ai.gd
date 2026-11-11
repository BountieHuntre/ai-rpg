class_name CreatureAI
extends Node
## A creature's classic spellcasting, from its EventAI script
## (creature_ai_scripts in CMaNGOS, exported as the creature's "Events"):
## timed casts in and out of combat, casts on aggro and spawn, casts when
## the target is in range or turned away, and buffs kept up. Casts follow the
## classic rules: cast times, mana, cooldowns, pushback when hit, and
## interrupts (stuns, fear, silence, and Hilt Strike's school lockout).
## Casters in ranged mode (ACTION_T_SET_RANGED_MODE, TYPE_PROXIMITY for
## every caster here) stand off and cast their
## main spell, closing to melee when they can't: out of mana, silenced, or
## locked out (UnitAI::UpdateAI and SetCurrentRangedMode in CMaNGOS).
## Must be a child of an Enemy.

## EventAI event types (CreatureEventAI.h).
const EVENT_TIMER_IN_COMBAT := 0
const EVENT_TIMER_OOC := 1
## Health between two percentages (params: max %, min %, repeat min/max).
const EVENT_HP := 2
const EVENT_AGGRO := 4
const EVENT_RANGE := 9
const EVENT_SPAWNED := 11
const EVENT_FRIENDLY_MISSING_BUFF := 27
const EVENT_FACING_TARGET := 33
## Action types: cast a spell, set ranged mode.
const ACTION_TEXT := 1
const ACTION_CAST := 11
const ACTION_FLEE_FOR_ASSIST := 25
const ACTION_CALL_FOR_HELP := 39
const ACTION_CHANCED_TEXT := 44
const ACTION_TEXT_NEW := 54
const ACTION_SET_RANGED_MODE := 57
## How long a creature flees (CreatureFamilyFleeDelay in CMaNGOS).
const FLEE_TIME := 10.0
## What creatures say when the data has them speak (classic's lines aren't
## used): by the start of their name.
const SAYINGS := {
	"Burrowling": ["No take the candles!", "Ours! This dig is ours!", "You go away from tunnel!", "Candle stays with us!"],
	"Brigand": ["Your purse or your life!", "Wrong road, traveller.", "Should've kept walking.", "Fresh pickings!"],
	"Masked Brigand": ["Your purse or your life!", "Wrong road, traveller.", "Should've kept walking.", "Fresh pickings!"],
	"Brasstooth": ["Shiny is mine! You no take!", "Brasstooth keeps it! All of it!", "Go 'way from my dig!"],
	"Ditchjaw": ["Grah! Meat walks into camp!", "Ditchjaw land! You leave bones here!", "Hrrk! More for the pot!"],
	"Grunmaw": ["Grunmaw smell you! Grunmaw eat you!", "Who sent little meat to Grunmaw?", "Bones! Bones for the pile!"],
}
## Event flags.
const EFLAG_REPEATABLE := 0x01
## The event's first action must succeed, or it tries again next update.
const EFLAG_COMBAT_ACTION := 0x400
## Cast targets and flags (TARGET_T_*, CastFlags in UnitAI.h).
const TARGET_SELF := 0
const CAST_INTERRUPT_PREVIOUS := 0x01
const CAST_TRIGGERED := 0x02
const CAST_FORCE_TARGET_SELF := 0x10
const CAST_AURA_NOT_PRESENT := 0x20
const CAST_MAIN_SPELL := 0x100
## Ranged mode resumes once the target is this far beyond melee range
## (CanReachWithMeleeAttack(victim, 3.f)).
const RANGED_RESUME_MARGIN := 3.0
## Spell InterruptFlags: hits push the cast back; interrupt effects cut it.
const INTERRUPT_FLAG_PUSHBACK := 0x02
const INTERRUPT_FLAG_INTERRUPT := 0x08
## PreventionType: silence stops magic, pacify stops physical abilities.
const PREVENTION_SILENCE := 1
const PREVENTION_PACIFY := 2
## ProcFlags: taken a melee hit, or a melee ability's hit (Rime Shroud).
const PROC_TAKEN_MELEE := 0x08 | 0x20
## ProcFlags: its own melee swing or melee ability (Poison Proc, Thrash).
const PROC_DONE_MELEE := 0x04 | 0x10
const EFFECT_ADD_EXTRA_ATTACKS := 19
## Spell Attributes: damage scales with the creature's level.
const ATTR_SCALES_WITH_CREATURE_LEVEL := 0x80000
const DMG_CLASS_MELEE := 2
const CLASS_DAMAGE_PATH := "res://data/classic/creature_class_damage.json"
## Creatures have a full 100 energy that refills 20 every 2 s, for abilities
## that cost energy (Back Thrust); costs in other powers but mana are free.
const POWER_ENERGY := 3
const MAX_ENERGY := 100.0
const ENERGY_REGEN := 10.0
## Effects whose amounts scale with a creature's level (Object.cpp).
const SCALED_EFFECTS := [
	SpellDB.EFFECT_SCHOOL_DAMAGE, SpellDB.EFFECT_HEAL, SpellDB.EFFECT_WEAPON_DAMAGE_NOSCHOOL,
	SpellDB.EFFECT_NORMALIZED_WEAPON_DMG, SpellDB.EFFECT_POWER_BURN,
]
const SCALED_AURAS := [SpellDB.AURA_PERIODIC_DAMAGE, SpellDB.AURA_PERIODIC_LEECH, SpellDB.AURA_SCHOOL_ABSORB]
const WEAPON_EFFECTS := [SpellDB.EFFECT_WEAPON_DAMAGE_NOSCHOOL, SpellDB.EFFECT_NORMALIZED_WEAPON_DMG]

## Why a cast failed, as CanCastResult: running low on mana, being prevented
## (silence, lockout, cooldown) and being too close end ranged mode.
enum Fail { NONE, CASTING, POWER, PREVENTED, RANGE, TOO_CLOSE, SIGHT, TARGET, CHANCE }

static var _class_damage: Dictionary

## The spell being cast, or {} when not casting.
var casting: Dictionary = {}
## Ranged mode is on (set by the script), and the creature is standing off
## right now rather than meleeing.
var ranged := false
var ranged_now := false
var chase_distance := 0.0

var _enemy: Enemy
var _me: Combatant
var _unit_class := 1
var _events: Array[Dictionary] = []
var _cast_left := 0.0
var _cast_total := 0.0
var _cast_target: Combatant
var _pushbacks := 0
## Spell id -> seconds of cooldown left; school -> seconds locked out.
var _cooldowns: Dictionary = {}
var _locked: Dictionary = {}
var _main_spells: Array[Dictionary] = []
## Spells in flight: { "spell", "target", "amount", "left" }.
var _missiles: Array[Dictionary] = []
var _in_combat := false
var _energy := MAX_ENERGY


func setup(enemy: Enemy, data: Dictionary) -> void:
	_enemy = enemy
	_me = enemy.combatant
	_unit_class = int(data.get("UnitClass", 1))
	for event: Dictionary in data.get("Events", []):
		_events.append({ "data": event, "timer": 0.0, "done": false })
		for action: Array in event.actions:
			if int(action[0]) == ACTION_CAST and int(action[3]) & CAST_MAIN_SPELL:
				_main_spells.append(SpellDB.get_spell(int(action[1])))
	_me.stunned.connect(func() -> void: interrupt())
	_me.auras_changed.connect(_on_auras_changed)
	_me.interrupt_requested.connect(_on_interrupt_requested)
	_me.took_damage.connect(func(amount: int, _source: Combatant, _crit: bool) -> void:
		if amount > 0:
			_push_back()
	)
	_me.melee_hit_taken.connect(_on_melee_hit_taken)
	_me.proc_event.connect(_on_proc_event)


## The creature appeared (spawned or respawned): fresh timers and spawn events.
func on_spawn() -> void:
	_reset()
	_run_events(EVENT_SPAWNED)


## It started fighting: combat timers start and aggro events run.
func on_aggro() -> void:
	if _in_combat:
		return
	_in_combat = true
	for event in _events:
		var data: Dictionary = event.data
		event.done = false
		match int(data.type):
			EVENT_TIMER_IN_COMBAT:
				event.timer = randf_range(data.params[0], maxf(data.params[0], data.params[1])) / 1000.0
			EVENT_RANGE, EVENT_FACING_TARGET:
				event.timer = 0.0
	_run_events(EVENT_AGGRO)


## It evaded home or died: casts stop and combat state is forgotten.
func on_leave_combat() -> void:
	_reset()


func _reset() -> void:
	_stop_cast()
	_missiles.clear()
	_energy = MAX_ENERGY
	_cooldowns.clear()
	_locked.clear()
	ranged = false
	ranged_now = false
	_in_combat = false
	for event in _events:
		event.done = false
		var data: Dictionary = event.data
		event.timer = randf_range(data.params[0], maxf(data.params[0], data.params[1])) / 1000.0 if int(data.type) == EVENT_TIMER_OOC else 0.0


func cast_fraction() -> float:
	return 0.0 if _cast_total <= 0.0 else 1.0 - _cast_left / _cast_total


## Whether the creature should hold its ground rather than close in on its
## victim: while casting, and in ranged mode within chase distance and sight.
func holds_ground(victim: Combatant) -> bool:
	if _enemy.panic_left > 0.0:
		return false
	if not casting.is_empty():
		return true
	return ranged_now and _me.distance_to(victim) <= chase_distance and _in_sight(victim)


func _physics_process(delta: float) -> void:
	if _enemy.state == Enemy.State.DEAD:
		return
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	for school: int in _locked.keys():
		_locked[school] -= delta
		if _locked[school] <= 0.0:
			_locked.erase(school)
	_fly_missiles(delta)
	_energy = minf(_energy + ENERGY_REGEN * delta, MAX_ENERGY)
	if not casting.is_empty():
		_cast_left -= delta
		if _cast_left <= 0.0:
			var spell := casting
			var target := _cast_target
			_stop_cast()
			_finish(spell, target)
	var fighting := _enemy.state == Enemy.State.CHASE
	if fighting and not _in_combat:
		on_aggro()
	var victim := _enemy.current_victim()
	if fighting and victim:
		_update_ranged_mode(victim)
	for event in _events:
		if event.done:
			continue
		var data: Dictionary = event.data
		var kind := int(data.type)
		var active := false
		match kind:
			EVENT_TIMER_IN_COMBAT, EVENT_RANGE, EVENT_FACING_TARGET, EVENT_HP:
				active = fighting and victim != null
			EVENT_TIMER_OOC:
				active = _enemy.state == Enemy.State.IDLE
			EVENT_FRIENDLY_MISSING_BUFF:
				active = true
		if not active:
			continue
		# Timers run on while it casts; a cast then waits for the current one.
		event.timer -= delta
		if event.timer > 0.0 or not casting.is_empty() or not _condition_met(data, victim):
			continue
		var result := _fire(event)
		if result != Fail.NONE and result != Fail.CHANCE and int(data.flags) & EFLAG_COMBAT_ACTION:
			continue
		if int(data.flags) & EFLAG_REPEATABLE:
			event.timer = randf_range(data.params[2], maxf(data.params[2], data.params[3])) / 1000.0
		else:
			event.done = true


## Conditions of the events that wait on something besides a timer.
func _condition_met(data: Dictionary, victim: Combatant) -> bool:
	var params: Array = data.params
	match int(data.type):
		EVENT_RANGE:
			var distance := _me.distance_to(victim)
			return distance >= float(params[0]) and distance <= float(params[1])
		EVENT_HP:
			var percent := 100.0 * _me.health / maxf(_me.max_health, 1.0)
			return percent <= float(params[0]) and percent >= float(params[1])
		EVENT_FACING_TARGET:
			# 0: behind its target (the target faces away), 1: in front of it.
			var in_front := victim.faces(_me)
			return in_front if int(params[0]) == 1 else not in_front
		EVENT_FRIENDLY_MISSING_BUFF:
			var buff := int(params[0])
			for friend in _friends_near(float(params[1])):
				if friend.find_aura(func(spell: Dictionary) -> bool: return int(spell.Id) == buff).is_empty():
					return true
			return false
	return true


## The other creatures (and itself) within a radius.
func _friends_near(radius: float) -> Array[Combatant]:
	var friends: Array[Combatant] = [_me]
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other != _enemy and other.state != Enemy.State.DEAD and _me.distance_to(other.combatant) <= radius:
			friends.append(other.combatant)
	return friends


## Runs every event of a kind that has no timer (aggro, spawn).
func _run_events(kind: int) -> void:
	for event in _events:
		if int(event.data.type) == kind and not event.done:
			_fire(event)
			if not int(event.data.flags) & EFLAG_REPEATABLE:
				event.done = true


## Rolls the event's chance and runs its actions. Returns the first action's
## result.
func _fire(event: Dictionary) -> Fail:
	var data: Dictionary = event.data
	if randi() % 100 >= int(data.chance):
		return Fail.CHANCE
	var first := Fail.NONE
	var index := 0
	for action: Array in data.actions:
		var result := Fail.NONE
		match int(action[0]):
			ACTION_CAST:
				result = _try_cast(int(action[1]), int(action[2]), int(action[3]))
			ACTION_SET_RANGED_MODE:
				ranged = true
				chase_distance = float(action[2])
				ranged_now = true
			ACTION_TEXT, ACTION_TEXT_NEW:
				_say()
			ACTION_CHANCED_TEXT:
				if randi() % 100 < int(action[1]):
					_say()
			ACTION_FLEE_FOR_ASSIST:
				result = Fail.NONE if _enemy.flee(FLEE_TIME) else Fail.PREVENTED
			ACTION_CALL_FOR_HELP:
				_enemy.call_for_help(float(action[1]))
		if index == 0:
			first = result
		index += 1
	return first


## A line of the creature's own, said aloud (classic's text ids pick lines
## the game doesn't use).
func _say() -> void:
	var name := _me.display_name
	for prefix: String in SAYINGS:
		if name.begins_with(prefix) or name.contains(prefix):
			var lines: Array = SAYINGS[prefix]
			Chat.monster(name, lines[randi() % lines.size()], _enemy.global_position)
			return


## Proximity ranged mode: melee when the victim reaches it, back to casting
## when it steps away and the main spell can be cast.
func _update_ranged_mode(victim: Combatant) -> void:
	if not ranged or not casting.is_empty():
		return
	var distance := _me.distance_to(victim)
	if ranged_now and distance <= _me.melee_range:
		ranged_now = false
	elif not ranged_now and distance > _me.melee_range + RANGED_RESUME_MARGIN and _eligible_for_range() and not _main_prevented():
		ranged_now = true


## Enough mana for two main spells (UnitAI::IsEligibleForDistancing).
func _eligible_for_range() -> bool:
	if _main_spells.is_empty():
		return false
	return _me.max_mana <= 0 or _me.mana > mana_cost(_main_spells[0]) * 2


func _main_prevented() -> bool:
	for spell in _main_spells:
		if not _prevented(spell):
			return false
	return true


## Cooldown, school lockout, silence or pacify keeps the spell from being cast.
func _prevented(spell: Dictionary) -> bool:
	if _cooldowns.has(int(spell.Id)) or _locked.has(int(spell.get("School", 0))):
		return true
	match int(spell.get("PreventionType", 0)):
		PREVENTION_SILENCE:
			return _me.has_aura_type(SpellDB.AURA_MOD_SILENCE)
		PREVENTION_PACIFY:
			return _me.is_pacified()
	return false


## Starts casting a spell from an event, or says why it can't.
func _try_cast(id: int, target_kind: int, flags: int) -> Fail:
	var spell := SpellDB.get_spell(id)
	if spell.is_empty():
		return Fail.TARGET
	var victim := _enemy.current_victim()
	var target := _me if target_kind == TARGET_SELF or flags & CAST_FORCE_TARGET_SELF else victim
	if target == null or not target.is_alive():
		return Fail.TARGET
	if flags & CAST_AURA_NOT_PRESENT and not target.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == id).is_empty():
		return Fail.TARGET
	if not casting.is_empty():
		if flags & CAST_INTERRUPT_PREVIOUS:
			_stop_cast()
		else:
			return Fail.CASTING
	var result := _problem(spell, target, flags)
	if result != Fail.NONE:
		if spell in _main_spells and result in [Fail.POWER, Fail.PREVENTED, Fail.TOO_CLOSE]:
			ranged_now = false
		return result
	var time := 0.0 if flags & CAST_TRIGGERED else SpellDB.cast_time(spell)
	if target != _me:
		_enemy.face_toward(target.body.global_position)
	if time > 0.0:
		Sfx.play_at("cast", _enemy.global_position)
		casting = spell
		_cast_target = target
		_cast_left = time
		_cast_total = time
		_pushbacks = 0
		_me.is_casting = true
	else:
		_finish(spell, target)
	return Fail.NONE


func _problem(spell: Dictionary, target: Combatant, flags := 0) -> Fail:
	if _me.is_stunned() or _me.is_feared() or _enemy.panic_left > 0.0:
		return Fail.PREVENTED
	if _prevented(spell):
		return Fail.PREVENTED
	if not flags & CAST_TRIGGERED and _power(spell) < mana_cost(spell) and _pays_power(spell):
		return Fail.POWER
	if target != _me:
		var distance := _me.distance_to(target)
		var reach := SpellDB.spell_range(spell)
		# Melee abilities reach as far as a swing.
		if reach <= 5.0:
			reach = maxf(reach, _me.melee_range)
		if distance > reach:
			return Fail.RANGE
		if distance < SpellDB.min_range(spell):
			return Fail.TOO_CLOSE
		if not _in_sight(target):
			return Fail.SIGHT
	return Fail.NONE


## The mana a creature pays, lower when the spell is above its level
## (Spell::CalculatePowerCost: cost / (1.117 * spell level / level - 0.1327)).
func mana_cost(spell: Dictionary) -> int:
	var cost := SpellDB.mana_cost(spell, _me.max_mana)
	var spell_level := int(spell.get("SpellLevel", 0))
	if int(spell.get("Attributes", 0)) & ATTR_SCALES_WITH_CREATURE_LEVEL and spell_level > 0:
		var divisor := 1.117 * spell_level / maxi(_me.level, 1) - 0.1327
		if divisor > 0.0:
			cost = int(cost / divisor)
	return cost


## Mana for mana spells, energy for energy abilities.
func _power(spell: Dictionary) -> float:
	return _energy if int(spell.get("PowerType", 0)) == POWER_ENERGY else _me.mana


func _pays_power(spell: Dictionary) -> bool:
	return int(spell.get("PowerType", 0)) in [SpellDB.POWER_MANA, POWER_ENERGY]


func _in_sight(target: Combatant) -> bool:
	var eye := Vector3.UP * SpellCaster.EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		_enemy.global_position + eye, target.body.global_position + eye, SpellCaster.WORLD_LAYER
	)
	return _enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The cast completes: pay for it and apply its effects.
func _finish(spell: Dictionary, target: Combatant) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive() or not _me.is_alive():
		return
	if target != _me and _problem(spell, target, CAST_TRIGGERED) in [Fail.RANGE, Fail.SIGHT]:
		return
	if _pays_power(spell):
		if int(spell.get("PowerType", 0)) == POWER_ENERGY:
			_energy -= mana_cost(spell)
		else:
			_me.spend_mana(mana_cost(spell))
	var cooldown := SpellDB.cooldown(spell)
	if cooldown > 0.0:
		_cooldowns[int(spell.Id)] = cooldown
	if target == _me or not target.is_player:
		_apply_helpful(spell, target)
		return
	_me.enter_combat()
	var weapon := false
	var flat := 0.0
	var percent := 100.0
	var damage := 0.0
	for i in 3:
		match int(spell.get("Effect%d" % (i + 1), 0)):
			SpellDB.EFFECT_SCHOOL_DAMAGE:
				damage += scaled_value(spell, i)
			SpellDB.EFFECT_WEAPON_DAMAGE_NOSCHOOL, SpellDB.EFFECT_NORMALIZED_WEAPON_DMG:
				weapon = true
				flat += scaled_value(spell, i)
			SpellDB.EFFECT_WEAPON_PERCENT_DAMAGE:
				weapon = true
				percent = SpellDB.effect_value(spell, i, _me.level)
	if weapon:
		# Weapon strikes (Back Thrust): the swing plus flat damage, then the percentage.
		if _me.strike(target, (_me.roll_weapon_damage() + flat) * percent / 100.0):
			_apply_harmful_auras(spell, target)
	elif damage > 0.0:
		# Bolts fly at the spell's speed in yards per second.
		var speed := float(spell.get("Speed", 0))
		var flight := _me.distance_to(target) / speed if speed > 0.0 else 0.0
		if flight > 0.0:
			Vfx.bolt(_me.body, target.body, int(spell.get("School", 0)), flight)
		_missiles.append({ "spell": spell, "target": target, "amount": damage, "left": flight })
		_fly_missiles(0.0)
	elif int(spell.get("DmgClass", 0)) == DMG_CLASS_MELEE:
		# Melee abilities that only leave an aura (Prying Strike) can miss,
		# be dodged and parried.
		var outcome := CombatRules.roll_melee_ability(_me, target)
		if outcome in [CombatRules.Outcome.MISS, CombatRules.Outcome.DODGE, CombatRules.Outcome.PARRY]:
			target.avoid(CombatRules.OUTCOME_TEXT[outcome], _me)
		else:
			_apply_harmful_auras(spell, target)
	elif CombatRules.roll_spell(_me, target) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", _me)
	else:
		_apply_harmful_auras(spell, target)


func _fly_missiles(delta: float) -> void:
	for missile in _missiles.duplicate():
		missile.left -= delta
		if missile.left > 0.0:
			continue
		_missiles.erase(missile)
		var target: Combatant = missile.target
		if not is_instance_valid(target) or not target.is_alive():
			continue
		var spell: Dictionary = missile.spell
		Sfx.play_at("bolt_hit", target.body.global_position)
		if _me.hit_with_spell(target, missile.amount, int(spell.get("School", 0))):
			_apply_harmful_auras(spell, target)


## A spell's auras on an enemy: stuns hold it.
func _apply_harmful_auras(spell: Dictionary, target: Combatant) -> void:
	if not target.is_alive() or not SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
		return
	target.add_aura(spell, _me)
	if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
		target.stun(SpellDB.duration(spell))


## Buffs on itself or another creature (Rime Shroud, Headlong Charge).
func _apply_helpful(spell: Dictionary, target: Combatant) -> void:
	if SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
		target.add_aura(spell, _me)
		Sfx.play_at("buff", _enemy.global_position)
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) == SpellDB.EFFECT_HEAL:
			target.heal(roundi(scaled_value(spell, i)), false, _me)


## An effect's amount at the creature's level. Damage and healing of spells
## that scale with creature level go by the creature class's base damage at
## its level over that at the spell's level (WorldObject::CalculateSpellEffectValue).
func scaled_value(spell: Dictionary, effect: int) -> float:
	var value := SpellDB.effect_value(spell, effect, _me.level)
	var spell_level := int(spell.get("SpellLevel", 0))
	if not int(spell.get("Attributes", 0)) & ATTR_SCALES_WITH_CREATURE_LEVEL or spell_level <= 0:
		return value
	var aura := int(spell.get("EffectApplyAuraName%d" % (effect + 1), 0))
	var kind := int(spell.get("Effect%d" % (effect + 1), 0))
	if not (aura in SCALED_AURAS if aura != 0 else kind in SCALED_EFFECTS):
		return value
	var at_level := class_damage(_unit_class, _me.level)
	var at_spell := class_damage(_unit_class, spell_level)
	return value * at_level / at_spell if at_level > 0.0 and at_spell > 0.0 else value


## creature_template_classlevelstats BaseDamageExp0 for a class and level.
static func class_damage(unit_class: int, level: int) -> float:
	if _class_damage.is_empty():
		_class_damage = JSON.parse_string(FileAccess.get_file_as_string(CLASS_DAMAGE_PATH))
	var table: Array = _class_damage.get(str(unit_class), _class_damage.get("1", []))
	return float(table[clampi(level, 1, table.size()) - 1]) if not table.is_empty() else 0.0


## Spell::Delayed: hits set the cast back 1.0 s, then 0.8, 0.6, 0.4 and 0.2.
func _push_back() -> void:
	if casting.is_empty() or int(casting.get("InterruptFlags", 0)) & INTERRUPT_FLAG_PUSHBACK == 0:
		return
	var delay := 1.0 - 0.2 * _pushbacks if _pushbacks < 5 else 0.2
	_pushbacks += 1
	_cast_left = minf(_cast_left + delay, _cast_total)


## Fear and silence cut a cast short when they land.
func _on_auras_changed() -> void:
	if casting.is_empty():
		return
	var silenced := _me.has_aura_type(SpellDB.AURA_MOD_SILENCE) and int(casting.get("PreventionType", 0)) == PREVENTION_SILENCE
	if _me.is_feared() or silenced:
		interrupt()


## Hilt Strike and Shield Smash: the cast stops and its school is locked
## (Spell::EffectInterruptCast), for spells that can be interrupted.
func _on_interrupt_requested(lockout: float) -> void:
	if casting.is_empty() or int(casting.get("InterruptFlags", 0)) & INTERRUPT_FLAG_INTERRUPT == 0:
		return
	if lockout > 0.0:
		_locked[int(casting.get("School", 0))] = lockout
	interrupt()


## Stops the cast. A caster whose main spell is now kept from it runs in to
## melee (UnitAI::OnSpellInterrupt).
func interrupt() -> void:
	if casting.is_empty():
		return
	var spell := casting
	_stop_cast()
	_me.cast_interrupted.emit()
	if ranged and spell in _main_spells and _main_prevented():
		ranged_now = false


func _stop_cast() -> void:
	casting = {}
	_cast_target = null
	_cast_left = 0.0
	_cast_total = 0.0
	if _me:
		_me.is_casting = false


## Auras that fire when its own melee lands (ProcFlags done melee): the
## spiders' Poison Proc poisons the victim, the Ditchjaw Outrider's Thrash
## gives it extra swings.
func _on_proc_event(flags: int, ex: int, other: Combatant, _spell: Dictionary, _amount: int) -> void:
	if flags & PROC_DONE_MELEE == 0 or ex & (Combatant.PROC_EX_NORMAL | Combatant.PROC_EX_CRIT) == 0:
		return
	for aura in _me.auras.duplicate():
		var spell: Dictionary = aura.spell
		if int(spell.get("ProcFlags", 0)) & flags == 0 or randf() * 100.0 >= float(spell.get("ProcChance", 100)):
			continue
		for i in 3:
			if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) != SpellDB.AURA_PROC_TRIGGER_SPELL:
				continue
			var triggered := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
			if triggered.is_empty():
				continue
			if int(triggered.get("Effect1", 0)) == EFFECT_ADD_EXTRA_ATTACKS:
				_me.extra_attacks += maxi(roundi(SpellDB.effect_value(triggered, 0, _enemy.level)), 1)
			elif other and other.is_alive():
				other.add_aura(triggered, _me)


## Auras that strike back at melee attackers (Rime Shroud chills them).
func _on_melee_hit_taken(attacker: Combatant) -> void:
	for aura in _me.auras.duplicate():
		var spell: Dictionary = aura.spell
		if int(spell.get("ProcFlags", 0)) & PROC_TAKEN_MELEE == 0:
			continue
		for i in 3:
			if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) != SpellDB.AURA_PROC_TRIGGER_SPELL:
				continue
			var triggered := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
			if not triggered.is_empty() and attacker.is_alive() and randf() * 100.0 < float(spell.get("ProcChance", 100)):
				attacker.add_aura(triggered, _me)
