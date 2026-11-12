# The world plan

Two continents of zones from level 1 to 60, for both factions: **Aldmark**,
the old kingdoms (classic's Eastern Kingdoms in spirit), and **Kareth**,
the wild continent across the sea (classic's Kalimdor in spirit).

## How the plan works

- **One zone stands in for one classic zone.** Its creatures, loot, quests,
  vendors and trainers come from that zone's classic data, renamed by
  `tools/classic_db/renames.py`, as Ashford Vale (Northshire Valley) and
  Harrowfield (Elwynn Forest) already do. Levels are classic's.
- **The geography is the game's own.** Names, layout, settlements and places
  are new. The continents keep classic's broad sense (humans in the
  south, dwarves in the mountains, the Undead's north, the Horde's red coast
  and plains, the wild south of Kareth) but not its map.
- **Each race starts in a small walled valley (levels 1-6) that opens onto
  its first zone (6-12)**, as Ashford Vale opens onto Harrowfield: Humans in
  Ashford Vale; Dwarves and Gnomes in Frosthollow; the Undead in Gravesend;
  Wood Elves in Mossglen; Orcs and Trolls in Emberhollow; Hornkin at Sunfold
  Camp. Each faction has three capitals.
- **Places.** Each zone is a rectangle in world yards (`rect`: x0, z0, x1,
  z1; x east, z south, so -Z is north, as `World` has it). A zone's square
  is what `World.zone_at` will answer for. Ashford Vale (400 yards) and
  Harrowfield (1000) are where they are in the game, and the rest are sized to
  match: starting valleys 400 yards across, capitals 400-800, most zones
  1000-1600, the largest (the Thornwild, the Sunburnt Steppe) up to 2600.
  Each continent is its own world; ships, airships and the tram travel
  between them.
- **Links** are the roads and passes between neighbouring zones (`Zone.PASSES`
  cut through the mountains where two meet). Zones that share an edge without
  a link are kept apart by the mountains along every zone's edge.
- **Dungeons and raids** are listed with the zone their entrance is in, but
  not planned in detail yet.

`tools/world/plan_world.py` holds the plan. It writes `zones.json` (for the
game to read when zones are built) and the tables below, and checks that no
two zones overlap and that every link joins zones sharing an edge, both ways.
Change the plan there and rerun it:

    python tools/world/plan_world.py

## Built so far

- Aldmark: Ashford Vale and Harrowfield (Humans); Frosthollow and Highpeak (Dwarves and Gnomes); Gravesend and Duskmoor Glades (the Undead).
- Kareth: Mossglen and Eldergrove Isle (Wood Elves); Emberhollow and the Redsand Coast (Orcs and Trolls); Sunfold Camp and the Tallgrass (Hornkin).

Every race now begins in its own lands.

## Building order

1. The Horde's starting areas: Emberhollow and the Redsand Coast (Orcs and
   Trolls), with Ironmaw Hold; then Gravesend and Duskmoor Glades (Undead)
   and Sunfold Camp and the Tallgrass (Hornkin), so every race begins in its
   own lands.
2. The other Alliance starts: Frosthollow and Highpeak (Dwarves and Gnomes),
   Mossglen and Eldergrove Isle (Wood Elves), and the capitals.
3. The 10-20 zones (the Dunmarch, Lake Brannoch, Ashpine Forest, Moonshore,
   the Sunburnt Steppe), then upward by level band, with each band's
   dungeons.

<!-- tables -->

## Aldmark

The old kingdoms of men and dwarves, and the Undead's grey north: classic's Eastern Kingdoms in spirit, laid out anew.

