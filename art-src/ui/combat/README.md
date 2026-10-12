# Combat shield vector masters

The editable SVG masters and runtime copies are original vector artwork based on the supplied battle reference. They use paths, linear/radial gradients and layered strokes, with no external fonts, bitmap images or filters.

Run `python art-src/ui/combat/build_combat_shields.py` from the repository root to rebuild the SVG files in this folder and `assets/ui/combat/`. The generator also writes `combat_shield_catalog.html` for a browser preview. Import assets in Godot after rebuilding.

Each team has infantry, crossbow, cavalry and siege crests. Infantry carries a steel spear and wooden shield; cavalry uses a sculpted gold horse head; siege shows a trebuchet and three stone balls. The selection glow is a separate SVG layer, allowing the HUD to apply the existing single-player visibility policy. Crown and bolt status icons remain separate from the crest art.
