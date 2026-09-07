from pathlib import Path
import numpy as np
import trimesh

import generate_v22_ferry as v22

OUT = Path("assets/v20/ferry_remaster_v20.glb")


def add_deck_fixed(parts):
    parts.append(v22.box((15.5, 0.30, 74.0), (0.0, 4.30, 0.0), v22.DECK))
    for x in (-5.8, -1.95, 1.95, 5.8):
        for z in np.arange(-31.0, 32.0, 8.0):
            parts.append(v22.box((0.075, 0.025, 4.5), (x, 4.48, float(z)), v22.WHITE_TOP))
    for x in (-7.25, 7.25):
        parts.append(v22.box((0.09, 0.025, 69.0), (x, 4.49, 0.0), v22.YELLOW))

    # Fixed hinge beams stay on the hull. The ramp plates themselves are exported below as
    # independent glTF nodes whose local origin is the hinge, so Godot can animate them properly.
    for sign in (-1.0, 1.0):
        hinge_z = sign * 37.0
        parts.append(v22.cyl(0.25, 15.1, (0.0, 4.30, hinge_z), v22.DARK_STEEL, 24, "x"))
        for x in (-6.9, 6.9):
            parts.append(v22.box((0.35, 0.55, 0.85), (x, 4.48, hinge_z), v22.STEEL))


def make_ramp(sign):
    pieces = []
    # Local z=0 is the hinge. Positive sign extends toward +z end, negative toward -z end.
    pieces.append(v22.box((15.5, 0.26, 7.2), (0.0, 0.0, sign * 3.6), v22.STEEL))
    pieces.append(v22.box((15.15, 0.08, 6.85), (0.0, 0.17, sign * 3.62), v22.DECK))
    for x in np.linspace(-6.5, 6.5, 7):
        mat = v22.YELLOW if abs(float(x)) < 1.2 else v22.WHITE_TOP
        pieces.append(v22.box((0.075, 0.025, 6.25), (float(x), 0.24, sign * 3.65), mat))
    # Side guard lips and visible anti-slip cross ribs.
    for x in (-7.48, 7.48):
        pieces.append(v22.box((0.16, 0.42, 7.05), (x, 0.18, sign * 3.58), v22.STEEL))
    for z in np.linspace(0.8, 6.6, 9):
        pieces.append(v22.box((14.5, 0.035, 0.09), (0.0, 0.25, sign * float(z)), v22.DARK_STEEL))
    return trimesh.util.concatenate(pieces)


def add_finish_details(parts):
    # Waterline rubbing strakes and small sacrificial plates help the hull read as working machinery.
    for side in (-1.0, 1.0):
        for z in np.linspace(-28.0, 28.0, 8):
            parts.append(v22.box((0.10, 0.34, 3.7), (side * 8.47, 1.05, float(z)), v22.DARK_STEEL))
        # Small maintenance doors and drain scuppers.
        for z in (-23.0, -10.0, 10.0, 23.0):
            parts.append(v22.box((0.08, 0.65, 1.10), (side * 8.46, 5.45, z), v22.NAVY))
        for z in np.arange(-29.0, 30.0, 5.8):
            parts.append(v22.cyl(0.055, 0.14, (side * 8.52, 3.72, float(z)), v22.DARK_STEEL, 10, "x"))

    # Deck safety boxes / extinguishers / bollard clusters break up large empty surfaces.
    for z in (-27.0, -15.0, 15.0, 27.0):
        parts.append(v22.box((0.65, 1.05, 0.42), (-7.2, 5.05, z), v22.ORANGE))
    for x in (-5.9, 5.9):
        for z in (-31.0, 31.0):
            parts.append(v22.cyl(0.24, 0.52, (x, 4.78, z), v22.DARK_STEEL, 20, "y"))


def main():
    parts = [v22.make_hull()]
    parts.extend(v22.make_side_band(-4.5, -1.5, v22.RED))
    parts.extend(v22.make_side_band(-1.45, -0.65, v22.NAVY))
    parts.extend(v22.make_side_band(-0.60, -0.18, v22.BLUE))
    add_deck_fixed(parts)
    v22.add_superstructure(parts)
    v22.add_equipment(parts)
    add_finish_details(parts)

    scene = trimesh.Scene()
    for idx, mesh in enumerate(parts):
        scene.add_geometry(mesh, node_name=f"V23_FerryPart_{idx:04d}")

    front = make_ramp(-1.0)
    rear = make_ramp(1.0)
    scene.add_geometry(
        front,
        node_name="V23_RampFrontVisual",
        geom_name="V23_RampFrontMesh",
        transform=trimesh.transformations.translation_matrix((0.0, 4.30, -37.0)),
    )
    scene.add_geometry(
        rear,
        node_name="V23_RampRearVisual",
        geom_name="V23_RampRearMesh",
        transform=trimesh.transformations.translation_matrix((0.0, 4.30, 37.0)),
    )

    data = scene.export(file_type="glb")
    OUT.write_bytes(data)
    print(f"generated V23 ferry {OUT}: {len(data)/1024/1024:.2f} MB, fixed_parts={len(parts)}, hinged_ramps=2")


if __name__ == "__main__":
    main()
