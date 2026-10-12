"""Sword-fight clips of the castle raid fighters (M6). Key poses are solved with two-bone IK on the
fighter's own rest pose: a fist target and a blade direction for the sword hand, a fist target for
the shield hand and a few body turns. Keys are rotation matrices blended by quaternion slerp; walk,
hit, fall and cheer come from unit_clips."""
import math

from mathutils import Matrix, Vector

from unit_clips import cheer, death, hit, idle, walk
from unit_rig import FIST, HUMAN, Pose

TAU = math.tau
# Right-hand pole (elbow out and down) and left-hand pole (elbow out to the left).
POLE_R = (-0.7, 0.3, -0.5)
POLE_L = (0.9, 0.3, -0.5)


class Rig:
    """The fighter's rest pose as a bone set, so IK starts from where the figure stands."""

    def __init__(self, rest, blade):
        self.bones = tuple((name, parent, tuple(rest.point(name, head)), tuple(rest.point(name, tail)))
                           for name, parent, head, tail in HUMAN)
        self.fist = {side: rest.point(f"hand.{side}", FIST[side]) for side in ("L", "R")}
        self.blade = Vector(blade).normalized()


def _grip(pose, rig, side, at, pole):
    target = Vector(at)
    for _ in range(4):
        pose.reach(f"upper_arm.{side}", f"forearm.{side}", target, pole)
        target += Vector(at) - pose.point(f"hand.{side}", rig.fist[side])


def _aim(pose, bone, rest_dir, want):
    outer = pose.delta(pose.bones[bone][0]).to_3x3()
    current = pose.delta(bone).to_3x3() @ rest_dir
    turn = current.rotation_difference(Vector(want).normalized()).to_matrix()
    pose.rot[bone] = outer.inverted() @ turn @ outer @ pose.rot.get(bone, Matrix.Identity(3))
    pose._cache.clear()


def key(rig, sword, blade, shield=None, turns=None, root=(0.0, 0.0, 0.0), pole=POLE_R):
    """One key pose: rotations (matrices, armature axes, relative to the rest pose) and root move."""
    pose = Pose(rig.bones, moves={"root": root})
    for bone, angles in (turns or {}).items():
        pose.turn(bone, *angles)
    for _ in range(3):
        _grip(pose, rig, "R", sword, pole)
        _aim(pose, "hand.R", rig.blade, blade)
    if shield is not None:
        _grip(pose, rig, "L", shield, POLE_L)
    return dict(pose.rot), {"root": tuple(root)}


REST = ({}, {"root": (0.0, 0.0, 0.0)})


def _blend(a, b, u):
    out = {}
    for name in set(a) | set(b):
        qa = a.get(name, Matrix.Identity(3)).to_quaternion()
        qb = b.get(name, Matrix.Identity(3)).to_quaternion()
        if qa.dot(qb) < 0:
            qb.negate()
        out[name] = qa.slerp(qb, u).to_matrix()
    return out


def _lerp(a, b, u):
    names = set(a) | set(b)
    return {n: tuple(p + (q - p) * u for p, q in zip(a.get(n, (0, 0, 0)), b.get(n, (0, 0, 0)))) for n in names}


def clip(keys):
    """keys: [(frame, (rotations, moves))]; smoothstep between keys."""
    def sample(frame):
        for (f0, (r0, m0)), (f1, (r1, m1)) in zip(keys, keys[1:]):
            if frame <= f1:
                u = (frame - f0) / (f1 - f0)
                u = u * u * (3 - 2 * u)
                return _blend(r0, r1, u), _lerp(m0, m1, u), {}
        return keys[-1][1][0], keys[-1][1][1], {}
    return keys[0][0], keys[-1][0], sample


def sneak():
    """Crouched, slow walk with the sword held low."""
    def sample(frame):
        t = (frame - 1) / 32
        s, c = math.sin(t * TAU), math.cos(t * TAU)
        rot = {"thigh.L": (-42 - 18 * s, 0, 0), "thigh.R": (-42 + 18 * s, 0, 0),
               "shin.L": (72 + 22 * max(0.0, c), 0, 0), "shin.R": (72 + 22 * max(0.0, -c), 0, 0),
               "spine": (16, 0, 0), "chest": (10, 0, 5 * s), "head": (-22, 0, 0),
               "upper_arm.L": (-10 + 8 * s, 0, 0)}
        return rot, {"root": (0, 0.04, -0.15 - 0.015 * s * s)}, {}
    return 1, 33, sample


