from model_character_details import loft, rounded
from model_primitives import box
from unit_shapes import limb, part

SIDES = (("L", 1), ("R", -1))


def body(kit, detail=1.0):
    """Stocky standing human in the rig's standard rest; every part is bound to a HUMAN bone.

    kit keys: hose, boots, coat, sleeves, cuffs, hands, hem_z, skirt, hem, collar, belt,
    quilt, mail_shirt, pauldrons, face, beard; simple drops toes, shoulders, eyes and the waist piece;
    rider keeps the legs out of the GPU stride mask (the horse walks, not the rider).
    """
    def n(base):
        return max(5, round(base * detail))

    legs(kit, n)
    torso(kit, n)
    arms(kit, n)
    head(kit, n)


def legs(kit, n):
    for side, sign in SIDES:
        x = 0.12 * sign
        stride = 0 if kit.get("rider") else sign
        with part(f"thigh.{side}", stride):
            loft("thigh", [(0.40, 0.088, 0.092, x, 0.0), (0.56, 0.10, 0.105, x, 0.0),
                           (0.68, 0.10, 0.105, x * 0.92, 0.0)], kit["hose"], segments=n(8))
        with part(f"shin.{side}", stride):
            loft("boot", [(0.04, 0.085, 0.10, x, -0.012), (0.30, 0.078, 0.085, x, 0.0),
                          (0.41, 0.093, 0.099, x, 0.0)], kit["boots"], segments=n(8))
        if kit.get("simple"):
            continue
        with part(f"foot.{side}", stride):
            rounded("boot_toe", (x, -0.085, 0.055), (0.085, 0.13, 0.06), kit["boots"],
                    segments=n(8), rings=4)


def torso(kit, n):
    coat, quilt = kit["coat"], kit.get("quilt", 0.0)
    skirt, hem_z = kit.get("skirt", coat), kit["hem_z"]
    simple = kit.get("simple", False)
    top = [(1.17, 0.275, 0.20, 0, 0.0)] if simple else [(0.93, 0.252, 0.186, 0, 0.0)]
    with part("pelvis"):
        loft("skirt", [(hem_z, 0.30, 0.235, 0, 0.0), (0.74, 0.275, 0.21, 0, 0.0)] + top,
             skirt, segments=n(12), folds=0.035)
        if kit.get("hem"):
            loft("skirt_hem", [(hem_z - 0.01, 0.305, 0.24, 0, 0.0), (hem_z + 0.055, 0.299, 0.234, 0, 0.0)],
                 kit["hem"], segments=n(12), folds=0.035)
        if kit.get("mail_shirt"):
            loft("mail_skirt", [(hem_z + 0.12, 0.31, 0.245, 0, 0.0), (0.93, 0.262, 0.196, 0, 0.0)],
                 "unit_mail", segments=n(12), folds=0.02)
    chest_color = "unit_mail" if kit.get("mail_shirt") else coat
    if simple:
        with part("chest"):
            loft("chest", [(1.13, 0.272, 0.198, 0, 0.0), (1.37, 0.285, 0.195, 0, 0.0),
                           (1.50, 0.08, 0.08, 0, 0.01)], chest_color, segments=n(12))
        return
    with part("spine"):
        loft("waist", [(0.88, 0.25, 0.185, 0, 0.0), (1.02, 0.258, 0.19, 0, 0.0),
                       (1.17, 0.275, 0.20, 0, 0.0)], chest_color, segments=n(12), folds=quilt)
        if kit.get("belt"):
            loft("belt", [(0.92, 0.263, 0.197, 0, 0.0), (0.985, 0.267, 0.201, 0, 0.0)],
                 kit["belt"], segments=n(12))
            box("belt_buckle", (0, -0.205, 0.952), (0.075, 0.02, 0.058), "unit_gold")
    with part("chest"):
        loft("chest", [(1.13, 0.272, 0.198, 0, 0.0), (1.28, 0.29, 0.205, 0, 0.0),
                       (1.39, 0.275, 0.19, 0, 0.0), (1.46, 0.17, 0.14, 0, 0.01),
                       (1.50, 0.075, 0.075, 0, 0.01)], chest_color, segments=n(12), folds=quilt)
        if kit.get("collar"):
            loft("collar", [(1.425, 0.205, 0.165, 0, 0.01), (1.475, 0.135, 0.12, 0, 0.01)],
                 kit["collar"], segments=n(12))
        for side, color in kit.get("pauldrons", ()):
            sign = 1 if side == "L" else -1
            rounded("pauldron", (0.275 * sign, 0.0, 1.395), (0.15, 0.15, 0.105), color,
                    segments=n(10), rings=5)


def arms(kit, n):
    for side, sign in SIDES:
        sleeve = kit["sleeves"][side] if isinstance(kit["sleeves"], dict) else kit["sleeves"]
        cuff = kit.get("cuffs", sleeve)
        cuff = cuff[side] if isinstance(cuff, dict) else cuff
        with part(f"upper_arm.{side}"):
            if not kit.get("simple"):
                rounded("shoulder", (0.285 * sign, 0.0, 1.365), (0.105, 0.105, 0.10), sleeve,
                        segments=n(10), rings=6)
            limb("upper_arm", [(0.295 * sign, 0, 1.34), (0.33 * sign, 0, 1.115)], [0.082, 0.072],
                 sleeve, n(8))
        with part(f"forearm.{side}"):
            limb("forearm", [(0.33 * sign, 0, 1.14), (0.35 * sign, -0.02, 0.925)], [0.074, 0.063],
                 cuff, n(8))
        with part(f"hand.{side}"):
            rounded("fist", (0.35 * sign, -0.03, 0.86), (0.068, 0.068, 0.072), kit["hands"],
                    segments=n(8), rings=4 if kit.get("simple") else 5)


def head(kit, n):
    with part("neck"):
        limb("neck", [(0, 0.0, 1.44), (0, 0.0, 1.57)], [0.075, 0.075], "unit_skin", n(8))
    if not kit.get("face", True):
        return
    with part("head"):
        rounded("face", (0, -0.005, 1.68), (0.155, 0.15, 0.172), "unit_skin", segments=n(12), rings=n(8))
        rounded("nose", (0, -0.163, 1.645), (0.048, 0.05, 0.055), "unit_skin", segments=n(8),
                rings=3 if kit.get("simple") else 5)
        for _, sign in () if kit.get("simple") else SIDES:
            rounded("eye", (0.058 * sign, -0.139, 1.70), (0.022, 0.014, 0.03), "unit_dark",
                    segments=6, rings=4)
        if kit.get("beard"):
            rounded("beard", (0, -0.07, 1.565), (0.14, 0.115, 0.09), kit["beard"],
                    segments=n(10), rings=5)
