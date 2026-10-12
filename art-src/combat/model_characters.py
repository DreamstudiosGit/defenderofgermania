import math

from model_character_details import ellipse, heraldry, loft, mail_links, rounded, shield, side_panel, timber, tube
from model_primitives import beam, box, cone, mesh, plate


def soldier(team, role, seated=False):
    height = 1.04 if seated else 0.0
    for side in (-1, 1):
        x = side * (0.43 if seated else 0.17)
        loft("trousers", [(height + 0.22, 0.10, 0.105, x, 0.015),
                           (height + 0.43, 0.13, 0.14, x, 0.015),
                           (height + 0.62, 0.145, 0.15, x * 0.88, 0)], "mail", side, 12)
        rounded("boot_toe", (x, -0.087, height + 0.11), (0.145, 0.235, 0.115), "leather", side)
        loft("boot_leg", [(height + 0.10, 0.11, 0.13, x, 0),
                          (height + 0.29, 0.11, 0.12, x, 0),
                          (height + 0.32, 0.135, 0.14, x, 0)], "leather", side, 12)
        loft("boot_fold", [(height + 0.265, 0.142, 0.145, x, 0),
                           (height + 0.34, 0.15, 0.15, x, 0),
                           (height + 0.365, 0.125, 0.13, x, 0)], "wood", side, 12)
    loft("tunic_gold_hem", [(height + 0.57, 0.355, 0.24, 0, 0),
                            (height + 0.615, 0.35, 0.24, 0, 0)], "gold", folds=0.025)
    loft("tailored_tunic", [(height + 0.615, 0.35, 0.235, 0, 0),
                            (height + 0.77, 0.325, 0.23, 0, 0),
                            (height + 0.90, 0.275, 0.21, 0, 0),
                            (height + 1.08, 0.30, 0.225, 0, 0),
                            (height + 1.23, 0.33, 0.205, 0, 0),
                            (height + 1.32, 0.235, 0.18, 0, 0)], team, folds=0.016)
    tube("tunic_front_trim", [(0, -0.238, height + 0.595), (0, -0.228, height + 0.77),
                              (0, -0.22, height + 0.88)], 0.018, "gold")
    loft("waist_belt", [(height + 0.86, 0.29, 0.23, 0, 0),
                        (height + 0.95, 0.287, 0.224, 0, 0)], "leather")
    box("belt_buckle", (0, -0.243, height + 0.905), (0.13, 0.034, 0.115), "gold", 0.012)
    box("belt_buckle_inset", (0, -0.262, height + 0.905), (0.085, 0.012, 0.071), "leather", 0.008)
    tube("shoulder_baldric", [(-0.19, -0.17, height + 1.29), (-0.06, -0.244, height + 1.13),
                              (0.15, -0.239, height + 0.945)], 0.037, "wood")
    for side in (-1, 1):
        rounded("mail_sleeve", (side * 0.335, 0, height + 1.17), (0.15, 0.155, 0.23), "mail")
        hand_x, hand_y = (side * 0.275, -0.385) if role == "crossbowman" else (side * 0.40, -0.245)
        tube("gauntlet_arm", [(side * 0.37, 0, height + 1.16),
                              (side * 0.41, -0.16, height + 1.045),
                              (hand_x, hand_y, height + 1.035)], 0.094, "leather", taper=0.85)
        rounded("glove_palm", (hand_x, hand_y, height + 1.035), (0.107, 0.098, 0.115), "wood")
        for i in range(3):
            rounded("glove_finger", (hand_x + side * 0.016, hand_y - 0.075, height + 0.984 + i * 0.047),
                    (0.095, 0.047, 0.026), "leather", segments=8, rings=4)
    rounded("mail_coif", (0, 0.047, height + 1.60), (0.315, 0.28, 0.335), "mail")
    loft("mail_mantle", [(height + 1.245, 0.32, 0.232, 0, 0.02),
                         (height + 1.33, 0.282, 0.235, 0, 0.02),
                         (height + 1.435, 0.205, 0.18, 0, 0)], "mail", segments=16)
    mail_links(height)
    rounded("face", (0, -0.115, height + 1.61), (0.252, 0.226, 0.27), "skin", segments=20, rings=12)
    rounded("nose", (0.015, -0.352, height + 1.59), (0.089, 0.091, 0.078), "skin")
    for side in (-1, 1):
        x = side * 0.098
        rounded("eye_white", (x, -0.316, height + 1.684), (0.065, 0.033, 0.081), "white")
        rounded("eye_pupil", (x + 0.01, -0.347, height + 1.677), (0.029, 0.017, 0.046), "black", segments=12)
        rounded("eye_catchlight", (x + 0.019, -0.36, height + 1.702), (0.010, 0.006, 0.012), "white", segments=8, rings=4)
        tube("eyebrow", [(x - 0.052, -0.309, height + 1.783),
                         (x, -0.328, height + 1.797), (x + 0.05, -0.309, height + 1.786)], 0.018, "mane")
    tube("smile", [(-0.092, -0.317, height + 1.496), (-0.046, -0.338, height + 1.479),
                   (0.048, -0.337, height + 1.479), (0.102, -0.305, height + 1.504)], 0.009, "leather", segments=6)
    if role == "levy":
        rounded("cloth_cap", (0, 0.02, height + 1.85), (0.30, 0.27, 0.17), team)
        loft("cap_band", [(height + 1.79, 0.30, 0.265, 0, 0.02),
                          (height + 1.83, 0.31, 0.275, 0, 0.02)], "leather")
    else:
        helmet(height + 1.81, role)
    if role != "crossbowman":
        shield(-0.41, -0.34, height + 1.06, team, 1.0)
    if role == "crossbowman":
        crossbow(height)
    elif role in ("knight", "leader", "brabanter"):
        sword(0.40, -0.28, height + 1.04)
    elif role == "levy":
        beam("axe_handle", (0.40, -0.25, 0.78), (0.40, -0.25, 1.70), 0.034, "wood_light")
        plate("axe_blade", [(0.37, 1.46), (0.65, 1.40), (0.74, 1.49), (0.74, 1.66),
                            (0.67, 1.74), (0.37, 1.65)], -0.25, 0.036, "steel")
    if role in ("knight", "leader", "brabanter"):
        for side in (-1, 1):
            rounded("pauldron", (side * 0.31, 0, height + 1.285), (0.18, 0.185, 0.113), "steel")
        heraldry(0.10, -0.231, height + 1.12, 0.22, team)
    if role == "leader":
        plate("cape", [(-0.25, height + 1.29), (0.25, height + 1.29), (0.36, height + 0.58),
                       (0.10, height + 0.49), (-0.15, height + 0.52), (-0.38, height + 0.62)],
              0.24, 0.025, team)


