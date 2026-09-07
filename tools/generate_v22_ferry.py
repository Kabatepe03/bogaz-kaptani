import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = Path("assets/v20/ferry_remaster_v20.glb")
OUT.parent.mkdir(parents=True, exist_ok=True)


def material(name, rgb, metallic=0.0, roughness=0.5, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    mat = PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=roughness)
    if emissive is not None:
        mat.emissiveFactor = tuple(float(v) for v in emissive)
    return mat


WHITE = material("v22_marine_white", (0.82, 0.85, 0.85), 0.02, 0.42)
WHITE_TOP = material("v22_white_top", (0.91, 0.92, 0.90), 0.02, 0.34)
NAVY = material("v22_navy", (0.018, 0.055, 0.105), 0.04, 0.48)
BLUE = material("v22_waterline", (0.025, 0.13, 0.24), 0.03, 0.46)
RED = material("v22_antifouling", (0.30, 0.025, 0.025), 0.01, 0.72)
DECK = material("v22_vehicle_deck", (0.075, 0.082, 0.086), 0.02, 0.91)
STEEL = material("v22_steel", (0.43, 0.47, 0.49), 0.62, 0.34)
DARK_STEEL = material("v22_dark_steel", (0.055, 0.065, 0.070), 0.48, 0.48)
GLASS = material("v22_bridge_glass", (0.012, 0.045, 0.065), 0.14, 0.10)
RUBBER = material("v22_rubber", (0.009, 0.010, 0.010), 0.0, 0.98)
ORANGE = material("v22_safety_orange", (0.93, 0.22, 0.025), 0.0, 0.62)
YELLOW = material("v22_lane_yellow", (0.90, 0.68, 0.08), 0.0, 0.72)
WINDOW = material("v22_lounge_glass", (0.020, 0.060, 0.075), 0.10, 0.16)
LIGHT = material("v22_warm_light", (0.98, 0.80, 0.48), 0.0, 0.15, emissive=(1.0, 0.58, 0.22))
RED_LIGHT = material("v22_port_light", (0.94, 0.02, 0.01), 0.0, 0.12, emissive=(1.0, 0.0, 0.0))
GREEN_LIGHT = material("v22_starboard_light", (0.01, 0.88, 0.12), 0.0, 0.12, emissive=(0.0, 1.0, 0.08))


def apply(mesh, mat):
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    return mesh


def box(extents, pos, mat, rotation=None):
    m = trimesh.creation.box(extents=extents)
    if rotation is not None:
        angle, axis = rotation
        m.apply_transform(trimesh.transformations.rotation_matrix(angle, axis))
    m.apply_translation(pos)
    return apply(m, mat)


def cyl(radius, height, pos, mat, sections=24, axis="y"):
    m = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    elif axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, mat)


def sphere(scale, pos, mat):
    m = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    m.apply_scale(scale)
    m.apply_translation(pos)
    return apply(m, mat)


def torus(major, minor, pos, mat, axis="x"):
    m = trimesh.creation.torus(major_radius=major, minor_radius=minor, major_sections=28, minor_sections=10)
    if axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, mat)


def hull_half_width(z, y):
    q = min(1.0, abs(z) / 44.0)
    end_taper = max(0.035, (1.0 - q ** 3.9) ** 0.45)
    flare = np.interp(y, [-5.0, -4.0, -2.7, -1.3, 0.2, 2.3, 4.25], [0.20, 0.39, 0.63, 0.80, 0.91, 0.98, 1.0])
    return 8.40 * end_taper * flare


def make_hull():
    zs = np.linspace(-44.0, 44.0, 221)
    ys = np.array([-5.0, -4.1, -3.1, -2.0, -0.8, 0.5, 2.0, 3.25, 4.25], dtype=float)
    verts = []
    for y in ys:
        for z in zs:
            w = hull_half_width(float(z), float(y))
            verts.append((-w, float(y), float(z)))
            verts.append((w, float(y), float(z)))
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
            faces.extend([[a, e, g], [a, g, c], [b, d, h], [b, h, f]])
    top = (len(ys) - 1) * row
    for iz in range(len(zs) - 1):
        a, b, c, d = top + iz * 2, top + iz * 2 + 1, top + iz * 2 + 2, top + iz * 2 + 3
        faces.extend([[a, d, c], [a, b, d]])
    m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
    m.fix_normals()
    return apply(m, WHITE)


