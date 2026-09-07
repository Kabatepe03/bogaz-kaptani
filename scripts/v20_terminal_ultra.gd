extends Node

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame in range(24):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var canakkale: Node = scene.find_child("V20_ÇANAKKALE FERİBOT TERMİNALİ", true, false)
	var eceabat: Node = scene.find_child("V20_ECEABAT FERİBOT TERMİNALİ", true, false)
	if canakkale is Node3D:
		_build_canakkale(canakkale as Node3D)
	if eceabat is Node3D:
		_build_eceabat(eceabat as Node3D)

func _build_eceabat(root: Node3D) -> void:
	if root.find_child("V20EceabatPhotoPass", false, false) != null:
		return
	var detail: Node3D = Node3D.new()
	detail.name = "V20EceabatPhotoPass"
	root.add_child(detail)

	var yellow: StandardMaterial3D = _mat(Color(0.92, 0.62, 0.025), 0.58, 0.10)
	var white: StandardMaterial3D = _mat(Color(0.88, 0.89, 0.86), 0.72, 0.05)
	var cream: StandardMaterial3D = _mat(Color(0.78, 0.70, 0.52), 0.88, 0.01)
	var blue: StandardMaterial3D = _mat(Color(0.025, 0.18, 0.39), 0.48, 0.12)
	var roof: StandardMaterial3D = _mat(Color(0.34, 0.16, 0.095), 0.86, 0.02)
	var glass: StandardMaterial3D = _glass_mat()

	var booth: Node3D = Node3D.new()
	booth.position = Vector3(-6.0, 1.75, 48.0)
	detail.add_child(booth)
	booth.add_child(_box(Vector3(3.6, 3.2, 3.2), Vector3(0.0, 1.6, 0.0), yellow))
	booth.add_child(_box(Vector3(2.45, 1.15, 0.08), Vector3(0.0, 1.95, -1.64), glass))
	booth.add_child(_box(Vector3(4.0, 0.22, 3.7), Vector3(0.0, 3.30, 0.0), roof))

	var gantry_xs: Array[float] = [-9.0, 9.0]
	for gantry_x: float in gantry_xs:
		detail.add_child(_box(Vector3(0.34, 5.6, 0.34), Vector3(gantry_x, 4.45, 49.5), white))
	detail.add_child(_box(Vector3(18.4, 0.32, 0.38), Vector3(0.0, 7.20, 49.5), white))
	detail.add_child(_box(Vector3(8.7, 2.05, 0.20), Vector3(2.2, 6.15, 49.2), blue))
	var sign: Label3D = Label3D.new()
	sign.text = "ECEABAT İSKELESİ"
	sign.font_size = 74
	sign.outline_size = 5
	sign.pixel_size = 0.012
	sign.modulate = Color(0.97, 0.98, 0.96)
	sign.position = Vector3(2.2, 6.15, 49.05)
	detail.add_child(sign)

	var sides: Array[float] = [-1.0, 1.0]
	for side: float in sides:
		var rail_x: float = side * 10.7
		detail.add_child(_rail(Vector3(rail_x, 1.80, 34.0), 24.0, yellow, 1.20))
		detail.add_child(_rail(Vector3(rail_x, 1.80, 70.0), 24.0, yellow, 1.20))
	var lane_xs: Array[float] = [-5.3, 0.0, 5.3]
	for lane_x: float in lane_xs:
		detail.add_child(_box(Vector3(0.12, 0.035, 41.0), Vector3(lane_x, 1.79, 75.0), yellow))

	for i in range(4):
		var building_x: float = -27.0 + float(i) * 14.0
		var building: Node3D = Node3D.new()
		building.position = Vector3(building_x, 1.7, 96.0 + absf(building_x) * 0.12)
		detail.add_child(building)
		building.add_child(_box(Vector3(11.0, 4.4, 9.0), Vector3(0.0, 2.2, 0.0), cream))
		building.add_child(_box(Vector3(11.8, 0.34, 9.8), Vector3(0.0, 4.55, 0.0), roof))
		var window_xs: Array[float] = [-3.5, 0.0, 3.5]
		for window_x: float in window_xs:
			building.add_child(_box(Vector3(2.1, 1.35, 0.08), Vector3(window_x, 2.65, -4.55), glass))

	var promenade_mat: StandardMaterial3D = _mat(Color(0.46, 0.34, 0.30), 0.84, 0.02)
	detail.add_child(_box(Vector3(9.0, 0.28, 44.0), Vector3(20.5, 2.15, 62.0), promenade_mat))
	for z_value in range(43, 84, 4):
		var rail_z: float = float(z_value)
		detail.add_child(_box(Vector3(0.10, 1.1, 0.10), Vector3(16.2, 2.72, rail_z), white))
		detail.add_child(_box(Vector3(0.10, 1.1, 0.10), Vector3(24.8, 2.72, rail_z), white))
	detail.add_child(_box(Vector3(0.10, 0.10, 42.0), Vector3(16.2, 3.25, 63.0), white))
	detail.add_child(_box(Vector3(0.10, 0.10, 42.0), Vector3(24.8, 3.25, 63.0), white))

	for ix in range(-4, 5):
		for iz in range(0, 4):
			var checker: float = 0.60 if (ix + iz) % 2 == 0 else 0.48
			var paving_mat: StandardMaterial3D = _mat(Color(checker, checker * 0.97, checker * 0.90), 0.93, 0.0)
			detail.add_child(_box(Vector3(5.7, 0.08, 5.7), Vector3(float(ix) * 5.8, 1.82, 116.0 + float(iz) * 5.8), paving_mat))
	var tree_points: Array[Vector3] = [
		Vector3(-24.0, 1.85, 116.0), Vector3(26.0, 1.85, 121.0),
		Vector3(-17.0, 1.85, 134.0), Vector3(18.0, 1.85, 137.0)
	]
	for tree_pos: Vector3 in tree_points:
		detail.add_child(_terminal_tree(tree_pos, 1.15))

	var fender_zs: Array[float] = [-8.0, -15.0, -22.0, -29.0]
	for side: float in sides:
		for fender_z: float in fender_zs:
			detail.add_child(_fender(Vector3(side * 10.4, 0.9, fender_z)))

