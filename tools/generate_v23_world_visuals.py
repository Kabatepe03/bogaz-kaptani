import math
import os

import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial

BASE_WORLD = os.path.join("assets", "v20", "canakkale_eceabat_remaster_v20.glb")


def pbr(name, rgb, metallic=0.0, rough=0.8):
    rgba = tuple(int(max(0.0, min(1.0, c)) * 255) for c in rgb) + (255,)
    return PBRMaterial(name=name, baseColorFactor=rgba, metallicFactor=metallic, roughnessFactor=rough)


WHITE = pbr("v23_road_white", (0.86, 0.86, 0.79), 0.0, 0.76)
YELLOW = pbr("v23_road_yellow", (0.87, 0.66, 0.10), 0.0, 0.74)
SIDEWALK = pbr("v23_sidewalk", (0.44, 0.43, 0.40), 0.0, 0.92)
CURB = pbr("v23_curb", (0.68, 0.68, 0.64), 0.0, 0.91)
ROOF_METAL = pbr("v23_roof_metal", (0.28, 0.30, 0.30), 0.52, 0.52)
ROOF_LIGHT = pbr("v23_roof_light", (0.68, 0.67, 0.62), 0.08, 0.79)
ANTENNA = pbr("v23_antenna", (0.12, 0.13, 0.13), 0.68, 0.42)


def box(extents, center, material, yaw=0.0):
    mesh = trimesh.creation.box(extents=extents)
    if abs(yaw) > 1e-7:
        mesh.apply_transform(trimesh.transformations.rotation_matrix(yaw, [0, 1, 0]))
    mesh.apply_translation(center)
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    return mesh


def cyl(radius, height, center, material, sections=10):
    mesh = trimesh.creation.cylinder(radius=radius, height=height, sections=sections)
    mesh.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2.0, [1, 0, 0]))
    mesh.apply_translation(center)
    mesh.visual = trimesh.visual.TextureVisuals(material=material)
    return mesh


def component_axis(component):
    vertices = np.asarray(component.vertices, dtype=np.float64)
    if len(vertices) < 4:
        return None
    xz = vertices[:, [0, 2]]
    center = xz.mean(axis=0)
    centered = xz - center
    cov = centered.T @ centered / max(len(centered), 1)
    values, vectors = np.linalg.eigh(cov)
    order = np.argsort(values)[::-1]
    major = vectors[:, order[0]]
    minor = vectors[:, order[1]]
    major_proj = centered @ major
    minor_proj = centered @ minor
    length = float(major_proj.max() - major_proj.min())
    width = float(minor_proj.max() - minor_proj.min())
    if width > length:
        length, width = width, length
        major, minor = minor, major
    yaw = math.atan2(float(major[0]), float(major[1]))
    y = float(vertices[:, 1].max())
    return center, major, minor, length, width, y, yaw


def generate_road_detail(scene):
    markings = []
    edge_lines = []
    sidewalks = []
    curbs = []
    segment_count = 0

    road_geometries = []
    for name, geom in scene.geometry.items():
        low = str(name).lower()
        if "osm_mainroads" in low or "osm_main_roads" in low or "mainroads" in low:
            road_geometries.append(geom)

    for road_mesh in road_geometries:
        try:
            components = road_mesh.split(only_watertight=False)
        except Exception:
            components = [road_mesh]
        for component in components[:1800]:
            stats = component_axis(component)
            if stats is None:
                continue
            center, major, minor, length, width, top_y, yaw = stats
            if length < 8.0 or width < 3.0 or width > 18.0:
                continue
            segment_count += 1
            cx, cz = float(center[0]), float(center[1])
            mx, mz = float(major[0]), float(major[1])
            nx, nz = float(minor[0]), float(minor[1])

            # Broken centre line, generated from each disconnected OSM road segment.
            dash_len = 3.4 if width < 9.5 else 4.2
            gap = 3.0
            usable = max(0.0, length - 1.5)
            count = max(1, int(usable / (dash_len + gap)))
            for i in range(count):
                along = -usable * 0.5 + (i + 0.5) * usable / count
                px = cx + mx * along
                pz = cz + mz * along
                markings.append(box((0.13, 0.025, min(dash_len, usable / count * 0.62)), (px, top_y + 0.035, pz), WHITE, yaw))

            # Solid outer lines on wider roads, useful from the drone/bridge cameras.
            if width >= 6.8 and length >= 14.0:
                for side in (-1.0, 1.0):
                    offset = side * max(1.8, width * 0.5 - 0.55)
                    px = cx + nx * offset
                    pz = cz + nz * offset
                    edge_lines.append(box((0.10, 0.022, length * 0.94), (px, top_y + 0.030, pz), WHITE, yaw))

            # Sidewalks are kept modest so they do not cover narrow residential streets.
            if width >= 6.2 and length >= 11.0:
                for side in (-1.0, 1.0):
                    side_offset = side * (width * 0.5 + 1.05)
                    px = cx + nx * side_offset
                    pz = cz + nz * side_offset
                    sidewalks.append(box((1.55, 0.10, length * 0.96), (px, top_y + 0.055, pz), SIDEWALK, yaw))
                    curb_offset = side * (width * 0.5 + 0.20)
                    qx = cx + nx * curb_offset
                    qz = cz + nz * curb_offset
                    curbs.append(box((0.16, 0.14, length * 0.97), (qx, top_y + 0.070, qz), CURB, yaw))

    groups = [
        (markings, "V23_MainRoad_CentreMarkings", WHITE),
        (edge_lines, "V23_MainRoad_EdgeLines", WHITE),
        (sidewalks, "V23_MainRoad_Sidewalks", SIDEWALK),
        (curbs, "V23_MainRoad_Curbs", CURB),
    ]
    for meshes, name, material in groups:
        if meshes:
            combined = trimesh.util.concatenate(meshes)
            combined.visual = trimesh.visual.TextureVisuals(material=material)
            scene.add_geometry(combined, node_name=name)
    print(f"v23 road detail: source_segments={segment_count}, centre_dashes={len(markings)}, sidewalks={len(sidewalks)}")


