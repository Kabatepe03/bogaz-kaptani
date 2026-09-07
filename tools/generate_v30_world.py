import json
import math
import os
from pathlib import Path

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

import generate_v12_world as v12

try:
    from shapely.geometry import Point, Polygon
except Exception:
    Point = None
    Polygon = None

WORLD = Path("assets/v20/canakkale_eceabat_remaster_v20.glb")
OUT = Path("assets/v30")
OUT.mkdir(parents=True, exist_ok=True)


def pbr(name, rgb, metallic=0.0, rough=0.8, emissive=None):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    mat = PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)
    if emissive is not None:
        mat.emissiveFactor = tuple(float(v) for v in emissive)
    return mat


WINDOWS = [
    pbr("v30_window_cool", (0.025, 0.060, 0.075), 0.12, 0.14),
    pbr("v30_window_blue", (0.035, 0.090, 0.120), 0.10, 0.16),
    pbr("v30_window_warm", (0.15, 0.11, 0.075), 0.05, 0.24, emissive=(0.12, 0.07, 0.025)),
]
BALCONY = pbr("v30_balcony_concrete", (0.64, 0.63, 0.58), 0.02, 0.88)
RAIL = pbr("v30_balcony_rail", (0.22, 0.24, 0.24), 0.72, 0.40)
SHOP = pbr("v30_storefront_glass", (0.018, 0.045, 0.060), 0.16, 0.10)
MARK_WHITE = pbr("v30_road_marking_white", (0.88, 0.87, 0.80), 0.0, 0.72)
MARK_YELLOW = pbr("v30_road_marking_yellow", (0.90, 0.67, 0.08), 0.0, 0.72)
CURB = pbr("v30_curb_concrete", (0.61, 0.61, 0.58), 0.0, 0.92)
SIDEWALK = pbr("v30_sidewalk", (0.39, 0.39, 0.37), 0.0, 0.94)
POLE = pbr("v30_streetlight_pole", (0.12, 0.13, 0.13), 0.76, 0.38)
LAMP = pbr("v30_streetlight_lamp", (0.95, 0.83, 0.55), 0.0, 0.18, emissive=(0.65, 0.42, 0.17))
QUAY = pbr("v30_quay_edge", (0.37, 0.37, 0.35), 0.03, 0.92)
FENDER = pbr("v30_quay_fender", (0.015, 0.018, 0.020), 0.0, 0.98)
ROCK = pbr("v30_shore_rock", (0.31, 0.29, 0.24), 0.0, 0.98)


def apply(mesh, mat):
    mesh.visual = trimesh.visual.TextureVisuals(material=mat)
    return mesh


def box(extents, center, mat, yaw=0.0):
    mesh = trimesh.creation.box(extents=extents)
    if abs(yaw) > 1e-8:
        mesh.apply_transform(trimesh.transformations.rotation_matrix(yaw, [0, 1, 0]))
    mesh.apply_translation(center)
    return apply(mesh, mat)


def cylinder(radius, height, center, mat, sections=12):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    mesh.apply_translation(center)
    return apply(mesh, mat)


def sphere(scale, center, mat, subdivisions=1):
    mesh = trimesh.creation.icosphere(subdivisions=subdivisions, radius=1.0)
    mesh.apply_scale(scale)
    mesh.apply_translation(center)
    return apply(mesh, mat)


def local_coords(points):
    return [v12.to_local(float(lat), float(lon)) for lat, lon in points]


def poly_signed_area(coords):
    if len(coords) < 3:
        return 0.0
    total = 0.0
    for a, b in zip(coords, coords[1:] + coords[:1]):
        total += a[0] * b[1] - b[0] * a[1]
    return total * 0.5


def facade_yaw(dx, dz):
    # Thin local-Z box, local-X follows the façade segment.
    return math.atan2(-dz, dx)


def segment_ground(a_ll, b_ll):
    lat = (a_ll[0] + b_ll[0]) * 0.5
    lon = (a_ll[1] + b_ll[1]) * 0.5
    return max(0.20, float(v12.elevation(lat, lon)))


