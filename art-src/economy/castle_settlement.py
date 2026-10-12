"""Settlement house variants around the castle; their number follows the province population."""
from castle_shapes import chimney, door, gable_roof, half_timber, hip_roof, opening
from model_primitives import box, cone


def cottage():
    box("cottage_walls", (0, 0, 1.2), (4.2, 3.4, 2.4), "castle_plaster")
    for x in (-2.1, 2.1):
        for y in (-1.7, 1.7):
            box("cottage_post", (x, y, 1.2), (0.22, 0.22, 2.4), "castle_timber")
    gable_roof("cottage_roof", (0, 0, 2.3), 5.0, 4.4, 2.6, "castle_thatch")
    door((-0.8, -1.73, 0.0), 0.9, 1.9)
    opening("cottage_window", (0.9, -1.73, 1.0), 0.6, 0.6, arch=False)
    box("cottage_bench", (0.9, -2.05, 0.25), (1.2, 0.35, 0.08), "castle_wood")


def house():
    box("house_plinth", (0, 0, 0.25), (5.2, 4.2, 0.5), "castle_stone")
    half_timber((0, 0), 5.0, 4.0, 0.5, 3.3, 1.7)
    gable_roof("house_roof", (0, 0, 3.3), 5.8, 4.9, 2.9, "castle_roof_tile")
    chimney((1.4, 0.8, 4.6), 2.0)
    door((-1.2, -2.04, 0.5), 0.95, 2.0)
    for x in (0.6, 1.8):
        opening("house_window", (x, -2.04, 1.5), 0.6, 0.75, arch=False)


def longhouse():
    box("longhouse_walls", (0, 0, 1.1), (8.0, 4.4, 2.2), "castle_wood")
    for x in (-4.0, -1.3, 1.3, 4.0):
        for y in (-2.2, 2.2):
            box("longhouse_post", (x, y, 1.1), (0.25, 0.25, 2.2), "castle_timber")
    hip_roof("longhouse_roof", (0, 0, 2.1), 9.0, 5.4, 3.0, "castle_thatch")
    door((-2.4, -2.23, 0.0), 1.0, 1.9)
    door((2.2, -2.23, 0.0), 1.8, 1.9)
    for i in range(6):
        x = -4.0 + i * 1.6
        box("pen_post", (x, -4.6, 0.5), (0.14, 0.14, 1.0), "castle_timber")
    for z in (0.4, 0.85):
        box("pen_rail", (0, -4.6, z), (8.0, 0.08, 0.1), "castle_wood_light")
    for x in (-4.0, 4.0):
        box("pen_rail", (x, -3.4, 0.85), (0.08, 2.4, 0.1), "castle_wood_light")
    cone("haystack", (5.4, 1.4, 1.0), 1.3, 2.0, "castle_thatch", 0.25, 8)


def townhouse():
    box("townhouse_ground", (0, 0, 1.5), (4.4, 5.4, 3.0), "castle_stone_light")
    half_timber((0, -0.2), 4.8, 5.8, 3.0, 6.0, 1.5)
    gable_roof("townhouse_roof", (0, -0.2, 6.0), 6.4, 5.4, 4.2, "castle_roof_tile", axis="y")
    door((-1.0, -2.73, 0.0), 1.0, 2.2)
    opening("townhouse_shop", (0.9, -2.73, 0.8), 1.3, 1.1, arch=False)
    box("shop_shutter", (0.9, -3.05, 0.75), (1.4, 0.6, 0.08), "castle_wood_light")
    for x in (-1.2, 1.2):
        opening("townhouse_window", (x, -3.15, 3.9), 0.7, 0.9, arch=False)
    opening("townhouse_gable_window", (0, -3.15, 6.8), 0.6, 0.8, arch=False)
    chimney((1.2, 1.4, 7.4), 1.8)
    box("townhouse_sign_arm", (2.4, -3.0, 2.6), (0.9, 0.08, 0.08), "castle_iron")
    box("townhouse_sign", (2.75, -3.0, 2.2), (0.5, 0.06, 0.6), "castle_gold")
