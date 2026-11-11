class_name SpellswordAbilities
extends Node
## The Spellsword's abilities, for the SpellCaster (the game's own class, not
## classic's; its data is data/classes/spellsword.json, built from its design
## by tools/class_designs/build_class_data.py). Child of the SpellCaster, as
## WarriorAbilities is:
##   Forms: Bladesong (20) and Wardweave (21), shapeshift auras with their
##   passives (SpellDB.linked_spell); Wardweave's armor from Intellect is
##   read in CharacterStats.
##   Edges: an imbue on the blade (one, or two with Twin Edge) that adds its
##   school's damage and effect to every melee hit, scaled by Bladecraft (a
##   quarter of attack power).
##   Resonance (Combatant.resonance, 0 to 5): Edged melee hits build it,
##   Release spends it, by the Edge inscribed last.
##   Every ability and talent ability by name, and the talents with rules of
##   their own (read from their auras' amounts, `_talent`).

const ERR_NO_RESONANCE := "No Resonance to release"
const ERR_NOT_NOW := "You can't do that yet"
const ERR_NO_EDGE := "Your blade has no Edge"
const FORMS := { 20: "Bladesong Form", 21: "Wardweave Form" }
const FORM_PASSIVES := ["Bladesong", "Wardweave"]
const EDGES := ["Flame Edge", "Frost Edge", "Storm Edge", "Warding Edge"]
const MAX_RESONANCE := 5
## Seconds out of combat before Resonance fades.
const RESONANCE_FADE := 10.0
## Share of attack power added to Edge damage, and to Release per Resonance.
const BLADECRAFT := 0.25
const RELEASE_PER_RESONANCE_AP := 0.05
## Wardweave Form: shields are this much stronger, and threat on top of the
## form's own multiplier for Warding Edge hits.
const WARDWEAVE_SHIELDS := 1.2
const WARDING_THREAT := 0.2
## Twin Edge: each of two Edges deals this share.
const TWIN_SHARE := 0.6
## Storm Edge's chance to arc, and how far.
const STORM_ARC_CHANCE := 20.0
const ARC_RANGE := 8.0
## Flame Burst's and Thunderclap's reach, Bulwark of Runes' threat radius.
const BURST_RADIUS := 8.0
const THUNDERCLAP_TARGETS := 3
const BULWARK_RADIUS := 10.0
## Binding Glyph: how close an enemy must come.
const GLYPH_RADIUS := 2.5
## Arc Cleave and Arc of Ruin: the cone's half angle (degrees) and targets.
const CLEAVE_HALF_ANGLE := 60.0
const CLEAVE_TARGETS := 3
const RUIN_HALF_ANGLE := 30.0
## Arcane Lance and Arc of Ruin: damage per level (their rows' DmgMultiplier1),
## plus a share of attack power, and more for each Resonance spent.
const LANCE_PER_RESONANCE := 0.2
const RUIN_PER_RESONANCE := 0.1
## Thousand Cuts and Glyph Storm strike once a second.
const TICK := 1.0
const SAP_SHARE := 0.2
## Bastion of Glyphs: the party's share it takes.
const BASTION_SHARE := 0.3

var caster: SpellCaster
var _unit: PlayerUnit
var _combatant: Combatant
## The Edge inscribed last: Release follows it.
var _last_edge := ""
var _out_of_combat := 0.0
## Reprisal is usable until this time (after a parry or block).
var _reprisal_until := 0.0
## Phase Step's extra Resonance on the next melee attack, until this time.
var _phase_until := 0.0
## Arcane Momentum's bonus on the next melee attack, until this time.
var _momentum_until := 0.0
## Binding Glyphs on the ground: [{ "at", "until", "left" }].
var _glyphs: Array[Dictionary] = []
var _tick_left := 0.0
## Party members Bastion of Glyphs guards.
var _guarded: Array[Combatant] = []


func _ready() -> void:
	caster = get_parent()
	_unit = caster.get_parent()
	_combatant = _unit.get_node("Combatant")
	_combatant.proc_event.connect(_on_proc)
	_combatant.avoided.connect(func(text: String, _source: Combatant) -> void:
		if text in ["Parry", "Block"]:
			_reprisal_until = _now() + 5.0
	)
	_combatant.blocked_attack.connect(func(_attacker: Combatant) -> void: _reprisal_until = _now() + 5.0)
	_combatant.absorbed.connect(_on_absorbed)
	if _is_spellsword():
		_combatant.damage_filter = _filter_damage


