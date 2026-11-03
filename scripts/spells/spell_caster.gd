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
const ERR_NOTHING_TO_DISPEL := "Nothing to dispel"
const ERR_PASSIVE := "That ability is passive."
## Seconds before the Homing Token can be used again. Classic's is an hour
## (the spell's CategoryRecoveryTime); here it's 15 minutes.
const HOMING_TOKEN_COOLDOWN := 900.0
const ERR_NO_OATH := "You have no Oath to pass Verdict on."
const ERR_TARGET_HEALTH := "Target must be below 20% health."
## Spells that only affect undead and demons (Banishment, Rebuke the Dead
## undead only), as their spell_template TargetCreatureType in classic.
const UNDEAD_OR_DEMON := ["Banishment", "Radiant Fury"]
const UNDEAD_ONLY := ["Rebuke the Dead"]
## Proficiencies taught by spells: "item class:subclass".
const PROFICIENCY_SPELLS := { "Plate Mail": "4:4" }
## InterruptFlags: taking damage delays the cast.
const INTERRUPT_DAMAGE_PUSHBACK := 0x02
const ERR_IN_COMBAT := "You are in combat"
const ERR_ITEM_NOT_READY := "Item is not ready yet."
## item_template spelltrigger: 0 is "Use:".
const ITEM_SPELL_ON_USE := 0

const WORLD_LAYER := 1
const EYE_HEIGHT := 1.2

## The spell being cast, or {} when not casting.
var casting: Dictionary = {}

var _cast_left := 0.0
var _cast_total := 0.0
var _cast_target: Combatant
var _pushbacks := 0
var _gcd_left := 0.0
var _gcd_total := 1.5
## Spell id -> seconds of cooldown left.
var _cooldowns: Dictionary = {}
## Item spell category -> seconds left.
var _item_cooldowns: Dictionary = {}
## Combat-driven effects: Oath procs, damage shields, hallowed ground.
var _procs := SpellProcs.new()

@onready var _player: Player = get_parent()


func _ready() -> void:
	# The Player's own @onready references aren't set yet while children are readied.
	var combatant: Combatant = $"../Combatant"
	combatant.auto_attack_landed.connect(_on_auto_attack_landed)
	add_child(_procs)
	combatant.took_damage.connect(func(amount: int, _source: Combatant, _crit: bool) -> void:
		if amount > 0:
			_push_back()
	)


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
	# Casting stands you up.
	_player.sitting = false
	var gcd := SpellDB.global_cooldown(spell)
	if gcd > 0.0:
		_gcd_left = gcd
		_gcd_total = gcd
	var time := SpellDB.cast_time(spell)
	if time > 0.0:
		Sfx.play("cast")
		casting = spell
		_player.combatant.is_casting = true
		_pushbacks = 0
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
	_player.combatant.is_casting = not casting.is_empty()
	_gcd_left = maxf(_gcd_left - delta, 0.0)
	for id: int in _cooldowns.keys():
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)
	for category: int in _item_cooldowns.keys():
		_item_cooldowns[category] = maxf(_item_cooldowns[category] - delta, 0.0)
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


