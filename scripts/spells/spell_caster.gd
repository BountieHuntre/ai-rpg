class_name SpellCaster
extends Node
## Casts a player character's classic WoW spells: checks, global cooldown,
## cooldowns, cast times, channels and the effects of each Templar (Paladin)
## and Cleric (Priest) spell. Formulas follow the CMaNGOS classic code; see
## data/classic/SOURCE.md.
## Must be a child of a PlayerUnit: the Player, or a playerbot, whose AI picks
## its targets.

signal failed(message: String)
## A spell was cast (its cast time done, or an instant), before its effects.
signal spell_finished(spell: Dictionary)

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
const ERR_CANT_YET := "You can't do that yet"
const ERR_SHAPESHIFTED := "You can't do that while shapeshifted."
## Dread Wail frightens up to this many enemies (MaxAffectedTargets in classic).
const MAX_FEAR_TARGETS := 5
## Leeching Embrace heals the caster's party for this share of shadow damage.
const EMBRACE_SHARE := 0.2
## Stillness: the next spell costs no mana and has this much more crit chance.
const STILLNESS_CRIT := 25.0
## item_template spelltrigger: 0 is "Use:".
const ITEM_SPELL_ON_USE := 0

const WORLD_LAYER := 1
const EYE_HEIGHT := 1.2
## SPELL_AURA_MOD_SPELL_CRIT_CHANCE_SCHOOL (Sacred Power).
const AURA_MOD_SPELL_CRIT_SCHOOL := 71

## The spell being cast or channeled, or {} when not casting.
var casting: Dictionary = {}
## True while `casting` is a channel (Mind Rend, Falling Stars): its effect
## already landed and lasts while the caster holds still.
var channeling := false

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
## The bag slot of an item being cast that's used up when its spell lands.
var _item_ref: Dictionary = {}
## The spell of the item being used, which costs no mana.
var _item_spell := 0
## Combat-driven effects: Oath procs, damage shields, hallowed ground.
var _procs := SpellProcs.new()
## The Man-at-Arms' abilities: stances, next-swing attacks, rushing in.
var _warrior := WarriorAbilities.new()
## The Spellsword's: forms, Edges, Resonance and Release.
var _spellsword := SpellswordAbilities.new()

@onready var _unit: PlayerUnit = get_parent()


## A quest item's spell being cast (QuestSpells), and what it's used on.
var _quest_spell := 0
var _quest_target: Node3D


func _ready() -> void:
	# The Player's own @onready references aren't set yet while children are readied.
	var combatant: Combatant = $"../Combatant"
	combatant.auto_attack_landed.connect(_on_auto_attack_landed)
	_procs.name = "SpellProcs"
	add_child(_procs)
	_warrior.name = "WarriorAbilities"
	add_child(_warrior)
	_spellsword.name = "SpellswordAbilities"
	add_child(_spellsword)
	var talent_procs := TalentProcs.new()
	talent_procs.name = "TalentProcs"
	add_child(talent_procs)
	combatant.took_damage.connect(func(amount: int, _source: Combatant, _crit: bool) -> void:
		if amount > 0:
			_push_back()
	)
	# Stuns and interrupt effects cut a cast short, as they do a creature's.
	combatant.stunned.connect(_interrupt)
	combatant.interrupt_requested.connect(func(_lockout: float) -> void: _interrupt())


func _interrupt() -> void:
	if casting.is_empty():
		return
	if channeling:
		_stop_channel()
	else:
		casting = {}
	_unit.combatant.is_casting = false
	_unit.combatant.cast_interrupted.emit()
	failed.emit("Interrupted")


## Starts casting a known spell, or reports why it can't.
func cast(id: int) -> void:
	var me := _unit.combatant
	if not me.is_alive() or not id in _unit.profile.known_spells:
		return
	if id == SpellDB.ATTACK:
		_toggle_attack()
		return
	if id == SpellDB.SHOOT:
		toggle_shoot()
		return
	var spell := SpellDB.get_spell(id)
	_item_ref = {}
	_item_spell = 0
	# Clicking the stance you're already in does nothing, as in classic.
	var form := SpellDB.stance_form(spell)
	if form != 0 and SpellDB.uses_rage(spell) and form == current_form():
		return
	var target := _pick_target(spell)
	var problem := _find_problem(spell, target, true)
	if not problem.is_empty():
		failed.emit(problem)
		return
	# A new spell ends a channel.
	if channeling:
		_stop_channel()
	# Casting stands you up.
	_unit.sitting = false
	var gcd := SpellDB.global_cooldown(spell)
	if gcd > 0.0:
		_gcd_left = gcd
		_gcd_total = gcd
	var time := SpellDB.cast_time(spell, me)
	if time > 0.0:
		Sfx.play_at("cast", _unit.global_position)
		casting = spell
		_unit.combatant.is_casting = true
		_pushbacks = 0
		_cast_left = time
		_cast_total = time
		_cast_target = target
	else:
		_finish(spell, target)


## Why a known spell can't be cast at its target right now, or "" if it can.
## Playerbots ask before casting.
func problem(id: int) -> String:
	var spell := SpellDB.get_spell(id)
	return _find_problem(spell, _pick_target(spell), true)


## How far the cast has got, 0 to 1; a channel's bar runs down instead.
func cast_fraction() -> float:
	if casting.is_empty():
		return 0.0
	return _cast_left / _cast_total if channeling else 1.0 - _cast_left / _cast_total


