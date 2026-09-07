import os
import numpy as np
import trimesh
from scipy.ndimage import gaussian_filter

import generate_v12_world as v12

GRID_X = 108
GRID_Z = 124
MAT_TERRAIN = v12.pbr("dardanelles_ground_v14", (0.29, 0.33, 0.21), 0.0, 0.93)


def build_smooth_terrain():
    raw = np.zeros((GRID_Z, GRID_X), dtype=np.float32)
    xs = np.zeros((GRID_Z, GRID_X), dtype=np.float32)
    zs = np.zeros((GRID_Z, GRID_X), dtype=np.float32)

    for iz in range(GRID_Z):
        lat = v12.NORTH + (v12.SOUTH - v12.NORTH) * (iz / (GRID_Z - 1))
        for ix in range(GRID_X):
            lon = v12.WEST + (v12.EAST - v12.WEST) * (ix / (GRID_X - 1))
            x, z = v12.to_local(lat, lon)
            xs[iz, ix] = x
            zs[iz, ix] = z
            raw[iz, ix] = v12.elevation(lat, lon)

    land = raw > 0.8
    weights = gaussian_filter(land.astype(np.float32), sigma=1.15)
    weighted = gaussian_filter(np.where(land, raw, 0.0), sigma=1.15)
    smooth = np.where(land, weighted / np.maximum(weights, 0.001), -5.5)
    smooth = np.where(land, np.clip(smooth, 0.25, 330.0), -5.5)

    vertices = []
    for iz in range(GRID_Z):
        for ix in range(GRID_X):
            vertices.append((float(xs[iz, ix]), float(smooth[iz, ix]), float(zs[iz, ix])))

    faces = []
    for iz in range(GRID_Z - 1):
        for ix in range(GRID_X - 1):
            a = iz * GRID_X + ix
            b = a + 1
            c = a + GRID_X
            d = c + 1
            faces.append((a, c, b))
            faces.append((b, c, d))

    mesh = trimesh.Trimesh(np.asarray(vertices), np.asarray(faces), process=True, validate=True)
    mesh.remove_unreferenced_vertices()
    mesh.fix_normals()
    _ = mesh.vertex_normals
    mesh.visual = trimesh.visual.TextureVisuals(material=MAT_TERRAIN)
    return mesh


def main():
    terrain = build_smooth_terrain()
    scene = trimesh.Scene()
    scene.add_geometry(terrain, node_name="RealTerrainV14_Smoothed")

    osm = v12.build_osm_scene(v12.overpass_elements())
    for name, geom in osm.geometry.items():
        scene.add_geometry(geom.copy(), node_name=name)

    target = os.path.join(v12.OUT, "canakkale_real_world_v12.glb")
    data = scene.export(file_type="glb")
    with open(target, "wb") as stream:
        stream.write(data)
    with open(os.path.join(v12.OUT, "ATTRIBUTION.txt"), "w", encoding="utf-8") as stream:
        stream.write("Map data © OpenStreetMap contributors, ODbL. Terrain Tiles accessed from AWS Open Data / Mapzen Terrain Tiles. v14 terrain smoothing applied.\n")
    print(f"generated {target}: {len(data)} bytes")


if __name__ == "__main__":
    main()
