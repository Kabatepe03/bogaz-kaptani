extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")
const FERRY_ASSET := "res://assets/v11/ferry_gestas_style_v11.glb"

const EUROPE_SHORE := [
	Vector2(40.2050, 26.3510),
	Vector2(40.1950, 26.3555),
	Vector2(40.18417, 26.36028),
	Vector2(40.1740, 26.3654),
	Vector2(40.1630, 26.3710),
	Vector2(40.15647, 26.37316),
	Vector2(40.14778, 26.37944),
	Vector2(40.1370, 26.3835),
	Vector2(40.1240, 26.3880)
]

const ASIA_SHORE := [
	Vector2(40.2050, 26.4140),
	Vector2(40.1950, 26.4105),
	Vector2(40.1840, 26.4075),
	Vector2(40.1740, 26.4050),
	Vector2(40.1620, 26.4035),
	Vector2(40.15056, 26.40194),
	Vector2(40.1400, 26.4040),
	Vector2(40.1280, 26.4085),
	Vector2(40.1160, 26.4140)
]

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	# Let the v8/v10 visual passes finish first, then replace the placeholder ferry.
	for _i in range(5):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	_build_real_strait_coasts(scene)
	_build_waterfronts(scene)
	_build_strait_nature(scene)
	_replace_ferry_visual(scene)

func _replace_ferry_visual(scene: Node) -> void:
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D
	if ferry.find_child("V11RealGLTFFerry", false, false) != null:
		return
	for child in ferry.get_children():
		if child.name == "DynamicCargo":
			continue
		_hide_visuals(child)
	if not ResourceLoader.exists(FERRY_ASSET):
		return
	var packed := load(FERRY_ASSET) as PackedScene
	if packed == null:
		return
	var model := packed.instantiate()
	model.name = "V11RealGLTFFerry"
	ferry.add_child(model)

