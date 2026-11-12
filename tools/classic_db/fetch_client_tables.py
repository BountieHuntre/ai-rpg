"""Fetches the client tables the game needs that aren't in the server database:
repair costs into data/classic/durability.json and starting gear into
data/classic/start_outfits.json. Run it before extract.py, which reads the
starting gear.

Usage (Python 3, no extra packages):
    python tools/classic_db/fetch_client_tables.py

Repair cost in CMaNGOS (Player::DurabilityRepair) is
    lost durability * DurabilityCosts[item level][column] * DurabilityQuality[(quality + 1) * 2]
where column is the weapon subclass, or the armor subclass + 21. Those two
tables are client DBC files, not part of the server database, so they come
from wago.tools' Classic Era (1.15) client exports.

Starting gear is CharStartOutfit, by race and class (Player::Create in CMaNGOS
gives each new character these items).

Talents are TalentTab (each class's three trees) and Talent (each talent's
tier, column, rank spells and prerequisites), into data/classic/talents.json.
extract.py exports their spells and renames the trees. Each class spell's
skill line (SkillLineAbility) goes into skill_lines.json, for the spellbook's
tabs.

Factions are FactionTemplate, for who is hostile to whom (FactionTemplateEntry
in CMaNGOS), and each race's template from ChrRaces, into
data/classic/factions.json.

Pets (the Ranger's): CreatureFamily (each family's name, its two skill lines,
the abilities it may learn, and its size range) and CreatureSpellData (the
abilities a wild beast knows, by creature_template's PetSpellDataId, which a
Ranger learns by taming it), into data/classic/pet_families.json.
`python tools/classic_db/fetch_client_tables.py pets` fetches only these.
"""

import csv
import io
import json
import os
import urllib.request

URL = "https://wago.tools/db2/{table}/csv?product=wow_classic_era"
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "classic")


