"""Extracts classic WoW (patch 1.12) data for the game from the CMaNGOS classic
database dump into data/classic/*.json.

Usage (Python 3, no extra packages), after fetch_client_tables.py:
    python tools/classic_db/extract.py path/to/ClassicDB_1_12_1_z2815.sql.gz

The dump is Full_DB/ClassicDB_1_12_1_z2815.sql.gz from
https://github.com/cmangos/classic-db. Creatures to include are listed in
CREATURES below; their loot tables, every item those can drop and the starting
items are exported with them.
"""

import gzip
import json
import os
import re
import sys

import renames

# creature_template entries used in the game.
# Young Wolf, Kobold Vermin, Timber Wolf, Kobold Worker, Kobold Laborer,
# Defias Thug, Stonetusk Boar, Kobold Tunneler: classic levels 1 to 6.
CREATURES = [299, 6, 69, 257, 80, 38, 113, 475]
# Vendors whose stock is exported: Brother Danil (General Supplies) and
# Godric Rothgar (Armorer & Shieldcrafter) from Northshire.
VENDORS = [152, 1213]

# Quests whose rules (objectives, level, XP, money, rewards, chain) the game's
# own quests are built on. Titles, text and quest givers are the game's own,
# in data/quests.json. From Northshire and Elwynn: A Threat Within, Eagan
# Peltskinner, Wolves Across the Border, Brotherhood of Thieves, Kobold Camp
# Cleanup, Investigate Echo Ridge, Skirmish at Echo Ridge, Kobold Candles and
# Gold Dust Exchange.
QUESTS = [783, 5261, 33, 18, 7, 15, 21, 60, 47]