func _hide_visuals(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = false
	for child in node.get_children():
		_hide_visuals(child)

func _build_real_strait_coasts(scene: Node) -> void:
	if scene.find_child("V11RealCoastEurope", false, false) == null:
		scene.add_child(_coast_mesh(EUROPE_SHORE, -1.0, 118.0, "V11RealCoastEurope"))
	if scene.find_child("V11RealCoastAsia", false, false) == null:
		scene.add_child(_coast_mesh(ASIA_SHORE, 1.0, 82.0, "V11RealCoastAsia"))

func _coast_mesh(points: Array, inland_sign: float, max_height: float, mesh_name: String) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var distances := [0.0, 90.0, 220.0, 430.0, 720.0, 1120.0]
	var positions: Array[Array] = []
	var colors: Array[Array] = []
	for i in range(points.size()):
		var row: Array = []
		var color_row: Array = []
		var shore := GeoReference.to_local(points[i])
		for j in range(distances.size()):
			var d: float = distances[j]
			var rise := 0.18
			if d > 0.0:
				rise = 2.5 + max_height * pow(d / 1120.0, 0.72)
				rise += sin(float(i) * 1.71 + float(j) * 2.13) * (2.0 + d * 0.008)
			var p := shore + Vector3(inland_sign * d, rise, 0.0)
			row.append(p)
			var c := Color(0.56, 0.49, 0.30)
			if d < 80.0:
				c = Color(0.63, 0.56, 0.38)
			elif d < 360.0:
				c = Color(0.29, 0.38, 0.19)
			elif d < 800.0:
				c = Color(0.22, 0.33, 0.16)
			else:
				c = Color(0.30, 0.35, 0.19)
			color_row.append(c)
		positions.append(row)
		colors.append(color_row)

	for i in range(points.size() - 1):
		for j in range(distances.size() - 1):
			_emit_colored_triangle(st, positions[i][j], colors[i][j], positions[i + 1][j], colors[i + 1][j], positions[i + 1][j + 1], colors[i + 1][j + 1])
			_emit_colored_triangle(st, positions[i][j], colors[i][j], positions[i + 1][j + 1], colors[i + 1][j + 1], positions[i][j + 1], colors[i][j + 1])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.name = mesh_name
	node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.96
	mat.metallic = 0.0
	node.material_override = mat
	return node

func _emit_colored_triangle(st: SurfaceTool, a: Vector3, ca: Color, b: Vector3, cb: Color, c: Vector3, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)

func _build_waterfronts(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V11WaterfrontReality"
	scene.add_child(root)
	var canakkale_a := GeoReference.to_local(Vector2(40.1438, 26.4032))
	var canakkale_b := GeoReference.to_local(Vector2(40.1608, 26.4038))
	var eceabat_a := GeoReference.to_local(Vector2(40.1775, 26.3628))
	var eceabat_b := GeoReference.to_local(Vector2(40.1902, 26.3577))
	root.add_child(_segment_box(canakkale_a, canakkale_b, 12.0, 0.55, Color(0.36, 0.37, 0.36)))
	root.add_child(_segment_box(eceabat_a, eceabat_b, 9.0, 0.50, Color(0.38, 0.39, 0.36)))
	_add_waterfront_lamps(root, canakkale_a, canakkale_b, 14)
	_add_waterfront_lamps(root, eceabat_a, eceabat_b, 10)

func _segment_box(a: Vector3, b: Vector3, width: float, y: float, color: Color) -> MeshInstance3D:
	var dir := b - a
	dir.y = 0.0
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.32, dir.length())
	node.mesh = mesh
	node.global_position = (a + b) * 0.5 + Vector3(0, y, 0)
	node.rotation.y = atan2(dir.x, dir.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	node.material_override = mat
	return node

func _add_waterfront_lamps(parent: Node3D, a: Vector3, b: Vector3, count: int) -> void:
	for i in range(count):
		var t := (float(i) + 0.5) / float(count)
		var p := a.lerp(b, t)
		var pole := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.07
		mesh.bottom_radius = 0.09
		mesh.height = 6.0
		mesh.radial_segments = 10
		pole.mesh = mesh
		pole.position = p + Vector3(0, 3.1, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.19, 0.19)
		mat.metallic = 0.55
		mat.roughness = 0.34
		pole.material_override = mat
		parent.add_child(pole)

func _build_strait_nature(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V11DardanellesNature"
	scene.add_child(root)
	# Gallipoli side: dense pine/maquis line rising behind Eceabat and Kilitbahir.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11017
	for i in range(145):
		var lat := rng.randf_range(40.1370, 40.1990)
		var shore_lon := 26.3835 - (lat - 40.1370) * 0.47
		var lon := shore_lon - rng.randf_range(0.0020, 0.0105)
		var p := GeoReference.to_local(Vector2(lat, lon))
		var inland_m := absf(lon - shore_lon) * 111320.0 * cos(deg_to_rad(40.16))
		var y := 4.0 + minf(105.0, inland_m * 0.09) + rng.randf_range(-3.0, 6.0)
		root.add_child(_tree(Vector3(p.x, y, p.z), rng.randf_range(0.75, 1.35)))
	# Çanakkale side: lower, more urban vegetation belt.
	for i in range(85):
		var lat2 := rng.randf_range(40.1330, 40.1810)
		var lon2 := rng.randf_range(26.4070, 26.4185)
		var p2 := GeoReference.to_local(Vector2(lat2, lon2))
		var y2 := rng.randf_range(6.0, 34.0)
		root.add_child(_tree(Vector3(p2.x, y2, p2.z), rng.randf_range(0.65, 1.10)))

func _tree(pos: Vector3, scale_value: float) -> Node3D:
	var group := Node3D.new()
	group.position = pos
	group.scale = Vector3.ONE * scale_value
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 3.7
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.85
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.20, 0.13, 0.075)
	trunk_mat.roughness = 0.98
	trunk.material_override = trunk_mat
	group.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 2.0
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 5
	crown.mesh = crown_mesh
	crown.scale = Vector3(1.9, 2.8, 1.9)
	crown.position.y = 5.1
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.075, 0.19, 0.075)
	crown_mat.roughness = 0.96
	crown.material_override = crown_mat
	group.add_child(crown)
	return group
