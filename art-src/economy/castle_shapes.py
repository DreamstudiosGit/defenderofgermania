"""Building blocks of the castle kit: roofs, merlons, towers, openings, flags, half-timbering.
Blender coordinates: Z up, front (towards the default camera) is -Y; metres."""
import math
from contextlib import contextmanager

import bpy
from mathutils import Matrix, Vector

import castle_palette  # noqa: F401  registers the castle palette
from model_primitives import beam, box, cone, mesh, plate, sphere

PRIMARY = "house_primary"
SECONDARY = "house_secondary"


@contextmanager
def placed(at=(0.0, 0.0, 0.0), yaw=0.0):
    """Moves everything built inside the block: rotation about Z (radians), then translation."""
    before = set(bpy.context.scene.objects)
    yield
    matrix = Matrix.Translation(Vector(at)) @ Matrix.Rotation(yaw, 4, "Z")
    for obj in bpy.context.scene.objects:
        if obj not in before:
            obj.matrix_world = matrix @ obj.matrix_world


def ring_points(radius_x, radius_y, count, start=0.0, center=(0.0, 0.0)):
    return [(center[0] + math.cos(start + i * math.tau / count) * radius_x,
             center[1] + math.sin(start + i * math.tau / count) * radius_y) for i in range(count)]


def gable_roof(name, center, length, depth, height, color, axis="x"):
    """Prism roof standing on z = center[2]; the ridge runs along `axis`."""
    x, y, z = center
    if axis == "x":
        a, b = length / 2, depth / 2
        verts = [(x - a, y - b, z), (x + a, y - b, z), (x + a, y + b, z), (x - a, y + b, z),
                 (x - a, y, z + height), (x + a, y, z + height)]
    else:
        a, b = depth / 2, length / 2
        verts = [(x - a, y + b, z), (x - a, y - b, z), (x + a, y - b, z), (x + a, y + b, z),
                 (x, y + b, z + height), (x, y - b, z + height)]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (3, 2, 1, 0)]
    return mesh(name, verts, faces, color)


def hip_roof(name, center, length, depth, height, color):
    """Hipped roof over a length (X) x depth (Y) rectangle; a pyramid when both are equal."""
    x, y, z = center
    ridge = max(0.0, (length - depth) / 2)
    verts = [(x - length / 2, y - depth / 2, z), (x + length / 2, y - depth / 2, z),
             (x + length / 2, y + depth / 2, z), (x - length / 2, y + depth / 2, z),
             (x - ridge, y, z + height), (x + ridge, y, z + height)]
    faces = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (3, 2, 1, 0)]
    return mesh(name, verts, faces, color)


def spire(name, center, radius, height, color, vertices=8):
    return cone(name, (center[0], center[1], center[2] + height / 2), radius, height, color,
                vertices=vertices)


def merlons_line(start, end, z, color, size=(0.8, 0.6, 0.9), spacing=1.7):
    start, end = Vector(start), Vector(end)
    direction = end - start
    count = max(1, int(direction.length / spacing))
    angle = math.atan2(direction.y, direction.x)
    for i in range(count):
        at = start + direction * ((i + 0.5) / count)
        merlon = box("merlon", (at.x, at.y, z + size[2] / 2), size, color)
        merlon.rotation_euler.z = angle


def merlons_ring(center, radius, z, count, color, size=(0.75, 0.55, 0.85)):
    for i in range(count):
        angle = i * math.tau / count
        merlon = box("merlon", (center[0] + math.cos(angle) * radius,
                                center[1] + math.sin(angle) * radius, z + size[2] / 2), size, color)
        merlon.rotation_euler.z = angle + math.pi / 2


def round_tower(center, radius, height, color, merlons=8, vertices=10, top=None):
    x, y = center
    # The body stops short of the corbel's top so the two never share a (flickering) face.
    cone("tower", (x, y, (height - 0.05) / 2), radius, height - 0.05, color, radius, vertices)
    cone("tower_corbel", (x, y, height - 0.35), radius + 0.3, 0.7, top or color, radius + 0.3,
         vertices)
    if merlons:
        merlons_ring(center, radius + 0.05, height, merlons, top or color)


def square_tower(center, size, height, color, merlons=True, top=None):
    x, y = center
    box("tower", (x, y, height / 2), (size, size, height), color)
    if merlons:
        half = size / 2 - 0.25
        for sx, sy, ex, ey in ((-1, -1, 1, -1), (1, -1, 1, 1), (1, 1, -1, 1), (-1, 1, -1, -1)):
            merlons_line((x + sx * half, y + sy * half), (x + ex * half, y + ey * half), height,
                         top or color, (0.6, 0.5, 0.8), 1.4)


def wall(start, end, height, thickness, color, top=None, merlons=True):
    start, end = Vector(start), Vector(end)
    direction = end - start
    middle = (start + end) / 2
    body = box("wall", (middle.x, middle.y, height / 2), (direction.length, thickness, height), color)
    body.rotation_euler.z = math.atan2(direction.y, direction.x)
    if merlons:
        normal = Vector((-direction.y, direction.x)).normalized() * (thickness / 2 - 0.3)
        merlons_line(start - normal, end - normal, height, top or color)
    return body