# Class trainers whose spell lists are exported. 927 is Brother Wilhelm, Paladin
# Trainer. Priests have racial spells, so their list merges one trainer per race
# (race id: trainer): Brother Joshua (Human), Maxan Anvol (Dwarf), Astarii
# Starseeker (Night Elf), Father Cobb (Undead) and Tai'jin (Troll). Entries that
# not every one of them teaches get a "races" list.
# 913 is Lyria Du Lac, Warrior Trainer.
CLASS_TRAINERS = {"paladin": 927, "priest": {1: 5489, 3: 1226, 4: 4090, 5: 3046, 8: 3706}, "warrior": 913}
# Classes whose starting spells are exported: the ones with spell code in the game.
SPELL_CLASSES = {1, 2, 5}  # Warrior, Paladin, Priest
# Each class's SpellFamilyName: start spells of other families (racials) are left out.
CLASS_SPELL_FAMILIES = {1: 4, 2: 10, 5: 6}
# Junk trainer rows: Lyria Du Lac lists Elemental Fury, a creature spell.
SKIP_TRAINER_SPELLS = {877}
# Starting spells worth keeping (the rest are passives and internals).
START_SPELL_EFFECTS = {2, 6, 10, 17, 35, 77}
# Seal of Righteousness procs by rank, from UnitAuraProcHandler.cpp in CMaNGOS.
SEAL_OF_RIGHTEOUSNESS_PROCS = {
    20154: 25742, 21084: 25741, 20287: 25740, 20288: 25739, 20289: 25738,
    20290: 25737, 20291: 25736, 20292: 25735, 20293: 25713,
}
# Holy Light's script effect heals through this spell (SpellEffects.cpp).
HOLY_LIGHT_HEAL = 19968
# First ranks the trainer doesn't sell because classic gives them as talents.
# There are no talents yet, so the game's trainer sells them at the talent's
# tier level: Seal of Command, Consecration, Blessing of Kings, Blessing of
# Sanctuary, Holy Shock and Holy Shield.
# Priest: Inner Focus, Holy Nova, Mind Flay, Divine Spirit, Silence, Vampiric
# Embrace, Power Infusion, Shadowform and Lightwell.
TALENT_FIRST_RANKS = {
    "paladin": [[20375, 20], [26573, 20], [20217, 20], [20911, 30], [20473, 40], [20925, 40]],
    "priest": [[14751, 20], [15237, 20], [15407, 20], [14752, 30], [15487, 30], [15286, 30],
               [10060, 40], [15473, 40], [724, 40]],
    # Warrior: Last Stand, Piercing Howl, Sweeping Strikes, Concussion Blow,
    # Death Wish, Mortal Strike, Bloodthirst and Shield Slam.
    "warrior": [[12975, 20], [12323, 20], [12292, 30], [12809, 30], [12328, 30],
                [12294, 40], [23881, 40], [23922, 40]],
}
# Spells classic gives from a class quest, sold free at their level: Defensive
# Stance and Taunt at 10, Berserker Stance at 30.
QUEST_SPELLS = {"warrior": [[71, 10], [355, 10], [2458, 30]]}
# First ranks of priest racial spells, which classic gives from a quest: sold
# free at the spell's level to the races that have them. Desperate Prayer
# (Human, Dwarf), Feedback (Human), Fear Ward (Dwarf), Starshards and Elune's
# Grace (Night Elf), Touch of Weakness and Devouring Plague (Undead), Hex of
# Weakness and Shadowguard (Troll).
RACIAL_FIRST_RANKS = {"priest": [
    [13908, [1, 3]], [13896, [1]], [6346, [3]], [10797, [4]], [2651, [4]],
    [2652, [5]], [2944, [5]], [9035, [8]], [18137, [8]],
]}
# Spells another spell casts that the data doesn't link (from the CMaNGOS spell
# scripts): Holy Nova's heal per rank, Touch of Weakness's and Shadowguard's
# damage per rank, Power Word: Shield's Weakened Soul and Vampiric Embrace's heal.
SPELL_LINKS = {
    15237: 23455, 15430: 23458, 15431: 23459, 27799: 27803, 27800: 27804, 27801: 27805,
    2652: 2943, 19261: 19249, 19262: 19251, 19264: 19252, 19265: 19253, 19266: 19254,
    18137: 28377, 19308: 28378, 19309: 28379, 19310: 28380, 19311: 28381, 19312: 28382,
    15286: 15290,
    # Warrior: each stance's passive (threat, damage taken and done, crit),
    # Retaliation's strike and Last Stand's health.
    2457: 21156, 71: 7376, 2458: 7381, 20230: 22858, 12975: 12976,
}
WEAKENED_SOUL = 6788
# Judgement of Light and Wisdom heal or restore through a spell per rank, picked
# in UnitAuraProcHandler.cpp (HandleDummyAuraProc), not linked in the data.
JUDGEMENT_PROC_SPELLS = {
    20185: 20267, 20344: 20341, 20345: 20342, 20346: 20343,
    20186: 20268, 20354: 20352, 20355: 20353,
}
# Holy Shock's dummy effect casts a damage or a heal spell for its rank
# (SpellEffects.cpp): [damage, heal].
HOLY_SHOCK_SPELLS = {20473: [25912, 25914], 20929: [25911, 25913], 20930: [25902, 25903]}

