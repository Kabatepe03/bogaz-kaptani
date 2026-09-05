import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = os.path.join("assets", "v11")
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


WHITE = pbr("marine_white", (0.91, 0.93, 0.94), 0.12, 0.30)
BLUE = pbr("marine_blue", (0.025, 0.105, 0.19), 0.28, 0.30)
RED = pbr("antifouling", (0.44, 0.035, 0.028), 0.05, 0.55)
DECK = pbr("deck", (0.16, 0.17, 0.18), 0.08, 0.82)
GLASS = pbr("bridge_glass", (0.015, 0.055, 0.085), 0.25, 0.07, 220)
STEEL = pbr("steel", (0.62, 0.66, 0.68), 0.72, 0.24)
BLACK = pbr("rubber", (0.015, 0.018, 0.022), 0.0, 0.92)
ORANGE = pbr("safety_orange", (0.95, 0.22, 0.035), 0.03, 0.55)
YELLOW = pbr("deck_yellow", (0.90, 0.76, 0.16), 0.02, 0.62)
DARK = pbr("dark_metal", (0.045, 0.05, 0.055), 0.35, 0.42)


def apply(mesh, material):
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    return mesh


def box(extents, pos, material):
    mesh = trimesh.creation.box(extents=extents)
    mesh.apply_translation(pos)
    return apply(mesh, material)


def cyl(radius, height, pos, material, sections=24, axis="y"):
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


def scene_export(parts, name):
    scene = trimesh.Scene()
    for index, mesh in enumerate(parts):
        scene.add_geometry(mesh, node_name=f"{name}_{index:03d}")
    data = scene.export(file_type="glb")
    path = os.path.join(OUT, name + ".glb")
    with open(path, "wb") as stream:
        stream.write(data)
    print(f"generated {path}: {len(data)} bytes")


def make_ferry():
    parts = []
    zs = np.linspace(-34.0, 34.0, 69)
    levels = [(-4.8, 0.20), (-2.4, 0.65), (0.0, 0.88), (2.5, 1.0), (5.0, 1.0)]
    vertices = []
    faces = []
    for y, scale in levels:
        for z in zs:
            t = (z - zs[0]) / (zs[-1] - zs[0])
            shape = max(0.06, math.sin(math.pi * t) ** 0.26)
            fullness = 0.92 + 0.08 * t
            width = 11.7 * shape * scale * fullness
            vertices.append([-width, y, z])
            vertices.append([width, y, z])
    cols = len(zs) * 2
    for level in range(len(levels) - 1):
        for i in range(len(zs) - 1):
            a = level * cols + i * 2
            b = a + 1
            c = a + 2
            d = a + 3
            e = (level + 1) * cols + i * 2
            f = e + 1
            g = e + 2
            h = e + 3
            faces += [[a, e, g], [a, g, c], [b, d, h], [b, h, f]]
    for i in range(len(zs) - 1):
        a = i * 2
        b = a + 1
        c = a + 2
        d = a + 3
        faces += [[a, c, d], [a, d, b]]
        offset = (len(levels) - 1) * cols
        a = offset + i * 2
        b = a + 1
        c = a + 2
        d = a + 3
        faces += [[a, d, c], [a, b, d]]
    hull = trimesh.Trimesh(np.asarray(vertices), np.asarray(faces), process=True)
    parts.append(apply(hull, WHITE))

    for side in (-1, 1):
        for z in np.linspace(-29.0, 29.0, 15):
            t = (z + 34.0) / 68.0
            width = 11.7 * max(0.06, math.sin(math.pi * t) ** 0.26) * (0.92 + 0.08 * t)
            parts.append(box((0.12, 1.4, 4.2), (side * (width + 0.05), 0.9, z), BLUE))
            parts.append(box((0.10, 1.1, 4.2), (side * (width * 0.82 + 0.04), -1.65, z), RED))

    parts += [
        box((21.0, 0.42, 58.5), (0, 5.28, 0), DECK),
        box((16.0, 0.38, 6.0), (0, 5.22, -31.5), STEEL),
        box((16.0, 0.38, 6.0), (0, 5.22, 31.5), STEEL),
        box((16.3, 4.2, 12.4), (0, 8.0, 5.0), WHITE),
        box((13.2, 2.7, 8.0), (0, 11.6, 5.8), WHITE),
    ]
    for x in np.linspace(-6.2, 6.2, 8):
        parts.append(box((1.45, 1.35, 0.12), (x, 8.95, -1.25), GLASS))
    for side in (-1, 1):
        for z in np.linspace(1.5, 9.0, 4):
            parts.append(box((0.12, 1.35, 1.7), (side * 8.2, 8.95, z), GLASS))
        for z in (-17.0, -13.0, -9.0, -5.0):
            parts.append(box((0.10, 0.95, 2.2), (side * 10.2, 7.25, z), GLASS))
        for z in (-18.0, 18.0):
            parts.append(cyl(0.55, 0.18, (side * 10.8, 7.0, z), ORANGE, 24, "x"))
            parts.append(cyl(0.30, 0.20, (side * 10.82, 7.0, z), WHITE, 24, "x"))
        parts.append(box((0.10, 0.10, 50.0), (side * 10.65, 6.2, 0), STEEL))
        parts.append(box((0.10, 0.10, 50.0), (side * 10.65, 6.8, 0), STEEL))
        for z in np.linspace(-24.0, 24.0, 13):
            parts.append(cyl(0.055, 1.6, (side * 10.65, 6.0, z), STEEL, 12, "y"))
        for z in np.linspace(-24.0, 24.0, 7):
            parts.append(cyl(0.32, 2.2, (side * 11.55, 3.0, z), BLACK, 20, "y"))

    parts.append(cyl(0.16, 8.8, (0, 17.4, 4.8), STEEL, 20, "y"))
    parts.append(box((6.2, 0.16, 0.16), (0, 19.7, 4.8), STEEL))
    for x in (-3.0, 3.0):
        parts.append(cyl(1.0, 3.8, (x, 15.0, 9.3), DARK, 32, "y"))
    parts.append(box((3.3, 0.16, 0.75), (0, 20.9, 4.8), WHITE))

    for x in (-6.8, -2.3, 2.3, 6.8):
        for z in (-20.0, -8.0, 4.0, 16.0):
            parts.append(box((0.14, 0.035, 7.4), (x, 5.51, z), YELLOW))
    for side in (-1, 1):
        for z in (-25.0, 25.0):
            parts.append(cyl(0.42, 0.65, (side * 7.8, 5.85, z), DARK, 18, "y"))

    scene_export(parts, "ferry_gestas_style_v11")


