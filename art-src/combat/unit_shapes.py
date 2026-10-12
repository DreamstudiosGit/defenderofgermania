import math
from contextlib import contextmanager

import bmesh
import bpy
from mathutils import Vector

from model_primitives import mesh


def bind(obj, bone, stride=0):
    """Rigid skinning to one bone; stride is the UV2 leg mask (+1 left phase, -1 right phase)."""
    obj.vertex_groups.clear()
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    for value in obj.data.color_attributes["motion"].data:
        value.color = (abs(stride), 1.0 if stride > 0 else 0.0, 0.0, 1.0)
    obj["bone"] = bone


@contextmanager
def part(bone, stride=0):
    """Binds every mesh created inside the block that is not bound yet."""
    before = set(bpy.context.scene.objects)
    yield
    for obj in set(bpy.context.scene.objects) - before:
        if obj.type == "MESH" and "bone" not in obj:
            bind(obj, bone, stride)


def created_since(before):
    return [obj for obj in bpy.context.scene.objects if obj not in before and obj.type == "MESH"]


def transform(objects, matrix):
    for obj in objects:
        obj.matrix_world = matrix @ obj.matrix_world


def _smooth(obj, smooth):
    for face in obj.data.polygons:
        face.use_smooth = smooth and len(face.vertices) == 4
    return obj


def outward(obj):
    data = bmesh.new()
    data.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(data, faces=data.faces)
    data.to_mesh(obj.data)
    data.free()
    return obj


def limb(name, points, radii, color, segments=8, caps=True, smooth=True):
    """Loft of elliptical rings along a polyline; a radius is a float or a (side, up) pair."""
    points = [Vector(p) for p in points]
    vertices = []
    for i, point in enumerate(points):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        reference = Vector((1, 0, 0)) if abs(tangent.x) < 0.9 else Vector((0, 1, 0))
        side = (reference - tangent * reference.dot(tangent)).normalized()
        up = tangent.cross(side)
        radius_side, radius_up = radii[i] if isinstance(radii[i], tuple) else (radii[i], radii[i])
        for k in range(segments):
            angle = k * math.tau / segments
            vertices.append(point + side * math.cos(angle) * radius_side + up * math.sin(angle) * radius_up)
    faces = []
    for row in range(len(points) - 1):
        for k in range(segments):
            a, b = row * segments + k, row * segments + (k + 1) % segments
            faces.append((a, b, b + segments, a + segments))
    if caps:
        faces.append(tuple(reversed(range(segments))))
        faces.append(tuple(range(len(vertices) - segments, len(vertices))))
    return _smooth(mesh(name, [tuple(v) for v in vertices], faces, color), smooth)


def sheet(name, rows, color, thickness, normal=(0, 1, 0), smooth=True):
    """Closed thin slab from a grid of points (rows of equal length), offset along `normal`."""
    offset = Vector(normal).normalized() * thickness / 2
    width = len(rows[0])
    front = [Vector(p) - offset for row in rows for p in row]
    back = [Vector(p) + offset for row in rows for p in row]
    count = len(front)
    faces = []
    for r in range(len(rows) - 1):
        for c in range(width - 1):
            a, b, d, e = r * width + c, r * width + c + 1, (r + 1) * width + c + 1, (r + 1) * width + c
            faces.append((a, b, d, e))
            faces.append((e + count, d + count, b + count, a + count))
    edge = ([c for c in range(width)] + [r * width + width - 1 for r in range(1, len(rows))]
            + [(len(rows) - 1) * width + c for c in range(width - 2, -1, -1)]
            + [r * width for r in range(len(rows) - 2, 0, -1)])
    for i, a in enumerate(edge):
        b = edge[(i + 1) % len(edge)]
        faces.append((b, a, a + count, b + count))
    return _smooth(outward(mesh(name, [tuple(v) for v in front + back], faces, color)), smooth)


def outline_plate(name, outline, color, thickness, frame, bulge=0.0):
    """2D outline (u, v) extruded along the frame normal, which points to the back; bulge domes the front."""
    origin, right, up, normal = (Vector(v) for v in frame)
    centre_u = sum(u for u, _ in outline) / len(outline)
    centre_v = sum(v for _, v in outline) / len(outline)
    vertices = [tuple(origin + right * centre_u + up * centre_v - normal * (thickness / 2 + bulge))]
    for depth in (-thickness / 2, thickness / 2):
        for u, v in outline:
            vertices.append(tuple(origin + right * u + up * v + normal * depth))
    n = len(outline)
    faces = [(0, (i + 1) % n + 1, i + 1) for i in range(n)]
    faces.append(tuple(range(n + 1, 2 * n + 1)))
    faces += [(i + 1, (i + 1) % n + 1, (i + 1) % n + 1 + n, i + 1 + n) for i in range(n)]
    return outward(mesh(name, vertices, faces, color))
