# Status

Milestones from the owner's brief "THRONSTREIT 1198" (2026-10-12). Each milestone starts with a plan the owner approves and ends with an owner review; the next one starts only after release. Sources: `docs/GDD.md` (binding numbers and names), `docs/ROADMAP.md` (phases and gates), `docs/reference/` (look of the battle and the figures).

| Milestone | State | Acceptance (short) |
|---|---|---|
| M0 Foundation | done | tests green; worked example "Welfen im ersten Herbst" exact (20.925 / 15.694 / 25.3125 T, 300 + 180 bushels, demand 363, surplus 117, sale 52.65 T) |
| M1 Battle graybox | done; needs an owner playtest with two controllers (`docs/screenshots/m1_battle_*.png`) | 2–4 min match with two controllers; same seed and inputs give the same result; scenario tests: knight charge beats crossbows, hedgehog stops knights, crossbows beat a spear line at range |
| M2 Blender figures and battle look | done; Steam Deck frame rate not measured (`docs/screenshots/m2_*.png`, `scripts/benchmark_battle.gd`: 412 figures, 140 fps at 1280 × 800 on an RTX 5060 Ti) | screenshot comparable to `docs/reference/schlacht.png`; 400 figures at ≥ 40 fps at 1280 × 800; every house recognisable by colour and crest |
| M3 Imperial map and round flow | done; needs a hot-seat playtest (`node scripts/run.mjs --campaign`, `docs/screenshots/m3_*.png`) | two houses play 8 rounds; all numbers match the formulas; the battle is fully integrated |
| M4 Home castle and buildings | done; needs a hands-on look with mouse and controller (`docs/screenshots/m4_*.png`) | every level looks clearly different; costs, upkeep and unlocks match the tables |
| M5 Electors, coronation, events | done; needs a hot-seat playtest of the realm tab and event cards with mouse and controller (`docs/screenshots/m5_*.png`) | test scenarios trigger the coronation along all four rows of the table |
| M6 Adventures | done; needs hands-on playtests of all four minigames with mouse and controller (timing feel, frame rate) (`docs/screenshots/m6_*.png`, practice: `node scripts/run.mjs --joust / --siege / --raid / --merchant`) | each minigame takes 1–3 min and has a practice mode |
| M7 AI | in progress: utility AI with four decision levels, personalities and difficulties; balance tuning running | each house wins 20–30 %; coronation on average in round 25–35; bankruptcy in < 5 % |
| M8 Full game | open | prologue to coronation without a crash in 60–120 min |

## Owner decisions
- 2026-10-12: minigames (M6) and electors, coronation, homage, patron cards and the ban (M5) are back in scope; diplomacy between houses (alliances, truces, treaties, marriages, peace congress, camp truce) stays out; events are their own system (ADR 0005).

## Design questions (M0 data; current choice)
- Event weights are not in the GDD; every deck card weighs 1.
- "Missernte / reiche Ernte" counts as one of the 18 events: it announces the weather roll and has no effect of its own.
- The marriage proposal needs marriages, which are out; the card stays in the data, disabled (`enabled: false`).
- Plague: the GDD has both "population −10 %" in the event and "− plague" in the spring growth formula; the data applies −10 % population and −10 Z to the province and its neighbours, each halved by a monastery.
- Flood hits one river province of the drawing house.
- Feud letter: the count's 4 companies have no unit type; using levy, like the robber knights.
- Merchant train escort: "favour of the trade cities +5" goes to Cologne and Brabant, the lords with a favour list and a market (`groups.trade_cities` in `data/events.json`).
- Papal legate and crusade: "church favour" = favour with the three church electors (the only church lords with a favour list now that the peace congress is out); the legate compares the sum over the three, and on a tie nobody gains or risks the ban.
- Home castle 4 halves "the ban's duration", but the ban has no duration (it ends with penance); only the chapel's half-price penance is in the data.
- Osnabrück's start favour (Welfen 45) belongs to the peace congress and is left out; so is the second marriage card at home castle 4.
- Death of the Lionheart: English cards work at 75 % on all three effects (150 T, 3 companies, +11.25 favour).
- The tourney ground hosts tournaments (`HostTournamentCommand`) without the joust until M6.
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

