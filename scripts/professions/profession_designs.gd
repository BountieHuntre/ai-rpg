class_name ProfessionDesigns
extends RefCounted
## The professions' design files (data/designs/professions/<name>.json),
## beside the classes': each is a class design (spell groups and the
## trainer's list, SpellDesigns, read over spells.json) with a `recipe` on
## each recipe's rank, plus sections of its own read over professions.json:
## `profession` (its skill, ranks, start spells and tools), `nodes` (herbs or
## ore and their loot), `skinning_loot`, `disenchant_loot` and `enchants`.
## Items are written { "item": id, "name": "Copper Ore" }: the name is for
## reading and is ignored when read back. docs/spells/FIELDS.md describes it.

const FILES := [["herbalism", "professions/herbalism"], ["mining", "professions/mining"],
	["skinning", "professions/skinning"], ["enchanting", "professions/enchanting"]]
## Item enchantment effects (ITEM_ENCHANTMENT_TYPE) by name.
const ENCHANT_EFFECTS := { 1: "proc_spell", 2: "weapon_damage", 3: "equip_spell", 4: "resistance", 5: "stat", 6: "totem" }
## Item stat types (ITEM_MOD) an enchant's `stat` effect raises.
const ITEM_STATS := { 0: "mana", 1: "health", 3: "agility", 4: "strength", 5: "intellect", 6: "spirit", 7: "stamina" }
## Spell focus objects by name: Smelting needs a forge.
const FOCUS := { 3: "forge", 1: "anvil" }

## Item names for writing designs (the export tool sets it); reading never
## needs them.
static var item_names: Dictionary = {}


static func item_ref(id: int) -> Dictionary:
	return { "item": id, "name": str(item_names.get(str(id), "")) }


static func _item(ref: Variant) -> int:
	return int(ref.item) if ref is Dictionary else int(ref)


# Recipes, on their spell's rank in the spell groups.

static func encode_recipe(recipe: Dictionary) -> Dictionary:
	var out := { "skill": recipe.skill, "levels": recipe.levels }
	out.reagents = recipe.reagents.map(func(r: Array) -> Dictionary: return item_ref(int(r[0])).merged({ "count": int(r[1]) }))
	if not recipe.tools.is_empty():
		out.tools = recipe.tools.map(func(t: Variant) -> Dictionary: return item_ref(int(t)))
	if int(recipe.focus) != 0:
		out.focus = FOCUS.get(int(recipe.focus), int(recipe.focus))
	if recipe.has("makes"):
		out.makes = item_ref(int(recipe.makes[0])).merged({ "count": int(recipe.makes[1]) })
	if recipe.has("enchant"):
		out.enchant = int(recipe.enchant)
		if recipe.get("temporary", false):
			out.temporary = true
	if recipe.has("formula"):
		out.formula = item_ref(int(recipe.formula))
	return out


static func decode_recipe(d: Dictionary, profession: String) -> Dictionary:
	var out := { "profession": profession, "skill": int(d.get("skill", 1)) }
	var levels: Array = d.get("levels", [])
	out.levels = levels.map(func(v: Variant) -> int: return int(v)) if levels.size() == 4 else [out.skill, out.skill, out.skill, out.skill]
	out.reagents = (d.get("reagents", []) as Array).map(func(r: Variant) -> Array: return [_item(r), int(r.get("count", 1)) if r is Dictionary else 1])
	out.tools = (d.get("tools", []) as Array).map(func(t: Variant) -> int: return _item(t))
	var focus: Variant = d.get("focus", 0)
	out.focus = FOCUS.find_key(focus) if FOCUS.values().has(focus) else int(focus)
	if d.has("makes"):
		out.makes = [_item(d.makes), int(d.makes.get("count", 1)) if d.makes is Dictionary else 1]
	if d.has("enchant"):
		out.enchant = int(d.enchant)
		out.temporary = bool(d.get("temporary", false))
	if d.has("formula"):
		out.formula = _item(d.formula)
	return out


# Loot tables.

