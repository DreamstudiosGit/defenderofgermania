## Project
- Genre: turn-based strategy with real-time battles; players move armies across a map, fight battles and manage an economy, against the AI, in hot-seat (2–4) or in a 1v1 couch battle.
- Stack: Godot 4.7.2 (Forward+ renderer, Jolt physics), GDScript with static typing (untyped declarations are errors), GUT 9.7.1 for tests, gdtoolkit 4.5.0 for linting — use only APIs of these versions.
- Target: Steam (Windows, macOS, Linux) and Steam Deck; input: controller and mouse/keyboard as equals

## Commands
- Run the game for the user: `node scripts/run.mjs` (`--editor` opens the editor); finds Godot via `GODOT`, PATH or `~/Tools/Godot/`
- Import (after cloning or adding assets): `godot --headless --import`
- Lint/typecheck: `gdlint .` · `godot --headless --script res://scripts/typecheck.gd`
- Test: `godot --headless -s addons/gut/gut_cmdln.gd` · folders: `… -gdir=res://src/<a>,res://src/<b> -gexit` · single: `… -gconfig= -gtest=res://<file>` (without `-gconfig=` the whole suite runs)
- Smoke test: `godot --headless --quit-after 600` — runs the main scene (battle prototype, computer vs. computer); must exit 0 without ERROR lines

## Layout
- One name per system everywhere: `src/systems/<system>/`, `data/<system>.json`, `docs/design/<system>.md`, `assets/<system>/`, commit scope `<system>`. Systems: `map`, `combat`, `economy`, `ai`.
- `src/core/` — turn loop, state, events, save/load
- `src/systems/<system>/` — rules, types and tests (`test_*.gd`) of one system; never references `src/render/` or `src/ui/` (enforced by the typecheck)
- `src/render/`, `src/ui/` — scenes, presentation and input
- `data/` — balancing values and player-facing texts
- `assets/` — runtime assets (`<system>/`, `ui/`); find them by filename
- `art-src/` — source files (.blend, master .svg) the game never loads; its `.gdignore` keeps Godot from importing them
- `addons/` — third-party plugins (GUT); never edit

## Communication
- Talk to the user in German. Code, identifiers, filenames, docs and commits in English.

## Context
- Open known files/symbols directly; otherwise search names/symbols first. Read only the ranges you need; never scan the whole repo.
- Read docs only when their trigger applies:
  - `docs/project.md` — overall scope unclear
  - `docs/design/<system>.md` — implementing or changing that system's mechanics
  - `docs/architecture.md` — cross-system or architectural change
  - `assets/README.md` — adding or renaming assets
  - `docs/tasks.md` — planning or open work
  - `docs/decisions/` — list filenames before architectural or data-format changes
- Don't read or hand-edit unless the task targets them: `assets/`, `art-src/`, `docs/archive/`, `addons/`, `.godot/`, `build/`, generated files (`*.import`, `*.uid`), large level/map files.
- Filter long command output for errors (grep); the first error is usually the cause.

## Code
- Smallest coherent change; no unrelated edits, no full-file rewrites.
- Add comments or docstrings only for constraints or rationale the code can't express (e.g. engine-bug workarounds); intent goes into names and types.
- No new abstractions, wrappers or dependencies without a concrete need; no circular dependencies.
- One responsibility per file; put new features in new files instead of growing files past ~300 lines.
- Pass randomness and time into game rules so they stay testable.
- Every player action is a `Command` that validates before it applies; AI, hot-seat and later async online use the same path. Never trust UI state.
- Move or rename assets and scenes together with their `.import`/`.uid` files, preferably in the editor.
- Balancing values (for example stats, costs, timings, spawn rates) live in `data/`, not in code.
- Player-facing text: German and English via keys in `data/i18n/texts.csv` (columns `keys,de,en`, read with `tr()`), not in code.
- Save format changes always bump the save version; add a migration once existing saves must survive (first public playtest).
- Don't drop validation or error handling when simplifying.

## Workflow
1. Ambiguous and costly to redo? Ask first; when running unattended, pick the most reasonable reading and state it.
2. Before changing shared code, types, method names or data formats, find all references — including string references in data and scene files.
3. Run focused tests/lint/typecheck. Report what ran, what didn't, and what needs manual playtesting.
4. Update docs only where facts changed: `docs/architecture.md`, a short ADR in `docs/decisions/` for significant decisions (new system, data format, library). Never document what code or tooling already shows.
5. When a task is done, delete it from `docs/tasks.md`.

## Git
- Commit or push only when the user asks; then run `node scripts/ship.mjs "<type>(<system>): <summary>"` (checks, logs to `docs/done.md`, commits, pushes, opens a PR from non-main branches).
- Never discard changes you didn't make.
