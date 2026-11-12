class_name RangerAbilities
extends Node
## The Ranger's abilities (classic's Hunter, as CMaNGOS runs them), for the
## SpellCaster. Child of the SpellCaster, as WarriorAbilities is:
##   Auto Shot: the SpellCaster's Shoot (Combatant.start_shooting), on the
##   Ranger's own button.
##   Shots (ranged attacks, DmgClass 3): the ranged table (miss, block, crit;
##   no dodge or parry), weapon damage normalised to a 2.8-second weapon plus
##   ranged attack power for Careful Shot and Spread Shot, flat school damage
##   for Glimmer Shot, debuffs for the stings and Hobbling Shot, threat for
##   Taunting Shot, and Arrow Rain's area. The game has no ammo, so the
##   weapon alone counts (unlike classic).
##   Spirits (classic's Aspects): one at a time, on the stance bar like the
##   Templar's Presences; Cheetah and Pack Spirit are Dazed by a hit.
##   Traps: Summon Object effects set a Trap (scenes/objects/trap.gd) that
##   fires its spell on the first enemy to come near (spells.json "traps").
##   Still as Death drops every creature's threat on you, and they lose
##   interest while you lie still. Weasel Bite after a dodge, Counterattack
##   after a parry. Tracking: one at a time, read by the minimap.
## Talents that need code of their own are here too: Hawk Spirit's Quick
## Shots (Improved Hawk Spirit's chance), Improved Mend Companion's cleanse,
## Menace (the pet's next hit stuns), Beast Fury (on the pet), Drake Sting's
## poison when its sleep ends, and the shots' damage and crit modifiers
## (Barrage, Grievous Shots, Ranged Weapon Mastery).
## Spells that fit the SpellCaster's own kinds (self buffs, Frighten Beast's
## fear, Creature Lore) are left to it.

const AUTO_SHOT := 75
const ERR_NEED_RANGED := "You need a ranged weapon equipped."
const ERR_NOT_NOW := "You can't do that yet"
const ERR_ALREADY := "That is already active."
const ERR_NO_PET := "You do not have a pet."
const ERR_PET_OUT := "You already have a pet out."
const ERR_HAVE_PET := "You already have a pet. Stable it or abandon it first."
const ERR_PET_DEAD := "Your pet is dead."
const ERR_PET_ALIVE := "Your pet is alive."
const ERR_NOT_OUT := "Your pet isn't out."
const ERR_NOT_TAMEABLE := "That creature can't be tamed."
const ERR_TOO_HIGH := "That creature is too high level for you to tame."
const ERR_NOT_YET := "That isn't in the game yet."
## Revive Pet brings it back with this share of its health (its effect's
## base points plus one, in percent).
const REVIVE_SHARE := 0.15

signal beast_training_requested
## The pet came out, went away, or changed (level, health, abilities).
signal pet_changed
## Effects and auras of the Ranger's own (CMaNGOS SpellEffects, SpellAuraNames).
const EFFECT_WEAPON_DAMAGE := 58
const EFFECT_THREAT := 63
const EFFECT_ADD_FARSIGHT := 72
const EFFECT_SUMMON_OBJECT := 104
const AURA_MOD_FEIGN_DEATH := 66
const AURA_TRACK_CREATURES := 44
const AURA_MOD_RANGED_ATTACK_POWER_ATTACKER_BONUS := 127
## Damage classes (SpellDmgClass): ranged attacks.
const DMG_CLASS_MELEE := 2
const DMG_CLASS_RANGED := 3
## Normalised ranged weapon speed (Unit::CalculateDamage, normalized ranged).
const RANGED_NORMAL_SPEED := 2.8
## Spread Shot strikes its target and up to two more near it (its effect's
## chain targets in classic).
const SPREAD_TARGETS := 3
const SPREAD_RADIUS := 8.0
## Reactive attacks are usable this long after the dodge or parry.
const REACTIVE_TIME := 5.0
## Distant Gaze: how far out the camera looks from.
const FAR_SIGHT_DISTANCE := 60.0