| Zone | Levels | Faction | Classic | Settlement | Opens onto |
|---|---|---|---|---|---|
| **Ashford Vale** | 1-6 | alliance | Northshire Valley | the priory | Harrowfield |
| **Frosthollow** | 1-6 | alliance | Coldridge Valley | the Hollow Hall | Highpeak |
| **Gravesend** | 1-6 | horde | Deathknell | the Gravesend Chapel | Duskmoor Glades |
| **Harrowfield** | 6-12 | alliance | Elwynn Forest | Wexford | Ashford Vale, Aldgate, The Dunmarch, Redcrag Hills, Gloamwood |
| **Highpeak** | 6-12 | alliance | Dun Morogh | Kettlefold | Frosthollow, Anvilhold, Lake Brannoch |
| **Duskmoor Glades** | 6-12 | horde | Tirisfal Glades | Gallowfield | Gravesend, The Ossuary, Ashpine Forest, The Withering |
| **The Dunmarch** | 10-20 | alliance | Westfall | Saltmere Watch | Harrowfield, Aldgate, Gloamwood, The Thornwild |
| **Lake Brannoch** | 10-20 | alliance | Loch Modan | Brannoch Hold | Highpeak, Greymire Fens, The Ochre Waste |
| **Ashpine Forest** | 10-20 | horde | Silverpine Forest | the Grave Watch | Duskmoor Glades, Hallowbrook Foothills |
| **Redcrag Hills** | 15-25 | alliance | Redridge Mountains | Tarnbridge | Harrowfield, Cinderreach, Sorrowmire |
| **Gloamwood** | 18-30 | alliance | Duskwood | Lanternfall | Harrowfield, The Dunmarch, The Thornwild, Hollowpass, Sorrowmire |
| **Greymire Fens** | 20-30 | contested | Wetlands | Saltgate Harbour | Lake Brannoch, Carrow Downs, Hallowbrook Foothills |
| **Hallowbrook Foothills** | 20-30 | contested | Hillsbrad Foothills | Hallowbrook | Ashpine Forest, Greymire Fens, Wolfcrag Peaks, Carrow Downs |
| **Wolfcrag Peaks** | 30-40 | contested | Alterac Mountains | none | Hallowbrook Foothills, The Withering |
| **Carrow Downs** | 30-40 | contested | Arathi Highlands | Thistle Keep | Greymire Fens, Hallowbrook Foothills, The Wildreaches |
| **The Thornwild** | 30-45 | contested | Stranglethorn Vale | Corsair Cove | The Dunmarch, Gloamwood |
| **The Ochre Waste** | 35-45 | contested | Badlands | Redfang Bluff | Lake Brannoch, Slagdeep Gorge |
| **Sorrowmire** | 35-45 | contested | Swamp of Sorrows | Gravelmoss | Redcrag Hills, Gloamwood, The Scar |
| **The Wildreaches** | 40-50 | contested | The Hinterlands | Windroost | Carrow Downs, The Blightmarch |
| **Slagdeep Gorge** | 43-50 | contested | Searing Gorge | Ironcrest Point | Cinderreach, The Ochre Waste |
| **The Scar** | 45-55 | contested | Blasted Lands | Wardstone Hold | Sorrowmire, Hollowpass |
| **Cinderreach** | 50-58 | contested | Burning Steppes | Ashguard Vigil | Redcrag Hills, Slagdeep Gorge |
| **The Withering** | 51-58 | contested | Western Plaguelands | Mourncross Camp | Duskmoor Glades, Wolfcrag Peaks, The Blightmarch |
| **The Blightmarch** | 53-60 | contested | Eastern Plaguelands | Dawnvigil Chapel | The Withering, The Wildreaches |
| **Hollowpass** | 55-60 | contested | Deadwind Pass | none | Gloamwood, The Scar |
| **Aldgate** | city | alliance | Stormwind City | Aldgate | Harrowfield, The Dunmarch |
| **Anvilhold** | city | alliance | Ironforge | Anvilhold | Highpeak |
| **The Ossuary** | city | horde | Undercity | the Ossuary | Duskmoor Glades |

