# Status

Milestones from the owner's brief "THRONSTREIT 1198" (2026-10-12). Each milestone starts with a plan the owner approves and ends with an owner review; the next one starts only after release. Sources: `docs/GDD.md` (binding numbers and names), `docs/ROADMAP.md` (phases and gates), `docs/reference/` (look of the battle and the figures).

| Milestone | State | Acceptance (short) |
|---|---|---|
| M0 Foundation | done | tests green; worked example "Welfen im ersten Herbst" exact (20.925 / 15.694 / 25.3125 T, 300 + 180 bushels, demand 363, surplus 117, sale 52.65 T) |
| M1 Battle graybox | done; needs an owner playtest with two controllers (`docs/screenshots/m1_battle_*.png`) | 2–4 min match with two controllers; same seed and inputs give the same result; scenario tests: knight charge beats crossbows, hedgehog stops knights, crossbows beat a spear line at range |
| M2 Blender figures and battle look | Blender sources, glTF models, scenery and shaders exist (ADR 0004), not yet checked against M2 | screenshot comparable to `docs/reference/schlacht.png`; 400 figures at ≥ 40 fps at 1280 × 800; every house recognisable by colour and crest |
| M3 Imperial map and round flow | rules exist (map, economy, turn loop); no map view | two houses play 8 rounds; all numbers match the formulas; the battle is fully integrated |
| M4 Home castle and buildings | rules and data exist; no castle view | every level looks clearly different; costs, upkeep and unlocks match the tables |
| M5 Electors, coronation, events | data exists (M0) | test scenarios trigger the coronation along all four rows of the table |
| M6 Adventures | open | each minigame takes 1–3 min and has a practice mode |
| M7 AI | open | each house wins 20–30 %; coronation on average in round 25–35; bankruptcy in < 5 % |
| M8 Full game | open | prologue to coronation without a crash in 60–120 min |

## Owner decisions
- 2026-10-12: minigames (M6) and electors, coronation, homage, patron cards and the ban (M5) are back in scope; diplomacy between houses (alliances, truces, treaties, marriages, peace congress, camp truce) stays out; events are their own system (ADR 0005).

## Design questions (M0 data; current choice)
- Event weights are not in the GDD; every deck card weighs 1.
- "Missernte / reiche Ernte" counts as one of the 18 events: it announces the weather roll and has no effect of its own.
- The marriage proposal needs marriages, which are out; the card stays in the data, disabled (`enabled: false`).
- Tournament invitation, merchant train and hostage lead into the M6 minigames (joust, merchant train, castle raid).
- Plague: the GDD has both "population −10 %" in the event and "− plague" in the spring growth formula; the data applies −10 % population and −10 Z to the province and its neighbours, each halved by a monastery.
- Flood hits one river province of the drawing house.
- Feud letter: the count's 4 companies have no unit type; using levy, like the robber knights.
- Merchant train escort: "favour of the trade cities +5" — which lords count as trade cities?
- Papal legate and crusade: "church favour" = favour with the three church electors (the only church lords with a favour list now that the peace congress is out).
- Death of the Lionheart: do English cards work at 75 % on all three effects (150 T, 3 companies, +11.25 favour)?
- Home castle 4 halves "the ban's duration", but the ban has no duration (it ends with penance); only the chapel's half-price penance is in the data.
- Osnabrück's start favour (Welfen 45) belongs to the peace congress and is left out; so is the second marriage card at home castle 4.
- The tourney ground can be built now but does nothing until tournaments exist (M5/M6).
- Without the camp truce every house is hostile from the start (as before).
- House colours are hex values picked from the GDD colour names; the battle prototype still uses its own blue and red.
- M2: the figure references (`docs/reference/figur_*.png`) show rounded cartoon figures with a fleur-de-lis and a lion; the GDD asks for stylised low-poly at a 1 : 5 head-to-body ratio with each house's crest.