func _is_spellsword() -> bool:
	return _unit.profile.char_class == ClassicData.CharClass.SPELLSWORD


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _level() -> int:
	return _unit.profile.level


## A talent's value from its aura (its rank's amount), or 0 without it.
func _talent(talent_name: String, effect := 0) -> float:
	for aura in _combatant.auras:
		if aura.spell.SpellName == talent_name and int(aura.spell.get("Attributes", 0)) & SpellDB.ATTR_PASSIVE:
			return float(aura.amounts[effect])
	return 0.0


func _has_aura(spell_name: String) -> bool:
	return not _combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == spell_name).is_empty()


func current_form() -> int:
	for aura in _combatant.auras:
		var form := SpellDB.stance_form(aura.spell)
		if form != 0:
			return form
	return 0


func in_wardweave() -> bool:
	return current_form() == 21


func in_bladesong() -> bool:
	return current_form() == 20


## The Edges on the blade, newest last.
func edges() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for aura in _combatant.auras:
		if aura.spell.SpellName in EDGES:
			found.append(aura)
	return found


func release_edge() -> String:
	var on := edges().map(func(aura: Dictionary) -> String: return aura.spell.SpellName)
	if _last_edge in on:
		return _last_edge
	return on[-1] if not on.is_empty() else ""


func add_resonance(amount: int) -> void:
	if amount <= 0:
		return
	var total := _combatant.resonance + amount
	# Overflow: Resonance past 5 becomes mana.
	if total > MAX_RESONANCE:
		var overflow := _talent("Overflow")
		if overflow > 0.0:
			_combatant.mana = minf(_combatant.mana + _combatant.max_mana * overflow / 100.0 * (total - MAX_RESONANCE), _combatant.max_mana)
	_combatant.resonance = mini(total, MAX_RESONANCE)
	_combatant.enter_combat()


## Why a Spellsword ability can't be used now, or "".
func problem(spell: Dictionary, target: Combatant) -> String:
	var name: String = spell.SpellName
	var form := SpellDB.stance_form(spell)
	if form in FORMS and form == current_form():
		return ERR_NOT_NOW
	match name:
		"Release":
			if _combatant.resonance <= 0 and not _has_aura("Overload"):
				return ERR_NO_RESONANCE
			var edge := release_edge()
			if edge.is_empty():
				return ERR_NO_EDGE
			if edge in ["Frost Edge", "Storm Edge"]:
				return _enemy_problem(spell, _unit.enemy_target())
		"Reprisal":
			if _reprisal_until < _now():
				return ERR_NOT_NOW
		"Arc Cleave", "Sigil Flurry", "Hurl Blade", "Arcane Strike", "Thousand Cuts":
			if name == "Arc Cleave" and edges().is_empty():
				return ERR_NO_EDGE
	return ""


## The checks a harmful spell at an enemy gets, for Release's Frost and Storm.
func _enemy_problem(spell: Dictionary, target: Combatant) -> String:
	if target == null:
		return SpellCaster.ERR_NO_TARGET
	if not target.is_alive():
		return SpellCaster.ERR_DEAD_TARGET
	if _combatant.distance_to(target) > SpellDB.spell_range(spell, _combatant):
		return SpellCaster.ERR_RANGE
	if not _unit.is_facing(target.body.global_position):
		return SpellCaster.ERR_FACING
	return ""


## Mana it doesn't cost: Edges during Arcane Surge.
func costs_nothing(spell: Dictionary) -> bool:
	return spell.get("SpellName", "") in EDGES and _has_aura("Arcane Surge")


