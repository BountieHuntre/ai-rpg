class_name Enemy
extends CharacterBody3D
## Placeholder enemy. Wanders near its spawn point, chases whoever it has the
## most threat on (the player or a playerbot), auto-attacks in melee, and runs
## home to reset if pulled too far. When killed it leaves a corpse, lootable
## if the player's group tapped it, then respawns. Stats, money, loot,
## respawn time and wander distance come from the classic creature entry in
## data/classic/creatures.json.

enum State { IDLE, CHASE, RETURN, DEAD }

const CREATURES_PATH := "res://data/classic/creatures.json"
const CREATURE_TYPE_HUMANOID := 7
## Dead units move to this physics layer so their corpses can be clicked.
const CORPSE_LAYER := 4
const UNIT_LAYER := 2
## Creature run speed is its SpeedRun times the base run speed of 7 yards/s,
## and walk speed its SpeedWalk times 2.5 yards/s.
const BASE_RUN_SPEED := 7.0
const BASE_WALK_SPEED := 2.5
## RandomMovementGenerator in CMaNGOS: wait 0.5 to 10 s between wanders.
const WANDER_PAUSE_MIN := 0.5
const WANDER_PAUSE_MAX := 10.0
const CREATURE_TYPE_BEAST := 1
## ThreatManager in CMaNGOS: a creature changes victim only when another unit
## has 110% of the current victim's threat in melee range, 130% beyond it.
const THREAT_SWITCH_MELEE := 1.1
const THREAT_SWITCH_RANGED := 1.3
## Healing draws half its amount as threat (HostileRefManager::threatAssist).
const HEAL_THREAT := 0.5
## Placeholder looks until there are models: [size, body color]. Beasts lie
## along their length.
const LOOKS := {
	299: [Vector3(0.75, 0.75, 0.75), Color(0.55, 0.55, 0.58)],
	69: [Vector3(0.9, 0.9, 0.9), Color(0.42, 0.36, 0.3)],
	113: [Vector3(1.0, 0.85, 1.0), Color(0.45, 0.3, 0.22)],
	6: [Vector3(0.65, 0.65, 0.65), Color(0.75, 0.55, 0.3)],
	257: [Vector3(0.75, 0.75, 0.75), Color(0.7, 0.5, 0.28)],
	80: [Vector3(0.8, 0.8, 0.8), Color(0.62, 0.45, 0.25)],
	475: [Vector3(0.85, 0.85, 0.85), Color(0.55, 0.38, 0.22)],
	38: [Vector3(1.0, 1.0, 1.0), Color(0.6, 0.15, 0.15)],
	476: [Vector3(0.8, 0.8, 0.8), Color(0.75, 0.35, 0.2)],
	40: [Vector3(0.85, 0.85, 0.85), Color(0.5, 0.42, 0.3)],
	94: [Vector3(0.95, 0.95, 0.95), Color(0.3, 0.3, 0.35)],
	# Harrowfield.
	525: [Vector3(0.85, 0.85, 0.85), Color(0.5, 0.45, 0.38)],
	30: [Vector3(0.7, 0.45, 0.8), Color(0.25, 0.22, 0.2)],
	285: [Vector3(0.85, 0.85, 0.85), Color(0.3, 0.55, 0.45)],
	735: [Vector3(0.85, 0.85, 0.85), Color(0.25, 0.5, 0.55)],
	732: [Vector3(0.95, 0.95, 0.95), Color(0.22, 0.42, 0.38)],
	46: [Vector3(0.95, 0.95, 0.95), Color(0.35, 0.5, 0.3)],
	524: [Vector3(1.05, 0.9, 1.05), Color(0.4, 0.38, 0.35)],
	390: [Vector3(1.0, 0.85, 1.0), Color(0.85, 0.6, 0.55)],
	330: [Vector3(1.3, 1.05, 1.3), Color(0.9, 0.65, 0.6)],
	1922: [Vector3(0.95, 0.95, 0.95), Color(0.5, 0.5, 0.52)],
	822: [Vector3(1.15, 1.0, 1.15), Color(0.35, 0.25, 0.18)],
	118: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.3, 0.32)],
	43: [Vector3(0.8, 0.5, 0.9), Color(0.18, 0.16, 0.15)],
	327: [Vector3(0.95, 0.95, 0.95), Color(0.75, 0.6, 0.25)],
	116: [Vector3(1.0, 1.0, 1.0), Color(0.55, 0.12, 0.12)],
	474: [Vector3(1.0, 1.0, 1.0), Color(0.35, 0.2, 0.45)],
	97: [Vector3(0.9, 0.9, 0.9), Color(0.6, 0.45, 0.3)],
	478: [Vector3(1.0, 1.0, 1.0), Color(0.55, 0.4, 0.25)],
	117: [Vector3(1.1, 1.1, 1.1), Color(0.5, 0.36, 0.22)],
	448: [Vector3(1.4, 1.4, 1.4), Color(0.45, 0.3, 0.2)],
	# Kareth: Emberhollow.
	3098: [Vector3(0.9, 0.8, 0.9), Color(0.52, 0.38, 0.28)],
	3124: [Vector3(0.7, 0.45, 0.8), Color(0.62, 0.42, 0.2)],
	3101: [Vector3(0.6, 0.6, 0.6), Color(0.7, 0.3, 0.15)],
	3102: [Vector3(0.95, 0.9, 1.0), Color(0.35, 0.25, 0.3)],
	3281: [Vector3(1.3, 0.8, 1.4), Color(0.6, 0.3, 0.15)],
	3183: [Vector3(1.0, 1.0, 1.0), Color(0.4, 0.15, 0.12)],
	# The Redsand Coast.
	3099: [Vector3(1.05, 0.9, 1.05), Color(0.48, 0.34, 0.25)],
	3100: [Vector3(1.15, 0.95, 1.15), Color(0.42, 0.3, 0.22)],
	3106: [Vector3(0.55, 0.35, 0.6), Color(0.75, 0.4, 0.25)],
	3107: [Vector3(0.7, 0.45, 0.75), Color(0.72, 0.36, 0.22)],
	3108: [Vector3(0.85, 0.5, 0.9), Color(0.55, 0.5, 0.4)],
	3103: [Vector3(0.9, 0.9, 0.9), Color(0.6, 0.35, 0.3)],
	3104: [Vector3(0.95, 0.95, 0.95), Color(0.55, 0.4, 0.32)],
	3105: [Vector3(1.0, 1.0, 1.0), Color(0.65, 0.3, 0.25)],
	3141: [Vector3(1.1, 1.1, 1.1), Color(0.5, 0.42, 0.38)],
	3125: [Vector3(0.75, 0.5, 0.85), Color(0.6, 0.45, 0.25)],
	3126: [Vector3(0.85, 0.55, 0.95), Color(0.4, 0.35, 0.3)],
	3127: [Vector3(0.9, 0.55, 1.0), Color(0.35, 0.45, 0.25)],
	5823: [Vector3(1.1, 0.7, 1.2), Color(0.25, 0.35, 0.2)],
	3111: [Vector3(0.95, 0.95, 0.95), Color(0.5, 0.36, 0.3)],
	3112: [Vector3(0.95, 0.95, 0.95), Color(0.48, 0.38, 0.3)],
	3113: [Vector3(1.0, 1.0, 1.0), Color(0.55, 0.4, 0.32)],
	3114: [Vector3(1.1, 1.1, 1.1), Color(0.45, 0.32, 0.26)],
	5826: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.5, 0.35)],
	5824: [Vector3(1.2, 1.2, 1.2), Color(0.4, 0.3, 0.25)],
	3115: [Vector3(0.95, 0.95, 0.95), Color(0.6, 0.5, 0.4)],
	3116: [Vector3(0.95, 0.95, 0.95), Color(0.55, 0.45, 0.38)],
	3117: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.42, 0.35)],
	3118: [Vector3(1.0, 1.0, 1.0), Color(0.4, 0.45, 0.6)],
	3119: [Vector3(1.15, 1.15, 1.15), Color(0.5, 0.38, 0.25)],
	3120: [Vector3(1.2, 1.2, 1.2), Color(0.55, 0.4, 0.26)],
	5808: [Vector3(1.35, 1.35, 1.35), Color(0.45, 0.32, 0.2)],
	3121: [Vector3(1.0, 0.85, 1.1), Color(0.78, 0.5, 0.2)],
	3122: [Vector3(0.95, 1.0, 1.0), Color(0.6, 0.25, 0.2)],
	3123: [Vector3(1.05, 1.1, 1.1), Color(0.5, 0.22, 0.18)],
	3128: [Vector3(1.0, 1.0, 1.0), Color(0.2, 0.3, 0.55)],
	3129: [Vector3(1.0, 1.0, 1.0), Color(0.2, 0.3, 0.55)],
	3192: [Vector3(1.0, 1.0, 1.0), Color(0.2, 0.3, 0.55)],
	5809: [Vector3(1.0, 1.0, 1.0), Color(0.2, 0.3, 0.55)],
	3130: [Vector3(1.2, 0.9, 1.4), Color(0.45, 0.5, 0.55)],
	3131: [Vector3(1.25, 0.95, 1.45), Color(0.4, 0.48, 0.65)],
	3195: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3196: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3197: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3198: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3199: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3203: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3204: [Vector3(1.1, 1.1, 1.1), Color(0.3, 0.08, 0.08)],
	5822: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.08, 0.08)],
	3205: [Vector3(1.05, 1.05, 1.05), Color(0.35, 0.2, 0.45)],
	3206: [Vector3(1.0, 1.0, 1.0), Color(0.35, 0.2, 0.45)],
	3207: [Vector3(1.0, 1.0, 1.0), Color(0.35, 0.2, 0.45)],
	3110: [Vector3(1.2, 0.6, 1.6), Color(0.3, 0.38, 0.25)],
	# Aldmark's north and Kareth's west.
	1501: [Vector3(1.0, 1.0, 1.0), Color(0.45, 0.5, 0.42)],
	1502: [Vector3(1.0, 1.0, 1.0), Color(0.42, 0.45, 0.4)],
	1890: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.72)],
	1508: [Vector3(0.8, 0.8, 0.8), Color(0.5, 0.42, 0.32)],
	1509: [Vector3(0.9, 0.9, 0.9), Color(0.45, 0.38, 0.3)],
	1512: [Vector3(0.6, 0.6, 0.6), Color(0.3, 0.25, 0.28)],
	1513: [Vector3(0.65, 0.65, 0.65), Color(0.32, 0.26, 0.26)],
	1504: [Vector3(0.7, 0.7, 0.7), Color(0.25, 0.22, 0.2)],
	1505: [Vector3(0.85, 0.85, 0.85), Color(0.22, 0.2, 0.18)],
	1688: [Vector3(1.1, 1.1, 1.1), Color(0.3, 0.2, 0.25)],
	1506: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1507: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1667: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1525: [Vector3(1.0, 1.0, 1.0), Color(0.42, 0.46, 0.36)],
	1526: [Vector3(1.0, 1.0, 1.0), Color(0.4, 0.42, 0.34)],
	1547: [Vector3(0.9, 0.9, 0.9), Color(0.3, 0.28, 0.3)],
	1548: [Vector3(0.95, 0.95, 0.95), Color(0.28, 0.25, 0.3)],
	1549: [Vector3(1.0, 1.0, 1.0), Color(0.25, 0.22, 0.28)],
	10356: [Vector3(1.15, 1.15, 1.15), Color(0.2, 0.18, 0.22)],
	1553: [Vector3(0.75, 0.75, 0.75), Color(0.3, 0.25, 0.28)],
	1554: [Vector3(0.8, 0.8, 0.8), Color(0.35, 0.2, 0.25)],
	10357: [Vector3(0.95, 0.95, 0.95), Color(0.4, 0.2, 0.25)],
	1555: [Vector3(0.9, 0.9, 0.9), Color(0.3, 0.15, 0.2)],
	1520: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.72)],
	1522: [Vector3(1.0, 1.0, 1.0), Color(0.8, 0.78, 0.7)],
	1523: [Vector3(1.05, 1.05, 1.05), Color(0.82, 0.78, 0.68)],
	1674: [Vector3(0.95, 0.95, 0.95), Color(0.42, 0.36, 0.3)],
	1675: [Vector3(0.9, 0.9, 0.9), Color(0.45, 0.4, 0.3)],
	1941: [Vector3(0.95, 0.95, 0.95), Color(0.4, 0.34, 0.28)],
	1753: [Vector3(1.2, 1.2, 1.2), Color(0.38, 0.32, 0.26)],
	1535: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1536: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1537: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1538: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1539: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1540: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1660: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1662: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1664: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.82, 0.75)],
	1665: [Vector3(1.05, 1.05, 1.05), Color(0.85, 0.82, 0.75)],
	1543: [Vector3(0.85, 0.85, 0.85), Color(0.3, 0.45, 0.4)],
	1544: [Vector3(0.9, 0.9, 0.9), Color(0.35, 0.4, 0.5)],
	1545: [Vector3(0.95, 0.95, 0.95), Color(0.3, 0.4, 0.35)],
	1909: [Vector3(1.0, 1.0, 1.0), Color(0.25, 0.42, 0.4)],
	1957: [Vector3(0.95, 0.95, 0.95), Color(0.3, 0.5, 0.42)],
	1958: [Vector3(0.95, 0.95, 0.95), Color(0.32, 0.42, 0.55)],
	1910: [Vector3(1.15, 1.15, 1.15), Color(0.35, 0.5, 0.35)],
	1529: [Vector3(1.05, 1.05, 1.05), Color(0.55, 0.3, 0.3)],
	1532: [Vector3(1.0, 1.0, 1.0), Color(0.6, 0.65, 0.7)],
	1534: [Vector3(1.0, 1.0, 1.0), Color(0.6, 0.62, 0.66)],
	1530: [Vector3(1.0, 1.0, 1.0), Color(0.45, 0.48, 0.4)],
	1658: [Vector3(1.1, 1.1, 1.1), Color(0.5, 0.5, 0.45)],
	1654: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.52, 0.5)],
	1655: [Vector3(0.95, 0.95, 0.95), Color(0.5, 0.52, 0.5)],
	1656: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.52, 0.5)],
	1657: [Vector3(0.9, 0.9, 0.9), Color(0.5, 0.52, 0.5)],
	1934: [Vector3(1.0, 1.0, 1.0), Color(0.45, 0.35, 0.22)],
	1935: [Vector3(0.95, 0.95, 0.95), Color(0.45, 0.35, 0.22)],
	1936: [Vector3(1.05, 1.05, 1.05), Color(0.45, 0.35, 0.22)],
	1531: [Vector3(1.0, 1.0, 1.0), Color(0.6, 0.65, 0.7)],
	2955: [Vector3(0.9, 0.9, 0.9), Color(0.6, 0.5, 0.35)],
	2956: [Vector3(1.0, 1.0, 1.0), Color(0.55, 0.45, 0.32)],
	2957: [Vector3(1.1, 1.1, 1.1), Color(0.5, 0.42, 0.3)],
	2961: [Vector3(0.95, 0.95, 0.95), Color(0.62, 0.5, 0.36)],
	3035: [Vector3(1.0, 1.0, 1.0), Color(0.66, 0.55, 0.38)],
	3566: [Vector3(1.05, 1.05, 1.05), Color(0.5, 0.42, 0.3)],
	2966: [Vector3(1.0, 1.0, 1.0), Color(0.45, 0.32, 0.24)],
	2954: [Vector3(1.05, 1.05, 1.05), Color(0.4, 0.3, 0.22)],
	2952: [Vector3(0.95, 0.95, 0.95), Color(0.55, 0.4, 0.3)],
	2953: [Vector3(0.95, 0.95, 0.95), Color(0.5, 0.42, 0.32)],
	3229: [Vector3(1.0, 1.0, 1.0), Color(0.55, 0.38, 0.28)],
	8554: [Vector3(1.25, 1.25, 1.25), Color(0.48, 0.34, 0.25)],
	3232: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.38, 0.28)],
	2958: [Vector3(0.85, 0.85, 0.85), Color(0.6, 0.52, 0.4)],
	2959: [Vector3(0.9, 0.9, 0.9), Color(0.55, 0.45, 0.35)],
	2960: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.42, 0.32)],
	2969: [Vector3(0.8, 0.8, 0.8), Color(0.55, 0.45, 0.35)],
	2970: [Vector3(0.9, 0.9, 0.9), Color(0.5, 0.4, 0.3)],
	2971: [Vector3(0.95, 0.95, 0.95), Color(0.45, 0.35, 0.28)],
	2949: [Vector3(0.95, 0.95, 0.95), Color(0.7, 0.66, 0.55)],
	2950: [Vector3(0.95, 0.95, 0.95), Color(0.68, 0.62, 0.5)],
	2951: [Vector3(1.0, 1.0, 1.0), Color(0.65, 0.6, 0.48)],
	5786: [Vector3(1.15, 1.15, 1.15), Color(0.6, 0.55, 0.45)],
	2962: [Vector3(0.95, 0.95, 0.95), Color(0.55, 0.5, 0.45)],
	2963: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.48, 0.55)],
	3068: [Vector3(1.4, 1.4, 1.4), Color(0.45, 0.42, 0.35)],
	3056: [Vector3(1.15, 1.15, 1.15), Color(0.85, 0.85, 0.82)],
	2978: [Vector3(0.8, 0.8, 0.8), Color(0.45, 0.6, 0.3)],
	2979: [Vector3(0.85, 0.85, 0.85), Color(0.45, 0.6, 0.3)],
	3051: [Vector3(0.9, 0.9, 0.9), Color(0.45, 0.6, 0.3)],
	# Aldmark's mountains and Kareth's north-west.
	705: [Vector3(0.8, 0.8, 0.8), Color(0.5, 0.48, 0.46)],
	704: [Vector3(0.9, 0.9, 0.9), Color(0.45, 0.42, 0.4)],
	707: [Vector3(0.9, 0.9, 0.9), Color(0.5, 0.46, 0.42)],
	724: [Vector3(1.0, 1.0, 1.0), Color(0.46, 0.42, 0.38)],
	706: [Vector3(0.8, 0.8, 0.8), Color(0.5, 0.6, 0.66)],
	946: [Vector3(0.9, 0.9, 0.9), Color(0.5, 0.6, 0.66)],
	708: [Vector3(0.75, 0.75, 0.75), Color(0.5, 0.42, 0.36)],
	808: [Vector3(1.05, 1.05, 1.05), Color(0.45, 0.55, 0.62)],
	1718: [Vector3(1.0, 1.0, 1.0), Color(0.44, 0.4, 0.36)],
	1125: [Vector3(0.9, 0.9, 0.9), Color(0.48, 0.4, 0.34)],
	1126: [Vector3(1.0, 1.0, 1.0), Color(0.46, 0.38, 0.32)],
	1127: [Vector3(1.1, 1.1, 1.1), Color(0.42, 0.36, 0.3)],
	1689: [Vector3(1.1, 1.1, 1.1), Color(0.44, 0.34, 0.28)],
	1128: [Vector3(0.9, 0.9, 0.9), Color(0.18, 0.16, 0.16)],
	1196: [Vector3(1.1, 1.1, 1.1), Color(0.82, 0.84, 0.88)],
	1130: [Vector3(1.3, 1.3, 1.3), Color(0.86, 0.88, 0.92)],
	1961: [Vector3(1.25, 1.25, 1.25), Color(0.4, 0.32, 0.26)],
	1199: [Vector3(0.8, 0.8, 0.8), Color(0.88, 0.88, 0.9)],
	1201: [Vector3(1.0, 1.0, 1.0), Color(0.85, 0.84, 0.8)],
	1131: [Vector3(1.0, 1.0, 1.0), Color(0.88, 0.88, 0.9)],
	1138: [Vector3(0.95, 0.95, 0.95), Color(0.55, 0.55, 0.58)],
	1133: [Vector3(0.95, 0.95, 0.95), Color(0.75, 0.75, 0.78)],
	1132: [Vector3(1.15, 1.15, 1.15), Color(0.6, 0.6, 0.62)],
	1134: [Vector3(1.0, 1.0, 1.0), Color(0.86, 0.86, 0.88)],
	1135: [Vector3(1.15, 1.15, 1.15), Color(0.84, 0.84, 0.86)],
	1137: [Vector3(1.25, 1.25, 1.25), Color(0.8, 0.82, 0.86)],
	1271: [Vector3(1.35, 1.35, 1.35), Color(0.9, 0.92, 0.95)],
	1388: [Vector3(1.35, 1.35, 1.35), Color(0.78, 0.8, 0.84)],
	1120: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.6, 0.66)],
	1121: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.6, 0.66)],
	1123: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.6, 0.66)],
	1122: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.6, 0.66)],
	1124: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.6, 0.66)],
	1397: [Vector3(1.0, 1.0, 1.0), Color(0.5, 0.6, 0.66)],
	1260: [Vector3(1.15, 1.15, 1.15), Color(0.5, 0.6, 0.66)],
	1211: [Vector3(0.65, 0.65, 0.65), Color(0.5, 0.58, 0.42)],
	8503: [Vector3(0.7, 0.7, 0.7), Color(0.48, 0.56, 0.4)],
	1115: [Vector3(1.0, 1.0, 1.0), Color(0.46, 0.42, 0.38)],
	1116: [Vector3(1.0, 1.0, 1.0), Color(0.44, 0.4, 0.36)],
	1117: [Vector3(1.0, 1.0, 1.0), Color(0.48, 0.42, 0.36)],
	1118: [Vector3(1.1, 1.1, 1.1), Color(0.42, 0.38, 0.34)],
	1119: [Vector3(1.2, 1.2, 1.2), Color(0.4, 0.36, 0.32)],
	2031: [Vector3(0.8, 0.8, 0.8), Color(0.3, 0.26, 0.38)],
	2032: [Vector3(0.9, 0.9, 0.9), Color(0.34, 0.3, 0.38)],
	1984: [Vector3(0.7, 0.7, 0.7), Color(0.42, 0.34, 0.3)],
	1985: [Vector3(0.85, 0.85, 0.85), Color(0.4, 0.32, 0.28)],
	1988: [Vector3(0.6, 0.6, 0.6), Color(0.36, 0.52, 0.3)],
	1989: [Vector3(0.5, 0.5, 0.5), Color(0.4, 0.56, 0.32)],
	1986: [Vector3(0.6, 0.6, 0.6), Color(0.3, 0.3, 0.36)],
	1994: [Vector3(0.85, 0.85, 0.85), Color(0.36, 0.28, 0.42)],
	1995: [Vector3(0.7, 0.7, 0.7), Color(0.55, 0.48, 0.4)],
	1996: [Vector3(0.75, 0.75, 0.75), Color(0.5, 0.44, 0.38)],
	1997: [Vector3(0.8, 0.8, 0.8), Color(0.45, 0.4, 0.34)],
	1998: [Vector3(0.65, 0.65, 0.65), Color(0.32, 0.3, 0.36)],
	1999: [Vector3(0.75, 0.75, 0.75), Color(0.3, 0.34, 0.3)],
	2000: [Vector3(0.8, 0.8, 0.8), Color(0.4, 0.38, 0.44)],
	2001: [Vector3(1.0, 1.0, 1.0), Color(0.3, 0.28, 0.34)],
	2002: [Vector3(0.45, 0.45, 0.45), Color(0.5, 0.6, 0.85)],
	2003: [Vector3(0.5, 0.5, 0.5), Color(0.35, 0.4, 0.65)],
	2004: [Vector3(0.55, 0.55, 0.55), Color(0.3, 0.26, 0.45)],
	2005: [Vector3(0.65, 0.65, 0.65), Color(0.32, 0.46, 0.28)],
	2038: [Vector3(0.9, 0.9, 0.9), Color(0.3, 0.22, 0.4)],
	14432: [Vector3(0.75, 0.75, 0.75), Color(0.38, 0.5, 0.3)],
	2042: [Vector3(0.95, 0.95, 0.95), Color(0.28, 0.26, 0.36)],
	2043: [Vector3(1.0, 1.0, 1.0), Color(0.24, 0.22, 0.32)],
	2033: [Vector3(1.05, 1.05, 1.05), Color(0.32, 0.3, 0.4)],
	2034: [Vector3(1.05, 1.05, 1.05), Color(0.36, 0.28, 0.32)],
	14430: [Vector3(1.15, 1.15, 1.15), Color(0.18, 0.16, 0.24)],
	2006: [Vector3(1.1, 1.1, 1.1), Color(0.45, 0.34, 0.24)],
	2007: [Vector3(1.05, 1.05, 1.05), Color(0.48, 0.38, 0.26)],
	2008: [Vector3(1.1, 1.1, 1.1), Color(0.42, 0.32, 0.22)],
	7235: [Vector3(1.05, 1.05, 1.05), Color(0.5, 0.4, 0.3)],
	7234: [Vector3(1.2, 1.2, 1.2), Color(0.38, 0.28, 0.22)],
	2152: [Vector3(1.1, 1.1, 1.1), Color(0.4, 0.3, 0.2)],
	2009: [Vector3(1.05, 1.05, 1.05), Color(0.46, 0.36, 0.28)],
	2010: [Vector3(1.15, 1.15, 1.15), Color(0.4, 0.3, 0.22)],
	2011: [Vector3(1.05, 1.05, 1.05), Color(0.5, 0.42, 0.3)],
	2012: [Vector3(1.1, 1.1, 1.1), Color(0.44, 0.34, 0.24)],
	2013: [Vector3(1.15, 1.15, 1.15), Color(0.38, 0.28, 0.2)],
	2014: [Vector3(1.1, 1.1, 1.1), Color(0.5, 0.38, 0.28)],
	2039: [Vector3(1.35, 1.35, 1.35), Color(0.34, 0.24, 0.18)],
	14429: [Vector3(1.25, 1.25, 1.25), Color(0.3, 0.22, 0.16)],
	14428: [Vector3(1.25, 1.25, 1.25), Color(0.46, 0.36, 0.26)],
	2022: [Vector3(1.0, 1.0, 1.0), Color(0.4, 0.32, 0.24)],
	2025: [Vector3(1.05, 1.05, 1.05), Color(0.38, 0.3, 0.22)],
	2027: [Vector3(1.15, 1.15, 1.15), Color(0.36, 0.3, 0.24)],
	2029: [Vector3(1.15, 1.15, 1.15), Color(0.3, 0.34, 0.24)],
	2030: [Vector3(1.25, 1.25, 1.25), Color(0.34, 0.28, 0.22)],
	2166: [Vector3(1.45, 1.45, 1.45), Color(0.3, 0.36, 0.24)],
	2015: [Vector3(0.95, 0.95, 0.95), Color(0.6, 0.3, 0.3)],
	2017: [Vector3(0.95, 0.95, 0.95), Color(0.55, 0.28, 0.28)],
	2018: [Vector3(0.95, 0.95, 0.95), Color(0.5, 0.3, 0.4)],
	2019: [Vector3(1.0, 1.0, 1.0), Color(0.65, 0.25, 0.25)],
	2020: [Vector3(1.0, 1.0, 1.0), Color(0.55, 0.35, 0.45)],
	2021: [Vector3(1.1, 1.1, 1.1), Color(0.6, 0.22, 0.22)],
	14431: [Vector3(1.1, 1.1, 1.1), Color(0.7, 0.2, 0.2)],
}

