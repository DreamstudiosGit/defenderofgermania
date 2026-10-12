# Castle raid

The castle raid minigame of M6 (GDD "Abenteuer-Module" → "Burgüberfall"): the leader alone in a torch-lit castle, side view, against 3–6 guards one after another. Rules in `src/systems/combat/raid/`, values in `data/combat_raid.json` (`RaidConfig`, sections typed by `RaidRules`), the leader's blade values from `data/combat.json` → `leader_skills.blade` (`CombatConfig`). Presentation in `src/render/raid/` (scene `raid_main.tscn`, values in `data/combat_raid_art.json`), HUD and menus in `src/ui/raid/`, fighters from `art-src/combat/build_raid_assets.py`.

## Contract
- `RaidSetup` (from the campaign): `raider_house`, `blade` (0–5), `target` (`treasury`, `dungeon`, `granary`, `regalia`), `defender_owner` (house id, `neutral`, `church`, `elector`), `castle_level` with `home_castle` (home 1–5, province 1–3; an open province has no castle), `guard_skill` (0–3), `practice`. `validate()` lists every problem; `RaidSim` refuses a broken setup (errors pushed, raid over at once, failed result).
- `RaidResult`: `success`, `target`, `outcome` (`SUCCESS`, `CAPTURED`, `ESCAPED_WOUNDED`), `time_used` (raid seconds, without intro), `alarm_raised`, `guards_defeated`, `guards_avoided`, `practice`.
- `RaidSim.new(cfg, setup, seed)`, `step(RaidInput)` at 30 Hz, `is_over()`, `result()`. Deterministic: no clocks or global randomness; the seed only picks which posts get sneak paths, cellar or gallery, and where each guard starts in its patterns. Same setup, seed and inputs give the same `RaidState.checksum()` every tick.
- `RaidInput` per tick: `move` (−1…1), `strike` / `parry` (height 0 high, 1 middle, 2 low, −1 none; a parry wins over a strike), `act` (held: sneak path at its entrance, deed in the target room), `flee`. The simulation clamps everything.
- `RaidAI.new(cfg, skill, seed)` plays the leader (`think(sim) -> RaidInput`); `RaidAI.auto_resolve(cfg, setup, seed, skill)` plays a whole raid headless.
- Rewards for the campaign: `cfg.prestige(target)` (+3, regalia +10), `cfg.treasury_loot(enemy_taler)` (20 %, at most 200), `cfg.granary_loss(enemy_grain)` (30 %), `cfg.church_ban_chance` (0.25). Applying them, the trigger (leader in or next to an enemy castle, one raid per round), the dungeon's prisoners, regalia only where the true ones lie, ransom, wound (no aura next round) and the ban roll are campaign work.

## Rules
- Time: 120 s of raid. After 60 s the alarm sounds; the castle's reinforcements come through a door at the far end of the target room, one every 7 s, and march towards the leader. Time out: the leader slips away wounded. Health 0: captured. `flee`: escaped wounded. Deed done: success.
- Layout: one corridor. Posts at `entry_length + i · post_spacing`, the target room `door_gap` after the last post, the deed spot at `deed_at` of the room. Guards per castle: `castles.home` / `castles.province` by level — the data follow "2 + wall level" (home 1–5: 3, 4, 5, 5, 6; province 1–3: 3, 4, 5).
- Sneak paths: `sneak_paths` of the castle's posts (never the one before the target door) have a way round, from `sneak_before` before the post to `sneak_after` behind it. Holding `act` at the entrance takes it while its guard still stands unaware at its post; holding forward crosses it in `sneak_seconds` (12 s for 12 m that take 4 s to walk). Nobody sees the leader there; the guard stays behind, avoided.
- A guard wakes when the leader comes within `engage_distance` (5 m), steps up to `fight_distance` (1.5 m) and fights; only the guard in front fights, the others wait at their posts or queue behind it.
- Guard patterns per skill (`guards.skills[0–3]`): it covers one height (`stances`, next one every `stance_ms`), attacks after `idle_ms` with a `windup_ms` telegraph in the fixed order of `attacks`, recovers `recover_ms`. From skill 1 a hit makes it cover the height it was hit at (`adapts`), and on the beat of `reacts` it turns its cover towards the leader's blow `react_ms` after he winds up (skill 3: two blows of three). A blocked blow is its cue: it strikes back at once.
- Leader: blow = `strike_windup_ms` (300) windup, lands, `strike_recover_ms`; costs `strike_cost` (24) of 100 stamina, which returns at 18/s after 0.6 s without spending. A blow at a covered height is blocked (`blocked_recover_ms` 400, still short enough to parry the counter); otherwise it hits for `strike_damage · (1 + 0.1 · blade)`, staggers the guard and cancels its windup — except mid-swing, where the guard takes `windup_damage_factor` (½) and strikes on.
- Parry: `parry_cost` (6) stamina; holds at its height for 150 + 20 × blade ms — a parry pressed k ticks before the blow lands holds while k × 33.3 ms ≤ window (`RaidConfig.parry_ticks`). A held parry leaves the guard open for `open_ms` (riposte); the leader is ready at once. A late, early or wrong parry takes the guard's `damage` and staggers the leader.
- Targets: deed time (`targets.<id>.deed_seconds`, 4–5 s of holding `act` at the deed spot, paused while a guard is close).
- Computer leader per skill (`ai_skills[0–3]`): parry beat (`ok`, `late`, `early`, `wrong`), blind strikes or reading the stance and timing (`reads_stance`), ripostes, sneak path beat. Over 12 seeds against drilled guards (skill 2) at a level-2 province castle it succeeds 3, 5, 10 and 12 times; typical raids (skill 1–2, levels 2–3) take about 40–90 s of raid time, 50–100 s with intro and outro.

