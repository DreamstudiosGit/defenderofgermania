"""Decorations of the home castle (banners, pennants, fountain, rose garden, tapestry) and the
construction site pieces (scaffold bay, treadwheel crane, building site)."""
import math
import random

from castle_shapes import PRIMARY, SECONDARY, gable_roof, placed
from model_primitives import beam, box, cone, ico, plate, sphere


def banner():
    """Tall pole with a hanging banner in the house colours; pivot at the pole foot."""
    beam("banner_pole", (0, 0, 0), (0, 0, 8.6), 0.09, "castle_timber", vertices=6)
    sphere("banner_finial", (0, 0, 8.75), (0.2, 0.2, 0.2), "castle_gold", segments=6, rings=4)
    beam("banner_crossbar", (-0.95, -0.12, 8.2), (0.95, -0.12, 8.2), 0.05, "castle_gold", vertices=4)
    outline = [(-0.85, 8.15), (0.85, 8.15), (0.85, 4.8), (0.0, 5.4), (-0.85, 4.8)]
    plate("banner_cloth", outline, -0.16, 0.05, PRIMARY)
    for x in (-0.55, 0.55):
        plate("banner_stripe", [(x - 0.13, 8.15), (x + 0.13, 8.15), (x + 0.13, 5.1), (x - 0.13, 5.1)],
              -0.2, 0.05, SECONDARY)
    plate("banner_charge", [(0.0, 7.6), (0.32, 7.0), (0.0, 6.4), (-0.32, 7.0)], -0.21, 0.05,
          "castle_gold")


def pennant():
    """Short pole with a long swallow-tailed streamer; pivot at the pole foot."""
    beam("pennant_pole", (0, 0, 0), (0, 0, 4.4), 0.06, "castle_timber", vertices=6)
    sphere("pennant_finial", (0, 0, 4.52), (0.13, 0.13, 0.13), "castle_gold", segments=6, rings=4)
    plate("pennant_cloth", [(0.05, 4.3), (2.4, 4.0), (3.6, 4.1), (3.0, 3.85), (3.6, 3.55), (2.4, 3.7),
                            (0.05, 3.6)], 0.0, 0.04, PRIMARY)
    plate("pennant_band", [(0.05, 4.3), (0.7, 4.22), (0.7, 3.65), (0.05, 3.6)], 0.0, 0.07, SECONDARY)


def tapestry():
    """Wall hanging in the house colours with a gold rod; pivot at the bottom centre, faces -Y."""
    beam("tapestry_rod", (-1.0, -0.12, 3.85), (1.0, -0.12, 3.85), 0.06, "castle_timber", vertices=6)
    for x in (-1.05, 1.05):
        sphere("tapestry_knob", (x, -0.12, 3.85), (0.11, 0.11, 0.11), "castle_gold", segments=6, rings=4)
    plate("tapestry_cloth", [(-0.8, 3.8), (0.8, 3.8), (0.8, 0.35), (0.0, 0.0), (-0.8, 0.35)], -0.1, 0.04,
          PRIMARY)
    for x in (-0.66, 0.66):
        plate("tapestry_border", [(x - 0.07, 3.8), (x + 0.07, 3.8), (x + 0.07, 0.45), (x - 0.07, 0.4)],
              -0.13, 0.03, SECONDARY)
    plate("tapestry_hem", [(-0.8, 0.62), (0.8, 0.62), (0.8, 0.35), (0.0, 0.0), (-0.8, 0.35)], -0.135,
          0.03, SECONDARY)
    roundel = cone("tapestry_roundel", (0, -0.15, 2.35), 0.5, 0.03, SECONDARY, 0.5, 8)
    roundel.rotation_euler.x = math.pi / 2
    plate("tapestry_charge", [(0.0, 2.75), (0.28, 2.35), (0.0, 1.95), (-0.28, 2.35)], -0.18, 0.03,
          "castle_gold")
    for i in range(7):
        x = -0.72 + i * 0.24
        plate("tapestry_fringe", [(x - 0.06, 3.8), (x + 0.06, 3.8), (x, 3.58)], -0.135, 0.03,
              "castle_gold")


