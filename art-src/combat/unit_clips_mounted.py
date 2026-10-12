"""Horse clips plus the rider's clips, re-rooted every key so the rider stays in the moving saddle."""
import math

from mathutils import Matrix, Vector

from unit_clips import TAU, attack, both, cheer, hit, idle, key, merge, rider_death, table
from unit_rig import HORSE, SADDLE, Pose, euler

HIND_HOOVES = Vector((0, 0.45, 0.0))
TROT = {"front.L": 0.0, "hind.R": 0.0, "front.R": 0.5, "hind.L": 0.5}
GALLOP = {"front.L": 0.0, "front.R": 0.08, "hind.L": 0.5, "hind.R": 0.58}
WALK = {"hind.L": 0.0, "front.L": 0.25, "hind.R": 0.5, "front.R": 0.75}
GAIT_FRAMES = {"walk": 24, "horse_trot": 16, "horse_gallop": 12, "horse_charge": 12}


def pivot(rotation, point=HIND_HOOVES):
    """Root move that keeps `point` in place while the root (head at the origin) rotates."""
    return tuple(Vector(point) - euler(rotation) @ Vector(point))


def _legs(t, phases, swing, fold_front, fold_hind):
    rot = {}
    for leg, phase in phases.items():
        kind, side = leg.split(".")
        s, c = math.sin((t + phase) * TAU), math.cos((t + phase) * TAU)
        rot[f"{kind}_upper.{side}"] = (-swing * s, 0, 0)
        rot[f"{kind}_lower.{side}"] = ((fold_front if kind == "front" else fold_hind) * max(0.0, c), 0, 0)
    return rot


def gait(kind):
    length = GAIT_FRAMES[kind]

    def sample(frame):
        t = (frame - 1) / length
        s, c = math.sin(t * TAU), math.cos(t * TAU)
        s2, c2 = math.sin(2 * t * TAU), math.cos(2 * t * TAU)
        if kind == "walk":
            rot = merge(_legs(t, WALK, 16, 35, 30), {"neck": (4 * c2, 0, 0), "head": (-3 * c2, 0, 0),
                                                     "tail": (8, 0, 6 * s)})
            return rot, {"root": (0, 0, 0.015 * c2)}, {}
        if kind == "horse_trot":
            rot = merge(_legs(t, TROT, 24, 60, 45), {"body": (2 * s2, 0, 0), "neck": (5 * c2, 0, 0),
                                                     "head": (-4 * c2, 0, 0), "tail": (12 + 6 * s2, 0, 6 * s)})
            return rot, {"root": (0, 0, 0.035 * c2)}, {}
        charge = kind == "horse_charge"
        k = 1.15 if charge else 1.0
        rot = merge(_legs(t, GALLOP, 45 * k, 80, 60),
                    {"body": (-8 * k * s, 0, 0), "neck": ((22 if charge else 0) + 10 * s, 0, 0),
                     "head": ((-12 if charge else 0) - 6 * s, 0, 0), "tail": (25, 0, 5 * s)})
        return rot, {"root": (0, 0, (-0.04 if charge else 0.0) + 0.05 * (1 + c))}, {}
    return 1, length + 1, sample


def horse_idle():
    def sample(frame):
        t = (frame - 1) / 48
        stamp = max(0.0, 1 - abs(t - 0.65) / 0.1)
        return ({"neck": (3 * math.sin(t * TAU), 0, 0), "head": (-5 * math.sin(t * TAU), 0, 0),
                 "tail": (5, 0, 10 * math.sin(2 * t * TAU)), "front_upper.R": (-20 * stamp, 0, 0),
                 "front_lower.R": (60 * stamp, 0, 0)}, {}, {})
    return 1, 49, sample


def horse_attack():
    rear = (-10, 0, 0)
    return table([key(1),
                  key(6, merge({"root": rear, "neck": (-12, 0, 0)}, both("front_upper", -40), both("front_lower", 70)),
                      {"root": pivot(rear)}),
                  key(10, merge({"root": (2, 0, 0)}, both("front_upper", 5)), {"root": pivot((2, 0, 0))}),
                  key(13), key(19)])


