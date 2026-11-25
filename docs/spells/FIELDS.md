# Spell design fields

Every class's spells and talents are in a design file, `data/designs/<class>.json`
(`man_at_arms`, `templar`, `ranger`, `cleric`, `spellsword`). The game reads them when it
starts (`SpellDesigns`, over classic's data), so an edit to a file takes effect on the next
start or on the dev console's `reload`. The Developer tab's **Edit Spells...** edits them in
the game: Apply Live takes effect at once, Save writes the file.

Every name a field takes, and what each name does, is in [NAMES.md](NAMES.md); anywhere a
name goes, its number works too.

Many fields come from classic's spell data (CMaNGOS's `spell_template`) and are kept so the
spells stay faithful to it. Not all of them do anything in the game yet: those are marked
**not read** below. Changing a not-read field changes nothing until code reads it.

Problems in a design (an unknown field or name, a talent rank with no spell) are printed
as warnings when the game starts, and listed by the spell editor. To see what your designs
change from classic's data, run the check:

```
<console exe> --headless --path C:/ai-rpg -s res://tools/spells/export_designs.gd
```

`-- --export` rewrites every design file from classic's data, **losing your edits**: use it
only to start over.

`-- --add-missing` adds to each design file the spells its own spells trigger (a proc's buff,
a periodic trigger's spell) that it doesn't hold yet, from classic's data, after your spells,
changing nothing else. Groups whose name one of your groups already has are marked
"(triggered)".

## A design file

```json
{
	"class": 1,
	"trainer": "warrior",
	"spells": [ ...spell groups... ],
	"talents": [ ...talent trees... ],
	"start_spells": { "1-1": [78, 2457] }
}
```

| Field | What it does |
|---|---|
| `class` | Which class the file is for (1 Man-at-Arms, 2 Templar, 3 Ranger, 5 Cleric, 10 Spellsword). Its talent trees, spellbook tabs and start spells are filed under this number. |
| `trainer` | The name of the class trainer's list (`warrior`, `paladin`, `hunter`, `priest`, `spellsword`). Every rank with a `trainer` entry is sold from this list by the class's trainers. |
| `spells` | The class's spells, each a group of ranks (below). Talent ranks are spells too, and go here. |
| `talents` | The talent trees shown in the talent window (N), left to right (below). |
| `start_spells` | What a new character knows, by `"<race>-<class>"` (race and class numbers): a list of spell ids. `"1-1"` is a Human Man-at-Arms. |
| `trainer_extra` | Trainer entries teaching something that isn't one of the file's spells (a spell kept in classic's data), sold as they are. |
| `book_tabs_extra` | Spellbook tabs for spells not in the file: spell id to tab. |

## A spell group

A spell and its ranks, lowest first.

```json
{ "name": "Mighty Blow", "ranks": [ { ...rank 1... }, { ...rank 2... } ] }
```

| Field | What it does |
|---|---|
| `name` | The spell's name, for reading the file and the spell editor's list. Each rank has its own `name`, which is what the game shows. |
| `ranks` | Each rank's spell, lowest first. They form a chain: learning a rank replaces the one before it on the action bar, and "Hide old ranks" in the spellbook hides the lower ones. |
| `tags` | Names for the spell that talents can use, given to every rank (see Tags below). | `"tags": ["radiant_strike"]` |
| `chain` | `false` when the ranks aren't a chain: each is a spell of its own, none replacing another. Classic's Man-at-Arms spells are like that. [true] |

## A spell (one rank)

Only `id` and `name` are needed. Everything else has a default, shown in brackets.

### Who it is

| Field | What it does | Example |
|---|---|---|
| `id` | The spell's number, which saves, action bars and other spells use. It must be unique. Use 950000 and up for new spells. | `"id": 78` |
| `name` | The name shown in the spellbook, tooltips, buff bar and combat. | `"name": "Mighty Blow"` |
| `rank` | Shown as "Rank 3" under the name. | `"rank": 3` |
| `rank_text` | Text shown in place of a rank, such as "Passive" or "Racial". | `"rank_text": "Passive"` |
| `text` | The tooltip's description, in place of the one SpellText writes. Placeholders in braces are filled in from the spell's own numbers at your level, so the text stays right when its values change (see Tooltip text below). | `"text": "Strikes for {amount1} more damage."` |
| `icon` | Which painted icon it shows (a key from `assets/icons/`). Without it, one is picked by name. | `"icon": "strike"` |
| `icon_id` | Classic's icon number. **Not read** (the game's icons are its own). | `"icon_id": 856` |

### Learning it

| Field | What it does | Example |
|---|---|---|
| `level` | The spell's level: the level a character needs to learn it, and what level-scaled amounts start from. [0] | `"level": 8` |
| `base_level` | The level its `per_level` growth counts from. [0] | `"base_level": 8` |
| `max_level` | The level its `per_level` growth stops at. A creature spell with `level_damage_calculation` scales to this. [0, no cap] | `"max_level": 20` |
| `trainer` | Makes the class trainer sell it. `level`: the character level it's offered from. `price`: in copper. `quest: true`: free, as a class-quest spell. `races`: race numbers that may learn it (racial spells). `teach`: classic's teaching spell id, kept as it is. `also`: more spell ids learned with it. | `"trainer": { "level": 8, "price": 200 }` |
| `book_tab` | Its spellbook tab: 0 General, 1-3 the talent trees in order. Spells with no tab aren't in the spellbook. | `"book_tab": 0` |

### Casting it

| Field | What it does | Example |
|---|---|---|
| `school` | Its magic school. This decides which resistance lowers it, which school-based buffs and talents change it, and its effects' colours. [physical] | `"school": "fire"` |
| `damage_class` | How it lands. `magic` rolls spell hit and crit and takes spell power. `melee` and `ranged` roll the weapon tables and take attack power; they also draw the matching weapon and don't sheathe it. `none` can't miss or crit. [none] | `"damage_class": "melee"` |
| `power` | What it costs. [mana] | `"power": "rage"` |
| `cost` | The cost in its power's points (rage in whole points). [0] | `"cost": 15` |
| `cost_percent` | The cost as a percentage of base mana. It replaces `cost` for mana spells. [0] | `"cost_percent": 8` |
| `cast` | Cast time in seconds. With a cast time, the caster stands still, can be pushed back, and puts weapons away. [0, instant] | `"cast": 2.5` |
| `cooldown` | Its own cooldown, seconds. [0] | `"cooldown": 6` |
| `category` / `category_cooldown` | A shared cooldown. Casting it puts every spell of the same `category` on `category_cooldown` seconds. | `"category": 107, "category_cooldown": 30` |
| `gcd` | The global cooldown it starts, seconds (1.5 for most spells, 1 for some abilities). [0] | `"gcd": 1.5` |
| `gcd_category` | Classic's global cooldown category. **Not read.** | `"gcd_category": 133` |
| `range` | How far away the target may be, yards. [self only] | `"range": 30` |
| `min_range` | How near the target may be, yards (Rush, shots' dead zone). [0] | `"min_range": 8` |
| `duration` | How long its auras last, seconds, or `"until_cancelled"`. Class buffs of 5 minutes or more last an hour in the game. | `"duration": 30` |
| `speed` | Flight speed, yards a second: the spell flies as a bolt and lands on arrival. [0, lands at once] | `"speed": 20` |
| `prevention` | What stops it being cast: 1 silence (spells), 2 pacify (abilities). Creatures' spells use this too. [0] | `"prevention": 1` |
| `interrupt_flags` | Classic's mask of what disturbs the cast. The game reads two bits: 0x2, being hit pushes the cast back; 0x8, interrupt effects can cut it (creature spells). | `"interrupt_flags": 15` |
| `aura_interrupt_flags` | Classic's mask of what ends its aura early. The game reads two bits: 0x2, taking damage ends it (fear breaking); 0x80, standing up ends it (eating and drinking). | `"aura_interrupt_flags": 128` |
| `target_flags` | Classic's mask of what it may target. **Not read** (the effects' `target` decides). | `"target_flags": 2` |
| `cast_index`, `duration_index`, `range_index` | Classic's table numbers for cast time, duration and range. They're written only when the time or reach isn't a known one. Prefer `cast`, `duration` and `range`. | `"cast_index": 14` |

### What it needs

| Field | What it does | Example |
|---|---|---|
| `stances` | The forms or stances the caster must be in, as a list. With none, any form works. | `"stances": ["vanguard", "bastion"]` |
| `requires_item` | What must be equipped: `weapon` (a weapon of the `item_types` held) or `armor` (a shield for Shield Smash and the like). | `"requires_item": "weapon"` |
| `item_types` | Which weapon or armour types count (a list), or `"all"`. For a passive talent, it's the gear the talent needs to work. For a proficiency spell, it's the gear it lets you use. | `"item_types": ["sword", "axe"]` |
| `item_slots` | Classic's mask of equipment slots it needs. **Not read.** | `"item_slots": 32` |
| `creature_types` | The kinds of creature it may target (Turn Undead's undead), as a list. With none, any creature. | `"creature_types": ["undead", "demon"]` |
| `spell_focus` | An object it must be cast near (a gameobject id; zones list theirs in `spell_focuses`). | `"spell_focus": 1561` |

### How it behaves

| Field | What it does | Example |
|---|---|---|
| `attributes` | Classic's attribute bits, by name (NAMES.md). The game reads `passive` (always on, applied when learned), `on_next_swing` (replaces the next melee swing), `not_in_combat` and `level_damage_calculation` (creature spells). The rest are kept from classic and **not read**. | `"attributes": ["passive", "hidden"]` |
| `attributes_ex`, `attributes_ex2`, `attributes_ex3` | Classic's other attribute masks, as hex bits. The game reads only the bits below; the rest are kept from classic and **not read**. | `"attributes_ex": ["0x4"]` |
| `mechanic` | What kind of effect it is (stun, root, fear...). **Not read**: the game knows a stun by its aura. | `"mechanic": "stun"` |
| `dispel` | Its auras' type, which says what removes them: Cure Disease removes `disease`, Dispel Magic removes `magic`. | `"dispel": "magic"` |
| `stacks` | How many times its aura stacks on one target. [1] | `"stacks": 5` |
| `charges` | How many times its aura can be used up before it ends (Inner Flame, talent buffs). [0, no limit] | `"charges": 3` |
| `proc_chance` | The chance, in %, that its proc aura fires when its `proc_on` happens. [101, always] | `"proc_chance": 20` |
| `proc_on` | The events that fire its proc aura, as a list. | `"proc_on": ["melee_hit_done"]` |
| `proc` | Proc rules from classic's spell_proc_event. `chance`: in % per hit, the same at any weapon speed, replaces `proc_chance` (the game's own: there are no rates per minute; classic's became the chance at a 3 s weapon, Oath of Valor's 7 a minute 35%). `cooldown`: seconds between procs. `school`: only spells of these schools. `family`/`family_mask`: only these spells (`family_mask` a number, or a list of tags and spell names). `flags`/`ex`: classic's proc masks. | `"proc": { "chance": 15 }` |
| `coefficients` | How much spell power or attack power adds. `direct`: for its hit or heal. `dot`: for each tick. Otherwise worked out from the cast time. | `"coefficients": { "direct": 0.857 }` |
| `tags` | Tags of this rank only, on top of its group's (see Tags below). | `"tags": ["heavy_strikes"]` |
| `family` / `family_flags` | Its class family and flag bits. Talents (spell modifiers) and proc rules pick the spells they change by these (`affects`, `family_mask`). Give a new spell the bit of the spells it should be treated as. | `"family": 4, "family_flags": 64` |
| `link` | Another spell cast along with it, or kept on with it (a stance's passive). | `"link": 23455` |
| `extra` | Templar side tables, by name: `judgement_procs` (the Verdict an Oath gives), `holy_shock` (its damage and heal spells), `seal_of_righteousness_procs` (the hit an Oath's proc deals). | `"extra": { "judgement_procs": 20187 }` |
| `extra_value` | An extra amount that a spell's own code reads: Warding Edge's shield per Resonance. | `"extra_value": 20` |
| `chain_link` | Its place in its chain when that isn't its place in the group (classic's branching chains): `{ "prev": id, "first": id, "rank": n }`. | |
| `chain_entry` | `false` for a chain's first rank that classic gives no chain entry of its own. | |
| `raw` | Classic fields kept as they are, by classic's field name, for anything no other field covers (none at present). | `"raw": { "SpellVisual": 3 }` |

#### Hex attribute bits the game reads

| Field | Bit | What it does |
|---|---|---|
| `attributes_ex` | `0x2` | Spends all the caster's power, whatever its `cost` (Execute-like). |
| `attributes_ex` | `0x4`, `0x40` | Channelled: the effect lasts while the caster holds still, and moving or casting another spell ends it. |
| `attributes_ex2` | `0x20000000` | Can't crit. |
| `attributes_ex3` | `0x100000` | Its aura stays through death. |

### Effects

`effects` is a list of up to three. Each one does something when the spell lands.

| Field | What it does | Example |
|---|---|---|
| `type` | What the effect does: deal damage, heal, apply an aura, energize, dispel... (NAMES.md lists each). | `"type": "school_damage"` |
| `aura` | For `apply_aura` and area auras: which aura is put on the target (NAMES.md lists each). | `"aura": "periodic_damage"` |
| `value` | Its amount: damage, healing, the aura's bonus, a percentage, as the type or aura says. A number, or `[least, most]` for a random amount between them. [0] | `"value": [42, 50]` |
| `per_level` | Added to `value` for each caster level above `base_level`, up to `max_level`. | `"per_level": 0.5` |
| `dice` | Classic's base dice: how a `[least, most]` is stored. Set only when it isn't 1, as classic has it. | `"dice": 0` |
| `dice_per_level` | Classic's dice per level. **Not read.** | |
| `target` | Who it lands on: the caster, the enemy targeted, the party around, enemies in an area... (NAMES.md lists each). | `"target": "enemy"` |
| `target_b` | Classic's second target. **Not read.** | |
| `radius` | Its area, yards, for area targets. | `"radius": 8` |
| `radius_index` | Classic's radius table number, written only when the radius isn't a known one. Prefer `radius`. | |
| `period` | For ticking auras (periodic damage, heal, energize, trigger): seconds between ticks. | `"period": 3` |
| `trigger` | A spell id it casts: the spell a proc or periodic trigger aura casts, or the spell `trigger_spell` casts. | `"trigger": 67` |
| `mechanic` | This effect's own mechanic. **Not read.** | `"mechanic": "snare"` |
| `multiplier` | Classic's damage multiplier for chain targets (DmgMultiplier). The game reads it only for a few abilities by name: on the first effect, Execute's damage per point of rage, and Arcane Lance's and Arc of Ruin's damage per level. [1] | `"multiplier": 0.3` |
| `cost_share` | The game's own, for an `energize` effect of a spell a talent's proc casts: gives back this % of a mana cost, in place of `value`. Whose cost is set by `cost_of`. | `"cost_share": 20` |
| `cost_of` | With `cost_share`: `"spell"`, the spell that set the proc off [the default], or `"oath"`, the Oath you have up (for talents that proc on Verdict). | `"cost_of": "oath"` |
| `multiple_value` | For `periodic_leech`: health the caster gains per point drained [1]. For `power_burn`: damage dealt per point of mana burned [0.5]. | `"multiple_value": 0.5` |
| `stat` | Stat auras (`stat`, `stat_percent`, `total_stat_percent`): which stat changes. | `"stat": "stamina"` |
| `modifies` | Spell modifiers (`flat_modifier`, `percent_modifier`): what they change in other spells (damage, cost, cast time...). | `"modifies": "cost"` |
| `affects` | Spell modifiers: which spells they change, as a list of tags and spell names (see Tags below), a mask of `family_flags` bits of the class's family, or `"instant"`: every spell and ability of the class cast at once (no cast time after your other talents; not channelled spells, passives, Attack or Shoot). | `"affects": 64`, `"affects": "instant"` |
| `form` | Shapeshift auras: the form it puts the caster in. | `"form": "bastion"` |
| `against` | Mechanic immunity or resistance auras: the mechanic. | `"against": "stun"` |
| `schools` | School auras (resistance, damage done, absorb...): which schools, as a list. Physical means armour for resistances. | `"schools": ["fire", "frost"]` |
| `dispel` | Dispel effects: which type they remove. | `"dispel": "magic"` |
| `power` | Energize effects: which power they give. | `"power": "rage"` |
| `misc` / `item` | Classic's misc value and item, where none of the fields above names it. Their meaning depends on the type or aura (NAMES.md says): a skill id, a creature-type mask, a power, an item to create... | `"misc": 1` |
| `slot` | Its slot (1-3) when an earlier slot is empty, as some classic spells have. | `"slot": 3` |

## Tooltip text

Without `text`, a spell's tooltip comes from `scripts/spells/spell_text.gd` (by name, or
from its effects) or, for passive talents, `talent_text.gd`. With `text`, the tooltip is
that text, with these placeholders filled in (`n` is the effect, 1 to 3):

| Placeholder | Becomes |
|---|---|
| `{amount1}` | The effect's value at your level: "40 to 48", or "40" when it doesn't vary. |
| `{min1}`, `{max1}` | The effect's least and most value. |
| `{total1}` | A periodic effect's total over the duration ("90"). |
| `{ticks1}` | How many times a periodic effect ticks over the duration. |
| `{period1}` | Seconds between a periodic effect's ticks. |
| `{radius1}` | The effect's area in yards. |
| `{duration}` | How long it lasts: "30 sec", "2 min", "1 hr". |
| `{seconds}` | How long it lasts, in seconds. |
| `{cast}` | Cast time in seconds. |
| `{cooldown}` | Its cooldown: "6 sec", "2 min". |
| `{range}`, `{min_range}` | Its range and least range in yards. |
| `{cost}` | Its cost: "15 rage", "35 mana", "8% of base mana". |
| `{chance}` | Its proc chance in %. |
| `{stacks}`, `{charges}` | How many times it stacks, and its charges. |
| `{level}` | Your level. |
| `{cost_share1}` | An energize effect's `cost_share`: the % of a mana cost it gives back. |
| `{trigger1:...}` | Any placeholder above, read from the spell that effect 1 triggers (`trigger`): `{trigger1:cost_share1}`, `{trigger1:amount1}`. A proc talent's tooltip uses it to show what its triggered spell does. |

Numbers count your talents, as the tooltip's cost, range, cast and cooldown lines do: with
Improved Verdict, `{cooldown}` on Verdict says 8 sec, and an Improved Boon's extra shows in `{amount1}`
(talents that change cast time, duration, range, radius, cost, effect amounts, and damage:
Radiant Arbiter's +20% shows in Radiant Strike's `{amount1}` and `{amount2}`). Anything else in braces is left as it is. Write `%` plainly ("raises your crit by
{amount1}%").

```json
"text": "Deals {amount1} Fire damage, then {total2} more over {duration}."
```

In the spell editor, **Fill Text** copies each rank's current tooltip into its `text` (as
plain words and numbers) to start from. Swap its numbers for placeholders where they
should follow the spell's values, then press Apply Live; the note under the window shows
the first rank's tooltip as it now reads.

## Professions

Each profession has a design file too, `data/designs/professions/<name>.json` (`herbalism`,
`mining`, `skinning`, `enchanting`), in the spell editor after the classes. It's a class
design without talents: its spell groups (the ranks, Find Herbs, Smelting, every recipe) and
its trainer's list (each rank's `trainer`), read over classic's data the same way. It adds:

