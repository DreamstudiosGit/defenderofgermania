"""Builds the castle raid fighters: assets/combat/unit_raider.glb and unit_guard.glb plus their
editable .blend files here, and updates their entries in combat_asset_manifest.json in place.

    blender --background --factory-startup --python art-src/combat/build_raid_assets.py
"""
import json
import sys
from pathlib import Path

import bpy

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parent.parent
sys.path.insert(0, str(SOURCE))
sys.dont_write_bytecode = True

import unit_palette  # noqa: E402,F401  registers the unit palette and house masks
from raid_fighters import FIGHTERS  # noqa: E402
from unit_export import _export, _reset  # noqa: E402

OUTPUT = ROOT / "assets" / "combat"


def export_fighter(name):
    build, budget = FIGHTERS[name]
    _reset()
    anchor = build()
    entry = _export(f"unit_{name}", SOURCE, OUTPUT, True)
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    animations = [track.name for rig in rigs for track in rig.animation_data.nla_tracks]
    entry.update({"budget": budget, "animations": animations, "rigs": sorted(rig.name for rig in rigs),
                  "crest_anchor_height": round(anchor.location.z, 3)})
    if entry["triangles"] > budget:
        raise RuntimeError(f"{entry['file']}: {entry['triangles']} triangles exceed {budget}")
    return entry


def write_manifest(entries):
    """Replaces the raid fighters' entries where they stand and appends new ones at the end."""
    path = SOURCE / "combat_asset_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    fresh = {entry["file"]: entry for entry in entries}
    merged = [fresh.pop(entry["file"], entry) for entry in manifest]
    merged += [entry for entry in entries if entry["file"] in fresh]
    path.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")


def main():
    bpy.context.preferences.filepaths.save_version = 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    entries = [export_fighter(name) for name in FIGHTERS]
    write_manifest(entries)
    print("BUILT", ", ".join(entry["file"] for entry in entries), flush=True)


if __name__ == "__main__":
    main()