## Carries out a Spellsword ability once paid for. False for spells it
## doesn't handle.
func cast(spell: Dictionary, target: Combatant) -> bool:
	if int(spell.get("SpellFamilyName", 0)) != 12:
		return false
	var me := _combatant
	var level := _level()
	var name: String = spell.SpellName
	if SpellDB.stance_form(spell) in FORMS:
		_enter_form(spell)
		return true
	if name in EDGES:
		_inscribe(spell)
		return true
	match name:
		"Arcane Strike":
			var bonus := SpellDB.effect_value(spell, 0, level, me)
			if me.strike(target, me.roll_weapon_damage(), true, spell):
				target.take_damage(roundi(SpellMods.apply(me, spell, SpellMods.DAMAGE, bonus)), me, false, SpellDB.School.ARCANE)
				if edges().is_empty():
					add_resonance(1)
			_provoke(target)
		"Spark":
			caster._spell_damage(spell, target)
			_after_spell()
		"Release":
			_release(spell)
			_after_spell()
		"Runic Ward", "Aegis of Runes", "Bastion of Glyphs":
			_shield(spell)
		"Phase Step":
			_phase_step(spell, target)
		"Severing Sigil":
			if caster._warrior._melee_roll(target):
				target.interrupt_cast(SpellDB.duration(spell, me))
				var silence := _talent("Silencing Sigil")
				if silence > 0.0:
					_helper_aura("Sigil Silence", target, silence)
			_provoke(target)
		"Mark of Challenge":
			target.add_aura(spell, me)
			if target.body is Enemy:
				(target.body as Enemy).taunt(me)
		"Mirror Guard", "Last Sigil", "Sap Edge", "Overload":
			caster._buff(spell, me)
		"Arcane Surge":
			caster._buff(spell, me)
			var surge := _talent("Resonant Surge")
			if surge > 0.0:
				add_resonance(int(surge))
				var aura := me.find_aura(func(other: Dictionary) -> bool: return other.SpellName == "Arcane Surge")
				if not aura.is_empty():
					aura.remaining += _talent("Resonant Surge", 1)
		"Arc Cleave":
			var bonus := SpellDB.effect_value(spell, 0, level, me)
			var school := _edge_school(release_edge())
			for enemy in _enemies_in_front(SpellDB.effect_radius(spell, 0, me) if SpellDB.effect_radius(spell, 0, me) > 0.0 else 8.0, CLEAVE_HALF_ANGLE, CLEAVE_TARGETS):
				if me.strike(enemy, me.roll_weapon_damage(), true, spell):
					enemy.take_damage(roundi(SpellMods.apply(me, spell, SpellMods.DAMAGE, bonus)), me, false, school)
				_provoke(enemy)
			Sfx.play_at("swing", _unit.global_position)
		"Binding Glyph":
			var at := target.body.global_position if target else _unit.global_position
			_glyphs.append({ "at": at, "until": _now() + SpellDB.duration(spell, me), "left": int(SpellDB.effect_value(spell, 0, level, me)) + int(_talent("Glyph Mastery")) })
			Sfx.play_at("buff", at)
		"Hurl Blade":
			var damage := me.roll_weapon_damage()
			if me.strike(target, damage, false, spell) and target.body is Enemy:
				(target.body as Enemy).add_threat(me, damage * 2.0 * me.threat_multiplier())
			_provoke(target)
			Sfx.play_at("swing", target.body.global_position)
		"Challenging Glyph":
			for enemy in _enemies_near(_unit.global_position, 10.0, 99):
				enemy.add_aura(spell, me)
				(enemy.body as Enemy).taunt(me)
		"Spell Shatter":
			if caster._warrior._melee_roll(target):
				caster._dispel(spell, target)
			_provoke(target)
		"Glyph Storm":
			caster._start_channel(spell, me)
			_tick_left = 0.0
		"Sigil Flurry":
			for i in 3:
				if target.is_alive():
					me.strike(target, me.roll_weapon_damage() * SpellDB.effect_value(spell, 0, level, me) / 100.0, true, spell)
			_provoke(target)
			Sfx.play_at("swing", _unit.global_position)
		"Reprisal":
			_reprisal_until = 0.0
			var damage := me.roll_weapon_damage()
			if me.strike(target, damage, true, spell):
				add_resonance(int(SpellDB.effect_value(spell, 0, level, me)))
				if target.body is Enemy:
					(target.body as Enemy).add_threat(me, damage * 2.0 * me.threat_multiplier())
			_provoke(target)
		"Arcane Lance":
			var resonance := _spend_resonance()
			var amount := (level * float(spell.get("DmgMultiplier1", 3.0)) + me.attack_power * BLADECRAFT) * (1.0 + LANCE_PER_RESONANCE * resonance)
			_spell_hit(spell, target, amount, SpellDB.School.ARCANE)
			_after_spell()
		"Arc of Ruin":
			var resonance := _spend_resonance()
			var amount := (level * float(spell.get("DmgMultiplier1", 4.0)) + me.attack_power * BLADECRAFT) * (1.0 + RUIN_PER_RESONANCE * resonance)
			for enemy in _enemies_in_front(20.0, RUIN_HALF_ANGLE, 99):
				_spell_hit(spell, enemy, amount, SpellDB.School.ARCANE)
			_after_spell()
		"Thousand Cuts":
			caster._buff(spell, me)
			_helper_aura("Whirling Steel", me, SpellDB.duration(spell, me))
			_tick_left = 0.0
		_:
			return false
	return true


