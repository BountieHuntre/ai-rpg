# Spell design names

Every name a spell design file (`data/designs/<class>.json`) may use, by field, and what it does. Written by
`tools/spells/make_names.py` from `data/designs/names.json` and the meanings in `tools/spells/name_notes.py`;
see FIELDS.md for the fields themselves. Anywhere a name goes, its number works too (for values with no name here).

**In the game** counts the spells of the game's classes (the design files) that use the name, with one of them.
A few spells the game has but leaves unfinished (Dominate Will, Borrowed Eyes, Font of Light) count too. Names used by none are classic's: the game may do nothing with them yet, and a spell using one needs code
(`SpellCaster`, `Combatant`, the class's abilities script) before it does anything.

## school

A spell's school, and an effect's `schools`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `physical` | 0 | Weapon damage. Lowered by armour, not by resistances. | 112: Sanctified Ward, Wall of Steel, Tame Beast |
| `holy` | 1 | Holy magic. Nothing resists it. | 347: Sanctified Ward, Wall of Steel, Ranged Weapon Mastery |
| `fire` | 2 | Fire magic, resisted by fire resistance. | 81: Sanctified Ward, Wall of Steel, Burning Trap |
| `nature` | 3 | Nature magic (poisons, lightning), resisted by nature resistance. | 118: Sanctified Ward, Wall of Steel, Mend Companion |
| `frost` | 4 | Frost magic, resisted by frost resistance. | 69: Sanctified Ward, Wall of Steel, Frostbind Trap |
| `shadow` | 5 | Shadow magic, resisted by shadow resistance. | 151: Sanctified Ward, Wall of Steel, Ranged Weapon Mastery |
| `arcane` | 6 | Arcane magic, resisted by arcane resistance. | 134: Sanctified Ward, Wall of Steel, Quarry's Mark |

## damage_class

How a spell lands: a spell (magic), a melee or ranged attack, or neither.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `none` | 0 | Neither a spell nor an attack: can't miss or crit (buffs, stances, most auras on yourself). | none |
| `magic` | 1 | A spell: rolls spell hit and crit, can be resisted, takes spell power. | 652: Sanctified Ward, Goad, Mend Companion |
| `melee` | 2 | A melee attack: rolls the melee table (miss, dodge, parry, block, crit), takes attack power. | 102: Shield Smash, Break Away, Verdict of Dominion |
| `ranged` | 3 | A ranged attack: rolls the ranged table (miss, block, crit), takes ranged attack power. | 51: Auto Shot, Gavel of Reckoning |

## power

What a spell costs, and an energize effect's `power`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `health` | -2 | Paid in health. | none |
| `mana` | 0 | Paid in mana (the default). | 9: Last Rite |
| `rage` | 1 | Paid in rage; `cost` is in whole rage points. | 110: Bastion Stance |
| `focus` | 2 | Paid in focus (pets). | none |
| `energy` | 3 | Paid in energy. | none |
| `happiness` | 4 | Pet happiness (classic only; the game has none). | none |

## effect type

An effect's `type`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `instakill` | 1 | Kills the target outright. | 1: Hallowed Ransom |
| `school_damage` | 2 | Deals value damage of the spell's school. | 139: Chastise, Shield Smash, Weasel Bite |
| `dummy` | 3 | Does nothing by itself; the game's code does what the spell needs by its name. | 38: Finishing Blow, Tame Beast, Release |
| `portal_teleport` | 4 | Teleports the target through a portal. | none |
| `teleport_units` | 5 | Teleports the target to a set place (Hearthstone-like). | none |
| `apply_aura` | 6 | Puts the `aura` on the target for the spell's duration. | 1118: Sanctified Ward, Bastion Stance, Mend Companion |
| `environmental_damage` | 7 | Damage from the world (fire, lava, falling). | none |
| `power_drain` | 8 | Drains value of the target's `power` and gives it to the caster. | 1: Dismiss Pet |
| `health_leech` | 9 | Deals value damage and heals the caster by it (times multiple_value). | none |
| `heal` | 10 | Heals the target by value. | 40: Communal Mending, Mending Radiance |
| `bind` | 11 | Sets the target's home (inn). | none |
| `portal` | 12 | Opens a portal. | none |
| `ritual_base` | 13 | Starts a ritual. | none |
| `ritual_specialize` | 14 | A ritual step. | none |
| `ritual_activate_portal` | 15 | Opens a ritual's portal. | none |
| `quest_complete` | 16 | Completes the quest named by its misc value. | none |
| `weapon_damage_noschool` | 17 | A weapon strike: weapon damage plus value, as a melee or ranged attack. | 19: Mighty Blow, Hurl Blade |
| `resurrect` | 18 | Brings a dead player back with value% health. | none |
| `add_extra_attacks` | 19 | The caster swings value more times at once. | none |
| `dodge` | 20 | Lets the target dodge (a skill effect). | none |
| `evade` | 21 | Lets the target evade. | none |
| `parry` | 22 | Lets the target parry. | 1: Parry |
| `block` | 23 | Lets the target block. | none |
| `create_item` | 24 | Makes value of the item `item`. | none |
| `weapon` | 25 | Teaches a weapon skill. | none |
| `defense` | 26 | Teaches the defense skill. | none |
| `persistent_area_aura` | 27 | Leaves an area on the ground that gives its aura to those in it (Hallowed Ground-like). | 12: Arrow Rain, Hallowed Ground |
| `summon` | 28 | Summons a creature. | none |
| `leap` | 29 | Jumps the caster forward. | none |
| `energize` | 30 | Gives value of `power` (mana, rage...) to the target. | 7: Rush, Last Rite |
| `weapon_percent_damage` | 31 | A weapon strike for value% of weapon damage. | 1: Scattering Shot |
| `trigger_missile` | 32 | Fires another spell (`trigger`) as a missile at the target. | none |
| `open_lock` | 33 | Opens a lock (chests, doors). | none |
| `summon_change_item` | 34 | Swaps an item for another. | none |
| `apply_area_aura_party` | 35 | Gives the `aura` to the caster's party within the radius, kept up while near (Presences). | 29: Pack Spirit, Bulwark Presence |
| `learn_spell` | 36 | Teaches the spell `trigger`. | none |
| `spell_defense` | 37 | Teaches spell defense. | none |
| `dispel` | 38 | Removes value of the target's auras of the `dispel` type. | 12: Unweave, Shield Crush, Improved Mend Companion |
| `language` | 39 | Teaches a language. | none |
| `dual_wield` | 40 | Lets the target hold a weapon in the off hand. | 1: Two-Weapon Fighting |
| `summon_wild` | 41 | Summons creatures that act on their own. | none |
| `summon_guardian` | 42 | Summons a guardian that fights for the caster. | none |
| `teleport_units_face_caster` | 43 | Teleports the target in front of the caster, facing it. | none |
| `skill_step` | 44 | Raises a skill's top. | none |
| `add_honor` | 45 | Gives honor. | none |
| `spawn` | 46 | Plays a creature's spawn. | none |
| `trade_skill` | 47 | Teaches a trade skill. | none |
| `stealth` | 48 | Puts the caster in stealth. | none |
| `detect` | 49 | Finds stealthed units nearby. | none |
| `trans_door` | 50 | Summons an object (a door, a portal). | 3: Font of Light |
| `force_critical_hit` | 51 | Makes the next hit a crit. | none |
| `guarantee_hit` | 52 | Makes the next hit land. | none |
| `enchant_item` | 53 | Puts a lasting enchantment on an item. | none |
| `enchant_item_temporary` | 54 | Puts a temporary enchantment on a weapon (poisons, sharpening stones). | none |
| `tame_creature` | 55 | Tames the target beast as the caster's pet. | none |
| `summon_pet` | 56 | Calls the caster's pet. | 1: Call Pet |
| `learn_pet_spell` | 57 | Teaches the pet a spell. | none |
| `weapon_damage` | 58 | A weapon strike: weapon damage plus value, as a melee or ranged attack. | 9: Auto Shot |
| `open_lock_item` | 59 | Opens a locked item. | none |
| `proficiency` | 60 | Lets the target use the item types in `item_types` (weapon and armour proficiencies). | 3: Plate Mail, Mail |
| `send_event` | 61 | Sends an event to the world's scripts. | none |
| `power_burn` | 62 | Burns value of the target's mana, dealing damage for it (times multiple_value). | 5: Mana Scorch |
| `threat` | 63 | Adds value threat on the target. | 10: Break Away |
| `trigger_spell` | 64 | Casts the spell `trigger` as well. | 13: Rush, Hallowed Ransom |
| `health_funnel` | 65 | Moves health from the caster to its pet. | none |
| `power_funnel` | 66 | Moves power from the caster to its pet. | none |
| `heal_max_health` | 67 | Heals the target to full (Lay on Hands-like). | 3: Last Rite |
| `interrupt_cast` | 68 | Stops the target's spell and locks its school for the spell's duration. | 6: Shield Smash, Severing Sigil |
| `distract` | 69 | Makes creatures look towards a place. | none |
| `pull` | 70 | Pulls the target towards the caster. | none |
| `pickpocket` | 71 | Steals from a creature. | none |
| `add_farsight` | 72 | Lets the caster see from a place far away (Distant Gaze). | 1: Distant Gaze |
| `summon_possessed` | 73 | Summons a creature the caster controls. | none |
| `summon_totem` | 74 | Summons a totem. | none |
| `heal_mechanical` | 75 | Heals a mechanical target. | none |
| `summon_object_wild` | 76 | Puts an object in the world. | none |
| `script_effect` | 77 | Done by the game's code for this spell by name. | 15: Mending Radiance |
| `attack` | 78 | Makes the caster attack. | none |
| `sanctuary` | 79 | Drops all threat on the caster. | 1: Hallowed Ransom |
| `add_combo_points` | 80 | Gives combo points on the target. | none |
| `create_house` | 81 | Builds a house (unused). | none |
| `bind_sight` | 82 | Sees through the target's eyes. | none |
| `duel` | 83 | Starts a duel. | none |
| `stuck` | 84 | Frees a stuck character. | none |
| `summon_player` | 85 | Summons a player. | none |
| `activate_object` | 86 | Uses an object in the world. | none |
| `summon_totem_slot1` | 87 | Summons a totem in slot 1. | none |
| `summon_totem_slot2` | 88 | Summons a totem in slot 2. | none |
| `summon_totem_slot3` | 89 | Summons a totem in slot 3. | none |
| `summon_totem_slot4` | 90 | Summons a totem in slot 4. | none |
| `threat_all` | 91 | Adds threat with every creature fighting the caster. | none |
| `enchant_held_item` | 92 | Enchants the item the target holds. | none |
| `summon_phantasm` | 93 | Summons a phantasm. | none |
| `self_resurrect` | 94 | Lets the caster come back to life by itself. | none |
| `skinning` | 95 | Skins a creature. | none |
| `charge` | 96 | Rushes the caster to the target (Rush). | 5: Rush |
| `summon_critter` | 97 | Summons a pet critter. | none |
| `knock_back` | 98 | Knocks the target back. | none |
| `disenchant` | 99 | Breaks an item into enchanting materials. | none |
| `inebriate` | 100 | Makes the target drunk. | none |
| `feed_pet` | 101 | Feeds the pet. | none |
| `dismiss_pet` | 102 | Sends the pet away. | 1: Dismiss Pet |
| `reputation` | 103 | Gives reputation. | none |
| `summon_object_slot1` | 104 | Puts an object in slot 1 (traps). | 12: Frostbind Trap |
| `summon_object_slot2` | 105 | Puts an object in slot 2. | none |
| `summon_object_slot3` | 106 | Puts an object in slot 3. | none |
| `summon_object_slot4` | 107 | Puts an object in slot 4. | none |
| `dispel_mechanic` | 108 | Removes the target's auras with the `mechanic` (snares, stuns...). | none |
| `summon_dead_pet` | 109 | Brings back the dead pet. | 1: Revive Pet |
| `destroy_all_totems` | 110 | Removes the caster's totems. | none |
| `durability_damage` | 111 | Damages the target's gear's durability. | none |
| `summon_demon` | 112 | Summons a demon. | none |
| `resurrect_new` | 113 | Brings a dead player back with value health. | 10: Rite of Return, Revival |
| `attack_me` | 114 | Makes the target attack the caster (taunt). | 2: Goad, Mark of Challenge |
| `durability_damage_pct` | 115 | Takes value% of the target's gear's durability. | none |
| `skin_player_corpse` | 116 | Loots a player's body. | none |
| `spirit_heal` | 117 | A spirit healer's resurrection. | none |
| `skill` | 118 | Raises a skill. | none |
| `apply_area_aura_pet` | 119 | Gives the `aura` to the caster's pet. | 2: Kindred Bond |
| `teleport_graveyard` | 120 | Sends the target to its graveyard. | none |
| `normalized_weapon_damage` | 121 | A weapon strike with weapon speed normalised (the same for fast and slow weapons) plus value. | 19: Cyclone Strike, Spread Shot |
| `send_taxi` | 123 | Starts a flight. | none |
| `player_pull` | 124 | Pulls a player to the caster. | none |
| `modify_threat_percent` | 125 | Changes the caster's threat on the target by value%. | none |
| `steal_beneficial_buff` | 126 | Steals a buff from the target. | none |
| `prospecting` | 127 | Prospects ore. | none |
| `apply_area_aura_friend` | 128 | Gives the `aura` to friends around the caster. | none |
| `apply_area_aura_enemy` | 129 | Gives the `aura` to enemies around the caster. | none |

## aura

An `apply_aura` (or area aura) effect's `aura`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `bind_sight` | 1 | Sees through the target's eyes. | 2: Borrowed Eyes |
| `possess` | 2 | Takes control of the target. | 3: Dominate Will |
| `periodic_damage` | 3 | Deals value damage of the spell's school every `period` seconds. | 63: Gnawing Shadow, Gash, Arrow Rain |
| `dummy` | 4 | Does nothing by itself; the game's code reads it by the spell's name (talents with rules of their own). | 130: Dominate Will, Wide Swings, Beast's Eyes |
| `confuse` | 5 | The target wanders confused. | 1: Scattering Shot |
| `charm` | 6 | The target fights for the caster. | none |
| `fear` | 7 | The target runs in fear. | 11: Dread Wail, Cowing Roar, Frighten Beast |
| `periodic_heal` | 8 | Heals value every `period` seconds. | 19: Lingering Grace, Mend Companion |
| `attack_speed` | 9 | Changes attack speed by value% (negative is slower). | 6: Oath of the Vanguard |
| `threat` | 10 | Changes threat caused by value% (`misc`: a school mask, 127 for all). | 17: Quiet Resolve, Bastion Stance Passive, Wardweave |
| `taunt` | 11 | The target must attack the caster. | 9: Goad, Mark of Challenge |
| `stun` | 12 | The target can't move, attack or cast. | 13: Bind the Dead, Mace Stun, Drake Sting |
| `damage_done` | 13 | Adds value to damage done with the `schools`. | 12: Withering Touch |
| `damage_taken` | 14 | Adds value to damage taken from the `schools`. | 10: Verdict of the Vanguard |
| `damage_shield` | 15 | Deals value damage to anyone who hits the target in melee. | 5: Thorned Presence |
| `stealth` | 16 | Stealth. | none |
| `stealth_detect` | 17 | Sees stealthed units better. | 1: Track Hidden |
| `invisibility` | 18 | Invisibility. | none |
| `invisibility_detect` | 19 | Sees invisible units. | none |
| `health_percent_regen` | 20 | Restores value% of health every few seconds. | 2: Kindred Bond |
| `mana_percent_regen` | 21 | Restores value% of mana every few seconds. | none |
| `resistance` | 22 | Adds value to the resistances (or armour, physical) of the `schools`. | 17: Inner Flame, Rend Armor, Bulwark Presence |
| `periodic_trigger_spell` | 23 | Casts the spell `trigger` every `period` seconds. | 2: Cleanse Sickness, Tame Beast |
| `periodic_energize` | 24 | Gives value of `power` every `period` seconds. | 7: Boon of Clarity |
| `pacify` | 25 | The target can't attack. | 5: Hallowed Guard |
| `root` | 26 | The target can't move. | 4: Ensnaring Traps |
| `silence` | 27 | The target can't cast spells. | 1: Hush |
| `reflect_spells` | 28 | Reflects value% of spells cast at the target. | none |
| `stat` | 29 | Adds value to the `stat` (all for every stat). | 15: Litany of Fortitude, Stinger Venom |
| `skill` | 30 | Adds value to the skill whose id is `misc`. | none |
| `speed` | 31 | Run speed up by value%. | 15: Dread Wail, Cowing Roar, Frighten Beast |
| `mounted_speed` | 32 | Mounted speed up by value%. | none |
| `slow` | 33 | Run speed down by value% (a snare). | 14: Mind Rend, Hobble, Crippling Cut |
| `max_health` | 34 | Adds value to maximum health. | 1: Final Stand |
| `max_power` | 35 | Adds value to the maximum of the power in `misc` (0 mana, 1 rage, 2 focus, 3 energy). | none |
| `shapeshift` | 36 | Puts the target in the `form` (Man-at-Arms stances, Spellsword forms, Shroud of Shadow). | 6: Shroud of Shadow, Bastion Stance, Bladesong Form |
| `effect_immunity` | 37 | Immune to an effect type. | none |
| `state_immunity` | 38 | Immune to an aura type. | none |
| `school_immunity` | 39 | Immune to the `schools`. | 7: Hallowed Guard |
| `damage_immunity` | 40 | Takes no damage from the `schools`. | none |
| `dispel_immunity` | 41 | Immune to the `dispel` type. | 1: Flare |
| `proc_trigger_spell` | 42 | Casts the spell `trigger` when the spell's `proc_on` happens, at its `proc_chance`. | 148: Withering Touch, Swordsman's Craft, Cheetah Spirit |
| `proc_trigger_damage` | 43 | Deals value damage when the spell's `proc_on` happens. | 8: Boon of Refuge |
| `track_creatures` | 44 | Shows the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid) on the minimap. | 7: Track Beasts |
| `track_resources` | 45 | Shows resources (herbs, ore) on the minimap. | none |
| `parry_skill` | 46 | Adds value to parry skill. | none |
| `parry_percent` | 47 | Adds value% parry chance. | 22: Deflection, Slipstep, Mirror Guard |
| `dodge_skill` | 48 | Adds value to dodge skill. | none |
| `dodge_percent` | 49 | Adds value% dodge chance. | 7: Moon's Grace, Monkey Spirit |
| `block_skill` | 50 | Adds value to block skill. | none |
| `block_percent` | 51 | Adds value% block chance. | 9: Shield Brace, Radiant Bulwark |
| `crit_percent` | 52 | Adds value% melee and ranged crit chance. | 35: Abandon, Predator's Instinct, Keen Edges |
| `periodic_leech` | 53 | Drains value health every `period` seconds, healing the caster. | 6: Ravening Blight |
| `hit_chance` | 54 | Adds value% chance to hit with weapons. | 6: Sure Step, Precision |
| `spell_hit_chance` | 55 | Adds value% chance to hit with spells. | none |
| `transform` | 56 | Changes the target's look into a creature's. | none |
| `spell_crit_chance` | 57 | Adds value% spell crit chance. | none |
| `swim_speed` | 58 | Swim speed up by value%. | none |
| `damage_done_creature` | 59 | Adds value damage against the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid). | none |
| `pacify_silence` | 60 | The target can't attack or cast. | none |
| `scale` | 61 | Changes the target's size by value%. | 1: Beast Fury |
| `periodic_health_funnel` | 62 | Moves health from the caster to its pet over time. | none |
| `periodic_mana_funnel` | 63 | Moves mana from the caster to its pet over time. | none |
| `periodic_mana_leech` | 64 | Drains value mana every `period` seconds. | 3: Asp Sting |
| `casting_speed` | 65 | Changes cast speed by value% (negative is slower). | none |
| `feign_death` | 66 | Lies as if dead: creatures forget the target. | 1: Still as Death |
| `disarm` | 67 | The target can't use its weapon. | 1: Wrest Weapon |
| `stalked` | 68 | The target can't hide. | 6: Borrowed Eyes, Quarry's Mark |
| `school_absorb` | 69 | Soaks up value damage of the `schools` (Wards). | 17: Sanctified Ward, Runic Ward |
| `extra_attacks` | 70 | Extra swings. | none |
| `spell_crit_chance_school` | 71 | Adds value% crit chance for spells of the `schools`. | 10: Arcane Insight, Sacred Power |
| `power_cost_school_percent` | 72 | Changes the cost of spells of the `schools` by value%. | none |
| `power_cost_school` | 73 | Changes the cost of spells of the `schools` by value. | none |
| `reflect_spells_school` | 74 | Reflects value% of spells of the `schools`. | none |
| `language` | 75 | Speaks a language. | none |
| `far_sight` | 76 | Sees far away. | none |
| `mechanic_immunity` | 77 | Immune to effects with the mechanic `against` (stuns, fear...). | 6: Dread Ward, Abandon, Beast Fury |
| `mounted` | 78 | Mounted. | none |
| `damage_percent_done` | 79 | Damage done with the `schools` up by value%. | 42: Kindled Power, Bastion Stance Passive, Ranged Weapon Mastery |
| `stat_percent` | 80 | The `stat` up by value%. | none |
| `split_damage_percent` | 81 | Moves value% of damage taken to the caster. | none |
| `water_breathing` | 82 | Breathes under water. | none |
| `base_resistance` | 83 | Adds value to base resistances (or armour) of the `schools`. | none |
| `health_regen` | 84 | Restores value health every 5 seconds. | none |
| `power_regen` | 85 | Restores value of the power in `misc` (0 mana, 1 rage...) every 5 seconds. | 1: Simmering Anger |
| `channel_death_item` | 86 | Makes an item if the target dies while channelled on (Soul Shards). | none |
| `damage_percent_taken` | 87 | Damage taken from the `schools` changed by value%. | 12: Shroud of Shadow, Wall of Steel, Last Sigil |
| `health_regen_percent` | 88 | Health regeneration up by value%. | none |
| `periodic_damage_percent` | 89 | Deals value% of maximum health every `period` seconds. | none |
| `resist_chance` | 90 | Chance to resist. | none |
| `detect_range` | 91 | Changes the range at which creatures notice the target by value yards. | 3: Calm Mind |
| `prevents_fleeing` | 92 | The target can't flee. | 1: Verdict of Binding |
| `unattackable` | 93 | The target can't be attacked. | none |
| `interrupt_regen` | 94 | Stops regeneration. | none |
| `ghost` | 95 | A ghost (after death). | none |
| `spell_magnet` | 96 | Draws a spell to itself. | none |
| `mana_shield` | 97 | Soaks damage by spending mana. | none |
| `skill_talent` | 98 | Adds value to the skill whose id is `misc` (from a talent). | 10: Anticipation |
| `attack_power` | 99 | Adds value melee attack power. | 28: Daunting Roar, Sharpshooter's Aura, Boon of Strength |
| `auras_visible` | 100 | Shows auras. | none |
| `resistance_percent` | 101 | Resistances (or armour) of the `schools` up by value%. | 2: Death Craving, Tame Beast |
| `melee_attack_power_versus` | 102 | Adds value melee attack power against the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid). | none |
| `total_threat` | 103 | Changes threat by value. | 6: Veil of Humility |
| `water_walk` | 104 | Walks on water. | 1: Featherfall |
| `feather_fall` | 105 | Falls slowly. | 1: Featherfall |
| `hover` | 106 | Floats above the ground. | 1: Featherfall |
| `flat_modifier` | 107 | A spell modifier: adds value to what `modifies` names, for the spells in `affects` (talents). | 162: Improved Mana Scorch, Improved Mighty Blow, Brutal Strikes |
| `percent_modifier` | 108 | A spell modifier: changes what `modifies` names by value%, for the spells in `affects` (talents). | 160: Quick Mind, Improved Gash, Cunning Traps |
| `add_target_trigger` | 109 | Casts `trigger` on the target of the spells in `affects`. | 5: Gloomweave |
| `power_regen_percent` | 110 | Regeneration of the power in `misc` (0 mana, 1 rage...) up by value%. | none |
| `add_caster_hit_trigger` | 111 | Casts a spell when hit. | none |
| `override_class_scripts` | 112 | Classic's class scripts (handled by name). | 15: Stance Discipline, Improved Stinger Venom, Inner Light |
| `ranged_damage_taken` | 113 | Adds value to ranged damage taken. | 5: Moon's Grace |
| `ranged_damage_taken_percent` | 114 | Ranged damage taken changed by value%. | none |
| `healing` | 115 | Adds value to healing taken. | none |
| `regen_during_combat` | 116 | Lets value% of regeneration go on in combat. | none |
| `mechanic_resistance` | 117 | Adds value% to resisting the mechanic `against`. | 18: Unbending Will, Iron Resolve, Sure Step |
| `healing_percent` | 118 | Healing taken changed by value%. | 10: Feeble Hex, Grievous Strike |
| `share_pet_tracking` | 119 | The pet shares the caster's tracking. | none |
| `untrackable` | 120 | Can't be tracked. | 1: Beast Spirit |
| `empathy` | 121 | Shows a beast's information. | 1: Creature Lore |
| `offhand_damage_percent` | 122 | Off-hand damage up by value%. | 5: Two-Weapon Craft |
| `target_resistance` | 123 | Lowers the target's resistance to the caster's spells by value. | none |
| `ranged_attack_power` | 124 | Adds value ranged attack power. | 9: Hawk Spirit |
| `melee_damage_taken` | 125 | Adds value to melee damage taken. | none |
| `melee_damage_taken_percent` | 126 | Melee damage taken changed by value%. | none |
| `ranged_attack_power_attacker_bonus` | 127 | Attackers get value ranged attack power against the target (Quarry's Mark). | 4: Quarry's Mark |
| `possess_pet` | 128 | Takes control of the pet. | 1: Beast's Eyes |
| `speed_always` | 129 | Run speed up by value%, even mounted. | none |
| `mounted_speed_always` | 130 | Mounted speed up by value%. | none |
| `ranged_attack_power_versus` | 131 | Adds value ranged attack power against the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid). | none |
| `max_power_percent` | 132 | Maximum of the power in `misc` (0 mana, 1 rage...) up by value%. | 5: Deep Mind |
| `max_health_percent` | 133 | Maximum health up by value%. | 5: Hardy |
| `mana_regen_interrupt` | 134 | Lets value% of mana regeneration go on while casting. | 3: Contemplation |
| `healing_done` | 135 | Adds value to healing done. | none |
| `healing_done_percent` | 136 | Healing done changed by value%. | 1: Kindled Power |
| `total_stat_percent` | 137 | The `stat` up by value% of its total. | 28: Quick Reflexes, Hardened Spirit, Righteous Rebuke |
| `melee_haste` | 138 | Melee attack speed up by value%. | 23: Dominate Will, Ground Slam, Bladesong Cadence |
| `force_reaction` | 139 | Makes a faction friendly or hostile. | none |
| `ranged_haste` | 140 | Ranged attack speed up by value%. | 1: Quick Fire |
| `ranged_ammo_haste` | 141 | Ranged attack speed up by value% (from ammo). | none |
| `base_resistance_percent` | 142 | Base resistances (or armour) of the `schools` up by value%. | 15: Toughness, Woven Mail |
| `resistance_exclusive` | 143 | Adds value resistance, the highest of these only. | 14: Shadow Warding, Wild Spirit, Gloomward Presence |
| `safe_fall` | 144 | Takes less falling damage. | none |
| `charisma` | 145 | Better prices. | none |
| `persuaded` | 146 | Persuaded. | none |
| `mechanic_immunity_mask` | 147 | Immune to several mechanics. | none |
| `retain_combo_points` | 148 | Keeps combo points. | none |
| `resist_pushback` | 149 | value% less spell pushback when hit while casting. | 1: Focused Presence |
| `shield_block_value_percent` | 150 | Shield block value up by value%. | 3: Shield Craft |
| `track_stealthed` | 151 | Sees stealthed units. | 1: Track Hidden |
| `detected_range` | 152 | Changes the range at which the target notices others. | none |
| `split_damage_flat` | 153 | Moves value damage taken to the caster. | 2: Boon of the Martyr |
| `stealth_level` | 154 | Better stealth. | none |
| `water_breathing_percent` | 155 | Breath lasts value% longer. | none |
| `reputation_gain` | 156 | More reputation. | none |
| `pet_damage_multiplier` | 157 | Pet damage changed by value%. | none |
| `shield_block_value` | 158 | Adds value to shield block value. | none |
| `no_pvp_credit` | 159 | Gives no honor. | none |
| `aoe_avoidance` | 160 | Takes less area damage. | none |
| `health_regen_in_combat` | 161 | Restores health in combat. | none |
| `power_burn_mana` | 162 | Burns mana. | none |
| `crit_damage_bonus` | 163 | Crits deal value% more damage. | none |
| `melee_attack_power_attacker_bonus` | 165 | Attackers get value melee attack power against the target. | none |
| `attack_power_percent` | 166 | Melee attack power up by value%. | none |
| `ranged_attack_power_percent` | 167 | Ranged attack power up by value%. | none |
| `damage_done_versus` | 168 | Damage done to the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid) up by value% (Monster Hunter). | 6: Manhunter |
| `crit_percent_versus` | 169 | Crit chance against the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid) up by value% (Manhunter). | 6: Manhunter |
| `detect_amore` | 170 | A holiday aura. | none |
| `speed_not_stack` | 171 | Run speed up by value% (the highest only). | none |
| `mounted_speed_not_stack` | 172 | Mounted speed up by value% (the highest only). | 2: Swift Justice |
| `allow_champion_spells` | 173 | Allows champion spells. | none |
| `spell_damage_of_stat_percent` | 174 | Spell damage up by value% of Intellect (`misc`: the schools, a mask). | 5: Spirit's Guidance |
| `spell_healing_of_stat_percent` | 175 | Healing up by value% of a stat. | 5: Spirit's Guidance |
| `spirit_of_redemption` | 176 | Lingers as a spirit after death. | none |
| `aoe_charm` | 177 | Charms all around. | none |
| `debuff_resistance` | 178 | Resists debuffs. | none |
| `attacker_spell_crit_chance` | 179 | Spells cast at the target crit value% more (or less). | none |
| `flat_spell_damage_versus` | 180 | Adds value spell damage against the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid). | none |
| `flat_spell_crit_damage_versus` | 181 | Adds value spell crit damage against the creature types in `misc` (a mask: 1 beast, 2 dragonkin, 4 demon, 8 elemental, 16 giant, 32 undead, 64 humanoid). | none |
| `resistance_of_stat_percent` | 182 | Resistances up by value% of a stat. | none |
| `critical_threat` | 183 | Crits cause value% threat. | none |
| `attacker_melee_hit_chance` | 184 | Melee attacks against the target hit value% more (or less). | none |
| `attacker_ranged_hit_chance` | 185 | Ranged attacks against the target hit value% more (or less). | none |
| `attacker_spell_hit_chance` | 186 | Spells against the target hit value% more (or less). | none |
| `attacker_melee_crit_chance` | 187 | Melee attacks against the target crit value% more (or less). | none |
| `attacker_ranged_crit_chance` | 188 | Ranged attacks against the target crit value% more (or less). | none |
| `rating` | 189 | A combat rating (later games). | none |
| `faction_reputation_gain` | 190 | More reputation with a faction. | none |
| `control_duration_percent` | 1001 | The game's own: crowd control (stuns, roots, fears...) on the target lasts value% longer or shorter. | 3: Steadfast Glyphs |
| `crit_damage_taken_percent` | 1002 | The game's own: crits against the target deal value% more or less damage. | 2: Rooted Stance |

