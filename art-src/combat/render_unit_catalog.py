"""Review render: every unit tinted for two houses with its crest mounted, plus the four crests (shown 2x)."""
import math

import bpy
from mathutils import Matrix, Vector

from model_primitives import clear_scene
from unit_palette import linear

# Render-only tints; the exported masks stay white.
HOUSES = (("welfen", "b0302a", "d9a82e", "crest_lion"), ("wittelsbacher", "2f62b0", "d8dde2", "crest_wings"))
ROLES = ("levy", "spearman", "crossbowman", "brabanter", "knight", "leader", "trebuchet")
SPACING, ROW_DEPTH, CREST_SCALE = 2.7, 4.6, 2.0


def _import(path, offset, scale=1.0, turn=0.0):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added = [obj for obj in bpy.context.scene.objects if obj not in before]
    for obj in added:
        if obj.type == "ARMATURE" and obj.animation_data:
            obj.animation_data.action = None
            for track in list(obj.animation_data.nla_tracks):
                obj.animation_data.nla_tracks.remove(track)
            for bone in obj.pose.bones:
                bone.matrix_basis.identity()
        if obj.parent is None:
            obj.matrix_world = (Matrix.Translation(offset) @ Matrix.Rotation(turn, 4, "Z")
                                @ Matrix.Scale(scale, 4) @ obj.matrix_world)
    return added


def _tint(objects, primary, secondary):
    for obj in objects:
        if obj.type != "MESH":
            continue
        for slot in obj.material_slots:
            name = slot.material.name if slot.material else ""
            color = primary if name.startswith("house_primary") else secondary if name.startswith("house_secondary") \
                else None
            if color:
                slot.material = slot.material.copy()
                slot.material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*linear(color), 1)


def make_catalog(source, output):
    clear_scene()
    scene = bpy.context.scene
    scene.world.color = (0.20, 0.20, 0.19)
    for row, (_, primary, secondary, crest) in enumerate(HOUSES):
        for col, role in enumerate(ROLES):
            side_view = role == "trebuchet"
            offset = Vector(((col - 3) * SPACING + (1.0 if side_view else 0.0), row * ROW_DEPTH, 0))
            added = _import(output / f"unit_{role}.glb", offset, turn=math.pi / 2 if side_view else 0.0)
            _tint(added, primary, secondary)
            anchor = next((obj for obj in added if obj.name.startswith("crest_anchor")), None)
            if anchor:
                bpy.context.view_layer.update()
                _import(output / f"{crest}.glb", anchor.matrix_world.translation)
    for i, crest in enumerate(("crest_lion", "crest_eagle", "crest_antlers", "crest_wings")):
        _import(output / f"{crest}.glb", ((i - 1.5) * 2.4, -3.2, 0), CREST_SCALE)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -0.01))
    floor = bpy.context.object
    floor.data.materials.append(bpy.data.materials.new("catalog_floor"))
    floor.data.materials[0].diffuse_color = (*linear("6d7350"), 1)
    floor.data.materials[0].use_nodes = True
    floor.data.materials[0].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = \
        (*linear("6d7350"), 1)
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 12))
    sun = bpy.context.object
    sun.rotation_euler = (0.75, -0.35, -0.5)
    sun.data.energy = 3.2
    sun.data.angle = 0.2
    bpy.ops.object.light_add(type="AREA", location=(-4, -12, 10))
    fill = bpy.context.object
    fill.rotation_euler = (Vector((0, 2, 1)) - fill.location).to_track_quat("-Z", "Y").to_euler()
    fill.data.energy = 1800
    fill.data.size = 14
    bpy.ops.object.camera_add(location=(0.9, -23.2, 17))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0.9, 2.0, 1.0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 20
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = 1800, 1200
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(source / "combat_asset_catalog.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(source / "combat_asset_catalog.blend"), compress=True)
    bpy.ops.render.render(write_still=True)
