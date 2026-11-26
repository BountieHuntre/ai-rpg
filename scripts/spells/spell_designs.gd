class_name SpellDesigns
extends RefCounted
## Spell design files: every class's spells and talents in readable fields,
## `data/designs/<class>.json`, which the game reads over classic's data
## (SpellDB._get_data) and the Developer tab's spell editor writes. A design
## gives each spell's numbers in seconds, yards and names rather than
## classic's indexes, masks and ids; `encode` turns a classic spell row into
## its design and `decode` turns it back (the same spell, so a class's designs
## build exactly the spells classic's data had: tools/spells/check_designs.gd).
## The names are data/designs/names.json (tools/spells/make_names.py); a
## design may give a number where it has no name. Every field is in
## docs/spells/FIELDS.md.

const DESIGN_DIR := "res://data/designs/"
const NAMES_PATH := "res://data/designs/names.json"
## Each design file's class: [class id, its trainer list's key, file name].
const CLASSES := [[1, "warrior", "man_at_arms"], [2, "paladin", "templar"], [3, "hunter", "ranger"],
	[5, "priest", "cleric"], [10, "spellsword", "spellsword"]]
## New spells and talents a design adds take ids from here up (no classic
## spell or the Spellsword's uses them).
static var NEW_SPELL_IDS := 950000
static var NEW_TALENT_IDS := 9500
## Side tables of spells.json keyed by spell id, kept in a spell's design.
const SIDE_TABLES := ["judgement_procs", "holy_shock", "seal_of_righteousness_procs"]

static var _names: Dictionary
## Readable name -> number, per table.
static var _numbers: Dictionary
## Problems found reading designs: shown in the console and the editor.
static var warnings: Array[String] = []


static func names() -> Dictionary:
	if _names.is_empty():
		_names = JSON.parse_string(FileAccess.get_file_as_string(NAMES_PATH))
		for table: String in _names:
			var back := {}
			for number: String in _names[table]:
				back[_names[table][number]] = int(number)
			_numbers[table] = back
	return _names


## A number's name in a table, or the number where it has none.
static func name_of(table: String, number: int) -> Variant:
	return names().get(table, {}).get(str(number), number)


## A name's number in a table (a number given stays one); -1 and a warning
## for a name it doesn't know.
static func number_of(table: String, value: Variant, where := "") -> int:
	names()
	if value is String:
		if _numbers.get(table, {}).has(value):
			return _numbers[table][value]
		if (value as String).is_valid_int():
			return int(value)
		warnings.append("%s: unknown %s \"%s\"" % [where, table.trim_suffix("s"), value])
		return -1
	return int(value)


## Bits of a mask as names (or hex numbers for bits with none).
static func bits_of(table: String, mask: int) -> Array:
	var out := []
	for bit in 32:
		var value := 1 << bit
		if mask & value:
			var label: Variant = names().get(table, {}).get(str(value), null)
			out.append(label if label != null else "0x%x" % value)
	return out


static func mask_of(table: String, list: Array, where := "") -> int:
	var mask := 0
	for item: Variant in list:
		if item is String and (item as String).begins_with("0x"):
			mask |= (item as String).hex_to_int()
		else:
			var number := number_of(table, item, where)
			if number > 0:
				mask |= number
	return mask


## Index masks (forms, weapon and armour types, creature types: bit n-1 or n)
## as names.
static func index_bits_of(table: String, mask: int, offset: int) -> Array:
	var out := []
	for bit in 32:
		if mask & (1 << bit):
			out.append(name_of(table, bit + offset))
	return out


static func index_mask_of(table: String, list: Array, offset: int, where := "") -> int:
	var mask := 0
	for item: Variant in list:
		var number := number_of(table, item, where)
		if number >= offset:
			mask |= 1 << (number - offset)
	return mask


# One spell.

