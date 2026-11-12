class_name Bot
extends PlayerUnit
## A playerbot: a computer-run player character, like the playerbots of
## classic private servers. On its own it takes quests from the quest givers,
## does them and turns them in (BotQuests), hunts creatures near its level,
## sits down to eat and drink when low, and gets back up after dying. In the
## player's party it follows, fights what the group fights (by the Playerbots
## options), and Templars heal, buff and raise the party. BotManager makes
## bots from saved profiles.

enum Command { FOLLOW, STAY }

const RUN_SPEED := 7.0
const GRAVITY := 19.29
const JUMP_SPEED := 7.96
## Seconds between decisions; bots far from the player think less often.
const THINK_INTERVAL := 0.25
const FAR_THINK_INTERVAL := 0.75
## Beyond this many yards from the player a bot walks the ground's height
## without collision, which costs far less with hundreds of bots about. The
## player never sees it up close.
static var FAR := 45.0
## Seconds between working out what its quests need and which quest giver it
## has business with.
const QUEST_CHECK := 2.0
## Yards a bot on its own looks around for creatures to hunt.
const HUNT_RANGE := 30.0
## How far away a creature attacking it can be: past its leash it gives up.
const LEASH_REACH := 70.0
## A bot on its own leaves creatures this many levels above it alone.
const HUNT_LEVELS_ABOVE := 2
## Party bots fight creatures within this many yards of the leader.
const ASSIST_RANGE := 40.0
## Seconds before a dead bot gets back up with half its health and mana, as
## if it had run back from the graveyard. Party bots wait for the fight to end.
const REVIVE_TIME := 30.0
## Party bots further than this from the leader catch up by teleporting, when
## the Playerbots options allow it, as playerbots do.
const TELEPORT_DISTANCE := 40.0
## Following bots also teleport after this many seconds of getting no closer
## while more than BEHIND_DISTANCE yards away (stuck on a wall or a tree).
const BEHIND_TIME := 4.0
const BEHIND_DISTANCE := 12.0
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
## Yards from a quest giver to talk to them, and seconds spent talking.
const NPC_REACH := 3.0
const TALK_TIME := 1.5
## Templars renew their Boons with this many seconds left.
const BOON_REFRESH := 30.0
## Spellcasters get Boon of Clarity (mana), everyone else Boon of Strength.
const CASTER_CLASSES := [ClassicData.CharClass.PRIEST, ClassicData.CharClass.MAGE, ClassicData.CharClass.WARLOCK]
## Buff categories per class for the party window, and the spells in each.
## Auto leaves the choice to the bot (as below); a spell keeps that one up;
## None keeps none.
const BUFF_CATEGORIES := {
	ClassicData.CharClass.PALADIN: ["Presence", "Oath", "Boon"],
	ClassicData.CharClass.PRIEST: ["Fortitude", "Spirit", "Warding", "Self"],
	ClassicData.CharClass.WARRIOR: ["Stance", "Shout"],
	ClassicData.CharClass.SPELLSWORD: ["Edge", "Form"],
	ClassicData.CharClass.HUNTER: ["Spirits"],
}
const CATEGORY_SPELLS := {
	"Presence": ["Bulwark Presence", "Thorned Presence", "Focused Presence", "Hallowed Presence",
		"Gloomward Presence", "Frostward Presence", "Emberward Presence"],
	"Oath": ["Oath of Dominion", "Oath of Valor", "Oath of the Vanguard", "Oath of Insight", "Oath of Mending", "Oath of Binding"],
	"Boon": ["Boon of Strength", "Boon of Clarity", "Boon of Sovereigns", "Boon of Quietude", "Boon of Radiance", "Boon of Refuge",
		"Greater Boon of Strength", "Greater Boon of Clarity", "Greater Boon of Sovereigns", "Greater Boon of Quietude",
		"Greater Boon of Radiance", "Greater Boon of Refuge"],
	"Fortitude": ["Litany of Fortitude"],
	"Spirit": ["Uplifted Spirit"],
	"Warding": ["Shadow Warding"],
	"Self": ["Inner Flame", "Umbral Guard", "Withering Touch"],
	"Stance": ["Vanguard Stance", "Bastion Stance", "Fury Stance"],
	"Shout": ["Rallying Cry"],
	"Edge": ["Flame Edge", "Frost Edge", "Storm Edge", "Warding Edge"],
	"Form": ["Bladesong Form", "Wardweave Form"],
	"Spirits": ["Hawk Spirit", "Monkey Spirit", "Cheetah Spirit", "Pack Spirit", "Beast Spirit", "Wild Spirit"],
}
## The Ranger's pet spells, from the taming quests, which bots skip: they
## know them from level 10 (unlike classic).
const RANGER_PET_SPELLS := [1515, 883, 2641, 982, 5149]
const RANGER_PET_LEVEL := 10
## A Ranger bot shoots from this far; nearer than the dead zone it fights in
## melee.
const RANGER_RANGE := 25.0
## How far a Ranger bot looks for a beast to tame, and how often.
const TAME_SEARCH := 100.0
const TAME_EVERY := 5.0
## Presences a Templar bot keeps up, best first.
const PRESENCES := ["Bulwark Presence", "Thorned Presence", "Focused Presence"]
## Oaths a Templar bot fights with, best first.
const OATHS := ["Oath of Dominion", "Oath of Valor"]
## How far from its enemy a Cleric bot with mana stands to cast.
const CASTER_RANGE := 25.0
## A Cleric bot fights from range while it has this share of its mana.
const CASTER_MANA := 0.15
## Buffs a Cleric bot keeps on its group, and the ones on itself.
const CLERIC_GROUP_BUFFS := ["Litany of Fortitude", "Uplifted Spirit"]
const CLERIC_SELF_BUFFS := ["Inner Flame", "Umbral Guard", "Withering Touch"]
## Cleric heals, biggest last: the bot casts the first it can.
const CLERIC_HEALS := ["Greater Mending", "Mending", "Lesser Mending"]

## Set by BotManager: where bots on their own go hunting.
## Far from the player, the BotManager ticks the bot itself, a slice of the
## far bots each frame, in bigger steps: its nodes' own per-frame work is
## switched off.
func set_far(far: bool) -> void:
	if far == _far:
		return
	_far = far
	# Far bots walk through walls: one that comes near standing in one steps
	# out to the nearest open place.
	if not far and manager and combatant.is_alive():
		global_position = manager.paths.free_spot(global_position)
		_detour.clear()
	for node: Node in [self, combatant, stats, spells, spells.get_node_or_null("SpellProcs")]:
		if node:
			node.set_physics_process(not far)
	_feedback.set_process(not far)
	if model:
		model.set_animating(not far)
	if pet and is_instance_valid(pet):
		pet.set_far(far)


## One slow tick for a far bot: what its nodes would do over `delta` seconds.
func far_tick(delta: float) -> void:
	combatant._physics_process(delta)
	stats._physics_process(delta)
	spells._physics_process(delta)
	_physics_process(delta)
	if pet and is_instance_valid(pet):
		pet.far_tick(delta)


## Brought back to life: raised by a spell, or got up after the wait.
signal revived(raised: bool)
## Reached the player it was walking to (to trade).
signal arrived