## target

An effect's `target` and `target_b`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `none` | 0 | No target of its own (the spell's target). | none |
| `self` | 1 | The caster. | 916: Veil of Humility, Bastion Stance, Two-Weapon Fighting |
| `random_enemy_chain_in_area` | 3 | Enemies near the target, one jumping to the next. | none |
| `random_friend_chain_in_area` | 4 | Friends near the target, one jumping to the next. | none |
| `pet` | 5 | The caster's pet. | 12: Mend Companion |
| `enemy` | 6 | The enemy targeted. | 327: Calm Mind, Shield Smash, Auto Shot |
| `area_custom` | 7 | An area set by the spell's script. | none |
| `area_around_target` | 8 | Everyone in the radius around the target. | none |
| `enemies_in_area` | 15 | Enemies in the radius around the place targeted. | 30: Dread Wail, Daunting Roar, Blast Trap Effect |
| `enemies_in_area_instant` | 16 | Enemies in the radius around the place targeted, at once. | 5: Hallowed Ground |
| `location` | 18 | A place. | 5: Hallowed Ground |
| `party_around_caster` | 20 | The caster's party within the radius. | 17: Communal Mending, Rallying Cry |
| `friend` | 21 | The friendly unit targeted. | 95: Lingering Grace, Last Rite |
| `caster_location` | 22 | Where the caster stands. | 33: Font of Light, Daunting Roar, Blast Trap Effect |
| `game_object` | 23 | An object in the world. | none |
| `cone_in_front` | 24 | Everyone in a cone in front of the caster. | none |
| `any_unit` | 25 | Any unit targeted. | 15: Unweave, Quarry's Mark, Radiant Jolt |
| `game_object_item` | 26 | An object or an item. | none |
| `master` | 27 | The pet's owner. | none |
| `enemies_in_area_channeled` | 28 | Enemies in the radius around the place targeted, while channelled (Arrow Rain). | 7: Arrow Rain |
| `friends_around_caster` | 30 | Friends within the radius of the caster. | none |
| `friends_in_area` | 31 | Friends in the radius around the place targeted. | none |
| `minion` | 32 | The caster's minion. | 1: Call Pet |
| `party` | 33 | The target's whole party. | none |
| `party_around_caster_2` | 34 | The caster's party within the radius. | none |
| `party_member` | 35 | A party member. | none |
| `party_around_target` | 37 | The target's party within the radius. | 1: Communal Spirit |
| `script` | 38 | A creature or object picked by the spell's script. | none |
| `self_fishing` | 39 | The caster's fishing spot. | none |
| `chain_heal` | 45 | Friends near the target, jumping between them. | none |
| `script_location` | 46 | A place picked by the spell's script. | none |
| `front_of_caster` | 47 | Just in front of the caster. | 16: Font of Light, Revive Pet |
| `enemy_location` | 53 | Where the targeted enemy stands. | none |
| `raid_around_caster` | 56 | The caster's raid within the radius. | none |
| `party_or_raid_member` | 57 | A member of the caster's party or raid. | 17: Sanctified Ward, Boon of Shelter |

