"""Castle pieces: each home castle level and province castle level combines some of them
(data/castle_art.json). Pieces that belong to the castle ring (curtain wall, tower roofs,
palisades) are modelled around the castle centre; the others around their own foot."""
import math

from castle_shapes import (
    PRIMARY, SECONDARY, door, flag, gable_roof, hip_roof, merlons_line, opening, placed,
    quoins, ring_points, round_tower, spire, square_tower, stairs, wall,
)
from model_primitives import beam, box, cone, plate, sphere

WALL_RADIUS = 21.0
WALL_HEIGHT = 7.0
TOWER_RADIUS = 2.6
TOWER_HEIGHT = 10.5
MOTTE_HEIGHT = 4.0
KEEP_SIZE = 7.0
KEEP_HEIGHT = 17.0
GATE_TURRETS = ((-4.6, -2.4), (4.6, -2.4))
GATE_TURRET_HEIGHT = 13.0


def wall_corners():
    return ring_points(WALL_RADIUS, WALL_RADIUS, 8, math.pi / 8)


def motte():
    cone("motte_mound", (0, 0, MOTTE_HEIGHT / 2), 7.8, MOTTE_HEIGHT, "castle_grass", 5.3, 14)
    cone("motte_yard", (0, 0, MOTTE_HEIGHT + 0.04), 5.4, 0.08, "castle_earth", 5.4, 14)
    cone("motte_ditch", (0, 0, 0.03), 8.9, 0.06, "castle_earth", 8.9, 16)
    # Wooden stair from the bailey up to the yard on the mound.
    stairs((0, -12.2, 0.0), (0, -5.2, MOTTE_HEIGHT), 1.6, 11)
    for x in (-0.85, 0.85):
        beam("motte_rail", (x, -12.2, 1.0), (x, -5.2, MOTTE_HEIGHT + 1.0), 0.05, "castle_timber",
             vertices=4)
        for y in (-9.9, -7.6):
            z = (y + 12.2) / 7.0 * MOTTE_HEIGHT
            box("motte_trestle", (x, y, z / 2), (0.22, 0.22, z), "castle_timber")


def wood_tower():
    size, body = 4.4, 6.0
    box("tower_planks", (0, 0, body / 2), (size, size, body), "castle_wood")
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("tower_post", (sx * size / 2, sy * size / 2, 3.9), (0.32, 0.32, 7.8), "castle_timber")
    for z in (0.3, 3.0, body):
        box("tower_band", (0, 0, z), (size + 0.15, size + 0.15, 0.22), "castle_timber")
    box("tower_gallery", (0, 0, 6.85), (5.6, 5.6, 1.7), "castle_wood_light")
    for i in range(3):
        for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
            with placed((0, 0, 0), yaw):
                opening("tower_loophole", (-1.6 + i * 1.6, -2.83, 6.5), 0.35, 0.7, arch=False)
    hip_roof("tower_roof", (0, 0, 7.7), 6.4, 6.4, 3.2, "castle_shingle")
    door((0, -2.24, 0.0), 1.1, 2.0)
    beam("tower_brace", (-2.2, -2.27, 3.0), (2.2, -2.27, 5.9), 0.08, "castle_timber", vertices=4)
    flag((0, 0, 10.6), 2.2, 1.5, 0.85)