- **Ashford Vale**: A walled valley of vineyards round the priory, where the kingdom's recruits begin. Places: the priory, the mine, the brigand camp, the bridge.
- **Frosthollow**: A snowbound valley below the dwarven halls, where Dwarves and Gnomes begin. Places: the Hollow Hall, the Troll Caves, the Frozen Stair.
- **Gravesend**: A ruined chapel yard where the risen dead wake to their second life. Places: the Gravesend Chapel, the Webbed Vault, the Old Crypts.
- **Harrowfield**: Farmland and woods over the pass from the vale, troubled by brigands, burrowlings and gnolls. Places: Wexford, the Old Delve, Copperhollow, the Mirrow Mere, Thornwick Tower.
- **Highpeak**: Snowy pine valleys and frozen lakes under the mountains, with troll caves and a ruined gnome works. Places: Kettlefold, the Cogworks, the Icewater Tarn, the Southgate Pass.
- **Duskmoor Glades**: Grey glades of dead farms and pumpkin fields, hunted by the zealots of a crusading order. Places: Gallowfield, the Zealot Abbey, Lake Hollowmere, the Plaguewood Farms.
- **The Dunmarch**: Abandoned coastal farms where the brigand brotherhood gathers an army of the dispossessed. Places: Saltmere Watch, the Mill at Brack, the Drowned Lighthouse, Gullcove.
- **Lake Brannoch**: A dammed lake among green hills, mined by dwarves and raided by cave brutes and ogres. Places: Brannoch Hold, the Great Dam, the Silvervein Mine, the Ogre Mound.
- **Ashpine Forest**: A grey pine forest of wolfmen and wolves: the dead's road south to the human lands. Places: the Grave Watch, the Wolf Lord's Keep, the Ruined Mill, Shrouded Lake.
- **Redcrag Hills**: Red-rock hills round a lake town, held against gnoll warbands and the orcs of the high pass. Places: Tarnbridge, the Greyward Tower, Stonejaw Camp, the Ochre Lake.
- **Gloamwood**: A forest under endless dusk: wolfmen, ghouls and the hungry dead round a lantern-lit town. Places: Lanternfall, the Crowmound Barrows, the Widow's Hollow, Crookback Manor.
- **Greymire Fens**: A rain-soaked marsh between the dwarves and the north; its harbour sails to Kareth. Places: Saltgate Harbour, the Drakewatch Ruins, the Sunken Keep, the Reed Maze.
- **Hallowbrook Foothills**: Orchard hills where a human town and a Horde outpost fight over the farms between them. Places: Hallowbrook, Rookmill, the Orchard Farms, the Southwatch.
- **Wolfcrag Peaks**: Snowbound peaks over a fallen kingdom's ruins, overrun by ogres and its own exiles. Places: the Ruined Capital, the Ogre Halls, the Wolf Dens, the Snowdrift Camp.
- **Carrow Downs**: Wind-swept downs of standing stones and ruined forts, fought over by both factions. Places: Thistle Keep, Grimtusk Hold, the Kingstones, the Sunken Fort.
- **The Thornwild**: A great jungle down to a pirate port, full of tigers, raptors and troll ruins. Places: Corsair Cove, the Outlaw Camp, the Jungle Arena, the Jade Ziggurats, the Goldtooth Mines.
- **The Ochre Waste**: Red badlands of dry canyons, old dragon bones and a dig into a buried vault. Places: Redfang Bluff, the Delvers' Dig, the Dragon Bones, the Sandstone Fort.
- **Sorrowmire**: A grey swamp round a sunken temple of the old troll gods. Places: Gravelmoss, the Drowned Temple, the Reedmist Strand, the Exiles' Haven.
- **The Wildreaches**: High wooded hills of gryphon aeries and jungle-troll temples. Places: Windroost, the Tusktide Shore, the Serpent Steps, the Overgrown Altar.
- **Slagdeep Gorge**: A volcanic gorge round a vast slag mine, worked by the ashen dwarves' slaves. Places: Ironcrest Point, the Crucible, the Slag Pits, the Firewatch.
- **The Scar**: A blasted red waste round a dead gateway to another world, watched by a mage fortress. Places: Wardstone Hold, the Dead Gate, the Blight Rift, the Viper's Coil.
- **Cinderreach**: A scorched plain at the foot of the Cindermount, ruled by ashen dwarves and black dragons. Places: Ashguard Vigil, the Cindermount Gate, the Dragon's Rest, the Pillar of Ash.
- **The Withering**: Plagued farmland round a necromancers' school on an island keep. Places: Mourncross Camp, the Necromancers' School, the Ashgrain Farms, the Great Barricade.
- **The Blightmarch**: The heart of the plague: a dead city, a floating necropolis and the last chapel that holds. Places: Dawnvigil Chapel, the Fallen City, the Necropolis Shadow, Mourner's Crossing.
- **Hollowpass**: A dead, grey pass round a sorcerer's haunted tower. Places: the Mage's Tower, the Ravine, the Quiet Gorge.
- **Aldgate**: The kingdom's walled capital on the western harbour: trainers of every class, the bank and the ships. Places: the King's Keep, the Cathedral of the Dawn, the Harbour, the Old Town.
- **Anvilhold**: The dwarven capital hewn round a forge in the mountain's heart; its Undertram runs under the mountains to Aldgate. Places: the Heartforge, the Delvers' Library, the Undertram.
- **The Ossuary**: The Undead's capital, in the catacombs beneath a fallen royal city. Places: the Ruined Palace, the Alchemists' Vault, the Sewer Ring.

