class_name TerrainBuilder
extends RefCounted

static func make_landmass(center: Vector3, extent: Vector2, coastal_sign: float, seed: int) -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0012
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.52
	noise.fractal_lacunarity = 2.1

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 72
	for z in range(n):
		for x in range(n):
			var u0: float = float(x) / float(n - 1)
			var v0: float = float(z) / float(n - 1)
			var u1: float = float(x + 1) / float(n - 1)
			var v1: float = float(z + 1) / float(n - 1)
			if x == n - 1 or z == n - 1:
				continue
			_emit_quad(st, center, extent, coastal_sign, noise, u0, v0, u1, v1)
	st.generate_normals()
	var mesh := st.commit()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.27, 0.12)
	mat.roughness = 0.96
	mat.metallic = 0.0
	node.material_override = mat
	return node

static func _emit_quad(st: SurfaceTool, center: Vector3, extent: Vector2, sign_dir: float, noise: FastNoiseLite, u0: float, v0: float, u1: float, v1: float) -> void:
	var p00 := _point(center, extent, sign_dir, noise, u0, v0)
	var p10 := _point(center, extent, sign_dir, noise, u1, v0)
	var p01 := _point(center, extent, sign_dir, noise, u0, v1)
	var p11 := _point(center, extent, sign_dir, noise, u1, v1)
	for p in [p00, p01, p10, p10, p01, p11]:
		st.set_uv(Vector2(p.x / extent.x, p.z / extent.y))
		st.add_vertex(p)

static func _point(center: Vector3, extent: Vector2, sign_dir: float, noise: FastNoiseLite, u: float, v: float) -> Vector3:
	var lx: float = (u - 0.5) * extent.x
	var lz: float = (v - 0.5) * extent.y
	var coastal: float = float(clamp((sign_dir * lx + extent.x * 0.23) / (extent.x * 0.46), 0.0, 1.0))
	var ridge: float = float(pow(coastal, 1.35)) * 150.0
	var macro: float = noise.get_noise_2d(center.x + lx, center.z + lz) * 48.0
	var micro: float = noise.get_noise_2d((center.x + lx) * 2.7, (center.z + lz) * 2.7) * 9.0
	var h: float = maxf(-8.0, ridge + macro + micro - 16.0)
	return center + Vector3(lx, h, lz)
