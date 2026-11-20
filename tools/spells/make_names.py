"""Writes data/designs/names.json: the readable names spell design files use
for classic's numbers (schools, powers, effect and aura types, targets, proc
flags, attribute bits, stances, weapon and armour types, mechanics, dispel
types, creature types), after the CMaNGOS/vmangos enums (SharedDefines.h,
SpellAuraDefines.h). A design file may give either the name or the number;
numbers with no name here are written as numbers.

Run: python tools/spells/make_names.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

SCHOOLS = {0: "physical", 1: "holy", 2: "fire", 3: "nature", 4: "frost", 5: "shadow", 6: "arcane"}
DMG_CLASSES = {0: "none", 1: "magic", 2: "melee", 3: "ranged"}
POWERS = {-2: "health", 0: "mana", 1: "rage", 2: "focus", 3: "energy", 4: "happiness"}

EFFECTS = {
	1: "instakill", 2: "school_damage", 3: "dummy", 4: "portal_teleport", 5: "teleport_units", 6: "apply_aura",
	7: "environmental_damage", 8: "power_drain", 9: "health_leech", 10: "heal", 11: "bind", 12: "portal",
	13: "ritual_base", 14: "ritual_specialize", 15: "ritual_activate_portal", 16: "quest_complete",
	17: "weapon_damage_noschool", 18: "resurrect", 19: "add_extra_attacks", 20: "dodge", 21: "evade",
	22: "parry", 23: "block", 24: "create_item", 25: "weapon", 26: "defense", 27: "persistent_area_aura",
	28: "summon", 29: "leap", 30: "energize", 31: "weapon_percent_damage", 32: "trigger_missile",
	33: "open_lock", 34: "summon_change_item", 35: "apply_area_aura_party", 36: "learn_spell",
	37: "spell_defense", 38: "dispel", 39: "language", 40: "dual_wield", 41: "summon_wild",
	42: "summon_guardian", 43: "teleport_units_face_caster", 44: "skill_step", 45: "add_honor",
	46: "spawn", 47: "trade_skill", 48: "stealth", 49: "detect", 50: "trans_door", 51: "force_critical_hit",
	52: "guarantee_hit", 53: "enchant_item", 54: "enchant_item_temporary", 55: "tame_creature",
	56: "summon_pet", 57: "learn_pet_spell", 58: "weapon_damage", 59: "open_lock_item", 60: "proficiency",
	61: "send_event", 62: "power_burn", 63: "threat", 64: "trigger_spell", 65: "health_funnel",
	66: "power_funnel", 67: "heal_max_health", 68: "interrupt_cast", 69: "distract", 70: "pull",
	71: "pickpocket", 72: "add_farsight", 73: "summon_possessed", 74: "summon_totem", 75: "heal_mechanical",
	76: "summon_object_wild", 77: "script_effect", 78: "attack", 79: "sanctuary", 80: "add_combo_points",
	81: "create_house", 82: "bind_sight", 83: "duel", 84: "stuck", 85: "summon_player",
	86: "activate_object", 87: "summon_totem_slot1", 88: "summon_totem_slot2", 89: "summon_totem_slot3",
	90: "summon_totem_slot4", 91: "threat_all", 92: "enchant_held_item", 93: "summon_phantasm",
	94: "self_resurrect", 95: "skinning", 96: "charge", 97: "summon_critter", 98: "knock_back",
	99: "disenchant", 100: "inebriate", 101: "feed_pet", 102: "dismiss_pet", 103: "reputation",
	104: "summon_object_slot1", 105: "summon_object_slot2", 106: "summon_object_slot3",
	107: "summon_object_slot4", 108: "dispel_mechanic", 109: "summon_dead_pet", 110: "destroy_all_totems",
	111: "durability_damage", 112: "summon_demon", 113: "resurrect_new", 114: "attack_me",
	115: "durability_damage_pct", 116: "skin_player_corpse", 117: "spirit_heal", 118: "skill",
	119: "apply_area_aura_pet", 120: "teleport_graveyard", 121: "normalized_weapon_damage",
	123: "send_taxi", 124: "player_pull", 125: "modify_threat_percent", 126: "steal_beneficial_buff",
	127: "prospecting", 128: "apply_area_aura_friend", 129: "apply_area_aura_enemy",
}

AURAS = {
	1: "bind_sight", 2: "possess", 3: "periodic_damage", 4: "dummy", 5: "confuse", 6: "charm", 7: "fear",
	8: "periodic_heal", 9: "attack_speed", 10: "threat", 11: "taunt", 12: "stun", 13: "damage_done",
	14: "damage_taken", 15: "damage_shield", 16: "stealth", 17: "stealth_detect", 18: "invisibility",
	19: "invisibility_detect", 20: "health_percent_regen", 21: "mana_percent_regen", 22: "resistance",
	23: "periodic_trigger_spell", 24: "periodic_energize", 25: "pacify", 26: "root", 27: "silence",
	28: "reflect_spells", 29: "stat", 30: "skill", 31: "speed", 32: "mounted_speed", 33: "slow",
	34: "max_health", 35: "max_power", 36: "shapeshift", 37: "effect_immunity", 38: "state_immunity",
	39: "school_immunity", 40: "damage_immunity", 41: "dispel_immunity", 42: "proc_trigger_spell",
	43: "proc_trigger_damage", 44: "track_creatures", 45: "track_resources", 46: "parry_skill",
	47: "parry_percent", 48: "dodge_skill", 49: "dodge_percent", 50: "block_skill", 51: "block_percent",
	52: "crit_percent", 53: "periodic_leech", 54: "hit_chance", 55: "spell_hit_chance", 56: "transform",
	57: "spell_crit_chance", 58: "swim_speed", 59: "damage_done_creature", 60: "pacify_silence",
	61: "scale", 62: "periodic_health_funnel", 63: "periodic_mana_funnel", 64: "periodic_mana_leech",
	65: "casting_speed", 66: "feign_death", 67: "disarm", 68: "stalked", 69: "school_absorb",
	70: "extra_attacks", 71: "spell_crit_chance_school", 72: "power_cost_school_percent",
	73: "power_cost_school", 74: "reflect_spells_school", 75: "language", 76: "far_sight",
	77: "mechanic_immunity", 78: "mounted", 79: "damage_percent_done", 80: "stat_percent",
	81: "split_damage_percent", 82: "water_breathing", 83: "base_resistance", 84: "health_regen",
	85: "power_regen", 86: "channel_death_item", 87: "damage_percent_taken", 88: "health_regen_percent",
	89: "periodic_damage_percent", 90: "resist_chance", 91: "detect_range", 92: "prevents_fleeing",
	93: "unattackable", 94: "interrupt_regen", 95: "ghost", 96: "spell_magnet", 97: "mana_shield",
	98: "skill_talent", 99: "attack_power", 100: "auras_visible", 101: "resistance_percent",
	102: "melee_attack_power_versus", 103: "total_threat", 104: "water_walk", 105: "feather_fall",
	106: "hover", 107: "flat_modifier", 108: "percent_modifier", 109: "add_target_trigger",
	110: "power_regen_percent", 111: "add_caster_hit_trigger", 112: "override_class_scripts",
	113: "ranged_damage_taken", 114: "ranged_damage_taken_percent", 115: "healing",
	116: "regen_during_combat", 117: "mechanic_resistance", 118: "healing_percent",
	119: "share_pet_tracking", 120: "untrackable", 121: "empathy", 122: "offhand_damage_percent",
	123: "target_resistance", 124: "ranged_attack_power", 125: "melee_damage_taken",
	126: "melee_damage_taken_percent", 127: "ranged_attack_power_attacker_bonus", 128: "possess_pet",
	129: "speed_always", 130: "mounted_speed_always", 131: "ranged_attack_power_versus",
	132: "max_power_percent", 133: "max_health_percent", 134: "mana_regen_interrupt",
	135: "healing_done", 136: "healing_done_percent", 137: "total_stat_percent", 138: "melee_haste",
	139: "force_reaction", 140: "ranged_haste", 141: "ranged_ammo_haste", 142: "base_resistance_percent",
	143: "resistance_exclusive", 144: "safe_fall", 145: "charisma", 146: "persuaded",
	147: "mechanic_immunity_mask", 148: "retain_combo_points", 149: "resist_pushback",
	150: "shield_block_value_percent", 151: "track_stealthed", 152: "detected_range",
	153: "split_damage_flat", 154: "stealth_level", 155: "water_breathing_percent",
	156: "reputation_gain", 157: "pet_damage_multiplier", 158: "shield_block_value", 159: "no_pvp_credit",
	160: "aoe_avoidance", 161: "health_regen_in_combat", 162: "power_burn_mana",
	163: "crit_damage_bonus", 165: "melee_attack_power_attacker_bonus", 166: "attack_power_percent",
	167: "ranged_attack_power_percent", 168: "damage_done_versus", 169: "crit_percent_versus",
	170: "detect_amore", 171: "speed_not_stack", 172: "mounted_speed_not_stack",
	173: "allow_champion_spells", 174: "spell_damage_of_stat_percent",
	175: "spell_healing_of_stat_percent", 176: "spirit_of_redemption", 177: "aoe_charm",
	178: "debuff_resistance", 179: "attacker_spell_crit_chance", 180: "flat_spell_damage_versus",
	181: "flat_spell_crit_damage_versus", 182: "resistance_of_stat_percent", 183: "critical_threat",
	184: "attacker_melee_hit_chance", 185: "attacker_ranged_hit_chance", 186: "attacker_spell_hit_chance",
	187: "attacker_melee_crit_chance", 188: "attacker_ranged_crit_chance", 189: "rating",
	190: "faction_reputation_gain",
	# The game's own (SpellDB).
	1001: "control_duration_percent", 1002: "crit_damage_taken_percent",
}

TARGETS = {
	0: "none", 1: "self", 3: "random_enemy_chain_in_area", 4: "random_friend_chain_in_area", 5: "pet",
	6: "enemy", 7: "area_custom", 8: "area_around_target", 15: "enemies_in_area", 16: "enemies_in_area_instant",
	18: "location", 20: "party_around_caster", 21: "friend", 22: "caster_location", 23: "game_object",
	24: "cone_in_front", 25: "any_unit", 26: "game_object_item", 27: "master", 28: "enemies_in_area_channeled",
	30: "friends_around_caster", 31: "friends_in_area", 32: "minion", 33: "party", 34: "party_around_caster_2",
	35: "party_member", 37: "party_around_target", 38: "script", 39: "self_fishing", 45: "chain_heal",
	46: "script_location", 47: "front_of_caster", 53: "enemy_location", 56: "raid_around_caster",
	57: "party_or_raid_member",
}

PROC_FLAGS = {
	0x1: "killed", 0x2: "kill", 0x4: "melee_hit_done", 0x8: "melee_hit_taken",
	0x10: "melee_ability_done", 0x20: "melee_ability_taken", 0x40: "ranged_hit_done", 0x80: "ranged_hit_taken",
	0x100: "ranged_ability_done", 0x200: "ranged_ability_taken", 0x400: "helpful_area_done",
	0x800: "helpful_area_taken", 0x1000: "harmful_area_done", 0x2000: "harmful_area_taken",
	0x4000: "helpful_spell_done", 0x8000: "helpful_spell_taken", 0x10000: "harmful_spell_done",
	0x20000: "harmful_spell_taken", 0x40000: "periodic_done", 0x80000: "periodic_taken",
	0x100000: "any_damage_taken", 0x200000: "trap_triggered", 0x400000: "offhand_hit_taken",
	0x800000: "offhand_hit_done",
}

ATTRIBUTES = {
	0x2: "ranged", 0x4: "on_next_swing", 0x10: "ability", 0x20: "trade_spell", 0x40: "passive",
	0x80: "hidden", 0x100: "hide_in_combat_log", 0x200: "target_main_hand_item", 0x400: "on_next_swing_2",
	0x1000: "daytime_only", 0x2000: "night_only", 0x4000: "indoors_only", 0x8000: "outdoors_only",
	0x10000: "not_shapeshifted", 0x20000: "only_stealthed", 0x40000: "keeps_sheath",
	0x80000: "level_damage_calculation", 0x100000: "stop_attack_target", 0x200000: "cannot_be_avoided",
	0x400000: "set_tracking_target", 0x800000: "castable_while_dead", 0x1000000: "castable_while_mounted",
	0x2000000: "disabled_while_active", 0x4000000: "negative", 0x8000000: "castable_while_sitting",
	0x10000000: "not_in_combat", 0x20000000: "ignores_invulnerability", 0x40000000: "heartbeat_resist",
	0x80000000: "cannot_cancel",
}

# Shapeshift forms: a spell's Stances mask has bit (form - 1). The Men-at-Arms'
# and Spellswords' by the game's names.
FORMS = {
	1: "cat", 2: "tree", 3: "travel", 4: "aquatic", 5: "bear", 6: "ambient", 7: "ghoul", 8: "dire_bear",
	17: "vanguard", 18: "bastion", 19: "fury", 20: "bladesong", 21: "wardweave", 27: "flight", 28: "stealth",
	29: "moonkin", 30: "spirit_of_redemption",
}

WEAPONS = {
	0: "axe", 1: "axe_2h", 2: "bow", 3: "gun", 4: "mace", 5: "mace_2h", 6: "polearm", 7: "sword",
	8: "sword_2h", 10: "staff", 13: "fist", 14: "misc", 15: "dagger", 16: "thrown", 17: "spear",
	18: "crossbow", 19: "wand", 20: "fishing_pole",
}
ARMOR = {0: "misc", 1: "cloth", 2: "leather", 3: "mail", 4: "plate", 5: "buckler", 6: "shield"}
ITEM_CLASSES = {-1: "none", 0: "consumable", 2: "weapon", 4: "armor"}

MECHANICS = {
	1: "charm", 2: "disoriented", 3: "disarm", 4: "distract", 5: "fear", 6: "fumble", 7: "root",
	8: "pacify", 9: "silence", 10: "sleep", 11: "snare", 12: "stun", 13: "freeze", 14: "knockout",
	15: "bleed", 16: "bandage", 17: "polymorph", 18: "banish", 19: "shield", 20: "shackle", 21: "mount",
	22: "persuade", 23: "turn", 24: "horror", 25: "invulnerability", 26: "interrupt", 27: "daze",
	28: "discovery", 29: "immune_shield", 30: "sapped",
}
DISPELS = {1: "magic", 2: "curse", 3: "disease", 4: "poison", 5: "stealth", 6: "invisibility", 7: "all", 9: "enrage"}
CREATURE_TYPES = {
	1: "beast", 2: "dragonkin", 3: "demon", 4: "elemental", 5: "giant", 6: "undead", 7: "humanoid",
	8: "critter", 9: "mechanical", 10: "not_specified",
}
# The stat an aura of `stat` (29) and the like changes (EffectMiscValue).
STATS = {-1: "all", 0: "strength", 1: "agility", 2: "stamina", 3: "intellect", 4: "spirit"}


# What a spell modifier aura (flat_modifier, percent_modifier) changes
# (SpellModOp, its EffectMiscValue); SpellMods reads the same numbers.
SPELL_MODS = {
	0: "damage", 1: "duration", 2: "threat", 3: "effect1", 4: "charges", 5: "range", 6: "radius",
	7: "crit_chance", 8: "all_effects", 9: "pushback", 10: "cast_time", 11: "cooldown", 12: "speed",
	14: "cost", 15: "crit_damage", 16: "resist_miss_chance", 17: "jump_targets", 18: "chance_of_success",
	19: "activation_time", 20: "effect_past_first", 21: "global_cooldown", 22: "periodic_damage",
	23: "effect3", 24: "spell_bonus_damage", 26: "frequency_of_success", 27: "multiple_value",
	28: "resist_dispel_chance",
}


def table(names):
	return {str(k): v for k, v in names.items()}


def main():
	out = {
		"schools": table(SCHOOLS), "dmg_classes": table(DMG_CLASSES), "powers": table(POWERS),
		"effects": table(EFFECTS), "auras": table(AURAS), "targets": table(TARGETS),
		"proc_flags": table(PROC_FLAGS), "attributes": table(ATTRIBUTES), "forms": table(FORMS),
		"weapons": table(WEAPONS), "armor": table(ARMOR), "item_classes": table(ITEM_CLASSES),
		"mechanics": table(MECHANICS), "dispels": table(DISPELS), "creature_types": table(CREATURE_TYPES),
		"stats": table(STATS), "spell_mods": table(SPELL_MODS),
	}
	for key, names in out.items():
		assert len(set(names.values())) == len(names), f"{key}: a name is used twice"
	root = os.path.join(os.path.dirname(__file__), "..", "..")
	path = os.path.join(root, "data", "designs", "names.json")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		json.dump(out, f, indent="\t")
		f.write("\n")
	print("wrote", path)
	write_names_doc(out, os.path.join(root, "docs", "spells", "NAMES.md"))


TITLES = {
	"schools": ("school", "A spell's school, and an effect's `schools`."),
	"dmg_classes": ("damage_class", "How a spell lands: a spell (magic), a melee or ranged attack, or neither."),
	"powers": ("power", "What a spell costs, and an energize effect's `power`."),
	"effects": ("effect type", "An effect's `type`."),
	"auras": ("aura", "An `apply_aura` (or area aura) effect's `aura`."),
	"targets": ("target", "An effect's `target` and `target_b`."),
	"proc_flags": ("proc_on", "What makes a proc aura fire (`proc_on`)."),
	"attributes": ("attributes", "A spell's `attributes` (classic's Attributes bits). Most are kept from classic and not read; each says which. `attributes_ex`, `attributes_ex2` and `attributes_ex3` take hex bits such as `\"0x4\"`: FIELDS.md lists the ones the game reads."),
	"forms": ("form", "A spell's `stances` (the forms or stances it needs) and a shapeshift aura's `form`."),
	"weapons": ("item_types (weapons)", "`item_types` when `requires_item` is `weapon`."),
	"armor": ("item_types (armour)", "`item_types` when `requires_item` is `armor`."),
	"item_classes": ("requires_item", "What a spell needs equipped."),
	"mechanics": ("mechanic", "A mechanic aura's `against` (immunity or resistance to it), which the game reads; also a spell's or effect's `mechanic`, which it doesn't (it knows a stun by its aura)."),
	"dispels": ("dispel", "A spell's `dispel` type, and a dispel effect's `dispel`."),
	"creature_types": ("creature_types", "What a spell may target (`creature_types`)."),
	"stats": ("stat", "A stat aura's `stat`."),
	"spell_mods": ("modifies", "What a spell modifier (`flat_modifier`, `percent_modifier`) changes."),
}


def _usage(root):
	"""How many of the game's class spells (the design files) use each name,
	by table, with an example from each class using it:
	{ table: { name: { "ids": set of spell ids, "examples": { class file: spell name } } } }."""
	from collections import defaultdict
	used = defaultdict(dict)
	current = {}

	def count(table, value, spell):
		values = value if isinstance(value, list) else [value]
		for v in values:
			if isinstance(v, str):
				entry = used[table].setdefault(v, {"ids": set(), "examples": {}})
				entry["ids"].add(current["id"])
				entry["examples"].setdefault(current["file"], spell)

	folder = os.path.join(root, "data", "designs")
	for name in sorted(os.listdir(folder)):
		if name == "names.json" or not name.endswith(".json"):
			continue
		with open(os.path.join(folder, name), encoding="utf-8") as f:
			design = json.load(f)
		for group in design.get("spells", []):
			for rank in group.get("ranks", []):
				spell = rank.get("name", group.get("name", "?"))
				current["id"] = rank.get("id", 0)
				current["file"] = name
				for field, table in (("school", "schools"), ("damage_class", "dmg_classes"), ("power", "powers"),
						("proc_on", "proc_flags"), ("attributes", "attributes"), ("stances", "forms"),
						("requires_item", "item_classes"), ("mechanic", "mechanics"), ("dispel", "dispels"),
						("creature_types", "creature_types")):
					if field in rank:
						count(table, rank[field], spell)
				if isinstance(rank.get("item_types"), list):
					count("weapons" if rank.get("requires_item") == "weapon" else "armor", rank["item_types"], spell)
				for effect in rank.get("effects", []):
					for field, table in (("type", "effects"), ("aura", "auras"), ("target", "targets"),
							("target_b", "targets"), ("form", "forms"), ("against", "mechanics"),
							("mechanic", "mechanics"), ("schools", "schools"), ("dispel", "dispels"),
							("power", "powers"), ("stat", "stats"), ("modifies", "spell_mods")):
						if field in effect:
							count(table, effect[field], spell)
	return used


def write_names_doc(out, path):
	from name_notes import NOTES
	root = os.path.join(os.path.dirname(path), "..", "..")
	used = _usage(root)
	lines = ["# Spell design names", "",
		"Every name a spell design file (`data/designs/<class>.json`) may use, by field, and what it does. Written by",
		"`tools/spells/make_names.py` from `data/designs/names.json` and the meanings in `tools/spells/name_notes.py`;",
		"see FIELDS.md for the fields themselves. Anywhere a name goes, its number works too (for values with no name here).",
		"",
		"**In the game** counts the spells of the game's classes (the design files) that use the name, with one of them.",
		"A few spells the game has but leaves unfinished (Dominate Will, Borrowed Eyes, Font of Light) count too. Names used by none are classic's: the game may do nothing with them yet, and a spell using one needs code",
		"(`SpellCaster`, `Combatant`, the class's abilities script) before it does anything.", ""]
	for key, names in out.items():
		title, about = TITLES.get(key, (key, ""))
		notes = NOTES.get(key, {})
		lines += ["## " + title, "", about, "", "| Name | Number | What it does | In the game |", "|---|---|---|---|"]
		for number, name in sorted(names.items(), key=lambda kv: int(kv[0])):
			shown = hex(int(number)) if key in ("proc_flags", "attributes") else number
			use = used.get(key, {}).get(name)
			in_game = "%d: %s" % (len(use["ids"]), ", ".join(list(dict.fromkeys(use["examples"].values()))[:3])) if use else "none"
			lines.append("| `%s` | %s | %s | %s |" % (name, shown, notes.get(name, "").replace("|", "\\|"), in_game))
			if name not in notes:
				print("no meaning for", key, name)
		lines.append("")
	os.makedirs(os.path.dirname(path), exist_ok=True)
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		f.write("\n".join(lines))
	print("wrote", path)


if __name__ == "__main__":
	main()