## Spell::Delayed in CMaNGOS: each hit taken while casting a spell with the
## DAMAGE_PUSHBACK interrupt flag sets the cast back 1.0 s, then 0.8, 0.6, 0.4
## and 0.2 s for every later hit, never past the start of the cast.
func _push_back() -> void:
	if casting.is_empty() or int(casting.get("InterruptFlags", 0)) & INTERRUPT_DAMAGE_PUSHBACK == 0:
		return
	var delay := 1.0 - 0.2 * _pushbacks if _pushbacks < 5 else 0.2
	_pushbacks += 1
	_cast_left = minf(_cast_left + delay, _cast_total)


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
		SpellDB.TARGET_ANY:
			# Radiant Jolt: the enemy targeted, or yourself.
			var enemy := _player.targeting.target_combatant()
			return enemy if enemy and enemy.is_alive() else _player.combatant
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
	# Unlike classic, Verdict without an Oath it can unleash fails before costing
	# mana, the global cooldown or its own cooldown.
	if spell.SpellName == "Verdict" and _judgeable_seal().is_empty():
		return ERR_NO_OATH
	if SpellDB.is_passive(spell):
		return ERR_PASSIVE
	if me.mana < mana_cost(spell):
		return ERR_NO_MANA
	if int(spell.Effect1) == SpellDB.EFFECT_DISPEL and not _has_dispellable(spell, target):
		return ERR_NOTHING_TO_DISPEL
	var at_enemy := SpellDB.target_type(spell) == SpellDB.TARGET_ENEMY or (SpellDB.target_type(spell) == SpellDB.TARGET_ANY and target != me)
	if at_enemy:
		if target == null:
			return ERR_NO_TARGET
		if not target.is_alive():
			return ERR_DEAD_TARGET
		if spell.SpellName in UNDEAD_OR_DEMON and not _creature_type(target) in [SpellDB.CREATURE_UNDEAD, SpellDB.CREATURE_DEMON]:
			return ERR_DEAD_TARGET
		if spell.SpellName in UNDEAD_ONLY and _creature_type(target) != SpellDB.CREATURE_UNDEAD:
			return ERR_DEAD_TARGET
		if spell.SpellName == "Gavel of Reckoning" and target.health > target.max_health * 0.2:
			return ERR_TARGET_HEALTH
		if me.distance_to(target) > SpellDB.spell_range(spell):
			return ERR_RANGE
		if not _player.is_facing(target.body.global_position):
			return ERR_FACING
		if not _has_line_of_sight(target):
			return ERR_LINE_OF_SIGHT
	return ""


## creature_template CreatureType of an enemy, or 0.
static func _creature_type(target: Combatant) -> int:
	var enemy := target.body as Enemy
	return int(Enemy.creature_data(enemy.creature_entry).get("CreatureType", 0)) if enemy else 0


## Purify removes poisons and diseases (dispel types in the effects' misc values).
func _has_dispellable(spell: Dictionary, target: Combatant) -> bool:
	var types := []
	for i in 3:
		if int(spell["Effect%d" % (i + 1)]) == SpellDB.EFFECT_DISPEL:
			types.append(int(spell["EffectMiscValue%d" % (i + 1)]))
	for aura in target.auras:
		if _is_harmful(aura) and int(aura.spell.get("Dispel", 0)) in types:
			return true
	return false


## Cleansing takes only harmful effects: ones an enemy put on the target, not
## the Paladin's own Boons and Presences (most are magic effects too).
func _is_harmful(aura: Dictionary) -> bool:
	var caster: Combatant = aura.caster
	return caster == null or not is_instance_valid(caster) or not caster.is_player


func _has_line_of_sight(target: Combatant) -> bool:
	var eye := Vector3.UP * EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		_player.global_position + eye, target.body.global_position + eye, WORLD_LAYER
	)
	return _player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _finish(spell: Dictionary, target: Combatant) -> void:
	var me := _player.combatant
	# Unlike classic, Last Rite leaves your mana alone.
	if int(spell.get("AttributesEx", 0)) & SpellDB.ATTR_EX_DRAIN_ALL_POWER and spell.SpellName != "Last Rite":
		me.spend_mana(int(me.mana))
	else:
		me.spend_mana(mana_cost(spell))
	var cooldown := SpellDB.cooldown(spell)
	if cooldown > 0.0:
		_cooldowns[int(spell.Id)] = cooldown
	match spell.SpellName:
		"Mending Radiance", "Quick Radiance":
			_holy_light(spell, target)
		"Radiant Jolt":
			_holy_shock(spell, target)
		"Gavel of Reckoning", "Banishment":
			_spell_damage(spell, target)
		"Radiant Fury":
			_holy_wrath(spell)
		"Rebuke the Dead":
			_turn_undead(spell, target)
		"Hallowed Ground":
			_procs.hallow_ground(spell, _player.global_position)
			Sfx.play("buff")
		"Verdict":
			_judgement(target)
		"Stunning Gavel":
			_hammer_of_justice(spell, target)
		"Last Rite":
			target.heal(me.max_health)
		"Homing Token":
			_go_home(spell)
		_:
			if int(spell.Effect1) == SpellDB.EFFECT_DISPEL:
				_dispel(spell, target)
			elif SpellDB.is_seal(spell):
				_apply_seal(spell)
			elif SpellDB.is_paladin_aura(spell):
				_replace_own(spell, me, SpellDB.is_paladin_aura)
			elif SpellDB.is_blessing(spell):
				_replace_own(spell, target, SpellDB.is_blessing)
			elif int(spell.Effect1) == SpellDB.EFFECT_APPLY_AURA:
				# Divine Protection and other self buffs.
				target.add_aura(spell, me)
				Sfx.play("buff")


