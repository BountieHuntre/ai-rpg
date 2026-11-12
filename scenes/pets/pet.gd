class_name Pet
extends CharacterBody3D
## A Ranger's tamed beast (classic's hunter pet, as CMaNGOS's Pet and PetAI
## run it): the tamed creature's look, stats by its level and family
## (PetDB), focus for its abilities, and orders from its owner.
##   Orders: Follow (keeps beside its owner), Stay (holds where it is) and
##   Attack (its owner's target).
##   Stances: Aggressive (attacks enemies near its owner), Defensive (fights
##   whatever attacks it or its owner) and Passive (never fights on its own).
##   Abilities: Bite, Claw, Growl and the rest, cast when ready if set to
##   autocast; passives (Great Stamina...) are auras it always has.
##   It earns its owner's kill XP and levels up, never past its owner.
## Its record (PetDB.new_record) is what's saved: GameState.pet for the
## player's.

signal changed

## Where it keeps when following: behind and to the left of its owner.
const FOLLOW_OFFSET := Vector3(-1.6, 0.0, 1.6)
const RUN_SPEED := 7.0
const ACCELERATION := 60.0
const GRAVITY := 19.29
## Aggressive: enemies this near its owner are attacked.
const AGGRESSIVE_RADIUS := 15.0
## Too far from its owner (a teleport, a long fall): it comes back to them.
const LEASH := 60.0
## Health back a second out of combat: a share of its maximum (CMaNGOS
## regenerates pets as creatures out of combat).
const REGEN_SHARE := 0.02
const THINK := 0.25
## The hidden passive whose trigger is Frenzy's attack speed.
const FRENZY_PASSIVE := 20784

var owner_unit: PlayerUnit
var record: Dictionary = {}
var combatant: Combatant
var order := "follow"
var mode := "defensive"
## Its own target (Attack, or what it chose).
var target: Combatant
var _stay_at := Vector3.ZERO
var _think_left := 0.0
var _cooldowns: Dictionary = {}
var _visual: Node3D
var _model: Node3D
## Far from the player with its owner (Bot.set_far): ticked by its owner's
## far_tick, walking the ground without collision, as far bots do.
var _far := false
## The owner's talent ranks last applied (see _on_owner_auras).
var _owner_talents := ""
## Kindred Bond's aura on its owner, while it's out.
var _bond_id := 0


func setup(owner: PlayerUnit, pet_record: Dictionary) -> void:
	owner_unit = owner
	record = pet_record
	mode = str(record.get("mode", "defensive"))


func _ready() -> void:
	add_to_group("pets")
	collision_layer = Enemy.UNIT_LAYER
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.2
	shape.shape = capsule
	shape.position.y = 0.6
	add_child(shape)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	combatant = Combatant.new()
	combatant.name = "Combatant"
	add_child(combatant)
	combatant.is_player = true
	combatant.owner_combatant = owner_unit.combatant
	combatant.power_type = SpellDB.POWER_FOCUS
	combatant.faces_point = func(_point: Vector3) -> bool: return true
	_build_model()
	var feedback := UnitFeedback.new()
	feedback.name = "UnitFeedback"
	add_child(feedback)
	apply_stats()
	var health := int(record.get("health", -1))
	combatant.health = combatant.max_health if health < 0 else clampi(health, 1, combatant.max_health)
	combatant.mana = float(record.get("focus", PetDB.MAX_FOCUS))
	if record.get("dead", false):
		combatant.health = 0
	combatant.died.connect(func() -> void:
		record.dead = true
		target = null
		changed.emit())
	combatant.took_damage.connect(func(_amount: int, source: Combatant, _crit: bool) -> void:
		if mode != "passive" and source and source.is_alive() and target == null:
			target = source)
	owner_unit.combatant.took_damage.connect(_on_owner_hit)
	owner_unit.combatant.auras_changed.connect(_on_owner_auras)
	# Gone with its owner (a bot leaving the world).
	owner_unit.tree_exiting.connect(queue_free)
	combatant.proc_event.connect(_on_proc_event)
	_owner_talents = _talent_key()
	Targeting.mark_unit(_visual)


func _exit_tree() -> void:
	if _bond_id and is_instance_valid(owner_unit):
		owner_unit.combatant.remove_aura(_bond_id)
		_bond_id = 0