# Forms and Edges.

## A form: the other and its passive go, this one and its passive come.
## Resonance stays.
func _enter_form(spell: Dictionary) -> void:
	var me := _combatant
	for aura in me.auras.duplicate():
		var other: Dictionary = aura.spell
		if SpellDB.stance_form(other) in FORMS or other.SpellName in FORM_PASSIVES:
			me.remove_aura(int(other.Id), false)
	me.add_aura(spell, me)
	var passive := SpellDB.get_spell(SpellDB.linked_spell(int(spell.Id)))
	if not passive.is_empty():
		me.add_aura(passive, me)
	Sfx.play_at("buff", _unit.global_position)


## An Edge on the blade: the others go, unless Twin Edge keeps the newest one
## of another kind.
func _inscribe(spell: Dictionary) -> void:
	var me := _combatant
	var keep := ""
	if _talent("Twin Edge") > 0.0:
		var on := edges().filter(func(aura: Dictionary) -> bool: return aura.spell.SpellName != spell.SpellName)
		if not on.is_empty():
			keep = on[-1].spell.SpellName
	for aura in edges():
		if aura.spell.SpellName != keep:
			me.remove_aura(int(aura.spell.Id), false)
	me.add_aura(spell, me)
	_last_edge = spell.SpellName
	Sfx.play_at("buff", _unit.global_position)


static func _edge_school(edge: String) -> int:
	match edge:
		"Flame Edge":
			return SpellDB.School.FIRE
		"Frost Edge":
			return SpellDB.School.FROST
		"Storm Edge":
			return SpellDB.School.NATURE
	return SpellDB.School.ARCANE


## Every melee hit that lands: the Edges' damage and effects, Resonance, and
## the talents that ride on hits (Sap Edge, Arcane Momentum).
func _on_proc(flags: int, ex: int, other: Combatant, spell: Dictionary, amount: int) -> void:
	if flags & Combatant.PROC_KILL:
		var momentum := _talent("Momentum")
		if momentum > 0.0:
			add_resonance(int(momentum))
		return
	if flags & (Combatant.PROC_MELEE_HIT | Combatant.PROC_MELEE_ABILITY) == 0:
		return
	if ex & (Combatant.PROC_EX_NORMAL | Combatant.PROC_EX_CRIT) == 0 or other == null or not is_instance_valid(other):
		return
	var crit := ex & Combatant.PROC_EX_CRIT != 0
	var me := _combatant
	# Sap Edge: mana from damage.
	if _has_aura("Sap Edge") and amount > 0:
		me.mana = minf(me.mana + amount * SAP_SHARE, me.max_mana)
	# Arcane Momentum: the first melee hit after a spell hits harder.
	if _momentum_until > _now() and amount > 0:
		_momentum_until = 0.0
		other.take_damage(roundi(amount * _talent("Arcane Momentum") / 100.0), me, false, SpellDB.School.ARCANE)
	var on := edges()
	if on.is_empty():
		return
	for aura in on:
		_edge_hit(aura, other, crit, on.size() > 1)
	var gained := 2 if crit else 1
	if crit and in_bladesong():
		gained += 1
	if randf() * 100.0 < _talent("Resonant Steel"):
		gained += 1
	if _phase_until > _now():
		_phase_until = 0.0
		gained += 1
	add_resonance(gained)


