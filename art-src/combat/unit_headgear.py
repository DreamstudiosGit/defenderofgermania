import math

from model_character_details import loft, rounded
from model_primitives import box, cone
from unit_palette import HOUSE_PRIMARY, HOUSE_SECONDARY
from unit_shapes import limb, part

# Top centre of each helmet in the standard rest; the crest mounts here.
ANCHORS = {"kettle_hat": (0, 0.005, 1.905), "coif": (0, 0.035, 1.905), "great_helm": (0, 0.0, 1.90)}


def headgear(kind, detail=1.0, circlet=False):
    def n(base):
        return max(5, round(base * detail))

    with part("head"):
        if kind == "kettle_hat":
            loft("kettle_crown", [(1.775, 0.166, 0.163, 0, 0.005), (1.845, 0.155, 0.152, 0, 0.005),
                                  (1.89, 0.10, 0.097, 0, 0.005), (1.905, 0.03, 0.03, 0, 0.005)],
                 "unit_iron", segments=n(12))
            loft("kettle_brim", [(1.738, 0.30, 0.295, 0, 0.005), (1.764, 0.292, 0.287, 0, 0.005),
                                 (1.792, 0.168, 0.165, 0, 0.005)], "unit_iron", segments=n(14))
        elif kind == "coif":
            rounded("coif", (0, 0.035, 1.71), (0.178, 0.17, 0.195), "unit_mail", segments=n(12), rings=n(8))
        elif kind == "great_helm":
            great_helm(n, circlet)
        elif kind == "nasal_helm":
            loft("nasal_helm", [(1.745, 0.168, 0.166, 0, 0.01), (1.82, 0.152, 0.15, 0, 0.01),
                                (1.89, 0.075, 0.075, 0, 0.0), (1.935, 0.012, 0.012, 0, -0.01)],
                 "unit_iron", segments=n(12))
            loft("nasal_rim", [(1.735, 0.172, 0.17, 0, 0.01), (1.765, 0.172, 0.17, 0, 0.01)],
                 "unit_leather", segments=n(12))
            box("nasal_guard", (0, -0.168, 1.69), (0.034, 0.02, 0.12), "unit_iron")
        elif kind == "gugel":
            rounded("hood", (0, 0.03, 1.715), (0.182, 0.175, 0.19), HOUSE_PRIMARY, segments=n(12), rings=n(8))
            if detail >= 1.0:
                limb("hood_tail", [(0, 0.18, 1.80), (0, 0.27, 1.70), (0.02, 0.30, 1.52)],
                     [0.055, 0.038, 0.018], HOUSE_PRIMARY, n(6))
    if kind == "coif":
        with part("chest"):
            loft("coif_mantle", [(1.33, 0.30, 0.222, 0, 0.0), (1.42, 0.27, 0.205, 0, 0.0),
                                 (1.50, 0.19, 0.16, 0, 0.01), (1.58, 0.14, 0.13, 0, 0.02)],
                 "unit_mail", segments=n(12))
    if kind == "gugel":
        with part("chest"):
            loft("hood_cape", [(1.25, 0.325, 0.25, 0, 0.0), (1.36, 0.30, 0.225, 0, 0.0),
                               (1.47, 0.20, 0.17, 0, 0.01), (1.57, 0.14, 0.13, 0, 0.02)],
                 HOUSE_PRIMARY, segments=n(12))
            if detail >= 1.0:
                loft("hood_cape_hem", [(1.235, 0.33, 0.255, 0, 0.0), (1.27, 0.328, 0.253, 0, 0.0)],
                     HOUSE_SECONDARY, segments=n(12))


def great_helm(n, circlet):
    loft("great_helm", [(1.50, 0.165, 0.17, 0, 0.0), (1.62, 0.172, 0.178, 0, 0.0),
                        (1.80, 0.17, 0.175, 0, 0.0), (1.875, 0.158, 0.162, 0, 0.0),
                        (1.90, 0.135, 0.14, 0, 0.0)], "unit_iron", segments=n(14))
    slit = [(0.182 * math.sin(a), -0.187 * math.cos(a), 1.735) for a in (-1.1, -0.55, 0.0, 0.55, 1.1)]
    limb("helm_slit", slit, [0.016] * len(slit), "unit_dark", 6)
    limb("helm_ridge", [(0, -0.185, 1.52), (0, -0.183, 1.70), (0, -0.18, 1.86)], [0.017] * 3, "unit_gold", 6)
    if circlet:
        loft("circlet", [(1.83, 0.178, 0.183, 0, 0.0), (1.872, 0.168, 0.173, 0, 0.0)],
             "unit_gold", segments=n(14))
        for i in range(6):
            angle = i * math.tau / 6 + math.pi / 6
            cone("circlet_point", (0.165 * math.cos(angle), 0.17 * math.sin(angle), 1.905),
                 0.032, 0.075, "unit_gold", vertices=5)