## A classic spell row as its design.
static func encode(row: Dictionary) -> Dictionary:
	var d := {}
	var raw := row.duplicate()
	var take := func(key: String) -> Variant:
		var value: Variant = raw.get(key, 0)
		raw.erase(key)
		return value
	d.id = int(take.call("Id"))
	d.name = str(take.call("SpellName"))
	var rank := str(take.call("Rank1"))
	if rank.begins_with("Rank ") and rank.substr(5).is_valid_int():
		d.rank = int(rank.substr(5))
	elif rank != "" and rank != "0":
		d.rank_text = rank
	var school := int(take.call("School"))
	if school != 0:
		d.school = name_of("schools", school)
	var dmg_class := int(take.call("DmgClass"))
	if dmg_class != 0:
		d.damage_class = name_of("dmg_classes", dmg_class)
	for pair: Array in [["SpellLevel", "level"], ["BaseLevel", "base_level"], ["MaxLevel", "max_level"],
			["Speed", "speed"], ["StackAmount", "stacks"], ["ProcChance", "proc_chance"], ["ProcCharges", "charges"],
			["Category", "category"], ["StartRecoveryCategory", "gcd_category"], ["SpellFamilyName", "family"],
			["SpellFamilyFlags", "family_flags"], ["SpellIconID", "icon_id"], ["ExtraValue", "extra_value"],
			["Targets", "target_flags"], ["InterruptFlags", "interrupt_flags"], ["AuraInterruptFlags", "aura_interrupt_flags"],
			["RequiresSpellFocus", "spell_focus"], ["PreventionType", "prevention"],
			["EquippedItemInventoryTypeMask", "item_slots"]]:
		var value: Variant = take.call(pair[0])
		if value is float and value == floorf(value):
			value = int(value)
		if value != 0 and str(value) != "0":
			d[pair[1]] = value
	_seconds(d, "cast", take.call("CastingTimeIndex"), SpellDB.CAST_TIMES, 1)
	_seconds(d, "duration", take.call("DurationIndex"), SpellDB.DURATIONS, 0)
	var range_index := int(take.call("RangeIndex"))
	if range_index != 1:
		if SpellDB.RANGES.has(range_index):
			d.range = SpellDB.RANGES[range_index]
			if SpellDB.MIN_RANGES.has(range_index):
				d.min_range = SpellDB.MIN_RANGES[range_index]
		else:
			d.range_index = range_index
	for pair: Array in [["RecoveryTime", "cooldown"], ["CategoryRecoveryTime", "category_cooldown"], ["StartRecoveryTime", "gcd"]]:
		var ms := int(take.call(pair[0]))
		if ms != 0:
			d[pair[1]] = ms / 1000.0
	var power := int(take.call("PowerType"))
	var cost := int(take.call("ManaCost"))
	var percent := int(take.call("ManaCostPercentage"))
	if power != 0:
		d.power = name_of("powers", power)
	if cost != 0:
		# Rage is kept in tenths.
		d.cost = cost / 10.0 if power == SpellDB.POWER_RAGE else cost
	if percent != 0:
		d.cost_percent = percent
	var attributes := int(take.call("Attributes"))
	if attributes != 0:
		d.attributes = bits_of("attributes", attributes)
	for pair: Array in [["AttributesEx", "attributes_ex"], ["AttributesEx2", "attributes_ex2"], ["AttributesEx3", "attributes_ex3"]]:
		var mask := int(take.call(pair[0]))
		if mask != 0:
			d[pair[1]] = bits_of("none", mask)
	var procs := int(take.call("ProcFlags"))
	if procs != 0:
		d.proc_on = bits_of("proc_flags", procs)
	var stances := int(take.call("Stances"))
	if stances != 0:
		d.stances = index_bits_of("forms", stances, 1)
	var creatures := int(take.call("TargetCreatureType"))
	if creatures != 0:
		d.creature_types = index_bits_of("creature_types", creatures, 1)
	var item_class := int(raw.get("EquippedItemClass", -1))
	raw.erase("EquippedItemClass")
	var item_mask := int(take.call("EquippedItemSubClassMask"))
	if item_class != -1 and item_class != 0 or item_mask != 0:
		d.requires_item = name_of("item_classes", item_class)
		if item_mask == -1:
			d.item_types = "all"
		elif item_mask != 0:
			d.item_types = index_bits_of("weapons" if item_class == 2 else "armor", item_mask, 0)
	elif item_class == 0:
		d.requires_item = "consumable"
	var mechanic := int(take.call("Mechanic"))
	if mechanic != 0:
		d.mechanic = name_of("mechanics", mechanic)
	var dispel := int(take.call("Dispel"))
	if dispel != 0:
		d.dispel = name_of("dispels", dispel)
	var text := str(take.call("Description"))
	if text != "" and text != "0":
		d.text = text
	var icon := str(take.call("Icon"))
	if icon != "" and icon != "0":
		d.icon = icon
	var effects := []
	for n in [1, 2, 3]:
		var effect := _encode_effect(raw, n)
		if not effect.is_empty():
			# An effect in a later slot than its place in the list says so.
			if n != effects.size() + 1:
				effect.slot = n
			effects.append(effect)
	if not effects.is_empty():
		d.effects = effects
	# What's left is kept as it was.
	for key: String in raw.keys():
		var value: Variant = raw[key]
		if value == null or str(value) == "0" or str(value) == "" or (value is float and value == 0.0):
			raw.erase(key)
	if not raw.is_empty():
		d.raw = raw
	return d


static func _seconds(d: Dictionary, key: String, index: Variant, table: Dictionary, default_index: int) -> void:
	var i := int(index)
	if i == default_index or (i == 0 and default_index == 0):
		return
	if table.has(i):
		var value: float = table[i]
		if value != 0.0:
			d[key] = "until_cancelled" if value < 0.0 else value
	else:
		d[key + "_index"] = i


static func _encode_effect(raw: Dictionary, n: int) -> Dictionary:
	var fields := {}
	for field: String in ["Effect", "EffectApplyAuraName", "EffectBasePoints", "EffectBaseDice", "EffectDieSides",
			"EffectDicePerLevel", "EffectRealPointsPerLevel", "EffectImplicitTargetA", "EffectImplicitTargetB",
			"EffectRadiusIndex", "EffectAmplitude", "EffectTriggerSpell", "EffectMiscValue", "EffectItemType",
			"EffectMechanic", "EffectMultipleValue", "DmgMultiplier", "EffectCostShare", "EffectCostOf", "EffectAffectsInstant"]:
		fields[field] = raw.get(field + str(n), 0)
		raw.erase(field + str(n))
	var type := int(fields.Effect)
	if type == 0:
		return {}
	var e := {}
	e.type = name_of("effects", type)
	var aura := int(fields.EffectApplyAuraName)
	if aura != 0:
		e.aura = name_of("auras", aura)
	var base := int(fields.EffectBasePoints)
	var dice := int(fields.EffectBaseDice)
	var sides := int(fields.EffectDieSides)
	var low := base + dice
	var high := base + maxi(dice, sides)
	e.value = low if low == high else [low, high]
	if dice != 1:
		e.dice = dice
	for pair: Array in [["EffectDicePerLevel", "dice_per_level"], ["EffectRealPointsPerLevel", "per_level"],
			["EffectTriggerSpell", "trigger"], ["EffectMultipleValue", "multiple_value"], ["EffectCostShare", "cost_share"], ["EffectCostOf", "cost_of"]]:
		var value: Variant = fields[pair[0]]
		if value is float and value == floorf(value):
			value = int(value)
		if str(value) != "0" and value != 0:
			e[pair[1]] = value
	var misc := int(fields.EffectMiscValue)
	_name_misc(e, type, aura, misc, int(fields.EffectItemType))
	# The game's own: a spell modifier on every instant spell of the class.
	if int(fields.EffectAffectsInstant) != 0:
		e.affects = "instant"
	var target := int(fields.EffectImplicitTargetA)
	if target != 0:
		e.target = name_of("targets", target)
	var target_b := int(fields.EffectImplicitTargetB)
	if target_b != 0:
		e.target_b = name_of("targets", target_b)
	var radius := int(fields.EffectRadiusIndex)
	if radius != 0:
		if SpellDB.RADII.has(radius):
			e.radius = SpellDB.RADII[radius]
		else:
			e.radius_index = radius
	var period := int(fields.EffectAmplitude)
	if period != 0:
		e.period = period / 1000.0
	var mechanic := int(fields.EffectMechanic)
	if mechanic != 0:
		e.mechanic = name_of("mechanics", mechanic)
	var multiplier := float(fields.DmgMultiplier)
	if multiplier != 1.0:
		e.multiplier = multiplier
	return e


