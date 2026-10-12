"""Side-view siege kit for the trebuchet minigame (assets/combat/siege_*.glb plus an editable
.blend each): straight wall, palisade and gate segments, a wall tower, the wooden hoarding on
the gatehouse, rubble heaps and the two projectiles. They reuse the castle kit's shapes and
palette (art-src/economy/castle_shapes.py) so they sit seamlessly next to the M4 kit pieces.

  blender --background --factory-startup --python art-src/combat/build_siege_kit.py [-- names]

Blender coordinates: Z up, front (facing the trebuchet) is -Y, segments run along X; metres,
ground-centred pivots."""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parent.parent
sys.path.insert(0, str(SOURCE))
sys.path.insert(0, str(ROOT / "art-src" / "economy"))
sys.dont_write_bytecode = True

from castle_kit import stake_panel  # noqa: E402
from castle_shapes import (  # noqa: E402
    hip_roof, merlons_line, opening, round_tower,
)
from model_primitives import beam, box, clear_scene, cone, ico, join_meshes, sphere  # noqa: E402

OUTPUT = ROOT / "assets" / "combat"
BUDGET = 3000
SEGMENT = 10.0


def palisade():
    """Ten metres of pointed stakes with the rail and props behind them."""
    stake_panel((-SEGMENT / 2, 0.0), (SEGMENT / 2, 0.0), 3.2, 3)
    for z in (1.0, 2.4):
        box("palisade_rail", (0, 0.32, z), (SEGMENT, 0.18, 0.2), "castle_timber")
    for x in (-3.5, 0.0, 3.5):
        beam("palisade_prop", (x, 1.6, 0.0), (x, 0.3, 2.6), 0.09, "castle_timber", vertices=5)


def palisade_gate():
    """Gate of a wooden castle: two posted gate towers with a closed double gate between."""
    depth = 1.9
    for side in (-1, 1):
        x = side * 2.35
        for ox in (-0.7, 0.7):
            for oy in (-0.7, 0.7):
                box("gate_post", (x + ox, oy, 2.6), (0.3, 0.3, 5.2), "castle_timber")
        box("gate_platform", (x, 0, 4.4), (depth, depth, 0.25), "castle_wood_light")
        box("gate_parapet", (x, -0.85, 4.95), (depth, 0.12, 0.9), "castle_wood")
        hip_roof("gate_roof", (x, 0, 5.6), 2.4, 2.4, 1.3, "castle_shingle")
        stake_panel((x - 0.95, 0.0), (x + 0.95, 0.0), 3.2, 5 + side)
    for side in (-1, 1):
        box("gate_leaf", (side * 0.71, -0.1, 1.6), (1.38, 0.18, 3.2), "castle_wood_light")
        for z in (0.7, 2.5):
            box("gate_band", (side * 0.71, -0.21, z), (1.3, 0.05, 0.14), "castle_iron")
    beam("gate_brace", (-1.35, -0.22, 0.4), (-0.1, -0.22, 2.9), 0.07, "castle_timber", vertices=4)
    beam("gate_brace", (1.35, -0.22, 0.4), (0.1, -0.22, 2.9), 0.07, "castle_timber", vertices=4)
    box("gate_lintel", (0, 0, 4.6), (6.6, 0.35, 0.35), "castle_timber")


def wall_segment():
    """Ten metres of curtain wall (7 m high, 1.8 m thick) with merlons and a wall-walk."""
    height, thickness = 7.0, 1.8
    box("wall", (0, 0, height / 2), (SEGMENT, thickness, height), "castle_stone")
    box("wall_course", (0, 0, height - 0.25), (SEGMENT + 0.05, thickness + 0.2, 0.5),
        "castle_stone_light")
    box("wall_plinth", (0, 0, 0.4), (SEGMENT + 0.05, thickness + 0.3, 0.8), "castle_stone_dark")
    merlons_line((-SEGMENT / 2 + 0.2, -thickness / 2 + 0.3), (SEGMENT / 2 - 0.2,
                 -thickness / 2 + 0.3), height, "castle_stone_light")
    for x in (-2.6, 2.6):
        opening("wall_slit", (x, -thickness / 2 - 0.03, 3.2), 0.4, 1.2)


def wall_tower():
    round_tower((0, 0), 2.6, 10.5, "castle_stone", 8, 10, "castle_stone_light")
    for z in (3.5, 7.0):
        opening("tower_slit", (0, -2.62, z), 0.45, 1.2)


def hoarding():
    """Wooden fighting gallery on top of a gatehouse: 4.6 m wide, 7.6 m deep, 2.9 m high."""
    width, depth, height = 4.6, 7.6, 2.9
    box("hoarding_floor", (0, 0, 0.12), (width, depth, 0.24), "castle_timber")
    box("hoarding_walls", (0, 0, 1.1), (width - 0.1, depth - 0.1, 1.8), "castle_wood")
    for x in (-width / 2, 0.0, width / 2):
        for y in (-depth / 2, depth / 2):
            box("hoarding_post", (x, y, 1.0), (0.22, 0.22, 2.0), "castle_timber")
    for y in (-depth / 2, depth / 2):
        box("hoarding_beam", (0, y, 2.0), (width + 0.2, 0.24, 0.22), "castle_timber")
        for x in (-1.2, 0.0, 1.2):
            opening("hoarding_loophole", (x, y - (0.03 if y < 0 else -0.03), 0.9), 0.32, 0.6,
                    0.0 if y < 0 else math.pi, arch=False)
    for x in (-width / 2 - 0.03, width / 2 + 0.03):
        for y in (-2.0, 2.0):
            opening("hoarding_loophole", (x, y, 0.9), 0.32, 0.6,
                    -math.pi / 2 if x < 0 else math.pi / 2, arch=False)
    hip_roof("hoarding_roof", (0, 0, 2.0), width + 0.8, depth + 0.8, 0.9, "castle_shingle")


