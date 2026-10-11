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
- Generated from the seed at game start: leadership, lance and blade start at 2, the house bonus adds 1 (Welfen leadership, Wettiner blade, Staufer lance; the Wittelsbacher "free choice" is drawn from the seed), the remaining 2 points go to random skills, at most 5 each — 9 points in total. Only leadership has an effect while joust and castle raid are cut.
- The leader rides with one army (`HouseState.leader_army`); `AssignLeaderCommand` hands an army to the leader at court (army in the home province) or moves the leader between armies in one province.
- Captured leaders: captor in `HouseState.leader_captor`; while captured, the house's armies fight with morale −10 (`morale.leader_captured`); `PayRansomCommand` frees them (docs/design/economy.md).

## Campaign phase
No diplomacy yet: every other house is hostile (the camp truce "Burgfrieden" comes with diplomacy), and neutral, church and elector provinces are hostile land. Ban and elector effects are not applied yet.
- `MoveArmyCommand`: one neighbouring province per round; in summer a second step if the first one entered an own province. Entering foreign land or fighting ends the move.
- Hostile armies in the entered province are fought one after another (field battle, no walls). Then, in a foreign province: no defenders → conquest; defenders without a castle → open battle against them; a castle → siege.
- Defenders without an army: castle garrisons of house provinces (home castle table: wall level companies of levy, i.e. 1/2/3/3/4; province castles 1/2/3) and the levy of provinces without a house, ⌈V/20⌉ companies (Bohemia 8). All their companies share one health share (`ProvinceState.garrison_health`) and cost no upkeep; a garrison under 20 % is broken.
- Siege: the army stays in the province. `StormCommand` fights the garrison behind the walls (`BattleSetup.defender_wall`); otherwise the garrison starves at settlement (docs/design/economy.md, "Sieges") and surrenders once broken. The trebuchet is a normal unit while its minigame is cut.
- Battles: `BattleSetup` from the armies (health per company, leader and leadership, morale bonus while the leader is captured), the province terrain and the winter flag, resolved by `GameRules.resolver` (empty: auto-resolve with `state.rng`; the real-time battle plugs in here). Losers retreat to an own neighbour without hostile armies, the attacker preferring the province it came from; without one the army disbands and its leader is captured by the winner. A beaten army whose companies all broke counts the same.
- Conquest: the owner changes, the province is occupied for 4 rounds, its orders are cancelled, the garrison is fresh. A castle taken by siege (storm or starvation) loses one level; a castle that is nobody's home castle any more is capped at province castle level 3.

## Exile and victory
- Losing the home castle sends a house into exile: it keeps its provinces and one army (the leader's, else the largest) and loses its decorations. Taking a castle that had level ≥ 2 before the capture makes it the new home castle (one level lower). After 4 settlements without one the house is eliminated; its provinces fall to neutral lords. A house without provinces and armies is eliminated at once.
- Subjugation: the last house not eliminated wins (checked after every campaign phase and settlement).
- Time limit: after the settlement of round 48 the highest legitimacy wins, `L = 30·regalia + 20·Aachen + 10·Mainz + 2·provinces + prestige/5` (province tags `imperial_regalia`, `coronation_site`, `emergency_coronation_site`); ties go to the alphabetically first house id. Votes and forged regalia join once electors exist; the regalia stay on Trifels while the castle raid is cut.
- Coronation is deferred with the electors.
