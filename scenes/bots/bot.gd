class_name Bot
extends PlayerUnit
## A playerbot: a computer-run player character, like the playerbots of
## classic private servers. On its own it hunts creatures near its level,
## sits down to eat and drink when low, and gets back up after dying. In the
## player's party it follows, fights what the group fights (by the Playerbots
## options), and Templars heal, buff and raise the party. BotManager makes
## bots from saved profiles.

enum Command { FOLLOW, STAY }

const RUN_SPEED := 7.0
const GRAVITY := 19.29
const JUMP_SPEED := 7.96
## Seconds between decisions.
const THINK_INTERVAL := 0.25
## Yards a bot on its own looks around for creatures to hunt.
const HUNT_RANGE := 30.0
## A bot on its own leaves creatures this many levels above it alone.
const HUNT_LEVELS_ABOVE := 2
## Party bots fight creatures within this many yards of the leader.
const ASSIST_RANGE := 40.0
## Seconds before a dead bot gets back up with half its health and mana, as
## if it had run back from the graveyard. Party bots wait for the fight to end.
const REVIVE_TIME := 30.0
## Party bots further than this from the leader catch up by teleporting, when
## the Playerbots options allow it, as playerbots do.
const TELEPORT_DISTANCE := 60.0
## Sits down to eat below half health, to drink below a third of its mana,
## and stands once both are nearly full.
const REST_HEALTH := 0.5
const REST_MANA := 0.35
const REST_UNTIL := 0.95
## Playerbots eat and drink food for their level: a twentieth of health and
## mana back each second.
const REST_RATE := 0.05
const FOOD_SPELL := 433
const DRINK_SPELL := 430
## Seconds of running without getting anywhere before jumping and stepping
## aside.
const STUCK_TIME := 0.6
const SIDESTEP_TIME := 0.8
## Templars renew their Boons with this many seconds left.
const BOON_REFRESH := 30.0
## Spellcasters get Boon of Clarity (mana), everyone else Boon of Strength.
const CASTER_CLASSES := [ClassicData.CharClass.PRIEST, ClassicData.CharClass.MAGE, ClassicData.CharClass.WARLOCK]
## Presences a Templar bot keeps up, best first.
const PRESENCES := ["Bulwark Presence", "Thorned Presence", "Focused Presence"]
## Oaths a Templar bot fights with, best first.
const OATHS := ["Oath of Dominion", "Oath of Valor"]

## Set by BotManager: where bots on their own go hunting.
var manager: BotManager
var in_party := false
var command := Command.FOLLOW
## Its place in the party, which spreads the members out behind the leader.
var party_slot := 0

var _enemy: Combatant
var _friend: Combatant
var _think_left := 0.0
var _dead_for := 0.0
var _resting := false
var _rest_carry := Vector2.ZERO
var _destination := Vector3.ZERO
var _has_destination := false
var _stuck_for := 0.0
var _sidestep_left := 0.0
var _sidestep_side := 1.0
var _stay_at := Vector3.ZERO
var _roam_left := 0.0

@onready var stats: CharacterStats = $CharacterStats
@onready var progression: Progression = $Progression
@onready var spells: SpellCaster = $SpellCaster
@onready var _feedback: UnitFeedback = $UnitFeedback


func _ready() -> void:
	combatant.display_name = profile.char_name
	apply_race_look()
	combatant.faces_point = is_facing
	combatant.took_damage.connect(func(_amount: int, _source: Combatant, _crit: bool) -> void:
		sitting = false
		_resting = false
	)
	combatant.died.connect(_on_died)
	progression.leveled_up.connect(func(_level: int) -> void: learn_spells())
	learn_spells()
	combatant.health = combatant.max_health
	combatant.mana = combatant.max_mana
	_stay_at = global_position
	_think_left = randf() * THINK_INTERVAL


func enemy_target() -> Combatant:
	return _enemy


func friendly_target() -> Combatant:
	return _friend