func _build_canakkale(root: Node3D) -> void:
	if root.find_child("V20CanakkalePhotoPass", false, false) != null:
		return
	var detail: Node3D = Node3D.new()
	detail.name = "V20CanakkalePhotoPass"
	root.add_child(detail)

	var yellow: StandardMaterial3D = _mat(Color(0.91, 0.67, 0.04), 0.62, 0.06)
	var white: StandardMaterial3D = _mat(Color(0.87, 0.88, 0.86), 0.75, 0.04)
	var navy: StandardMaterial3D = _mat(Color(0.025, 0.13, 0.27), 0.50, 0.12)
	var concrete: StandardMaterial3D = _mat(Color(0.48, 0.48, 0.45), 0.92, 0.02)
	var glass: StandardMaterial3D = _glass_mat()

	for i in range(3):
		var island_x: float = -9.0 + float(i) * 9.0
		var island: Node3D = Node3D.new()
		island.position = Vector3(island_x, 1.75, 62.0)
		detail.add_child(island)
		island.add_child(_box(Vector3(3.0, 2.8, 5.0), Vector3(0.0, 1.4, 0.0), concrete))
		island.add_child(_box(Vector3(2.25, 0.90, 0.08), Vector3(0.0, 1.72, -2.55), glass))
		island.add_child(_box(Vector3(3.8, 0.20, 6.0), Vector3(0.0, 2.90, 0.0), navy))

	var sides: Array[float] = [-1.0, 1.0]
	for side: float in sides:
		detail.add_child(_rail(Vector3(side * 14.2, 1.78, 78.0), 70.0, yellow, 0.95))
	var queue_xs: Array[float] = [-8.0, 0.0, 8.0]
	for queue_x: float in queue_xs:
		for z_value in range(54, 122, 12):
			detail.add_child(_box(Vector3(0.12, 0.04, 6.5), Vector3(queue_x, 1.81, float(z_value)), white))

	var canopy: Node3D = Node3D.new()
	canopy.position = Vector3(0.0, 1.8, 106.0)
	detail.add_child(canopy)
	canopy.add_child(_box(Vector3(26.0, 0.26, 12.0), Vector3(0.0, 5.7, 0.0), navy))
	var canopy_xs: Array[float] = [-11.0, -3.7, 3.7, 11.0]
	for canopy_x: float in canopy_xs:
		canopy.add_child(_box(Vector3(0.30, 5.5, 0.30), Vector3(canopy_x, 2.75, 0.0), white))

	var city_fender_zs: Array[float] = [-4.0, -11.0, -18.0]
	for side: float in sides:
		detail.add_child(_box(Vector3(1.0, 2.7, 36.0), Vector3(side * 12.0, 0.1, -6.0), concrete))
		for fender_z: float in city_fender_zs:
			detail.add_child(_fender(Vector3(side * 11.4, 0.9, fender_z)))

	var tree_points: Array[Vector3] = [
		Vector3(-27.0, 1.85, 115.0), Vector3(-22.0, 1.85, 128.0),
		Vector3(25.0, 1.85, 118.0), Vector3(30.0, 1.85, 132.0),
		Vector3(17.0, 1.85, 139.0)
	]
	for tree_pos: Vector3 in tree_points:
		detail.add_child(_terminal_tree(tree_pos, 1.05))

	var sign_back: MeshInstance3D = _box(Vector3(13.0, 2.0, 0.25), Vector3(0.0, 6.5, 44.0), navy)
	detail.add_child(sign_back)
	var sign: Label3D = Label3D.new()
	sign.text = "ÇANAKKALE İSKELESİ"
	sign.font_size = 70
	sign.outline_size = 5
	sign.pixel_size = 0.012
	sign.modulate = Color(0.97, 0.98, 0.96)
	sign.position = Vector3(0.0, 6.5, 43.82)
	detail.add_child(sign)