## What an effect's misc value (and a modifier's item mask) means, by its
## type and aura, as a readable key: a stat aura's stat, a modifier's
## property and the spells it affects, a form, a mechanic, schools, a
## dispel type, a power; else plain `misc` and `item`.
const STAT_AURAS := ["stat", "stat_percent", "total_stat_percent"]
const SCHOOL_AURAS := ["resistance", "damage_done", "damage_taken", "damage_percent_done", "damage_percent_taken",
	"school_absorb", "school_immunity", "damage_immunity", "base_resistance", "base_resistance_percent",
	"resistance_percent", "resistance_exclusive", "healing", "healing_done", "spell_crit_chance_school",
	"power_cost_school", "power_cost_school_percent", "reflect_spells_school", "target_resistance",
	"split_damage_percent", "damage_shield", "mana_shield", "spell_hit_chance", "attacker_spell_crit_chance"]


static func _name_misc(e: Dictionary, type: int, aura: int, misc: int, item: int) -> void:
	var aura_name := str(name_of("auras", aura)) if aura != 0 else ""
	var type_name := str(name_of("effects", type))
	if aura_name in STAT_AURAS:
		e.stat = name_of("stats", misc)
	elif aura_name in ["flat_modifier", "percent_modifier"]:
		e.modifies = name_of("spell_mods", misc)
		if item != 0:
			e.affects = item
		return
	elif aura_name == "shapeshift":
		e.form = name_of("forms", misc)
	elif aura_name in ["mechanic_immunity", "mechanic_resistance"]:
		e.against = name_of("mechanics", misc)
	elif aura_name in SCHOOL_AURAS and misc > 0 and misc < 128:
		e.schools = bits_of("none", 0)
		for school in 7:
			if misc & (1 << school):
				e.schools.append(name_of("schools", school))
	elif type_name == "dispel" and aura == 0:
		e.dispel = name_of("dispels", misc)
	elif type_name == "energize" or aura_name == "periodic_energize":
		e.power = name_of("powers", misc)
	elif misc != 0:
		e.misc = misc
	if item != 0:
		e.item = item


static func _misc_of(e: Dictionary, where: String) -> int:
	if e.has("stat"):
		return number_of("stats", e.stat, where)
	if e.has("modifies"):
		return number_of("spell_mods", e.modifies, where)
	if e.has("form"):
		return number_of("forms", e.form, where)
	if e.has("against"):
		return number_of("mechanics", e.against, where)
	if e.has("schools"):
		var mask := 0
		for school: Variant in e.schools:
			mask |= 1 << number_of("schools", school, where)
		return mask
	if e.has("dispel"):
		return number_of("dispels", e.dispel, where)
	if e.has("power"):
		return number_of("powers", e.power, where)
	return int(e.get("misc", 0))


## A design as a classic spell row. `where` names it in warnings.
## Every field of a classic spell_template row (spells.json's), which a
## design's spells are given whatever they leave out, with these defaults
## (0 for the rest).
const ROW_FIELDS := ["Id", "SpellName", "Rank1", "School", "Category", "Dispel", "Mechanic", "Attributes",
	"AttributesEx", "AttributesEx2", "AttributesEx3", "Targets", "CastingTimeIndex", "RecoveryTime",
	"CategoryRecoveryTime", "StartRecoveryCategory", "StartRecoveryTime", "InterruptFlags", "AuraInterruptFlags",
	"ProcFlags", "ProcChance", "ProcCharges", "MaxLevel", "BaseLevel", "SpellLevel", "DurationIndex", "PowerType",
	"ManaCost", "ManaCostPercentage", "RangeIndex", "Speed", "StackAmount", "DmgClass", "SpellFamilyName",
	"SpellFamilyFlags", "SpellIconID", "PreventionType", "Effect1", "EffectDieSides1", "EffectBaseDice1",
	"EffectDicePerLevel1", "EffectRealPointsPerLevel1", "EffectBasePoints1", "EffectMechanic1",
	"EffectImplicitTargetA1", "EffectImplicitTargetB1", "EffectRadiusIndex1", "EffectApplyAuraName1",
	"EffectAmplitude1", "EffectMiscValue1", "EffectTriggerSpell1", "EffectMultipleValue1", "DmgMultiplier1", "Effect2",
	"EffectDieSides2", "EffectBaseDice2", "EffectDicePerLevel2", "EffectRealPointsPerLevel2", "EffectBasePoints2",
	"EffectMechanic2", "EffectImplicitTargetA2", "EffectImplicitTargetB2", "EffectRadiusIndex2", "EffectApplyAuraName2",
	"EffectAmplitude2", "EffectMiscValue2", "EffectTriggerSpell2", "EffectMultipleValue2", "DmgMultiplier2", "Effect3",
	"EffectDieSides3", "EffectBaseDice3", "EffectDicePerLevel3", "EffectRealPointsPerLevel3", "EffectBasePoints3",
	"EffectMechanic3", "EffectImplicitTargetA3", "EffectImplicitTargetB3", "EffectRadiusIndex3", "EffectApplyAuraName3",
	"EffectAmplitude3", "EffectMiscValue3", "EffectTriggerSpell3", "EffectMultipleValue3", "DmgMultiplier3",
	"TargetCreatureType", "Stances", "EffectItemType1", "EffectItemType2", "EffectItemType3", "EquippedItemClass",
	"EquippedItemSubClassMask", "EquippedItemInventoryTypeMask", "RequiresSpellFocus"]
