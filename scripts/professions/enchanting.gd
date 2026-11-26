class_name Enchanting
extends RefCounted
## Enchanting's rules, classic 1.12's (CMaNGOS): enchanted gear, its effects,
## disenchanting and Formulas.
##
## An enchanted item's stack carries `enchant` (its SpellItemEnchantment id,
## ProfessionDB.enchant), saved with it. What an enchant does, by its
## effects (ITEM_ENCHANTMENT_TYPE): a stat or armour or resistance and weapon
## damage are added to the gear's totals (gear_bonus, from
## Inventory.gear_totals); an equip spell is an aura kept up while the item is
## worn, as an item's own Equip: spell is (equip_spells, through
## Talents.passive_spells); a proc spell fires on melee hits at its
## own chance per hit, the game's own in place of classic's rate per minute (proc_spells, SpellProcs).

const TYPE_PROC := 1
const TYPE_WEAPON_DAMAGE := 2
const TYPE_EQUIP_SPELL := 3
const TYPE_RESISTANCE := 4
const TYPE_STAT := 5
## SPELL_EFFECT_DISENCHANT.
static var EFFECT_DISENCHANT := 99
## An item's Equip: spell trigger (ITEM_SPELLTRIGGER_ON_EQUIP).
static var ON_EQUIP := 1
## Item quality: uncommon to epic can be disenchanted.
const DISENCHANT_QUALITIES := [2, 3, 4]
## ITEM_CLASS_RECIPE: Formulas that teach a recipe.
static var ITEM_CLASS_RECIPE := 9
const ENCHANT_COLOR := Color(0.12, 1.0, 0.0)


static func enchant_of(stack: Dictionary) -> Dictionary:
	return ProfessionDB.enchant(int(stack.get("enchant", 0))) if stack.has("enchant") else {}


## The enchant's line on the item's tooltip: its name, in green.
static func line(enchant_id: int) -> String:
	return str(ProfessionDB.enchant(enchant_id).get("name", ""))


## How an enchanted weapon looks, by words in its enchant's name: a glow on
## the blade in its colour and a mist of it about the weapon (Vfx.weapon_mist:
## "up" rising off it, "down" sinking, "swirl" hanging round it). Each weapon
## enchant has its own; others a soft blue.
const WEAPON_LOOKS := [
	["fiery", Color(1.0, 0.68, 0.18), "up"],
	["crusader", Color(1.0, 0.92, 0.55), "up"],
	["icy", Color(0.55, 0.82, 1.0), "down"],
	["lifestealing", Color(0.8, 0.05, 0.12), "swirl"],
	["unholy", Color(0.55, 0.2, 0.75), "swirl"],
	["demonslaying", Color(1.0, 0.35, 0.25), "up"],
	["beast", Color(0.55, 0.8, 0.3), "swirl"],
	["elemental", Color(0.3, 0.9, 0.85), "swirl"],
	["winter", Color(0.7, 0.9, 1.0), "down"],
	["spell power", Color(0.8, 0.55, 1.0), "up"],
	["healing", Color(0.55, 1.0, 0.65), "up"],
	["intellect", Color(0.5, 0.6, 1.0), "up"],
	["spirit", Color(0.65, 0.85, 1.0), "up"],
	["agility", Color(0.4, 1.0, 0.45), "up"],
	["strength", Color(1.0, 0.6, 0.3), "up"],
	["damage", Color(0.85, 0.9, 1.0), "up"],
	["striking", Color(0.85, 0.9, 1.0), "up"],
]


## The look of a weapon's enchant: { color, motion }, or {} when it has none.
static func weapon_look(stack: Dictionary) -> Dictionary:
	var enchant := enchant_of(stack)
	if enchant.is_empty():
		return {}
	var name := str(enchant.get("name", "")).to_lower()
	for look: Array in WEAPON_LOOKS:
		if str(look[0]) in name:
			return { "color": look[1], "motion": look[2] }
	return { "color": Color(0.7, 0.8, 1.0), "motion": "up" }


const SCHOOL_NAMES := ["Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane"]
const CREATURE_TYPES := { 1: "beasts", 2: "dragonkin", 3: "demons", 4: "elementals", 5: "giants", 6: "undead", 7: "humanoids" }