var caster: SpellCaster
var _unit: PlayerUnit
var _combatant: Combatant
## Weasel Bite: creatures that dodged, until when.
var _dodged_by: Dictionary = {}
## Counterattack: usable until this time (after you parry).
var _counter_until := 0.0
## Arrow Rain on the ground: { "spell", "at", "left", "tick" }, while channelled.
var _rain: Dictionary = {}
## Tame Beast underway: { "target", "until" }.
var _taming: Dictionary = {}
## Drake Sting's sleepers: target -> the sting's spell, until it wears off.
var _drake_stung: Dictionary = {}
## Mend Companion: time to the next roll of Improved Mend Companion.
var _mend_roll := 0.0


func _ready() -> void:
	caster = get_parent()
	_unit = caster.get_parent()
	_combatant = _unit.get_node("Combatant")
	_combatant.attack_avoided.connect(func(target: Combatant, text: String) -> void:
		if text == "Dodge":
			_dodged_by[target] = _now() + REACTIVE_TIME
	)
	_combatant.avoided.connect(func(text: String, _source: Combatant) -> void:
		if text == "Parry":
			_counter_until = _now() + REACTIVE_TIME
	)
	# A Ranger's pet is dismissed when they die; one that was out comes back
	# with them into the world.
	_combatant.died.connect(func() -> void:
		if _unit.pet and is_instance_valid(_unit.pet):
			_unsummon(false))
	_summon_saved.call_deferred()
	# Cheetah and Pack Spirit: a hit Dazes you (their proc, Spell 15571).
	_combatant.took_damage.connect(func(amount: int, source: Combatant, _crit: bool) -> void:
		if amount > 0 and source and source != _combatant:
			_dazed_by_hit()
	)
	_combatant.proc_event.connect(_on_proc_event)
	# Tame Beast held to its end tames the beast.
	caster.channel_completed.connect(func(spell: Dictionary) -> void:
		if str(spell.get("SpellName", "")) == "Tame Beast" and not _taming.is_empty():
			var tame_target: Combatant = _taming.target
			_taming = {}
			if is_instance_valid(tame_target) and tame_target.is_alive():
				_finish_taming(tame_target))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _level() -> int:
	return _unit.profile.level


## A ranged attack (a shot or sting): it needs a ranged weapon.
static func is_shot(spell: Dictionary) -> bool:
	return int(spell.get("DmgClass", 0)) == DMG_CLASS_RANGED and int(spell.Id) != AUTO_SHOT


static func is_trap(spell: Dictionary) -> bool:
	return SpellDB.has_effect(spell, EFFECT_SUMMON_OBJECT)


static func is_tracking(spell: Dictionary) -> bool:
	return str(spell.SpellName).begins_with("Track ")


