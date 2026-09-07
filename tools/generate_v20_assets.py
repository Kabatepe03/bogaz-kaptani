import math
import os
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = Path("assets/v20")
OUT.mkdir(parents=True, exist_ok=True)


def pbr(name, rgb, metallic=0.0, rough=0.5, alpha=255, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (alpha,)
    mat = PBRMaterial(
        name=name,
        baseColorFactor=rgba,
        metallicFactor=float(metallic),
        roughnessFactor=float(rough),
    )
    if emissive is not None:
        mat.emissiveFactor = tuple(float(v) for v in emissive)
    return mat


HULL_WHITE = pbr("v20_hull_marine_white", (0.86, 0.89, 0.90), 0.08, 0.28)
HULL_SHADOW = pbr("v20_hull_shadow", (0.60, 0.65, 0.68), 0.10, 0.42)
NAVY = pbr("v20_navy_boot", (0.018, 0.060, 0.105), 0.18, 0.28)
ANTIFOUL = pbr("v20_antifouling", (0.39, 0.028, 0.025), 0.03, 0.62)
DECK = pbr("v20_vehicle_deck", (0.105, 0.115, 0.122), 0.08, 0.80)
RAMP = pbr("v20_ramp_steel", (0.30, 0.33, 0.34), 0.62, 0.42)
STEEL = pbr("v20_stainless", (0.58, 0.62, 0.64), 0.78, 0.22)
DARK_STEEL = pbr("v20_dark_steel", (0.055, 0.065, 0.070), 0.62, 0.38)
RUBBER = pbr("v20_rubber", (0.010, 0.012, 0.013), 0.0, 0.97)
GLASS = pbr("v20_bridge_glass", (0.014, 0.048, 0.070), 0.25, 0.08, 218)
WINDOW_GLOW = pbr("v20_window_glow", (0.055, 0.095, 0.11), 0.12, 0.16, 240, (0.18, 0.14, 0.08))
ORANGE = pbr("v20_safety_orange", (0.94, 0.22, 0.025), 0.01, 0.52)
YELLOW = pbr("v20_lane_yellow", (0.94, 0.75, 0.095), 0.02, 0.62)
WHITE_LINE = pbr("v20_lane_white", (0.90, 0.90, 0.86), 0.01, 0.66)
RED_LIGHT = pbr("v20_port_light", (0.9, 0.015, 0.01), 0.0, 0.18, emissive=(1.0, 0.0, 0.0))
GREEN_LIGHT = pbr("v20_starboard_light", (0.01, 0.88, 0.18), 0.0, 0.18, emissive=(0.0, 1.0, 0.12))
WARM_LIGHT = pbr("v20_warm_light", (0.92, 0.72, 0.38), 0.0, 0.16, emissive=(0.92, 0.52, 0.18))


def apply(mesh, material, smooth=True):
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    if smooth:
        _ = mesh.vertex_normals
    return mesh


def box(extents, pos, material):
    m = trimesh.creation.box(extents=extents)
    m.apply_translation(pos)
    return apply(m, material, False)


def cyl(radius, height, pos, material, sections=32, axis="y"):
    m = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    elif axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, material)


def sphere(scale, pos, material, subdivisions=3):
    m = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    m.apply_scale(scale)
    m.apply_translation(pos)
    return apply(m, material)


def torus(major, minor, pos, material, axis="x"):
    try:
        m = trimesh.creation.torus(major_radius=major, minor_radius=minor, major_sections=36, minor_sections=12)
    except TypeError:
        m = trimesh.creation.torus(major_radius=major, minor_radius=minor)
    if axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    elif axis == "z":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    m.apply_translation(pos)
    return apply(m, material)


def hull_width(z, y):
    half_len = 41.0
    q = min(1.0, abs(z) / half_len)
    # Ferry hull stays full for most of its length, then tightens smoothly into the double-ended bows.
    end = max(0.06, (1.0 - q ** 4.7) ** 0.30)
    flare = np.interp(y, [-5.4, -3.8, -2.0, 0.0, 2.6, 5.0], [0.20, 0.48, 0.70, 0.84, 0.96, 1.0])
    shoulder = 0.96 + 0.04 * math.cos(q * math.pi * 0.5)
    return 10.65 * end * flare * shoulder


def make_hull(material):
    zs = np.linspace(-41.0, 41.0, 181)
    ys = [-5.4, -4.4, -3.3, -2.1, -0.8, 0.7, 2.3, 3.8, 5.0]
    verts = []
    for y in ys:
        for z in zs:
            w = hull_width(float(z), float(y))
            verts.extend([(-w, y, z), (w, y, z)])

    faces = []
    row = len(zs) * 2
    for iy in range(len(ys) - 1):
        for iz in range(len(zs) - 1):
            a = iy * row + iz * 2
            b = a + 1
            c = a + 2
            d = a + 3
            e = (iy + 1) * row + iz * 2
            f = e + 1
            g = e + 2
            h = e + 3
            faces += [[a, e, g], [a, g, c], [b, d, h], [b, h, f]]

    # Bottom and weather-deck caps.
    for level in (0, len(ys) - 1):
        base = level * row
        for iz in range(len(zs) - 1):
            a = base + iz * 2
            b = a + 1
            c = a + 2
            d = a + 3
            faces += ([[a, c, d], [a, d, b]] if level == 0 else [[a, d, c], [a, b, d]])

    m = trimesh.Trimesh(np.asarray(verts, dtype=float), np.asarray(faces, dtype=int), process=True)
    m.fix_normals()
    return apply(m, material)