## What an enchant does, in words, where its name doesn't say (its line on
## a tooltip is its name: "Crusader", "Absorption (10)"): a proc's effects
## ("5% chance on hit to heal you for 75 to 125 and increase your Strength by
## 100 for 15 sec."), and equip spells whose name is vague. "" when the name
## says it all ("Agility +7").
static func describe(enchant_id: int, level := 60) -> String:
	var enchant := ProfessionDB.enchant(enchant_id)
	var parts: Array[String] = []
	for effect: Array in enchant.get("effects", []):
		var spell := SpellDB.get_spell(int(effect[3]))
		match int(effect[0]):
			TYPE_PROC:
				var proc := proc_text(spell, level, float(enchant.get("chance", 5.0)))
				if not proc.is_empty():
					parts.append(proc)
			TYPE_EQUIP_SPELL:
				var equip := _equip_text(spell, level)
				if not equip.is_empty():
					parts.append(equip)
	return " ".join(parts)


## A whole number, or "least to most".
static func _span(spell: Dictionary, i: int, level: int) -> String:
	var span := SpellDB.effect_span(spell, i, level)
	var low := absi(roundi(span.x))
	var high := absi(roundi(span.y))
	return str(low) if low == high else "%d to %d" % [mini(low, high), maxi(low, high)]


## A proc spell's effects as "5% chance on hit to ...": what happens at once
## first, then what lasts, with how long.
static func proc_text(spell: Dictionary, level: int, chance: float) -> String:
	var now: Array[String] = []
	var lasting: Array[String] = []
	var school: String = SCHOOL_NAMES[clampi(int(spell.get("School", 0)), 0, 6)]
	for i in 3:
		var amount := _span(spell, i, level)
		match int(spell.get("Effect%d" % (i + 1), 0)):
			SpellDB.EFFECT_SCHOOL_DAMAGE:
				now.append("deal %s %s damage" % [amount, school])
			SpellProcs.EFFECT_HEALTH_LEECH:
				now.append("steal %s health from the target" % amount)
			SpellDB.EFFECT_HEAL:
				now.append("heal you for %s" % amount)
			SpellDB.EFFECT_APPLY_AURA:
				var misc := int(spell.get("EffectMiscValue%d" % (i + 1), 0))
				match int(spell.get("EffectApplyAuraName%d" % (i + 1), 0)):
					29:
						lasting.append("increase your %s by %s" % [ClassicData.STAT_NAMES[clampi(misc, 0, 4)] if misc >= 0 else "stats", amount])
					33:
						lasting.append("slow the target's movement by %s%%" % amount)
					138:
						lasting.append("slow the target's attacks by %s%%" % amount)
					12:
						lasting.append("stun the target")
					13:
						lasting.append("lower the target's damage by %s" % amount)
	if now.is_empty() and lasting.is_empty():
		return ""
	var seconds := SpellDB.duration(spell)
	var parts := now.duplicate()
	if not lasting.is_empty():
		parts.append(_join(lasting) + (" for %d sec" % roundi(seconds) if seconds > 0.0 else ""))
	var text := "%s%% chance on hit to %s." % [str(int(chance)) if is_equal_approx(chance, roundf(chance)) else "%.1f" % chance, _join(parts)]
	var only := int(spell.get("TargetCreatureType", 0))
	if only != 0:
		var kinds: Array[String] = []
		for type: int in CREATURE_TYPES:
			if only & (1 << (type - 1)):
				kinds.append(CREATURE_TYPES[type])
		text = "Against %s: %s" % [_join(kinds), text.left(1).to_lower() + text.substr(1)]
	return text


