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
# Kobold Geomancer, Kobold Miner and Defias Cutpurse (5 to 8) cast spells.
# Then Harrowfield's, from the rest of Elwynn Forest (levels 5 to 12): Mangy
# Wolf, Forest Spider, Murloc, Murloc Streamrunner, Rockhide Boar, Porcine
# Entourage, Gray Forest Wolf, Young Forest Bear, Defias Bandit, Goldtooth,
# Mine Spider, Riverpaw Runt, Defias Rogue Wizard, Princess, Prowler, Murloc
# Lurker, Murloc Forager, Riverpaw Outrunner, Hogger and Riverpaw Gnoll.
CREATURES = [299, 6, 69, 257, 80, 38, 113, 475, 476, 40, 94,
             525, 30, 285, 735, 524, 390, 1922, 822, 116, 327, 43, 97, 474, 330, 118, 732, 46, 478, 448, 117,
             473,
             # Kareth: Emberhollow (Valley of Trials): Mottled Boar, Scorpid
             # Worker, Vile Familiar, Felstalker, Sarkoth, Yarrog Baneshadow.
             3098, 3124, 3101, 3102, 3281, 3183,
             # The Redsand Coast (Durotar): boars, surf crawlers, makrura,
             # scorpids, the Razormane quilboar, the Dustwind harpies, the
             # Kolkar, the tiger, raptors, Kul Tiras sailors and marines,
             # thunder lizards, the Burning Blade, Zalazane's trolls, the
             # crocolisk, and their named ones (Lieutenant Benedict, Fizzle
             # Darkstorm, Gazz'uz, Zalazane) and rares (Geolord Mottle,
             # Captain Flat Tusk, Warlord Kolkanis, Watch Commander Zalaphil,
             # Felweaver Scornn, Death Flayer).
             3099, 3100, 3106, 3107, 3108, 3103, 3104, 3105, 3141, 3125, 3126, 3127,
             3111, 3112, 3113, 3114, 3115, 3116, 3117, 3118, 3119, 3120, 3121, 3122, 3123,
             3128, 3129, 3192, 3130, 3131, 3195, 3196, 3197, 3198, 3199, 3203, 3204, 3205,
             3206, 3207, 3110, 5826, 5824, 5808, 5809, 5822, 5823,
             # Aldmark's north. Gravesend (Deathknell): the zombies, the
             # Rattlecage skeletons, scavengers, duskbats, Night Web spiders,
             # the Scarlet converts and initiates and Meven Korgal.
             1501, 1502, 1890, 1508, 1509, 1512, 1513, 1504, 1505, 1688, 1506, 1507, 1667,
             # Duskmoor Glades (Tirisfal Glades): the rotting dead, darkhounds,
             # duskbats, spiders, the mills' skeletons, the Rot Hide gnolls and
             # Maggot Eye, the Scarlet Crusade and its captains, the Vile Fin
             # murlocs, the haunted Agamand family and their crypt, the
             # farmers, and the rares (Bayne, Ressan the Needler, Muad).
             1525, 1526, 1547, 1548, 1549, 1553, 1554, 1555, 1520, 1522, 1523, 1674, 1675, 1941, 1753,
             1535, 1536, 1537, 1538, 1539, 1540, 1662, 1664, 1665, 1660, 1543, 1544, 1545, 1909, 1957, 1958,
             1529, 1532, 1534, 1530, 1658, 1654, 1655, 1656, 1657, 1934, 1935, 1936, 10356, 10357, 1910, 1531,
             # Kareth's west. Sunfold Camp (Camp Narache): plainstriders,
             # cougars, battleboars and the Bristleback quilboar with their chief.
             2955, 2961, 2966, 2952, 2953, 2954, 3229, 8554,
             # The Tallgrass (Mulgore): prairie wolves, plainstriders, cougars,
             # swoops, the Palemane gnolls, the Windfury harpies, the
             # Bristleback interlopers, the Venture Co. goblins at their
             # derrick, Mazzranache, Ghost Howl and Snagglespear.
             2958, 2959, 2960, 2956, 2957, 3035, 3566, 2969, 2970, 2971, 2949, 2950, 2951, 5786, 2962, 2963,
             3232, 3068, 3056, 2978, 2979, 3051,
             # Aldmark's mountains. Frosthollow (Coldridge Valley): ragged
             # wolves, the Rockjaw troggs and raiders, crag boars, the
             # Frostmane whelps and novices and Grik'nir the Cold.
             705, 704, 707, 724, 706, 946, 708, 808, 1718,
             # Highpeak (Dun Morogh): crag boars, bears, snow leopards, winter
             # wolves, wendigos and their den (Edan the Howler, Old Icebeard,
             # Vagash), the Frostmane trolls and Great Father Arctikus, the
             # leper gnomes and Gibblewilt, the Rockjaw troggs of the quarry
             # and Hammerspine, Mangeclaw, Timber and Bjarn.
             1125, 1126, 1127, 1128, 1196, 1199, 1201, 1131, 1138, 1133, 1132, 1134, 1135, 1137, 1271, 1388,
             1397, 1120, 1121, 1123, 1122, 1124, 1260, 1211, 8503, 1115, 1116, 1117, 1118, 1119, 1961, 1689, 1130,
             # Kareth's north-west. Mossglen (Shadowglen): young nightsabers and
             # thistle boars, the grells and Webwood spiders, Githyiss the Vile.
             1984, 2031, 1985, 1988, 2032, 1986, 1989, 1994,
             # Eldergrove Isle (Teldrassil): owls, Webwood spiders, sprites and
             # grells with Lord Melenas, the Gnarlpine furbolgs (Ferocitas,
             # Ursal the Mauler), timberlings and Oakenscowl, nightsabers, the
             # Bloodfeather harpies, and the rares (Uruson, Grimmaw,
             # Duskstalker, Threggil, Fury Shelda).
             1995, 1996, 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2038, 2006, 2007, 2008, 2009,
             2010, 2011, 2012, 2013, 2014, 2152, 7235, 7234, 2039, 2022, 2025, 2027, 2029, 2030, 2166, 2042,
             2043, 2033, 2034, 14428, 14429, 14430, 14432, 2015, 2017, 2018, 2019, 2020, 2021, 14431,
             # For quests with items to use: the Lazy Peons of Emberhollow,
             # Samuel Fipps in Gravesend, Rageclaw in the Thornbarrow Den,
             # Mist (escorted) and Blackmoss the Fetid (the Moss-twined Heart).
             10556, 1919, 7318, 3568, 3535]
