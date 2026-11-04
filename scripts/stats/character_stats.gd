class_name CharacterStats
extends Node
## A player character's classic WoW stats: base Strength, Agility, Stamina, Intellect
## and Spirit from the class and race tables, and everything derived from
## them. Also runs health and mana regeneration on the classic 2-second tick.
## Must be a child of a PlayerUnit (the player or a playerbot), beside its
## Combatant; it reads the unit's profile.

const REGEN_TICK := 2.0
## The five-second rule: Spirit mana regen stops for this long after spending mana.
const MANA_REGEN_DELAY := 5.0

## Shield block chance when the character can block.
const SHIELD_BLOCK_CHANCE := 5.0
## Sitting raises Spirit health regen by half.
const SITTING_REGEN := 1.5
## Food and drink auras tick on a 5-second period.
const FOOD_DRINK_PERIOD := 5.0
## The Parry passive, trained at level 8 by Paladins.
const PARRY_SPELL := 3127
## Rage lost each tick out of combat.
const RAGE_DECAY := 3.0

var race: ClassicData.Race:
	get:
		return _profile.race
var char_class: ClassicData.CharClass:
	get:
		return _profile.char_class

## Current Strength, Agility, Stamina, Intellect and Spirit, gear included.
var stats: Array[int] = [0, 0, 0, 0, 0]
## The part of stats that comes from gear, shown as green bonuses.
var gear_stats: Array = [0, 0, 0, 0, 0]
var mana_per_tick := 0.0
var health_per_tick := 0.0

var _tick_left := REGEN_TICK
## Fractions of health carried to the next tick, as in CMaNGOS.
var _health_carry := 0.0

@onready var _combatant: Combatant = $"../Combatant"
@onready var _profile: CharacterProfile = (get_parent() as PlayerUnit).profile


func _ready() -> void:
	_combatant.is_player = true
	refresh()
	_combatant.reset()
	if _profile == GameState:
		GameState.inventory_changed.connect(refresh)
		GameState.spells_changed.connect(refresh)
	_combatant.auras_changed.connect(refresh)


## Recomputes everything from level, class, race, equipped gear, trained
## passives and active auras. Keeps current health and mana, capped to the new
## maximums.
func refresh() -> void:
	var level := _profile.level
	var base := ClassicData.base_stats(race, char_class, level)
	var gear := Inventory.gear_totals(_profile.equipment)
	gear_stats = gear.stats
	# Boon of Sovereigns raises every attribute by a percentage.
	var stat_scale := 1.0 + _combatant.aura_total(SpellDB.AURA_MOD_TOTAL_STAT_PERCENTAGE) / 100.0
	# Litany of Fortitude and Uplifted Spirit add to one attribute (misc value
	# is the stat, -1 all of them).
	for i in stats.size():
		var bonus := _combatant.aura_total_exact(SpellDB.AURA_MOD_STAT, i) + _combatant.aura_total_exact(SpellDB.AURA_MOD_STAT, -1)
		stats[i] = int((int(base[i]) + int(gear_stats[i]) + bonus) * stat_scale)
	var strength := stats[ClassicData.Stat.STRENGTH]
	var agility := stats[ClassicData.Stat.AGILITY]
	var stamina := stats[ClassicData.Stat.STAMINA]
	var intellect := stats[ClassicData.Stat.INTELLECT]
	var spirit := stats[ClassicData.Stat.SPIRIT]

	var c := _combatant
	c.level = level
	# Final Stand adds health for a while (SPELL_AURA_MOD_INCREASE_HEALTH).
	c.max_health = ClassicData.base_health(char_class, level) + health_from_stamina(stamina) + gear.health \
		+ int(c.aura_total(SpellDB.AURA_MOD_INCREASE_HEALTH))
	var base_mana := ClassicData.base_mana(char_class, level)
	c.max_mana = base_mana + mana_from_intellect(intellect) + gear.mana if base_mana > 0 else 0
	# The Man-at-Arms fights on rage instead of mana.
	if char_class == ClassicData.CharClass.WARRIOR:
		if c.power_type != SpellDB.POWER_RAGE:
			c.power_type = SpellDB.POWER_RAGE
			c.mana = 0.0
		c.max_mana = Combatant.MAX_RAGE
	# Devotion Aura adds armor (resistance aura on the physical school).
	c.armor = gear.armor + agility * 2 + int(c.aura_total(SpellDB.AURA_MOD_RESISTANCE, 1))
	# Blessing of Might and Seal of the Crusader add attack power.
	c.attack_power = maxi(melee_attack_power(char_class, level, strength, agility), 0) + int(c.aura_total(SpellDB.AURA_MOD_ATTACK_POWER))
	# Seal of the Crusader speeds up attacks but cuts weapon damage to match,
	# as in the CMaNGOS SealOfTheCrusader script.
	var haste := c.aura_total(SpellDB.AURA_MOD_ATTACK_SPEED)
	var damage_scale := 1.0 + (-100.0 * haste / (haste + 100.0)) / 100.0
	c.min_damage = gear.weapon.min * damage_scale
	c.max_damage = gear.weapon.max * damage_scale
	c.swing_interval = gear.weapon.speed / (1.0 + haste / 100.0)
	# Melee haste auras: Hallowed Aegis slows attacks (-100% doubles the swing time).
	var melee_haste := c.aura_total(SpellDB.AURA_MOD_MELEE_HASTE)
	var haste_factor := 1.0 / (1.0 + melee_haste / 100.0) if melee_haste >= 0.0 else 1.0 - melee_haste / 100.0
	c.swing_interval *= haste_factor
	# A weapon in the off hand (Two-Weapon Fighting) swings on its own.
	var off: Dictionary = gear.get("off_weapon", {})
	c.off_min_damage = float(off.get("min", 0.0))
	c.off_max_damage = float(off.get("max", 0.0))
	c.off_swing_interval = float(off.get("speed", 0.0)) / (1.0 + haste / 100.0) * haste_factor
	# Fury Stance and Abandon add crit (SPELL_AURA_MOD_CRIT_PERCENT).
	c.melee_crit = agility / _agility_rate(char_class, level, true) + c.aura_total(SpellDB.AURA_MOD_CRIT_PERCENT)
	# Moon's Grace adds dodge.
	c.dodge = BASE_DODGE.get(char_class, 0.0) + agility / _agility_rate(char_class, level, false) + c.aura_total(SpellDB.AURA_MOD_DODGE_PERCENT)
	# Parry has to be trained, and players need a melee weapon to parry.
	var armed: bool = gear.weapon != Inventory.UNARMED_WEAPON
	c.parry = 5.0 if armed and PARRY_SPELL in _profile.known_spells else 0.0
	# Blocking needs a shield. Block value: shield block + Strength / 20 - 1.
	c.block = SHIELD_BLOCK_CHANCE if gear.has_shield else 0.0
	# Radiant Bulwark adds block chance (with a shield).
	if gear.has_shield:
		c.block += c.aura_total(SpellDB.AURA_MOD_BLOCK_PERCENT)
	c.block_value = maxi(gear.block + strength / 20 - 1, 0) if gear.has_shield else 0
	c.spell_crit = spell_crit_from_intellect(char_class, level, intellect)
	mana_per_tick = 0.0 if c.uses_rage() else mana_regen_per_tick(char_class, spirit)
	health_per_tick = health_regen_per_tick(char_class, spirit)
	c.health = mini(c.health, c.max_health)
	c.mana = minf(c.mana, c.max_mana)


