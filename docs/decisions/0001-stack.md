# 0001 — Stack

Superseded by 0003 for platform, renderer and networking; engine, language and tool versions still apply.

- Context: turn-based strategy in low-poly 3D, played in the browser with online multiplayer.
- Decision: Godot 4.7.2 with GDScript (static typing enforced via project warnings), GL Compatibility renderer, GUT 9.7.1 for tests, gdtoolkit 4.5.0 for linting.
- Consequences: the GL Compatibility renderer is required for the Web export, so Forward+/Mobile-only features are unavailable.
- Consequences: in the browser only WebSocket/WebRTC networking works (no ENet); the network model needs its own ADR.
- Consequences: the CLI expects `godot` on PATH (launcher in `%USERPROFILE%\Tools\Godot`).
