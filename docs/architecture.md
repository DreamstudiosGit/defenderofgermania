# Architecture

## Systems
- `map` — provinces, ownership, unit positions, movement and visibility.
- `combat` — resolves battles between units and applies losses.
- `economy` — resources, income and the costs of recruiting and building.
- `ai` — decides computer-controlled turns using the same actions as human players.

## Communication
- Systems talk via signals on an event bus autoload (`src/core/events.gd`).
- Allowed direct dependencies between systems: `combat`, `economy`, `ai` → read-only queries of `map`; `ai` → read-only queries of `combat` and `economy` (provisional).
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
- Combat presentation uses Blender glTF meshes batched by unit and team, GPU limb animation, foliage wind and flowing water. `data/combat_art.json` is presentation-only. Shared-view selection cues are hidden in two-human couch battles; see `docs/decisions/0004-combat-art.md`.
- Player actions are `Command` subclasses; `execute()` validates (active house, phase, game not over, rules) before `apply()` changes the state.
- All chance goes through `GameState.rng`; same seed and commands give the same `checksum()`.
- Multiplayer: hot-seat and the couch battle share one local state; online v1.0 is Steam Remote Play Together. Async online after launch sends only commands and the seed and replays them, so the simulation must stay deterministic.

## Save/load
- Serialized: the full game state including turn number and RNG state; save version field: `version` at the root of the save file.
- Format: `GameState.to_bytes()` (`var_to_bytes` of `to_dict()`), not JSON — see `docs/decisions/0002-game-data-and-saves.md`.