## Kareth

The wild continent across the sea: the Wood Elves' isle, the Horde's red coast and plains, deserts, jungles and a frozen north. Classic's Kalimdor in spirit, laid out anew.

| Zone | Levels | Faction | Classic | Settlement | Opens onto |
|---|---|---|---|---|---|
| **Mossglen** | 1-6 | alliance | Shadowglen | the Elderbough | Eldergrove Isle |
| **Emberhollow** | 1-6 | horde | Valley of Trials | the Proving Ground | Redsand Coast |
| **Sunfold Camp** | 1-6 | horde | Camp Narache | Sunfold Camp | The Tallgrass |
| **Eldergrove Isle** | 6-12 | alliance | Teldrassil | Fernwatch | Mossglen, Silverbough |
| **Redsand Coast** | 6-12 | horde | Durotar | Spikewall | Emberhollow, Ironmaw Hold, The Sunburnt Steppe, Fogmarsh |
| **The Tallgrass** | 6-12 | horde | Mulgore | Longhorn Village | Sunfold Camp, Windspire Mesa, The Sunburnt Steppe, Cragspire Peaks |
| **Moonshore** | 10-20 | alliance | Darkshore | Starhaven | Dimwood, Rotwood |
| **The Sunburnt Steppe** | 10-25 | horde | The Barrens | the Waymeet | Redsand Coast, The Tallgrass, Dimwood, Cragspire Peaks, Fogmarsh, The Hundred Spires |
| **Cragspire Peaks** | 15-27 | contested | Stonetalon Mountains | Sunstone Retreat | The Sunburnt Steppe, Dimwood, The Bonewind Waste, The Tallgrass |
| **Dimwood** | 18-30 | contested | Ashenvale | Silverglade | Moonshore, Rotwood, The Sunburnt Steppe, Cragspire Peaks, The Shattered Coast |
| **The Hundred Spires** | 25-35 | contested | Thousand Needles | Highwind Post | The Sunburnt Steppe, The Primeval Crater |
| **The Bonewind Waste** | 30-40 | contested | Desolace | Bramwell's Point | Cragspire Peaks, Wyldwood |
| **Fogmarsh** | 35-45 | contested | Dustwallow Marsh | Highmoor Isle | Redsand Coast, The Sunburnt Steppe |
| **Wyldwood** | 40-50 | contested | Feralas | Thornhaven | The Bonewind Waste, The Hiveland |
| **The Glass Dunes** | 40-50 | contested | Tanaris | Coppersand | The Primeval Crater |
| **The Shattered Coast** | 45-55 | contested | Azshara | Thornwatch Point | Dimwood |
| **The Primeval Crater** | 48-55 | contested | Un'Goro Crater | the Explorers' Rest | The Hundred Spires, The Glass Dunes, The Hiveland |
| **Rotwood** | 48-55 | contested | Felwood | the Verdant Sanctuary | Dimwood, Moonshore, Starfall Glade, Rimefrost Vale |
| **Rimefrost Vale** | 53-60 | contested | Winterspring | Frostgate | Rotwood |
| **The Hiveland** | 55-60 | contested | Silithus | Wardens' Hold | Wyldwood, The Primeval Crater |
| **Silverbough** | city | alliance | Darnassus | Silverbough | Eldergrove Isle |
| **Ironmaw Hold** | city | horde | Orgrimmar | Ironmaw Hold | Redsand Coast |
| **Windspire Mesa** | city | horde | Thunder Bluff | Windspire Mesa | The Tallgrass |
| **Starfall Glade** | sanctuary | neutral | Moonglade | Starhollow | Rotwood |

