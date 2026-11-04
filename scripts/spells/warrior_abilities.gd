class_name WarriorAbilities
extends Node
## The Man-at-Arms' (classic Warrior's) abilities, for the SpellCaster: stances,
## stance and situation checks, abilities on the next swing, rushing in, and
## each ability's effect. Formulas follow CMaNGOS classic (Spell::EffectWeapon
## DmgNoSchool, EffectNormalizedWeaponDamage, EffectCharge, EffectTaunt, the
## Execute and Bloodrage scripts). Child of the SpellCaster.

const ERR_NO_RAGE := "Not enough rage"
const ERR_STANCE := "Must be in %s"
const ERR_TOO_CLOSE := "Target too close"
const ERR_SHIELD := "Must have a Shield equipped"
const ERR_NOT_NOW := "You can't do that yet"
## Stance (shapeshift form) names, by form.
const STANCES := { 17: "Vanguard Stance", 18: "Bastion Stance", 19: "Fury Stance" }
const STANCE_MASK := (1 << 16) | (1 << 17) | (1 << 18)
## Seconds Riposte Strike stays usable after the target dodges, and Retort
## after you dodge, parry or block (classic's aura states).
const REACTIVE_TIME := 5.0
## Rush and Cut Off: yards per second.
const RUSH_SPEED := 25.0
## Abilities that need a shield.
const SHIELD_ABILITIES := ["Shield Brace", "Shield Smash", "Shield Crush", "Wall of Steel"]
## Most enemies an area attack strikes (Cyclone Strike, Ground Slam; classic's
## MaxAffectedTargets), and Cowing Roar frightens.
const MAX_AREA_TARGETS := 4
const MAX_FEAR_TARGETS := 5
## Final Stand raises maximum health by this share for its duration.
const FINAL_STAND_SHARE := 0.3
## Normalized weapon speeds: one-handers, two-handers, daggers.
const NORMAL_SPEED := 2.4
const NORMAL_SPEED_TWO_HAND := 3.3
const NORMAL_SPEED_DAGGER := 1.7
const WEAPON_SUBCLASS_DAGGER := 15

var caster: SpellCaster
## The spell waiting for the next swing (Mighty Blow, Sweeping Cut), or {}.
var queued: Dictionary = {}
var _unit: PlayerUnit
var _combatant: Combatant
## Time (s) until which Riposte Strike may hit each target that dodged.
var _dodged_by: Dictionary = {}
var _retort_until := 0.0
## A rush under way: { spell, target }, or {}.
var _rush: Dictionary = {}


func _ready() -> void:
	caster = get_parent()
	_unit = caster.get_parent()
	_combatant = _unit.get_node("Combatant")
	_combatant.swing_replacer = _on_swing
	_combatant.attack_avoided.connect(func(target: Combatant, text: String) -> void:
		if text == "Dodge":
			_dodged_by[target] = _now() + REACTIVE_TIME
	)
	_combatant.avoided.connect(func(text: String, _source: Combatant) -> void:
		if text in ["Dodge", "Parry", "Block"]:
			_retort_until = _now() + REACTIVE_TIME
	)
	_combatant.blocked_attack.connect(func(_attacker: Combatant) -> void: _retort_until = _now() + REACTIVE_TIME)
	_take_up_stance.call_deferred()


## A Man-at-Arms always stands in a stance: Vanguard Stance to begin with, as
## classic warriors start in Battle Stance.
func _take_up_stance() -> void:
	if current_form() != 0 or not _combatant.is_alive():
		return
	for id: int in _unit.profile.known_spells:
		var spell := SpellDB.get_spell(id)
		if SpellDB.stance_form(spell) == 17 and SpellDB.uses_rage(spell):
			_enter_stance(spell, false)
			return


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## The stance the unit is in (17 Vanguard, 18 Bastion, 19 Fury), or 0.
func current_form() -> int:
	for aura in _combatant.auras:
		var form := SpellDB.stance_form(aura.spell)
		if form != 0:
			return form
	return 0


