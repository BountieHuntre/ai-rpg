class_name CharacterStats
extends Node
## The player's classic WoW stats: base Strength, Agility, Stamina, Intellect
## and Spirit from the class and race tables, and everything derived from
## them. Also runs health and mana regeneration on the classic 2-second tick.
## Must be a sibling of the player's Combatant.

const REGEN_TICK := 2.0
## The five-second rule: Spirit mana regen stops for this long after spending mana.
const MANA_REGEN_DELAY := 5.0

## Shield block chance when the character can block.
const SHIELD_BLOCK_CHANCE := 5.0
## The Parry passive, trained at level 8 by Paladins.
const PARRY_SPELL := 3127

var race: ClassicData.Race:
	get:
		return GameState.race
var char_class: ClassicData.CharClass:
	get:
		return GameState.char_class

## Current Strength, Agility, Stamina, Intellect and Spirit, gear included.
var stats: Array[int] = [0, 0, 0, 0, 0]
## The part of stats that comes from gear, shown as green bonuses.
var gear_stats: Array = [0, 0, 0, 0, 0]
var mana_per_tick := 0.0
var health_per_tick := 0.0

var _tick_left := REGEN_TICK

@onready var _combatant: Combatant = $"../Combatant"


func _ready() -> void:
	_combatant.is_player = true
	refresh()
	_combatant.reset()
	GameState.inventory_changed.connect(refresh)
	GameState.spells_changed.connect(refresh)
	_combatant.auras_changed.connect(refresh)


## Recomputes everything from level, class, race, equipped gear, trained
## passives and active auras. Keeps current health and mana, capped to the new
## maximums.
func refresh() -> void:
	var level := GameState.level
	var base := ClassicData.base_stats(race, char_class, level)
	var gear := Inventory.gear_totals()
	gear_stats = gear.stats
	for i in stats.size():
		stats[i] = int(base[i]) + int(gear_stats[i])
	var strength := stats[ClassicData.Stat.STRENGTH]
	var agility := stats[ClassicData.Stat.AGILITY]
	var stamina := stats[ClassicData.Stat.STAMINA]
	var intellect := stats[ClassicData.Stat.INTELLECT]
	var spirit := stats[ClassicData.Stat.SPIRIT]

	var c := _combatant
	c.level = level
	c.max_health = ClassicData.base_health(char_class, level) + health_from_stamina(stamina) + gear.health
	var base_mana := ClassicData.base_mana(char_class, level)
	c.max_mana = base_mana + mana_from_intellect(intellect) + gear.mana if base_mana > 0 else 0
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
	c.melee_crit = agility / _agility_rate(char_class, level, true)
	c.dodge = BASE_DODGE.get(char_class, 0.0) + agility / _agility_rate(char_class, level, false)
	# Parry has to be trained, and players need a melee weapon to parry.
	var armed: bool = gear.weapon != Inventory.UNARMED_WEAPON
	c.parry = 5.0 if armed and PARRY_SPELL in GameState.known_spells else 0.0
	# Blocking needs a shield. Block value: shield block + Strength / 20 - 1.
	c.block = SHIELD_BLOCK_CHANCE if gear.has_shield else 0.0
	c.block_value = maxi(gear.block + strength / 20 - 1, 0) if gear.has_shield else 0
	c.spell_crit = spell_crit_from_intellect(char_class, level, intellect)
	mana_per_tick = mana_regen_per_tick(char_class, spirit)
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
		c.health = mini(c.health + int(health_per_tick), c.max_health)
	c.mana = minf(c.mana + current_mana_per_tick(), c.max_mana)


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