## proc_on

What makes a proc aura fire (`proc_on`).

| Name | Number | What it does | In the game |
|---|---|---|---|
| `killed` | 0x1 | The holder is killed. | none |
| `kill` | 0x2 | The holder kills something that gives experience. | 5: Spirit Harvest |
| `melee_hit_done` | 0x4 | The holder lands a white melee swing. | 62: Swordsman's Craft, Menace, Righteous Rebuke |
| `melee_hit_taken` | 0x8 | The holder is hit by a white melee swing. | 77: Inner Flame, Shield Brace, Frighten Beast |
| `melee_ability_done` | 0x10 | The holder lands a melee ability. | 75: Stillness, Swordsman's Craft, Hawk Spirit |
| `melee_ability_taken` | 0x20 | The holder is hit by a melee ability. | 77: Inner Flame, Shield Brace, Frighten Beast |
| `ranged_hit_done` | 0x40 | The holder lands a ranged auto-attack. | 49: Stillness, Improved Hobble, Hawk Spirit |
| `ranged_hit_taken` | 0x80 | The holder is hit by a ranged auto-attack. | 61: Inner Flame, Shield Brace, Frighten Beast |
| `ranged_ability_done` | 0x100 | The holder lands a ranged ability. | 49: Stillness, Improved Hobble, Hawk Spirit |
| `ranged_ability_taken` | 0x200 | The holder is hit by a ranged ability. | 61: Inner Flame, Shield Brace, Frighten Beast |
| `helpful_area_done` | 0x400 | The holder casts a helpful area spell. | 46: Stillness, Improved Hobble, Hawk Spirit |
| `helpful_area_taken` | 0x800 | The holder is touched by a helpful area spell. | none |
| `harmful_area_done` | 0x1000 | The holder casts a harmful area spell. | 51: Stillness, Improved Hobble, Hawk Spirit |
| `harmful_area_taken` | 0x2000 | The holder is hit by a harmful area spell. | 42: Dread Ward, Cowing Roar, Frighten Beast |
| `helpful_spell_done` | 0x4000 | The holder casts a helpful spell. | 47: Stillness, Improved Hobble, Hawk Spirit |
| `helpful_spell_taken` | 0x8000 | The holder gets a helpful spell. | none |
| `harmful_spell_done` | 0x10000 | The holder lands a harmful spell. | 51: Stillness, Improved Hobble, Hawk Spirit |
| `harmful_spell_taken` | 0x20000 | The holder is hit by a harmful spell. | 48: Dread Ward, Cowing Roar, Frighten Beast |
| `periodic_done` | 0x40000 | A periodic effect of the holder's ticks. | 1: Ensnaring Traps |
| `periodic_taken` | 0x80000 | A periodic effect ticks on the holder. | 12: Dread Wail, Cowing Roar, Frighten Beast |
| `any_damage_taken` | 0x100000 | The holder takes any damage. | 3: Drake Sting |
| `trap_triggered` | 0x200000 | A trap of the holder's fires. | 5: Ensnaring Traps |
| `offhand_hit_taken` | 0x400000 | The holder is hit by an off-hand swing. | none |
| `offhand_hit_done` | 0x800000 | The holder lands an off-hand swing. | none |

