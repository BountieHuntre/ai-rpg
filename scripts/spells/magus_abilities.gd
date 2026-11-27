class_name MagusAbilities
extends Node
## The Magus's spells (classic's Mage, as CMaNGOS runs them), for the
## SpellCaster. Child of the SpellCaster, as RangerAbilities is:
##   Bolts with a second effect (Rime Bolt's chill, Flame Bolt's and Blazing
##   Orb's burn) put it on when the damage lands.
##   Areas: Arcane Nova, Rime Burst and Searing Wave round the caster; Frost
##   Fan in a cone in front; Pillar of Flame and Hailstorm on the ground
##   where the enemy target stands (the game has no ground targeting), the
##   Pillar's flames burning on after it and Hailstorm falling while you
##   channel it.
##   Arcane Darts: a channel loosing a dart at the target every tick.
##   Arcane Renewal (Evocation): a channel that speeds mana regeneration.
##   Beastshape (Polymorph): the creature becomes a sheep, held until it
##   wears off or is hurt (Combatant.is_transformed, Enemy's model).
##   Flicker (Blink): 20 yards forward, stopped by walls, free of stuns and
##   roots. Spellbreak (Counterspell): an interrupt locking the school.
##   Conjuring: food, water and mana stones into the bags (one of each stone).
##   Frozen Vigil (Ice Block): immune and held, until it ends or is
##   cancelled. Rime Renewal (Cold Snap) ends the Rime spells' cooldowns.
##   Kindling (Combustion): each fire spell that doesn't crit adds to the
##   next one's chance, until three have.
## Talents with rules of their own: Shattering Cold (crits on frozen targets),
## Smoulder (Ignite's burn after a fire crit), Elemental Thrift (Master of
## Elements' refund), Improved Hailstorm's chill.

const MAGE_FAMILY := 3
const ERR_HAVE_ONE := "You already have one of those."
const ERR_FULL := "Inventory is full."
## Effects (CMaNGOS SpellEffects) the Magus's spells use.
static var EFFECT_CREATE_ITEM := 24
static var EFFECT_LEAP := 29
## Flicker: how far, and the step it checks the way in.
static var BLINK_STEP := 1.0
## A cone in front (Frost Fan, classic's Cone of Cold): within this angle
## either side of the facing, in degrees.
static var CONE_HALF_ANGLE := 45.0
## Kindling: each fire spell that doesn't crit adds this to the next one's
## crit chance, in percent; it ends after this many crits.
static var KINDLING_STEP := 10.0
static var KINDLING_CRITS := 3
## Smoulder (classic's Ignite): the fire crit's damage burned over this long,
## in ticks of this many seconds.
static var SMOULDER_TIME := 4.0
static var SMOULDER_TICK := 2.0
## Smoulder adds this much of a fire crit's damage a rank, and Shattering
## Cold this much crit chance a rank against frozen targets, in percent
## (classic's Ignite and Shatter; their effects name no amounts).
static var SMOULDER_PER_RANK := 8.0
static var SHATTER_PER_RANK := 10.0
## SPELL_AURA_ADD_TARGET_TRIGGER (Frostgrip's root on a chill, Improved Searing
## Touch's Searing Weakness) and SPELL_AURA_MOD_ATTACKER_SPELL_CRIT_CHANCE
## (Deepening Chill on the target).
static var AURA_ADD_TARGET_TRIGGER := 109
static var AURA_ATTACKER_SPELL_CRIT := 179
## Pillar of Flame's flames and Hailstorm: a tick every this many seconds when
## the spell names no period.
static var DEFAULT_PERIOD := 1.0

var caster: SpellCaster
var _unit: PlayerUnit
var _combatant: Combatant
## Areas burning or falling on the ground: { spell, effect, at, left, tick,
## period, channel }.
var _areas: Array[Dictionary] = []
## Arcane Darts underway: { spell, dart, target, tick, period }.
var _darts: Dictionary = {}
## The creature this Magus keeps as a sheep (one at a time).
var _sheep: Object
## Kindling: its stacks of crit chance and the crits it has left.
var _kindling := 0.0
var _kindling_crits := 0