@export var acceleration := 60.0
@export var gravity := 19.29
## Seconds to respawn and yards to wander; below zero takes the classic
## spawn's values from the data.
@export var respawn_override := -1.0
## Respawn times are this share of classic's (unlike classic, which with few
## players about leaves hunting grounds empty too long).
const RESPAWN_SCALE := 0.5
@export var wander_override := -1.0
## Never attacks on sight, whatever its classic faction: it only fights back.
@export var passive := false
## Distance from home that makes it give up and evade.
@export var leash_radius := 60.0
@export var stop_distance := 2.0
var respawn_time := 180.0
## creature_template entry, such as 299 for Young Wolf.
@export var creature_entry := 299

static var _creatures: Dictionary
static var _class_stats: Dictionary

const CLASS_STATS_PATH := "res://data/classic/creature_class_stats.json"
## creature_template Rank: 0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare.
const RANK_NORMAL := 0
const RANK_ELITE := 1
const RANK_BOSS := 3
## What a rank made by "spawn" multiplies a normal creature's health and
## damage by, and its size. The game's own numbers: classic's elite and boss
## templates carry their own stats instead.
const RANK_HEALTH := { RANK_ELITE: 3.0, RANK_BOSS: 15.0 }
const RANK_DAMAGE := { RANK_ELITE: 1.5, RANK_BOSS: 2.5 }
const RANK_SIZE := { RANK_ELITE: 1.2, RANK_BOSS: 1.6 }