## How much of a spell's cooldown (or the global cooldown) is left, 1 to 0.
func cooldown_fraction(id: int) -> float:
	var spell := SpellDB.get_spell(id)
	var fraction := 0.0
	if SpellDB.global_cooldown(spell) > 0.0:
		fraction = _gcd_left / _gcd_total
	var total := SpellDB.cooldown(spell, _unit.combatant)
	if total > 0.0:
		fraction = maxf(fraction, _cooldowns.get(id, 0.0) / total)
	return fraction


## Stillness makes the next spell free.
func mana_cost(spell: Dictionary) -> int:
	# Spells cast from an item cost nothing (Spell::CalculatePowerCost).
	if _item_spell != 0 and int(spell.get("Id", 0)) == _item_spell:
		return 0
	if _spellsword.costs_nothing(spell):
		return 0
	var cost := SpellDB.mana_cost(spell, ClassicData.base_mana(_unit.profile.char_class, _unit.profile.level), _unit.combatant)
	return 0 if cost > 0 and _stillness() else cost


## The ability waiting for the next swing (Mighty Blow), or {}: its button glows.
func queued_swing() -> Dictionary:
	return _warrior.queued


## The Man-at-Arms' stance form (17, 18 or 19), or 0.
func current_form() -> int:
	return _warrior.current_form()


## Stillness waiting for the next spell, or {}.
func _stillness() -> Dictionary:
	# By name: percentage talents are spell modifiers too.
	return _unit.combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Stillness")


## Stillness's extra crit chance for the next spell.
func _extra_crit() -> float:
	return STILLNESS_CRIT if not _stillness().is_empty() else 0.0


## Talents' extra crit chance for a spell: for the spell itself (SpellMods)
## and for its school (Sacred Power for Holy).
func _talent_crit(spell: Dictionary) -> float:
	var me := _unit.combatant
	return SpellMods.flat(me, spell, SpellMods.CRITICAL_CHANCE) + me.aura_total(AURA_MOD_SPELL_CRIT_SCHOOL, 1 << int(spell.get("School", 0)))


## Whether the current target is out of the spell's range, for the action bar.
func out_of_range(id: int) -> bool:
	var spell := SpellDB.get_spell(id)
	if id == SpellDB.SHOOT:
		var shot_at := _unit.enemy_target()
		return shot_at != null and not _unit.combatant.ranged_weapon.is_empty() \
			and _unit.combatant.distance_to(shot_at) > float(_unit.combatant.ranged_weapon.range)
	if id == SpellDB.ATTACK or SpellDB.target_type(spell) != SpellDB.TARGET_ENEMY:
		return false
	var target := _unit.enemy_target()
	if target == null:
		return false
	var distance := _unit.combatant.distance_to(target)
	return distance > SpellDB.spell_range(spell, _unit.combatant) or distance < SpellDB.min_range(spell)


func _physics_process(delta: float) -> void:
	_unit.combatant.is_casting = not casting.is_empty()
	_gcd_left = maxf(_gcd_left - delta, 0.0)
	# Cooldowns that ran out are dropped, so idle casters have nothing to count.
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	for category: int in _item_cooldowns.keys():
		_item_cooldowns[category] = maxf(_item_cooldowns[category] - delta, 0.0)
	if casting.is_empty():
		return
	if channeling:
		_cast_left -= delta
		var held := _cast_target != null and is_instance_valid(_cast_target) and _cast_target.is_alive()
		if _unit.is_moving() or not _unit.combatant.is_alive() or not held:
			_stop_channel()
		elif _cast_left <= 0.0:
			casting = {}
			channeling = false
		return
	if _unit.is_moving() or not _unit.combatant.is_alive():
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
			_use_up_item()
		else:
			failed.emit(problem)


## Spell::Delayed in CMaNGOS: each hit taken while casting a spell with the
## DAMAGE_PUSHBACK interrupt flag sets the cast back 1.0 s, then 0.8, 0.6, 0.4
## and 0.2 s for every later hit, never past the start of the cast.
## Talents may resist it: Mending Focus (SpellMods NOT_LOSE_CASTING_TIME) and
## Steady Casting (SPELL_AURA_RESIST_PUSHBACK), as a chance in percent.
func _push_back() -> void:
	if casting.is_empty() or channeling or int(casting.get("InterruptFlags", 0)) & INTERRUPT_DAMAGE_PUSHBACK == 0:
		return
	var me := _unit.combatant
	var resist := SpellMods.apply(me, casting, SpellMods.NOT_LOSE_CASTING_TIME, 100.0) - 100.0 + me.aura_total(SpellDB.AURA_RESIST_PUSHBACK)
	if resist > 0.0 and randf() * 100.0 < resist:
		return
	var delay := 1.0 - 0.2 * _pushbacks if _pushbacks < 5 else 0.2
	_pushbacks += 1
	_cast_left = minf(_cast_left + delay, _cast_total)


func _toggle_attack() -> void:
	var me := _unit.combatant
	if me.attack_target:
		me.attack_target = null
		return
	var target := _unit.enemy_target()
	if target == null or not target.is_alive():
		failed.emit(ERR_NO_TARGET)
		return
	me.stop_shooting()
	me.attack_target = target


## Shoot: starts or stops shooting the target with the ranged weapon.
func toggle_shoot() -> void:
	var me := _unit.combatant
	if me.shoot_target:
		me.stop_shooting()
		return
	var target := _unit.enemy_target()
	if target == null or not target.is_alive():
		failed.emit(ERR_NO_TARGET)
		return
	var problem := me.shot_problem(target)
	if not problem.is_empty():
		failed.emit(problem)
		return
	me.start_shooting(target)