- **Mossglen**: A moonlit glen at the foot of the great tree, where Wood Elves begin. Places: the Elderbough, the Shadowrock, the Silkhollow.
- **Emberhollow**: A dry canyon of scorpids and boars, where Orcs and Trolls begin. Places: the Proving Ground, the Ember Cult Cave, the Scorpion Rocks.
- **Sunfold Camp**: A plains camp of the Hornkin tribes, where their young begin. Places: Sunfold Camp, the Thornback Ravine, the Wellspring.
- **Eldergrove Isle**: An island forest grown on the branches of a world-tree, troubled by corrupted bearfolk. Places: Fernwatch, the Seers' Glade, the Moonwells, the Thornbarrow Den.
- **Redsand Coast**: A red rocky coast of harpies, raptors and a stranded human keep. Places: Spikewall, the Tidebone Isles, the Stranded Keep, Stormcrag Ridge.
- **The Tallgrass**: Rolling grassland of tallbirds and thunderhorns, its wells drilled by goblin prospectors. Places: Longhorn Village, the Goldtooth Derrick, Ashmane Rock, the Ochre Stones.
- **Moonshore**: A long dark coast of ruined elven towns; its harbour sails to the isle and to Aldmark. Places: Starhaven, the Owlfolk Isle, the Duskwater Vale, the Fallen Glaive.
- **The Sunburnt Steppe**: A vast dry savanna of zebras, tuskfolk and raiders, crossed by the Horde's roads. Places: the Waymeet, Rustwater Harbour, the Weeping Caves, the Brackish Oasis, Camp Hornwatch.
- **Cragspire Peaks**: High peaks stripped by goblin loggers, with harpy nests and a burned valley. Places: Sunstone Retreat, the Galecut Crag, the Burnt Vale, Cragspire Peak.
- **Dimwood**: An old twilight forest that the elves guard against the Horde's lumber camps. Places: Silverglade, Splitpine Post, the Gloomwater Strand, the Warcry Lumber Camp.
- **The Hundred Spires**: A canyon of stone spires and a salt flat where goblins race. Places: Highwind Post, the Glittering Salt, the Long Lift, Stormcloud Pinnacle.
- **The Bonewind Waste**: A grey waste of thunderhorn bones and warring centaur clans. Places: Bramwell's Point, Grimfeather Village, the Thunderhorn Graveyard, the Centaur Holds.
- **Fogmarsh**: A fog-bound marsh round an island citadel whose harbour sails to Aldmark, and a dragon's lair. Places: Highmoor Isle, Mirewall Village, the Broodmother's Den, the Hag's Knoll.
- **Wyldwood**: A rain forest of giant trees, yetis and the ruins of an elven capital. Places: Thornhaven, Camp Tallhorn, the Old Court Ruins, the Twin Giants.
- **The Glass Dunes**: A burning desert round a goblin port, with sand-troll cities and a cave at the edge of time. Places: Coppersand, the Sandwalls, the Hourglass Cave, the Breaker Beach.
- **The Shattered Coast**: An autumn coast of broken elven palaces haunted by serpentfolk and goat-demons. Places: Thornwatch Point, the Drowned Palaces, the Serpent Temple, the Stormwrack Bay.
- **The Primeval Crater**: A steaming jungle crater of great saurians, oozes and ancient crystals. Places: the Explorers' Rest, the Smoke Ridge, the Crystal Pylons, the Wormscar.
- **Rotwood**: A forest rotted by demon fel, with tainted bearfolk and a tunnel north. Places: the Verdant Sanctuary, Venomfall, the Greenfire Glen, the Bearfolk Hold.
- **Rimefrost Vale**: A snowy valley of chimaeras, bearfolk and a goblin trading town. Places: Frostgate, Icemurmur Gorge, the Owlwood Thicket, the Shadow Gorge.
- **The Hiveland**: A desert of insect hives and cultists before the gates of a buried insect empire. Places: Wardens' Hold, the Hive Spires, the Cultists' Camps, the Beetle Wall.
- **Silverbough**: The Wood Elves' capital high in the world-tree. Places: the Starlight Temple, the Grove Enclave, the Blade Terrace.
- **Ironmaw Hold**: The Orcs' capital in a canyon fortress; airships leave its tower for Aldmark. Places: the Warlord's Hall, the Dark Rift, the Skyport.
- **Windspire Mesa**: The Hornkin's capital on high mesas joined by rope bridges and lifts. Places: the Elders' Mesa, the Spirit Mesa, the Hunters' Mesa.
- **Starfall Glade**: A peaceful druids' glade where every Wildwarden is welcome. Places: Starhollow, the Keeper's Shrine, the Barrow Dens.