var state := State.IDLE
var level := 1
var elite := false
## A boss (classic rank 3, a world boss): its level shows as "??".
var boss := false
## Set before it's added (the dev console's "spawn"): a level to scale the
## creature to (0 keeps the template's), a rank (-1 keeps the template's;
## RANK_NORMAL, RANK_ELITE, RANK_BOSS), and whether it's gone for good once
## its corpse would respawn (and isn't saved).
var level_override := 0
var rank_override := -1
var temporary := false
## What's left on the corpse: { "id", "count" } entries, and copper.
var loot: Array[Dictionary] = []
var loot_money := 0
## Unix time (seconds) when a dead enemy comes back. Real time, so it keeps
## counting while the game is closed, like a classic server's respawn timer.
var respawn_at := 0.0
## Threat on each player unit fighting it: Combatant -> threat.
var threat: Dictionary = {}
## The first player unit to strike it. Its group gets the kill: XP, quest
## credit and the loot. Others see the creature grey.
var tapped_by: Combatant
## Its classic spellcasting, for creatures whose EventAI casts spells; else null.
var ai: CreatureAI
var _victim: Combatant
## Seconds to the next look around for players to attack (staggered, so
## creatures don't all look on the same frame).
var _aggro_left := randf() * AGGRO_CHECK
const AGGRO_CHECK := 0.2
## Player units by square of the world, GRID yards on a side, made once a
## physics frame, so a creature looking for someone to attack only checks
## the squares around it. Classic's widest aggro radius is 45 yards.
const GRID := 50.0
static var _grid: Dictionary = {}
static var _grid_frame := -1
static var _player_at := Vector3.ZERO
## Far from the player (Bot.FAR), the BotManager ticks the creature itself
## within its time budget (BotManager.far_schedule), in bigger steps, with its
## nodes' own per-frame work switched off; far_clock is when it last did.
var _far := false
var far_clock := 0.0

