"""Oversized Codex-Manesse helmet crests: pivot at the mounting point (bottom centre), front -Y, metres.
Wide silhouettes so they still read on a ~30 px figure under the 60 degree battle camera."""
import math

from model_character_details import rounded
from model_primitives import cone, plate
from unit_shapes import limb, outward

SIDES = (1, -1)


def _mirror(outline, sign):
    return [(x * sign, z) for x, z in outline]


def _swept(obj, sign, degrees):
    """Turns a wing plate about the crest axis so the pair opens into a V seen from above."""
    obj.rotation_euler.z = sign * math.radians(degrees)
    return obj


def lion():
    gold = "unit_gold"
    limb("lion_body", [(0, 0.03, 0.0), (0, 0.0, 0.17), (0, -0.02, 0.30)],
         [(0.12, 0.10), (0.125, 0.105), (0.11, 0.09)], gold, 6)
    mane = [(math.sin(i * math.tau / 16) * (0.20 if i % 2 else 0.15),
             0.40 + math.cos(i * math.tau / 16) * (0.20 if i % 2 else 0.15)) for i in range(16)]
    outward(plate("lion_mane", mane, 0.03, 0.08, gold))
    rounded("lion_head", (0, -0.05, 0.41), (0.125, 0.105, 0.115), gold, segments=8, rings=5)
    rounded("lion_muzzle", (0, -0.15, 0.365), (0.085, 0.07, 0.055), gold, segments=6, rings=3)
    for name, at, radius in (("lion_nose", (0, -0.215, 0.39), 0.03), ("lion_eye", (0.05, -0.15, 0.44), 0.02),
                             ("lion_eye", (-0.05, -0.15, 0.44), 0.02)):
        cone(name, at, radius, 0.03, "unit_dark", vertices=3).rotation_euler.x = math.pi / 2
    for sign in SIDES:
        cone("lion_ear", (0.09 * sign, -0.05, 0.515), 0.038, 0.075, gold, vertices=4)
        limb("lion_paw", [(0.09 * sign, -0.06, 0.24), (0.20 * sign, -0.16, 0.30), (0.24 * sign, -0.20, 0.40)],
             [0.045, 0.04, 0.056], gold, 5)
    limb("lion_tail", [(0.06, 0.09, 0.06), (0.22, 0.13, 0.15), (0.27, 0.11, 0.33), (0.21, 0.08, 0.48)],
         [0.025, 0.022, 0.022, 0.05], gold, 5)


def eagle():
    black, gold = "unit_dark", "unit_gold"
    limb("eagle_body", [(0, 0.0, 0.07), (0, -0.01, 0.24), (0, -0.01, 0.40)], [0.06, 0.09, 0.065], black, 8)
    rounded("eagle_head", (0.0, -0.02, 0.47), (0.06, 0.06, 0.065), black, segments=8, rings=5)
    beak = cone("eagle_beak", (-0.075, -0.03, 0.465), 0.025, 0.08, gold, vertices=4)
    beak.rotation_euler.y = -math.pi / 2
    wing = [(0.04, 0.42), (0.14, 0.50), (0.26, 0.60), (0.37, 0.67), (0.35, 0.57), (0.42, 0.53),
            (0.34, 0.45), (0.40, 0.38), (0.30, 0.33), (0.34, 0.25), (0.22, 0.23), (0.23, 0.15),
            (0.12, 0.19), (0.05, 0.28)]
    for sign in SIDES:
        _swept(outward(plate("eagle_wing", _mirror(wing, sign), 0.0, 0.035, black)), sign, 15)
        limb("eagle_claw", [(0.02 * sign, 0.0, 0.10), (0.08 * sign, -0.03, 0.02)], [0.02, 0.025], gold, 4)
    outward(plate("eagle_tail", [(-0.09, 0.02), (-0.05, 0.13), (0.05, 0.13), (0.09, 0.02)], 0.03, 0.03, black))


def antlers():
    bone, gold = "unit_linen", "unit_gold"
    cone("antler_base", (0, 0, 0.03), 0.09, 0.06, gold, 0.06, vertices=8)
    for sign in SIDES:
        beam = [(0.05 * sign, 0.0, 0.04), (0.16 * sign, 0.0, 0.18), (0.25 * sign, 0.02, 0.36),
                (0.30 * sign, 0.04, 0.56), (0.27 * sign, 0.06, 0.69)]
        limb("antler_beam", beam, [0.035, 0.03, 0.026, 0.02, 0.012], bone, 5)
        for start, middle, end in (((0.16, 0.0, 0.18), (0.11, -0.05, 0.25), (0.08, -0.07, 0.33)),
                                   ((0.25, 0.02, 0.36), (0.19, 0.01, 0.45), (0.13, 0.0, 0.53)),
                                   ((0.30, 0.04, 0.56), (0.37, 0.04, 0.61), (0.42, 0.04, 0.67))):
            limb("antler_tine", [(p[0] * sign, p[1], p[2]) for p in (start, middle, end)],
                 [0.02, 0.016, 0.008], bone, 4)


def wings():
    blue, gold = "unit_blue", "unit_gold"
    cone("wings_base", (0, 0, 0.03), 0.08, 0.06, gold, 0.06, vertices=8)
    wing = [(0.02, 0.02), (0.08, 0.06), (0.16, 0.10), (0.21, 0.06), (0.24, 0.16), (0.31, 0.13),
            (0.32, 0.26), (0.39, 0.25), (0.38, 0.38), (0.44, 0.40), (0.40, 0.52), (0.43, 0.59),
            (0.34, 0.67), (0.24, 0.63), (0.14, 0.53), (0.07, 0.38), (0.03, 0.22), (0.0, 0.10)]
    for sign in SIDES:
        _swept(outward(plate("wing", _mirror(wing, sign), 0.0, 0.035, blue)), sign, 22)
        _swept(limb("wing_stem", [(0.05 * sign, -0.025, 0.12), (0.17 * sign, -0.025, 0.40),
                                  (0.30 * sign, -0.025, 0.58)], [0.014, 0.012, 0.01], gold, 4), sign, 22)


CRESTS = {"crest_lion": lion, "crest_eagle": eagle, "crest_antlers": antlers, "crest_wings": wings}
