import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parent.parent
sys.path.insert(0, str(SOURCE))
sys.dont_write_bytecode = True

from model_landscape import (
    bridge, camp, fern, ground, pebble_patch, river, riverbank, rock, tree, undergrowth, water_lilies
)
from model_primitives import clear_scene, join_meshes
from model_weapons import spear
from render_unit_catalog import make_catalog
from unit_export import export_all

OUTPUT = ROOT / "assets" / "combat"


def export_asset(name, build):
    clear_scene()
    build()
    obj = join_meshes(name)
    obj["front"] = "-Y in Blender, +Z in glTF/Godot"
    obj["units"] = "metres; ground-centred pivot"
    obj["stride_mask"] = "UV2.x weight; UV2.y limb phase; runtime GPU animation"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / (name + ".glb")), export_format="GLB",
        use_selection=True, export_yup=True, export_texcoords=True,
        export_normals=True, export_materials="EXPORT", export_animations=False, export_extras=True,
    )
    triangle_count = 0
    for item in bpy.context.scene.objects:
        if item.type == "MESH":
            item.data.calc_loop_triangles()
            triangle_count += len(item.data.loop_triangles)
    corners = [item.matrix_world @ Vector(corner) for item in bpy.context.scene.objects
               if item.type == "MESH" for corner in item.bound_box]
    size = tuple(round(max(c[axis] for c in corners) - min(c[axis] for c in corners), 3)
                 for axis in range(3))
    print("ASSET", name, triangle_count, size, flush=True)
    return {"file": name + ".glb", "triangles": triangle_count,
            "dimensions_blender": size, "animations": []}


def build_scenery():
    manifest = []
    for team in ("blue", "red"):
        for prop in ("banner", "tent", "watchtower"):
            manifest.append(export_asset(f"prop_{prop}_{team}", lambda p=prop, t=team: camp(p, t)))
    manifest.append(export_asset("weapon_spear", spear))
    for kind in ("oak", "birch", "pine", "oak_autumn"):
        manifest.append(export_asset(f"tree_{kind}", lambda k=kind: tree(k)))
    for variant in ("boulder", "small", "cluster"):
        manifest.append(export_asset(f"rock_{variant}", lambda v=variant: rock(v)))
    for kind in ("bush", "stump", "grass", "flowers", "reeds"):
        manifest.append(export_asset(f"foliage_{kind}", lambda k=kind: undergrowth(k)))
    for kind in ("barrel", "fence"):
        manifest.append(export_asset(f"prop_{kind}_wood", lambda k=kind: camp(k)))
    manifest.append(export_asset("prop_bridge_wood", bridge))
    manifest.append(export_asset("terrain_river_straight", river))
    manifest.append(export_asset("terrain_river_bend", lambda: river(True)))
    manifest.append(export_asset("terrain_meadow", ground))
    manifest.append(export_asset("terrain_hill", lambda: ground(True)))
    manifest.append(export_asset("terrain_path", lambda: ground(path=True)))
    manifest.append(export_asset("terrain_riverbank_rocky", riverbank))
    manifest.append(export_asset("foliage_water_lilies", water_lilies))
    manifest.append(export_asset("foliage_fern", fern))
    manifest.append(export_asset("terrain_pebble_patch", pebble_patch))
    return manifest


def write_manifest(entries):
    """Rebuilt entries first; entries of assets not rebuilt in this run are kept."""
    path = SOURCE / "combat_asset_manifest.json"
    previous = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    fresh = {entry["file"] for entry in entries}
    merged = entries + [entry for entry in previous if entry["file"] not in fresh]
    path.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    return merged


def main():
    """Groups after `--`: units (house-neutral units, crests, catalog), scenery. Default: units."""
    bpy.context.preferences.filepaths.save_version = 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    groups = set(sys.argv[sys.argv.index("--") + 1:]) if "--" in sys.argv else {"units"}
    entries = []
    if "units" in groups:
        entries += export_all(SOURCE, OUTPUT)
    if "scenery" in groups:
        entries += build_scenery()
    print("BUILT", len(entries), "assets;", len(write_manifest(entries)), "in manifest", flush=True)
    if "units" in groups:
        make_catalog(SOURCE, OUTPUT)


if __name__ == "__main__":
    main()