## Harmful spells go at the current target. Friendly ones go at the target if
## it's a friendly player (a playerbot), otherwise at the caster.
func _pick_target(spell: Dictionary) -> Combatant:
	# Revival names no target type: it takes a friendly corpse.
	if is_resurrection(spell):
		return _unit.friendly_target()
	match SpellDB.target_type(spell):
		SpellDB.TARGET_ENEMY:
			return _unit.enemy_target()
		SpellDB.TARGET_ANY:
			# Radiant Jolt and Unweave: the enemy targeted, else the friend, else yourself.
			var enemy := _unit.enemy_target()
			if enemy and enemy.is_alive():
				return enemy
			var friend := _unit.friendly_target()
			return friend if friend and friend.is_alive() else _unit.combatant
		SpellDB.TARGET_FRIEND:
			var friend := _unit.friendly_target()
			return friend if friend and friend.is_alive() else _unit.combatant
		_:
			return _unit.combatant


## Revival brings back a dead friendly player.
static func is_resurrection(spell: Dictionary) -> bool:
	return int(spell.get("Effect1", 0)) == SpellDB.EFFECT_RESURRECT


func _find_problem(spell: Dictionary, target: Combatant, starting: bool) -> String:
	var me := _unit.combatant
	if starting:
		if not casting.is_empty() and not channeling:
			return ERR_IN_PROGRESS
		if SpellDB.global_cooldown(spell) > 0.0 and _gcd_left > 0.0:
			return ERR_NOT_READY
		if _cooldowns.get(int(spell.Id), 0.0) > 0.0:
			return ERR_NOT_READY
		if SpellDB.cast_time(spell, _unit.combatant) > 0.0 and _unit.is_moving():
			return ERR_MOVING
	# Unlike classic, Verdict without an Oath it can unleash fails before costing
	# mana, the global cooldown or its own cooldown.
	if spell.SpellName == "Verdict" and _judgeable_seal().is_empty():
		return ERR_NO_OATH
	if SpellDB.is_passive(spell):
		return ERR_PASSIVE
	# Rage, stances, shields and the moments some abilities wait for.
	var warrior_problem := _warrior.problem(spell, target)
	if not warrior_problem.is_empty():
		return warrior_problem
	var spellsword_problem := _spellsword.problem(spell, target)
	if not spellsword_problem.is_empty():
		return spellsword_problem
	# Shroud of Shadow shuts out Holy spells (Shadowform in classic).
	if int(spell.get("School", 0)) == SpellDB.School.HOLY and _in_shroud():
		return ERR_SHAPESHIFTED
	if me.mana < mana_cost(spell):
		return ERR_NO_MANA
	if is_resurrection(spell):
		if target == null:
			return ERR_NO_TARGET
		if target.is_alive() or target == me:
			return ERR_DEAD_TARGET
	# (Shield Crush strikes whether or not there's anything to strip.)
	if int(spell.Effect1) == SpellDB.EFFECT_DISPEL and not SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE) and not _has_dispellable(spell, target):
		return ERR_NOTHING_TO_DISPEL
	# Sanctified Ward leaves a Spent Soul that keeps another off for a while.
	if spell.SpellName == "Sanctified Ward" and target and not target.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == SpellDB.WEAKENED_SOUL).is_empty():
		return ERR_CANT_YET
	if target and target != me and target.is_player:
		# Helping another player: in range and in sight, but facing doesn't matter.
		if me.distance_to(target) > SpellDB.spell_range(spell, _unit.combatant):
			return ERR_RANGE
		if not _has_line_of_sight(target):
			return ERR_LINE_OF_SIGHT
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
		# Creature types the spell takes (Bind the Dead undead, Calm Mind humanoids).
		var types := int(spell.get("TargetCreatureType", 0))
		if types != 0 and (_creature_type(target) == 0 or types & (1 << (_creature_type(target) - 1)) == 0):
			return ERR_DEAD_TARGET
		if int(spell.Effect1) == SpellDB.EFFECT_POWER_BURN and target.max_mana <= 0:
			return ERR_DEAD_TARGET
		if spell.SpellName == "Gavel of Reckoning" and target.health > target.max_health * 0.2:
			return ERR_TARGET_HEALTH
		if me.distance_to(target) > SpellDB.spell_range(spell, _unit.combatant):
			return ERR_RANGE
		if not _unit.is_facing(target.body.global_position):
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
	if target == null:
		return false
	var types := []
	for i in 3:
		if int(spell["Effect%d" % (i + 1)]) == SpellDB.EFFECT_DISPEL:
			types.append(int(spell["EffectMiscValue%d" % (i + 1)]))
	for aura in target.auras:
		if _dispellable(aura, target) and int(aura.spell.get("Dispel", 0)) in types:
			return true
	return false


## Cleansing a friend takes only harmful effects: ones an enemy put on them,
## not the Templar's own Boons and Presences (most are magic effects too).
## Unweave on an enemy takes its own buffs instead.
func _dispellable(aura: Dictionary, target: Combatant) -> bool:
	var caster: Combatant = aura.caster
	var from_creature := caster == null or not is_instance_valid(caster) or not caster.is_player
	return from_creature if target.is_player else (from_creature and int(aura.spell.get("Dispel", 0)) != 0)


func _in_shroud() -> bool:
	return not _unit.combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Shroud of Shadow").is_empty()


