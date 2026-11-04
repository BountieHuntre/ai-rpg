class_name TalentProcs
extends Node
## Talents that fire from combat events (Combatant.proc_event): passive
## talents with SPELL_AURA_PROC_TRIGGER_SPELL cast their trigger spell when an
## event matches, as CMaNGOS's proc handling decides it. The event must be one
## of the talent's ProcFlags (or its spell_proc_event row's procFlags), go the
## way its procEx asks (a crit, a block; a landed hit by default), and come
## from the spells its family mask names; then its chance is rolled (procs per
## minute for weapon procs). Most trigger spells are buffs, debuffs, stuns or
## rage, applied generically; Lingering Wounds, Inner Light and Hallowed
## Recovery have their own code (UnitAuraProcHandler.cpp). Buffs from talents
## that last a number of hits (Battle Frenzy, Rising Wrath, Steadfast Guard)
## use up their charges here. Also Tooth for a Tooth and Gloomweave.
## Child of the SpellCaster.

const AURA_DUMMY := 4
const AURA_ADD_TARGET_TRIGGER := 109
const AURA_OBS_MOD_HEALTH := 20
const EFFECT_ADD_EXTRA_ATTACKS := 19
## procEx bits that say what to require (above them are server-internal flags).
const EX_OUTCOMES := 0xFFFF
const LANDED := Combatant.PROC_EX_NORMAL | Combatant.PROC_EX_CRIT
## Lingering Wounds: a share of the average weapon hit per rank, over 4 ticks.
const DEEP_WOUNDS_SHARE := 0.2
const DEEP_WOUNDS_TICKS := 4.0
## Hallowed Recovery heals this share of the hit per rank (8, 16, 25%).
const BLESSED_RECOVERY_SHARE := [0.08, 0.16, 0.25]
## Tooth for a Tooth: a share of a spell crit taken per rank, back at the caster.
const EYE_FOR_AN_EYE_SHARE := 0.15

var _unit: PlayerUnit
var _combatant: Combatant
## Talent spell id -> time its proc can fire again.
var _ready_at: Dictionary = {}


func _ready() -> void:
	_unit = get_parent().get_parent()
	_combatant = _unit.get_node("Combatant")
	_combatant.proc_event.connect(_on_proc_event)


func _on_proc_event(flags: int, ex: int, other: Combatant, spell: Dictionary, amount: int) -> void:
	_use_charges(flags, ex, spell)
	for aura in _combatant.auras.duplicate():
		if not aura.get("talent", false):
			continue
		var talent: Dictionary = aura.spell
		for i in 3:
			var kind := int(talent.get("EffectApplyAuraName%d" % (i + 1), 0))
			if kind == AURA_ADD_TARGET_TRIGGER:
				# Gloomweave: landed Shadow spells, at the talent's chance.
				var shadow := int(spell.get("School", 0)) == SpellDB.School.SHADOW
				# Its chance is the effect's amount (ProcChance is 101 on these).
				if flags & Combatant.PROC_NEGATIVE_SPELL and shadow and ex & LANDED and randf() * 100.0 < aura.amounts[i]:
					_fire(talent, i, kind, other, spell, amount)
				break
			if kind == SpellDB.AURA_PROC_TRIGGER_SPELL or kind == AURA_DUMMY:
				if _matches(talent, flags, ex, spell) and _worth_it(talent, other) and _roll(talent):
					_fire(talent, i, kind, other, spell, amount)
				break


## Spirit Harvest only counts kills that give experience.
func _worth_it(talent: Dictionary, other: Combatant) -> bool:
	if talent.SpellName != "Spirit Harvest":
		return true
	var enemy := other.body as Enemy if other else null
	return enemy != null and CombatRules.kill_xp(_unit.profile.level, enemy.level, enemy.elite) > 0


