"""Province buildings (data/economy.json `buildings`) as small set pieces, front facing -Y."""
import math
import random

from castle_decor import crane
from castle_shapes import (
    PRIMARY, SECONDARY, chimney, door, flag, gable_roof, half_timber, hip_roof, opening, placed,
)
from model_primitives import beam, box, cone, ico, plate


def mill():
    box("mill_ground", (0, 0, 1.5), (6.0, 5.0, 3.0), "castle_stone")
    half_timber((0, 0), 6.0, 5.0, 3.0, 5.4, 2.0)
    gable_roof("mill_roof", (0, 0, 5.4), 6.8, 5.8, 3.0, "castle_thatch")
    door((-1.2, -2.53, 0.0), 1.3, 2.2)
    opening("mill_window", (1.4, -2.53, 1.2), 0.7, 0.9, arch=False)
    wx, wz, radius = 3.75, 2.4, 2.3
    for x in (wx - 0.35, wx + 0.35):
        for i in range(12):
            a0, a1 = i * math.tau / 12, (i + 1) * math.tau / 12
            beam("wheel_rim", (x, math.cos(a0) * radius, wz + math.sin(a0) * radius),
                 (x, math.cos(a1) * radius, wz + math.sin(a1) * radius), 0.07, "castle_wood", vertices=4)
    for i in range(12):
        angle = i * math.tau / 12
        paddle = box("wheel_paddle", (wx, math.cos(angle) * (radius - 0.15), wz + math.sin(angle) *
                                      (radius - 0.15)), (0.85, 0.08, 0.55), "castle_wood_light")
        paddle.rotation_euler.x = angle
        if i % 2 == 0:
            beam("wheel_spoke", (wx, 0, wz), (wx, math.cos(angle) * radius, wz + math.sin(angle) * radius),
                 0.06, "castle_timber", vertices=4)
    beam("wheel_axle", (2.9, 0, wz), (wx + 0.6, 0, wz), 0.14, "castle_timber", vertices=6)
    box("millrace", (wx, 4.3, 4.9), (0.9, 4.6, 0.4), "castle_wood")
    box("millrace_water", (wx, 4.3, 5.1), (0.7, 4.6, 0.08), "castle_water")
    for y in (3.2, 5.6):
        box("millrace_trestle", (wx, y, 2.4), (0.25, 0.25, 4.8), "castle_timber")
    box("mill_pond", (wx + 0.2, -0.4, 0.05), (2.8, 7.5, 0.1), "castle_water")
    for y in (-4.3, 3.5):
        box("mill_pond_edge", (wx + 0.2, y, 0.15), (3.0, 0.4, 0.3), "castle_stone_dark")
    for x in (-2.4, -2.0):
        ico("mill_sack", (x, -3.1, 0.35), (0.3, 0.25, 0.38), "castle_linen")


def _stall(at, yaw, stripes):
    with placed(at, yaw):
        for x in (-1.3, 1.3):
            for y, h in ((-0.9, 2.5), (0.9, 2.9)):
                box("stall_post", (x, y, h / 2), (0.12, 0.12, h), "castle_timber")
        box("stall_counter", (0, -0.7, 0.5), (2.8, 0.8, 1.0), "castle_wood")
        for i in range(6):
            awning = box("stall_awning", (-1.5 + i * 0.6 + 0.3, 0.0, 2.75), (0.6, 2.2, 0.06), stripes[i % 2])
            awning.rotation_euler.x = 0.22
        for i, color in enumerate(("castle_glass_gold", "castle_rose", "castle_hedge", "castle_linen")):
            ico("stall_goods", (-1.0 + i * 0.66, -0.75, 1.15), (0.24, 0.24, 0.18), color)


def _market_square(stalls):
    box("market_paving", (0, 0, 0.03), (12.0, 9.0, 0.06), "castle_stone_light")
    for at, yaw, stripes in stalls:
        _stall(at, yaw, stripes)
    for x, y in ((4.8, -3.4), (5.3, -2.8), (-5.0, 3.2)):
        cone("market_barrel", (x, y, 0.45), 0.38, 0.9, "castle_wood_light", 0.33, 8)
    for x, y in ((-4.6, -3.3), (-4.0, -3.5)):
        box("market_crate", (x, y, 0.3), (0.6, 0.6, 0.6), "castle_wood")