var manager: BotManager
## What it remembers, for what it says: { "killer", "place", "time" } of its
## last death, { "title", "time" } of the last quest it handed in, and the
## creature entry it last killed.
var last_death := {}
var last_quest_done := {}
var last_kill := 0
var _last_attacker := ""
## Its quest log, saved in its roster entry.
var quests := BotQuests.new()
## Its loot and money, for trading; saved in its roster entry.
var bag := BotBag.new()
## Standing still for a trade with the player.
var trading := false
## Walking over to the player (to trade), until this time (seconds).
var _coming_until := 0.0
## Yards from the player that count as there, and how long it keeps trying.
const COME_REACH := 4.0
const COME_TIME := 120.0
var in_party := false
var command := Command.FOLLOW
## How it picks fights in a party ("Assist", "Defend" or "Passive"), or "" for
## the Party Bots Attack option. Set from the party bar (PartyBar).
var behavior := ""
const BEHAVIORS := ["Assist", "Defend", "Passive"]
## The role it plays, set from the party bar: "Tank", "Healer", "Damage", or
## "" for its class's usual one (current_role). Its talents follow it.
var role := ""
const CLASS_ROLES := {
	ClassicData.CharClass.WARRIOR: ["Tank", "Damage"],
	ClassicData.CharClass.PALADIN: ["Tank", "Healer", "Damage"],
	ClassicData.CharClass.PRIEST: ["Healer", "Damage"],
	ClassicData.CharClass.SPELLSWORD: ["Tank", "Damage"],
}
## Below this share of health, a bot that isn't the healer still heals.
const EMERGENCY_HEAL := 0.35
## Which buff it keeps up in each of its class's categories (BUFF_CATEGORIES):
## "Auto" (its own judgement), "None", or a spell's name.
var buff_choices := {}
## Spells are known up to this level: a bot on its own trains as it levels,
## a party bot when the player takes it to its trainer (train()). 0 is its level.
var trained_level := 0
## Its level before the last level-up (several can come at once).
var _level_before := 1
## A creature it was told to attack, before anything else.
var _ordered_target: Combatant
## An errand the party window sent it on: { "kind": "sell" or "train", "npc",
## "all" (sell everything, not only junk) }.
var _errand := {}
## Its place in the party, which spreads the members out behind the leader.
var party_slot := 0

var _enemy: Combatant
var _friend: Combatant
var _think_left := 0.0
var _dead_for := 0.0
var _resting := false
## How close a bot must pass a vendor to sell its trash.
const VENDOR_REACH := 15.0
var _rest_carry := Vector2.ZERO
var _destination := Vector3.ZERO
var _has_destination := false
## Waypoints to the destination, through gates (BotManager.route).
var _route: Array[Vector3] = []
var _stuck_for := 0.0
## Seconds a following bot has gone without closing in on the leader.
var _behind_for := 0.0
var _last_leader_distance := 0.0
var _sidestep_left := 0.0
## Waypoints round something in the way (BotPaths.detour), walked before the
## route; and when it's given up on.
var _detour: Array[Vector3] = []
## Where the leg to the route's next waypoint began.
var _leg_start := Vector3.ZERO
var _detour_until := 0.0
## Seconds a detour may take before the bot looks again.
const DETOUR_TIME := 20.0
var _sidestep_side := 1.0
var _stay_at := Vector3.ZERO
var _roam_left := 0.0
var _talk_left := 0.0
## Creatures its quests still need, and the quest giver it has business with,
## worked out every QUEST_CHECK seconds.
var _wanted: Array[int] = []
var _business: Npc
var _quest_check_left := 0.0
## The place an exploration quest sends it to, and the game object (a
## Bundle of Wood) holding an item its quests need, worked out with the rest.
var _explore := ""
var _chest: GameObject
var _far := false
## When the BotManager last ticked it while far (BotManager.far_schedule).
var far_clock := 0.0
## A Ranger's pet record while it isn't out (RangerAbilities keeps it here;
## out, the pet holds it), saved in its roster entry.
var pet_record: Dictionary = {}
## A beast a Ranger bot is going to tame, and when it next looks for one.
var _tame_target: Enemy
var _tame_search_left := 0.0


@onready var stats: CharacterStats = $CharacterStats
@onready var progression: Progression = $Progression
@onready var spells: SpellCaster = $SpellCaster
@onready var _feedback: UnitFeedback = $UnitFeedback


func _ready() -> void:
	combatant.display_name = profile.char_name
	apply_race_look()
	combatant.faces_point = is_facing
	combatant.took_damage.connect(func(_amount: int, source: Combatant, _crit: bool) -> void:
		sitting = false
		_resting = false
		if source and is_instance_valid(source):
			_last_attacker = source.display_name
	)
	combatant.died.connect(_on_died)
	progression.leveled_up.connect(_on_leveled_up)
	_level_before = profile.level
	learn_spells()
	combatant.health = combatant.max_health
	combatant.mana = combatant.max_mana if combatant.has_mana() else 0.0
	_stay_at = global_position
	_think_left = randf() * THINK_INTERVAL


func enemy_target() -> Combatant:
	return _enemy


func friendly_target() -> Combatant:
	return _friend


## Knows every spell its class trains up to its level, every rank, as a
## player who kept up with their trainer, and spends its talent points
## (Talents.spend_for_bot). Later ranks of talent abilities need the talent.
func learn_spells() -> void:
	var known: Array[int] = [SpellDB.ATTACK, SpellDB.SHOOT]
	for id in SpellDB.start_spells(profile.race, profile.char_class):
		known.append(int(id))
	profile.known_spells = known
	profile.talents = {}
	Talents.spend_for_bot(profile, Talents.bot_trees(profile.char_class, current_role()))
	# By level, so each rank comes after the one before it; up to the level
	# it has trained to.
	var up_to := profile.level if trained_level <= 0 else mini(trained_level, profile.level)
	var list := SpellDB.class_trainer_list(profile.char_class, profile.race)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.level) < int(b.level))
	for entry: Dictionary in list:
		if int(entry.level) > up_to:
			continue
		var previous := SpellDB.previous_rank(int(entry.spells[0]))
		if previous != 0 and not previous in known:
			continue
		for id in entry.spells:
			if not int(id) in known:
				known.append(int(id))
	if profile.char_class == ClassicData.CharClass.HUNTER and up_to >= RANGER_PET_LEVEL:
		for id: int in RANGER_PET_SPELLS:
			if not id in known:
				known.append(id)
	profile.known_spells = known
	# Weapon skills its class may learn, as from the Weapon Master.
	for entry: Dictionary in SpellDB.trainer_list(SpellDB.WEAPON_TRAINER, profile.race, profile.char_class):
		if int(entry.level) <= profile.level:
			for id in entry.spells:
				for proficiency in SpellDB.proficiencies_of(SpellDB.get_spell(int(id))):
					if not proficiency in profile.proficiencies:
						profile.proficiencies.append(proficiency)
	stats.refresh()


## Where the bot is and how it's doing, for the roster file, so it carries
## on from there next time: zone, position, facing, health, mana, how long
## it's been dead, a Stay order, and the buffs it cast on itself.
func saved_state() -> Dictionary:
	var p := global_position
	# Its buffs, its own and ones the player or other bots put on it, as the
	# player's are saved.
	var auras := combatant.saved_auras()
	return {
		"zone": manager.zone_name_at(p) if manager else AshfordVale.ZONE_NAME, "position": [p.x, p.y, p.z], "facing": facing,
		"health": combatant.health, "mana": combatant.mana, "dead_for": _dead_for,
		"stay": [_stay_at.x, _stay_at.y, _stay_at.z] if command == Command.STAY else [], "auras": auras,
		"item_cooldowns": spells.saved_item_cooldowns(),
		"behavior": behavior, "buffs": buff_choices, "trained_level": trained_level, "role": role,
		"pet": pet.saved_record() if pet and is_instance_valid(pet) else pet_record,
	}


## Puts back a saved state from a zone in the world (anything else starts
## afresh).
func restore_state(state: Dictionary) -> void:
	if manager == null or not manager.has_zone(str(state.get("zone", ""))):
		return
	var at: Array = state.position
	global_position = Vector3(at[0], at[1], at[2])
	facing = float(state.get("facing", 0.0))
	_visual.rotation.y = facing
	combatant.restore_saved_auras(state.get("auras", []))
	spells.restore_item_cooldowns(state.get("item_cooldowns", {}))
	combatant.mana = clampf(float(state.get("mana", combatant.max_mana)), 0.0, combatant.max_mana)
	var health := clampi(int(state.get("health", combatant.max_health)), 0, combatant.max_health)
	if health <= 0:
		combatant.health = 0
		combatant.clear_auras()
		_dead_for = float(state.get("dead_for", 0.0))
		_feedback.show_dead()
	else:
		combatant.health = health
	behavior = str(state.get("behavior", ""))
	role = str(state.get("role", ""))
	var buffs: Variant = state.get("buffs", {})
	buff_choices = buffs if buffs is Dictionary else {}
	trained_level = int(state.get("trained_level", 0))
	if trained_level > 0 or not role.is_empty():
		learn_spells()
	var stay: Array = state.get("stay", [])
	if stay.size() == 3:
		command = Command.STAY
		_stay_at = Vector3(stay[0], stay[1], stay[2])
	# Its pet, back at its side if it was out.
	var saved_pet: Variant = state.get("pet", {})
	if saved_pet is Dictionary and not (saved_pet as Dictionary).is_empty():
		pet_record = saved_pet
		if combatant.is_alive():
			spells.ranger()._summon_saved()


