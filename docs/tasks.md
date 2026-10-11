# Tasks

## Decisions (owner)
- Events: own `events` system (ADR + `AGENTS.md`) or part of an existing one, and which of the GDD's 18 events remain now that the minigames are cut and diplomacy/electors are deferred.
- Interim victory: the coronation needs the electors' votes; until they return a game ends by subjugation or by legitimacy after round 48.

## Design questions (from the economy implementation)
- Starting satisfaction is not in the GDD; using 55, the value of the worked example.
- The worked example's balance (+56 T) leaves out building upkeep (mill 2 T, market 2 T); the rules charge it. Are starting buildings upkeep-free?
- The price rises 10 % per round after autumn, so summer is the most expensive season, but the season table says spring.
- Grain price before the first autumn: assuming 0.5 T last autumn (0.6 T in the first spring).
- Starting castles Trifels (3) and Nuremberg (2) cost Staufer and Wittelsbacher 10 T and 5 T upkeep per round — intended?
- "5 · Markt" in Z*: using the market level (market II gives +10), not mere presence.
- Autumn order: harvest before consumption; trade price impact applies after the trade.
- Neutral, church and elector provinces are not settled (satisfaction, growth stay static).

## Design questions (from the round flow; current choice)
- Constructions finish at the end of settlement: build time 1 means ordered this round, usable next round.
- The home castle level unlocks units for the whole house; the recruiting province only needs a castle. Brabanters need market II, trebuchets the workshop in that province.
- The yearly recruit cap ⌊V/20⌋ is a budget set at game start and each spring, so recruiting does not shrink its own cap.
- Home castle garrisons are not in the GDD: wall level in levy companies (1/2/3/3/4). All garrisons cost no upkeep (the GDD says so only for the wooden castle).
- Starvation takes 15 points of full garrison HP per round (≈ 6 rounds); not storming means starving; a garrison under 20 % surrenders.
- A captured home castle above level 3 is capped at province castle level 3; conquest refills the garrison and cancels orders.
- Several hostile armies in one province fight one after another, no joint defence; time-limit ties go to the alphabetically first house.
- Ransom is paid without the captor's consent; neutral captors receive nothing.
- Leaders get lance and blade values as in the GDD, but only leadership has an effect while the minigames are cut.
- The trebuchet stays a normal unit without its siege minigame; the tourney ground is removed with the joust.

## Design questions (from battle prototype P1; current choice)
- Damage hits the whole company and does not shrink as figures die; a volley is one 14-damage hit per company.
- Archers hold 3 volleys and reload one per 4 s; line fires a full volley per command, staggered fires half volleys on its own at half reload time (same damage over time).
- Charge impact = `max(1, melee × formation impact × charge multiplier − armor) × 3 s × min(1, run / 30 m)`; the wedge ×2 stacks with the knights' ×2. Hedgehog "double protection" = half damage from cavalry; it cannot move, attack or be flanked.
- With the GDD numbers morale rarely breaks from HP loss alone (−0.5 per % HP); routs come from the −15 flank and −20 leader shocks.
- Rallied companies return with at least 40 morale; the 45 s cooldown starts only if someone was rallied.
- A side loses when none of its companies fights; a lone leader escapes. At the time limit fleeing companies count 0, ties keep the defender on the field.
- The leader charges with the cavalry and is captured in 17 of 24 computer battles — keep him out of charges or give him his own shield?

## Next
- Owner playtest of P1 against the kill criterion (does a tester start a second round on their own?), keyboard-only and with two controllers.
- Balance P1: matches last 97–208 s (mean 166 s) instead of 3–4 min; knobs `battle.deploy_depth`, `battle.charge.impact_seconds`, `battle.morale.per_hp_percent`; morale breaking, leader capture rate.
- Real-time battle in the campaign: a battle takes minutes, so the move needs a pending-battle step that waits for the battle scene's `BattleResult`; the synchronous `GameRules.resolver` only fits auto-resolve and tests. Add the battle seed to `BattleSetup` then (`BattleSim` takes it separately today).
- AI turns through the same commands (utility AI from the GDD, personalities, difficulty).
- Map UI and hot-seat handover screen.
- Event cards in the event phase (after the events decision).
- Rebels and revolt endings, morale state on the map, splitting and merging armies.
- Install Godot 4.7.2 export templates, add export presets for Windows, macOS and Linux (include `data/*.json`) and a build command (`godot --headless --export-release "Linux" build/linux/<name>.x86_64`) to `AGENTS.md`.
- Steam Deck pipeline test (Gate 1): 200 figures with vertex animation textures on MultiMesh at 60 fps or more on the Deck; also measure P1 there (desktop: 1.4 ms simulation per tick and 1.6 ms figure update per frame at 386 figures).