const ROW_DEFAULTS := { "SpellName": "", "Rank1": "", "CastingTimeIndex": 1, "RangeIndex": 1, "EquippedItemClass": -1,
	"DmgMultiplier1": 1.0, "DmgMultiplier2": 1.0, "DmgMultiplier3": 1.0 }


static func decode(d: Dictionary, where := "") -> Dictionary:
	var row := {}
	var known := { "id": true, "name": true, "rank": true, "rank_text": true, "trainer": true, "book_tab": true,
		"school": true, "damage_class": true,
		"link": true, "proc": true, "coefficients": true, "extra": true, "effects": true, "raw": true, "chain_entry": true,
		"chain_link": true, "recipe": true }
	row.Id = int(d.get("id", 0))
	row.SpellName = str(d.get("name", ""))
	if d.has("rank"):
		row.Rank1 = "Rank %d" % int(d.rank)
	elif d.has("rank_text"):
		row.Rank1 = str(d.rank_text)
	else:
		row.Rank1 = ""
	if d.has("school"):
		row.School = number_of("schools", d.school, where)
	if d.has("damage_class"):
		row.DmgClass = number_of("dmg_classes", d.damage_class, where)
	for pair: Array in [["SpellLevel", "level"], ["BaseLevel", "base_level"], ["MaxLevel", "max_level"],
			["Speed", "speed"], ["StackAmount", "stacks"], ["ProcChance", "proc_chance"], ["ProcCharges", "charges"],
			["Category", "category"], ["StartRecoveryCategory", "gcd_category"], ["SpellFamilyName", "family"],
			["SpellFamilyFlags", "family_flags"], ["SpellIconID", "icon_id"], ["ExtraValue", "extra_value"],
			["Targets", "target_flags"], ["InterruptFlags", "interrupt_flags"], ["AuraInterruptFlags", "aura_interrupt_flags"],
			["RequiresSpellFocus", "spell_focus"], ["PreventionType", "prevention"],
			["EquippedItemInventoryTypeMask", "item_slots"]]:
		known[pair[1]] = true
		if d.has(pair[1]):
			row[pair[0]] = d[pair[1]]
	known.cast = true
	known.cast_index = true
	row.CastingTimeIndex = _index_of(d, "cast", SpellDB.CAST_TIMES, 1, row, "CastTime")
	known.duration = true
	known.duration_index = true
	row.DurationIndex = _index_of(d, "duration", SpellDB.DURATIONS, 0, row, "Duration")
	known.range = true
	known.min_range = true
	known.range_index = true
	if d.has("range_index"):
		row.RangeIndex = int(d.range_index)
	elif d.has("range"):
		row.RangeIndex = 0
		for i: int in SpellDB.RANGES:
			if is_equal_approx(SpellDB.RANGES[i], float(d.range)) \
					and is_equal_approx(SpellDB.MIN_RANGES.get(i, 0.0), float(d.get("min_range", 0.0))):
				row.RangeIndex = i
				break
		if row.RangeIndex == 0:
			row.Range = float(d.range)
			row.MinRange = float(d.get("min_range", 0.0))
	else:
		row.RangeIndex = 1
	for pair: Array in [["RecoveryTime", "cooldown"], ["CategoryRecoveryTime", "category_cooldown"], ["StartRecoveryTime", "gcd"]]:
		known[pair[1]] = true
		if d.has(pair[1]):
			row[pair[0]] = int(roundf(float(d[pair[1]]) * 1000.0))
	known.power = true
	known.cost = true
	known.cost_percent = true
	var power := number_of("powers", d.get("power", "mana"), where)
	row.PowerType = power
	if d.has("cost"):
		row.ManaCost = int(roundf(float(d.cost) * (10.0 if power == SpellDB.POWER_RAGE else 1.0)))
	if d.has("cost_percent"):
		row.ManaCostPercentage = int(d.cost_percent)
	known.attributes = true
	if d.has("attributes"):
		row.Attributes = mask_of("attributes", d.attributes, where)
	for pair: Array in [["AttributesEx", "attributes_ex"], ["AttributesEx2", "attributes_ex2"], ["AttributesEx3", "attributes_ex3"]]:
		known[pair[1]] = true
		if d.has(pair[1]):
			row[pair[0]] = mask_of("none", d[pair[1]], where)
	known.proc_on = true
	if d.has("proc_on"):
		row.ProcFlags = mask_of("proc_flags", d.proc_on, where)
	known.stances = true
	if d.has("stances"):
		row.Stances = index_mask_of("forms", d.stances, 1, where)
	known.creature_types = true
	if d.has("creature_types"):
		row.TargetCreatureType = index_mask_of("creature_types", d.creature_types, 1, where)
	known.requires_item = true
	known.item_types = true
	row.EquippedItemClass = number_of("item_classes", d.get("requires_item", "none"), where)
	if str(d.get("item_types", "")) == "all":
		row.EquippedItemSubClassMask = -1
	elif d.has("item_types"):
		row.EquippedItemSubClassMask = index_mask_of("weapons" if row.EquippedItemClass == 2 else "armor", d.item_types, 0, where)
	known.mechanic = true
	if d.has("mechanic"):
		row.Mechanic = number_of("mechanics", d.mechanic, where)
	known.dispel = true
	if d.has("dispel"):
		row.Dispel = number_of("dispels", d.dispel, where)
	known.text = true
	if d.has("text"):
		row.Description = str(d.text)
	known.icon = true
	if d.has("icon"):
		row.Icon = str(d.icon)
	var effects: Array = d.get("effects", [])
	for n in 3:
		row["DmgMultiplier%d" % (n + 1)] = 1.0
	var slot := 0
	for n in mini(effects.size(), 3):
		var effect: Dictionary = effects[n]
		slot = clampi(int(effect.get("slot", slot + 1)), slot + 1, 3)
		_decode_effect(effect, slot, row, "%s effect %d" % [where, slot])
	if effects.size() > 3:
		warnings.append("%s: a spell has at most 3 effects" % where)
	for key: String in d.get("raw", {}):
		row[key] = d.raw[key]
	for key: String in d:
		if not known.has(key):
			warnings.append("%s: unknown field \"%s\"" % [where, key])
	# Every field a classic row has, as the game's code reads them straight.
	for field: String in ROW_FIELDS:
		if not row.has(field):
			row[field] = ROW_DEFAULTS.get(field, 0)
	return row