def raid_clips(rig, shield):
    """Clip set shared by raider and guard; guards also move their shield to the height."""
    def at(height_shield):
        return height_shield if shield else None

    guard_high = key(rig, (-0.18, -0.26, 1.62), (0.75, -0.55, 0.35), at((0.24, -0.36, 1.58)),
                     {"chest": (-4, 0, 0)})
    guard_low = key(rig, (-0.24, -0.32, 0.80), (0.15, -0.75, -0.6), at((0.24, -0.38, 0.82)),
                    {"spine": (8, 0, 0)}, (0, 0, -0.03))
    windups = {
        "high": key(rig, (-0.20, 0.06, 1.86), (0.05, 0.55, 0.85), at((0.28, -0.30, 1.30)),
                    {"chest": (-8, 0, -12), "spine": (-4, 0, 0)}),
        "mid": key(rig, (-0.46, 0.12, 1.22), (-0.35, 0.92, 0.15), at((0.30, -0.30, 1.15)),
                   {"chest": (0, 0, -28), "spine": (0, 0, -8)}),
        "low": key(rig, (-0.42, 0.12, 0.84), (-0.3, 0.55, -0.75), at((0.30, -0.28, 0.95)),
                   {"chest": (12, 0, -18), "spine": (8, 0, 0)}, (0, 0, -0.08)),
    }
    lunge = {"thigh.L": (-24, 0, 0), "shin.L": (20, 0, 0), "thigh.R": (10, 0, 0)}
    contacts = {
        "high": key(rig, (-0.08, -0.58, 1.40), (0.05, -0.8, -0.6), at((0.30, -0.20, 1.15)),
                    {"chest": (14, 0, 14), "spine": (8, 0, 0), **lunge}, (0, -0.10, -0.03)),
        "mid": key(rig, (0.06, -0.55, 1.16), (0.72, -0.68, 0.05), at((0.32, -0.10, 1.10)),
                   {"chest": (6, 0, 26), "spine": (0, 0, 8), **lunge}, (0, -0.10, -0.02)),
        "low": key(rig, (-0.06, -0.58, 0.66), (0.5, -0.75, -0.42), at((0.32, -0.18, 1.00)),
                   {"chest": (24, 0, 18), "spine": (12, 0, 0), **lunge}, (0, -0.10, -0.12)),
    }
    follows = {
        "high": key(rig, (-0.02, -0.44, 1.00), (0.1, -0.45, -0.9), at((0.30, -0.18, 1.12)),
                    {"chest": (20, 0, 18), "spine": (10, 0, 0), **lunge}, (0, -0.10, -0.05)),
        "mid": key(rig, (0.22, -0.36, 1.12), (0.92, -0.25, 0.0), at((0.34, -0.06, 1.08)),
                   {"chest": (6, 0, 34), "spine": (0, 0, 10), **lunge}, (0, -0.10, -0.02)),
        "low": key(rig, (0.10, -0.46, 0.62), (0.85, -0.45, -0.25), at((0.32, -0.16, 1.00)),
                   {"chest": (24, 0, 26), "spine": (12, 0, 0), **lunge}, (0, -0.10, -0.12)),
    }
    parries = {
        "high": key(rig, (-0.16, -0.34, 1.74), (0.97, -0.12, 0.12), at((0.24, -0.34, 1.62)),
                    {"chest": (-6, 0, 0)}),
        "mid": key(rig, (-0.06, -0.40, 1.14), (0.18, -0.25, 0.95), at((0.24, -0.40, 1.16)),
                   {"chest": (0, 0, 8)}),
        "low": key(rig, (-0.16, -0.40, 0.84), (0.25, -0.35, -0.9), at((0.24, -0.40, 0.78)),
                   {"chest": (14, 0, 6), "spine": (6, 0, 0)}, (0, 0, -0.06)),
    }
    kneel = {"thigh.L": (-88, 0, 0), "shin.L": (90, 0, 0), "thigh.R": (-5, 0, 0), "shin.R": (95, 0, 0),
             "spine": (14, 0, 0)}
    deed_a = key(rig, (-0.16, -0.48, 0.42), (0.1, -0.6, -0.8), at((0.24, -0.40, 0.50)), kneel, (0, 0, -0.33))
    deed_b = key(rig, (-0.10, -0.52, 0.50), (0.3, -0.7, -0.65), at((0.20, -0.44, 0.44)), kneel,
                 (0, 0, -0.33))
    clips = {"idle": idle(), "walk": walk(18.0, 6.0), "sneak": sneak(), "hit": hit(), "down": death(),
             "cheer": cheer(),
             "guard_high": clip([(1, guard_high), (9, guard_high)]),
             "guard_low": clip([(1, guard_low), (9, guard_low)]),
             "deed": clip([(1, deed_a), (9, deed_b), (17, deed_a)])}
    for height in ("high", "mid", "low"):
        clips[f"windup_{height}"] = clip([(1, REST), (9, windups[height])])
        clips[f"strike_{height}"] = clip([(1, windups[height]), (4, contacts[height]), (7, follows[height]),
                                          (16, REST)])
        clips[f"parry_{height}"] = clip([(1, REST), (3, parries[height]), (10, parries[height]), (16, REST)])
    return clips
