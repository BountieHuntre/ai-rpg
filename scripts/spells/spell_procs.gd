class_name SpellProcs
extends Node
## Spell effects that fire from combat rather than from a cast, for the
## player: Oath procs on melee hits (procs per minute and cooldowns from
## spell_proc_event), Verdict debuffs that heal or restore the attacker,
## damage shields (Thorned Presence, Boon of Refuge, Radiant Bulwark's blocks)
## and hallowed ground that burns enemies standing on it.
## Child of the SpellCaster; follows CMaNGOS classic's proc handling.

## Glowing disc shown on hallowed ground.
const GROUND_COLOR := Color(1, 0.85, 0.35, 0.35)

var _unit: PlayerUnit
var _combatant: Combatant
## Seal spell id -> time (s) its proc can fire again.
var _proc_ready_at: Dictionary = {}
## Hallowed ground: [{ spell, center, radius, amount, period, left, tick, mesh }].
var _grounds: Array[Dictionary] = []


func _ready() -> void:
	_unit = get_parent().get_parent()
	_combatant = _unit.get_node("Combatant")
	_combatant.auto_attack_landed.connect(_on_melee_hit)
	_combatant.melee_hit_taken.connect(_on_hit_taken)
	_combatant.blocked_attack.connect(_on_block)


func _physics_process(delta: float) -> void:
	if _grounds.is_empty():
		return
	for ground in _grounds.duplicate():
		ground.left -= delta
		ground.tick += delta
		while ground.tick >= ground.period and ground.left > -0.001:
			ground.tick -= ground.period
			_burn(ground)
		if ground.left <= 0.0:
			if is_instance_valid(ground.mesh):
				ground.mesh.queue_free()
			_grounds.erase(ground)


## A melee hit landed: Oaths with a proc spell may fire (Oath of Valor has its
## own code in SpellCaster), and Verdicts on the target may heal or restore you.
func _on_melee_hit(target: Combatant) -> void:
	if not target.is_alive():
		return
	var now := Time.get_ticks_msec() / 1000.0
	for aura in _combatant.auras.duplicate():
		var spell: Dictionary = aura.spell
		if not SpellDB.is_seal(spell) or int(spell.get("EffectApplyAuraName1", 0)) != SpellDB.AURA_PROC_TRIGGER_SPELL:
			continue
		var proc := SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0)))
		if proc.is_empty() or now < _proc_ready_at.get(int(spell.Id), 0.0):
			continue
		var info := SpellDB.proc_info(spell)
		if randf() * 100.0 < _proc_chance(spell, info):
			_proc_ready_at[int(spell.Id)] = now + float(info.get("cooldown", 0.0))
			_apply(proc, target)
	for aura in target.auras.duplicate():
		var debuff: Dictionary = aura.spell
		if aura.caster != _combatant or int(debuff.get("EffectApplyAuraName1", 0)) != SpellDB.AURA_PROC_TRIGGER_SPELL:
			continue
		var proc_id := SpellDB.judgement_proc_spell(int(debuff.Id))
		if proc_id != 0 and randf() * 100.0 < float(debuff.get("ProcChance", 0)):
			_apply(SpellDB.get_spell(proc_id), target)


## Procs per minute make the chance per hit scale with weapon speed, as in
## Unit::GetPPMProcChance: ppm * swing time / 60.
func _proc_chance(spell: Dictionary, info: Dictionary) -> float:
	var ppm := float(info.get("ppm", 0.0))
	if ppm > 0.0:
		return ppm * _combatant.swing_interval / 60.0 * 100.0
	if float(info.get("chance", 0.0)) > 0.0:
		return float(info.chance)
	return float(spell.get("ProcChance", 0))


