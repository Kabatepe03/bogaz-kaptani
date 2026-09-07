import io
import json
import math
import os
import re
import urllib.parse
import urllib.request

import numpy as np
from PIL import Image
import trimesh
from trimesh.visual.material import PBRMaterial

try:
    from shapely.geometry import Polygon
except Exception:
    Polygon = None

OUT = os.path.join("assets", "v12")
os.makedirs(OUT, exist_ok=True)

# Çanakkale - Eceabat gameplay window. Coordinates are WGS84.
SOUTH, WEST, NORTH, EAST = 40.125, 26.330, 40.215, 26.435
ORIGIN_LAT, ORIGIN_LON = 40.15112, 26.40200
ZOOM = 13
GRID_X = 128
GRID_Z = 144
UA = "BogazKaptani/12.0 real-world build (OpenStreetMap + AWS Terrain Tiles)"


def pbr(name, color, metallic=0.0, rough=0.7):
    rgba = tuple(int(max(0, min(1, c)) * 255) for c in color[:3]) + (255,)
    return PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)


MAT_BUILDINGS = [
    pbr("stone_plaster", (0.73, 0.69, 0.61), 0.02, 0.78),
    pbr("warm_plaster", (0.80, 0.71, 0.58), 0.02, 0.76),
    pbr("light_concrete", (0.69, 0.71, 0.70), 0.04, 0.82),
    pbr("white_plaster", (0.86, 0.85, 0.79), 0.01, 0.80),
]
MAT_ROAD = pbr("asphalt", (0.080, 0.085, 0.090), 0.05, 0.92)
MAT_MAIN_ROAD = pbr("main_asphalt", (0.095, 0.098, 0.102), 0.05, 0.89)
MAT_TREE = pbr("mediterranean_green", (0.075, 0.20, 0.070), 0.0, 0.94)
MAT_TRUNK = pbr("tree_trunk", (0.20, 0.12, 0.065), 0.0, 0.96)


def to_local(lat, lon):
    lat0 = math.radians(ORIGIN_LAT)
    x = (lon - ORIGIN_LON) * 111320.0 * math.cos(lat0)
    z = -(lat - ORIGIN_LAT) * 110540.0
    return x, z


def tile_xy(lat, lon, zoom=ZOOM):
    n = 2.0 ** zoom
    x = (lon + 180.0) / 360.0 * n
    lat_rad = math.radians(max(-85.05112878, min(85.05112878, lat)))
    y = (1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n
    return x, y


_tile_cache = {}


def terrain_tile(tx, ty):
    key = (int(tx), int(ty))
    if key in _tile_cache:
        return _tile_cache[key]
    url = f"https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{ZOOM}/{key[0]}/{key[1]}.png"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=20) as response:
            image = Image.open(io.BytesIO(response.read())).convert("RGB")
        arr = np.asarray(image, dtype=np.float32)
        elev = arr[:, :, 0] * 256.0 + arr[:, :, 1] + arr[:, :, 2] / 256.0 - 32768.0
        _tile_cache[key] = elev
    except Exception as exc:
        print(f"terrain tile fallback {key}: {exc}")
        _tile_cache[key] = None
    return _tile_cache[key]


def fallback_elevation(lat, lon):
    # Only used if an AWS terrain tile is temporarily unavailable.
    x, z = to_local(lat, lon)
    west_hills = max(0.0, (-x - 1200.0) / 2200.0) * 105.0
    east_hills = max(0.0, (x - 500.0) / 2500.0) * 48.0
    relief = 10.0 * math.sin(x * 0.0014) * math.cos(z * 0.0011)
    shore_guess = abs(x + 900.0 + z * 0.11)
    if shore_guess < 560.0:
        return -3.0
    return max(1.0, west_hills + east_hills + relief)


def elevation(lat, lon):
    xf, yf = tile_xy(lat, lon)
    tx, ty = int(math.floor(xf)), int(math.floor(yf))
    arr = terrain_tile(tx, ty)
    if arr is None:
        return fallback_elevation(lat, lon)
    px = (xf - tx) * 255.0
    py = (yf - ty) * 255.0
    x0, y0 = int(math.floor(px)), int(math.floor(py))
    x1, y1 = min(255, x0 + 1), min(255, y0 + 1)
    fx, fy = px - x0, py - y0
    e0 = arr[y0, x0] * (1.0 - fx) + arr[y0, x1] * fx
    e1 = arr[y1, x0] * (1.0 - fx) + arr[y1, x1] * fx
    return float(e0 * (1.0 - fy) + e1 * fy)


