import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from shapely.geometry import Point, Polygon

import generate_v12_world as v12
import generate_v14_world as v14
import generate_v20_world as v20

OUT = os.path.join("assets", "v20")
os.makedirs(OUT, exist_ok=True)


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


def forest_polygons(elements):
    polys = []
    for element in elements:
        tags = element.get("tags", {})
        if not (tags.get("natural") == "wood" or tags.get("landuse") == "forest"):
            continue
        pts = v12.geometry_points(element)
        if len(pts) < 4:
            continue
        coords = [v12.to_local(lat, lon) for lat, lon in pts]
        try:
            poly = Polygon(coords)
        except Exception:
            continue
        if poly.is_valid and 2500.0 <= poly.area <= 30_000_000.0:
            polys.append(poly)
    return polys


def sample_poly(poly, count, rng, output):
    minx, minz, maxx, maxz = poly.bounds
    attempts = 0
    while count > 0 and attempts < count * 18 + 300:
        attempts += 1
        x = float(rng.uniform(minx, maxx))
        z = float(rng.uniform(minz, maxz))
        if not poly.contains(Point(x, z)):
            continue
        y = height_at(x, z)
        if y < 3.0 or y > 300.0:
            continue
        output.append((x, z, y, "pine" if rng.random() < 0.86 else "cypress", float(rng.uniform(0.90, 1.65))))
        count -= 1


def sample_cluster(center, radius_x, radius_z, count, rng, output, min_h, max_h, mix="pine"):
    cx, cz = center
    attempts = 0
    while count > 0 and attempts < count * 14 + 500:
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
            kind = "pine" if roll < 0.74 else ("cypress" if roll < 0.88 else "olive")
        elif mix == "urban":
            kind = "olive" if roll < 0.68 else "cypress"
        output.append((x, z, y, kind, float(rng.uniform(0.88, 1.55))))
        count -= 1


def build_ultra_nature(elements):
    rng = np.random.default_rng(20092027)
    placements = []

    # First honour mapped forest/wood polygons so the green masses follow real OSM land use.
    polys = forest_polygons(elements)
    for poly in polys:
        target = int(max(20, min(420, poly.area / 1350.0)))
        sample_poly(poly, target, rng, placements)
        if len(placements) >= 5600:
            break

    eceabat = v12.to_local(40.1841667, 26.3602778)
    kilitbahir = v12.to_local(40.14778, 26.37944)
    canakkale = v12.to_local(40.1505556, 26.4019444)

    # The ferry route sees these slopes constantly. Make them visually dense at real tree scale.
    sample_cluster(eceabat, 1750.0, 1500.0, 3300, rng, placements, 5.0, 185.0, "med")
    sample_cluster(kilitbahir, 1500.0, 1700.0, 1800, rng, placements, 5.0, 220.0, "med")

    # Çanakkale is urban, but the waterfront and residential background must not look like a desert.
    sample_cluster(canakkale, 1750.0, 1450.0, 1150, rng, placements, 3.0, 105.0, "urban")

    # Wider Gallipoli backdrop for the long crossing views.
    sample_cluster((-3000.0, -2100.0), 2600.0, 2600.0, 2200, rng, placements, 8.0, 280.0, "med")

    trunks = []
    pine_crowns = []
    cypress_crowns = []
    olive_crowns = []
    for x, z, y, kind, scale in placements[:12500]:
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

    # Low scrub patches make distant hills read as vegetation even before individual tree silhouettes resolve.
    shrubs = []
    for _ in range(3200):
        x = float(rng.uniform(-5200.0, 3400.0))
        z = float(rng.uniform(-4300.0, 3600.0))
        y = height_at(x, z)
        if 4.0 <= y <= 220.0:
            shrubs.append(shrub_mesh(x, z, y, float(rng.uniform(0.65, 1.35))))

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
    print(f"ultra vegetation: placements={len(placements)}, shrubs={len(shrubs)}, forest_polygons={len(polys)}")
    return scene


def main():
    print("v20 ultra world: smooth real DEM")
    terrain = v14.build_smooth_terrain()
    scene = trimesh.Scene()
    scene.add_geometry(terrain, node_name="RealTerrainV20_Smoothed")

    print("v20 ultra world: OSM buildings, roofs and roads")
    elements = v12.overpass_elements()
    city = v20.build_dense_city(elements)
    for name, geom in city.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)

    print("v20 ultra world: dense Mediterranean vegetation")
    nature = build_ultra_nature(elements)
    for name, geom in nature.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)

    target = os.path.join(OUT, "canakkale_eceabat_remaster_v20.glb")
    data = scene.export(file_type="glb")
    with open(target, "wb") as stream:
        stream.write(data)
    with open(os.path.join(OUT, "WORLD_ATTRIBUTION.txt"), "w", encoding="utf-8") as stream:
        stream.write("Map data © OpenStreetMap contributors, ODbL. Terrain elevation from AWS Open Data / Mapzen Terrain Tiles. Dense vegetation and roof geometry are original procedural game assets.\n")
    print(f"generated {target}: {len(data)/1024/1024:.2f} MB, source_elements={len(elements)}")


if __name__ == "__main__":
    main()