## Knows every spell its class trains up to its level, every rank, as a
## player who kept up with their trainer.
func learn_spells() -> void:
	var known: Array[int] = [SpellDB.ATTACK]
	for id in SpellDB.start_spells(profile.race, profile.char_class):
		known.append(int(id))
	if profile.char_class == ClassicData.CharClass.PALADIN:
		for entry: Dictionary in SpellDB.trainer_list("paladin"):
			if int(entry.level) <= profile.level:
				for id in entry.spells:
					if not int(id) in known:
						known.append(int(id))
	profile.known_spells = known
	stats.refresh()


## Where the bot is and how it's doing, for the roster file, so it carries
## on from there next time: zone, position, facing, health, mana, how long
## it's been dead, a Stay order, and the buffs it cast on itself.
func saved_state() -> Dictionary:
	var p := global_position
	var auras := []
	for aura in combatant.auras:
		var ends_on_standing: bool = int(aura.spell.get("AuraInterruptFlags", 0)) & SpellDB.AURA_INTERRUPT_NOT_SEATED != 0
		if aura.caster == combatant and not ends_on_standing:
			auras.append({ "id": int(aura.spell.Id), "remaining": aura.remaining, "duration": aura.duration, "amounts": aura.amounts })
	return {
		"zone": AshfordVale.ZONE_NAME, "position": [p.x, p.y, p.z], "facing": facing,
		"health": combatant.health, "mana": combatant.mana, "dead_for": _dead_for,
		"stay": [_stay_at.x, _stay_at.y, _stay_at.z] if command == Command.STAY else [], "auras": auras,
	}


## Puts back a saved state from this zone (anything else starts afresh).
func restore_state(state: Dictionary) -> void:
	if state.get("zone", "") != AshfordVale.ZONE_NAME:
		return
	var at: Array = state.position
	global_position = Vector3(at[0], at[1], at[2])
	facing = float(state.get("facing", 0.0))
	_visual.rotation.y = facing
	for saved: Dictionary in state.get("auras", []):
		var spell := SpellDB.get_spell(int(saved.id))
		if not spell.is_empty():
			combatant.restore_aura(spell, combatant, float(saved.remaining), float(saved.duration), saved.amounts)
	combatant.mana = clampf(float(state.get("mana", combatant.max_mana)), 0.0, combatant.max_mana)
	var health := clampi(int(state.get("health", combatant.max_health)), 0, combatant.max_health)
	if health <= 0:
		combatant.health = 0
		combatant.clear_auras()
		_dead_for = float(state.get("dead_for", 0.0))
		_feedback.show_dead()
	else:
		combatant.health = health
	var stay: Array = state.get("stay", [])
	if stay.size() == 3:
		command = Command.STAY
		_stay_at = Vector3(stay[0], stay[1], stay[2])


## Fresh joins start following; a party put back from the save keeps its
## orders.
func joined_party(fresh := true) -> void:
	in_party = true
	if fresh:
		command = Command.FOLLOW
	_enemy = null
	combatant.attack_target = null
	_has_destination = false
	progression.level_cap = ClassicData.MAX_LEVEL


func left_party() -> void:
	in_party = false
	_enemy = null
	combatant.attack_target = null
	progression.level_cap = manager.max_level() if manager else ClassicData.MAX_LEVEL


## Revival, or getting back up after the wait.
func resurrect(health: int, mana: int) -> void:
	if combatant.is_alive():
		return
	combatant.health = clampi(health, 1, combatant.max_health)
	combatant.mana = clampf(mana, 0.0, combatant.max_mana)
	_feedback.reset()
	_dead_for = 0.0
	_stay_at = global_position


func _on_died() -> void:
	_dead_for = 0.0
	sitting = false
	_resting = false
	_enemy = null
	_has_destination = false


func _physics_process(delta: float) -> void:
	_visual.rotation.y = facing
	if not combatant.is_alive():
		velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()
		_dead_for += delta
		if _dead_for >= REVIVE_TIME and _may_get_up():
			resurrect(combatant.max_health / 2, int(combatant.max_mana / 2.0))
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = THINK_INTERVAL
		_think()
	if _resting:
		_rest(delta)
	_move(delta)


