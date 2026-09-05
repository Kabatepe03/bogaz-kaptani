class_name TerrainBuilder
extends RefCounted

static func make_landmass(center: Vector3, extent: Vector2, coastal_sign: float, seed: int) -> MeshInstance3D:
	var noise := _make_noise(seed)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = 96
	for z in range(n):
		for x in range(n):
			if x == n - 1 or z == n - 1:
				continue
			var u0: float = float(x) / float(n - 1)
			var v0: float = float(z) / float(n - 1)
			var u1: float = float(x + 1) / float(n - 1)
			var v1: float = float(z + 1) / float(n - 1)
			_emit_quad(st, center, extent, coastal_sign, noise, u0, v0, u1, v1)
	st.generate_normals()
	var mesh := st.commit()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	mat.metallic = 0.0
	node.material_override = mat
	return node

static func height_at(center: Vector3, extent: Vector2, coastal_sign: float, seed: int, world_x: float, world_z: float) -> float:
	var noise := _make_noise(seed)
	var lx := world_x - center.x
	var lz := world_z - center.z
	if abs(lx) > extent.x * 0.5 or abs(lz) > extent.y * 0.5:
		return 0.0
	return center.y + _height_local(center, extent, coastal_sign, noise, lx, lz)

static func _make_noise(seed: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0012
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.52
	noise.fractal_lacunarity = 2.1
	return noise

static func _emit_quad(st: SurfaceTool, center: Vector3, extent: Vector2, sign_dir: float, noise: FastNoiseLite, u0: float, v0: float, u1: float, v1: float) -> void:
	var p00 := _point(center, extent, sign_dir, noise, u0, v0)
	var p10 := _point(center, extent, sign_dir, noise, u1, v0)
	var p01 := _point(center, extent, sign_dir, noise, u0, v1)
	var p11 := _point(center, extent, sign_dir, noise, u1, v1)
	_emit_vertex(st, p00, extent)
	_emit_vertex(st, p01, extent)
	_emit_vertex(st, p10, extent)
	_emit_vertex(st, p10, extent)
	_emit_vertex(st, p01, extent)
	_emit_vertex(st, p11, extent)

static func _emit_vertex(st: SurfaceTool, p: Vector3, extent: Vector2) -> void:
	st.set_uv(Vector2(p.x / extent.x, p.z / extent.y))
	st.set_color(_terrain_color(p.y))
	st.add_vertex(p)

static func _terrain_color(h: float) -> Color:
	if h < 3.0:
		return Color(0.66, 0.60, 0.43)
	if h < 18.0:
		var t := inverse_lerp(3.0, 18.0, h)
		return Color(0.48, 0.50, 0.27).lerp(Color(0.24, 0.36, 0.16), t)
	if h < 85.0:
		var t2 := inverse_lerp(18.0, 85.0, h)
		return Color(0.24, 0.36, 0.16).lerp(Color(0.14, 0.27, 0.11), t2)
	if h < 150.0:
		var t3 := inverse_lerp(85.0, 150.0, h)
		return Color(0.14, 0.27, 0.11).lerp(Color(0.30, 0.30, 0.24), t3)
	return Color(0.34, 0.33, 0.29)

static func _point(center: Vector3, extent: Vector2, sign_dir: float, noise: FastNoiseLite, u: float, v: float) -> Vector3:
	var lx: float = (u - 0.5) * extent.x
	var lz: float = (v - 0.5) * extent.y
	var h := _height_local(center, extent, sign_dir, noise, lx, lz)
	return center + Vector3(lx, h, lz)

static func _height_local(center: Vector3, extent: Vector2, sign_dir: float, noise: FastNoiseLite, lx: float, lz: float) -> float:
	var coastal: float = float(clamp((sign_dir * lx + extent.x * 0.23) / (extent.x * 0.46), 0.0, 1.0))
	var ridge: float = float(pow(coastal, 1.35)) * 150.0
	var macro: float = noise.get_noise_2d(center.x + lx, center.z + lz) * 48.0
	var micro: float = noise.get_noise_2d((center.x + lx) * 2.7, (center.z + lz) * 2.7) * 9.0
	return maxf(-8.0, ridge + macro + micro - 16.0)
