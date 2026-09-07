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
        mat.emissiveFactor = tuple(float(v) for v in emissive)
    return mat

WHITE = pbr("v30_marine_white", (0.76,0.78,0.77), 0.04, 0.44)
WHITE_TOP = pbr("v30_marine_white_top", (0.88,0.89,0.86), 0.03, 0.36)
HULL = pbr("v30_marine_hull", (0.035,0.047,0.055), 0.38, 0.46)
RED = pbr("v30_marine_antifoul", (0.31,0.024,0.018), 0.04, 0.72)
DECK = pbr("v30_marine_deck", (0.16,0.17,0.17), 0.20, 0.75)
STEEL = pbr("v30_marine_steel", (0.42,0.45,0.46), 0.74, 0.28)
GLASS = pbr("v30_marine_glass", (0.010,0.035,0.050), 0.18, 0.08)
ORANGE = pbr("v30_container_orange", (0.64,0.18,0.028), 0.06, 0.68)
BLUE = pbr("v30_container_blue", (0.028,0.16,0.33), 0.08, 0.64)
GREEN = pbr("v30_container_green", (0.038,0.24,0.13), 0.06, 0.68)
GREY = pbr("v30_container_grey", (0.36,0.38,0.38), 0.12, 0.67)
YELLOW = pbr("v30_workboat_yellow", (0.82,0.52,0.02), 0.08, 0.52)
PORT = pbr("v30_nav_port", (0.92,0.012,0.006), 0.0, 0.10, (0.9,0.0,0.0))
STARBOARD = pbr("v30_nav_starboard", (0.008,0.88,0.05), 0.0, 0.10, (0.0,0.9,0.03))
MAST = pbr("v30_nav_mast", (0.94,0.84,0.57), 0.0, 0.10, (0.75,0.50,0.20))


def apply(mesh, material):
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    try:
        _ = mesh.vertex_normals
    except Exception:
        pass
    return mesh


def box(ext, pos, material, yaw=0.0):
    m = trimesh.creation.box(extents=ext)
    if abs(yaw) > 1e-8:
        m.apply_transform(trimesh.transformations.rotation_matrix(yaw,[0,1,0]))
    m.apply_translation(pos)
    return apply(m, material)


def cylinder(radius, height, pos, material, sections=28, axis="y"):
    m = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    if axis == "y":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[1,0,0]))
    elif axis == "x":
        m.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2,[0,1,0]))
    m.apply_translation(pos)
    return apply(m, material)


def sphere(scale, pos, material, subdivisions=2):
    m = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    m.apply_scale(scale)
    m.apply_translation(pos)
    return apply(m, material)


def smooth_hull(length, beam, draft, freeboard, material, bow_power=3.6, stern_power=4.8, sections=181):
    zs = np.linspace(-length*0.5, length*0.5, sections)
    ys = np.array([-draft, -draft*0.80, -draft*0.48, -draft*0.15, freeboard*0.22, freeboard*0.60, freeboard], dtype=float)
    verts=[]
    for y in ys:
        for z in zs:
            q = z/(length*0.5)
            power = bow_power if q < 0 else stern_power
            taper = max(0.025, (1.0 - min(1.0, abs(q))**power)**0.42)
            flare = np.interp(y, [-draft,-draft*.8,-draft*.48,-draft*.15,freeboard*.22,freeboard*.6,freeboard],[0.14,0.32,0.58,0.78,0.91,0.98,1.0])
            w = beam*0.5*taper*flare
            verts.extend([(-w,y,z),(w,y,z)])
    faces=[]
    row=len(zs)*2
    for iy in range(len(ys)-1):
        for iz in range(len(zs)-1):
            a=iy*row+iz*2; b=a+1; c=a+2; d=a+3
            e=(iy+1)*row+iz*2; f=e+1; g=e+2; h=e+3
            faces += [[a,e,g],[a,g,c],[b,d,h],[b,h,f]]
    top=(len(ys)-1)*row
    for iz in range(len(zs)-1):
        a=top+iz*2; b=a+1; c=a+2; d=a+3
        faces += [[a,b,d],[a,d,c]]
    m=trimesh.Trimesh(np.asarray(verts),np.asarray(faces),process=True)
    m.fix_normals()
    return apply(m,material)


def rounded_house(length, width, y0, y1, z0, material, sections=21):
    zs=np.linspace(z0-length*0.5,z0+length*0.5,sections)
    verts=[]; ring=8
    for z in zs:
        q=abs((z-z0)/(length*0.5))
        taper=max(.72,1.0-q**3*.22)
        w=width*.5*taper
        verts += [(-w,y0,z),(-w,y0+(y1-y0)*.48,z),(-w*.78,y1,z),(w*.78,y1,z),(w,y0+(y1-y0)*.48,z),(w,y0,z),(w*.76,y0-.08,z),(-w*.76,y0-.08,z)]
    faces=[]
    for i in range(sections-1):
        a=i*ring; b=(i+1)*ring
        for j in range(ring):
            j2=(j+1)%ring
            faces += [[a+j,b+j,b+j2],[a+j,b+j2,a+j2]]
    m=trimesh.Trimesh(np.asarray(verts),np.asarray(faces),process=True)
    m.fix_normals()
    return apply(m,material)


def nav_lights(parts, beam, z, y):
    parts.append(sphere((0.28,0.28,0.28),(-beam*.52,y,z),PORT,1))
    parts.append(sphere((0.28,0.28,0.28),(beam*.52,y,z),STARBOARD,1))
    parts.append(sphere((0.25,0.25,0.25),(0,y+2.4,z),MAST,1))