## Mana regen right now, per tick: zero within five seconds of spending mana.
func current_mana_per_tick() -> float:
	return 0.0 if _combatant.seconds_since_mana_spent() < MANA_REGEN_DELAY else mana_per_tick


func _physics_process(delta: float) -> void:
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left += REGEN_TICK
	var c := _combatant
	if not c.is_alive():
		return
	if not c.is_in_combat() and c.health < c.max_health:
		_health_carry += health_per_tick * (SITTING_REGEN if c.sitting else 1.0) + food_per_tick()
		var gained := int(_health_carry)
		_health_carry -= gained
		c.health = mini(c.health + gained, c.max_health)
	# Rage fades out of combat: 3 a tick (Player::Regenerate in CMaNGOS classic).
	if c.uses_rage():
		if not c.is_in_combat():
			c.mana = maxf(c.mana - RAGE_DECAY, 0.0)
		return
	c.mana = minf(c.mana + current_mana_per_tick() + drink_per_tick(), c.max_mana)


## Food heals its amount every 5 seconds, applied on the 2-second tick
## (RegenerateHealth in CMaNGOS: amount * 2000 / 5000).
func food_per_tick() -> float:
	return _combatant.aura_total(SpellDB.AURA_MOD_REGEN) * REGEN_TICK / FOOD_DRINK_PERIOD


## Drink restores its amount as mana per 5 seconds, even within the
## five-second rule (UpdateManaRegen in CMaNGOS).
func drink_per_tick() -> float:
	return _combatant.aura_total(SpellDB.AURA_MOD_POWER_REGEN) / FOOD_DRINK_PERIOD * REGEN_TICK


# Formulas from the CMaNGOS classic and vmangos StatSystem and Player code.

## The first 20 Stamina give 1 health each, the rest 10 each.
static func health_from_stamina(stamina: int) -> int:
	var low := mini(stamina, 20)
	return low + (stamina - low) * 10


## The first 20 Intellect give 1 mana each, the rest 15 each.
static func mana_from_intellect(intellect: int) -> int:
	var low := mini(intellect, 20)
	return low + (intellect - low) * 15