# Respawn time and wander distance for creatures the dump spawns only through
# spawn groups (no plain creature rows): classic's usual 5 minutes and 5 yards.
DEFAULT_RESPAWN = 300
DEFAULT_WANDER = 5.0
# EventAI (creature_ai_scripts) actions the game runs: say something (1, 44,
# 54: the game writes its own lines), flee for assistance (25), cast a spell
# (11), call for help (39) and set ranged mode (57). Emotes and sounds are
# left out.
AI_ACTIONS = {1, 11, 25, 39, 44, 54, 57}
# Vendors whose stock is exported: Brother Danil (General Supplies) and
# Godric Rothgar (Armorer & Shieldcrafter) from Northshire; Innkeeper Farley
# and Kurran Steele (Cloth & Leather Armor) from Goldshire.
VENDORS = [152, 1213, 295, 74, 54,
           # Emberhollow (Valley of Trials): Duokna (General Goods), Rarc
           # (Armorer & Shieldcrafter), Huklah (Cloth & Leather Armor). The
           # Redsand Coast's Spikewall (Razor Hill): Jark (General Goods),
           # Cutac (Cloth & Leather Armor), Wuark (Armorer & Shieldcrafter),
           # Uhgar (Weaponsmith) and Innkeeper Grosk.
           3158, 3161, 3160, 3164, 3166, 3167, 3163, 6928,
           # Gravesend (Deathknell): Archibald Kava and Joshua Kien.
           # Gallowfield (Brill): Mrs. Winters, Eliza Callen, Abigail Shiel
           # (Trade Supplies: the Coarse Thread of The Chill of Death) and
           # Innkeeper Renee. Sunfold Camp (Camp Narache): Kawnie Softbreeze. Longhorn
           # Village (Bloodhoof Village): Moorat Longstride, Mahnott Roughwound
           # and Innkeeper Kauth.
           2113, 2115, 2134, 2137, 2118, 5688, 3072, 3076, 3077, 6747,
           # Frosthollow (Anvilmar): Adlin Pridedrift, Grundel Harkin, Rybrad
           # Coldbank and Durnan Furcutter. Highpeak's Kharanos: Innkeeper Belm
           # (Rhapsody Malt), Kreg Bilmn, Boran Ironclink, Grawn Thromwyn and
           # Gamili Frosthide. Mossglen (Shadowglen): Lyrai, Khardan
           # Proudblade, Janna Brightmoon, Freja Nightwing, Andiss and
           # Dellylah. Eldergrove's Dolanaar: Innkeeper Keldamyr, Aldia,
           # Shalomon, Meri Ironweave, Sinda and Brannol Eaglemoon.
           829, 1104, 945, 836, 1247, 1691, 1240, 1273, 1238, 3587, 3588, 3590, 3591, 3592, 6091,
           6736, 3608, 3609, 3613, 3612, 3611]
# Loot added to creatures that classic didn't give it (unlike classic): the
# Red Defias Mask (7997), which every Defias of level 10 and up drops about 2%
# of the time in classic (creature_loot_template: 1.4-2.6%, mostly about 2),
# also drops from Harrowfield's level 8-10 brigands, the Defias Bandit and
# Defias Rogue Wizard, the only helm a low-level character can find.
# creature_template entry -> [(item, chance)].
EXTRA_LOOT = {116: [(7997, 2.0)], 474: [(7997, 2.0)]}

