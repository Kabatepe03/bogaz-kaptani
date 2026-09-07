import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

import generate_v12_world as v12
import generate_v14_world as v14

OUT = os.path.join("assets", "v20")
os.makedirs(OUT, exist_ok=True)

MAT_WALLS = [
    v12.pbr("v20_plaster_warm", (0.77, 0.71, 0.62), 0.01, 0.82),
    v12.pbr("v20_plaster_light", (0.84, 0.82, 0.74), 0.01, 0.80),
    v12.pbr("v20_concrete", (0.66, 0.67, 0.64), 0.02, 0.86),
    v12.pbr("v20_whitewash", (0.90, 0.88, 0.82), 0.01, 0.79),
    v12.pbr("v20_muted_ochre", (0.70, 0.62, 0.49), 0.01, 0.84),
    v12.pbr("v20_pale_blue", (0.67, 0.73, 0.73), 0.01, 0.81),
]
MAT_ROOFS = [
    v12.pbr("v20_roof_terracotta", (0.45, 0.17, 0.085), 0.01, 0.91),
    v12.pbr("v20_roof_weathered", (0.31, 0.22, 0.17), 0.02, 0.92),
    v12.pbr("v20_roof_grey", (0.27, 0.28, 0.27), 0.03, 0.90),
]
MAT_ROAD = v12.pbr("v20_city_asphalt", (0.075, 0.078, 0.082), 0.02, 0.94)
MAT_MAIN_ROAD = v12.pbr("v20_main_asphalt", (0.088, 0.090, 0.094), 0.02, 0.91)
MAT_TRUNK = v12.pbr("v20_tree_trunk", (0.18, 0.11, 0.055), 0.0, 0.97)
MAT_PINE = v12.pbr("v20_pine", (0.055, 0.145, 0.055), 0.0, 0.95)
MAT_CYPRESS = v12.pbr("v20_cypress", (0.035, 0.115, 0.045), 0.0, 0.96)
MAT_SHRUB = v12.pbr("v20_scrub", (0.19, 0.25, 0.105), 0.0, 0.97)


def local_to_lat_lon(x: float, z: float):
    lat = v12.ORIGIN_LAT - z / 110540.0
    lon = v12.ORIGIN_LON + x / (111320.0 * math.cos(math.radians(v12.ORIGIN_LAT)))
    return lat, lon


def building_stats(points):
    coords = [v12.to_local(lat, lon) for lat, lon in points]
    if len(coords) < 3:
        return None
    xs = [p[0] for p in coords]
    zs = [p[1] for p in coords]
    sx = max(xs) - min(xs)
    sz = max(zs) - min(zs)
    if sx < 2.2 or sz < 2.2 or sx * sz > 16000.0:
        return None
    cx = (min(xs) + max(xs)) * 0.5
    cz = (min(zs) + max(zs)) * 0.5
    lat, lon = local_to_lat_lon(cx, cz)
    ground = max(0.25, v12.elevation(lat, lon))
    return cx, cz, sx, sz, ground


def gable_roof(points, height: float):
    stats = building_stats(points)
    if stats is None:
        return None
    cx, cz, sx, sz, ground = stats
    eave_y = ground + height + 0.04
    roof_h = max(0.65, min(2.8, min(sx, sz) * 0.20))
    ex = sx * 0.54
    ez = sz * 0.54

    if sx >= sz:
        verts = np.array([
            [cx-ex, eave_y, cz-ez], [cx+ex, eave_y, cz-ez],
            [cx-ex, eave_y, cz+ez], [cx+ex, eave_y, cz+ez],
            [cx-ex, eave_y+roof_h, cz], [cx+ex, eave_y+roof_h, cz],
        ], dtype=np.float64)
        faces = np.array([
            [0,1,5], [0,5,4], [2,4,5], [2,5,3],
            [0,4,2], [1,3,5],
        ], dtype=np.int64)
    else:
        verts = np.array([
            [cx-ex, eave_y, cz-ez], [cx+ex, eave_y, cz-ez],
            [cx-ex, eave_y, cz+ez], [cx+ex, eave_y, cz+ez],
            [cx, eave_y+roof_h, cz-ez], [cx, eave_y+roof_h, cz+ez],
        ], dtype=np.float64)
        faces = np.array([
            [0,4,5], [0,5,2], [1,3,5], [1,5,4],
            [0,1,4], [2,5,3],
        ], dtype=np.int64)
    mesh = trimesh.Trimesh(verts, faces, process=True, validate=True)
    mesh.fix_normals()
    return mesh