func _ready() -> void:
	caster = get_parent()
	_unit = caster.get_parent()
	_combatant = _unit.get_node("Combatant")
	_combatant.proc_event.connect(_on_proc_event)
	# Magic Siphon: resisting a spell gives back mana.
	_combatant.avoided.connect(func(text: String, _source: Combatant) -> void:
		if text != "Resist":
			return
		var siphon := _combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Magic Siphon")
		if not siphon.is_empty():
			var back := _combatant.max_mana * Talents.rank_of_spell(int(siphon.spell.Id)) / 100.0
			_combatant.mana = minf(_combatant.mana + back, _combatant.max_mana)
			_combatant.energized.emit(roundi(back), 0, "Magic Siphon"))


func _level() -> int:
	return _unit.profile.level


static func is_magus_spell(spell: Dictionary) -> bool:
	return int(spell.get("SpellFamilyName", 0)) == MAGE_FAMILY


## Why a Magus spell can't be cast now, or "".
func problem(spell: Dictionary, _target: Combatant) -> String:
	if not is_magus_spell(spell):
		return ""
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) != EFFECT_CREATE_ITEM:
			continue
		var item := int(spell.get("EffectItemType%d" % (i + 1), 0))
		# One of each mana stone, as classic.
		if _is_mana_stone(item) and _count(item) > 0:
			return ERR_HAVE_ONE
	return ""


## Lands a Magus spell; false leaves it to the SpellCaster's own kinds.
func cast(spell: Dictionary, target: Combatant) -> bool:
	if not is_magus_spell(spell):
		return false
	match str(spell.SpellName):
		"Beastshape":
			_beastshape(spell, target)
		"Flicker":
			_flicker(spell)
		"Spellbreak":
			_spellbreak(spell, target)
		"Arcane Darts":
			_start_darts(spell, target)
		"Arcane Renewal":
			caster._buff(spell, _combatant)
			caster._start_channel(spell, _combatant)
		"Rime Renewal":
			_rime_renewal()
		"Frozen Vigil":
			_frozen_vigil(spell)
		"Kindling":
			caster._buff(spell, _combatant)
			_kindling = 0.0
			_kindling_crits = KINDLING_CRITS
		"Arcane Nova", "Rime Burst", "Searing Wave":
			_nova(spell)
		"Frost Fan":
			_cone(spell)
		"Pillar of Flame", "Hailstorm":
			_ground(spell, target)
		_:
			if SpellDB.has_effect(spell, EFFECT_CREATE_ITEM):
				_conjure(spell)
			elif SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE) and target and target != _combatant:
				_bolt(spell, target)
			else:
				return false
	return true


# Damage.

## A bolt's damage, and what rides on it (Rime Bolt's chill, Flame Bolt's burn).
func _bolt(spell: Dictionary, target: Combatant) -> void:
	if caster._spell_damage(spell, target) and target.is_alive() and SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
		_rides_on(spell, target)
	if int(spell.get("School", 0)) == SpellDB.School.FROST and target.is_alive():
		Vfx.freeze(target.body)


## The aura parts of a damaging spell, after it hit: one of each per caster.
func _rides_on(spell: Dictionary, target: Combatant) -> void:
	caster._replace_own(spell, target, func(other: Dictionary) -> bool: return other.SpellName == spell.SpellName, false)
	var enemy := target.body as Enemy
	if enemy:
		enemy.provoke(_combatant)


## Enemies within a radius of a point, alive.
func _enemies_within(at: Vector3, radius: float) -> Array[Combatant]:
	var found: Array[Combatant] = []
	for node in _unit.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.global_position.distance_to(at) <= radius:
			found.append(enemy.combatant)
	return found


## Damage, and its aura parts, on each enemy hit (areas).
func _strike(spell: Dictionary, target: Combatant) -> void:
	var hit := true
	if SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE):
		hit = caster._spell_damage(spell, target)
	elif CombatRules.roll_spell(_combatant, target, spell) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", _combatant)
		hit = false
	if hit and target.is_alive() and SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA):
		_rides_on(spell, target)
		if SpellDB.has_effect(spell, Combatant.AURA_MOD_ROOT, true):
			Vfx.freeze(target.body)
	var enemy := target.body as Enemy
	if enemy:
		enemy.provoke(_combatant)


