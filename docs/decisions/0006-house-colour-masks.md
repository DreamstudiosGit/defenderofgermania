# 0006 — House colour masks and crests

- Context: the four houses (and later church and neutral lords) fight in their own colours; one model per unit and house would multiply the exports and every art change.
- Decision: one house-neutral Blender model per unit. Surfaces with the material names `house_primary` and `house_secondary` are white masks that the figure shader tints with per-batch instance uniforms (`unit_motion.gdshader`, `house_slot`). Each house has one oversized crest export (`crest_lion`, `crest_eagle`, `crest_antlers`, `crest_wings`; mapping in `data/combat_art.json` `crests`) that `BattleModels.unit_mesh` mounts at the unit's `crest_anchor` node; units without a helmet (levy, brabanters, trebuchet) have no anchor.
- Decision: the HUD group shields are generated per house from the house colours in `data/map.json` (`art-src/ui/combat/build_combat_shields.py`).
- Consequences: a new house needs colours in `data/map.json`, a crest export, a `crests` entry and a shield rebuild — no new unit models. Figures still animate through UV2 limb masks on the GPU; the skeletal clips in the exports are for editing and future use. Camp props keep their blue/red markings for now.