def build_facades(elements):
    windows = [[] for _ in WINDOWS]
    balconies = []
    rails = []
    shops = []
    selected = []

    canakkale = v12.to_local(40.1508, 26.4020)
    eceabat = v12.to_local(40.1842, 26.3603)

    for element in elements:
        tags = element.get("tags", {})
        if "building" not in tags:
            continue
        pts = v12.geometry_points(element)
        if len(pts) < 3:
            continue
        coords = local_coords(pts)
        if coords[0] == coords[-1]:
            coords = coords[:-1]
            pts = pts[:-1]
        if len(coords) < 3:
            continue
        xs = [p[0] for p in coords]
        zs = [p[1] for p in coords]
        area = max(0.0, (max(xs) - min(xs)) * (max(zs) - min(zs)))
        if area < 28.0 or area > 9000.0:
            continue
        cx = sum(xs) / len(xs)
        cz = sum(zs) / len(zs)
        city_distance = min(math.hypot(cx - canakkale[0], cz - canakkale[1]), math.hypot(cx - eceabat[0], cz - eceabat[1]))
        score = city_distance - min(area, 1000.0) * 0.18
        selected.append((score, area, element, pts, coords, cx, cz))

    selected.sort(key=lambda item: item[0])
    selected = selected[:920]

    facade_count = 0
    window_count = 0
    balcony_count = 0
    storefront_count = 0

    for bidx, (_, area, element, pts, coords, cx, cz) in enumerate(selected):
        tags = element.get("tags", {})
        height = float(v12.parse_height(tags))
        floors = max(1, min(8, int(round(max(3.0, height - 0.7) / 3.05))))
        orientation_ccw = poly_signed_area(coords) > 0.0
        seg_records = []
        for i in range(len(coords)):
            a = coords[i]
            b = coords[(i + 1) % len(coords)]
            dx = b[0] - a[0]
            dz = b[1] - a[1]
            length = math.hypot(dx, dz)
            if length < 3.7 or length > 85.0:
                continue
            ux, uz = dx / length, dz / length
            # For CCW rings, right-hand normal points outside; reverse for CW.
            nx, nz = (uz, -ux) if orientation_ccw else (-uz, ux)
            seg_records.append((length, i, ux, uz, nx, nz))

        seg_records.sort(reverse=True, key=lambda r: r[0])
        for sidx, (length, i, ux, uz, nx, nz) in enumerate(seg_records[:7]):
            a = coords[i]
            b = coords[(i + 1) % len(coords)]
            a_ll = pts[i]
            b_ll = pts[(i + 1) % len(pts)]
            ground = segment_ground(a_ll, b_ll)
            mx = (a[0] + b[0]) * 0.5
            mz = (a[1] + b[1]) * 0.5
            yaw = facade_yaw(ux, uz)
            count = max(1, min(7, int(length / 3.0)))
            usable = min(length * 0.82, count * 2.55)
            for floor in range(floors):
                # Ground floor is less repetitive in dense waterfront streets.
                if floor == 0 and (bidx + sidx) % 3 == 0:
                    continue
                for w in range(count):
                    along = 0.0 if count == 1 else (-usable * 0.5 + usable * float(w) / float(count - 1))
                    wx = mx + ux * along + nx * 0.075
                    wz = mz + uz * along + nz * 0.075
                    wy = ground + 1.75 + floor * 3.05
                    width = min(1.38, max(0.82, length / max(count, 1) * 0.46))
                    window = box((width, 1.18, 0.075), (wx, wy, wz), WINDOWS[(bidx + floor + w) % len(WINDOWS)], yaw)
                    windows[(bidx + floor + w) % len(WINDOWS)].append(window)
                    window_count += 1
            facade_count += 1

        # Balconies go on the longest façade only, preventing floating/intersecting slab spam.
        if seg_records and bidx % 4 == 0 and floors >= 2:
            length, i, ux, uz, nx, nz = seg_records[0]
            a = coords[i]
            b = coords[(i + 1) % len(coords)]
            ground = segment_ground(pts[i], pts[(i + 1) % len(pts)])
            mx = (a[0] + b[0]) * 0.5
            mz = (a[1] + b[1]) * 0.5
            yaw = facade_yaw(ux, uz)
            balcony_width = min(6.4, max(2.4, length * 0.58))
            for floor in range(1, min(floors, 4)):
                by = ground + floor * 3.05 + 0.34
                balconies.append(box((balcony_width, 0.13, 0.92), (mx + nx * 0.48, by, mz + nz * 0.48), BALCONY, yaw))
                rails.append(box((balcony_width, 0.62, 0.055), (mx + nx * 0.94, by + 0.38, mz + nz * 0.94), RAIL, yaw))
                balcony_count += 1

        # Realistic shop-front glazing close to either town centre.
        city_d = min(math.hypot(cx - canakkale[0], cz - canakkale[1]), math.hypot(cx - eceabat[0], cz - eceabat[1]))
        if seg_records and city_d < 900.0 and bidx % 3 == 0:
            length, i, ux, uz, nx, nz = seg_records[0]
            if length >= 5.0:
                a = coords[i]
                b = coords[(i + 1) % len(coords)]
                ground = segment_ground(pts[i], pts[(i + 1) % len(pts)])
                mx = (a[0] + b[0]) * 0.5
                mz = (a[1] + b[1]) * 0.5
                yaw = facade_yaw(ux, uz)
                shops.append(box((min(6.5, length * 0.58), 2.20, 0.085), (mx + nx * 0.085, ground + 1.25, mz + nz * 0.085), SHOP, yaw))
                storefront_count += 1

    scene = trimesh.Scene()
    groups = [
        (windows[0], "V30_FacadeWindows_Cool", WINDOWS[0]),
        (windows[1], "V30_FacadeWindows_Blue", WINDOWS[1]),
        (windows[2], "V30_FacadeWindows_Warm", WINDOWS[2]),
        (balconies, "V30_Balconies", BALCONY),
        (rails, "V30_BalconyRails", RAIL),
        (shops, "V30_Storefronts", SHOP),
    ]
    for meshes, name, mat in groups:
        if not meshes:
            continue
        merged = trimesh.util.concatenate(meshes)
        merged.visual = trimesh.visual.TextureVisuals(material=mat)
        scene.add_geometry(merged, node_name=name, geom_name=name)
    print("v30 facades:", "buildings", len(selected), "facades", facade_count, "windows", window_count, "balconies", balcony_count, "shops", storefront_count)
    return scene, {"buildings": len(selected), "windows": window_count, "balconies": balcony_count, "shops": storefront_count}