## Whether the event is one the talent answers.
func _matches(talent: Dictionary, flags: int, ex: int, spell: Dictionary) -> bool:
	var info := _proc_info(talent)
	var wanted_flags := int(info.get("flags", 0))
	if wanted_flags == 0:
		wanted_flags = int(talent.get("ProcFlags", 0))
	if wanted_flags & flags == 0:
		return false
	var wanted_ex := int(info.get("ex", 0)) & EX_OUTCOMES
	if wanted_ex != 0:
		if wanted_ex & ex == 0:
			return false
	elif ex & LANDED == 0:
		return false
	var mask := int(info.get("family_mask", 0))
	if mask != 0:
		if spell.is_empty() or int(spell.get("SpellFamilyFlags", 0)) & mask == 0:
			return false
		if int(info.get("family", 0)) != 0 and int(spell.get("SpellFamilyName", 0)) != int(info.family):
			return false
	var school_mask := int(info.get("school", 0))
	if school_mask != 0 and school_mask & (1 << int(spell.get("School", 0))) == 0:
		return false
	return true


## The proc's chance: per minute for weapon procs (scaled by swing time), else
## the row's chance or the talent's ProcChance. A cooldown keeps it from
## firing again too soon.
func _roll(talent: Dictionary) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var id := int(talent.Id)
	if now < _ready_at.get(id, 0.0):
		return false
	var info := _proc_info(talent)
	var chance := float(talent.get("ProcChance", 100))
	if float(info.get("ppm", 0.0)) > 0.0:
		chance = float(info.ppm) * _combatant.swing_interval / 60.0 * 100.0
	elif float(info.get("chance", 0.0)) > 0.0:
		chance = float(info.chance)
	if randf() * 100.0 >= chance:
		return false
	if float(info.get("cooldown", 0.0)) > 0.0:
		_ready_at[id] = now + float(info.cooldown)
	return true


func _fire(talent: Dictionary, effect: int, kind: int, other: Combatant, spell: Dictionary, amount: int) -> void:
	var me := _combatant
	var level := _unit.profile.level
	match talent.SpellName:
		"Tooth for a Tooth":
			var rank := Talents.rank_of_spell(int(talent.Id))
			if other and other.is_alive() and amount > 0:
				other.take_damage(roundi(amount * EYE_FOR_AN_EYE_SHARE * maxi(rank, 1)), me, false, SpellDB.School.HOLY)
			return
	var trigger := SpellDB.get_spell(int(talent.get("EffectTriggerSpell%d" % (effect + 1), 0)))
	if trigger.is_empty():
		return
	# Gloomweave: shadow spells leave the target more open to shadow.
	if kind == AURA_ADD_TARGET_TRIGGER:
		if other and other.is_alive():
			other.add_aura(trigger, me)
		return
	match trigger.SpellName:
		"Lingering Wounds":
			_deep_wounds(talent, other)
			return
		"Dummy Trigger":
			if talent.SpellName == "Inner Light":
				# The spell that crit costs nothing after all.
				me.mana = minf(me.mana + _caster().mana_cost(spell), me.max_mana)
			elif talent.SpellName == "Hallowed Recovery":
				_blessed_recovery(talent, amount)
			return
	# Most triggers: on yourself (buffs, rage) or on the other unit.
	var target := me if int(trigger.get("EffectImplicitTargetA1", 1)) == SpellDB.TARGET_SELF else other
	if target == null or not is_instance_valid(target) or not target.is_alive():
		return
	for i in 3:
		match int(trigger.get("Effect%d" % (i + 1), 0)):
			SpellDB.EFFECT_ENERGIZE:
				var gain := SpellDB.effect_value(trigger, i, level)
				if int(trigger.get("EffectMiscValue%d" % (i + 1), 0)) == SpellDB.POWER_RAGE:
					me.gain_rage(gain / 10.0)
				else:
					me.mana = minf(me.mana + gain, me.max_mana)
			EFFECT_ADD_EXTRA_ATTACKS:
				if me.attack_target and me.attack_target.is_alive():
					me.extra_attacks += maxi(roundi(SpellDB.effect_value(trigger, i, level)), 1)
	if SpellDB.has_effect(trigger, SpellDB.EFFECT_APPLY_AURA):
		if target != me and CombatRules.roll_spell(me, target) == CombatRules.Outcome.RESIST:
			target.avoid("Resist", me)
			return
		target.add_aura(trigger, me)
		var added := target.find_aura(func(other_spell: Dictionary) -> bool: return int(other_spell.Id) == int(trigger.Id))
		if not added.is_empty():
			added["from_talent"] = true
		if SpellDB.has_effect(trigger, SpellDB.AURA_MOD_STUN, true):
			target.stun(SpellDB.duration(trigger))
		if target.body is Enemy and target != me:
			(target.body as Enemy).provoke(me)