static func encode_loot(entries: Array) -> Array:
	var out := []
	for e: Dictionary in entries:
		var row: Dictionary
		if int(e.min_or_ref) < 0:
			row = { "reference": -int(e.min_or_ref) }
		else:
			row = item_ref(int(e.item))
			row.count = [int(e.min_or_ref), int(e.max)]
		row.chance = e.chance
		if int(e.group) != 0:
			row.group = int(e.group)
		if int(e.condition) != 0:
			row.condition = int(e.condition)
		if int(e.min_or_ref) < 0 and int(e.max) != 1:
			row.times = int(e.max)
		out.append(row)
	return out


static func decode_loot(rows: Array) -> Array:
	var out := []
	for row: Dictionary in rows:
		var entry := { "chance": float(row.get("chance", 100.0)), "group": int(row.get("group", 0)),
			"condition": int(row.get("condition", 0)) }
		if row.has("reference"):
			# A reference row names its table in its item too, as classic's do.
			entry.item = int(row.reference)
			entry.min_or_ref = -int(row.reference)
			entry.max = int(row.get("times", 1))
		else:
			var count: Array = row.get("count", [1, 1])
			entry.item = _item(row)
			entry.min_or_ref = int(count[0])
			entry.max = int(count[1]) if count.size() > 1 else int(count[0])
		out.append(entry)
	return out


# Enchantments.

static func encode_enchant(id: String, enchant: Dictionary) -> Dictionary:
	var out := { "id": int(id), "name": enchant.name }
	if int(enchant.get("charges", 0)) != 0:
		out.charges = int(enchant.charges)
	if enchant.has("chance"):
		out.chance = enchant.chance
	var effects := []
	for effect: Array in enchant.effects:
		var kind := int(effect[0])
		var e := { "type": ENCHANT_EFFECTS.get(kind, kind) }
		match kind:
			1, 3:
				e.spell = int(effect[3])
			4:
				e.value = int(effect[1])
				e.school = SpellDesigns.name_of("schools", int(effect[3]))
			5:
				e.value = int(effect[1])
				e.stat = ITEM_STATS.get(int(effect[3]), int(effect[3]))
			_:
				e.value = int(effect[1]) if int(effect[1]) == int(effect[2]) else [int(effect[1]), int(effect[2])]
				if int(effect[3]) != 0:
					e.arg = int(effect[3])
		effects.append(e)
	out.effects = effects
	return out


static func decode_enchant(d: Dictionary) -> Dictionary:
	var out := { "name": str(d.get("name", "")), "charges": int(d.get("charges", 0)) }
	if d.has("chance"):
		out.chance = float(d.chance)
	var effects := []
	for e: Dictionary in d.get("effects", []):
		var kind: int = ENCHANT_EFFECTS.find_key(e.get("type")) if ENCHANT_EFFECTS.values().has(e.get("type")) else int(e.get("type", 0))
		var value: Variant = e.get("value", 0)
		var low := int(value[0]) if value is Array else int(value)
		var high := int(value[1]) if value is Array else low
		var arg := int(e.get("arg", 0))
		match kind:
			1, 3:
				arg = int(e.get("spell", 0))
			4:
				arg = SpellDesigns.number_of("schools", e.get("school", "physical"))
			5:
				var stat: Variant = e.get("stat", 0)
				arg = ITEM_STATS.find_key(stat) if ITEM_STATS.values().has(stat) else int(stat)
		effects.append([kind, low, high, arg])
	out.effects = effects
	return out


# A profession's own sections.