## An equip spell's effect where its enchant's name is vague.
static func _equip_text(spell: Dictionary, level: int) -> String:
	var aura := int(spell.get("EffectApplyAuraName1", 0))
	var amount := _span(spell, 0, level)
	var misc := int(spell.get("EffectMiscValue1", 0))
	match aura:
		59:
			var kinds: Array[String] = []
			for type: int in CREATURE_TYPES:
				if misc & (1 << (type - 1)):
					kinds.append(CREATURE_TYPES[type])
			return "Increases damage done to %s by %s." % [_join(kinds), amount]
		31:
			return "Increases run speed by %s%%." % amount
		130:
			return "Increases mount speed by %s%%." % amount
		42:
			var chance := int(spell.get("ProcChance", 0))
			var shield := SpellDB.get_spell(int(spell.get("EffectTriggerSpell1", 0)))
			var absorbs := _span(shield, 0, level) if not shield.is_empty() else amount
			return "%d%% chance when hit to absorb %s damage." % [chance, absorbs] if chance > 0 else ""
		10:
			var threat := SpellDB.effect_value(spell, 0, level)
			return "%s the threat you cause by %d%%." % ["Increases" if threat > 0 else "Reduces", absi(roundi(threat))]
		154:
			return "Slightly improves your stealth."
	return ""


static func _join(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]


## Adds an equipped stack's enchant to the gear totals: stats, armour (a
## physical resistance), weapon damage on the weapon in its slot.
static func gear_bonus(stack: Dictionary, totals: Dictionary, weapon_key: String) -> void:
	var enchant := enchant_of(stack)
	if enchant.is_empty():
		return
	var stat_index := { 4: ClassicData.Stat.STRENGTH, 3: ClassicData.Stat.AGILITY, 7: ClassicData.Stat.STAMINA, 5: ClassicData.Stat.INTELLECT, 6: ClassicData.Stat.SPIRIT }
	for effect: Array in enchant.get("effects", []):
		var amount := int(effect[1])
		match int(effect[0]):
			TYPE_STAT:
				var kind := int(effect[3])
				if stat_index.has(kind):
					totals.stats[stat_index[kind]] += amount
				elif kind == 1:
					totals.health += amount
				elif kind == 0:
					totals.mana += amount
			TYPE_RESISTANCE:
				if int(effect[3]) == 0:
					totals.armor += amount
			TYPE_WEAPON_DAMAGE:
				if weapon_key != "" and totals.has(weapon_key):
					var weapon: Dictionary = totals[weapon_key].duplicate()
					weapon.min = float(weapon.min) + amount
					weapon.max = float(weapon.max) + amount
					totals[weapon_key] = weapon


## Equip spells of everything worn: items' own Equip: spells and enchants'
## equip spells, kept up as auras while worn.
static func equip_spells(equipment: Dictionary) -> Array[Dictionary]:
	var spells: Array[Dictionary] = []
	for slot: Variant in equipment:
		var stack: Dictionary = equipment[slot]
		if stack.is_empty() or Inventory.is_broken(stack):
			continue
		var item := ItemDB.get_item(int(stack.id))
		if int(item.get("spelltrigger_1", -1)) == ON_EQUIP and int(item.get("spellid_1", 0)) > 0:
			_add_spell(spells, int(item.spellid_1))
		for effect: Array in enchant_of(stack).get("effects", []):
			if int(effect[0]) == TYPE_EQUIP_SPELL:
				_add_spell(spells, int(effect[3]))
	return spells


static func _add_spell(spells: Array[Dictionary], id: int) -> void:
	var spell := SpellDB.get_spell(id)
	if not spell.is_empty() and SpellDB.has_effect(spell, SpellDB.EFFECT_APPLY_AURA) and not spells.has(spell):
		spells.append(spell)


## A weapon stack's proc enchants: [spell, chance per hit in %].
static func proc_spells(stack: Dictionary) -> Array:
	var procs := []
	var enchant := enchant_of(stack)
	for effect: Array in enchant.get("effects", []):
		if int(effect[0]) == TYPE_PROC:
			var spell := SpellDB.get_spell(int(effect[3]))
			if not spell.is_empty():
				procs.append([spell, float(enchant.get("chance", 5.0))])
	return procs


## Whether an enchant recipe's spell can go on an item: its
## EquippedItemClass, SubClassMask and InventoryTypeMask (Spell::CheckItems).
static func fits(spell: Dictionary, item: Dictionary) -> bool:
	var item_class := int(spell.get("EquippedItemClass", -1))
	if item_class >= 0 and int(item.get("class", -1)) != item_class:
		return false
	var subclass_mask := int(spell.get("EquippedItemSubClassMask", 0))
	if subclass_mask > 0 and subclass_mask & (1 << int(item.get("subclass", 0))) == 0:
		return false
	var type_mask := int(spell.get("EquippedItemInventoryTypeMask", 0))
	if type_mask > 0 and type_mask & (1 << int(item.get("InventoryType", 0))) == 0:
		return false
	return true