func _has_line_of_sight(target: Combatant) -> bool:
	var eye := Vector3.UP * EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(
		_unit.global_position + eye, target.body.global_position + eye, WORLD_LAYER
	)
	return _unit.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _finish(spell: Dictionary, target: Combatant) -> void:
	var me := _unit.combatant
	if _quest_spell != 0 and int(spell.Id) == _quest_spell:
		_quest_spell = 0
		spell_finished.emit(spell)
		QuestSpells.land(_unit, spell, _quest_target)
		_quest_target = null
		return
	# Mighty Blow and Sweeping Cut wait for the next swing, paying then.
	if _warrior.queue(spell):
		return
	spell_finished.emit(spell)
	# Stillness is used up by the next spell that costs mana.
	var stillness := _stillness()
	var uses_stillness := not stillness.is_empty() and SpellDB.mana_cost(spell, 1) > 0
	var extra_crit := _extra_crit()
	# Unlike classic, Last Rite leaves your mana alone.
	if int(spell.get("AttributesEx", 0)) & SpellDB.ATTR_EX_DRAIN_ALL_POWER and spell.SpellName != "Last Rite":
		me.spend_mana(int(me.mana))
	else:
		me.spend_mana(mana_cost(spell))
	var cooldown := SpellDB.cooldown(spell, _unit.combatant)
	if cooldown > 0.0:
		_cooldowns[int(spell.Id)] = cooldown
	if not _spellsword.cast(spell, target) and not _warrior.cast(spell, target):
		_cleric_spell(spell, target, extra_crit)
	# Helpful spells that aren't heals (heals report their own) are events for
	# procs too (Improved Last Rite, Improved Unbridled Rage).
	if SpellDB.target_type(spell) != SpellDB.TARGET_ENEMY and not SpellDB.has_effect(spell, SpellDB.EFFECT_HEAL) and target:
		me.proc_event.emit(Combatant.PROC_POSITIVE_SPELL, Combatant.PROC_EX_NORMAL, target, spell, 0)
		if target != me:
			target.proc_event.emit(Combatant.PROC_TAKEN_POSITIVE_SPELL, Combatant.PROC_EX_NORMAL, me, spell, 0)
	if uses_stillness:
		me.remove_aura(int(stillness.spell.Id))
	_use_modifier_charges(spell)


## Buffs that change your next few spells (Heaven's Favor: the next heal is
## a critical one) lose a charge when a spell they change is cast.
func _use_modifier_charges(spell: Dictionary) -> void:
	var me := _unit.combatant
	for aura in me.auras.duplicate():
		if aura.get("talent", false) or not aura.has("charges") or aura.spell.SpellName == "Stillness":
			continue
		var buff: Dictionary = aura.spell
		var changes := false
		for i in 3:
			var kind := int(buff.get("EffectApplyAuraName%d" % (i + 1), 0))
			if (kind == SpellMods.AURA_FLAT or kind == SpellMods.AURA_PCT) and int(buff.get("EffectItemType%d" % (i + 1), 0)) & int(spell.get("SpellFamilyFlags", 0)) != 0:
				changes = int(buff.get("SpellFamilyName", 0)) == int(spell.get("SpellFamilyName", 0))
		if changes and buff != spell:
			aura.charges -= 1
			if aura.charges <= 0:
				me.remove_aura(int(buff.Id))


## Templar spells, then Cleric ones (spell_caster's second half).
func _templar_spell(spell: Dictionary, target: Combatant) -> bool:
	var me := _unit.combatant
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
			_procs.hallow_ground(spell, _unit.global_position)
			Sfx.play_at("buff", _unit.global_position)
		"Verdict":
			_judgement(target)
		"Stunning Gavel":
			_hammer_of_justice(spell, target)
		"Last Rite":
			target.heal(me.max_health, false, me)
		"Homing Token":
			_go_home(spell)
		_:
			if SpellDB.is_seal(spell):
				_apply_seal(spell)
			elif SpellDB.is_paladin_aura(spell):
				_replace_own(spell, me, SpellDB.is_paladin_aura)
			elif SpellDB.is_blessing(spell):
				_replace_own(spell, target, SpellDB.is_blessing)
			else:
				return false
	return true


## Every other spell, by what its effects do: raising the dead, dispels,
## heals, damage, and buffs and debuffs, with the Cleric's odd ones by name.
func _cleric_spell(spell: Dictionary, target: Combatant, extra_crit: float) -> void:
	if _templar_spell(spell, target):
		return
	var me := _unit.combatant
	match spell.SpellName:
		"Blessed Burst":
			_holy_nova(spell, extra_crit)
		"Communal Mending":
			for unit in _group_near(SpellDB.effect_radius(spell, 0, _unit.combatant)):
				_direct_heal(spell, unit.combatant, extra_crit)
		"Communal Spirit":
			for unit in _group_near(SpellDB.effect_radius(spell, 0, _unit.combatant)):
				_buff(spell, unit.combatant)
		"Sanctified Ward":
			_buff(spell, target)
			target.add_aura(SpellDB.get_spell(SpellDB.WEAKENED_SOUL), me)
		"Shroud of Shadow":
			# Casting it again leaves the form.
			if _in_shroud():
				me.remove_aura(int(spell.Id))
			else:
				_buff(spell, me)
		"Mana Scorch":
			_mana_burn(spell, target, extra_crit)
		"Dread Wail":
			_fear_around(spell)
		"Cleanse Sickness":
			_buff(spell, target)
			_dispel(spell, target)
		_:
			if is_resurrection(spell):
				var bot := target.body as Bot
				if bot:
					bot.resurrect(roundi(SpellDB.effect_value(spell, 0, _unit.profile.level, _unit.combatant)), int(spell.get("EffectMiscValue1", 0)))
					Sfx.play_at("heal", _unit.global_position)
			elif int(spell.Effect1) == SpellDB.EFFECT_DISPEL:
				_dispel(spell, target)
			elif int(spell.Effect1) == SpellDB.EFFECT_HEAL:
				_direct_heal(spell, target, extra_crit)
			elif int(spell.Effect1) == SpellDB.EFFECT_SCHOOL_DAMAGE:
				# Sacred Flame's burn rides on its hit.
				if _spell_damage(spell, target, 1.0, true, extra_crit) and SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
					_replace_own(spell, target, func(other: Dictionary) -> bool: return other.SpellName == spell.SpellName, false)
			elif int(spell.Effect1) == SpellDB.EFFECT_APPLY_AURA:
				if SpellDB.target_type(spell) == SpellDB.TARGET_ENEMY:
					if _debuff(spell, target) and SpellDB.is_channeled(spell):
						_start_channel(spell, target)
				else:
					# Divine Protection, Litany of Fortitude and other buffs.
					_buff(spell, target)