TABLES = {
    "player_levelstats", "player_classlevelstats", "player_xp_for_level",
    "creature_template", "creature_loot_template", "reference_loot_template", "creature",
    "item_template", "spell_template", "npc_trainer", "playercreateinfo_spell", "npc_vendor",
    "spell_chain", "spell_bonus_data", "playercreateinfo_item", "quest_template", "spell_proc_event",
}
SPELL_FIELDS = [
    "Id", "SpellName", "Rank1", "School", "Category", "Dispel", "Mechanic", "Attributes",
    "AttributesEx", "AttributesEx2", "AttributesEx3", "Targets", "CastingTimeIndex", "RecoveryTime",
    "CategoryRecoveryTime", "StartRecoveryCategory", "StartRecoveryTime", "InterruptFlags",
    "AuraInterruptFlags", "ProcFlags", "ProcChance", "ProcCharges", "MaxLevel", "BaseLevel",
    "SpellLevel", "DurationIndex", "PowerType", "ManaCost", "ManaCostPercentage", "RangeIndex",
    "Speed", "StackAmount", "DmgClass", "SpellFamilyName", "SpellFamilyFlags", "SpellIconID",
] + [f"{field}{i}" for i in (1, 2, 3) for field in (
    "Effect", "EffectDieSides", "EffectBaseDice", "EffectDicePerLevel", "EffectRealPointsPerLevel",
    "EffectBasePoints", "EffectMechanic", "EffectImplicitTargetA", "EffectImplicitTargetB",
    "EffectRadiusIndex", "EffectApplyAuraName", "EffectAmplitude", "EffectMiscValue",
    "EffectTriggerSpell", "EffectMultipleValue", "DmgMultiplier",
)] + ["TargetCreatureType", "Stances"]
SPELL_EFFECT_LEARN = 36
SPELL_EFFECT_DUMMY = 3
SPELL_EFFECT_PROFICIENCY = 60
ITEM_CLASS_CONSUMABLE = 0
ITEM_SUBCLASS_FOOD = 5
SPELL_AURA_DUMMY = 4
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "classic")
BACKSLASH = chr(92)

CREATURE_FIELDS = [
    "Entry", "Name", "SubName", "MinLevel", "MaxLevel", "MinLevelHealth", "MaxLevelHealth",
    "MinLevelMana", "MaxLevelMana", "Armor", "MinMeleeDmg", "MaxMeleeDmg", "MeleeAttackPower",
    "MeleeBaseAttackTime", "Rank", "CreatureType", "Family", "LootId", "MinLootGold", "MaxLootGold",
    "SpeedWalk", "SpeedRun", "Faction", "ExtraFlags",
]
ITEM_FIELDS = [
    "entry", "name", "description", "Quality", "class", "subclass", "InventoryType", "ItemLevel",
    "RequiredLevel", "AllowableClass", "stackable", "BuyPrice", "SellPrice", "bonding", "armor",
    "block", "delay", "MaxDurability", "ContainerSlots", "dmg_min1", "dmg_max1", "dmg_type1",
    "dmg_min2", "dmg_max2", "dmg_type2", "BuyCount", "spellid_1", "spelltrigger_1", "spellcharges_1",
    "spellcooldown_1", "spellcategory_1", "spellcategorycooldown_1",
] + [f"stat_{kind}{i}" for i in range(1, 11) for kind in ("type", "value")]


def parse_values(line):
    """Splits an INSERT statement's VALUES into lists of strings."""
    text = line[line.index("VALUES") + 6:]
    rows, i, n = [], 0, len(text)
    while i < n:
        if text[i] != "(":
            i += 1
            continue
        values, current, quoted = [], "", False
        i += 1
        while True:
            ch = text[i]
            if quoted:
                if ch == BACKSLASH:
                    current += text[i + 1]
                    i += 2
                    continue
                if ch == "'":
                    quoted = False
                else:
                    current += ch
            elif ch == "'":
                quoted = True
            elif ch == ",":
                values.append(current)
                current = ""
            elif ch == ")":
                values.append(current)
                break
            else:
                current += ch
            i += 1
        rows.append(values)
        i += 1
    return rows


def read_dump(path):
    columns, rows, table = {}, {name: [] for name in TABLES}, None
    with gzip.open(path, "rt", encoding="utf8", errors="replace") as dump:
        for line in dump:
            create = re.match(r"CREATE TABLE `(\w+)`", line)
            if create:
                table = create.group(1) if create.group(1) in TABLES else None
                if table:
                    columns[table] = []
                continue
            if table and table not in rows or (table and line.startswith(")")):
                table = None
            elif table:
                column = re.match(r"\s+`(\w+)`", line)
                if column:
                    columns[table].append(column.group(1))
            insert = re.match(r"INSERT INTO `(\w+)`", line)
            if insert and insert.group(1) in TABLES:
                rows[insert.group(1)].extend(parse_values(line))
    return {name: [dict(zip(columns[name], row)) for row in rows[name]] for name in TABLES}


