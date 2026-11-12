class_name Talents
extends RefCounted
## Classic talents: one point a level from level 10 (51 at 60), spent in a
## class's three trees (Talent and TalentTab in the client, exported into
## spells.json's "talents"). A talent's tier needs 5 points spent in its tree
## per tier above the first, and some need another talent maxed first.
## Ranks are kept in CharacterProfile.talents (talent id -> rank).
## A talent that's an ability (Final Stand, Radiant Jolt, Hush) joins the
## known spells, and the trainer sells its later ranks. Passive talents
## become permanent auras on the unit, their highest rank only (sync_passives),
## and only while their weapon or stance requirement is met.

const FIRST_LEVEL := 10
## Talents bots leave alone: not in the game yet, or no use yet (no wands).
const BOT_SKIPS := ["Lingering Spirit", "Font of Light", "Wandwork",
	# The Ranger's: Beast's Eyes isn't in the game, creatures have no
	# Stamina, and Still as Death is never resisted yet.
	"Improved Beast's Eyes", "Improved Stinger Venom", "Improved Still as Death"]
## Unlearning costs 1 gold, then 5, then 10, rising 5 gold each time to 50
## (Player::resetTalentsCost in CMaNGOS; the cost there also falls back by
## 5 gold a month, which isn't kept here).
const RESET_STEPS := [10000, 50000, 100000]
const RESET_STEP := 50000
const RESET_MOST := 500000
const POINTS_PER_TIER := 5
## EquippedItemClass: a weapon, or armor (a shield).
const ITEM_CLASS_WEAPON := 2
const ITEM_CLASS_ARMOR := 4


static var _rank_of: Dictionary = {}
static var _first_of: Dictionary = {}


## A talent spell's first rank (its own id for rank 1, or for spells that
## aren't talent ranks).
static func first_rank_spell(spell_id: int) -> int:
	if _first_of.is_empty():
		for char_class in SpellDB.TRAINER_CLASSES.values():
			for tree: Dictionary in trees(int(char_class)):
				for talent: Dictionary in tree.talents:
					for rank_id in talent.ranks:
						_first_of[int(rank_id)] = int(talent.ranks[0])
	return _first_of.get(spell_id, spell_id)


## Which rank of its talent a talent spell is (1 up), or 0. Talent ranks
## aren't in the spell chains.
static func rank_of_spell(spell_id: int) -> int:
	if _rank_of.is_empty():
		for char_class in SpellDB.TRAINER_CLASSES.values():
			for tree: Dictionary in trees(int(char_class)):
				for talent: Dictionary in tree.talents:
					for i in talent.ranks.size():
						_rank_of[int(talent.ranks[i])] = i + 1
	return _rank_of.get(spell_id, 0)


## The class's trees in order: { id, name, order, talents: [{ id, tier,
## column, ranks, prereq: [[talent id, rank], ...] }] }.
static func trees(char_class: int) -> Array:
	return SpellDB._get_data().get("talents", {}).get(str(char_class), [])


static func points_total(level: int) -> int:
	return maxi(level - FIRST_LEVEL + 1, 0)


static func rank(profile: CharacterProfile, talent_id: int) -> int:
	return int(profile.talents.get(str(talent_id), 0))


static func spent(profile: CharacterProfile) -> int:
	var total := 0
	for key: String in profile.talents:
		total += int(profile.talents[key])
	return total


static func points_left(profile: CharacterProfile) -> int:
	return points_total(profile.level) - spent(profile)


static func spent_in(profile: CharacterProfile, tree: Dictionary) -> int:
	var total := 0
	for talent: Dictionary in tree.talents:
		total += rank(profile, int(talent.id))
	return total


## The talent and its tree, or {} for an unknown id.
static func find(char_class: int, talent_id: int) -> Dictionary:
	for tree: Dictionary in trees(char_class):
		for talent: Dictionary in tree.talents:
			if int(talent.id) == talent_id:
				return { "tree": tree, "talent": talent }
	return {}


