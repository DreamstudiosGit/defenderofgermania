from model_primitives import METALLIC, PALETTE

# The one muted palette shared by every unit and crest (sRGB hex; documented in README.md).
UNIT_COLORS = {
    "unit_iron": "8a9096", "unit_mail": "4d5257", "unit_gold": "c9962e",
    "unit_skin": "e0a47c", "unit_leather": "5c3a22", "unit_wood": "8a6038",
    "unit_linen": "d8c9a3", "unit_wool": "7d6f5c", "unit_dark": "2a2420",
    "unit_chestnut": "8c4f2a", "unit_stone": "9a958a", "unit_blue": "2f4f8f",
}
# Godot tints these per house; white keeps the tint exact.
HOUSE_PRIMARY = "house_primary"
HOUSE_SECONDARY = "house_secondary"


def linear(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)


PALETTE.update({name: linear(value) for name, value in UNIT_COLORS.items()})
PALETTE.update({HOUSE_PRIMARY: (1.0, 1.0, 1.0), HOUSE_SECONDARY: (1.0, 1.0, 1.0)})
METALLIC.update({"unit_iron": (0.55, 0.42), "unit_mail": (0.5, 0.6), "unit_gold": (0.65, 0.35)})
