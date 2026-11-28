# Editing content

Much of the game's content is in Godot resource files (`.tres`) rather than in scripts. Open one in Godot's FileSystem dock and edit it in the Inspector: colours have pickers, numbers have fields, some text fields offer dropdowns, and every field shows a tooltip saying what it does. The scripts keep only the rules.

**Live while the game runs.** In editor and debug runs, `ContentWatch` (`scripts/content/content_watch.gd`, an autoload) checks the content folders every half second (`CHECK_EVERY`). A file saved with Ctrl+S is read again and put into the running game at once, and the chat says what reloaded. Release builds don't watch; they just read the files.

| What | Where | Class (in `scripts/content/`) | On save |
|---|---|---|---|
| A creature's look | `data/creatures/<entry>_<name>.tres` | `CreatureLook`, read by `CreatureLooks` | Its creatures in the world take the new look |
| Creature models | `data/creatures/models.tres` | `CreatureModels` of `CreatureModelInfo` | Every creature with that model updates |
| A race's colours and choices | `data/looks/<race>.tres` | `RaceLook`, read by `CharacterLooks` | Every character model re-colours |
| Gear colours, NPC outfits | `data/looks/outfits.tres` | `OutfitLooks` with `TradeOutfit`s | NPCs pick their outfits again, and models re-colour |
| A zone's layout | `data/zones/<zone>.tres` | `ZoneLayout`, read by `ZoneLayouts` | The zone is rebuilt in place (about 2.5 s) |
| Icon maps | `data/icons.tres` | `IconMaps` with `IconWord`s | The interface redraws |

Script changes still need Reload Game (Developer tab) or a restart: Godot can't swap a running script.

## Creatures: `data/creatures/`

There is one `CreatureLook` per creature, named by its classic entry and its name (`3122_redclaw_lasher.tres`). A creature with no file is a capsule in a default colour.

- **size, color**:
  - Without a model, these are the capsule's scale and colour.
  - With one, the model's size is `size.x` over the model's base size (`models.tres`). The colour is a beast's coat or a humanoid creature's skin.
- **model**: one of `models.tres`'s models (`wolf`, `raptor`, `harpy`...), or a playable race for dressed creatures. Leave it empty for the capsule.
- **dressed**: a person of the model's race with a face of its own, wearing its band's colour (`band`) on head and chest, and a cloak (`cloak`) when it has no helm. The brigands' red gives them leather chests.
- **Gear**:
  - `main`: a weapon shape (`sword`, `axe2h`, `staff`...). Leave it empty for bare hands.
  - `off`: an `Off_*` or `Shield_*` part.
  - `helm`: a `Helm_*` part.

  Gear only shows on humanoid creatures.

**Adding a creature** (one that's in the classic data, `extract.py`'s `CREATURES`): duplicate a similar creature's file, rename it, and set `entry`.

**Adding a model** means building it in the Blender build scripts (`tools/models/...`), then adding it to `models.tres` with its base size and whether it's a beast.

## Characters: `data/looks/`

- **`<race>.tres` (`RaceLook`)**:
  - skins and hair colours to choose from;
  - eye colour, and `glowing_eyes` (the whites glow too);
  - tusk, horn and bone colour;
  - for character creation, the feature and markings' titles and choice names, plus the markings' `paint` colour.

  A race with no file takes the Human's. Keep as many skins and hair colours as the Human has, so any look fits any race.
- **`outfits.tres` (`OutfitLooks`)**:
  - armour palettes (`cloth`, `leather`, `mail`, `plate`; each item picks one colour);
  - `name_colors`: words in item names that set a colour;
  - gems by quality, and the smallclothes, trim, wood, steel, strap and parchment colours;
  - `trades`: what each trade's NPCs wear (`TradeOutfit`):
    - the chest from a palette or from colours of its own, darkened if set;
    - its patterns, one picked;
    - whether the legs and their pattern match the chest.

    A trade with no entry wears the everyday outfit.

The model parts (hair styles, beards, helms, shoulder pieces) are named in `scenes/characters/humanoid_model.gd`, as they belong to the model files.

## Zones: `data/zones/<zone>.tres`

The file is named after the zone script's folder (`ashford_vale`, `harrowfield`...). It is a `ZoneLayout`:

| Field | What it holds |
|---|---|
| **places** | Named circles: bots' talk, the world map's names and places to explore. List them smallest first. |
| **flats** | Level ground for camps and towns. A flat's `key` is the name the zone's code uses for it (`DELVE` → `FLATS[DELVE]`), so its buildings follow it wherever it is in the list. Keep the key, and change the centre, radius and height freely. |
| **hills** | Rounded hills: centre, radius and height. |
| **stream, roads** | Lists of points. |
| **woods** | Circles where the trees grow. |
| **spawns** | A creature `entry` (its name is filled in beside it in the editor), a centre and radius, and how many. Order matters: it names the creatures, and saved corpses go by name. Add new groups at the end. |
| **chests, quest_objects, enclosures, spell_focuses** | Scattered chests; quest bodies and barrels (named for `quests.json`); walled places with their gates (for bots); spell focus points. |

Saving the file rebuilds the zone in place (`World.rebuild_zone`):

- **Kept:** corpses, the player and the party.
- **Lifted:** anyone standing in the zone is put on the new ground if it rose.
- **Let go:** targets and debuffs from the old zone's creatures.
- **Worked out again:** the minimap, bots' path cells and nameplates.
- **Not kept:** emptied chests come back full.

`rebuildzone` (the Developer tab's Rebuild Zone button) does the same after a script change to a zone's builders.

Buildings, fields and props are laid out in the zone's script. Hand-shaped ground and caves are Blender edits (`data/zone_edits/`, `editzone`).

## Icons: `data/icons.tres`

An icon key is the name of a PNG in `assets/icons/`. These are painted by `tools/icons/icon_painter.gd`; after adding a key, bake it with `tools/icons/bake_icons.gd`.

- **`spell_icons`, `weapon_skill_icons`**: icons by a spell's exact name.
- **`talent_words`, `item_words`, `creature_portraits`**: words looked for in a name, in order; the first found wins. Put a longer phrase before a shorter one it contains ("healing potion" before "potion"). Item words are lower case.

The rest of the rules are in `ui/icons.gd`: weapon types, armour slots, qualities, spell families and schools.

## How the files were made

`tools/content/extract_content.gd` wrote every file once from the tables the scripts held (`-- --only=creatures|looks|zones|icons`), keeping each table entry's code comment as its name (`tools/content/zone_notes.py` read the zones' comments). The tables are gone from the scripts now, so the files are the source, and the converter has nothing more to read.
