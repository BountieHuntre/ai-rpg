# Classic WoW data

`player_tables.json` holds patch 1.12 player tables, converted from the
CMaNGOS classic database (`Full_DB/ClassicDB_1_12_1_z2815.sql.gz` in
https://github.com/cmangos/classic-db):

- `level_stats["race-class"]`: Strength, Agility, Stamina, Intellect, Spirit
  for levels 1 to 60 (`player_levelstats`)
- `class_stats["class"]`: base health and base mana for levels 1 to 60
  (`player_classlevelstats`)
- `xp_to_next`: XP needed to leave each level 1 to 60 (`player_xp_for_level`)

Also:

- `creatures.json`: `creature_template` rows for the creatures in the game
- `loot_tables.json`: their `creature_loot_template` rows and every
  `reference_loot_template` they use
- `items.json`: `item_template` rows for everything those tables can drop, plus
  the starting gear

- `spells.json`: `spell_template` rows for the Paladin trainer list (Brother
  Wilhelm, 927), the Human Paladin starting spells, and every spell those
  trigger (seal procs, judgements, Holy Light's heal), plus `spell_chain`
  ranks, `spell_bonus_data` coefficients and the trainer list itself.

Spells refer to client DBC tables for cast time, duration, range and radius.
Those aren't in the database, so `scripts/spells/spell_db.gd` holds the values
for the indexes Paladin spells use, matched against classic spell tooltips.

Names are replaced with the game's own by `tools/classic_db/renames.py`;
the numbers stay classic.

Regenerate everything with `tools/classic_db/extract.py`. To add creatures, add
their entries to `CREATURES` in that script and rerun it.

Race ids: 1 Human, 2 Orc, 3 Dwarf, 4 Night Elf, 5 Undead, 6 Tauren, 7 Gnome, 8 Troll.
Class ids: 1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue, 5 Priest, 7 Shaman, 8 Mage,
9 Warlock, 11 Druid.

Formulas in `scripts/stats/` follow the CMaNGOS classic and vmangos server code
(`StatSystem.cpp`, `Player.cpp`, `Unit.cpp`, `Formulas.h`).

`quests.json` holds the rules of the classic quests the game's quests are
built on (quest_template: level, minimum level, previous quest, kill and item
objectives, reward items and choices, money, RewMoneyMaxLevel). The game's
titles, text and quest givers are its own, in `data/quests.json`. Quest XP
follows Quest::XPValue, and quest-only drops (negative loot chances) only roll
while a quest needs the item, as in CMaNGOS.

`spells.json` also carries `procs`: procs per minute and cooldowns from
spell_proc_event (Seal of Justice 5, Light and Wisdom 20, Command 7, each with
a 3 s cooldown), used as Unit::GetPPMProcChance does (ppm x swing time / 60).
Judgement of Light and Wisdom's per-rank heal and mana spells, and Holy
Shock's damage and heal spells, are mapped in `extract.py` from the CMaNGOS
proc and effect handlers, since the data doesn't link them.

`factions.json` is the client's FactionTemplate table and each race's template
(ChrRaces), from wago.tools' Classic Era exports via
`tools/classic_db/fetch_client_tables.py`. `ClassicData` follows
FactionTemplateEntry::IsHostileTo and IsFriendlyTo in CMaNGOS: a creature
attacks on sight only if its template is hostile to the player's and its
creature_template ExtraFlags lack CREATURE_EXTRA_FLAG_NO_AGGRO_ON_SIGHT (0x2).

The CMaNGOS projects are GPL-licensed. Check the licensing of this data before
shipping the game commercially.