## Why a point can't go in the talent now, or "" if it can.
static func problem(profile: CharacterProfile, talent_id: int) -> String:
	var found := find(profile.char_class, talent_id)
	if found.is_empty():
		return "Unknown talent."
	var talent: Dictionary = found.talent
	if rank(profile, talent_id) >= talent.ranks.size():
		return "Already at its highest rank."
	if points_left(profile) <= 0:
		return "No talent points left." if profile.level >= FIRST_LEVEL else "Talents start at level %d." % FIRST_LEVEL
	var needed := int(talent.tier) * POINTS_PER_TIER
	if spent_in(profile, found.tree) < needed:
		return "Requires %d points in %s." % [needed, found.tree.name]
	for pair: Array in talent.prereq:
		var other := find(profile.char_class, int(pair[0]))
		if rank(profile, int(pair[0])) < int(pair[1]) and not other.is_empty():
			return "Requires %d point%s in %s." % [int(pair[1]), "" if int(pair[1]) == 1 else "s", name_of(other.talent)]
	return ""


## The talent's name: its first rank's spell name.
static func name_of(talent: Dictionary) -> String:
	return str(SpellDB.get_spell(int(talent.ranks[0])).get("SpellName", "?"))


## Puts a point in a talent. Returns the name of what was learned, or "".
static func learn(profile: CharacterProfile, talent_id: int) -> String:
	if not problem(profile, talent_id).is_empty():
		return ""
	var talent: Dictionary = find(profile.char_class, talent_id).talent
	var new_rank := rank(profile, talent_id) + 1
	profile.talents[str(talent_id)] = new_rank
	var spell_id := int(talent.ranks[new_rank - 1])
	var spell := SpellDB.get_spell(spell_id)
	if not SpellDB.is_passive(spell):
		_add_known(profile, spell_id)
	elif profile == GameState:
		GameState.spells_changed.emit()
	return SpellDB.full_name(spell)


## Takes every point back, and the abilities they gave with all their
## trained ranks (unlearning talents at a trainer).
static func reset(profile: CharacterProfile) -> void:
	var removed := talent_ability_spells(profile.char_class, profile.known_spells)
	profile.talents.clear()
	for id in removed:
		profile.known_spells.erase(id)
	if profile == GameState:
		for i in GameState.action_bar.size():
			if GameState.action_bar[i] in removed:
				GameState.action_bar[i] = 0
		GameState.spells_changed.emit()


## Known spells that belong to a talent ability (any rank of one): those a
## reset takes away.
static func talent_ability_spells(char_class: int, known: Array[int]) -> Array[int]:
	var firsts := {}
	for tree: Dictionary in trees(char_class):
		for talent: Dictionary in tree.talents:
			var first := int(talent.ranks[0])
			if not SpellDB.is_passive(SpellDB.get_spell(first)):
				firsts[first] = true
	var found: Array[int] = []
	for id in known:
		if firsts.has(SpellDB.first_rank(id)) or firsts.has(id):
			found.append(id)
	return found


## Fixes a profile up after loading: points spent beyond its level (after a
## level change) are all taken back, and talent abilities known without the
## talent (bought from trainers before there were talents) are dropped.
static func validate(profile: CharacterProfile) -> void:
	if spent(profile) > points_total(profile.level):
		reset(profile)
		return
	var backed := {}
	for tree: Dictionary in trees(profile.char_class):
		for talent: Dictionary in tree.talents:
			if rank(profile, int(talent.id)) > 0:
				backed[int(talent.ranks[0])] = true
	for id in talent_ability_spells(profile.char_class, profile.known_spells):
		var first := SpellDB.first_rank(id)
		if not backed.has(first if first != 0 else id):
			profile.known_spells.erase(id)
			if profile == GameState:
				for i in GameState.action_bar.size():
					if GameState.action_bar[i] == id:
						GameState.action_bar[i] = 0


static func _add_known(profile: CharacterProfile, spell_id: int) -> void:
	if profile == GameState:
		SpellCaster.learn([spell_id])
	elif not spell_id in profile.known_spells:
		profile.known_spells.append(spell_id)


## The passive talent spells in effect: each talent's highest rank.
static func passive_spells(profile: CharacterProfile) -> Array[Dictionary]:
	var spells: Array[Dictionary] = []
	for tree: Dictionary in trees(profile.char_class):
		for talent: Dictionary in tree.talents:
			var r := rank(profile, int(talent.id))
			if r <= 0:
				continue
			var spell := SpellDB.get_spell(int(talent.ranks[r - 1]))
			if SpellDB.is_passive(spell):
				spells.append(spell)
	return spells