## Arcane Nova, Rime Burst, Searing Wave: everything around the caster.
func _nova(spell: Dictionary) -> void:
	var radius := SpellDB.effect_radius(spell, 0, _combatant)
	_combatant.enter_combat()
	for enemy in _enemies_within(_unit.global_position, radius):
		_strike(spell, enemy)
	var color := Vfx.school_color(int(spell.get("School", 0)))
	Vfx.shockwave(_unit, Vector3.UP * 0.3, color, radius, 0.5)
	Vfx.school_burst(_unit, Vector3.UP * 0.8, int(spell.get("School", 0)), 16, radius * 0.5)


## Frost Fan: everything in a cone in front.
func _cone(spell: Dictionary) -> void:
	var radius := SpellDB.effect_radius(spell, 0, _combatant)
	var forward := Basis(Vector3.UP, _unit.facing) * Vector3.FORWARD
	var limit := cos(deg_to_rad(CONE_HALF_ANGLE))
	_combatant.enter_combat()
	for enemy in _enemies_within(_unit.global_position, radius):
		var way := enemy.body.global_position - _unit.global_position
		way.y = 0.0
		if way.length() < 0.5 or way.normalized().dot(forward) >= limit:
			_strike(spell, enemy)
	Vfx.school_burst(_unit, forward * radius * 0.5 + Vector3.UP * 0.8, int(spell.get("School", 0)), 20, radius * 0.4)


## Pillar of Flame and Hailstorm: on the ground where the enemy target stands
## (or ahead of you with none). The Pillar strikes at once, then burns on;
## Hailstorm falls while channelled.
func _ground(spell: Dictionary, target: Combatant) -> void:
	var at := _unit.global_position + Basis(Vector3.UP, _unit.facing) * Vector3.FORWARD * 10.0
	if target and target != _combatant and is_instance_valid(target):
		at = target.body.global_position
	_combatant.enter_combat()
	var area_effect := -1
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) == SpellDB.EFFECT_PERSISTENT_AREA_AURA:
			area_effect = i
	if SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE):
		for enemy in _enemies_within(at, SpellDB.effect_radius(spell, 0, _combatant)):
			_strike(spell, enemy)
		Vfx.impact(_unit, at - _unit.global_position + Vector3.UP * 0.5, int(spell.get("School", 0)), true)
	if area_effect < 0:
		return
	var period := int(spell.get("EffectAmplitude%d" % (area_effect + 1), 0)) / 1000.0
	if period <= 0.0:
		period = DEFAULT_PERIOD
	var channel := SpellDB.is_channeled(spell)
	_areas.append({ "spell": spell, "effect": area_effect, "at": at, "left": SpellDB.duration(spell, _combatant),
		"tick": period, "period": period, "channel": channel })
	if channel:
		caster._start_channel(spell, _combatant)


func _tick_areas(delta: float) -> void:
	for area: Dictionary in _areas.duplicate():
		var spell: Dictionary = area.spell
		var held: bool = not area.channel or (caster.channeling and int(caster.casting.get("Id", 0)) == int(spell.Id))
		area.left -= delta
		if not held or area.left <= -0.01:
			_areas.erase(area)
			continue
		area.tick -= delta
		if area.tick > 0.0:
			continue
		area.tick += area.period
		var i: int = area.effect
		var radius := SpellDB.effect_radius(spell, i, _combatant)
		var amount := SpellMods.apply(_combatant, spell, SpellMods.DOT, SpellDB.effect_value(spell, i, _level(), _combatant))
		var school := int(spell.get("School", 0))
		for enemy in _enemies_within(area.at, radius):
			enemy.take_damage(roundi(amount), _combatant, false, school)
			(enemy.body as Enemy).provoke(_combatant)
			if spell.SpellName == "Hailstorm":
				_improved_hailstorm(enemy)
		Vfx.school_burst(_unit, area.at - _unit.global_position + Vector3.UP * 1.5, school, 14, radius * 0.4)


## Improved Hailstorm: Hailstorm chills what it hits (the talent's linked
## Chilled spell, its first effect's trigger).
func _improved_hailstorm(enemy: Combatant) -> void:
	var talent := _combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Improved Hailstorm")
	if talent.is_empty():
		return
	var chill := SpellDB.get_spell(SpellDB.linked_spell(int(talent.spell.Id)))
	if not chill.is_empty() and enemy.is_alive():
		enemy.add_aura(chill, _combatant)


