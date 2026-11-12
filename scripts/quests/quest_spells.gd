class_name QuestSpells
extends RefCounted
## Quest items' spells, as CMaNGOS runs them: a phial filled at a moonwell
## (Create Item, needing a spell focus object near: RequiresSpellFocus), a
## well cleansed (Quest Complete), remains buried in a grave or a spell cast
## on a creature or object a quest counts (ReqSpellCast,
## Player::CastedCreatureOrGO), and the dummy effects CMaNGOS scripts by
## hand: a Lazy Peon woken (it gives the quest's kill credit) and Wildclaw's
## body released. SpellCaster.use_item hands such items here: `problem` says
## why one can't be used here and now, and `land` does what it does once its
## cast is done.

const EFFECT_DUMMY := 3
const EFFECT_QUEST_COMPLETE := 16
const EFFECT_CREATE_ITEM := 24
const EFFECT_SEND_EVENT := 61
## How near the creature or object a spell is used on must be, in yards.
const REACH := 8.0
## Dummy effects' scripts: the creature the spell is used on, and whether it
## must be dead. Awaken Peon wakes a sleeping Lazy Peon (an Npc) and counts as
## killing it, as its CMaNGOS script gives; Release Wildclaw frees the druid's
## spirit from his body (its Quest Complete effect does the rest).
const DUMMY_TARGETS := { 19938: [10556, false], 10617: [7318, true] }
## The taming rods of Taming the Beast (CMaNGOS scripts them on one beast
## each): rod spell -> the beast's creature entry. Using one through its
## channel completes the quest it came with.
const TAMING_RODS := {
	19674: 1126, 19687: 1201, 19548: 1196, 19688: 2956, 19689: 2959, 19692: 2970,
	19693: 1998, 19699: 2043, 19700: 1996, 19694: 3099, 19696: 3107, 19697: 3126,
}
const ERR_NO_TARGET := "There's nothing here to use it on."
const ERR_FOCUS := "Requires %s."

## Creatures and objects (negative) quests want each spell cast on: { spell: [targets] }.
static var _quest_targets: Dictionary
static var _built := false


static func is_quest_spell(spell: Dictionary) -> bool:
	if int(spell.get("RequiresSpellFocus", 0)) > 0 or DUMMY_TARGETS.has(int(spell.Id)) or TAMING_RODS.has(int(spell.Id)):
		return true
	for i in [1, 2, 3]:
		if int(spell.get("Effect%d" % i, 0)) in [EFFECT_QUEST_COMPLETE, EFFECT_CREATE_ITEM, EFFECT_SEND_EVENT]:
			return true
	return not _targets_for(int(spell.Id)).is_empty()


## What quests want a spell cast on: creature entries, and objects as negative ids.
static func _targets_for(spell_id: int) -> Array:
	if not _built:
		_built = true
		for id: int in QuestDB.all_ids():
			for wanted: Array in QuestDB.get_quest(id).get("objects", []):
				if int(wanted[2]) != 0:
					var targets: Array = _quest_targets.get(int(wanted[2]), [])
					if not int(wanted[0]) in targets:
						targets.append(int(wanted[0]))
					_quest_targets[int(wanted[2])] = targets
	return _quest_targets.get(spell_id, [])


## Why a quest item's spell can't be used where `unit` stands, or "" when it
## can: the spell focus it needs isn't near, or there's nothing to use it on.
static func problem(unit: Node3D, spell: Dictionary) -> String:
	var focus := int(spell.get("RequiresSpellFocus", 0))
	if focus > 0 and (World.current == null or not World.current.spell_focus_near(focus, unit.global_position)):
		return ERR_FOCUS % focus_name(focus)
	if needs_target(spell) and find_target(unit, spell) == null:
		return ERR_NO_TARGET
	return ""


static func needs_target(spell: Dictionary) -> bool:
	return DUMMY_TARGETS.has(int(spell.Id)) or TAMING_RODS.has(int(spell.Id)) or not _targets_for(int(spell.Id)).is_empty()


## The name of a spell focus (its object's: "Mossglen Moonwell").
static func focus_name(focus: int) -> String:
	for id: int in GameObject.all_ids():
		var data := GameObject.data(id)
		if int(data.get("focus", -1)) == focus:
			return str(data.name)
	return "a special place"


## The nearest creature, NPC or object within REACH the spell can be used on.
static func find_target(unit: Node3D, spell: Dictionary) -> Node3D:
	var id := int(spell.Id)
	var wanted: Array = []
	var dead := false
	if TAMING_RODS.has(id):
		wanted = [int(TAMING_RODS[id])]
	elif DUMMY_TARGETS.has(id):
		wanted = [int(DUMMY_TARGETS[id][0])]
		dead = DUMMY_TARGETS[id][1]
	else:
		wanted = _targets_for(id)
	var best: Node3D = null
	var best_distance := maxf(REACH, SpellDB.spell_range(spell)) if TAMING_RODS.has(id) else REACH
	for node in unit.get_tree().get_nodes_in_group("enemies") + unit.get_tree().get_nodes_in_group("npcs") \
			+ unit.get_tree().get_nodes_in_group("game_objects"):
		var target := _target_id(node)
		if target == 0 or not target in wanted:
			continue
		if node is Enemy and (node as Enemy).combatant.is_alive() == dead:
			continue
		if node is Npc and not (node as Npc).can_be_woken() and id == 19938:
			continue
		if node is GameObject and not (node as GameObject).is_spawned():
			continue
		var distance := unit.global_position.distance_to((node as Node3D).global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best


## A node's id as quest objectives name it: a creature's entry, an object's
## entry negated.
static func _target_id(node: Node) -> int:
	if node is Enemy:
		return (node as Enemy).creature_entry
	if node is GameObject:
		return -(node as GameObject).entry
	if node is Npc:
		return (node as Npc).creature_entry
	return 0


## The spell's cast is done: fills the phial, cleanses the well, buries the
## remains, wakes the peon.
static func land(unit: Node3D, spell: Dictionary, target: Node3D) -> void:
	var id := int(spell.Id)
	for i in [1, 2, 3]:
		match int(spell.get("Effect%d" % i, 0)):
			EFFECT_CREATE_ITEM:
				var item := int(spell.get("EffectItemType%d" % i, 0))
				if item > 0:
					Inventory.add_item(item, 1)
			EFFECT_QUEST_COMPLETE:
				QuestLog.complete_event(int(spell.get("EffectMiscValue%d" % i, 0)))
	if TAMING_RODS.has(id):
		_tamed_with_rod(unit, spell, target)
		return
	if target == null or not is_instance_valid(target):
		return
	if id == 19938 and target is Npc:
		(target as Npc).wake()
		QuestLog.on_kill(10556)
	elif not DUMMY_TARGETS.has(id):
		QuestLog.credit_object(_target_id(target), id)


## A taming rod's channel ran through: the quest it came with is done, and
## the beast, calmed, goes back where it came from.
static func _tamed_with_rod(unit: Node3D, spell: Dictionary, target: Node3D) -> void:
	for id: int in GameState.quests:
		var item := ItemDB.get_item(int(QuestDB.get_quest(id).get("source_item", 0)))
		if int(item.get("spellid_1", 0)) == int(spell.Id):
			QuestLog.complete_event(id)
	var enemy := target as Enemy
	if enemy and is_instance_valid(enemy) and enemy.combatant.is_alive():
		enemy.forget((unit as PlayerUnit).combatant)
		if enemy.threat.is_empty():
			enemy._start_return()
