# Map

Ported from the GDD sections "Reichskarte", "Armeen auf der Karte", "Belagerung" and the victory rules of "Spielablauf". The province table (region, start owner, terrain, population, features, neighbors) lives in `data/map.json`; army, conquest, leader and victory values in its `campaign` section (`CampaignRules`); names in `data/i18n/texts.csv` as `PROVINCE_<ID>`.

## Shape
- 31 provinces in three regions (north, middle, south) with 63 connections; adjacency always works both ways.
- Start owners: each house holds two provinces, one of them its home castle (Welfen Brunswick, Wettiner Meissen, Staufer Swabia, Wittelsbacher Bavaria); 7 provinces belong to electors, 6 to church princes, 10 to neutral lords.
- Church lands (attacking them risks the ban): Bremen, Magdeburg, Münster, Osnabrück, Franconia, Salzburg and the elector archbishoprics Cologne, Mainz and Trier.
- Coronation site Aachen, emergency coronation in Mainz, imperial regalia on Trifels (Speyer & Trifels) — the Rhine decides the game.
- Neutral provinces and electors defend with ⌈V/20⌉ companies (Bohemia 8). Rivers and passes allow toll stations.

## Terrain
| Terrain | Field yield (bushels per V and year) | Battlefield |
|---|---|---|
| Farmland | 4.0 | open field |
| Marsh | 3.5 | swamp |
| Hills | 3.0 | heights |
| Forest | 2.5 | forest edge |
| Heath | 2.5 | hollows |
| Mountains | 2.0 | pass |
| City | 1.0 | before the gates |

## Armies
- Size: with the leader up to 6 + leadership companies, under a captain up to 6.
- Count: 1 + ⌊home castle level / 2⌋ armies per house (1 while the home castle is lost).
- Each company has its own health share (`ArmyState.health`); companies under 20 % HP disband, an army without companies disbands and a free leader in it returns to the home castle.
- Recovery at settlement: +25 % of full HP per round in own provinces, +10 % elsewhere; garrisons that are not besieged +25 %.

## Leaders
- Generated from the seed at game start: leadership, lance and blade start at 2, the house bonus adds 1 (Welfen leadership, Wettiner blade, Staufer lance; the Wittelsbacher "free choice" is drawn from the seed), the remaining 2 points go to random skills, at most 5 each — 9 points in total; 3 wins in a discipline add a point (`wins_per_point`). Only leadership has an effect until joust and castle raid exist (M6); lance and blade values are in `data/combat.json` (`leader_skills`).
- The leader rides with one army (`HouseState.leader_army`); `AssignLeaderCommand` hands an army to the leader at court (army in the home province) or moves the leader between armies in one province.
- Captured leaders: captor in `HouseState.leader_captor`; while captured, the house's armies fight with morale −10 (`morale.leader_captured`); `PayRansomCommand` frees them (docs/design/economy.md).

## Campaign phase
Diplomacy between houses is out of scope (owner decision 2026-10-12): every other house is hostile and there is no camp truce ("Burgfrieden"); neutral, church and elector provinces are hostile land. Ban and elector effects come with M5.
- `MoveArmyCommand`: one neighbouring province per round; in summer a second step if the first one entered an own province. Entering foreign land or fighting ends the move.
- Hostile armies in the entered province are fought one after another (field battle, no walls). Then, in a foreign province: no defenders → conquest; defenders without a castle → open battle against them; a castle → siege.
- Defenders without an army: castle garrisons of house provinces (home castle table: wall level companies of levy, i.e. 1/2/3/3/4; province castles 1/2/3) and the levy of provinces without a house, ⌈V/20⌉ companies (Bohemia 8). All their companies share one health share (`ProvinceState.garrison_health`) and cost no upkeep; a garrison under 20 % is broken.
- Siege: the army stays in the province. `StormCommand` fights the garrison behind the walls (`BattleSetup.defender_wall`); otherwise the garrison starves at settlement (docs/design/economy.md, "Sieges") and surrenders once broken. The trebuchet is a normal unit until its minigame exists (M6).
- Battles: `BattleSetup` from the armies (health per company, leader and leadership, morale bonus while the leader is captured), the province terrain and the winter flag, resolved by `GameRules.resolver` (empty: auto-resolve with `state.rng`; the real-time battle plugs in here). Losers retreat to an own neighbour without hostile armies, the attacker preferring the province it came from; without one the army disbands and its leader is captured by the winner. A beaten army whose companies all broke counts the same.
- Conquest: the owner changes, the province is occupied for 4 rounds, its orders are cancelled, the garrison is fresh. A castle taken by siege (storm or starvation) loses one level; a castle that is nobody's home castle any more is capped at province castle level 3.

## Exile and victory
- Losing the home castle sends a house into exile: it keeps its provinces and one army (the leader's, else the largest) and loses its decorations. Taking a castle that had level ≥ 2 before the capture makes it the new home castle (one level lower). After 4 settlements without one the house is eliminated; its provinces fall to neutral lords. A house without provinces and armies is eliminated at once.
- Subjugation: the last house not eliminated wins (checked after every campaign phase and settlement).
- Time limit: after the settlement of round 48 the highest legitimacy wins, `L = 30·regalia + 20·Aachen + 10·Mainz + 2·provinces + prestige/5` (province tags `imperial_regalia`, `coronation_site`, `emergency_coronation_site`); ties go to the alphabetically first house id. `CampaignRules.legitimacy` also weighs forged regalia (+10) and secure votes (+10 each); both stay 0 until M5. The regalia stay on Trifels until the castle raid exists (M6).
- Coronation comes with M5 (section below).

## Road to the crown (data now, rules in M5)
The `crown` section of `data/map.json`, read by `CrownData`; houses carry their camp and two heraldic colours.
- Electors are the 7 provinces owned by `elector`; Cologne, Mainz and Trier are archbishops. Favour runs 0–100 per house and starts at 30 unless the province lists `start_favour` (GDD elector table; Alsace 50 for the Staufer). An elector votes for the house with the highest favour from 60 on.
- Coronation (`CrownData.votes_needed`): true or forged regalia at Aachen or Mainz need 4/5/5/6 of 7 votes; the archbishop of the site (Cologne for Aachen, Mainz for Mainz) needs favour 50 or the house holds that province. Forged regalia: 300 T, 2 rounds, home castle 3.
- Favour changes, gifts (50 T, +5; Wittelsbacher ×1.5 favour and ×0.75 cost), homage of neutral lords at favour 80 for 100 T, patron cards (north England, south France; 3 cards, 1 per round: 200 T, 4 brabanter companies or +15 favour) and the ban (attack on church land 50 %, raid 25 %; penance 150 T and 10 prestige, half the taler with the chapel of home castle 4).
