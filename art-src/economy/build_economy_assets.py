"""Builds the castle kit, the province buildings and the settlement houses (assets/economy/*.glb
plus an editable .blend each) and renders the review catalogues.

  blender --background --factory-startup --python art-src/economy/build_economy_assets.py [-- groups]

Groups: `pieces` (export every piece and the manifest), `catalog` (render the catalogues from
the exports and data/castle_art.json). Default: both."""
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parent.parent
sys.path.insert(0, str(ROOT / "art-src" / "combat"))
sys.path.insert(0, str(SOURCE))
sys.dont_write_bytecode = True

import castle_buildings  # noqa: E402
import castle_decor  # noqa: E402
import castle_halls  # noqa: E402
import castle_kit  # noqa: E402
import castle_settlement  # noqa: E402
from model_primitives import clear_scene, join_meshes  # noqa: E402

OUTPUT = ROOT / "assets" / "economy"
BUDGET = 3000

PIECES = {
    "castle_motte": castle_kit.motte,
    "castle_wood_tower": castle_kit.wood_tower,
    "castle_palisade": castle_kit.palisade,
    "castle_wood_hall": castle_kit.wood_hall,
    "castle_keep": castle_kit.keep,
    "castle_keep_spire": castle_kit.keep_spire,
    "castle_curtain_wall": castle_kit.curtain_wall,
    "castle_gatehouse": castle_kit.gatehouse,
    "castle_tower_roof": castle_kit.tower_roof,
    "castle_palas": castle_halls.palas,
    "castle_chapel": castle_halls.chapel,
    "castle_pfalz": castle_halls.pfalz,
    "castle_palisade_small": castle_kit.palisade_small,
    "castle_wall_small": castle_kit.wall_small,
    "castle_banner": castle_decor.banner,
    "castle_pennant": castle_decor.pennant,
    "castle_fountain": castle_decor.fountain,
    "castle_rose_garden": castle_decor.rose_garden,
    "castle_tapestry": castle_decor.tapestry,
    "castle_stained_glass": castle_halls.stained_glass,
    "castle_scaffold": castle_decor.scaffold,
    "castle_crane": castle_decor.crane,
    "castle_building_site": castle_decor.building_site,
    "castle_site_hut": castle_decor.site_hut,
    "building_mill": castle_buildings.mill,
    "building_market_1": castle_buildings.market_1,
    "building_market_2": castle_buildings.market_2,
    "building_granary": castle_buildings.granary,
    "building_monastery": castle_buildings.monastery,
    "building_mine": castle_buildings.mine,
    "building_toll": castle_buildings.toll,
    "building_tourney_ground": castle_buildings.tourney_ground,
    "building_workshop": castle_buildings.workshop,
    "settlement_cottage": castle_settlement.cottage,
    "settlement_house": castle_settlement.house,
    "settlement_longhouse": castle_settlement.longhouse,
    "settlement_townhouse": castle_settlement.townhouse,
}


def export_piece(name, build):
    clear_scene()
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
    build()
    obj = join_meshes(name)
    obj.data.uv_layers.remove(obj.data.uv_layers["stride"])
    obj["front"] = "-Y in Blender, +Z in glTF/Godot"
    obj["units"] = "metres; ground-centred pivot"
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / (name + ".glb")), export_format="GLB", use_selection=True,
        export_yup=True, export_texcoords=True, export_normals=True, export_materials="EXPORT",
        export_animations=False, export_extras=True,
    )
    obj.data.calc_loop_triangles()
    triangles = len(obj.data.loop_triangles)
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    size = [round(max(c[axis] for c in corners) - min(c[axis] for c in corners), 2) for axis in range(3)]
    materials = sorted({slot.material.name for slot in obj.material_slots if slot.material})
    print("ASSET", name, triangles, size, flush=True)
    return {"file": name + ".glb", "triangles": triangles, "budget": BUDGET,
            "dimensions_blender": size, "materials": materials}


def build_pieces(names):
    entries = [export_piece(name, PIECES[name]) for name in names]
    over = [entry for entry in entries if entry["triangles"] > entry["budget"]]
    path = SOURCE / "economy_asset_manifest.json"
    previous = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    fresh = {entry["file"] for entry in entries}
    merged = sorted(entries + [e for e in previous if e["file"] not in fresh], key=lambda e: e["file"])
    path.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    if over:
        raise RuntimeError("over the triangle budget: " + ", ".join(
            f"{e['file']} {e['triangles']}" for e in over))
    return entries


def main():
    bpy.context.preferences.filepaths.save_version = 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    groups = {arg for arg in args if arg in ("pieces", "catalog")} or {"pieces", "catalog"}
    names = [arg for arg in args if arg in PIECES] or list(PIECES)
    if "pieces" in groups:
        print("BUILT", len(build_pieces(names)), "pieces", flush=True)
    if "catalog" in groups:
        from render_castle_catalog import make_catalogs
        make_catalogs(SOURCE, OUTPUT, ROOT / "data" / "castle_art.json")


if __name__ == "__main__":
    main()