## Seconds left fleeing in a panic (flee), or 0.
var panic_left := 0.0
## Call for help on a pull: who it noted, against whom, and when they come.
const ASSIST_RADIUS := 5.0
const ASSIST_DELAY := 2.0
var _assist_left := -1.0
var _assist_receivers: Array[Enemy] = []
var _assist_enemy: Combatant

var _home := Vector3.ZERO
var _data: Dictionary
var _wander_distance := 0.0
var _wander_target := Vector3.ZERO
var _wander_wait := 0.0

@onready var combatant: Combatant = $Combatant
@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D
## The standing shape, put back on respawn.
@onready var _standing_shape: Shape3D = _collision.shape
@onready var _standing_transform: Transform3D = _collision.transform
@onready var _feedback: UnitFeedback = $UnitFeedback
@onready var _sparkle := _build_sparkle()

const SPARKLE_SPIN := 2.0
## Extra yards around a corpse's body that still count as clicking it.
const CORPSE_CLICK_MARGIN := 0.2


## A creature_template entry's data from data/classic/creatures.json.
static func creature_data(entry: int) -> Dictionary:
	if _creatures.is_empty():
		_creatures = JSON.parse_string(FileAccess.get_file_as_string(CREATURES_PATH))
	return _creatures.get(str(entry), {})


## Every creature entry in the data (the dev console's "spawn" picks one).
static func creature_entries() -> Array[int]:
	creature_data(0)
	var entries: Array[int] = []
	for key: String in _creatures:
		entries.append(int(key))
	return entries


func _ready() -> void:
	_home = global_position
	_data = creature_data(creature_entry)
	var c := combatant
	c.display_name = _data.Name
	c.min_damage = _data.MinMeleeDmg
	c.max_damage = _data.MaxMeleeDmg
	c.swing_interval = _data.MeleeBaseAttackTime / 1000.0
	c.attack_power = int(_data.MeleeAttackPower)
	c.armor = int(_data.Armor)
	c.melee_crit = CombatRules.NPC_CRIT
	c.dodge = CombatRules.NPC_AVOIDANCE
	c.parry = CombatRules.NPC_AVOIDANCE if int(_data.CreatureType) == CREATURE_TYPE_HUMANOID else 0.0
	var rank := rank_override if rank_override >= 0 else int(_data.Rank)
	elite = rank > 0
	boss = rank == RANK_BOSS
	respawn_time = respawn_override if respawn_override >= 0.0 else float(_data.get("Respawn", 180)) * RESPAWN_SCALE
	_wander_distance = wander_override if wander_override >= 0.0 else float(_data.get("Wander", 0))
	_wander_target = _home
	_wander_wait = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
	_apply_look()
	if rank_override > 0:
		_visual.scale *= float(RANK_SIZE.get(rank_override, 1.0))
	c.faces_point = _is_facing
	_roll_level()
	c.took_damage.connect(func(amount: int, source: Combatant, _crit: bool) -> void: _on_attacked(source, amount))
	c.avoided.connect(func(_text: String, source: Combatant) -> void: _on_attacked(source, 0))
	c.died.connect(_on_died)
	if not _data.get("Events", []).is_empty():
		ai = CreatureAI.new()
		ai.name = "CreatureAI"
		add_child(ai)
		ai.setup(self, _data)
		ai.on_spawn()


func _physics_process(delta: float) -> void:
	_refresh_frame()
	# Corpses stay where they fell: no gravity or sliding with the corpse shape.
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return
	var destination := global_position

	var speed: float = _data.SpeedRun * BASE_RUN_SPEED
	match state:
		State.IDLE:
			_aggro_left -= delta
			if _aggro_left <= 0.0 and is_aggressive():
				_aggro_left = AGGRO_CHECK
				for unit: PlayerUnit in _units_near():
					if unit.combatant.is_alive() and global_position.distance_to(unit.global_position) <= aggro_radius(unit.combatant.level):
						add_threat(unit.combatant, 0.0)
						_start_chase(unit.combatant)
						break
			if state == State.IDLE:
				destination = _wander(delta)
				speed = _data.SpeedWalk * BASE_WALK_SPEED
		State.CHASE:
			_victim = _pick_victim()
			_update_assistance(delta)
			var feared := combatant.fear_source()
			if panic_left > 0.0 and _victim:
				# Fleeing in a panic: away from its victim, without fighting.
				panic_left -= delta
				combatant.attack_target = null
				combatant.enter_combat()
				var flight := global_position - _victim.body.global_position
				flight.y = 0.0
				destination = global_position + (flight.normalized() if flight.length() > 0.1 else Vector3.FORWARD) * 5.0
				_face(destination)
			elif feared:
				# Runs from whoever frightened it, without fighting.
				combatant.attack_target = null
				combatant.enter_combat()
				var away := global_position - feared.body.global_position
				away.y = 0.0
				destination = global_position + (away.normalized() if away.length() > 0.1 else Vector3.FORWARD) * 5.0
				_face(destination)
			elif _victim == null or global_position.distance_to(_home) > leash_radius:
				_start_return()
			else:
				var at := _victim.body.global_position
				combatant.attack_target = _victim
				combatant.enter_combat()
				_victim.enter_combat()
				# Casters stand off to cast, and hold still while casting.
				if global_position.distance_to(at) > stop_distance and not (ai and ai.holds_ground(_victim)):
					destination = at
				_face(at)
		State.RETURN:
			destination = _home
			if Vector2(global_position.x - _home.x, global_position.z - _home.z).length() < 0.5:
				combatant.reset()
				state = State.IDLE
				_wander_target = _home

	speed *= combatant.speed_multiplier() if not combatant.is_rooted() else 0.0
	var offset := destination - global_position
	offset.y = 0.0
	var direction := offset.normalized() if state != State.DEAD and not combatant.is_stunned() else Vector3.ZERO
	if state in [State.IDLE, State.RETURN] and direction != Vector3.ZERO:
		_face(global_position + direction)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(direction * speed, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if _far and World.current:
		# Far from the player: along the ground, no collision (as far bots),
		# its long steps stopping where it's going rather than overshooting.
		var reach := minf(Vector2(velocity.x, velocity.z).length() * delta, Vector2(offset.x, offset.z).length())
		var step := global_position + Vector3(velocity.x, 0.0, velocity.z).normalized() * reach
		global_position = Vector3(step.x, World.current.height_at(step.x, step.z), step.z)
		velocity.y = 0.0
		return
	# Standing still on the ground: nothing to move, so no collision work.
	if horizontal == Vector3.ZERO and is_on_floor() and velocity.y <= 0.0:
		velocity.y = 0.0
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()


func set_far(far: bool) -> void:
	if far == _far:
		return
	_far = far
	for node: Node in [self, combatant, ai]:
		if node:
			node.set_physics_process(not far)
	_feedback.set_process(not far)
	if model:
		model.call("set_animating", not far)


## One slow tick for a far creature: what its nodes would do over `delta`.
func far_tick(delta: float) -> void:
	combatant._physics_process(delta)
	if ai:
		ai._physics_process(delta)
	_physics_process(delta)


func is_far() -> bool:
	return _far


## Once a physics frame, for every creature: where the player is, and the
## player units by square.
func _refresh_frame() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _grid_frame:
		return
	_grid_frame = frame
	_grid.clear()
	for node in get_tree().get_nodes_in_group("player_units"):
		if node.is_in_group("player"):
			_player_at = node.global_position
		var key := Vector2i(floori(node.global_position.x / GRID), floori(node.global_position.z / GRID))
		if not _grid.has(key):
			_grid[key] = []
		_grid[key].append(node)


## The living and dead player units in the squares around this creature.
func _units_near() -> Array:
	var near := []
	var cell := Vector2i(floori(global_position.x / GRID), floori(global_position.z / GRID))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			near.append_array(_grid.get(cell + Vector2i(dx, dz), []))
	return near


## Idle wandering: walk to a random point near home, pause, pick another.
func _wander(delta: float) -> Vector3:
	if _wander_distance <= 0.0:
		return global_position
	var offset := _wander_target - global_position
	offset.y = 0.0
	if offset.length() > 0.3:
		return _wander_target
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		var angle := randf() * TAU
		var reach := sqrt(randf()) * _wander_distance
		_wander_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * reach
		_wander_wait = randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)
	return global_position