def rubble_stone():
    """Heap of broken masonry left where a stone part came down."""
    blocks = [(-2.2, -0.6, 0.45, 1.6, 1.1, 0.9, 12), (-0.6, 0.4, 0.55, 1.9, 1.3, 1.1, -20),
              (1.2, -0.3, 0.4, 1.5, 1.2, 0.8, 35), (2.6, 0.5, 0.3, 1.1, 0.9, 0.6, -8),
              (0.2, -0.9, 1.2, 1.3, 0.9, 0.7, 50), (-1.4, 0.2, 1.3, 1.2, 1.0, 0.7, -35),
              (0.9, 0.6, 1.1, 1.0, 0.8, 0.6, 15)]
    for x, y, z, sx, sy, sz, yaw in blocks:
        block = box("rubble_block", (x, y, z), (sx, sy, sz), "castle_stone")
        block.rotation_euler = (math.radians(yaw * 0.3), math.radians(-yaw * 0.2),
                                math.radians(yaw))
    for x, y in ((-2.8, 0.9), (3.0, -0.8), (-0.2, 1.3), (1.8, -1.2)):
        ico("rubble_chunk", (x, y, 0.3), (0.45, 0.4, 0.3), "castle_stone_light")
    cone("rubble_dust", (0, 0, 0.12), 3.6, 0.24, "castle_earth", 3.2, 12)


def rubble_wood():
    """Charred beams and planks left where a wooden part burnt or fell."""
    beams = [((-2.6, -0.8, 0.2), (2.2, 0.6, 0.5)), ((-2.0, 0.9, 0.3), (2.4, -0.5, 0.2)),
             ((-0.4, -1.4, 0.2), (0.8, 1.5, 0.9)), ((1.4, -1.0, 0.25), (2.9, 1.1, 0.25)),
             ((-2.9, 0.1, 0.6), (-0.6, 0.4, 1.1))]
    for i, (start, end) in enumerate(beams):
        beam("charred_beam", start, end, 0.18, "castle_dark" if i % 2 else "castle_timber",
             vertices=5)
    for x, y in ((-1.2, -0.2), (0.9, 0.3)):
        plank = box("charred_plank", (x, y, 0.1), (1.6, 0.5, 0.12), "castle_wood")
        plank.rotation_euler.z = math.radians(25 * x)
    cone("ash", (0, 0, 0.06), 3.2, 0.12, "castle_dark", 2.9, 12)


def stone():
    """Trebuchet stone, 0.8 m across."""
    ico("stone", (0, 0, 0.4), (0.42, 0.4, 0.38), "castle_rock", subdivisions=1)


def fire_pot():
    """Clay fire pot with a rope sling and a stopper rag, 0.7 m tall."""
    sphere("pot_body", (0, 0, 0.3), (0.3, 0.3, 0.28), "castle_roof_tile", smooth=False,
           segments=10, rings=6)
    cone("pot_neck", (0, 0, 0.6), 0.14, 0.14, "castle_roof_tile", 0.11, 10)
    cone("pot_rag", (0, 0, 0.72), 0.12, 0.14, "castle_linen", 0.0, 6)
    for angle in (0.0, math.pi / 2):
        ring = cone("pot_rope", (0, 0, 0.3), 0.31, 0.06, "castle_timber", 0.31, 10)
        ring.rotation_euler = (math.pi / 2, 0.0, angle)


PIECES = {
    "siege_palisade": palisade,
    "siege_palisade_gate": palisade_gate,
    "siege_wall": wall_segment,
    "siege_wall_tower": wall_tower,
    "siege_hoarding": hoarding,
    "siege_rubble_stone": rubble_stone,
    "siege_rubble_wood": rubble_wood,
    "siege_stone": stone,
    "siege_fire_pot": fire_pot,
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
    size = [round(max(c[axis] for c in corners) - min(c[axis] for c in corners), 2)
            for axis in range(3)]
    materials = sorted({slot.material.name for slot in obj.material_slots if slot.material})
    print("ASSET", name, triangles, size, flush=True)
    return {"file": name + ".glb", "triangles": triangles, "budget": BUDGET,
            "dimensions_blender": size, "materials": materials}


def main():
    bpy.context.preferences.filepaths.save_version = 0
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = [arg for arg in args if arg in PIECES] or list(PIECES)
    entries = [export_piece(name, PIECES[name]) for name in names]
    path = SOURCE / "siege_kit_manifest.json"
    previous = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    fresh = {entry["file"] for entry in entries}
    merged = sorted(entries + [e for e in previous if e["file"] not in fresh],
                    key=lambda e: e["file"])
    path.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    over = [entry for entry in entries if entry["triangles"] > entry["budget"]]
    if over:
        raise RuntimeError("over the triangle budget: " + ", ".join(
            f"{e['file']} {e['triangles']}" for e in over))
    print("BUILT", len(entries), "siege pieces", flush=True)


if __name__ == "__main__":
    main()
