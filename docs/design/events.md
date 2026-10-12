# Events

Event cards from `data/events.json` (GDD "Ereignisse"), read by `EventData`; state in `EventState` (`GameState.events`). ADR 0005.

## When cards come
- Every house's turn starts with its event phase (`TurnLoop._begin_turn` → `EventDeck.begin_turn`). The opening round has no cards (`first_turn` 1: it belongs to the prologue).
- The house draws one card from the deck: `deck` events plus `once` events without a favour condition (Zähringer years 1–3, crusade from year 4) until they fired, filtered by season, years and conditions, weighted (all weights 1; the GDD names none), by `state.rng`.
- `once` events with a favour condition fire on their own when the house reaches it (Bohemia at favour 50), once per game.
- Conditions: `needs_province` (Wartburg: the owner of Thuringia), `needs_feature` (flood, merchant train: a river province of the house; the card picks one), scope `neighbor` (robber knights, feud: an own province that is not the home and borders land of no house).
- Round events (`EventRound.start_round`, before the first house's turn) are news for everyone: `fixed` dates (papal legate every winter, the Lionheart's death in spring of year 2), the yearly `province_chance` roll per province in its season (plague: 4 % in summer), and the `weather` news in winter for regions whose autumn weather hit 0.6 or 1.3. Crusaders come home here as a new army at the home castle.

## Choices
- Cards without a choice act at once. With cards waiting for a choice the house stays in the event phase; `ChooseEventCommand` answers the first one (cost, effects, then a battle and its victory effects); after the last the administration phase begins.
- The campaign scene shows a human house its event phase in `EventCardDialog`: the round's news grouped per event, its cards that already acted and the waiting card with one button per choice (tooltip: cost and effects; refused choices say why); after the last answer the dialog sums up the turn once.
- Ending the phase (and passive houses until the AI) takes each card's `default`, else the first choice the house can take; a card it cannot answer passes.
- Refused choices: adventures (tournament invitation, merchant train raid, hostage raid) until their minigames exist (M6, `EVENT_ADVENTURE_LATER`); marriage is out of scope; Breisgau's homage once it has a lord; sending knights the house does not have; hunting without an army in or next to the card's province.

## Effects (`EventEffects`)
- Grain −20 % (−10 % with a granary anywhere); grain demand +25 % at the coming settlement (`EventState.grain_demand`, shown as its own breakdown term); harvest −20 % in the flooded province until the next autumn and no entry for one round (`EventState.harvest`, `blocked_until`, `MoveArmyCommand`).
- Population and satisfaction in the province and its neighbours, halved where a monastery stands; satisfaction of the home or the card's province; prestige (collected until settlement), gold.
- Favour with a lord or a group (`groups`: church electors Cologne, Mainz, Trier; trade cities Cologne and Brabant, the lords with a market); the legate's house with the highest summed church favour gains, the lowest risks the ban (nobody on a tie).
- Homage of Breisgau, the Bohemian vote promise (`CrownState.promised_votes`), England's cards at 75 % (`CrownState.patron_strength`), knights sent away for 8 rounds (`EventState.away`).
- Battles (`EventBattles`, auto-resolved through `GameRules.resolver`): `hunt` — the house's largest army in or next to the province attacks 3 companies of levy; `defend` — a count's 4 companies attack the province's largest army, else its garrison behind the walls, and a province that does not hold falls to a neutral lord. Band battles earn no battle prestige; the card's victory effects pay instead.