## Design questions (M2 look; current choice)
- Figures follow the GDD (stocky, head 1/5 of the height, oversized crests) rather than the rounder cartoon look of `docs/reference/figur_*.png`; the references set mood and colour only.
- The near zoom shows 45 m so figures stand about 30 px tall (GDD readability target); the wide zoom shows the whole fight with tiny figures and looks emptier than `schlacht.png`, which is a close view of a river crossing.
- Levy, brabanters and trebuchet crews wear no crest (no helmet in the GDD); they are recognised by colour alone, brabanters (mercenaries) not even by that.
- Death is a comic throw and somersault drawn on the CPU, cheering a hop; the skeletal clips in the exports (`hit`, `death`, `cheer`, horse gaits) are not played at runtime yet — the batched figures animate through UV2 limb masks.
- Camp props (banner, tent, watchtower) still carry the blue/red prototype markings instead of house colours.
- Ink: figures get an inverted-hull outline, scenery gets edges from depth jumps over 3 m and normal jumps; grass tufts and figures are kept out of the post-effect edges so the field does not turn into dark specks.

## Design questions (M3 map and round flow; current choice)
- Houses nobody plays pass their turns until the AI arrives (M7); they keep their start armies and do not build, recruit or move.
- The war table draws Voronoi borders around rough real province centres; 59 of the 63 GDD neighbourhoods also share a drawn border. Moves always follow the GDD adjacency.
- The main scene stays the battle prototype (`AGENTS.md` describes the smoke test that way); the campaign starts with `node scripts/run.mjs --campaign` until the main menu (M8).
- A live battle puts the attacker on keyboard and mouse and a human defender on controller 1; storming a castle and several battles in one move are still auto-resolved (only the first battle of a move can be played live).
- The settlement report's income and upkeep lines come from the breakdown of the state before the settlement; if starving garrisons change a province first, these lines can differ slightly (the before → after totals are exact).
- The Kornvogt forecast ignores census growth, recruiting and desertion; the prestige projection leaves out hunger and revolts (its tooltip says so).
- Controller support on the map covers panning and zooming; picking provinces needs a cursor or province cycling (M8 "controller everywhere").

## Design questions (M4 castle; current choice)
- The village shows round(0.6 × population) houses, 3 to 60; the GDD only says it follows the home province's people.
- During an upgrade the old pieces (wooden tower, wood hall, palas) stand until it finishes and overlap the rising new ones; market I stands inside a market II under construction.
- Buildings stand on the same plots in every province; rivers and terrain of the province are not shown yet; the mill wheel and banners do not move and there are no people.
- "Time-lapse while the round goes on": the view replays what is new since the province was last shown (per session) whenever it opens; the round does not wait for it.

## Design questions (M5 crown; current choice)
- The Wittelsbacher multiplier (×1.5) works on every favour gain: gifts, embassies, tournaments, protection, prestige ÷ 50 and the imperial palace; losses and the drift towards 30 stay as they are. A second gift brings (5 − 1) × 1.5 = 6, not 6.5.
- Neutral secular lords keep their favour lists like electors: prestige ÷ 50 and the drift every round, gifts, −20 for war against them; embassies, tournaments, protection, the imperial palace and occupation only concern electors.
- Holding true and forged regalia counts both in L (30 + 10), as the formula reads.
- Attacking church land risks the ban even when another house holds it now; the 50 % roll comes when the army enters, not again on conquest.
- Penance takes its 10 prestige at once; the armies may not move or storm until the next round.
- Patron mercenaries join the next battle of any army of the house (as attacker or defender) and may exceed the army limit for it.
- A house in exile that retakes its old home castle ends the exile; a razed home castle comes back as level 1.
- Gifts work for any lord with a favour list, also an elector whose province another house occupies.