# Quests whose rules (objectives, level, XP, money, rewards, chain) the game's
# own quests are built on. Titles, text and quest givers are the game's own,
# in data/quests.json. From Northshire and Elwynn: A Threat Within, Eagan
# Peltskinner, Wolves Across the Border, Brotherhood of Thieves, Kobold Camp
# Cleanup, Investigate Echo Ridge, Skirmish at Echo Ridge, Kobold Candles and
# Gold Dust Exchange. Then Harrowfield's, from Elwynn Forest: Rest and
# Relaxation and A Fishy Peril (from the vale), Riverpaw Gnoll Bounty, Bounty
# on Murlocs, Protect the Frontier, Red Linen Goods, Princess Must Die!, Lost
# Necklace, Pie for Billy, Back to Billy, Goldtooth, Young Lovers, Speak with
# Gramma, Note to William, Collecting Kelp, The Escape and Wanted: "Hogger".
QUESTS = [783, 5261, 33, 18, 7, 15, 21, 60, 47,
          2158, 40, 11, 46, 52, 83, 88, 85, 86, 84, 87, 106, 111, 107, 112, 114, 176,
          62, 76, 239, 35, 37, 45, 71, 39, 59, 5545, 123, 147,
          # Kareth. Emberhollow's, from the Valley of Trials: The New Horde,
          # Cutting Teeth, Sting of the Scorpid, Galgar's Cactus Apple
          # Surprise, Sarkoth (both), Vile Familiars, Burning Blade Medallion,
          # Report to Sen'jin Village and A Peon's Burden. Left out: Your Place
          # In The World (The New Horde for every Horde race instead) and
          # Welcome!
          787, 788, 789, 4402, 790, 804, 792, 794, 805, 2161,
          # The Redsand Coast's, from Durotar: Vanquish the Betrayers, From
          # The Wreckage...., The Admiral's Orders (its first part), Carry Your
          # Weight, Report to Orgnil, Dark Storms, Margoz, Skull Rock, Burning
          # Shadows, Minshina's Skull, Need for a Cure, Finding the Antidote,
          # Break a Few Eggs, Lost But Not Forgotten, Practical Prey, A Solvent
          # Spirit, Zalazane, Winds in the Desert, Securing the Lines and
          # Encroachment. Left out: those leading to Orgrimmar or the Barrens
          # (Neeru Fireblade, Ak'Zeloth, The Demon Seed, Flawed Power Stone,
          # The Admiral's Orders' second part, Conscript of the Horde,
          # Crossroads Conscription) and the level-60 raptor ones.
          784, 825, 830, 791, 823, 806, 828, 827, 832, 808, 812, 813, 815, 816, 817, 818,
          826, 834, 835, 837,
          # Gravesend's, from Deathknell: Rude Awakening, The Mindless Ones,
          # Rattling the Rattlecages, The Damned, Scavenging Deathknell, Night
          # Web's Hollow, The Scarlet Crusade, The Red Messenger and Vital
          # Intelligence. Left out: the rogue's letter and Welcome!
          363, 364, 3901, 376, 3902, 380, 381, 382, 383,
          # Duskmoor Glades', from Tirisfal Glades: the war with the Scarlet
          # Crusade and Proof of Demise, Graverobbers, Fields of Grief, A
          # Putrid Task, The Mills Overrun, The Haunted Mills, Deaths in the
          # Family, Speak with Sevren, The Family Crypt, The Chill of Death,
          # Wanted: Maggot Eye, Rear Guard Patrol, A New Plague (its first
          # three, the Undead's), Gordo's Task and Doom Weed. Left out: those
          # that lead to the Ossuary or Ashpine Forest, the lich's chain and
          # the level-55 termites.
          427, 370, 371, 372, 374, 358, 365, 404, 426, 362, 354, 355, 408, 375, 398, 356, 367, 368, 369,
          5481, 5482,
          # Sunfold Camp's, from Camp Narache: The Hunt Begins and Continues,
          # A Humble Task, the Rites of the Earthmother and Rite of Strength,
          # The Battleboars, Attack on Camp Narache, Break Sharptusk! and A
          # Task Unfinished.
          747, 750, 752, 753, 755, 757, 763, 780, 781, 3376, 1656,
          # The Tallgrass's, from Mulgore: Dangers of the Windfury, Sharing
          # the Land, Poison Water, Swoop Hunting, Mazzranache, the first two
          # Rites of Vision, The Demon Scarred Cloak, A Sacred Burial and The
          # Hunter's Way. Left out: the
          # Venture Co. chain (from a search of a caravan), Dwarven Digging
          # and those leading to Windspire Mesa or the Steppe.
          743, 745, 748, 761, 766, 767, 771, 770, 833, 861,
          # Frosthollow's, from Coldridge Valley: Dwarven Outfitters, A New
          # Threat, The Boar Hunter, the mail delivery, A Refugee's Quandary,
          # The Troll Cave, The Stolen Journal, Senir's Observations,
          # Scalding Mornbrew Delivery (five minutes, as classic) and Bring Back the Mug
          # and Supplies to Tannok. Left out: Welcome!
          179, 170, 183, 233, 234, 3361, 182, 218, 282, 420, 3364, 3365, 2160,
          # Highpeak's, from Dun Morogh: Tools for Steelgrill, the Evershine
          # chain, Beer Basted Boar Ribs, The Grizzled Den, Protecting the
          # Herd, The Perfect Stout and Shimmer Stout,
          # Operation Recombobulation, the Gol'Bolar quarry's two, Frostmane
          # Hold, The Lost Pilot and A Pilot's Revenge, Tundra MacGrann's
          # Stolen Stash and Ammo for Rumbleshot. Left out: Guarded Thunderbrew
          # Barrel (the guarded barrel's note), The Reports and Stout to Kadrell
          # (to Ironforge and Loch Modan),
          # the level-20 Incendicite and the mount exchanges.
          400, 317, 318, 319, 320, 384, 313, 314, 315, 413, 412, 432, 433, 287, 419, 417, 312, 5541,
          # Mossglen's, from Shadowglen: The Woodland Protector, The Balance
          # of Nature, Webwood Venom and Webwood Egg, A Good Friend, A Friend
          # in Need, Iverron's Antidote (the cure in five minutes, as classic) and
          # Dolanaar Delivery. Left out: Welcome!
          458, 459, 456, 457, 916, 917, 4495, 3519, 3521, 3522, 2159,
          # Eldergrove Isle's, from Teldrassil: Zenn's Bidding and Seek
          # Redemption!, Denalan's Earth, Timberling Seeds and Sprouts, the
          # Gnarlpine Corruption chain (A Troubling Breeze, The Relics of
          # Wakening, Ursal the Mauler), The Emerald Dreamcatcher, The Road to
          # Darnassus, Twisted Hatred, The Sleeping Druid and The Enchanted
          # Glade. Left out: those leading to Darnassus, Ferocitas (a necklace
          # to open) and the fruit and frond (found by chance in classic, from
          # no drop the data has).
          488, 489, 997, 918, 919, 475, 476, 483, 486, 2438, 487, 932, 2541, 937,
          # Quests with items and objects to use, escorts and events: Lazy
          # Peons and Thazz'ril's Pick (Emberhollow); Thwarting Kolkar
          # Aggression (the Redsand Coast); Marla's Last Wish (Gravesend); the
          # Tallgrass's well cleansings and the totem quests between them;
          # Distracting Jarven, Bitter Rivals and Return to Marleth
          # (Highpeak); Tenaron's Summons and the Crown of the Earth phials up
          # to the amethyst (Mossglen and Eldergrove Isle; the older amethyst
          # quest, 934, and the one to Darnassus left out); Druid of the Claw,
          # Mist, The Moss-twined Heart and Planting the Heart (Eldergrove).
          5441, 6394, 786, 6395, 754, 756, 758, 759, 760, 308, 310, 311,
          920, 921, 928, 929, 933, 7383, 2561, 938, 927, 941,
          # The Ranger's taming quests at level 10, each race's own: three
          # Taming the Beast (a taming rod used on a beast of its second
          # zone) and Training the Beast. Dwarves (Highpeak), Wood Elves
          # (Eldergrove Isle), Orcs and Trolls (the Redsand Coast), Hornkin
          # (the Tallgrass).
          6064, 6084, 6085, 6086, 6063, 6101, 6102, 6103, 6062, 6083, 6082, 6081, 6061, 6087, 6088, 6089]
# Game objects exported to gameobjects.json (gameobject_template): quest
# givers and enders (type 2: A half-eaten body, Rolf's corpse) and chests to
# loot (type 3: Bundle of Wood), with their loot and usual respawn time.
GAMEOBJECTS = [55, 56, 176793,
               # Kareth's chests: Cactus Apple, Gnomish Toolbox, Imprisoned
               # Darkspear (Minshina's Skull), Taillasher Eggs, Stolen Supply Sack.
               171938, 3236, 3237, 3240, 3290,
               # Equipment Boxes (Scavenging Deathknell), Tirisfal Pumpkins,
               # Gloom Weed and Doom Weed, the Water Pitchers, the Well Stone
               # and Ambercorn (Rite of Vision).
               164662, 375, 175566, 176753, 337, 2907, 2910, 2912,
               # Felix's Box, Chest and Bucket of Bolts; MacGrann's Meat
               # Locker, the Shimmerweed Baskets, the Ammo Crate and A Dwarven
               # Corpse (The Lost Pilot); Webwood Eggs, Hyacinth Mushrooms and
               # Moonpetal Lilies; Fel Cones, Timberling Sprouts, the four
               # chests of the Relics of Wakening and Tallonkai's Dresser.
               148499, 178084, 178085, 272, 276, 176785, 2059, 4406, 152094, 152095, 1673, 4608,
               2739, 2740, 2741, 2742, 126158,
               # Spell focus objects (type 8): the Tallgrass's three wells and
               # the four moonwells of Crown of the Earth. Objects to use (type
               # 10): the Kolkar attack plans and Marla's Grave. Thazz'ril's
               # Pick (a chest). Quest givers and enders: the guarded and
               # unguarded Thunder Ale barrels and Denalan's Planter.
               2909, 2911, 2913, 19549, 19550, 19551, 19552, 3189, 3190, 3192, 178090, 178087,
               269, 270, 7923]