## Puts an aura on the target, replacing any of the same kind from this caster.
func _replace_own(spell: Dictionary, target: Combatant, same_kind: Callable) -> void:
	var me := _player.combatant
	for aura in target.auras.duplicate():
		if aura.caster == me and same_kind.call(aura.spell):
			target.remove_aura(int(aura.spell.Id))
	target.add_aura(spell, me)
	Sfx.play("buff")


## The active seal that has a judgement, or {}. (The first rank of Oath of
## Valor that Paladins start with has none, as in classic.)
func _judgeable_seal() -> Dictionary:
	return _player.combatant.find_aura(func(spell: Dictionary) -> bool: return SpellDB.seal_judgement(spell) != 0)


## Unleashes the active seal's judgement on the target. Unlike classic, the
## seal stays up afterwards, and Verdict can't be cast without one.
## Judgements ignore the hit roll (TRIGGERED_IGNORE_HIT_CALCULATION).
func _judgement(target: Combatant) -> void:
	var me := _player.combatant
	var seal := _judgeable_seal()
	if seal.is_empty():
		return
	var judgement := SpellDB.get_spell(SpellDB.seal_judgement(seal.spell))
	if judgement.is_empty():
		return
	Sfx.play("bolt_hit")
	if int(judgement.Effect1) == SpellDB.EFFECT_DUMMY:
		# Verdict of Dominion: Holy damage, doubled on a stunned target
		# (Judgement of Command's dummy effect in CMaNGOS).
		var strike := SpellDB.get_spell(int(judgement.EffectBasePoints1) + 1)
		_spell_damage(strike, target, 2.0 if target.is_stunned() else 1.0, false)
	elif int(judgement.Effect1) == SpellDB.EFFECT_SCHOOL_DAMAGE:
		# Judgement of Righteousness.
		var amount := SpellDB.effect_value(judgement, 0, GameState.level)
		amount += _spell_power() * SpellDB.direct_coefficient(int(judgement.Id))
		var crit := CombatRules.roll_heal(me) == CombatRules.Outcome.CRIT
		_holy_damage(target, roundi(amount * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)), crit)
	else:
		# Judgement of the Crusader and other judgement debuffs: one per Paladin.
		_replace_own(judgement, target, func(spell: Dictionary) -> bool: return str(spell.SpellName).begins_with("Verdict of"))


## A magic stun: resisted on a failed spell hit roll.
func _hammer_of_justice(spell: Dictionary, target: Combatant) -> void:
	var me := _player.combatant
	me.enter_combat()
	if CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return
	target.add_aura(spell, me)
	target.stun(SpellDB.duration(spell))


func _holy_damage(target: Combatant, amount: int, crit: bool) -> void:
	target.take_damage(amount, _player.combatant, crit, SpellDB.School.HOLY)


## Holy Light's script effect heals through spell 19968 (SpellEffects.cpp).
## Learns spells from a trainer. A new spell with the same name and rank text
## as a known one replaces it (Judgement teaches a second Rank 1 Seal of
## Righteousness that can be judged). Other new ranks sit alongside the old
## ones in the spellbook, but take over their action bar slots. That's a
## convenience over classic, which left the old rank on the bar.
## Uses an item's on-use spell (food and drink so far): checks it, takes one
## from the stack and applies the spell. Returns an error or "".
func use_item(ref: Dictionary) -> String:
	var stack := Inventory.stack_at(ref)
	if stack.is_empty():
		return ""
	var item := ItemDB.get_item(stack.id)
	var spell := SpellDB.get_spell(int(item.get("spellid_1", 0)))
	if spell.is_empty() or int(item.spelltrigger_1) != ITEM_SPELL_ON_USE:
		return ""
	var me := _player.combatant
	if not me.is_alive():
		return ""
	if int(spell.Attributes) & SpellDB.ATTR_CANT_USE_IN_COMBAT and me.is_in_combat():
		return ERR_IN_COMBAT
	var category := int(item.spellcategory_1)
	if _item_cooldowns.get(category, 0.0) > 0.0:
		return ERR_ITEM_NOT_READY
	if not casting.is_empty():
		return ERR_IN_PROGRESS
	# Items whose spell has a cast time and no aura (the Homing Token) cast
	# like a spell; the spell's own category holds the cooldown.
	if SpellDB.cast_time(spell) > 0.0 and int(spell.Effect1) != SpellDB.EFFECT_APPLY_AURA:
		return _cast_item_spell(spell)
	if int(item.spellcategorycooldown_1) > 0:
		_item_cooldowns[category] = int(item.spellcategorycooldown_1) / 1000.0
	if int(item.spellcharges_1) < 0:
		Inventory.remove_one(ref)
	me.add_aura(spell, me)
	# Food and drink are taken sitting down.
	if int(spell.AuraInterruptFlags) & SpellDB.AURA_INTERRUPT_NOT_SEATED:
		_player.sitting = true
	Sfx.play("eat")
	return ""


