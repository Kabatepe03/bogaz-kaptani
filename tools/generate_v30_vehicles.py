import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = Path("assets/v20/vehicles")
OUT.mkdir(parents=True, exist_ok=True)


def mat(name, rgb, metallic=0.0, rough=0.5, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    m = PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)
    if emissive is not None:
        m.emissiveFactor = tuple(float(v) for v in emissive)
    return m


PAINT = mat("v30_vehicle_paint", (0.13, 0.30, 0.55), 0.38, 0.20)
PAINT_2 = mat("v30_vehicle_paint_trim", (0.18, 0.35, 0.58), 0.32, 0.23)
GLASS = mat("v30_vehicle_glass", (0.012, 0.038, 0.055), 0.12, 0.08)
RUBBER = mat("v30_vehicle_rubber", (0.008, 0.009, 0.010), 0.0, 0.98)
RIM = mat("v30_vehicle_rim", (0.48, 0.50, 0.51), 0.80, 0.20)
DARK = mat("v30_vehicle_dark", (0.025, 0.028, 0.030), 0.35, 0.46)
CHROME = mat("v30_vehicle_chrome", (0.58, 0.60, 0.61), 0.92, 0.14)
WHITE = mat("v30_vehicle_white", (0.82, 0.84, 0.83), 0.14, 0.31)
HEAD = mat("v30_headlamp", (0.90, 0.90, 0.78), 0.03, 0.12, (0.70, 0.62, 0.35))
TAIL = mat("v30_taillamp", (0.78, 0.012, 0.008), 0.02, 0.16, (0.55, 0.0, 0.0))
ORANGE = mat("v30_indicator", (0.92, 0.30, 0.02), 0.0, 0.18, (0.38, 0.10, 0.0))


def apply(mesh, material):
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    try:
        _ = mesh.vertex_normals
    except Exception:
        pass
    return mesh


