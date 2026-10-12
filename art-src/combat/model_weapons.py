from model_primitives import beam, cone, mesh


def spear(wood="wood_light", iron="steel", blade="steel_light"):
    beam("spear_shaft", (0, 0, 0), (0, 0, 2.71), 0.029, wood)
    cone("spear_socket", (0, 0, 2.71), 0.05, 0.14, iron, 0.039)
    vertices = [(0, 0, 3.17), (-0.095, 0, 2.83), (0, -0.038, 2.83),
                (0.095, 0, 2.83), (0, 0.038, 2.83), (0, 0, 2.72)]
    mesh("spearhead", vertices, [(0, i, i % 4 + 1) for i in range(1, 5)]
         + [(5, i % 4 + 1, i) for i in range(1, 5)], blade)
    cone("spear_foot", (0, 0, 0.035), 0.032, 0.07, iron, 0.032)