## Dungeons and raids

| Dungeon | Levels | Zone | Classic |
|---|---|---|---|
| The Ember Chasm | 13-18 | Ironmaw Hold | Ragefire Chasm |
| The Undermines | 17-26 | The Dunmarch | The Deadmines |
| The Weeping Caves | 17-24 | The Sunburnt Steppe | Wailing Caverns |
| The Wolf Lord's Keep | 22-30 | Ashpine Forest | Shadowfang Keep |
| The Gaol | 24-32 | Aldgate | The Stockade |
| The Fathom Shrine | 24-32 | Dimwood | Blackfathom Deeps |
| The Cogworks | 29-38 | Highpeak | Gnomeregan |
| The Bramble Warrens | 29-38 | The Sunburnt Steppe | Razorfen Kraul |
| The Zealot Abbey | 34-45 | Duskmoor Glades | Scarlet Monastery |
| The Bramble Barrows | 37-46 | The Hundred Spires | Razorfen Downs |
| The Buried Vault | 41-51 | The Ochre Waste | Uldaman |
| The Sandwalls | 44-54 | The Glass Dunes | Zul'Farrak |
| The Hollow Hills | 46-55 | The Bonewind Waste | Maraudon |
| The Drowned Temple | 50-60 | Sorrowmire | The Temple of Atal'Hakkar |
| The Ashen Depths | 52-60 | Cinderreach | Blackrock Depths |
| The Cinder Spire | 55-60 | Cinderreach | Blackrock Spire |
| The Old Court | 55-60 | Wyldwood | Dire Maul |
| The Necromancers' School | 58-60 | The Withering | Scholomance |
| The Fallen City | 58-60 | The Blightmarch | Stratholme |
| The Molten Deep | raid | Cinderreach | Molten Core |
| The Dragon's Spire | raid | Cinderreach | Blackwing Lair |
| The Jade Ziggurats | raid | The Thornwild | Zul'Gurub |
| The Necropolis | raid | The Blightmarch | Naxxramas |
| The Broodmother's Den | raid | Fogmarsh | Onyxia's Lair |
| The Hive Gates | raid | The Hiveland | Ahn'Qiraj |

## Ships, airships and the tram

- Greymire Fens to Fogmarsh (ship): Saltgate Harbour to Highmoor Isle.
- Greymire Fens to Moonshore (ship): Saltgate Harbour to Starhaven.
- Moonshore to Eldergrove Isle (ship): Starhaven to the isle's shore.
- The Thornwild to The Sunburnt Steppe (ship): Corsair Cove to Rustwater Harbour, neutral.
- Ironmaw Hold to Duskmoor Glades (airship): Ironmaw's skyport to Gallowfield.
- Ironmaw Hold to The Thornwild (airship): Ironmaw's skyport to the Horde camp in the Thornwild.
- Aldgate to Anvilhold (tram): the Undertram under the mountains.