def horse_hit():
    return table([key(1), key(3, {"root": (0, 0, 6), "neck": (-15, 0, 0), "head": (-15, 0, 0), "body": (-4, 0, 0)},
                          {"root": (0, 0.05, 0)}),
                  key(6, {"neck": (-8, 0, 0)}), key(13)])


def horse_death():
    rolled = {"root": (0, 82, 0), "neck": (25, 0, 0)}
    return table([key(1),
                  key(6, merge({"body": (6, 0, 0), "neck": (10, 0, 0)}, both("front_upper", -20),
                               both("front_lower", 100)), {"root": (0, 0, -0.10)}),
                  key(9, merge({"body": (10, 0, 0)}, both("front_upper", -25), both("front_lower", 110),
                               both("hind_upper", -15), both("hind_lower", 40)), {"root": (0, 0, -0.30)}),
                  key(14, merge(rolled, {"root": (0, 80, 0)}, both("front_lower", 20)), {"root": (0, 0, 0.16)}),
                  key(17, merge(rolled, {"root": (0, 74, 0)}), {"root": (0, 0, 0.24)}),
                  key(21, rolled, {"root": (0, 0, 0.17)}),
                  key(31, merge(rolled, {"head": (10, 0, 0), "hind_lower.L": (30, 0, 0)}, both("front_lower", 20)),
                      {"root": (0, 0, 0.17)})])


def horse_rear():
    def reared(angle, legs):
        return merge({"root": (angle, 0, 0), "neck": (-18, 0, 0), "tail": (20, 0, 0)}, legs)
    high = reared(-26, merge(both("front_upper", -55), both("front_lower", 85)))
    paddle = reared(-22, merge({"front_upper.L": (-35, 0, 0), "front_upper.R": (-60, 0, 0)},
                               both("front_lower", 80)))
    return table([key(1), key(7, high, {"root": pivot((-26, 0, 0))}), key(13, paddle, {"root": pivot((-22, 0, 0))}),
                  key(19, {"root": (-6, 0, 0)}, {"root": pivot((-6, 0, 0))}), key(25)])


def ride(length, lean=2.0, sway=2.0, extra=None):
    def sample(frame):
        t = (frame - 1) / length
        return merge({"spine": (lean + sway * math.sin(t * TAU * 2), 0, 0)}, extra or {}), {}, {}
    return 1, length + 1, sample


def follow(horse_clip, rider_clip, attached=True):
    first, last, horse_sample = horse_clip
    rider_sample = rider_clip[2]

    def sample(frame):
        rot, move, scale = rider_sample(frame)
        saddle = Matrix.Identity(4)
        if attached:
            horse_rot, horse_move, _ = horse_sample(frame)
            saddle = Pose(HORSE, rotations=horse_rot, moves=horse_move).delta("body")
        own = (Matrix.Translation(Vector(move.get("root", (0, 0, 0))) + SADDLE)
               @ euler(rot.get("root", (0, 0, 0))).to_4x4() @ Matrix.Translation(-SADDLE))
        total = saddle @ own
        return (merge(rot, {"root": total.to_3x3()}), merge(move, {"root": tuple(total @ SADDLE - SADDLE)}),
                scale)
    return first, last, sample


def mounted_clips(attack_style, charge_arm):
    """(horse clips, rider clips); every name exists on both rigs with the same frame range."""
    horse = {"idle": horse_idle(), "walk": gait("walk"), "attack": horse_attack(), "hit": horse_hit(),
             "death": horse_death(), "cheer": horse_rear(), "horse_trot": gait("horse_trot"),
             "horse_gallop": gait("horse_gallop"), "horse_charge": gait("horse_charge")}
    rider = {"idle": idle(), "walk": ride(24), "attack": attack(attack_style), "hit": hit(rider=True),
             "death": rider_death(), "cheer": cheer(rider=True), "horse_trot": ride(16, 4, 2),
             "horse_gallop": ride(12, 10, 3),
             "horse_charge": ride(12, 6, 2, merge({"chest": (12, 0, 0)}, charge_arm))}
    return horse, {name: follow(horse[name], clip, name != "death") for name, clip in rider.items()}
