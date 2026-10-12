"""Assembles the house-neutral soldiers: body + headgear in the rig's standard rest, the role's rest
pose (IK grips), gear placed on the posed hands, one shared human rig and keyed clips."""
import math

import bpy
from mathutils import Matrix, Vector

from model_primitives import join_meshes
from unit_body import body
from unit_clips import human_clips, merge
from unit_clips_mounted import mounted_clips
from unit_gear import (battle_axe, cloak, crossbow, flail, heater_shield, lance, pavise, round_shield, scabbard,
                       spear_held, sword)
from unit_headgear import ANCHORS, headgear
from unit_horse import banner, horse
from unit_palette import HOUSE_PRIMARY, HOUSE_SECONDARY
from unit_rig import HORSE, HUMAN, SADDLE, Pose, build_rig, key_clips, pose_parts, skin
from unit_shapes import bind, created_since

BASE_KIT = {"hose": "unit_wool", "boots": "unit_leather", "hands": "unit_skin", "belt": "unit_leather",
            "hem_z": 0.50}
KITS = {
    "levy": {"coat": "unit_linen", "sleeves": "unit_linen", "hem_z": 0.44, "headgear": "gugel"},
    "spearman": {"coat": HOUSE_PRIMARY, "sleeves": HOUSE_PRIMARY, "hem": HOUSE_SECONDARY,
                 "collar": HOUSE_SECONDARY, "quilt": 0.03, "headgear": "kettle_hat"},
    "crossbowman": {"coat": "unit_linen", "sleeves": "unit_linen", "quilt": 0.03, "headgear": "coif"},
    "brabanter": {"coat": "unit_wool", "sleeves": "unit_mail", "cuffs": {"L": "unit_wool", "R": "unit_leather"},
                  "hose": "unit_leather", "boots": "unit_dark", "mail_shirt": True, "beard": "unit_dark",
                  "pauldrons": (("L", "unit_iron"), ("R", "unit_leather")), "headgear": "nasal_helm"},
    "knight": {"coat": HOUSE_PRIMARY, "sleeves": "unit_mail", "hose": "unit_mail", "hands": "unit_leather",
               "hem": HOUSE_SECONDARY, "hem_z": 0.62, "face": False, "headgear": "great_helm"},
}
ELBOW_L = (0.33, 0, 1.12)
ATTACKS = {"levy": ("flail", (25, 25)), "spearman": ("thrust", (10, 4)), "crossbowman": ("shoot", (3, 3)),
           "brabanter": ("swing", (15, 6))}


def _rest_levy(pose):
    pose.turn("thigh.L", y=-4).turn("thigh.R", y=4)
    pose.grip("L", (0.37, -0.05, 0.86), (0.4, 0.6, -0.5))
    flail(pose.grip("R", (-0.36, -0.14, 0.98), (-0.4, 0.6, -0.5)))


def _rest_spearman(pose):
    weapon = spear_held(pose.grip("R", (-0.39, -0.23, 0.95), (-0.6, 0.6, -0.5)))
    left = pose.grip("L", (0.30, -0.25, 1.00), (1.0, 0.5, -0.4))
    elbow = pose.point("forearm.L", ELBOW_L)
    round_shield((left + elbow) / 2 + Vector((0.07, -0.09, 0.02)), (0.35, -0.94, 0))
    return {"weapon_spear": weapon}


def _rest_crossbowman(pose):
    rear = pose.grip("R", (-0.10, -0.22, 1.02), (-0.8, 0.6, -0.3))
    front_hand = pose.grip("L", (0.12, -0.36, 1.10), (0.8, 0.3, -0.5))
    crossbow(rear, rear + (front_hand - rear).normalized() * 0.58)
    pavise((0, 0.30, 1.10), (0, 0.99, 0.12))


def _rest_brabanter(pose):
    pose.turn("thigh.L", y=-10).turn("thigh.R", y=10)
    pose.grip("L", (0.30, 0.03, 0.97), (1.0, 0.8, 0.2))
    battle_axe(pose.grip("R", (-0.40, -0.16, 0.98), (-0.6, 0.6, -0.4)))


REST = {"levy": _rest_levy, "spearman": _rest_spearman, "crossbowman": _rest_crossbowman,
        "brabanter": _rest_brabanter}


def _anchor(pose, kind):
    if kind not in ANCHORS:
        return None
    bpy.ops.object.empty_add(type="PLAIN_AXES", radius=0.1, location=pose.point("head", ANCHORS[kind]))
    empty = bpy.context.object
    empty.name = "crest_anchor"
    return empty