## Starts an item's cast-time spell on yourself, checking the spell's category
## cooldown (an hour for the Homing Token, from CategoryRecoveryTime) and the
## global cooldown. Moving interrupts it, as for any cast.
func _cast_item_spell(spell: Dictionary) -> String:
	if _item_cooldowns.get(_spell_category(spell), 0.0) > 0.0:
		return ERR_ITEM_NOT_READY
	if _gcd_left > 0.0:
		return ERR_NOT_READY
	if _player.is_moving():
		return ERR_MOVING
	_player.sitting = false
	var gcd := SpellDB.global_cooldown(spell)
	if gcd > 0.0:
		_gcd_left = gcd
		_gcd_total = gcd
	Sfx.play("cast")
	casting = spell
	_player.combatant.is_casting = true
	_pushbacks = 0
	_cast_left = SpellDB.cast_time(spell)
	_cast_total = _cast_left
	_cast_target = _player.combatant
	return ""


## Item spells share cooldowns by spell category (so every Homing Token
## waits the same hour). Kept apart from item categories by sign.
static func _spell_category(spell: Dictionary) -> int:
	return -int(spell.get("Category", 0))


## Seconds left before an item's spell can be used again, or 0.
func item_cooldown_left(item: Dictionary) -> float:
	var spell := SpellDB.get_spell(int(item.get("spellid_1", 0)))
	var left: float = _item_cooldowns.get(int(item.get("spellcategory_1", 0)), 0.0)
	if not spell.is_empty():
		left = maxf(left, _item_cooldowns.get(_spell_category(spell), 0.0))
	return left


## Item cooldowns still running, as { category: unix time they end }, for the
## save, so an hour's wait doesn't reset on logging out.
func saved_item_cooldowns() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var saved := {}
	for category: int in _item_cooldowns:
		if _item_cooldowns[category] > 0.0:
			saved[str(category)] = now + _item_cooldowns[category]
	return saved


func restore_item_cooldowns(saved: Dictionary) -> void:
	var now := Time.get_unix_time_from_system()
	for category: String in saved:
		var left := float(saved[category]) - now
		if left > 0.0:
			_item_cooldowns[int(category)] = left


## The Homing Token's teleport: back to the zone's start point, the camera
## jumping along, and its cooldown starting once the cast lands.
func _go_home(spell: Dictionary) -> void:
	_item_cooldowns[_spell_category(spell)] = HOMING_TOKEN_COOLDOWN
	_player.combatant.attack_target = null
	_player.velocity = Vector3.ZERO
	_player.global_position = AshfordVale.SPAWN
	_player.facing = AshfordVale.SPAWN_FACING
	var camera := _player.get_viewport().get_camera_3d() as OrbitCamera
	if camera:
		camera.snap_to_target()
	Sfx.play("level_up")