def road_segment_record(a_ll, b_ll, width):
    x0, z0 = v12.to_local(*a_ll)
    x1, z1 = v12.to_local(*b_ll)
    dx, dz = x1 - x0, z1 - z0
    length = math.hypot(dx, dz)
    if length < 5.5 or length > 430.0:
        return None
    ux, uz = dx / length, dz / length
    nx, nz = -uz, ux
    ground = segment_ground(a_ll, b_ll) + 0.24
    return x0, z0, x1, z1, ux, uz, nx, nz, length, ground, width


def build_roads_waterfront(elements):
    markings = []
    edge_lines = []
    sidewalks = []
    curbs = []
    poles = []
    lamps = []
    quay_edges = []
    fenders = []
    rocks = []
    road_segments = 0
    light_count = 0
    quay_count = 0
    rock_count = 0

    for element in elements:
        tags = element.get("tags", {})
        pts = v12.geometry_points(element)
        highway = tags.get("highway")
        if highway and len(pts) >= 2:
            main = highway in ("primary", "secondary", "tertiary")
            width = 7.6 if main else (5.5 if highway in ("residential", "unclassified") else 4.0)
            for a_ll, b_ll in zip(pts[:-1], pts[1:]):
                rec = road_segment_record(a_ll, b_ll, width)
                if rec is None:
                    continue
                x0, z0, x1, z1, ux, uz, nx, nz, length, ground, road_width = rec
                mx, mz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
                yaw_z = math.atan2(ux, uz)
                road_segments += 1

                if main or highway in ("residential", "unclassified"):
                    dash_len = 3.6 if main else 2.7
                    gap = 3.0 if main else 4.2
                    count = max(1, int(length / (dash_len + gap)))
                    for d in range(count):
                        along = -length * 0.5 + (d + 0.5) * length / count
                        px, pz = mx + ux * along, mz + uz * along
                        markings.append(box((0.13, 0.025, min(dash_len, length / count * 0.58)), (px, ground + 0.025, pz), MARK_WHITE, yaw_z))

                if main and length > 14.0:
                    for side in (-1.0, 1.0):
                        off = side * (road_width * 0.5 - 0.48)
                        edge_lines.append(box((0.10, 0.023, length * 0.95), (mx + nx * off, ground + 0.024, mz + nz * off), MARK_WHITE, yaw_z))

                if road_width >= 5.2 and length > 9.0:
                    for side in (-1.0, 1.0):
                        soff = side * (road_width * 0.5 + 1.08)
                        coff = side * (road_width * 0.5 + 0.16)
                        sidewalks.append(box((1.55, 0.11, length * 0.96), (mx + nx * soff, ground + 0.045, mz + nz * soff), SIDEWALK, yaw_z))
                        curbs.append(box((0.17, 0.15, length * 0.97), (mx + nx * coff, ground + 0.070, mz + nz * coff), CURB, yaw_z))

                if main and light_count < 430 and length >= 24.0:
                    step = 34.0
                    count_l = max(1, int(length / step))
                    for li in range(count_l):
                        if light_count >= 430:
                            break
                        along = -length * 0.5 + (li + 0.5) * length / count_l
                        side = -1.0 if (road_segments + li) % 2 == 0 else 1.0
                        off = side * (road_width * 0.5 + 2.05)
                        px, pz = mx + ux * along + nx * off, mz + uz * along + nz * off
                        poles.append(cylinder(0.075, 6.5, (px, ground + 3.25, pz), POLE, 10))
                        lamps.append(sphere((0.24, 0.16, 0.36), (px, ground + 6.46, pz), LAMP, 1))
                        light_count += 1

        if tags.get("man_made") == "quay" and len(pts) >= 2:
            for a_ll, b_ll in zip(pts[:-1], pts[1:]):
                rec = road_segment_record(a_ll, b_ll, 2.0)
                if rec is None:
                    continue
                x0, z0, x1, z1, ux, uz, nx, nz, length, ground, _ = rec
                mx, mz = (x0 + x1) * 0.5, (z0 + z1) * 0.5
                yaw_z = math.atan2(ux, uz)
                quay_edges.append(box((2.2, 0.30, length), (mx, max(0.42, ground - 0.05), mz), QUAY, yaw_z))
                count_f = max(1, int(length / 18.0))
                for fi in range(count_f):
                    if quay_count >= 190:
                        break
                    along = -length * 0.5 + (fi + 0.5) * length / count_f
                    px, pz = mx + ux * along, mz + uz * along
                    fenders.append(cylinder(0.28, 2.1, (px, 0.85, pz), FENDER, 14))
                    quay_count += 1

        if tags.get("natural") == "coastline" and len(pts) >= 2:
            for a_ll, b_ll in zip(pts[:-1], pts[1:]):
                if rock_count >= 760:
                    break
                x0, z0 = v12.to_local(*a_ll)
                x1, z1 = v12.to_local(*b_ll)
                dx, dz = x1 - x0, z1 - z0
                length = math.hypot(dx, dz)
                if length < 8.0:
                    continue
                count_r = min(12, max(1, int(length / 20.0)))
                for ri in range(count_r):
                    if rock_count >= 760:
                        break
                    t = (ri + 0.35) / count_r
                    px = x0 + dx * t
                    pz = z0 + dz * t
                    scale = 0.45 + ((rock_count * 37) % 100) / 100.0 * 0.75
                    rocks.append(sphere((1.45 * scale, 0.72 * scale, 1.15 * scale), (px, 0.18 + 0.20 * scale, pz), ROCK, 1))
                    rock_count += 1

    scene = trimesh.Scene()
    groups = [
        (markings, "V30_RoadCentreLines", MARK_WHITE),
        (edge_lines, "V30_RoadEdgeLines", MARK_WHITE),
        (sidewalks, "V30_Sidewalks", SIDEWALK),
        (curbs, "V30_Curbs", CURB),
        (poles, "V30_StreetLightPoles", POLE),
        (lamps, "V30_StreetLightHeads", LAMP),
        (quay_edges, "V30_QuayEdges", QUAY),
        (fenders, "V30_QuayFenders", FENDER),
        (rocks, "V30_ShoreRocks", ROCK),
    ]
    for meshes, name, mat in groups:
        if not meshes:
            continue
        merged = trimesh.util.concatenate(meshes)
        merged.visual = trimesh.visual.TextureVisuals(material=mat)
        scene.add_geometry(merged, node_name=name, geom_name=name)
    print("v30 roads:", road_segments, "streetlights", light_count, "quay_fenders", quay_count, "shore_rocks", rock_count)
    return scene, {"road_segments": road_segments, "streetlights": light_count, "quay_fenders": quay_count, "shore_rocks": rock_count}


