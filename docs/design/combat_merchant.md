# Merchant train raid

The adventure module "Kaufmannszug" of the GDD (section "Abenteuer-Module"), built for M6: a side-scrolling raid of 1–3 minutes with a practice mode. Values live in `data/combat_merchant.json` (`MerchantConfig`), the leader's blade in `data/combat.json` → `leader_skills.blade` (`CombatConfig`), the battle's tick rate in `battle.tick_rate`. The event card's escort choice and the raid's prestige −3 and Cologne's favour −10 stay with `data/events.json`; this module only plays the raid.

## Rules as built
- Five wagons roll towards the town gate at a constant 1.6 m/s, 14 m apart. The rear wagon starts at 0 and reaches the gate after exactly 90 s (`train_seconds`), so the gate lies at 144 m and the leading wagon gets there after 55 s. A wagon that reaches the gate is lost; the raid ends when no wagon rolls any more or the leader is captured.
- Every wagon carries a fixed cargo of 30–40 taler drawn from the seed before the raid and shown on the wagon and on the road strip; more valuable wagons are piled higher. The loot is the sum of the stopped wagons — nothing if the leader is captured.
- An intro of 6 s (the camera glides from the gate back along the train) and an outro of 8 s before the result frame the 90 s; a typical raid lasts 60–100 s in total.
- The leader starts 16 m behind the rear wagon and rides at 4 m/s along the near verge. He stops a wagon in one of two ways:
  - **Pull the driver off the box:** hold *pull* within 1.5 m of the box for 2.5 s; the leader rides along meanwhile. A blow interrupts and resets the pull.
  - **Crossbow at the harness:** 3 bolts, 5 s to span again, the horses of a rolling wagon 5–14 m ahead in the riding direction. The aim swings in a fixed, visible rhythm (period 1.5 s, half the swing when standing, the full swing at full gallop); a bolt cuts the traces while the swing is within ±0.22, else it misses and is gone.
