import math

import bpy
from mathutils import Euler, Matrix, Vector

FPS = 24
KEY_STEP = 2


def _pair(name, parent, head, tail):
    """Left (+X, the figure's left when it faces -Y) and mirrored right bone; '?' in parent is the side."""
    return tuple((f"{name}.{side}", parent.replace("?", side) if parent else None,
                  (sign * head[0], head[1], head[2]), (sign * tail[0], tail[1], tail[2]))
                 for side, sign in (("L", 1), ("R", -1)))


# Standing rest of the shared human rig: 1.90 m to the helmet top, head 1/5 of the height.
HUMAN = ((("root", None, (0, 0, 0), (0, 0, 0.25)),
          ("pelvis", "root", (0, 0, 0.74), (0, 0, 0.92)),
          ("spine", "pelvis", (0, 0, 0.92), (0, 0, 1.14)),
          ("chest", "spine", (0, 0, 1.14), (0, 0, 1.44)),
          ("neck", "chest", (0, 0, 1.44), (0, 0, 1.52)),
          ("head", "neck", (0, 0, 1.52), (0, 0, 1.90)))
         + _pair("upper_arm", "chest", (0.29, 0, 1.38), (0.33, 0, 1.12))
         + _pair("forearm", "upper_arm.?", (0.33, 0, 1.12), (0.35, -0.02, 0.92))
         + _pair("hand", "forearm.?", (0.35, -0.02, 0.92), (0.35, -0.03, 0.80))
         + _pair("thigh", "pelvis", (0.12, 0, 0.74), (0.12, 0, 0.42))
         + _pair("shin", "thigh.?", (0.12, 0, 0.42), (0.12, 0, 0.10))
         + _pair("foot", "shin.?", (0.12, 0, 0.10), (0.12, -0.14, 0.03)))
FIST = {"L": (0.35, -0.03, 0.86), "R": (-0.35, -0.03, 0.86)}

HORSE = ((("root", None, (0, 0, 0), (0, 0, 0.3)),
          ("body", "root", (0, 0, 1.12), (0, -0.5, 1.12)),
          ("neck", "body", (0, -0.55, 1.28), (0, -0.82, 1.78)),
          ("head", "neck", (0, -0.82, 1.80), (0, -1.20, 1.58)),
          ("tail", "body", (0, 0.62, 1.26), (0, 0.88, 0.80)))
         + _pair("front_upper", "body", (0.15, -0.45, 1.02), (0.15, -0.45, 0.56))
         + _pair("front_lower", "front_upper.?", (0.15, -0.45, 0.56), (0.15, -0.46, 0.04))
         + _pair("hind_upper", "body", (0.15, 0.45, 1.02), (0.15, 0.47, 0.56))
         + _pair("hind_lower", "hind_upper.?", (0.15, 0.47, 0.56), (0.15, 0.45, 0.04)))
SADDLE = Vector((0, 0.02, 1.45))


def euler(rotation):
    if isinstance(rotation, Matrix):
        return rotation
    return Euler(tuple(math.radians(a) for a in rotation)).to_matrix()