## The creature type the tracking aura shows (its misc value), or 0.
func tracked_type() -> int:
	for aura in _combatant.auras:
		for i in 3:
			if int(aura.spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == AURA_TRACK_CREATURES:
				return int(aura.spell.get("EffectMiscValue%d" % (i + 1), 0))
	return 0


## Why a Ranger ability can't be used right now, or "".
func problem(spell: Dictionary, target: Combatant) -> String:
	if is_shot(spell) and _combatant.ranged_weapon.is_empty():
		return ERR_NEED_RANGED
	# Arrow Rain falls round your enemy target (its target is a place, so
	# the SpellCaster's own target checks don't cover it).
	if is_shot(spell) and SpellDB.has_effect(spell, SpellDB.EFFECT_PERSISTENT_AREA_AURA):
		var enemy := _unit.enemy_target()
		if enemy == null or not enemy.is_alive():
			return SpellCaster.ERR_NO_TARGET
		if _combatant.distance_to(enemy) > SpellDB.spell_range(spell, _combatant):
			return SpellCaster.ERR_RANGE
	var record := pet_record()
	var out := _unit.pet != null and is_instance_valid(_unit.pet)
	match str(spell.SpellName):
		"Tame Beast":
			if not record.is_empty():
				return ERR_HAVE_PET
			var beast := target.body as Enemy if target else null
			if beast == null or not PetDB.is_tameable(beast.creature_entry):
				return ERR_NOT_TAMEABLE
			if beast.level > _level():
				return ERR_TOO_HIGH
		"Call Pet":
			if record.is_empty():
				return ERR_NO_PET
			if out:
				return ERR_PET_OUT
			if record.get("dead", false):
				return ERR_PET_DEAD
		"Dismiss Pet":
			if not out:
				return ERR_NOT_OUT
		"Revive Pet":
			if record.is_empty():
				return ERR_NO_PET
			if not record.get("dead", false) and not (out and not _unit.pet.combatant.is_alive()):
				return ERR_PET_ALIVE
		"Mend Companion":
			if not out or not _unit.pet.combatant.is_alive():
				return ERR_NOT_OUT
			if _combatant.distance_to(_unit.pet.combatant) > SpellDB.spell_range(spell, _combatant):
				return SpellCaster.ERR_RANGE
		"Beast's Eyes":
			return ERR_NOT_YET
		"Weasel Bite":
			if target == null or _dodged_by.get(target, 0.0) < _now():
				return ERR_NOT_NOW
		"Counterattack":
			if _counter_until < _now():
				return ERR_NOT_NOW
		"Menace", "Beast Fury":
			if not out or not _unit.pet.combatant.is_alive():
				return ERR_NOT_OUT
	if SpellDB.is_aspect(spell) and not _combatant.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == int(spell.Id)).is_empty():
		return ERR_ALREADY
	return ""