## Human creatures shown as the Human model: creature entry -> { "main":
## weapon prop, "off": off-hand part, "helm": helm part }
## (HumanoidModel.creature_gear). The brigands wear the red hoods of their band.
const HUMAN_CREATURES := {
	38: { "main": "sword", "helm": "Helm_hood" },
	94: { "main": "dagger", "helm": "Helm_hood" },
	116: { "main": "dagger", "off": "Off_dagger", "helm": "Helm_hood" },
	473: { "main": "sword", "off": "Shield_round" },
	474: { "main": "staff", "helm": "Helm_hood" },
	# Kareth: the Saltmarch sailors and marines of the Stranded Keep.
	3128: { "main": "sword" },
	3129: { "main": "sword", "off": "Shield_round", "helm": "Helm_cap" },
	3192: { "main": "sword", "off": "Shield_kite", "helm": "Helm_plate" },
	5809: { "main": "mace", "off": "Shield_kite", "helm": "Helm_coif" },
	# The Ember Cult's orcs.
	3183: { "main": "staff", "helm": "Helm_hood" },
	3195: { "main": "mace" },
	3196: { "main": "dagger" },
	3197: { "main": "axe2h" },
	3198: { "main": "staff", "helm": "Helm_hood" },
	3199: { "main": "staff", "helm": "Helm_hood" },
	3203: { "main": "staff", "helm": "Helm_hood" },
	3204: { "main": "axe", "off": "Off_axe" },
	5822: { "main": "staff", "helm": "Helm_hood" },
	# Vazzar's trolls.
	3205: { "main": "staff" },
	3206: { "main": "staff" },
	3207: { "main": "axe" },
	# Aldmark's north and Kareth's west.
	1501: { "main": "" },
	1502: { "main": "" },
	1890: { "main": "sword" },
	1520: { "main": "sword", "off": "Shield_round" },
	1522: { "main": "staff" },
	1523: { "main": "axe" },
	1525: { "main": "" },
	1526: { "main": "" },
	1529: { "main": "" },
	1532: { "main": "" },
	1534: { "main": "" },
	1530: { "main": "" },
	1531: { "main": "" },
	1658: { "main": "sword2h", "helm": "Helm_plate" },
	1654: { "main": "mace" },
	1655: { "main": "dagger" },
	1656: { "main": "sword" },
	1657: { "main": "" },
	1506: { "main": "mace" },
	1507: { "main": "sword", "helm": "Helm_hood" },
	1667: { "main": "dagger" },
	1535: { "main": "sword", "off": "Shield_kite", "helm": "Helm_cap" },
	1536: { "main": "staff", "helm": "Helm_hood" },
	1537: { "main": "sword2h" },
	1538: { "main": "staff", "helm": "Helm_hood" },
	1539: { "main": "mace", "helm": "Helm_hood" },
	1540: { "main": "sword", "off": "Shield_kite", "helm": "Helm_coif" },
	1660: { "main": "mace", "off": "Shield_kite", "helm": "Helm_plate" },
	1662: { "main": "sword", "off": "Shield_kite", "helm": "Helm_plate" },
	1664: { "main": "mace2h", "helm": "Helm_plate" },
	1665: { "main": "sword2h", "helm": "Helm_plate" },
	1934: { "main": "polearm" },
	1935: { "main": "" },
	1936: { "main": "axe" },
	2978: { "main": "mace" },
	2979: { "main": "axe" },
	3051: { "main": "mace", "helm": "Helm_cap" },
	# The Icemane trolls.
	706: { "main": "" },
	946: { "main": "staff" },
	808: { "main": "axe" },
	1120: { "main": "axe" },
	1121: { "main": "polearm" },
	1123: { "main": "axe", "off": "axe" },
	1122: { "main": "dagger" },
	1124: { "main": "staff" },
	1397: { "main": "staff" },
	1260: { "main": "axe2h" },
}
## The race and colours of HUMAN_CREATURES that aren't brigands: entry ->
## [model race, colour of their hoods and coats, whether they wear a cloak].
const CREATURE_RACES := {
	3128: ["human", Color(0.2, 0.3, 0.55), false], 3129: ["human", Color(0.2, 0.3, 0.55), false],
	3192: ["human", Color(0.2, 0.3, 0.55), true], 5809: ["human", Color(0.2, 0.3, 0.55), true],
	3183: ["orc", Color(0.3, 0.08, 0.08), false], 3195: ["orc", Color(0.3, 0.08, 0.08), false],
	3196: ["orc", Color(0.3, 0.08, 0.08), false], 3197: ["orc", Color(0.3, 0.08, 0.08), true],
	3198: ["orc", Color(0.3, 0.08, 0.08), false], 3199: ["orc", Color(0.3, 0.08, 0.08), false],
	3203: ["orc", Color(0.3, 0.08, 0.08), true], 3204: ["orc", Color(0.3, 0.08, 0.08), true],
	5822: ["orc", Color(0.3, 0.08, 0.08), true],
	3205: ["troll", Color(0.35, 0.2, 0.45), true], 3206: ["troll", Color(0.35, 0.2, 0.45), false],
	3207: ["troll", Color(0.35, 0.2, 0.45), false],
	1501: ["undead", Color(0.3, 0.28, 0.26), false],
	1502: ["undead", Color(0.3, 0.28, 0.26), false],
	1890: ["undead", Color(0.3, 0.28, 0.26), false],
	1520: ["undead", Color(0.3, 0.28, 0.26), false],
	1522: ["undead", Color(0.3, 0.28, 0.26), false],
	1523: ["undead", Color(0.3, 0.28, 0.26), false],
	1525: ["undead", Color(0.3, 0.28, 0.26), false],
	1526: ["undead", Color(0.3, 0.28, 0.26), false],
	1529: ["undead", Color(0.3, 0.28, 0.26), false],
	1532: ["undead", Color(0.3, 0.28, 0.26), false],
	1534: ["undead", Color(0.3, 0.28, 0.26), false],
	1530: ["undead", Color(0.3, 0.28, 0.26), false],
	1531: ["undead", Color(0.3, 0.28, 0.26), false],
	1658: ["undead", Color(0.3, 0.28, 0.26), false],
	1654: ["undead", Color(0.3, 0.28, 0.26), false],
	1655: ["undead", Color(0.3, 0.28, 0.26), false],
	1656: ["undead", Color(0.3, 0.28, 0.26), false],
	1657: ["undead", Color(0.3, 0.28, 0.26), false],
	1506: ["human", Color(0.62, 0.12, 0.1), false],
	1507: ["human", Color(0.62, 0.12, 0.1), false],
	1667: ["human", Color(0.62, 0.12, 0.1), false],
	1535: ["human", Color(0.62, 0.12, 0.1), false],
	1536: ["human", Color(0.62, 0.12, 0.1), false],
	1537: ["human", Color(0.62, 0.12, 0.1), false],
	1538: ["human", Color(0.62, 0.12, 0.1), false],
	1539: ["human", Color(0.62, 0.12, 0.1), false],
	1540: ["human", Color(0.62, 0.12, 0.1), false],
	1660: ["human", Color(0.62, 0.12, 0.1), true],
	1662: ["human", Color(0.62, 0.12, 0.1), true],
	1664: ["human", Color(0.62, 0.12, 0.1), true],
	1665: ["human", Color(0.62, 0.12, 0.1), true],
	1934: ["human", Color(0.42, 0.32, 0.2), false],
	1935: ["human", Color(0.42, 0.32, 0.2), false],
	1936: ["human", Color(0.42, 0.32, 0.2), false],
	2978: ["gnome", Color(0.5, 0.4, 0.25), false],
	2979: ["gnome", Color(0.5, 0.4, 0.25), false],
	3051: ["gnome", Color(0.5, 0.4, 0.25), false],
	706: ["troll", Color(0.62, 0.64, 0.68), false],
	946: ["troll", Color(0.62, 0.64, 0.68), false],
	808: ["troll", Color(0.62, 0.64, 0.68), false],
	1120: ["troll", Color(0.62, 0.64, 0.68), false],
	1121: ["troll", Color(0.62, 0.64, 0.68), false],
	1123: ["troll", Color(0.62, 0.64, 0.68), false],
	1122: ["troll", Color(0.62, 0.64, 0.68), false],
	1124: ["troll", Color(0.62, 0.64, 0.68), false],
	1397: ["troll", Color(0.62, 0.64, 0.68), false],
	1260: ["troll", Color(0.62, 0.64, 0.68), false],
}
## Other creatures with models: entry -> [model, props]. Beasts (wolf, boar,
## bear, spider) are BeastModels coloured by their LOOKS colour; humanoid
## creatures (burrowling, mirefin, ditchjaw) are HumanoidModels of their own
## race with props as in HUMAN_CREATURES.
const CREATURE_MODELS := {
	299: ["wolf", {}], 69: ["wolf", {}], 525: ["wolf", {}], 1922: ["wolf", {}], 118: ["wolf", {}],
	113: ["boar", {}], 524: ["boar", {}], 390: ["boar", {}], 330: ["boar", {}],
	822: ["bear", {}],
	30: ["spider", {}], 43: ["spider", {}],
	6: ["burrowling", { "main": "dagger" }], 257: ["burrowling", { "main": "axe" }], 80: ["burrowling", { "main": "mace" }],
	40: ["burrowling", { "main": "axe" }], 475: ["burrowling", { "main": "sword" }], 476: ["burrowling", { "main": "staff" }],
	327: ["burrowling", { "main": "axe", "off": "Shield_round" }],
	285: ["mirefin", { "main": "polearm" }], 735: ["mirefin", { "main": "polearm" }], 732: ["mirefin", { "main": "dagger" }],
	46: ["mirefin", { "main": "" }],
	97: ["ditchjaw", { "main": "axe" }], 117: ["ditchjaw", { "main": "axe2h" }], 478: ["ditchjaw", { "main": "polearm" }],
	448: ["ditchjaw", { "main": "axe2h" }],
	# Kareth's boars, scorpions, crabs (the clawfolk too), tigers (and the
	# ashstalker), lizards (and the crocodile), tuskfolk and imps.
	3098: ["boar", {}], 3099: ["boar", {}], 3100: ["boar", {}],
	3124: ["scorpion", {}], 3125: ["scorpion", {}], 3126: ["scorpion", {}], 3127: ["scorpion", {}],
	5823: ["scorpion", {}], 3281: ["scorpion", {}],
	3106: ["crab", {}], 3107: ["crab", {}], 3108: ["crab", {}],
	3103: ["crab", {}], 3104: ["crab", {}], 3105: ["crab", {}], 3141: ["crab", {}],
	3121: ["tiger", {}], 3102: ["tiger", {}],
	3130: ["thunder_lizard", {}], 3131: ["thunder_lizard", {}], 3110: ["thunder_lizard", {}],
	3111: ["tuskfolk", { "main": "axe" }], 3112: ["tuskfolk", { "main": "polearm" }],
	3113: ["tuskfolk", { "main": "staff" }], 3114: ["tuskfolk", { "main": "axe", "off": "Shield_round" }],
	5826: ["tuskfolk", { "main": "staff" }], 5824: ["tuskfolk", { "main": "axe2h" }],
	3101: ["imp", { "main": "" }],
	# Aldmark's north and Kareth's west.
	1508: ["wolf", {}],
	1509: ["wolf", {}],
	1547: ["wolf", {}],
	1548: ["wolf", {}],
	1549: ["wolf", {}],
	10356: ["wolf", {}],
	2958: ["wolf", {}],
	2959: ["wolf", {}],
	2960: ["wolf", {}],
	3056: ["wolf", {}],
	1504: ["spider", {}],
	1505: ["spider", {}],
	1688: ["spider", {}],
	1555: ["spider", {}],
	1674: ["ditchjaw", { "main": "axe" }],
	1675: ["ditchjaw", { "main": "axe" }],
	1941: ["ditchjaw", { "main": "axe" }],
	1753: ["ditchjaw", { "main": "axe" }],
	2949: ["ditchjaw", { "main": "axe" }],
	2950: ["ditchjaw", { "main": "axe" }],
	2951: ["ditchjaw", { "main": "axe" }],
	5786: ["ditchjaw", { "main": "axe" }],
	1543: ["mirefin", { "main": "polearm" }],
	1544: ["mirefin", { "main": "polearm" }],
	1545: ["mirefin", { "main": "polearm" }],
	1909: ["mirefin", { "main": "polearm" }],
	1957: ["mirefin", { "main": "polearm" }],
	1958: ["mirefin", { "main": "polearm" }],
	1910: ["mirefin", { "main": "polearm" }],
	2961: ["tiger", {}],
	3035: ["tiger", {}],
	3566: ["tiger", {}],
	2966: ["boar", {}],
	2954: ["boar", {}],
	2952: ["tuskfolk", { "main": "axe" }],
	2953: ["tuskfolk", { "main": "axe" }],
	3229: ["tuskfolk", { "main": "axe" }],
	8554: ["tuskfolk", { "main": "axe" }],
	3232: ["tuskfolk", { "main": "axe" }],
	# Aldmark's mountains and Kareth's north-west.
	705: ["wolf", {}],
	704: ["wolf", {}],
	1131: ["wolf", {}],
	1138: ["wolf", {}],
	1133: ["wolf", {}],
	1132: ["wolf", {}],
	708: ["boar", {}],
	1125: ["boar", {}],
	1126: ["boar", {}],
	1127: ["boar", {}],
	1689: ["boar", {}],
	1984: ["boar", {}],
	1985: ["boar", {}],
	1128: ["bear", {}],
	1196: ["bear", {}],
	1130: ["bear", {}],
	1961: ["bear", {}],
	1134: ["bear", {}],
	1135: ["bear", {}],
	1137: ["bear", {}],
	1271: ["bear", {}],
	1388: ["bear", {}],
	1199: ["tiger", {}],
	1201: ["tiger", {}],
	2031: ["tiger", {}],
	2032: ["tiger", {}],
	2042: ["tiger", {}],
	2043: ["tiger", {}],
	2033: ["tiger", {}],
	2034: ["tiger", {}],
	14430: ["tiger", {}],
	1986: ["spider", {}],
	1994: ["spider", {}],
	1998: ["spider", {}],
	1999: ["spider", {}],
	2000: ["spider", {}],
	2001: ["spider", {}],
	707: ["dwarf", { "main": "mace" }],
	724: ["dwarf", { "main": "mace2h" }],
	1718: ["dwarf", { "main": "axe" }],
	1115: ["dwarf", { "main": "mace" }],
	1116: ["dwarf", { "main": "dagger" }],
	1117: ["dwarf", { "main": "axe" }],
	1118: ["dwarf", { "main": "mace2h" }],
	1119: ["dwarf", { "main": "mace2h" }],
	1211: ["gnome", { "main": "" }],
	8503: ["gnome", { "main": "mace" }],
	1988: ["imp", { "main": "" }],
	1989: ["imp", { "main": "" }],
	2002: ["imp", { "main": "" }],
	2003: ["imp", { "main": "" }],
	2004: ["imp", { "main": "" }],
	2005: ["imp", { "main": "" }],
	2038: ["imp", { "main": "staff" }],
	14432: ["imp", { "main": "" }],
	2006: ["ditchjaw", { "main": "" }],
	2007: ["ditchjaw", { "main": "staff" }],
	2008: ["ditchjaw", { "main": "mace" }],
	7235: ["ditchjaw", { "main": "staff" }],
	7234: ["ditchjaw", { "main": "mace2h" }],
	2152: ["ditchjaw", { "main": "axe" }],
	2009: ["ditchjaw", { "main": "staff" }],
	2010: ["ditchjaw", { "main": "mace", "off": "Shield_round" }],
	2011: ["ditchjaw", { "main": "staff" }],
	2012: ["ditchjaw", { "main": "axe" }],
	2013: ["ditchjaw", { "main": "mace" }],
	2014: ["ditchjaw", { "main": "staff" }],
	2039: ["ditchjaw", { "main": "mace2h" }],
	14429: ["ditchjaw", { "main": "axe2h" }],
	14428: ["ditchjaw", { "main": "mace2h" }],
}
## How big each model is at scale 1, in LOOKS' terms, so a creature's model
## is scaled by its LOOKS size over this.
const MODEL_BASE_SIZE := { "wolf": 0.9, "boar": 1.0, "bear": 1.15, "spider": 0.75, "burrowling": 0.75, "mirefin": 0.9, "ditchjaw": 1.0,
	"scorpion": 0.8, "crab": 0.75, "tiger": 1.0, "thunder_lizard": 1.2, "tuskfolk": 0.95, "imp": 0.6,
	"dwarf": 0.9, "gnome": 0.65 }