static func _index_of(d: Dictionary, key: String, table: Dictionary, default_index: int, row: Dictionary, direct: String) -> int:
	if d.has(key + "_index"):
		return int(d[key + "_index"])
	if not d.has(key):
		return default_index
	var seconds := -1.0 if str(d[key]) == "until_cancelled" else float(d[key])
	var keys := table.keys()
	keys.sort()
	for i: int in keys:
		if is_equal_approx(float(table[i]), seconds):
			return i
	# No index holds it: the readers take the seconds directly.
	row[direct] = seconds
	return 0


static func _decode_effect(e: Dictionary, n: int, row: Dictionary, where: String) -> void:
	var known := { "slot": true, "type": true, "aura": true, "value": true, "dice": true, "dice_per_level": true, "per_level": true,
		"trigger": true, "item": true, "multiple_value": true, "cost_share": true, "cost_of": true, "misc": true, "target": true, "target_b": true,
		"radius": true, "radius_index": true, "period": true, "mechanic": true, "multiplier": true,
		"stat": true, "modifies": true, "affects": true, "form": true, "against": true, "schools": true, "dispel": true, "power": true }
	for key: String in e:
		if not known.has(key):
			warnings.append("%s: unknown field \"%s\"" % [where, key])
	row["Effect%d" % n] = number_of("effects", e.get("type", 0), where)
	if e.has("aura"):
		row["EffectApplyAuraName%d" % n] = number_of("auras", e.aura, where)
	var dice := int(e.get("dice", 1))
	var value: Variant = e.get("value", dice)
	var low: int = int(value[0]) if value is Array else int(value)
	var high: int = int(value[1]) if value is Array else low
	row["EffectBaseDice%d" % n] = dice
	row["EffectBasePoints%d" % n] = low - dice
	row["EffectDieSides%d" % n] = high - (low - dice) if high > low else dice
	for pair: Array in [["EffectDicePerLevel", "dice_per_level"], ["EffectRealPointsPerLevel", "per_level"],
			["EffectTriggerSpell", "trigger"], ["EffectMultipleValue", "multiple_value"], ["EffectCostShare", "cost_share"], ["EffectCostOf", "cost_of"]]:
		if e.has(pair[1]):
			row[pair[0] + str(n)] = e[pair[1]]
	row["EffectMiscValue%d" % n] = _misc_of(e, where)
	if str(e.get("affects", "")) == "instant":
		row["EffectAffectsInstant%d" % n] = 1
		row["EffectItemType%d" % n] = 0
	else:
		row["EffectItemType%d" % n] = int(e.get("affects", e.get("item", 0)))
	if e.has("target"):
		row["EffectImplicitTargetA%d" % n] = number_of("targets", e.target, where)
	if e.has("target_b"):
		row["EffectImplicitTargetB%d" % n] = number_of("targets", e.target_b, where)
	if e.has("radius_index"):
		row["EffectRadiusIndex%d" % n] = int(e.radius_index)
	elif e.has("radius"):
		row["EffectRadiusIndex%d" % n] = 0
		for i: int in SpellDB.RADII:
			if is_equal_approx(SpellDB.RADII[i], float(e.radius)):
				row["EffectRadiusIndex%d" % n] = i
				break
		if row["EffectRadiusIndex%d" % n] == 0 and float(e.radius) != 0.0:
			row["EffectRadius%d" % n] = float(e.radius)
	if e.has("period"):
		row["EffectAmplitude%d" % n] = int(roundf(float(e.period) * 1000.0))
	if e.has("mechanic"):
		row["EffectMechanic%d" % n] = number_of("mechanics", e.mechanic, where)
	row["DmgMultiplier%d" % n] = float(e.get("multiplier", 1.0))