def make_side_band(y0, y1, mat):
    parts = []
    for side in (-1.0, 1.0):
        zs = np.linspace(-42.5, 42.5, 140)
        verts = []
        for z in zs:
            verts.extend([
                (side * (hull_half_width(float(z), y0) + 0.035), y0, float(z)),
                (side * (hull_half_width(float(z), y1) + 0.035), y1, float(z)),
            ])
        faces = []
        for i in range(len(zs) - 1):
            a, b, c, d = i * 2, i * 2 + 1, i * 2 + 2, i * 2 + 3
            if side > 0:
                faces.extend([[a, b, c], [c, b, d]])
            else:
                faces.extend([[a, c, b], [c, d, b]])
        m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
        m.fix_normals()
        parts.append(apply(m, mat))
    return parts


def rounded_loft(zs, widths, y_bottom, y_top, mat):
    # Four-corner section loft with tapered ends; far less boxy than a single cuboid.
    verts = []
    for z, w in zip(zs, widths):
        shoulder = w * 0.97
        roof = w * 0.88
        verts.extend([
            (-shoulder, y_bottom, z), (shoulder, y_bottom, z),
            (-w, y_bottom + 0.65, z), (w, y_bottom + 0.65, z),
            (-roof, y_top - 0.40, z), (roof, y_top - 0.40, z),
            (-roof * 0.94, y_top, z), (roof * 0.94, y_top, z),
        ])
    faces = []
    section = 8
    for i in range(len(zs) - 1):
        a = i * section
        b = (i + 1) * section
        loops = [(0,2),(2,4),(4,6),(6,7),(7,5),(5,3),(3,1),(1,0)]
        for p0, p1 in loops:
            faces.extend([[a+p0, b+p0, b+p1], [a+p0, b+p1, a+p1]])
    # end caps
    for base, reverse in ((0, True), ((len(zs)-1)*section, False)):
        cap = [[0,1,3],[0,3,2],[2,3,5],[2,5,4],[4,5,7],[4,7,6]]
        for f in cap:
            faces.append([base + idx for idx in (reversed(f) if reverse else f)])
    m = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
    m.fix_normals()
    return apply(m, mat)


def add_rails(parts, x, z0, z1, y):
    parts.append(box((0.06, 0.06, z1-z0), (x, y+0.95, (z0+z1)*0.5), STEEL))
    parts.append(box((0.045, 0.045, z1-z0), (x, y+0.52, (z0+z1)*0.5), STEEL))
    for z in np.arange(z0, z1+0.01, 2.2):
        parts.append(cyl(0.028, 1.02, (x, y+0.48, float(z)), STEEL, 8, "y"))


def add_deck(parts):
    parts.append(box((15.5, 0.30, 74.0), (0.0, 4.30, 0.0), DECK))
    for x in (-5.8, -1.95, 1.95, 5.8):
        for z in np.arange(-31.0, 32.0, 8.0):
            parts.append(box((0.075, 0.025, 4.5), (x, 4.48, float(z)), WHITE_TOP))
    for x in (-7.25, 7.25):
        parts.append(box((0.09, 0.025, 69.0), (x, 4.49, 0.0), YELLOW))
    for z, sign in ((-40.5, -1.0), (40.5, 1.0)):
        parts.append(box((15.5, 0.26, 7.0), (0.0, 4.28, z), STEEL))
        parts.append(cyl(0.25, 15.1, (0.0, 4.30, z-sign*3.15), DARK_STEEL, 24, "x"))
        for x in np.linspace(-6.6, 6.6, 7):
            parts.append(box((0.08, 0.025, 6.2), (float(x), 4.45, z), YELLOW if abs(x) < 1.2 else WHITE_TOP))