## Its stats at its level, as Pet::InitStatsForLevel works out a hunter pet's:
## pet_levelstats, the family's health, damage and armour modifiers, damage
## from its level (level - level/4 to level + level/4 every 2 seconds), and
## its passive abilities.
func apply_stats() -> void:
	var level := int(record.level)
	var stats := PetDB.level_stats(level)
	var modifiers: Array = PetDB.family(int(record.family)).get("modifiers", [1.0, 1.0, 1.0])
	var c := combatant
	c.display_name = str(record.name)
	c.level = level
	var strength := int(stats[2])
	var agility := int(stats[3])
	var stamina := int(stats[4])
	# Health: the table's, plus Stamina as a player's (the first 20 one each,
	# the rest 10), scaled by family.
	c.max_health = roundi((int(stats[0]) + CharacterStats.health_from_stamina(stamina)) * float(modifiers[0]))
	c.armor = roundi((int(stats[1]) + agility * 2) * float(modifiers[2]))
	c.min_damage = (level - level / 4.0) * float(modifiers[1])
	c.max_damage = (level + level / 4.0) * float(modifiers[1])
	c.swing_interval = PetDB.ATTACK_TIME
	c.attack_power = maxi(strength * 2 - 20, 0)
	c.melee_crit = CombatRules.NPC_CRIT
	c.dodge = CombatRules.NPC_AVOIDANCE
	c.max_mana = PetDB.MAX_FOCUS
	# Passive abilities are always on.
	for aura in c.auras.duplicate():
		if aura.get("talent", false):
			c.remove_aura(int(aura.spell.Id), false)
	for id in record.get("spells", []):
		var spell := SpellDB.get_spell(int(id))
		if SpellDB.is_passive(spell):
			c.add_passive_aura(spell)
	# Every hunter pet's hidden passives, whose amounts are its owner's pet
	# talents (Unbound Fury, Hardiness Training, Tough Hide, Beast Swiftness,
	# Beast Discipline, Wild Ferocity; Frenzy's chance is read on its crits).
	var owner_combatant := owner_unit.combatant if is_instance_valid(owner_unit) else null
	for id in SpellDB.pet_passives():
		c.add_passive_aura(SpellDB.get_spell(id), owner_combatant)
	c.max_health = roundi(c.max_health * (1.0 + c.aura_total(SpellDB.AURA_MOD_INCREASE_HEALTH_PERCENT) / 100.0))
	c.armor = roundi(c.armor * (1.0 + c.aura_total_exact(SpellDB.AURA_MOD_RESISTANCE_PCT, 1) / 100.0))
	c.melee_crit += c.aura_total(SpellDB.AURA_MOD_CRIT_PERCENT)
	c.health = mini(c.health, c.max_health)
	_update_bond()
	changed.emit()


## The owner's talent auras, to notice when they change.
func _talent_key() -> String:
	if not is_instance_valid(owner_unit):
		return ""
	var ids: Array = []
	for aura in owner_unit.combatant.auras:
		if aura.get("talent", false):
			ids.append(int(aura.spell.Id))
	ids.sort()
	return str(ids)


## Its owner's talents changed (learned, unlearned): its stats follow.
func _on_owner_auras() -> void:
	var key := _talent_key()
	if key != _owner_talents:
		_owner_talents = key
		apply_stats()


## Kindred Bond: while it's out, it and its owner regain health every 10
## seconds (the talent's pet aura, spell_pet_auras in CMaNGOS).
func _update_bond() -> void:
	if not is_instance_valid(owner_unit):
		return
	var bond_id := 0
	for aura in owner_unit.combatant.auras:
		if aura.get("talent", false) and str(aura.spell.SpellName) == "Kindred Bond":
			bond_id = SpellDB.linked_spell(int(aura.spell.Id))
	if _bond_id and bond_id != _bond_id:
		owner_unit.combatant.remove_aura(_bond_id)
		combatant.remove_aura(_bond_id)
	if bond_id:
		var bond := SpellDB.get_spell(bond_id)
		if combatant.find_aura(func(spell: Dictionary) -> bool: return int(spell.Id) == bond_id).is_empty():
			combatant.add_passive_aura(bond)
		if bond_id != _bond_id:
			owner_unit.combatant.add_aura(bond, combatant)
	_bond_id = bond_id