## Why a Man-at-Arms ability can't be used right now, or "".
func problem(spell: Dictionary, target: Combatant) -> String:
	var name: String = spell.SpellName
	if SpellDB.uses_rage(spell) and _combatant.mana < caster.mana_cost(spell):
		return ERR_NO_RAGE
	var form := SpellDB.stance_form(spell)
	if form != 0 and SpellDB.uses_rage(spell) and form == current_form():
		return ERR_NOT_NOW
	# Only the three stances count: other classes' spells name forms too (a
	# Cleric's spells can be cast in Shroud of Shadow).
	var needed := int(spell.get("Stances", 0)) & STANCE_MASK if SpellDB.uses_rage(spell) else 0
	var now := current_form()
	if needed != 0 and (now == 0 or needed & (1 << (now - 1)) == 0):
		var names := PackedStringArray()
		for f: int in STANCES:
			if needed & (1 << (f - 1)):
				names.append(STANCES[f])
		return ERR_STANCE % ", ".join(names)
	if name in SHIELD_ABILITIES and not _has_shield():
		return ERR_SHIELD
	if int(spell.get("Attributes", 0)) & SpellDB.ATTR_CANT_USE_IN_COMBAT and _combatant.is_in_combat():
		return SpellCaster.ERR_IN_COMBAT
	if name == queued.get("SpellName", ""):
		return ERR_NOT_NOW
	if target and target != _combatant and target.is_alive():
		if SpellDB.min_range(spell) > 0.0 and _combatant.distance_to(target) < SpellDB.min_range(spell):
			return ERR_TOO_CLOSE
	match name:
		"Riposte Strike":
			if target == null or _dodged_by.get(target, 0.0) < _now():
				return ERR_NOT_NOW
		"Retort":
			if _retort_until < _now():
				return ERR_NOT_NOW
		"Finishing Blow":
			if target and target.health > target.max_health * 0.2:
				return SpellCaster.ERR_TARGET_HEALTH
	return ""


func _has_shield() -> bool:
	var off: Dictionary = _unit.profile.equipment.get(Inventory.Slot.OFF_HAND, {})
	if off.is_empty():
		return false
	var item := ItemDB.get_item(off.id)
	return int(item["class"]) == ItemDB.ITEM_CLASS_ARMOR and int(item.subclass) == Inventory.ARMOR_SUBCLASS_SHIELD


## Abilities on the next swing wait for it: no rage is spent until it lands.
## Returns whether the spell was queued.
func queue(spell: Dictionary) -> bool:
	if int(spell.get("Attributes", 0)) & SpellDB.ATTR_ON_NEXT_SWING == 0:
		return false
	queued = spell
	if _combatant.attack_target == null:
		var target := _unit.enemy_target()
		if target and target.is_alive():
			_combatant.attack_target = target
	return true


## The main-hand swing, if an ability is queued: Mighty Blow strikes harder,
## Sweeping Cut also hits an enemy beside the target. Without the rage, it's
## a plain swing. Returns whether it made the attack.
func _on_swing(target: Combatant) -> bool:
	if queued.is_empty():
		return false
	var spell := queued
	queued = {}
	var cost := caster.mana_cost(spell)
	if _combatant.mana < cost:
		return false
	_combatant.spend_mana(cost)
	var bonus := SpellDB.effect_value(spell, 0, _unit.profile.level)
	_combatant.strike(target, _combatant.roll_weapon_damage() + bonus)
	if spell.SpellName == "Sweeping Cut":
		for other in _enemies_near(target.body.global_position, _combatant.melee_range + 1.0, 1, target):
			_combatant.strike(other, _combatant.roll_weapon_damage() + bonus)
	Sfx.play_at("swing", _unit.global_position)
	return true


func _physics_process(delta: float) -> void:
	if _rush.is_empty():
		return
	var target: Combatant = _rush.target
	if not is_instance_valid(target) or not target.is_alive() or not _combatant.is_alive():
		_rush = {}
		return
	var to := target.body.global_position - _unit.global_position
	var flat := Vector2(to.x, to.z)
	var stop := _combatant.melee_range * 0.7
	_unit.facing = atan2(-to.x, -to.z)
	if flat.length() <= stop + RUSH_SPEED * delta:
		_unit.global_position += Vector3(to.x, 0.0, to.z).normalized() * maxf(flat.length() - stop, 0.0)
		_unit.global_position.y = target.body.global_position.y
		_arrive(_rush.spell, target)
		_rush = {}
		return
	var step := Vector3(to.x, 0.0, to.z).normalized() * RUSH_SPEED * delta
	_unit.global_position += step
	_unit.global_position.y = lerpf(_unit.global_position.y, target.body.global_position.y, 0.2)
	_unit.velocity = Vector3.ZERO


func is_rushing() -> bool:
	return not _rush.is_empty()