def helmet(z, role):
    loft("helmet_dome", [(z, 0.31, 0.27, 0, 0.02), (z + 0.07, 0.302, 0.264, 0, 0.02),
                         (z + 0.16, 0.24, 0.22, 0, 0.02), (z + 0.225, 0.14, 0.135, 0, 0.02),
                         (z + 0.25, 0.02, 0.02, 0, 0.02)], "steel", segments=20)
    loft("helmet_shadow_rim", [(z - 0.036, 0.32, 0.277, 0, 0.02),
                               (z - 0.008, 0.322, 0.28, 0, 0.02)], "mail", segments=20)
    loft("helmet_steel_band", [(z - 0.007, 0.324, 0.281, 0, 0.02),
                               (z + 0.028, 0.322, 0.28, 0, 0.02)], "steel_light", segments=20)
    tube("helmet_crown_seam", [(0, -0.263, z + 0.01), (0, -0.229, z + 0.15),
                               (0, -0.10, z + 0.235), (0, 0.02, z + 0.257),
                               (0, 0.17, z + 0.208), (0, 0.274, z + 0.03)], 0.016, "steel_light")
    box("nasal_guard", (0, -0.277, z - 0.064), (0.048, 0.031, 0.245), "steel_light", 0.012)
    for x in (-0.247, -0.145, 0.145, 0.247):
        rounded("helmet_rivet", (x, -0.23 if abs(x) < 0.2 else -0.15, z + 0.006),
                (0.012, 0.012, 0.012), "steel", segments=8, rings=4)
    if role == "leader":
        loft("crown_band", [(z + 0.072, 0.30, 0.264, 0, 0.02),
                            (z + 0.129, 0.281, 0.25, 0, 0.02)], "gold")
        for i in range(6):
            angle = i * math.tau / 6
            cone("crown_point", (0.28 * math.cos(angle), 0.245 * math.sin(angle) + 0.02, z + 0.175),
                 0.036, 0.155, "gold", vertices=6)


