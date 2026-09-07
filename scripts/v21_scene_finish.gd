extends Node

var installed := false

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(26):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_add_terminal_detail(scene, "V20_ÇANAKKALE FERİBOT TERMİNALİ", 2101)
	_add_terminal_detail(scene, "V20_ECEABAT FERİBOT TERMİNALİ", 2102)
	_add_ferry_detail(scene)
	installed = true

func _add_terminal_detail(scene: Node, terminal_name: String, seed_value: int) -> void:
	var found: Node = scene.find_child(terminal_name, true, false)
	if not (found is Node3D):
		return
	var terminal := found as Node3D
	if terminal.find_child("V21TerminalLife", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V21TerminalLife"
	terminal.add_child(root)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trunk_mat := _mat(Color(0.16, 0.09, 0.045), 0.96, 0.0)
	var pine_mat := _mat(Color(0.055, 0.18, 0.070), 0.93, 0.0)
	var olive_mat := _mat(Color(0.18, 0.30, 0.12), 0.95, 0.0)
	var scrub_mat := _mat(Color(0.24, 0.34, 0.13), 0.97, 0.0)
	var concrete := _mat(Color(0.44, 0.45, 0.43), 0.92, 0.01)
	var steel := _mat(Color(0.18, 0.20, 0.21), 0.54, 0.38)

	# Dense but batched-looking foreground greenery around the terminal is much more visible than
	# thousands of tiny 8 m trees spread over the entire 80 km² map.
	for i in range(78):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(24.0, 170.0)
		var z: float = rng.randf_range(82.0, 245.0)
		var scale_value: float = rng.randf_range(0.85, 1.55)
		root.add_child(_tree(Vector3(x, 1.80, z), scale_value, trunk_mat, pine_mat if rng.randf() < 0.66 else olive_mat))
	for i in range(95):
		var x: float = rng.randf_range(-180.0, 180.0)
		var z: float = rng.randf_range(70.0, 255.0)
		if absf(x) < 24.0 and z < 155.0:
			continue
		root.add_child(_shrub(Vector3(x, 1.79, z), rng.randf_range(0.55, 1.15), scrub_mat))

	# Promenade edge and street furniture make the terminal connect to a lived-in waterfront.
	root.add_child(_box(Vector3(92.0, 0.16, 7.0), Vector3(0.0, 1.76, 154.0), concrete))
	for x in range(-42, 43, 7):
		root.add_child(_lamp(Vector3(float(x), 1.85, 151.5), steel))
	for x in [-38.0, -19.0, 19.0, 38.0]:
		root.add_child(_bench(Vector3(x, 1.90, 156.0), steel))

func _add_ferry_detail(scene: Node) -> void:
	var found: Node = scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D
	if ferry.find_child("V21FerryDetail", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V21FerryDetail"
	ferry.add_child(root)

	var dark := _mat(Color(0.025, 0.055, 0.070), 0.20, 0.16)
	var steel := _mat(Color(0.25, 0.27, 0.28), 0.45, 0.45)
	var orange := _mat(Color(0.92, 0.23, 0.045), 0.52, 0.03)
	var white := _mat(Color(0.72, 0.73, 0.70), 0.76, 0.03)
	var deck := _mat(Color(0.11, 0.12, 0.12), 0.89, 0.01)

	# Bridge glazing and roof lip break the giant white-plastic silhouette visible in v20.
	root.add_child(_box(Vector3(10.8, 1.25, 0.18), Vector3(0.0, 12.25, -7.05), dark))
	root.add_child(_box(Vector3(12.4, 0.26, 8.0), Vector3(0.0, 14.10, -3.5), steel))
	for x in [-4.5, -2.25, 0.0, 2.25, 4.5]:
		root.add_child(_box(Vector3(1.65, 0.88, 0.12), Vector3(x, 12.25, -7.18), dark))

	# Liferaft canisters, side rub rails and deck markings add scale cues from chase/drone cameras.
	for side in [-1.0, 1.0]:
		for z in [-18.0, -6.0, 6.0, 18.0]:
			root.add_child(_capsule(Vector3(side * 8.7, 7.1, z), Vector3(0.82, 0.48, 1.25), orange))
		root.add_child(_box(Vector3(0.16, 0.20, 56.0), Vector3(side * 8.72, 4.85, 0.0), white))
	for x in [-5.5, 0.0, 5.5]:
		root.add_child(_box(Vector3(0.12, 0.025, 54.0), Vector3(x, 5.37, 0.0), white))
	root.add_child(_box(Vector3(15.2, 0.045, 54.0), Vector3(0.0, 5.31, 0.0), deck))

	# Compact radar/mast package.
	root.add_child(_cylinder(Vector3(0.0, 17.3, -1.0), 0.12, 5.0, steel))
	root.add_child(_box(Vector3(5.4, 0.13, 0.22), Vector3(0.0, 19.7, -1.0), white))
	root.add_child(_box(Vector3(0.22, 0.18, 4.0), Vector3(0.0, 19.72, -1.0), white))

func _tree(pos: Vector3, scale_value: float, trunk_mat: Material, crown_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = fmod(absf(pos.x * 3.7 + pos.z * 1.9), 360.0)
	var trunk := _cylinder(Vector3(0.0, 2.0 * scale_value, 0.0), 0.18 * scale_value, 4.0 * scale_value, trunk_mat)
	root.add_child(trunk)
	for layer in range(3):
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.12 * scale_value
		cone.bottom_radius = (2.25 - float(layer) * 0.42) * scale_value
		cone.height = 2.8 * scale_value
		cone.radial_segments = 9
		crown.mesh = cone
		crown.position.y = (4.1 + float(layer) * 1.35) * scale_value
		crown.material_override = crown_mat
		root.add_child(crown)
	return root

func _shrub(pos: Vector3, scale_value: float, material: Material) -> Node3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.15 * scale_value
	mesh.height = 1.45 * scale_value
	mesh.radial_segments = 8
	mesh.rings = 5
	node.mesh = mesh
	node.position = pos + Vector3(0.0, 0.70 * scale_value, 0.0)
	node.scale = Vector3(1.35, 0.68, 1.0)
	node.material_override = material
	return node

func _lamp(pos: Vector3, material: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.add_child(_cylinder(Vector3(0.0, 2.8, 0.0), 0.07, 5.6, material))
	root.add_child(_box(Vector3(0.8, 0.13, 0.32), Vector3(0.30, 5.5, 0.0), material))
	return root

func _bench(pos: Vector3, material: Material) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.add_child(_box(Vector3(3.0, 0.14, 0.70), Vector3(0.0, 0.55, 0.0), material))
	root.add_child(_box(Vector3(3.0, 0.14, 0.14), Vector3(0.0, 1.05, 0.28), material))
	for x in [-1.15, 1.15]:
		root.add_child(_box(Vector3(0.12, 0.65, 0.12), Vector3(x, 0.30, 0.0), material))
	return root

func _capsule(pos: Vector3, scale_value: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.48
	mesh.height = 1.45
	mesh.radial_segments = 12
	mesh.rings = 5
	node.mesh = mesh
	node.position = pos
	node.scale = scale_value
	node.rotation_degrees.z = 90.0
	node.material_override = material
	return node

func _cylinder(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = 10
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node

func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
