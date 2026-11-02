"""Extracts classic WoW (patch 1.12) data for the game from the CMaNGOS classic
database dump into data/classic/*.json.

Usage (Python 3, no extra packages):
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

# creature_template entries used in the game.
CREATURES = [299, 69, 257]  # Young Wolf, Timber Wolf, Kobold Worker
# Items the player starts with: Human Paladin starting gear.
STARTER_ITEMS = [2361, 45, 44, 43, 6948]

TABLES = {
    "player_levelstats", "player_classlevelstats", "player_xp_for_level",
    "creature_template", "creature_loot_template", "reference_loot_template",
    "item_template",
}
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "classic")
BACKSLASH = chr(92)

CREATURE_FIELDS = [
    "Entry", "Name", "SubName", "MinLevel", "MaxLevel", "MinLevelHealth", "MaxLevelHealth",
    "MinLevelMana", "MaxLevelMana", "Armor", "MinMeleeDmg", "MaxMeleeDmg", "MeleeAttackPower",
    "MeleeBaseAttackTime", "Rank", "CreatureType", "Family", "LootId", "MinLootGold", "MaxLootGold",
    "SpeedWalk", "SpeedRun",
]
ITEM_FIELDS = [
    "entry", "name", "description", "Quality", "class", "subclass", "InventoryType", "ItemLevel",
    "RequiredLevel", "AllowableClass", "stackable", "BuyPrice", "SellPrice", "bonding", "armor",
    "block", "delay", "MaxDurability", "ContainerSlots", "dmg_min1", "dmg_max1", "dmg_type1",
    "dmg_min2", "dmg_max2", "dmg_type2",
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

    creature_loot, references, item_ids = {}, {}, set(STARTER_ITEMS)
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
    write("creatures.json", creatures)
    write("loot_tables.json", {"creature": creature_loot, "reference": references})

    items = {r["entry"]: pick(r, ITEM_FIELDS) for r in db["item_template"] if int(r["entry"]) in item_ids}
    for item in items.values():
        item["stats"] = [[item.pop(f"stat_type{i}"), item.pop(f"stat_value{i}")] for i in range(1, 11)]
        item["stats"] = [s for s in item["stats"] if s[1] != 0]
    write("items.json", items)
    print(f"{len(creatures)} creatures, {len(creature_loot)} loot tables, {len(references)} references, {len(items)} items")


def write(name, data):
    with open(os.path.join(OUT_DIR, name), "w", encoding="utf8") as out:
        json.dump(data, out, separators=(",", ":"), ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1])
