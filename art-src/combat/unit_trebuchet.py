"""Counterweight trebuchet, cocked (sling end on the ground behind), with four low-poly crew."""
import math

import bpy
from mathutils import Matrix, Vector

from model_character_details import rounded
from model_primitives import box, cone, join_meshes
from unit_body import body
from unit_clips import attack, cheer, death, hit, idle, key, merge, table, walk
from unit_headgear import headgear
from unit_palette import HOUSE_PRIMARY
from unit_rig import HUMAN, Pose, build_rig, key_clips, pose_parts, skin
from unit_shapes import created_since, limb, outline_plate, part

PIVOT = Vector((0, 0, 1.70))
REACH = Vector((0, 0.771, -0.637))
LONG_END, SHORT_END = PIVOT + REACH * 2.0, PIVOT - REACH * 0.55
POUCH, STONE = Vector((0, 2.15, 0.10)), Vector((0, 2.15, 0.19))
MACHINE = (("root", None, (0, 0, 0), (0, 0, 0.3)),
           ("axle_front", "root", (0, -0.80, 0.28), (0.3, -0.80, 0.28)),
           ("axle_back", "root", (0, 0.80, 0.28), (0.3, 0.80, 0.28)),
           ("arm", "root", PIVOT, LONG_END),
           ("counterweight", "arm", SHORT_END, SHORT_END - Vector((0, 0, 0.35))),
           ("sling", "arm", LONG_END, POUCH),
           ("stone", "root", STONE, STONE + Vector((0, 0, 0.2))))
CREW = ((1.0, -0.25), (-1.0, -0.25), (0.62, 1.62), (-0.62, 1.62))
CREW_KIT = {"hose": "unit_wool", "boots": "unit_leather", "coat": "unit_linen", "sleeves": "unit_linen",
            "hands": "unit_skin", "hem_z": 0.50, "simple": True}


def machine():
    with part("root"):
        for x in (-0.55, 0.55):
            box("rail", (x, 0, 0.36), (0.14, 2.3, 0.16), "unit_wood")
            for y in (-0.85, 0.85):
                limb("upright", [(x * 0.82, y, 0.40), (x * 0.82, 0, 1.76)], [(0.06, 0.06)] * 2, "unit_wood", 4,
                     smooth=False)
        for y in (-1.05, 0.0, 1.05):
            box("crossbeam", (0, y, 0.36), (1.24, 0.12, 0.12), "unit_wood")
        limb("pivot_axle", [(-0.58, 0, 1.70), (0.58, 0, 1.70)], [0.045, 0.045], "unit_iron", 6)
        limb("pennant_pole", [(0.45, 0, 1.76), (0.45, 0, 2.55)], [0.022, 0.018], "unit_wood", 5)
        outline_plate("pennant", [(0.0, 0.13), (0.0, -0.13), (0.62, 0.02)], HOUSE_PRIMARY, 0.02,
                      (Vector((0.45, 0.02, 2.40)), Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))))
        for at, size in (((-1.0, 0.75, 0.11), 0.11), ((-1.12, 1.0, 0.10), 0.10)):
            rounded("spare_stone", at, (size, size, size), "unit_stone", segments=6, rings=4)
    for bone, y in (("axle_front", -0.80), ("axle_back", 0.80)):
        with part(bone):
            limb("axle", [(-0.76, y, 0.28), (0.76, y, 0.28)], [0.035, 0.035], "unit_iron", 5)
            for x in (-0.70, 0.70):
                wheel = cone("wheel", (x, y, 0.28), 0.28, 0.09, "unit_wood", 0.28, 10)
                wheel.rotation_euler.y = math.pi / 2
                hub = cone("wheel_hub", (x * 1.1, y, 0.28), 0.07, 0.06, "unit_iron", 0.05, 6)
                hub.rotation_euler.y = math.pi / 2
    with part("arm"):
        limb("throwing_arm", [SHORT_END + REACH * -0.08, LONG_END], [(0.07, 0.06), (0.05, 0.045)], "unit_wood", 4,
             smooth=False)
    with part("counterweight"):
        box("counterweight_box", SHORT_END - Vector((0, 0, 0.33)), (0.46, 0.40, 0.42), "unit_wood")
        box("counterweight_stones", SHORT_END - Vector((0, 0, 0.11)), (0.40, 0.34, 0.04), "unit_stone")
        for x in (-0.2, 0.2):
            limb("counterweight_strap", [SHORT_END + Vector((x, 0, -0.12)), SHORT_END], [0.015] * 2, "unit_iron", 4,
                 smooth=False)
    with part("sling"):
        for x in (-0.06, 0.06):
            limb("sling_rope", [LONG_END, POUCH + Vector((x, -0.06, 0.03))], [0.012] * 2, "unit_linen", 4,
                 smooth=False)
        rounded("sling_pouch", POUCH, (0.14, 0.16, 0.07), "unit_leather", segments=6, rings=4)
    with part("stone"):
        rounded("stone", STONE, (0.12, 0.12, 0.12), "unit_stone", segments=8, rings=6)


