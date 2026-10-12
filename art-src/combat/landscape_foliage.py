import math
import random

from mathutils import Vector

from model_primitives import PALETTE, material, mesh


PALETTE.update({
    "bark_shadow": (0.27, 0.14, 0.053), "bark_warm": (0.36, 0.20, 0.081),
    "bark_lit": (0.43, 0.26, 0.12), "birch_bark": (0.77, 0.74, 0.59),
    "oak_shadow": (0.055, 0.17, 0.027), "oak_mid": (0.13, 0.29, 0.038),
    "oak_lit": (0.25, 0.40, 0.061), "oak_tip": (0.33, 0.47, 0.086),
    "birch_shadow": (0.10, 0.23, 0.028), "birch_mid": (0.23, 0.37, 0.045),
    "birch_lit": (0.38, 0.49, 0.070), "birch_tip": (0.46, 0.55, 0.11),
    "autumn_shadow": (0.23, 0.095, 0.020), "autumn_mid": (0.48, 0.23, 0.025),
    "autumn_lit": (0.64, 0.38, 0.043), "autumn_tip": (0.74, 0.48, 0.076),
    "pine_shadow": (0.025, 0.12, 0.057), "pine_mid": (0.047, 0.22, 0.11),
    "pine_lit": (0.085, 0.31, 0.16), "pine_tip": (0.15, 0.38, 0.18),
    "rock_shadow": (0.20, 0.20, 0.16), "rock_mid": (0.32, 0.31, 0.25),
    "rock_lit": (0.46, 0.44, 0.34), "rock_warm": (0.40, 0.36, 0.27),
})


def tinted_mesh(name, vertices, faces, colors, indices, smooth=False):
    obj = mesh(name, vertices, faces, colors[0])
    for color in colors[1:]:
        obj.data.materials.append(material(color))
    for polygon, index in zip(obj.data.polygons, indices):
        polygon.material_index = index
        polygon.use_smooth = smooth
    return obj


def branch(name, points, radii, birch=False):
    vertices, faces, colors = [], [], []
    sides = 9
    for row, point in enumerate(points):
        center = Vector(point)
        tangent = Vector(points[min(row + 1, len(points) - 1)]) - Vector(points[max(0, row - 1)])
        axis = tangent.normalized()
        cross = axis.cross(Vector((0, 1, 0))).normalized()
        side = axis.cross(cross)
        for i in range(sides):
            angle = i * math.tau / sides
            radius = radii[row] * (1.0 + math.sin(i * 2.2 + row) * 0.08)
            vertices.append(center + (cross * math.cos(angle) + side * math.sin(angle)) * radius)
    for row in range(len(points) - 1):
        for i in range(sides):
            faces.append((row * sides + i, row * sides + (i + 1) % sides,
                          (row + 1) * sides + (i + 1) % sides, (row + 1) * sides + i))
            colors.append(0 if birch else (i % 3 if i % 3 != 0 else 1))
    faces += [tuple(reversed(range(sides))), tuple(range((len(points) - 1) * sides, len(points) * sides))]
    colors += [0, 1]
    palette = ("birch_bark", "bark_shadow", "bark_warm") if birch else (
        "bark_shadow", "bark_warm", "bark_lit")
    return tinted_mesh(name, vertices, faces, palette, colors, smooth=True)


def leaf_geometry(center, direction, width, length, tilt=0.25, roll=0.0):
    forward = Vector((math.cos(direction), math.sin(direction), tilt)).normalized() * length
    across = Vector((-math.sin(direction) * math.cos(roll), math.cos(direction) * math.cos(roll),
                     math.sin(roll))) * width
    outline = [(-0.85, 0), (-0.67, -0.47), (-0.20, -0.72), (0.48, -0.52),
               (0.92, 0), (0.48, 0.52), (-0.20, 0.72), (-0.67, 0.47)]
    origin = Vector(center)
    vertices = [origin + forward * x + across * y for x, y in outline]
    vertices += [origin + Vector((0, 0, length * 0.13)), origin - Vector((0, 0, length * 0.065))]
    faces = []
    for i in range(8):
        faces.extend([(8, i, (i + 1) % 8), (9, (i + 1) % 8, i)])
    return vertices, faces


