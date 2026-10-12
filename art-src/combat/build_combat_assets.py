import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
ROOT = SOURCE.parent.parent
sys.path.insert(0, str(SOURCE))
sys.dont_write_bytecode = True

from model_characters import horse, soldier, spear, trebuchet
from model_landscape import (
    bridge, camp, fern, ground, pebble_patch, river, riverbank, rock, tree, undergrowth, water_lilies
)
from model_primitives import clear_scene, join_meshes

OUTPUT = ROOT / "assets" / "combat"
ROLES = ("levy", "spearman", "crossbowman", "brabanter", "knight", "leader", "trebuchet")


def animate(obj, role):
    bpy.ops.object.select_all(action="DESELECT")
    data = bpy.data.armatures.new("unit_rig")
    rig = bpy.data.objects.new("unit_rig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = data.edit_bones.new("root")
    root.head, root.tail = (0, 0, 0), (0, 0, 1)
    for side, name in ((-1, "leg_left"), (1, "leg_right")):
        bone = data.edit_bones.new(name)
        bone.head = (side * 0.17, 0, 0.65)
        bone.tail = (side * 0.17, 0, 0.15)
        bone.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    modifier = obj.modifiers.new("unit_skin", "ARMATURE")
    modifier.object = rig
    obj.parent = rig
    for name in ("idle", "walk", "attack", "death"):
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data_create()
        rig.animation_data.action = action
        for frame in (1, 7, 13, 19, 25):
            phase = (frame - 1) / 24 * math.tau
            for bone in rig.pose.bones:
                bone.rotation_mode = "XYZ"
                bone.rotation_euler = (0, 0, 0)
                bone.location = (0, 0, 0)
                if name == "walk" and bone.name != "root":
                    bone.rotation_euler.x = math.sin(phase) * (0.34 if bone.name == "leg_left" else -0.34)
                if bone.name == "root":
                    if name == "idle":
                        bone.location.y = math.sin(phase) * 0.012
                    elif name == "walk":
                        bone.location.y = abs(math.sin(phase)) * 0.025
                    elif name == "attack":
                        bone.rotation_euler.x = math.sin(phase) * 0.10
                    elif name == "death":
                        bone.rotation_euler.x = min((frame - 1) / 18, 1) * math.pi / 2
                bone.keyframe_insert(data_path="rotation_euler", frame=frame)
                bone.keyframe_insert(data_path="location", frame=frame)
    rig.animation_data.action = bpy.data.actions.get("idle")
    bpy.context.scene.frame_set(1)
    return rig


def export_asset(name, build, role=None):
    clear_scene()
    build()
    obj = join_meshes(name)
    obj["front"] = "-Y in Blender, +Z in glTF/Godot"
    obj["units"] = "metres; ground-centred pivot"
    obj["stride_mask"] = "UV2.x weight; UV2.y limb phase; runtime GPU animation"
    rig = animate(obj, role) if role and role != "trebuchet" else None
    held_spear = None
    if role == "spearman":
        before = set(bpy.context.scene.objects)
        spear()
        held_spear = join_meshes("weapon_spear", list(set(bpy.context.scene.objects) - before))
        held_spear.location = (0.39, -0.23, 0.0)
        held_spear.parent = rig
        modifier = held_spear.modifiers.new("weapon_skin", "ARMATURE")
        modifier.object = rig
    bpy.context.scene.render.fps = 24
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 25
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    if rig:
        rig.select_set(True)
    if held_spear:
        held_spear.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")), compress=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT / (name + ".glb")), export_format="GLB",
        use_selection=True, export_yup=True, export_texcoords=True,
        export_normals=True, export_materials="EXPORT", export_animations=bool(rig),
        export_animation_mode="ACTIONS", export_extras=True,
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
            "dimensions_blender": size, "animations": ["idle", "walk", "attack", "death"] if rig else []}


def character(team, role):
    if role == "trebuchet":
        trebuchet(team)
    else:
        seated = role in ("knight", "leader")
        if seated:
            horse(team, role == "leader")
        soldier(team, role, seated)


def make_catalog():
    clear_scene()
    scene = bpy.context.scene
    scene.world.color = (0.22, 0.22, 0.22)
    for row, team in enumerate(("blue", "red")):
        for col, role in enumerate(ROLES):
            before = set(scene.objects)
            bpy.ops.import_scene.gltf(filepath=str(OUTPUT / f"unit_{role}_{team}.glb"))
            for obj in set(scene.objects) - before:
                if not obj.parent:
                    obj.location += Vector(((col - 3) * 3.2, row * 4.5, 0))
    for i, name in enumerate(("tree_oak", "tree_birch", "tree_pine", "rock_boulder",
                              "prop_watchtower_blue", "prop_tent_red", "prop_bridge_wood")):
        before = set(scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(OUTPUT / (name + ".glb")))
        for obj in set(scene.objects) - before:
            if not obj.parent:
                obj.location += Vector(((i - 3) * 3.2, 9, 0))
    bpy.ops.mesh.primitive_plane_add(size=200)
    floor = bpy.context.object
    floor.name = "catalog_floor"
    from model_primitives import material
    floor.data.materials.append(material("grass"))
    floor.location.z = -0.025
    bpy.ops.object.light_add(type="AREA", location=(0, -6, 14))
    key = bpy.context.object
    key.data.energy = 2200
    key.data.shape = "DISK"
    key.data.size = 12
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 12))
    bpy.context.object.rotation_euler = (0.4, -0.5, -0.3)
    bpy.context.object.data.energy = 2.2
    bpy.ops.object.camera_add(location=(11, -21, 19))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 4, 1)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 26
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(SOURCE / "combat_asset_catalog.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "combat_asset_catalog.blend"), compress=True)
    bpy.ops.render.render(write_still=True)


def main():
    bpy.context.preferences.filepaths.save_version = 0
    OUTPUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for team in ("blue", "red"):
        for role in ROLES:
            manifest.append(export_asset(f"unit_{role}_{team}", lambda t=team, r=role: character(t, r), role))
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
    (SOURCE / "combat_asset_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("BUILT", len(manifest), "assets", flush=True)
    make_catalog()


if __name__ == "__main__":
    main()