static func encode_profession(classic: Dictionary, name: String) -> Dictionary:
	var prof: Dictionary = classic.professions[name]
	var out := {}
	out.profession = { "name": name.capitalize(), "skill": int(prof.skill),
		"ranks": prof.ranks.map(func(r: Dictionary) -> Dictionary:
			return { "spell": int(r.spell), "rank": r.rank, "max": int(r.max), "level": int(r.level), "skill": int(r.skill), "price": int(r.cost) }),
		"start": prof.start, "tools": prof.tools.map(func(t: Variant) -> Dictionary: return item_ref(int(t))) }
	var kind: String = { "herbalism": "herb", "mining": "ore" }.get(name, "")
	if kind != "":
		var nodes := []
		for id: String in classic.nodes:
			var node: Dictionary = classic.nodes[id]
			if node.kind == kind:
				nodes.append({ "id": int(id), "name": node.name, "skill": int(node.skill), "size": node.size, "respawn": int(node.respawn),
					"loot_id": int(node.loot), "loot": encode_loot(classic.node_loot.get(str(int(node.loot)), [])) })
		nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.skill < b.skill or (a.skill == b.skill and a.id < b.id))
		out.nodes = nodes
	if name == "skinning":
		var tables := []
		for id: String in classic.skinning_loot:
			tables.append({ "id": int(id), "loot": encode_loot(classic.skinning_loot[id]) })
		tables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		out.skinning_loot = tables
	if name == "enchanting":
		var tables := []
		for id: String in classic.disenchant_loot:
			tables.append({ "id": int(id), "loot": encode_loot(classic.disenchant_loot[id]) })
		tables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		out.disenchant_loot = tables
		var enchants := []
		for id: String in classic.enchants:
			enchants.append(encode_enchant(id, classic.enchants[id]))
		enchants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
		out.enchants = enchants
	return out


## A profession design's sections back in professions.json's shape (its
## recipes come from its spell groups, decode_class's `recipes`).
static func decode_profession(design: Dictionary, name: String, recipes: Dictionary) -> Dictionary:
	var out := { "professions": {}, "recipes": {}, "nodes": {}, "node_loot": {}, "skinning_loot": {},
		"disenchant_loot": {}, "enchants": {} }
	for id: String in recipes:
		out.recipes[id] = decode_recipe(recipes[id], name)
	var prof: Dictionary = design.get("profession", {})
	out.professions[name] = { "skill": int(prof.get("skill", 0)),
		"ranks": (prof.get("ranks", []) as Array).map(func(r: Dictionary) -> Dictionary:
			return { "spell": int(r.spell), "rank": str(r.get("rank", "")), "max": int(r.get("max", 75)), "level": int(r.get("level", 1)),
				"skill": int(r.get("skill", 0)), "cost": int(r.get("price", 0)) }),
		"start": (prof.get("start", []) as Array).map(func(s: Variant) -> int: return int(s)),
		"tools": (prof.get("tools", []) as Array).map(func(t: Variant) -> int: return _item(t)) }
	var kind: String = { "herbalism": "herb", "mining": "ore" }.get(name, "")
	for node: Dictionary in design.get("nodes", []):
		var loot_id := int(node.get("loot_id", node.get("id", 0)))
		out.nodes[str(int(node.id))] = { "name": str(node.get("name", "")), "kind": kind, "skill": int(node.get("skill", 1)),
			"loot": loot_id, "size": float(node.get("size", 1.0)), "respawn": int(node.get("respawn", 300)) }
		out.node_loot[str(loot_id)] = decode_loot(node.get("loot", []))
	for table: Dictionary in design.get("skinning_loot", []):
		out.skinning_loot[str(int(table.id))] = decode_loot(table.get("loot", []))
	for table: Dictionary in design.get("disenchant_loot", []):
		out.disenchant_loot[str(int(table.id))] = decode_loot(table.get("loot", []))
	for enchant: Dictionary in design.get("enchants", []):
		out.enchants[str(int(enchant.id))] = decode_enchant(enchant)
	return out


## Every profession design read over professions.json's data.
static func apply(data: Dictionary) -> void:
	for spec: Array in FILES:
		var design := SpellDesigns.design_of(str(spec[1]))
		if design.is_empty():
			continue
		var built := SpellDesigns.decode_class(design, str(spec[1]))
		var decoded := decode_profession(design, str(spec[0]), built.get("recipes", {}))
		for key: String in decoded:
			if not data.has(key):
				data[key] = {}
			# This profession's recipes replace classic's for it.
			if key == "recipes":
				for id: String in (data.recipes as Dictionary).keys():
					if str(data.recipes[id].get("profession", "")) == str(spec[0]):
						data.recipes.erase(id)
			(data[key] as Dictionary).merge(decoded[key], true)