def market_1():
    _market_square([((-3.0, 1.8, 0), 0.0, ("castle_awning", "castle_linen")),
                    ((2.4, 2.0, 0), 0.0, ("castle_hedge", "castle_linen")),
                    ((4.2, -1.2, 0), math.pi / 2, (PRIMARY, SECONDARY))])


def market_2():
    _market_square([((-4.6, -1.6, 0), -math.pi / 2, ("castle_awning", "castle_linen")),
                    ((4.6, -1.8, 0), math.pi / 2, (PRIMARY, SECONDARY)),
                    ((-2.2, -3.6, 0), 0.2, ("castle_hedge", "castle_linen")),
                    ((2.6, -3.7, 0), -0.2, ("castle_awning", "castle_linen"))])
    for x in (-4.0, -1.35, 1.35, 4.0):
        for y in (0.6, 3.6):
            box("hall_pillar", (x, y, 1.6), (0.55, 0.55, 3.2), "castle_stone")
    box("hall_floor", (0, 2.1, 3.3), (9.4, 4.0, 0.25), "castle_timber")
    half_timber((0, 2.1), 9.4, 4.0, 3.4, 6.0, 1.6)
    gable_roof("hall_roof", (0, 2.1, 6.0), 10.2, 4.9, 3.6, "castle_roof_tile")
    for x in (-3.0, 0.0, 3.0):
        opening("hall_window", (x, 0.07, 4.2), 0.8, 1.1, arch=False)
    hip_roof("hall_lantern_roof", (0, 2.1, 9.7), 1.0, 1.0, 1.2, "castle_slate")
    box("hall_lantern", (0, 2.1, 9.45), (0.8, 0.8, 0.5), "castle_wood_light")
    box("market_cross_step", (0, -1.4, 0.2), (1.4, 1.4, 0.4), "castle_stone")
    beam("market_cross", (0, -1.4, 0.4), (0, -1.4, 3.6), 0.14, "castle_stone_light", vertices=6)
    box("market_cross_arm", (0, -1.4, 3.1), (1.0, 0.18, 0.18), "castle_stone_light")
    flag((0, 2.1, 10.1), 1.8, 1.2, 0.7)


def granary():
    for x in (-3.2, 0.0, 3.2):
        for y in (-1.9, 0.0, 1.9):
            cone("staddle_stem", (x, y, 0.4), 0.25, 0.8, "castle_stone", 0.15, 6)
            cone("staddle_cap", (x, y, 0.88), 0.45, 0.16, "castle_stone_light", 0.45, 6)
    box("granary_floor", (0, 0, 1.08), (8.0, 4.8, 0.25), "castle_timber")
    box("granary_walls", (0, 0, 3.2), (7.6, 4.4, 4.0), "castle_wood")
    for i in range(9):
        x = -3.6 + i * 0.9
        for y in (-2.23, 2.23):
            box("granary_batten", (x, y, 3.2), (0.12, 0.08, 4.0), "castle_timber")
    gable_roof("granary_roof", (0, 0, 5.2), 8.6, 5.6, 4.0, "castle_thatch")
    door((0, -2.25, 1.25), 1.2, 2.0)
    for i in range(3):
        box("granary_step", (0, -2.7 - i * 0.35, 0.9 - i * 0.3), (1.2, 0.35, 0.12), "castle_wood_light")
    beam("hoist_beam", (-3.6, 0, 8.6), (-5.0, 0, 8.6), 0.12, "castle_timber", vertices=4)
    beam("hoist_rope", (-4.9, 0, 8.55), (-4.9, 0, 4.2), 0.025, "castle_linen", vertices=4)
    ico("hoist_sack", (-4.9, 0, 3.8), (0.32, 0.28, 0.45), "castle_linen")
    for x in (2.6, 3.1):
        ico("granary_sack", (x, -2.9, 0.35), (0.3, 0.25, 0.38), "castle_linen")