## The effect of a proc spell: a heal or mana for you, a stun or Holy damage
## (a share of a weapon hit) for the target.
func _apply(spell: Dictionary, target: Combatant) -> void:
	var value := SpellDB.effect_value(spell, 0, _unit.profile.level)
	match int(spell.get("Effect1", 0)):
		SpellDB.EFFECT_HEAL:
			_combatant.heal(roundi(value), false, _combatant)
		SpellDB.EFFECT_ENERGIZE:
			_combatant.mana = minf(_combatant.mana + value, _combatant.max_mana)
		SpellDB.EFFECT_WEAPON_PERCENT_DAMAGE:
			var damage := _combatant.roll_weapon_damage() * value / 100.0
			target.take_damage(roundi(damage), _combatant, false, SpellDB.School.HOLY)
		SpellDB.EFFECT_SCHOOL_DAMAGE:
			target.take_damage(roundi(value), _combatant, false, int(spell.get("School", SpellDB.School.HOLY)))
		SpellDB.EFFECT_APPLY_AURA:
			if int(spell.get("EffectApplyAuraName1", 0)) == SpellDB.AURA_MOD_STUN:
				target.add_aura(spell, _combatant)
				target.stun(SpellDB.duration(spell))


## Struck in melee: Thorned Presence and Boon of Refuge strike back with Holy
## damage. (Radiant Bulwark's strike-back answers blocks instead.)
func _on_hit_taken(attacker: Combatant) -> void:
	if attacker == null or not attacker.is_alive():
		return
	for aura in _combatant.auras.duplicate():
		var spell: Dictionary = aura.spell
		if _blocks_only(spell):
			continue
		for i in 3:
			var kind := int(spell.get("EffectApplyAuraName%d" % (i + 1), 0))
			if kind == SpellDB.AURA_DAMAGE_SHIELD or kind == SpellDB.AURA_PROC_TRIGGER_DAMAGE:
				attacker.take_damage(roundi(aura.amounts[i]), _combatant, false, SpellDB.School.HOLY)


## Blocked a swing: Radiant Bulwark deals Holy damage back and uses a charge.
func _on_block(attacker: Combatant) -> void:
	for aura in _combatant.auras.duplicate():
		var spell: Dictionary = aura.spell
		if not _blocks_only(spell):
			continue
		for i in 3:
			if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_PROC_TRIGGER_DAMAGE and attacker.is_alive():
				attacker.take_damage(roundi(aura.amounts[i]), _combatant, false, SpellDB.School.HOLY)
		if aura.has("charges"):
			aura.charges -= 1
			if aura.charges <= 0:
				_combatant.remove_aura(int(spell.Id))


## Radiant Bulwark: a block-chance aura whose damage answers blocks.
static func _blocks_only(spell: Dictionary) -> bool:
	for i in 3:
		if int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)) == SpellDB.AURA_MOD_BLOCK_PERCENT:
			return true
	return false


## Hallows the ground at a point: enemies within the radius take the spell's
## damage every tick until it fades. A soft golden disc marks it.
func hallow_ground(spell: Dictionary, center: Vector3) -> void:
	var radius := SpellDB.effect_radius(spell)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.05
	disc.radial_segments = 24
	mesh.mesh = disc
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = GROUND_COLOR
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_unit.get_parent().add_child(mesh)
	mesh.global_position = center + Vector3.UP * 0.05
	_grounds.append({
		"spell": spell, "center": center, "radius": radius,
		"amount": SpellDB.effect_value(spell, 0, _unit.profile.level),
		"period": maxf(int(spell.get("EffectAmplitude1", 1000)) / 1000.0, 0.1),
		"left": SpellDB.duration(spell), "tick": 0.0, "mesh": mesh,
	})


func _burn(ground: Dictionary) -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var flat := Vector2(enemy.global_position.x - ground.center.x, enemy.global_position.z - ground.center.z)
		if enemy.combatant.is_alive() and flat.length() <= ground.radius:
			enemy.combatant.take_damage(roundi(ground.amount), _combatant, false, SpellDB.School.HOLY)