def number(value):
    try:
        return int(value)
    except ValueError:
        try:
            return float(value)
        except ValueError:
            return value


def most_common(values):
    values = list(values)
    return max(sorted(set(values)), key=values.count) if values else 0


def pick(row, fields):
    return {field: number(row[field]) for field in fields if field in row}


def main(path):
    db = read_dump(path)
    os.makedirs(OUT_DIR, exist_ok=True)

    # Player tables.
    level_stats, class_stats = {}, {}
    for row in sorted(db["player_levelstats"], key=lambda r: (int(r["race"]), int(r["class"]), int(r["level"]))):
        key = f'{row["race"]}-{row["class"]}'
        level_stats.setdefault(key, []).append([int(row[s]) for s in ("str", "agi", "sta", "inte", "spi")])
    for row in sorted(db["player_classlevelstats"], key=lambda r: (int(r["class"]), int(r["level"]))):
        class_stats.setdefault(row["class"], []).append([int(row["basehp"]), int(row["basemana"])])
    xp = [int(r["xp_for_next_level"]) for r in sorted(db["player_xp_for_level"], key=lambda r: int(r["lvl"]))]
    write("player_tables.json", {"level_stats": level_stats, "class_stats": class_stats, "xp_to_next": xp})

    # Creatures and their loot.
    creatures = {r["Entry"]: pick(r, CREATURE_FIELDS) for r in db["creature_template"] if int(r["Entry"]) in CREATURES}
    # From their classic spawns: the usual respawn time, and how far they
    # wander from their spawn point (0 stands still).
    for entry, creature in creatures.items():
        spawns = [s for s in db["creature"] if s["id"] == entry]
        creature["Respawn"] = most_common(int(s["spawntimesecsmin"]) for s in spawns)
        creature["Wander"] = most_common(float(s["spawndist"]) if s["MovementType"] == "1" else 0.0 for s in spawns)
    loot_rows = {}
    for r in db["creature_loot_template"]:
        loot_rows.setdefault(r["entry"], []).append(r)
    reference_rows = {}
    for r in db["reference_loot_template"]:
        reference_rows.setdefault(r["entry"], []).append(r)

    def loot_entries(rows):
        return [{
            "item": int(r["item"]), "chance": float(r["ChanceOrQuestChance"]), "group": int(r["groupid"]),
            "min_or_ref": int(r["mincountOrRef"]), "max": int(r["maxcount"]), "condition": int(r["condition_id"]),
        } for r in rows]

    with open(os.path.join(OUT_DIR, "start_outfits.json"), encoding="utf8") as f:
        outfits = json.load(f)
    creature_loot, references = {}, {}
    item_ids = {item for outfit in outfits.values() for item in outfit}
    item_ids.update(int(r["itemid"]) for r in db["playercreateinfo_item"])
    pending = []
    for creature in creatures.values():
        loot_id = str(creature["LootId"])
        if loot_id != "0" and loot_id in loot_rows:
            creature_loot[loot_id] = loot_entries(loot_rows[loot_id])
            pending.extend(creature_loot[loot_id])
    while pending:
        entry = pending.pop()
        if entry["min_or_ref"] < 0:
            ref = str(-entry["min_or_ref"])
            if ref not in references:
                references[ref] = loot_entries(reference_rows.get(ref, []))
                pending.extend(references[ref])
        else:
            item_ids.add(entry["item"])
    vendors = {}
    for entry in VENDORS:
        template = next(r for r in db["creature_template"] if int(r["Entry"]) == entry)
        stock = sorted((r for r in db["npc_vendor"] if int(r["entry"]) == entry), key=lambda r: int(r["slot"]))
        # NpcFlags 0x4000 is UNIT_NPC_FLAG_REPAIR: armorers who repair gear.
        vendors[str(entry)] = {"name": template["Name"], "subname": template["SubName"],
                               "repair": int(template["NpcFlags"]) & 0x4000 != 0,
                               "items": [int(r["item"]) for r in stock]}
        item_ids.update(int(r["item"]) for r in stock)
    write("loot_tables.json", {"creature": creature_loot, "reference": references})
    quests = export_quests(db)
    for quest in quests.values():
        item_ids.update(item for item, _ in quest["reward_choices"] + quest["reward_items"] + quest["items"])
        if quest["source_item"]:
            item_ids.add(quest["source_item"])
    write("quests.json", quests)

    items = {r["entry"]: pick(r, ITEM_FIELDS) for r in db["item_template"] if int(r["entry"]) in item_ids}
    for item in items.values():
        item["stats"] = [[item.pop(f"stat_type{i}"), item.pop(f"stat_value{i}")] for i in range(1, 11)]
        item["stats"] = [s for s in item["stats"] if s[1] != 0]
    # The game uses its own names, not the classic ones.
    renames.apply(items, creatures, vendors, {}, classic_names(db))
    write("vendors.json", vendors)
    write("creatures.json", creatures)
    write("items.json", items)
    write("characters.json", starting_characters(db, outfits, items, level_stats))
    print(f"{len(creatures)} creatures, {len(creature_loot)} loot tables, {len(references)} references, {len(items)} items, {len(vendors)} vendors")
    item_spells = {int(item["spellid_1"]) for item in items.values() if int(item["spellid_1"]) > 0}
    export_spells(db, item_spells)


