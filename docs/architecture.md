# Architecture

## Systems
- `map` — provinces, ownership, unit positions, movement and visibility; electors, favour, coronation, homage, patron cards and the ban (`CrownData`).
- `combat` — resolves battles between units and applies losses; the adventure minigames (joust, trebuchet siege, castle raid, merchant train) are its modules (ADR 0007), played in the campaign through `Adventures` in `src/core/`.
- `economy` — resources, income and the costs of recruiting and building.
- `events` — event cards: drawing per turn, round events, choices and effects (`docs/design/events.md`, ADR 0005); its state is `EventState` in `src/core/`, battles it starts run in `EventBattles`.
- `ai` — decides computer-controlled turns using the same actions as human players (`docs/design/ai.md`); the session calls it through an injected Callable, so the core does not depend on it.

## Communication
- Systems talk via signals on an event bus autoload (`src/core/events.gd`).
- Allowed direct dependencies between systems: `combat`, `economy`, `events`, `ai` → read-only queries of `map`; `events`, `ai` → read-only queries of `economy`; `ai` → read-only queries of `combat` (provisional).
- Systems may use `src/core/` state and base classes; `src/core/` setup, turn loop and campaign orchestration call into systems (battles only through `GameRules.resolve_battle`).
- `economy` also reads the army limits and the hostile-army check of `map` (`CampaignRules`, `Movement`).
- The battle's computer opponent (`BattleAI`) lives in `combat` and sends the same `BattleInput` as a player; the strategic `ai` system is separate.

## Turn order
One round is one season; turn 0 is spring. `TurnLoop` drives it; houses play phases 1–3 one after another (lowest prestige first, ties by `GameState.rng`), eliminated houses are skipped; `EndPhaseCommand` ends a phase.
1. Event — passes at once until event cards exist (`TurnLoop._begin_turn`)
2. Administration — tax, ration, grain trade, building, castles, decorations, recruiting, leader, ransom
3. Campaign — `MoveArmyCommand` (battles, conquest, sieges on entering), `StormCommand`
4. Settlement — garrisons starve, `EconomySettlement.settle()` (constructions finish, `turn` advances, spring resets recruit budgets), recovery, exile countdown, victory check, next round

## State
- Game state lives in `src/core/game_state.gd` (typed data, no nodes); systems mutate it, render/ui only read it.
- Static data (`MapData`, `EconomyConfig`, `CombatConfig`) and the battle resolver form `GameRules`, built once from `data/` and never saved.
- Battles: the campaign builds a `BattleSetup`, the resolver returns a `BattleResult` (auto-resolve with `GameState.rng` while no resolver is set) and the campaign applies it.
- Real-time battle: `BattleSim` advances `BattleState` (packed arrays) in fixed 30 Hz ticks from one `BattleInput` per side and tick; render/ui turn devices into inputs and only read the state. Same setup, seed and inputs give the same `BattleResult`. The main scene is currently the battle prototype (`src/render/battle/battle_main.tscn`).
- Combat presentation uses house-neutral Blender glTF meshes batched by unit and side and tinted per house (ADR 0006), GPU limb animation, foliage wind and flowing water. `data/combat_art.json` is presentation-only. Shared-view selection cues are hidden in two-human couch battles; see `docs/decisions/0004-combat-art.md`.
- The imperial map is a war-table diorama in `src/render/map/` (`MapTable`: province fields from Voronoi cells of the province centres clipped to the realm outline, banners, castles, wooden army figures, candlelight). The drawing is approximate; moves always follow the adjacency in `data/map.json`. `data/map_art.json` is presentation-only; owner colours come from `MapData.heraldry()`.
- The castle view (`src/render/castle/`, `CastleView`) renders in its own `SubViewport` world, so its light never touches the war table; the campaign rests the table while it is open.
- Campaign UI in `src/ui/campaign/`: panels take the state through `refresh(...)` and only emit `command_requested(command)`; tooltips show every number's terms from `EconomyBreakdown`/`GrainBreakdown`, the grain forecast comes from `EconomyForecast` (`src/systems/economy/`). `src/render/campaign/campaign_main.tscn` wires the session, the war table, the panels and the battle scene.
- A campaign is driven by `CampaignSession` (`src/core/`): human houses issue commands, the others pass until the AI (M7); a move into a battle can be fought live in the battle scene (`battle_main.tscn`, `configure_campaign`) and its `BattleResult` then decides that battle.
- Player actions are `Command` subclasses; `execute()` validates (active house, phase, game not over, rules) before `apply()` changes the state.
- All chance goes through `GameState.rng`; same seed and commands give the same `checksum()`.
- Multiplayer: hot-seat and the couch battle share one local state; online v1.0 is Steam Remote Play Together. Async online after launch sends only commands and the seed and replays them, so the simulation must stay deterministic.

## Save/load
- Serialized: the full game state including turn number and RNG state; save version field: `version` at the root of the save file.
- Format: `GameState.to_bytes()` (`var_to_bytes` of `to_dict()`), not JSON — see `docs/decisions/0002-game-data-and-saves.md`.
