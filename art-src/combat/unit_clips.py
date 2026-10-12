"""Human clips as rotation deltas (degrees, armature axes: +X tilts an upright bone forward and swings
a hanging limb back) on top of each role's rest pose. Weapons ride on hand.R, so hand.R
counter-rotates wherever the weapon must stay level or upright."""
import math

TAU = math.tau


def key(frame, rot=None, move=None, scale=None):
    return frame, rot or {}, move or {}, scale or {}


def both(bone, x=0.0, y=0.0, z=0.0):
    return {f"{bone}.L": (x, y, z), f"{bone}.R": (x, -y, -z)}


def merge(*parts):
    result = {}
    for item in parts:
        result.update(item)
    return result


def _mix(a, b, u, default):
    out = {}
    for name in set(a) | set(b):
        x, y = a.get(name, default), b.get(name, default)
        out[name] = (x + (y - x) * u if isinstance(x, (int, float))
                     else tuple(p + (q - p) * u for p, q in zip(x, y)))
    return out


def table(keys):
    """Eased (smoothstep) interpolation between authored keys; returns a clip (first, last, sample)."""
    def sample(frame):
        for (f0, *a), (f1, *b) in zip(keys, keys[1:]):
            if frame <= f1:
                u = (frame - f0) / (f1 - f0)
                u = u * u * (3 - 2 * u)
                return (_mix(a[0], b[0], u, (0, 0, 0)), _mix(a[1], b[1], u, (0, 0, 0)),
                        _mix(a[2], b[2], u, 1.0))
        return keys[-1][1:]
    return keys[0][0], keys[-1][0], sample


def idle(offset=0.0):
    def sample(frame):
        t = (frame - 1) / 48 + offset
        breath = math.sin(t * TAU)
        return (merge({"spine": (breath, 0, 0), "chest": (1.5 * breath, 0, 0),
                       "head": (-1.5 * breath, 0, 10 * math.sin(t * TAU))},
                      both("upper_arm", 2.0 * breath)), {}, {})
    return 1, 49, sample


def walk(arm_left=22.0, arm_right=22.0, push=False):
    def sample(frame):
        t = (frame - 1) / 24
        s, c = math.sin(t * TAU), math.cos(t * TAU)
        rot = {"thigh.L": (-28 * s, 0, 0), "thigh.R": (28 * s, 0, 0),
               "shin.L": (42 * max(0.0, c), 0, 0), "shin.R": (42 * max(0.0, -c), 0, 0),
               "pelvis": (0, 0, -6 * s), "chest": (0, 0, 8 * s), "spine": (5, 0, 0), "head": (-3, 0, 0)}
        if push:
            rot.update(both("upper_arm", -55))
            rot.update(both("forearm", -45))
        else:
            rot.update({"upper_arm.L": (arm_left * s, 0, 0), "upper_arm.R": (-arm_right * s, 0, 0)})
        return rot, {"root": (-0.015 * c, 0, 0.03 - 0.06 * s * s)}, {}
    return 1, 25, sample


def _swing_keys(lunge):
    legs = {"thigh.L": (-15, 0, 0), "shin.L": (12, 0, 0)} if lunge else {}
    move = {"root": (0, -0.06, 0)} if lunge else {}
    return [key(1),
            key(6, merge({"upper_arm.R": (-160, 8, 0), "forearm.R": (-100, 0, 0), "hand.R": (80, 0, 0),
                          "chest": (-10, 0, -15), "spine": (-5, 0, 0), "upper_arm.L": (20, 0, 0)})),
            key(10, merge({"upper_arm.R": (-35, 0, 0), "forearm.R": (-10, 0, 0), "hand.R": (150, 0, 0),
                           "chest": (20, 0, 20), "spine": (8, 0, 0), "head": (10, 0, 0),
                           "upper_arm.L": (-15, 0, 0)}, legs), move),
            key(13, merge({"upper_arm.R": (-20, 0, 0), "forearm.R": (-5, 0, 0), "hand.R": (140, 0, 0),
                           "chest": (24, 0, 24), "spine": (8, 0, 0)}, legs), move),
            key(19)]