def sword(x, y, z):
    beam("sword_grip", (x, y, z - 0.08), (x, y, z + 0.15), 0.038, "leather")
    rounded("sword_pommel", (x, y, z - 0.105), (0.05, 0.045, 0.057), "gold")
    tube("sword_guard", [(x - 0.15, y, z + 0.145), (x, y, z + 0.185),
                         (x + 0.15, y, z + 0.145)], 0.024, "gold")
    vertices = [(x, y - 0.02, z + 0.20), (x - 0.045, y, z + 0.20),
                (x + 0.045, y, z + 0.20), (x, y - 0.018, z + 0.82),
                (x - 0.03, y, z + 0.82), (x + 0.03, y, z + 0.82), (x, y, z + 0.99)]
    mesh("sword_blade", vertices, [(1, 0, 3, 4), (0, 2, 5, 3), (4, 3, 6), (3, 5, 6),
                                 (1, 4, 6, 5, 2), (2, 0, 1)], "steel_light")


def crossbow(height):
    box("crossbow_stock", (0, -0.40, height + 1.055), (0.085, 0.57, 0.08), "wood_light", 0.018)
    tube("crossbow_lath", [(-0.405, -0.475, height + 1.10), (-0.27, -0.57, height + 1.11),
                           (0, -0.655, height + 1.12), (0.27, -0.57, height + 1.11),
                           (0.405, -0.475, height + 1.10)], 0.026, "wood", segments=8)
    for side in (-1, 1):
        beam("bowstring", (side * 0.405, -0.475, height + 1.10),
             (0, -0.27, height + 1.10), 0.006, "cream", vertices=4)
    beam("bolt", (0, -0.27, height + 1.15), (0, -0.78, height + 1.15), 0.011, "wood_light")
    cone("bolt_head", (0, -0.795, height + 1.15), 0.024, 0.075, "steel", vertices=4).rotation_euler.x = math.pi / 2
    box("bolt_fletching", (0, -0.29, height + 1.17), (0.057, 0.07, 0.011), "white")