def box(ext, pos, material, yaw=0.0):
    m = trimesh.creation.box(extents=ext)
    if abs(yaw) > 1e-7:
        m.apply_transform(trimesh.transformations.rotation_matrix(yaw, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, material)


def cylinder(radius, width, pos, material, sections=32):
    m = trimesh.creation.cylinder(radius=radius, height=width, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, material)


def rounded_shell(length, width, base_y, roof_profile, width_profile, material, sections=45):
    zs = np.linspace(-length * 0.5, length * 0.5, sections)
    verts = []
    ring = 10
    for z in zs:
        t = float((z + length * 0.5) / length)
        roof_y = float(np.interp(t, roof_profile[0], roof_profile[1]))
        half_w = width * float(np.interp(t, width_profile[0], width_profile[1]))
        # Rounded ten-point cross section: underbody -> shoulders -> roof crown.
        verts.extend([
            (-half_w * 0.78, base_y, z),
            (-half_w, base_y + (roof_y-base_y) * 0.28, z),
            (-half_w * 0.98, base_y + (roof_y-base_y) * 0.55, z),
            (-half_w * 0.86, base_y + (roof_y-base_y) * 0.82, z),
            (-half_w * 0.58, roof_y, z),
            (half_w * 0.58, roof_y, z),
            (half_w * 0.86, base_y + (roof_y-base_y) * 0.82, z),
            (half_w * 0.98, base_y + (roof_y-base_y) * 0.55, z),
            (half_w, base_y + (roof_y-base_y) * 0.28, z),
            (half_w * 0.78, base_y, z),
        ])
    faces = []
    for i in range(sections - 1):
        a = i * ring
        b = (i + 1) * ring
        for j in range(ring - 1):
            faces += [[a+j, b+j, b+j+1], [a+j, b+j+1, a+j+1]]
        faces += [[a+ring-1, b+ring-1, b], [a+ring-1, b, a]]
    faces += [[0, j, j+1] for j in range(1, ring-1)]
    e = (sections - 1) * ring
    faces += [[e, e+j+1, e+j] for j in range(1, ring-1)]
    mesh = trimesh.Trimesh(np.asarray(verts), np.asarray(faces), process=True)
    mesh.fix_normals()
    return apply(mesh, material)


def wheels(parts, zs, half_width, radius, width):
    for z in zs:
        for side in (-1.0, 1.0):
            x = side * half_width
            parts.append(cylinder(radius, width, (x, radius, z), RUBBER, 36))
            parts.append(cylinder(radius * 0.55, width + 0.022, (x, radius, z), RIM, 28))
            parts.append(cylinder(radius * 0.13, width + 0.028, (x, radius, z), DARK, 20))


def lamps(parts, length, half_width, y):
    front = -length * 0.5 - 0.018
    rear = length * 0.5 + 0.018
    for x in (-half_width * 0.70, half_width * 0.70):
        parts.append(box((0.38, 0.22, 0.045), (x, y, front), HEAD))
        parts.append(box((0.34, 0.20, 0.045), (x, y, rear), TAIL))
        parts.append(box((0.10, 0.15, 0.052), (x + (0.20 if x < 0 else -0.20), y, front), ORANGE))


def export(name, parts):
    scene = trimesh.Scene()
    for i, mesh in enumerate(parts):
        node = f"V30_{name}_{i:03d}"
        scene.add_geometry(mesh, node_name=node, geom_name=node)
    data = scene.export(file_type="glb")
    path = OUT / f"{name}.glb"
    path.write_bytes(data)
    print(f"generated V30 {path}: {len(data)/1024:.1f} KB parts={len(parts)}")


def sedan():
    L, W = 4.72, 0.94
    parts = [rounded_shell(
        L, W, 0.30,
        ([0.0,0.08,0.18,0.31,0.45,0.67,0.82,0.94,1.0], [0.58,0.66,0.88,1.26,1.48,1.46,1.24,0.72,0.56]),
        ([0.0,0.06,0.18,0.50,0.82,0.95,1.0], [0.72,0.91,0.99,1.0,0.98,0.86,0.68]),
        PAINT, 49,
    )]
    # Panoramic cabin glazing broken into windshield/roof-side/rear glass rather than one black cube.
    parts += [
        box((1.48, 0.52, 0.065), (0.0, 1.16, -0.91), GLASS, 0.0),
        box((1.44, 0.46, 0.065), (0.0, 1.16, 0.89), GLASS, 0.0),
    ]
    for side in (-1.0, 1.0):
        parts.append(box((0.055, 0.48, 1.48), (side * 0.805, 1.16, -0.02), GLASS))
        parts.append(box((0.13, 0.10, 0.27), (side * 1.01, 1.10, -0.46), DARK))
        parts.append(box((0.055, 0.08, 2.75), (side * 0.94, 0.63, 0.02), CHROME))
    parts.append(box((1.48, 0.14, 0.12), (0.0, 0.53, -2.31), DARK))
    parts.append(box((1.46, 0.12, 0.12), (0.0, 0.51, 2.31), DARK))
    parts.append(box((1.10, 0.25, 0.055), (0.0, 0.82, -2.36), DARK))
    wheels(parts, [-1.42, 1.39], 0.93, 0.34, 0.24)
    lamps(parts, L, W, 0.72)
    export("sedan_remaster_v20", parts)


def minibus():
    L, W = 5.95, 1.04
    parts = [rounded_shell(
        L, W, 0.35,
        ([0,.05,.13,.23,.82,.94,1],[0.82,1.18,1.92,2.24,2.24,1.70,0.82]),
        ([0,.05,.12,.90,.97,1],[0.78,0.96,1.0,1.0,0.91,0.72]),
        PAINT_2, 51,
    )]
    for side in (-1.0,1.0):
        for z in (-1.62,-0.62,0.38,1.38):
            parts.append(box((0.052,0.72,0.82),(side*1.035,1.55,z),GLASS))
        parts.append(box((0.06,0.16,4.75),(side*1.04,0.62,0.08),DARK))
        parts.append(box((0.16,0.12,0.30),(side*1.15,1.64,-2.15),DARK))
    parts.append(box((1.72,0.78,0.055),(0,1.55,-2.94),GLASS))
    parts.append(box((1.58,0.52,0.055),(0,1.52,2.94),GLASS))
    wheels(parts,[-1.88,1.78],1.04,0.40,0.25)
    lamps(parts,L,W,0.77)
    export("minibus_remaster_v20",parts)


def bus():
    L, W = 11.90, 1.28
    parts = [rounded_shell(
        L, W, 0.43,
        ([0,.025,.07,.13,.88,.95,.98,1],[1.12,1.76,2.78,3.18,3.18,2.76,1.72,1.08]),
        ([0,.025,.08,.92,.98,1],[0.84,0.98,1.0,1.0,0.96,0.82]),
        PAINT, 61,
    )]
    for side in (-1.0,1.0):
        for z in np.linspace(-4.45,4.45,9):
            parts.append(box((0.052,0.78,0.86),(side*1.275,2.12,float(z)),GLASS))
        parts.append(box((0.060,0.22,9.80),(side*1.28,0.72,0.0),DARK))
    parts.append(box((2.08,0.92,0.055),(0,2.08,-5.90),GLASS))
    parts.append(box((1.82,0.62,0.055),(0,2.06,5.90),GLASS))
    parts.append(box((1.95,0.18,0.16),(0,0.68,-5.91),DARK))
    wheels(parts,[-3.88,3.72],1.27,0.48,0.29)
    lamps(parts,L,W,0.84)
    export("bus_remaster_v20",parts)


def truck():
    parts=[]
    # Cab-over tractor uses a rounded shell; trailer gets edge rails, under-run guards and separate chassis.
    parts.append(rounded_shell(
        4.05,1.26,0.42,
        ([0,.04,.11,.20,.86,.96,1],[1.08,1.65,2.85,3.40,3.40,2.55,1.05]),
        ([0,.05,.12,.92,1],[0.86,0.99,1.0,0.99,0.84]),
        PAINT,45,
    ))
    parts.append(box((2.03,0.92,0.055),(0,2.36,-2.01),GLASS))
    for side in (-1.0,1.0):
        parts.append(box((0.055,0.82,0.82),(side*1.255,2.28,-0.70),GLASS))
        parts.append(box((0.16,0.12,0.34),(side*1.40,2.36,-1.30),DARK))
    parts.append(box((2.32,0.31,9.55),(0,0.70,4.85),DARK))
    parts.append(box((2.54,3.02,7.48),(0,2.05,5.58),WHITE))
    parts.append(box((2.60,0.17,7.52),(0,3.64,5.58),CHROME))
    for side in (-1.0,1.0):
        parts.append(box((0.09,0.18,7.25),(side*1.30,0.78,5.58),CHROME))
        parts.append(box((0.12,0.68,0.12),(side*1.34,0.62,8.85),DARK))
    wheels(parts,[-1.28,1.25,4.18,6.38,7.72],1.27,0.50,0.30)
    lamps(parts,4.05,1.27,0.84)
    export("truck_remaster_v20",parts)


if __name__ == "__main__":
    sedan(); minibus(); bus(); truck()
