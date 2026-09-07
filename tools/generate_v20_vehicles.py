import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = Path("assets/v20/vehicles")
OUT.mkdir(parents=True, exist_ok=True)


def pbr(name, rgb, metallic=0.0, rough=0.5, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    m = PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)
    if emissive is not None:
        m.emissiveFactor = emissive
    return m


PAINT = pbr("v20_vehicle_paint", (0.12, 0.30, 0.58), 0.34, 0.22)
PAINT_LIGHT = pbr("v20_vehicle_paint_trim", (0.18, 0.38, 0.66), 0.30, 0.24)
GLASS = pbr("v20_vehicle_glass", (0.012, 0.035, 0.050), 0.20, 0.09)
RUBBER = pbr("v20_vehicle_rubber", (0.010, 0.011, 0.012), 0.0, 0.96)
RIM = pbr("v20_vehicle_rim", (0.48, 0.50, 0.50), 0.72, 0.24)
DARK = pbr("v20_vehicle_dark", (0.035, 0.040, 0.043), 0.25, 0.48)
LIGHT = pbr("v20_vehicle_headlight", (0.82, 0.87, 0.83), 0.05, 0.14, (0.72, 0.68, 0.48))
RED = pbr("v20_vehicle_taillight", (0.72, 0.01, 0.01), 0.02, 0.18, (0.55, 0.0, 0.0))
WHITE = pbr("v20_vehicle_white", (0.82, 0.84, 0.84), 0.15, 0.30)
METAL = pbr("v20_vehicle_metal", (0.43, 0.45, 0.46), 0.78, 0.30)


def apply(mesh, mat, smooth=True):
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    if smooth:
        _ = mesh.vertex_normals
    return mesh


def box(extents, pos, mat):
    m = trimesh.creation.box(extents=extents)
    m.apply_translation(pos)
    return apply(m, mat, False)


def cyl(radius, width, pos, mat, sections=24):
    m = trimesh.creation.cylinder(radius=radius, height=width, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [0, 1, 0]))
    m.apply_translation(pos)
    return apply(m, mat)


def loft_body(length, base_y, top_profile, width_profile, mat, sections=29):
    zs = np.linspace(-length/2, length/2, sections)
    verts = []
    for z in zs:
        t = (z + length/2) / length
        width = float(np.interp(t, width_profile[0], width_profile[1]))
        top = float(np.interp(t, top_profile[0], top_profile[1]))
        shoulder = width * 0.93
        verts.extend([
            (-width, base_y, z), (width, base_y, z),
            (-shoulder, top * 0.67, z), (shoulder, top * 0.67, z),
            (-width * 0.78, top, z), (width * 0.78, top, z),
        ])
    faces = []
    ring = 6
    pairs = [(0,2),(2,4),(4,5),(5,3),(3,1),(1,0)]
    for i in range(sections-1):
        a = i*ring
        b = (i+1)*ring
        for p0,p1 in pairs:
            faces += [[a+p0,b+p0,b+p1],[a+p0,b+p1,a+p1]]
    faces += [[0,1,3],[0,3,2],[2,3,5],[2,5,4]]
    e=(sections-1)*ring
    faces += [[e+0,e+3,e+1],[e+0,e+2,e+3],[e+2,e+5,e+3],[e+2,e+4,e+5]]
    m=trimesh.Trimesh(np.asarray(verts),np.asarray(faces),process=True)
    m.fix_normals()
    return apply(m,mat)


def wheels(parts, wheel_zs, half_width, radius, tyre_width):
    for z in wheel_zs:
        for side in (-1,1):
            x = side * half_width
            parts.append(cyl(radius, tyre_width, (x, radius, z), RUBBER, 28))
            parts.append(cyl(radius*0.48, tyre_width+0.015, (x, radius, z), RIM, 24))


def lamps(parts, length, half_width, y, front_is_negative=True):
    front_z = -length/2 - 0.012 if front_is_negative else length/2 + 0.012
    rear_z = length/2 + 0.012 if front_is_negative else -length/2 - 0.012
    for x in (-half_width*0.72, half_width*0.72):
        parts.append(box((0.32,0.22,0.035),(x,y,front_z),LIGHT))
        parts.append(box((0.28,0.20,0.035),(x,y,rear_z),RED))