def horse(team, leader=False):
    coat = "cream" if leader else "horse"
    body = loft("horse_barrel", [(-0.76, 0.14, 0.22, 0, 0), (-0.59, 0.34, 0.39, 0, 0),
                                 (-0.20, 0.37, 0.43, 0, 0), (0.30, 0.35, 0.39, 0, 0),
                                 (0.56, 0.25, 0.32, 0, 0), (0.68, 0.10, 0.21, 0, 0)], coat, segments=20)
    body.rotation_euler.x = math.pi / 2
    body.location = (0, 0.02, 1.13)
    loft("horse_neck", [(1.12, 0.265, 0.26, 0, -0.48), (1.42, 0.225, 0.255, 0, -0.60),
                        (1.72, 0.17, 0.20, 0, -0.71), (1.95, 0.155, 0.16, 0, -0.75)], coat)
    rounded("horse_skull", (0, -0.82, 1.96), (0.215, 0.30, 0.235), coat, segments=20, rings=10)
    muzzle = rounded("horse_muzzle", (0, -1.075, 1.865), (0.19, 0.225, 0.16), coat)
    muzzle.rotation_euler.x = -0.25
    for side in (-1, 1):
        loft("horse_ear", [(2.13, 0.069, 0.067, side * 0.135, -0.71),
                           (2.27, 0.065, 0.044, side * 0.155, -0.73),
                           (2.38, 0.015, 0.015, side * 0.17, -0.735)], coat, segments=10)
        rounded("horse_ear_inset", (side * 0.156, -0.767, 2.26), (0.035, 0.012, 0.080), "wood")
        rounded("horse_eye_white", (side * 0.201, -0.88, 2.023), (0.024, 0.074, 0.079), "white")
        rounded("horse_eye_pupil", (side * 0.224, -0.903, 2.02), (0.012, 0.035, 0.045), "black")
        rounded("horse_nostril", (side * 0.125, -1.253, 1.875), (0.032, 0.018, 0.040), "mane")
        tube("bridle_cheek", [(side * 0.182, -0.70, 2.15), (side * 0.226, -0.86, 1.985),
                              (side * 0.181, -1.10, 1.849)], 0.017, "leather")
        rounded("bridle_buckle", (side * 0.241, -0.855, 1.985), (0.018, 0.034, 0.034), "gold")
        tube("horse_mouth", [(side * 0.156, -1.218, 1.809), (side * 0.13, -1.084, 1.754),
                             (side * 0.165, -1.015, 1.779)], 0.008, "mane", segments=6)
        side_panel(side, team)
        for front in (-1, 1):
            x, y, phase = side * 0.26, front * 0.47, side * front
            loft("horse_leg", [(0.19, 0.065, 0.082, x, y - 0.025),
                               (0.44, 0.065, 0.072, x, y + 0.035),
                               (0.57, 0.095, 0.105, x, y + 0.055),
                               (0.89, 0.125, 0.16, x, y + 0.015),
                               (1.16, 0.145, 0.19, x, y)], coat, phase, 12)
            rounded("horse_sock", (x, y - 0.025, 0.22), (0.079, 0.105, 0.155), "cream", phase)
            loft("horse_hoof", [(0.025, 0.115, 0.155, x, y - 0.075),
                                (0.13, 0.112, 0.145, x, y - 0.068),
                                (0.195, 0.074, 0.099, x, y - 0.025)], "leather", phase, 12)
    for i in range(5):
        side = 1 if i % 2 else -1
        tube("mane_swept_lock", [(0, -0.71 + i * 0.062, 2.18 - i * 0.13),
                                 (side * 0.075, -0.43 + i * 0.036, 1.99 - i * 0.12),
                                 (side * 0.115, -0.32 + i * 0.029, 1.87 - i * 0.13)],
             0.065, "mane", taper=0.15)
    tube("forelock", [(0, -0.72, 2.21), (-0.09, -0.87, 2.18), (-0.17, -0.97, 2.10)], 0.069, "mane", taper=0.15)
    for i in (-1, 0, 1):
        tube("horse_tail", [(i * 0.037, 0.62, 1.36), (i * 0.053, 0.93, 1.14),
                            (i * 0.065, 1.03, 0.70), (i * 0.067, 1.12, 0.45)],
             0.065, "mane", taper=0.3)
    box("saddle_seat", (0, 0.10, 1.535), (0.50, 0.51, 0.115), "leather", 0.065)
    rounded("saddle_cantle", (0, 0.34, 1.565), (0.265, 0.076, 0.12), "leather")
    tube("noseband", [(-0.18, -1.105, 1.948), (0, -1.215, 1.965), (0.18, -1.105, 1.948)], 0.021, "leather")
    chest = [(-0.25, 1.50), (0.25, 1.50), (0.32, 1.13), (0, 0.98), (-0.32, 1.13)]
    plate("horse_chest_gold_trim", chest, -0.875, 0.026, "gold")
    plate("horse_chest_cloth", [(x * 0.89, (z - 1.25) * 0.86 + 1.25) for x, z in chest],
          -0.893, 0.019, team)
    heraldry(0, -0.911, 1.28, 0.25, team)
    for side in (-1, 1):
        tube("reins", [(side * 0.215, -0.94, 1.935), (side * 0.27, -0.53, 1.62),
                       (side * 0.36, -0.18, 2.03)], 0.010, "leather", segments=6)