func _edge_hit(aura: Dictionary, target: Combatant, crit: bool, twin: bool) -> void:
	var me := _combatant
	var edge: String = aura.spell.SpellName
	var damage := float(aura.amounts[0]) + me.attack_power * BLADECRAFT / 10.0
	damage *= 1.0 + _talent("Honed Sigils") / 100.0
	if twin:
		damage *= TWIN_SHARE
	if crit:
		damage *= 1.0 + _talent("Spellsteel Fury") / 100.0
	match edge:
		"Flame Edge":
			target.take_damage(roundi(damage), me, false, SpellDB.School.FIRE)
			var searing := _talent("Searing Edge")
			if searing > 0.0 and target.is_alive():
				_helper_aura("Searing Brand", target, 4.0, damage * searing / 100.0 / 2.0)
		"Frost Edge":
			target.take_damage(roundi(damage), me, false, SpellDB.School.FROST)
			if target.is_alive():
				_helper_aura("Rime Chill", target, 4.0, -30.0 - _talent("Biting Frost"))
		"Storm Edge":
			target.take_damage(roundi(damage), me, false, SpellDB.School.NATURE)
			if randf() * 100.0 < STORM_ARC_CHANCE + _talent("Stormcaller"):
				for other in _enemies_near(target.body.global_position, ARC_RANGE, 1, target):
					other.take_damage(roundi(damage), me, false, SpellDB.School.NATURE)
		"Warding Edge":
			var per_stack := damage * (WARDWEAVE_SHIELDS if in_wardweave() else 1.0)
			var shield := SpellDB.get_spell(_helper_id("Ward of the Edge"))
			var most := int(shield.get("StackAmount", 5)) + int(_talent("Bulwark Weave", 1))
			var old := me.find_aura(func(other: Dictionary) -> bool: return other.SpellName == "Ward of the Edge")
			var stacks := mini(int(old.get("stacks", 0)) + 1, most) if not old.is_empty() else 1
			var held := float(old.amounts[0]) if not old.is_empty() else 0.0
			me.add_aura(shield, me)
			var now := me.find_aura(func(other: Dictionary) -> bool: return other.SpellName == "Ward of the Edge")
			if not now.is_empty():
				now.stacks = stacks
				now.amounts[0] = minf(held + per_stack, per_stack * most)
			if target.body is Enemy:
				(target.body as Enemy).add_threat(me, damage * WARDING_THREAT * me.threat_multiplier())


# Release and the spells.

func _spend_resonance() -> int:
	var overload := _combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Overload")
	var resonance := _combatant.resonance
	if not overload.is_empty():
		_combatant.remove_aura(int(overload.spell.Id))
		resonance = MAX_RESONANCE
	_combatant.resonance = 0
	return resonance


## Release: all the Resonance, as the Edge inscribed last says.
func _release(spell: Dictionary) -> void:
	var me := _combatant
	var edge := release_edge()
	var resonance := _spend_resonance()
	var level := _level()
	var bonus := me.attack_power * RELEASE_PER_RESONANCE_AP
	match edge:
		"Flame Edge":
			var per := SpellMods.apply(me, spell, SpellMods.DAMAGE, SpellDB.effect_value(spell, 0, level, me) + bonus)
			for enemy in _enemies_near(_unit.global_position, BURST_RADIUS, 99):
				_spell_hit(spell, enemy, per * resonance, SpellDB.School.FIRE)
			Sfx.play_at("bolt_hit", _unit.global_position)
		"Frost Edge":
			var target := _unit.enemy_target()
			var per := SpellMods.apply(me, spell, SpellMods.DAMAGE, SpellDB.effect_value(spell, 1, level, me) + bonus)
			if target and _spell_hit(spell, target, per * resonance, SpellDB.School.FROST) and target.is_alive():
				_helper_aura("Rime Lance Hold", target, float(resonance))
		"Storm Edge":
			var target := _unit.enemy_target()
			var per := SpellMods.apply(me, spell, SpellMods.DAMAGE, SpellDB.effect_value(spell, 2, level, me) + bonus)
			if target:
				var struck: Array[Combatant] = [target]
				struck.append_array(_enemies_near(target.body.global_position, BURST_RADIUS, THUNDERCLAP_TARGETS, target))
				for enemy in struck:
					if _spell_hit(spell, enemy, per * resonance, SpellDB.School.NATURE):
						enemy.interrupt_cast(2.0)
		"Warding Edge":
			var per := SpellMods.apply(me, spell, SpellMods.DAMAGE, float(spell.get("ExtraValue", 20)) + bonus * 2.0)
			var amount := per * resonance * (WARDWEAVE_SHIELDS if in_wardweave() else 1.0)
			_helper_aura("Bulwark of Runes", me, 15.0, amount)
			for enemy in _enemies_near(_unit.global_position, BULWARK_RADIUS, 99):
				var creature := enemy.body as Enemy
				if creature:
					creature.add_threat(me, amount * me.threat_multiplier())
					creature.provoke(me)
			Sfx.play_at("buff", _unit.global_position)