def add_superstructure(parts):
    # Passenger lounge: tapered fore/aft ends keep both vehicle-deck approaches visually open.
    zs = np.array([-25.5, -23.0, -18.0, -9.0, 0.0, 9.0, 18.0, 23.0, 25.5])
    widths = np.array([4.2, 6.4, 7.0, 7.15, 7.2, 7.15, 7.0, 6.4, 4.2])
    parts.append(rounded_loft(zs, widths, 7.2, 10.9, WHITE))
    parts.append(box((14.0, 0.24, 47.0), (0.0, 7.05, 0.0), WHITE_TOP))

    # Window ribbon on both sides with metal mullions.
    for side in (-1.0, 1.0):
        x = side * 7.16
        for z in np.arange(-20.5, 21.0, 3.0):
            parts.append(box((0.10, 1.25, 2.28), (x, 9.15, float(z)), WINDOW))
            parts.append(box((0.14, 1.42, 0.12), (x + side*0.02, 9.15, float(z)+1.20), STEEL))

    # Wheelhouse: compact central panoramic bridge, not a giant white block.
    bridge_z = np.array([-6.2, -5.2, 0.0, 5.2, 6.2])
    bridge_w = np.array([4.6, 6.15, 6.65, 6.15, 4.6])
    parts.append(rounded_loft(bridge_z, bridge_w, 11.0, 14.2, WHITE_TOP))
    for z in (-6.25, 6.25):
        for x in np.linspace(-4.8, 4.8, 9):
            parts.append(box((0.95, 1.20, 0.10), (float(x), 12.85, z), GLASS))
    for side in (-1.0, 1.0):
        for z in (-3.6, -1.2, 1.2, 3.6):
            parts.append(box((0.10, 1.10, 1.55), (side*6.35, 12.85, z), GLASS))
    parts.append(box((12.9, 0.24, 12.1), (0.0, 14.35, 0.0), NAVY))

    # Structural side arches and open deck supports.
    for side in (-1.0, 1.0):
        for z in (-28.0, -22.0, 22.0, 28.0):
            parts.append(box((0.34, 4.0, 0.44), (side*7.75, 6.25, z), STEEL))
        add_rails(parts, side*8.0, -34.0, 34.0, 4.45)


def add_equipment(parts):
    # Tyre fenders and life rings.
    for side in (-1.0, 1.0):
        for z in np.linspace(-31.0, 31.0, 13):
            parts.append(torus(0.45, 0.14, (side*8.54, 2.5, float(z)), RUBBER, "x"))
        for z in (-20.0, -6.5, 6.5, 20.0):
            parts.append(torus(0.42, 0.11, (side*7.32, 10.35, z), ORANGE, "x"))
        for z in (-29.0, -24.0, 24.0, 29.0):
            parts.append(cyl(0.28, 0.60, (side*7.1, 4.75, z), DARK_STEEL, 20, "y"))
        for z in (-26.0, 26.0):
            parts.append(cyl(0.50, 0.72, (side*6.0, 4.78, z), DARK_STEEL, 24, "x"))

    # Liferaft canisters along upper deck.
    for side in (-1.0, 1.0):
        for z in (-17.0, -8.5, 8.5, 17.0):
            parts.append(cyl(0.35, 1.55, (side*7.38, 10.95, z), ORANGE, 18, "x"))

    # Twin exhausts, mast, radar and navigation lamps.
    for x in (-1.85, 1.85):
        parts.append(cyl(0.48, 3.3, (x, 15.95, 1.2), DARK_STEEL, 24, "y"))
        parts.append(cyl(0.58, 0.34, (x, 17.55, 1.2), RUBBER, 24, "y"))
    parts.append(cyl(0.12, 6.1, (0.0, 17.6, -1.1), STEEL, 18, "y"))
    parts.append(box((6.0, 0.14, 0.24), (0.0, 19.6, -1.1), STEEL))
    parts.append(box((4.0, 0.16, 0.72), (0.0, 20.45, -1.1), WHITE_TOP))
    parts.append(sphere((0.15,0.15,0.15), (-7.5, 14.8, -0.6), RED_LIGHT))
    parts.append(sphere((0.15,0.15,0.15), (7.5, 14.8, -0.6), GREEN_LIGHT))
    parts.append(sphere((0.15,0.15,0.15), (0.0, 21.0, -1.1), LIGHT))


def main():
    parts = [make_hull()]
    parts.extend(make_side_band(-4.5, -1.5, RED))
    parts.extend(make_side_band(-1.45, -0.65, NAVY))
    parts.extend(make_side_band(-0.60, -0.18, BLUE))
    add_deck(parts)
    add_superstructure(parts)
    add_equipment(parts)

    scene = trimesh.Scene()
    for idx, mesh in enumerate(parts):
        scene.add_geometry(mesh, node_name=f"V22_FerryPart_{idx:04d}")
    data = scene.export(file_type="glb")
    OUT.write_bytes(data)
    print(f"generated {OUT}: {len(data)/1024/1024:.2f} MB, detail_parts={len(parts)}")


if __name__ == "__main__":
    main()
