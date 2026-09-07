import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = Path("assets/v20/ferry_remaster_v20.glb")


def mat(name, rgb, metallic=0.0, rough=0.5, alpha=255, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (alpha,)
    m = PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)
    if emissive is not None:
        m.emissiveFactor = tuple(float(v) for v in emissive)
    return m


WHITE = mat("marine_white", (0.91, 0.93, 0.93), 0.04, 0.30)
WHITE_SHADOW = mat("marine_white_shadow", (0.70, 0.74, 0.75), 0.05, 0.48)
NAVY = mat("navy_boot", (0.018, 0.055, 0.105), 0.10, 0.34)
BLUE = mat("waterline_blue", (0.025, 0.17, 0.34), 0.06, 0.38)
GREEN = mat("dardanelles_green", (0.05, 0.56, 0.24), 0.02, 0.42)
RED = mat("antifouling", (0.39, 0.025, 0.022), 0.02, 0.65)
DECK = mat("vehicle_deck", (0.095, 0.105, 0.11), 0.06, 0.86)
STEEL = mat("steel", (0.54, 0.58, 0.60), 0.72, 0.27)
DARK = mat("dark_steel", (0.045, 0.055, 0.060), 0.64, 0.40)
GLASS = mat("bridge_glass", (0.012, 0.050, 0.075), 0.18, 0.08, 235)
WINDOW = mat("passenger_glass", (0.018, 0.065, 0.085), 0.12, 0.12, 240)
RUBBER = mat("rubber", (0.008, 0.010, 0.011), 0.0, 0.98)
ORANGE = mat("lifebuoy", (0.96, 0.22, 0.025), 0.0, 0.55)
YELLOW = mat("deck_yellow", (0.92, 0.72, 0.08), 0.0, 0.62)
WARM = mat("warm_light", (0.95, 0.75, 0.45), 0.0, 0.18, emissive=(0.95, 0.56, 0.22))
RED_LIGHT = mat("port_light", (0.90, 0.02, 0.015), 0.0, 0.16, emissive=(1.0, 0.0, 0.0))
GREEN_LIGHT = mat("starboard_light", (0.015, 0.85, 0.16), 0.0, 0.16, emissive=(0.0, 1.0, 0.10))


def apply(mesh, material, smooth=False):
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    if smooth:
        _ = mesh.vertex_normals
    return mesh


def box(extents, pos, material, rotation=None):
    m = trimesh.creation.box(extents=extents)
    if rotation is not None:
        angle, axis = rotation
        m.apply_transform(trimesh.transformations.rotation_matrix(angle, axis))
    m.apply_translation(pos)
    return apply(m, material)


def cyl(radius, height, pos, material, sections=20, axis="y"):
    m = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    elif axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, material, True)


def sphere(scale, pos, material):
    m = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    m.apply_scale(scale)
    m.apply_translation(pos)
    return apply(m, material, True)


def torus(major, minor, pos, material, axis="x"):
    m = trimesh.creation.torus(major_radius=major, minor_radius=minor, major_sections=28, minor_sections=10)
    if axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, material, True)


def hull_width(z, y):
    half_len = 44.0
    q = min(1.0, abs(z) / half_len)
    bow = max(0.09, (1.0 - q ** 5.4) ** 0.34)
    flare = np.interp(y, [-4.9, -3.4, -1.8, 0.0, 2.0, 4.2], [0.22, 0.50, 0.72, 0.88, 0.98, 1.0])
    return 8.40 * bow * flare


def hull_mesh(material):
    zs = np.linspace(-44.0, 44.0, 197)
    ys = [-4.9, -3.8, -2.7, -1.4, 0.0, 1.8, 3.2, 4.25]
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
    for level in (0, len(ys) - 1):
        base = level * row
        for iz in range(len(zs) - 1):
            a, b, c, d = base + iz * 2, base + iz * 2 + 1, base + iz * 2 + 2, base + iz * 2 + 3
            faces += ([[a, c, d], [a, d, b]] if level == 0 else [[a, d, c], [a, b, d]])
    m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
    m.fix_normals()
    return apply(m, material, True)


