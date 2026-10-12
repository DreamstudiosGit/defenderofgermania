# AI

Computer opponents (GDD "KI-Gegner"): a utility AI in `src/systems/ai/` with values in `data/ai.json` (`AiConfig`). It plays only through Commands, validated like a human's; no extra knowledge beyond the state a player sees (there is no fog of war yet).

## Houses and settings
- `HouseState.personality` ("" for a human house) and `difficulty` 0–3 (squire, knight, prince, emperor) are part of the save. `CampaignSession.create(rules, humans, seed, computers, player)` makes the other houses computers (`AiPlayer.opponents`: the data's default personality per house — Welfen merchant, Wettiner builder, Staufer conqueror, Wittelsbacher diplomat — and the default difficulty knight) and injects `AiPlayer.play_phase` as `session.computer`, so the core does not depend on the AI. The session ends each phase after the AI acted.
- Difficulty: computer income ×0.8 / 1.0 / 1.15 / 1.3 (`economy.json` `computer_income`, an own breakdown term); the squire takes a random worse option in 30 % of decisions; prince and emperor recruit against the enemies' most common unit (counters); the emperor gangs up on a leading house (coalition). In minigames the difficulty is the computer's skill (`Adventures.auto_skill`).

## Decision levels (every phase, in this order)
- Event phase (`AiEvents`): every choice valued in taler — cost, gold, prestige, satisfaction, favour, votes, provinces; battles and adventures by their chance (`adventure_success` per skill).
- Administration: supply (`AiSupply`: ransom, grain forecast until the harvest — buy, cut the ration, sell a surplus — and the tax raised while every target satisfaction stays above 35); security (`AiSecurity`: threat map of enemy strength within one step against garrison and armies, threatened castles recruit, the home first); goals (`AiGoals`: coronation the moment it is possible, then options from `AiCourt` — gifts to lords close to their vote or homage, homage, patron cards, tournaments, forged regalia, penance — `AiBuilding` — buildings, the next castle level, decorations — and recruits for the field army, all valued as taler worth per taler, taken best first while a reserve stays).
- Campaign (`AiCampaign`): a castle raid when the expected loot beats the risk; besieging armies storm when their strength K beats the walls' by `storm_ratio`, else bombard, else starve; other armies attack from `attack_ratio` 1.4 (the auto-resolve's K, counters and walls included) or march along the pull of the pillars of the crown (`AiTargets`). The only army at home stays while enemies within two steps outmatch the garrison (home guard). A house holding two pillars draws everyone's attacks (anti-leader).
- Personalities weigh the categories economy, military, castle, court, favour and adventure.

## Debug overlay and balance
- `AiPlayer.logs` keeps every option each computer house weighed in its last turn with its utility and whether it was taken.
- `scripts/balance_run.gd` plays computer-only games (one JSON line each; `--trace=1` prints every round and every action); `node scripts/balance.mjs --games=1000 --jobs=8` runs them in parallel and sums up win shares, endings, the coronation round and bankruptcies against the GDD targets.

## Setup and debug overlay (UI)
- New game (`SetupScreen`): each house is played by a human or the computer; a computer house gets a personality (its house's default, or "random", rolled from the seed in map order) and a difficulty (default `default_difficulty`). At least one human: the session plays computer houses in one call until a human is to move, so a game without humans would run to its end at once. Tooltips show a personality's weights and a difficulty's income and habits from the data; the hot-seat handover lists the other houses with their player.
- Debug overlay (`AiDebugOverlay`, campaign scene only, never takes the focus): F3 or Back+Y toggles it, F4 / Shift+F4 or Back+RB / Back+LB pick the computer house, the wheel or Back+d-pad scrolls. It shows the house's personality, difficulty and pillars and its `AiPlayer.logs` entries newest first: phase, label, utility, ✓ when taken, the error key when the rules refused.
- Screenshots: `godot --resolution 1280x800 --script res://scripts/preview_campaign_ai.gd -- --view=setup|overlay --shot=<png>`.
