# Trebuchet siege (combat_siege)

The GDD's "Blide-Minispiel" (Abenteuer-Module → Belagerung): the attacker bombards a castle built from kit parts in a side view; a breach lets the storm follow at once. Rules in `src/systems/combat/siege/`, scene in `src/render/siege/`, HUD in `src/ui/siege/`, values in `data/combat_siege.json` (rules) and `data/combat_siege_art.json` (presentation).

## Rules as built

- **Side view.** x is the distance from the trebuchet (castle front at `ballistics.castle_front` = 150 m), y the height. Each castle kit is a cross-section along the line of fire: parts are rectangles relative to the castle front (`layouts.<kit>.parts[].rect` = x0, y0, x1, y1). The kit follows the castle like the castle view: home castles and castles above province level 3 use `home_<level>`, others `province_<level>`.
- **Wall HP.** 400 × wall level (`wall_hp_per_level`), spread over the parts by `hp_share` (shares add up to 1 per kit; mounds have 0 and only block). HP are whole numbers.
- **Aim.** Counterweight 0–100 % sets the launch speed between `speed_min` and `speed_max`; the release angle runs 20–70°. The stone leaves the sling at `release`, falls with `gravity` and is pushed along x by the wind (`wind × acceleration_per_mps`). The fire pot is lighter (`speed_factor` 1.06).
- **Wind and preview.** Each shot's wind (−6…6 m/s, tenths) is rolled from the seed when the bombardment starts and shown before aiming; the player also sees the first `preview_share` (20 %) of the unobstructed flight. Nothing else is random.
- **Shots.** 3 + 2 × trebuchets (`shots`). From wall level 3 (`counterfire.from_wall`) every third shot (`counterfire.every`) is lost to counterfire; fires keep burning in that slot.
- **Impact.** The path is stepped at `step_rate` (120 Hz) and hits the first standing part (or the ground) it enters.
  - Stone: 240 damage to that part (`projectiles.stone.damage`).
  - Fire pot: garrison −0.08 of its full health per hit (`garrison_damage`; a hit is a part or the bailey ground between the front and the rear of the castle); a wooden part it strikes catches fire.
  - Burning: a burning part loses `burning.share_per_shot` (34 %) of its HP at the end of every shot slot, starting with the shot that lit it, so wood burns down within three slots.