GO_TYPE_QUESTGIVER = 2
GO_TYPE_CHEST = 3
GO_TYPE_SPELL_FOCUS = 8
GO_TYPE_TRAP = 6
SPELL_EFFECT_SUMMON_OBJECT = 104

# Class trainers whose spell lists are exported. 927 is Brother Wilhelm, Paladin
# Trainer. Priests have racial spells, so their list merges one trainer per race
# (race id: trainer): Brother Joshua (Human), Maxan Anvol (Dwarf), Astarii
# Starseeker (Night Elf), Father Cobb (Undead) and Tai'jin (Troll). Entries that
# not every one of them teaches get a "races" list.
# 913 is Lyria Du Lac, Warrior Trainer. 3039 is Holt Thunderhorn, Hunter
# Trainer (the Ranger's), whose list has every rank.
CLASS_TRAINERS = {"paladin": 927, "priest": {1: 5489, 3: 1226, 4: 4090, 5: 3046, 8: 3706}, "warrior": 913,
                  "hunter": 3039}
# Classic's weapon masters, whose lists the game's one Weapon Master joins
# ("weapons"): Buliwyf Stonehand, Ilyenia Moonfire, Woo Ping, Sayoc,
# Ansekhwa, Archibald, Bixi Wobblebonk and Hanashi. Each entry's "classes" is
# the class mask that may learn it (weapon_skills.json, SkillRaceClassInfo).
WEAPON_MASTERS = [11865, 11866, 11867, 11868, 11869, 11870, 13084, 2704]
# Each class's skill lines in the order of its talent trees (SkillLine ids):
# Arms, Fury, Protection; Holy, Protection, Retribution; Beast Mastery,
# Marksmanship, Survival; Discipline, Holy, Shadow Magic.
CLASS_SKILL_LINES = {1: [26, 256, 257], 2: [594, 267, 184], 3: [50, 163, 51], 5: [613, 56, 78]}
# Classes whose starting spells are exported: the ones with spell code in the game.
SPELL_CLASSES = {1, 2, 3, 5}  # Warrior, Paladin, Hunter, Priest
# Each class's SpellFamilyName: start spells of other families (racials) are left out.
CLASS_SPELL_FAMILIES = {1: 4, 2: 10, 3: 9, 5: 6}
# Spells left out of the game: Feed Pet (pets have no happiness here).
LEFT_OUT_SPELLS = {6991}
# Spells the pet trainer's list still names that classic 1.12 pets never
# learned there: early patches' Pet Aggression and the like, and a GM charm.
PET_TRAINER_LEFT_OUT = {"Pet Aggression", "Pet Hardiness", "Pet Recovery", "Pet Resistance", "Charm (Possess)"}
# The Ranger's pets. Peria Lamenur, Pet Trainer: the abilities a Ranger buys
# to teach (Growl, Great Stamina, Natural Armor, the resistances).
PET_TRAINER = 2878
# Hunter pets' stats by level are pet_levelstats' creature_entry 1
# (Pet::InitStatsForLevel, HUNTER_PET); pet_familystats scales them by family.
HUNTER_PET_STATS = 1
# Pets' XP to the next level is the player's times this (PET_XP_FACTOR).
PET_XP_FACTOR = 0.05
# Hunter pet families (CreatureFamily ids): Wolf, Cat, Spider, Bear, Boar,
# Crocolisk, Carrion Bird, Crab, Gorilla, Raptor, Tallstrider, Scorpid,
# Turtle, Bat, Hyena, Owl and Wind Serpent (the warlock's Imp shares their
# general skill line, so it's named here rather than found by it).
PET_FAMILIES = {1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 20, 21, 24, 25, 26, 27}
# Families' game names (plain words kept).
PET_FAMILY_NAMES = {"Scorpid": "Scorpion", "Tallstrider": "Tallbird", "Crocolisk": "Crocodile", "Carrion Bird": "Carrion Bird"}
# Junk trainer rows: Lyria Du Lac lists Elemental Fury, a creature spell.
SKIP_TRAINER_SPELLS = {877}
# Starting spells worth keeping (the rest are passives and internals).
START_SPELL_EFFECTS = {2, 6, 10, 17, 35, 58, 77}
# Seal of Righteousness procs by rank, from UnitAuraProcHandler.cpp in CMaNGOS.
SEAL_OF_RIGHTEOUSNESS_PROCS = {
    20154: 25742, 21084: 25741, 20287: 25740, 20288: 25739, 20289: 25738,
    20290: 25737, 20291: 25736, 20292: 25735, 20293: 25713,
}
# Holy Light's script effect heals through this spell (SpellEffects.cpp).
HOLY_LIGHT_HEAL = 19968
# Spells classic gives from a class quest, sold free at their level: Defensive
# Stance and Taunt at 10, Berserker Stance at 30; Redemption's first rank at
# 12 (the trainer sells the later ranks, which need it).
QUEST_SPELLS = {"warrior": [[71, 10], [355, 10], [2458, 30]], "paladin": [[7328, 12]]}
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
    # Talents: Deep Wounds' bleed (its dummy effect casts it), and Blessed
    # Recovery's heal per rank (UnitAuraProcHandler.cpp).
    12162: 12721, 27811: 27813, 27815: 27817, 27816: 27818,
    # Ranger: Wyvern Sting's poison when its sleep ends, per rank (SpellAuras.cpp);
    # Spirit Bond's aura on the pet and its owner (spell_pet_auras); Improved
    # Mend Pet's cleanse (its ADD_TARGET_TRIGGER aura).
    19386: 24131, 24132: 24134, 24133: 24135, 19578: 19579, 20895: 24529,
    19572: 24406, 19573: 24406,
}
# The hidden passives every tamed hunter pet has (Pet::LearnPetPassives),
# which the Ranger's pet talents change through spell modifiers on the
# owner (Unleashed Fury, Endurance Training, Thick Hide, Bestial Swiftness,
# Bestial Discipline, Ferocity, Frenzy).
HUNTER_PET_PASSIVES = [8875, 19580, 19581, 19582, 19589, 19591, 20784]
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
    "creature_ai_scripts", "creature_template_classlevelstats", "spell_affect",
    "gameobject_template", "gameobject", "gameobject_loot_template", "npc_vendor_template",
    "pet_levelstats", "pet_familystats",
}
SPELL_FIELDS = [
    "Id", "SpellName", "Rank1", "School", "Category", "Dispel", "Mechanic", "Attributes",
    "AttributesEx", "AttributesEx2", "AttributesEx3", "Targets", "CastingTimeIndex", "RecoveryTime",
    "CategoryRecoveryTime", "StartRecoveryCategory", "StartRecoveryTime", "InterruptFlags",
    "AuraInterruptFlags", "ProcFlags", "ProcChance", "ProcCharges", "MaxLevel", "BaseLevel",
    "SpellLevel", "DurationIndex", "PowerType", "ManaCost", "ManaCostPercentage", "RangeIndex",
    "Speed", "StackAmount", "DmgClass", "SpellFamilyName", "SpellFamilyFlags", "SpellIconID", "PreventionType",
] + [f"{field}{i}" for i in (1, 2, 3) for field in (
    "Effect", "EffectDieSides", "EffectBaseDice", "EffectDicePerLevel", "EffectRealPointsPerLevel",
    "EffectBasePoints", "EffectMechanic", "EffectImplicitTargetA", "EffectImplicitTargetB",
    "EffectRadiusIndex", "EffectApplyAuraName", "EffectAmplitude", "EffectMiscValue",
    "EffectTriggerSpell", "EffectMultipleValue", "DmgMultiplier",
)] + ["TargetCreatureType", "Stances", "EffectItemType1", "EffectItemType2", "EffectItemType3",
     "EquippedItemClass", "EquippedItemSubClassMask", "EquippedItemInventoryTypeMask",
     # The spell focus object it must be cast near (gameobjects.json "focus"),
     # or 0: a moonwell for Crown of the Earth's phials.
     "RequiresSpellFocus"]
