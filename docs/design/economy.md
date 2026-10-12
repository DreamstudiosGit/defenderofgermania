# Economy

Ported from the GDD section "Wirtschaft" (plus building and castle tables from "Gebäude & Stammburg"). Formulas are binding; all numbers live in `data/economy.json` and are starting values for balancing. Compute with floats, round to whole taler only for display.

## Resources and levers
| Resource | Level | Meaning |
|---|---|---|
| Taler (T) | house | money for buildings, troops, gifts |
| Grain (bushels) | house | stock; feeds population and troops |
| Population (V) | province | 1 V = 100 people; base for tax, harvest, recruits |
| Satisfaction (Z) | province | 0–100; drives tax collection, growth, revolts |
| Prestige (A) | house | 0–100; favour, marriage, satisfaction |

Levers per house, valid for all its provinces: tax rate s ∈ {5, 10, 15, 20, 25, 30, 40} % and ration r ∈ {2 hunger, 3 normal, 4 rich} bushels per V and year. Start per house: 200 T, 300 bushels, prestige 20, tax 15 %, ration 3, home castle level 1, army of 2 levy + 2 spearmen.

## Income (per round)
- Tax: `V · s · 3 · (0.5 + Z/200)`; Frisia caps s at 15 %.
- Market: `V · 0.3 · m · h · f · (1 if Z ≥ 30 else 0.5)` — m = market level 0–2, h = 1.5 for Welfen, f = 1.25 in autumn.
- Fixed: mine +30 T (Wettiner ×1.5), toll +8 T at rivers / +15 T at passes, Salzburg salt trade +20 T.
- Provinces in revolt pay nothing.
- Upkeep: units + buildings + castle (home castle table for the home province, province castle table elsewhere).
- Below 0 T: each army loses ⌈10 %⌉ of its companies (mercenaries first) and every province −5 Z. No loans.

## Grain
- Harvest, autumn only: `V · F · W_region · (1 + 0.25 · mill) · b` — F = field yield of the terrain (`data/map.json`), b = 0.5 if occupied or in revolt.
- Weather per region (north, middle, south) from the seed: 0.6 (10 %), 0.85 (20 %), 1.0 (40 %), 1.15 (20 %), 1.3 (10 %).
- Demand per round: `Σ V · r/4 + Σ companies k · w` — k = grain upkeep of the unit, w = 1.5 in winter outside own provinces.
- Shortage with coverage D = stock ÷ demand: every province −30·(1−D) Z and V × (1 − 0.1·(1−D)); all companies −20·(1−D) morale; prestige −3.
- Spoilage after eating: stock × (1 − q), q = max(0.02, 0.10 − 0.02 · granaries).

## Grain market
- Autumn price `P = 0.5 / W̄ · ε`, W̄ = mean weather of the year, ε ~ U(0.9, 1.1); later rounds `P · (1 + 0.1 · n)`, n = rounds since autumn.
- Buy at P·(1+σ), sell at P·(1−σ), σ = 0.2 (Welfen 0.1). Each 100 bushels bought/sold move P by +/−2 %; P stays within 0.2–2.0 T.
- Trading (`TradeGrainCommand`, administration phase): positive bushels buy, negative sell. The price of the round is `P_t · (1 + 0.02 · net/100)`, net = bushels all houses bought minus sold this round (`GameState.grain_traded`); a trade pays the price before its own impact. The shift resets at settlement.

## Satisfaction and revolt
- Each round `Z ← Z + 0.25 · (Z* − Z)`.
- `Z* = 60 − 1.5·(s% − 10) + 10·(r − 3) + 10·monastery + 5·market + A/10 + B − 15·occupied − 15·ban`, clamped to 0–100. B = +5 per home castle level above 1 (home province only); occupied = 4 rounds after a conquest. Frisia +10, fountain decoration +3 in the home province.
- Z < 25 at round end: revolt with chance (25 − Z) · 3 %: no income, rebels with ⌈V/15⌉ levy companies (`PopulationRules.rebel_companies`); ends by victory or concession (2 rounds tax-free, +20 Z).