## A buff replaces the same spell's other ranks from anyone (two Litanies
## don't stack).
func _buff(spell: Dictionary, target: Combatant) -> void:
	for aura in target.auras.duplicate():
		if aura.spell.SpellName == spell.SpellName:
			target.remove_aura(int(aura.spell.Id), false)
	target.add_aura(spell, _unit.combatant)
	Sfx.play_at("buff", _unit.global_position)


## A harmful aura on an enemy: a spell hit roll (Resist on a miss), the
## creature turning to fight (Calm Mind excepted, which draws no threat), and
## one of each spell per caster. Stuns hold the target. Returns whether it landed.
func _debuff(spell: Dictionary, target: Combatant) -> bool:
	var me := _unit.combatant
	var quiet: bool = spell.SpellName == "Calm Mind"
	if not quiet:
		me.enter_combat()
	if CombatRules.roll_spell(me, target, spell) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return false
	_replace_own(spell, target, func(other: Dictionary) -> bool: return other.SpellName == spell.SpellName, false)
	me.proc_event.emit(Combatant.PROC_NEGATIVE_SPELL, Combatant.PROC_EX_NORMAL, target, spell, 0)
	target.proc_event.emit(Combatant.PROC_TAKEN_NEGATIVE_SPELL, Combatant.PROC_EX_NORMAL, me, spell, 0)
	if SpellDB.has_effect(spell, SpellDB.AURA_MOD_STUN, true):
		target.stun(SpellDB.duration(spell, _unit.combatant))
	var enemy := target.body as Enemy
	if enemy and not quiet:
		enemy.provoke(me)
	Sfx.play_at("bolt_hit", target.body.global_position)
	return true


## Holds a channel: the bar runs down while the effect lasts, and moving, a
## new spell or the target dying ends it early, taking the effect away.
func _start_channel(spell: Dictionary, target: Combatant) -> void:
	casting = spell
	channeling = true
	_cast_target = target
	_cast_total = maxf(SpellDB.duration(spell), 0.1)
	_cast_left = _cast_total
	_unit.combatant.is_casting = true


func _stop_channel() -> void:
	if channeling and _cast_target and is_instance_valid(_cast_target):
		for aura in _cast_target.auras.duplicate():
			if aura.caster == _unit.combatant and int(aura.spell.Id) == int(casting.get("Id", 0)):
				_cast_target.remove_aura(int(aura.spell.Id))
	casting = {}
	channeling = false


## The caster's group within a radius: the party for the player and its
## members, just itself for a bot on its own.
func _group_near(radius: float) -> Array[PlayerUnit]:
	var group: Array[PlayerUnit] = []
	var units: Array[PlayerUnit] = [_unit]
	if Party.has_unit(_unit.combatant):
		units = Party.units()
	for unit in units:
		if unit.combatant.is_alive() and unit.global_position.distance_to(_unit.global_position) <= radius:
			group.append(unit)
	return group


## A direct heal from the first effect: its amount plus spell power.
func _direct_heal(spell: Dictionary, target: Combatant, extra_crit := 0.0) -> void:
	var amount := SpellDB.effect_value(spell, 0, _unit.profile.level, _unit.combatant) + _spell_power() * SpellDB.direct_coefficient(int(spell.Id))
	target.heal_with_spell(amount, _unit.combatant, extra_crit + _talent_crit(spell), spell)
	Sfx.play_at("heal", target.body.global_position)


## Blessed Burst: damage to enemies around the caster and its rank's heal on
## the group around them, neither drawing threat (as classic's Holy Nova).
func _holy_nova(spell: Dictionary, extra_crit: float) -> void:
	var me := _unit.combatant
	var radius := SpellDB.effect_radius(spell, 0, _unit.combatant)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and _unit.global_position.distance_to(enemy.global_position) <= radius:
			var before := enemy.combatant.health
			_spell_damage(spell, enemy.combatant, 1.0, true, extra_crit)
			if enemy.threat.has(me):
				enemy.threat[me] = maxf(enemy.threat[me] - (before - enemy.combatant.health), 0.0)
	var heal := SpellDB.get_spell(SpellDB.linked_spell(int(spell.Id)))
	if heal.is_empty():
		return
	for unit in _group_near(radius):
		var crit := CombatRules.roll_heal(me, extra_crit) == CombatRules.Outcome.CRIT
		var amount := SpellDB.effect_value(heal, 0, _unit.profile.level, _unit.combatant) * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)
		unit.combatant.heal(roundi(amount * (1.0 + me.aura_total(SpellDB.AURA_MOD_HEALING_DONE_PERCENT) / 100.0)), crit)
	Sfx.play_at("heal", _unit.global_position)