def keep():
    half = KEEP_SIZE / 2
    box("keep_plinth", (0, 0, 0.6), (KEEP_SIZE + 0.8, KEEP_SIZE + 0.8, 1.2), "castle_stone_dark")
    box("keep_body", (0, 0, KEEP_HEIGHT / 2 - 0.03), (KEEP_SIZE, KEEP_SIZE, KEEP_HEIGHT - 0.06),
        "castle_stone")
    box("keep_course", (0, 0, 11.5), (KEEP_SIZE + 0.25, KEEP_SIZE + 0.25, 0.35), "castle_stone_light")
    box("keep_corbel", (0, 0, KEEP_HEIGHT - 0.45), (KEEP_SIZE + 0.7, KEEP_SIZE + 0.7, 0.9),
        "castle_stone_light")
    quoins((0, 0), KEEP_SIZE, 1.2, KEEP_HEIGHT - 0.9, rows=9)
    edge = half + 0.1
    for start, end in (((-edge, -edge), (edge, -edge)), ((edge, -edge), (edge, edge)),
                       ((edge, edge), (-edge, edge)), ((-edge, edge), (-edge, -edge))):
        merlons_line(start, end, KEEP_HEIGHT, "castle_stone_light", (0.75, 0.55, 0.9), 1.45)
    for yaw in (0, math.pi / 2, math.pi, -math.pi / 2):
        with placed((0, 0, 0), yaw):
            for z in (8.2, 13.0):
                opening("keep_slit", (0, -half - 0.03, z), 0.5, 1.3)
    opening("keep_door", (0, -half - 0.03, 4.6), 1.2, 2.2, color="castle_timber")
    box("keep_landing", (0, -half - 0.7, 4.45), (1.9, 1.4, 0.25), "castle_wood")
    stairs((3.6, -half - 1.0, 0.0), (0.9, -half - 1.0, 4.5), 1.0, 8)
    flag((0, 0, KEEP_HEIGHT), 3.2, 1.9, 1.1)


def keep_spire():
    """Spire crowning the keep; its pivot is the keep's top so it can grow from there."""
    half = KEEP_SIZE / 2
    box("spire_drum", (0, 0, 1.2), (5.6, 5.6, 2.4), "castle_stone_light")
    pyramid = cone("spire_roof", (0, 0, 2.4 + 4.75), 4.4, 9.5, PRIMARY, vertices=4)
    pyramid.rotation_euler.z = math.pi / 4
    box("spire_eave", (0, 0, 2.45), (6.4, 6.4, 0.2), "castle_timber")
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (half + 0.15), sy * (half + 0.15)
            cone("bartizan_corbel", (x, y, -1.4), 0.25, 1.4, "castle_stone_light", 1.0, 8)
            cone("bartizan", (x, y, 0.9), 1.0, 3.2, "castle_stone_light", 1.0, 8)
            spire("bartizan_roof", (x, y, 2.5), 1.25, 2.6, PRIMARY)
            sphere("bartizan_finial", (x, y, 5.2), (0.16, 0.16, 0.16), "castle_gold", segments=6, rings=4)
    top = 2.4 + 9.5
    sphere("spire_orb", (0, 0, top + 0.2), (0.35, 0.35, 0.35), "castle_gold", segments=8, rings=5)
    box("spire_cross", (0, 0, top + 1.0), (0.12, 0.12, 1.3), "castle_gold")
    box("spire_cross_arm", (0, 0, top + 1.25), (0.7, 0.12, 0.12), "castle_gold")
    for sign in (-1, 1):
        opening("spire_dormer", (0, sign * 2.83, 0.35), 0.8, 1.4, 0.0 if sign < 0 else math.pi)


def stake_panel(start, end, height, seed):
    """One stretch of palisade: pointed stakes as a zig-zag plank, front facing outward."""
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = math.hypot(dx, dy)
    count = max(2, round(length / 0.5))
    width = length / count
    outline = []
    for i in range(count):
        top = height + 0.25 * math.sin(seed * 1.7 + i * 2.3)
        outline += [(-length / 2 + i * width + 0.03, top), (-length / 2 + (i + 0.5) * width, top + 0.5)]
    outline += [(length / 2 - 0.03, height), (length / 2, 0.0), (-length / 2, 0.0)]
    with placed(((start[0] + end[0]) / 2, (start[1] + end[1]) / 2, 0), math.atan2(dy, dx)):
        plate("palisade_stakes", outline, 0.0, 0.32, "castle_wood")