## A spell hit of a school: the spell table's resist and crit, talents'
## damage, and the proc events, as SpellCaster._spell_damage. Returns
## whether it landed.
func _spell_hit(spell: Dictionary, target: Combatant, amount: float, school: int) -> bool:
	var me := _combatant
	me.enter_combat()
	if CombatRules.roll_spell(me, target, spell) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return false
	var crit := CombatRules.roll_heal(me, caster._talent_crit(spell)) == CombatRules.Outcome.CRIT
	var multiplier := CombatRules.SPELL_CRIT_MULTIPLIER * (1.0 + _talent("Spellsteel Fury") / 100.0) if crit else 1.0
	var dealt := roundi(amount * multiplier)
	target.take_damage(dealt, me, crit, school)
	var ex := Combatant.PROC_EX_CRIT if crit else Combatant.PROC_EX_NORMAL
	me.proc_event.emit(Combatant.PROC_NEGATIVE_SPELL, ex, target, spell, dealt)
	target.proc_event.emit(Combatant.PROC_TAKEN_NEGATIVE_SPELL, ex, me, spell, dealt)
	_provoke(target)
	return true


## After a spell: Arcane Momentum's next melee hit.
func _after_spell() -> void:
	if _talent("Arcane Momentum") > 0.0:
		_momentum_until = _now() + 6.0


## Runic Ward, Aegis of Runes and Bastion of Glyphs: shields on the caster,
## stronger in Wardweave Form. Aegis and Bastion hold a share of health.
func _shield(spell: Dictionary) -> void:
	var me := _combatant
	caster._buff(spell, me)
	var aura := me.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == int(spell.Id))
	if aura.is_empty():
		return
	var amount := float(aura.amounts[0])
	match spell.SpellName:
		"Aegis of Runes":
			amount = me.max_health * 0.3
		"Bastion of Glyphs":
			amount = me.max_health * 0.5
			_guard_party(true)
	aura.amounts[0] = amount * (WARDWEAVE_SHIELDS if in_wardweave() else 1.0)
	me.auras_changed.emit()


## Bastion of Glyphs takes a share of the party's damage while it holds.
func _guard_party(on: bool) -> void:
	for unit in _guarded:
		if is_instance_valid(unit) and unit.guardian == _combatant:
			unit.guardian = null
	_guarded.clear()
	_combatant.guardian_share = BASTION_SHARE if on else 0.0
	if not on:
		return
	for unit in caster._group_near(BULWARK_RADIUS * 3.0):
		if unit.combatant != _combatant:
			unit.combatant.guardian = _combatant
			_guarded.append(unit.combatant)


func _phase_step(spell: Dictionary, target: Combatant) -> void:
	var to := target.body.global_position - _unit.global_position
	to.y = 0.0
	var beside := target.body.global_position - to.normalized() * maxf(_combatant.melee_range * 0.6, 1.5)
	_unit.global_position = Vector3(beside.x, target.body.global_position.y, beside.z)
	_unit.velocity = Vector3.ZERO
	_unit.facing = atan2(-to.x, -to.z)
	caster._buff(spell, _combatant)
	_phase_until = _now() + SpellDB.duration(spell, _combatant)
	_combatant.attack_target = target
	Sfx.play_at("buff", _unit.global_position)


# Damage taken: Mirror Guard turns a spell back, Warding Mana pays with mana,
# Unyielding blunts area attacks (creature spells, here).

func _filter_damage(amount: int, school: int, source: Combatant) -> int:
	var me := _combatant
	if amount <= 0:
		return amount
	if school != SpellDB.School.PHYSICAL and source and is_instance_valid(source) and source != me:
		var mirror := me.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Mirror Guard")
		if not mirror.is_empty() and source.body is Enemy:
			me.remove_aura(int(mirror.spell.Id))
			me.avoid("Reflect", source)
			source.take_damage(amount, me, false, school)
			return 0
		var unyielding := _talent("Unyielding")
		if unyielding > 0.0:
			amount = roundi(amount * (1.0 - unyielding / 100.0))
	var mana_share := _talent("Warding Mana")
	if mana_share > 0.0 and in_bladesong() and me.mana > 0.0:
		var paid := minf(amount * mana_share / 100.0, me.mana)
		me.mana -= paid
		amount -= roundi(paid)
	return amount


## Runic Retaliation: shields strike back with part of what they soaked.
func _on_absorbed(amount: int, source: Combatant) -> void:
	var share := _talent("Runic Retaliation")
	if share > 0.0 and source and is_instance_valid(source) and source.is_alive() and source != _combatant:
		source.take_damage(roundi(amount * share / 100.0), _combatant, false, SpellDB.School.ARCANE)