## Carries out a Ranger ability once its cost is paid. Returns false for
## spells it leaves to the SpellCaster.
func cast(spell: Dictionary, target: Combatant) -> bool:
	var me := _combatant
	var name: String = spell.SpellName
	if SpellDB.is_aspect(spell):
		caster._replace_own(spell, me, SpellDB.is_aspect)
		return true
	if is_tracking(spell):
		caster._replace_own(spell, me, is_tracking)
		return true
	if is_trap(spell):
		_set_trap(spell)
		return true
	match name:
		"Tame Beast":
			_taming = { "target": target, "until": _now() + SpellDB.duration(spell, me) }
			caster._start_channel(spell, target)
			if target.body is Enemy:
				(target.body as Enemy).provoke(me)
			return true
		"Call Pet":
			_summon(pet_record())
			return true
		"Dismiss Pet":
			_unsummon(true)
			return true
		"Sharpshooter's Aura":
			# Its owner's only, as the Templar's Presences are here (a party
			# aura in classic).
			caster._replace_own(spell, me, func(other: Dictionary) -> bool: return other.SpellName == spell.SpellName)
			return true
		"Menace":
			# The pet's next hit stuns its target.
			_unit.pet.combatant.add_aura(spell, me)
			return true
		"Beast Fury":
			_unit.pet.combatant.add_aura(spell, me)
			return true
		"Revive Pet":
			var record := pet_record()
			if _unit.pet and is_instance_valid(_unit.pet):
				_unit.pet.queue_free()
				_unit.pet = null
			record.dead = false
			record.health = -1
			_summon(record)
			if _unit.pet:
				# Improved Revive Companion raises the share (its effect's value).
				var share := SpellDB.effect_value(spell, 0, _level(), me) / 100.0
				_unit.pet.combatant.health = maxi(roundi(_unit.pet.combatant.max_health * maxf(share, REVIVE_SHARE)), 1)
			return true
		"Mend Companion":
			var pet_combatant: Combatant = _unit.pet.combatant
			caster._replace_own(spell, pet_combatant, func(other: Dictionary) -> bool: return other.SpellName == spell.SpellName)
			caster._start_channel(spell, pet_combatant)
			_mend_roll = _tick_period(spell)
			return true
		"Beast Training":
			beast_training_requested.emit()
			return true
		"Still as Death":
			_feign_death(spell)
			return true
		"Break Away":
			if target and target.body is Enemy:
				var enemy := target.body as Enemy
				enemy.add_threat(me, SpellDB.effect_value(spell, 0, _level(), me))
				if enemy.threat.has(me):
					enemy.threat[me] = maxf(float(enemy.threat[me]), 0.0)
			Sfx.play_at("swing", _unit.global_position)
			return true
		"Weasel Bite":
			_dodged_by.erase(target)
			_melee_strike(spell, target)
			return true
		"Counterattack":
			_counter_until = 0.0
			if _melee_strike(spell, target):
				target.add_aura(spell, me)
			return true
		"Crippling Cut":
			if _melee_strike(spell, target):
				target.add_aura(spell, me)
			return true
		"Distant Gaze":
			_far_sight(spell)
			return true
		"Flare":
			# Nothing hides from sight in the game yet: a flash, no more.
			Vfx.release(_unit, SpellDB.School.FIRE)
			return true
	if not is_shot(spell):
		return false
	if target and target != me:
		_unit.combatant.shot.emit(target)
	if SpellDB.has_effect(spell, SpellDB.EFFECT_PERSISTENT_AREA_AURA):
		var enemy := _unit.enemy_target()
		if enemy:
			_start_rain(spell, enemy)
		return true
	if SpellDB.has_effect(spell, EFFECT_THREAT):
		# Taunting Shot: a shot that only draws threat.
		if _ranged_roll(target) != CombatRules.Outcome.MISS:
			_threat_on(target, SpellDB.effect_value(spell, 0, _level(), me))
		return true
	if SpellDB.has_effect(spell, SpellDB.EFFECT_WEAPON_PERCENT_DAMAGE):
		# Scattering Shot: a share of a weapon hit, then it's disoriented.
		var share := 1.0
		for i in 3:
			if int(spell.get("Effect%d" % (i + 1), 0)) == SpellDB.EFFECT_WEAPON_PERCENT_DAMAGE:
				share = SpellDB.effect_value(spell, i, _level(), me) / 100.0
		if _weapon_shot(spell, target, 0.0, share):
			target.add_aura(spell, me)
			target.stun(SpellDB.duration(spell, me))
		return true
	if SpellDB.has_effect(spell, SpellDB.EFFECT_NORMALIZED_WEAPON_DMG) or SpellDB.has_effect(spell, EFFECT_WEAPON_DAMAGE):
		var extra := 0.0
		for i in 3:
			if int(spell.get("Effect%d" % (i + 1), 0)) in [SpellDB.EFFECT_NORMALIZED_WEAPON_DMG, EFFECT_WEAPON_DAMAGE]:
				extra += SpellDB.effect_value(spell, i, _level(), me)
		var targets: Array[Combatant] = [target]
		if name == "Spread Shot":
			targets.append_array(_enemies_near(target, SPREAD_RADIUS, SPREAD_TARGETS - 1))
		for each in targets:
			_weapon_shot(spell, each, extra)
		return true
	if SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE):
		# Glimmer Shot: the ranged table, then its school's flat damage.
		var outcome := _ranged_roll(target)
		if outcome != CombatRules.Outcome.MISS:
			var damage := SpellDB.effect_value(spell, 0, _level(), me)
			var crit := outcome == CombatRules.Outcome.CRIT
			damage = _shot_damage(spell, damage, crit)
			target.take_damage(roundi(damage), me, crit, int(spell.get("School", 0)))
			me.proc_event.emit(Combatant.PROC_DONE_RANGED, Combatant.PROC_EX_CRITICAL_HIT if crit else Combatant.PROC_EX_NORMAL, target, spell, roundi(damage))
		return true
	if SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
		# Stings, Hobbling Shot, Scattering Shot, Drake Sting: the shot must hit.
		var outcome := _ranged_roll(target)
		if outcome != CombatRules.Outcome.MISS:
			caster._replace_own(spell, target, func(other: Dictionary) -> bool: return other.SpellName == spell.SpellName, false)
			if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
				target.stun(SpellDB.duration(spell, me))
			# Drake Sting: a poison follows when the sleep ends.
			if SpellDB.linked_spell(int(spell.Id)) and str(spell.SpellName) == "Drake Sting":
				_drake_stung[target] = spell
			if target.body is Enemy:
				(target.body as Enemy).provoke(me)
			# For talents (Improved Hobbling Shot's daze).
			me.proc_event.emit(Combatant.PROC_DONE_RANGED, Combatant.PROC_EX_CRIT if outcome == CombatRules.Outcome.CRIT else Combatant.PROC_EX_NORMAL, target, spell, 0)
		return true
	return false