- **Collapse** (data-driven, per part): a destroyed part brings down every part listing it in `supported_by` (they fall at once), and crashes onto each part in its `falls_onto` for `collapse.fall_damage_share` (0.75) × its own max HP. Crushed parts can fall in turn; the queue runs in data order. Examples: the wooden hoarding on a gatehouse rests on the gate and falls onto it; a felled keep crushes the hall; the Kaiserpfalz spire rests on the keep.
- **Breach.** The first part of kind `wall` or `gate` at 0 HP opens the breach and ends the bombardment at once (the campaign's storm follows without the wall bonus at that segment). Without a breach the siege goes on next round.
- **Earlier damage.** `TrebuchetSetup.wall_damage` (the campaign's `ProvinceState.wall_damage`) is spread evenly: every part starts at `round(max_hp × (1 − wall_damage))`, at least 1 HP while the share is below 1; at 1 the wall is gone and the result is a breach without a shot. `TrebuchetResult.wall_damage` is the earlier share plus this bombardment's (`wall_damage_dealt`), capped at 1, for the campaign to store back.
- **Duration.** Per shot: aiming (the player's time, at most `timing.aim_limit_seconds` = 20 s, then the captain throws anyway) + throw (2 s) + flight (4–6 s) + settle (3 s); a counterfire slot costs 3 s. With 10 s of aiming a full bombardment of 1–2 trebuchets takes roughly 80–145 s, an early breach less; 3 or more trebuchets can run past 3 minutes when every shot is used.

| Kit | Parts (front → rear; breach segments in bold) |
| --- | --- |
| province_1 (Holzburg) | **wooden gate**, wood tower (falls onto the rear palisade), **rear palisade** |
| province_2 (Steinburg) | **stone gatehouse (¾ size)** with wooden hoarding, wood hall, keep (falls onto the hall), **rear wall** |
| province_3 (Festung) | **gatehouse** with hoarding, wood hall, keep (falls onto the hall), **rear wall** |
| home_1 (Motte) | **wooden gate**, hall, motte with wood tower (falls onto the hall), **rear palisade** |
| home_2 (Bergfried) | **wooden gate**, hall, motte with keep (falls onto the hall), **rear palisade** |
| home_3–5 | **gatehouse** with hoarding, hall / palas / Pfalz, motte with keep (falls onto the building), on home_5 the spire on the keep, **rear wall** |

### Computer crew

`TrebuchetAimer` throws stones at the middle of the front-most standing wall or gate segment: it solves the counterweight for its angle by bisection on the same ballistics, allowing for its share of the wind (`wind_awareness`), then adds its fixed error pattern (`counterweight_errors`, `angle_errors`, cycled per shot). Over 40 seeds with one trebuchet the crews breach a wall-3 gatehouse about 15 % / 33 % / 68 % / 100 % of the time (skill 0–3) and hit with about 59 % / 68 % / 81 % / 100 % of their stones. The scene uses `ai.campaign_skill` (2).

## Data keys

`data/combat_siege.json` (typed loader `SiegeConfig`, checks in `SiegeConfigCheck`): `wall_hp_per_level`, `shots.base|per_trebuchet`, `counterfire.from_wall|every`, `projectiles.<stone|fire_pot>.damage|garrison_damage|ignites|speed_factor`, `burning.share_per_shot`, `collapse.fall_damage_share`, `wind.min|max|acceleration_per_mps`, `ballistics.gravity|release|speed_min|speed_max|counterweight|angle_deg|start|step_rate|max_flight_seconds|preview_share|castle_front`, `timing.aim_limit_seconds|typical_aim_seconds|throw_seconds|settle_seconds|counterfire_seconds`, `practice` (the practice setup), `ai.campaign_skill|skills[]` and `layouts.<kit>.parts[].id|kind|material|rect|hp_share|supported_by|falls_onto`. Kinds: wall, gate, hoarding, tower, keep, building, roof, mound; materials: wood, stone, earth.

`data/combat_siege_art.json` (read by `SiegeArt`): light, ground (road with range stones every 25 m, fields, woods, village), pacing (the computer's aiming and hold time, headless speed), trebuchet placement and release moment, projectile and preview look, camera framings (aim, castle, follow), fire, dust, falling and rubble, ring styles and per kit the piece of every part, the ring (front, rear, half width, gate opening, tower roofs) and decorations (optionally attached to a part so they fall with it).

## Scene contract

`res://src/render/siege/trebuchet_main.tscn`:

- `func configure_campaign(setup: TrebuchetSetup, devices: PackedInt32Array, seed_value: int) -> void` before adding it to the tree; `devices[0]` is the attacker's `BattleInputMap.Device` or -1 for the computer's crew.
- `signal finished(result: TrebuchetResult)`: a human presses "continue" on the result; a computer siege reports 2.5 s after its result shows. The result equals `TrebuchetAimer.new(cfg, cfg.campaign_skill).play(TrebuchetSim.new(cfg, setup, seed))` for computer sieges (tested).
- Opened directly it is the practice: the default setup from `practice`, the how-to first, "again" (next seed) and "quit" (closes the game, or reports `finished` when a menu opened it). Headless it lets the computer play at 8× speed.
- `TrebuchetSetup`: attacker house, defender owner (house id or neutral/church/elector), wall level, home castle flag and castle level (kit), trebuchets, garrison health share, earlier wall damage, practice flag. `TrebuchetResult`: breach, `breach_part` and `breach_kind` (gate/wall), `wall_damage` (total share), `wall_damage_dealt`, `garrison_damage` (share of full health), shots fired and lost, hits, `duration_seconds`.

Controls (keyboard + mouse and controller as equals, `SiegeInputMap` after the battle's per-device actions): A/D or ←/→, left stick or d-pad left/right: counterweight; W/S or ↑/↓, stick or d-pad up/down: angle (tap one step, hold to repeat); mouse wheel (Shift: angle) or the HUD sliders; Q/E/Tab, X or LB/RB: stone or fire pot; Space/Enter, A or the button: loose; hold C, Y or LT: look at the castle; Esc/H/F1, Start/Back: help (in practice with again and quit).

## Determinism

The rules decide everything: hits, damage, collapse, burning and the breach come from `TrebuchetSim`, a pure per-shot model whose inputs are whole numbers (counterweight in %, angle in degrees, projectile), with seeded wind rolled up front. It only uses + − × ÷ and `sqrt` (IEEE-exact on every platform); sine and cosine come from a fixed Taylor polynomial instead of the platform's libm; the path is stepped at a fixed rate with closed-form positions (no accumulated error); HP are integers. The same setup, seed and shots give the same result everywhere, so replays, saves and async play agree.

Jolt only tumbles the visual pieces of parts the rules already destroyed (`SiegeCastleView`): a destroyed part becomes a rigid body pushed away from the trebuchet, freezes after 3.5 s, sinks into a rubble heap and is never read back. Jolt is not used for the rules because its results depend on step timing, solver iteration order and float behaviour across platforms and builds; proving it deterministic would cost more than a rules model that is deterministic by construction.

## Art

The castle is assembled from the M4 kit (`assets/economy/castle_*.glb`: gatehouse, keep, wood tower, wood hall, palas, Pfalz, chapel, motte, spire, tower roofs) and a side-view siege kit in the same shapes and palette (`assets/combat/siege_*.glb`: wall, palisade and palisade-gate segments, wall tower, hoarding, rubble, stone, fire pot), built by `art-src/combat/build_siege_kit.py` (Blender 5.2; reuses `art-src/economy/castle_shapes.py`). The trebuchet is the battle's `unit_trebuchet.glb` with its `idle` and `attack` clips, pennant and crew in the attacker's colour; the defender's colours go on the kit's house masks. Scenery comes from `assets/combat/` and `assets/economy/settlement_*`, the ink and grain pass is `BattleInk`.