## Rush: rage, and the stun its spell triggers. Cut Off: its stun and damage.
func _arrive(spell: Dictionary, target: Combatant) -> void:
	for i in 3:
		match int(spell.get("Effect%d" % (i + 1), 0)):
			SpellDB.EFFECT_ENERGIZE:
				_combatant.gain_rage(SpellDB.effect_value(spell, i, _unit.profile.level) / 10.0)
			SpellDB.EFFECT_TRIGGER_SPELL:
				var stun := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
				if not stun.is_empty():
					_apply_stun(stun, target)
					if SpellDB.has_effect(stun, SpellDB.EFFECT_SCHOOL_DAMAGE):
						target.take_damage(roundi(SpellDB.effect_value(stun, 1, _unit.profile.level)), _combatant)
	_combatant.attack_target = target
	Sfx.play_at("swing", _unit.global_position)


## Carries out a Man-at-Arms ability once its cost is paid. Returns false for
## spells it doesn't handle.
func cast(spell: Dictionary, target: Combatant) -> bool:
	var me := _combatant
	var level := _unit.profile.level
	var name: String = spell.SpellName
	if SpellDB.stance_form(spell) != 0 and SpellDB.uses_rage(spell):
		_enter_stance(spell)
		return true
	match name:
		"Rush", "Cut Off":
			me.enter_combat()
			if target.body is Enemy:
				(target.body as Enemy).provoke(me)
			_rush = { "spell": spell, "target": target }
		"Heavy Swing":
			me.strike(target, me.roll_weapon_damage() + SpellDB.effect_value(spell, 0, level))
		"Riposte Strike":
			_dodged_by.erase(target)
			me.strike(target, me.roll_normalized_damage(_normal_speed()) + SpellDB.effect_value(spell, 0, level), false)
		"Retort":
			_retort_until = 0.0
			me.strike(target, SpellDB.effect_value(spell, 0, level))
		"Finishing Blow":
			# Base damage plus each rage point left after the cost, times the rank's multiplier.
			var extra := me.mana
			me.mana = 0.0
			var damage := SpellDB.effect_value(spell, 0, level) + extra * 10.0 * float(spell.get("DmgMultiplier1", 0.3))
			me.strike(target, damage)
		"Bloodlust Strike":
			me.strike(target, me.attack_power * (SpellDB.effect_value(spell, 0, level)) / 100.0)
		"Grievous Strike":
			if me.strike(target, me.roll_normalized_damage(_normal_speed()) + SpellDB.effect_value(spell, 1, level)):
				target.add_aura(spell, me)
		"Shield Crush":
			if me.strike(target, SpellDB.effect_value(spell, 1, level)):
				caster._dispel(spell, target)
		"Cyclone Strike":
			for enemy in _enemies_near(_unit.global_position, SpellDB.effect_radius(spell), MAX_AREA_TARGETS):
				me.strike(enemy, me.roll_normalized_damage(_normal_speed()))
		"Ground Slam":
			for enemy in _enemies_near(_unit.global_position, SpellDB.effect_radius(spell), MAX_AREA_TARGETS):
				if CombatRules.roll_spell(me, enemy) == CombatRules.Outcome.RESIST:
					enemy.avoid("Resist", me)
					continue
				enemy.take_damage(roundi(SpellDB.effect_value(spell, 0, level)), me)
				enemy.add_aura(spell, me)
			Sfx.play_at("swing", _unit.global_position)
		"Daunting Roar", "Crippling Howl":
			for enemy in _enemies_near(_unit.global_position, SpellDB.effect_radius(spell), 99):
				caster._debuff(spell, enemy)
		"Daring Roar":
			for enemy in _enemies_near(_unit.global_position, SpellDB.effect_radius(spell), 99):
				enemy.add_aura(spell, me)
				(enemy.body as Enemy).taunt(me)
		"Cowing Roar":
			var cower := SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0)))
			if not cower.is_empty() and target and target.is_alive():
				_apply_stun(cower, target)
			var feared := 0
			for enemy in _enemies_near(_unit.global_position, SpellDB.effect_radius(spell, 1), 99):
				if enemy != target and feared < MAX_FEAR_TARGETS:
					caster._debuff(spell, enemy)
					feared += 1
		"Goad":
			if CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
				target.avoid("Resist", me)
			else:
				target.add_aura(spell, me)
				(target.body as Enemy).taunt(me)
		"Taunting Blow":
			if me.strike(target, SpellDB.effect_value(spell, 0, level)):
				target.add_aura(spell, me)
				(target.body as Enemy).taunt(me)
		"Rallying Cry":
			for unit in caster._group_near(SpellDB.effect_radius(spell)):
				caster._buff(spell, unit.combatant)
		"Blood Fury":
			# Costs a fifth of base health (ManaCostPercentage of a health-cost spell).
			var cost := ClassicData.base_health(_unit.profile.char_class, level) * int(spell.get("ManaCostPercentage", 0)) / 100
			me.health = maxi(me.health - cost, 1)
			me.gain_rage(SpellDB.effect_value(spell, 0, level) / 10.0)
			var more := SpellDB.get_spell(int(spell.get("EffectTriggerSpell2", 0)))
			if not more.is_empty():
				me.add_aura(more, me)
			me.enter_combat()
		"Final Stand":
			var stand := SpellDB.get_spell(SpellDB.linked_spell(int(spell.Id)))
			if not stand.is_empty():
				var gain := roundi(me.max_health * FINAL_STAND_SHARE)
				me.add_aura(stand, me)
				me.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == int(stand.Id)).amounts[0] = gain
				me.auras_changed.emit()
				me.health = mini(me.health + gain, me.max_health)
		_:
			return _melee_ability(spell, target)
	return true