def attack(style):
    if style == "swing":
        return table(_swing_keys(True))
    if style == "sword":
        return table(_swing_keys(False))
    if style == "flail":
        return table([key(1),
                      key(4, {"upper_arm.R": (-160, 8, 0), "forearm.R": (-100, 0, 0), "hand.R": (80, 0, 0),
                              "chest": (-10, 0, -20)}, {"root": (0, 0, 0.05)}),
                      key(7, {"upper_arm.R": (-35, 0, 0), "forearm.R": (-10, 0, 0), "hand.R": (150, 0, 0),
                              "chest": (20, 0, 25), "head": (10, 0, 0)}, {"root": (0, -0.05, 0)}),
                      key(10, {"upper_arm.R": (-110, 60, 0), "forearm.R": (-80, 0, 0), "hand.R": (60, 0, 0),
                               "chest": (0, 0, -30)}, {"root": (0, -0.05, 0.06)}),
                      key(13, {"upper_arm.R": (-60, -30, 0), "forearm.R": (-20, 0, 0), "hand.R": (140, 0, 0),
                               "chest": (15, 0, 35)}, {"root": (0, -0.08, 0)}),
                      key(19)])
    if style == "thrust":
        cocked = {"upper_arm.R": (25, 0, 0), "forearm.R": (-30, 0, 0), "hand.R": (80, 0, 0),
                  "chest": (0, 0, -18), "spine": (5, 0, 0), "upper_arm.L": (-25, 0, 0)}
        lunge = {"upper_arm.R": (-45, 0, 0), "forearm.R": (-20, 0, 0), "hand.R": (150, 0, 0),
                 "chest": (10, 0, 15), "upper_arm.L": (-30, 0, 0), "thigh.L": (-22, 0, 0),
                 "shin.L": (18, 0, 0), "thigh.R": (10, 0, 0)}
        return table([key(1), key(5, cocked), key(9, lunge, {"root": (0, -0.10, 0)}),
                      key(12, lunge, {"root": (0, -0.10, 0)}), key(19)])
    if style == "lance":
        couched = {"upper_arm.R": (20, 0, 0), "forearm.R": (-15, 0, 0), "hand.R": (82, 0, 0), "chest": (12, 0, 0)}
        thrust = {"upper_arm.R": (-15, 0, 0), "forearm.R": (-15, 0, 0), "hand.R": (82, 0, 0), "chest": (22, 0, 12)}
        return table([key(1), key(6, couched), key(10, thrust), key(13, thrust), key(19)])
    if style == "shoot":
        aim = merge({"thigh.L": (-88, 0, 0), "shin.L": (88, 0, 0), "shin.R": (88, 0, 0), "foot.R": (-30, 0, 0),
                     "chest": (5, 0, 0), "head": (12, 0, 0), "hand.R": (90, 0, 0)},
                    both("upper_arm", -50), both("forearm", -40))
        kneel = {"root": (0, 0, -0.37)}
        recoil = merge(aim, {"chest": (-6, 0, 0), "upper_arm.R": (-58, 0, 0), "upper_arm.L": (-58, 0, 0),
                             "head": (4, 0, 0)})
        span = merge({"thigh.L": (-45, 0, 0), "shin.L": (30, 0, 0), "chest": (42, 0, 0), "hand.R": (78, 0, 0)},
                     both("upper_arm", -10), both("forearm", -20))
        pull = merge(span, {"chest": (15, 0, 0)}, both("forearm", -70))
        return table([key(1), key(6, aim, kneel), key(10, aim, kneel), key(12, recoil, kneel),
                      key(16, aim, kneel), key(22, span, {"root": (0, 0, -0.05)}), key(28, pull), key(33), key(37)])
    if style == "haul":
        crank_a = merge({"chest": (15, 0, 0)}, both("upper_arm", -60), both("forearm", -50))
        crank_b = merge({"chest": (15, 0, 0)}, both("upper_arm", -30), both("forearm", -80))
        return table([key(1),
                      key(4, merge({"chest": (-5, 0, 0)}, both("upper_arm", -150), both("forearm", -10)),
                          {"root": (0, 0, 0.03)}),
                      key(7, merge({"chest": (25, 0, 0)}, both("upper_arm", -40), both("forearm", -60),
                                   both("thigh", -25), both("shin", 40)), {"root": (0, 0, -0.10)}),
                      key(10, merge({"chest": (20, 0, 0)}, both("upper_arm", -40), both("forearm", -60))),
                      key(14, merge({"head": (-25, 0, 0), "chest": (-10, 0, 0)}, both("upper_arm", -20))),
                      key(18, merge(both("upper_arm", -160, -20), {"head": (-15, 0, 0)}), {"root": (0, 0, 0.12)}),
                      key(22, both("upper_arm", -150, -20)),
                      key(28, crank_a), key(33, crank_b), key(38, crank_a), key(43, crank_b), key(48)])
    raise ValueError(style)