def leafy_crown(name, center, radius, palette, rng, count=24):
    vertices, faces, colors = [], [], []
    # The deep lobes fill the crown; the overlapping leaf rims give it a leafy silhouette.
    for row, (z, span) in enumerate(((-0.62, 0.36), (-0.35, 0.86), (0.08, 1.0), (0.58, 0.58))):
        for i in range(11):
            angle = i * math.tau / 11
            reach = span * rng.uniform(0.90, 1.07)
            vertices.append((center[0] + math.cos(angle) * radius[0] * reach,
                             center[1] + math.sin(angle) * radius[1] * reach,
                             center[2] + (z + rng.uniform(-0.07, 0.07)) * radius[2]))
    vertices.append((center[0] + 0.06, center[1] - 0.08, center[2] + radius[2] * 0.78))
    for row in range(3):
        for i in range(11):
            faces.append((row * 11 + i, row * 11 + (i + 1) % 11,
                          (row + 1) * 11 + (i + 1) % 11, (row + 1) * 11 + i))
            colors.append(0 if row == 0 else 1 if row == 1 else 2)
    for i in range(11):
        faces.append((33 + i, 33 + (i + 1) % 11, 44))
        colors.append(2)
    faces.append(tuple(reversed(range(11))))
    colors.append(0)
    for i in range(count):
        angle = i * 2.39996 + rng.uniform(-0.18, 0.18)
        elevation = -0.15 + 1.30 * ((i + 0.5) / count)
        horizontal = math.sqrt(max(0.03, 1.0 - elevation * elevation * 0.72))
        point = (center[0] + math.cos(angle) * radius[0] * horizontal,
                 center[1] + math.sin(angle) * radius[1] * horizontal,
                 center[2] + elevation * radius[2] * 0.73)
        length = rng.uniform(0.20, 0.29)
        leaf, polygons = leaf_geometry(point, angle + rng.uniform(-0.45, 0.45),
                                        length * 0.75, length, tilt=rng.uniform(-0.35, 0.65),
                                        roll=rng.uniform(-0.60, 0.60))
        offset = len(vertices)
        vertices.extend(leaf)
        faces.extend(tuple(v + offset for v in polygon) for polygon in polygons)
        color = 1 if elevation < 0.15 else 2 if i % 4 else 3
        colors.extend([color] * len(polygons))
    return tinted_mesh(name, vertices, faces, palette, colors, smooth=True)


def deciduous_tree(kind):
    rng = random.Random(kind)
    birch = kind == "birch"
    palette = tuple(("birch" if birch else "autumn" if kind == "oak_autumn" else "oak") + "_" + shade
                    for shade in ("shadow", "mid", "lit", "tip"))
    trunk = [(0, 0, 0), (0.05, -0.05, 0.72), (-0.08, 0.04, 1.48),
             (0.08, 0.06, 2.13), (0.20, -0.04, 2.77), (0.12, 0.01, 3.36)]
    if birch:
        trunk = [(x * 0.6, y, z * 1.16) for x, y, z in trunk]
    branch("branching_trunk", trunk, [0.29, 0.21, 0.17, 0.13, 0.08, 0.028], birch)
    for i in range(7):
        angle = i * math.tau / 7 + 0.2
        branch("flared_root", [(0, 0, 0.28), (math.cos(angle) * 0.29, math.sin(angle) * 0.29, 0.13),
                               (math.cos(angle) * 0.68, math.sin(angle) * 0.68, 0.015)],
               [0.115, 0.095, 0.015], birch)
    for i in range(13):
        angle = i * 2.39996
        upper = i > 8
        reach = rng.uniform(0.62, 1.19) * (0.63 if upper else 1.0) * (0.83 if birch else 1.0)
        z = rng.uniform(2.65, 3.28) + (0.56 if upper else 0) + (0.30 if birch else 0)
        end = (math.cos(angle) * reach, math.sin(angle) * reach, z)
        start = trunk[2 if i < 5 else 3]
        middle = (end[0] * 0.50 + start[0], end[1] * 0.50 + start[1], z - 0.46)
        branch("forking_limb", [start, middle, end], [0.105, 0.060, 0.015], birch)
        crown_radius = (0.69 if birch else 0.79, 0.72 if birch else 0.79, 0.65)
        leafy_crown("layered_leaf_spray", end, crown_radius, palette, rng, 38)
    if birch:
        for i in range(14):
            z = 0.32 + i * 0.21
            point = (0.05 * math.sin(i), -0.168 + z * 0.025, z)
            vertices = [(point[0] - 0.09, point[1], z), (point[0] + 0.07, point[1], z + 0.012),
                        (point[0] + 0.075, point[1], z + 0.034), (point[0] - 0.07, point[1], z + 0.023)]
            mesh("birch_bark_notch", vertices, [(0, 1, 2, 3), (3, 2, 1, 0)], "bark_shadow")


