"""Exports the house-neutral units and the crests (glTF + editable .blend) and reports manifest entries."""
import bpy

import unit_palette  # noqa: F401  registers the unit palette and house masks
from model_crests import CRESTS
from model_primitives import clear_scene, join_meshes
from unit_roles import ROLE_BUILDERS
from unit_trebuchet import trebuchet_unit

UNIT_ROLES = ("levy", "spearman", "crossbowman", "brabanter", "knight", "leader", "trebuchet")
BUDGETS = {"leader": 6000}
SOLDIER_BUDGET = 3000
CREST_BUDGET = 300


def _reset():
    clear_scene()
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


def _export(name, source, output, animated):
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start, scene.frame_end = 1, 49
    bpy.ops.object.select_all(action="DESELECT")
    for obj in scene.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(o for o in scene.objects if o.type == "MESH")
    bpy.ops.wm.save_as_mainfile(filepath=str(source / (name + ".blend")), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output / (name + ".glb")), export_format="GLB", use_selection=True, export_yup=True,
        export_texcoords=True, export_normals=True, export_materials="EXPORT", export_extras=True,
        export_animations=animated, export_animation_mode="ACTIONS", export_merge_animation="NLA_TRACK",
        export_anim_slide_to_zero=True, export_frame_range=False)
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    corners = [obj.matrix_world @ vertex.co for obj in meshes for vertex in obj.data.vertices]
    size = [round(max(c[axis] for c in corners) - min(c[axis] for c in corners), 3) for axis in range(3)]
    materials = sorted({slot.material.name for obj in meshes for slot in obj.material_slots if slot.material})
    print("ASSET", name, triangles, size, flush=True)
    return {"file": name + ".glb", "triangles": triangles, "dimensions_blender": size, "materials": materials}


def export_unit(role, source, output):
    _reset()
    anchor = (trebuchet_unit if role == "trebuchet" else ROLE_BUILDERS[role])(role)
    entry = _export(f"unit_{role}", source, output, True)
    rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    animations = []
    for rig in rigs:
        for track in rig.animation_data.nla_tracks:
            if track.name not in animations:
                animations.append(track.name)
    entry.update({"budget": BUDGETS.get(role, SOLDIER_BUDGET), "animations": animations,
                  "rigs": sorted(rig.name for rig in rigs),
                  "crest_anchor_height": round(anchor.location.z, 3) if anchor else None})
    return entry


def export_crest(name, source, output):
    _reset()
    CRESTS[name]()
    join_meshes(name)
    entry = _export(name, source, output, False)
    entry.update({"budget": CREST_BUDGET, "animations": []})
    return entry


def export_all(source, output):
    entries = [export_unit(role, source, output) for role in UNIT_ROLES]
    entries += [export_crest(name, source, output) for name in CRESTS]
    for entry in entries:
        if entry["triangles"] > entry["budget"]:
            raise RuntimeError(f"{entry['file']}: {entry['triangles']} triangles exceed {entry['budget']}")
    return entries