def build_terrain():
    vertices = []
    colors = []
    for iz in range(GRID_Z):
        lat = NORTH + (SOUTH - NORTH) * (iz / (GRID_Z - 1))
        for ix in range(GRID_X):
            lon = WEST + (EAST - WEST) * (ix / (GRID_X - 1))
            x, z = to_local(lat, lon)
            h = elevation(lat, lon)
            # Put open-water DEM points safely under the water shader surface.
            if h < 0.8:
                y = -4.5
                col = (35, 52, 49, 255)
            else:
                y = min(h, 330.0)
                if y < 18:
                    col = (128, 132, 92, 255)
                elif y < 65:
                    col = (91, 111, 69, 255)
                elif y < 145:
                    col = (72, 92, 57, 255)
                else:
                    col = (105, 101, 83, 255)
            vertices.append((x, y, z))
            colors.append(col)
    faces = []
    for iz in range(GRID_Z - 1):
        for ix in range(GRID_X - 1):
            a = iz * GRID_X + ix
            b = a + 1
            c = a + GRID_X
            d = c + 1
            faces.append((a, c, b))
            faces.append((b, c, d))
    mesh = trimesh.Trimesh(np.asarray(vertices), np.asarray(faces), process=False)
    mesh.visual = trimesh.visual.ColorVisuals(mesh=mesh, vertex_colors=np.asarray(colors, dtype=np.uint8))
    mesh.fix_normals()
    return mesh


def overpass_elements():
    query = f'''[out:json][timeout:60];(
      way["building"]({SOUTH},{WEST},{NORTH},{EAST});
      way["highway"~"primary|secondary|tertiary|residential|service|unclassified"]({SOUTH},{WEST},{NORTH},{EAST});
      way["natural"="wood"]({SOUTH},{WEST},{NORTH},{EAST});
      way["landuse"="forest"]({SOUTH},{WEST},{NORTH},{EAST});
    );out tags geom;'''
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")
    endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
    ]
    for endpoint in endpoints:
        try:
            req = urllib.request.Request(endpoint, data=data, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=75) as response:
                payload = json.loads(response.read().decode("utf-8"))
            print(f"OSM elements: {len(payload.get('elements', []))} from {endpoint}")
            return payload.get("elements", [])
        except Exception as exc:
            print(f"Overpass failed {endpoint}: {exc}")
    return []


def parse_height(tags):
    raw = str(tags.get("height", "")).replace(",", ".")
    match = re.search(r"[-+]?\d*\.?\d+", raw)
    if match:
        try:
            return max(2.8, min(38.0, float(match.group(0))))
        except ValueError:
            pass
    try:
        levels = float(str(tags.get("building:levels", "3")).replace(",", "."))
    except ValueError:
        levels = 3.0
    return max(3.2, min(30.0, levels * 3.05 + 0.6))


def geometry_points(element):
    points = []
    for p in element.get("geometry", []):
        if "lat" in p and "lon" in p:
            points.append((float(p["lat"]), float(p["lon"])))
    return points


def building_mesh(points, height):
    if len(points) < 3:
        return None
    coords = [to_local(lat, lon) for lat, lon in points]
    if coords[0] != coords[-1]:
        coords.append(coords[0])
    cx = sum(p[0] for p in coords[:-1]) / max(1, len(coords) - 1)
    cz = sum(p[1] for p in coords[:-1]) / max(1, len(coords) - 1)
    lat = sum(p[0] for p in points) / len(points)
    lon = sum(p[1] for p in points) / len(points)
    ground = max(0.3, elevation(lat, lon))
    if Polygon is not None:
        try:
            poly = Polygon(coords)
            if poly.is_valid and poly.area > 14.0 and poly.area < 12000.0:
                mesh = trimesh.creation.extrude_polygon(poly, height=height, engine="earcut")
                # trimesh extrusion is Z-up; Godot is Y-up.
                verts = mesh.vertices.copy()
                mesh.vertices = np.column_stack([verts[:, 0], verts[:, 2] + ground, verts[:, 1]])
                mesh.fix_normals()
                return mesh
        except Exception:
            pass
    xs = [p[0] for p in coords[:-1]]
    zs = [p[1] for p in coords[:-1]]
    if not xs:
        return None
    sx, sz = max(xs) - min(xs), max(zs) - min(zs)
    if sx < 2.0 or sz < 2.0 or sx * sz > 14000.0:
        return None
    mesh = trimesh.creation.box(extents=(sx, height, sz))
    mesh.apply_translation((cx, ground + height * 0.5, cz))
    return mesh


def road_segment(a, b, width):
    x0, z0 = to_local(*a)
    x1, z1 = to_local(*b)
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz)
    if length < 3.0 or length > 450.0:
        return None
    lat = (a[0] + b[0]) * 0.5
    lon = (a[1] + b[1]) * 0.5
    ground = max(0.2, elevation(lat, lon)) + 0.18
    mesh = trimesh.creation.box(extents=(width, 0.16, length))
    angle = math.atan2(dx, dz)
    mesh.apply_transform(trimesh.transformations.rotation_matrix(angle, [0, 1, 0]))
    mesh.apply_translation(((x0 + x1) * 0.5, ground, (z0 + z1) * 0.5))
    return mesh


def make_tree(x, z, y, scale=1.0):
    trunk = trimesh.creation.cylinder(radius=0.20 * scale, height=3.0 * scale, sections=7)
    trunk.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    trunk.apply_translation((x, y + 1.5 * scale, z))
    crown = trimesh.creation.icosphere(subdivisions=1, radius=2.0 * scale)
    crown.apply_scale((0.85, 1.25, 0.85))
    crown.apply_translation((x, y + 4.2 * scale, z))
    return trunk, crown