## The ranged table for an ability: a miss shows, the creature turns to fight.
func _ranged_roll(target: Combatant) -> CombatRules.Outcome:
	var me := _combatant
	me.enter_combat()
	var outcome := CombatRules.roll_ranged(me, target)
	if outcome == CombatRules.Outcome.MISS:
		target.avoid("Miss", me)
	if target.body is Enemy:
		(target.body as Enemy).provoke(me)
	return outcome


## Ranged attack power against a target: Quarry's Mark adds to it.
func _ranged_power(target: Combatant) -> float:
	return _combatant.ranged_attack_power + target.aura_total(AURA_MOD_RANGED_ATTACK_POWER_ATTACKER_BONUS)


## Careful Shot and Spread Shot: normalised ranged weapon damage, ranged
## attack power and the ability's bonus, through armour, on the ranged table
## (Scattering Shot: a share of it). Returns whether it landed.
func _weapon_shot(spell: Dictionary, target: Combatant, extra: float, share := 1.0) -> bool:
	var me := _combatant
	var weapon := me.ranged_weapon
	var outcome := _ranged_roll(target)
	if outcome == CombatRules.Outcome.MISS:
		return false
	var damage := (randf_range(float(weapon.min), float(weapon.max)) + _ranged_power(target) / 14.0 * RANGED_NORMAL_SPEED + extra) * share
	var crit := outcome == CombatRules.Outcome.CRIT
	damage = _shot_damage(spell, damage, crit)
	damage = CombatRules.reduce_by_armor(damage, target, me)
	if outcome == CombatRules.Outcome.BLOCK:
		target.blocked_attack.emit(me)
		damage = maxf(damage - target.block_value, 0.0)
	target.take_damage(roundi(damage), me, crit)
	me.proc_event.emit(Combatant.PROC_DONE_RANGED, Combatant.PROC_EX_CRITICAL_HIT if crit else Combatant.PROC_EX_NORMAL, target, spell, roundi(damage))
	return true


## A shot's damage after its talents: Barrage's damage (SpellMods DAMAGE),
## Grievous Shots' crit bonus, and Ranged Weapon Mastery.
func _shot_damage(spell: Dictionary, damage: float, crit: bool) -> float:
	var me := _combatant
	damage = SpellMods.apply(me, spell, SpellMods.DAMAGE, damage)
	if crit:
		damage *= 1.0 + (CombatRules.MELEE_CRIT_MULTIPLIER - 1.0) * (1.0 + SpellMods.percent(me, spell, SpellMods.CRIT_DAMAGE_BONUS) / 100.0)
	return damage * (1.0 + me.ranged_damage_percent() / 100.0)