def export_quests(db):
    """The rules of each quest in QUESTS, from quest_template."""
    quests = {}
    for r in db["quest_template"]:
        if int(r["entry"]) not in QUESTS:
            continue
        def pairs(id_field, count_field, n):
            return [[int(r[f"{id_field}{i}"]), int(r[f"{count_field}{i}"])] for i in range(1, n + 1) if int(r[f"{id_field}{i}"]) > 0]
        quests[r["entry"]] = {
            "level": int(r["QuestLevel"]), "min_level": int(r["MinLevel"]),
            "prev": int(r["PrevQuestId"]), "flags": int(r["QuestFlags"]),
            "kills": pairs("ReqCreatureOrGOId", "ReqCreatureOrGOCount", 4),
            "items": pairs("ReqItemId", "ReqItemCount", 4),
            "reward_choices": pairs("RewChoiceItemId", "RewChoiceItemCount", 6),
            "reward_items": pairs("RewItemId", "RewItemCount", 4),
            "money": int(r["RewOrReqMoney"]), "money_max_level": int(r["RewMoneyMaxLevel"]),
            "source_item": int(r["SrcItemId"]),
        }
    missing = set(map(str, QUESTS)) - set(quests)
    if missing:
        raise KeyError(f"Quests not in quest_template: {sorted(missing)}")
    return quests


def starting_characters(db, outfits, items, level_stats):
    """Starting items and weapon and armor proficiencies for each race and class."""
    spells = {r["Id"]: r for r in db["spell_template"]}
    characters = {}
    for key in level_stats:
        race, char_class = (int(part) for part in key.split("-"))
        # Player::Create: each outfit item, BuyCount of them, except food (4)
        # and drink (2); then playercreateinfo_item.
        start_items = []
        for item_id in outfits.get(key, []):
            item = items.get(str(item_id))
            if not item:
                continue
            count = int(item["BuyCount"])
            if int(item["class"]) == ITEM_CLASS_CONSUMABLE and int(item["subclass"]) == ITEM_SUBCLASS_FOOD:
                limit = {11: 4, 59: 2}.get(int(item["spellcategory_1"]))
                if limit and int(item["stackable"]) > limit:
                    count = limit
            start_items.append([item_id, count])
        start_items += [[int(r["itemid"]), int(r["amount"])] for r in db["playercreateinfo_item"]
                        if (int(r["race"]), int(r["class"])) == (race, char_class)]
        # Proficiency spells name an item class and a mask of its subclasses.
        proficiencies = set()
        for r in db["playercreateinfo_spell"]:
            spell = spells.get(r["Spell"])
            if (int(r["race"]), int(r["class"])) != (race, char_class) or not spell:
                continue
            if SPELL_EFFECT_PROFICIENCY in (int(spell[f"Effect{i}"]) for i in (1, 2, 3)):
                item_class, mask = int(spell["EquippedItemClass"]), int(spell["EquippedItemSubClassMask"])
                proficiencies.update(f"{item_class}:{bit}" for bit in range(32) if mask & (1 << bit))
        characters[key] = {"items": start_items, "proficiencies": sorted(proficiencies)}
    return characters


