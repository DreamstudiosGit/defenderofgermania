from model_primitives import METALLIC, PALETTE
from unit_palette import linear

# Muted building palette shared by every castle, building and settlement piece (sRGB hex).
# house_primary / house_secondary come from unit_palette (white, tinted by the game).
CASTLE_COLORS = {
    "castle_stone": "a59b87", "castle_stone_dark": "7a7262", "castle_stone_light": "cfc3a6",
    "castle_plaster": "e6d9ba", "castle_timber": "5a3b22", "castle_wood": "8a6038",
    "castle_wood_light": "b08552", "castle_thatch": "c9a35a", "castle_roof_tile": "a8492e",
    "castle_slate": "4f5a66", "castle_shingle": "6e5a44", "castle_earth": "7a5a36",
    "castle_grass": "7a9440", "castle_hedge": "40652a", "castle_dark": "241c16",
    "castle_gold": "d4a236", "castle_water": "4f86a0", "castle_iron": "5d6166",
    "castle_linen": "e2d4ad", "castle_awning": "b8402e", "castle_rose": "c42a48",
    "castle_rose_pink": "ee8aa4", "castle_glass_blue": "2f6bd0", "castle_glass_red": "d03a30",
    "castle_glass_gold": "f0c040", "castle_glass_green": "3fa050", "castle_rock": "8c8478",
}

PALETTE.update({name: linear(value) for name, value in CASTLE_COLORS.items()})
METALLIC.update({"castle_gold": (0.6, 0.35), "castle_iron": (0.5, 0.5)})