## Arcane Darts: a dart at the target every tick while channelled (the
## channel's periodic trigger effect, each dart its own spell).
func _start_darts(spell: Dictionary, target: Combatant) -> void:
	var dart := {}
	var period := DEFAULT_PERIOD
	for i in 3:
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_PERIODIC_TRIGGER_SPELL:
			dart = SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
			period = maxf(int(spell.get("EffectAmplitude%d" % (i + 1), 1000)) / 1000.0, 0.1)
	if dart.is_empty():
		return
	_combatant.enter_combat()
	_darts = { "spell": spell, "dart": dart, "target": target, "tick": period, "period": period }
	caster._start_channel(spell, target)


func _tick_darts(delta: float) -> void:
	if _darts.is_empty():
		return
	var spell: Dictionary = _darts.spell
	if not caster.channeling or int(caster.casting.get("Id", 0)) != int(spell.Id) or not is_instance_valid(_darts.target) 			or not (_darts.target as Combatant).is_alive():
		_darts = {}
		return
	var target: Combatant = _darts.target
	_darts.tick -= delta
	if _darts.tick > 0.0:
		return
	_darts.tick += _darts.period
	var dart: Dictionary = _darts.dart
	var flight := _unit.global_position.distance_to(target.body.global_position) / maxf(float(spell.get("Speed", 0.0)), 20.0)
	Vfx.bolt(_unit, target.body, int(spell.get("School", 0)), flight)
	get_tree().create_timer(flight, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(target) and target.is_alive():
			# The dart's damage counts the channel's spell power share, split
			# between its darts (spell_bonus_data's for the dart itself).
			caster._spell_damage(dart, target))


# Control.

## Beastshape: a spell hit roll, then the creature is a sheep (one at a time).
func _beastshape(spell: Dictionary, target: Combatant) -> void:
	if is_instance_valid(_sheep) and _sheep != target:
		(_sheep as Combatant).remove_aura(int(_held_sheep_spell().get("Id", 0)))
	if caster._debuff(spell, target):
		_sheep = target
		target.interrupt_cast()
		target.attack_target = null


func _held_sheep_spell() -> Dictionary:
	if not is_instance_valid(_sheep):
		return {}
	var aura: Dictionary = (_sheep as Combatant).find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Beastshape")
	return {} if aura.is_empty() else aura.spell


## Spellbreak: interrupts the target's spell, locking its school for the
## spell's duration.
func _spellbreak(spell: Dictionary, target: Combatant) -> void:
	_combatant.enter_combat()
	if CombatRules.roll_spell(_combatant, target, spell) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", _combatant)
		return
	target.interrupt_cast(SpellDB.duration(spell, _combatant))
	_combatant.proc_event.emit(Combatant.PROC_NEGATIVE_SPELL, Combatant.PROC_EX_NORMAL, target, spell, 0)
	var enemy := target.body as Enemy
	if enemy:
		enemy.provoke(_combatant)
	Vfx.impact(target.body, Vector3.UP * 1.2, SpellDB.School.ARCANE)


## Flicker: forward along the ground up to the spell's distance, stopping
## short of walls and steep rises; free of stuns and roots.
func _flicker(spell: Dictionary) -> void:
	var distance := 20.0
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) == EFFECT_LEAP:
			distance = maxf(SpellDB.effect_radius(spell, i, _combatant), 1.0)
	var forward := Basis(Vector3.UP, _unit.facing) * Vector3.FORWARD
	var space := _unit.get_world_3d().direct_space_state
	var at := _unit.global_position
	var travelled := 0.0
	Vfx.release(_unit, SpellDB.School.ARCANE)
	while travelled + BLINK_STEP <= distance:
		var next := at + forward * BLINK_STEP
		# A wall at chest height ends it.
		var wall := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.0, next + Vector3.UP * 1.0, SpellCaster.WORLD_LAYER)
		if not space.intersect_ray(wall).is_empty():
			break
		# The ground under the next step: no more than a step up, or off a ledge
		# down to whatever is there.
		var down := PhysicsRayQueryParameters3D.create(next + Vector3.UP * 2.0, next + Vector3.DOWN * 30.0, SpellCaster.WORLD_LAYER)
		var ground := space.intersect_ray(down)
		if ground.is_empty() or (ground.position as Vector3).y > at.y + PlayerUnit.STEP_HEIGHT * 2.0:
			break
		at = ground.position
		travelled += BLINK_STEP
	_unit.global_position = at + Vector3.UP * 0.05
	_unit.velocity = Vector3.ZERO
	_unit.reset_physics_interpolation()
	_combatant.clear_stun()
	for aura in _combatant.auras.duplicate():
		if SpellDB.has_effect(aura.spell, Combatant.AURA_MOD_ROOT, true) or SpellDB.has_effect(aura.spell, SpellDB.AURA_MOD_STUN, true):
			if aura.caster != _combatant:
				_combatant.remove_aura(int(aura.spell.Id))
	Vfx.release(_unit, SpellDB.School.ARCANE)
	Sfx.play_at("buff", _unit.global_position)