- a `recipe` on each recipe's rank
- sections of its own: `profession`, `nodes` (Herbalism and Mining), `skinning_loot`
  (Skinning), and `disenchant_loot` and `enchants` (Enchanting)

Items are written `{ "item": 2770, "name": "Copper Ore" }`. The name is only for reading; the
game goes by `item`.

### A recipe

On the recipe spell's rank:

```json
"recipe": { "skill": 1, "levels": [1, 25, 47, 70],
	"reagents": [ { "item": 2770, "name": "Copper Ore", "count": 1 } ],
	"focus": "forge",
	"makes": { "item": 2840, "name": "Copper Bar", "count": 1 } }
```

| Field | What it does |
|---|---|
| `skill` | The skill needed to learn and make it. |
| `levels` | `[orange, yellow, green, grey]`: from orange it always raises the skill, from yellow usually, from green rarely, from grey never. |
| `reagents` | What it uses up, with counts. |
| `tools` | Items it needs in the bags but doesn't use up (a Runed Copper Rod). |
| `focus` | Somewhere it must be made near: `"forge"` (Smelting). |
| `makes` | The item it makes, with a count. |
| `enchant` | Or the enchant it puts on an item (its id in `enchants`). `"temporary": true` for oils and the like that wear off. |
| `formula` | The Formula item that teaches it, when the trainer doesn't. |