## Party bots stay down until the fight is over (or someone raises them).
func _may_get_up() -> bool:
	if not in_party:
		return true
	return not Party.units().any(func(unit: PlayerUnit) -> bool: return unit.combatant.is_alive() and unit.combatant.is_in_combat())


func _think() -> void:
	_enemy = _choose_enemy()
	if spells.casting.is_empty():
		_use_spells()
	if not spells.casting.is_empty():
		_has_destination = false
		return
	if _enemy:
		_resting = false
		sitting = false
		combatant.attack_target = _enemy
		var reach := combatant.melee_range * 0.8
		if combatant.distance_to(_enemy) > reach:
			_go_to(_enemy.body.global_position)
		else:
			_has_destination = false
		return
	combatant.attack_target = null
	if in_party:
		_party_idle()
	else:
		_solo_idle()


# Choosing what to fight.

func _choose_enemy() -> Combatant:
	if not in_party:
		return _solo_enemy()
	var leader := _leader()
	var mode: String = Settings.get_value("bot_assist")
	# What the leader is attacking, or has targeted and is fighting.
	if mode == "Assist My Target" and leader and leader.combatant.is_alive():
		var target := leader.combatant.attack_target
		if target == null:
			var picked := leader.targeting.target_combatant()
			var enemy := picked.body as Enemy if picked else null
			if enemy and enemy.state == Enemy.State.CHASE and _fights_group(enemy):
				target = picked
		if target and target.is_alive() and target.distance_to(leader.combatant) <= ASSIST_RANGE:
			return target
	# Creatures attacking the group (Passive only fights back for itself).
	var best: Combatant = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.state != Enemy.State.CHASE or not enemy.combatant.is_alive():
			continue
		var attacks_me := enemy.threat.has(combatant)
		if not attacks_me and (mode == "Passive" or not _fights_group(enemy)):
			continue
		if leader and enemy.global_position.distance_to(leader.global_position) > ASSIST_RANGE and not attacks_me:
			continue
		if _enemy == enemy.combatant:
			return _enemy
		if best == null or combatant.distance_to(enemy.combatant) < combatant.distance_to(best):
			best = enemy.combatant
	return best


func _fights_group(enemy: Enemy) -> bool:
	for unit in Party.units():
		if enemy.threat.has(unit.combatant):
			return true
	return false


## On its own: whatever is attacking it, then the creature it's fighting,
## then the nearest creature worth hunting, unless it needs a rest.
func _solo_enemy() -> Combatant:
	var attacker: Combatant = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.state == Enemy.State.CHASE and enemy.combatant.is_alive() and enemy.threat.has(combatant):
			if attacker == null or combatant.distance_to(enemy.combatant) < combatant.distance_to(attacker):
				attacker = enemy.combatant
	if attacker:
		return _enemy if _enemy and _enemy.is_alive() and (_enemy.body as Enemy).threat.has(combatant) else attacker
	if _enemy and _enemy.is_alive() and _can_hunt(_enemy.body as Enemy, true):
		return _enemy
	if _resting or _needs_rest():
		return null
	var best: Combatant = null
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if _can_hunt(enemy, false) and global_position.distance_to(enemy.global_position) <= HUNT_RANGE:
			if best == null or combatant.distance_to(enemy.combatant) < combatant.distance_to(best):
				best = enemy.combatant
	return best


## A creature it can take on: alive, near its level, and nobody else's.
func _can_hunt(enemy: Enemy, already_fighting: bool) -> bool:
	if enemy == null or not enemy.combatant.is_alive() or enemy.state == Enemy.State.RETURN:
		return false
	if enemy.tapped_by and is_instance_valid(enemy.tapped_by) and enemy.tapped_by != combatant:
		return false
	if not already_fighting and enemy.state == Enemy.State.CHASE:
		return false
	var level := profile.level
	return enemy.level <= level + HUNT_LEVELS_ABOVE and enemy.level > CombatRules.gray_level(level)


func _leader() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


# Out of combat.