def side_band(y0, y1, material):
    out = []
    for side in (-1.0, 1.0):
        zs = np.linspace(-41.0, 41.0, 120)
        verts = []
        for z in zs:
            verts.extend([(side * (hull_width(float(z), y0) + 0.03), y0, z),
                          (side * (hull_width(float(z), y1) + 0.03), y1, z)])
        faces = []
        for i in range(len(zs) - 1):
            a, b, c, d = i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 3
            faces += [[a, b, c], [c, b, d]] if side > 0 else [[a, c, b], [c, d, b]]
        m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
        m.fix_normals()
        out.append(apply(m, material, True))
    return out


def beam_yz(x, p0, p1, thickness, depth, material):
    y0, z0 = p0
    y1, z1 = p1
    dy, dz = y1 - y0, z1 - z0
    length = math.hypot(dy, dz)
    angle = -math.atan2(dy, dz)
    return box((depth, thickness, length), (x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), material, (angle, [1, 0, 0]))


def arch_parts(side, material, y_base=6.2, y_peak=15.0, span=33.0, thickness=0.55, depth=0.55):
    x = side * 8.25
    pts = []
    for z in np.linspace(-span, span, 34):
        q = abs(float(z)) / span
        y = y_base + (y_peak - y_base) * max(0.0, 1.0 - q ** 1.75) ** 0.62
        pts.append((y, float(z)))
    return [beam_yz(x, a, b, thickness, depth, material) for a, b in zip(pts[:-1], pts[1:])]


def add_rails(parts, x, z0, z1, y):
    parts.append(box((0.07, 0.07, z1 - z0), (x, y + 0.95, (z0 + z1) * 0.5), STEEL))
    parts.append(box((0.05, 0.05, z1 - z0), (x, y + 0.50, (z0 + z1) * 0.5), STEEL))
    for z in np.arange(z0, z1 + 0.01, 2.0):
        parts.append(cyl(0.032, 1.05, (x, y + 0.45, float(z)), STEEL, 10, "y"))


def add_windows(parts):
    # Long passenger lounge window ribbon, interrupted by structural mullions.
    for side in (-1.0, 1.0):
        x = side * 7.05
        for z in np.linspace(-24.0, 24.0, 17):
            parts.append(box((0.10, 1.55, 2.15), (x, 9.10, float(z)), WINDOW))
            parts.append(box((0.13, 1.72, 0.16), (x + side * 0.02, 9.10, float(z) + 1.16), WHITE_SHADOW))

    # Panoramic wheelhouse windows front/rear and wings.
    for z in (-6.25, 6.25):
        for x in np.linspace(-5.5, 5.5, 9):
            parts.append(box((1.05, 1.25, 0.10), (float(x), 13.25, z), GLASS))
    for side in (-1.0, 1.0):
        for z in (-4.0, -1.5, 1.5, 4.0):
            parts.append(box((0.10, 1.15, 1.65), (side * 6.55, 13.20, z), GLASS))


def add_ramps(parts):
    for z, sign in ((-40.5, -1.0), (40.5, 1.0)):
        parts.append(box((15.6, 0.30, 7.0), (0.0, 4.28, z), STEEL))
        parts.append(cyl(0.28, 15.3, (0.0, 4.32, z - sign * 3.10), DARK, 24, "x"))
        for x in np.linspace(-6.8, 6.8, 8):
            parts.append(box((0.10, 0.025, 6.4), (float(x), 4.47, z), YELLOW if abs(x) < 1.2 else WHITE_SHADOW))


def add_deck_details(parts):
    # Vehicle deck lane guidance.
    for x in (-5.5, -1.8, 1.8, 5.5):
        for z in np.arange(-31.0, 32.0, 8.0):
            parts.append(box((0.08, 0.025, 4.4), (x, 4.46, float(z)), WHITE_SHADOW))
    for x in (-7.2, 7.2):
        parts.append(box((0.10, 0.025, 69.0), (x, 4.47, 0.0), YELLOW))

    # Bollards, winches and hanging tyre fenders.
    for side in (-1.0, 1.0):
        for z in (-31.0, -24.0, 24.0, 31.0):
            parts.append(cyl(0.28, 0.56, (side * 7.15, 4.72, z), DARK, 20, "y"))
        for z in (-26.0, 26.0):
            parts.append(cyl(0.52, 0.70, (side * 6.1, 4.78, z), DARK, 24, "x"))
        for z in np.linspace(-28.0, 28.0, 11):
            parts.append(torus(0.46, 0.15, (side * 8.55, 2.45, float(z)), RUBBER, "x"))
        for z in (-22.0, -7.0, 7.0, 22.0):
            parts.append(torus(0.44, 0.12, (side * 7.35, 10.65, z), ORANGE, "x"))