## Abilities that hit with the yellow melee table and then leave a debuff or
## deal flat damage: Gash, Hobble, Rend Armor, Wrest Weapon, Shield Smash, Hilt
## Strike, Stunning Blow. Returns false for spells that aren't these.
func _melee_ability(spell: Dictionary, target: Combatant) -> bool:
	if SpellDB.target_type(spell) != SpellDB.TARGET_ENEMY or SpellDB.spell_range(spell) > 5.0 or not SpellDB.uses_rage(spell):
		return false
	var me := _combatant
	var damage := 0.0
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) == SpellDB.EFFECT_SCHOOL_DAMAGE:
			damage += SpellDB.effect_value(spell, i, _unit.profile.level)
	var landed := false
	if damage > 0.0:
		landed = me.strike(target, damage)
	else:
		landed = _melee_roll(target)
	if landed and target.is_alive() and SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
		target.add_aura(spell, me)
		if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
			target.stun(SpellDB.duration(spell))
	if target.body is Enemy:
		(target.body as Enemy).provoke(me)
	return true


## A melee ability's miss, dodge and parry roll with no damage of its own.
func _melee_roll(target: Combatant) -> bool:
	var outcome := CombatRules.roll_melee_ability(_combatant, target)
	if outcome in [CombatRules.Outcome.MISS, CombatRules.Outcome.DODGE, CombatRules.Outcome.PARRY]:
		target.avoid(CombatRules.OUTCOME_TEXT[outcome], _combatant)
		return false
	_combatant.enter_combat()
	target.enter_combat()
	return true


func _apply_stun(stun: Dictionary, target: Combatant) -> void:
	target.add_aura(stun, _combatant)
	target.stun(SpellDB.duration(stun))


## Changing stance: the old stance and its passive go, the new one and its
## passive come, and rage is lost (classic, without Tactical Mastery).
func _enter_stance(spell: Dictionary, sound := true) -> void:
	var me := _combatant
	for aura in me.auras.duplicate():
		var other: Dictionary = aura.spell
		if SpellDB.stance_form(other) != 0 or str(other.SpellName).ends_with("Stance Passive"):
			me.remove_aura(int(other.Id), false)
	me.add_aura(spell, me)
	var passive := SpellDB.get_spell(SpellDB.linked_spell(int(spell.Id)))
	if not passive.is_empty():
		me.add_aura(passive, me)
	me.mana = 0.0
	if sound:
		Sfx.play_at("buff", _unit.global_position)


## Normalized speed for the main-hand weapon.
func _normal_speed() -> float:
	var weapon: Dictionary = _unit.profile.equipment.get(Inventory.Slot.MAIN_HAND, {})
	if weapon.is_empty():
		return NORMAL_SPEED
	var item := ItemDB.get_item(weapon.id)
	if Inventory.is_two_hander(weapon):
		return NORMAL_SPEED_TWO_HAND
	return NORMAL_SPEED_DAGGER if int(item.subclass) == WEAPON_SUBCLASS_DAGGER else NORMAL_SPEED


## Living enemies within a radius of a point, nearest first, at most `count`,
## leaving out `except`.
func _enemies_near(point: Vector3, radius: float, count: int, except: Combatant = null) -> Array[Combatant]:
	var near: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.combatant != except and enemy.state != Enemy.State.RETURN \
				and point.distance_to(enemy.global_position) <= radius:
			near.append(enemy)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool: return point.distance_to(a.global_position) < point.distance_to(b.global_position))
	var found: Array[Combatant] = []
	for enemy in near.slice(0, count):
		found.append(enemy.combatant)
	return found