## Frenzy: its melee crits may speed its attacks (the passive's trigger, at
## its owner's talent's chance); Menace: its next hit stuns.
func _on_proc_event(flags: int, ex: int, other: Combatant, _spell: Dictionary, _amount: int) -> void:
	if flags & Combatant.PROC_MELEE_HIT == 0 or other == null:
		return
	if ex & Combatant.PROC_EX_CRIT and is_instance_valid(owner_unit):
		var frenzy := SpellDB.get_spell(FRENZY_PASSIVE)
		var chance := SpellMods.flat(owner_unit.combatant, frenzy, SpellMods.CHANCE_OF_SUCCESS)
		if chance > 0.0 and randf() * 100.0 < chance:
			combatant.add_aura(SpellDB.get_spell(int(frenzy.EffectTriggerSpell1)), combatant)
	if ex & (Combatant.PROC_EX_NORMAL | Combatant.PROC_EX_CRIT):
		var menace := combatant.find_aura(func(spell: Dictionary) -> bool: return str(spell.SpellName) == "Menace" and SpellDB.has_effect(spell, SpellDB.AURA_PROC_TRIGGER_SPELL, true))
		if not menace.is_empty():
			combatant.remove_aura(int(menace.spell.Id))
			var stun := SpellDB.get_spell(int(menace.spell.EffectTriggerSpell1))
			if not stun.is_empty() and other.is_alive():
				other.add_aura(stun, owner_unit.combatant)
				other.stun(SpellDB.duration(stun, owner_unit.combatant))
				if other.body is Enemy:
					(other.body as Enemy).add_threat(owner_unit.combatant, SpellDB.effect_value(stun, 0, owner_unit.profile.level))


func _build_model() -> void:
	var entry := int(record.entry)
	var look: Array = Enemy.LOOKS.get(entry, [Vector3.ONE, Color(0.6, 0.5, 0.4)])
	var color: Color = look[1]
	if Enemy.CREATURE_MODELS.has(entry):
		var kind: String = Enemy.CREATURE_MODELS[entry][0]
		_visual.scale = Vector3.ONE * (float(look[0].x) / float(Enemy.MODEL_BASE_SIZE[kind]))
		if kind in Enemy.BEASTS:
			var beast := BeastModel.new()
			beast.species = kind
			beast.colors = BeastModel.coat_colors(color, kind)
			beast.name = "Model"
			_visual.add_child(beast)
			beast.attach_creature(self, combatant)
			_model = beast
			return
	# No model of its own: the capsule on all fours.
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.4
	body.mesh = mesh
	var skin := StandardMaterial3D.new()
	skin.albedo_color = color
	body.material_override = skin
	body.rotation.x = PI / 2
	body.position = Vector3(0, 0.5, 0)
	body.name = "Body"
	_visual.add_child(body)
	_visual.scale = look[0]


## Attack: its owner's target.
func order_attack(enemy: Combatant) -> void:
	if enemy and enemy.is_alive() and combatant.is_alive():
		target = enemy


func order_follow() -> void:
	order = "follow"
	target = null


func order_stay() -> void:
	order = "stay"
	_stay_at = global_position


func set_mode(new_mode: String) -> void:
	mode = new_mode
	record.mode = new_mode
	if mode == "passive":
		target = null
	changed.emit()


## Its owner was hit: a defensive or aggressive pet turns on the attacker.
func _on_owner_hit(_amount: int, source: Combatant, _crit: bool) -> void:
	if mode == "passive" or target != null or source == null or not source.is_alive() or source == owner_unit.combatant:
		return
	if source.body is Enemy:
		target = source


## Kill XP its owner earned: the same for it, up to its owner's level
## (Pet::GivePetXP).
func give_xp(amount: int) -> void:
	if not combatant.is_alive() or amount <= 0:
		return
	var cap := owner_unit.profile.level
	if int(record.level) >= cap:
		record.xp = 0
		return
	record.xp = int(record.xp) + amount
	var leveled := false
	while int(record.level) < cap and int(record.xp) >= PetDB.xp_to_next(int(record.level)):
		record.xp = int(record.xp) - PetDB.xp_to_next(int(record.level))
		record.level = int(record.level) + 1
		leveled = true
	if int(record.level) >= cap:
		record.xp = 0
	if leveled:
		apply_stats()
		combatant.health = combatant.max_health
		Chat.system("%s has reached level %d." % [record.name, int(record.level)]) if owner_unit is Player else null
	changed.emit()


## Training points it has to spend.
func training_points_left() -> int:
	return PetDB.training_points(int(record.level)) - int(record.get("tp_used", 0))


## Its record to save, with its health and focus as they are now.
func saved_record() -> Dictionary:
	record.health = combatant.health
	record.focus = combatant.mana
	record.dead = not combatant.is_alive()
	record.mode = mode
	return record


## Its owner went far from the player, or came back near.
func set_far(far: bool) -> void:
	if far == _far:
		return
	_far = far
	set_physics_process(not far)
	combatant.set_physics_process(not far)
	if _model and _model.has_method("set_animating"):
		_model.call("set_animating", not far)