## On its own it trains as it goes; in a party it waits for the player to
## take it to its trainer, and says so.
func _on_leveled_up(_level: int) -> void:
	if not in_party:
		trained_level = 0
	elif trained_level <= 0:
		trained_level = _level_before
	_level_before = profile.level
	learn_spells()
	if in_party and not spells_to_train().is_empty():
		_party_say("I've new spells to learn, take me to my trainer when you can")


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
	# Its usual role may differ in a party (a Man-at-Arms with a shield tanks):
	# talents to match.
	learn_spells()
	stats.refresh()


func left_party() -> void:
	in_party = false
	_ordered_target = null
	_errand = {}
	# On its own again, it goes and trains.
	if trained_level > 0:
		trained_level = 0
		learn_spells()
	_enemy = null
	combatant.attack_target = null
	progression.level_cap = manager.max_level() if manager else ClassicData.MAX_LEVEL


## Revival, or getting back up after the wait.
func resurrect(health: int, mana: int, raised := true) -> void:
	if combatant.is_alive():
		return
	combatant.health = clampi(health, 1, combatant.max_health)
	combatant.mana = clampf(mana, 0.0, combatant.max_mana)
	_feedback.reset()
	_dead_for = 0.0
	_stay_at = global_position
	revived.emit(raised)


func _on_died() -> void:
	last_death = {
		"killer": _last_attacker, "place": manager.place_at(global_position) if manager else "",
		"time": Time.get_ticks_msec() / 1000.0,
	}
	_dead_for = 0.0
	sitting = false
	_resting = false
	_enemy = null
	_has_destination = false


func _physics_process(delta: float) -> void:
	_visual.rotation.y = facing
	if not combatant.is_alive():
		velocity = Vector3(0.0, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, 0.0)
		if not _far:
			move_and_slide()
		_dead_for += delta
		if _dead_for >= REVIVE_TIME and _may_get_up():
			# Bots on their own come back at the zone's graveyard, like the
			# player, so they don't rise among whatever killed them.
			if not in_party:
				for enemy: Enemy in _creatures():
					enemy.forget(combatant)
				var graveyard: Vector3 = manager.graveyard_at(global_position) if manager else AshfordVale.SPAWN
				global_position = graveyard + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
				velocity = Vector3.ZERO
			resurrect(combatant.max_health / 2, int(combatant.max_mana / 2.0) if combatant.has_mana() else 0, false)
		return
	_think_left -= delta
	if _think_left <= 0.0:
		_think_left = FAR_THINK_INTERVAL if _far else THINK_INTERVAL
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
	# Waits where it is while trading, unless something attacks it.
	if trading and not combatant.is_in_combat():
		_has_destination = false
		combatant.attack_target = null
		return
	# Left behind, whatever it was doing: catch up first.
	if in_party and _left_behind():
		_teleport_to(_leader())
		return
	_quest_check_left -= THINK_INTERVAL
	if _quest_check_left <= 0.0:
		_quest_check_left = QUEST_CHECK
		_sell_trash_nearby()
		var questing: bool = manager != null and not in_party and Settings.get_value("bot_quests")
		if questing:
			_drop_unreachable_quests()
		_wanted = quests.wanted_creatures(manager.spawn_entries()) if questing else ([] as Array[int])
		# What the player's quests need is theirs: a random bot doesn't hunt it.
		if questing:
			var players: Dictionary = manager.player_needs().creatures
			_wanted.assign(_wanted.filter(func(entry: int) -> bool: return not players.has(entry)))
		_business = _quest_npc() if questing else null
		_explore = quests.place_to_explore() if questing else ""
		_chest = _nearest_chest() if questing else null
	# Walking into a place explores it, fighting or not.
	if not _explore.is_empty():
		_check_explored()
	_enemy = _choose_enemy()
	# A Ranger without a pet tames one before hunting on.
	if _tame_step():
		return
	if spells.casting.is_empty():
		_use_spells()
	if not spells.casting.is_empty():
		_has_destination = false
		return
	if _enemy:
		_resting = false
		sitting = false
		# A caster with a wand stays back and shoots it once its mana runs
		# low, as classic's priests do.
		var wanding := _shoots_wand()
		# A Ranger shoots from range, and fights in melee only in the dead zone.
		var shooting := _ranger_shoots()
		if wanding or shooting:
			combatant.attack_target = null
			if not _casts_from_range() and combatant.shoot_target != _enemy and combatant.shot_problem(_enemy).is_empty():
				combatant.start_shooting(_enemy)
		else:
			combatant.stop_shooting()
			combatant.attack_target = _enemy
		var reach := CASTER_RANGE if wanding or _casts_from_range() else RANGER_RANGE if shooting else combatant.melee_range * 0.8
		if combatant.distance_to(_enemy) > reach:
			_go_to(_enemy.body.global_position)
		else:
			_has_destination = false
		return
	combatant.attack_target = null
	combatant.stop_shooting()
	if not _errand.is_empty() and _do_errand():
		return
	if in_party:
		_party_idle()
	else:
		_solo_idle()


# Choosing what to fight.

func _choose_enemy() -> Combatant:
	if not in_party:
		return _solo_enemy()
	var leader := _leader()
	# Told to attack something: that, until it's dead.
	if _ordered_target and is_instance_valid(_ordered_target) and _ordered_target.is_alive():
		return _ordered_target
	_ordered_target = null
	var mode := fight_mode()
	# What the leader is attacking, or has targeted and is fighting.
	if mode == "Assist" and leader and leader.combatant.is_alive():
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
	for node in _creatures():
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


## The roles its class can play.
func roles() -> Array:
	return CLASS_ROLES.get(profile.char_class, ["Damage"])


## The role it plays: the one set, or its class's usual one (Men-at-Arms and
## Spellswords tank with a shield in a party, Templars and Clerics heal).
func current_role() -> String:
	if role in roles():
		return role
	match profile.char_class:
		ClassicData.CharClass.WARRIOR, ClassicData.CharClass.SPELLSWORD:
			return "Tank" if in_party and _has_shield_on() else "Damage"
		ClassicData.CharClass.PALADIN, ClassicData.CharClass.PRIEST:
			return "Healer"
	return "Damage"


## Takes up a role ("" for its usual one): its talents are spent again for it.
func set_role(new_role: String) -> void:
	if new_role == role:
		return
	role = new_role
	learn_spells()
	stats.refresh()
	if in_party:
		_party_say({ "Tank": "I'll tank", "Healer": "I'll keep you all alive", "Damage": "I'll go all out on damage" }.get(current_role(), "ok"))


## How hurt someone must be before it heals them: the Bots Heal Below option
## for healers, only emergencies for the rest.
func _heal_below() -> float:
	return heal_threshold() if current_role() == "Healer" else EMERGENCY_HEAL


## How it picks fights: its own setting, or the Party Bots Attack option's.
func fight_mode() -> String:
	if behavior in BEHAVIORS:
		return behavior
	return { "Assist My Target": "Assist", "Passive": "Passive" }.get(Settings.get_value("bot_assist"), "Defend")


## Attack this, whatever its fighting mode, until it's dead.
func order_attack(target: Combatant) -> void:
	_ordered_target = target
	_errand = {}
	_resting = false
	sitting = false
	_think_left = 0.0


