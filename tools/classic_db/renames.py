"""Original names for the game, replacing the classic WoW names in the exported data.

The numbers and rules stay classic; the names are the game's own. Plain fantasy
words (Wolf, Copper Ore, Paladin, Human) are kept, but every recognisable
WoW name is replaced. extract.py applies this after exporting, and running this
file on its own renames the JSON already in data/classic:

    python tools/classic_db/renames.py

Every exported name must be either renamed here or listed in KEEP, so new
exports can't slip classic names in unnoticed.
"""

import json
import os

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "classic")

ITEMS = {
    "Squire's Boots": "Recruit's Boots",
    "Squire's Pants": "Recruit's Trousers",
    "Squire's Shirt": "Recruit's Undershirt",
    "Refreshing Spring Water": "Cool Well Water",
    "Silverleaf": "Pale Sageleaf",
    "Peacebloom": "Meadow Blossom",
    "Ragged Leather Vest": "Worn Hide Vest",
    "Ragged Leather Pants": "Worn Hide Pants",
    "Ragged Leather Boots": "Worn Hide Boots",
    "Ragged Leather Gloves": "Worn Hide Gloves",
    "Ragged Leather Belt": "Worn Hide Belt",
    "Ragged Leather Bracers": "Worn Hide Bracers",
    "Ragged Cloak": "Worn Hide Cloak",
    "Frayed Shoes": "Threadbare Shoes",
    "Frayed Cloak": "Threadbare Cloak",
    "Frayed Gloves": "Threadbare Gloves",
    "Frayed Pants": "Threadbare Pants",
    "Frayed Robe": "Threadbare Robe",
    "Frayed Belt": "Threadbare Belt",
    "Frayed Bracers": "Threadbare Bracers",
    "Battered Buckler": "Dented Buckler",
    "Bent Large Shield": "Warped Kite Shield",
    "Battleworn Hammer": "Scuffed Militia Mace",
    "Tarnished Chain Vest": "Dull Ringmail Vest",
    "Tarnished Chain Belt": "Dull Ringmail Belt",
    "Tarnished Chain Leggings": "Dull Ringmail Leggings",
    "Tarnished Chain Boots": "Dull Ringmail Boots",
    "Tarnished Chain Bracers": "Dull Ringmail Bracers",
    "Tarnished Chain Gloves": "Dull Ringmail Gloves",
    "Flimsy Chain Belt": "Loose Link Belt",
    "Flimsy Chain Boots": "Loose Link Boots",
    "Flimsy Chain Bracers": "Loose Link Bracers",
    "Flimsy Chain Cloak": "Loose Link Cloak",
    "Flimsy Chain Gloves": "Loose Link Gloves",
    "Flimsy Chain Pants": "Loose Link Pants",
    "Flimsy Chain Vest": "Loose Link Vest",
    "Small Green Dagger": "Mossy Dirk",
    "Tough Hunk of Bread": "Hard Barley Loaf",
    "Feral Blade": "Wildfang Blade",
    "Small Lustrous Pearl": "Small Pale Pearl",
    "Hearthstone": "Homing Token",
    "Rugged Leather Pants": "Sturdy Hide Pants",
}

CREATURES = {
    "Kobold Worker": "Burrowling Digger",
}

# Vendor names and titles, by creature entry.
VENDORS = {
    "152": ("Friar Osric", "Provisioner"),
    "1213": ("Hugh Stannard", "Armorer"),
}

