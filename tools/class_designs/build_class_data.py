"""Builds a designed class's game data from its design.

    python tools/class_designs/build_class_data.py

Reads docs/class_designs/spellsword.json (abilities, ranks, talents) and the
spec below (how each ability and talent works as spell_template rows), and
writes data/classes/spellsword.json in spells.json's own shape, plus the
class's player tables and starting kits. SpellDB and ClassicData merge it over
the classic data at load (CLASS_FILES), so the classic export can be
regenerated without touching it.

Spell ids from 900000 (no classic spell uses them); the class's own spell
family is 12, with one SpellFamilyFlags bit per ability, so talents change
them as spell modifiers (SpellMods), as classic's do.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CLASS_ID = 10
FAMILY = 12
TRAINER = "spellsword"
RACES = [1, 4, 5, 7, 8]  # Human, Night Elf, Undead, Gnome, Troll

# spell_template values used here (as SpellDB names them).
SCHOOL = {"physical": 0, "holy": 1, "fire": 2, "nature": 3, "frost": 4, "shadow": 5, "arcane": 6}
EFFECT_SCHOOL_DAMAGE, EFFECT_DUMMY, EFFECT_APPLY_AURA = 2, 3, 6
EFFECT_DISPEL, EFFECT_INTERRUPT, EFFECT_PROFICIENCY = 38, 68, 60
EFFECT_ATTACK_ME, EFFECT_WEAPON_DAMAGE = 114, 17
AURA_DUMMY, AURA_MOD_STUN, AURA_MOD_TAUNT, AURA_MOD_ROOT = 4, 12, 11, 26
AURA_MOD_DAMAGE_PERCENT_DONE, AURA_MOD_DAMAGE_PERCENT_TAKEN = 79, 87
AURA_MOD_DECREASE_SPEED, AURA_PERIODIC_DAMAGE = 33, 3
AURA_SCHOOL_ABSORB, AURA_MOD_SHAPESHIFT, AURA_MOD_THREAT = 69, 36, 10
AURA_MOD_PARRY, AURA_MOD_CRIT, AURA_MOD_SPELL_CRIT = 47, 52, 71
AURA_MOD_BASE_RESISTANCE_PCT, AURA_MOD_TOTAL_STAT_PCT, AURA_MOD_MELEE_HASTE = 142, 137, 138
AURA_MOD_SILENCE = 27
AURA_FLAT, AURA_PCT = 107, 108
# Our own aura types (no classic number): read by Combatant.
AURA_CONTROL_DURATION_PCT = 1001  # stuns and fears on the unit last this much shorter
AURA_CRIT_DAMAGE_TAKEN_PCT = 1002  # critical strikes on the unit deal this much less
# SpellMods operations.
OP_DAMAGE, OP_DURATION, OP_ALL_EFFECTS, OP_RANGE = 0, 1, 8, 5
OP_CASTING_TIME, OP_COOLDOWN, OP_COST = 10, 11, 14
TARGET_SELF, TARGET_ENEMY = 1, 6
ATTR_PASSIVE = 0x40
ATTR_EX_CHANNELED = 0x4
SCHOOLS_MAGIC = 0x7E  # holy to arcane
SCHOOLS_ALL = 0x7F
# Forms: shapeshift ids no classic form uses; their Stances bits.
FORM_BLADESONG, FORM_WARDWEAVE = 20, 21
STANCE_BLADESONG, STANCE_WARDWEAVE = 1 << (FORM_BLADESONG - 1), 1 << (FORM_WARDWEAVE - 1)
# SpellDB index tables (casting times, durations, ranges), ours from 900.
CAST = {"Instant": 1, "1 sec": 4, "1.5 sec": 16, "2 sec": 5, "2.5 sec": 19}
DURATION = {0: 0, 1: 36, 2: 39, 3: 27, 4: 35, 5: 28, 6: 32, 8: 31, 10: 1, 12: 29, 15: 8, 20: 18, 30: 9, 60: 3, 1800: 30, 3600: 42, -1: 21}
RANGE = {0: 1, 5: 2, 8: 7, 10: 7, 20: 3, 25: 901, 30: 4, 40: 5}
# Weapon classes for talents that need a sword.
ITEM_CLASS_WEAPON = 2
SWORDS = (1 << 7) | (1 << 8)

# One bit per ability, for spell modifiers.
FLAG = {name: 1 << i for i, name in enumerate([
    "Arcane Strike", "Flame Edge", "Spark", "Release", "Bladesong Form", "Wardweave Form", "Frost Edge",
    "Runic Ward", "Phase Step", "Severing Sigil", "Storm Edge", "Mark of Challenge", "Mirror Guard",
    "Arc Cleave", "Sap Edge", "Warding Edge", "Binding Glyph", "Hurl Blade", "Challenging Glyph",
    "Arcane Surge", "Spell Shatter", "Last Sigil", "Glyph Storm", "Sigil Flurry", "Reprisal",
    "Aegis of Runes", "Arcane Lance", "Overload", "Thousand Cuts", "Bastion of Glyphs", "Arc of Ruin",
])}
EDGES = ["Flame Edge", "Frost Edge", "Storm Edge", "Warding Edge"]
ALL_SPELLS = sum(FLAG.values())
EDGE_MASK = sum(FLAG[n] for n in EDGES)

# How each ability works as a row: school, target, range, duration, effects
# (each [effect, aura, misc] or None; values come from the design's ranks),
# and the forms it needs. "cost" overrides the design's (percent of base
# mana). Most behave by name in SpellswordAbilities; the rows carry their
# numbers, costs, cooldowns, ranges and what the rest of the game reads.
ABILITY = {
    "Arcane Strike": {"school": "arcane", "target": TARGET_ENEMY, "range": 5, "effects": [[EFFECT_SCHOOL_DAMAGE, 0, 0]], "gcd": True},
    "Flame Edge": {"school": "fire", "edge": True, "duration": 3600},
    "Spark": {"school": "arcane", "target": TARGET_ENEMY, "range": 20, "effects": [[EFFECT_SCHOOL_DAMAGE, 0, 0]], "gcd": True},
    "Release": {"school": "arcane", "target": TARGET_SELF, "range": 20, "effects": [[EFFECT_DUMMY, 0, 0], [EFFECT_DUMMY, 0, 0], [EFFECT_DUMMY, 0, 0]], "extra": 3, "gcd": True},
    "Bladesong Form": {"form": FORM_BLADESONG, "duration": -1},
    "Wardweave Form": {"form": FORM_WARDWEAVE, "duration": -1},
    "Frost Edge": {"school": "frost", "edge": True, "duration": 3600},
    "Storm Edge": {"school": "nature", "edge": True, "duration": 3600},
    "Warding Edge": {"school": "arcane", "edge": True, "duration": 3600},
    "Runic Ward": {"school": "arcane", "duration": 30, "effects": [[EFFECT_APPLY_AURA, AURA_SCHOOL_ABSORB, SCHOOLS_ALL]], "gcd": True},
    "Phase Step": {"school": "arcane", "target": TARGET_ENEMY, "range": 20, "min_range": 8, "duration": 5, "effects": [[EFFECT_APPLY_AURA, AURA_DUMMY, 0]], "gcd": True},
    "Severing Sigil": {"school": "arcane", "target": TARGET_ENEMY, "range": 5, "duration": 4, "effects": [[EFFECT_INTERRUPT, 0, 0]], "gcd": True},
    "Mark of Challenge": {"school": "arcane", "target": TARGET_ENEMY, "range": 20, "duration": 3, "effects": [[EFFECT_ATTACK_ME, 0, 0], [EFFECT_APPLY_AURA, AURA_MOD_TAUNT, 0]]},
    "Mirror Guard": {"school": "arcane", "duration": 5, "effects": [[EFFECT_APPLY_AURA, AURA_MOD_PARRY, 0, 50], [EFFECT_APPLY_AURA, AURA_DUMMY, 0]]},
    "Arc Cleave": {"school": "arcane", "target": TARGET_ENEMY, "range": 5, "radius": 8, "effects": [[EFFECT_DUMMY, 0, 0]], "gcd": True},
    "Sap Edge": {"school": "arcane", "duration": 15, "effects": [[EFFECT_APPLY_AURA, AURA_DUMMY, 0, 20]]},
    "Binding Glyph": {"school": "arcane", "target": TARGET_ENEMY, "range": 30, "duration": 20, "effects": [[EFFECT_DUMMY, 0, 0, 3]], "gcd": True},
    "Hurl Blade": {"school": "physical", "target": TARGET_ENEMY, "range": 25, "effects": [[EFFECT_WEAPON_DAMAGE, 0, 0]], "gcd": True},
    "Challenging Glyph": {"school": "arcane", "radius": 10, "duration": 6, "effects": [[EFFECT_APPLY_AURA, AURA_MOD_TAUNT, 0]]},
    "Arcane Surge": {"school": "arcane", "duration": 15, "effects": [[EFFECT_APPLY_AURA, AURA_MOD_DAMAGE_PERCENT_DONE, SCHOOLS_ALL, 20]]},
    "Spell Shatter": {"school": "arcane", "target": TARGET_ENEMY, "range": 5, "effects": [[EFFECT_DISPEL, 0, 1, 1]], "gcd": True},
    "Last Sigil": {"school": "arcane", "duration": 8, "effects": [[EFFECT_APPLY_AURA, AURA_MOD_DAMAGE_PERCENT_TAKEN, SCHOOLS_ALL, -50]]},
    "Glyph Storm": {"school": "arcane", "radius": 10, "duration": 6, "channel": True, "effects": [[EFFECT_DUMMY, 0, 0]], "gcd": True},
}
# Talent abilities: their own rows (cost %, cooldown s, cast, range, effects).
TALENT_ABILITY = {
    "Sigil Flurry": {"cost": 15, "cooldown": 20, "target": TARGET_ENEMY, "range": 5, "school": "physical", "effects": [[EFFECT_DUMMY, 0, 0, 60]], "gcd": True},
    "Reprisal": {"cost": 5, "cooldown": 6, "target": TARGET_ENEMY, "range": 5, "school": "physical", "effects": [[EFFECT_DUMMY, 0, 0, 2]], "gcd": True},
    "Aegis of Runes": {"cost": 0, "cooldown": 60, "school": "arcane", "duration": 10, "effects": [[EFFECT_APPLY_AURA, AURA_SCHOOL_ABSORB, SCHOOLS_ALL, 0]]},
    "Arcane Lance": {"cost": 15, "cooldown": 0, "cast": "2 sec", "target": TARGET_ENEMY, "range": 30, "school": "arcane", "effects": [[EFFECT_SCHOOL_DAMAGE, 0, 0, 0]], "gcd": True, "scale": 3.0},
    "Overload": {"cost": 0, "cooldown": 60, "school": "arcane", "duration": 30, "effects": [[EFFECT_APPLY_AURA, AURA_DUMMY, 0, 5]]},
    "Thousand Cuts": {"cost": 25, "cooldown": 60, "school": "physical", "radius": 8, "duration": 6, "effects": [[EFFECT_APPLY_AURA, AURA_DUMMY, 0, 100]], "gcd": True},
    "Bastion of Glyphs": {"cost": 0, "cooldown": 120, "school": "arcane", "duration": 12, "effects": [[EFFECT_APPLY_AURA, AURA_SCHOOL_ABSORB, SCHOOLS_ALL, 0]]},
    "Arc of Ruin": {"cost": 25, "cooldown": 60, "cast": "2.5 sec", "target": TARGET_ENEMY, "range": 20, "radius": 20, "school": "arcane", "effects": [[EFFECT_SCHOOL_DAMAGE, 0, 0, 0]], "gcd": True, "scale": 4.0},
}
# Passive talents: each effect [aura, misc, value index into the design's
# values (or a fixed number with "fixed"), mask names for spell modifiers].
# "dummy" talents are read by name in SpellswordAbilities.
TALENT_PASSIVE = {
    "Keen Edges": [[AURA_MOD_CRIT, 0, 0]],
    "Honed Sigils": "dummy",
    "Quick Draw": [[AURA_FLAT, OP_COOLDOWN, 0, ["Arcane Strike"], -1000]],
    "Resonant Steel": "dummy",
    "Bladesong Cadence": [[AURA_MOD_MELEE_HASTE, 0, 0, None, 1, STANCE_BLADESONG]],
    "Searing Edge": "dummy",
    "Biting Frost": "dummy",
    "Blade Mastery": [[AURA_MOD_DAMAGE_PERCENT_DONE, 1, 0, None, 1, 0, SWORDS]],
    "Overflow": "dummy",
    "Twin Edge": "dummy",
    "Stormcaller": "dummy",
    "Duelist's Footing": [[AURA_FLAT, OP_COOLDOWN, 0, ["Phase Step"], -1000]],
    "Spellsteel Fury": "dummy",
    "Momentum": "dummy",
    "Woven Mail": [[AURA_MOD_BASE_RESISTANCE_PCT, 1, 0]],
    "Steady Mind": "dummy",
    "Parrying Sigils": [[AURA_MOD_PARRY, 0, 0]],
    "Thick Wards": [[AURA_PCT, OP_ALL_EFFECTS, 0, ["Runic Ward"]]],
    "Commanding Glyphs": [[AURA_FLAT, OP_COOLDOWN, 0, ["Mark of Challenge"], -1000]],
    "Hardened Spirit": [[AURA_MOD_TOTAL_STAT_PCT, 2, 0]],
    "Spell Turning": [[AURA_FLAT, OP_COOLDOWN, 0, ["Mirror Guard"], -1000]],
    "Bulwark Weave": [[AURA_PCT, OP_ALL_EFFECTS, 0, ["Warding Edge"]], [AURA_DUMMY, 0, 1]],
    "Unyielding": "dummy",
    "Steadfast Glyphs": [[AURA_CONTROL_DURATION_PCT, 0, 0]],
    "Glyph Echo": [[AURA_FLAT, OP_COOLDOWN, 0, ["Challenging Glyph"], -60000]],
    "Runic Retaliation": "dummy",
    "Rooted Stance": [[AURA_CRIT_DAMAGE_TAKEN_PCT, 0, 0, None, 1, STANCE_WARDWEAVE]],
    "Arcane Insight": [[AURA_MOD_SPELL_CRIT, SCHOOLS_MAGIC, 0]],
    "Focused Study": [[AURA_MOD_TOTAL_STAT_PCT, 3, 0]],
    "Quickened Spark": [[AURA_FLAT, OP_CASTING_TIME, 0, ["Spark"], -1000]],
    "Mana Edge": [[AURA_FLAT, OP_COOLDOWN, 0, ["Sap Edge"], -1000]],
    "Far Reach": [[AURA_FLAT, OP_RANGE, 0, ["Spark", "Hurl Blade", "Release"]]],
    "Clear Mind": [[AURA_PCT, OP_COST, 0, "all", -1]],
    "Silencing Sigil": "dummy",
    "Empowered Release": [[AURA_PCT, OP_DAMAGE, 0, ["Release"]]],
    "Warding Mana": [[AURA_DUMMY, 0, 0, None, 1, STANCE_BLADESONG]],
    "Arcane Momentum": "dummy",
    "Glyph Mastery": [[AURA_DUMMY, 0, 0], [AURA_FLAT, OP_COOLDOWN, 1, ["Glyph Storm"], -1000]],
    "Spellweaver's Haste": [[AURA_MOD_MELEE_HASTE, 0, 0], [AURA_PCT, OP_CASTING_TIME, 0, "all", -1]],
    "Resonant Surge": "dummy",
}
# Spells the abilities put on others or themselves, not trained: their names
# show in the buff bars. [name, school, duration s, effects, stacks].
HELPERS = [
    ["Searing Brand", "fire", 4, [[EFFECT_APPLY_AURA, AURA_PERIODIC_DAMAGE, 0, 1, 2000]], 0],
    ["Rime Chill", "frost", 4, [[EFFECT_APPLY_AURA, AURA_MOD_DECREASE_SPEED, 0, -30]], 0],
    ["Rime Lance Hold", "frost", 5, [[EFFECT_APPLY_AURA, AURA_MOD_ROOT, 0, 0]], 0],
    ["Ward of the Edge", "arcane", 30, [[EFFECT_APPLY_AURA, AURA_SCHOOL_ABSORB, SCHOOLS_ALL, 1]], 5],
    ["Bulwark of Runes", "arcane", 15, [[EFFECT_APPLY_AURA, AURA_SCHOOL_ABSORB, SCHOOLS_ALL, 1]], 0],
    ["Glyph Binding", "arcane", 4, [[EFFECT_APPLY_AURA, AURA_MOD_ROOT, 0, 0]], 0],
    ["Sigil Silence", "arcane", 2, [[EFFECT_APPLY_AURA, AURA_MOD_SILENCE, 0, 0]], 0],
    ["Unhinging Daze", "arcane", 2, [[EFFECT_APPLY_AURA, AURA_MOD_DECREASE_SPEED, 0, -50]], 0],
    ["Wall of Wards", "arcane", 12, [[EFFECT_APPLY_AURA, AURA_DUMMY, 0, 30]], 0],
    ["Whirling Steel", "physical", 6, [[EFFECT_APPLY_AURA, AURA_MOD_DECREASE_SPEED, 0, -50]], 0],
    ["Bladesong", "physical", -1, [[EFFECT_APPLY_AURA, AURA_MOD_DAMAGE_PERCENT_DONE, SCHOOLS_ALL, 10]], 0],
    ["Wardweave", "arcane", -1, [[EFFECT_APPLY_AURA, AURA_MOD_THREAT, SCHOOLS_ALL, 45], [EFFECT_APPLY_AURA, AURA_MOD_DAMAGE_PERCENT_TAKEN, SCHOOLS_ALL, -10], [EFFECT_APPLY_AURA, AURA_MOD_DAMAGE_PERCENT_DONE, SCHOOLS_ALL, -10]], 0],
]
# Form passives (SPELL_LINKS): form -> its passive helper.
FORM_PASSIVES = {"Bladesong Form": "Bladesong", "Wardweave Form": "Wardweave"}
# Trainer: the class quest at 10 gives Wardweave Form free; Mail at 40.
QUEST_SPELLS = {"Wardweave Form": 10}
START = ["Arcane Strike", "Flame Edge"]
# Talent trees' columns and the order the window shows them.
BOOK_TAB = {"Strike": 0, "Edge": 0, "Form": -1, "Spell": 2, "Defence": 1, "Utility": -1}
FORM_TAB = {"Bladesong Form": 0, "Wardweave Form": 1}


def fill(text, values):
    """The design's text with a rank's values for {0}, {1}..."""
    for i, value in enumerate(values):
        shown = ("%g" % value) if isinstance(value, (int, float)) else str(value)
        text = text.replace("{%d}" % i, shown)
    return text


HELPER_ICON = {
    "Searing Brand": "burn", "Rime Chill": "frost", "Rime Lance Hold": "frost", "Ward of the Edge": "aegis",
    "Bulwark of Runes": "ward", "Glyph Binding": "ground", "Sigil Silence": "hex", "Unhinging Daze": "stun",
    "Wall of Wards": "presence_hallowed", "Whirling Steel": "cyclone", "Bladesong": "stance_fury", "Wardweave": "stance_bastion",
}
HELPER_TEXT = {
    "Searing Brand": "Burning.",
    "Rime Chill": "Movement slowed.",
    "Rime Lance Hold": "Rooted in place by frost.",
    "Ward of the Edge": "Absorbs damage. Builds with each hit of your Warding Edge.",
    "Bulwark of Runes": "Absorbs damage.",
    "Glyph Binding": "Rooted in place by a glyph.",
    "Sigil Silence": "Silenced.",
    "Unhinging Daze": "Dazed.",
    "Wall of Wards": "Takes a share of nearby allies' damage.",
    "Whirling Steel": "Whirling: moving at half speed.",
    "Bladesong": "Bladesong Form: 10% more damage.",
    "Wardweave": "Wardweave Form: more threat, less damage taken and dealt.",
}


def blank(spell_id, name, rank_text=""):
    row = {
        "Id": spell_id, "SpellName": name, "Rank1": rank_text, "School": 0, "Category": 0, "Dispel": 0, "Mechanic": 0,
        "Attributes": 0, "AttributesEx": 0, "AttributesEx2": 0, "AttributesEx3": 0, "Targets": 0,
        "CastingTimeIndex": 1, "RecoveryTime": 0, "CategoryRecoveryTime": 0, "StartRecoveryCategory": 0,
        "StartRecoveryTime": 0, "InterruptFlags": 0, "AuraInterruptFlags": 0, "ProcFlags": 0, "ProcChance": 101,
        "ProcCharges": 0, "MaxLevel": 0, "BaseLevel": 1, "SpellLevel": 1, "DurationIndex": 0, "PowerType": 0,
        "ManaCost": 0, "ManaCostPercentage": 0, "RangeIndex": 1, "Speed": 0, "StackAmount": 0, "DmgClass": 1,
        "SpellFamilyName": FAMILY, "SpellFamilyFlags": 0, "SpellIconID": 0, "PreventionType": 1,
        "TargetCreatureType": 0, "Stances": 0, "EquippedItemClass": -1, "EquippedItemSubClassMask": -1,
        "EquippedItemInventoryTypeMask": 0,
    }
    for i in (1, 2, 3):
        row.update({
            "Effect%d" % i: 0, "EffectDieSides%d" % i: 0, "EffectBaseDice%d" % i: 0, "EffectDicePerLevel%d" % i: 0,
            "EffectRealPointsPerLevel%d" % i: 0, "EffectBasePoints%d" % i: 0, "EffectMechanic%d" % i: 0,
            "EffectImplicitTargetA%d" % i: 0, "EffectImplicitTargetB%d" % i: 0, "EffectRadiusIndex%d" % i: 0,
            "EffectApplyAuraName%d" % i: 0, "EffectAmplitude%d" % i: 0, "EffectMiscValue%d" % i: 0,
            "EffectTriggerSpell%d" % i: 0, "EffectMultipleValue%d" % i: 0, "DmgMultiplier%d" % i: 1,
            "EffectItemType%d" % i: 0,
        })
    return row


def set_effect(row, i, kind, aura, misc, value, target, mask=0, amplitude=0):
    """Effect i (1-3): `value` exactly (base points value - 1, one die side)."""
    row["Effect%d" % i] = kind
    row["EffectApplyAuraName%d" % i] = aura
    row["EffectMiscValue%d" % i] = misc
    row["EffectBasePoints%d" % i] = int(round(value)) - 1
    row["EffectBaseDice%d" % i] = 1
    row["EffectDieSides%d" % i] = 1
    row["EffectImplicitTargetA%d" % i] = target
    row["EffectItemType%d" % i] = mask
    row["EffectAmplitude%d" % i] = amplitude


def percent(text):
    return int(text.split("%")[0]) if "%" in text else 0


def seconds(text):
    if text.startswith("None"):
        return 0
    number = float(text.split()[0])
    return number * 60 if "min" in text.split()[1] else number


def mask_of(names):
    if names == "all":
        return ALL_SPELLS
    return sum(FLAG[n] for n in names)


def build():
    design = json.load(open(os.path.join(ROOT, "docs", "class_designs", "spellsword.json"), encoding="utf8"))
    spells, chains, trainer, book_tabs, links = {}, {}, [], {}, {}
    next_id = [900000]
    by_name = {}

    def new_id():
        next_id[0] += 1
        return next_id[0]

    # Abilities, a row per rank.
    for ability in design["abilities"]:
        name = ability["name"]
        spec = ABILITY[name]
        cost = percent(ability["cost"])
        cooldown = seconds(ability["cooldown"].split(" (")[0])
        cast = ability["cast"]
        ids = []
        for rank_index, (level, values) in enumerate(ability["ranks"]):
            spell_id = new_id()
            row = blank(spell_id, name, "Rank %d" % (rank_index + 1) if len(ability["ranks"]) > 1 else "")
            row["School"] = SCHOOL[spec.get("school", "arcane")]
            row["BaseLevel"] = row["SpellLevel"] = level
            row["ManaCostPercentage"] = cost
            row["RecoveryTime"] = int(cooldown * 1000)
            row["StartRecoveryTime"] = 1500 if spec.get("gcd") else 0
            row["CastingTimeIndex"] = CAST.get(cast, 1)
            row["RangeIndex"] = 902 if spec.get("min_range") else RANGE[spec.get("range", 0)]
            row["SpellFamilyFlags"] = FLAG[name]
            row["DurationIndex"] = DURATION[spec.get("duration", 0)]
            target = spec.get("target", TARGET_SELF)
            if spec.get("channel"):
                row["AttributesEx"] |= ATTR_EX_CHANNELED
            if spec.get("form"):
                set_effect(row, 1, EFFECT_APPLY_AURA, AURA_MOD_SHAPESHIFT, spec["form"], 0, TARGET_SELF)
                row["Attributes"] |= 0x10000  # can't be cancelled by moving, as stances
            elif spec.get("edge"):
                set_effect(row, 1, EFFECT_APPLY_AURA, AURA_DUMMY, 0, values[0] if values else 0, TARGET_SELF)
            else:
                for i, effect in enumerate(spec.get("effects", [])):
                    value = values[i] if i < len(values) else (effect[3] if len(effect) > 3 else 0)
                    set_effect(row, i + 1, effect[0], effect[1], effect[2], value, target)
                if spec.get("extra") is not None and len(values) > spec["extra"]:
                    row["ExtraValue"] = values[spec["extra"]]
            if spec.get("radius"):
                row["EffectRadiusIndex1"] = {8: 14, 10: 13, 20: 9}[spec["radius"]]
            row["Description"] = fill(ability["text"], values)
            row["Icon"] = ability["icon"]
            spells[str(spell_id)] = row
            chains[str(spell_id)] = {"prev": ids[-1] if ids else 0, "first": ids[0] if ids else spell_id, "rank": rank_index + 1}
            ids.append(spell_id)
            entry = {"teach": spell_id, "spells": [spell_id], "cost": 0, "level": level}
            if name in QUEST_SPELLS and rank_index == 0:
                entry["quest"] = True
            trainer.append(entry)
            tab = FORM_TAB.get(name, BOOK_TAB[ability["category"]])
            book_tabs[str(spell_id)] = tab
        by_name[name] = ids

    # Helper spells, then the forms' passives.
    helper_ids = {}
    for name, school, duration, effects, stacks in HELPERS:
        spell_id = new_id()
        row = blank(spell_id, name)
        row["School"] = SCHOOL[school]
        row["DurationIndex"] = DURATION[duration]
        row["StackAmount"] = stacks
        row["SpellFamilyFlags"] = 0
        for i, effect in enumerate(effects):
            set_effect(row, i + 1, effect[0], effect[1], effect[2], effect[3], TARGET_SELF, amplitude=effect[4] if len(effect) > 4 else 0)
        if duration == -1:
            row["Attributes"] |= ATTR_PASSIVE
        row["Description"] = HELPER_TEXT.get(name, "")
        row["Icon"] = HELPER_ICON.get(name, "unknown")
        spells[str(spell_id)] = row
        helper_ids[name] = spell_id
    for form, passive in FORM_PASSIVES.items():
        for spell_id in by_name[form]:
            links[str(spell_id)] = helper_ids[passive]

    # Mail proficiency at 40.
    mail_id = new_id()
    mail = blank(mail_id, "Mail")
    mail["Effect1"] = EFFECT_PROFICIENCY
    mail["EquippedItemClass"] = 4
    mail["EquippedItemSubClassMask"] = 1 << 3
    mail["Attributes"] = ATTR_PASSIVE
    mail["BaseLevel"] = mail["SpellLevel"] = 40
    mail["Description"] = "Lets you wear mail armor."
    mail["Icon"] = "chest_mail_common"
    spells[str(mail_id)] = mail
    trainer.append({"teach": mail_id, "spells": [mail_id], "cost": 0, "level": 40})

    # Talents: trees, and a row per rank.
    trees = []
    talent_id = 9000
    talent_ids = {}
    for order, tree in enumerate(design["trees"]):
        entries = []
        for talent in tree["talents"]:
            talent_id += 1
            talent_ids[talent["name"]] = talent_id
            ranks = []
            for rank in range(talent["ranks"]):
                spell_id = new_id()
                row = blank(spell_id, talent["name"], "Rank %d" % (rank + 1))
                row["BaseLevel"] = row["SpellLevel"] = 10 + (talent["row"] - 1) * 5
                if talent["name"] in TALENT_ABILITY:
                    spec = TALENT_ABILITY[talent["name"]]
                    row["School"] = SCHOOL[spec["school"]]
                    row["ManaCostPercentage"] = spec["cost"]
                    row["RecoveryTime"] = int(spec["cooldown"] * 1000)
                    row["StartRecoveryTime"] = 1500 if spec.get("gcd") else 0
                    row["CastingTimeIndex"] = CAST[spec.get("cast", "Instant")]
                    row["RangeIndex"] = RANGE[spec.get("range", 0)]
                    row["DurationIndex"] = DURATION[spec.get("duration", 0)]
                    row["SpellFamilyFlags"] = FLAG[talent["name"]]
                    if spec.get("channel"):
                        row["AttributesEx"] |= ATTR_EX_CHANNELED
                    if spec.get("radius"):
                        row["EffectRadiusIndex1"] = {8: 14, 10: 13, 20: 9}[spec["radius"]]
                    if spec.get("scale"):
                        row["DmgMultiplier1"] = spec["scale"]
                    target = spec.get("target", TARGET_SELF)
                    for i, effect in enumerate(spec["effects"]):
                        set_effect(row, i + 1, effect[0], effect[1], effect[2], effect[3], target)
                else:
                    row["Attributes"] = ATTR_PASSIVE
                    passive = TALENT_PASSIVE[talent["name"]]
                    if passive == "dummy":
                        passive = [[AURA_DUMMY, 0, i] for i in range(len(talent.get("values", [[1]])))] or [[AURA_DUMMY, 0, 0]]
                    for i, effect in enumerate(passive):
                        aura, misc, value_index = effect[0], effect[1], effect[2]
                        values = talent.get("values", [[1] * talent["ranks"]])
                        value = values[value_index][rank] if value_index < len(values) else 1
                        if isinstance(value, str):
                            value = 1 if value else 0
                        scale = effect[4] if len(effect) > 4 and effect[4] is not None else 1
                        mask = mask_of(effect[3]) if len(effect) > 3 and effect[3] else 0
                        # Times in modifiers are milliseconds; values scale by sign/unit.
                        amount = value * scale if aura in (AURA_FLAT,) else value * (scale if scale != 1 else 1)
                        if aura == AURA_FLAT and misc == OP_RANGE:
                            amount = value
                        set_effect(row, i + 1, EFFECT_APPLY_AURA, aura, misc, amount, TARGET_SELF, mask)
                        if len(effect) > 5 and effect[5]:
                            row["Stances"] = effect[5]
                        if len(effect) > 6 and effect[6]:
                            row["EquippedItemClass"] = ITEM_CLASS_WEAPON
                            row["EquippedItemSubClassMask"] = effect[6]
                    # Percent cost and cast-time cuts are negative.
                    for i in (1, 2, 3):
                        if row["EffectApplyAuraName%d" % i] == AURA_PCT and row["EffectMiscValue%d" % i] in (OP_COST, OP_CASTING_TIME):
                            row["EffectBasePoints%d" % i] = -abs(row["EffectBasePoints%d" % i] + 1) - 1
                values = [v[rank] for v in talent.get("values", [])]
                row["Description"] = fill(talent["text"], values)
                row["Icon"] = talent["icon"]
                spells[str(spell_id)] = row
                if ranks:
                    chains[str(spell_id)] = {"prev": ranks[-1], "first": ranks[0], "rank": rank + 1}
                else:
                    chains[str(spell_id)] = {"prev": 0, "first": spell_id, "rank": 1}
                ranks.append(spell_id)
                book_tabs[str(spell_id)] = order
            prereq = []
            if talent.get("requires"):
                required = next(t for t in tree["talents"] if t["name"] == talent["requires"])
                prereq = [[talent_ids[talent["requires"]], required["ranks"]]]
            entries.append({"id": talent_id, "tier": talent["row"] - 1, "column": talent["col"], "ranks": ranks, "prereq": prereq})
        trees.append({"id": 9100 + order, "name": tree["name"], "order": order, "talents": entries})

    # Trainer costs: the Templar's at each level (classic's class trainers
    # charge the same by level).
    classic = json.load(open(os.path.join(ROOT, "data", "classic", "spells.json"), encoding="utf8"))
    paid = {}
    for entry in classic["trainers"]["paladin"]:
        if entry["cost"] > 0:
            paid[entry["level"]] = max(paid.get(entry["level"], 0), entry["cost"])
    def cost_at(level):
        known = sorted(paid)
        below = [l for l in known if l <= level]
        return paid[below[-1]] if below else 10
    for entry in trainer:
        if not entry.get("quest"):
            entry["cost"] = cost_at(entry["level"])
        if entry["teach"] == mail_id:
            entry["cost"] = 2000

    # Start spells for each race: the first ranks of START, and Parry.
    start = {"%d-%d" % (race, CLASS_ID): [by_name[n][0] for n in START] + [3127] for race in RACES}
    # Player tables: each race's warrior rows plus the Human Templar's
    # difference from the Human Man-at-Arms; health and mana as the Templar's.
    tables = json.load(open(os.path.join(ROOT, "data", "classic", "player_tables.json"), encoding="utf8"))
    paladin, warrior = tables["level_stats"]["1-2"], tables["level_stats"]["1-1"]
    level_stats = {}
    for race in RACES:
        rows = tables["level_stats"]["%d-1" % race]
        level_stats["%d-%d" % (race, CLASS_ID)] = [[rows[l][s] + paladin[l][s] - warrior[l][s] for s in range(5)] for l in range(60)]
    class_stats = {str(CLASS_ID): tables["class_stats"]["2"]}
    # Starting kits: the race's Man-at-Arms kit with a sword and no shield
    # (shields come with Wardweave), and the class's proficiencies.
    kits = json.load(open(os.path.join(ROOT, "data", "classic", "characters.json"), encoding="utf8"))
    characters = {}
    for race in RACES:
        items = [i for i in kits["%d-1" % race]["items"] if i[0] not in (25, 37, 2362, 3111)]
        items.insert(0, [25, 1])
        characters["%d-%d" % (race, CLASS_ID)] = {"items": items, "proficiencies": ["2:7", "2:8", "2:15", "4:0", "4:1", "4:2", "4:6"]}

    out = {
        "class": CLASS_ID,
        "spells": spells, "chains": chains, "trainers": {TRAINER: trainer}, "start_spells": start,
        "talents": {str(CLASS_ID): trees}, "book_tabs": {str(CLASS_ID): book_tabs}, "links": links,
        "level_stats": level_stats, "class_stats": class_stats, "characters": characters,
    }
    os.makedirs(os.path.join(ROOT, "data", "classes"), exist_ok=True)
    path = os.path.join(ROOT, "data", "classes", "spellsword.json")
    json.dump(out, open(path, "w", encoding="utf8", newline="\n"), indent="\t", ensure_ascii=False)
    print("Wrote %s: %d spells, %d trainer entries, %d talents" % (path, len(spells), len(trainer), sum(len(t["talents"]) for t in trees)))
    return out


if __name__ == "__main__":
    build()
