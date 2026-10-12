"""Castle raid fighters (M6): the leader on foot (knight kit, circlet, cloak, sword) and the castle
guard (gambeson in the owner's colours, kettle hat, sword and round shield), both on the shared human
rig in a fencing stance with the raid clips."""
import bpy
from mathutils import Vector

from raid_clips import Rig, raid_clips
from unit_body import body
from unit_clips import merge
from unit_gear import cloak, round_shield, sword
from unit_headgear import headgear
from unit_rig import HUMAN, Pose, key_clips, pose_parts
from unit_roles import BASE_KIT, ELBOW_L, KITS, _anchor, _cloak_rows, _finish_human
from unit_shapes import created_since

# Rest blade direction: up and towards the enemy, a little across the body.
SWORD_UP = (0.12, -0.55, 0.83)
SWORD_FIST = (-0.22, -0.33, 1.05)


def _stance(pose):
    pose.turn("thigh.L", x=-14).turn("shin.L", x=10).turn("thigh.R", x=12).turn("shin.R", x=4)


def raider():
    """The leader of any house: tabard and cloak take the house colours, the crest mounts on top."""
    before = set(bpy.context.scene.objects)
    detail = 1.35
    body(merge(BASE_KIT, KITS["knight"]), detail)
    headgear("great_helm", detail, circlet=True)
    cloak(*_cloak_rows())
    parts = created_since(before)
    pose = Pose(HUMAN)
    _stance(pose)
    right = pose.grip("R", SWORD_FIST, (-0.6, 0.6, -0.5))
    pose.grip("L", (0.30, -0.16, 0.98), (1.0, 0.6, -0.4))
    pose_parts(parts, pose)
    sword(right, SWORD_UP)
    anchor = _anchor(pose, "great_helm")
    rig = _finish_human("unit_raider", before, pose, {})
    key_clips(rig, raid_clips(Rig(pose, SWORD_UP), shield=False))
    return anchor


def guard():
    """A castle guard in the owner's colours; the shield shows the height it covers."""
    before = set(bpy.context.scene.objects)
    body(merge(BASE_KIT, KITS["spearman"]))
    headgear("kettle_hat")
    parts = created_since(before)
    pose = Pose(HUMAN)
    _stance(pose)
    right = pose.grip("R", SWORD_FIST, (-0.6, 0.6, -0.5))
    left = pose.grip("L", (0.24, -0.36, 1.10), (1.0, 0.4, -0.4))
    pose_parts(parts, pose)
    sword(right, SWORD_UP)
    elbow = pose.point("forearm.L", ELBOW_L)
    round_shield((left + elbow) / 2 + Vector((0.06, -0.08, 0.02)), (0.25, -0.97, 0), 0.22)
    anchor = _anchor(pose, "kettle_hat")
    rig = _finish_human("unit_guard", before, pose, {})
    key_clips(rig, raid_clips(Rig(pose, SWORD_UP), shield=True))
    return anchor


FIGHTERS = {"raider": (raider, 6000), "guard": (guard, 3000)}
