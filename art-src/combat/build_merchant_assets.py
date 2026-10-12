"""Exports the merchant train kit to assets/combat/ (run with Blender 5.2, see README.md)."""
import sys
from pathlib import Path

import bpy

SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))
sys.dont_write_bytecode = True

from build_combat_assets import export_asset, write_manifest  # noqa: E402
from model_merchant import cargo, draught_horse, town_gate, wagon, wheel  # noqa: E402

ASSETS = {
    "prop_wagon_merchant": wagon,
    "prop_wagon_wheel": wheel,
    "prop_cargo_bale": lambda: cargo("bale"),
    "prop_cargo_crate": lambda: cargo("crate"),
    "unit_draught_horse": draught_horse,
    "prop_town_gate": town_gate,
}


def outward_normals(build):
    """Plates and mirrored parts come with mixed windings; point every face outwards."""
    def run():
        build()
        for obj in [item for item in bpy.context.scene.objects if item.type == "MESH"]:
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="SELECT")
            bpy.ops.mesh.normals_make_consistent(inside=False)
            bpy.ops.object.mode_set(mode="OBJECT")
    return run


def main():
    bpy.context.preferences.filepaths.save_version = 0
    entries = [export_asset(name, outward_normals(build)) for name, build in ASSETS.items()]
    print("BUILT", len(entries), "merchant assets;", len(write_manifest(entries)), "in manifest",
          flush=True)


if __name__ == "__main__":
    main()