const BEASTS := ["wolf", "boar", "bear", "spider", "scorpion", "crab", "tiger", "thunder_lizard"]
const BRIGAND_RED := Color(0.55, 0.12, 0.1)
## The creature's model (HumanoidModel or BeastModel), for HUMAN_CREATURES
## and CREATURE_MODELS.
var model: Node3D


func _apply_look() -> void:
	# Out of the target ring's projection (models mark their own meshes).
	Targeting.mark_unit(_visual)
	if HUMAN_CREATURES.has(creature_entry):
		_apply_human_look()
		return
	if CREATURE_MODELS.has(creature_entry):
		_apply_creature_model()
		return
	var look: Array = LOOKS.get(creature_entry, [Vector3.ONE, Color(0.75, 0.25, 0.25)])
	var body: MeshInstance3D = $Visual/Body
	var skin := StandardMaterial3D.new()
	skin.albedo_color = look[1]
	body.material_override = skin
	if int(_data.CreatureType) == CREATURE_TYPE_BEAST:
		# On all fours: the capsule lies along the facing direction.
		body.rotation.x = PI / 2
		body.position = Vector3(0, 0.5, 0)
		$Visual/Nose.position = Vector3(0, 0.6, -1.0)
		# Dead beasts roll onto their side rather than tipping up on end.
		_feedback.fall_axis = "z"
	_visual.scale = look[0]


