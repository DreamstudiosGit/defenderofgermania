# Steam Early Access overhaul — plan and tracking

Goal: take THRONSTREIT 1198 from "milestones M0–M8 built" to a build that starts, plays and feels like a commercial indie title in Steam Early Access. Branch: `steam-early-access`. Started 2026-11-09.

State legend: `[x]` done and verified · `[~]` in progress · `[ ]` open · `[!]` blocked / needs the owner.

## Audit (2026-11-09)

Baseline: 663 GUT tests green (~3 min), lint and typecheck clean, simulation deterministic, rules cleanly separated from presentation (`src/systems` never touches `src/render` / `src/ui`), every player action a validated `Command`. The rules side is in good shape; what is missing is everything around it.

| Area | Finding | Severity |
|---|---|---|
| Shell | No main menu: the main scene is the battle prototype, the campaign starts only through `scripts/run.mjs --campaign` | P0 |
| Shell | No options (video, audio, language, controls), no pause menu, no way to quit or go back from any scene | P0 |
| Shell | Saves exist in code (`SaveGames`, autosave) but have no UI: no load screen, no manual save, no "continue" | P0 |
| Display | No stretch mode: UI is fixed pixels, unreadable on 4K, cramped on the Steam Deck | P0 |
| Audio | No audio at all: no files, no players, no buses | P0 |
| Look | Default engine font everywhere, GDD asks for Textura headings and an antiqua body; two parallel panel styles (`CampaignStyle`, `BattleResultPanel.panel_style`) | P1 |
| Controller | Campaign map: selecting provinces/armies and moving armies is mouse-only; no control holds focus after a modal closes | P0 |
| Controller | Campaign battles hard-wire the attacker to keyboard/mouse; the campaign battle result focuses a hidden button | P0 |
| Controller | No pause/leave in live campaign battles, joust and merchant train; nothing pauses the tree | P1 |
| Controller | Map camera reads pan/zoom input behind modals, battles and minigames | P1 |
| Controller | Bindings hard-coded in seven `*_input_map.gd`; no rebinding; hints are static strings for both device families | P1 |
| Feel | One tween in the whole game; modals pop in and out; army figures teleport; no screen shake outside the siege, no rumble, no hit-stop outside the battle's slow motion | P1 |
| Feel | AI turns and the end of a round run synchronously inside one button press with nothing shown | P1 |
| Render | MSAA 4x forced in every scene `_ready`; no quality levels for the Steam Deck | P1 |
| Render | Battles and minigames launched from the campaign may inherit the map's `WorldEnvironment` (first in tree wins) — to verify | P1 |
| Packaging | No export presets, no export templates installed, no icon, no build script, no Steam depot files, no CI | P0 |
| Packaging | `data/*.json` are plain files, not resources: exports must include them explicitly | P0 |
| Onboarding | No prologue, no advisors, no help; a new player lands on the war table without guidance | P1 |
| Docs | `docs/architecture.md` describes an event bus autoload (`src/core/events.gd`) that does not exist | P2 |

Full audit notes (UI inventory, architecture and save robustness) are folded into the work packages below as they come in.

## Decisions

- **Title**: the product name in the window title, menu and builds is the GDD's "THRONSTREIT 1198"; user data moves to a fixed folder (`Thronstreit1198`) so Steam Auto-Cloud paths stay stable.
- **Resolution model**: base canvas 1280×720, stretch `canvas_items`, aspect `expand`. The Steam Deck (1280×800) renders 1:1, 1080p at 1.5×, 4K at 3×. A UI-scale option (75–115 %) covers desktop preferences.
- **Fonts**: Texturina (Textura display face) for headings, Vollkorn (antiqua, lining tabular figures) for text; both SIL OFL, shipped with their licences in `assets/ui/`.
- **Autoloads**: `App` (options, shared theme, scene changes behind a curtain, controller-in-use, rumble, quit) and `Audio` (sound bank, pooled voices, layered music). Both live in `src/render/`; `src/core` and `src/systems` never reference them.
- **Audio content**: no licensed audio exists. All sounds and music are synthesised by `scripts/make_audio.mjs` (own work, no third-party samples) as placeholders with correct hooks, levels and ducking; replacing a file never needs a code change (`data/audio.json`).
- **Options**: `UserSettings` (`src/core/user_settings.gd`) is plain data with ranges and a ConfigFile; `SettingsApplier` turns it into engine state.
- **Steamworks**: builds run without the Steam client. GodotSteam (achievements, cloud API, overlay) needs the owner's app id and a GDExtension build matching Godot 4.7.2 — prepared, not bundled.
- **Git**: all work lands on `steam-early-access`, one commit per step through `scripts/ship.mjs`; `main` stays untouched until the owner merges.

## Work packages

