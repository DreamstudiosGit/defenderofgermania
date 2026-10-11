# 0003 — Steam target

Supersedes the platform, renderer and networking parts of 0001.

- Context: the GDD targets Steam and the Steam Deck with controllers, hot-seat and a 1v1 couch battle; the browser target of 0001 ruled out Forward+ effects (toon shading, outlines, many figures) and required own netcode.
- Decision: Steam builds for Windows, macOS and Linux, plus the Steam Deck as a native Linux x86_64 build. Godot 4.7.2, GDScript, GUT 9.7.1 and gdtoolkit 4.5.0 stay.
- Decision: Forward+ renderer and Jolt physics.
- Decision: controller and mouse/keyboard are equal inputs.
- Decision: multiplayer is local — hot-seat for 2–4 players and the 1v1 couch battle. Online v1.0 runs through Steam Remote Play Together without own netcode. Asynchronous online play after launch only sends commands and the seed.
- Decision: Steamworks features (achievements, cloud saves) come through the GodotSteam GDExtension once they are built; its version is pinned in `AGENTS.md` then.
- Consequences: no Web export.
- Consequences: performance budgets target the Steam Deck: map 60 fps; battle with 400 figures at least 40 fps; under 1,500 draw calls. Crowds need MultiMesh with vertex animation textures.
- Consequences: Jolt is only for presentation and minigames, never the deterministic simulation.
- Consequences: commands are still validated before they apply, so the AI, hot-seat and later async online share one path.
- Consequences: macOS builds need signing and notarisation (Apple developer account); consoles come later through a porting partner, since Godot ships no console exports.
