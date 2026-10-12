import math

from model_primitives import mesh, sphere


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