## Lingering Wounds: a crit makes the target bleed for 20% of your average
## weapon hit per rank over 12 s (the Deep Wound spell's 4 ticks).
func _deep_wounds(talent: Dictionary, target: Combatant) -> void:
	if target == null or not target.is_alive():
		return
	# Each rank has its own dummy spell; the bleed is linked from rank 1's.
	var first := SpellDB.get_spell(Talents.first_rank_spell(int(talent.Id)))
	var bleed := SpellDB.get_spell(SpellDB.linked_spell(int(first.get("EffectTriggerSpell1", 0))))
	if bleed.is_empty():
		return
	var rank := maxi(Talents.rank_of_spell(int(talent.Id)), 1)
	var average := (_combatant.min_damage + _combatant.max_damage) / 2.0 + _combatant.attack_power / 14.0 * _combatant.swing_interval
	target.add_aura(bleed, _combatant)
	var aura := target.find_aura(func(spell: Dictionary) -> bool: return int(spell.Id) == int(bleed.Id))
	if not aura.is_empty():
		aura.amounts[0] = average * DEEP_WOUNDS_SHARE * rank / DEEP_WOUNDS_TICKS


## Hallowed Recovery: a crit taken heals part of it back over 6 s.
func _blessed_recovery(talent: Dictionary, amount: int) -> void:
	var heal := SpellDB.get_spell(SpellDB.linked_spell(int(talent.Id)))
	if heal.is_empty() or amount <= 0:
		return
	var rank := clampi(Talents.rank_of_spell(int(talent.Id)), 1, BLESSED_RECOVERY_SHARE.size())
	var period := maxf(int(heal.get("EffectAmplitude1", 2000)) / 1000.0, 0.1)
	var ticks := maxf(SpellDB.duration(heal) / period, 1.0)
	_combatant.add_aura(heal, _combatant)
	var aura := _combatant.find_aura(func(spell: Dictionary) -> bool: return int(spell.Id) == int(heal.Id))
	if not aura.is_empty():
		aura.amounts[0] = amount * BLESSED_RECOVERY_SHARE[rank - 1] / ticks


## Buffs from talents that last a number of hits lose one when an event they
## count happens (Battle Frenzy's swings, Rising Wrath's hits, Steadfast
## Guard's blocks).
func _use_charges(flags: int, ex: int, spell: Dictionary) -> void:
	for aura in _combatant.auras.duplicate():
		if not aura.get("from_talent", false) or not aura.has("charges"):
			continue
		var buff: Dictionary = aura.spell
		if not _matches(buff, flags, ex, spell):
			continue
		aura.charges -= 1
		if aura.charges <= 0:
			_combatant.remove_aura(int(buff.Id))


## The talent's spell_proc_event row: most are only on the first rank, and
## CMaNGOS uses it for every rank.
func _proc_info(spell: Dictionary) -> Dictionary:
	var info := SpellDB.proc_info(spell)
	if info.is_empty():
		info = SpellDB.proc_info(SpellDB.get_spell(Talents.first_rank_spell(int(spell.get("Id", 0)))))
	return info


func _caster() -> SpellCaster:
	return get_parent() as SpellCaster