static func melee_attack_power(c: ClassicData.CharClass, level: int, strength: int, agility: int) -> int:
	match c:
		ClassicData.CharClass.WARRIOR, ClassicData.CharClass.PALADIN:
			return level * 3 + strength * 2 - 20
		ClassicData.CharClass.ROGUE, ClassicData.CharClass.HUNTER:
			return level * 2 + strength + agility - 20
		ClassicData.CharClass.SHAMAN:
			return level * 2 + strength * 2 - 20
		ClassicData.CharClass.DRUID:
			return strength * 2 - 20
		_:
			return strength - 10


const BASE_DODGE := {
	ClassicData.CharClass.PALADIN: 0.75, ClassicData.CharClass.HUNTER: 0.64,
	ClassicData.CharClass.PRIEST: 3.0, ClassicData.CharClass.SHAMAN: 1.75,
	ClassicData.CharClass.MAGE: 3.25, ClassicData.CharClass.WARLOCK: 2.0,
	ClassicData.CharClass.DRUID: 0.75,
}

## Agility per 1% crit (or dodge), from level 1 and level 60 values with
## linear interpolation between them.
const AGILITY_RATES := {
	ClassicData.CharClass.PALADIN: [4.6, 20.0, 4.6, 20.0],
	ClassicData.CharClass.SHAMAN: [4.6, 20.0, 4.6, 20.0],
	ClassicData.CharClass.DRUID: [4.6, 20.0, 4.6, 20.0],
	ClassicData.CharClass.MAGE: [12.9, 20.0, 12.9, 20.0],
	ClassicData.CharClass.ROGUE: [2.2, 29.0, 1.1, 14.5],
	ClassicData.CharClass.HUNTER: [3.5, 53.0, 1.8, 26.5],
	ClassicData.CharClass.PRIEST: [11.0, 20.0, 11.0, 20.0],
	ClassicData.CharClass.WARLOCK: [8.4, 20.0, 8.4, 20.0],
	ClassicData.CharClass.WARRIOR: [3.9, 20.0, 3.9, 20.0],
}


static func _agility_rate(c: ClassicData.CharClass, level: int, crit: bool) -> float:
	var rates: Array = AGILITY_RATES[c]
	var at_1: float = rates[0] if crit else rates[2]
	var at_60: float = rates[1] if crit else rates[3]
	return at_1 * (60.0 - level) / 59.0 + at_60 * (level - 1.0) / 59.0


## Base spell crit plus Intellect / (rate0 + rate1 * level).
const SPELL_CRIT_DATA := {
	ClassicData.CharClass.PALADIN: [3.70, 14.77, 0.65],
	ClassicData.CharClass.PRIEST: [2.97, 10.03, 0.82],
	ClassicData.CharClass.SHAMAN: [3.54, 11.51, 0.80],
	ClassicData.CharClass.MAGE: [3.70, 14.77, 0.65],
	ClassicData.CharClass.WARLOCK: [3.18, 11.30, 0.82],
	ClassicData.CharClass.DRUID: [3.33, 12.41, 0.79],
}


static func spell_crit_from_intellect(c: ClassicData.CharClass, level: int, intellect: int) -> float:
	var data: Array = SPELL_CRIT_DATA.get(c, [0.0, 0.0, 10.0])
	return data[0] + intellect / (data[1] + data[2] * level)


## Mana per 2-second tick from Spirit, outside the five-second rule.
static func mana_regen_per_tick(c: ClassicData.CharClass, spirit: int) -> float:
	match c:
		ClassicData.CharClass.MAGE, ClassicData.CharClass.PRIEST:
			return spirit / 4.0 + 12.5
		ClassicData.CharClass.SHAMAN:
			return spirit / 5.0 + 17.0
		ClassicData.CharClass.PALADIN, ClassicData.CharClass.HUNTER, ClassicData.CharClass.WARLOCK, ClassicData.CharClass.DRUID:
			return spirit / 5.0 + 15.0
		_:
			return 0.0


## Health per 2-second tick from Spirit, out of combat only.
static func health_regen_per_tick(c: ClassicData.CharClass, spirit: int) -> float:
	var value := 0.0
	match c:
		ClassicData.CharClass.DRUID, ClassicData.CharClass.MAGE:
			value = spirit * 0.11 + 1.0
		ClassicData.CharClass.HUNTER:
			value = spirit * 0.43 - 5.5
		ClassicData.CharClass.PALADIN:
			value = spirit * 0.25
		ClassicData.CharClass.PRIEST:
			value = spirit * 0.15 + 1.4
		ClassicData.CharClass.ROGUE:
			value = spirit * 0.84 - 13.0
		ClassicData.CharClass.SHAMAN:
			value = spirit * 0.28 - 3.6
		ClassicData.CharClass.WARLOCK:
			value = spirit * 0.12 + 1.5
		ClassicData.CharClass.WARRIOR:
			value = spirit * 1.26 - 22.6
	return maxf(value, 0.0)
