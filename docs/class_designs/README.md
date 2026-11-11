# Class designs

Ideas for new classes, kept here until we decide whether to add them. Each
design is one JSON file (the source) and an HTML page built from it to browse
everything about the class: abilities by level, talent trees with a talent
calculator, mechanics, items it needs, playerbot behaviour and what adding it
would take.

Check a design (grid slots, prerequisite lines, icons, builds against the
talent rules), then rebuild its page after editing its JSON:

    python tools/class_designs/check_design.py docs/class_designs/<class>.json
    python tools/class_designs/build_viewer.py docs/class_designs/<class>.json

The page embeds the game's icons (`assets/icons/`) and opens on its own in a
browser. `tools/class_designs/viewer_template.html` is the page's template.

| Class | Status | Files | Published page |
|---|---|---|---|
| Banneret: a knight who fights with spear and polearm under their own banner and commands the party (Morale, 5 banners, 7 Orders; Standard, Command and Lance trees; 15 new low-level polearms) | Parked: designed 2026-11-10, not decided | `banneret.json`, `banneret.html` | https://claude.ai/artifact/4hQS91oo4MR3bSjrg8PzZn |
| Spellsword: a swordsman who writes spells into the blade, tank or melee damage (Mana and Resonance, 4 Edges, Release, Bladesong and Wardweave Forms; Bladesong, Wardweave and Arcana trees) | Added to the game 2026-11-11 (its data: `tools/class_designs/build_class_data.py` → `data/classes/spellsword.json`) | `spellsword.json`, `spellsword.html` | https://claude.ai/artifact/4gezh7yxaAeZhQn2KayLcy |