def generate_rooftop_detail(scene):
    hvac = []
    vents = []
    antennas = []
    candidates = []
    for name, geom in list(scene.geometry.items()):
        if "osm_buildings_" not in str(name).lower():
            continue
        try:
            components = geom.split(only_watertight=False)
        except Exception:
            components = [geom]
        for comp in components:
            bounds = np.asarray(comp.bounds)
            sx = float(bounds[1, 0] - bounds[0, 0])
            sz = float(bounds[1, 2] - bounds[0, 2])
            sy = float(bounds[1, 1] - bounds[0, 1])
            area = sx * sz
            if area < 80.0 or area > 4500.0 or sy < 4.5:
                continue
            candidates.append((area, bounds, sx, sz))

    candidates.sort(key=lambda item: item[0], reverse=True)
    rng = np.random.default_rng(230923)
    for idx, (_, bounds, sx, sz) in enumerate(candidates[:780]):
        cx = float((bounds[0, 0] + bounds[1, 0]) * 0.5)
        cz = float((bounds[0, 2] + bounds[1, 2]) * 0.5)
        top_y = float(bounds[1, 1]) + 0.08
        if idx % 3 == 0:
            size_x = min(2.8, max(1.2, sx * 0.18))
            size_z = min(2.4, max(1.0, sz * 0.17))
            hvac.append(box((size_x, 0.75, size_z), (cx + rng.uniform(-sx*0.18, sx*0.18), top_y + 0.38, cz + rng.uniform(-sz*0.18, sz*0.18)), ROOF_METAL))
        if idx % 4 == 0:
            vents.append(cyl(0.18, 1.25, (cx + rng.uniform(-sx*0.22, sx*0.22), top_y + 0.62, cz + rng.uniform(-sz*0.22, sz*0.22)), ROOF_LIGHT, 10))
        if idx % 7 == 0:
            mast_x = cx + rng.uniform(-sx*0.15, sx*0.15)
            mast_z = cz + rng.uniform(-sz*0.15, sz*0.15)
            antennas.append(cyl(0.055, 2.9, (mast_x, top_y + 1.45, mast_z), ANTENNA, 8))
            antennas.append(box((1.1, 0.06, 0.06), (mast_x, top_y + 2.45, mast_z), ANTENNA))

    groups = [
        (hvac, "V23_Rooftop_HVAC", ROOF_METAL),
        (vents, "V23_Rooftop_Vents", ROOF_LIGHT),
        (antennas, "V23_Rooftop_Antennas", ANTENNA),
    ]
    for meshes, name, material in groups:
        if meshes:
            combined = trimesh.util.concatenate(meshes)
            combined.visual = trimesh.visual.TextureVisuals(material=material)
            scene.add_geometry(combined, node_name=name)
    print(f"v23 rooftop detail: buildings={len(candidates[:780])}, hvac={len(hvac)}, vents={len(vents)}, antenna_parts={len(antennas)}")


def main():
    if not os.path.exists(BASE_WORLD):
        raise RuntimeError(f"world missing: {BASE_WORLD}")
    loaded = trimesh.load(BASE_WORLD, force="scene", process=False)
    scene = loaded if isinstance(loaded, trimesh.Scene) else trimesh.Scene(loaded)
    base_groups = len(scene.geometry)
    generate_road_detail(scene)
    generate_rooftop_detail(scene)
    data = scene.export(file_type="glb")
    with open(BASE_WORLD, "wb") as stream:
        stream.write(data)
    print(f"v23 world visuals: {len(data)/1024/1024:.2f} MB, geometry_groups {base_groups}->{len(scene.geometry)}")


if __name__ == "__main__":
    main()