A recipe the trainer teaches has a `trainer` on its rank like any spell, with `skill`: the
skill needed to learn it there.

### `profession`

```json
"profession": { "name": "Mining", "skill": 186,
	"ranks": [ { "spell": 2575, "rank": "Apprentice", "max": 75, "level": 5, "skill": 0, "price": 10 }, ... ],
	"start": [2580, 2656, 2657],
	"tools": [ { "item": 2901, "name": "Mining Pick" } ] }
```

| Field | What it does |
|---|---|
| `skill` | Its skill line (182 Herbalism, 186 Mining, 393 Skinning, 333 Enchanting). |
| `ranks` | Each rank's spell, its skill cap (`max`), the level and skill it needs, and its price in copper. |
| `start` | Spells learned with the profession itself (Find Minerals, Smelting, Smelt Copper). |
| `tools` | What gathering needs in the bags (Mining Pick, Skinning Knife). |

### `nodes`

A herb or ore kind and its loot:

```json
{ "id": 1731, "name": "Copper Vein", "skill": 1, "size": 1, "respawn": 300, "loot_id": 1502,
	"loot": [ { "item": 2770, "name": "Copper Ore", "count": [1, 2], "chance": 100 }, ... ] }
```

| Field | What it does |
|---|---|
| `skill` | The skill needed to gather it (and its colour for skill-ups). |
| `size` | How big it's drawn. |
| `respawn` | Seconds until it grows back somewhere. |
| `loot` | What gathering it gives (as the skinning and disenchanting tables below). |