def fetch(table):
    request = urllib.request.Request(URL.format(table=table), headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return list(csv.DictReader(io.StringIO(response.read().decode("utf8"))))


def main():
    costs = {}
    for row in fetch("DurabilityCosts"):
        weapon = [int(row[f"WeaponSubClassCost_{i}"]) for i in range(21)]
        armor = [int(row[f"ArmorSubClassCost_{i}"]) for i in range(8)]
        costs[row["ID"]] = weapon + armor
    quality = {row["ID"]: float(row["Data"]) for row in fetch("DurabilityQuality")}
    with open(os.path.join(OUT_DIR, "durability.json"), "w", encoding="utf8") as out:
        json.dump({"costs": costs, "quality": quality, "source": URL.format(table="<table>")}, out, separators=(",", ":"))
    print(f"{len(costs)} item levels, {len(quality)} quality modifiers")

    # Outfits are the same for both sexes; keep the male ones, by "race-class".
    outfits = {}
    for row in fetch("CharStartOutfit"):
        if row["SexID"] == "0":
            items = [int(row[f"ItemID_{i}"]) for i in range(24)]
            outfits[f'{row["RaceID"]}-{row["ClassID"]}'] = [item for item in items if item > 0]
    with open(os.path.join(OUT_DIR, "start_outfits.json"), "w", encoding="utf8") as out:
        json.dump(dict(sorted(outfits.items())), out, separators=(",", ":"))
    print(f"{len(outfits)} starting outfits")

    templates = {}
    for row in fetch("FactionTemplate"):
        templates[row["ID"]] = {
            "faction": int(row["Faction"]), "group": int(row["FactionGroup"]),
            "friend_group": int(row["FriendGroup"]), "enemy_group": int(row["EnemyGroup"]),
            "enemies": [int(row[f"Enemies_{i}"]) for i in range(8) if int(row[f"Enemies_{i}"]) > 0],
            "friends": [int(row[f"Friend_{i}"]) for i in range(8) if int(row[f"Friend_{i}"]) > 0],
        }
    races = {row["ID"]: int(row["FactionID"]) for row in fetch("ChrRaces") if int(row["ID"]) <= 8}
    with open(os.path.join(OUT_DIR, "factions.json"), "w", encoding="utf8") as out:
        json.dump({"templates": templates, "races": races}, out, separators=(",", ":"))
    print(f"{len(templates)} faction templates")
    export_talents()
    export_skill_lines()
    export_weapon_skills()


def export_pet_families():
    """Pet families, each family skill line's abilities, and the spells wild
    beasts know, into pet_families.json."""
    families = {}
    for row in fetch("CreatureFamily"):
        families[row["ID"]] = {
            "name": row["Name_lang"], "skill_lines": [int(row[f"SkillLine_{i}"]) for i in range(2) if int(row[f"SkillLine_{i}"]) > 0],
            "min_scale": float(row["MinScale"]), "max_scale": float(row["MaxScale"]),
            "min_scale_level": int(row["MinScaleLevel"]), "max_scale_level": int(row["MaxScaleLevel"]),
        }
    spell_data = {}
    for row in fetch("CreatureSpellData"):
        spells = [int(row[f"Spells_{i}"]) for i in range(4) if int(row[f"Spells_{i}"]) > 0]
        if spells:
            spell_data[row["ID"]] = spells
    # Each family skill line's abilities (a spell can be in several: Bite).
    lines = {line for family in families.values() for line in family["skill_lines"]}
    abilities = {}
    for row in fetch("SkillLineAbility"):
        if int(row["SkillLine"]) in lines:
            abilities.setdefault(row["SkillLine"], []).append(int(row["Spell"]))
    with open(os.path.join(OUT_DIR, "pet_families.json"), "w", encoding="utf8") as out:
        json.dump({"families": families, "spell_data": spell_data, "abilities": abilities}, out, separators=(",", ":"))
    print(f"{len(families)} creature families, {len(spell_data)} creature spell lists")


def export_skill_lines():
    """Each class spell's skill line (SkillLineAbility, for skill lines of
    the class category, 7), into skill_lines.json: the spellbook's tabs."""
    class_lines = {row["ID"] for row in fetch("SkillLine") if row["CategoryID"] == "7"}
    spells = {}
    for row in fetch("SkillLineAbility"):
        if row["SkillLine"] in class_lines:
            spells[row["Spell"]] = int(row["SkillLine"])
    with open(os.path.join(OUT_DIR, "skill_lines.json"), "w", encoding="utf8") as out:
        json.dump(spells, out, separators=(",", ":"))
    print(f"{len(spells)} class spells' skill lines")


def export_weapon_skills():
    """Which classes can learn each weapon skill: every spell of a skill line
    in the weapon skills category (6) in SkillLineAbility, with the classes of
    that skill's SkillRaceClassInfo rows joined (some rows are per race), as a
    class mask (bit 0 Warrior). Into weapon_skills.json, for the Weapon Master."""
    weapon_lines = {row["ID"] for row in fetch("SkillLine") if row["CategoryID"] == "6"}
    masks = {}
    for row in fetch("SkillRaceClassInfo"):
        if row["SkillID"] in weapon_lines:
            masks[row["SkillID"]] = masks.get(row["SkillID"], 0) | int(row["ClassMask"])
    spells = {}
    for row in fetch("SkillLineAbility"):
        if row["SkillLine"] in weapon_lines:
            spells[row["Spell"]] = masks.get(row["SkillLine"], 0)
    with open(os.path.join(OUT_DIR, "weapon_skills.json"), "w", encoding="utf8") as out:
        json.dump(spells, out, separators=(",", ":"))
    print(f"{len(spells)} weapon skill spells")


def export_talents():
    """By class id: the trees in order, each with its talents. A talent's
    prereq is [talent id, ranks needed]; ranks are the spell of each rank."""
    by_class = {}
    tabs = {}
    for row in fetch("TalentTab"):
        mask = int(row["ClassMask"])
        if mask and mask & (mask - 1) == 0:
            class_id = mask.bit_length()
            tabs[row["ID"]] = {"id": int(row["ID"]), "name": row["Name_lang"], "order": int(row["OrderIndex"]),
                               "class": class_id, "talents": []}
    for row in fetch("Talent"):
        tab = tabs.get(row["TabID"])
        if tab is None:
            continue
        ranks = [int(row[f"SpellRank_{i}"]) for i in range(9) if int(row[f"SpellRank_{i}"]) > 0]
        prereq = [[int(row[f"PrereqTalent_{i}"]), int(row[f"PrereqRank_{i}"]) + 1] for i in range(3)
                  if int(row[f"PrereqTalent_{i}"]) > 0]
        tab["talents"].append({"id": int(row["ID"]), "tier": int(row["TierID"]), "column": int(row["ColumnIndex"]),
                               "ranks": ranks, "prereq": prereq})
    for tab in sorted(tabs.values(), key=lambda t: (t["class"], t["order"])):
        tab["talents"].sort(key=lambda t: (t["tier"], t["column"]))
        by_class.setdefault(str(tab.pop("class")), []).append(tab)
    with open(os.path.join(OUT_DIR, "talents.json"), "w", encoding="utf8") as out:
        json.dump(by_class, out, separators=(",", ":"))
    print(f"{sum(len(t['talents']) for c in by_class.values() for t in c)} talents in {len(tabs)} trees")


if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["pets"]:
        export_pet_families()
    else:
        main()
        export_pet_families()