def land_kind(tags):
    natural = str(tags.get("natural", ""))
    landuse = str(tags.get("landuse", ""))
    leisure = str(tags.get("leisure", ""))
    if natural == "wood" or landuse == "forest":
        return "pine"
    if landuse in ("orchard", "vineyard"):
        return "olive"
    if natural == "scrub":
        return "island"
    if leisure in ("park", "garden") or landuse in ("meadow", "grass", "recreation_ground"):
        return "small"
    return None


def sample_foliage(elements):
    if Polygon is None or Point is None:
        return []
    rng = np.random.default_rng(30092026)
    points_out = []
    for element in elements:
        kind = land_kind(element.get("tags", {}))
        if kind is None:
            continue
        pts = v12.geometry_points(element)
        if len(pts) < 4:
            continue
        coords = local_coords(pts)
        if coords[0] == coords[-1]:
            coords = coords[:-1]
        try:
            poly = Polygon(coords)
            if not poly.is_valid:
                poly = poly.buffer(0)
            if poly.is_empty or poly.area < 500.0:
                continue
        except Exception:
            continue
        minx, minz, maxx, maxz = poly.bounds
        wanted = min(18, max(2, int(poly.area / 14000.0)))
        placed = 0
        attempts = 0
        while placed < wanted and attempts < wanted * 30 and len(points_out) < 560:
            attempts += 1
            x = float(rng.uniform(minx, maxx))
            z = float(rng.uniform(minz, maxz))
            if not poly.contains(Point(x, z)):
                continue
            lat = v12.ORIGIN_LAT - z / 110540.0
            lon = v12.ORIGIN_LON + x / (111320.0 * math.cos(math.radians(v12.ORIGIN_LAT)))
            y = float(v12.elevation(lat, lon))
            if y < 0.7 or y > 285.0:
                continue
            points_out.append({
                "x": round(x, 3), "y": round(y, 3), "z": round(z, 3),
                "kind": kind, "scale": round(float(rng.uniform(0.72, 1.28)), 3),
                "yaw": round(float(rng.uniform(0.0, math.tau)), 4),
            })
            placed += 1
        if len(points_out) >= 560:
            break
    (OUT / "foliage_points.json").write_text(json.dumps({"points": points_out}, ensure_ascii=False), encoding="utf-8")
    print("v30 OSM foliage points:", len(points_out))
    return points_out