## Frozen Vigil: held in ice and immune to everything; casting it again (or
## cancelling it) lets go.
func _frozen_vigil(spell: Dictionary) -> void:
	if not _combatant.find_aura(func(other: Dictionary) -> bool: return int(other.Id) == int(spell.Id)).is_empty():
		_combatant.remove_aura(int(spell.Id))
		return
	_combatant.attack_target = null
	caster._buff(spell, _combatant)
	Vfx.freeze(_unit)


## Rime Renewal: the Magus's frost spells are ready again.
func _rime_renewal() -> void:
	for id: int in caster._cooldowns.keys():
		var other := SpellDB.get_spell(id)
		if is_magus_spell(other) and int(other.get("School", 0)) == SpellDB.School.FROST and other.SpellName != "Rime Renewal":
			caster._cooldowns.erase(id)
	Vfx.freeze(_unit)
	Sfx.play_at("buff", _unit.global_position)


# Conjuring.

## Mana stones (Mana Pearl, Amber, Topaz, Garnet): their use restores mana.
static func _is_mana_stone(item_id: int) -> bool:
	var item := ItemDB.get_item(item_id)
	return not item.is_empty() and str(item.get("name", "")).begins_with("Mana ")


func _count(item_id: int) -> int:
	if _unit is Bot:
		return (_unit as Bot).bag.count_of(item_id)
	if _unit is Player:
		return Inventory.count_item(item_id)
	return 0


## Food, water or a mana stone into the bags: the effect's amount of them.
func _conjure(spell: Dictionary) -> void:
	for i in 3:
		if int(spell.get("Effect%d" % (i + 1), 0)) != EFFECT_CREATE_ITEM:
			continue
		var item := int(spell.get("EffectItemType%d" % (i + 1), 0))
		var count := maxi(roundi(SpellDB.effect_value(spell, i, _level(), _combatant)), 1)
		if _is_mana_stone(item):
			count = 1
		if _unit is Bot:
			(_unit as Bot).bag.add(item, count)
		elif _unit is Player and Inventory.add_item(item, count) > 0:
			caster.failed.emit(ERR_FULL)
	Sfx.play_at("buff", _unit.global_position)


# Crits and procs.

## Extra crit chance for a Magus spell at a target, in percent: Kindling's
## stacks for fire, Shattering Cold against a frozen (rooted) target.
func extra_crit(spell: Dictionary, target: Combatant) -> float:
	if not is_magus_spell(spell):
		return 0.0
	var extra := 0.0
	if _kindling_crits > 0 and int(spell.get("School", 0)) == SpellDB.School.FIRE and _has_kindling():
		extra += _kindling
	if target and target.is_rooted():
		var shatter := _combatant.find_aura(func(other: Dictionary) -> bool: return other.SpellName == "Shattering Cold")
		if not shatter.is_empty():
			extra += SHATTER_PER_RANK * Talents.rank_of_spell(int(shatter.spell.Id))
	# Deepening Chill on the target: frost spells crit it more.
	if target:
		extra += target.aura_total(AURA_ATTACKER_SPELL_CRIT, 1 << int(spell.get("School", 0)))
	return extra


func _has_kindling() -> bool:
	return not _combatant.find_aura(func(spell: Dictionary) -> bool: return spell.SpellName == "Kindling").is_empty()


