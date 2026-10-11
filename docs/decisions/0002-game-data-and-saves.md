# 0002 — Game data and save format

- Context: all balancing values come from the GDD and must stay out of code; the simulation must be deterministic and saves must load bit-identically.
- Decision: one JSON file per system in `data/` (`map.json`, `economy.json`, …), loaded into typed classes (`MapData`, `EconomyConfig`) through `DataReader`, which reports every missing or mistyped key. Province ids are the GDD's three-letter codes, all other ids snake_case. Integrity (references, symmetric adjacency, GDD counts) is checked by GUT tests, not a separate lint tool.
- Decision: the save format is `GameState.to_dict()` encoded with `var_to_bytes` (binary), with a `version` field at the root; the state checksum is SHA-256 over the same bytes.
- Consequences: Godot's JSON parser does not read doubles back exactly, so saves and state sync must never go through JSON; `bytes_to_var` is used without object decoding.
- Consequences: JSON numbers are floats, so loaders convert whole numbers explicitly; 64-bit RNG values are stored as strings.
- Consequences: the data files are read with `FileAccess` at runtime, so the exports must contain `data/*.json` (check the export, add an include filter if missing).