func _physics_process(delta: float) -> void:
	if not _is_spellsword():
		return
	var me := _combatant
	# Resonance fades out of combat.
	if me.is_in_combat():
		_out_of_combat = 0.0
	elif me.resonance > 0:
		_out_of_combat += delta
		if _out_of_combat >= RESONANCE_FADE:
			me.resonance = 0
	if not _glyphs.is_empty():
		_check_glyphs()
	# Bastion's guarding ends with its shield.
	if me.guardian_share > 0.0 and not _has_aura("Bastion of Glyphs"):
		_guard_party(false)
	# Thousand Cuts and Glyph Storm strike once a second.
	var whirling := _has_aura("Thousand Cuts")
	var storming: bool = caster.channeling and caster.casting.get("SpellName", "") == "Glyph Storm"
	if not whirling and not storming:
		return
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += TICK
	if whirling:
		for enemy in _enemies_near(_unit.global_position, 8.0, 99):
			me.strike(enemy, me.roll_weapon_damage(), true, SpellDB.get_spell(_spell_id("Thousand Cuts")))
		Sfx.play_at("swing", _unit.global_position)
	if storming:
		var spell: Dictionary = caster.casting
		var per := SpellDB.effect_value(spell, 0, _level(), me)
		for enemy in _enemies_near(_unit.global_position, 10.0, 99):
			if _spell_hit(spell, enemy, per, SpellDB.School.ARCANE) and in_wardweave() and enemy.body is Enemy:
				(enemy.body as Enemy).add_threat(me, per * 2.0 * me.threat_multiplier())


func _check_glyphs() -> void:
	var now := _now()
	for glyph in _glyphs.duplicate():
		if now > float(glyph.until) or int(glyph.left) <= 0:
			_glyphs.erase(glyph)
			continue
		for enemy in _enemies_near(glyph.at, GLYPH_RADIUS, 99):
			if int(glyph.left) <= 0:
				break
			if not enemy.is_rooted():
				_helper_aura("Glyph Binding", enemy, 4.0)
				glyph.left = int(glyph.left) - 1


# Helpers.

## A helper spell's aura (Rime Chill, Bulwark of Runes...) on a unit for a
## time, its first amount set when given.
func _helper_aura(helper: String, target: Combatant, length: float, amount := INF) -> void:
	var spell := SpellDB.get_spell(_helper_id(helper))
	if spell.is_empty():
		return
	target.add_aura(spell, _combatant)
	var aura := target.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == int(spell.Id))
	if aura.is_empty():
		return
	aura.remaining = length
	aura.duration = length
	if amount != INF:
		aura.amounts[0] = amount
	if SpellDB.has_effect(spell, SpellDB.AURA_MOD_SILENCE, true):
		target.interrupt_cast(length)
	target.auras_changed.emit()


static var _ids: Dictionary = {}


## A Spellsword spell's id by name (its first rank, for helpers).
static func _helper_id(spell_name: String) -> int:
	return _spell_id(spell_name)


static func _spell_id(spell_name: String) -> int:
	if _ids.is_empty():
		for extra: Dictionary in ClassicData.class_files():
			for key: String in extra.get("spells", {}):
				var name := str(extra.spells[key].SpellName)
				if not _ids.has(name) or int(key) < int(_ids[name]):
					_ids[name] = int(key)
	return int(_ids.get(spell_name, 0))


func _provoke(target: Combatant) -> void:
	if target and is_instance_valid(target) and target.body is Enemy:
		(target.body as Enemy).provoke(_combatant)


func _enemies_near(point: Vector3, radius: float, count: int, except: Combatant = null) -> Array[Combatant]:
	return caster._warrior._enemies_near(point, radius, count, except)


## Enemies in a cone in front of the caster, nearest first.
func _enemies_in_front(radius: float, half_angle: float, count: int) -> Array[Combatant]:
	var forward := Vector3(-sin(_unit.facing), 0.0, -cos(_unit.facing))
	var found: Array[Combatant] = []
	for enemy in _enemies_near(_unit.global_position, radius, 99):
		var to := enemy.body.global_position - _unit.global_position
		to.y = 0.0
		if to.length() < 1.0 or rad_to_deg(forward.angle_to(to.normalized())) <= half_angle:
			found.append(enemy)
		if found.size() >= count:
			break
	return found