## The spells of a buff category it knows.
func buff_options(category: String) -> Array[String]:
	var known: Array[String] = []
	for spell_name: String in CATEGORY_SPELLS.get(category, []):
		if profile.best_rank(spell_name) != 0:
			known.append(spell_name)
	return known


func buff_choice(category: String) -> String:
	return str(buff_choices.get(category, "Auto"))


## Whether a unit has an aura of the spell (any rank), from this bot or anyone.
func _wears(target: Combatant, spell_name: String, mine := false) -> bool:
	for aura in target.auras:
		if aura.spell.SpellName == spell_name and (not mine or aura.caster == combatant):
			return true
	return false


# Errands from the party window: selling at a vendor, training at a trainer.

## Walks to a vendor and sells its junk (or everything in its bag).
func send_to_vendor(npc: Npc, everything: bool) -> void:
	_errand = { "kind": "sell", "npc": npc, "all": everything }
	_ordered_target = null
	_resting = false
	sitting = false
	_think_left = 0.0


## Walks to its class trainer and learns what it's ready for.
func send_to_trainer(npc: Npc) -> void:
	_errand = { "kind": "train", "npc": npc }
	_ordered_target = null
	_resting = false
	sitting = false
	_think_left = 0.0


func errand() -> String:
	return str(_errand.get("kind", ""))


## On its way, or there and done: true while the errand takes its time.
func _do_errand() -> bool:
	var npc: Npc = _errand.get("npc")
	if npc == null or not is_instance_valid(npc):
		_errand = {}
		return false
	if global_position.distance_to(npc.global_position) > NPC_REACH:
		_go_to(npc.global_position)
		return true
	_has_destination = false
	_face(npc.global_position)
	var kind: String = _errand.kind
	var everything: bool = _errand.get("all", false)
	_errand = {}
	if kind == "sell":
		var sold := bag.sell_all() if everything else bag.sell_trash_count()
		_party_say("sold %d item%s to %s for %s" % [sold[0], "" if sold[0] == 1 else "s", npc.npc_name, ItemDB.money_text(sold[1])] if sold[0] > 0 else "nothing to sell")
	elif kind == "train":
		_party_say(train())
	return true


func _party_say(text: String) -> void:
	if manager and in_party:
		manager.party_say(self, text)


# Training: party bots learn new spells at their trainer.

## Trainer entries for spells it could know at its level and doesn't: as a
## player's trainer lists them (each rank after the one before).
func spells_to_train() -> Array[Dictionary]:
	var known: Array[int] = profile.known_spells.duplicate()
	var wanted: Array[Dictionary] = []
	var list := SpellDB.class_trainer_list(profile.char_class, profile.race)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.level) < int(b.level))
	for entry: Dictionary in list:
		if int(entry.level) > profile.level:
			continue
		var previous := SpellDB.previous_rank(int(entry.spells[0]))
		if previous != 0 and not previous in known:
			continue
		var new_spell := false
		for id in entry.spells:
			if not int(id) in known:
				known.append(int(id))
				new_spell = true
		if new_spell:
			wanted.append(entry)
	return wanted


func training_cost() -> int:
	var cost := 0
	for entry in spells_to_train():
		cost += int(entry.get("cost", 0))
	return cost


## Learns everything it's ready for, paying from its own money and the
## player's for the rest. Says how it went.
func train() -> String:
	var wanted := spells_to_train()
	if wanted.is_empty():
		return "nothing new for me to learn yet"
	var cost := training_cost()
	if bag.money + GameState.money < cost:
		return "training costs %s, and we've only %s between us" % [ItemDB.money_text(cost), ItemDB.money_text(bag.money + GameState.money)]
	var from_me := mini(bag.money, cost)
	bag.money -= from_me
	if cost > from_me:
		GameState.money -= cost - from_me
		GameState.inventory_changed.emit()
	trained_level = profile.level
	learn_spells()
	Sfx.play_at("level_up", global_position)
	var names: Array[String] = []
	for entry in wanted:
		var spell_name := str(SpellDB.get_spell(int(entry.spells[0])).get("SpellName", ""))
		if not spell_name in names:
			names.append(spell_name)
	var paid := "" if cost == 0 else (" (%s, %s of it yours)" % [ItemDB.money_text(cost), ItemDB.money_text(cost - from_me)] if cost > from_me else " (%s)" % ItemDB.money_text(cost))
	return "learned %s%s" % [", ".join(names), paid]


func _fights_group(enemy: Enemy) -> bool:
	for unit in Party.units():
		if enemy.threat.has(unit.combatant):
			return true
	return false


## On its own: whatever is attacking it, then the creature it's fighting,
## then the nearest creature worth hunting, unless it needs a rest.
func _solo_enemy() -> Combatant:
	var attacker: Combatant = null
	for node in _creatures_near(LEASH_REACH):
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
	# On its way to the player or a quest giver it only fights what attacks it.
	if is_coming() or _quest_business():
		return null
	# Creatures its quests need come first, then anything worth hunting.
	var best: Combatant = null
	var best_wanted := false
	for node in _creatures_near(HUNT_RANGE):
		var enemy := node as Enemy
		if not _can_hunt(enemy, false) or global_position.distance_to(enemy.global_position) > HUNT_RANGE:
			continue
		var wanted := enemy.creature_entry in _wanted
		if best_wanted and not wanted:
			continue
		if best == null or (wanted and not best_wanted) or combatant.distance_to(enemy.combatant) < combatant.distance_to(best):
			best = enemy.combatant
			best_wanted = wanted
	return best


## A creature it can take on: alive, near its level, and nobody else's.
func _can_hunt(enemy: Enemy, already_fighting: bool) -> bool:
	if enemy == null or not enemy.combatant.is_alive() or enemy.state == Enemy.State.RETURN:
		return false
	if enemy.tapped_by and is_instance_valid(enemy.tapped_by) and enemy.tapped_by != combatant:
		return false
	if not already_fighting and enemy.state == Enemy.State.CHASE:
		return false
	# A random bot leaves creatures the player's quests need to the player
	# (party bots help with them).
	if not already_fighting and not in_party and manager and manager.player_needs().creatures.has(enemy.creature_entry):
		return false
	var level := profile.level
	# Grey creatures are still worth killing for a quest.
	var worth := enemy.level > CombatRules.gray_level(level) or enemy.creature_entry in _wanted
	return enemy.level <= level + HUNT_LEVELS_ABOVE and worth


## The zone's creatures (a list kept by the BotManager, cheaper than asking
## the tree).
func _creatures() -> Array:
	return manager.creatures() if manager else get_tree().get_nodes_in_group("enemies")


## The creatures within about `radius` yards (BotManager.creatures_near).
func _creatures_near(radius: float) -> Array:
	return manager.creatures_near(global_position, radius) if manager else _creatures()


func _leader() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


# Out of combat.

func _needs_rest() -> bool:
	var c := combatant
	if c.is_in_combat():
		return false
	return c.health < c.max_health * REST_HEALTH or (c.has_mana() and c.mana < c.max_mana * REST_MANA)


## Quest givers with something to hand in or take, then the creatures its
## quests need, or else hunting grounds near its level.
func _solo_idle() -> void:
	if _resting:
		return
	if _needs_rest():
		_start_rest()
		return
	if _talk_left > 0.0:
		_talk_left -= THINK_INTERVAL
		return
	if is_coming():
		_come_closer()
		return
	if _quest_business():
		var npc := _business
		if npc:
			if global_position.distance_to(npc.global_position) <= NPC_REACH:
				_talk_to(npc)
			else:
				_go_to(npc.global_position)
			return
	if _explore_quest() or _fetch_from_chest():
		return
	_roam_left -= THINK_INTERVAL
	var arrived := not _has_destination or global_position.distance_to(_destination) < 2.0
	if (arrived or _roam_left <= 0.0) and manager:
		_go_to(manager.hunting_spot(profile.level, _wanted, global_position))
		_roam_left = 20.0