# The game code recognises spell kinds by these name patterns: "Oath of" seals,
# "Verdict" judgements, "Boon of" blessings and "... Presence" auras.
SPELLS = {
    "Seal of Righteousness": "Oath of Valor",
    "Seal of the Crusader": "Oath of the Vanguard",
    "Seal of Justice": "Oath of Binding",
    "Seal of Light": "Oath of Mending",
    "Seal of Wisdom": "Oath of Insight",
    "Seal of Command": "Oath of Dominion",
    "Judgement": "Verdict",
    "Judgement of Righteousness": "Verdict of Valor",
    "Judgement of the Crusader": "Verdict of the Vanguard",
    "Judgement of Justice": "Verdict of Binding",
    "Judgement of Light": "Verdict of Mending",
    "Judgement of Light Intermediate": "Verdict of Mending Intermediate",
    "Judgement of Wisdom": "Verdict of Insight",
    "Judgement of Wisdom Intermediate": "Verdict of Insight Intermediate",
    "Judgement of Command": "Verdict of Dominion",
    "Blessing of Might": "Boon of Strength",
    "Blessing of Wisdom": "Boon of Clarity",
    "Blessing of Protection": "Boon of Shelter",
    "Blessing of Freedom": "Boon of Unfettering",
    "Blessing of Sacrifice": "Boon of the Martyr",
    "Blessing of Salvation": "Boon of Quietude",
    "Blessing of Light": "Boon of Radiance",
    "Blessing of Sanctuary": "Boon of Refuge",
    "Greater Blessing of Kings": "Greater Boon of Sovereigns",
    "Greater Blessing of Might": "Greater Boon of Strength",
    "Greater Blessing of Wisdom": "Greater Boon of Clarity",
    "Greater Blessing of Salvation": "Greater Boon of Quietude",
    "Greater Blessing of Light": "Greater Boon of Radiance",
    "Greater Blessing of Sanctuary": "Greater Boon of Refuge",
    "Devotion Aura": "Bulwark Presence",
    "Retribution Aura": "Thorned Presence",
    "Concentration Aura": "Focused Presence",
    "Fire Resistance Aura": "Emberward Presence",
    "Frost Resistance Aura": "Frostward Presence",
    "Shadow Resistance Aura": "Gloomward Presence",
    "Holy Light": "Mending Radiance",
    "Flash of Light": "Quick Radiance",
    "Holy Shock": "Radiant Jolt",
    "Holy Wrath": "Radiant Fury",
    "Holy Shield": "Radiant Bulwark",
    "Hammer of Justice": "Stunning Gavel",
    "Hammer of Wrath": "Gavel of Reckoning",
    "Lay on Hands": "Last Rite",
    "Divine Protection": "Hallowed Guard",
    "Divine Shield": "Hallowed Aegis",
    "Divine Intervention": "Hallowed Ransom",
    "Purify": "Cleansing Touch",
    "Cleanse": "Greater Cleansing",
    "Consecration": "Hallowed Ground",
    "Exorcism": "Banishment",
    "Turn Undead": "Rebuke the Dead",
    "Redemption": "Revival",
    "Righteous Fury": "Zealous Fervor",
    "Hearthstone": "Homing Token",
}

# Plain names that are kept as they are.
KEEP = {
    "Tough Wolf Meat", "Melted Candle", "Small Red Pouch", "Small Blue Pouch", "Small Brown Pouch",
    "Small Black Pouch", "Small Green Pouch", "Large Round Shield", "Small Shield", "Light Mail Bracers",
    "Light Chain Armor", "Copper Chain Vest", "Rough Arrow", "Light Shot", "Copper Ore", "Rough Stone",
    "Small Throwing Knife", "Crude Throwing Axe", "Shiny Red Apple", "Ruined Pelt", "Broken Fang",
    "Chipped Claw", "Timber Wolf", "Young Wolf", "Food", "Drink", "Parry", "Stun", "Plate Mail",
}


def _rename(name, table, kind):
    if name in table:
        return table[name]
    if name in KEEP or name in table.values():
        return name
    raise KeyError(f"{kind} {name!r} has no original name: add it to tools/classic_db/renames.py")


def apply(items, creatures, vendors, spells):
    """Renames the exported data in place."""
    for item in items.values():
        item["name"] = _rename(item["name"], ITEMS, "Item")
        if item.get("description"):
            raise KeyError(f"Item {item['name']!r} has a description: give it an original one here")
    for creature in creatures.values():
        creature["Name"] = _rename(creature["Name"], CREATURES, "Creature")
    for entry, vendor in vendors.items():
        vendor["name"], vendor["subname"] = VENDORS[entry]
    for spell in spells.values():
        spell["SpellName"] = _rename(spell["SpellName"], SPELLS, "Spell")


def _load(name):
    with open(os.path.join(DATA_DIR, name), encoding="utf8") as f:
        return json.load(f)


def _save(name, data):
    with open(os.path.join(DATA_DIR, name), "w", encoding="utf8") as out:
        json.dump(data, out, separators=(",", ":"), ensure_ascii=False)


if __name__ == "__main__":
    items, creatures, vendors, spells = (_load(f) for f in ("items.json", "creatures.json", "vendors.json", "spells.json"))
    apply(items, creatures, vendors, spells["spells"])
    for name, data in (("items.json", items), ("creatures.json", creatures), ("vendors.json", vendors), ("spells.json", spells)):
        _save(name, data)
    print("renamed")
