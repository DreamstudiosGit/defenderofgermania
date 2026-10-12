import math

import bpy
from mathutils import Vector

from model_character_details import rounded
from model_characters import spear
from model_primitives import box, cone
from unit_palette import HOUSE_PRIMARY, HOUSE_SECONDARY
from unit_shapes import limb, outline_plate, part, sheet

HEATER = [(-0.25, 0.30), (0, 0.33), (0.25, 0.30), (0.26, 0.12), (0.23, -0.06), (0.17, -0.20),
          (0.09, -0.31), (0, -0.37), (-0.09, -0.31), (-0.17, -0.20), (-0.23, -0.06), (-0.26, 0.12)]


def frame(centre, facing, up=(0, 0, 1)):
    """Plate frame whose front looks along `facing`."""
    back = -Vector(facing).normalized()
    right = Vector(up).cross(back).normalized()
    return Vector(centre), right, back.cross(right).normalized(), back


def _scaled(outline, factor, du=0.0, dv=0.0):
    return [(u * factor + du, v * factor + dv) for u, v in outline]


def _front(plate_frame, distance):
    origin, right, up, back = plate_frame
    return origin - back * distance, right, up, back


def spear_held(fist):
    before = set(bpy.context.scene.objects)
    spear("unit_wood", "unit_iron", "unit_iron")
    objects = [obj for obj in bpy.context.scene.objects if obj not in before]
    for obj in objects:
        obj.location += Vector((fist.x, fist.y, 0.0))
    return objects


def flail(fist):
    with part("hand.R"):
        top = fist + Vector((0, 0.04, 0.52))
        limb("flail_handle", [fist + Vector((0, 0.01, -0.16)), top], [0.026, 0.024], "unit_wood", 6)
        rounded("flail_ring", top, (0.034, 0.034, 0.034), "unit_iron", segments=6, rings=4)
        limb("flail_swingle", [top, top + Vector((0.02, 0.15, -0.30))], [0.036, 0.03], "unit_leather", 6)


def round_shield(centre, facing, radius=0.24):
    plate_frame = frame(centre, facing)
    circle = [(math.cos(a) * radius, math.sin(a) * radius) for a in
              (i * math.tau / 12 for i in range(12))]
    with part("forearm.L"):
        outline_plate("shield_rim", _scaled(circle, 1.0), HOUSE_SECONDARY, 0.03, plate_frame)
        outline_plate("shield_field", _scaled(circle, 0.82), HOUSE_PRIMARY, 0.02,
                      _front(plate_frame, 0.018), bulge=0.03)
        origin, _, _, back = plate_frame
        rounded("shield_boss", origin - back * 0.07, (0.06, 0.06, 0.06), "unit_iron", segments=8, rings=4)


def heater_shield(centre, facing, scale=1.0, bone="forearm.L"):
    plate_frame = frame(centre, facing)
    chevron = [(-0.24, -0.02), (0, 0.17), (0.24, -0.02), (0.24, -0.13), (0, 0.06), (-0.24, -0.13)]
    with part(bone):
        outline_plate("heater_border", _scaled(HEATER, scale), HOUSE_SECONDARY, 0.03, plate_frame)
        outline_plate("heater_field", _scaled(HEATER, scale * 0.86, dv=0.01 * scale), HOUSE_PRIMARY, 0.02,
                      _front(plate_frame, 0.018), bulge=0.025)
        outline_plate("heater_chevron", _scaled(chevron, scale * 0.86), HOUSE_SECONDARY, 0.012,
                      _front(plate_frame, 0.05))


def pavise(centre, facing):
    plate_frame = frame(centre, facing, up=(0, 0.12, 1))
    outline = [(-0.31, 0.49), (0, 0.52), (0.31, 0.49), (0.28, -0.47), (-0.28, -0.47)]
    with part("chest"):
        outline_plate("pavise_border", outline, HOUSE_SECONDARY, 0.035, plate_frame)
        outline_plate("pavise_field", _scaled(outline, 0.88, dv=0.01), HOUSE_PRIMARY, 0.02,
                      _front(plate_frame, 0.02), bulge=0.02)
        outline_plate("pavise_pale", [(-0.07, 0.43), (0.07, 0.43), (0.07, -0.40), (-0.07, -0.40)],
                      HOUSE_SECONDARY, 0.012, _front(plate_frame, 0.055))
        limb("pavise_strap", [(-0.20, -0.20, 1.40), (0.0, -0.215, 1.15), (0.22, -0.19, 0.95)],
             [0.022] * 3, "unit_leather", 5)