# A class's design file.

## Whole numbers as integers, all through a value (JSON reads every number
## as a float), so a design file shows 78, not 78.0.
static func whole(value: Variant) -> Variant:
	if value is float and value == floorf(value) and absf(value) < 1e15:
		return int(value)
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return whole(item))
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = whole(value[key])
		return out
	return value


## A class's spells in spells.json's shape, as its design file: spells
## grouped by chain (a chain's ranks in order) with their trainer entries,
## spellbook tabs, links, proc rules, coefficients and side tables; its
## talent trees naming their ranks' spells; its start spells.
static func encode_class(data: Dictionary, class_id: int, trainer: String, owned: Array) -> Dictionary:
	var trainer_of := {}
	for entry: Dictionary in data.trainers.get(trainer, []):
		var at: int = int(entry.spells[0]) if not entry.spells.is_empty() else int(entry.teach)
		trainer_of[at] = entry
	var tabs: Dictionary = data.book_tabs.get(str(class_id), {})
	var groups := {}
	var order := []
	var ids := owned.duplicate()
	ids.sort()
	# By chain, or by name for spells classic's data has no chain for (the
	# Men-at-Arms' ranks), those groups marked so no chain is made of them.
	var firsts := {}
	for id: String in data.chains:
		firsts[int(data.chains[id].first)] = true
	for id: int in ids:
		var chain: Dictionary = data.chains.get(str(id), {})
		var group_key: String
		if chain.has("first"):
			group_key = str(int(chain.first))
		elif firsts.has(id):
			group_key = str(id)
		else:
			group_key = "name:" + str(data.spells[str(id)].SpellName)
		if not groups.has(group_key):
			groups[group_key] = []
			order.append(group_key)
		groups[group_key].append(id)
	var spells := []
	for group_key: String in order:
		var members: Array = groups[group_key]
		var place := func(id: int) -> float:
			if data.chains.has(str(id)):
				return float(data.chains[str(id)].rank)
			var text := str(data.spells[str(id)].get("Rank1", ""))
			return float(text.substr(5)) if text.begins_with("Rank ") and text.substr(5).is_valid_int() else 0.0
		members.sort_custom(func(a: int, b: int) -> bool:
			return place.call(a) < place.call(b) or (place.call(a) == place.call(b) and a < b))
		var ranks := []
		for id: int in members:
			var design := encode(data.spells[str(id)])
			# A chain's first rank that classic's data gives no entry of its own.
			if not data.chains.has(str(id)) and firsts.has(id):
				design.chain_entry = false
			if trainer_of.has(id):
				var entry: Dictionary = trainer_of[id].duplicate()
				var learn := { "level": entry.level, "price": entry.cost }
				if int(entry.teach) != id:
					learn.teach = entry.teach
				if entry.spells.size() > 1:
					learn.also = entry.spells.slice(1)
				for key: String in entry:
					if not key in ["teach", "spells", "cost", "level"]:
						learn[key] = entry[key]
				design.trainer = learn
			if tabs.has(str(id)):
				design.book_tab = int(tabs[str(id)])
			if data.links.has(str(id)):
				design.link = data.links[str(id)]
			if data.procs.has(str(id)):
				design.proc = data.procs[str(id)]
			if data.bonus.has(str(id)):
				design.coefficients = data.bonus[str(id)]
			# A profession's recipe (professions.json): reagents, tools, what it makes.
			if data.get("recipes", {}).has(str(id)):
				design.recipe = ProfessionDesigns.encode_recipe(data.recipes[str(id)])
			var extra := {}
			for table: String in SIDE_TABLES:
				if data.get(table, {}).has(str(id)):
					extra[table] = data[table][str(id)]
			if not extra.is_empty():
				design.extra = extra
			ranks.append(design)
		var group := { "name": str(data.spells[str(members[0])].SpellName), "ranks": ranks }
		var chained := false
		for id: int in members:
			chained = chained or data.chains.has(str(id))
		if not chained:
			group.chain = false
		else:
			# A rank whose chain entry isn't its place in the list (classic
			# has chains that branch) keeps its entry.
			var previous := 0
			for i in members.size():
				var id: int = members[i]
				var entry: Dictionary = whole(data.chains.get(str(id), {}))
				if not entry.is_empty() and entry != { "prev": previous, "first": int(members[0]), "rank": i + 1 }:
					ranks[i].chain_link = entry
				previous = id
		spells.append(group)
	var talents := []
	for tree: Dictionary in data.talents.get(str(class_id), []):
		var entries := []
		for talent: Dictionary in tree.talents:
			var entry := { "name": str(data.spells.get(str(int(talent.ranks[0])), {}).get("SpellName", "")), "id": talent.id,
				"tier": talent.tier, "column": talent.column, "ranks": talent.ranks }
			if not talent.prereq.is_empty():
				entry.prereq = talent.prereq
			for key: String in talent:
				if not key in ["id", "tier", "column", "ranks", "prereq"]:
					entry[key] = talent[key]
			entries.append(entry)
		talents.append({ "name": tree.name, "id": tree.id, "order": tree.order, "talents": entries })
	var starts := {}
	for key: String in data.start_spells:
		if key.split("-")[1] == str(class_id):
			starts[key] = data.start_spells[key]
	# Trainer entries that teach a spell this class doesn't hold.
	var other_entries := []
	for entry: Dictionary in data.trainers.get(trainer, []):
		var at: int = int(entry.spells[0]) if not entry.spells.is_empty() else int(entry.teach)
		if not at in owned:
			other_entries.append(entry)
	var out := { "class": class_id, "trainer": trainer, "spells": spells, "talents": talents, "start_spells": starts }
	var other_tabs := {}
	for id: String in tabs:
		if not int(id) in owned:
			other_tabs[id] = tabs[id]
	if not other_tabs.is_empty():
		out.book_tabs_extra = other_tabs
	if not other_entries.is_empty():
		out.trainer_extra = other_entries
	return out