def spear(wood="wood_light", iron="steel", blade="steel_light"):
    beam("spear_shaft", (0, 0, 0), (0, 0, 2.71), 0.029, wood)
    cone("spear_socket", (0, 0, 2.71), 0.05, 0.14, iron, 0.039)
    vertices = [(0, 0, 3.17), (-0.095, 0, 2.83), (0, -0.038, 2.83),
                (0.095, 0, 2.83), (0, 0.038, 2.83), (0, 0, 2.72)]
    mesh("spearhead", vertices, [(0, i, i % 4 + 1) for i in range(1, 5)]
         + [(5, i % 4 + 1, i) for i in range(1, 5)], blade)
    cone("spear_foot", (0, 0, 0.035), 0.032, 0.07, iron, 0.032)


def trebuchet(team):
    for x in (-0.77, 0.77):
        box("carriage_rail", (x, 0, 0.41), (0.15, 2.55, 0.19), "wood", 0.025)
        for y in (-0.85, 0.85):
            wheel_x = x * 1.23
            wheel = cone("wheel", (wheel_x, y, 0.32), 0.31, 0.105, "wood", 0.31, 16)
            wheel.rotation_euler.y = math.pi / 2
            rim = ellipse("wheel_iron_rim", (0, 0, 0), 0.302, 0.302, 0.025, "steel", samples=16)
            rim.rotation_euler.z = math.pi / 2
            rim.location = (wheel_x + math.copysign(0.065, wheel_x), y, 0.32)
            for i in range(4):
                angle = i * math.pi / 4
                face_x = wheel_x + math.copysign(0.067, wheel_x)
                beam("wheel_spoke", (face_x, y - math.cos(angle) * 0.25, 0.32 - math.sin(angle) * 0.25),
                     (face_x, y + math.cos(angle) * 0.25, 0.32 + math.sin(angle) * 0.25), 0.032, "wood_light")
            rounded("wheel_hub", (wheel_x + math.copysign(0.085, wheel_x), y, 0.32), (0.07, 0.077, 0.077), "gold")
        timber("frame_front", (x, -0.96, 0.48), (x, 0, 1.66), 0.13)
        timber("frame_back", (x, 0.92, 0.48), (x, 0, 1.66), 0.13)
    for y in (-0.93, 0, 0.92):
        box("crossbrace", (0, y, 0.43), (1.67, 0.14, 0.14), "wood", 0.023)
    beam("pivot_axle", (-0.98, 0, 1.6), (0.98, 0, 1.6), 0.082, "steel")
    timber("throwing_arm", (0, 0.75, 1.14), (0, -1.48, 2.52), 0.13)
    box("counterweight", (0, 0.73, 0.98), (0.48, 0.36, 0.48), "wood", 0.035)
    rounded("throwing_cup", (0, -1.56, 2.53), (0.32, 0.31, 0.14), "leather")
    rounded("ammo", (0, -1.56, 2.67), (0.22, 0.22, 0.22), "stone", segments=12, rings=8)
    shield(-0.85, -0.22, 1.02, team, 0.64)
    for x in (-1.24, 1.24):
        for y in (0.39, 0.78):
            rounded("spare_stone", (x, y, 0.19), (0.18, 0.18, 0.18), "stone", segments=12, rings=8)