def export(name, parts):
    scene=trimesh.Scene()
    for i,m in enumerate(parts):
        scene.add_geometry(m,node_name=f"{name}_{i:03d}")
    data=scene.export(file_type="glb")
    path=OUT/f"{name}.glb"
    path.write_bytes(data)
    print(f"generated {path}: {len(data)/1024:.1f} KB")


def sedan():
    L=4.65; W=0.92
    parts=[loft_body(L,0.36,([0,.12,.28,.48,.72,.88,1],[0.60,0.74,1.16,1.43,1.40,0.92,0.60]),([0,.08,.45,.92,1],[0.70,0.90,0.92,0.88,0.68]),PAINT)]
    # dark glass band/cabin glazing
    parts += [
        box((1.47,0.48,1.55),(0,1.22,-0.22),GLASS),
        box((1.52,0.42,0.07),(0,1.12,-1.00),GLASS),
        box((1.48,0.38,0.07),(0,1.10,0.92),GLASS),
    ]
    wheels(parts,[-1.38,1.34],0.91,0.33,0.22)
    lamps(parts,L,W,0.69)
    for side in (-1,1):
        parts.append(box((0.13,0.10,0.28),(side*1.02,1.08,-0.38),DARK))
    export("sedan_remaster_v20",parts)


def minibus():
    L=5.85; W=1.03
    parts=[loft_body(L,0.42,([0,.08,.20,.78,.94,1],[0.86,1.72,2.20,2.20,1.72,0.92]),([0,.08,.92,1],[0.76,1.02,1.02,0.76]),PAINT_LIGHT)]
    for z in np.linspace(-1.30,1.65,4):
        for side in (-1,1):
            parts.append(box((0.055,0.72,0.83),(side*1.02,1.62,float(z)),GLASS))
    parts.append(box((1.72,0.72,0.055),(0,1.62,-2.70),GLASS))
    wheels(parts,[-1.85,1.78],1.02,0.39,0.24)
    lamps(parts,L,W,0.78)
    export("minibus_remaster_v20",parts)


def bus():
    L=11.75; W=1.27
    parts=[loft_body(L,0.50,([0,.035,.10,.90,.965,1],[1.25,2.80,3.20,3.20,2.75,1.35]),([0,.035,.965,1],[0.94,1.26,1.26,0.94]),PAINT)]
    for side in (-1,1):
        for z in np.linspace(-4.2,4.2,8):
            parts.append(box((0.055,0.82,0.88),(side*1.27,2.18,float(z)),GLASS))
    parts.append(box((2.05,0.88,0.055),(0,2.12,-5.70),GLASS))
    parts.append(box((2.05,0.70,0.055),(0,2.08,5.70),GLASS))
    wheels(parts,[-3.75,3.70],1.25,0.47,0.28)
    lamps(parts,L,W,0.84)
    export("bus_remaster_v20",parts)


def truck():
    parts=[]
    # European cab-over tractor.
    parts.append(loft_body(3.9,0.48,([0,.08,.20,.88,1],[1.2,2.65,3.35,3.35,1.15]),([0,.08,.92,1],[0.98,1.25,1.25,0.96]),PAINT))
    parts.append(box((2.02,0.88,0.055),(0,2.35,-1.90),GLASS))
    for side in (-1,1):
        parts.append(box((0.055,0.82,0.82),(side*1.25,2.30,-0.65),GLASS))
    # chassis and separate trailer with realistic gap.
    parts.append(box((2.28,0.30,9.4),(0,0.70,4.8),DARK))
    parts.append(box((2.52,3.05,7.35),(0,2.05,5.50),WHITE))
    parts.append(box((2.58,0.18,7.42),(0,3.62,5.50),METAL))
    wheels(parts,[-1.25,1.25,4.05,6.20,7.55],1.26,0.49,0.30)
    lamps(parts,3.9,1.27,0.86)
    export("truck_remaster_v20",parts)


if __name__ == "__main__":
    sedan(); minibus(); bus(); truck()