## Presentation and controls
- Side view (orthographic, slight tilt) of a cut-away castle built from primitives: masonry back walls (one MultiMesh), stairs between the posts, a cellar under the floor or a wooden gallery for each sneak path, halls with moonlit windows, banners and tapestries of the M4 castle kit in the owner's colours, barrels and racks; the target room furnished per target (strongbox and coins, cell with a prisoner of the raider's house, sacks and hay that burn, chapel altar with crown and orb). Flickering torches carry the light; the battle's ink pass and toon shading.
- Fighters: `unit_raider` (the leader on foot: knight kit, cloak, circlet, house crest, sword) and `unit_guard` (gambeson in the owner's colours, kettle hat, sword, round shield; mirrored so its sword arm faces the camera), skinned, with clips for guard stances, windups, strikes and parries at three heights, walk, sneak, hit, fall, deed and cheer. `RaidAnimator` samples the clips at times derived from the simulation: windups fill the windup, the strike's contact frame lands on the hit tick. No blood: sparks, stagger, a comic fall and dust.
- HUD: time and alarm countdown, target, guards beaten / dodged / left, health and stamina, the front guard's health and covered height (shield mark), a red warning at the height of its coming blow, the leader's chosen height, prompts for sneak paths and the deed, short pop-up words.

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Walk | A / D, ← / → | left stick, D-pad |
| Height | hold W (high) / S (low), nothing: middle; the mouse aims by pointing at head, body or legs | right or left stick up / down, D-pad up / down |
| Strike | J, Space, left click | X, RB, RT |
| Parry | K, Shift, right click | B, LB, LT |
| Sneak path / deed | E (hold) | A (hold) |
| Pause (resume, flee, quit practice) | Esc | Start |

## Scene
- `src/render/raid/raid_main.tscn`: `signal finished(result: RaidResult)`; `configure_campaign(setup, devices, seed)` before adding it to the tree plays that setup (`devices[0]`: `BattleInputMap.Device` of the leader, −1 for the computer, which then fences at skill `clamp(blade − 1, 0, 3)`); intro 5 s, raid, outro 3 s, result panel with "continue" → `finished`.
- Opened directly it is the practice: setup screen (target, guards, castle, blade, who leads), a short how-to, result with again / back to setup / quit. Quit emits `finished` (last result, may be null) when someone listens, otherwise it quits the game. Headless (tests) the computer plays at once and `finished` fires without intro and outro.

## Open questions
- Guards per castle follow "2 + wall level"; the GDD only says 3–6.
- Guard skill per castle: not in the GDD; the campaign should pick it (castle level, garrison, difficulty).
- Which castle the target rooms belong to: the dungeon needs prisoners or hostages, the regalia the true ones — the campaign decides which targets it offers.
- Computer raids: auto-resolve with `RaidAI` at a difficulty-dependent skill, or the blade-based skill the scene uses.
- Practice in the main menu: no main menu exists yet; the scene runs alone.
- No audio yet (clangs, alarm bell).
