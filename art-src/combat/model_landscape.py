import math
import random

from model_primitives import beam, box, cone, emblem, ico, material, mesh, plate, sphere
from landscape_foliage import branch, deciduous_tree, leaf_geometry, leafy_crown, pine_tree, weathered_stone


def tree(kind):
    if kind == "pine":
        pine_tree()
    else:
        deciduous_tree(kind)


def rock(variant):
    rng = random.Random(variant)
    count = 1 if variant != "cluster" else 4
    for i in range(count):
        x, y = (0, 0) if count == 1 else (rng.uniform(-0.6, 0.6), rng.uniform(-0.5, 0.5))
        scale = (1.0, 0.76, 1.25) if variant == "boulder" else (0.61, 0.58, 0.60)
        weathered_stone((x, y, 0), scale, rng, moss=variant != "small")


def grass_blade(x, y, height, angle, width, color):
    direction = (math.cos(angle), math.sin(angle))
    across = (-direction[1] * width, direction[0] * width)
    vertices = []
    for z, reach, span in ((0, 0, 0.80), (0.42, 0.09, 1.0), (0.79, 0.24, 0.51)):
        for side in (-1, 1):
            vertices.append((x + direction[0] * height * reach + across[0] * span * side,
                             y + direction[1] * height * reach + across[1] * span * side, z * height))
    vertices.append((x + direction[0] * height * 0.43, y + direction[1] * height * 0.43, height))
    faces = [(0, 1, 3, 2), (2, 3, 5, 4), (4, 5, 6)]
    return mesh("curved_grass_blade", vertices, faces + [tuple(reversed(face)) for face in faces], color)


def undergrowth(kind):
    rng = random.Random(kind)
    if kind == "bush":
        for i in range(7):
            angle = i * 2.39996
            x, y = math.cos(angle) * 0.34, math.sin(angle) * 0.31
            z = rng.uniform(0.32, 0.56)
            branch("bush_stem", [(0, 0, 0), (x * 0.6, y * 0.6, z * 0.5), (x, y, z)],
                   [0.027, 0.020, 0.006])
            leafy_crown("bush_leaf_spray", (x, y, z), (0.36, 0.32, 0.30),
                        ("oak_shadow", "oak_mid", "oak_lit", "oak_tip"), rng, 22)
    elif kind == "stump":
        cone("stump", (0, 0, 0.30), 0.35, 0.60, "wood", 0.29)
        cone("cut_surface", (0, 0, 0.607), 0.255, 0.016, "wood_light", 0.255)
        for i in range(4):
            angle = math.tau * i / 4
            beam("stump_root", (0, 0, 0.20), (math.cos(angle) * 0.52, math.sin(angle) * 0.52, 0.04),
                 0.09, "wood")
    else:
        for i in range(27 if kind == "grass" else 13):
            x, y = rng.uniform(-0.45, 0.45), rng.uniform(-0.40, 0.40)
            z = rng.uniform(0.25, 0.50) if kind != "reeds" else rng.uniform(0.7, 1.35)
            angle = rng.uniform(0, math.tau)
            if kind == "grass":
                grass_blade(x, y, z, angle, rng.uniform(0.012, 0.024),
                            "grass" if i % 4 else "oak_lit")
                continue
            beam("stem", (x, y, 0), (x + 0.07, y, z), 0.008, "grass", vertices=5)
            if kind == "flowers":
                color = ("white", "gold", "flower")[i % 3]
                for petal in range(6):
                    direction = petal * math.tau / 6
                    vertices, faces = leaf_geometry((x + 0.07 + math.cos(direction) * 0.04,
                                                    y + math.sin(direction) * 0.04, z),
                                                   direction, 0.034, 0.043, 0.0)
                    mesh("flower_petal", vertices, faces, color)
                sphere("flower_center", (x + 0.07, y, z + 0.015), (0.020, 0.020, 0.013), "gold",
                       segments=8, rings=4)
                for side in (-1, 1):
                    vertices, faces = leaf_geometry((x, y, z * 0.36), angle + side * 1.4, 0.028, 0.085)
                    mesh("flower_stem_leaf", vertices, faces, "oak_mid")
            elif kind == "reeds":
                beam("reed_head", (x + 0.07, y, z - 0.13), (x + 0.07, y, z + 0.04), 0.028, "bark_shadow")
                grass_blade(x, y, z * 0.82, angle, 0.026, "grass")
                grass_blade(x, y, z * 0.62, angle + 1.4, 0.022, "oak_lit")