func _needs_rest() -> bool:
	var c := combatant
	if c.is_in_combat():
		return false
	return c.health < c.max_health * REST_HEALTH or (c.max_mana > 0 and c.mana < c.max_mana * REST_MANA)


## Hunting grounds near its level, then a creature there.
func _solo_idle() -> void:
	if _resting:
		return
	if _needs_rest():
		_start_rest()
		return
	_roam_left -= THINK_INTERVAL
	var arrived := not _has_destination or global_position.distance_to(_destination) < 2.0
	if (arrived or _roam_left <= 0.0) and manager:
		_go_to(manager.hunting_spot(profile.level))
		_roam_left = 20.0


func _party_idle() -> void:
	var leader := _leader()
	if leader == null:
		return
	var distance := global_position.distance_to(leader.global_position)
	if Settings.get_value("bot_teleport") and distance > TELEPORT_DISTANCE and leader.combatant.is_alive() and leader.is_on_floor():
		_teleport_to(leader)
		return
	if command == Command.STAY:
		if global_position.distance_to(_stay_at) > 1.0:
			_go_to(_stay_at)
		elif _needs_rest() and not _resting:
			_start_rest()
		return
	var spot := _follow_spot(leader)
	if global_position.distance_to(spot) > 1.5:
		_resting = false
		sitting = false
		_go_to(spot)
	else:
		_has_destination = false
		if _needs_rest() and not _resting and not leader.is_moving():
			_start_rest()


## A place behind the leader, the members fanned out so they don't stack.
func _follow_spot(leader: Player) -> Vector3:
	var distance: float = Settings.get_value("bot_follow_distance")
	var angle := leader.facing + PI + (party_slot - 1.5) * 0.45
	return leader.global_position + Basis(Vector3.UP, angle) * Vector3.FORWARD * distance


func _teleport_to(leader: Player) -> void:
	velocity = Vector3.ZERO
	global_position = _follow_spot(leader) + Vector3.UP * 0.5
	_has_destination = false


func stay() -> void:
	command = Command.STAY
	_stay_at = global_position
	_has_destination = false


func follow() -> void:
	command = Command.FOLLOW


func _start_rest() -> void:
	_has_destination = false
	sitting = true
	_resting = true
	combatant.add_aura(SpellDB.get_spell(FOOD_SPELL), combatant)
	if combatant.max_mana > 0:
		combatant.add_aura(SpellDB.get_spell(DRINK_SPELL), combatant)


func _rest(delta: float) -> void:
	var c := combatant
	if not sitting:
		_resting = false
		return
	_rest_carry += Vector2(c.max_health, c.max_mana) * REST_RATE * delta
	var health := int(_rest_carry.x)
	var mana := int(_rest_carry.y)
	_rest_carry -= Vector2(health, mana)
	c.health = mini(c.health + health, c.max_health)
	c.mana = minf(c.mana + mana, c.max_mana)
	var full_mana := c.max_mana == 0 or c.mana >= c.max_mana * REST_UNTIL
	if c.health >= c.max_health * REST_UNTIL and full_mana:
		sitting = false
		_resting = false


# Templar spells.

