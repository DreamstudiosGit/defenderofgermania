"""Merchant train kit: wagon, wheel, cargo, draught horse and town gate (Blender, -Y forward)."""
import math

import bpy

from model_primitives import PALETTE, beam, box, cone, finish, plate, sphere

PALETTE.update({
    "roof_tile": (0.42, 0.10, 0.05), "shadow": (0.035, 0.028, 0.022),
    "canvas": (0.74, 0.64, 0.44), "cloth_red": (0.55, 0.06, 0.05),
    "cloth_blue": (0.06, 0.16, 0.45), "cloth_green": (0.10, 0.28, 0.08),
    "horse_bay": (0.30, 0.13, 0.05), "feather": (0.80, 0.74, 0.60),
})

WHEEL_RADIUS = 0.5


def wagon():
    """Open merchant wagon facing -Y: bed, driver's box, draw pole and axles; wheels apart."""
    floor = 1.0
    box("wagon_floor", (0, 0.15, floor), (1.5, 3.3, 0.12), "wood", 0.02)
    for side in (-1, 1):
        box("wagon_side", (side * 0.72, 0.15, floor + 0.3), (0.08, 3.3, 0.5), "wood_light", 0.02)
        for y in (-1.3, -0.3, 0.7, 1.6):
            box("wagon_stake", (side * 0.78, y, floor + 0.32), (0.07, 0.07, 0.62), "wood", 0.01)
        box("wagon_rail", (side * 0.72, 0.15, floor + 0.58), (0.1, 3.4, 0.07), "wood", 0.01)
    box("wagon_tailboard", (0, 1.78, floor + 0.3), (1.42, 0.08, 0.5), "wood_light", 0.02)
    box("box_front", (0, -1.42, floor + 0.35), (1.42, 0.08, 0.6), "wood_light", 0.02)
    box("box_seat", (0, -1.2, floor + 0.62), (1.3, 0.42, 0.1), "wood", 0.02)
    box("box_footboard", (0, -1.72, floor + 0.08), (1.2, 0.5, 0.06), "wood", 0.01)
    for y in (-1.05, 1.15):
        beam("axle", (-0.95, y, WHEEL_RADIUS), (0.95, y, WHEEL_RADIUS), 0.06, "wood", vertices=6)
        box("axle_block", (0, y, (WHEEL_RADIUS + floor) * 0.5), (1.1, 0.2, floor - WHEEL_RADIUS),
            "wood", 0.01)
    beam("draw_pole", (0, -1.5, 0.8), (0, -4.6, 0.95), 0.06, "wood", vertices=6)
    beam("swingle_tree", (-0.75, -1.85, 0.82), (0.75, -1.85, 0.82), 0.045, "wood", vertices=6)
    box("lantern", (0.62, -1.55, floor + 0.95), (0.14, 0.14, 0.2), "gold", 0.02)
    beam("lantern_post", (0.62, -1.45, floor + 0.3), (0.62, -1.55, floor + 0.85), 0.025, "steel")


def wheel():
    """Spoked wheel, axle along X, pivot at the hub so the game can spin it."""
    bpy.ops.mesh.primitive_torus_add(major_radius=WHEEL_RADIUS - 0.04, minor_radius=0.05,
                                     major_segments=16, minor_segments=4,
                                     rotation=(0, math.pi / 2, 0))
    finish(bpy.context.object, "wheel_rim", "wood")
    for i in range(8):
        angle = i * math.tau / 8
        end = (0, math.cos(angle) * (WHEEL_RADIUS - 0.06), math.sin(angle) * (WHEEL_RADIUS - 0.06))
        beam("wheel_spoke", (0, 0, 0), end, 0.025, "wood_light", vertices=4)
    beam("wheel_hub", (-0.1, 0, 0), (0.1, 0, 0), 0.09, "steel", vertices=8)


def cargo(kind):
    """Cargo pieces for the wagon bed: cloth bales or crates (barrels reuse prop_barrel_wood)."""
    if kind == "bale":
        beam("bale", (-0.42, 0, 0.25), (0.42, 0, 0.25), 0.25, "cloth_red", vertices=8)
        for x in (-0.25, 0.25):
            beam("bale_cord", (x, 0, 0.25), (x + 0.03, 0, 0.25), 0.262, "canvas", vertices=8)
    else:
        box("crate", (0, 0, 0.27), (0.58, 0.58, 0.54), "wood_light", 0.02)
        for z in (0.06, 0.48):
            box("crate_band", (0, 0, z), (0.6, 0.6, 0.06), "wood", 0.0)
        box("crate_seal", (0, -0.3, 0.32), (0.16, 0.02, 0.16), "cloth_red", 0.0)


