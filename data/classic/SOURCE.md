# Classic WoW data

`player_tables.json` holds patch 1.12 player tables, converted from the
CMaNGOS classic database (`Full_DB/ClassicDB_1_12_1_z2815.sql.gz` in
https://github.com/cmangos/classic-db):

- `level_stats["race-class"]`: Strength, Agility, Stamina, Intellect, Spirit
  for levels 1 to 60 (`player_levelstats`)
- `class_stats["class"]`: base health and base mana for levels 1 to 60
  (`player_classlevelstats`)
- `xp_to_next`: XP needed to leave each level 1 to 60 (`player_xp_for_level`)

Race ids: 1 Human, 2 Orc, 3 Dwarf, 4 Night Elf, 5 Undead, 6 Tauren, 7 Gnome, 8 Troll.
Class ids: 1 Warrior, 2 Paladin, 3 Hunter, 4 Rogue, 5 Priest, 7 Shaman, 8 Mage,
9 Warlock, 11 Druid.

Formulas in `scripts/stats/` follow the CMaNGOS classic and vmangos server code
(`StatSystem.cpp`, `Player.cpp`, `Unit.cpp`, `Formulas.h`).

The CMaNGOS projects are GPL-licensed. Check the licensing of this data before
shipping the game commercially.