func _use_spells() -> void:
	if profile.char_class != ClassicData.CharClass.PALADIN:
		return
	var me := combatant
	var fighting := me.is_in_combat()
	var group := _group_units()
	var hurt := _most_hurt(group)
	if hurt and hurt.health < hurt.max_health * 0.15 and fighting and _try("Last Rite", hurt):
		return
	if fighting and me.health < me.max_health * 0.2 and _try("Hallowed Aegis", me):
		return
	var heal_below: float = Settings.get_value("bot_heal_threshold")
	if hurt and hurt.health < hurt.max_health * heal_below:
		var quick := hurt.health < hurt.max_health * 0.35
		if (quick and _try("Quick Radiance", hurt)) or _try("Mending Radiance", hurt):
			return
	if not fighting:
		for unit in group:
			if unit != self and not unit.combatant.is_alive() and _try("Revival", unit.combatant):
				return
	if not _has_own(me, SpellDB.is_paladin_aura):
		for presence in PRESENCES:
			if _try(presence, me):
				return
	if _enemy:
		var oath := me.find_aura(func(spell: Dictionary) -> bool: return SpellDB.is_seal(spell))
		if oath.is_empty():
			for name in OATHS:
				if _try(name, me):
					return
		elif me.distance_to(_enemy) <= 10.0 and _try("Verdict", _enemy):
			return
		return
	if fighting or _resting:
		return
	for unit in group:
		var target := unit.combatant
		if not target.is_alive() or me.distance_to(target) > 30.0:
			continue
		var boon := target.find_aura(func(spell: Dictionary) -> bool: return SpellDB.is_blessing(spell))
		if boon.is_empty() or (boon.caster == me and boon.remaining < BOON_REFRESH and boon.remaining >= 0.0):
			var name := "Boon of Clarity" if unit.profile.char_class in CASTER_CLASSES else "Boon of Strength"
			if _try(name, target):
				return


## The group it looks after: the party, or itself.
func _group_units() -> Array[PlayerUnit]:
	if in_party:
		return Party.units()
	var only: Array[PlayerUnit] = [self]
	return only


## The living unit with the lowest share of health, within healing reach.
func _most_hurt(group: Array[PlayerUnit]) -> Combatant:
	var worst: Combatant = null
	for unit in group:
		var c := unit.combatant
		if not c.is_alive() or combatant.distance_to(c) > 40.0 or c.health >= c.max_health:
			continue
		if worst == null or float(c.health) / c.max_health < float(worst.health) / worst.max_health:
			worst = c
	return worst


func _has_own(target: Combatant, kind: Callable) -> bool:
	for aura in target.auras:
		if aura.caster == combatant and kind.call(aura.spell):
			return true
	return false


## Casts the best known rank of a spell at a target, if nothing stops it.
func _try(spell_name: String, target: Combatant) -> bool:
	var id := profile.best_rank(spell_name)
	if id == 0:
		return false
	var spell := SpellDB.get_spell(id)
	if SpellDB.target_type(spell) == SpellDB.TARGET_ENEMY:
		if target != _enemy:
			return false
	else:
		_friend = target
	if not target.is_alive() and not SpellCaster.is_resurrection(spell):
		return false
	if not spells.problem(id).is_empty():
		return false
	_has_destination = false
	velocity.x = 0.0
	velocity.z = 0.0
	spells.cast(id)
	return true


# Moving.

func _go_to(point: Vector3) -> void:
	_destination = point
	_has_destination = true


func _move(delta: float) -> void:
	var direction := Vector3.ZERO
	if _has_destination and not sitting and spells.casting.is_empty() and not combatant.is_stunned():
		var offset := _destination - global_position
		offset.y = 0.0
		if offset.length() > 0.3:
			direction = offset.normalized()
		else:
			_has_destination = false
	if direction != Vector3.ZERO and _sidestep_left > 0.0:
		_sidestep_left -= delta
		direction = (direction + Basis(Vector3.UP, PI / 2.0) * direction * _sidestep_side).normalized()
	var target := combatant.attack_target
	if target and is_instance_valid(target) and target.is_alive():
		_face(target.body.global_position)
	elif direction != Vector3.ZERO:
		_face(global_position + direction)
	if is_on_floor():
		velocity.x = direction.x * RUN_SPEED
		velocity.z = direction.z * RUN_SPEED
	else:
		velocity.y -= GRAVITY * delta
	var before := global_position
	move_and_slide()
	if direction == Vector3.ZERO or not is_on_floor():
		_stuck_for = 0.0
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_stuck_for = _stuck_for + delta if moved < RUN_SPEED * delta * 0.3 else 0.0
	if _stuck_for > STUCK_TIME:
		_stuck_for = 0.0
		velocity.y = JUMP_SPEED
		_sidestep_left = SIDESTEP_TIME
		_sidestep_side = [-1.0, 1.0].pick_random()


func _face(point: Vector3) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() > 0.01:
		facing = atan2(-offset.x, -offset.z)