def fountain():
    cone("fountain_paving", (0, 0, 0.04), 3.3, 0.08, "castle_stone_light", 3.3, 8)
    cone("fountain_basin", (0, 0, 0.42), 2.1, 0.75, "castle_stone", 2.2, 8)
    cone("fountain_water", (0, 0, 0.74), 1.85, 0.06, "castle_water", 1.85, 8)
    cone("fountain_column", (0, 0, 1.5), 0.32, 1.6, "castle_stone_light", 0.24, 8)
    cone("fountain_bowl", (0, 0, 2.35), 0.35, 0.4, "castle_stone_light", 0.95, 8)
    cone("fountain_bowl_water", (0, 0, 2.56), 0.85, 0.04, "castle_water", 0.85, 8)
    cone("fountain_spout", (0, 0, 2.95), 0.18, 0.8, "castle_stone_light", 0.08, 6)
    sphere("fountain_finial", (0, 0, 3.45), (0.2, 0.2, 0.2), "castle_gold", segments=6, rings=4)
    for i in range(4):
        angle = i * math.pi / 2 + math.pi / 4
        start = (math.cos(angle) * 0.75, math.sin(angle) * 0.75, 2.45)
        end = (math.cos(angle) * 1.45, math.sin(angle) * 1.45, 0.78)
        beam("fountain_jet", start, end, 0.07, "castle_water", vertices=4)


def rose_garden():
    rng = random.Random(7)
    box("garden_gravel", (0, 0, 0.03), (8.4, 6.4, 0.06), "castle_linen")
    for (x, y, sx, sy) in ((0, 3.0, 8.4, 0.5), (-4.0, 0, 0.5, 6.4), (4.0, 0, 0.5, 6.4),
                           (-2.6, -3.0, 3.2, 0.5), (2.6, -3.0, 3.2, 0.5)):
        box("garden_hedge", (x, y, 0.38), (sx, sy, 0.7), "castle_hedge")
    for bx in (-2.1, 2.1):
        for by in (-1.35, 1.35):
            box("rose_bed", (bx, by, 0.12), (2.6, 1.6, 0.18), "castle_earth")
            for i in range(3):
                at = (bx - 0.8 + i * 0.8, by + rng.uniform(-0.25, 0.25), 0.55)
                ico("rose_bush", at, (0.45, 0.45, 0.42), "castle_hedge")
                for j in range(3):
                    angle = rng.uniform(0, math.tau)
                    color = "castle_rose" if (i + j) % 3 else "castle_rose_pink"
                    ico("rose_blossom", (at[0] + math.cos(angle) * 0.32, at[1] + math.sin(angle) * 0.32,
                                         0.62 + rng.uniform(0, 0.25)), (0.13, 0.13, 0.12), color)
    for x in (-0.75, 0.75):
        box("arbor_post", (x, 0, 1.2), (0.14, 0.14, 2.4), "castle_wood_light")
    for i in range(6):
        a0, a1 = i * math.pi / 6, (i + 1) * math.pi / 6
        beam("arbor_arch", (math.cos(a0) * 0.75, 0, 2.4 + math.sin(a0) * 0.6),
             (math.cos(a1) * 0.75, 0, 2.4 + math.sin(a1) * 0.6), 0.06, "castle_wood_light", vertices=4)
    for i in range(5):
        x = -0.75 + i * 0.375
        z = 2.4 + math.sqrt(max(0.0, 1 - (x / 0.75) ** 2)) * 0.6
        ico("arbor_rose", (x, 0, z), (0.22, 0.22, 0.2), "castle_rose" if i % 2 else "castle_hedge")
    box("garden_bench", (0, 2.3, 0.45), (1.6, 0.45, 0.1), "castle_wood")
    for x in (-0.65, 0.65):
        box("bench_leg", (x, 2.3, 0.22), (0.12, 0.4, 0.44), "castle_wood")


def scaffold():
    """One scaffold bay, 3 m wide and 3 m tall; its back (+Y) stands against the wall."""
    for x in (-1.45, 1.45):
        for y in (-0.6, 0.6):
            beam("scaffold_pole", (x, y, 0), (x, y, 3.0), 0.07, "castle_wood_light", vertices=4)
    for y in (-0.6, 0.6):
        beam("scaffold_ledger", (-1.6, y, 2.9), (1.6, y, 2.9), 0.05, "castle_wood_light", vertices=4)
    box("scaffold_deck", (0, 0, 2.97), (3.0, 1.35, 0.08), "castle_wood")
    beam("scaffold_brace", (-1.45, -0.62, 0.1), (1.45, -0.62, 2.85), 0.045, "castle_wood_light", vertices=4)
    box("scaffold_toeboard", (0, -0.66, 3.1), (3.0, 0.04, 0.2), "castle_wood")