def monastery():
    # Church along X at the back, cloister ranges round a garth in front.
    box("church_nave", (0, 5.0, 4.0), (14.0, 7.0, 8.0), "castle_stone_light")
    gable_roof("church_roof", (0, 5.0, 8.0), 14.6, 8.0, 4.6, "castle_slate")
    cone("church_apse", (7.0, 5.0, 3.0), 3.0, 6.0, "castle_stone_light", 3.0, 10)
    cone("church_apse_roof", (7.0, 5.0, 7.2), 3.4, 2.4, "castle_slate", 0.4, 10)
    box("church_tower", (-8.6, 5.0, 9.0), (4.2, 4.2, 18.0), "castle_stone_light")
    pyramid = cone("church_spire", (-8.6, 5.0, 18.0 + 3.8), 3.2, 7.6, "castle_slate", vertices=4)
    pyramid.rotation_euler.z = math.pi / 4
    box("church_cross", (-8.6, 5.0, 26.3), (0.14, 0.14, 1.5), "castle_gold")
    box("church_cross_arm", (-8.6, 5.0, 26.6), (0.8, 0.14, 0.14), "castle_gold")
    for x in (-4.5, -1.5, 1.5, 4.5):
        opening("church_window", (x, 1.47, 3.2), 0.8, 2.6)
    for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
        with placed((-8.6, 5.0, 0), yaw):
            opening("church_belfry", (0, -2.13, 14.5), 0.8, 1.6)
    door((-8.6, 2.87, 0.0), 1.5, 2.8)
    for name, center, size, axis in (("cloister_west", (-6.0, -4.5), (3.2, 12.0), "y"),
                                     ("cloister_east", (6.0, -4.5), (3.2, 12.0), "y"),
                                     ("cloister_south", (0, -9.0), (8.8, 3.0), "x")):
        box(name, (center[0], center[1], 2.0), (size[0], size[1], 4.0), "castle_plaster")
        length = size[1] if axis == "y" else size[0]
        depth = size[0] if axis == "y" else size[1]
        gable_roof(name + "_roof", (center[0], center[1], 4.0), length + 0.4, depth + 0.6, 2.2,
                   "castle_roof_tile", axis=axis)
    box("cloister_garth", (0, -3.3, 0.05), (8.8, 8.4, 0.1), "castle_grass")
    for x in (-3.6, -1.2, 1.2, 3.6):
        box("cloister_arch", (x, -7.4, 1.1), (0.3, 0.3, 2.2), "castle_stone_light")
    for y in (-5.6, -3.0, -0.4):
        for x in (-4.3, 4.3):
            box("cloister_arch", (x, y, 1.1), (0.3, 0.3, 2.2), "castle_stone_light")
    cone("cloister_well", (0, -3.3, 0.45), 0.8, 0.9, "castle_stone", 0.8, 8)
    for i in range(3):
        box("herb_bed", (-2.6 + i * 2.6, -12.6, 0.12), (1.8, 1.4, 0.24), "castle_earth")
        for j in range(3):
            ico("herb", (-3.1 + i * 2.6 + j * 0.5, -12.6, 0.36), (0.22, 0.22, 0.18), "castle_hedge")
    for y in (-14.0,):
        box("garden_wall", (0, y, 0.6), (9.0, 0.4, 1.2), "castle_stone")


