import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

import generate_v12_world as v12

WORLD = os.path.join("assets", "v20", "canakkale_eceabat_remaster_v20.glb")


def pbr(name, rgb, rough=0.95):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    return PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=0.0, roughnessFactor=rough)


TRUNK = pbr("v22_trunk", (0.14, 0.075, 0.035), 0.98)
PINE = pbr("v22_pine", (0.028, 0.105, 0.035), 0.97)
PINE_SUN = pbr("v22_pine_sun", (0.060, 0.155, 0.050), 0.96)
OLIVE = pbr("v22_olive", (0.17, 0.26, 0.105), 0.97)
CYPRESS = pbr("v22_cypress", (0.018, 0.072, 0.028), 0.98)
SCRUB = pbr("v22_scrub", (0.18, 0.29, 0.090), 0.98)
DRY_SCRUB = pbr("v22_dry_scrub", (0.29, 0.31, 0.12), 0.98)


def local_to_lat_lon(x, z):
    lat = v12.ORIGIN_LAT - z / 110540.0
    lon = v12.ORIGIN_LON + x / (111320.0 * math.cos(math.radians(v12.ORIGIN_LAT)))
    return lat, lon


def elevation(x, z):
    lat, lon = local_to_lat_lon(x, z)
    return float(v12.elevation(lat, lon))


def cone(radius, height, x, y, z, mat, sections=8):
    m = trimesh.creation.cone(radius=radius, height=height, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    m.apply_translation((x, y + height * 0.5, z))
    m.visual = trimesh.visual.TextureVisuals(material=mat)
    return m


def cylinder(radius, height, x, y, z, mat, sections=7):
    m = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    m.apply_translation((x, y + height * 0.5, z))
    m.visual = trimesh.visual.TextureVisuals(material=mat)
    return m


def olive_crown(x, y, z, scale, mat):
    m = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    m.apply_scale((3.1 * scale, 1.75 * scale, 2.8 * scale))
    m.apply_translation((x, y + 4.3 * scale, z))
    m.visual = trimesh.visual.TextureVisuals(material=mat)
    return m


def shrub(x, y, z, scale, mat):
    m = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    m.apply_scale((1.8 * scale, 0.85 * scale, 1.55 * scale))
    m.apply_translation((x, y + 0.85 * scale, z))
    m.visual = trimesh.visual.TextureVisuals(material=mat)
    return m


def add_tree(parts, x, z, y, scale, kind, rng):
    parts["trunk"].append(cylinder(0.18 * scale, 4.2 * scale, x, y, z, TRUNK))
    if kind == "cypress":
        parts["cypress"].append(cone(1.45 * scale, 9.5 * scale, x, y + 1.2 * scale, z, CYPRESS, 10))
    elif kind == "olive":
        parts["olive"].append(olive_crown(x, y, z, scale, OLIVE))
    else:
        yaw = float(rng.uniform(0.0, math.tau))
        crowns = [
            cone(3.0 * scale, 4.8 * scale, x, y + 2.1 * scale, z, PINE, 9),
            cone(2.35 * scale, 4.3 * scale, x, y + 4.4 * scale, z, PINE_SUN, 9),
            cone(1.65 * scale, 3.7 * scale, x, y + 6.5 * scale, z, PINE, 9),
        ]
        for crown in crowns:
            crown.apply_transform(trimesh.transformations.rotation_matrix(yaw, [0, 1, 0], point=[x, y, z]))
            parts["pine"].append(crown)


def sample_zone(center, radius_x, radius_z, count, min_h, max_h, mix, rng, parts):
    cx, cz = center
    placed = 0
    attempts = 0
    while placed < count and attempts < count * 18:
        attempts += 1
        theta = float(rng.uniform(0.0, math.tau))
        r = math.sqrt(float(rng.random()))
        x = cx + math.cos(theta) * radius_x * r
        z = cz + math.sin(theta) * radius_z * r
        lat, lon = local_to_lat_lon(x, z)
        if not (v12.SOUTH <= lat <= v12.NORTH and v12.WEST <= lon <= v12.EAST):
            continue
        y = elevation(x, z)
        if y < min_h or y > max_h:
            continue
        roll = float(rng.random())
        if mix == "urban":
            kind = "olive" if roll < 0.62 else ("cypress" if roll < 0.82 else "pine")
        else:
            kind = "pine" if roll < 0.70 else ("cypress" if roll < 0.84 else "olive")
        scale = float(rng.uniform(1.05, 1.75))
        add_tree(parts, x, z, y, scale, kind, rng)
        placed += 1


def main():
    if not os.path.exists(WORLD):
        raise RuntimeError(f"missing world: {WORLD}")
    loaded = trimesh.load(WORLD, force="scene", process=False)
    scene = loaded if isinstance(loaded, trimesh.Scene) else trimesh.Scene(loaded)

    rng = np.random.default_rng(22092026)
    parts = {"trunk": [], "pine": [], "cypress": [], "olive": [], "scrub": [], "dry_scrub": []}

    eceabat = v12.to_local(40.1841667, 26.3602778)
    kilitbahir = v12.to_local(40.14778, 26.37944)
    canakkale = v12.to_local(40.1505556, 26.4019444)

    # Large foreground trees and hillside masses. These are deliberately concentrated where the
    # ferry passenger actually looks, instead of being diluted across the full terrain tile.
    sample_zone(eceabat, 1100.0, 980.0, 2200, 4.0, 180.0, "med", rng, parts)
    sample_zone(kilitbahir, 1200.0, 1250.0, 1800, 5.0, 230.0, "med", rng, parts)
    sample_zone(canakkale, 900.0, 850.0, 850, 3.0, 105.0, "urban", rng, parts)

    # Dense low scrub fills the visual gaps between trees and removes the bare-sand tabletop look.
    for _ in range(6500):
        side_west = rng.random() < 0.70
        if side_west:
            x = float(rng.uniform(-4900.0, -700.0))
            z = float(rng.uniform(-3900.0, 3600.0))
        else:
            x = float(rng.uniform(250.0, 3300.0))
            z = float(rng.uniform(-3400.0, 3100.0))
        y = elevation(x, z)
        if y < 3.5 or y > 220.0:
            continue
        scale = float(rng.uniform(0.75, 1.65))
        target = "scrub" if rng.random() < 0.72 else "dry_scrub"
        parts[target].append(shrub(x, y, z, scale, SCRUB if target == "scrub" else DRY_SCRUB))

    groups = [
        ("trunk", "V22_Foreground_Trunks", TRUNK),
        ("pine", "V22_Foreground_Pines", PINE),
        ("cypress", "V22_Foreground_Cypress", CYPRESS),
        ("olive", "V22_Foreground_Olive", OLIVE),
        ("scrub", "V22_Foreground_Scrub", SCRUB),
        ("dry_scrub", "V22_Foreground_DryScrub", DRY_SCRUB),
    ]
    for key, name, mat in groups:
        if not parts[key]:
            continue
        mesh = trimesh.util.concatenate(parts[key])
        mesh.visual = trimesh.visual.TextureVisuals(material=mat)
        scene.add_geometry(mesh, node_name=name)

    data = scene.export(file_type="glb")
    with open(WORLD, "wb") as stream:
        stream.write(data)
    print(
        "v22 world finish:",
        f"trees={len(parts['trunk'])}",
        f"scrub={len(parts['scrub']) + len(parts['dry_scrub'])}",
        f"size={len(data)/1024/1024:.2f} MB",
    )


if __name__ == "__main__":
    main()