static func learn(ids: Array) -> Array[String]:
	var learned: Array[String] = []
	for id: int in ids:
		if id in GameState.known_spells:
			continue
		var spell := SpellDB.get_spell(id)
		var previous := 0
		for known: int in GameState.known_spells:
			var other := SpellDB.get_spell(known)
			if other.SpellName == spell.SpellName and other.Rank1 == spell.Rank1:
				previous = known
		if previous != 0:
			GameState.known_spells[GameState.known_spells.find(previous)] = id
		else:
			GameState.known_spells.append(id)
		for i in GameState.action_bar.size():
			var on_bar := SpellDB.get_spell(GameState.action_bar[i])
			var replaces := previous != 0 and GameState.action_bar[i] == previous
			var lower_rank: bool = on_bar.get("SpellName") == spell.SpellName and int(on_bar.get("SpellLevel", 0)) < int(spell.SpellLevel)
			if replaces or lower_rank:
				GameState.action_bar[i] = id
		learned.append(SpellDB.full_name(spell))
		# Plate Mail teaches wearing plate.
		var proficiency: String = PROFICIENCY_SPELLS.get(spell.SpellName, "")
		if not proficiency.is_empty() and not proficiency in GameState.proficiencies:
			GameState.proficiencies.append(proficiency)
	GameState.spells_changed.emit()
	return learned


## Mending Radiance and Quick Radiance. Boon of Radiance on the target adds
## its bonus: the first amount to Mending Radiance, the second to Quick.
func _holy_light(spell: Dictionary, target: Combatant) -> void:
	var amount := SpellDB.effect_value(spell, 0, GameState.level)
	amount += _spell_power() * SpellDB.direct_coefficient(SpellDB.HOLY_LIGHT_HEAL)
	var boon := target.find_aura(func(other: Dictionary) -> bool: return str(other.SpellName).ends_with("Boon of Radiance"))
	if not boon.is_empty():
		amount += boon.amounts[0 if spell.SpellName == "Mending Radiance" else 1]
	target.heal_with_spell(amount)


## Holy damage from a spell's first effect: a spell hit roll (Resist on a
## miss, unless the spell always hits) and a crit roll.
func _spell_damage(spell: Dictionary, target: Combatant, multiplier := 1.0, can_miss := true) -> void:
	var me := _player.combatant
	me.enter_combat()
	if can_miss and CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return
	var amount := SpellDB.effect_value(spell, 0, GameState.level) + _spell_power() * SpellDB.direct_coefficient(int(spell.Id))
	var crit := not SpellDB.has_attribute_ex2(spell, SpellDB.ATTR_EX2_CANT_CRIT) and CombatRules.roll_heal(me) == CombatRules.Outcome.CRIT
	Sfx.play("bolt_hit")
	_holy_damage(target, roundi(amount * multiplier * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)), crit)


## Radiant Jolt: its rank's damage spell on an enemy, or its heal on yourself.
func _holy_shock(spell: Dictionary, target: Combatant) -> void:
	var pair := SpellDB.holy_shock_spells(int(spell.Id))
	if pair.size() < 2:
		return
	if target == _player.combatant:
		var heal := SpellDB.get_spell(int(pair[1]))
		target.heal_with_spell(SpellDB.effect_value(heal, 0, GameState.level))
	else:
		_spell_damage(SpellDB.get_spell(int(pair[0])), target)


## Radiant Fury: Holy damage to every undead and demon within its radius.
func _holy_wrath(spell: Dictionary) -> void:
	var radius := SpellDB.effect_radius(spell)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var kind := _creature_type(enemy.combatant)
		if enemy.combatant.is_alive() and kind in [SpellDB.CREATURE_UNDEAD, SpellDB.CREATURE_DEMON] \
				and _player.global_position.distance_to(enemy.global_position) <= radius:
			_spell_damage(spell, enemy.combatant)


## Rebuke the Dead: classic's fear makes the undead run; here it holds them in
## place for the duration instead (there's no fleeing yet).
func _turn_undead(spell: Dictionary, target: Combatant) -> void:
	var me := _player.combatant
	me.enter_combat()
	if CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return
	target.add_aura(spell, me)
	target.stun(SpellDB.duration(spell))


## Cleansing: removes one harmful effect of each dispel type the spell names.
func _dispel(spell: Dictionary, target: Combatant) -> void:
	for i in 3:
		if int(spell["Effect%d" % (i + 1)]) != SpellDB.EFFECT_DISPEL:
			continue
		var kind := int(spell["EffectMiscValue%d" % (i + 1)])
		for aura in target.auras:
			if _is_harmful(aura) and int(aura.spell.get("Dispel", 0)) == kind:
				target.remove_aura(int(aura.spell.Id))
				break
	Sfx.play("heal")


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
	_holy_damage(target, seal_of_righteousness_damage(seal.spell), false)


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