def mine():
    rng = random.Random(5)
    cone("mine_hill", (0, 4.5, 2.0), 7.5, 4.0, "castle_grass", 3.5, 10)
    for i in range(6):
        angle = i * 0.9 - 2.2
        at = (math.cos(angle) * 3.5, 3.0 + math.sin(angle) * 2.0, 2.0 + rng.uniform(0, 1.5))
        rock = ico("mine_rock", at, (rng.uniform(1.6, 2.4), rng.uniform(1.3, 2.0), rng.uniform(1.3, 2.2)),
                   "castle_rock")
        rock.rotation_euler = (rng.uniform(0, 1), rng.uniform(0, 1), rng.uniform(0, 3))
    box("mine_face", (0, 1.3, 1.8), (3.4, 1.2, 3.6), "castle_rock")
    opening("mine_entrance", (0, 0.68, 0.0), 1.9, 2.4, arch=False)
    for x in (-1.1, 1.1):
        box("mine_post", (x, 0.5, 1.3), (0.3, 0.3, 2.6), "castle_timber")
    box("mine_lintel", (0, 0.5, 2.7), (2.8, 0.35, 0.35), "castle_timber")
    for x in (-0.45, 0.45):
        box("mine_rail", (x, -3.0, 0.12), (0.08, 7.0, 0.08), "castle_iron")
    for i in range(8):
        box("mine_sleeper", (0, 0.2 - i * 0.9, 0.05), (1.3, 0.22, 0.1), "castle_timber")
    box("mine_cart", (0, -4.2, 0.65), (1.1, 1.5, 0.7), "castle_wood")
    for x in (-0.5, 0.5):
        for y in (-4.7, -3.7):
            wheel = cone("cart_wheel", (x, y, 0.25), 0.25, 0.1, "castle_iron", 0.25, 6)
            wheel.rotation_euler.y = math.pi / 2
    for i in range(3):
        ico("mine_ore", (-0.25 + i * 0.25, -4.2, 1.05), (0.25, 0.25, 0.2), "castle_stone_dark")
    cone("mine_spoil", (3.6, -2.2, 0.8), 2.4, 1.6, "castle_earth", 0.3, 8)
    box("mine_shed", (-3.6, -2.0, 1.1), (2.4, 2.0, 2.2), "castle_wood")
    gable_roof("mine_shed_roof", (-3.6, -2.0, 2.2), 2.8, 2.6, 1.1, "castle_shingle")


def toll():
    box("toll_ground", (6.0, 0, 1.5), (4.6, 4.6, 3.0), "castle_stone")
    half_timber((6.0, 0), 4.6, 4.6, 3.0, 5.2, 1.6)
    hip_roof("toll_roof", (6.0, 0, 5.2), 5.4, 5.4, 3.0, "castle_roof_tile")
    door((6.0, -2.33, 0.0), 1.1, 2.1)
    opening("toll_window", (3.67, 0.8, 1.2), 0.8, 0.9, -math.pi / 2, arch=False)
    box("boom_post", (3.2, -2.6, 0.6), (0.4, 0.4, 1.2), "castle_timber")
    for i in range(5):
        color = "castle_awning" if i % 2 == 0 else "castle_linen"
        beam("toll_boom", (3.2 - i * 1.4, -2.6, 1.25), (3.2 - (i + 1) * 1.4, -2.6, 1.25), 0.09, color,
             vertices=4)
    box("boom_weight", (4.0, -2.6, 1.25), (1.0, 0.4, 0.5), "castle_stone_dark")
    for x in (-3.9, -3.5):
        box("boom_rest", (x, -2.6, 0.55), (0.14, 0.14, 1.1), "castle_timber")
    box("sentry_box", (-5.0, -1.0, 1.3), (1.4, 1.4, 2.6), "castle_wood")
    hip_roof("sentry_roof", (-5.0, -1.0, 2.6), 1.8, 1.8, 0.9, "castle_shingle")
    opening("sentry_door", (-5.0, -1.73, 0.0), 0.8, 1.9, arch=False)
    box("toll_sign_post", (3.6, -3.4, 1.2), (0.14, 0.14, 2.4), "castle_timber")
    plate("toll_sign", [(3.15, 2.6), (4.05, 2.6), (4.05, 2.0), (3.6, 1.6), (3.15, 2.0)], -3.5, 0.08, PRIMARY)
    plate("toll_sign_band", [(3.45, 2.6), (3.75, 2.6), (3.75, 1.8), (3.6, 1.65), (3.45, 1.8)], -3.56, 0.06,
          SECONDARY)