- **Escorts** (2–4) follow a fixed pattern per escort skill 0–3 (`escorts.skills`): walk beside a driver's box; go for the nearest raider within notice range (×3 once the first wagon stopped — the alarm); shield up (cover: strikes glance off), wind up behind the shield with a "!" over the head, strike, recover. A leader who pulls a driver gets the wind-up at once. A blow that lands costs the leader one of 5 composure and stuns him 0.8 s; at 0 the escort pulls him off his horse: captured.
- **Parry** opens a window of 220 ms + 20 ms × blade for 0.7 s of cooldown; a blow landing in it staggers the escort for 1.2 s. **Strikes** reach 2.6 m, deal 1 × (1 + 0.1 × blade) guard, double against a staggered escort; an escort without guard lies in the ditch for 8–14 s (by skill) and comes back.
- **Companies** (0–2 unit ids from the leader's army; trebuchets and other units without melee cannot join) lie in ambush at 60 % and 85 % of the road and break out when the train's head passes. They go for the nearest free escort within 10 m and hold him for `8 s × 8 / unit melee × escort guard / 3` (knights fastest, crossbowmen slowest), then he lies in the ditch; otherwise they pull the nearest driver in 6 s. Escorts who meet a company fight it instead of the leader.
- No dice: the seed only sets the cargo values, the escorts' posts (±1.5 m around the box) and the phase of the crossbow swing.

**Bloodless presentation.** A bolt never hits a horse: it snaps the traces ("Ritsch!"), the two horses trot off to the meadow to graze and the wagon stalls. A pulled driver cartwheels into the verge and sits there with circling stars; beaten escorts lie in the ditch with stars; hits are "Bonk!", blocks "Klong!", the captured leader topples over comically.

## Computer raider
`MerchantAI` plays the leader for auto-resolve, computer houses and tests: it rides for the nearest rolling wagon, shoots the harness ahead when the swing looks calm enough, pulls drivers, parries every wind-up and fights escorts who go for it — with fixed mistakes per skill (`raider_ai`): think time, parries off by a repeating list of milliseconds, bolts loosed while the swing is still wider than `hit_window × aim_factor`, pauses; skill 0 does not fight at all. Wagons stopped on average over 12 seeds (2 companies in brackets):

| Escort skill | Raider 0 | Raider 1 | Raider 2 | Raider 3 |
| --- | --- | --- | --- | --- |
| 0 drowsy (2 escorts) | 2.3 (5.0) | 4.0 (5.0) | 5.0 (5.0) | 5.0 (5.0) |
| 1 watchful (3) | 0.3 (0.4) | 3.8 (5.0) | 4.4 (5.0) | 5.0 (5.0) |
| 2 seasoned (3) | 0.8 (0.8) | 3.0 (5.0) | 5.0 (5.0) | 5.0 (5.0) |
| 3 veterans (4) | 0.4 (0.4) | 2.4 (2.7) | 2.6 (5.0) | 3.0 (5.0) |

Raider 0 is captured in almost every raid from escort skill 1 on; a rider who only holds *pull* and rides on is captured at the first guarded wagon. Raids of raiders 1–3 against watchful escorts take 48–64 s of train time.

## Data (`data/combat_merchant.json`)
- `train`: `wagons`, `train_seconds`, `intro_seconds`, `outro_seconds`, `wagon_speed`, `wagon_spacing`, `cargo_taler` [min, max], `box_ahead` / `horses_ahead` (box and horses ahead of the wagon's centre).
- `leader`: `start_behind`, `speed`, `acceleration`, `composure`, `stun_seconds`, `gate_keep_away`, `strike_reach`, `strike_damage`, `strike_seconds`, `parry_window_ms`, `parry_cooldown_seconds`, `pull_reach`, `pull_seconds`.
- `crossbow`: `reload_seconds`, `bolts`, `range` [min, max], `sway_period_seconds`, `sway_still`, `sway_riding`, `hit_window`.
- `companies`: `max`, `figures`, `ambush_at` (shares of the road), `speed_factor` (× unit speed), `engage_range`, `reach`, `pull_seconds`, `fight_seconds`, `reference_melee`, `reference_guard`.
- `escorts`: `reach`, `stagger_seconds`, `post_jitter`, `alarm_notice_factor`, `skills[4]` with `count`, `speed`, `notice_range`, `cover_seconds`, `windup_seconds`, `recover_seconds`, `down_seconds`, `guard`.
- `raider_ai[4]`: `think_seconds`, `parry_errors_ms`, `aim_factor`, `fights_escorts`, `hesitate_every_seconds`, `hesitate_seconds`.

`MerchantConfig.read` reports every missing or mistyped key and broken ranges at once.

## Contract
- Rules in `src/systems/combat/merchant/`: `MerchantSetup` → `MerchantSim` (fixed tick, one `MerchantInput` per tick: `move`, held `pull`, pressed `strike` / `parry` / `shoot`) → `MerchantResult`. Same setup, seed and inputs give the same result and `MerchantState.checksum()`.
- `MerchantSetup`: `house`, `blade` (1–5), `companies` (unit ids, at most 2), `escort_skill` (0–3), `escort_count` (0 = by skill, else 2–4), `province` (scenery and the town's name at the gate), `season` (spring or summer light), `raider_skill` (0–3, the computer raider), `practice`. `errors()` lists problems; the simulation reports them and plays `playable()`, a clamped copy.
- `MerchantResult`: `wagons_total`, `wagons_stopped`, `taler`, `leader_captured`, `seconds` (train time without intro and outro).
- Scene `src/render/merchant/merchant_main.tscn`: `signal finished(result: MerchantResult)`, `configure_campaign(setup, devices, seed_value)` before adding it to the tree. `devices` are `BattleInputMap.Device` values that all steer the one leader; an empty array (or only −1) lets `MerchantAI` raid with `setup.raider_skill`. A campaign raid ends with the result frame and *continue*; a practice setup (`practice = true`, or the scene opened directly) offers *again* and *quit*, and *quit* emits `finished` with the last result (with nobody connected it quits the tree).

## Controls
| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Ride | A / D or arrows | left stick or d-pad |
| Pull the driver (hold) | W, ↑ or E | A |
| Strike | Space, J or left click | X |
| Parry | S, ↓, K or right click | B or LB |
| Crossbow | F or L | Y or RT |
| Practice menu | Esc | Start |

## Presentation
Orthographic side view (11 m high, tilted 11°) along a river road in the battle's toon and ink style (`BattleInk`, `BattleRiver`, the battle's meadow shader, trees, reeds, rocks and fences from `assets/combat/`, town houses from `assets/economy/`). Figures are `BattleModels.unit_mesh` batches animated by the stride shader: the leader in house colours, companies in house colours with their crests, escorts as spearmen and drivers as levy in the neutral lords' colours. Wagons, wheels, cargo, draught horses and the town gate come from `art-src/combat/build_merchant_assets.py`. The HUD shows the whole road with every wagon's value, the gate countdown, loot, composure, bolts, the pull progress and the crossbow's swing over its green band.

## Open
- Whether a captured leader should forfeit the loot (built: yes) or the companies keep the wagons they stopped.
- The campaign decides which escort skill a train gets and which raider skill a computer house plays with; raider 0 is mostly captured.
- A raid with both companies and flawless play can end after about 41 s of train time (55 s in total), slightly under the minute.