def palisade_ring(radius_x, radius_y, center_y, gate_width, height=3.2):
    perimeter = math.tau * math.sqrt((radius_x ** 2 + radius_y ** 2) / 2)
    count = round(perimeter / 2.5)
    points = ring_points(radius_x, radius_y, count, -math.pi / 2 + math.pi / count, (0, center_y))
    gap = 0.0
    for i in range(count):
        start, end = points[i], points[(i + 1) % count]
        if start[1] < center_y and abs((start[0] + end[0]) / 2) < gate_width / 2 + 1.0:
            gap = max(gap, abs(start[0]), abs(end[0]))
            continue
        stake_panel(start, end, height, i)
    front = center_y - radius_y
    passage = gap - 1.9
    for side in (-1, 1):
        x = side * (gap - 0.95)
        for ox in (-0.7, 0.7):
            for oy in (-0.7, 0.7):
                box("gate_post", (x + ox, front + oy, 2.6), (0.3, 0.3, 5.2), "castle_timber")
        box("gate_platform", (x, front, 4.4), (1.9, 1.9, 0.25), "castle_wood_light")
        box("gate_parapet", (x, front - 0.85, 4.95), (1.9, 0.12, 0.9), "castle_wood")
        hip_roof("gate_roof", (x, front, 5.6), 2.4, 2.4, 1.3, "castle_shingle")
        # Gate leaves stand open into the bailey.
        angle = 1.2
        direction = (-side * math.cos(angle), math.sin(angle))
        leaf = box("gate_leaf", (side * passage + direction[0] * passage / 2,
                                 front + direction[1] * passage / 2, 1.5),
                   (passage - 0.1, 0.18, 3.0), "castle_wood_light")
        leaf.rotation_euler.z = math.atan2(direction[1], direction[0])
    box("gate_lintel", (0, front, 4.6), (gap * 2, 0.35, 0.35), "castle_timber")


def palisade():
    palisade_ring(16.0, 18.5, 1.5, 4.0)


def palisade_small():
    palisade_ring(11.0, 11.0, 0.0, 3.6, 2.9)


def curtain_wall():
    corners = wall_corners()
    for i in range(8):
        start, end = corners[i], corners[(i + 1) % 8]
        if start[1] < -WALL_RADIUS * 0.9 and end[1] < -WALL_RADIUS * 0.9:
            gap = 4.5 * (1 if start[0] > end[0] else -1)
            wall(start, (gap, start[1]), WALL_HEIGHT, 1.8, "castle_stone", "castle_stone_light")
            wall((-gap, end[1]), end, WALL_HEIGHT, 1.8, "castle_stone", "castle_stone_light")
        else:
            wall(start, end, WALL_HEIGHT, 1.8, "castle_stone", "castle_stone_light")
    for x, y in corners:
        round_tower((x, y), TOWER_RADIUS, TOWER_HEIGHT, "castle_stone", 8, 10, "castle_stone_light")
        with placed((x, y, 0), math.atan2(y, x) + math.pi / 2):
            opening("tower_slit", (0, -TOWER_RADIUS - 0.02, 6.0), 0.45, 1.2)


def gatehouse():
    width, depth, height = 9.0, 7.0, 11.5
    box("gate_block", (0, 0, height / 2 - 0.03), (width, depth, height - 0.06), "castle_stone")
    box("gate_course", (0, 0, height - 0.5), (width + 0.6, depth + 0.6, 1.0), "castle_stone_light")
    merlons_line((-width / 2 - 0.1, -depth / 2 - 0.1), (width / 2 + 0.1, -depth / 2 - 0.1), height,
                 "castle_stone_light")
    merlons_line((width / 2 + 0.1, depth / 2 + 0.1), (-width / 2 - 0.1, depth / 2 + 0.1), height,
                 "castle_stone_light")
    for sign in (-1, 1):
        opening("gate_arch", (0, sign * (depth / 2 + 0.03), 0.0), 3.6, 5.4, 0.0 if sign < 0
                else math.pi)
    for i in range(5):
        box("portcullis_bar", (-1.4 + i * 0.7, -depth / 2 - 0.12, 2.0), (0.12, 0.1, 3.4), "castle_iron")
    for z in (1.0, 2.4):
        box("portcullis_rail", (0, -depth / 2 - 0.12, z), (3.2, 0.1, 0.12), "castle_iron")
    for x, y in GATE_TURRETS:
        round_tower((x, y), 2.2, GATE_TURRET_HEIGHT, "castle_stone", 7, 10, "castle_stone_light")
        opening("turret_slit", (x, y - 2.22, 7.5), 0.45, 1.2)
    bridge = box("drawbridge", (0, -depth / 2 - 2.7, 0.18), (3.6, 5.4, 0.3), "castle_wood")
    bridge.rotation_euler.x = 0.05
    for x in (-1.6, 1.6):
        beam("drawbridge_chain", (x, -depth / 2 - 5.2, 0.4), (x, -depth / 2 - 0.05, 6.4), 0.05,
             "castle_iron", vertices=4)
    plate("gate_shield", [(-1.0, 8.9), (1.0, 8.9), (1.0, 7.9), (0.0, 6.7), (-1.0, 7.9)],
          -depth / 2 - 0.05, 0.12, PRIMARY)
    plate("gate_shield_bend", [(-0.25, 8.9), (0.25, 8.9), (0.25, 6.95), (0.0, 6.7), (-0.25, 6.95)],
          -depth / 2 - 0.12, 0.1, SECONDARY)