## Mana Scorch: burns the target's mana, and it takes half the burned amount
## as damage (EffectMultipleValue, Spell::EffectPowerBurn).
func _mana_burn(spell: Dictionary, target: Combatant, extra_crit: float) -> void:
	var me := _unit.combatant
	me.enter_combat()
	if CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return
	var burned := minf(SpellDB.effect_value(spell, 0, _unit.profile.level, _unit.combatant), target.mana)
	target.mana -= burned
	var crit := CombatRules.roll_heal(me, extra_crit) == CombatRules.Outcome.CRIT
	var damage := burned * float(spell.get("EffectMultipleValue1", 0.5)) * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)
	Sfx.play_at("bolt_hit", target.body.global_position)
	target.take_damage(roundi(damage), me, crit, int(spell.get("School", 0)))


## Dread Wail: up to five enemies around the caster flee for its duration.
func _fear_around(spell: Dictionary) -> void:
	var radius := SpellDB.effect_radius(spell, 0, _unit.combatant)
	var near: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and _unit.global_position.distance_to(enemy.global_position) <= radius:
			near.append(enemy)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return _unit.global_position.distance_to(a.global_position) < _unit.global_position.distance_to(b.global_position))
	for enemy in near.slice(0, MAX_FEAR_TARGETS):
		_debuff(spell, enemy.combatant)


## Puts an aura on the target, replacing any of the same kind from this caster.
func _replace_own(spell: Dictionary, target: Combatant, same_kind: Callable, sound := true) -> void:
	var me := _unit.combatant
	for aura in target.auras.duplicate():
		if aura.caster == me and same_kind.call(aura.spell):
			target.remove_aura(int(aura.spell.Id))
	target.add_aura(spell, me)
	if sound:
		Sfx.play_at("buff", _unit.global_position)


## The active seal that has a judgement, or {}. (The first rank of Oath of
## Valor that Paladins start with has none, as in classic.)
func _judgeable_seal() -> Dictionary:
	return _unit.combatant.find_aura(func(spell: Dictionary) -> bool: return SpellDB.seal_judgement(spell) != 0)


## Unleashes the active seal's judgement on the target. Unlike classic, the
## seal stays up afterwards, and Verdict can't be cast without one.
## Judgements ignore the hit roll (TRIGGERED_IGNORE_HIT_CALCULATION).
func _judgement(target: Combatant) -> void:
	var me := _unit.combatant
	var seal := _judgeable_seal()
	if seal.is_empty():
		return
	var judgement := SpellDB.get_spell(SpellDB.seal_judgement(seal.spell))
	if judgement.is_empty():
		return
	Sfx.play_at("bolt_hit", _unit.global_position)
	if int(judgement.Effect1) == SpellDB.EFFECT_DUMMY:
		# Verdict of Dominion: Holy damage, doubled on a stunned target
		# (Judgement of Command's dummy effect in CMaNGOS).
		var strike := SpellDB.get_spell(int(judgement.EffectBasePoints1) + 1)
		_spell_damage(strike, target, 2.0 if target.is_stunned() else 1.0, false)
	elif int(judgement.Effect1) == SpellDB.EFFECT_SCHOOL_DAMAGE:
		# Judgement of Righteousness.
		var amount := SpellDB.effect_value(judgement, 0, _unit.profile.level, _unit.combatant)
		amount += _spell_power() * SpellDB.direct_coefficient(int(judgement.Id))
		var crit := CombatRules.roll_heal(me) == CombatRules.Outcome.CRIT
		_holy_damage(target, roundi(amount * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0)), crit)
	else:
		# Judgement of the Crusader and other judgement debuffs: one per Paladin.
		_replace_own(judgement, target, func(spell: Dictionary) -> bool: return str(spell.SpellName).begins_with("Verdict of"))


## A magic stun: resisted on a failed spell hit roll.
func _hammer_of_justice(spell: Dictionary, target: Combatant) -> void:
	var me := _unit.combatant
	me.enter_combat()
	if CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return
	target.add_aura(spell, me)
	target.stun(SpellDB.duration(spell, _unit.combatant))


func _holy_damage(target: Combatant, amount: int, crit: bool, school := SpellDB.School.HOLY) -> void:
	target.take_damage(amount, _unit.combatant, crit, school)


## Holy Light's script effect heals through spell 19968 (SpellEffects.cpp).
## Learns spells from a trainer. A new spell with the same name and rank text
## as a known one replaces it (Judgement teaches a second Rank 1 Seal of
## Righteousness that can be judged). Other new ranks sit alongside the old
## ones in the spellbook, but take over their action bar slots, and a spell
## new to the player goes in the first empty slot of a shown bar. Those are
## conveniences over classic, which left the old rank on the bar and new
## spells in the spellbook.
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
	var me := _unit.combatant
	if not me.is_alive():
		return ""
	if int(spell.Attributes) & SpellDB.ATTR_CANT_USE_IN_COMBAT and me.is_in_combat():
		return ERR_IN_COMBAT
	var category := int(item.spellcategory_1)
	if _item_cooldowns.get(category, 0.0) > 0.0:
		return ERR_ITEM_NOT_READY
	if not casting.is_empty():
		return ERR_IN_PROGRESS
	# Quest items: a phial filled at a moonwell, a totem at a well, a charm on
	# a body (QuestSpells).
	if QuestSpells.is_quest_spell(spell):
		return _use_quest_item(ref, item, spell)
	# Items thrown at an enemy (the Hedge-Witch Candle's fire) take your
	# target and are used up when the spell lands.
	if SpellDB.target_type(spell) == SpellDB.TARGET_ENEMY:
		var target := _unit.enemy_target()
		_item_spell = int(spell.Id)
		var problem := _find_problem(spell, target, true)
		if not problem.is_empty():
			_item_spell = 0
			return problem
		_item_ref = ref if int(item.spellcharges_1) < 0 else {}
		if SpellDB.cast_time(spell) > 0.0:
			return _cast_item_spell(spell, target)
		_finish(spell, target)
		_use_up_item()
		return ""
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
		_unit.sitting = true
	Sfx.play_at("eat", _unit.global_position)
	return ""