def crossbow(rear, front):
    rear, front = Vector(rear), Vector(front)
    axis = (front - rear).normalized()
    side = axis.cross(Vector((0, 0, 1))).normalized()
    bow = front - axis * 0.06
    with part("hand.R"):
        limb("crossbow_stock", [rear, front], [(0.035, 0.045), (0.03, 0.035)], "unit_wood", 6)
        limb("crossbow_prod", [bow + side * 0.34 - axis * 0.10, bow + axis * 0.03, bow - side * 0.34 - axis * 0.10],
             [0.018, 0.026, 0.018], "unit_wood", 5)
        for sign in (1, -1):
            limb("crossbow_string", [bow + side * sign * 0.34 - axis * 0.10, rear + axis * 0.22],
                 [0.006, 0.006], "unit_linen", 4, smooth=False)
        limb("crossbow_stirrup", [bow + side * 0.07, front + axis * 0.08, bow - side * 0.07],
             [0.012] * 3, "unit_iron", 4)


def battle_axe(fist):
    low, high = fist + Vector((0.01, 0.0, -0.42)), fist + Vector((-0.07, 0.03, 0.98))
    with part("hand.R"):
        limb("axe_haft", [low, high], [0.03, 0.026], "unit_wood", 6)
        blade = [(0.0, 0.10), (-0.10, 0.12), (-0.25, 0.22), (-0.33, 0.06), (-0.31, -0.14),
                 (-0.22, -0.20), (-0.10, -0.06), (0.0, -0.06)]
        centre = high - Vector((0, 0, 0.16))
        outline_plate("axe_blade", blade, "unit_iron", 0.03, (centre, Vector((1, 0, 0)),
                                                                 Vector((0, 0, 1)), Vector((0, 1, 0))))
        spike = cone("axe_spike", centre + Vector((0.08, 0, 0.02)), 0.035, 0.14, "unit_iron", vertices=4)
        spike.rotation_euler.y = math.pi / 2


def lance(fist):
    with part("hand.R"):
        limb("lance_shaft", [fist + Vector((0, 0, -0.62)), fist + Vector((0, 0, 0.12)), fist + Vector((0, 0, 2.25))],
             [0.03, 0.036, 0.022], "unit_wood", 6)
        cone("lance_tip", fist + Vector((0, 0, 2.34)), 0.034, 0.2, "unit_iron", vertices=4)
        cone("lance_vamplate", fist + Vector((0, 0, 0.16)), 0.075, 0.08, "unit_iron", 0.03, vertices=8)


def sword(fist, up=(0, 0, 1), bone="hand.R"):
    up = Vector(up).normalized()
    with part(bone):
        limb("sword_blade", [fist + up * 0.09, fist + up * 0.80, fist + up * 0.90],
             [(0.032, 0.008), (0.026, 0.008), (0.004, 0.004)], "unit_iron", 4, smooth=False)
        side = up.cross(Vector((0, 1, 0))).normalized()
        limb("sword_guard", [fist + up * 0.08 - side * 0.12, fist + up * 0.08 + side * 0.12],
             [0.018, 0.018], "unit_gold", 5)
        rounded("sword_pommel", fist - up * 0.09, (0.035, 0.035, 0.035), "unit_gold", segments=6, rings=4)


def scabbard(top, bottom):
    top, bottom = Vector(top), Vector(bottom)
    up = (top - bottom).normalized()
    with part("pelvis"):
        limb("scabbard", [bottom, top], [0.03, 0.036], "unit_leather", 5)
        limb("scabbard_hilt", [top, top + up * 0.16], [0.022, 0.022], "unit_leather", 5)
        side = up.cross(Vector((1, 0, 0))).normalized()
        limb("scabbard_guard", [top - side * 0.09, top + side * 0.09], [0.016, 0.016], "unit_gold", 5)
        rounded("scabbard_pommel", top + up * 0.19, (0.032, 0.032, 0.032), "unit_gold", segments=6, rings=4)


def cloak(rows, hem_rows):
    with part("chest"):
        sheet("cloak", rows, HOUSE_PRIMARY, 0.03)
        sheet("cloak_hem", hem_rows, HOUSE_SECONDARY, 0.04)
        box("cloak_clasp", (0, -0.17, 1.45), (0.07, 0.03, 0.07), "unit_gold")
