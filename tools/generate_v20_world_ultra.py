import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

import generate_v12_world as v12

OUT = os.path.join("assets", "v20")
os.makedirs(OUT, exist_ok=True)
BASE_WORLD = os.path.join(OUT, "canakkale_eceabat_remaster_v20.glb")


def pbr(name, rgb, rough=0.92):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    return PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=0.0, roughnessFactor=rough)


TRUNK = pbr("ultra_tree_trunk", (0.16, 0.09, 0.045), 0.98)
PINE_DARK = pbr("ultra_pine_dark", (0.035, 0.115, 0.040), 0.97)
PINE_MID = pbr("ultra_pine_mid", (0.060, 0.165, 0.050), 0.96)
CYPRESS = pbr("ultra_cypress", (0.025, 0.090, 0.035), 0.98)
OLIVE = pbr("ultra_olive", (0.16, 0.245, 0.105), 0.97)
SCRUB = pbr("ultra_scrub", (0.20, 0.285, 0.105), 0.98)


def local_to_lat_lon(x, z):
    lat = v12.ORIGIN_LAT - z / 110540.0
    lon = v12.ORIGIN_LON + x / (111320.0 * math.cos(math.radians(v12.ORIGIN_LAT)))
    return lat, lon


def height_at(x, z):
    lat, lon = local_to_lat_lon(x, z)
    return float(v12.elevation(lat, lon))


def cone(radius, height, x, y, z, material, sections=8):
    mesh = trimesh.creation.cone(radius=radius, height=height, sections=sections)
    mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    mesh.apply_translation((x, y + height * 0.5, z))
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    return mesh


def trunk(radius, height, x, y, z):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=6)
    mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    mesh.apply_translation((x, y + height * 0.5, z))
    mesh.visual = trimesh.visual.TextureVisuals(material=TRUNK)
    return mesh


def pine_parts(x, z, y, scale, rng):
    h = 7.5 * scale
    t = trunk(0.15 * scale, h * 0.44, x, y, z)
    crowns = [
        cone(2.35 * scale, 3.7 * scale, x, y + h * 0.26, z, PINE_DARK, 8),
        cone(1.90 * scale, 3.4 * scale, x, y + h * 0.48, z, PINE_MID, 8),
        cone(1.35 * scale, 2.9 * scale, x, y + h * 0.67, z, PINE_DARK, 8),
    ]
    yaw = float(rng.uniform(0.0, math.tau))
    for crown in crowns:
        crown.apply_transform(trimesh.transformations.rotation_matrix(yaw, [0, 1, 0], point=[x, y, z]))
    return t, crowns


def cypress_parts(x, z, y, scale):
    h = 8.5 * scale
    t = trunk(0.12 * scale, h * 0.45, x, y, z)
    crown = cone(1.25 * scale, 7.6 * scale, x, y + 1.4 * scale, z, CYPRESS, 9)
    return t, [crown]


def olive_parts(x, z, y, scale):
    t = trunk(0.18 * scale, 2.8 * scale, x, y, z)
    crown = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    crown.apply_scale((2.6 * scale, 1.55 * scale, 2.35 * scale))
    crown.apply_translation((x, y + 3.6 * scale, z))
    crown.visual = trimesh.visual.TextureVisuals(material=OLIVE)
    return t, [crown]


def shrub_mesh(x, z, y, scale):
    crown = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    crown.apply_scale((1.6 * scale, 0.75 * scale, 1.4 * scale))
    crown.apply_translation((x, y + 0.72 * scale, z))
    crown.visual = trimesh.visual.TextureVisuals(material=SCRUB)
    return crown


def sample_cluster(center, radius_x, radius_z, count, rng, output, min_h, max_h, mix="pine"):
    cx, cz = center
    attempts = 0
    while count > 0 and attempts < count * 16 + 900:
        attempts += 1
        angle = float(rng.uniform(0.0, math.tau))
        r = math.sqrt(float(rng.random()))
        x = cx + math.cos(angle) * radius_x * r
        z = cz + math.sin(angle) * radius_z * r
        lat, lon = local_to_lat_lon(x, z)
        if not (v12.SOUTH <= lat <= v12.NORTH and v12.WEST <= lon <= v12.EAST):
            continue
        y = height_at(x, z)
        if y < min_h or y > max_h:
            continue
        roll = float(rng.random())
        kind = mix
        if mix == "med":
            kind = "pine" if roll < 0.70 else ("cypress" if roll < 0.86 else "olive")
        elif mix == "urban":
            kind = "olive" if roll < 0.66 else "cypress"
        output.append((x, z, y, kind, float(rng.uniform(0.94, 1.72))))
        count -= 1


