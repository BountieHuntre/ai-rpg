"""Original names for the game, replacing the classic WoW names in the exported data.

The numbers and rules stay classic; the names are the game's own. Plain fantasy
words (Wolf, Copper Ore, Paladin, Human) are kept, but every recognisable
WoW name is replaced. extract.py applies this after exporting.

Every exported name must be either renamed here or listed in KEEP, and no new
name may be a classic item, creature or spell name, so new exports can't slip
classic names in unnoticed.
"""

ITEMS = {
    "Squire's Boots": "Postulant's Boots",
    "Squire's Pants": "Postulant's Breeches",
    "Squire's Shirt": "Postulant's Undershirt",
    "Refreshing Spring Water": "Cool Well Water",
    "Silverleaf": "Pale Sageleaf",
    "Peacebloom": "Meadow Blossom",
    "Ragged Leather Vest": "Worn Hide Vest",
    "Ragged Leather Pants": "Worn Hide Pants",
    "Ragged Leather Boots": "Worn Hide Boots",
    "Ragged Leather Gloves": "Worn Hide Gloves",
    "Ragged Leather Belt": "Worn Hide Belt",
    "Ragged Leather Bracers": "Worn Hide Bracers",
    "Ragged Cloak": "Worn Hide Cape",
    "Frayed Shoes": "Threadbare Shoes",
    "Frayed Cloak": "Threadbare Cloak",
    "Frayed Gloves": "Threadbare Gloves",
    "Frayed Pants": "Threadbare Pants",
    "Frayed Robe": "Threadbare Robe",
    "Frayed Belt": "Threadbare Belt",
    "Frayed Bracers": "Threadbare Bracers",
    "Battered Buckler": "Scraped Roundel",
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
    # Starting gear for the other classes.
    "Recruit's Shirt": "Levy's Shirt",
    "Recruit's Pants": "Levy's Breeches",
    "Recruit's Boots": "Levy's Boots",
    "Acolyte's Robe": "Deacon's Robe",
    "Acolyte's Pants": "Deacon's Pants",
    "Acolyte's Shirt": "Deacon's Shirt",
    "Acolyte's Shoes": "Deacon's Shoes",
    "Apprentice's Robe": "Pupil's Robe",
    "Apprentice's Pants": "Pupil's Pants",
    "Apprentice's Shirt": "Pupil's Shirt",
    "Apprentice's Boots": "Pupil's Boots",
    "Neophyte's Robe": "Fledgling's Robe",
    "Neophyte's Pants": "Fledgling's Pants",
    "Neophyte's Shirt": "Fledgling's Shirt",
    "Neophyte's Boots": "Fledgling's Boots",
    "Novice's Robe": "Seedling's Robe",
    "Novice's Pants": "Seedling's Pants",
    "Brawler's Harness": "Scrapper's Harness",
    "Brawler's Pants": "Scrapper's Pants",
    "Brawler's Boots": "Scrapper's Boots",
    "Footpad's Shirt": "Cutpurse's Shirt",
    "Footpad's Pants": "Cutpurse's Pants",
    "Footpad's Shoes": "Cutpurse's Shoes",
    "Thug Shirt": "Ruffian's Shirt",
    "Thug Pants": "Ruffian's Pants",
    "Thug Boots": "Ruffian's Boots",
    "Trapper's Shirt": "Snarer's Shirt",
    "Trapper's Pants": "Snarer's Pants",
    "Trapper's Boots": "Snarer's Boots",
    "Rugged Trapper's Shirt": "Rough Snarer's Shirt",
    "Rugged Trapper's Pants": "Rough Snarer's Pants",
    "Rugged Trapper's Boots": "Rough Snarer's Boots",
    "Primitive Kilt": "Hide-Wrap Kilt",
    "Primitive Mantle": "Hide-Wrap Mantle",
    "Bent Staff": "Knotted Oak Staff",
    "Handcrafted Staff": "Whittled Staff",
    "Darnassian Bleu": "Sharp Blue Cheese",
    "Forest Mushroom Cap": "Brown Woodcap",
    "Tough Jerky": "Dried Meat Strip",
    "Light Quiver": "Simple Quiver",
    "Small Ammo Pouch": "Small Bullet Sack",
    "Old Blunderbuss": "Rusty Handgonne",
    "Worn Axe": "Chipped Hatchet",
    "Worn Battleaxe": "Chipped Greataxe",
    "Worn Dagger": "Dull Knife",
    "Worn Mace": "Dented Cudgel",
    "Worn Shortbow": "Weathered Shortbow",
    "Worn Shortsword": "Nicked Shortsword",
    "Worn Wooden Shield": "Cracked Wooden Shield",
}

# Item flavor text, replaced whole.
DESCRIPTIONS = {}

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
    "Chipped Claw", "Timber Wolf", "Young Wolf", "Food", "Drink", "Parry", "Stun", "Plate Mail", "Haste",
}


def _rename(name, table, kind, missing):
    if name in table:
        return table[name]
    if name not in KEEP:
        missing.append(f"{kind} {name!r}")
    return name


def apply(items, creatures, vendors, spells, classic_names):
    """Renames the exported data in place. Fails listing every name with no
    original name yet, and every new name that is itself a classic name."""
    clashes = sorted(new for table in (ITEMS, CREATURES, SPELLS) for new in table.values() if new in classic_names)
    clashes += sorted(name for name, _ in VENDORS.values() if name in classic_names)
    if clashes:
        raise KeyError("These new names are classic names too, change them in tools/classic_db/renames.py:\n"
                       + "\n".join(clashes))
    missing = []
    for item in items.values():
        item["name"] = _rename(item["name"], ITEMS, "Item", missing)
        if item.get("description"):
            item["description"] = _rename(item["description"], DESCRIPTIONS, "Description", missing)
    for creature in creatures.values():
        creature["Name"] = _rename(creature["Name"], CREATURES, "Creature", missing)
    for entry, vendor in vendors.items():
        vendor["name"], vendor["subname"] = VENDORS[entry]
    for spell in spells.values():
        spell["SpellName"] = _rename(spell["SpellName"], SPELLS, "Spell", missing)
    if missing:
        raise KeyError("No original name yet, add these to tools/classic_db/renames.py:\n" + "\n".join(sorted(set(missing))))