class Pose:
    """Rigid forward kinematics: per bone a rotation about its rest head in armature axes."""

    def __init__(self, bones, base=None, rotations=None, moves=None):
        self.bones = {name: (parent, Vector(head), Vector(tail)) for name, parent, head, tail in bones}
        self.base = base if base is not None else Matrix.Identity(4)
        self.rot = {name: euler(r) for name, r in (rotations or {}).items()}
        self.move = {name: Vector(m) for name, m in (moves or {}).items()}
        self._cache = {}

    def turn(self, bone, x=0.0, y=0.0, z=0.0):
        self.rot[bone] = euler((x, y, z)) @ self.rot.get(bone, Matrix.Identity(3))
        self._cache.clear()
        return self

    def delta(self, bone):
        if bone not in self._cache:
            parent, head, _ = self.bones[bone]
            outer = self.delta(parent) if parent else self.base
            self._cache[bone] = (outer @ Matrix.Translation(self.move.get(bone, Vector()) + head)
                                 @ self.rot.get(bone, Matrix.Identity(3)).to_4x4() @ Matrix.Translation(-head))
        return self._cache[bone]

    def point(self, bone, at):
        return self.delta(bone) @ Vector(at)

    def reach(self, upper, lower, target, pole):
        """Two-bone IK: rotates upper and lower so the lower bone's tail lands on target."""
        parent, shoulder, elbow = self.bones[upper]
        wrist = self.bones[lower][2]
        outer = self.delta(parent).to_3x3()
        start = self.delta(parent) @ shoulder
        first, second = (elbow - shoulder).length, (wrist - elbow).length
        offset = Vector(target) - start
        distance = min(max(offset.length, abs(first - second) + 1e-3), first + second - 1e-4)
        direction = offset.normalized()
        bend = Vector(pole) - direction * Vector(pole).dot(direction)
        along = (first * first - second * second + distance * distance) / (2 * distance)
        knee = start + direction * along + bend.normalized() * math.sqrt(max(first * first - along * along, 0))
        upper_world = (elbow - shoulder).rotation_difference(knee - start).to_matrix()
        current = upper_world @ (wrist - elbow)
        lower_world = current.rotation_difference(start + direction * distance - knee).to_matrix() @ upper_world
        self.rot[upper] = outer.inverted() @ upper_world
        self.rot[lower] = upper_world.inverted() @ lower_world
        self._cache.clear()

    def grip(self, side, at, pole):
        """Places the fist centre of one hand on `at` (iterates the wrist target)."""
        target = Vector(at)
        for _ in range(4):
            self.reach(f"upper_arm.{side}", f"forearm.{side}", target, pole)
            target += Vector(at) - self.point(f"hand.{side}", FIST[side])
        return self.point(f"hand.{side}", FIST[side])


def pose_parts(objects, pose):
    for obj in objects:
        obj.matrix_world = pose.delta(obj["bone"]) @ obj.matrix_world


def build_rig(name, bones, pose, root_head=None):
    data = bpy.data.armatures.new(name)
    rig = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(rig)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for bone, parent, head, tail in bones:
        edit = data.edit_bones.new(bone)
        edit.head, edit.tail, edit.roll = head, tail, 0.0
        edit.matrix = pose.delta(bone) @ edit.matrix
        edit.use_connect = False
        if parent:
            edit.parent = made[parent]
        made[bone] = edit
    if root_head is not None:
        shift = Vector(root_head) - made["root"].head
        made["root"].head += shift
        made["root"].tail += shift
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def skin(obj, rig):
    obj.modifiers.new("skin", "ARMATURE").object = rig
    obj.parent = rig


def key_clips(rig, clips, facing=None):
    """clips: name -> (first, last, sample(frame) -> (rotations, moves, scales)); one NLA track per clip."""
    facing = facing if facing is not None else Matrix.Identity(3)
    rig.animation_data_create()
    for clip_name, (first, last, sample) in clips.items():
        action = bpy.data.actions.new(f"{clip_name}_{rig.name}")
        action.use_fake_user = True
        rig.animation_data.action = action
        previous = {}
        frames = list(range(first, last, KEY_STEP)) + [last]
        for frame in frames:
            rotations, moves, scales = sample(frame)
            for bone in rig.pose.bones:
                rest = bone.bone.matrix_local.to_3x3()
                world = facing @ euler(rotations.get(bone.name, (0, 0, 0))) @ facing.inverted()
                quaternion = (rest.inverted() @ world @ rest).to_quaternion()
                if bone.name in previous and previous[bone.name].dot(quaternion) < 0:
                    quaternion.negate()
                previous[bone.name] = quaternion
                bone.rotation_mode = "QUATERNION"
                bone.rotation_quaternion = quaternion
                bone.location = rest.inverted() @ (facing @ Vector(moves.get(bone.name, (0, 0, 0))))
                bone.scale = (scales.get(bone.name, 1.0),) * 3
                for path in ("rotation_quaternion", "location", "scale"):
                    bone.keyframe_insert(path, frame=frame, group=bone.name)
        slot = rig.animation_data.action_slot
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip_name
        strip = track.strips.new(clip_name, first, action)
        strip.action_slot = slot
    for bone in rig.pose.bones:
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)