SPELL_EFFECT_LEARN = 36
SPELL_EFFECT_DUMMY = 3
SPELL_EFFECT_PROFICIENCY = 60
ITEM_CLASS_CONSUMABLE = 0
# Arrows and shot: the game has no ammo (ranged weapons need none), so these
# are left out of items, vendors, loot and starting kits.
ITEM_CLASS_PROJECTILE = 6
ITEM_SUBCLASS_THROWN = 16
ITEM_SUBCLASS_FOOD = 5
SPELL_AURA_DUMMY = 4
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "data", "classic")
BACKSLASH = chr(92)

CREATURE_FIELDS = [
    "Entry", "Name", "SubName", "MinLevel", "MaxLevel", "MinLevelHealth", "MaxLevelHealth",
    "MinLevelMana", "MaxLevelMana", "Armor", "MinMeleeDmg", "MaxMeleeDmg", "MeleeAttackPower",
    "MeleeBaseAttackTime", "Rank", "CreatureType", "Family", "LootId", "MinLootGold", "MaxLootGold",
    "SpeedWalk", "SpeedRun", "Faction", "ExtraFlags", "UnitClass", "CallForHelp",
    # CreatureTypeFlags 0x1 is tameable by a Ranger; PetSpellDataId names the
    # abilities it knows (CreatureSpellData, pet_families.json "spell_data").
    "CreatureTypeFlags", "PetSpellDataId",
]
ITEM_FIELDS = [
    "entry", "name", "description", "Quality", "class", "subclass", "InventoryType", "ItemLevel",
    "RequiredLevel", "AllowableClass", "stackable", "BuyPrice", "SellPrice", "bonding", "armor",
    "block", "delay", "MaxDurability", "ContainerSlots", "dmg_min1", "dmg_max1", "dmg_type1",
    "dmg_min2", "dmg_max2", "dmg_type2", "BuyCount", "spellid_1", "spelltrigger_1", "spellcharges_1",
    "spellcooldown_1", "spellcategory_1", "spellcategorycooldown_1", "startquest",
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
        creature["Respawn"] = most_common(int(s["spawntimesecsmin"]) for s in spawns) if spawns else DEFAULT_RESPAWN
        creature["Wander"] = most_common(float(s["spawndist"]) if s["MovementType"] == "1" else 0.0 for s in spawns) if spawns else DEFAULT_WANDER
        creature["Events"] = creature_events(db, entry)
    # Creature spell damage scales by the class's base damage at the
    # creature's level over that at the spell's level (Object.cpp,
    # SPELL_ATTR_SCALES_WITH_CREATURE_LEVEL): BaseDamageExp0 by class, level 1 up.
    classes = {str(c["UnitClass"]) for c in creatures.values()}
    class_damage = {}
    for r in sorted(db["creature_template_classlevelstats"], key=lambda r: int(r["Level"])):
        if r["Class"] in classes:
            class_damage.setdefault(r["Class"], []).append(float(r["BaseDamageExp0"]))
    write("creature_class_damage.json", class_damage)
    # A creature's base stats by class and level, level 1 up: health, mana,
    # damage, melee attack power, armor (creature_template_classlevelstats).
    # The dev console's "spawn" scales a creature to any level by these.
    class_stats = {}
    for r in sorted(db["creature_template_classlevelstats"], key=lambda r: int(r["Level"])):
        class_stats.setdefault(r["Class"], []).append([
            int(r["BaseHealthExp0"]), int(r["BaseMana"]), float(r["BaseDamageExp0"]),
            float(r["BaseMeleeAttackPower"]), int(r["BaseArmor"]),
        ])
    write("creature_class_stats.json", class_stats)
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
        } for r in rows if int(r["mincountOrRef"]) < 0 or int(r["item"]) not in ammo]

    ammo = {int(r["entry"]) for r in db["item_template"] if int(r["class"]) == ITEM_CLASS_PROJECTILE}

    with open(os.path.join(OUT_DIR, "start_outfits.json"), encoding="utf8") as f:
        outfits = json.load(f)
    creature_loot, references = {}, {}
    item_ids = {item for outfit in outfits.values() for item in outfit}
    item_ids.update(int(r["itemid"]) for r in db["playercreateinfo_item"])
    item_ids -= ammo
    pending = []
    for creature in creatures.values():
        loot_id = str(creature["LootId"])
        if loot_id != "0" and loot_id in loot_rows:
            creature_loot[loot_id] = loot_entries(loot_rows[loot_id])
            for item, chance in EXTRA_LOOT.get(int(creature["Entry"]), []):
                creature_loot[loot_id].append({"item": item, "chance": chance, "group": 0,
                                               "min_or_ref": 1, "max": 1, "condition": 0})
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
        # Many sell a shared list too (VendorTemplateId, npc_vendor_template),
        # after their own, as CMaNGOS lists both.
        if int(template.get("VendorTemplateId", 0)):
            stock += sorted((r for r in db["npc_vendor_template"] if r["entry"] == template["VendorTemplateId"]), key=lambda r: int(r["slot"]))
        # NpcFlags 0x4000 is UNIT_NPC_FLAG_REPAIR: armorers who repair gear.
        vendors[str(entry)] = {"name": template["Name"], "subname": template["SubName"],
                               "repair": int(template["NpcFlags"]) & 0x4000 != 0,
                               "items": [int(r["item"]) for r in stock if int(r["item"]) not in ammo]}
        item_ids.update(int(r["item"]) for r in stock if int(r["item"]) not in ammo)
    # Game objects: chests' loot comes from gameobject_loot_template by their
    # data1 (the loot id), and their respawn time from their classic spawns.
    object_loot_rows = {}
    for r in db["gameobject_loot_template"]:
        object_loot_rows.setdefault(r["entry"], []).append(r)
    gameobjects, object_loot = {}, {}
    for r in db["gameobject_template"]:
        if int(r["entry"]) not in GAMEOBJECTS:
            continue
        spawns = [g for g in db["gameobject"] if g["id"] == r["entry"]]
        gameobjects[r["entry"]] = {
            "name": r["name"], "type": int(r["type"]), "size": float(r["size"]),
            "loot": int(r["data1"]) if int(r["type"]) == GO_TYPE_CHEST else 0,
            # Spell focus objects (type 8): the focus id spells require
            # (RequiresSpellFocus) and how near it they must be cast.
            **({"focus": int(r["data0"]), "radius": float(r["data1"])} if int(r["type"]) == GO_TYPE_SPELL_FOCUS else {}),
            "respawn": most_common(int(g["spawntimesecsmin"]) for g in spawns) if spawns else DEFAULT_RESPAWN,
        }
        loot_id = r["data1"]
        if int(r["type"]) == GO_TYPE_CHEST and loot_id in object_loot_rows:
            object_loot[loot_id] = loot_entries(object_loot_rows[loot_id])
            item_ids.update(entry["item"] for entry in object_loot[loot_id] if entry["min_or_ref"] >= 0)
    write("loot_tables.json", {"creature": creature_loot, "reference": references, "gameobject": object_loot})
    export_pets(db, creatures)
    quests = export_quests(db)
    # No ammo in the game: quests that gave arrows or shot give nothing else instead.
    for quest in quests.values():
        quest["reward_items"] = [r for r in quest["reward_items"] if r[0] not in ammo]
        quest["reward_choices"] = [r for r in quest["reward_choices"] if r[0] not in ammo]
    for quest in quests.values():
        item_ids.update(item for item, _ in quest["reward_choices"] + quest["reward_items"] + quest["items"])
        if quest["source_item"]:
            item_ids.add(quest["source_item"])
    # Items that start an exported quest when used (The Collector's schedule).
    item_ids.update(int(r["entry"]) for r in db["item_template"] if int(r["startquest"]) in QUESTS)
    write("quests.json", quests)

    items = {r["entry"]: pick(r, ITEM_FIELDS) for r in db["item_template"]
             if int(r["entry"]) in item_ids and int(r["entry"]) not in ammo}
    for item in items.values():
        item["stats"] = [[item.pop(f"stat_type{i}"), item.pop(f"stat_value{i}")] for i in range(1, 11)]
        item["stats"] = [s for s in item["stats"] if s[1] != 0]
        # A thrown weapon is one weapon, not a stack of 200 to throw.
        if int(item["class"]) == 2 and int(item["subclass"]) == ITEM_SUBCLASS_THROWN:
            item["stackable"] = 1
            item["BuyCount"] = 1
    # The game uses its own names, not the classic ones.
    renames.apply(items, creatures, vendors, {}, classic_names(db), gameobjects)
    write("gameobjects.json", gameobjects)
    write("vendors.json", vendors)
    write("creatures.json", creatures)
    write("items.json", items)
    write("characters.json", starting_characters(db, outfits, items, level_stats))
    print(f"{len(creatures)} creatures, {len(creature_loot)} loot tables, {len(references)} references, {len(items)} items, {len(vendors)} vendors")
    item_spells = {int(item["spellid_1"]) for item in items.values() if int(item["spellid_1"]) > 0}
    export_spells(db, item_spells | creature_spells(db) | {s for q in quests.values() for s in q["learns"]})