## attributes

A spell's `attributes` (classic's Attributes bits). Most are kept from classic and not read; each says which. `attributes_ex`, `attributes_ex2` and `attributes_ex3` take hex bits such as `"0x4"`: FIELDS.md lists the ones the game reads.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `ranged` | 0x2 | A ranged attack (uses the ranged weapon). Not read by the game. | 48: Auto Shot |
| `on_next_swing` | 0x4 | Replaces the next melee swing (Mighty Blow) rather than striking at once. The game reads it. | 21: Mighty Blow, Talon Strike |
| `ability` | 0x10 | An ability rather than a spell (melee and ranged skills). Not read by the game. | 659: Quick Mind, Bastion Stance, Auto Shot |
| `trade_spell` | 0x20 | A trade skill recipe. Not read by the game. | none |
| `passive` | 0x40 | Always on: no casting, applied when learned (talents, passives). The game reads it. | 711: Quick Mind, Two-Weapon Fighting, Parry |
| `hidden` | 0x80 | Not shown in the buff bar or spellbook. Not read by the game. | 575: Quick Mind, Plate Mail, Mail |
| `hide_in_combat_log` | 0x100 | Not shown in the combat log. Not read by the game. | 546: Quick Mind, Finishing Blow, Tame Beast |
| `target_main_hand_item` | 0x200 | Works on the main-hand weapon. Not read by the game. | none |
| `on_next_swing_2` | 0x400 | Replaces the next melee swing (another kind). Not read by the game. | 8: Talon Strike |
| `daytime_only` | 0x1000 | Only by day. Not read by the game. | none |
| `night_only` | 0x2000 | Only at night. Not read by the game. | none |
| `indoors_only` | 0x4000 | Only indoors. Not read by the game. | none |
| `outdoors_only` | 0x8000 | Only outdoors. Not read by the game. | 2: Distant Gaze |
| `not_shapeshifted` | 0x10000 | Can't be cast in a shapeshift form (stances and Presences don't count). Not read by the game. | 611: Sanctified Ward, Bastion Stance, Auto Shot |
| `only_stealthed` | 0x20000 | Only in stealth. Not read by the game. | none |
| `keeps_sheath` | 0x40000 | Classic's: casting it leaves weapons as they are (the game decides by `damage_class` instead). Not read by the game. | 413: Sanctified Ward, Bastion Stance, Auto Shot |
| `level_damage_calculation` | 0x80000 | A creature's spell: its damage and cost scale to the creature's level, up to `max_level`. The game reads it. | none |
| `stop_attack_target` | 0x100000 | Stops auto-attack when cast. Not read by the game. | 15: Dominate Will, Break Away, Contrition |
| `cannot_be_avoided` | 0x200000 | Can't be dodged, parried or blocked. Not read by the game. | 12: Riposte Strike, Counterattack, Verdict of Dominion |
| `set_tracking_target` | 0x400000 | Sets the tracking target. Not read by the game. | 6: Careful Shot |
| `castable_while_dead` | 0x800000 | Can be cast while dead. Not read by the game. | 3: Drake Sting |
| `castable_while_mounted` | 0x1000000 | Can be cast while mounted. Not read by the game. | 43: Umbral Guard, Bastion Stance, Track Beasts |
| `disabled_while_active` | 0x2000000 | Its cooldown starts only when its aura ends (Stealth-like). Not read by the game. | 4: Stillness, Still as Death, Heaven's Favor |
| `negative` | 0x4000000 | Counts as a debuff. Not read by the game. | 8: Borrowed Eyes, Death Craving, Quarry's Mark |
| `castable_while_sitting` | 0x8000000 | Can be cast sitting. Not read by the game. | 41: Leeching Embrace, Bastion Stance, Track Beasts |
| `not_in_combat` | 0x10000000 | Can't be cast in combat. The game reads it. | 28: Rite of Return, Rush, Frostbind Trap |
| `ignores_invulnerability` | 0x20000000 | Hits even invulnerable targets. Not read by the game. | 6: Rush, Hallowed Ransom |
| `heartbeat_resist` | 0x40000000 | Its effect may break early by a resist roll every few seconds (roots, fears). Not read by the game. | 11: Dominate Will, Frighten Beast, Rebuke the Dead |
| `cannot_cancel` | 0x80000000 | Its aura can't be right-clicked off. Not read by the game. | none |