def crane():
    """Treadwheel crane with a stone block on the hook."""
    for angle in (0, math.pi / 2):
        foot = box("crane_foot", (0, 0, 0.15), (4.0, 0.3, 0.3), "castle_timber")
        foot.rotation_euler.z = angle
    beam("crane_mast", (0, 0, 0), (0, 0, 8.0), 0.18, "castle_timber", vertices=6)
    for i in range(4):
        angle = i * math.pi / 2
        beam("crane_strut", (math.cos(angle) * 1.8, math.sin(angle) * 1.8, 0.2), (0, 0, 3.0), 0.08,
             "castle_timber", vertices=4)
    beam("crane_jib", (-1.0, 0, 7.0), (5.0, 0, 8.6), 0.13, "castle_wood", vertices=6)
    beam("crane_rope", (4.9, 0, 8.5), (4.9, 0, 2.6), 0.025, "castle_linen", vertices=4)
    box("crane_load", (4.9, 0, 2.2), (0.9, 0.7, 0.6), "castle_stone_light")
    for i in range(12):
        a0, a1 = i * math.tau / 12, (i + 1) * math.tau / 12
        for y in (-0.55, 0.55):
            beam("treadwheel_rim", (-1.6 + math.cos(a0) * 1.7, y, 2.2 + math.sin(a0) * 1.7),
                 (-1.6 + math.cos(a1) * 1.7, y, 2.2 + math.sin(a1) * 1.7), 0.06, "castle_wood_light",
                 vertices=4)
        if i % 2 == 0:
            beam("treadwheel_spoke", (-1.6, 0, 2.2), (-1.6 + math.cos(a0) * 1.7, 0, 2.2 + math.sin(a0) * 1.7),
                 0.05, "castle_wood_light", vertices=4)
    beam("treadwheel_axle", (-1.6, -0.8, 2.2), (-1.6, 0.8, 2.2), 0.1, "castle_timber", vertices=6)


def building_site():
    rng = random.Random(11)
    for i in range(7):
        row, col = divmod(i, 4)
        block = box("site_block", (-1.6 + col * 0.95 + row * 0.45, -0.6, 0.3 + row * 0.6), (0.85, 0.7, 0.58),
                    "castle_stone_light")
        block.rotation_euler.z = rng.uniform(-0.1, 0.1)
    for i in range(5):
        beam("site_timber", (1.0, -0.4 + i * 0.25, 0.12 + (i % 2) * 0.22), (4.2, -0.3 + i * 0.25,
                                                                           0.12 + (i % 2) * 0.22),
             0.11, "castle_wood_light", vertices=6)
    box("site_cart", (-0.6, 1.6, 0.85), (2.2, 1.3, 0.5), "castle_wood")
    for x in (-1.2, 0.0):
        for y in (0.9, 2.3):
            wheel = cone("site_wheel", (x + 0.0, y, 0.5), 0.5, 0.12, "castle_timber", 0.5, 8)
            wheel.rotation_euler.x = math.pi / 2
    beam("site_shaft", (0.5, 1.4, 0.8), (2.4, 1.4, 0.3), 0.06, "castle_wood", vertices=4)
    beam("site_shaft", (0.5, 1.8, 0.8), (2.4, 1.8, 0.3), 0.06, "castle_wood", vertices=4)
    box("site_trough", (2.6, -1.8, 0.25), (1.4, 0.8, 0.5), "castle_wood")
    box("site_mortar", (2.6, -1.8, 0.48), (1.2, 0.6, 0.06), "castle_linen")


def site_hut():
    """Mason's lean-to beside a construction."""
    for x in (-1.8, 1.8):
        for y, h in ((-1.2, 2.6), (1.2, 2.0)):
            box("hut_post", (x, y, h / 2), (0.18, 0.18, h), "castle_timber")
    gable_roof("hut_roof", (0, 0, 2.0), 4.2, 3.0, 0.9, "castle_shingle")