def export_pets(db, creatures):
    """The Ranger's pets, into pets.json: stats by level (pet_levelstats for
    hunter pets: health, armor, Strength, Agility, Stamina, Intellect,
    Spirit), each family's health, damage and armour modifiers
    (pet_familystats), its abilities (its skill lines' spells) and size, and
    the abilities each exported creature knows (its PetSpellDataId)."""
    with open(os.path.join(OUT_DIR, "pet_families.json"), encoding="utf8") as f:
        client = json.load(f)
    level_stats = [[int(r[k]) for k in ("hp", "armor", "str", "agi", "sta", "inte", "spi")]
                   for r in sorted((r for r in db["pet_levelstats"] if int(r["creature_entry"]) == HUNTER_PET_STATS),
                                   key=lambda r: int(r["level"]))]
    modifiers = {r["family"]: [float(r["healthModifier"]), float(r["damageModifier"]), float(r["armorModifier"])]
                 for r in db["pet_familystats"]}
    spells = {r["Id"]: r for r in db["spell_template"]}
    families = {}
    for family_id, family in client["families"].items():
        if int(family_id) not in PET_FAMILIES:
            continue
        abilities = set()
        for line in family["skill_lines"]:
            abilities.update(s for s in client["abilities"].get(str(line), [])
                             if str(s) in spells and not spells[str(s)]["SpellName"].endswith("(DND)"))
        families[family_id] = {
            "name": PET_FAMILY_NAMES.get(family["name"], family["name"]),
            "abilities": sorted(abilities),
            "modifiers": modifiers.get(family_id, [1.0, 1.0, 1.0]),
            "scale": [family["min_scale"], family["max_scale"]],
        }
    known = {}
    for creature in creatures.values():
        data_id = str(creature.get("PetSpellDataId", 0))
        if data_id != "0" and data_id in client["spell_data"]:
            known[data_id] = client["spell_data"][data_id]
    write("pets.json", {"level_stats": level_stats, "families": families, "spell_data": known,
                        "xp_factor": PET_XP_FACTOR})
    print(f"{len(families)} pet families, {len(level_stats)} pet levels")