## Walks to the place an exploration quest sends it to; well inside it, the
## place is explored. Returns whether it's on its way.
func _explore_quest() -> bool:
	if _explore.is_empty() or manager == null:
		return false
	var place := manager.place_named(_explore)
	if place.is_empty():
		_explore = ""
		return false
	var center: Vector2 = place[1]
	_go_to(Vector3(center.x, manager.ground_height(center.x, center.y), center.y))
	return true


## Inside the place an exploration quest sends it to: explored.
func _check_explored() -> void:
	var place := manager.place_named(_explore) if manager else []
	if place.is_empty() or Vector2(global_position.x, global_position.z).distance_to(place[1]) <= float(place[2]) * 0.6:
		if not place.is_empty():
			quests.explored(_explore)
		_explore = ""


## Walks to a game object holding an item its quests need and takes it.
## Returns whether it's busy with one.
func _fetch_from_chest() -> bool:
	if _chest == null or not is_instance_valid(_chest) or not _chest.is_spawned():
		_chest = null
		return false
	if global_position.distance_to(_chest.global_position) > CHEST_REACH:
		_go_to(_chest.global_position)
		return true
	for item in quests.object_items_needed():
		if _chest.holds(item):
			quests.took_item(item)
			break
	_chest.take_for_bot()
	_chest = _nearest_chest()
	return true


## The nearest game object holding an item its quests still need, within
## CHEST_SEARCH yards, or null.
func _nearest_chest() -> GameObject:
	var needed := quests.object_items_needed()
	# Not ones holding what the player's quests need.
	if manager and not in_party:
		var players: Dictionary = manager.player_needs().items
		needed.assign(needed.filter(func(item: int) -> bool: return not players.has(item)))
	if needed.is_empty():
		return null
	var best: GameObject = null
	var best_distance := CHEST_SEARCH
	for node in get_tree().get_nodes_in_group("game_objects"):
		var chest := node as GameObject
		if not chest.is_spawned() or not needed.any(func(item: int) -> bool: return chest.holds(item)):
			continue
		if manager and not manager.reachable(global_position, chest.global_position):
			continue
		var distance := global_position.distance_to(chest.global_position)
		if distance < best_distance:
			best = chest
			best_distance = distance
	return best


const CHEST_REACH := 3.0
const CHEST_SEARCH := 600.0


## Sets off to walk over to the player, to trade.
func come_to_player() -> void:
	_coming_until = Time.get_ticks_msec() / 1000.0 + COME_TIME
	_resting = false
	sitting = false


func is_coming() -> bool:
	return not in_party and Time.get_ticks_msec() / 1000.0 < _coming_until


func _come_closer() -> void:
	var player := _leader()
	if player == null or not player.combatant.is_alive():
		return
	if global_position.distance_to(player.global_position) <= COME_REACH:
		_coming_until = 0.0
		_has_destination = false
		_face(player.global_position)
		arrived.emit()
	else:
		_go_to(player.global_position)


func _quest_business() -> bool:
	return _business != null and not in_party


## Passing a vendor (within VENDOR_REACH), it sells its trash.
func _sell_trash_nearby() -> void:
	if not bag.has_trash() or combatant.is_in_combat():
		return
	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Npc
		if npc.vendor != 0 and global_position.distance_to(npc.global_position) <= VENDOR_REACH:
			bag.sell_trash()
			return


## The nearest quest giver it has business with: one to hand a finished
## quest to, or one with a quest it can take.
func _quest_npc() -> Npc:
	# Who it has business with, from its quests, then the nearest of them.
	var business := {}
	for id: int in QuestDB.all_ids():
		var quest := QuestDB.get_quest(id)
		if quests.active.has(id):
			if quests.is_complete(id):
				business[quest.get("ender")] = true
		elif quests.can_take(id, profile.level, profile.race):
			business[quest.get("giver")] = true
	if business.is_empty():
		return null
	var best: Npc = null
	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Npc
		if not business.has(npc.npc_id()):
			continue
		if manager and not manager.reachable(global_position, npc.global_position):
			continue
		if best == null or global_position.distance_to(npc.global_position) < global_position.distance_to(best.global_position):
			best = npc
	return best


## Gives up quests it can't hand in from here: their ender isn't in this
## world (zones not built, as after moving between unjoined zones) or can't
## be walked to.
func _drop_unreachable_quests() -> void:
	var enders := {}
	for node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Npc
		if manager.reachable(global_position, npc.global_position):
			enders[npc.npc_id()] = true
	for id: int in quests.active.keys():
		if not enders.has(str(QuestDB.get_quest(id).get("ender", ""))):
			quests.active.erase(id)


func _has_business(npc_id: String) -> bool:
	for id: int in QuestDB.all_ids():
		var quest := QuestDB.get_quest(id)
		if quest.get("ender") == npc_id and quests.is_complete(id):
			return true
		if quest.get("giver") == npc_id and quests.can_take(id, profile.level, profile.race):
			return true
	return false


## Hands in its finished quests for their XP, then takes what's on offer.
func _talk_to(npc: Npc) -> void:
	_has_destination = false
	_face(npc.global_position)
	var npc_id := npc.npc_id()
	for id: int in quests.active.keys():
		if QuestDB.get_quest(id).get("ender") == npc_id and quests.is_complete(id):
			last_quest_done = { "title": str(QuestDB.get_quest(id).title), "time": Time.get_ticks_msec() / 1000.0 }
			progression.add_xp(quests.turn_in(id, profile.level))
			_quest_check_left = 0.0
	for id: int in QuestDB.all_ids():
		if QuestDB.get_quest(id).get("giver") == npc_id and quests.can_take(id, profile.level, profile.race):
			quests.accept(id)
			_quest_check_left = 0.0
	_talk_left = TALK_TIME


func _party_idle() -> void:
	var leader := _leader()
	if leader == null:
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


## A following bot is left behind when it's out of party-frame range, or
## hasn't got any closer for a few seconds while well back. Bots told to stay
## stay, and nobody teleports to a leader who's dead or in the air.
func _left_behind() -> bool:
	var leader := _leader()
	if leader == null or command != Command.FOLLOW or not Settings.get_value("bot_teleport"):
		_behind_for = 0.0
		return false
	var distance := global_position.distance_to(leader.global_position)
	var closing := distance < _last_leader_distance - 0.5
	_last_leader_distance = distance
	# Fighting isn't falling behind, as long as it's within range.
	var following := _enemy == null and spells.casting.is_empty() and not _resting
	_behind_for = 0.0 if closing or distance <= BEHIND_DISTANCE or not following else _behind_for + THINK_INTERVAL
	if not leader.combatant.is_alive() or not leader.is_on_floor():
		return false
	return distance > TELEPORT_DISTANCE or _behind_for >= BEHIND_TIME


func _teleport_to(leader: Player) -> void:
	_behind_for = 0.0
	_enemy = null
	combatant.attack_target = null
	sitting = false
	_resting = false
	_route.clear()
	_detour.clear()
	velocity = Vector3.ZERO
	global_position = _follow_spot(leader) + Vector3.UP * 0.5
	_has_destination = false


func stay() -> void:
	command = Command.STAY
	_stay_at = global_position
	_has_destination = false


func follow() -> void:
	command = Command.FOLLOW


## Sits down to eat and drink now (the party window's Rest), unless fighting.
func rest() -> bool:
	if combatant.is_in_combat() or not combatant.is_alive():
		return false
	_errand = {}
	_start_rest()
	return true


func _start_rest() -> void:
	_has_destination = false
	sitting = true
	_resting = true
	combatant.add_aura(SpellDB.get_spell(FOOD_SPELL), combatant)
	if combatant.has_mana():
		combatant.add_aura(SpellDB.get_spell(DRINK_SPELL), combatant)