def _finish_human(name, before, pose, extra, root_head=None):
    rig = build_rig("rig_human", HUMAN, pose, root_head)
    extra_objects = [obj for objects in extra.values() for obj in objects]
    mesh = join_meshes(name, [obj for obj in created_since(before) if obj not in extra_objects])
    skin(mesh, rig)
    for extra_name, objects in extra.items():
        for obj in objects:
            bind(obj, "hand.R")
        child = join_meshes(extra_name, objects)
        skin(child, rig)
    return rig


def foot_unit(role):
    before = set(bpy.context.scene.objects)
    kit = merge(BASE_KIT, KITS[role])
    body(kit)
    headgear(kit["headgear"])
    parts = created_since(before)
    pose = Pose(HUMAN)
    extra = REST[role](pose) or {}
    pose_parts(parts, pose)
    anchor = _anchor(pose, kit["headgear"])
    rig = _finish_human(f"unit_{role}", before, pose, extra)
    style, swing = ATTACKS[role]
    key_clips(rig, human_clips(style, swing))
    return anchor


def _seat(pose):
    for side, sign in (("L", 1), ("R", -1)):
        pose.reach(f"thigh.{side}", f"shin.{side}", (0.38 * sign, -0.04, 0.96), (0.3 * sign, -1.0, 0.3))


def _cloak_rows():
    def row(z, half, depth, back):
        return [(x, back + depth * math.sqrt(max(0.0, 1 - (x / (half + 0.02)) ** 2)), z)
                for x in (-half, -half / 2, 0.0, half / 2, half)]
    rows = [row(1.44, 0.26, 0.20, 0.03), row(1.20, 0.34, 0.22, 0.05), row(0.95, 0.38, 0.22, 0.20),
            row(0.80, 0.40, 0.22, 0.36)]
    hem = [row(0.83, 0.405, 0.22, 0.33), row(0.78, 0.41, 0.22, 0.385)]
    return rows, hem


def mounted_unit(role):
    leader = role == "leader"
    detail = 1.35 if leader else 1.0
    before = set(bpy.context.scene.objects)
    horse("unit_linen" if leader else "unit_chestnut", "unit_wool" if leader else "unit_dark", detail)
    if leader:
        banner((-0.24, 0.40, 1.30))
    horse_rig = build_rig("rig_horse", HORSE, Pose(HORSE))
    skin(join_meshes(f"unit_{role}_horse", created_since(before)), horse_rig)

    before = set(bpy.context.scene.objects)
    body(merge(BASE_KIT, KITS["knight"], {"rider": True}), detail)
    headgear("great_helm", detail, circlet=leader)
    if leader:
        cloak(*_cloak_rows())
    parts = created_since(before)
    pose = Pose(HUMAN, base=Matrix.Translation((0, 0.02, 0.72)))
    _seat(pose)
    right = pose.grip("R", (-0.34, -0.31, 1.81), (-0.6, 0.6, -0.4))
    left = pose.grip("L", (0.20, -0.38, 1.76), (0.8, 0.4, -0.4))
    pose_parts(parts, pose)
    if leader:
        sword(right, (0, -0.08, 1))
    else:
        lance(right)
        scabbard((0.27, 0.04, 1.62), (0.40, 0.40, 1.05))
    elbow = pose.point("forearm.L", ELBOW_L)
    heater_shield((left + elbow) / 2 + Vector((0.12, -0.02, 0.06)), (0.8, -0.6, 0), 0.95)
    anchor = _anchor(pose, "great_helm")
    rig = _finish_human(f"unit_{role}", before, pose, {}, root_head=SADDLE)
    charge_arm = ({"upper_arm.R": (-75, 0, 0), "forearm.R": (-10, 0, 0), "hand.R": (175, 0, 0)} if leader
                  else {"upper_arm.R": (20, 0, 0), "forearm.R": (-15, 0, 0), "hand.R": (82, 0, 0)})
    horse_clips, rider_clips = mounted_clips("sword" if leader else "lance", charge_arm)
    key_clips(horse_rig, horse_clips)
    key_clips(rig, rider_clips)
    return anchor


ROLE_BUILDERS = {"levy": foot_unit, "spearman": foot_unit, "crossbowman": foot_unit, "brabanter": foot_unit,
                 "knight": mounted_unit, "leader": mounted_unit}