def add_mast(parts):
    parts.append(cyl(0.13, 7.0, (0.0, 18.2, 0.0), STEEL, 20, "y"))
    parts.append(box((6.2, 0.15, 0.26), (0.0, 20.15, 0.0), STEEL))
    parts.append(box((3.8, 0.18, 0.70), (0.0, 21.0, 0.0), WHITE))
    for x in (-1.9, 1.9):
        parts.append(cyl(0.07, 3.2, (x, 20.7, 0.0), STEEL, 12, "y"))
    parts.append(sphere((0.16, 0.16, 0.16), (-7.7, 14.9, -0.5), RED_LIGHT))
    parts.append(sphere((0.16, 0.16, 0.16), (7.7, 14.9, -0.5), GREEN_LIGHT))
    parts.append(sphere((0.15, 0.15, 0.15), (0.0, 22.0, 0.0), WARM))


def make_ferry():
    parts = [hull_mesh(WHITE)]
    parts += side_band(-4.4, -1.3, RED)
    parts += side_band(-1.25, -0.55, NAVY)
    parts += side_band(-0.50, -0.15, BLUE)

    # Open vehicle deck. The upper passenger deck is raised above it instead of occupying it.
    parts.append(box((15.2, 0.28, 72.0), (0.0, 4.32, 0.0), DECK))
    add_ramps(parts)

    # Passenger deck floor and side supports keep the car deck visibly open from both ends.
    parts.append(box((14.7, 0.34, 55.0), (0.0, 7.30, 0.0), WHITE_SHADOW))
    for side in (-1.0, 1.0):
        for z in np.linspace(-25.0, 25.0, 12):
            parts.append(box((0.42, 3.1, 0.48), (side * 7.15, 5.80, float(z)), WHITE))

    # Long passenger lounge with shallow chamfered roof.
    parts.append(box((13.8, 2.9, 51.0), (0.0, 9.05, 0.0), WHITE))
    parts.append(box((14.2, 0.32, 52.0), (0.0, 10.67, 0.0), WHITE_SHADOW))
    add_windows(parts)

    # Elevated wheelhouse: compact, broad and panoramic like Dardanelles Ro-Ro ferries.
    parts.append(box((12.8, 3.4, 12.0), (0.0, 13.15, 0.0), WHITE))
    parts.append(box((13.2, 0.30, 12.4), (0.0, 14.92, 0.0), NAVY))

    # Signature arch structures visible from the shore and ferry approach.
    parts.extend(arch_parts(-1.0, WHITE, 6.1, 15.2, 33.5, 0.62, 0.64))
    parts.extend(arch_parts(1.0, WHITE, 6.1, 15.2, 33.5, 0.62, 0.64))
    parts.extend(arch_parts(-1.0, GREEN, 7.15, 14.25, 29.0, 0.22, 0.24))
    parts.extend(arch_parts(1.0, GREEN, 7.15, 14.25, 29.0, 0.22, 0.24))

    # Open upper passenger promenade and railings.
    for side in (-1.0, 1.0):
        add_rails(parts, side * 7.25, -25.5, 25.5, 10.70)
        add_rails(parts, side * 6.55, -6.0, 6.0, 14.95)

    # Twin compact exhaust trunks aft/forward of the bridge centreline.
    for x in (-2.5, 2.5):
        parts.append(cyl(0.58, 2.4, (x, 16.0, 2.8), DARK, 28, "y"))
        parts.append(cyl(0.46, 0.35, (x, 17.35, 2.8), RUBBER, 28, "y"))

    add_deck_details(parts)
    add_mast(parts)

    # Small warm deck lights break the sterile white surfaces at dusk.
    for side in (-1.0, 1.0):
        for z in np.linspace(-22.0, 22.0, 9):
            parts.append(sphere((0.08, 0.08, 0.08), (side * 7.45, 7.65, float(z)), WARM))

    scene = trimesh.Scene()
    for i, mesh in enumerate(parts):
        scene.add_geometry(mesh, node_name=f"V20_ULTRA_FERRY_{i:04d}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    data = scene.export(file_type="glb")
    OUT.write_bytes(data)
    print(f"generated {OUT}: {len(data)/1024/1024:.2f} MB, parts={len(parts)}")


if __name__ == "__main__":
    make_ferry()
