# Combat art and selection visibility

Status: accepted

## Context

The battle prototype needs editable medieval models, animated scenery and readable selection cues while retaining batched rendering and deterministic combat.

## Decision

Use original Blender sources under `art-src/combat/` and glTF exports under `assets/combat/`. Batch rest meshes by unit and team with MultiMesh. UV2 encodes limb weight and phase for vertex animation; instance custom data carries movement, contact and interpolated simulation time. Named rigid bone actions are retained in character exports for source editing and future animation work.

Wind and water use presentation time. Palettes, scenery density and animation parameters belong to `data/combat_art.json`; this file is presentation-only and never part of a save or combat checksum. The compact art preview can stage a central river; the combat prototype's river is outside the playable field until river traversal and bridge pathfinding exist.

On the shared battle view, show selection circles, directional markers and highlighted group shields only when exactly one human controls a side. Show only that human's active group. Two-human couch battles and spectator/AI battles hide all selection cues, as requested by the owner.

## Consequences

No skeleton per runtime soldier, no third-party assets and no combat-rule or save-format changes. Art parameters can change independently of balancing. Steam Deck performance and real controller ergonomics still require hardware playtests.