def build_osm_scene(elements):
    building_groups = [[] for _ in range(len(MAT_BUILDINGS))]
    road_minor, road_main = [], []
    forest_polys = []

    buildings = [e for e in elements if "building" in e.get("tags", {})]
    # Keep the largest/most useful footprint set for mobile draw and memory cost.
    candidates = []
    for e in buildings:
        pts = geometry_points(e)
        if len(pts) < 3:
            continue
        xs = [to_local(*p)[0] for p in pts]
        zs = [to_local(*p)[1] for p in pts]
        area_hint = max(0.0, (max(xs) - min(xs)) * (max(zs) - min(zs)))
        candidates.append((area_hint, e, pts))
    candidates.sort(key=lambda item: item[0], reverse=True)
    for idx, (_, e, pts) in enumerate(candidates[:950]):
        mesh = building_mesh(pts, parse_height(e.get("tags", {})))
        if mesh is not None:
            building_groups[idx % len(building_groups)].append(mesh)

    for e in elements:
        tags = e.get("tags", {})
        pts = geometry_points(e)
        highway = tags.get("highway")
        if highway and len(pts) >= 2:
            main = highway in ("primary", "secondary", "tertiary")
            width = 7.2 if main else (5.2 if highway in ("residential", "unclassified") else 3.8)
            target = road_main if main else road_minor
            for a, b in zip(pts[:-1], pts[1:]):
                if len(target) >= (850 if main else 1400):
                    break
                segment = road_segment(a, b, width)
                if segment is not None:
                    target.append(segment)
        if (tags.get("natural") == "wood" or tags.get("landuse") == "forest") and len(pts) >= 4:
            forest_polys.append(pts)

    scene = trimesh.Scene()
    for index, group in enumerate(building_groups):
        if group:
            mesh = trimesh.util.concatenate(group)
            mesh.visual = trimesh.visual.TextureVisuals(material=MAT_BUILDINGS[index])
            scene.add_geometry(mesh, node_name=f"OSM_Buildings_{index}")
    if road_minor:
        mesh = trimesh.util.concatenate(road_minor)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_ROAD)
        scene.add_geometry(mesh, node_name="OSM_Roads")
    if road_main:
        mesh = trimesh.util.concatenate(road_main)
        mesh.visual = trimesh.visual.TextureVisuals(material=MAT_MAIN_ROAD)
        scene.add_geometry(mesh, node_name="OSM_MainRoads")

    rng = np.random.default_rng(12026)
    trunks, crowns = [], []
    for pts in forest_polys[:80]:
        xs = [to_local(*p)[0] for p in pts]
        zs = [to_local(*p)[1] for p in pts]
        if not xs:
            continue
        minx, maxx, minz, maxz = min(xs), max(xs), min(zs), max(zs)
        for _ in range(min(18, max(3, int((maxx-minx)*(maxz-minz) / 60000.0)))):
            x = float(rng.uniform(minx, maxx))
            z = float(rng.uniform(minz, maxz))
            # Convert local point back approximately for elevation lookup.
            lat = ORIGIN_LAT - z / 110540.0
            lon = ORIGIN_LON + x / (111320.0 * math.cos(math.radians(ORIGIN_LAT)))
            y = max(0.5, elevation(lat, lon))
            trunk, crown = make_tree(x, z, y, float(rng.uniform(0.75, 1.30)))
            trunks.append(trunk)
            crowns.append(crown)
            if len(crowns) >= 520:
                break
        if len(crowns) >= 520:
            break
    if trunks:
        tm = trimesh.util.concatenate(trunks)
        tm.visual = trimesh.visual.TextureVisuals(material=MAT_TRUNK)
        scene.add_geometry(tm, node_name="OSM_Forest_Trunks")
    if crowns:
        cm = trimesh.util.concatenate(crowns)
        cm.visual = trimesh.visual.TextureVisuals(material=MAT_TREE)
        scene.add_geometry(cm, node_name="OSM_Forest_Canopies")
    return scene


def main():
    terrain = build_terrain()
    scene = trimesh.Scene()
    scene.add_geometry(terrain, node_name="RealTerrainV12")
    osm = build_osm_scene(overpass_elements())
    for name, geom in osm.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)
    target = os.path.join(OUT, "canakkale_real_world_v12.glb")
    data = scene.export(file_type="glb")
    with open(target, "wb") as stream:
        stream.write(data)
    with open(os.path.join(OUT, "ATTRIBUTION.txt"), "w", encoding="utf-8") as stream:
        stream.write("Map data © OpenStreetMap contributors, ODbL. Terrain Tiles accessed from AWS Open Data / Mapzen Terrain Tiles.\n")
    print(f"generated {target}: {len(data)} bytes; tiles={len(_tile_cache)}")


if __name__ == "__main__":
    main()
