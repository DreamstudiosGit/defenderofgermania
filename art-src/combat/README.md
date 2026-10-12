# Combat art

The 45 game exports in `assets/combat/` have matching editable `.blend` sources here. Names use English lowercase snake_case: `unit_spearman_blue`, `unit_knight_red`, `terrain_river_straight`, `tree_oak_autumn`, etc. The catalogue manifest lists dimensions, triangle counts and animation names.

The seven unit types have blue and red variants. Foot soldiers and mounted units have rigid bone animations `idle`, `walk`, `attack`, `death`. Runtime MultiMesh rendering uses the rest mesh and GPU limb motion instead of instantiating a skeleton per figure. Spears remain separate in the renderer for formation-dependent tilt; the standalone spearman export includes the held spear.

Blender uses Z up and -Y forward. Exported glTF uses Y up and +Z forward, metres, with ground-centred pivots. UV2 stores stride weight and left/right phase; it must not be repurposed for lightmaps on unit models.

Rebuild with Blender 5.2:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python art-src/combat/build_combat_assets.py
godot --headless --import
```

`combat_asset_catalog.blend` is the editable overview; `combat_asset_catalog.png` is its render. `combat_battle_preview.png` and `combat_unit_preview.png` show the real prototype. `landscape_summer_meadow.png`, `landscape_river_valley.png`, `landscape_autumn_woodland.png` show the composition previews.

Run `godot res://src/render/battle/combat_art_preview.tscn` to inspect the moving landscapes; keys 1–3 switch presets. The compact preview stages a central river and bridge without running combat. The real prototype keeps its decorative river outside the playable area: traversable river terrain and bridge pathfinding are not implemented by this art change.

`data/combat_art.json` controls palettes, density, water and wind. The matching shader files live under `src/render/battle/`.