def flat_roof(points, height: float):
    stats = building_stats(points)
    if stats is None:
        return None
    cx, cz, sx, sz, ground = stats
    roof = trimesh.creation.box(extents=(sx * 1.03, 0.22, sz * 1.03))
    roof.apply_translation((cx, ground + height + 0.11, cz))
    return roof


def make_pine(x: float, z: float, y: float, scale: float):
    trunk = trimesh.creation.cylinder(radius=0.18*scale, height=3.2*scale, sections=7)
    trunk.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2.0, [1,0,0]))
    trunk.apply_translation((x, y + 1.6*scale, z))
    crown = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    crown.apply_scale((2.5*scale, 1.55*scale, 2.5*scale))
    crown.apply_translation((x, y + 4.2*scale, z))
    return trunk, crown


def make_cypress(x: float, z: float, y: float, scale: float):
    trunk = trimesh.creation.cylinder(radius=0.13*scale, height=3.0*scale, sections=6)
    trunk.apply_transform(trimesh.transformations.rotation_matrix(math.pi/2.0, [1,0,0]))
    trunk.apply_translation((x, y + 1.5*scale, z))
    crown = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    crown.apply_scale((0.82*scale, 3.0*scale, 0.82*scale))
    crown.apply_translation((x, y + 4.5*scale, z))
    return trunk, crown


def make_shrub(x: float, z: float, y: float, scale: float):
    crown = trimesh.creation.icosphere(subdivisions=1, radius=1.0)
    crown.apply_scale((1.25*scale, 0.72*scale, 1.12*scale))
    crown.apply_translation((x, y + 0.72*scale, z))
    return crown


def build_dense_city(elements):
    scene = trimesh.Scene()
    wall_groups = [[] for _ in MAT_WALLS]
    roof_groups = [[] for _ in MAT_ROOFS]
    road_main = []
    road_minor = []

    buildings = [e for e in elements if "building" in e.get("tags", {})]
    candidates = []
    for e in buildings:
        pts = v12.geometry_points(e)
        stats = building_stats(pts)
        if stats is None:
            continue
        _, _, sx, sz, _ = stats
        area_hint = sx * sz
        candidates.append((area_hint, e, pts))
    candidates.sort(key=lambda item: item[0], reverse=True)

    # Much denser than the previous 950-building mobile prototype. Merging keeps draw calls low.
    for idx, (_, element, pts) in enumerate(candidates[:2400]):
        tags = element.get("tags", {})
        height = v12.parse_height(tags)
        wall = v12.building_mesh(pts, height)
        if wall is None:
            continue
        wall_groups[idx % len(wall_groups)].append(wall)

        roof = None
        # Eceabat/Gallipoli gets more pitched terracotta roofs; denser Çanakkale core mixes flat roofs.
        stats = building_stats(pts)
        if stats is not None:
            cx = stats[0]
            pitched_bias = 0.78 if cx < -1200.0 else 0.48
            selector = ((idx * 37) % 100) / 100.0
            roof = gable_roof(pts, height) if selector < pitched_bias else flat_roof(pts, height)
        if roof is not None:
            roof_groups[idx % len(roof_groups)].append(roof)

    for element in elements:
        tags = element.get("tags", {})
        highway = tags.get("highway")
        pts = v12.geometry_points(element)
        if highway and len(pts) >= 2:
            main = highway in ("primary", "secondary", "tertiary")
            width = 7.4 if main else (5.4 if highway in ("residential", "unclassified") else 4.0)
            target = road_main if main else road_minor
            limit = 1500 if main else 3200
            for a, b in zip(pts[:-1], pts[1:]):
                if len(target) >= limit:
                    break
                segment = v12.road_segment(a, b, width)
                if segment is not None:
                    target.append(segment)

    for idx, group in enumerate(wall_groups):
        if group:
            mesh = trimesh.util.concatenate(group)
            mesh.visual = trimesh.visual.TextureVisuals(material=MAT_WALLS[idx])
            scene.add_geometry(mesh, node_name=f"OSM_Buildings_{idx}")
    for idx, group in enumerate(roof_groups):
        if group:
            mesh = trimesh.util.concatenate(group)
            mesh.visual = trimesh.visual.TextureVisuals(material=MAT_ROOFS[idx])
            scene.add_geometry(mesh, node_name=f"V20_Roofs_{idx}")
    if road_minor:
        mesh = trimesh.util.concatenate(road_minor)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_ROAD)
        scene.add_geometry(mesh, node_name="OSM_Roads")
    if road_main:
        mesh = trimesh.util.concatenate(road_main)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_MAIN_ROAD)
        scene.add_geometry(mesh, node_name="OSM_MainRoads")
    return scene