def draught_horse():
    """Stocky draught horse with collar, blinkers and loose traces; diagonal trot in UV2."""
    coat, dark = "horse_bay", "black"
    sphere("horse_barrel", (0, 0.05, 1.18), (0.36, 0.78, 0.40), coat, segments=12, rings=8)
    sphere("horse_chest", (0, -0.62, 1.22), (0.34, 0.36, 0.42), coat, segments=10)
    sphere("horse_rump", (0, 0.72, 1.24), (0.37, 0.4, 0.4), coat, segments=10)
    beam("horse_neck", (0, -0.78, 1.38), (0, -1.12, 1.9), 0.22, coat, vertices=10)
    sphere("horse_head", (0, -1.32, 1.86), (0.15, 0.3, 0.17), coat, segments=10)
    sphere("horse_muzzle", (0, -1.56, 1.74), (0.13, 0.14, 0.13), coat, segments=8)
    sphere("horse_blaze", (0, -1.5, 1.92), (0.05, 0.16, 0.05), "feather", segments=6, rings=4)
    for side in (-1, 1):
        cone("horse_ear", (side * 0.08, -1.18, 2.08), 0.045, 0.16, coat, vertices=4)
        box("blinker", (side * 0.17, -1.32, 1.92), (0.03, 0.14, 0.11), "leather", 0.0)
    box("horse_mane", (0, -0.98, 1.84), (0.07, 0.42, 0.18), dark, 0.03)
    beam("horse_tail", (0, 1.08, 1.34), (0, 1.22, 0.82), 0.09, dark, vertices=6)
    for front in (-1, 1):
        for side in (-1, 1):
            # Diagonal pairs share a phase: front left with hind right.
            motion = 1 if side == front else -1
            x, y = side * 0.2, front * -0.55
            beam("horse_leg", (x, y, 1.0), (x, y, 0.18), 0.1, coat, motion, vertices=6)
            sphere("horse_feather", (x, y, 0.2), (0.12, 0.12, 0.1), "feather", motion,
                   segments=6, rings=4)
            beam("horse_hoof", (x, y, 0.12), (x, y, 0.0), 0.11, dark, motion, vertices=6)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.075, major_segments=12,
                                     minor_segments=5, location=(0, -0.86, 1.5),
                                     rotation=(math.radians(55), 0, 0))
    finish(bpy.context.object, "horse_collar", "leather")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.04, major_segments=12,
                                     minor_segments=4, location=(0, -0.83, 1.5),
                                     rotation=(math.radians(55), 0, 0))
    finish(bpy.context.object, "horse_hames", "gold")
    box("horse_pad", (0, -0.1, 1.6), (0.5, 0.36, 0.08), "leather", 0.02)
    for side in (-1, 1):
        beam("horse_trace", (side * 0.33, -0.8, 1.32), (side * 0.38, 1.05, 1.0), 0.03, "leather",
             vertices=4)
        beam("horse_rein", (side * 0.14, -1.52, 1.76), (side * 0.2, -0.1, 1.66), 0.015, "leather",
             vertices=4)


def town_gate():
    """Gatehouse with an open passage along Y (arches at both faces), roof and wall stubs."""
    width, depth, height = 8.0, 6.0, 10.0
    arch_half, arch_spring = 1.9, 3.0
    for y in (-depth / 2, depth / 2):
        for side in (-1, 1):
            outline = [(side * width / 2, 0), (side * arch_half, 0), (side * arch_half, arch_spring)]
            for i in range(1, 8):
                angle = i * math.pi / 2 / 8
                outline.append((side * arch_half * math.cos(angle),
                                arch_spring + arch_half * math.sin(angle)))
            outline += [(0, arch_spring + arch_half), (0, height), (side * width / 2, height)]
            if side > 0:
                outline.reverse()
            plate("gate_face", outline, y, 0.6, "stone")
    for side in (-1, 1):
        box("gate_flank", (side * (width / 2 - 0.3), 0, height / 2), (0.6, depth, height), "stone",
            0.03)
        box("passage_wall", (side * (arch_half + 0.05), 0, arch_spring), (0.1, depth - 0.7,
            arch_spring * 2), "shadow")
        box("gate_leaf", (side * (arch_half - 0.25), depth / 2 - 0.9, 2.2), (0.12, 1.7, 4.2),
            "wood", 0.02)
    box("passage_ceiling", (0, 0, arch_spring + arch_half + 0.05), (arch_half * 2, depth - 0.7,
        0.1), "shadow")
    box("gate_cornice", (0, 0, height + 0.15), (width + 0.4, depth + 0.4, 0.3), "stone", 0.03)
    for x in range(-3, 4, 2):
        for y in (-depth / 2, depth / 2):
            box("merlon", (x, y, height + 0.65), (0.8, 0.5, 0.7), "stone_light", 0.02)
    roof = cone("gate_roof", (0, 0, height + 2.3), 5.3, 4.0, "roof_tile", vertices=4)
    roof.rotation_euler.z = math.pi / 4
    cone("roof_finial", (0, 0, height + 4.6), 0.12, 0.8, "gold", vertices=6)
    for i in range(5):
        box("portcullis_bar", (-1.5 + i * 0.75, -depth / 2 + 0.45, arch_spring + 1.5),
            (0.08, 0.08, 1.2), "steel", 0.0)
    for y in (-depth / 2 - 0.35, depth / 2 + 0.35):
        box("banner_pole", (2.4, y, height - 1.5), (0.06, 0.06, 1.0), "wood", 0.0)
        box("gate_banner_red", (2.4, y, height - 3.0), (1.0, 0.05, 2.0), "cloth_red", 0.0)
        box("gate_banner_white", (2.4, y - 0.01 * (1 if y > 0 else -1), height - 3.0),
            (0.32, 0.05, 2.0), "white", 0.0)
    for side, length in ((1, 14.0), (-1, 2.0)):
        x = side * (width / 2 + length / 2)
        box("town_wall", (x, 0, 3.5), (length, 1.8, 7.0), "stone", 0.03)
        for i in range(int(length // 1.6)):
            mx = side * (width / 2 + 0.8 + i * 1.6)
            box("wall_merlon", (mx, 0, 7.4), (0.8, 1.8, 0.8), "stone_light", 0.02)