func _on_proc_event(flags: int, ex: int, other: Combatant, spell: Dictionary, amount: int) -> void:
	if flags & Combatant.PROC_NEGATIVE_SPELL == 0 or not is_magus_spell(spell):
		return
	if ex & (Combatant.PROC_EX_RESIST | Combatant.PROC_EX_MISS) == 0 and other and other.is_alive():
		_target_triggers(spell, other)
	if amount <= 0:
		return
	var school := int(spell.get("School", 0))
	var crit := ex & Combatant.PROC_EX_CRIT != 0
	# Kindling: fire spells that don't crit stoke it; three crits end it.
	if school == SpellDB.School.FIRE and _kindling_crits > 0 and _has_kindling():
		if crit:
			_kindling_crits -= 1
			if _kindling_crits <= 0:
				_combatant.remove_aura(int(_combatant.find_aura(func(s: Dictionary) -> bool: return s.SpellName == "Kindling").spell.Id))
				_kindling = 0.0
		else:
			_kindling += KINDLING_STEP
	if not crit:
		return
	# Smoulder (classic's Ignite): a fire crit burns on for its rank's share of
	# the damage, over SMOULDER_TIME.
	if school == SpellDB.School.FIRE and other and other.is_alive():
		var smoulder := _combatant.find_aura(func(s: Dictionary) -> bool: return s.SpellName == "Smoulder")
		if not smoulder.is_empty():
			_smoulder(other, amount * SMOULDER_PER_RANK * Talents.rank_of_spell(int(smoulder.spell.Id)) / 100.0)
	# Elemental Thrift (classic's Master of Elements): fire and frost crits
	# give back a share of the spell's mana.
	if school in [SpellDB.School.FIRE, SpellDB.School.FROST]:
		var thrift := _combatant.find_aura(func(s: Dictionary) -> bool: return s.SpellName == "Elemental Thrift")
		if not thrift.is_empty():
			var back := SpellDB.mana_cost(spell, ClassicData.base_mana(_unit.profile.char_class, _level()), _combatant) * float(thrift.amounts[0]) / 100.0
			if back > 0.0:
				_combatant.mana = minf(_combatant.mana + back, _combatant.max_mana)
				_combatant.energized.emit(roundi(back), 0, "Elemental Thrift")


## Talents that put a spell on what your spells hit (SPELL_AURA_ADD_TARGET_TRIGGER):
## Frostgrip's root on a chilling spell, Improved Searing Touch's Searing
## Weakness, each at its chance for the spells its family mask names.
func _target_triggers(spell: Dictionary, target: Combatant) -> void:
	for aura in _combatant.auras:
		var talent: Dictionary = aura.spell
		for i in 3:
			if int(talent.get("EffectApplyAuraName%d" % (i + 1), 0)) != AURA_ADD_TARGET_TRIGGER:
				continue
			var mask := int(talent.get("EffectItemType%d" % (i + 1), 0))
			if mask != 0 and mask & int(spell.get("SpellFamilyFlags", 0)) == 0:
				continue
			if randf() * 100.0 >= float(aura.amounts[i]):
				continue
			var trigger := SpellDB.get_spell(int(talent.get("EffectTriggerSpell%d" % (i + 1), 0)))
			if trigger.is_empty():
				continue
			target.add_aura(trigger, _combatant)
			if SpellDB.has_effect(trigger, Combatant.AURA_MOD_ROOT, true):
				Vfx.freeze(target.body)


## Smoulder's burn: what's left of an earlier burn adds to the new one.
func _smoulder(target: Combatant, total: float) -> void:
	var key := "smoulder_%d" % _combatant.get_instance_id()
	var left: Dictionary = target.get_meta(key, {})
	if not left.is_empty() and float(left.until) > Time.get_ticks_msec() / 1000.0:
		total += float(left.left)
	var ticks := maxi(roundi(SMOULDER_TIME / SMOULDER_TICK), 1)
	var state := { "left": total, "until": Time.get_ticks_msec() / 1000.0 + SMOULDER_TIME }
	target.set_meta(key, state)
	for n in ticks:
		get_tree().create_timer(SMOULDER_TICK * (n + 1), false).timeout.connect(func() -> void:
			if not is_instance_valid(target) or not target.is_alive() or not is_instance_valid(_combatant):
				return
			var now: Dictionary = target.get_meta(key, {})
			if now != state:
				return
			var share := float(state.left) / float(ticks - n)
			state.left = float(state.left) - share
			target.take_damage(roundi(share), _combatant, false, SpellDB.School.FIRE))


func _physics_process(delta: float) -> void:
	_tick_areas(delta)
	_tick_darts(delta)
	if _kindling_crits > 0 and not _has_kindling():
		_kindling_crits = 0
		_kindling = 0.0