def build_nature():
    rng = np.random.default_rng(20092026)
    trunks = []
    pine = []
    cypress = []
    shrubs = []

    # Gallipoli peninsula: dense Mediterranean vegetation on the recognisable hillside.
    attempts = 0
    while len(pine) + len(cypress) < 2300 and attempts < 9000:
        attempts += 1
        x = float(rng.uniform(-5200.0, -950.0))
        z = float(rng.uniform(-4300.0, 3900.0))
        lat, lon = local_to_lat_lon(x, z)
        if not (v12.SOUTH <= lat <= v12.NORTH and v12.WEST <= lon <= v12.EAST):
            continue
        y = float(v12.elevation(lat, lon))
        if y < 8.0 or y > 310.0:
            continue
        scale = float(rng.uniform(0.72, 1.38))
        if rng.random() < 0.78:
            trunk, crown = make_pine(x, z, y, scale)
            trunks.append(trunk)
            pine.append(crown)
        else:
            trunk, crown = make_cypress(x, z, y, scale)
            trunks.append(trunk)
            cypress.append(crown)

    # Çanakkale side: lower-density urban/peri-urban green to keep the city readable.
    attempts = 0
    while len(shrubs) < 900 and attempts < 5000:
        attempts += 1
        x = float(rng.uniform(350.0, 3600.0))
        z = float(rng.uniform(-3800.0, 3600.0))
        lat, lon = local_to_lat_lon(x, z)
        if not (v12.SOUTH <= lat <= v12.NORTH and v12.WEST <= lon <= v12.EAST):
            continue
        y = float(v12.elevation(lat, lon))
        if y < 4.0 or y > 180.0:
            continue
        shrubs.append(make_shrub(x, z, y, float(rng.uniform(0.65, 1.35))))

    scene = trimesh.Scene()
    if trunks:
        mesh = trimesh.util.concatenate(trunks)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_TRUNK)
        scene.add_geometry(mesh, node_name="V20_Nature_Trunks")
    if pine:
        mesh = trimesh.util.concatenate(pine)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_PINE)
        scene.add_geometry(mesh, node_name="V20_Nature_Pines")
    if cypress:
        mesh = trimesh.util.concatenate(cypress)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_CYPRESS)
        scene.add_geometry(mesh, node_name="V20_Nature_Cypress")
    if shrubs:
        mesh = trimesh.util.concatenate(shrubs)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_SHRUB)
        scene.add_geometry(mesh, node_name="V20_Nature_Scrub")
    return scene


def main():
    print("v20 world: sampling smooth real DEM...")
    terrain = v14.build_smooth_terrain()
    scene = trimesh.Scene()
    scene.add_geometry(terrain, node_name="RealTerrainV20_Smoothed")

    print("v20 world: downloading dense OSM geometry...")
    elements = v12.overpass_elements()
    city = build_dense_city(elements)
    for name, geom in city.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)

    print("v20 world: building Mediterranean nature pass...")
    nature = build_nature()
    for name, geom in nature.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)

    target = os.path.join(OUT, "canakkale_eceabat_remaster_v20.glb")
    data = scene.export(file_type="glb")
    with open(target, "wb") as stream:
        stream.write(data)
    with open(os.path.join(OUT, "WORLD_ATTRIBUTION.txt"), "w", encoding="utf-8") as stream:
        stream.write("Map data © OpenStreetMap contributors, ODbL. Terrain elevation from AWS Open Data / Mapzen Terrain Tiles. V20 procedural roofs and vegetation are original game geometry.\n")
    print(f"generated {target}: {len(data)/1024/1024:.2f} MB, source_elements={len(elements)}")


if __name__ == "__main__":
    main()
