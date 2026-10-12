"""Halls of the upper home castle levels: palas, chapel, imperial palace (Kaiserpfalz), and the
chapel's stained glass that fits its window openings."""
import math

from castle_shapes import (
    PRIMARY, SECONDARY, chimney, door, gable_roof, hip_roof, opening, placed, quoins, spire, stairs,
)
from model_primitives import box, cone, plate, sphere

CHAPEL_WIDTH, CHAPEL_LENGTH, CHAPEL_HEIGHT = 6.0, 11.0, 7.0
# Side windows: (y, sill height); window width and height.
CHAPEL_WINDOWS = ((-3.0, 2.4), (0.4, 2.4), (3.6, 2.4))
CHAPEL_WINDOW = (1.0, 3.0)
APSE_RADIUS = 2.7
APSE_WINDOWS = (-0.7, 0.0, 0.7)
TOWER_SIZE = 3.2
ROSE_HEIGHT = 9.6


def palas():
    length, depth = 13.0, 7.0
    front = -depth / 2 - 0.03
    box("palas_ground", (0, 0, 2.25), (length, depth, 4.5), "castle_stone")
    box("palas_course", (0, 0, 4.5), (length + 0.3, depth + 0.3, 0.35), "castle_stone_light")
    box("palas_upper", (0, 0, 6.85), (length, depth, 4.7), "castle_stone_light")
    gable_roof("palas_roof", (0, 0, 9.2), length + 0.9, depth + 1.1, 4.6, "castle_roof_tile")
    for gx in (-4.6, -1.55, 1.55, 4.6):
        for ox in (-0.48, 0.48):
            opening("palas_arcade", (gx + ox, front, 5.4), 0.8, 2.1)
        box("palas_colonnette", (gx, front - 0.05, 6.4), (0.18, 0.14, 2.1), "castle_stone_light")
    for gx in (-4.6, 4.6):
        opening("palas_window", (gx, front, 1.6), 0.8, 1.2, arch=False)
    opening("palas_door_arch", (0, front - 0.02, 0.0), 2.2, 3.2, color="castle_stone_light", depth=0.06)
    door((0, front - 0.06, 0.0), 1.6, 2.6)
    for gx in (-3.0, 3.0):
        opening("palas_back_window", (gx, depth / 2 + 0.03, 5.6), 0.8, 1.8, math.pi)
    chimney((3.4, 1.2, 11.0), 3.6)
    chimney((-4.2, -1.0, 10.4), 3.4)
    _gable_ends(length, depth, 9.2, 4.6, "castle_stone_light")


def _gable_ends(length, depth, eaves, height, color):
    for sign in (-1, 1):
        with placed((sign * length / 2, 0, 0), math.pi / 2 if sign > 0 else -math.pi / 2):
            plate("gable_end", [(-depth / 2, eaves), (0, eaves + height), (depth / 2, eaves)], 0.0,
                  0.3, color)