## A class's design file back in spells.json's shape: { spells, chains,
## trainer (its list), talents, start_spells, book_tabs, links, procs, bonus,
## and the side tables }.
## Each class's spell family (SpellFamilyName), by its trainer list.
const CLASS_FAMILIES := { "warrior": 4, "paladin": 10, "hunter": 9, "priest": 6, "spellsword": 12 }


## Tags: a rank's `"tags": ["radiant_strike"]` gives it a bit of the class's
## family_flags of its own (one free bit a tag, worked out here, the same for
## every rank with the tag), and a spell modifier's `affects` or a proc's
## `family_mask` may be a list of tags and spell names ("Verdict": the bits
## its ranks carry) in place of a number. Returns the design's spell groups
## with those turned into numbers, for decode.
static func _resolve_tags(design: Dictionary, where: String) -> Array:
	var groups: Array = (design.get("spells", []) as Array).duplicate(true)
	var family := int(CLASS_FAMILIES.get(str(design.get("trainer", "")), 0))
	# A group's tags (beside its name, before its ranks) are every rank's.
	for group: Dictionary in groups:
		if group.has("tags"):
			for rank: Dictionary in group.get("ranks", []):
				var all: Array = Array(group.tags).duplicate()
				for tag: Variant in rank.get("tags", []):
					if not tag in all:
						all.append(tag)
				rank.tags = all
			group.erase("tags")
	var used := 0
	var by_name := {}
	var tags := {}
	for group: Dictionary in groups:
		for rank: Dictionary in group.get("ranks", []):
			if int(rank.get("family", family)) != family:
				continue
			var flags := int(rank.get("family_flags", 0))
			used |= flags
			var name := str(rank.get("name", group.get("name", "")))
			by_name[name] = int(by_name.get(name, 0)) | flags
			for tag: Variant in rank.get("tags", []):
				tags[str(tag)] = 0
	# Free bits for the tags, in name order so they come out the same each time.
	var names := tags.keys()
	names.sort()
	var bit := 0
	for tag: String in names:
		while bit < 63 and used & (1 << bit):
			bit += 1
		if bit >= 63:
			warnings.append("%s: no free family_flags bit left for tag \"%s\"" % [where, tag])
			break
		tags[tag] = 1 << bit
		used |= 1 << bit
	for group: Dictionary in groups:
		for rank: Dictionary in group.get("ranks", []):
			if rank.has("tags"):
				rank.family = int(rank.get("family", family))
				var flags := int(rank.get("family_flags", 0))
				for tag: Variant in rank.tags:
					flags |= int(tags.get(str(tag), 0))
				rank.family_flags = flags
				var name := str(rank.get("name", group.get("name", "")))
				by_name[name] = int(by_name.get(name, 0)) | flags
				rank.erase("tags")
	var mask_of_names := func(list: Variant, at: String) -> int:
		var mask := 0
		for entry: Variant in list:
			if entry is float or entry is int:
				mask |= int(entry)
			elif tags.has(str(entry)):
				mask |= int(tags[str(entry)])
			elif by_name.has(str(entry)) and int(by_name[str(entry)]) != 0:
				mask |= int(by_name[str(entry)])
			else:
				warnings.append("%s: \"%s\" is no tag or spell with family_flags" % [at, entry])
		return mask
	for group: Dictionary in groups:
		for rank: Dictionary in group.get("ranks", []):
			var at := "%s, %s" % [where, rank.get("name", group.get("name", "?"))]
			for effect: Dictionary in rank.get("effects", []):
				var affects: Variant = effect.get("affects")
				# A list, or one name on its own ("instant" is its own rule).
				if affects is String and affects != "instant" and not (affects as String).is_valid_int():
					affects = [affects]
				if affects is Array:
					effect.affects = mask_of_names.call(affects, at)
			var proc: Variant = rank.get("proc")
			if proc is Dictionary and (proc as Dictionary).get("family_mask") is String 					and not str(proc.family_mask).is_valid_int():
				proc.family_mask = [proc.family_mask]
			if proc is Dictionary and (proc as Dictionary).get("family_mask") is Array:
				proc.family_mask = mask_of_names.call(proc.family_mask, at)
				if not proc.has("family"):
					proc.family = family
	return groups


