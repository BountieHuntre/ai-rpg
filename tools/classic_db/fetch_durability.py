"""Fetches the client's repair cost tables into data/classic/durability.json.

Usage (Python 3, no extra packages):
    python tools/classic_db/fetch_durability.py

Repair cost in CMaNGOS (Player::DurabilityRepair) is
    lost durability * DurabilityCosts[item level][column] * DurabilityQuality[(quality + 1) * 2]
where column is the weapon subclass, or the armor subclass + 21. Those two
tables are client DBC files, not part of the server database, so they come
from wago.tools' Classic Era (1.15) client exports.
"""

import csv
import io
import json
import os
import urllib.request

URL = "https://wago.tools/db2/{table}/csv?product=wow_classic_era"
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "classic", "durability.json")


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
    with open(OUT, "w", encoding="utf8") as out:
        json.dump({"costs": costs, "quality": quality, "source": URL.format(table="<table>")}, out, separators=(",", ":"))
    print(f"{len(costs)} item levels, {len(quality)} quality modifiers")


if __name__ == "__main__":
    main()