## A beast or humanoid creature of CREATURE_MODELS: its own model, sized by its
## LOOKS size and coloured by its LOOKS colour.
func _apply_creature_model() -> void:
	for part in ["Body", "Nose"]:
		get_node("Visual/" + part).visible = false
	var look: Array = LOOKS.get(creature_entry, [Vector3.ONE, Color(0.6, 0.5, 0.4)])
	var kind: String = CREATURE_MODELS[creature_entry][0]
	_visual.scale = Vector3.ONE * (float(look[0].x) / float(MODEL_BASE_SIZE[kind]))
	if model:
		return
	var color: Color = look[1]
	if kind in BEASTS:
		var beast := BeastModel.new()
		beast.species = kind
		beast.colors = BeastModel.coat_colors(color, kind)
		model = beast
		_visual.add_child(beast)
		beast.attach_creature(self, combatant)
		return
	var creature := HumanoidModel.new()
	creature.race = kind
	creature.set_appearance({ "body": 0, "skin": 0, "hair": 3, "hair_color": 0, "face": 0 })
	creature.skin_override = color
	creature.creature_gear = CREATURE_MODELS[creature_entry][1]
	# Rags: a dark loincloth and, on the furred ones, a vest.
	var rag := color.darkened(0.55)
	creature.outfit = { HumanoidModel.CHEST: color if kind == "mirefin" else rag.lightened(0.15), HumanoidModel.LEGS: rag,
		HumanoidModel.FEET: color, HumanoidModel.HANDS: color, HumanoidModel.WAIST: rag.darkened(0.2),
		HumanoidModel.HAIR: color.darkened(0.4) }
	model = creature
	_visual.add_child(creature)
	creature.attach_creature(self, combatant)


func _apply_human_look() -> void:
	for part in ["Body", "Nose"]:
		get_node("Visual/" + part).visible = false
	_visual.scale = Vector3.ONE
	if model:
		return
	var gear: Dictionary = HUMAN_CREATURES[creature_entry]
	var kind: Array = CREATURE_RACES.get(creature_entry, ["human", BRIGAND_RED, true])
	var human := HumanoidModel.new()
	human.race = kind[0]
	# Each brigand its own face: seeded by its place in the world.
	var seed_value := hash(str(name) + str(creature_entry))
	var look := HumanoidModel.random_appearance(seed_value)
	look.body = 0 if seed_value % 4 != 0 else 1
	human.set_appearance(look)
	human.creature_gear = gear
	var outfit := HumanoidModel.outfit_for("", seed_value)
	var band: Color = kind[1]
	outfit[HumanoidModel.HEAD] = band
	outfit[HumanoidModel.CHEST] = HumanoidModel.LEATHER[absi(seed_value) % HumanoidModel.LEATHER.size()] if band == BRIGAND_RED else band
	outfit[HumanoidModel.LEGS] = Color(0.22, 0.2, 0.2)
	if not gear.has("helm") and kind[2]:
		outfit[HumanoidModel.BACK] = band
	human.outfit = outfit
	model = human
	_visual.add_child(human)
	human.attach_creature(self, combatant)


func face_toward(point: Vector3) -> void:
	_face(point)


func _face(point: Vector3) -> void:
	var offset := point - global_position
	_visual.rotation.y = atan2(-offset.x, -offset.z)


func _is_facing(point: Vector3) -> bool:
	var forward := _visual.global_basis * Vector3.FORWARD
	var offset := point - global_position
	return Vector2(forward.x, forward.z).dot(Vector2(offset.x, offset.z)) >= 0.0


## Pulled: it chases, and creatures of its faction close by may join in.
func _start_chase(enemy: Combatant = null) -> void:
	Sfx.play_at("aggro", global_position)
	var pulled := state == State.IDLE
	state = State.CHASE
	if pulled and enemy:
		_mark_assistance(enemy)


func _update_assistance(delta: float) -> void:
	if _assist_left < 0.0:
		return
	_assist_left -= delta
	if _assist_left > 0.0:
		return
	_assist_left = -1.0
	if is_instance_valid(_assist_enemy) and _assist_enemy.is_alive():
		for other in _assist_receivers:
			if is_instance_valid(other):
				other._join(_assist_enemy)
	_assist_receivers.clear()


## Calling for help on a pull (Creature::MarkCallAssistanceOnPull and
## Unit::TriggerAggroLinkingEvent in CMaNGOS): creatures of the same faction
## within its call-for-help radius (5 yards unless the data gives one) that
## see it, aren't fighting and attack on sight are noted now, and join the
## fight 2 s later if it's still going. Their own pulls can bring in more.
func _mark_assistance(enemy: Combatant) -> void:
	_assist_enemy = enemy
	_assist_receivers = _helpers(_assist_radius())
	_assist_left = ASSIST_DELAY if not _assist_receivers.is_empty() else -1.0


func _assist_radius() -> float:
	var radius := float(_data.get("CallForHelp", 0))
	return radius if radius > 0.0 else ASSIST_RADIUS


