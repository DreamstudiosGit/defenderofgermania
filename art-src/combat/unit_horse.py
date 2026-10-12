import math

from mathutils import Vector

from model_character_details import loft, rounded
from model_primitives import box, cone
from unit_body import SIDES
from unit_palette import HOUSE_PRIMARY, HOUSE_SECONDARY
from unit_shapes import limb, part, sheet

NECK = [Vector((0, -0.50, 1.24)), Vector((0, -0.70, 1.55)), Vector((0, -0.84, 1.84))]
NECK_RADII = [(0.16, 0.21), (0.14, 0.16), (0.12, 0.13)]


def horse(coat, mane, detail=1.0):
    """Stocky horse facing -Y, bound to the HORSE rig; legs carry the diagonal trot phase in UV2."""
    def n(base):
        return max(5, round(base * detail))

    with part("body"):
        limb("horse_barrel", [(0, 0.66, 1.13), (0, 0.48, 1.15), (0, 0.05, 1.11), (0, -0.40, 1.15),
                              (0, -0.62, 1.20)],
             [(0.15, 0.17), (0.255, 0.27), (0.27, 0.27), (0.255, 0.28), (0.15, 0.19)], coat, n(12))
        box("saddle", (0, 0.03, 1.405), (0.38, 0.46, 0.09), "unit_leather")
        limb("saddle_cantle", [(-0.15, 0.23, 1.45), (0, 0.27, 1.50), (0.15, 0.23, 1.45)], [0.04] * 3,
             "unit_leather", 5)
        rounded("saddle_pommel", (0, -0.20, 1.47), (0.07, 0.05, 0.06), "unit_leather", segments=6, rings=4)
        loft("caparison", [(0.72, 0.36, 0.80, 0, 0.0), (1.10, 0.35, 0.77, 0, 0.0),
                           (1.37, 0.315, 0.70, 0, 0.0), (1.43, 0.20, 0.50, 0, 0.0)],
             HOUSE_PRIMARY, segments=n(14), folds=0.02)
        loft("caparison_hem", [(0.62, 0.367, 0.807, 0, 0.0), (0.735, 0.364, 0.804, 0, 0.0)],
             HOUSE_SECONDARY, segments=n(14), folds=0.02)
    with part("neck"):
        limb("horse_neck", NECK, NECK_RADII, coat, n(10))
        direction = (NECK[2] - NECK[0]).normalized()
        back = direction.cross(Vector((1, 0, 0))).normalized()
        if back.z < 0:
            back = -back
        crest = [p + back * r[1] * 0.92 for p, r in zip(NECK, NECK_RADII)]
        limb("horse_mane", [crest[0], crest[1], crest[2] + Vector((0, -0.04, 0.10))],
             [(0.035, 0.06), (0.04, 0.07), (0.03, 0.05)], mane, n(6))
    with part("head"):
        limb("horse_head", [(0, -0.80, 1.86), (0, -0.97, 1.79), (0, -1.13, 1.65)],
             [(0.125, 0.135), (0.115, 0.125), (0.10, 0.10)], coat, n(10))
        rounded("horse_muzzle", (0, -1.16, 1.62), (0.105, 0.105, 0.09), coat, segments=n(8), rings=5)
        for side, sign in SIDES:
            cone("horse_ear", (0.07 * sign, -0.80, 2.0), 0.038, 0.13, coat, vertices=4)
            rounded("horse_eye", (0.112 * sign, -0.93, 1.85), (0.026, 0.038, 0.04), "unit_dark",
                    segments=6, rings=4)
            limb("bridle", [(0.11 * sign, -1.08, 1.66), (0.125 * sign, -0.86, 1.94)], [0.012] * 2,
                 "unit_leather", 4, smooth=False)
            limb("reins", [(0.10 * sign, -1.10, 1.64), (0.15 * sign, -0.75, 1.62), (0.20 * sign, -0.42, 1.74)],
                 [0.01] * 3, "unit_leather", 4, smooth=False)
    with part("tail"):
        limb("horse_tail", [(0, 0.64, 1.30), (0, 0.80, 1.14), (0, 0.88, 0.86), (0, 0.86, 0.62)],
             [0.06, 0.075, 0.07, 0.03], mane, n(6))
    for side, sign in SIDES:
        for front in (-1, 1):
            x, y, leg = 0.15 * sign, 0.45 * front, "front" if front < 0 else "hind"
            with part(f"{leg}_upper.{side}", sign * front):
                limb("horse_leg_upper", [(x, y, 1.06), (x, y + 0.02 * front, 0.80), (x, y, 0.55)],
                     [(0.085, 0.11), (0.08, 0.085), (0.06, 0.065)], coat, n(8))
            with part(f"{leg}_lower.{side}", sign * front):
                limb("horse_leg_lower", [(x, y, 0.57), (x, y - 0.01, 0.16)], [0.052, 0.048], coat, n(6))
                limb("horse_hoof", [(x, y - 0.02, 0.17), (x, y - 0.025, 0.0)], [0.062, 0.075],
                     "unit_dark", n(8))


def banner(foot, height=2.15):
    """Leader's own banner on a pole behind the saddle; flag streams back (+Y) with a swallowtail."""
    foot = Vector(foot)
    top = foot + Vector((0, 0, height))
    with part("body"):
        limb("banner_pole", [foot, top], [0.026, 0.022], "unit_wood", 6)
        cone("banner_finial", top + Vector((0, 0, 0.06)), 0.045, 0.14, "unit_gold", vertices=6)

        def wave(y):
            return foot.x + 0.07 * math.sin((y - foot.y) * 5.0)

        columns = [foot.y + 0.03 + i * 0.2 for i in range(5)]
        rows = []
        for z, end in ((top.z - 0.10, 0.0), (top.z - 0.45, -0.24), (top.z - 0.80, 0.0)):
            rows.append([(wave(y), y + (end if i == 4 else 0.0), z) for i, y in enumerate(columns)])
        sheet("banner_flag", rows, HOUSE_PRIMARY, 0.025, normal=(1, 0, 0))
        band = [[(wave(y), y, z) for y in columns[:4]] for z in (top.z - 0.38, top.z - 0.52)]
        sheet("banner_band", band, HOUSE_SECONDARY, 0.04, normal=(1, 0, 0))