def make_side_band(y0, y1, material, thickness=0.06):
    meshes = []
    for side in (-1.0, 1.0):
        zs = np.linspace(-38.5, 38.5, 96)
        verts = []
        for z in zs:
            w0 = hull_width(float(z), y0) + thickness
            w1 = hull_width(float(z), y1) + thickness
            verts.extend([(side * w0, y0, z), (side * w1, y1, z)])
        faces = []
        for i in range(len(zs) - 1):
            a = i * 2
            b = a + 1
            c = a + 2
            d = a + 3
            faces += [[a, b, c], [c, b, d]] if side > 0 else [[a, c, b], [c, d, b]]
        m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
        m.fix_normals()
        meshes.append(apply(m, material))
    return meshes


def tapered_house(z0, z1, y0, y1, widths, material):
    # Rounded-looking longitudinal cabin/bridge made as a multi-section loft rather than a box.
    sections = 15
    zs = np.linspace(z0, z1, sections)
    verts = []
    for z in zs:
        t = (z - z0) / max(0.001, z1 - z0)
        width = np.interp(t, [0.0, 0.12, 0.5, 0.88, 1.0], widths)
        # six points around each side create chamfered shoulders.
        verts.extend([
            (-width * 0.92, y0, z), (width * 0.92, y0, z),
            (-width, y0 + (y1-y0)*0.28, z), (width, y0 + (y1-y0)*0.28, z),
            (-width * 0.90, y1, z), (width * 0.90, y1, z),
        ])
    ring = 6
    faces = []
    for i in range(sections - 1):
        a = i * ring
        b = (i + 1) * ring
        # port and starboard skins, lower bevel, upper bevel and roof/floor strips.
        pairs = [(0,2),(2,4),(1,3),(3,5),(4,5),(0,1)]
        for p0, p1 in pairs:
            faces += [[a+p0, b+p0, b+p1], [a+p0, b+p1, a+p1]]
    # End caps.
    faces += [[0,1,3],[0,3,2],[2,3,5],[2,5,4]]
    end = (sections-1)*ring
    faces += [[end+0,end+3,end+1],[end+0,end+2,end+3],[end+2,end+5,end+3],[end+2,end+4,end+5]]
    m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
    m.fix_normals()
    return apply(m, material)


def add_rail(parts, side, z0, z1, y=6.05):
    x = side * 9.95
    parts.append(box((0.075, 0.075, z1-z0), (x, y+0.66, (z0+z1)*0.5), STEEL))
    parts.append(box((0.060, 0.060, z1-z0), (x, y+0.22, (z0+z1)*0.5), STEEL))
    for z in np.arange(z0, z1 + 0.01, 2.35):
        parts.append(cyl(0.035, 1.32, (x, y+0.04, float(z)), STEEL, 12, "y"))


def add_windows(parts):
    # Bridge wraparound windows: narrower toward corners and angled visually around the front/rear.
    for z in (4.65, -4.65):
        for x in np.linspace(-6.8, 6.8, 11):
            parts.append(box((1.08, 1.18, 0.10), (float(x), 13.35, z), GLASS))
    for side in (-1, 1):
        x = side * 8.20
        for z in (-3.2, -1.1, 1.1, 3.2):
            parts.append(box((0.10, 1.10, 1.40), (x, 13.30, z), GLASS))

    # Long side passenger windows.
    for side in (-1, 1):
        x = side * 8.92
        for z in np.linspace(-18.0, 18.0, 13):
            parts.append(box((0.10, 1.16, 1.65), (x, 9.10, float(z)), WINDOW_GLOW))


def add_deck_detail(parts):
    # Lane markings with dashed segments, matching passenger-car scale.
    for x in (-6.0, -2.0, 2.0, 6.0):
        for z in np.arange(-29.0, 30.0, 7.5):
            parts.append(box((0.10, 0.025, 4.2), (x, 5.28, float(z)), WHITE_LINE))
    for x in (-8.25, 8.25):
        parts.append(box((0.11, 0.026, 61.0), (x, 5.29, 0.0), YELLOW))

    # Mooring bollards and winches.
    for side in (-1, 1):
        for z in (-27.5, -20.0, 20.0, 27.5):
            parts.append(cyl(0.30, 0.62, (side*8.65, 5.62, z), DARK_STEEL, 24, "y"))
        for z in (-23.0, 23.0):
            parts.append(cyl(0.58, 0.76, (side*7.2, 5.66, z), DARK_STEEL, 28, "x"))
            parts.append(cyl(0.28, 1.18, (side*7.2, 5.66, z), STEEL, 24, "x"))

    # Fire cabinets and life-raft canisters.
    for side in (-1, 1):
        for z in (-16.0, 0.0, 16.0):
            parts.append(box((0.55, 1.05, 0.72), (side*9.15, 6.35, z), HULL_WHITE))
        for z in (-24.0, 24.0):
            parts.append(cyl(0.42, 1.50, (side*8.9, 7.10, z), HULL_WHITE, 24, "z"))