def export_quests(db):
    """The rules of each quest in QUESTS, from quest_template."""
    spells = {r["Id"]: r for r in db["spell_template"]}
    quests = {}
    for r in db["quest_template"]:
        if int(r["entry"]) not in QUESTS:
            continue
        def pairs(id_field, count_field, n):
            return [[int(r[f"{id_field}{i}"]), int(r[f"{count_field}{i}"])] for i in range(1, n + 1) if int(r[f"{id_field}{i}"]) > 0]
        quests[r["entry"]] = {
            "level": int(r["QuestLevel"]), "min_level": int(r["MinLevel"]),
            "prev": int(r["PrevQuestId"]), "flags": int(r["QuestFlags"]),
            # Creatures to kill; objects to use and spells to cast on a
            # creature or object (ReqSpellCast) are "objects", below.
            "kills": [[int(r[f"ReqCreatureOrGOId{i}"]), int(r[f"ReqCreatureOrGOCount{i}"])] for i in range(1, 5)
                      if int(r[f"ReqCreatureOrGOId{i}"]) > 0 and int(r[f"ReqSpellCast{i}"]) == 0],
            # [target, count, spell]: a game object (negative id) used, or a
            # creature or object a spell is cast on (Player::CastedCreatureOrGO).
            "objects": [[int(r[f"ReqCreatureOrGOId{i}"]), int(r[f"ReqCreatureOrGOCount{i}"]), int(r[f"ReqSpellCast{i}"])]
                        for i in range(1, 5) if int(r[f"ReqCreatureOrGOId{i}"]) != 0
                        and (int(r[f"ReqCreatureOrGOId{i}"]) < 0 or int(r[f"ReqSpellCast{i}"]) != 0)],
            # LimitTime: seconds to finish it in, or 0.
            "time_limit": int(r["LimitTime"]),
            # SpecialFlags: 1 repeatable, 2 finished by an event (a spell's
            # Quest Complete effect, an escort's end) rather than objectives.
            "special": int(r["SpecialFlags"]),
            "items": pairs("ReqItemId", "ReqItemCount", 4),
            # ReqSourceId: items a quest needs carried to use, not handed in
            # (Samuel's Remains, buried with their own spell): quest drops
            # for it, as Player::HasQuestForItem.
            "sources": pairs("ReqSourceId", "ReqSourceCount", 4),
            "reward_choices": pairs("RewChoiceItemId", "RewChoiceItemCount", 6),
            "reward_items": pairs("RewItemId", "RewItemCount", 4),
            "money": int(r["RewOrReqMoney"]), "money_max_level": int(r["RewMoneyMaxLevel"]),
            "source_item": int(r["SrcItemId"]),
            # RequiredRaces: the races (bits by race id - 1) that may take
            # it, 0 for all (QuestLog.race_allowed); RequiredClasses the
            # same for classes (the Ranger's taming quests).
            "races": int(r["RequiredRaces"]),
            "classes": int(r["RequiredClasses"]),
            # Spells handing it in teaches (RewSpellCast's Learn Spell
            # effects: Tame Beast, Call Pet...), less Feed Pet (no happiness).
            "learns": [int(spells[r["RewSpellCast"]][f"EffectTriggerSpell{i}"]) for i in (1, 2, 3)
                       if r["RewSpellCast"] in spells and int(spells[r["RewSpellCast"]][f"Effect{i}"]) == SPELL_EFFECT_LEARN
                       and int(spells[r["RewSpellCast"]][f"EffectTriggerSpell{i}"]) not in LEFT_OUT_SPELLS],
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
            # Thrown weapons are their own ammo in classic, given 200 at a
            # time; with no ammo one is the weapon, worn in the ranged slot.
            if int(item["class"]) == 2 and int(item["subclass"]) == ITEM_SUBCLASS_THROWN:
                count = 1
            if int(item["class"]) == ITEM_CLASS_CONSUMABLE and int(item["subclass"]) == ITEM_SUBCLASS_FOOD:
                limit = {11: 4, 59: 2}.get(int(item["spellcategory_1"]))
                if limit and int(item["stackable"]) > limit:
                    count = limit
            start_items.append([item_id, count])
        start_items += [[int(r["itemid"]), int(r["amount"])] for r in db["playercreateinfo_item"]
                        if (int(r["race"]), int(r["class"])) == (race, char_class) and str(r["itemid"]) in items]
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
        for spell_id, level in QUEST_SPELLS.get(name, []):
            entries.append({"teach": spell_id, "spells": [spell_id], "cost": 0, "level": level, "quest": True})
            wanted.add(spell_id)
        for spell_id, races in RACIAL_FIRST_RANKS.get(name, []):
            level = int(spells[str(spell_id)]["SpellLevel"])
            entries.append({"teach": spell_id, "spells": [spell_id], "cost": 0, "level": level, "races": races})
            wanted.add(spell_id)
        trainers[name] = sorted(entries, key=lambda e: (e["level"], e["spells"][0]))

    with open(os.path.join(OUT_DIR, "weapon_skills.json"), encoding="utf8") as f:
        weapon_classes = json.load(f)
    weapons = {}
    for master in WEAPON_MASTERS:
        for teach, entry in trainer_entries(master).items():
            entry["classes"] = weapon_classes.get(str(entry["spells"][0]), 0)
            weapons.setdefault(teach, entry)
    for entry in weapons.values():
        wanted.update(entry["spells"])
    trainers["weapons"] = sorted(weapons.values(), key=lambda e: (e["level"], e["spells"][0]))
    # The pet trainer, and every pet family's abilities (pet_families.json,
    # from fetch_client_tables.py): their spells go out with the rest.
    trainers["pet"] = sorted((dict(entry, pet=True) for entry in trainer_entries(PET_TRAINER).values()
                              if spells[str(entry["spells"][0])]["SpellName"] not in PET_TRAINER_LEFT_OUT),
                             key=lambda e: (e["level"], e["spells"][0]))
    for entry in trainers["pet"]:
        wanted.update(entry["spells"])
    with open(os.path.join(OUT_DIR, "pet_families.json"), encoding="utf8") as f:
        pet_families = json.load(f)
    pet_lines = {str(line) for family_id, family in pet_families["families"].items() if int(family_id) in PET_FAMILIES
                 for line in family["skill_lines"]}
    for line in pet_lines:
        wanted.update(s for s in pet_families["abilities"].get(line, [])
                      if str(s) in spells and not spells[str(s)]["SpellName"].endswith("(DND)"))

    # Talent trees (data/classic/talents.json, from fetch_client_tables.py) of
    # the classes with spells: every rank's spell, and the trees renamed.
    with open(os.path.join(OUT_DIR, "talents.json"), encoding="utf8") as f:
        all_talents = json.load(f)
    talents = {}
    for class_id in sorted(SPELL_CLASSES):
        trees = all_talents.get(str(class_id), [])
        for tree in trees:
            for talent in tree["talents"]:
                wanted.update(talent["ranks"])
        talents[str(class_id)] = [dict(tree, name=renames.talent_tree(class_id, tree["name"])) for tree in trees]

    # The spellbook's tabs: each spell's talent tree, by its skill line
    # (skill_lines.json, from SkillLineAbility); spells in none go in General.
    with open(os.path.join(OUT_DIR, "skill_lines.json"), encoding="utf8") as f:
        skill_lines = json.load(f)
    book_tabs = {}
    for class_id, lines in CLASS_SKILL_LINES.items():
        book_tabs[str(class_id)] = {spell: lines.index(line) for spell, line in skill_lines.items() if line in lines}

    start = {}
    for r in db["playercreateinfo_spell"]:
        if int(r["class"]) in SPELL_CLASSES:
            spell = spells.get(r["Spell"])
            if spell and any(int(spell[f"Effect{i}"]) in START_SPELL_EFFECTS for i in (1, 2, 3)) \
                    and int(spell["SpellFamilyName"]) == CLASS_SPELL_FAMILIES[int(r["class"])]:
                start.setdefault(f'{r["race"]}-{r["class"]}', []).append(int(r["Spell"]))
                wanted.add(int(r["Spell"]))

    wanted.update(HUNTER_PET_PASSIVES)
    # Follow triggered spells, seal procs and seal judgements; and the trap
    # objects the Ranger's traps set (Summon Object, 104: gameobject_template
    # type 6, data2 its radius, data3 the spell it fires), their spells too.
    objects = {r["entry"]: r for r in db["gameobject_template"]}
    traps = {}
    pending = list(wanted)
    while pending:
        spell = spells.get(str(pending.pop()))
        if not spell:
            continue
        linked = [int(spell[f"EffectTriggerSpell{i}"]) for i in (1, 2, 3)]
        for i in (1, 2, 3):
            if int(spell[f"Effect{i}"]) == SPELL_EFFECT_SUMMON_OBJECT:
                trap = objects.get(spell[f"EffectMiscValue{i}"])
                if trap and int(trap["type"]) == GO_TYPE_TRAP:
                    traps[str(trap["entry"])] = {"spell": int(trap["data3"]), "radius": float(trap["data2"])}
                    linked.append(int(trap["data3"]))
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

    # Spell modifiers with no mask of their own take it from spell_affect
    # (SpellMgr::LoadSpellAffects in CMaNGOS).
    affects = {(r["entry"], int(r["effectId"])): int(r["SpellFamilyMask"]) for r in db["spell_affect"]}
    out = {}
    for spell_id in sorted(wanted):
        spell = pick(spells[str(spell_id)], SPELL_FIELDS)
        for i in range(3):
            mask = affects.get((str(spell_id), i), 0)
            if mask and not spell.get(f"EffectItemType{i + 1}"):
                spell[f"EffectItemType{i + 1}"] = mask
        spell["SpellFamilyFlags"] = int(spells[str(spell_id)]["SpellFamilyFlags"])
        out[str(spell_id)] = spell
    # A talent's later ranks use its first rank's spell_affect mask.
    for trees in talents.values():
        for tree in trees:
            for talent in tree["talents"]:
                first = out.get(str(talent["ranks"][0]), {})
                for rank_id in talent["ranks"][1:]:
                    spell = out.get(str(rank_id))
                    for i in range(1, 4):
                        if spell and not spell.get(f"EffectItemType{i}") and first.get(f"EffectItemType{i}"):
                            spell[f"EffectItemType{i}"] = first[f"EffectItemType{i}"]
    renames.apply({}, {}, {}, out, classic_names(db))
    chains = {r["spell_id"]: {"prev": int(r["prev_spell"]), "first": int(r["first_spell"]), "rank": int(r["rank"])}
              for r in db["spell_chain"] if int(r["spell_id"]) in wanted}
    bonus = {r["entry"]: {"direct": float(r["direct_bonus"]), "dot": float(r["dot_bonus"])}
             for r in db["spell_bonus_data"] if int(r["entry"]) in wanted}
    # Proc rates (procs per minute) and cooldowns, by spell, from spell_proc_event.
    # The spell family mask says which spells' hits set a proc off (Improved
    # Hamstring only from Hobble), procEx which outcomes (2: crits).
    procs = {r["entry"]: {"ppm": float(r["ppmRate"]), "chance": float(r["CustomChance"]), "cooldown": float(r["Cooldown"]),
                          "family": int(r["SpellFamilyName"]), "family_mask": int(r["SpellFamilyMask0"]),
                          "school": int(r["SchoolMask"]), "flags": int(r["procFlags"]), "ex": int(r["procEx"])}
             for r in db["spell_proc_event"] if int(r["entry"]) in wanted}
    write("spells.json", {"spells": out, "chains": chains, "bonus": bonus, "trainers": trainers,
                          "start_spells": start, "procs": procs, "talents": talents, "book_tabs": book_tabs,
                          "judgement_procs": {str(k): v for k, v in JUDGEMENT_PROC_SPELLS.items()},
                          "holy_shock": {str(k): v for k, v in HOLY_SHOCK_SPELLS.items()},
                          "links": {str(k): v for k, v in SPELL_LINKS.items()},
                          "traps": traps,
                          "pet_passives": HUNTER_PET_PASSIVES,
                          "seal_of_righteousness_procs": {str(k): v for k, v in SEAL_OF_RIGHTEOUSNESS_PROCS.items()}})
    print(f"{len(out)} spells, {sum(len(t) for t in trainers.values())} trainer entries, start spells {start}")


def creature_events(db, entry):
    """A creature's EventAI events that cast spells or set ranged mode:
    type, chance, flags, the six event params and [type, p1, p2, p3] actions."""
    events = []
    for r in sorted((r for r in db["creature_ai_scripts"] if r["creature_id"] == entry), key=lambda r: int(r["id"])):
        actions = [[int(r[f"action{i}_{k}"]) for k in ("type", "param1", "param2", "param3")] for i in (1, 2, 3)]
        actions = [a for a in actions if a[0] in AI_ACTIONS]
        if actions:
            events.append({"type": int(r["event_type"]), "chance": int(r["event_chance"]), "flags": int(r["event_flags"]),
                           "params": [int(r[f"event_param{i}"]) for i in range(1, 7)], "actions": actions})
    return events


def creature_spells(db):
    """Spells the exported creatures cast."""
    return {a[1] for entry in CREATURES for event in creature_events(db, str(entry))
            for a in event["actions"] if a[0] == 11}


def classic_names(db):
    """Every item, creature and spell name in the classic database."""
    return ({r["name"] for r in db["item_template"]} | {r["Name"] for r in db["creature_template"]}
            | {r["SpellName"] for r in db["spell_template"]})


def write(name, data):
    with open(os.path.join(OUT_DIR, name), "w", encoding="utf8") as out:
        json.dump(data, out, separators=(",", ":"), ensure_ascii=False)


if __name__ == "__main__":
    main(sys.argv[1])