### 0 Foundation
- [x] Branch, baseline run, export templates 4.7.2 installed (Windows, Linux, macOS)
- [x] `project.godot`: title, version 0.8.0, fixed user dir, 1280×720 canvas with `canvas_items` / `expand`, audio bus layout (Master with limiter, Music, Sfx, Ui), autoloads
- [x] Fonts and `UiFonts`; `CampaignStyle` uses them; root theme and fallback font set by `App`
- [x] `UserSettings` + tests; `SettingsApplier` (window mode, vsync, fps cap, quality, render scale, UI scale, language, volumes)
- [x] `App`: scene changes behind `SceneCurtain`, controller-in-use tracking, rumble, mute when unfocused
- [x] `Audio`: `AudioBank` (`data/audio.json`), voice pools (2D and positional), `MusicPlayer` with crossfade and intensity layers, `UiSounds` (every button, tab and slider gets a sound without per-screen code)
- [x] `CameraShake` helper (trauma-based, respects the screen-shake option)
- [ ] Theme polish: panel shadows, popup menus, scroll bars, check boxes, sliders
- [ ] `UiMotion`: shared open/close animation for modals and panels

### 1 Shell
- [ ] Main menu as main scene: war table backdrop, continue / new campaign / load / quick battle / practice / options / credits / quit
- [ ] Options screen: video, audio, game and accessibility, controls
- [ ] Pause menu in every scene: resume, options, save / load (campaign), back to menu, quit; pauses the scene
- [ ] Save and load screen: autosave and three slots with round, date and houses; overwrite and delete with confirmation
- [ ] Save robustness: atomic writes, a backup of the previous file, readable errors for broken or outdated saves
- [ ] Credits and licences screen (fonts, engine, GUT)
- [ ] Headless smoke test still reaches a computer-vs-computer battle through the menu

### 2 Audio content
- [ ] `scripts/make_audio.mjs`: synthesised UI, map, battle, joust, siege, raid, merchant sounds and stings
- [ ] Music: menu, map (calm), battle (layers by intensity), tournament, siege, raid (stealth → alarm), victory, defeat
- [ ] `data/audio.json` filled; levels checked (peak, RMS, no clipping, clean loops)

### 3 Controller and input
- [ ] One input table in data, registered at boot; the seven `*_input_map.gd` reduced to thin readers
- [ ] Rebinding with persistence; controls tab in the options
- [ ] Campaign map on a controller: province cursor, army selection, move, confirm / cancel, shoulder buttons for tabs
- [ ] Focus management: every screen grabs and restores focus; no dead ends
- [ ] Device-aware prompts (keyboard glyphs vs. controller buttons by last-used device)
- [ ] Campaign battles: the attacker plays on the device in use; second player on the next free one
- [ ] Map camera ignores input while a modal, battle or minigame covers it

### 4 Game feel
- [ ] Campaign: modal transitions, army move animation, phase / round banners, settlement and event stings, conquest feedback
- [ ] Battle: shake, rumble and sound on impact, volley, blast, rout, rally, capture; melee bed by contact count; music intensity
- [ ] Joust, siege, raid, merchant: sound, shake, rumble, hit-stop on their key events
- [ ] Curtain around battles and adventures launched from the campaign; no visible hitch
- [ ] AI turns and settlement no longer freeze the screen silently

### 5 Rendering and performance
- [ ] Quality levels (low for the Steam Deck, medium, high) drive MSAA, shadows, SSAO / SSIL, render scale
- [ ] Scenes stop forcing MSAA; `WorldEnvironment` conflict between map and covered scenes verified and fixed
- [ ] Benchmark at 1280×800, numbers recorded here

### 6 Onboarding
- [ ] Advisors (chamberlain, marshal, chancellor, master builder): at most one hint each per round, switchable in the options
- [ ] Help screen: how a round works, the three pillars, controls
- [ ] First-turn guidance for a new campaign

### 7 Packaging and Steam
- [ ] `export_presets.cfg` for Windows, Linux (Steam Deck) and macOS, including `data/*.json`
- [ ] `scripts/build.mjs`: versioned release builds into `build/`
- [ ] App icon, boot splash
- [ ] Steam depot build files (`steam/`), Steam Deck notes, Auto-Cloud paths
- [ ] CI workflow: lint, typecheck, tests, exports
- [ ] Exported Windows build starts and passes the smoke test

### 8 Verification
- [ ] Full suite green after every package; smoke test green
- [ ] Soak: computer-played campaigns to the end without errors
- [ ] Screenshots of every screen at 1280×800 and 1920×1080 reviewed
- [ ] `docs/architecture.md`, `docs/tasks.md`, `docs/STATUS.md`, `assets/README.md` match the code

## Needs the owner
- Listening pass on the synthesised audio; real music and foley are a content task (GDD: about 12 pieces, 200 sounds).
- Steam app id, depot ids and partner account for uploads; GodotSteam build for 4.7.2.
- macOS signing and notarisation (Apple developer account).
- Hands-on playtests with two controllers and on a Steam Deck; frame rates on the Deck.
- `AGENTS.md` is owner-edited: proposed changes are listed in the final report.

## Log
- 2026-11-09 Audit, plan, foundation (fonts, canvas scaling, options store, app shell, audio engine).
