import math

import bpy
from mathutils import Matrix, Vector

from model_primitives import box, mesh, plate, sphere


def rounded(name, at, scale, color, motion=0, segments=16, rings=8):
    return sphere(name, at, scale, color, motion, segments=segments, rings=rings)


def loft(name, sections, color, motion=0, segments=16, folds=0.0):
    vertices = []
    for z, rx, ry, cx, cy in sections:
        for i in range(segments):
            angle = i * math.tau / segments
            ripple = 1.0 + folds * math.cos(angle * 6)
            vertices.append((cx + rx * math.cos(angle) * ripple,
                             cy + ry * math.sin(angle) * ripple, z))
    faces = [tuple(reversed(range(segments)))]
    for row in range(len(sections) - 1):
        for i in range(segments):
            a, b = row * segments + i, row * segments + (i + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces.append(tuple(range(len(vertices) - segments, len(vertices))))
    obj = mesh(name, vertices, faces, color)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    if motion:
        for value in obj.data.color_attributes["motion"].data:
            value.color = (abs(motion), 1.0 if motion > 0 else 0.0, 0, 1)
        obj.vertex_groups.clear()
        group = obj.vertex_groups.new(name="leg_left" if motion > 0 else "leg_right")
        group.add(list(range(len(vertices))), 1.0, "REPLACE")
    return obj


def tube(name, points, radius, color, segments=8, steps=3, taper=1.0):
    controls = [Vector(p) for p in points]
    controls = [controls[0]] + controls + [controls[-1]]
    samples = []
    for i in range(1, len(controls) - 2):
        p0, p1, p2, p3 = controls[i - 1:i + 3]
        for j in range(steps):
            t = j / steps
            samples.append(0.5 * ((2 * p1) + (-p0 + p2) * t
                                  + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                  + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    samples.append(controls[-2])
    vertices = []
    for row, point in enumerate(samples):
        tangent = samples[min(row + 1, len(samples) - 1)] - samples[max(row - 1, 0)]
        tangent.normalize()
        reference = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
        normal = tangent.cross(reference).normalized()
        binormal = tangent.cross(normal).normalized()
        width = radius * (1 + (taper - 1) * row / (len(samples) - 1))
        for i in range(segments):
            angle = i * math.tau / segments
            vertices.append(point + width * (normal * math.cos(angle) + binormal * math.sin(angle)))
    faces = [tuple(reversed(range(segments)))]
    for row in range(len(samples) - 1):
        for i in range(segments):
            a, b = row * segments + i, row * segments + (i + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    faces.append(tuple(range(len(vertices) - segments, len(vertices))))
    obj = mesh(name, vertices, faces, color)
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return obj


def ellipse(name, centre, radius_x, radius_z, thickness, color, samples=20, segments=8):
    x, y, z = centre
    points = [(x + math.cos(i * math.tau / samples) * radius_x, y,
               z + math.sin(i * math.tau / samples) * radius_z) for i in range(samples + 1)]
    return tube(name, points, thickness, color, steps=1, segments=segments)


def mail_links(height):
    for row in range(2):
        for col in range(-3, 4):
            x = col * 0.063 + row * 0.016
            y = 0.02 - 0.236 * math.sqrt(1 - (x / 0.305) ** 2) - 0.007
            ellipse("mail_link", (x, y, height + 1.278 + row * 0.041),
                    0.027, 0.019, 0.0045, "steel", samples=10, segments=4)
    for side in (-1, 1):
        for i in range(3):
            ellipse("coif_link", (side * 0.275, -0.095, height + 1.50 + i * 0.064),
                    0.018, 0.023, 0.0045, "steel", samples=10, segments=4)


def heraldry(x, y, z, scale, team):
    color = "gold" if team == "blue" else "white"
    if team == "red":
        outline = [(-0.11, 0.48), (0.11, 0.48), (0.09, 0.14), (0.32, 0.15),
                   (0.32, -0.01), (0.09, 0), (0.11, -0.48), (-0.11, -0.48),
                   (-0.09, 0), (-0.32, -0.01), (-0.32, 0.15), (-0.09, 0.14)]
        plate("heraldic_cross", [(x + a * scale, z + b * scale) for a, b in outline],
              y, 0.019, color)
        return
    centre = [(0, 0.55), (0.10, 0.37), (0.11, 0.23), (0.045, 0.015),
              (-0.045, 0.015), (-0.11, 0.23), (-0.10, 0.37)]
    plate("fleur_de_lis_centre", [(x + a * scale, z + b * scale) for a, b in centre],
          y, 0.02, color)
    petal = [(0.035, 0.045), (0.12, 0.24), (0.22, 0.32), (0.33, 0.31),
             (0.39, 0.21), (0.37, 0.11), (0.30, 0.05), (0.27, 0.11),
             (0.26, 0.19), (0.20, 0.18), (0.16, 0.09), (0.12, -0.02)]
    foot = [(0.04, -0.04), (0.14, -0.15), (0.24, -0.16), (0.27, -0.11),
            (0.26, -0.22), (0.18, -0.25), (0.09, -0.19), (0.02, -0.09)]
    for side in (-1, 1):
        for name, outline in (("fleur_de_lis_petal", petal), ("fleur_de_lis_scroll", foot)):
            plate(name, [(x + side * a * scale, z + b * scale) for a, b in outline],
                  y, 0.019, color)
    plate("fleur_de_lis_tail", [(x, z - scale * 0.43), (x - scale * 0.08, z - scale * 0.27),
                                (x - scale * 0.04, z - scale * 0.035),
                                (x + scale * 0.04, z - scale * 0.035),
                                (x + scale * 0.08, z - scale * 0.27)], y, 0.019, color)
    box("fleur_de_lis_band", (x, y - 0.01, z), (scale * 0.41, 0.022, scale * 0.075), color, 0.008)


def shield(x, y, z, team, scale=1.0):
    outline = [(-0.36, 0.43), (0, 0.50), (0.36, 0.43), (0.375, 0.23),
               (0.35, -0.04), (0.27, -0.27), (0.15, -0.46), (0, -0.61),
               (-0.15, -0.46), (-0.27, -0.27), (-0.35, -0.04), (-0.375, 0.23)]
    for label, factor, offset, color in (("shield_rim", 1, 0, "steel_light"),
                                         ("shield_field", 0.87, -0.018, team)):
        edge = [(x + a * scale * factor,
                 y + offset - 0.060 * scale * (1 - abs(a) / 0.38),
                 z + b * scale * factor) for a, b in outline]
        vertices = [(x, y + offset - 0.065 * scale, z)] + edge
        vertices += [(a, b + 0.04 * scale, c) for a, b, c in edge]
        n = len(edge)
        faces = [(0, (i + 1) % n + 1, i + 1) for i in range(n)]
        faces += [(i + 1, (i + 1) % n + 1, (i + 1) % n + 1 + n, i + 1 + n)
                  for i in range(n)]
        faces.append(tuple(range(n + 1, 2 * n + 1)))
        obj = mesh(label, vertices, faces, color)
        for polygon in obj.data.polygons:
            polygon.use_smooth = len(polygon.vertices) == 3
    heraldry(x, y - 0.093 * scale, z + 0.014 * scale, 0.69 * scale, team)
    for a, b in outline:
        if abs(b) < 0.60:
            rounded("shield_rivet", (x + a * scale * 0.955,
                    y - 0.026 * scale - 0.060 * scale * (1 - abs(a) / 0.38),
                    z + b * scale * 0.955), (0.016 * scale, 0.012, 0.016 * scale),
                    "steel", segments=8, rings=4)
    rounded("shield_boss", (x, y - 0.11 * scale, z - 0.02 * scale),
            (0.065 * scale, 0.035 * scale, 0.076 * scale), "gold", segments=12, rings=6)


def side_panel(side, team):
    before = set(bpy.context.scene.objects)
    outline = [(-0.62, 0.29), (-0.31, 0.38), (0.43, 0.33), (0.68, 0.20),
               (0.63, -0.33), (0.35, -0.39), (-0.25, -0.36), (-0.63, -0.24)]
    for name, factor, y, color in (("caparison_gold_hem", 1, 0, "gold"),
                                   ("caparison_cloth", 0.93, -0.018, team)):
        plate(name, [(a * factor, b * factor) for a, b in outline], y, 0.021, color)
    heraldry(0.30, -0.040, -0.01, 0.36, team)
    for obj in set(bpy.context.scene.objects) - before:
        rotation = Matrix.Rotation(side * math.pi / 2, 4, "Z")
        obj.matrix_world = Matrix.Translation((side * 0.43, 0.05, 1.19)) @ rotation @ obj.matrix_world


def timber(name, start, end, width, color="wood_light"):
    delta = Vector(end) - Vector(start)
    obj = box(name, (Vector(start) + Vector(end)) / 2, (width, width, delta.length), color, 0.014)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = delta.to_track_quat("Z", "Y")
    return obj