## Uses a quest item (QuestSpells): checks it can be used here, then casts
## its spell, using the item up afterwards if it has charges to spend.
func _use_quest_item(ref: Dictionary, item: Dictionary, spell: Dictionary) -> String:
	var problem: String = QuestSpells.problem(_unit, spell)
	if not problem.is_empty():
		return problem
	_quest_spell = int(spell.Id)
	_quest_target = QuestSpells.find_target(_unit, spell)
	_item_ref = ref if int(item.spellcharges_1) < 0 else {}
	if SpellDB.cast_time(spell) > 0.0:
		var err := _cast_item_spell(spell)
		if not err.is_empty():
			_item_ref = {}
			_quest_spell = 0
		return err
	_finish(spell, _unit.combatant)
	_use_up_item()
	return ""


## Starts an item's cast-time spell on yourself, checking the spell's category
## cooldown (an hour for the Homing Token, from CategoryRecoveryTime) and the
## global cooldown. Moving interrupts it, as for any cast.
func _cast_item_spell(spell: Dictionary, target: Combatant = null) -> String:
	if _item_cooldowns.get(_spell_category(spell), 0.0) > 0.0:
		return ERR_ITEM_NOT_READY
	if _gcd_left > 0.0:
		return ERR_NOT_READY
	if _unit.is_moving():
		return ERR_MOVING
	_unit.sitting = false
	var gcd := SpellDB.global_cooldown(spell)
	if gcd > 0.0:
		_gcd_left = gcd
		_gcd_total = gcd
	Sfx.play_at("cast", _unit.global_position)
	casting = spell
	_unit.combatant.is_casting = true
	_pushbacks = 0
	_cast_left = SpellDB.cast_time(spell)
	_cast_total = _cast_left
	_cast_target = target if target else _unit.combatant
	return ""


## Uses up one of the item whose spell just landed.
func _use_up_item() -> void:
	_item_spell = 0
	if not _item_ref.is_empty():
		Inventory.remove_one(_item_ref)
		_item_ref = {}


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


## The Homing Token's teleport: back to the start point of the race's
## starting zone (its graveyard; on this continent, else its first zone), the
## camera jumping along, and its cooldown starting once the cast lands.
func _go_home(spell: Dictionary) -> void:
	_item_cooldowns[_spell_category(spell)] = HOMING_TOKEN_COOLDOWN
	_unit.combatant.attack_target = null
	_unit.velocity = Vector3.ZERO
	var home := World.current.start_zone_here(_unit.profile.race) if World.current else null
	_unit.global_position = home.graveyard if home else AshfordVale.SPAWN
	_unit.facing = home.graveyard_facing if home else AshfordVale.SPAWN_FACING
	var camera := _unit.get_viewport().get_camera_3d() as OrbitCamera
	if camera and _unit is Player:
		camera.snap_to_target()
	Sfx.play_at("level_up", _unit.global_position)


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
		var on_bar_already := false
		for i in GameState.action_bar.size():
			var on_bar := SpellDB.get_spell(GameState.action_bar[i])
			var replaces := previous != 0 and GameState.action_bar[i] == previous
			var lower_rank: bool = on_bar.get("SpellName") == spell.SpellName and int(on_bar.get("SpellLevel", 0)) < int(spell.SpellLevel)
			if replaces or lower_rank:
				GameState.action_bar[i] = id
			if GameState.action_bar[i] != 0 and SpellDB.get_spell(GameState.action_bar[i]).get("SpellName") == spell.SpellName:
				on_bar_already = true
		# A spell new to the player goes in the first empty slot, if there is
		# one. Passives stay off the bar; Presences and stances have the stance bar.
		var empty := -1
		for slot in GameState.shown_slots():
			if GameState.action_bar[slot] == 0:
				empty = slot
				break
		if not on_bar_already and empty >= 0 and not SpellDB.is_passive(spell) and not SpellDB.is_stance_bar_spell(spell):
			GameState.action_bar[empty] = id
		learned.append(SpellDB.full_name(spell))
		# Plate Mail teaches wearing plate, Two-Handed Swords wielding them.
		for proficiency in SpellDB.proficiencies_of(spell) + ([PROFICIENCY_SPELLS[spell.SpellName]] if PROFICIENCY_SPELLS.has(spell.SpellName) else []):
			if not proficiency in GameState.proficiencies:
				GameState.proficiencies.append(proficiency)
	GameState.spells_changed.emit()
	return learned


## Mending Radiance and Quick Radiance. Boon of Radiance on the target adds
## its bonus: the first amount to Mending Radiance, the second to Quick.
func _holy_light(spell: Dictionary, target: Combatant) -> void:
	var amount := SpellDB.effect_value(spell, 0, _unit.profile.level, _unit.combatant)
	amount += _spell_power() * SpellDB.direct_coefficient(SpellDB.HOLY_LIGHT_HEAL)
	var boon := target.find_aura(func(other: Dictionary) -> bool: return str(other.SpellName).ends_with("Boon of Radiance"))
	if not boon.is_empty():
		amount += boon.amounts[0 if spell.SpellName == "Mending Radiance" else 1]
	target.heal_with_spell(amount, _unit.combatant, _talent_crit(spell), spell)