func _terminal_tree(pos: Vector3, scale_value: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	var trunk_mat: StandardMaterial3D = _mat(Color(0.18, 0.10, 0.05), 0.98, 0.0)
	var leaf_mat: StandardMaterial3D = _mat(Color(0.08, 0.25, 0.07), 0.96, 0.0)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.16 * scale_value
	trunk_mesh.bottom_radius = 0.24 * scale_value
	trunk_mesh.height = 4.0 * scale_value
	trunk_mesh.radial_segments = 8
	trunk.mesh = trunk_mesh
	trunk.position.y = 2.0 * scale_value
	trunk.material_override = trunk_mat
	root.add_child(trunk)
	var crown_offsets: Array[Vector3] = [
		Vector3(0.0, 4.3, 0.0), Vector3(-1.0, 4.0, 0.3), Vector3(0.9, 4.1, -0.4)
	]
	for offset: Vector3 in crown_offsets:
		var crown: MeshInstance3D = MeshInstance3D.new()
		var sphere_mesh: SphereMesh = SphereMesh.new()
		sphere_mesh.radius = 1.7 * scale_value
		sphere_mesh.height = 2.8 * scale_value
		sphere_mesh.radial_segments = 10
		sphere_mesh.rings = 6
		crown.mesh = sphere_mesh
		crown.position = offset * scale_value
		crown.material_override = leaf_mat
		root.add_child(crown)
	return root

func _rail(pos: Vector3, length: float, material: Material, height: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.add_child(_box(Vector3(0.10, 0.10, length), Vector3(0.0, height, 0.0), material))
	root.add_child(_box(Vector3(0.08, 0.08, length), Vector3(0.0, height * 0.55, 0.0), material))
	var post_z: float = -length * 0.5
	while post_z <= length * 0.5 + 0.01:
		root.add_child(_box(Vector3(0.10, height, 0.10), Vector3(0.0, height * 0.5, post_z), material))
		post_z += 2.4
	return root

func _fender(pos: Vector3) -> Node3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.50
	mesh.bottom_radius = 0.50
	mesh.height = 2.1
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees.z = 90.0
	node.material_override = _mat(Color(0.015, 0.017, 0.018), 0.98, 0.0)
	return node

func _glass_mat() -> StandardMaterial3D:
	var mat: StandardMaterial3D = _mat(Color(0.02, 0.07, 0.085, 0.92), 0.16, 0.12)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node