## form

A spell's `stances` (the forms or stances it needs) and a shapeshift aura's `form`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `cat` | 1 | Cat Form. | none |
| `tree` | 2 | Tree of Life form. | none |
| `travel` | 3 | Travel Form. | none |
| `aquatic` | 4 | Aquatic Form. | none |
| `bear` | 5 | Bear Form. | none |
| `ambient` | 6 | An ambient form. | none |
| `ghoul` | 7 | Ghoul form. | none |
| `dire_bear` | 8 | Dire Bear Form. | none |
| `vanguard` | 17 | The Man-at-Arms' Vanguard Stance (classic Battle Stance). | 39: Shield Smash |
| `bastion` | 18 | The Man-at-Arms' Bastion Stance (Defensive Stance). | 25: Bastion Stance |
| `fury` | 19 | The Man-at-Arms' Fury Stance (Berserker Stance). | 16: Cyclone Strike |
| `bladesong` | 20 | The Spellsword's Bladesong Form. | 6: Bladesong Form |
| `wardweave` | 21 | The Spellsword's Wardweave Form. | 3: Wardweave Form |
| `flight` | 27 | Flight Form. | none |
| `stealth` | 28 | Stealth (as a form). | 123: Sanctified Ward |
| `moonkin` | 29 | Moonkin Form. | none |
| `spirit_of_redemption` | 30 | Spirit of Redemption. | none |