def wheel_pair(parts, x, z, radius=0.34, width=0.24):
    for side in (-1, 1):
        parts.append(cyl(radius, width, (side * x, radius, z), BLACK, 24, "x"))
        parts.append(cyl(radius * 0.56, width + 0.01, (side * x, radius, z), STEEL, 20, "x"))


def make_sedan():
    paint = pbr("carpaint", (0.10, 0.26, 0.64), 0.42, 0.18)
    parts = [
        sphere((1.95, 0.72, 4.55), (0, 0.65, 0), paint, 3),
        sphere((1.65, 0.78, 2.45), (0, 1.08, -0.15), paint, 3),
    ]
    for z in (-1.22, 1.15):
        parts.append(box((1.45, 0.46, 0.08), (0, 1.10, z), GLASS))
    for side in (-1, 1):
        parts.append(box((0.06, 0.44, 1.65), (side * 0.83, 1.10, -0.05), GLASS))
    wheel_pair(parts, 0.95, -1.42, 0.34)
    wheel_pair(parts, 0.95, 1.42, 0.34)
    headlight = pbr("headlight", (0.92, 0.95, 0.85), 0.02, 0.12, emissive=(0.6, 0.6, 0.5))
    for x in (-0.62, 0.62):
        parts.append(box((0.34, 0.18, 0.08), (x, 0.70, -2.30), headlight))
    scene_export(parts, "sedan_pbr_v11")


def make_minibus():
    paint = pbr("vanpaint", (0.84, 0.84, 0.80), 0.22, 0.25)
    parts = [
        sphere((2.15, 1.65, 5.75), (0, 1.05, 0), paint, 3),
        box((1.78, 0.62, 0.10), (0, 1.50, -2.88), GLASS),
    ]
    for side in (-1, 1):
        for z in (-1.35, 0.0, 1.35):
            parts.append(box((0.07, 0.62, 1.0), (side * 1.07, 1.48, z), GLASS))
    wheel_pair(parts, 1.05, -1.9, 0.39)
    wheel_pair(parts, 1.05, 1.9, 0.39)
    scene_export(parts, "minibus_pbr_v11")


def make_bus():
    paint = pbr("buspaint", (0.92, 0.90, 0.82), 0.16, 0.28)
    parts = [
        sphere((2.55, 2.95, 11.5), (0, 1.76, 0), paint, 3),
        box((2.18, 0.95, 0.10), (0, 2.40, -5.72), GLASS),
    ]
    for side in (-1, 1):
        for z in np.linspace(-3.8, 3.8, 6):
            parts.append(box((0.07, 0.88, 1.18), (side * 1.28, 2.40, z), GLASS))
    wheel_pair(parts, 1.20, -3.75, 0.50)
    wheel_pair(parts, 1.20, 3.65, 0.50)
    scene_export(parts, "bus_pbr_v11")


def make_truck():
    cab = pbr("truckpaint", (0.58, 0.08, 0.06), 0.36, 0.20)
    trailer = pbr("trailer", (0.76, 0.77, 0.74), 0.16, 0.62)
    parts = [
        sphere((2.55, 2.7, 3.4), (0, 1.62, -4.7), cab, 3),
        box((2.22, 0.78, 0.10), (0, 2.18, -6.38), GLASS),
        box((2.65, 3.0, 8.2), (0, 1.9, 1.2), trailer),
        box((2.72, 0.22, 8.3), (0, 0.48, 1.2), DARK),
    ]
    for z in (-5.0, -2.8, 2.6, 4.2):
        wheel_pair(parts, 1.22, z, 0.47)
    scene_export(parts, "truck_pbr_v11")


if __name__ == "__main__":
    make_ferry()
    make_sedan()
    make_minibus()
    make_bus()
    make_truck()