## One slow tick while far: its swings and its thinking, in a bigger step.
func far_tick(delta: float) -> void:
	combatant._physics_process(delta)
	_physics_process(delta)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_unit):
		queue_free()
		return
	for id: int in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	if not combatant.is_alive():
		velocity = Vector3.ZERO
		return
	# Beast Discipline speeds its focus (SPELL_AURA_MOD_POWER_REGEN_PERCENT).
	var focus_rate := 1.0 + combatant.aura_total(SpellDB.AURA_MOD_POWER_REGEN_PERCENT) / 100.0
	combatant.mana = minf(combatant.mana + PetDB.FOCUS_PER_SECOND * focus_rate * delta, combatant.max_mana)
	if not combatant.is_in_combat() and combatant.health < combatant.max_health:
		combatant.health = mini(combatant.health + maxi(roundi(combatant.max_health * REGEN_SHARE * delta), 1), combatant.max_health)
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK
		_think()
	var destination := _destination()
	var offset := destination - global_position
	offset.y = 0.0
	var speed := RUN_SPEED * combatant.speed_multiplier() if not combatant.is_rooted() else 0.0
	var direction := offset.normalized() if offset.length() > 0.4 and not combatant.is_stunned() else Vector3.ZERO
	var facing_at := target.body.global_position if target else global_position + direction
	if (facing_at - global_position).length() > 0.1:
		rotation.y = atan2(-(facing_at.x - global_position.x), -(facing_at.z - global_position.z))
	if _far:
		# Far: straight there over the ground, as its owner goes.
		var step := minf(speed * delta, offset.length())
		global_position += direction * step
		global_position.y = owner_unit.global_position.y
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, ACCELERATION * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	move_and_slide()


## Where it's going: its target, its post, or beside its owner.
func _destination() -> Vector3:
	if target and is_instance_valid(target) and target.is_alive():
		var at := target.body.global_position
		if global_position.distance_to(at) > combatant.melee_range * 0.8:
			return at
		return global_position
	if order == "stay":
		return _stay_at
	var owner_basis := Basis(Vector3.UP, owner_unit.facing)
	var spot := owner_unit.global_position + owner_basis * FOLLOW_OFFSET
	return spot if global_position.distance_to(spot) > 1.0 else global_position


## Picks what to fight and uses its abilities (PetAI::UpdateAI).
func _think() -> void:
	var owner_at := owner_unit.global_position
	# Lost: back beside its owner.
	if global_position.distance_to(owner_at) > LEASH:
		global_position = owner_at + Basis(Vector3.UP, owner_unit.facing) * FOLLOW_OFFSET
		target = null
	if target and (not is_instance_valid(target) or not target.is_alive() or target.body is Enemy and (target.body as Enemy).state == Enemy.State.RETURN):
		target = null
	if target == null and mode == "aggressive":
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy.combatant.is_alive() and enemy.state != Enemy.State.RETURN and enemy.is_aggressive() \
					and enemy.global_position.distance_to(owner_at) <= AGGRESSIVE_RADIUS:
				target = enemy.combatant
				break
	combatant.attack_target = target
	if target:
		combatant.enter_combat()
		_use_abilities()


## Autocast abilities, in the order it knows them, when it has the focus and
## they're ready.
func _use_abilities() -> void:
	for id in record.get("autocast", []):
		var spell := SpellDB.get_spell(int(id))
		if spell.is_empty() or SpellDB.is_passive(spell) or _cooldowns.has(int(id)):
			continue
		if cast(spell, target):
			return


## Casts one of its abilities. Returns whether it went off.
func cast(spell: Dictionary, on: Combatant) -> bool:
	var cost := SpellDB.mana_cost(spell, 0, combatant)
	if combatant.mana < cost or not combatant.is_alive() or combatant.is_stunned():
		return false
	var hostile := SpellDB.target_type(spell) == SpellDB.TARGET_ENEMY or SpellDB.has_effect(spell, SpellDB.EFFECT_SCHOOL_DAMAGE)
	if hostile:
		if on == null or not on.is_alive():
			return false
		var reach := maxf(SpellDB.spell_range(spell, combatant), combatant.melee_range)
		if combatant.distance_to(on) > reach:
			return false
	combatant.spend_mana(cost)
	var cooldown := SpellDB.cooldown(spell, combatant)
	if cooldown > 0.0:
		_cooldowns[int(spell.Id)] = cooldown
	PetAbilities.cast(self, spell, on)
	return true