def pine_fan(center, angle, length, width, palette, rng):
    forward, across = Vector((math.cos(angle), math.sin(angle), 0)), Vector((-math.sin(angle), math.cos(angle), 0))
    vertices, faces, colors = [], [], []
    outline = [(0, 0), (0.12, -0.48), (0.30, -0.31), (0.36, -0.77), (0.55, -0.44),
               (0.65, -0.58), (1.06, 0), (0.65, 0.58), (0.55, 0.44), (0.36, 0.77),
               (0.30, 0.31), (0.12, 0.48)]
    for x, y in outline:
        point = Vector(center) + forward * x * length + across * y * width
        point.z += math.sin(x * math.pi) * 0.10 - x * 0.15 + rng.uniform(-0.025, 0.025)
        vertices.append(point)
    vertices += [Vector(center) + forward * length * 0.43 + Vector((0, 0, 0.12)),
                 Vector(center) + forward * length * 0.45 - Vector((0, 0, 0.07))]
    for i in range(12):
        faces += [(12, i, (i + 1) % 12), (13, (i + 1) % 12, i)]
        colors += [2 if i % 4 else 1, 0]
    for i in range(4):
        offset = 0.19 + i * 0.11
        side = -1 if i % 2 else 1
        point = Vector(center) + forward * length * offset + across * width * 0.37 * side
        point.z += 0.06 - offset * 0.11
        leaf, polygons = leaf_geometry(point, angle + side * 0.73, width * 0.17, length * 0.24, -0.10)
        base = len(vertices)
        vertices.extend(leaf)
        faces.extend(tuple(v + base for v in polygon) for polygon in polygons)
        colors.extend([2 if i % 3 else 3] * len(polygons))
    tinted_mesh("layered_pine_bough", vertices, faces, palette, colors, smooth=True)


def pine_tree():
    rng = random.Random("pine")
    palette = tuple("pine_" + shade for shade in ("shadow", "mid", "lit", "tip"))
    branch("pine_trunk", [(0, 0, 0), (0.04, 0.02, 1.0), (-0.04, 0.03, 2.6), (0.08, 0, 4.53)],
           [0.24, 0.15, 0.10, 0.013])
    for i in range(6):
        angle = i * math.tau / 6
        branch("pine_root", [(0, 0, 0.22), (math.cos(angle) * 0.55, math.sin(angle) * 0.55, 0.01)],
               [0.10, 0.016])
    for tier in range(7):
        z = 1.02 + tier * 0.48
        reach = (1.62 - tier * 0.19) * (0.90 if tier == 0 else 1.0)
        count = 9 if tier < 3 else 7 if tier < 5 else 5
        for i in range(count):
            angle = i * math.tau / count + tier * 0.74 + rng.uniform(-0.10, 0.10)
            extent = reach * rng.uniform(0.84, 1.08)
            end = (math.cos(angle) * extent, math.sin(angle) * extent, z - 0.22)
            middle = (end[0] * 0.52, end[1] * 0.52, z + 0.03)
            branch("pine_limb", [(0, 0, z), middle, end], [0.032, 0.022, 0.005])
            pine_fan((end[0] * 0.12, end[1] * 0.12, z + 0.03), angle, extent * 0.65,
                     extent * 0.47, palette, rng)
            pine_fan((end[0] * 0.45, end[1] * 0.45, z + 0.12), angle + 0.16, extent * 0.56,
                     extent * 0.36, palette, rng)
    pine_fan((0.06, 0.0, 4.04), 0.7, 0.16, 0.26, palette, rng)
    for i in range(5):
        vertices, faces = leaf_geometry((0.05, 0, 4.35), i * math.tau / 5, 0.12, 0.45, 3.2)
        tinted_mesh("terminal_needle_spray", vertices, faces, palette, [2] * len(faces))


def weathered_stone(center, scale, rng, moss=True):
    vertices, faces, colors = [], [], []
    levels = ((-0.02, 0.73), (0.18, 1.0), (0.61, 0.86), (0.92, 0.42))
    for row, (z, radius) in enumerate(levels):
        for i in range(8):
            angle = i * math.tau / 8 + (0.10 if row == 2 else 0)
            reach = radius * rng.uniform(0.80, 1.12)
            vertices.append((center[0] + math.cos(angle) * scale[0] * reach,
                             center[1] + math.sin(angle) * scale[1] * reach,
                             center[2] + (z + rng.uniform(-0.04, 0.04)) * scale[2]))
    for row in range(3):
        for i in range(8):
            a, b, c, d = row * 8 + i, row * 8 + (i + 1) % 8, (row + 1) * 8 + (i + 1) % 8, (row + 1) * 8 + i
            faces += [(a, b, c), (a, c, d)] if (row + i) % 3 == 0 else [(a, b, c, d)]
            shade = 0 if row == 0 else 2 if row == 2 else 3 if i % 3 == 0 else 1
            colors.extend([shade] * (2 if (row + i) % 3 == 0 else 1))
    faces += [tuple(range(24, 32)), tuple(reversed(range(8)))]
    colors += [2, 0]
    obj = tinted_mesh("weathered_stone", vertices, faces,
                      ("rock_shadow", "rock_mid", "rock_lit", "rock_warm"), colors)
    if moss:
        leafy_crown("creeping_moss", (center[0] - scale[0] * 0.19, center[1] + scale[1] * 0.14,
                                     center[2] + scale[2] * 0.88),
                    (scale[0] * 0.40, scale[1] * 0.36, 0.042),
                    ("oak_shadow", "oak_mid", "oak_lit", "oak_tip"), rng, 6)
    return obj