def pfalz():
    length, depth = 16.0, 8.5
    front = -depth / 2 - 0.03
    box("pfalz_plinth", (0, 0, 0.4), (length + 0.6, depth + 0.6, 0.8), "castle_stone_dark")
    box("pfalz_ground", (0, 0, 2.6), (length, depth, 5.2), "castle_stone")
    box("pfalz_course", (0, 0, 5.2), (length + 0.4, depth + 0.4, 0.4), "castle_stone_light")
    box("pfalz_upper", (0, 0, 8.0), (length, depth, 5.6), "castle_stone_light")
    box("pfalz_cornice", (0, 0, 10.85), (length + 0.5, depth + 0.5, 0.3), "castle_gold")
    gable_roof("pfalz_roof", (0, 0, 11.0), length + 1.0, depth + 1.2, 5.6, "castle_slate")
    box("pfalz_ridge", (0, 0, 16.65), (length + 1.1, 0.25, 0.25), "castle_gold")
    _gable_ends(length, depth, 11.0, 5.6, "castle_stone_light")
    for gx in (-6.2, -3.4, 3.4, 6.2):
        for ox in (-0.7, 0.0, 0.7):
            opening("pfalz_arcade", (gx + ox, front, 6.0), 0.6, 2.8)
        opening("pfalz_arcade_frame", (gx, front + 0.01, 5.8), 2.4, 3.6, color="castle_stone", depth=0.08)
        opening("pfalz_window", (gx, front, 1.8), 0.9, 1.6)
    # Central gable bay with the imperial portal and the house arms.
    box("pfalz_bay", (0, -depth / 2 - 0.8, 6.5), (5.0, 1.6, 13.0), "castle_stone_light")
    gable_roof("pfalz_bay_roof", (0, -depth / 2 - 0.4, 13.0), 2.6, 5.6, 3.6, PRIMARY, axis="y")
    plate("pfalz_bay_gable", [(-2.5, 13.0), (0, 16.6), (2.5, 13.0)], -depth / 2 - 1.62, 0.12,
          "castle_stone_light")
    opening("pfalz_portal_frame", (0, -depth / 2 - 1.63, 5.2), 3.2, 4.4, color="castle_gold", depth=0.06)
    opening("pfalz_portal", (0, -depth / 2 - 1.65, 5.4), 2.4, 3.8, color="castle_timber")
    cone("pfalz_rose", (0, -depth / 2 - 1.62, 11.3), 0.95, 0.1, "castle_dark", 0.95, 10).rotation_euler.x = \
        math.pi / 2
    stairs((0, -depth / 2 - 8.0, 0.0), (0, -depth / 2 - 1.7, 5.2), 4.2, 10, "castle_stone_light")
    for side in (-1, 1):
        box("pfalz_stair_wall", (side * 2.25, -depth / 2 - 4.85, 1.4), (0.4, 6.3, 2.8), "castle_stone")
    # Octagonal stair towers at both ends.
    for side in (-1, 1):
        x, y = side * (length / 2 + 0.9), depth / 2 - 1.6
        cone("pfalz_tower", (x, y, 7.5), 2.0, 15.0, "castle_stone_light", 2.0, 8)
        cone("pfalz_tower_band", (x, y, 11.0), 2.15, 0.3, "castle_gold", 2.15, 8)
        spire("pfalz_tower_roof", (x, y, 15.0), 2.5, 6.0, PRIMARY, 8)
        sphere("pfalz_tower_orb", (x, y, 21.2), (0.25, 0.25, 0.25), "castle_gold", segments=6, rings=4)
        opening("pfalz_tower_window", (x, y - 2.0, 12.0), 0.6, 1.4)
    for gx in (-5.0, 0.0, 5.0):
        opening("pfalz_back_window", (gx, depth / 2 + 0.03, 6.5), 1.0, 2.4, math.pi)
    for gx in (-4.4, 4.4):
        hip_roof("pfalz_dormer_roof", (gx, -depth / 2 + 1.1, 13.0), 1.8, 1.5, 1.1, PRIMARY)
        box("pfalz_dormer", (gx, -depth / 2 + 1.1, 12.5), (1.5, 1.2, 1.0), "castle_stone_light")
    chimney((2.4, 1.5, 15.0), 3.0)


