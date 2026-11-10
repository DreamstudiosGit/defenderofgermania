# Steam: build, upload, configure

The game ships without the Steamworks SDK: the builds start with or without the Steam client.
Everything below is configuration on the Steamworks partner site plus an upload with `steamcmd`.
Nothing here was run against Steam yet — there is no app id; see "Not verified" at the end.

## Files

- `app_build.vdf` — the SteamPipe build script; names the app, the content root `build/` and the three depot scripts.
- `depot_build_windows.vdf`, `depot_build_linux.vdf`, `depot_build_macos.vdf` — one depot each, mapping `build/<platform>/`.
- Placeholders to replace once the ids exist: `REPLACE_WITH_APP_ID`, `REPLACE_WITH_WINDOWS_DEPOT_ID`, `REPLACE_WITH_LINUX_DEPOT_ID`, `REPLACE_WITH_MACOS_DEPOT_ID` (each depot id appears twice: in `app_build.vdf` and in its depot script).

## Build

```
node scripts/build.mjs all        # or: windows | linux | macos
```

| Platform | Preset | Result in `build/<platform>/` |
|---|---|---|
| Windows x86_64 | `Windows` | `thronstreit.exe`, `thronstreit.pck`, `version.txt` |
| Linux x86_64 (also the Steam Deck) | `Linux` | `thronstreit.x86_64`, `thronstreit.pck`, `version.txt` |
| macOS universal | `macOS` | `thronstreit.zip` (holds `THRONSTREIT 1198.app`), `version.txt` |

The script fails when an export reports an error, when the pack lacks a file the game reads as a plain file (`data/*.json`, the font licences) or when it holds tests or tools. `node scripts/pck_files.mjs <file.pck|file.zip> [text]` lists a pack.

Smoke test of a build (Windows shown): `build\windows\thronstreit.exe --headless --quit-after 600` must exit 0 without `ERROR` lines; without a console its output is in `user://logs/godot.log`.

## Steamworks setup (once)

1. Create three depots and restrict each to its operating system: Windows, Linux + SteamOS, macOS. Add all three to the store package and to the developer package — a depot missing from the package is the usual reason a platform downloads nothing.
2. Launch options (Installation → General Installation), no arguments:

| OS | Executable |
|---|---|
| Windows (64-bit) | `thronstreit.exe` |
| Linux + SteamOS (64-bit) | `thronstreit.x86_64` |
| macOS | `THRONSTREIT 1198.app` |

3. Steam Cloud, see "Auto-Cloud" below.
4. Store page, Basic Info: tick the local multiplayer features (shared/split screen, local co-op or PvP as applicable), full or partial controller support, and the languages German and English.

A first start opens borderless fullscreen; window mode and size are the player's options (`settings.cfg`), not launch arguments.

## Upload

`steamcmd` is part of the Steamworks SDK (`tools/ContentBuilder/builder*/`); it is not in this repository.

```
steamcmd +login <build account> +run_app_build <absolute path>/steam/app_build.vdf +quit
```

- Dry run first: set `"Preview" "1"` in `app_build.vdf`; nothing is uploaded, the manifests land in `build/steam_output/`.
- Put the version into `"Desc"` (`build/<platform>/version.txt`); it only shows on the builds page.
- An upload never goes live by itself: set the build live on a branch on the builds page (or add `"SetLive" "<beta branch>"`; the default branch cannot be set live by script).
- macOS: the depot needs the unpacked bundle. Unpack on a Mac or on Linux, where the executable bit and the ad-hoc signature survive: `cd build/macos && unzip thronstreit.zip`. The depot script leaves the zip out.
- Linux and macOS depots are best uploaded from Linux or macOS (for instance from the CI artifacts, which are tar archives and keep the executable bit). An export made on Windows cannot carry that bit on disk.

## Auto-Cloud

User data lives in a fixed folder (`config/use_custom_user_dir`, name `Thronstreit1198`), independent of the project name. Godot resolves `user://` to:

| OS | Folder | Auto-Cloud root |
|---|---|---|
| Windows | `%APPDATA%\Thronstreit1198\` (verified on the build machine: `C:\Users\<user>\AppData\Roaming\Thronstreit1198`) | `WinAppDataRoaming` |
| macOS | `~/Library/Application Support/Thronstreit1198/` | `MacAppSupport` |
| Linux, Steam Deck | `$XDG_DATA_HOME/Thronstreit1198/`, by default `~/.local/share/Thronstreit1198/` | `LinuxXdgDataHome` |

What is in it: `saves/*.sav` (`autosave.sav`, `slot_1.sav` … `slot_3.sav`; a fresh campaign is about 19 KB), `settings.cfg` (the options) and `logs/` (engine logs, never synced).

Steam Cloud settings (Application → Steam Cloud):

- Byte quota per user `10485760` (10 MB), number of files per user `32` — generous for four saves; raise it if the save format grows.
- Root paths, both with OS `[Cross-Platform]`, not recursive:

| Root | Subdirectory | Pattern |
|---|---|---|
| `WinAppDataRoaming` | `Thronstreit1198/saves` | `*.sav` |
| `WinAppDataRoaming` | `Thronstreit1198` | `settings.cfg` |

- Root overrides, so the same two rows apply on the other systems (no "Add/Replace Path"):

| Original root | OS | New root |
|---|---|---|
| `WinAppDataRoaming` | macOS | `MacAppSupport` |
| `WinAppDataRoaming` | Linux | `LinuxXdgDataHome` |

`settings.cfg` holds per-device values (window mode and size, quality, render scale, UI scale) next to personal ones (language, volumes, rumble). Synced, a desktop's quality level follows the player onto the Steam Deck. Either leave the second row out until the options are split into a device file and a player file, or accept that; the saves row is safe either way.

Test with "Enable cloud support for developers only" before publishing the settings, and check that a save written on Windows appears on a second system.

## Steam Deck

The Deck runs the Linux build natively (no Proton), on SteamOS's Vulkan driver. The canvas is 1280×720 with aspect `expand`, so the Deck's 1280×800 is rendered 1:1 with 80 more lines of height.

Valve's review for "Verified" (partner documentation, Steam Deck compatibility review) and where the game stands on this branch — the open points are tracked in `STEAM_OVERHAUL_PLAN.md`:

| Requirement | State |
|---|---|
| All content reachable with the Deck's controls in the default configuration, without changing settings | Menus, options and pause are controller-first. The campaign map on a controller is work package 3. Needs a play-through on the device. |
| Button prompts match the device in use; no keyboard glyphs during controller play | Work package 3 (device-aware prompts). |
| Text entry opens the on-screen keyboard or works with a controller alone | The only text field is the optional campaign seed, with a reroll button next to it. Opening the on-screen keyboard from the game needs GodotSteam. |
| Runs at a resolution the Deck supports (1280×800 or 1280×720 recommended) | Expected to be met: the canvas fits both, and a shipped build starts borderless fullscreen. To confirm on the device. |
| Smallest text at least 9 px tall at 1280×800 (12 px recommended) | Body text is 16 px, small text 14 px, progress-bar labels 12 px font size at 100 % UI scale: lower-case letters of the small sizes are near the limit. To measure on the device; the UI scale goes up to 115 %. |
| Default configuration gives a playable frame rate (30 fps at 800p) | Open: the default quality is "high" on every machine and nothing detects the Deck. Work package 5 (quality levels, benchmark at 1280×800); SteamOS sets the environment variable `SteamDeck=1`. |
| No warnings about unsupported hardware or software | Met: the game shows none. |
| No launcher | Met. |

Until all rows are met the expected rating is "Playable".

## Remote Play Together

Steam enables it for games listed with a local multiplayer feature on the store page (Basic Info); only the host needs the game. Hot-seat and the couch battle need nothing else: guests' controllers and keyboards arrive as local devices. To test before release, pick a password-protected branch under Application → Steam Remote Play. An in-game invite button would need `ISteamRemotePlay` through GodotSteam; the Steam overlay offers the same invite without it.

## Later: GodotSteam

[GodotSteam](https://godotsteam.com) wraps the Steamworks SDK as a GDExtension. It is neither bundled nor downloaded here; it needs the app id and a build matching Godot 4.7.2, and its version gets pinned in `AGENTS.md` then (ADR 0003). It would add:

- achievements and stats, rich presence;
- knowing that the overlay is open (to pause), the on-screen keyboard for the seed field, `isSteamRunningOnSteamDeck()` instead of the environment variable;
- the Cloud API as an alternative to Auto-Cloud, Remote Play invites from inside the game.

With it the build folders also carry the extension's library and the Steam API library (`steam_api64.dll`, `libsteam_api.so`, `libsteam_api.dylib`) next to the executable. The presets' exclude filter keeps out `addons/gut/` only, so an extension under `addons/` is exported.

## Not verified

- No upload was made: there is no app id, and `steamcmd` was not available. The `.vdf` files follow Valve's documented format; forward slashes in their paths are expected to work on every host (Valve's sample scripts are shared between the Windows, Linux and macOS builders) but were not run.
- Whether SteamPipe keeps or restores the executable bit of a Linux or macOS binary uploaded from Windows is not documented by Valve; hence the advice to upload those depots from Linux or macOS and to start each platform once from Steam after the first upload.
- The Linux and macOS builds were exported on Windows but not started. The macOS bundle is ad-hoc signed and not notarised (that needs the owner's Apple developer account); the bundle identifier `com.dreamstudios.thronstreit1198` in `export_presets.cfg` is a placeholder to confirm before the first signed build.
- The Auto-Cloud paths for macOS and Linux follow Godot's documented behaviour; only the Windows path was checked on a machine.