## Design questions (economy; current choice)
- Starting satisfaction is not in the GDD; using 55, the value of the worked example.
- The worked example's balance (+56 T) leaves out building upkeep (mill 2 T, market 2 T); the rules charge it. Are starting buildings upkeep-free?
- The price rises 10 % per round after autumn, so summer is the most expensive season, but the season table says spring.
- Grain price before the first autumn: assuming 0.5 T last autumn (0.6 T in the first spring).
- Starting castles Trifels (3) and Nuremberg (2) cost Staufer and Wittelsbacher 10 T and 5 T upkeep per round — intended?
- "5 · Markt" in Z*: using the market level (market II gives +10), not mere presence.
- Autumn order: harvest before consumption; trade price impact applies after the trade.
- Neutral, church and elector provinces are not settled (satisfaction, growth stay static).

## Design questions (round flow; current choice)
- Interim victory: until the coronation exists (M5) a game ends by subjugation or by legitimacy after round 48.
- Constructions finish at the end of settlement: build time 1 means ordered this round, usable next round.
- The home castle level unlocks units for the whole house; the recruiting province only needs a castle. Brabanters need market II, trebuchets the workshop in that province.
- The yearly recruit cap ⌊V/20⌋ is a budget set at game start and each spring, so recruiting does not shrink its own cap.
- Home castle garrisons are not in the GDD: wall level in levy companies (1/2/3/3/4). All garrisons cost no upkeep (the GDD says so only for the wooden castle).
- Starvation takes 15 points of full garrison HP per round (≈ 6 rounds); not storming means starving; a garrison under 20 % surrenders.
- A captured home castle above level 3 is capped at province castle level 3; conquest refills the garrison and cancels orders.
- Several hostile armies in one province fight one after another, no joint defence; time-limit ties go to the alphabetically first house.
- Ransom is paid without the captor's consent; neutral captors receive nothing.
- Leaders get lance and blade values as in the GDD, but only leadership has an effect until the minigames exist (M6).
- The trebuchet stays a normal unit until its siege minigame exists (M6).

## Design questions (battle prototype P1; current choice)
- Damage hits the whole company and does not shrink as figures die; a volley is one 14-damage hit per company.
- Archers hold 3 volleys and reload one per 4 s; line fires a full volley per command, staggered fires half volleys on its own at half reload time (same damage over time).
- Charge impact = `max(1, melee × formation impact × charge multiplier − armor) × 3 s × min(1, run / 30 m)`; the wedge ×2 stacks with the knights' ×2. Hedgehog "double protection" = half damage from cavalry; it cannot move, attack or be flanked.
- With the GDD numbers morale rarely breaks from HP loss alone (−0.5 per % HP); routs come from the −15 flank and −20 leader shocks.
- Rallied companies return with at least 40 morale; the 45 s cooldown starts only if someone was rallied.
- A side loses when none of its companies fights; a lone leader escapes. At the time limit fleeing companies count 0, ties keep the defender on the field.

## Design questions (M1 battle; current choice)
- The field is back at the GDD scale (300 × 180 m, 90 m crossbow range, 30 m aura, 12-figure companies, 6 knights); the art pass had shrunk it to 72 × 44 m. Zoom level 0 shows the whole fight with tiny figures, level 1 an 80 m slice — M2 tunes both against `docs/reference/schlacht.png`.
- The brief wants the active group to glow golden; in the couch duel it stays hidden (owner request, ADR 0004), so two players only see their selection by its movement. Keep it hidden?
- The leader moves with the cavalry but never charges (it was captured in 21 of 24 computer battles); it fights when attacked and rallies.
- After a charge impact the riders keep fighting the company they hit (before, they drifted out of reach and the battle stalled).
- Cover: 70 % ranged damage within 4 m of a tree stand or rock — the GDD gives no number for cover; the forest’s −30 % is borrowed.
- Trebuchets: stones fly 3 s, the target circle moves at 30 m/s, they hit enemies only (no friendly fire), one stone per 20 s; no walls on the open field yet.
- Deployment lasts 20 s (was 15 s) so computer battles fight 2–4 minutes; measured 143–205 s over 12 seeds, each side won 6.
- The default battle is Wittelsbacher against Welfen, so the models’ blue and red team markings match the house colours until M2 brings colour masks.