def tower_roof():
    """Conical roof on a raised drum for one wall tower; pivot on the tower top."""
    radius = TOWER_RADIUS
    cone("roof_drum", (0, 0, 1.5), radius + 0.15, 3.0, "castle_stone_light", radius + 0.15, 10)
    spire("tower_roof", (0, 0, 3.0), radius + 0.75, radius * 2.3, PRIMARY, 10)
    sphere("roof_finial", (0, 0, 3.0 + radius * 2.3 + 0.15), (0.22, 0.22, 0.22), "castle_gold",
           segments=6, rings=4)


def wood_hall():
    length, depth, height = 9.0, 5.0, 3.2
    box("hall_planks", (0, 0, height / 2), (length, depth, height), "castle_wood")
    for x in (-length / 2, -length / 6, length / 6, length / 2):
        for y in (-depth / 2, depth / 2):
            box("hall_post", (x, y, height / 2), (0.3, 0.3, height), "castle_timber")
    box("hall_sill", (0, 0, 0.2), (length + 0.2, depth + 0.2, 0.4), "castle_stone_dark")
    gable_roof("hall_roof", (0, 0, height), length + 1.0, depth + 1.2, 3.2, "castle_thatch")
    door((0, -depth / 2 - 0.04, 0.0), 1.3, 2.2)
    for x in (-3.0, 3.0):
        opening("hall_window", (x, -depth / 2 - 0.04, 1.3), 0.7, 0.8, arch=False)
    box("hall_smoke_hood", (1.8, 0, height + 2.6), (0.8, 0.8, 0.7), "castle_wood_light")


def wall_small():
    half, height = 11.0, 6.0
    corners = [(-half, -half), (half, -half), (half, half), (-half, half)]
    for i in range(4):
        start, end = corners[i], corners[(i + 1) % 4]
        if i == 0:
            wall(start, (-2.6, -half), height, 1.4, "castle_stone", "castle_stone_light")
            wall((2.6, -half), end, height, 1.4, "castle_stone", "castle_stone_light")
        else:
            wall(start, end, height, 1.4, "castle_stone", "castle_stone_light")
    for x, y in corners:
        square_tower((x, y), 3.6, 8.5, "castle_stone", top="castle_stone_light")
        quoins((x, y), 3.6, 0.0, 7.6, rows=5)
    box("gate_tower", (0, -half, 4.5), (5.6, 3.4, 9.0), "castle_stone")
    merlons_line((-2.8, -half - 1.6), (2.8, -half - 1.6), 9.0, "castle_stone_light", (0.6, 0.5, 0.8), 1.4)
    for sign in (-1, 1):
        opening("gate_arch", (0, -half + sign * 1.73, 0.0), 3.0, 4.4, 0.0 if sign < 0 else math.pi)
    opening("gate_window", (0, -half - 1.73, 6.2), 0.7, 1.3)
