import math

import bpy
from mathutils import Vector


PALETTE = {
    "steel": (0.42, 0.49, 0.56), "steel_light": (0.70, 0.76, 0.80),
    "mail": (0.24, 0.29, 0.34), "gold": (0.92, 0.60, 0.13),
    "skin": (0.93, 0.55, 0.28), "leather": (0.25, 0.105, 0.038),
    "wood": (0.38, 0.20, 0.075), "wood_light": (0.58, 0.34, 0.13),
    "blue": (0.025, 0.18, 0.68), "red": (0.66, 0.035, 0.055),
    "cream": (0.91, 0.85, 0.65), "white": (0.98, 0.95, 0.84),
    "black": (0.025, 0.022, 0.020), "horse": (0.49, 0.20, 0.065),
    "mane": (0.20, 0.07, 0.018), "leaf": (0.055, 0.19, 0.025),
    "leaf_light": (0.16, 0.32, 0.045), "pine": (0.018, 0.105, 0.05),
    "grass": (0.37, 0.47, 0.13), "earth": (0.48, 0.33, 0.16),
    "stone": (0.22, 0.21, 0.17), "stone_light": (0.33, 0.31, 0.24),
    "water": (0.025, 0.20, 0.27), "foam": (0.59, 0.82, 0.78),
    "flower": (0.63, 0.23, 0.53),
    "leaf_autumn": (0.32, 0.105, 0.018), "leaf_yellow": (0.43, 0.27, 0.03),
    "leaf_dark": (0.025, 0.09, 0.016), "water_deep": (0.018, 0.15, 0.27),
}
# Metallic, roughness per material name; everything else is matte (0, 0.78).
METALLIC = {"steel": (0.48, 0.52), "steel_light": (0.48, 0.52), "mail": (0.48, 0.52), "gold": (0.60, 0.36)}


def material(name):
    found = bpy.data.materials.get(name)
    if found:
        return found
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*PALETTE[name], 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Roughness"].default_value = 0.78
    if name in METALLIC:
        bsdf.inputs["Metallic"].default_value, bsdf.inputs["Roughness"].default_value = METALLIC[name]
    return mat


def finish(obj, name, color, motion=0, smooth=False):
    obj.name = name
    obj.data.materials.append(material(color))
    if not obj.data.uv_layers:
        obj.data.uv_layers.new(name="UVMap")
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for face in obj.data.polygons:
        face.use_smooth = smooth
    colors = obj.data.color_attributes.new(name="motion", type="FLOAT_COLOR", domain="POINT")
    # Red = stride weight; green = limb phase. These are data, not albedo colors.
    for value in colors.data:
        value.color = (abs(motion), 1.0 if motion > 0 else 0.0, 0.0, 1.0)
    group_name = "leg_left" if motion > 0 else "leg_right" if motion < 0 else "root"
    group = obj.vertex_groups.new(name=group_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def sphere(name, at, scale, color, motion=0, smooth=True, segments=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=at)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, color, motion, smooth)


def ico(name, at, scale, color, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, location=at)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, color)


def box(name, at, scale, color, bevel=0.0, motion=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.scale = scale
    finish(obj, name, color, motion)
    if bevel:
        modifier = obj.modifiers.new("soft_edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def cone(name, at, radius, depth, color, top=0.0, vertices=10):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=top, depth=depth, location=at
    )
    return finish(bpy.context.object, name, color)


def beam(name, start, end, radius, color, motion=0, vertices=8):
    direction = Vector(end) - Vector(start)
    obj = cone(name, (Vector(start) + Vector(end)) / 2, radius, direction.length,
               color, radius, vertices)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    if motion:
        for value in obj.data.color_attributes["motion"].data:
            value.color = (abs(motion), 1.0 if motion > 0 else 0.0, 0, 1)
        obj.vertex_groups.clear()
        group = obj.vertex_groups.new(name="leg_left" if motion > 0 else "leg_right")
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    return obj


def mesh(name, vertices, faces, color):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, color)


def plate(name, outline, y, thickness, color):
    count = len(outline)
    vertices = [(x, y + d, z) for d in (-thickness / 2, thickness / 2) for x, z in outline]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    return mesh(name, vertices, faces, color)


def emblem(x, y, z, scale, team):
    color = "gold" if team == "blue" else "white"
    if team == "red":
        box("cross_vertical", (x, y, z), (scale * 0.19, 0.015, scale), color)
        box("cross_horizontal", (x, y - 0.003, z + scale * 0.15),
            (scale * 0.65, 0.015, scale * 0.18), color)
    else:
        sphere("lily_center", (x, y, z + scale * 0.2),
               (scale * 0.12, 0.016, scale * 0.38), color)
        for side in (-1, 1):
            petal = sphere("lily_petal", (x + side * scale * 0.21, y, z + scale * 0.12),
                           (scale * 0.13, 0.015, scale * 0.24), color)
            petal.rotation_euler.y = side * -0.65
        box("lily_band", (x, y - 0.01, z - scale * 0.05),
            (scale * 0.57, 0.018, scale * 0.09), color)
        plate("lily_tail", [(x, z - scale * 0.4), (x - scale * 0.12, z - scale * 0.1),
                            (x + scale * 0.12, z - scale * 0.1)], y, 0.02, color)


def shield(x, y, z, team, scale=1.0):
    outline = [(-0.33, 0.44), (0.33, 0.44), (0.36, 0.03),
               (0.22, -0.32), (0, -0.55), (-0.22, -0.32), (-0.36, 0.03)]
    plate("shield_rim", [(x + a * scale, z + b * scale) for a, b in outline], y, 0.065, "steel_light")
    plate("shield_face", [(x + a * scale * 0.87, z + b * scale * 0.88) for a, b in outline],
          y - 0.038, 0.025, team)
    emblem(x, y - 0.061, z + 0.02 * scale, 0.62 * scale, team)
    for a, b in outline:
        sphere("shield_rivet", (x + a * scale * 0.94, y - 0.043, z + b * scale * 0.94),
               (0.022 * scale, 0.016, 0.022 * scale), "gold", segments=6, rings=4)


def join_meshes(name, objects=None):
    bpy.ops.object.select_all(action="DESELECT")
    if objects is None:
        objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    stride = joined.data.uv_layers.new(name="stride")
    colors = joined.data.color_attributes.get("motion")
    for loop in joined.data.loops:
        mask = colors.data[loop.vertex_index].color
        stride.data[loop.index].uv = (mask[0], mask[1])
    for attribute in list(joined.data.color_attributes):
        joined.data.color_attributes.remove(attribute)
    return joined


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