def _arm(angle, weight, sling):
    return {"arm": (angle, 0, 0), "counterweight": (weight, 0, 0), "sling": (sling, 0, 0)}


def _shot():
    first, last, swing = table([
        key(1), key(6), key(8, _arm(25, -25, -25)), key(10, _arm(70, -70, -50)), key(12, _arm(125, -110, 40)),
        key(14, _arm(150, -135, 110)), key(16, _arm(160, -150, 120)), key(18, _arm(140, -150, 80)),
        key(22, _arm(150, -150, 100)), key(26, _arm(148, -148, 95)), key(30, _arm(120, -120, 60)),
        key(36, _arm(70, -70, 20)), key(42, _arm(20, -20, 0)), key(46), key(48)])
    release = 13

    def carried(rot):
        return Pose(MACHINE, rotations=rot).point("sling", STONE) - STONE

    def sample(frame):
        rot, move, scale = swing(frame)
        if frame <= release:
            move = merge(move, {"stone": tuple(carried(rot))})
        elif frame < 20:
            u = frame - release
            start = carried(swing(release)[0])
            move = merge(move, {"stone": tuple(start + Vector((0, -0.45 * u, 0.30 * u - 0.012 * u * u)))})
            scale = merge(scale, {"stone": max(0.0, 1 - u / 7)})
        elif frame < 46:
            scale = merge(scale, {"stone": 0.0})
        return rot, move, scale
    return first, last, sample


def machine_clips():
    def still(length):
        def sample(frame):
            return {"sling": (0, 0, 2 * math.sin((frame - 1) / length * math.tau))}, {}, {}
        return 1, length + 1, sample

    def rolling(frame):
        t = (frame - 1) / 24
        return ({"axle_front": (216 * t, 0, 0), "axle_back": (216 * t, 0, 0)},
                {"root": (0, 0, 0.01 * abs(math.sin(2 * t * math.tau)))}, {})

    tilt = {"root": (9, 0, 0), "axle_front": (0, 25, 0)}
    return {"idle": still(48), "walk": (1, 25, rolling), "attack": _shot(),
            "hit": table([key(1), key(3, {"root": (2, 0, 3)}), key(5, {"root": (-1, 0, -2)}),
                          key(8, {"root": (1, 0, 1)}), key(13)]),
            "death": table([key(1), key(5, {"root": (4, 0, 2)}, {"root": (0, 0, 0.03)}),
                            key(10, merge(_arm(60, -60, 30), tilt), {"root": (0, 0, -0.04), "stone": (0.2, 0.3, -0.08)}),
                            key(14, merge(_arm(95, -40, 80), tilt), {"root": (0, 0, -0.06), "stone": (0.3, 0.4, -0.08)}),
                            key(20, merge(_arm(70, -70, 30), tilt), {"root": (0, 0, -0.05), "stone": (0.3, 0.4, -0.08)}),
                            key(31, merge(_arm(75, -60, 20), tilt), {"root": (0, 0, -0.05), "stone": (0.3, 0.4, -0.08)})]),
            "cheer": still(24)}


def crew_clips(index):
    return {"idle": idle(index * 0.21), "walk": walk(push=True), "attack": attack("haul"),
            "hit": hit(), "death": death(), "cheer": cheer()}


def trebuchet_unit(role="trebuchet"):
    before = set(bpy.context.scene.objects)
    machine()
    rig = build_rig("rig_trebuchet", MACHINE, Pose(MACHINE))
    skin(join_meshes(f"unit_{role}", created_since(before)), rig)
    key_clips(rig, machine_clips())
    for index, (x, y) in enumerate(CREW, 1):
        before = set(bpy.context.scene.objects)
        body(CREW_KIT, 0.6)
        headgear("gugel", 0.6)
        pose = Pose(HUMAN, base=Matrix.Translation((x, y, 0)))
        pose_parts(created_since(before), pose)
        crew_rig = build_rig(f"rig_crew_{index}", HUMAN, pose)
        skin(join_meshes(f"unit_{role}_crew_{index}", created_since(before)), crew_rig)
        key_clips(crew_rig, crew_clips(index))
    return None