func _rest(delta: float) -> void:
	var c := combatant
	if not sitting:
		_resting = false
		return
	_rest_carry += Vector2(c.max_health, c.max_mana if c.has_mana() else 0) * REST_RATE * delta
	var health := int(_rest_carry.x)
	var mana := int(_rest_carry.y)
	_rest_carry -= Vector2(health, mana)
	c.health = mini(c.health + health, c.max_health)
	c.mana = minf(c.mana + mana, c.max_mana)
	var full_mana := not c.has_mana() or c.mana >= c.max_mana * REST_UNTIL
	if c.health >= c.max_health * REST_UNTIL and full_mana:
		sitting = false
		_resting = false


## Clerics with mana stand back and cast; out of mana they close in and swing.
## A Cleric holding a wand: it fights with the wand, not in melee.
func _shoots_wand() -> bool:
	return profile.char_class == ClassicData.CharClass.PRIEST 		and int(combatant.ranged_weapon.get("kind", 0)) == Inventory.WEAPON_SUBCLASS_WAND


func _casts_from_range() -> bool:
	var c := combatant
	# A damage Cleric casts down to its last few drops.
	var keep := 0.05 if current_role() == "Damage" else CASTER_MANA
	return profile.char_class == ClassicData.CharClass.PRIEST and c.max_mana > 0 and c.mana >= c.max_mana * keep \
		and profile.best_rank("Chastise") != 0


func _use_spells() -> void:
	match profile.char_class:
		ClassicData.CharClass.PALADIN:
			_use_templar_spells()
		ClassicData.CharClass.PRIEST:
			_use_cleric_spells()
		ClassicData.CharClass.WARRIOR:
			_use_man_at_arms_spells()
		ClassicData.CharClass.SPELLSWORD:
			_use_spellsword_spells()
		ClassicData.CharClass.HUNTER:
			_use_ranger_spells()


# Ranger abilities: a Spirit kept up (Hawk, else Monkey), its pet called,
# revived, mended and sent in first; from range Quarry's Mark, Adder Sting,
# Glimmer Shot and Spread Shot when crowded; in the dead zone Talon Strike,
# Crippling Cut on what chases it, and the reactive strikes; Still as Death
# when it's losing.

## Whether a Ranger bot fights its enemy with its ranged weapon: it has one,
## and the enemy is past the dead zone.
func _ranger_shoots() -> bool:
	if profile.char_class != ClassicData.CharClass.HUNTER or combatant.ranged_weapon.is_empty() or _enemy == null:
		return false
	return combatant.distance_to(_enemy) >= float(combatant.ranged_weapon.get("min_range", 8.0))


func _use_ranger_spells() -> void:
	var me := combatant
	var fighting := me.is_in_combat()
	var ranger := spells.ranger()
	var record := ranger.pet_record()
	var out := pet != null and is_instance_valid(pet)
	# The pet: called, or revived out of combat; mended when hurt.
	if not record.is_empty() and not out:
		if record.get("dead", false):
			if not fighting and _try("Revive Pet", me):
				return
		elif _try("Call Pet", me):
			return
	if out and not pet.combatant.is_alive() and not fighting and _try("Revive Pet", me):
		return
	if out and pet.combatant.is_alive() and pet.combatant.health < pet.combatant.max_health * 0.4 \
			and me.distance_to(pet.combatant) <= 20.0 and _lacks(pet.combatant, "Mend Companion") and _try("Mend Companion", me):
		return
	# The Spirit: the one chosen, or Hawk (Monkey before Hawk is known).
	var choice := buff_choice("Spirits")
	var spirit := choice
	if choice == "Auto":
		spirit = "Hawk Spirit" if profile.best_rank("Hawk Spirit") != 0 else "Monkey Spirit"
	if choice != "None" and profile.best_rank(spirit) != 0 and _lacks(me, spirit) and _try(spirit, me):
		return
	if _enemy == null:
		return
	if out and pet.combatant.is_alive() and pet.target != _enemy:
		pet.order_attack(_enemy)
	# Losing: lie still and let the pet (or the group) hold it.
	if fighting and me.health < me.max_health * 0.2 and (_enemy.body as Enemy) != null \
			and (_enemy.body as Enemy).current_victim() == me and (out or in_party) and _try("Still as Death", me):
		return
	var distance := me.distance_to(_enemy)
	if _ranger_shoots():
		if _lacks(_enemy, "Quarry's Mark") and _try("Quarry's Mark", _enemy):
			return
		if _crowd_near_point(_enemy.body.global_position, 8.0) >= 2 and _try("Spread Shot", _enemy):
			return
		if _enemy.health > _enemy.max_health * 0.3 and _lacks(_enemy, "Adder Sting", false) and _try("Adder Sting", _enemy):
			return
		_try("Glimmer Shot", _enemy)
		return
	if distance > me.melee_range + 1.0:
		return
	if _try("Weasel Bite", _enemy) or _try("Counterattack", _enemy):
		return
	var chasing := _enemy.body is Enemy and (_enemy.body as Enemy).current_victim() == me
	if chasing and _lacks(_enemy, "Crippling Cut", false) and _try("Crippling Cut", _enemy):
		return
	_try("Talon Strike", _enemy)


## Living enemies fighting within a radius of a point.
func _crowd_near_point(point: Vector3, radius: float) -> int:
	var count := 0
	for node in _creatures_near(radius + 30.0):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.state == Enemy.State.CHASE and enemy.global_position.distance_to(point) <= radius:
			count += 1
	return count


## A Ranger bot with no pet, from level 10, tames the nearest beast it can
## (one of its level or below, not fighting): it walks up and holds Tame
## Beast. Returns true while it's busy with that.
func _tame_step() -> bool:
	if profile.char_class != ClassicData.CharClass.HUNTER or profile.level < RANGER_PET_LEVEL or profile.best_rank("Tame Beast") == 0:
		return false
	if not spells.ranger().pet_record().is_empty() or combatant.is_in_combat() or (in_party and command == Command.STAY):
		return false
	if _tame_target == null or not is_instance_valid(_tame_target) or not _tame_target.combatant.is_alive() \
			or not _tame_target.visible or _tame_target.state == Enemy.State.RETURN:
		_tame_target = null
		_tame_search_left -= THINK_INTERVAL
		if _tame_search_left > 0.0:
			return false
		_tame_search_left = TAME_EVERY
		var best_distance := TAME_SEARCH
		for node in _creatures_near(TAME_SEARCH):
			var beast := node as Enemy
			if not beast.combatant.is_alive() or not beast.visible or beast.state == Enemy.State.CHASE or beast.level > profile.level:
				continue
			if not PetDB.is_tameable(beast.creature_entry) or (beast.tapped_by != null and beast.tapped_by != combatant):
				continue
			var distance := global_position.distance_to(beast.global_position)
			if distance < best_distance:
				best_distance = distance
				_tame_target = beast
		if _tame_target == null:
			return false
	var target := _tame_target.combatant
	if combatant.distance_to(target) > 18.0:
		_go_to(_tame_target.global_position)
		return true
	_has_destination = false
	_enemy = target
	_face(_tame_target.global_position)
	if _try("Tame Beast", target):
		return true
	_enemy = null
	return false


# Spellsword spells: a tank in Wardweave Form with Warding Edge (with a
# shield in a party, or when told), else a damage dealer in Bladesong Form
# with Flame or Storm Edge; Release when the Resonance is worth it.

## Whether this Spellsword tanks: told to (its Form choice), or holding a
## shield in a party.
func _spellsword_tanks() -> bool:
	var choice := buff_choice("Form")
	if choice == "Wardweave Form":
		return true
	if choice == "Bladesong Form":
		return false
	return current_role() == "Tank" and profile.best_rank("Wardweave Form") != 0