## Hawk Spirit: Auto Shot's hits may bring Quick Shots, at the chance
## Improved Hawk Spirit gives it (its proc chance is 0 without).
func _on_proc_event(flags: int, ex: int, _other: Combatant, _spell: Dictionary, _amount: int) -> void:
	if flags & Combatant.PROC_RANGED_AUTO == 0 or ex & (Combatant.PROC_EX_NORMAL | Combatant.PROC_EX_CRIT) == 0:
		return
	var hawk := _combatant.find_aura(func(spell: Dictionary) -> bool: return str(spell.SpellName) == "Hawk Spirit")
	if hawk.is_empty():
		return
	var spell: Dictionary = hawk.spell
	for i in 3:
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_PROC_TRIGGER_SPELL:
			var chance := float(spell.get("ProcChance", 0)) + SpellMods.flat(_combatant, spell, SpellMods.CHANCE_OF_SUCCESS)
			if chance > 0.0 and randf() * 100.0 < chance:
				var quick := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
				if not quick.is_empty():
					_combatant.add_aura(quick, _combatant)
			return


## A periodic spell's tick time (its first periodic effect's amplitude).
func _tick_period(spell: Dictionary) -> float:
	for i in 3:
		var amplitude := int(spell.get("EffectAmplitude%d" % (i + 1), 0))
		if amplitude > 0:
			return amplitude / 1000.0
	return 1.0


## Improved Mend Companion: each of Mend Companion's ticks may cleanse one
## curse, disease, poison or magic effect from the pet (its trigger spell).
func _mend_tick() -> void:
	var talent := _combatant.find_aura(func(spell: Dictionary) -> bool: return str(spell.SpellName) == "Improved Mend Companion")
	if talent.is_empty() or not _unit.pet or not is_instance_valid(_unit.pet):
		return
	var chance := 0.0
	for i in 3:
		chance = maxf(chance, float(talent.amounts[i]))
	if randf() * 100.0 >= chance:
		return
	var pet_combatant: Combatant = _unit.pet.combatant
	for aura in pet_combatant.auras:
		var dispel := int(aura.spell.get("Dispel", 0))
		var from_enemy: bool = is_instance_valid(aura.caster) and aura.caster.body is Enemy
		if dispel >= 1 and dispel <= 4 and from_enemy:
			pet_combatant.remove_aura(int(aura.spell.Id))
			return


## A melee ability with flat damage of its own (Weasel Bite, Counterattack,
## Crippling Cut): the yellow melee table. Returns whether it landed.
func _melee_strike(spell: Dictionary, target: Combatant) -> bool:
	var damage := 0.0
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) == SpellDB.EFFECT_SCHOOL_DAMAGE:
			damage += SpellDB.effect_value(spell, i, _level(), _combatant)
	var landed := _combatant.strike(target, damage, true, spell)
	if target.body is Enemy:
		(target.body as Enemy).provoke(_combatant)
	return landed


func _threat_on(target: Combatant, amount: float) -> void:
	var enemy := target.body as Enemy
	if enemy:
		enemy.provoke(_combatant)
		enemy.add_threat(_combatant, amount)


## Other living enemies near a target, nearest first.
func _enemies_near(target: Combatant, radius: float, count: int) -> Array[Combatant]:
	var found: Array[Combatant] = []
	var candidates: Array = []
	for node in _unit.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant == target or not enemy.combatant.is_alive():
			continue
		var distance := enemy.global_position.distance_to(target.body.global_position)
		if distance <= radius:
			candidates.append([distance, enemy.combatant])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair in candidates.slice(0, count):
		found.append(pair[1])
	return found


## Still as Death: every creature fighting you forgets you, and goes home
## when nobody else is on its list; you lie still until you move.
func _feign_death(spell: Dictionary) -> void:
	var me := _combatant
	me.attack_target = null
	me.stop_shooting()
	me.add_aura(spell, me)
	for node in _unit.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.threat.has(me):
			enemy.forget(me)
			if enemy.threat.is_empty() and enemy.state == Enemy.State.CHASE:
				enemy._start_return()
	_unit.sitting = true