## Damage of the spell's school from its first effect: a spell hit roll
## (Resist on a miss, unless the spell always hits) and a crit roll. Returns
## whether it hit.
func _spell_damage(spell: Dictionary, target: Combatant, multiplier := 1.0, can_miss := true, extra_crit := 0.0) -> bool:
	var me := _unit.combatant
	me.enter_combat()
	if can_miss and CombatRules.roll_spell(me, target, spell) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		me.proc_event.emit(Combatant.PROC_NEGATIVE_SPELL, Combatant.PROC_EX_RESIST, target, spell, 0)
		return false
	var amount := SpellDB.effect_value(spell, 0, _unit.profile.level, _unit.combatant) + _spell_power() * SpellDB.direct_coefficient(int(spell.Id))
	# Damage talents for the spell (Scorching Light, Deepening Gloom).
	amount = SpellMods.apply(me, spell, SpellMods.DAMAGE, amount)
	var crit := not SpellDB.has_attribute_ex2(spell, SpellDB.ATTR_EX2_CANT_CRIT) and CombatRules.roll_heal(me, extra_crit + _talent_crit(spell)) == CombatRules.Outcome.CRIT
	Sfx.play_at("bolt_hit", _unit.global_position)
	var dealt := roundi(amount * multiplier * (CombatRules.SPELL_CRIT_MULTIPLIER if crit else 1.0))
	_holy_damage(target, dealt, crit, int(spell.get("School", SpellDB.School.HOLY)))
	var ex := Combatant.PROC_EX_CRIT if crit else Combatant.PROC_EX_NORMAL
	me.proc_event.emit(Combatant.PROC_NEGATIVE_SPELL, ex, target, spell, dealt)
	target.proc_event.emit(Combatant.PROC_TAKEN_NEGATIVE_SPELL, ex, me, spell, dealt)
	return true


## Radiant Jolt: its rank's damage spell on an enemy, or its heal on a friend.
func _holy_shock(spell: Dictionary, target: Combatant) -> void:
	var pair := SpellDB.holy_shock_spells(int(spell.Id))
	if pair.size() < 2:
		return
	if target.is_player:
		var heal := SpellDB.get_spell(int(pair[1]))
		target.heal_with_spell(SpellDB.effect_value(heal, 0, _unit.profile.level, _unit.combatant), _unit.combatant)
	else:
		_spell_damage(SpellDB.get_spell(int(pair[0])), target)


## Radiant Fury: Holy damage to every undead and demon within its radius.
func _holy_wrath(spell: Dictionary) -> void:
	var radius := SpellDB.effect_radius(spell, 0, _unit.combatant)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var kind := _creature_type(enemy.combatant)
		if enemy.combatant.is_alive() and kind in [SpellDB.CREATURE_UNDEAD, SpellDB.CREATURE_DEMON] \
				and _unit.global_position.distance_to(enemy.global_position) <= radius:
			_spell_damage(spell, enemy.combatant)


## Rebuke the Dead: the undead flee in fear for the duration.
func _turn_undead(spell: Dictionary, target: Combatant) -> void:
	_debuff(spell, target)


## Cleansing: removes one harmful effect of each dispel type the spell names
## (from an enemy, Unweave takes one of its own buffs).
func _dispel(spell: Dictionary, target: Combatant) -> void:
	for i in 3:
		if int(spell["Effect%d" % (i + 1)]) != SpellDB.EFFECT_DISPEL:
			continue
		var kind := int(spell["EffectMiscValue%d" % (i + 1)])
		for aura in target.auras:
			if _dispellable(aura, target) and int(aura.spell.get("Dispel", 0)) == kind:
				target.remove_aura(int(aura.spell.Id))
				break
	if not target.is_player and target.body is Enemy:
		(target.body as Enemy).provoke(_unit.combatant)
	Sfx.play_at("heal", _unit.global_position)


## Only one seal at a time.
func _apply_seal(spell: Dictionary) -> void:
	var me := _unit.combatant
	for aura in me.auras.duplicate():
		if SpellDB.is_seal(aura.spell):
			me.remove_aura(int(aura.spell.Id))
	me.add_aura(spell, me)
	Sfx.play_at("buff", _unit.global_position)


## Seal of Righteousness adds Holy damage to each white melee hit. The proc
## always hits and can't crit (its spell has ALWAYS_HIT and CANT_CRIT).
## Formula from Unit::HandleDummyAuraProc in CMaNGOS classic.
func _on_auto_attack_landed(target: Combatant) -> void:
	var seal := _unit.combatant.find_aura(func(spell: Dictionary) -> bool:
		return SpellDB.seal_of_righteousness_proc(int(spell.Id)) != 0
	)
	if seal.is_empty() or not target.is_alive():
		return
	_holy_damage(target, seal_of_righteousness_damage(seal.spell), false)


## Holy damage per hit for the equipped weapon.
func seal_of_righteousness_damage(seal: Dictionary) -> int:
	var amount := SpellDB.effect_value(seal, 0, _unit.profile.level, _unit.combatant)
	var weapon: Dictionary = _unit.profile.equipment.get(Inventory.Slot.MAIN_HAND, {})
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
## Spell power: gear has none yet; Spirit's Guidance turns Spirit into it.
func _spell_power() -> float:
	var stats := _unit.get_node_or_null("CharacterStats") as CharacterStats
	if stats == null:
		return 0.0
	return stats.stats[ClassicData.Stat.SPIRIT] * _unit.combatant.aura_total(CharacterStats.AURA_MOD_SPELL_DAMAGE_OF_STAT) / 100.0