## Why an enchant recipe can't go on the item at `ref`, or "".
static func enchant_problem(recipe_id: int, ref: Dictionary) -> String:
	if ref.is_empty():
		return "You must pick an item."
	var stack := Inventory.stack_at(ref)
	if stack.is_empty():
		return "You must pick an item."
	if not fits(SpellDB.get_spell(recipe_id), ItemDB.get_item(int(stack.id))):
		return "That enchant can't go on that item."
	return ""


## Puts an enchant on the item at `ref` (replacing any it had).
static func apply(ref: Dictionary, enchant_id: int) -> void:
	var stack := Inventory.stack_at(ref)
	if stack.is_empty():
		return
	stack.enchant = enchant_id
	# Enchanting binds the item, as classic's does.
	stack.bound = true
	GameState.inventory_changed.emit()


## Why the item at `ref` can't be disenchanted by `profile`, or "".
static func disenchant_problem(profile: CharacterProfile, ref: Dictionary) -> String:
	if ref.is_empty():
		return "You must pick an item."
	var stack := Inventory.stack_at(ref)
	if stack.is_empty():
		return "You must pick an item."
	if ref.get("kind", "") != "bag":
		return "Only items in your bags can be disenchanted."
	var item := ItemDB.get_item(int(stack.id))
	if not int(item.get("Quality", 0)) in DISENCHANT_QUALITIES or int(item.get("DisenchantID", 0)) <= 0 \
			or ProfessionDB.disenchant_loot(int(item.DisenchantID)).is_empty():
		return "That item can't be disenchanted."
	var needed := int(item.get("RequiredDisenchantSkill", 0))
	if needed < 0:
		return "That item can't be disenchanted."
	if Professions.value(profile, "enchanting") < needed:
		return "Requires Enchanting %d" % needed
	return ""


## Disenchants the item at `ref`: it's destroyed, and what it breaks into is
## rolled from its disenchanting loot.
static func disenchant(ref: Dictionary) -> Array[Dictionary]:
	var stack := Inventory.stack_at(ref)
	var item := ItemDB.get_item(int(stack.id))
	var loot := LootTable.roll_entries(ProfessionDB.disenchant_loot(int(item.DisenchantID)))
	Inventory.destroy(ref)
	GameState.inventory_changed.emit()
	return loot


## The recipe a Formula teaches (a recipe whose `formula` is the item), or 0.
static func formula_recipe(item_id: int) -> int:
	for id: String in ProfessionDB.data().recipes:
		if int(ProfessionDB.data().recipes[id].get("formula", 0)) == item_id:
			return int(id)
	return 0


## Using a Formula: learns its recipe if the profession and skill allow it
## (the item's RequiredSkill and RequiredSkillRank), using it up. Returns a
## problem, or "".
static func use_formula(ref: Dictionary) -> String:
	var stack := Inventory.stack_at(ref)
	var item := ItemDB.get_item(int(stack.id))
	var recipe_id := formula_recipe(int(stack.id))
	if recipe_id == 0:
		return ""
	var name := str(ProfessionDB.recipe(recipe_id).profession)
	if not Professions.knows(GameState, name):
		return "Requires %s" % Professions.title(name)
	if Professions.value(GameState, name) < int(item.get("RequiredSkillRank", 0)):
		return "Requires %s (%d)" % [Professions.title(name), int(item.RequiredSkillRank)]
	if GameState.level < int(item.get("RequiredLevel", 0)):
		return "You must be level %d to use that." % int(item.RequiredLevel)
	if recipe_id in GameState.known_spells:
		return "You already know that."
	Inventory.remove_one(ref)
	Professions.learn_spells(GameState, [recipe_id])
	Chat.system("You have learned how to create a new item: %s." % SpellDB.full_name(SpellDB.get_spell(recipe_id)))
	Sfx.play("level_up")
	GameState.inventory_changed.emit()
	return ""
