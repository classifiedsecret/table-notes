# Vanguard's Descent (source)

Godot 4.7.2 project for the D&D platformer at https://session-scribe.com/game/.
The exported web build lives in `../game/`; this folder is the source.

- `scripts/rules/` rules core (dice, attacks, damage, saves, death saves). Tests: `godot --headless --script res://tests/test_rules.gd`
- `scripts/data/` stat blocks and the generated atlas lookup
- `scripts/game/` real-time layer (player, goblins, room, HUD, pop-ups)
- `rooms/` text-grid room layouts
- `tools/make_sprites.py` builds the recoloured sprite strips from the 0x72 atlas
- `save-bridge.js` page-side bridge to the site's Firestore campaign data

Export: `godot --headless --export-release "Web" ../game/index.html`, then copy `save-bridge.js`,
`CREDITS.txt` and a `firebase-config.js` (the site's public web config) next to it.
Credits and licences: `CREDITS.txt` and `assets/licenses/`.