## item_types (weapons)

`item_types` when `requires_item` is `weapon`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `axe` | 0 | One-handed axes. | 107: Mighty Blow, Break Away, Parry |
| `axe_2h` | 1 | Two-handed axes. | 105: Mighty Blow, Break Away, Parry |
| `bow` | 2 | Bows. | 58: Auto Shot |
| `gun` | 3 | Guns. | 58: Auto Shot |
| `mace` | 4 | One-handed maces. | 107: Mighty Blow, Break Away, Parry |
| `mace_2h` | 5 | Two-handed maces. | 105: Mighty Blow, Break Away, Parry |
| `polearm` | 6 | Polearms. | 105: Mighty Blow, Break Away, Parry |
| `sword` | 7 | One-handed swords. | 112: Mighty Blow, Break Away, Parry |
| `sword_2h` | 8 | Two-handed swords. | 110: Mighty Blow, Break Away, Parry |
| `staff` | 10 | Staves. | 100: Mighty Blow, Break Away, Parry |
| `fist` | 13 | Fist weapons. | 99: Mighty Blow, Break Away, Parry |
| `misc` | 14 | Miscellaneous weapons. | none |
| `dagger` | 15 | Daggers. | 102: Mighty Blow, Break Away, Parry |
| `thrown` | 16 | Thrown weapons. | 5: Deadly Aim |
| `spear` | 17 | Spears (unused in classic). | 105: Mighty Blow, Break Away, Parry |
| `crossbow` | 18 | Crossbows. | 58: Auto Shot |
| `wand` | 19 | Wands. | 5: Wandwork |
| `fishing_pole` | 20 | Fishing poles. | none |