def export(name, parts):
    scene=trimesh.Scene()
    for i,m in enumerate(parts):
        n=f"V30_{name}_{i:03d}"
        scene.add_geometry(m,node_name=n,geom_name=n)
    data=scene.export(file_type="glb")
    path=OUT/f"{name}.glb"
    path.write_bytes(data)
    print(f"generated V30 marine {path}: {len(data)/1024:.1f} KB parts={len(parts)}")


def cargo_ship():
    L,B=171.0,25.8
    p=[smooth_hull(L,B,7.4,4.9,HULL,3.9,5.6,191)]
    # red antifouling side bands
    for side in (-1,1):
        p.append(box((0.16,2.0,142.0),(side*12.05,-4.7,3.0),RED))
    p.append(box((23.7,0.55,132.0),(0,5.0,3.0),DECK))
    p.append(rounded_house(21.0,17.6,5.2,16.7,59.0,WHITE,25))
    p.append(rounded_house(12.0,15.6,16.5,20.1,58.0,WHITE_TOP,17))
    for x in np.linspace(-6.2,6.2,7):
        p.append(box((1.35,1.35,0.09),(float(x),18.1,51.9),GLASS))
    p.append(cylinder(1.7,7.6,(0,20.4,68.0),HULL,30,"y"))
    colors=[ORANGE,BLUE,GREEN,GREY]
    idx=0
    for z in np.arange(-50.0,42.0,12.6):
        for x in (-7.0,-2.35,2.35,7.0):
            levels=2 + ((idx//3)%2)
            for level in range(levels):
                p.append(box((4.12,2.45,11.3),(x,6.6+level*2.49,float(z)),colors[(idx+level)%4]))
            idx += 1
    # cranes/vent boxes and nav equipment
    for z in (-31.0,17.0):
        p.append(cylinder(.22,10.0,(0,10.4,z),STEEL,14,"y"))
        p.append(box((9.0,.18,.20),(0,15.0,z),STEEL))
    nav_lights(p,B,50.0,19.4)
    export("cargo_ship_v20",p)


def tanker():
    L,B=186.0,29.4
    p=[smooth_hull(L,B,7.8,5.2,HULL,3.7,5.2,201), box((27.0,.55,145.0),(0,5.3,0),DECK)]
    # rounded cargo domes, pipe racks and catwalk
    for z in (-52,-30,-8,14,36,58):
        for x in (-7.1,7.1):
            p.append(cylinder(4.7,2.7,(x,6.9,z),WHITE_TOP,40,"y"))
            p.append(sphere((4.55,.70,4.55),(x,8.3,z),WHITE_TOP,2))
    p.append(rounded_house(22.0,18.2,5.5,18.4,68.0,WHITE,25))
    p.append(rounded_house(11.0,16.2,18.2,21.5,68.0,WHITE_TOP,17))
    for x in np.linspace(-6.2,6.2,7):
        p.append(box((1.4,1.35,.09),(float(x),19.6,61.8),GLASS))
    for x in (-9.0,0.0,9.0):
        p.append(cylinder(.18,126.0,(x,6.2,0),STEEL,12,"z"))
    for z in np.arange(-54,55,18):
        p.append(box((21.0,.12,.18),(0,7.1,float(z)),STEEL))
    p.append(cylinder(2.0,8.8,(0,22.0,76.0),HULL,30,"y"))
    nav_lights(p,B,60.0,21.0)
    export("tanker_v20",p)


def tug():
    L,B=32.5,10.8
    p=[smooth_hull(L,B,3.3,2.5,HULL,3.2,4.0,121), box((9.8,.42,24.0),(0,2.65,0),DECK)]
    p.append(rounded_house(10.2,8.4,2.8,7.2,-1.5,YELLOW,19))
    p.append(rounded_house(6.4,7.2,7.1,10.0,-2.0,WHITE_TOP,15))
    for x in (-2.45,0,2.45):
        p.append(box((1.35,1.05,.08),(x,8.8,-5.22),GLASS))
    p.append(cylinder(.18,7.5,(0,12.0,-1.0),STEEL,16,"y"))
    p.append(box((5.6,.14,.28),(0,14.8,-1.0),STEEL))
    for z in (-10.0,9.0):
        for side in (-1,1):
            p.append(cylinder(.74,1.6,(side*4.9,3.2,z),FENDER if 'FENDER' in globals() else HULL,24,"x"))
    nav_lights(p,B,-5.0,10.4)
    export("tug_v20",p)


def fishing():
    L,B=22.5,6.5
    p=[smooth_hull(L,B,2.6,1.9,WHITE,3.0,3.8,111), box((5.7,.38,14.8),(0,2.15,1.0),DECK)]
    p.append(rounded_house(6.8,5.2,2.2,6.2,-1.8,WHITE_TOP,17))
    for x in (-1.55,0,1.55):
        p.append(box((.95,.78,.08),(x,5.6,-5.24),GLASS))
    p.append(cylinder(.10,7.5,(0,8.5,.0),STEEL,12,"y"))
    p.append(box((6.8,.10,.18),(0,11.2,0),STEEL))
    p.append(cylinder(.08,11.0,(-2.4,7.5,2.8),STEEL,10,"y"))
    p.append(box((4.6,.09,.14),(-.4,12.5,2.8),STEEL))
    nav_lights(p,B,-4.8,6.9)
    export("fishing_boat_v20",p)


if __name__ == "__main__":
    cargo_ship(); tanker(); tug(); fishing()