### Loot tables

`skinning_loot` (by a creature's skinning loot id) and `disenchant_loot` (by an item's
disenchant id) are `{ "id", "loot" }`. A loot row:

| Field | What it does |
|---|---|
| `item` / `count` | The item and how many, `[least, most]`. |
| `chance` | Its chance in %. A negative chance is a quest item's: it drops only while a quest needs it. |
| `group` | Rows of one group roll as one: at most one of them drops. |
| `reference` | Instead of an item, a shared loot table rolled here (`times` times). |

### `enchants`

What each enchant does to the item it's on:

```json
{ "id": 803, "name": "Fiery Weapon", "chance": 30, "effects": [ { "type": "proc_spell", "spell": 13897 } ] }
```

| Effect `type` | What it does |
|---|---|
| `stat` | Raises a `stat` (`strength`, `agility`, `stamina`, `intellect`, `spirit`, `health`, `mana`) by `value`. |
| `resistance` | Raises a `school`'s resistance (`physical` is armour) by `value`. |
| `weapon_damage` | Adds `value` to the weapon's damage. |
| `equip_spell` | Keeps `spell` on the wearer while the item is worn (an aura). |
| `proc_spell` | Casts `spell` on a melee hit (a swing or a weapon ability, the hand's own weapon) with the enchant's `chance` in % (the game's own: classic's rate per minute at a 3 s weapon, the same for any weapon speed). |

`name` is the line the item's tooltip shows ("Enchanted: Fiery Weapon"). `charges` limits
how many uses it has.

## Talent trees

```json
{ "name": "Blademastery", "id": 161, "order": 0, "talents": [
	{ "name": "Improved Mighty Blow", "id": 124, "tier": 0, "column": 0, "ranks": [12282, 12663, 12664] }
] }
```

| Field | What it does |
|---|---|
| `name` | The tree's name, shown at the top of its column in the talent window and as its spellbook tab. |
| `id` | The tree's number. |
| `order` | Its place, left to right (0, 1, 2). |
| `talents` | Its talents (below). |

Each talent:

| Field | What it does |
|---|---|
| `name` | For reading; the game shows its first rank's spell name. |
| `id` | The talent's number, which saves use. New talents: 9500 and up. |
| `tier` | Its row, 0 at the top. Each tier needs 5 more points spent in the tree. |
| `column` | Its column, 0-3. |
| `ranks` | Each rank's spell id, lowest first; the spells are in `spells`. One point buys one rank. |
| `prereq` | Another talent needed first: `[[talent id, rank]]`. |

A talent's ranks are spells like any other: change what a rank does in its spell's
`effects`. Passive talents are auras (`stat`, `crit_percent`...) kept on while their
`item_types` and `stances` hold. Talents that change other spells are spell modifiers:
`flat_modifier` or `percent_modifier`, with `modifies` and `affects`. Talents with rules of
their own are `dummy` auras that the game's code reads by name.

## Adding a spell

Give it an id from 950000 up and a trainer entry, and put it in a group of its own. The
spell editor's **New Spell** starts one like this:

```json
{ "name": "Ember Lash", "ranks": [ {
	"id": 950001, "name": "Ember Lash", "rank": 1, "level": 4,
	"trainer": { "level": 4, "price": 100 }, "book_tab": 0,
	"school": "fire", "damage_class": "magic", "cost": 25, "cast": 1.5, "range": 30, "gcd": 1.5,
	"text": "Lashes the target with embers for 18 to 24 fire damage.", "icon": "fire",
	"effects": [ { "type": "school_damage", "value": [18, 24], "target": "enemy" } ]
} ] }
```

A second rank goes in the same group's `ranks`, with its own id and a higher `rank`.
New spells can do anything the game's spells already do: damage and healing of any school,
the auras NAMES.md shows in use, triggers, procs and area effects. A new kind of behaviour
still needs code (`SpellCaster`, the class's abilities script).

## Adding a talent

Add its ranks as spells (passive auras, ids from 950000) and an entry in a tree:

```json
{ "name": "Kindled Edge", "ranks": [
	{ "id": 950010, "name": "Kindled Edge", "rank": 1, "duration": "until_cancelled",
		"attributes": ["passive", "hidden"], "book_tab": 1,
		"effects": [ { "type": "apply_aura", "aura": "crit_percent", "value": 1, "target": "self" } ] },
	{ "id": 950011, "name": "Kindled Edge", "rank": 2, "duration": "until_cancelled",
		"attributes": ["passive", "hidden"], "book_tab": 1,
		"effects": [ { "type": "apply_aura", "aura": "crit_percent", "value": 2, "target": "self" } ] }
] }
```

```json
{ "name": "Kindled Edge", "id": 9501, "tier": 1, "column": 3, "ranks": [950010, 950011] }
```

## Tags

Talents pick the spells they change (`affects`) or fire on (a proc's `family_mask`) by bits of
`family_flags`. Rather than numbers, use names:

- **Your own tags.** `"tags"` on a spell group, beside its name and before its ranks, gives
  every rank the same bit of its own; `"tags"` on a rank adds tags for that rank only. Each tag
  gets a free bit of the class's family when the game loads (and `family` is set for you).
- **Spell names.** Any spell of the class with `family_flags` can be named: `"Verdict"`,
  `"Oath of Valor"` (the bits its ranks carry, every rank).

```json
{ "name": "Radiant Strike", "tags": ["radiant_strike"], "ranks": [ { "id": 950050, ... }, { "id": 950051, ... } ] }
```

```json
{ "type": "apply_aura", "aura": "percent_modifier", "value": -50, "modifies": "cost",
	"affects": ["radiant_strike", "Verdict"], "target": "self" }
```

```json
"proc": { "family_mask": ["radiant_strike"] }
```

A tag's bit can change when tags are added (they're handed out in name order on every load),
so refer to tags by name, never by the number. A name that is no tag or spell is warned about.
A single name works without the list too (`"affects": "Radiant Strike"`). Numbers still work, alone or mixed into a list. Damage talents count on a weapon strike's weapon part as well as its spell part.

## A weapon strike

A melee spell that hits with your weapon uses weapon damage effects. For any class, they add
up as one strike on the melee table (miss, dodge, parry, block, crit), lowered by armour:

| Effect | Does |
|---|---|
| `weapon_percent_damage` | Multiplies the weapon hit by `value`%: 25 is a quarter of a weapon hit, 150 half again. |
| `weapon_damage` | Adds `value` to a weapon hit. |
| `weapon_damage_noschool` | Adds `value` to a weapon hit. |
| `normalized_weapon_damage` | Adds `value` to a weapon hit worked out at a set speed (2.4, 3.3 for two-handers, 1.7 for daggers), so slow and fast weapons hit alike. |

Radiant Strike, a quarter of a weapon hit:

```json
{ "name": "Radiant Strike", "ranks": [
	{ "id": 950050, "name": "Radiant Strike", "rank": 1, "level": 1, "damage_class": "melee", "range": 5,
		"cost": 10, "gcd": 1.5, "family": 10, "book_tab": 0, "trainer": { "level": 1, "price": 0 },
		"effects": [ { "type": "weapon_percent_damage", "value": 25, "target": "enemy" } ] }
] }
```

With school damage as well: a `school_damage` effect beside the weapon effects deals its
`value` in the spell's `school` when the strike lands (no second hit roll), past armour, with
spell power (`coefficients`) and its own crit. Radiant Strike as a quarter of a weapon hit plus
10 to 14 Holy:

```json
{ "id": 950050, "name": "Radiant Strike", "rank": 1, "level": 1, "school": "holy", "damage_class": "melee",
	"range": 5, "cost": 10, "gcd": 1.5, "family": 10, "book_tab": 0, "trainer": { "level": 1, "price": 0 },
	"text": "Strikes an enemy for {amount1}% of your weapon damage plus {amount2} Holy damage.",
	"effects": [
		{ "type": "weapon_percent_damage", "value": 25, "target": "enemy" },
		{ "type": "school_damage", "value": [10, 14], "target": "enemy" }
	] }
```

The weapon part stays physical whatever the `school`.

Combine them for "weapon damage plus 20, at 125%": a `weapon_damage` of 20 and a
`weapon_percent_damage` of 125 make (weapon hit + 20) x 1.25. An `apply_aura` effect beside
them puts its aura (a stun, a snare) on the target when the strike lands. Ranger shots
(`damage_class` `ranged`) use the same effects with the ranged weapon.

## A talent for all instant spells

A spell modifier with `"affects": "instant"` changes every instant spell and ability of the
class. Swift Devotion, 20% off the cost of your instant spells and abilities:

```json
{ "name": "Swift Devotion", "ranks": [
	{ "id": 950040, "name": "Swift Devotion", "rank": 1, "family": 10, "duration": "until_cancelled",
		"attributes": ["passive", "hidden"], "book_tab": 1,
		"effects": [ { "type": "apply_aura", "aura": "percent_modifier", "value": -20, "modifies": "cost",
			"affects": "instant", "target": "self" } ] }
] }
```

Its `family` must be the class's (10 Templar, 4 Man-at-Arms, 6 Cleric, 9 Ranger, 12
Spellsword). Its tooltip writes itself ("Reduces the cost of your instant spells and abilities
by 20%."). Any `modifies` works with it except `cast_time`.

## Adding a proc talent

A talent that does something when an event happens is a passive aura of
`proc_trigger_spell`: when one of its `proc_on` events happens, at its `proc_chance`, it
casts its `trigger` spell. `proc` on the first rank narrows the events to some spells
(`family` and `family_mask`: the `family_flags` bits of the spells that count), for every
rank. Leave `chance` out of `proc` so each rank's own `proc_chance` counts.

Replenishing Verdict: Verdict has an 11%, 22% or 33% chance to return 20% of the mana cost
of your active Oath. Landing Verdict is a `harmful_spell_done` event, and Verdict's family
bit is 8388608 (0x800000). Three ranks, then the spell they cast:

```json
{ "name": "Replenishing Verdict", "chain": false, "ranks": [
	{ "id": 20335, "name": "Replenishing Verdict", "rank": 1, "family": 10, "duration": "until_cancelled",
		"attributes": ["passive", "hidden"], "book_tab": 2,
		"proc_on": ["harmful_spell_done"], "proc_chance": 11,
		"proc": { "family": 10, "family_mask": 8388608 },
		"text": "Your Verdict has a {chance}% chance to return {trigger1:cost_share1}% of the mana cost of your active Oath.",
		"effects": [ { "type": "apply_aura", "aura": "proc_trigger_spell", "trigger": 950030, "target": "self" } ] },
	{ "id": 20336, "name": "Replenishing Verdict", "rank": 2, "family": 10, "duration": "until_cancelled",
		"attributes": ["passive", "hidden"], "book_tab": 2,
		"proc_on": ["harmful_spell_done"], "proc_chance": 22,
		"text": "Your Verdict has a {chance}% chance to return {trigger1:cost_share1}% of the mana cost of your active Oath.",
		"effects": [ { "type": "apply_aura", "aura": "proc_trigger_spell", "trigger": 950030, "target": "self" } ] },
	{ "id": 20337, "name": "Replenishing Verdict", "rank": 3, "family": 10, "duration": "until_cancelled",
		"attributes": ["passive", "hidden"], "book_tab": 2,
		"proc_on": ["harmful_spell_done"], "proc_chance": 33,
		"text": "Your Verdict has a {chance}% chance to return {trigger1:cost_share1}% of the mana cost of your active Oath.",
		"effects": [ { "type": "apply_aura", "aura": "proc_trigger_spell", "trigger": 950030, "target": "self" } ] }
] }
```

```json
{ "name": "Replenishing Verdict (mana)", "ranks": [
	{ "id": 950030, "name": "Replenishing Verdict", "attributes": ["hidden"],
		"effects": [ { "type": "energize", "power": "mana", "value": 0, "cost_share": 20, "cost_of": "oath", "target": "self" } ] }
] }
```

For a different share per rank, give each rank its own trigger spell (950030, 950031, 950032,
each with its own `cost_share`, in a group with `"chain": false`); `{trigger1:cost_share1}` in each
rank's text then shows that rank's share.

Events that the game raises are listed in NAMES.md under `proc_on`. Melee, ranged and
spell hits, heals, helpful spells cast, kills, and Verdict landing all raise them.