def export_spells(db, item_spells):
    """Class trainer lists, starting spells, item use spells and every spell they reach."""
    spells = {r["Id"]: r for r in db["spell_template"]}
    wanted, trainers = set(item_spells), {}

    def taught_by(teach_id):
        teach = spells[str(teach_id)]
        learned = [int(teach[f"EffectTriggerSpell{i}"]) for i in (1, 2, 3)
                   if int(teach[f"Effect{i}"]) == SPELL_EFFECT_LEARN]
        return learned or [int(teach_id)]

    def trainer_entries(trainer):
        entries = {}
        for r in db["npc_trainer"]:
            if int(r["entry"]) != trainer:
                continue
            learned = taught_by(r["spell"])
            # Skip junk rows that point at unrelated, retired spells.
            if any(spells[str(s)]["SpellName"].startswith("zzOLD") or s in SKIP_TRAINER_SPELLS for s in learned):
                continue
            entries[int(r["spell"])] = {"teach": int(r["spell"]), "spells": learned, "cost": int(r["spellcost"]),
                                        "level": int(r["reqlevel"])}
        return entries

    for name, trainer in CLASS_TRAINERS.items():
        if isinstance(trainer, dict):
            by_race = {race: trainer_entries(entry) for race, entry in trainer.items()}
            merged = {}
            for race, entries in by_race.items():
                for teach, entry in entries.items():
                    merged.setdefault(teach, dict(entry, races=[]))["races"].append(race)
            for entry in merged.values():
                if len(entry["races"]) == len(trainer):
                    del entry["races"]
            entries = list(merged.values())
        else:
            entries = list(trainer_entries(trainer).values())
        for entry in entries:
            wanted.update(entry["spells"])
        for spell_id, level in TALENT_FIRST_RANKS.get(name, []):
            entries.append({"teach": spell_id, "spells": [spell_id], "cost": 0, "level": level, "talent": True})
            wanted.add(spell_id)
        for spell_id, level in QUEST_SPELLS.get(name, []):
            entries.append({"teach": spell_id, "spells": [spell_id], "cost": 0, "level": level, "quest": True})
            wanted.add(spell_id)
        for spell_id, races in RACIAL_FIRST_RANKS.get(name, []):
            level = int(spells[str(spell_id)]["SpellLevel"])
            entries.append({"teach": spell_id, "spells": [spell_id], "cost": 0, "level": level, "races": races})
            wanted.add(spell_id)
        trainers[name] = sorted(entries, key=lambda e: (e["level"], e["spells"][0]))

    start = {}
    for r in db["playercreateinfo_spell"]:
        if int(r["class"]) in SPELL_CLASSES:
            spell = spells.get(r["Spell"])
            if spell and any(int(spell[f"Effect{i}"]) in START_SPELL_EFFECTS for i in (1, 2, 3)) \
                    and int(spell["SpellFamilyName"]) == CLASS_SPELL_FAMILIES[int(r["class"])]:
                start.setdefault(f'{r["race"]}-{r["class"]}', []).append(int(r["Spell"]))
                wanted.add(int(r["Spell"]))

    # Follow triggered spells, seal procs and seal judgements.
    pending = list(wanted)
    while pending:
        spell = spells.get(str(pending.pop()))
        if not spell:
            continue
        linked = [int(spell[f"EffectTriggerSpell{i}"]) for i in (1, 2, 3)]
        spell_id = int(spell["Id"])
        if spell_id in SEAL_OF_RIGHTEOUSNESS_PROCS:
            linked.append(SEAL_OF_RIGHTEOUSNESS_PROCS[spell_id])
        if spell_id == 635 or spell["SpellName"] == "Holy Light":
            linked.append(HOLY_LIGHT_HEAL)
        # Seals keep their judgement spell id (minus one) in effect 3's base points.
        if int(spell["Effect3"]) == 6 and int(spell["EffectApplyAuraName3"]) == SPELL_AURA_DUMMY:
            linked.append(int(spell["EffectBasePoints3"]) + 1)
        # Judgement of Command's dummy effect names its damage spell the same way.
        if int(spell["Effect1"]) == SPELL_EFFECT_DUMMY and int(spell["EffectBasePoints1"]) > 1000:
            linked.append(int(spell["EffectBasePoints1"]) + 1)
        linked.append(JUDGEMENT_PROC_SPELLS.get(spell_id, 0))
        linked.extend(HOLY_SHOCK_SPELLS.get(spell_id, []))
        linked.append(SPELL_LINKS.get(spell_id, 0))
        if spell["SpellName"] == "Power Word: Shield":
            linked.append(WEAKENED_SOUL)
        for other in linked:
            if other and other not in wanted and str(other) in spells:
                wanted.add(other)
                pending.append(other)

    out = {}
    for spell_id in sorted(wanted):
        spell = pick(spells[str(spell_id)], SPELL_FIELDS)
        spell["SpellFamilyFlags"] = int(spells[str(spell_id)]["SpellFamilyFlags"])
        out[str(spell_id)] = spell
    renames.apply({}, {}, {}, out, classic_names(db))
    chains = {r["spell_id"]: {"prev": int(r["prev_spell"]), "first": int(r["first_spell"]), "rank": int(r["rank"])}
              for r in db["spell_chain"] if int(r["spell_id"]) in wanted}
    bonus = {r["entry"]: {"direct": float(r["direct_bonus"]), "dot": float(r["dot_bonus"])}
             for r in db["spell_bonus_data"] if int(r["entry"]) in wanted}
    # Proc rates (procs per minute) and cooldowns, by spell, from spell_proc_event.
    procs = {r["entry"]: {"ppm": float(r["ppmRate"]), "chance": float(r["CustomChance"]), "cooldown": float(r["Cooldown"])}
             for r in db["spell_proc_event"] if int(r["entry"]) in wanted}
    write("spells.json", {"spells": out, "chains": chains, "bonus": bonus, "trainers": trainers,
                          "start_spells": start, "procs": procs,
                          "judgement_procs": {str(k): v for k, v in JUDGEMENT_PROC_SPELLS.items()},
                          "holy_shock": {str(k): v for k, v in HOLY_SHOCK_SPELLS.items()},
                          "links": {str(k): v for k, v in SPELL_LINKS.items()},
                          "seal_of_righteousness_procs": {str(k): v for k, v in SEAL_OF_RIGHTEOUSNESS_PROCS.items()}})
    print(f"{len(out)} spells, {sum(len(t) for t in trainers.values())} trainer entries, start spells {start}")


def classic_names(db):
    """Every item, creature and spell name in the classic database."""
    return ({r["name"] for r in db["item_template"]} | {r["Name"] for r in db["creature_template"]}
            | {r["SpellName"] for r in db["spell_template"]})


def write(name, data):
    with open(os.path.join(OUT_DIR, name), "w", encoding="utf8") as out:
        json.dump(data, out, separators=(",", ":"), ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1])