def chapel():
    half_w, half_l = CHAPEL_WIDTH / 2, CHAPEL_LENGTH / 2
    box("chapel_nave", (0, 0, CHAPEL_HEIGHT / 2), (CHAPEL_WIDTH, CHAPEL_LENGTH, CHAPEL_HEIGHT),
        "castle_stone_light")
    box("chapel_plinth", (0, 0, 0.3), (CHAPEL_WIDTH + 0.4, CHAPEL_LENGTH + 0.4, 0.6), "castle_stone")
    gable_roof("chapel_roof", (0, 0, CHAPEL_HEIGHT), CHAPEL_LENGTH + 0.6, CHAPEL_WIDTH + 1.0, 4.2,
               "castle_slate", axis="y")
    for y, yaw in ((half_l, math.pi), (-half_l, 0.0)):
        with placed((0, y, 0), yaw):
            plate("chapel_gable", [(-half_w, CHAPEL_HEIGHT), (0, CHAPEL_HEIGHT + 4.2),
                                   (half_w, CHAPEL_HEIGHT)], 0.0, 0.3, "castle_stone_light")
    cone("chapel_apse", (0, half_l, 2.75), APSE_RADIUS, 5.5, "castle_stone_light", APSE_RADIUS, 12)
    cone("chapel_apse_roof", (0, half_l, 5.5 + 1.1), APSE_RADIUS + 0.4, 2.2, "castle_slate", 0.4, 12)
    for side in (-1, 1):
        for y, sill in CHAPEL_WINDOWS:
            with placed((side * (half_w + 0.03), y, 0), side * math.pi / 2):
                opening("chapel_window", (0, 0, sill), *CHAPEL_WINDOW)
        for y in (-half_l + 0.4, -1.3, 2.0, half_l - 0.4):
            box("chapel_buttress", (side * (half_w + 0.3), y, 2.4), (0.6, 0.7, 4.8), "castle_stone")
    for angle in APSE_WINDOWS:
        with placed((math.sin(angle) * (APSE_RADIUS + 0.03), half_l + math.cos(angle) * (APSE_RADIUS + 0.03),
                     0), math.pi - angle):
            opening("apse_window", (0, 0, 2.0), 0.6, 2.0)
    ty = -half_l - TOWER_SIZE / 2 + 0.3
    box("chapel_tower", (0, ty, 6.5), (TOWER_SIZE, TOWER_SIZE, 13.0), "castle_stone_light")
    quoins((0, ty), TOWER_SIZE, 0.0, 12.6, "castle_stone", rows=8)
    pyramid = cone("chapel_spire", (0, ty, 13.0 + 3.5), 2.5, 7.0, "castle_slate", vertices=4)
    pyramid.rotation_euler.z = math.pi / 4
    box("chapel_cross", (0, ty, 20.6), (0.12, 0.12, 1.3), "castle_gold")
    box("chapel_cross_arm", (0, ty, 20.85), (0.7, 0.12, 0.12), "castle_gold")
    for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
        with placed((0, ty, 0), yaw):
            opening("belfry", (0, -TOWER_SIZE / 2 - 0.03, 11.0), 0.7, 1.4)
    front = ty - TOWER_SIZE / 2 - 0.03
    door((0, front, 0.0), 1.4, 2.6)
    opening("chapel_portal", (0, front - 0.02, 0.0), 2.0, 3.2, color="castle_stone", depth=0.06)
    door((0, front - 0.05, 0.0), 1.4, 2.6)
    opening("chapel_rose", (0, front, ROSE_HEIGHT - 0.9), 1.8, 1.8)


def _pane(name, width, height, colors):
    """Stained glass pane facing -Y, bottom centre at the origin: coloured lights, gold tracery."""
    half = width / 2
    plate(name, [(-half, height - half), (0, height), (half, height - half)], 0.0, 0.05, colors[0])
    plate(name, [(-half, height - half), (0, height - half), (0, 0), (-half, 0)], 0.0, 0.05, colors[1])
    plate(name, [(0, height - half), (half, height - half), (half, 0), (0, 0)], 0.0, 0.05, colors[2])
    box("glass_lead", (0, -0.03, height / 2), (0.06, 0.04, height), "castle_dark")
    box("glass_lead", (0, -0.03, height * 0.45), (width, 0.04, 0.06), "castle_dark")


def stained_glass():
    half_w, half_l = CHAPEL_WIDTH / 2, CHAPEL_LENGTH / 2
    width, height = CHAPEL_WINDOW[0] - 0.16, CHAPEL_WINDOW[1] - 0.14
    sets = (("castle_glass_gold", "castle_glass_blue", "castle_glass_red"),
            ("castle_glass_red", "castle_glass_green", "castle_glass_blue"))
    for side in (-1, 1):
        for i, (y, sill) in enumerate(CHAPEL_WINDOWS):
            with placed((side * (half_w + 0.12), y, sill + 0.06), side * math.pi / 2):
                _pane("glass_pane", width, height, sets[i % 2])
    for i, angle in enumerate(APSE_WINDOWS):
        with placed((math.sin(angle) * (APSE_RADIUS + 0.12), half_l + math.cos(angle) * (APSE_RADIUS + 0.12),
                     2.06), math.pi - angle):
            _pane("glass_pane", 0.46, 1.86, sets[(i + 1) % 2])
    front = -half_l - TOWER_SIZE + 0.3 - 0.12
    colors = ("castle_glass_blue", "castle_glass_red")
    for i in range(8):
        a0, a1 = i * math.tau / 8, (i + 1) * math.tau / 8
        plate("glass_rose", [(0, ROSE_HEIGHT), (math.cos(a0) * 0.82, ROSE_HEIGHT + math.sin(a0) * 0.82),
                             (math.cos(a1) * 0.82, ROSE_HEIGHT + math.sin(a1) * 0.82)][::-1],
              front, 0.05, colors[i % 2])
    disc = cone("glass_rose_center", (0, front - 0.04, ROSE_HEIGHT), 0.28, 0.06, "castle_glass_gold", 0.28, 8)
    disc.rotation_euler.x = math.pi / 2