## Puts the passive talents' auras on the unit and takes off those that no
## longer apply: a lower rank, a talent taken back, or a requirement not met
## (Axeman's Craft needs an axe, Stubborn Defiance Bastion Stance). Returns
## whether anything changed.
static func sync_passives(combatant: Combatant, profile: CharacterProfile, equipment: Dictionary, form: int) -> bool:
	var wanted := {}
	for spell in passive_spells(profile):
		if _requirement_met(spell, equipment, form):
			wanted[int(spell.Id)] = spell
	var changed := false
	for aura in combatant.auras.duplicate():
		if aura.get("talent", false) and not wanted.has(int(aura.spell.Id)):
			combatant.remove_aura(int(aura.spell.Id), false)
			changed = true
	for id: int in wanted:
		if combatant.find_aura(func(spell: Dictionary) -> bool: return int(spell.Id) == id).is_empty():
			combatant.add_passive_aura(wanted[id])
			changed = true
	if changed:
		combatant.auras_changed.emit()
	return changed


## A passive's weapon (EquippedItemClass and SubClassMask) or stance
## (Stances) requirement. A weapon talent needs the main-hand weapon to be of
## its kind; a shield talent needs a shield in the off hand.
static func _requirement_met(spell: Dictionary, equipment: Dictionary, form: int) -> bool:
	var stances := int(spell.get("Stances", 0))
	if stances != 0 and (form == 0 or stances & (1 << (form - 1)) == 0):
		return false
	var item_class := int(spell.get("EquippedItemClass", -1))
	if item_class < 0:
		return true
	var mask := int(spell.get("EquippedItemSubClassMask", 0))
	# Ranged weapon talents (Deadly Aim) need one in the ranged slot.
	if Combatant.ranged_only(spell):
		var ranged: Dictionary = equipment.get(Inventory.Slot.RANGED, {})
		return not ranged.is_empty() and mask & (1 << int(ItemDB.get_item(int(ranged.id)).get("subclass", 0))) != 0
	var slots := [Inventory.Slot.MAIN_HAND, Inventory.Slot.OFF_HAND] if item_class == ITEM_CLASS_WEAPON else [Inventory.Slot.OFF_HAND]
	for slot in slots:
		var stack: Dictionary = equipment.get(slot, {})
		if stack.is_empty():
			continue
		var item := ItemDB.get_item(int(stack.id))
		if int(item.get("class", -1)) == item_class and (mask == 0 or mask & (1 << int(item.get("subclass", 0))) != 0):
			# Weapon talents go by the main hand (the off hand only counts for
			# Two-Weapon Craft, which has no weapon requirement).
			return true if item_class == ITEM_CLASS_ARMOR or slot == Inventory.Slot.MAIN_HAND else false
	return false


## The trees a playerbot spends in for its role (Bot.current_role: "Tank",
## "Healer" or "Damage"), main tree first: Men-at-Arms tank in Bulwark and
## fight in Blademastery; Templars heal in Grace, tank in Aegis, fight in
## Zeal; Clerics heal in Mercy, fight in Umbra; Spellswords tank in
## Wardweave, fight in Bladesong; Rangers go down Beastcraft (their pet),
## then Sharpshooting.
static func bot_trees(char_class: int, role: String) -> Array[int]:
	var order: Array[int] = [0, 1, 2]
	match char_class:
		ClassicData.CharClass.WARRIOR:
			if role == "Tank":
				order.assign([2, 0, 1])
		ClassicData.CharClass.PALADIN:
			order.assign({ "Tank": [1, 0, 2], "Damage": [2, 0, 1] }.get(role, [0, 1, 2]))
		ClassicData.CharClass.PRIEST:
			order.assign([2, 0, 1] if role == "Damage" else [1, 0, 2])
		ClassicData.CharClass.SPELLSWORD:
			order.assign([1, 2, 0] if role == "Tank" else [0, 2, 1])
	return order


## Spends a bot's points: down its main tree tier by tier, each talent to its
## highest rank, then the next tree.
static func spend_for_bot(profile: CharacterProfile, order: Array[int]) -> void:
	var all := trees(profile.char_class)
	var progress := true
	while points_left(profile) > 0 and progress:
		progress = false
		for index in order:
			if index >= all.size():
				continue
			for talent: Dictionary in all[index].talents:
				if name_of(talent) in BOT_SKIPS:
					continue
				while problem(profile, int(talent.id)).is_empty():
					learn(profile, int(talent.id))
					progress = true
				if points_left(profile) <= 0:
					return
			if progress:
				break


## What unlearning talents costs now, after paying `last` (0 for never).
static func reset_cost(last: int) -> int:
	for step: int in RESET_STEPS:
		if last < step:
			return step
	return mini(last + RESET_STEP, RESET_MOST)