## Creatures that would come to its aid: same faction, alive, not fighting,
## not passive, within the radius and in sight.
func _helpers(radius: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var faction := int(_data.get("Faction", 0))
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == self or other.state != State.IDLE or not other.combatant.is_alive() or not other.is_aggressive():
			continue
		if int(other._data.get("Faction", -1)) != faction or global_position.distance_to(other.global_position) > radius:
			continue
		var eye := Vector3.UP * 1.0
		var query := PhysicsRayQueryParameters3D.create(global_position + eye, other.global_position + eye, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			found.append(other)
	return found


## Called for help (EventAI ACTION_T_CALL_FOR_HELP, Creature::CallForHelp):
## creatures of its faction within the radius join the fight now.
func call_for_help(radius: float) -> void:
	var victim := current_victim()
	if victim == null:
		return
	for other in _helpers(radius if radius > 0.0 else _assist_radius()):
		other._join(victim)


func _join(enemy: Combatant) -> void:
	if state != State.IDLE or not combatant.is_alive() or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	add_threat(enemy, 0.0)
	_start_chase(enemy)


## Runs off in a panic for a while (EventAI ACTION_T_FLEE_FOR_ASSIST, at low
## health for creatures the data scripts that way): it doesn't fight, then
## comes back. Returns whether it could.
func flee(duration: float) -> bool:
	if state != State.CHASE or combatant.is_stunned() or combatant.is_rooted():
		return false
	panic_left = duration
	Chat.monster(combatant.display_name, "tries to run away in fear!", global_position, true)
	return true


func _start_return() -> void:
	state = State.RETURN
	combatant.attack_target = null
	combatant.invulnerable = true
	threat.clear()
	tapped_by = null
	_victim = null
	panic_left = 0.0
	_assist_left = -1.0
	if ai:
		ai.on_leave_combat()


## Adds threat on a player unit, putting it on the threat list.
func add_threat(unit: Combatant, amount: float) -> void:
	if unit == null or not unit.is_player or state == State.DEAD:
		return
	threat[unit] = threat.get(unit, 0.0) + amount


## The living unit with the most threat, keeping the current victim until
## another passes it by the classic margin.
func _pick_victim() -> Combatant:
	# Untyped: a playerbot that left the world is a freed key.
	for unit in threat.keys():
		if not is_instance_valid(unit) or not (unit as Combatant).is_alive():
			threat.erase(unit)
	if not is_instance_valid(_victim):
		_victim = null
	if threat.is_empty():
		return null
	# A taunt holds it on the taunter while it lasts.
	var taunter := combatant.taunted_by()
	if taunter and threat.has(taunter):
		return taunter
	var best: Combatant = null
	for unit: Combatant in threat:
		if best == null or _threat_of(unit) > _threat_of(best):
			best = unit
	if _victim and threat.has(_victim) and best != _victim:
		var margin := THREAT_SWITCH_MELEE if combatant.distance_to(best) <= combatant.melee_range else THREAT_SWITCH_RANGED
		if _threat_of(best) <= _threat_of(_victim) * margin:
			return _victim
	return best


## Goad: the taunter's threat rises to the top of the list (Spell::EffectTaunt),
## and it attacks them.
func taunt(unit: Combatant) -> void:
	_on_attacked(unit, 0)
	var top := 0.0
	for other: Combatant in threat:
		if is_instance_valid(other):
			top = maxf(top, threat[other])
	threat[unit] = maxf(threat.get(unit, 0.0), top)
	_victim = unit


## Threat on a unit, less what Veil of Humility hides for as long as it lasts
## (SPELL_AURA_MOD_TOTAL_THREAT).
func _threat_of(unit: Combatant) -> float:
	return threat[unit] + unit.aura_total(SpellDB.AURA_MOD_TOTAL_THREAT)


## Who it's fighting now, or null.
func current_victim() -> Combatant:
	return _victim if is_instance_valid(_victim) else null


## A player unit left the world (a playerbot removed): off the threat list.
func forget(unit: Combatant) -> void:
	threat.erase(unit)
	if _victim == unit:
		_victim = null
		combatant.attack_target = null
	if tapped_by == unit:
		tapped_by = null


## Healing a unit draws threat from every creature fighting it, half the
## amount healed, split between them.
static func add_heal_threat(healed: Combatant, healer: Combatant, amount: int) -> void:
	var fighting: Array[Enemy] = []
	for node in healed.get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.state == State.CHASE and enemy.threat.has(healed):
			fighting.append(enemy)
	for enemy in fighting:
		enemy.add_threat(healer, amount * HEAL_THREAT * healer.threat_multiplier(SpellDB.School.HOLY) / fighting.size())


## Whether someone outside the player's group tapped it: grey to the player.
func is_tapped_by_others() -> bool:
	return tapped_by != null and is_instance_valid(tapped_by) and not Party.has_unit(tapped_by)


## Whether this creature attacks the player on sight. Neutral creatures,
## hostile ones flagged to wait, and ones set `passive` only fight back.
func is_aggressive() -> bool:
	return not passive and ClassicData.aggressive(_data, GameState.race)


## A harmful spell without damage (a fear, a slow) landed: the creature
## fights back as if hit.
func provoke(source: Combatant) -> void:
	_on_attacked(source, 0)


func _on_attacked(source: Combatant, damage: int) -> void:
	if source == null or not source.is_player or state == State.RETURN or state == State.DEAD:
		return
	if tapped_by == null or not is_instance_valid(tapped_by):
		tapped_by = source
	# Stances change how much threat damage causes.
	add_threat(source, float(damage) * source.threat_multiplier(combatant.last_hit_school))
	if state == State.IDLE:
		_start_chase(source)


## Classic aggro radius: about 20 yards at equal level, one yard less per level
## the player is above it and one more per level below (counted up to 25),
## never under 5 yards. From Creature::GetAttackDistance in CMaNGOS.
## Calm Mind shortens it (SPELL_AURA_MOD_DETECT_RANGE).
func aggro_radius(player_level: int) -> float:
	var level_difference := maxi(player_level - level, -25)
	return maxf(maxf(20.0 - level_difference, 5.0) + combatant.aura_total(SpellDB.AURA_MOD_DETECT_RANGE), 0.0)


func has_loot() -> bool:
	return state == State.DEAD and (loot_money > 0 or not loot.is_empty())


## Level is rolled between the template's min and max, with health scaled
## linearly between the min-level and max-level values.
func _roll_level() -> void:
	if level_override > 0 or rank_override > 0:
		_scale_to_level(level_override if level_override > 0 else int(_data.MinLevel))
		return
	var min_level := int(_data.MinLevel)
	var max_level := int(_data.MaxLevel)
	level = randi_range(min_level, max_level)
	var t := 0.0 if max_level == min_level else float(level - min_level) / (max_level - min_level)
	combatant.level = level
	combatant.max_health = roundi(lerpf(_data.MinLevelHealth, _data.MaxLevelHealth, t))
	combatant.max_mana = roundi(lerpf(_data.get("MinLevelMana", 0), _data.get("MaxLevelMana", 0), t))
	combatant.reset()


## A creature made at any level: its class's base stats at that level, as
## CMaNGOS's Creature::SelectLevel works them out from
## creature_template_classlevelstats with every multiplier 1 (health, mana,
## armor; damage from base damage to 1.5 times it, plus attack power / 14 per
## second of swing, added in Combatant), then a spawned rank's multipliers.
## The template still gives its class, look, spells, speed and faction.
func _scale_to_level(new_level: int) -> void:
	if _class_stats.is_empty():
		_class_stats = JSON.parse_string(FileAccess.get_file_as_string(CLASS_STATS_PATH))
	var table: Array = _class_stats.get(str(int(_data.get("UnitClass", 1))), _class_stats.get("1"))
	level = clampi(new_level, 1, table.size())
	var row: Array = table[level - 1]
	var health_mod: float = RANK_HEALTH.get(rank_override, 1.0)
	var damage_mod: float = RANK_DAMAGE.get(rank_override, 1.0)
	var c := combatant
	c.level = level
	c.max_health = maxi(roundi(float(row[0]) * health_mod), 1)
	c.max_mana = int(row[1])
	c.min_damage = float(row[2]) * damage_mod
	c.max_damage = float(row[2]) * 1.5 * damage_mod
	c.attack_power = roundi(float(row[3]) * damage_mod)
	c.armor = int(row[4])
	c.reset()


func _on_died() -> void:
	state = State.DEAD
	collision_layer = CORPSE_LAYER
	_fit_corpse_shape()
	# The tapping unit's group gets the kill. Loot is only kept for the
	# player's group: bots don't loot.
	if Party.reward_kill(self, tapped_by if tapped_by and is_instance_valid(tapped_by) else null):
		loot = LootTable.roll_creature(int(_data.LootId))
		loot_money = LootTable.roll_money(int(_data.MinLootGold), int(_data.MaxLootGold))
	threat.clear()
	_victim = null
	panic_left = 0.0
	_assist_left = -1.0
	if ai:
		ai.on_leave_combat()
	_sparkle.visible = has_loot()
	respawn_at = Time.get_unix_time_from_system() + respawn_time


## Saved state for a dead enemy, or {} while it's alive.
func corpse_state() -> Dictionary:
	if state != State.DEAD or temporary:
		return {}
	var p := global_position
	return {
		"respawn_at": respawn_at, "level": level, "position": [p.x, p.y, p.z],
		"facing": _visual.rotation.y, "loot": loot, "money": loot_money,
	}


## Puts back a corpse from the save, unless its respawn time has passed.
func restore_corpse(saved: Dictionary) -> void:
	if float(saved.respawn_at) <= Time.get_unix_time_from_system():
		return
	level = int(saved.level)
	combatant.level = level
	combatant.health = 0
	state = State.DEAD
	collision_layer = CORPSE_LAYER
	var at: Array = saved.position
	global_position = Vector3(at[0], at[1], at[2])
	_visual.rotation.y = float(saved.facing)
	loot.assign(saved.loot.map(func(drop: Dictionary) -> Dictionary: return { "id": int(drop.id), "count": int(drop.count) }))
	loot_money = int(saved.money)
	respawn_at = float(saved.respawn_at)
	_feedback.show_dead()
	_fit_corpse_shape()


## Corpses lie down, so clicks (and loot) need a shape around the fallen body,
## not the standing capsule: a box around its meshes in their final pose.
func _fit_corpse_shape() -> void:
	var fall := Vector3(0.0, _visual.rotation.y, -PI / 2.0) if _feedback.fall_axis == "z" else Vector3(-PI / 2.0, _visual.rotation.y, 0.0)
	var fallen := Transform3D(Basis.from_euler(fall) * Basis.from_scale(_visual.scale), Vector3.ZERO)
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		if mesh == _sparkle or _sparkle.is_ancestor_of(mesh):
			continue
		# The mesh's place in the visual, in the visual's fallen pose.
		var box := fallen * (_visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	# Half the fallen body is below the feet; the box stays above the ground.
	var bottom := maxf(bounds.position.y, 0.0)
	bounds.size.y = maxf(bounds.end.y - bottom, 0.3)
	bounds.position.y = bottom
	var shape := BoxShape3D.new()
	shape.size = bounds.size + Vector3.ONE * CORPSE_CLICK_MARGIN
	_collision.shape = shape
	_collision.transform = Transform3D(Basis.IDENTITY, bounds.get_center())


func _process(delta: float) -> void:
	if state == State.DEAD and Time.get_unix_time_from_system() >= respawn_at:
		if temporary:
			queue_free()
			return
		_respawn()
	_sparkle.visible = has_loot()
	if _sparkle.visible:
		_sparkle.rotate_y(SPARKLE_SPIN * delta)


func _respawn() -> void:
	global_position = _home
	_wander_target = _home
	velocity = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_feedback.reset()
	collision_layer = UNIT_LAYER
	_collision.shape = _standing_shape
	_collision.transform = _standing_transform
	loot.clear()
	loot_money = 0
	threat.clear()
	tapped_by = null
	_roll_level()
	state = State.IDLE
	if ai:
		ai.on_spawn()


## Gold cubes over a corpse that still has loot, standing in for WoW's sparkles.
func _build_sparkle() -> Node3D:
	var sparkle := Node3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.12
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.85, 0.3)
	mesh.material = material
	for i in 4:
		var cube := MeshInstance3D.new()
		cube.mesh = mesh
		cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * i / 4.0
		cube.position = Vector3(cos(angle) * 0.6, 0.4 + 0.15 * (i % 2), sin(angle) * 0.6)
		sparkle.add_child(cube)
	sparkle.visible = false
	add_child(sparkle)
	return sparkle