static func decode_class(design: Dictionary, where: String) -> Dictionary:
	var out := { "spells": {}, "chains": {}, "trainer": [], "book_tabs": {}, "links": {}, "procs": {}, "bonus": {}, "recipes": {} }
	for table: String in SIDE_TABLES:
		out[table] = {}
	for group: Dictionary in _resolve_tags(design, where):
		var ranks: Array = group.get("ranks", [])
		var first := int(ranks[0].get("id", 0)) if not ranks.is_empty() else 0
		var previous := 0
		for i in ranks.size():
			var d: Dictionary = ranks[i]
			var label := "%s, %s rank %d" % [where, group.get("name", "?"), i + 1]
			var row := decode(d, label)
			var id: int = row.Id
			if id == 0:
				warnings.append("%s: no id" % label)
				continue
			out.spells[str(id)] = row
			if d.has("chain_link"):
				out.chains[str(id)] = d.chain_link
			elif group.get("chain", true) and d.get("chain_entry", true):
				out.chains[str(id)] = { "prev": previous, "first": first, "rank": i + 1 }
			previous = id
			if d.has("trainer"):
				var learn: Dictionary = d.trainer
				var entry := { "teach": int(learn.get("teach", id)), "spells": [id] + Array(learn.get("also", [])),
					"cost": int(learn.get("price", 0)), "level": int(learn.get("level", 1)) }
				for key: String in learn:
					if not key in ["teach", "also", "price", "level"]:
						entry[key] = learn[key]
				out.trainer.append(entry)
			if d.has("book_tab"):
				out.book_tabs[str(id)] = int(d.book_tab)
			if d.has("link"):
				out.links[str(id)] = d.link
			if d.has("proc"):
				out.procs[str(id)] = d.proc
			if d.has("coefficients"):
				out.bonus[str(id)] = d.coefficients
			if d.has("recipe"):
				out.recipes[str(id)] = d.recipe
			for table: String in d.get("extra", {}):
				if out.has(table):
					out[table][str(id)] = d.extra[table]
	for entry: Dictionary in design.get("trainer_extra", []):
		out.trainer.append(entry)
	for id: String in design.get("book_tabs_extra", {}):
		out.book_tabs[id] = int(design.book_tabs_extra[id])
	var trees := []
	for tree: Dictionary in design.get("talents", []):
		var talents := []
		for talent: Dictionary in tree.get("talents", []):
			var entry := { "id": int(talent.get("id", 0)), "tier": int(talent.get("tier", 0)),
				"column": int(talent.get("column", 0)), "ranks": talent.get("ranks", []), "prereq": talent.get("prereq", []) }
			for key: String in talent:
				if not key in ["name", "id", "tier", "column", "ranks", "prereq"]:
					entry[key] = talent[key]
			for rank: Variant in entry.ranks:
				if not out.spells.has(str(int(rank))):
					warnings.append("%s, talent %s: no spell %s in the design" % [where, talent.get("name", "?"), rank])
			talents.append(entry)
		trees.append({ "id": int(tree.get("id", 0)), "name": str(tree.get("name", "")), "order": int(tree.get("order", 0)),
			"talents": talents })
	out.talents = trees
	out.start_spells = design.get("start_spells", {})
	return out


## Every class's design file read over the data (spells.json's shape, its
## classes' entries replaced by their designs').
## Every design file as [class id, trainer list, file]: the classes', then
## the professions' (class 0, their trainer list named for them,
## ProfessionDesigns.FILES).
static func all_files() -> Array:
	var files := CLASSES.duplicate()
	for spec: Array in ProfessionDesigns.FILES:
		files.append([0, spec[0], spec[1]])
	return files


static func apply(data: Dictionary) -> void:
	warnings.clear()
	for spec: Array in all_files():
		var path := DESIGN_DIR + str(spec[2]) + ".json"
		if not edited.has(str(spec[2])) and not FileAccess.file_exists(path):
			continue
		var design: Variant = edited.get(str(spec[2]), null)
		if design == null:
			design = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not design is Dictionary:
			warnings.append("%s: not readable JSON" % path)
			continue
		var built := decode_class(design, str(spec[2]))
		for id: String in built.spells:
			data.spells[id] = built.spells[id]
		data.chains.merge(built.chains, true)
		data.trainers[spec[1]] = built.trainer
		# A class's talents, spellbook and start spells (a profession has none).
		if int(spec[0]) != 0:
			data.talents[str(spec[0])] = built.talents
			data.book_tabs[str(spec[0])] = built.book_tabs
			for key: String in built.start_spells:
				data.start_spells[key] = built.start_spells[key]
		for table: String in ["links", "procs", "bonus"] + SIDE_TABLES:
			if not data.has(table):
				data[table] = {}
			(data[table] as Dictionary).merge(built[table], true)
	for warning in warnings:
		push_warning("Spell designs: " + warning)


## Designs changed in the game (the Developer tab's spell editor) and not
## yet read from their files again: file name ("templar") to design. `apply`
## reads these in place of the files.
static var edited: Dictionary = {}


## A class's design as the game has it now: its edited copy, else its file.
static func design_of(file: String) -> Dictionary:
	if edited.has(file):
		return edited[file]
	var path := DESIGN_DIR + file + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var design: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return design if design is Dictionary else {}


## Writes a class's design to its file, as the export tool lays it out.
## Returns "" or what went wrong.
static func save(file: String) -> String:
	var design := design_of(file)
	if design.is_empty():
		return "Nothing to save for %s." % file
	var out := FileAccess.open(DESIGN_DIR + file + ".json", FileAccess.WRITE)
	if out == null:
		return "Can't write %s: %s" % [file, error_string(FileAccess.get_open_error())]
	out.store_string(JSON.stringify(whole(design), "\t", false) + "\n")
	out.close()
	return ""


## The lowest spell id from NEW_SPELL_IDS that no spell uses yet.
static func free_spell_id() -> int:
	var id := NEW_SPELL_IDS + 1
	while SpellDB.get_spell(id).size() > 0:
		id += 1
	for spec: Array in all_files():
		for group: Dictionary in design_of(str(spec[2])).get("spells", []):
			for rank: Dictionary in group.get("ranks", []):
				id = maxi(id, int(rank.get("id", 0)) + 1)
	return id