func _use_spellsword_spells() -> void:
	var me := combatant
	var fighting := me.is_in_combat()
	var tank := _spellsword_tanks()
	# The form: the one chosen, or the role's.
	var form_choice := buff_choice("Form")
	var form := "Wardweave Form" if tank else "Bladesong Form"
	if form_choice != "Auto" and form_choice != "None":
		form = form_choice
	var form_id := profile.best_rank(form)
	if form_choice != "None" and form_id != 0 and spells.current_form() != SpellDB.stance_form(SpellDB.get_spell(form_id)) and _try(form, me):
		return
	# The Edge: the one chosen, or Warding for tanks, Storm when crowded,
	# Flame otherwise.
	var crowd := _crowd_near(8.0)
	var edge_choice := buff_choice("Edge")
	var edge := edge_choice
	if edge_choice == "Auto":
		edge = "Flame Edge"
		if tank and profile.best_rank("Warding Edge") != 0:
			edge = "Warding Edge"
		elif crowd < 2 and profile.best_rank("Storm Edge") != 0:
			edge = "Storm Edge"
	if edge_choice != "None" and profile.best_rank(edge) != 0 and _lacks(me, edge, false) and _try(edge, me):
		return
	if fighting and me.health < me.max_health * 0.3 and _try("Last Sigil", me):
		return
	if fighting and tank and me.health < me.max_health * 0.6 and _lacks(me, "Runic Ward") and _try("Runic Ward", me):
		return
	if _enemy == null:
		return
	var distance := me.distance_to(_enemy)
	# Closing in: tanks throw a blade to pull, others step in.
	if not fighting and distance > 8.0 and _try("Hurl Blade" if tank else "Phase Step", _enemy):
		return
	if _enemy.is_casting and _try("Severing Sigil", _enemy):
		return
	var resonance := me.resonance
	if tank:
		var victim: Combatant = (_enemy.body as Enemy).current_victim() if _enemy.body is Enemy else null
		if in_party and victim != null and victim != me and _try("Mark of Challenge", _enemy):
			return
		if in_party and _loose_enemies() >= 3 and _try("Challenging Glyph", me):
			return
		if _try("Reprisal", _enemy):
			return
		if resonance >= 3 and _try("Release", me):
			return
	else:
		var elite := _enemy.body is Enemy and ((_enemy.body as Enemy).elite or (_enemy.body as Enemy).boss)
		if elite and _try("Arcane Surge", me):
			return
		if resonance >= 5 and _try("Release", me):
			return
	if distance > me.melee_range + 1.0:
		return
	if crowd >= 2 and _try("Arc Cleave", _enemy):
		return
	_try("Arcane Strike", _enemy)


## Living enemies fighting within a radius of the bot.
func _crowd_near(radius: float) -> int:
	var count := 0
	for node in _creatures_near(radius):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.state == Enemy.State.CHASE and global_position.distance_to(enemy.global_position) <= radius:
			count += 1
	return count


## Enemies fighting the party that aren't on this bot.
func _loose_enemies() -> int:
	var count := 0
	for node in _creatures_near(15.0):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.state == Enemy.State.CHASE and enemy.current_victim() != combatant and _fights_group(enemy):
			count += 1
	return count


# Cleric spells: heal the group (a Ward first when someone is in trouble),
# raise the fallen, keep buffs up, and fight with shadow and holy spells.

func _use_cleric_spells() -> void:
	var me := combatant
	var fighting := me.is_in_combat()
	var group := _group_units()
	var hurt := _most_hurt(group)
	if fighting and me.health < me.max_health * 0.3 and _try("Desperate Plea", me):
		return
	if hurt and fighting and hurt.health < hurt.max_health * 0.5 and _try("Sanctified Ward", hurt):
		return
	if hurt and hurt.health < hurt.max_health * _heal_below():
		var hurting := group.filter(func(unit: PlayerUnit) -> bool:
			var c := unit.combatant
			return c.is_alive() and c.health < c.max_health * _heal_below() and me.distance_to(c) <= 30.0)
		if hurting.size() >= 3 and _try("Communal Mending", me):
			return
		if hurt.health < hurt.max_health * 0.35 and _try("Swift Mending", hurt):
			return
		if hurt.health >= hurt.max_health * 0.5 and _lacks(hurt, "Lingering Grace") and _try("Lingering Grace", hurt):
			return
		for name in CLERIC_HEALS:
			if _try(name, hurt):
				return
	for unit in group:
		if unit.combatant.is_alive() and me.distance_to(unit.combatant) <= 30.0 and _try("Purge Sickness", unit.combatant):
			return
	if not fighting:
		for unit in group:
			if unit != self and not unit.combatant.is_alive() and _try("Rite of Return", unit.combatant):
				return
	if _enemy:
		# Hush stops a creature's spell and keeps it from casting.
		if _enemy.is_casting and _try("Hush", _enemy):
			return
		if _casts_from_range():
			if _lacks(_enemy, "Gnawing Shadow", false) and _try("Gnawing Shadow", _enemy):
				return
			if _try("Mind Lash", _enemy):
				return
			if _try("Chastise", _enemy):
				return
		return
	if fighting or _resting:
		return
	var self_choice := buff_choice("Self")
	var self_buffs: Array = CLERIC_SELF_BUFFS if self_choice == "Auto" else [] if self_choice == "None" else [self_choice]
	for name: String in self_buffs:
		if _lacks(me, name) and _try(name, me):
			return
	# Fortitude and Spirit unless told otherwise; Shadow Warding when chosen.
	var group_buffs: Array[String] = []
	for category: String in ["Fortitude", "Spirit", "Warding"]:
		var choice := buff_choice(category)
		if choice == "Auto" and category != "Warding":
			group_buffs.append(CATEGORY_SPELLS[category][0])
		elif choice != "Auto" and choice != "None":
			group_buffs.append(choice)
	for unit in group:
		var target := unit.combatant
		if not target.is_alive() or me.distance_to(target) > 30.0:
			continue
		for name in group_buffs:
			if _lacks(target, name) and _try(name, target):
				return


## Whether a target lacks a spell's aura (from anyone, or only from this bot),
## or has it with under BOON_REFRESH seconds left.
func _lacks(target: Combatant, spell_name: String, anyone := true) -> bool:
	for aura in target.auras:
		if aura.spell.SpellName == spell_name and (anyone or aura.caster == combatant):
			return aura.remaining >= 0.0 and aura.remaining < minf(BOON_REFRESH, aura.duration * 0.25)
	return true


# Man-at-Arms abilities: a stance (Bastion with a shield in a party, else
# Vanguard), Rallying Cry in a fight, Rush in, interrupts, then finishers, reactive
# strikes, Gash, area attacks when crowded, and Mighty Blow with spare rage.

func _use_man_at_arms_spells() -> void:
	var me := combatant
	var fighting := me.is_in_combat()
	var form := spells.current_form()
	var tank := current_role() == "Tank"
	var stance := "Bastion Stance" if tank and profile.best_rank("Bastion Stance") != 0 else "Vanguard Stance"
	var stance_choice := buff_choice("Stance")
	if stance_choice != "Auto" and stance_choice != "None" and profile.best_rank(stance_choice) != 0:
		stance = stance_choice
	if stance_choice != "None" and (form == 0 or (not fighting and SpellDB.stance_form(SpellDB.get_spell(profile.best_rank(stance))) != form)):
		if _try(stance, me):
			return
	if fighting and me.health < me.max_health * 0.25 and _try("Final Stand", me):
		return
	# Rage only comes in a fight, so the shout does too.
	if fighting and buff_choice("Shout") != "None" and _lacks(me, "Rallying Cry") and _try("Rallying Cry", me):
		return
	if _enemy == null:
		return
	var distance := me.distance_to(_enemy)
	if not fighting and distance >= 8.0 and _try("Rush", _enemy):
		return
	if distance > me.melee_range + 1.0:
		return
	if fighting and me.mana < 10.0 and me.health > me.max_health * 0.5 and _try("Blood Fury", me):
		return
	# Cut a caster's spell short.
	if _enemy.is_casting:
		for name in ["Hilt Strike", "Shield Smash"]:
			if _try(name, _enemy):
				return
	for name in ["Finishing Blow", "Riposte Strike", "Retort", "Grievous Strike", "Bloodlust Strike", "Shield Crush"]:
		if _try(name, _enemy):
			return
	# Taunt back a creature attacking someone else in the party.
	if in_party and tank and _enemy.body is Enemy and (_enemy.body as Enemy).current_victim() not in [null, me] and _try("Goad", _enemy):
		return
	var crowd := 0
	for node in _creatures_near(8.0):
		var enemy := node as Enemy
		if enemy.combatant.is_alive() and enemy.state == Enemy.State.CHASE and global_position.distance_to(enemy.global_position) <= 8.0:
			crowd += 1
	if crowd >= 2:
		for name in ["Cyclone Strike", "Ground Slam", "Daunting Roar"]:
			# Area attacks and shouts center on the bot itself.
			if (name != "Daunting Roar" or _lacks(_enemy, name, false)) and _try(name, me):
				return
	if _enemy.health > _enemy.max_health * 0.5 and _lacks(_enemy, "Gash", false) and _try("Gash", _enemy):
		return
	if me.mana >= 30.0 and spells.queued_swing().is_empty():
		_try("Mighty Blow", _enemy)