## Population and prestige
- Spring census: `V ← min(K, V · (1 + g))`, `g = 0.03 · (Z − 40)/60 + 0.02 · (r − 3) + 0.01 · monastery − plague`; `K = 1.5 · start V + 5 · castle level + 10 · market level`.
- `A ← min(100, 0.95 · A + ΔA)`; ΔA = running sources (home castle level, decorations, monasteries) + one-offs: battle won +3, defeat −3, revolt −2, hunger −3, ban −2 per round; tournament won +5 and hosted +5 (with M5/M6), merchant raid −3 (event data); alliance breaks are out with house diplomacy. Battle one-offs are collected in `HouseState.pending_prestige` and enter ΔA at the next settlement. Prestige settles at 20× the running sources.

## Building and castles
All orders are administration-phase commands of the active house, paid at once; they finish at the end of the settlement after their build time (build time 1: ordered this round, working from next round's settlement). Buildings under construction cost no upkeep; a conquest cancels the province's orders.
- Buildings (`BuildCommand`): each kind once per province. Slots: 2 per province; the home province 2 + 1 per home castle level above 1, at most 6; orders under construction take a slot. Cost × house modifier (Wettiner mine ×0.7).
- Prerequisites (data fields of `buildings`): market II needs market I (`upgrade_of`, replaces it in its slot) and home castle 2; mine needs ore; toll needs a river or pass (`features`); workshop needs the home province (`home_only`) and home castle 4.
- Tourney ground: home province, home castle 3. It can be built now; hosting a tournament (80 T, prestige +5, favour +3 with all electors) comes with M5/M6.
- Castles (`UpgradeCastleCommand`): one level at a time per province. Home province: home castle table, levels 2–5. Elsewhere: province castle table, levels 1–3; level 3 needs home castle 3. A workshop makes every castle level of its house 15 % cheaper (counted once).
- Decorations (`BuyDecorationCommand`): instant, each kind once, at most 5, only while the house holds its home castle; stained glass needs home castle 4. They are lost with the home castle.

## Recruiting and ransom
- `RecruitCommand`: only in own provinces with a castle (level ≥ 1) and without hostile armies. The home castle level unlocks units (levy and spearmen 1, crossbowmen 2, knights 3); brabanters need market II and trebuchets the workshop in the recruiting province.
- Yearly budget: each province gives ⌊V/20⌋ companies per year, set from its population at game start and at every new spring (`ProvinceState.recruits_left`).
- Each company costs gold (Staufer knights ×0.75), population (unit table) and 2 Z. It joins the given army in the province, or the first own army there with room, or forms a new army within the army limits (docs/design/map.md, "Armies").
- Ransom (`PayRansomCommand`): 150 T + 50 × own home castle level; a captor house receives it, the leader returns to the home castle.

## Sieges
- Besieging armies pay unit upkeep ×1.25.
- Starvation costs a besieged garrison 15 percentage points of HP per settlement; a granary in the province halves it (7.5).

## Settlement order (phase 4)
Autumn first rolls the regional weather and the new grain price. Then per house: income − upkeep (desertion if in debt; armies without companies disband), autumn harvest, grain consumption and shortage, spoilage, satisfaction and revolt rolls, prestige (incl. pending one-offs), spring census, occupation countdown. Then constructions advance and finish, the round's grain price shift resets, the turn advances, and a new spring sets every province's recruit budget. The turn loop runs garrison starvation before and recovery, exile countdown and the victory check after (docs/design/map.md).

## Worked example (golden test)
"Welfen im ersten Herbst": Brunswick (V 60, farmland, Z 55, mill) and Holstein (V 45, farmland, Z 55, market 1), tax 15 %, weather 1.0 → tax 20.925 T and 15.694 T, Holstein market 25.3125 T, army upkeep 6 T, harvest 300 + 180, yearly demand 363, surplus 117 sells at 0.45 T for 52.65 T; a bad harvest (0.6) leaves 75 bushels missing. See `src/systems/economy/test_welfen_first_autumn.gd`.

## Not implemented yet
Morale effects (no morale state yet); rebel spawning and revolt endings; plague and other events; AI difficulty income modifiers; patron cards ("Gönner").