def hit(rider=False):
    move = {} if rider else {"root": (0, 0.10, 0.04)}
    legs = {} if rider else {"thigh.L": (-15, 0, 0)}
    return table([key(1),
                  key(3, merge({"chest": (-22, 0, 0), "spine": (-8, 0, 0), "head": (-25, 0, 0)},
                               both("upper_arm", 10, -40), legs), move),
                  key(6, {"chest": (-12, 0, 0), "head": (-12, 0, 0)}, {} if rider else {"root": (0, 0.12, 0)}),
                  key(9, {"chest": (6, 0, 0), "head": (5, 0, 0)}, {} if rider else {"root": (0, 0.08, 0)}),
                  key(13)])


def death():
    arms_up = both("upper_arm", -170, -30)
    return table([key(1),
                   key(4, merge({"root": (-20, 0, 0), "chest": (-15, 0, 0), "head": (-25, 0, 0),
                                 "thigh.L": (-35, 0, 0), "shin.L": (30, 0, 0), "thigh.R": (10, 0, 0)},
                                both("upper_arm", -140, -25)), {"root": (0, 0.10, 0.22)}),
                   key(9, merge({"root": (-60, 0, 20)}, arms_up, both("thigh", -45), both("shin", 25)),
                       {"root": (0, 0.30, 0.30)}),
                   key(13, merge({"root": (-90, 0, 25), "head": (-10, 0, 0)}, both("upper_arm", -175, -35),
                                 both("thigh", -55), both("shin", 20)), {"root": (0, 0.45, 0.20)}),
                   key(16, merge({"root": (-85, 0, 25)}, both("upper_arm", -160, -50), both("thigh", -85),
                                 both("shin", 10)), {"root": (0, 0.50, 0.30)}),
                   key(20, merge({"root": (-90, 0, 25)}, both("upper_arm", -170, -45), both("thigh", -40)),
                       {"root": (0, 0.52, 0.20)}),
                   key(31, {"root": (-90, 0, 25), "thigh.L": (-60, 0, 0), "shin.L": (70, 0, 0),
                            "thigh.R": (-10, 0, 0), "shin.R": (5, 0, 0), "upper_arm.L": (-150, -50, 0),
                            "upper_arm.R": (-170, 40, 0), "head": (-5, 0, 30)}, {"root": (0, 0.52, 0.20)})])


def rider_death():
    return table([key(1),
                  key(4, merge({"root": (-25, 0, 0), "chest": (-10, 0, 0)}, both("upper_arm", -150, -25),
                               both("thigh", 20)), {"root": (0, 0.05, 0.15)}),
                  key(9, merge({"root": (-70, 0, 10)}, both("upper_arm", -170, -30)), {"root": (0, 0.45, 0.10)}),
                  key(14, merge({"root": (-100, 0, 15)}, both("upper_arm", -170, -40), both("thigh", 10)),
                      {"root": (0, 0.95, -1.15)}),
                  key(17, merge({"root": (-95, 0, 15)}, both("upper_arm", -160, -45)), {"root": (0, 1.0, -1.05)}),
                  key(21, merge({"root": (-100, 0, 15)}, both("upper_arm", -165, -45)), {"root": (0, 1.02, -1.20)}),
                  key(31, merge({"root": (-100, 0, 15), "thigh.L": (-30, 0, 0), "head": (0, 0, 30)},
                                both("upper_arm", -150, -45)), {"root": (0, 1.02, -1.20)})])


def cheer(rider=False):
    if rider:
        up = {"upper_arm.R": (-160, 15, 0), "forearm.R": (-10, 0, 0), "hand.R": (150, 0, 0),
              "chest": (-8, 0, 0), "head": (-10, 0, 0)}
        high = merge(up, {"upper_arm.R": (-175, 15, 0), "hand.R": (165, 0, 0)})
        return table([key(1, up), key(7, high), key(13, up), key(19, high), key(25, up)])
    arms = merge(both("upper_arm", -155, -20), both("forearm", -10), {"hand.R": (140, 0, 0)})
    tuck = merge(arms, both("upper_arm", -170, -20), both("thigh", -15), both("shin", 30))
    land = merge(arms, both("thigh", -20), both("shin", 35))
    return table([key(1, arms), key(7, tuck, {"root": (0, 0, 0.16)}), key(13, land, {"root": (0, 0, -0.05)}),
                  key(19, tuck, {"root": (0, 0, 0.16)}), key(25, arms)])


def human_clips(attack_style, arm_swing=(22.0, 22.0), offset=0.0):
    return {"idle": idle(offset), "walk": walk(*arm_swing), "attack": attack(attack_style),
            "hit": hit(), "death": death(), "cheer": cheer()}
