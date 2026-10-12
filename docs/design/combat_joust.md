# Joust

The joust minigame of M6 (GDD "Abenteuer-Module" → "Tjost"). Values in `data/combat_joust.json`, read by `JoustConfig`; the lance values come from `data/combat.json` `leader_skills.lance` through `CombatConfig`.

## How a joust runs
- `JoustSim` (`src/systems/combat/joust/`) runs at a fixed 30 Hz tick: a `JoustSetup` goes in, one `JoustInput` per rider and tick, a `JoustResult` comes out. No clock, no devices, no random numbers.
- Timeline: herald's call 8 s, then per pass ready 3 s, run-up 3 s, aim 1.5 s, clash 4 s (impact at its start), ride back 7 s; the ceremony (5 s) ends the joust. Three passes take 61.5 s; a deciding pass adds 18.5 s.
- **Run-up:** the gait beats every 0.5 s (six beats, at 0.25 s, 0.75 s, …). A spur within ±120 ms of a beat not yet spurred adds +0.15 tempo, any other spur −0.1. Tempo starts at 0.4, ideal 1.0, at most 1.6: four good spurs reach the ideal.
- Tempo is the hit's force: the stance hit dealt is `min_force + (1 − min_force) × min(tempo / ideal, 1)` of the GDD value (0.5 → 100 %); above the ideal the lance sways more (+150 % per tempo point).
- **Aim:** the input names where the lance hand should go (±0.8 m around the opponent's chest); the hand moves there at 1.4 m/s from its rest 0.6 m below the chest. The tip is hand + sway.
- **Sway:** a fixed Lissajous figure from the gait, 0.08 m × 0.12 m with periods 1.1 s and 0.5 s, starting each pass at its own phase (`pass_phase`), × (1 − 0.1 × lance) × the overspeed factor. Visible on screen; no chance.
- **Impact:** the first couching press from the aim start counts (mashing does not help). Within ±(60 + 15 × lance) ms (+40 ms for the Staufer) of the impact it is perfect; within ±300 ms (`couch_window_ms`) normal; otherwise, or never pressed, the lance glances off. The hit is scored 300 ms after the impact, when every press in the window has arrived.
- **Zones** (attacker's view, metres from the chest; the first containing the tip counts): helmet 5 points (r 0.16 at 0.5 up), shield centre 3 (r 0.13 at 0.4 right, 0.1 down), shield rim 1 (r 0.3 around it). A miss scores nothing and takes no stance.
- **Perfect:** the lance breaks, +1 point, stance −40 × force; normal −20 × force.
- **Shield:** the defender's shield input (own view, y up) counts as aligned when it is at least 0.5 long and within 35° of the incoming tip (mirrored into the defender's view) at the impact; it halves the stance hit.
- **Stance:** 100 per rider. Below 0 the rider falls and loses at once; the joust ends after that pass. If both fall in one pass, points and then stance decide who falls (still level: the player's rider).
- **Decision:** after three passes more points win, then more stance. Still level, up to `deciding_passes` (1) extra passes; then the opponent keeps the field (`Decision.STATUS_QUO`). The draw rule is not in the GDD.

## Computer riders
- `JoustAI` plays either rider through `JoustInput`s with the fixed error pattern of its skill (`ai[0..3]`): which beats it spurs and how far off, which zone it aims at and how far it misses, how much of its own sway at the impact it cancels, how far off it couches, in which passes it turns the shield towards the incoming tip (as it is at that moment, after its reaction time).
- Lists repeat per pass; the seed only rotates where a rider starts in each list, so the same seed and setup always give the same joust.
- Over any seed set skill 3 beats 0, 1 and 2, skill 2 beats 0 and 1, skill 1 beats 0 (`test_joust_ai.gd`). `JoustSim.play_out(config, setup, seed, player_skill)` plays a joust with the computer on both sides (auto-resolve).

## Scene contract (`src/render/joust/joust_main.tscn`)
- `func configure_campaign(setup: JoustSetup, devices: PackedInt32Array, seed_value: int)` before adding the scene: `devices[0]` is the player's `BattleInputMap.Device` (or -1 for the computer, skill 2); the opponent is always the computer with `setup.opponent_skill`.
- `signal finished(result: JoustResult)`: at once when the computer rode the player's side, otherwise when the player presses "continue" on the result panel.
- `JoustSetup`: `house`, `lance`, `opponent` (house id, `elector`, `neutral`, `church`), `opponent_lance`, `opponent_skill`, `host_province` ("" for none), `practice`. `JoustResult`: `won`, `player_points`, `opponent_points`, `unseated` (`PLAYER`, `OPPONENT` or `NONE`), `passes`, both stances, `decided_by`, `duration`.
- Opened directly it is the practice mode: a menu with the how-to, house, lance, opponent skill and controls; the result panel offers again, back to setup and quit. `signal quit_requested`; when nothing is connected, quit ends the game.
- Rewards stay with the caller: `rewards.prize_gold` (100 T) and `rewards.fief_satisfaction` (−10, the province changing hands in a fief joust) are in `combat_joust.json`; prestige +5 for a tournament win is `economy.json` `prestige.tournament_won`, favour +5 with the host `map.json` `crown.favour.changes.tournament_won`.

## Controls (`JoustInputMap`, `JoustInputReader`)
| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Spur | Space | A |
| Lance | mouse points where the hand goes | left stick moves that point |
| Couch the lance | left click or Enter | RT or RB |
| Shield | WASD or arrow keys | right stick |
| Menu (practice) | Esc | Start |

Presses are stamped with the simulation time of the frame that saw them and handed to the tick containing that moment, so the hit window is judged to the frame, not to the 33 ms tick.

## Presentation
- First person through the helmet slit (`JoustCamera`) from the ready call until 0.8 s after the impact: down the lists during the run-up, then locked on the opponent's chest with a zoom that keeps him the same size while he closes in. Otherwise from the stand: the herald's pan from rider to rider, following the riders, close on a rider falling from the saddle, then the winner.
- `JoustRiders` reuses the battle's knight (`BattleModels.unit_mesh("knights", owner)`), split into horse and rider without its upright lance (`JoustModels`), with house colours, crest and outline; the striped lance is built in code. Splinters when a lance breaks, a comic tumble and a dust puff when a rider falls, no blood.
- `JoustLists`/`JoustCrowd`: meadow with a sand band, the tilt barrier and stand canopy in both riders' colours, fences, pavilions, banners and trees from `assets/combat/`, a cheering crowd; the battle's `BattleInk` post effect.
- HUD (`src/ui/joust/`): stance and points per rider, pass, captions, the run-up gauge (beat pips, tempo bar with the ideal mark), aim marks (zones with points in practice, the swaying tip, the hand's goal, a ring that closes on the impact and turns gold inside the perfect window), the shield compass (incoming lance, own shield, gold when aligned), hints and shouts.
- `scripts/preview_joust.gd` renders `docs/screenshots/m6_joust_runup.png`, `m6_joust_aim.png`, `m6_joust_fall.png`.

## Open
- Tempo as the hit's force and the draw rule are interpretations; the GDD names neither.
- Two human riders (hot-seat fief joust) need a split screen; the scene rides rider 1 by the computer.
- Minigame aids from the GDD (wider window, slow motion) and audio are not built.
