# Tasks

Design questions and owner decisions: `docs/STATUS.md`.

## Next
- Owner playtest of P1 against the kill criterion (does a tester start a second round on their own?), keyboard-only and with two controllers.
- Real-time battle in the campaign: a battle takes minutes, so the move needs a pending-battle step that waits for the battle scene's `BattleResult`; the synchronous `GameRules.resolver` only fits auto-resolve and tests. Add the battle seed to `BattleSetup` then (`BattleSim` takes it separately today).
- AI turns through the same commands (utility AI from the GDD, personalities, difficulty).
- Map UI and hot-seat handover screen.
- Event cards in the event phase (M5; data in `data/events.json`).
- Rebels and revolt endings, morale state on the map, splitting and merging armies.
- Install Godot 4.7.2 export templates, add export presets for Windows, macOS and Linux (include `data/*.json`) and propose a build command (`godot --headless --export-release "Linux" build/linux/<name>.x86_64`) for `AGENTS.md` to the owner (`AGENTS.md` is owner-edited only).
- Steam Deck pipeline test (Gate 1): 200 figures with vertex animation textures on MultiMesh at 60 fps or more on the Deck; also measure P1 there (desktop: 1.4 ms simulation per tick and 1.6 ms figure update per frame at 386 figures).