def tourney_ground():
    half_x, half_y = 17.0, 7.0
    for i in range(11):
        x = -half_x + i * (2 * half_x / 10)
        for y in (-half_y, half_y):
            box("lists_post", (x, y, 0.65), (0.2, 0.2, 1.3), "castle_timber")
    for i in range(5):
        y = -half_y + i * (2 * half_y / 4)
        for x in (-half_x, half_x):
            box("lists_post", (x, y, 0.65), (0.2, 0.2, 1.3), "castle_timber")
    for z in (0.6, 1.15):
        for y in (-half_y, half_y):
            box("lists_rail", (0, y, z), (2 * half_x, 0.12, 0.14), "castle_wood_light")
        for x in (-half_x, half_x):
            box("lists_rail", (x, 0, z), (0.12, 2 * half_y, 0.14), "castle_wood_light")
    for i in range(6):
        x = -12.0 + i * 4.0 + 2.0
        box("tilt_panel", (x, 0, 0.75), (4.0, 0.16, 1.0), PRIMARY if i % 2 == 0 else SECONDARY)
    box("lists_sand", (0, 0, 0.02), (2 * half_x, 2 * half_y, 0.04), "castle_linen")
    for tier in range(3):
        box("stand_tier", (0, half_y + 1.4 + tier * 1.0, 0.35 + tier * 0.6), (14.0, 1.1, 0.7 + tier * 1.2),
            "castle_wood")
    box("stand_back", (0, half_y + 4.2, 2.2), (14.0, 0.25, 4.4), "castle_wood_light")
    for x in (-7.0, -2.3, 2.3, 7.0):
        box("stand_post", (x, half_y + 1.0, 2.2), (0.2, 0.2, 4.4), "castle_timber")
    canopy = box("stand_canopy", (0, half_y + 2.6, 4.6), (14.6, 3.8, 0.12), PRIMARY)
    canopy.rotation_euler.x = 0.12
    for i in range(7):
        plate("canopy_valance", [(-7.3 + i * 2.1, 4.45), (-5.2 + i * 2.1, 4.45), (-6.25 + i * 2.1, 3.9)],
              half_y + 0.7, 0.05, SECONDARY)
    box("royal_box", (0, half_y + 1.2, 1.4), (3.0, 0.2, 1.0), "castle_gold")
    for x in (-half_x - 3.0, half_x + 3.0):
        cone("pavilion_wall", (x, 0, 1.2), 2.2, 2.4, PRIMARY, 2.2, 10)
        cone("pavilion_roof", (x, 0, 3.4), 2.6, 2.0, SECONDARY, 0.0, 10)
        flag((x, 0, 4.3), 1.6, 1.0, 0.6)
    for x in (-6.0, 6.0):
        flag((x, half_y + 4.4, 4.4), 2.0, 1.2, 0.7)


def workshop():
    for x in (-4.2, 0.0, 4.2):
        for y, h in ((-2.4, 3.6), (2.4, 2.6)):
            box("shed_post", (x, y, h / 2), (0.25, 0.25, h), "castle_timber")
    roof = box("shed_roof", (0, 0, 3.15), (9.4, 5.8, 0.18), "castle_shingle")
    roof.rotation_euler.x = -0.18
    box("shed_back", (0, 2.45, 1.3), (8.4, 0.15, 2.6), "castle_wood")
    box("workbench", (-1.5, 0.3, 0.45), (3.2, 1.0, 0.9), "castle_wood_light")
    rng = random.Random(3)
    for i in range(5):
        block = box("dressed_stone", (2.0 + (i % 3) * 0.9, -0.8 + (i // 3) * 1.0, 0.3), (0.8, 0.7, 0.6),
                    "castle_stone_light")
        block.rotation_euler.z = rng.uniform(-0.15, 0.15)
    for i in range(4):
        beam("lodge_timber", (-4.0, -4.0 + i * 0.25, 0.12 + (i % 2) * 0.2), (0.0, -4.1 + i * 0.25,
                                                                           0.12 + (i % 2) * 0.2),
             0.1, "castle_wood_light", vertices=6)
    box("tracing_floor", (-1.5, -4.6, 0.04), (3.0, 2.0, 0.08), "castle_plaster")
    with placed((7.0, -1.0, 0), math.pi):
        crane()
    box("wall_stub", (9.0, 3.0, 1.2), (5.0, 1.2, 2.4), "castle_stone")
    for i in range(3):
        box("wall_stub_course", (8.0 + i * 1.2, 3.0, 2.7), (1.0, 1.1, 0.55), "castle_stone_light")