## item_types (armour)

`item_types` when `requires_item` is `armor`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `misc` | 0 | Miscellaneous (rings, trinkets, held off-hand items). | none |
| `cloth` | 1 | Cloth armour. | none |
| `leather` | 2 | Leather armour. | none |
| `mail` | 3 | Mail armour. | 2: Mail |
| `plate` | 4 | Plate armour. | 1: Plate Mail |
| `buckler` | 5 | Bucklers. | none |
| `shield` | 6 | Shields. | 17: Shield Smash, Steadfast Guard |

## requires_item

What a spell needs equipped.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `none` | -1 | Nothing needed. | 640: Lingering Grace, Goad, Mend Companion |
| `consumable` | 0 | A consumable. | none |
| `weapon` | 2 | A weapon of the `item_types` held. | 198: Wandwork, Mighty Blow, Auto Shot |
| `armor` | 4 | Armour of the `item_types` worn (a shield counts: Shield Smash needs one). | 20: Shield Smash, Mail, Plate Mail |

## mechanic

A mechanic aura's `against` (immunity or resistance to it), which the game reads; also a spell's or effect's `mechanic`, which it doesn't (it knows a stun by its aura).

| Name | Number | What it does | In the game |
|---|---|---|---|
| `charm` | 1 | Charmed. | 8: Dominate Will, Iron Resolve |
| `disoriented` | 2 | Disoriented. | 3: Scattering Shot, Steadfast Faith |
| `disarm` | 3 | Disarmed. | 1: Wrest Weapon |
| `distract` | 4 | Distracted. | none |
| `fear` | 5 | Feared: runs away. | 19: Dread Ward, Abandon, Frighten Beast |
| `fumble` | 6 | Fumbling. | none |
| `root` | 7 | Rooted: can't move. | 8: Ensnaring Traps, Boon of Unfettering |
| `pacify` | 8 | Pacified: can't attack. | none |
| `silence` | 9 | Silenced: can't cast. | 7: Unbending Will, Focused Presence |
| `sleep` | 10 | Asleep. | 3: Drake Sting |
| `snare` | 11 | Snared: slowed. | 18: Mind Rend, Hobble, Crippling Cut |
| `stun` | 12 | Stunned. | 18: Unbending Will, Mace Stun, Beast Fury |
| `freeze` | 13 | Frozen. | none |
| `knockout` | 14 | Knocked out (Gouge). | 2: Unbridled Rage, Contrition |
| `bleed` | 15 | Bleeding (bleed effects). | 7: Gash |
| `bandage` | 16 | Bandaging (Recently Bandaged). | none |
| `polymorph` | 17 | Polymorphed. | none |
| `banish` | 18 | Banished. | none |
| `shield` | 19 | Shielded (Wards, Weakened Soul). | 10: Sanctified Ward |
| `shackle` | 20 | Shackled. | 2: Bind the Dead |
| `mount` | 21 | Mounted. | none |
| `persuade` | 22 | Persuaded. | none |
| `turn` | 23 | Turned (Turn Undead). | 3: Rebuke the Dead |
| `horror` | 24 | Horrified. | none |
| `invulnerability` | 25 | Invulnerable (Divine Shield). | 7: Hallowed Guard |
| `interrupt` | 26 | Interrupted. | 8: Steady Casting, Shield Smash, Focused Presence |
| `daze` | 27 | Dazed. | none |
| `discovery` | 28 | Discovered. | none |
| `immune_shield` | 29 | Immunity shield (Blessing of Protection). | none |
| `sapped` | 30 | Sapped. | none |

