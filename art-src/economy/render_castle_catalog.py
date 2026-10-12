"""Review renders built from the exports and data/castle_art.json (the same compositions the game
places): `economy_castle_catalog.png` shows the home castle levels 1-5 with every decoration
(back row) and the province castles 0-3 (front row); `economy_kit_catalog.png` shows every
building, settlement house, decoration and construction piece. House tints exist only here."""
import json
import math

import bpy
from mathutils import Matrix, Vector

from model_primitives import clear_scene
from unit_palette import linear

TINTS = {"house_primary": "b0202a", "house_secondary": "e0b040"}
GLASS_PREFIX = "castle_glass"
KIT_ROWS = (
    ("building_mill", "building_market_1", "building_market_2", "building_granary", "building_monastery",
     "building_mine", "building_toll", "building_workshop"),
    ("building_tourney_ground", "settlement_cottage", "settlement_house", "settlement_longhouse",
     "settlement_townhouse", "castle_wood_hall", "castle_palisade_small", "castle_wall_small"),
    ("castle_banner", "castle_pennant", "castle_tapestry", "castle_fountain", "castle_rose_garden",
     "castle_scaffold", "castle_crane", "castle_building_site", "castle_site_hut", "castle_chapel",
     "castle_stained_glass", "castle_palas", "castle_pfalz"),
)


def _import(path, at, yaw_deg=0.0, scale=1.0):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    added = [obj for obj in bpy.context.scene.objects if obj not in before]
    matrix = (Matrix.Translation(at) @ Matrix.Rotation(math.radians(yaw_deg), 4, "Z")
              @ Matrix.Scale(scale, 4))
    for obj in added:
        if obj.parent is None:
            obj.matrix_world = matrix @ obj.matrix_world
        if obj.type == "MESH":
            _tint(obj)
    return added


def _tint(obj):
    for slot in obj.material_slots:
        if slot.material is None:
            continue
        name = slot.material.name.split(".")[0]
        bsdf = slot.material.node_tree.nodes.get("Principled BSDF")
        if name in TINTS:
            slot.material = slot.material.copy()
            bsdf = slot.material.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (*linear(TINTS[name]), 1)
        elif name.startswith(GLASS_PREFIX) and bsdf:
            bsdf.inputs["Emission Color"].default_value = bsdf.inputs["Base Color"].default_value
            bsdf.inputs["Emission Strength"].default_value = 0.8


def _godot(at):
    return Vector((at[0], -at[2], at[1]))


def _place(output, entry, offset):
    _import(output / (entry["piece"] + ".glb"), _godot(entry["at"]) + offset, entry.get("yaw", 0.0),
            entry.get("scale", 1.0))


def _for_level(table, level):
    keys = sorted(int(key) for key in table if int(key) <= level)
    return table[str(keys[-1])] if keys else []


def _floor(size, color):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, -0.02))
    floor = bpy.context.object
    material = bpy.data.materials.new("catalog_floor")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*linear(color), 1)
    floor.data.materials.append(material)


def _render(path, camera_from, target, ortho, resolution):
    scene = bpy.context.scene
    scene.world.color = (0.32, 0.36, 0.40)
    bpy.ops.object.light_add(type="SUN", location=(0, 0, 50))
    sun = bpy.context.object
    sun.rotation_euler = (0.8, -0.3, -0.6)
    sun.data.energy = 3.6
    sun.data.angle = 0.15
    bpy.ops.object.camera_add(location=camera_from)
    camera = bpy.context.object
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = ortho
    camera.data.clip_end = 2000
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x, scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def castle_catalog(source, output, art):
    clear_scene()
    for level in range(1, 6):
        offset = Vector(((level - 3) * 64.0, 40.0, 0))
        for entry in art["home_castle"][str(level)]:
            _place(output, entry, offset)
        for table in art["decorations"].values():
            for entry in _for_level(table, level):
                _place(output, entry, offset)
    for level in range(0, 4):
        offset = Vector(((level - 1.5) * 64.0, -32.0, 0))
        for entry in art["province_castle"][str(level)]:
            _place(output, entry, offset)
    _floor(800, "7f9a48")
    _render(source / "economy_castle_catalog.png", (0, -260, 210), (0, 6, 4), 330, (2400, 1400))


def kit_catalog(source, output):
    clear_scene()
    y, right = 0.0, 0.0
    for row in KIT_ROWS:
        x, depth = 0.0, 0.0
        for name in row:
            before = set(bpy.context.scene.objects)
            _import(output / (name + ".glb"), Vector((0, 0, 0)))
            added = [obj for obj in bpy.context.scene.objects if obj not in before and obj.type == "MESH"]
            corners = [obj.matrix_world @ Vector(c) for obj in added for c in obj.bound_box]
            low = Vector([min(c[i] for c in corners) for i in range(3)])
            high = Vector([max(c[i] for c in corners) for i in range(3)])
            shift = Vector((x - low.x, y - (low.y + high.y) / 2, 0))
            for obj in added:
                if obj.parent is None:
                    obj.matrix_world = Matrix.Translation(shift) @ obj.matrix_world
            x += high.x - low.x + 3.0
            depth = max(depth, high.y - low.y)
        right = max(right, x)
        y -= depth + 6.0
    center = Vector((right / 2, y / 2, 0))
    _floor(900, "7f9a48")
    _render(source / "economy_kit_catalog.png", center + Vector((0, -150, 125)), center, right * 1.04,
            (2400, 1400))


def make_catalogs(source, output, art_path):
    art = json.loads(art_path.read_text(encoding="utf-8"))
    castle_catalog(source, output, art)
    kit_catalog(source, output)