## Sets a trap at your feet: it arms, then fires its spell on the first
## enemy to come within its radius.
func _set_trap(spell: Dictionary) -> void:
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) == EFFECT_SUMMON_OBJECT:
			var info := SpellDB.trap(int(spell.get("EffectMiscValue%d" % (i + 1), 0)))
			if info.is_empty():
				return
			var trap := Trap.new()
			trap.spell = SpellDB.get_spell(int(info.spell))
			trap.radius = float(info.radius)
			trap.owner_unit = _unit
			trap.lifetime = maxf(SpellDB.duration(spell, _combatant), Trap.LIFETIME)
			_unit.get_parent().add_child(trap)
			trap.global_position = _unit.global_position
	# Every trap shares the cooldown (their spell category).
	caster.start_category_cooldown(spell)
	Sfx.play_at("buff", _unit.global_position)


## Arrow Rain: arrows fall on the target's ground, every tick hurting enemies
## there, while you channel.
func _start_rain(spell: Dictionary, target: Combatant) -> void:
	var period := 1.0
	for i in 3:
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_PERIODIC_DAMAGE:
			period = maxf(int(spell.get("EffectAmplitude%d" % (i + 1), 1000)) / 1000.0, 0.1)
	_rain = { "spell": spell, "at": target.body.global_position, "tick": period, "period": period }
	caster._start_channel(spell, _combatant)


## The pet's record: the player's in GameState; a bot's its own.
func pet_record() -> Dictionary:
	if _unit is Player:
		return GameState.pet
	return _unit.get("pet_record") if _unit.get("pet_record") is Dictionary else {}


func _set_record(record: Dictionary) -> void:
	if _unit is Player:
		GameState.pet = record
	else:
		_unit.set("pet_record", record)


## Brings the pet out beside its owner.
func _summon(record: Dictionary) -> void:
	if record.is_empty() or (_unit.pet and is_instance_valid(_unit.pet)):
		return
	record.out = true
	var pet: Pet = Pet.new()
	pet.setup(_unit, record)
	_unit.get_parent().add_child(pet)
	pet.global_position = _unit.global_position + Basis(Vector3.UP, _unit.facing) * Pet.FOLLOW_OFFSET
	_unit.pet = pet
	# A far bot's pet is far too (Bot.set_far).
	if _unit.get("_far") == true:
		pet.set_far(true)
	pet.changed.connect(func() -> void: pet_changed.emit())
	pet_changed.emit()
	Sfx.play_at("buff", _unit.global_position)


## Sends the pet away (Dismiss Pet, its owner dying); its record keeps it.
func _unsummon(by_choice: bool) -> void:
	var pet: Pet = _unit.pet
	if pet == null or not is_instance_valid(pet):
		return
	var record: Dictionary = pet.saved_record()
	record.out = false
	_set_record(record)
	_unit.pet = null
	pet.queue_free()
	pet_changed.emit()
	if by_choice:
		Sfx.play_at("buff", _unit.global_position)


## A pet that was out comes back when its owner enters the world.
func _summon_saved() -> void:
	var record := pet_record()
	if not record.is_empty() and record.get("out", false) and not record.get("dead", false) and _combatant.is_alive():
		_summon(record)


## Abandons the pet for good (the pet frame's menu).
func abandon_pet() -> void:
	if _unit.pet and is_instance_valid(_unit.pet):
		_unit.pet.queue_free()
	_unit.pet = null
	_set_record({})
	pet_changed.emit()