func _has_shield_on() -> bool:
	var off: Dictionary = profile.equipment.get(Inventory.Slot.OFF_HAND, {})
	if off.is_empty():
		return false
	var item := ItemDB.get_item(off.id)
	return int(item["class"]) == ItemDB.ITEM_CLASS_ARMOR and int(item.subclass) == Inventory.ARMOR_SUBCLASS_SHIELD


# Templar spells.

func _use_templar_spells() -> void:
	var me := combatant
	var fighting := me.is_in_combat()
	var group := _group_units()
	var hurt := _most_hurt(group)
	if hurt and hurt.health < hurt.max_health * 0.15 and fighting and _try("Last Rite", hurt):
		return
	if fighting and me.health < me.max_health * 0.2 and _try("Hallowed Aegis", me):
		return
	if hurt and hurt.health < hurt.max_health * _heal_below():
		var quick := hurt.health < hurt.max_health * 0.35
		if (quick and _try("Quick Radiance", hurt)) or _try("Mending Radiance", hurt):
			return
	# A tank Templar holds threat with holy power.
	if current_role() == "Tank":
		if _lacks(me, "Zealous Fervor") and _try("Zealous Fervor", me):
			return
		if fighting and _enemy and _crowd_near(8.0) >= 2 and _try("Hallowed Ground", me):
			return
	if not fighting:
		for unit in group:
			if unit != self and not unit.combatant.is_alive() and _try("Revival", unit.combatant):
				return
	var presence := buff_choice("Presence")
	if presence == "Auto":
		if not _has_own(me, SpellDB.is_paladin_aura):
			for name in PRESENCES:
				if _try(name, me):
					return
	elif presence != "None" and not _wears(me, presence, true) and _try(presence, me):
		return
	if _enemy:
		var oath_choice := buff_choice("Oath")
		var oath := me.find_aura(func(spell: Dictionary) -> bool: return SpellDB.is_seal(spell))
		if oath_choice == "None":
			pass
		elif oath.is_empty() or (oath_choice != "Auto" and not _wears(me, oath_choice, true)):
			for name: String in (OATHS if oath_choice == "Auto" else [oath_choice]):
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
		var choice := buff_choice("Boon")
		if choice == "None":
			break
		var name := choice if choice != "Auto" else "Boon of Clarity" if unit.profile.char_class in CASTER_CLASSES else "Boon of Strength"
		var boon := target.find_aura(func(spell: Dictionary) -> bool: return SpellDB.is_blessing(spell))
		var other_boon: bool = not boon.is_empty() and boon.caster == me and str(boon.spell.SpellName) != name
		if boon.is_empty() or other_boon or (boon.caster == me and boon.remaining < BOON_REFRESH and boon.remaining >= 0.0):
			if _try(name, target):
				return


## The share of health below which a bot heals someone: the "Bots Heal
## Below" option. Every class's healing reads it.
static func heal_threshold() -> float:
	return Settings.get_value("bot_heal_threshold")


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

## Heads for a point, by way of any gate in between. The route is worked
## out again only when the point moves a few yards (a creature or the leader
## moving), so the bot keeps going through the gate it chose.
func _go_to(point: Vector3) -> void:
	# Somewhere else entirely: the detour round the last obstacle is no use.
	if _has_destination and point.distance_to(_destination) > 15.0:
		_detour.clear()
	# Also when it's been moved off its way (raised at a graveyard, summoned).
	var off_route := not _route.is_empty() and global_position.distance_to(_route[0]) > _leg_start.distance_to(_route[0]) + 20.0
	if not _has_destination or _route.is_empty() or off_route or point.distance_to(_destination) > 3.0:
		_route = manager.route(global_position, point) if manager else ([point] as Array[Vector3])
		_leg_start = global_position
	else:
		_route[-1] = point
	_destination = point
	_has_destination = true


func _move(delta: float) -> void:
	var direction := Vector3.ZERO
	# How far the waypoint is, so a long far step stops on it, not past it.
	var to_waypoint := INF
	if not _detour.is_empty() and (not _has_destination or Time.get_ticks_msec() / 1000.0 > _detour_until):
		_detour.clear()
	if _has_destination and not sitting and spells.casting.is_empty() and not combatant.is_stunned() and not combatant.is_rooted():
		# Round an obstacle first, a waypoint at a time.
		while not _detour.is_empty() and Vector2(_detour[0].x - global_position.x, _detour[0].z - global_position.z).length() < 0.6:
			_detour.pop_front()
		var waypoint := _detour[0] if not _detour.is_empty() else _route[0] if not _route.is_empty() else _destination
		var offset := waypoint - global_position
		offset.y = 0.0
		to_waypoint = offset.length()
		if not _detour.is_empty():
			direction = offset.normalized()
		elif offset.length() > (0.3 if _route.size() <= 1 else 1.0):
			direction = offset.normalized()
		elif _route.size() > 1:
			_leg_start = _route.pop_front()
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
	if _far:
		# Far from the player: along the ground, no collision.
		velocity = Vector3.ZERO
		_stuck_for = 0.0
		var step := global_position + direction * minf(RUN_SPEED * combatant.speed_multiplier() * delta, to_waypoint)
		global_position = Vector3(step.x, manager.ground_height(step.x, step.z), step.z)
		return
	# Standing still on the ground: nothing to move, so no collision work.
	if direction == Vector3.ZERO and is_on_floor() and velocity.y <= 0.0:
		velocity = Vector3.ZERO
		_stuck_for = 0.0
		return
	if is_on_floor():
		# Slows (Chilled) and speed-ups change how fast it runs.
		velocity.x = direction.x * RUN_SPEED * combatant.speed_multiplier()
		velocity.z = direction.z * RUN_SPEED * combatant.speed_multiplier()
	else:
		velocity.y -= GRAVITY * delta
		if combatant.has_aura_type(SpellDB.AURA_FEATHER_FALL):
			velocity.y = maxf(velocity.y, -FEATHER_FALL_SPEED)
	var before := global_position
	move_and_slide()
	if direction == Vector3.ZERO or not is_on_floor():
		_stuck_for = 0.0
		return
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_stuck_for = _stuck_for + delta if moved < RUN_SPEED * combatant.speed_multiplier() * delta * 0.3 else 0.0
	if _stuck_for > STUCK_TIME:
		_stuck_for = 0.0
		# Find a way round what's in the way; failing that (a lip in the
		# ground, another unit), hop and sidestep.
		var goal := _route[0] if not _route.is_empty() else _destination
		var way: Array[Vector3] = manager.paths.detour(global_position, goal) if manager else ([] as Array[Vector3])
		if way.is_empty() and manager and manager.paths.busy():
			# Others are finding their ways this frame: ask again next.
			_stuck_for = STUCK_TIME
			return
		if way.size() > 0 and (_detour.is_empty() or way[0].distance_to(_detour[0]) > 0.5):
			_detour = way
			_detour_until = Time.get_ticks_msec() / 1000.0 + DETOUR_TIME
		else:
			_detour.clear()
			velocity.y = JUMP_SPEED
			_sidestep_left = SIDESTEP_TIME
			_sidestep_side = [-1.0, 1.0].pick_random()


func _face(point: Vector3) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() > 0.01:
		facing = atan2(-offset.x, -offset.z)
