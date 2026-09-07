import math
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

OUT = Path("assets/v20/marine")
OUT.mkdir(parents=True, exist_ok=True)


def pbr(name, rgb, metallic=0.0, rough=0.5, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c))*255) for c in rgb) + (255,)
    mat = PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)
    if emissive is not None:
        mat.emissiveFactor = emissive
    return mat

WHITE = pbr("marine_white", (0.78,0.80,0.80), 0.06, 0.42)
DARK = pbr("marine_dark", (0.045,0.055,0.06), 0.35, 0.48)
RED = pbr("marine_antifoul", (0.34,0.025,0.022), 0.04, 0.68)
DECK = pbr("marine_deck", (0.18,0.19,0.19), 0.18, 0.72)
STEEL = pbr("marine_steel", (0.46,0.49,0.50), 0.72, 0.30)
GLASS = pbr("marine_glass", (0.015,0.045,0.060), 0.20, 0.10)
ORANGE = pbr("container_orange", (0.66,0.20,0.035), 0.06, 0.66)
BLUE = pbr("container_blue", (0.035,0.19,0.38), 0.08, 0.62)
GREEN = pbr("container_green", (0.045,0.28,0.16), 0.06, 0.66)
YELLOW = pbr("workboat_yellow", (0.84,0.58,0.035), 0.08, 0.54)
WARM = pbr("marine_warm_light", (0.95,0.77,0.42), 0.0, 0.16, emissive=(0.8,0.5,0.16))


def apply(mesh, mat, smooth=True):
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    if smooth:
        _ = mesh.vertex_normals
    return mesh


def box(size, pos, mat):
    m = trimesh.creation.box(extents=size)
    m.apply_translation(pos)
    return apply(m, mat, False)


def cyl(radius, height, pos, mat, sections=24, axis="y"):
    m = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2, [1,0,0]))
    elif axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2, [0,1,0]))
    m.apply_translation(pos)
    return apply(m, mat)


def hull(length, beam, depth, mat, bow_factor=1.0):
    zvals = np.linspace(-length*0.5, length*0.5, 80)
    yvals = [-depth, -depth*0.50, 0.0, depth*0.62]
    verts = []
    for y in yvals:
        for z in zvals:
            q = min(1.0, abs(z)/(length*0.5))
            taper = max(0.03, (1.0-q**(3.5*bow_factor))**0.35)
            flare = np.interp(y, [-depth, -depth*0.5, 0.0, depth*0.62], [0.18,0.55,0.82,1.0])
            w = beam*0.5*taper*flare
            verts.extend([(-w,y,z),(w,y,z)])
    faces=[]
    row=len(zvals)*2
    for iy in range(len(yvals)-1):
        for iz in range(len(zvals)-1):
            a=iy*row+iz*2; b=a+1; c=a+2; d=a+3
            e=(iy+1)*row+iz*2; f=e+1; g=e+2; h=e+3
            faces += [[a,e,g],[a,g,c],[b,d,h],[b,h,f]]
    m=trimesh.Trimesh(np.asarray(verts),np.asarray(faces),process=True)
    m.fix_normals()
    return apply(m,mat)


def export(name, parts):
    scene=trimesh.Scene()
    for i,m in enumerate(parts):
        scene.add_geometry(m,node_name=f"{name}_{i:03d}")
    data=scene.export(file_type="glb")
    path=OUT/f"{name}.glb"
    path.write_bytes(data)
    print(f"generated {path}: {len(data)/1024:.1f} KB parts={len(parts)}")


def cargo_ship():
    p=[hull(168,25,7.0,DARK,1.10), box((23,0.8,128),(0,4.8,5),DECK)]
    # aft superstructure
    p += [box((17,12,20),(0,10.0,58),WHITE), box((16,3.0,12),(0,17.2,57),WHITE)]
    for x in [-6,-2,2,6]:
        p.append(box((2.6,1.5,0.12),(x,17.4,50.9),GLASS))
    p.append(cyl(1.8,7.0,(0,19.0,66),DARK,28,"y"))
    # container stacks
    colors=[ORANGE,BLUE,GREEN,WHITE]
    idx=0
    for z in range(-48,42,13):
        for x in [-7.2,-2.4,2.4,7.2]:
            for level in range(2 + (idx%2)):
                p.append(box((4.2,2.5,11.2),(x,6.5+level*2.55,z),colors[(idx+level)%len(colors)]))
            idx+=1
    export("cargo_ship_v20",p)


def tanker():
    p=[hull(182,29,7.5,DARK,1.05), box((26.5,0.8,142),(0,5.2,2),DECK)]
    # rounded tank domes and pipe deck
    for z in [-48,-24,0,24,48]:
        for x in [-7.0,7.0]:
            p.append(cyl(4.6,3.2,(x,7.1,z),WHITE,32,"y"))
    p.append(box((18,13,21),(0,11.5,66),WHITE))
    for x in [-6,-2,2,6]:
        p.append(box((2.7,1.5,0.12),(x,15.5,55.4),GLASS))
    p.append(cyl(2.1,8.5,(0,20.0,72),DARK,30,"y"))
    for x in [-9.0,0.0,9.0]:
        p.append(cyl(0.18,118,(x,6.0,0),STEEL,12,"z"))
    export("tanker_v20",p)


def tug():
    p=[hull(31,10.5,3.2,DARK,0.90), box((9.4,0.55,23),(0,2.4,0),DECK)]
    p += [box((8.2,5.4,10),(0,5.0,-1),YELLOW), box((7.1,2.5,6),(0,8.7,-2),WHITE)]
    for x in [-2.5,0,2.5]:
        p.append(box((1.7,1.1,0.10),(x,8.8,-5.05),GLASS))
    p += [cyl(0.18,7.0,(0,12.0,-1),STEEL,16,"y"), box((5.5,0.15,0.3),(0,13.3,-1),STEEL)]
    for z in [-9,8]:
        p.append(cyl(0.8,1.8,(0,3.3,z),DARK,24,"x"))
    export("tug_v20",p)


def fishing():
    p=[hull(21,6.2,2.5,WHITE,0.86), box((5.5,0.45,14),(0,2.0,1),DECK)]
    p += [box((5.1,3.7,6.2),(0,4.1,-1.8),WHITE), box((4.6,1.4,3.6),(0,6.5,-2.6),WHITE)]
    for x in [-1.5,0,1.5]:
        p.append(box((0.95,0.8,0.08),(x,6.5,-4.43),GLASS))
    p += [cyl(0.10,7.5,(0,9.0,0),STEEL,12,"y"), box((6.8,0.12,0.20),(0,10.3,0),STEEL)]
    export("fishing_boat_v20",p)


if __name__ == "__main__":
    cargo_ship(); tanker(); tug(); fishing()