def build_ultra_nature():
    rng = np.random.default_rng(20092027)
    placements = []

    eceabat = v12.to_local(40.1841667, 26.3602778)
    kilitbahir = v12.to_local(40.14778, 26.37944)
    canakkale = v12.to_local(40.1505556, 26.4019444)

    # These are the areas the player stares at for most of a crossing. Density is intentionally
    # concentrated near the visible hills and waterfront rather than spread thinly over 80 km².
    sample_cluster(eceabat, 1450.0, 1250.0, 4200, rng, placements, 4.0, 185.0, "med")
    sample_cluster(kilitbahir, 1300.0, 1450.0, 2600, rng, placements, 5.0, 220.0, "med")
    sample_cluster(canakkale, 1450.0, 1250.0, 1500, rng, placements, 3.0, 105.0, "urban")
    sample_cluster((-3000.0, -2100.0), 2200.0, 2200.0, 2600, rng, placements, 8.0, 280.0, "med")

    trunks = []
    pine_crowns = []
    cypress_crowns = []
    olive_crowns = []
    for x, z, y, kind, scale in placements[:15000]:
        if kind == "cypress":
            t, crowns = cypress_parts(x, z, y, scale)
            cypress_crowns.extend(crowns)
        elif kind == "olive":
            t, crowns = olive_parts(x, z, y, scale)
            olive_crowns.extend(crowns)
        else:
            t, crowns = pine_parts(x, z, y, scale, rng)
            pine_crowns.extend(crowns)
        trunks.append(t)

    shrubs = []
    for _ in range(4200):
        x = float(rng.uniform(-5000.0, 3300.0))
        z = float(rng.uniform(-4000.0, 3400.0))
        y = height_at(x, z)
        if 4.0 <= y <= 220.0:
            shrubs.append(shrub_mesh(x, z, y, float(rng.uniform(0.72, 1.48))))

    scene = trimesh.Scene()
    groups = [
        (trunks, "V20_Ultra_Nature_Trunks", TRUNK),
        (pine_crowns, "V20_Ultra_Nature_Pines", PINE_DARK),
        (cypress_crowns, "V20_Ultra_Nature_Cypress", CYPRESS),
        (olive_crowns, "V20_Ultra_Nature_Olive", OLIVE),
        (shrubs, "V20_Ultra_Nature_Scrub", SCRUB),
    ]
    for meshes, name, material in groups:
        if not meshes:
            continue
        combined = trimesh.util.concatenate(meshes)
        combined.visual = trimesh.visual.TextureVisuals(material=material)
        scene.add_geometry(combined, node_name=name)
    print(f"ultra vegetation: trees={len(placements)}, shrubs={len(shrubs)}")
    return scene


def main():
    # IMPORTANT: generate_v20_world.py has already fetched OSM and written the dense city/roads/roof
    # geometry to this GLB. Load that exact output and add nature to it. Do NOT make a second
    # Overpass request: a transient timeout used to replace a good city with an empty world.
    if not os.path.exists(BASE_WORLD) or os.path.getsize(BASE_WORLD) < 1024 * 1024:
        raise RuntimeError(f"base remaster world missing: {BASE_WORLD}")

    print(f"v20 ultra world: preserving base OSM city from {BASE_WORLD}")
    loaded = trimesh.load(BASE_WORLD, force="scene", process=False)
    scene = loaded if isinstance(loaded, trimesh.Scene) else trimesh.Scene(loaded)
    base_geometry_count = len(scene.geometry)

    print("v20 ultra world: adding concentrated Mediterranean vegetation")
    nature = build_ultra_nature()
    for name, geom in nature.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)

    data = scene.export(file_type="glb")
    with open(BASE_WORLD, "wb") as stream:
        stream.write(data)
    with open(os.path.join(OUT, "WORLD_ATTRIBUTION.txt"), "w", encoding="utf-8") as stream:
        stream.write("Map data © OpenStreetMap contributors, ODbL. Terrain elevation from AWS Open Data / Mapzen Terrain Tiles. Dense vegetation and roof geometry are original procedural game assets.\n")
    print(f"generated {BASE_WORLD}: {len(data)/1024/1024:.2f} MB, preserved_geometry_groups={base_geometry_count}, final_geometry_groups={len(scene.geometry)}")


if __name__ == "__main__":
    main()
