import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = os.path.join("assets", "v15")
os.makedirs(OUT, exist_ok=True)


def pbr(name, color, metallic=0.0, rough=0.5, alpha=255, emissive=None):
    rgba = tuple(int(max(0, min(1, c)) * 255) for c in color[:3]) + (alpha,)
    material = PBRMaterial(
        name=name,
        baseColorFactor=rgba,
        metallicFactor=metallic,
        roughnessFactor=rough,
    )
    if emissive is not None:
        material.emissiveFactor = tuple(float(x) for x in emissive)
    return material


WHITE = pbr("v15_marine_white", (0.92, 0.94, 0.95), 0.08, 0.34)
NAVY = pbr("v15_navy", (0.025, 0.085, 0.145), 0.20, 0.30)
RED = pbr("v15_antifouling", (0.43, 0.035, 0.028), 0.03, 0.58)
DECK = pbr("v15_deck", (0.13, 0.145, 0.155), 0.09, 0.83)
GLASS = pbr("v15_glass", (0.018, 0.055, 0.075), 0.28, 0.10, 225)
STEEL = pbr("v15_steel", (0.62, 0.66, 0.68), 0.70, 0.25)
DARK = pbr("v15_dark", (0.035, 0.042, 0.048), 0.36, 0.42)
BLACK = pbr("v15_rubber", (0.012, 0.014, 0.016), 0.0, 0.94)
ORANGE = pbr("v15_safety_orange", (0.96, 0.24, 0.035), 0.02, 0.54)
YELLOW = pbr("v15_deck_yellow", (0.92, 0.78, 0.16), 0.02, 0.62)
WARM = pbr("v15_warm_light", (0.90, 0.74, 0.42), 0.0, 0.18, emissive=(0.85, 0.56, 0.22))


def apply(mesh, material):
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    return mesh


def box(extents, pos, material):
    mesh = trimesh.creation.box(extents=extents)
    mesh.apply_translation(pos)
    return apply(mesh, material)


def cyl(radius, height, pos, material, sections=20, axis="y"):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    elif axis == "x":
        mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    mesh.apply_translation(pos)
    return apply(mesh, material)


def sphere(scale, pos, material, subdivisions=2):
    mesh = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    mesh.apply_scale(scale)
    mesh.apply_translation(pos)
    return apply(mesh, material)


def hull_shell(material):
    # Double-ended Ro-Ro ferry hull. The longitudinal fullness falls sharply near both ramps,
    # producing a proper ship silhouette rather than a floating rectangular block.
    z_values = np.linspace(-38.0, 38.0, 97)
    levels = [(-5.0, 0.18), (-3.0, 0.58), (-1.0, 0.82), (1.2, 0.96), (3.8, 1.0), (5.3, 1.0)]
    vertices = []
    for y, vertical_scale in levels:
        for z in z_values:
            t = (z - z_values[0]) / (z_values[-1] - z_values[0])
            end_shape = max(0.035, math.sin(math.pi * t) ** 0.34)
            shoulder = 0.90 + 0.10 * math.sin(math.pi * t) ** 0.75
            width = 11.9 * end_shape * shoulder * vertical_scale
            vertices.append([-width, y, z])
            vertices.append([width, y, z])

    faces = []
    row = len(z_values) * 2
    for level in range(len(levels) - 1):
        for i in range(len(z_values) - 1):
            a = level * row + i * 2
            b = a + 1
            c = a + 2
            d = a + 3
            e = (level + 1) * row + i * 2
            f = e + 1
            g = e + 2
            h = e + 3
            faces.extend([[a, e, g], [a, g, c], [b, d, h], [b, h, f]])

    # Deck and keel caps.
    for i in range(len(z_values) - 1):
        a = i * 2
        b = a + 1
        c = a + 2
        d = a + 3
        faces.extend([[a, c, d], [a, d, b]])
        top = (len(levels) - 1) * row
        a = top + i * 2
        b = a + 1
        c = a + 2
        d = a + 3
        faces.extend([[a, d, c], [a, b, d]])

    mesh = trimesh.Trimesh(np.asarray(vertices), np.asarray(faces), process=True)
    mesh.fix_normals()
    return apply(mesh, material)


def rail(parts, side, z0, z1, y=6.2):
    parts.append(box((0.09, 0.09, abs(z1-z0)), (side * 10.75, y, (z0+z1)*0.5), STEEL))
    parts.append(box((0.09, 0.09, abs(z1-z0)), (side * 10.75, y+0.65, (z0+z1)*0.5), STEEL))
    for z in np.linspace(z0, z1, max(2, int(abs(z1-z0)/4.0)+1)):
        parts.append(cyl(0.045, 1.45, (side * 10.75, y-0.05, float(z)), STEEL, 10, "y"))


