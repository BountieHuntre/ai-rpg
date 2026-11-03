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

Factions are FactionTemplate, for who is hostile to whom (FactionTemplateEntry
in CMaNGOS), and each race's template from ChrRaces, into
data/classic/factions.json.
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


if __name__ == "__main__":
    main()