def opening(name, at, width, height, yaw=0.0, depth=0.12, color="castle_dark", arch=True):
    """Dark window or door on a wall facing -Y (before yaw); `at` is its bottom centre."""
    outline = [(-width / 2, 0.0), (width / 2, 0.0), (width / 2, height - (width / 2 if arch else 0))]
    if arch:
        outline += [(math.cos(i * math.pi / 4) * width / 2,
                     height - width / 2 + math.sin(i * math.pi / 4) * width / 2) for i in range(1, 4)]
    outline.append((-width / 2, height - (width / 2 if arch else 0)))
    with placed(at, yaw):
        # plate() wants the outline clockwise as seen from the front.
        plate(name, list(reversed(outline)), 0.0, depth, color)


def flag(at, pole_height, width, height, yaw=0.0, color=PRIMARY, band=SECONDARY):
    """Pole with a flag flying towards +X (before yaw); `at` is the pole foot."""
    with placed(at, yaw):
        beam("flag_pole", (0, 0, 0), (0, 0, pole_height), 0.07, "castle_timber", vertices=6)
        sphere("flag_finial", (0, 0, pole_height + 0.12), (0.14, 0.14, 0.14), "castle_gold",
               segments=6, rings=4)
        top = pole_height - 0.15
        plate("flag_cloth", [(0.05, top), (width, top - 0.15), (width * 0.82, top - height / 2),
                             (width, top - height + 0.1), (0.05, top - height)], 0.0, 0.05, color)
        plate("flag_band", [(0.05, top - height * 0.42), (width * 0.9, top - height * 0.47),
                            (width * 0.88, top - height * 0.6), (0.05, top - height * 0.58)],
              0.0, 0.07, band)


def half_timber(center, length, depth, z0, z1, posts=1.6):
    """Plaster box with a timber frame (posts, sills, braces in the end panels) on all faces."""
    x, y = center
    middle, tall = (z0 + z1) / 2, z1 - z0
    box("plaster", (x, y, middle), (length, depth, tall), "castle_plaster")
    for z in (z0 + 0.1, z1 - 0.1):
        box("sill", (x, y, z), (length + 0.12, depth + 0.12, 0.2), "castle_timber")
    for along_x, span, across in ((True, length, depth), (False, depth, length)):
        count = max(1, round(span / posts))
        for sign in (-1, 1):
            face = (y if along_x else x) + sign * (across / 2 + 0.03)

            def point(offset, z, face=face):
                return (x + offset, face, z) if along_x else (face, y + offset, z)

            for i in range(count + 1):
                offset = -span / 2 + span * i / count
                size = (0.18, 0.1, tall) if along_x else (0.1, 0.18, tall)
                box("post", point(offset, middle), size, "castle_timber")
            if count >= 2:
                first, last = -span / 2, span / 2
                panel = span / count
                beam("brace", point(first + panel, z0 + 0.2), point(first, z1 - 0.2), 0.07,
                     "castle_timber", vertices=4)
                beam("brace", point(last - panel, z0 + 0.2), point(last, z1 - 0.2), 0.07,
                     "castle_timber", vertices=4)


def chimney(at, height, color="castle_stone"):
    box("chimney", (at[0], at[1], at[2] + height / 2), (0.7, 0.7, height), color)
    box("chimney_cap", (at[0], at[1], at[2] + height + 0.06), (0.9, 0.9, 0.12), "castle_stone_dark")


def door(at, width=1.2, height=2.1, yaw=0.0):
    opening("door", at, width, height, yaw, 0.14, "castle_timber", arch=False)


def stairs(start, end, width, steps, color="castle_wood"):
    start, end = Vector(start), Vector(end)
    for i in range(steps):
        at = start.lerp(end, (i + 0.5) / steps)
        rise = (end.z - start.z) / steps
        step = box("step", (at.x, at.y, at.z - rise / 2), (width, (end - start).xy.length / steps + 0.05,
                                                             max(rise, 0.15)), color)
        step.rotation_euler.z = math.atan2(end.y - start.y, end.x - start.x) - math.pi / 2


def quoins(center, size, z0, z1, color="castle_stone_light", rows=None):
    """Light corner stones up the four corners of a square tower."""
    x, y = center
    rows = rows or max(2, int((z1 - z0) / 1.2))
    step = (z1 - z0) / rows
    for row in range(rows):
        long_x = row % 2 == 0
        for sx in (-1, 1):
            for sy in (-1, 1):
                width = (1.1, 0.55) if long_x else (0.55, 1.1)
                box("quoin", (x + sx * (size / 2 - width[0] / 2 + 0.05),
                              y + sy * (size / 2 - width[1] / 2 + 0.05), z0 + step * (row + 0.5)),
                    (width[0], width[1], step * 0.8), color)
