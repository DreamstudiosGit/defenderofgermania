# 0005 — Events system and the road to the crown

- Context: the GDD's 18 event cards touch grain, population, prestige, favour, battles and minigames, so they fit no existing system. Electors, coronation, homage, patron cards and the ban return to scope (owner brief, 2026-10-12); diplomacy between houses (alliances, truces, treaties, marriages, peace congress, camp truce) stays out.
- Decision: a fifth system `events` (`src/systems/events/`, `data/events.json`, commit scope `events`). Each event is data: trigger (`deck`, `weather`, `province_chance`, `fixed`, `once`), seasons, weight, conditions, effects or choices with costs, effects and victory effects. Effect types, scopes and adventures are closed lists in `EventData`, checked by tests.
- Decision: electors, favour, coronation table, homage, patron cards and the ban live in `map` (`crown` section of `data/map.json`, `CrownData`); start favour lists sit on the provinces of electors and neutral lords.
- Consequences: `events` may read `map` and `economy` and change game state through the same paths as commands; drawing and applying events came with milestone M5 (`docs/design/events.md`).
- Consequences: `AGENTS.md` must list `events` among the systems (owner edit).
