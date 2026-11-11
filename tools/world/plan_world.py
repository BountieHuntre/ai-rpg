"""The plan of the game's two continents, Aldmark and Kareth: every zone
from 1 to 60 with the classic zone it stands in for (its creatures, loot and
quests come from that zone's classic data, renamed), its levels, faction,
rectangle in world yards (x east, z south; -Z is north, as the game's World),
settlement, places, dungeons and the zones it opens onto. Writes
docs/world/zones.json and the tables in docs/world/README.md (below its
"<!-- tables -->" line), and checks that no two zones overlap and that every
link joins zones that share an edge, both ways.

Run: python tools/world/plan_world.py
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# id: (name, classic zone, levels (None for a city or sanctuary), faction,
# [x0, z0, x1, z1] in yards, settlement, places, theme, links).
ALDMARK = {
	# Humans. Ashford Vale and Harrowfield are built; their rectangles are
	# where they are in the game.
	"ashford_vale": ("Ashford Vale", "Northshire Valley", (1, 6), "alliance", [-200, -200, 200, 200],
		"the priory", ["the priory", "the mine", "the brigand camp", "the bridge"],
		"A walled valley of vineyards round the priory, where the kingdom's recruits begin.",
		["harrowfield"]),
	"harrowfield": ("Harrowfield", "Elwynn Forest", (6, 12), "alliance", [-500, 200, 500, 1200],
		"Wexford", ["Wexford", "the Old Delve", "Copperhollow", "the Mirrow Mere", "Thornwick Tower"],
		"Farmland and woods over the pass from the vale, troubled by brigands, burrowlings and gnolls.",
		["ashford_vale", "aldgate", "dunmarch", "redcrag", "gloamwood"]),
	"aldgate": ("Aldgate", "Stormwind City", None, "alliance", [-1300, 200, -500, 1000],
		"Aldgate", ["the King's Keep", "the Cathedral of the Dawn", "the Harbour", "the Old Town"],
		"The kingdom's walled capital on the western harbour: trainers of every class, the bank and the ships.",
		["harrowfield", "dunmarch"]),
	"dunmarch": ("The Dunmarch", "Westfall", (10, 20), "alliance", [-1700, 1000, -500, 2200],
		"Saltmere Watch", ["Saltmere Watch", "the Mill at Brack", "the Drowned Lighthouse", "Gullcove"],
		"Abandoned coastal farms where the brigand brotherhood gathers an army of the dispossessed.",
		["harrowfield", "aldgate", "gloamwood", "thornwild"]),
	"redcrag": ("Redcrag Hills", "Redridge Mountains", (15, 25), "alliance", [500, 300, 1500, 1200],
		"Tarnbridge", ["Tarnbridge", "the Greyward Tower", "Stonejaw Camp", "the Ochre Lake"],
		"Red-rock hills round a lake town, held against gnoll warbands and the orcs of the high pass.",
		["harrowfield", "cinderreach", "sorrowmire"]),
	"gloamwood": ("Gloamwood", "Duskwood", (18, 30), "alliance", [-500, 1200, 700, 2200],
		"Lanternfall", ["Lanternfall", "the Crowmound Barrows", "the Widow's Hollow", "Crookback Manor"],
		"A forest under endless dusk: wolfmen, ghouls and the hungry dead round a lantern-lit town.",
		["harrowfield", "dunmarch", "thornwild", "hollowpass", "sorrowmire"]),
	# Dwarves and Gnomes.
	"frosthollow": ("Frosthollow", "Coldridge Valley", (1, 6), "alliance", [-1100, -1200, -700, -800],
		"the Hollow Hall", ["the Hollow Hall", "the Troll Caves", "the Frozen Stair"],
		"A snowbound valley below the dwarven halls, where Dwarves and Gnomes begin.",
		["highpeak"]),
	"highpeak": ("Highpeak", "Dun Morogh", (6, 12), "alliance", [-700, -1400, 500, -200],
		"Kettlefold", ["Kettlefold", "the Cogworks", "the Icewater Tarn", "the Southgate Pass"],
		"Snowy pine valleys and frozen lakes under the mountains, with troll caves and a ruined gnome works.",
		["frosthollow", "anvilhold", "brannoch"]),
	"anvilhold": ("Anvilhold", "Ironforge", None, "alliance", [-700, -1800, -100, -1400],
		"Anvilhold", ["the Heartforge", "the Delvers' Library", "the Undertram"],
		"The dwarven capital hewn round a forge in the mountain's heart; its Undertram runs under the mountains to Aldgate.",
		["highpeak"]),
	"brannoch": ("Lake Brannoch", "Loch Modan", (10, 20), "alliance", [500, -1400, 1500, -500],
		"Brannoch Hold", ["Brannoch Hold", "the Great Dam", "the Silvervein Mine", "the Ogre Mound"],
		"A dammed lake among green hills, mined by dwarves and raided by cave brutes and ogres.",
		["highpeak", "greymire", "ochre_waste"]),
	# Undead.
	"gravesend": ("Gravesend", "Deathknell", (1, 6), "horde", [-2900, -4500, -2500, -4100],
		"the Gravesend Chapel", ["the Gravesend Chapel", "the Webbed Vault", "the Old Crypts"],
		"A ruined chapel yard where the risen dead wake to their second life.",
		["duskmoor"]),
	"duskmoor": ("Duskmoor Glades", "Tirisfal Glades", (6, 12), "horde", [-2500, -4800, -1100, -3600],
		"Gallowfield", ["Gallowfield", "the Zealot Abbey", "Lake Hollowmere", "the Plaguewood Farms"],
		"Grey glades of dead farms and pumpkin fields, hunted by the zealots of a crusading order.",
		["gravesend", "ossuary", "ashpine", "withering"]),
	"ossuary": ("The Ossuary", "Undercity", None, "horde", [-1700, -5200, -1100, -4800],
		"the Ossuary", ["the Ruined Palace", "the Alchemists' Vault", "the Sewer Ring"],
		"The Undead's capital, in the catacombs beneath a fallen royal city.",
		["duskmoor"]),
	"ashpine": ("Ashpine Forest", "Silverpine Forest", (10, 20), "horde", [-2300, -3600, -1100, -2400],
		"the Grave Watch", ["the Grave Watch", "the Wolf Lord's Keep", "the Ruined Mill", "Shrouded Lake"],
		"A grey pine forest of wolfmen and wolves: the dead's road south to the human lands.",
		["duskmoor", "hallowbrook"]),
	# The middle and the north.
	"greymire": ("Greymire Fens", "Wetlands", (20, 30), "contested", [100, -2600, 1500, -1400],
		"Saltgate Harbour", ["Saltgate Harbour", "the Drakewatch Ruins", "the Sunken Keep", "the Reed Maze"],
		"A rain-soaked marsh between the dwarves and the north; its harbour sails to Kareth.",
		["brannoch", "carrow", "hallowbrook"]),
	"hallowbrook": ("Hallowbrook Foothills", "Hillsbrad Foothills", (20, 30), "contested", [-1100, -3600, 300, -2600],
		"Hallowbrook", ["Hallowbrook", "Rookmill", "the Orchard Farms", "the Southwatch"],
		"Orchard hills where a human town and a Horde outpost fight over the farms between them.",
		["ashpine", "greymire", "wolfcrag", "carrow"]),
	"wolfcrag": ("Wolfcrag Peaks", "Alterac Mountains", (30, 40), "contested", [-1100, -4500, 300, -3600],
		"none", ["the Ruined Capital", "the Ogre Halls", "the Wolf Dens", "the Snowdrift Camp"],
		"Snowbound peaks over a fallen kingdom's ruins, overrun by ogres and its own exiles.",
		["hallowbrook", "withering"]),
	"carrow": ("Carrow Downs", "Arathi Highlands", (30, 40), "contested", [300, -3700, 1700, -2600],
		"Thistle Keep", ["Thistle Keep", "Grimtusk Hold", "the Kingstones", "the Sunken Fort"],
		"Wind-swept downs of standing stones and ruined forts, fought over by both factions.",
		["greymire", "hallowbrook", "wildreaches"]),
	"wildreaches": ("The Wildreaches", "The Hinterlands", (40, 50), "contested", [1700, -3900, 2900, -2600],
		"Windroost", ["Windroost", "the Tusktide Shore", "the Serpent Steps", "the Overgrown Altar"],
		"High wooded hills of gryphon aeries and jungle-troll temples.",
		["carrow", "blightmarch"]),
	"withering": ("The Withering", "Western Plaguelands", (51, 58), "contested", [-1100, -5500, 500, -4500],
		"Mourncross Camp", ["Mourncross Camp", "the Necromancers' School", "the Ashgrain Farms", "the Great Barricade"],
		"Plagued farmland round a necromancers' school on an island keep.",
		["duskmoor", "wolfcrag", "blightmarch"]),
	"blightmarch": ("The Blightmarch", "Eastern Plaguelands", (53, 60), "contested", [500, -5500, 2100, -3900],
		"Dawnvigil Chapel", ["Dawnvigil Chapel", "the Fallen City", "the Necropolis Shadow", "Mourner's Crossing"],
		"The heart of the plague: a dead city, a floating necropolis and the last chapel that holds.",
		["withering", "wildreaches"]),
	# The south-east mountains.
	"cinderreach": ("Cinderreach", "Burning Steppes", (50, 58), "contested", [500, -500, 1500, 300],
		"Ashguard Vigil", ["Ashguard Vigil", "the Cindermount Gate", "the Dragon's Rest", "the Pillar of Ash"],
		"A scorched plain at the foot of the Cindermount, ruled by ashen dwarves and black dragons.",
		["redcrag", "slagdeep"]),
	"slagdeep": ("Slagdeep Gorge", "Searing Gorge", (43, 50), "contested", [1500, -500, 2500, 300],
		"Ironcrest Point", ["Ironcrest Point", "the Crucible", "the Slag Pits", "the Firewatch"],
		"A volcanic gorge round a vast slag mine, worked by the ashen dwarves' slaves.",
		["cinderreach", "ochre_waste"]),
	"ochre_waste": ("The Ochre Waste", "Badlands", (35, 45), "contested", [1500, -1500, 2700, -500],
		"Redfang Bluff", ["Redfang Bluff", "the Delvers' Dig", "the Dragon Bones", "the Sandstone Fort"],
		"Red badlands of dry canyons, old dragon bones and a dig into a buried vault.",
		["brannoch", "slagdeep"]),
	# The south.
	"sorrowmire": ("Sorrowmire", "Swamp of Sorrows", (35, 45), "contested", [700, 1200, 1700, 2200],
		"Gravelmoss", ["Gravelmoss", "the Drowned Temple", "the Reedmist Strand", "the Exiles' Haven"],
		"A grey swamp round a sunken temple of the old troll gods.",
		["redcrag", "gloamwood", "scar"]),
	"hollowpass": ("Hollowpass", "Deadwind Pass", (55, 60), "contested", [300, 2200, 1100, 2800],
		"none", ["the Mage's Tower", "the Ravine", "the Quiet Gorge"],
		"A dead, grey pass round a sorcerer's haunted tower.",
		["gloamwood", "scar"]),
	"scar": ("The Scar", "Blasted Lands", (45, 55), "contested", [1100, 2200, 2300, 3200],
		"Wardstone Hold", ["Wardstone Hold", "the Dead Gate", "the Blight Rift", "the Viper's Coil"],
		"A blasted red waste round a dead gateway to another world, watched by a mage fortress.",
		["sorrowmire", "hollowpass"]),
	"thornwild": ("The Thornwild", "Stranglethorn Vale", (30, 45), "contested", [-1700, 2200, 300, 3800],
		"Corsair Cove", ["Corsair Cove", "the Outlaw Camp", "the Jungle Arena", "the Jade Ziggurats", "the Goldtooth Mines"],
		"A great jungle down to a pirate port, full of tigers, raptors and troll ruins.",
		["dunmarch", "gloamwood"]),
}

KARETH = {
	# Wood Elves.
	"mossglen": ("Mossglen", "Shadowglen", (1, 6), "alliance", [-2400, -5200, -2000, -4800],
		"the Elderbough", ["the Elderbough", "the Shadowrock", "the Silkhollow"],
		"A moonlit glen at the foot of the great tree, where Wood Elves begin.",
		["eldergrove"]),
	"eldergrove": ("Eldergrove Isle", "Teldrassil", (6, 12), "alliance", [-2600, -4800, -1400, -3600],
		"Fernwatch", ["Fernwatch", "the Seers' Glade", "the Moonwells", "the Thornbarrow Den"],
		"An island forest grown on the branches of a world-tree, troubled by corrupted bearfolk.",
		["mossglen", "silverbough"]),
	"silverbough": ("Silverbough", "Darnassus", None, "alliance", [-2900, -4400, -2600, -4000],
		"Silverbough", ["the Starlight Temple", "the Grove Enclave", "the Blade Terrace"],
		"The Wood Elves' capital high in the world-tree.",
		["eldergrove"]),
	"moonshore": ("Moonshore", "Darkshore", (10, 20), "alliance", [-1200, -4400, -200, -2600],
		"Starhaven", ["Starhaven", "the Owlfolk Isle", "the Duskwater Vale", "the Fallen Glaive"],
		"A long dark coast of ruined elven towns; its harbour sails to the isle and to Aldmark.",
		["dimwood", "rotwood"]),
	# Orcs and Trolls.
	"emberhollow": ("Emberhollow", "Valley of Trials", (1, 6), "horde", [2300, -1900, 2700, -1500],
		"the Proving Ground", ["the Proving Ground", "the Ember Cult Cave", "the Scorpion Rocks"],
		"A dry canyon of scorpids and boars, where Orcs and Trolls begin.",
		["redsand"]),
	"redsand": ("Redsand Coast", "Durotar", (6, 12), "horde", [1300, -2400, 2300, -1000],
		"Spikewall", ["Spikewall", "the Tidebone Isles", "the Stranded Keep", "Stormcrag Ridge"],
		"A red rocky coast of harpies, raptors and a stranded human keep.",
		["emberhollow", "ironmaw", "steppe", "fogmarsh"]),
	"ironmaw": ("Ironmaw Hold", "Orgrimmar", None, "horde", [2300, -2400, 2900, -1900],
		"Ironmaw Hold", ["the Warlord's Hall", "the Dark Rift", "the Skyport"],
		"The Orcs' capital in a canyon fortress; airships leave its tower for Aldmark.",
		["redsand"]),
	# Hornkin.
	"sunfold": ("Sunfold Camp", "Camp Narache", (1, 6), "horde", [-700, 1000, -300, 1400],
		"Sunfold Camp", ["Sunfold Camp", "the Thornback Ravine", "the Wellspring"],
		"A plains camp of the Hornkin tribes, where their young begin.",
		["tallgrass"]),
	"tallgrass": ("The Tallgrass", "Mulgore", (6, 12), "horde", [-1500, -200, -300, 1000],
		"Longhorn Village", ["Longhorn Village", "the Goldtooth Derrick", "Ashmane Rock", "the Ochre Stones"],
		"Rolling grassland of tallbirds and thunderhorns, its wells drilled by goblin prospectors.",
		["sunfold", "windspire", "steppe", "cragspire"]),
	"windspire": ("Windspire Mesa", "Thunder Bluff", None, "horde", [-1300, 1000, -700, 1400],
		"Windspire Mesa", ["the Elders' Mesa", "the Spirit Mesa", "the Hunters' Mesa"],
		"The Hornkin's capital on high mesas joined by rope bridges and lifts.",
		["tallgrass"]),
	# The middle.
	"steppe": ("The Sunburnt Steppe", "The Barrens", (10, 25), "horde", [-300, -1600, 1300, 1000],
		"the Waymeet", ["the Waymeet", "Rustwater Harbour", "the Weeping Caves", "the Brackish Oasis", "Camp Hornwatch"],
		"A vast dry savanna of zebras, tuskfolk and raiders, crossed by the Horde's roads.",
		["redsand", "tallgrass", "dimwood", "cragspire", "fogmarsh", "hundred_spires"]),
	"cragspire": ("Cragspire Peaks", "Stonetalon Mountains", (15, 27), "contested", [-1700, -1600, -300, -200],
		"Sunstone Retreat", ["Sunstone Retreat", "the Galecut Crag", "the Burnt Vale", "Cragspire Peak"],
		"High peaks stripped by goblin loggers, with harpy nests and a burned valley.",
		["steppe", "dimwood", "bonewind", "tallgrass"]),
	"dimwood": ("Dimwood", "Ashenvale", (18, 30), "contested", [-1200, -2600, 700, -1600],
		"Silverglade", ["Silverglade", "Splitpine Post", "the Gloomwater Strand", "the Warcry Lumber Camp"],
		"An old twilight forest that the elves guard against the Horde's lumber camps.",
		["moonshore", "rotwood", "steppe", "cragspire", "shattered_coast"]),
	"hundred_spires": ("The Hundred Spires", "Thousand Needles", (25, 35), "contested", [-300, 1000, 1300, 1900],
		"Highwind Post", ["Highwind Post", "the Glittering Salt", "the Long Lift", "Stormcloud Pinnacle"],
		"A canyon of stone spires and a salt flat where goblins race.",
		["steppe", "crater"]),
	"bonewind": ("The Bonewind Waste", "Desolace", (30, 40), "contested", [-2900, -1600, -1700, 0],
		"Bramwell's Point", ["Bramwell's Point", "Grimfeather Village", "the Thunderhorn Graveyard", "the Centaur Holds"],
		"A grey waste of thunderhorn bones and warring centaur clans.",
		["cragspire", "wyldwood"]),
	"fogmarsh": ("Fogmarsh", "Dustwallow Marsh", (35, 45), "contested", [1300, -1000, 2500, 400],
		"Highmoor Isle", ["Highmoor Isle", "Mirewall Village", "the Broodmother's Den", "the Hag's Knoll"],
		"A fog-bound marsh round an island citadel whose harbour sails to Aldmark, and a dragon's lair.",
		["redsand", "steppe"]),
	"wyldwood": ("Wyldwood", "Feralas", (40, 50), "contested", [-3100, 0, -1500, 2000],
		"Thornhaven", ["Thornhaven", "Camp Tallhorn", "the Old Court Ruins", "the Twin Giants"],
		"A rain forest of giant trees, yetis and the ruins of an elven capital.",
		["bonewind", "hiveland"]),
	"glass_dunes": ("The Glass Dunes", "Tanaris", (40, 50), "contested", [1300, 1900, 2700, 3300],
		"Coppersand", ["Coppersand", "the Sandwalls", "the Hourglass Cave", "the Breaker Beach"],
		"A burning desert round a goblin port, with sand-troll cities and a cave at the edge of time.",
		["crater"]),
	"crater": ("The Primeval Crater", "Un'Goro Crater", (48, 55), "contested", [-300, 1900, 1300, 3100],
		"the Explorers' Rest", ["the Explorers' Rest", "the Smoke Ridge", "the Crystal Pylons", "the Wormscar"],
		"A steaming jungle crater of great saurians, oozes and ancient crystals.",
		["hundred_spires", "glass_dunes", "hiveland"]),
	"hiveland": ("The Hiveland", "Silithus", (55, 60), "contested", [-1700, 2000, -300, 3300],
		"Wardens' Hold", ["Wardens' Hold", "the Hive Spires", "the Cultists' Camps", "the Beetle Wall"],
		"A desert of insect hives and cultists before the gates of a buried insect empire.",
		["wyldwood", "crater"]),
	# The north.
	"shattered_coast": ("The Shattered Coast", "Azshara", (45, 55), "contested", [700, -3600, 1900, -2400],
		"Thornwatch Point", ["Thornwatch Point", "the Drowned Palaces", "the Serpent Temple", "the Stormwrack Bay"],
		"An autumn coast of broken elven palaces haunted by serpentfolk and goat-demons.",
		["dimwood"]),
	"rotwood": ("Rotwood", "Felwood", (48, 55), "contested", [-200, -4200, 500, -2600],
		"the Verdant Sanctuary", ["the Verdant Sanctuary", "Venomfall", "the Greenfire Glen", "the Bearfolk Hold"],
		"A forest rotted by demon fel, with tainted bearfolk and a tunnel north.",
		["dimwood", "moonshore", "starfall", "rimefrost"]),
	"starfall": ("Starfall Glade", "Moonglade", None, "neutral", [-200, -4800, 500, -4200],
		"Starhollow", ["Starhollow", "the Keeper's Shrine", "the Barrow Dens"],
		"A peaceful druids' glade where every Wildwarden is welcome.",
		["rotwood"]),
	"rimefrost": ("Rimefrost Vale", "Winterspring", (53, 60), "contested", [500, -5200, 1900, -3600],
		"Frostgate", ["Frostgate", "Icemurmur Gorge", "the Owlwood Thicket", "the Shadow Gorge"],
		"A snowy valley of chimaeras, bearfolk and a goblin trading town.",
		["rotwood"]),
}

# Dungeons and raids: (name, classic, levels or "raid", zone).
DUNGEONS = [
	("The Undermines", "The Deadmines", (17, 26), "dunmarch"),
	("The Gaol", "The Stockade", (24, 32), "aldgate"),
	("The Wolf Lord's Keep", "Shadowfang Keep", (22, 30), "ashpine"),
	("The Cogworks", "Gnomeregan", (29, 38), "highpeak"),
	("The Zealot Abbey", "Scarlet Monastery", (34, 45), "duskmoor"),
	("The Buried Vault", "Uldaman", (41, 51), "ochre_waste"),
	("The Drowned Temple", "The Temple of Atal'Hakkar", (50, 60), "sorrowmire"),
	("The Ashen Depths", "Blackrock Depths", (52, 60), "cinderreach"),
	("The Cinder Spire", "Blackrock Spire", (55, 60), "cinderreach"),
	("The Necromancers' School", "Scholomance", (58, 60), "withering"),
	("The Fallen City", "Stratholme", (58, 60), "blightmarch"),
	("The Ember Chasm", "Ragefire Chasm", (13, 18), "ironmaw"),
	("The Weeping Caves", "Wailing Caverns", (17, 24), "steppe"),
	("The Fathom Shrine", "Blackfathom Deeps", (24, 32), "dimwood"),
	("The Bramble Warrens", "Razorfen Kraul", (29, 38), "steppe"),
	("The Bramble Barrows", "Razorfen Downs", (37, 46), "hundred_spires"),
	("The Sandwalls", "Zul'Farrak", (44, 54), "glass_dunes"),
	("The Hollow Hills", "Maraudon", (46, 55), "bonewind"),
	("The Old Court", "Dire Maul", (55, 60), "wyldwood"),
	("The Molten Deep", "Molten Core", "raid", "cinderreach"),
	("The Dragon's Spire", "Blackwing Lair", "raid", "cinderreach"),
	("The Jade Ziggurats", "Zul'Gurub", "raid", "thornwild"),
	("The Necropolis", "Naxxramas", "raid", "blightmarch"),
	("The Broodmother's Den", "Onyxia's Lair", "raid", "fogmarsh"),
	("The Hive Gates", "Ahn'Qiraj", "raid", "hiveland"),
]

# Ships, airships and the tram: (from, to, kind, about).
ROUTES = [
	("greymire", "fogmarsh", "ship", "Saltgate Harbour to Highmoor Isle"),
	("greymire", "moonshore", "ship", "Saltgate Harbour to Starhaven"),
	("moonshore", "eldergrove", "ship", "Starhaven to the isle's shore"),
	("thornwild", "steppe", "ship", "Corsair Cove to Rustwater Harbour, neutral"),
	("ironmaw", "duskmoor", "airship", "Ironmaw's skyport to Gallowfield"),
	("ironmaw", "thornwild", "airship", "Ironmaw's skyport to the Horde camp in the Thornwild"),
	("aldgate", "anvilhold", "tram", "the Undertram under the mountains"),
]

CONTINENTS = {
	"aldmark": ("Aldmark", "The old kingdoms of men and dwarves, and the Undead's grey north: classic's Eastern Kingdoms in spirit, laid out anew.", ALDMARK),
	"kareth": ("Kareth", "The wild continent across the sea: the Wood Elves' isle, the Horde's red coast and plains, deserts, jungles and a frozen north. Classic's Kalimdor in spirit, laid out anew.", KARETH),
}


def touches(a, b):
	"""Whether two rectangles share a stretch of edge (not just a corner)."""
	x_overlap = min(a[2], b[2]) - max(a[0], b[0])
	z_overlap = min(a[3], b[3]) - max(a[1], b[1])
	return (x_overlap > 0 and z_overlap == 0) or (z_overlap > 0 and x_overlap == 0)


def overlaps(a, b):
	return min(a[2], b[2]) > max(a[0], b[0]) and min(a[3], b[3]) > max(a[1], b[1])


def main():
	out = {"continents": {}, "dungeons": [], "routes": []}
	problems = []
	zone_of = {}
	for cid, (name, about, zones) in CONTINENTS.items():
		listed = {}
		for zid, (zname, classic, levels, faction, rect, hub, places, theme, links) in zones.items():
			zone_of[zid] = cid
			listed[zid] = {
				"name": zname, "classic": classic, "levels": list(levels) if levels else None,
				"faction": faction, "kind": "zone" if levels else "sanctuary" if faction == "neutral" else "city",
				"rect": rect, "size": [rect[2] - rect[0], rect[3] - rect[1]],
				"hub": hub, "places": places, "theme": theme, "links": links,
			}
			for other in links:
				if other not in zones:
					problems.append(f"{zid} links to {other}, which isn't on {cid}")
				elif not touches(rect, zones[other][4]):
					problems.append(f"{zid} links to {other}, but they don't share an edge")
				elif zid not in zones[other][8]:
					problems.append(f"{zid} links to {other}, but not back")
		ids = list(zones)
		for i, a in enumerate(ids):
			for b in ids[i + 1:]:
				if overlaps(zones[a][4], zones[b][4]):
					problems.append(f"{a} overlaps {b}")
		out["continents"][cid] = {"name": name, "about": about, "zones": listed}
	for dname, classic, levels, zone in DUNGEONS:
		if zone not in zone_of:
			problems.append(f"{dname} is in {zone}, which isn't a zone")
		out["dungeons"].append({"name": dname, "classic": classic,
								"levels": levels if levels == "raid" else list(levels), "zone": zone})
	for a, b, kind, about in ROUTES:
		for z in (a, b):
			if z not in zone_of:
				problems.append(f"route from {a} to {b}: {z} isn't a zone")
		out["routes"].append({"from": a, "to": b, "kind": kind, "about": about})
	if problems:
		raise SystemExit("\n".join(problems))
	with open(os.path.join(ROOT, "docs", "world", "zones.json"), "w", encoding="utf8", newline="\n") as f:
		json.dump(out, f, indent="\t")
		f.write("\n")
	write_readme(out)
	print("ok:", {c: len(v["zones"]) for c, v in out["continents"].items()}, len(out["dungeons"]), "dungeons and raids")


def write_readme(out):
	path = os.path.join(ROOT, "docs", "world", "README.md")
	with open(path, encoding="utf8") as f:
		head = f.read().split("<!-- tables -->")[0]
	lines = [head + "<!-- tables -->", ""]
	names = {zid: z["name"] for c in out["continents"].values() for zid, z in c["zones"].items()}
	for cont in out["continents"].values():
		zones = cont["zones"]
		order = sorted(zones, key=lambda z: (zones[z]["levels"] or [99])[0])
		lines += [f"## {cont['name']}", "", cont["about"], "",
				  "| Zone | Levels | Faction | Classic | Settlement | Opens onto |", "|---|---|---|---|---|---|"]
		for zid in order:
			z = zones[zid]
			levels = f"{z['levels'][0]}-{z['levels'][1]}" if z["levels"] else z["kind"]
			links = ", ".join(names[l] for l in z["links"]) or "by sea only"
			lines.append(f"| **{z['name']}** | {levels} | {z['faction']} | {z['classic']} | {z['hub']} | {links} |")
		lines.append("")
		for zid in order:
			z = zones[zid]
			lines.append(f"- **{z['name']}**: {z['theme']} Places: {', '.join(z['places'])}.")
		lines.append("")
	lines += ["## Dungeons and raids", "", "| Dungeon | Levels | Zone | Classic |", "|---|---|---|---|"]
	for d in sorted(out["dungeons"], key=lambda d: (1, 0) if d["levels"] == "raid" else (0, d["levels"][0])):
		levels = "raid" if d["levels"] == "raid" else f"{d['levels'][0]}-{d['levels'][1]}"
		lines.append(f"| {d['name']} | {levels} | {names[d['zone']]} | {d['classic']} |")
	lines += ["", "## Ships, airships and the tram", ""]
	for r in out["routes"]:
		lines.append(f"- {names[r['from']]} to {names[r['to']]} ({r['kind']}): {r['about']}.")
	lines.append("")
	with open(path, "w", encoding="utf8", newline="\n") as f:
		f.write("\n".join(lines))


if __name__ == "__main__":
	main()