def make_ferry():
    parts = [hull_shell(WHITE)]

    # Lower hull bands and boot stripe.
    for side in (-1, 1):
        for z in np.linspace(-34.0, 34.0, 23):
            t = (z + 38.0) / 76.0
            width = 11.9 * max(0.035, math.sin(math.pi * t) ** 0.34) * (0.90 + 0.10 * math.sin(math.pi * t) ** 0.75)
            parts.append(box((0.12, 1.45, 3.0), (side*(width+0.04), -1.95, z), RED))
            parts.append(box((0.13, 0.42, 3.0), (side*(width+0.06), 0.15, z), NAVY))

    # Vehicle deck and both ramp assemblies.
    parts += [
        box((21.2, 0.40, 62.0), (0, 5.35, 0), DECK),
        box((17.6, 0.30, 8.2), (0, 5.18, -35.0), STEEL),
        box((17.6, 0.30, 8.2), (0, 5.18, 35.0), STEEL),
    ]
    for z in (-35.0, 35.0):
        for x in np.linspace(-6.0, 6.0, 5):
            parts.append(box((0.16, 0.03, 6.8), (x, 5.40, z), YELLOW))

    # Passenger salon along port side, leaving the vehicle deck visually open.
    parts.append(box((5.2, 4.2, 28.0), (-7.55, 7.85, 2.5), WHITE))
    parts.append(box((5.4, 0.28, 28.4), (-7.55, 10.08, 2.5), NAVY))
    for z in np.linspace(-9.0, 14.0, 8):
        parts.append(box((0.12, 1.25, 2.0), (-10.20, 8.35, float(z)), GLASS))

    # Bridge spans most of the ship width and has an angled visor silhouette.
    parts.append(box((17.4, 3.9, 10.8), (0.0, 8.1, 10.0), WHITE))
    parts.append(box((14.6, 2.7, 7.2), (0.0, 11.25, 10.5), WHITE))
    for x in np.linspace(-6.1, 6.1, 9):
        parts.append(box((1.22, 1.20, 0.11), (float(x), 11.55, 6.87), GLASS))
    for side in (-1, 1):
        for z in (8.0, 10.5, 13.0):
            parts.append(box((0.11, 1.15, 1.45), (side*7.35, 11.45, z), GLASS))

    # Funnel and mast/radar equipment.
    for x in (-3.2, 3.2):
        parts.append(cyl(0.95, 3.6, (x, 14.9, 14.0), DARK, 28, "y"))
        parts.append(cyl(0.77, 0.46, (x, 16.8, 14.0), BLACK, 28, "y"))
    parts.append(cyl(0.16, 7.8, (0.0, 17.2, 9.8), STEEL, 18, "y"))
    parts.append(box((5.8, 0.16, 0.32), (0.0, 20.3, 9.8), STEEL))
    parts.append(box((3.2, 0.16, 0.75), (0.0, 21.2, 9.8), WHITE))

    # Rails, fenders and lifesaving equipment.
    for side in (-1, 1):
        rail(parts, side, -28.0, 30.0)
        for z in np.linspace(-25.0, 25.0, 9):
            parts.append(cyl(0.36, 2.0, (side*11.35, 3.0, float(z)), BLACK, 18, "y"))
        for z in (-19.0, 19.0):
            parts.append(cyl(0.56, 0.17, (side*10.88, 7.15, z), ORANGE, 24, "x"))
            parts.append(cyl(0.28, 0.18, (side*10.90, 7.15, z), WHITE, 24, "x"))

    # Enclosed life rafts and deck machinery.
    for side in (-1, 1):
        for z in (-23.0, -15.0, 18.0, 26.0):
            parts.append(cyl(0.48, 1.25, (side*9.5, 6.3, z), WHITE, 18, "z" if False else "y"))
        parts.append(box((1.4, 1.0, 2.4), (side*8.8, 6.0, -20.0), STEEL))
        parts.append(box((1.4, 1.0, 2.4), (side*8.8, 6.0, 22.0), STEEL))

    # Lane markings and safety strips make deck scale obvious.
    for x in (-6.5, -2.2, 2.2, 6.5):
        for z in (-21.0, -10.0, 1.0, 12.0, 23.0):
            parts.append(box((0.13, 0.028, 6.2), (x, 5.58, z), YELLOW))

    # Warm salon lights for depth even in daylight.
    for z in np.linspace(-8.0, 13.0, 7):
        parts.append(box((0.13, 0.55, 1.2), (-10.28, 8.30, float(z)), WARM))

    scene = trimesh.Scene()
    for idx, mesh in enumerate(parts):
        scene.add_geometry(mesh, node_name=f"V15_Ferry_{idx:03d}")
    data = scene.export(file_type="glb")
    target = os.path.join(OUT, "ferry_realistic_v15.glb")
    with open(target, "wb") as stream:
        stream.write(data)
    print(f"generated {target}: {len(data)} bytes")


if __name__ == "__main__":
    make_ferry()