def add_safety(parts):
    for side in (-1, 1):
        # Real torus life rings instead of solid orange discs.
        for z in (-17.5, 17.5):
            parts.append(torus(0.48, 0.13, (side*9.33, 8.10, z), ORANGE, "x"))
        # Hanging tyre fenders along the working sides.
        for z in np.linspace(-24.0, 24.0, 9):
            parts.append(torus(0.53, 0.18, (side*10.47, 2.85, float(z)), RUBBER, "x"))


def add_mast(parts):
    parts.append(cyl(0.14, 8.0, (0.0, 18.1, 0.0), STEEL, 24, "y"))
    parts.append(box((6.4, 0.14, 0.30), (0.0, 20.4, 0.0), STEEL))
    parts.append(box((3.6, 0.18, 0.76), (0.0, 21.25, 0.0), HULL_WHITE))
    parts.append(cyl(0.09, 3.6, (-1.8, 20.6, 0.0), STEEL, 16, "y"))
    parts.append(cyl(0.09, 3.6, (1.8, 20.6, 0.0), STEEL, 16, "y"))
    parts.append(sphere((0.18,0.18,0.18), (-9.0, 14.7, 0.0), RED_LIGHT, 2))
    parts.append(sphere((0.18,0.18,0.18), (9.0, 14.7, 0.0), GREEN_LIGHT, 2))
    parts.append(sphere((0.16,0.16,0.16), (0.0, 22.6, 0.0), WARM_LIGHT, 2))


def add_ramps(parts):
    for z, sign in ((-37.7, -1.0), (37.7, 1.0)):
        parts.append(box((18.6, 0.28, 7.2), (0.0, 5.05, z), RAMP))
        parts.append(cyl(0.34, 18.4, (0.0, 5.10, z - sign*3.25), DARK_STEEL, 28, "x"))
        for x in np.linspace(-7.7, 7.7, 9):
            parts.append(box((0.12, 0.035, 6.6), (float(x), 5.23, z), YELLOW if abs(x) < 1.0 else HULL_SHADOW))
        for x in (-8.7, 8.7):
            parts.append(box((0.18, 0.60, 7.0), (x, 5.38, z), HULL_SHADOW))


def make_ferry():
    parts = [make_hull(HULL_WHITE)]
    parts += make_side_band(-4.6, -1.25, ANTIFOUL)
    parts += make_side_band(-1.15, -0.62, NAVY)

    # Weather deck and central passenger block.
    parts.append(box((19.0, 0.34, 66.0), (0.0, 5.10, 0.0), DECK))
    add_ramps(parts)

    # Lower passenger salon and upper bridge are lofted/tapered to remove the Lego-box silhouette.
    parts.append(tapered_house(-20.5, 20.5, 6.05, 10.25, [8.2, 8.85, 8.85, 8.85, 8.2], HULL_WHITE))
    parts.append(tapered_house(-5.5, 5.5, 11.15, 14.75, [6.6, 8.2, 8.4, 8.2, 6.6], HULL_WHITE))
    parts.append(tapered_house(-4.7, 4.7, 14.65, 15.25, [6.1, 7.7, 7.9, 7.7, 6.1], NAVY))
    add_windows(parts)

    # Twin compact exhaust trunks integrated behind the bridge.
    for x in (-3.1, 3.1):
        parts.append(cyl(0.72, 2.9, (x, 16.45, 2.1), DARK_STEEL, 32, "y"))
        parts.append(cyl(0.56, 0.44, (x, 18.08, 2.1), RUBBER, 32, "y"))

    for side in (-1, 1):
        add_rail(parts, side, -31.0, 31.0)
    add_deck_detail(parts)
    add_safety(parts)
    add_mast(parts)

    # Small exterior warm lights under the passenger-deck overhang.
    for side in (-1, 1):
        for z in np.linspace(-15.0, 15.0, 7):
            parts.append(sphere((0.10,0.10,0.10), (side*9.2, 7.15, float(z)), WARM_LIGHT, 1))

    scene = trimesh.Scene()
    for i, mesh in enumerate(parts):
        scene.add_geometry(mesh, node_name=f"V20_RORO_{i:04d}")
    data = scene.export(file_type="glb")
    path = OUT / "ferry_remaster_v20.glb"
    path.write_bytes(data)
    print(f"generated {path}: {len(data)/1024/1024:.2f} MB, parts={len(parts)}")


if __name__ == "__main__":
    make_ferry()