## Tame Beast held to its end: the beast is the Ranger's pet, at its own
## level, knowing its abilities, which the Ranger learns to teach.
func _finish_taming(target: Combatant) -> void:
	var beast := target.body as Enemy
	if beast == null or not beast.combatant.is_alive() or not pet_record().is_empty():
		return
	var record: Dictionary = PetDB.new_record(beast.creature_entry, beast.level)
	if _unit is Player:
		for id: int in record.spells:
			if not id in GameState.pet_spells:
				GameState.pet_spells.append(id)
	var at := beast.global_position
	var player := _unit as Player
	if player and player.targeting.target == beast:
		player.targeting.set_target(null)
	beast.vanish()
	_set_record(record)
	_summon(record)
	if _unit.pet:
		_unit.pet.global_position = at
	if _unit is Player:
		Chat.system("You have tamed %s." % record.name)


func _physics_process(delta: float) -> void:
	if not _taming.is_empty():
		var tame_target: Combatant = _taming.target
		# Let go early (moving, another spell, the beast dead): no pet.
		var held := caster.channeling and str(caster.casting.get("SpellName", "")) == "Tame Beast"
		if not held or not is_instance_valid(tame_target):
			_taming = {}
	# Drake Sting: once the sleep is over (worn off or broken), its poison.
	for stung: Combatant in _drake_stung.keys():
		var sting: Dictionary = _drake_stung[stung]
		if not is_instance_valid(stung) or not stung.is_alive():
			_drake_stung.erase(stung)
		elif stung.find_aura(func(spell: Dictionary) -> bool: return int(spell.Id) == int(sting.Id)).is_empty():
			_drake_stung.erase(stung)
			var poison := SpellDB.get_spell(SpellDB.linked_spell(int(sting.Id)))
			if not poison.is_empty():
				stung.add_aura(poison, _combatant)
	if caster.channeling and str(caster.casting.get("SpellName", "")) == "Mend Companion":
		_mend_roll -= delta
		if _mend_roll <= 0.0:
			_mend_roll += _tick_period(caster.casting)
			_mend_tick()
	# Lying still: moving gets you up.
	if _unit.is_moving():
		var feign := _combatant.find_aura(func(spell: Dictionary) -> bool: return SpellDB.has_effect(spell, AURA_MOD_FEIGN_DEATH, true))
		if not feign.is_empty():
			_combatant.remove_aura(int(feign.Id))
	if _rain.is_empty():
		return
	var spell: Dictionary = _rain.spell
	if not caster.channeling or int(caster.casting.get("Id", 0)) != int(spell.Id):
		_rain = {}
		return
	_rain.tick -= delta
	if _rain.tick > 0.0:
		return
	_rain.tick += _rain.period
	var radius := SpellDB.effect_radius(spell, 0, _combatant)
	var damage := 0.0
	for i in 3:
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_PERIODIC_DAMAGE:
			damage = SpellMods.apply(_combatant, spell, SpellMods.DOT, SpellDB.effect_value(spell, i, _level(), _combatant))
	for node in _unit.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.global_position.distance_to(_rain.at) <= radius:
			enemy.combatant.take_damage(roundi(damage), _combatant, false, int(spell.get("School", 0)))
			enemy.provoke(_combatant)
	Vfx.burst(_unit, _rain.at + Vector3.UP * 0.5, Vfx.school_color(int(spell.get("School", 0))), 12, 3.0, 0.1)


## Cheetah and Pack Spirit: being hit Dazes you (their proc spell), which
## slows you.
func _dazed_by_hit() -> void:
	for aura in _combatant.auras:
		var spell: Dictionary = aura.spell
		if not SpellDB.is_aspect(spell):
			continue
		for i in 3:
			if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_PROC_TRIGGER_SPELL:
				var daze := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
				if not daze.is_empty():
					_combatant.add_aura(daze, _combatant)
				return


## Distant Gaze: the camera rises far over you until you move.
func _far_sight(spell: Dictionary) -> void:
	var camera := _unit.get_viewport().get_camera_3d() as OrbitCamera
	if camera and _unit is Player:
		camera.far_sight(FAR_SIGHT_DISTANCE, SpellDB.duration(spell, _combatant))