## Design questions (M5 events; current choice)
- The opening round (spring of year 1) has no event cards; from the second round on every house draws exactly one card per turn, as the GDD says ("Jedes Haus zieht pro Runde eine Karte") — there is no "nothing happens" card.
- The hostage is held in the home castle of the strongest rival (highest prestige); its rescue raids that dungeon.
- Houses that do not choose (ending the event phase, passive houses until the AI) take a default per card: decline the jugglers, the Wartburg, the tournament, Bohemia, the Zähringer and the crusade; ignore the robber knights; escort the merchants; atone the feud (fight if the 80 T are missing); abandon the hostage.
- Robber knights and feuds need an own province that is not the home and borders land of no house; a lost feud hands that province to a neutral lord. Hunting needs an army in or next to it. Both battles are auto-resolved for now and earn no battle prestige (the card's reward instead).
- The Zähringer and the crusade are deck cards while their years last and until one house drew them; Bohemia's card goes to the first house that reaches favour 50 at the start of its turn.
- Plague rolls once a year in summer; the weather news comes at the start of winter, after the autumn roll.
- Crusaders come home after 8 rounds as a new army at the home castle (lost if the house has none then); while away they cost no upkeep.
- Jugglers (+3) and the plague (−10) change the current satisfaction once, not the target Z*.

## Design questions (M5 realm tab, event cards and coronation plate; current choice)
- The realm tab is one scrolling list (pillars, court, patron, 7 electors, 10 neutral lords) in data order; a filter or sort (votes within reach) may help later.
- Calling the coronation wins at once, without a confirmation step.
- The best rival shown per lord is the first one found on a tie, and it shows even when every house sits at the start favour.
- The GDD wants a blackletter heading on the coronation plate; there is no font asset yet, so it uses the default font.
- The event dialog shows each turn's news and cards once per house; a later look back (chronicle, M8) does not exist yet.

## Design questions (M6 adventures; current choice)
- The fief joust against a neighbouring house for a border province needs both houses to agree; that is diplomacy between houses, which the owner left out, so it is not built. Jousts come from hosting a tournament and from the invitation event.
- Joust: the GDD does not say what the run-up tempo does; it is the hit's force (half the stance hit at a standstill, full at the ideal tempo) and more sway above the ideal. A "normal" hit is a press within ±300 ms; outside it the lance glances off; only the first press counts.
- Joust draw (not in the GDD): points, then stance, then one deciding pass, then the opponent keeps the field; when both fall in one pass, points and then stance decide.
- Joust and trebuchet pauses (herald, ride back, flight) make the 1–3 minutes and cannot be skipped; with 3+ trebuchets a full bombardment can run past 3 minutes (the GDD shot formula is uncapped).
- A hosted tournament's prize (100 T) is paid also at the house's own tournament; its favour bonus only reaches an elector host (the invitation event), so it does nothing at home.
- The invitation comes from the elector who likes the house best; champions ride with lance 3 and skill 1 (`campaign.adventures`); a house that lets an adventure resolve itself plays it at skill 1.
- Trebuchet: at wall 1 one good stone breaches (240 > any part's share of 400 HP); a fire pot landing in the bailey counts as a garrison hit; the breach's segment is not modelled in the storm battle (the whole wall bonus is gone).
- Merchant train: a captured leader loses all the loot (companies keep nothing); escort skill 1; a raider of skill 0 is captured nearly always — computer houses (M7) need a sensible skill.
- The trebuchet is a siege option, not an adventure: it needs no leader and does not count towards the one adventure a round.
- Castle raid: guards per castle are 2 + wall level (3–6); guard skill is the campaign's opponent skill (1) until AI difficulties; a home castle of level 5 (6 guards, 3 reinforcements) is very hard; the raid's church ban chance sits in both `combat_raid.json` and the crown data, the campaign uses the crown's.
- A raid for the regalia by a house in exile moves them to the lost home castle's province, i.e. to whoever holds it now.