def bridge():
    rng = random.Random(81)
    for i in range(19):
        box("bridge_plank", (rng.uniform(-0.025, 0.025), -2.85 + i * 0.3,
                             0.40 + rng.uniform(-0.009, 0.009)),
            (3.0 + rng.uniform(-0.05, 0.05), 0.275, 0.15),
            "wood_light" if i % 4 else "bark_lit", 0.016)
        for x in (-1.06, 1.06):
            cone("plank_nail", (x, -2.85 + i * 0.3, 0.487), 0.020, 0.012, "steel", 0.020, 6)
    for side in (-1, 1):
        beam("bridge_support", (side * 1.1, -3, 0.22), (side * 1.1, 3, 0.22), 0.09, "wood")
        for y in (-2.7, -1.35, 0, 1.35, 2.7):
            beam("rail_post", (side * 1.4, y, 0), (side * 1.4, y, 1.3), 0.065, "wood")
        for z in (0.82, 1.25):
            beam("handrail", (side * 1.4, -2.8, z), (side * 1.4, 2.8, z), 0.048, "wood_light")


def river(bend=False):
    sections = 13
    vertices = []
    banks = [[], []]
    for i in range(sections):
        t = i / (sections - 1)
        angle = t * math.pi / 2
        center = (math.sin(angle) * 6, (1 - math.cos(angle)) * 6) if bend else (0, t * 12 - 6)
        cross = (math.sin(angle), -math.cos(angle)) if bend else (1, 0)
        for side in (-1, 1):
            vertices.append((center[0] + side * 1.55 * cross[0], center[1] + side * 1.55 * cross[1], 0.04))
            banks[(side + 1) // 2].append((center[0] + side * 1.85 * cross[0], center[1] + side * 1.85 * cross[1], 0.06))
    water = mesh("river_water", vertices, [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2)
                                           for i in range(sections - 1)], "water")
    for loop in water.data.loops:
        index = loop.vertex_index
        water.data.uv_layers["UVMap"].data[loop.index].uv = (index % 2, index // 2 / (sections - 1))
    for side in range(2):
        shore = []
        for i in range(sections):
            inner = vertices[i * 2 + side]
            outer = banks[side][i]
            shore += [(inner[0], inner[1], 0.035),
                      (outer[0], outer[1], 0.085 + math.sin(i * 1.7) * 0.025)]
        faces = [(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2) for i in range(sections - 1)]
        mesh("eroded_river_bank", shore,
             [tuple(reversed(face)) for face in faces] if side == 0 else faces, "earth")


def ground(hill=False, path=False):
    rng = random.Random(23)
    size = 8
    vertices = []
    for y in range(size + 1):
        for x in range(size + 1):
            px, py = x / size - 0.5, y / size - 0.5
            z = max(0, 1 - (px * px + py * py) * 3.8) * 0.25 if hill else 0
            vertices.append((px, py, z))
    faces = []
    for y in range(size):
        for x in range(size):
            i = y * (size + 1) + x
            faces.extend([(i, i + 1, i + size + 2), (i, i + size + 2, i + size + 1)])
    obj = mesh("landscape_surface", vertices, faces, "earth" if path else "grass")
    obj.data.materials.append(material("wood_light" if path else "leaf_light"))
    for face in obj.data.polygons:
        face.material_index = int(rng.random() > 0.84)


def camp(kind, team="blue"):
    if kind == "banner":
        beam("banner_pole", (0, 0, 0), (0, 0, 2.8), 0.044, "wood")
        sphere("banner_finial", (0, 0, 2.85), (0.08, 0.08, 0.10), "gold")
        beam("banner_crossbar", (-0.04, 0, 2.58), (0.84, 0, 2.58), 0.028, "wood")
        plate("banner_cloth", [(0.05, 2.55), (0.79, 2.55), (0.79, 1.19),
                               (0.42, 1.40), (0.05, 1.19)], -0.04, 0.02, team)
        emblem(0.42, -0.063, 1.98, 0.61, team)
    elif kind == "tent":
        mesh("tent_canvas", [(-1.1, -1.3, 0), (1.1, -1.3, 0), (0, -1.3, 1.65),
                             (-1.1, 1.3, 0), (1.1, 1.3, 0), (0, 1.3, 1.65)],
             [(0, 3, 5, 2), (1, 2, 5, 4), (3, 4, 5)], "cream")
        plate("tent_door_left", [(-1.1, 0), (-0.21, 0), (0, 1.65)], -1.31, 0.01, team)
        plate("tent_door_right", [(0.21, 0), (1.1, 0), (0, 1.65)], -1.31, 0.01, team)
        beam("tent_ridge", (0, -1.45, 1.66), (0, 1.45, 1.66), 0.045, "wood")
    elif kind == "barrel":
        cone("barrel_body", (0, 0, 0.4), 0.31, 0.8, "wood_light", 0.29, 12)
        for z in (0.12, 0.64):
            cone("barrel_hoop", (0, 0, z), 0.316, 0.06, "steel", 0.316, 12)
    elif kind == "fence":
        for x in (-1.2, 1.2):
            box("fence_post", (x, 0, 0.55), (0.14, 0.14, 1.1), "wood", 0.015)
        for z in (0.35, 0.85):
            box("fence_rail", (0, 0, z), (2.6, 0.11, 0.12), "wood_light", 0.02)
    elif kind == "watchtower":
        box("tower_base", (0, 0, 0.25), (2.3, 2.3, 0.5), "stone", 0.07)
        for row in range(8):
            for side in (-1, 1):
                for i in range(3):
                    p = -0.7 + i * 0.7
                    box("tower_block", (p, side * 0.75, 0.7 + row * 0.40),
                        (0.67, 0.35, 0.38), "stone_light" if (i + row) % 3 else "stone", 0.018)
                    box("tower_block", (side * 0.75, p, 0.7 + row * 0.40),
                        (0.35, 0.67, 0.38), "stone", 0.018)
        for x in (-0.82, 0, 0.82):
            for y in (-0.82, 0.82):
                box("tower_merlon", (x, y, 4.02), (0.45, 0.45, 0.58), "stone_light", 0.025)
        plate("tower_banner", [(-0.30, 3.2), (0.30, 3.2), (0.30, 1.95), (0, 1.75), (-0.30, 1.95)],
              -0.951, 0.01, team)
        emblem(0, -0.97, 2.62, 0.58, team)


def riverbank():
    rng = random.Random(43)
    for i in range(9):
        x, y = rng.uniform(-0.7, 0.7), i * 0.67 - 2.65
        weathered_stone((x, y, -0.055), (rng.uniform(0.28, 0.65), 0.42, rng.uniform(0.38, 0.62)),
                        rng, moss=i % 3 == 0)


def water_lilies():
    for x, y, radius in ((-0.3, 0, 0.21), (0.23, 0.22, 0.16), (0.1, -0.28, 0.13)):
        vertices = [(x, y, 0.030)] + [(x + math.cos(0.25 + i * (math.tau - 0.5) / 12) * radius,
                                     y + math.sin(0.25 + i * (math.tau - 0.5) / 12) * radius,
                                     0.025 + 0.004 * math.sin(i)) for i in range(13)]
        mesh("notched_lily_pad", vertices, [(0, i + 1, i + 2) for i in range(12)], "oak_mid")
    for i in range(6):
        angle = i * math.tau / 6
        vertices, faces = leaf_geometry((-0.3 + math.cos(angle) * 0.03,
                                        math.sin(angle) * 0.03, 0.055), angle, 0.026, 0.050, 0.4)
        mesh("lily_flower_petal", vertices, faces, "white")
    sphere("lily_stamen", (-0.3, 0, 0.061), (0.019, 0.019, 0.015), "gold", segments=8, rings=4)


def fern():
    for i in range(8):
        angle = i * math.tau / 8
        branch("arched_fern_stem", [(0, 0, 0), (math.cos(angle) * 0.15, math.sin(angle) * 0.15, 0.44),
                                   (math.cos(angle) * 0.49, math.sin(angle) * 0.49, 0.26)],
               [0.010, 0.007, 0.002])
        for j in range(8):
            r, z = 0.07 + j * 0.055, 0.38 + math.sin(j / 7 * math.pi) * 0.06 - j * 0.014
            x, y = math.cos(angle) * r, math.sin(angle) * r
            for side in (-1, 1):
                direction = angle + side * 0.85
                length = 0.14 - j * 0.012
                vertices, faces = leaf_geometry((x, y, z), direction, length * 0.28, length, -0.1)
                mesh("fern_leaflet", vertices, faces, "oak_lit" if i % 3 else "oak_mid")


def pebble_patch():
    rng = random.Random(71)
    for i in range(16):
        scale = rng.uniform(0.035, 0.10)
        ico("pebble", (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), scale * 0.25),
            (scale, scale * 0.7, scale * 0.4), "stone_light" if i % 3 else "earth")