## dispel

A spell's `dispel` type, and a dispel effect's `dispel`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `magic` | 1 | Magic: removed by Dispel Magic, Cleanse and the like. | 217: Sanctified Ward, Shield Crush, Quarry's Mark |
| `curse` | 2 | Curse. | 13: Withering Touch |
| `disease` | 3 | Disease: removed by Cure Disease, Purify. | 10: Purge Sickness, Cleansing Touch |
| `poison` | 4 | Poison: removed by Cure Poison, Purify. | 23: Adder Sting, Cleansing Touch |
| `stealth` | 5 | Stealth. | none |
| `invisibility` | 6 | Invisibility. | none |
| `all` | 7 | Every type. | 1: Improved Mend Companion |
| `enrage` | 9 | Enrage. | none |

## creature_types

What a spell may target (`creature_types`).

| Name | Number | What it does | In the game |
|---|---|---|---|
| `beast` | 1 | Beasts. | 9: Beast's Eyes |
| `dragonkin` | 2 | Dragonkin. | none |
| `demon` | 3 | Demons. | 8: Banishment |
| `elemental` | 4 | Elementals. | none |
| `giant` | 5 | Giants. | none |
| `undead` | 6 | Undead. | 13: Bind the Dead, Banishment |
| `humanoid` | 7 | Humanoids. | 7: Calm Mind, Contrition |
| `critter` | 8 | Critters. | none |
| `mechanical` | 9 | Mechanicals. | none |
| `not_specified` | 10 | Creatures of no type. | none |

## stat

A stat aura's `stat`.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `all` | -1 | Every stat. | 2: Boon of Sovereigns |
| `strength` | 0 | Strength. | 12: Stinger Venom, Righteous Rebuke |
| `agility` | 1 | Agility. | 12: Stinger Venom, Righteous Rebuke |
| `stamina` | 2 | Stamina. | 9: Litany of Fortitude, Hardened Spirit |
| `intellect` | 3 | Intellect. | 10: Focused Study, Blessed Intellect |
| `spirit` | 4 | Spirit. | 5: Uplifted Spirit |

## modifies

What a spell modifier (`flat_modifier`, `percent_modifier`) changes.

| Name | Number | What it does | In the game |
|---|---|---|---|
| `damage` | 0 | Damage or healing done. | 20: Scorching Light, Barrage, Empowered Release |
| `duration` | 1 | Duration (milliseconds for a flat modifier). | 24: Improved Gnawing Shadow, Improved Shield Brace, Cunning Traps |
| `threat` | 2 | Threat caused. | 3: Shadow Kinship |
| `effect1` | 3 | The first effect's value. | 3: Replenishing Verdict |
| `charges` | 4 | Charges. | 3: Improved Shield Brace |
| `range` | 5 | Range in yards. | 10: Long Shadows, Keen Sight, Far Reach |
| `radius` | 6 | Area radius in yards. | 7: Far Grace, Carrying Voice |
| `crit_chance` | 7 | Crit chance in %. | 16: Stillness, Improved Riposte Strike, Brutal Strikes |
| `all_effects` | 8 | Every effect's value. | 118: Improved Inner Flame, Improved Rush, Cunning Traps |
| `pushback` | 9 | Pushback when hit while casting. | 9: Steady Casting, Steady Faith |
| `cast_time` | 10 | Cast time (milliseconds for a flat modifier). | 22: Improved Mana Scorch, Improved Heavy Swing, Improved Revive Companion |
| `cooldown` | 11 | Cooldown (milliseconds for a flat modifier). | 41: Improved Mind Lash, Improved Goad, Improved Glimmer Shot |
| `speed` | 12 | Run speed bonus (the Ranger's Trailblazing). | 2: Trailblazing |
| `cost` | 14 | Mana, rage or energy cost. | 37: Quick Mind, Improved Mighty Blow, Efficiency |
| `crit_damage` | 15 | Crit damage bonus in %. | 7: Deep Thrust, Grievous Shots |
| `resist_miss_chance` | 16 | Chance to be resisted or missed. | 9: Gloom Focus, Improved Still as Death |
| `jump_targets` | 17 | Targets a chain jumps to. | none |
| `chance_of_success` | 18 | Chance to succeed. | 10: Improved Hawk Spirit |
| `activation_time` | 19 | Time to activate. | none |
| `effect_past_first` | 20 | Effects after the first, for chains. | none |
| `global_cooldown` | 21 | The global cooldown. | none |
| `periodic_damage` | 22 | Periodic damage or healing. | 20: Scorching Light, Barrage |
| `effect3` | 23 | The third effect's value. | none |
| `spell_bonus_damage` | 24 | How much spell power adds. | none |
| `frequency_of_success` | 26 | How often it succeeds. | none |
| `multiple_value` | 27 | The effect's multiple value. | none |
| `resist_dispel_chance` | 28 | Chance to resist being dispelled. | none |