def main():
    if not WORLD.exists():
        raise RuntimeError(f"missing world: {WORLD}")
    loaded = trimesh.load(WORLD, force="scene", process=False)
    scene = loaded if isinstance(loaded, trimesh.Scene) else trimesh.Scene(loaded)
    before = len(scene.geometry)

    print("v30: downloading one final OSM geometry snapshot for facade/road placement...")
    elements = v12.overpass_elements()
    if not elements:
        print("WARNING: OSM detail snapshot unavailable; keeping v23 world and writing empty foliage map")
        (OUT / "foliage_points.json").write_text('{"points":[]}', encoding="utf-8")
        return

    facade_scene, facade_metrics = build_facades(elements)
    for name, geom in facade_scene.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name, geom_name=name)

    road_scene, road_metrics = build_roads_waterfront(elements)
    for name, geom in road_scene.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name, geom_name=name)

    foliage = sample_foliage(elements)
    data = scene.export(file_type="glb")
    WORLD.write_bytes(data)
    metrics = {
        "osm_elements": len(elements),
        "world_geometry_groups_before": before,
        "world_geometry_groups_after": len(scene.geometry),
        "world_mb": round(len(data) / 1024 / 1024, 2),
        "foliage_points": len(foliage),
        **facade_metrics,
        **road_metrics,
    }
    (OUT / "BUILD_METRICS.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    (OUT / "ATTRIBUTION.txt").write_text(
        "Boğaz Kaptanı V30 ultra realism\nMap/building/road/land-use geometry © OpenStreetMap contributors, ODbL. Terrain elevation: AWS Open Data / Mapzen Terrain Tiles. Near vegetation models: Poly Haven CC0.\n",
        encoding="utf-8",
    )
    print("v30 world:", json.dumps(metrics, ensure_ascii=False))


if __name__ == "__main__":
    main()
