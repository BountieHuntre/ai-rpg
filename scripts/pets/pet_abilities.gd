class_name PetAbilities
extends RefCounted
## A pet's abilities, by their effects (CMaNGOS's spell effects for pets):
##   School damage: melee abilities (Bite, Claw, Screech's hit) on the yellow
##   melee table; magic ones (Storm Breath) a spell's resist roll; Thunder
##   Stomp's on every enemy around it.
##   Threat: Growl adds it, Cower takes it away, Scorpion Venom with its poison.
##   Auras: on itself (Dash, Dive, Prowl, Shell Ward, Serpent Reflexes), on
##   its target (Scorpion Venom's poison), on enemies around (Screech's
##   weakness), on its owner's party (Rallying Howl).
##   Charge (Rush, for boars): it rushes in, and its triggered spell dazes.

const EFFECT_THREAT := 63
const EFFECT_CHARGE := 96
const TARGET_PARTY_AROUND := 20
const TARGET_ENEMIES_AROUND := 22
## How far area abilities reach when the data gives no radius.
const AREA_RADIUS := 8.0


static func cast(pet: Pet, spell: Dictionary, target: Combatant) -> void:
	var me := pet.combatant
	var level := me.level
	var landed := true
	for i in 3:
		var effect := int(spell.get("Effect%d" % (i + 1), 0))
		var aim := int(spell.get("EffectImplicitTargetA%d" % (i + 1), 0))
		match effect:
			SpellDB.EFFECT_SCHOOL_DAMAGE:
				var amount := SpellDB.effect_value(spell, i, level, me)
				if aim == TARGET_ENEMIES_AROUND:
					for enemy in _enemies_around(pet, spell, i):
						_damage(pet, spell, enemy, amount)
				elif target:
					landed = _damage(pet, spell, target, amount)
			EFFECT_THREAT:
				if target and target.body is Enemy and landed:
					var enemy := target.body as Enemy
					enemy.provoke(me)
					enemy.add_threat(me, SpellDB.effect_value(spell, i, level, me))
					if enemy.threat.has(me):
						enemy.threat[me] = maxf(float(enemy.threat[me]), 0.0)
			EFFECT_CHARGE:
				if target:
					var to := target.body.global_position - pet.global_position
					to.y = 0.0
					if to.length() > me.melee_range:
						pet.global_position += to.normalized() * (to.length() - me.melee_range * 0.7)
			SpellDB.EFFECT_TRIGGER_SPELL:
				# Rush's daze on its target.
				var triggered := SpellDB.get_spell(int(spell.get("EffectTriggerSpell%d" % (i + 1), 0)))
				if not triggered.is_empty() and target and target.is_alive() and landed:
					target.add_aura(triggered, me)
					if SpellDB.has_effect(triggered, SpellDB.AURA_MOD_STUN, true):
						target.stun(SpellDB.duration(triggered, me))
			SpellDB.EFFECT_APPLY_AURA, SpellDB.EFFECT_APPLY_AREA_AURA:
				if not landed:
					continue
				match aim:
					SpellDB.TARGET_SELF:
						_replace(me, spell, me)
					SpellDB.TARGET_ENEMY:
						if target and target.is_alive():
							_replace(target, spell, me)
					TARGET_ENEMIES_AROUND:
						for enemy in _enemies_around(pet, spell, i):
							_replace(enemy, spell, me)
					TARGET_PARTY_AROUND, SpellDB.TARGET_PARTY:
						for unit in _party_around(pet, spell, i):
							_replace(unit, spell, me)
	Sfx.play_at("swing", pet.global_position)


## A damaging ability's hit: melee abilities on the yellow table, magic ones a
## spell's resist roll. Returns whether it hit.
static func _damage(pet: Pet, spell: Dictionary, target: Combatant, amount: float) -> bool:
	var me := pet.combatant
	if int(spell.get("DmgClass", 0)) == 2:
		return me.strike(target, amount, true, spell)
	if CombatRules.roll_spell(me, target, spell) == CombatRules.Outcome.RESIST:
		target.avoid("Resist", me)
		return false
	target.take_damage(roundi(amount), me, false, int(spell.get("School", 0)))
	if target.body is Enemy:
		(target.body as Enemy).provoke(me)
	return true


## One of each aura from the pet on a unit: a fresh one replaces it.
static func _replace(unit: Combatant, spell: Dictionary, caster: Combatant) -> void:
	for aura in unit.auras.duplicate():
		if aura.caster == caster and aura.spell.SpellName == spell.SpellName:
			unit.remove_aura(int(aura.spell.Id), false)
	unit.add_aura(spell, caster)


static func _radius(spell: Dictionary, effect: int, pet: Pet) -> float:
	var radius := SpellDB.effect_radius(spell, effect, pet.combatant)
	return radius if radius > 0.0 else AREA_RADIUS


static func _enemies_around(pet: Pet, spell: Dictionary, effect: int) -> Array[Combatant]:
	var radius := _radius(spell, effect, pet)
	var found: Array[Combatant] = []
	for node in pet.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.global_position.distance_to(pet.global_position) <= radius:
			found.append(enemy.combatant)
	return found


## Its owner and its owner's party near it, and itself.
static func _party_around(pet: Pet, spell: Dictionary, effect: int) -> Array[Combatant]:
	var radius := _radius(spell, effect, pet)
	var found: Array[Combatant] = [pet.combatant]
	var units: Array[PlayerUnit] = [pet.owner_unit]
	if Party.has_unit(pet.owner_unit.combatant):
		units = Party.units()
	for unit in units:
		if unit.combatant.is_alive() and unit.global_position.distance_to(pet.global_position) <= radius:
			found.append(unit.combatant)
	return found
