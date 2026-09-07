extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")

var _installed := false

func _ready() -> void:
	call_deferred("_install_when_world_ready")

func _install_when_world_ready() -> void:
	for _frame: int in range(20):
		await get_tree().process_frame
		var current_scene: Node = get_tree().current_scene
		if current_scene != null and current_scene.find_child("V20_REAL_CANAKKALE_WORLD", true, false) != null:
			_install(current_scene)
			return
	await get_tree().create_timer(0.8).timeout
	var fallback_scene: Node = get_tree().current_scene
	if fallback_scene != null:
		_install(fallback_scene)

func _install(scene: Node) -> void:
	if _installed:
		return
	_installed = true
	_build_clock_tower(scene)
	_build_cimenlik(scene)
	_build_kilitbahir(scene)
	_build_dur_yolcu(scene)
	_build_terminal_identity(scene, GeoReference.CANAKKALE_DOCK, GeoReference.ECEABAT_DOCK, "ÇANAKKALE")
	_build_terminal_identity(scene, GeoReference.ECEABAT_DOCK, GeoReference.CANAKKALE_DOCK, "ECEABAT")

func _build_clock_tower(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V20_Çanakkale_Saat_Kulesi"
	root.position = GeoReference.to_local(GeoReference.CANAKKALE_CLOCK_TOWER) + Vector3(0.0, 1.4, 0.0)
	scene.add_child(root)

	var stone: StandardMaterial3D = _mat(Color(0.72, 0.67, 0.57), 0.88, 0.0)
	var trim: StandardMaterial3D = _mat(Color(0.58, 0.53, 0.45), 0.90, 0.0)
	var clock_white: StandardMaterial3D = _mat(Color(0.91, 0.90, 0.84), 0.58, 0.0)
	var clock_dark: StandardMaterial3D = _mat(Color(0.04, 0.045, 0.05), 0.45, 0.08)

	var levels: Array[Vector3] = [
		Vector3(5.2, 4.0, 5.2),
		Vector3(4.7, 3.8, 4.7),
		Vector3(4.2, 3.6, 4.2),
		Vector3(3.7, 3.4, 3.7),
		Vector3(3.2, 3.1, 3.2)
	]
	var y: float = 0.0
	for size: Vector3 in levels:
		root.add_child(_box(size, Vector3(0.0, y + size.y * 0.5, 0.0), stone))
		y += size.y
		root.add_child(_box(Vector3(size.x + 0.30, 0.20, size.z + 0.30), Vector3(0.0, y, 0.0), trim))

	var face_y: float = 16.2
	for side: int in range(4):
		var face := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.05
		disc.bottom_radius = 1.05
		disc.height = 0.10
		disc.radial_segments = 40
		face.mesh = disc
		face.material_override = clock_white
		face.position.y = face_y
		if side == 0:
			face.position.z = -1.66
			face.rotation_degrees.x = 90.0
		elif side == 1:
			face.position.z = 1.66
			face.rotation_degrees.x = 90.0
		elif side == 2:
			face.position.x = -1.66
			face.rotation_degrees.z = 90.0
		else:
			face.position.x = 1.66
			face.rotation_degrees.z = 90.0
		root.add_child(face)

	root.add_child(_box(Vector3(0.12, 2.3, 0.12), Vector3(0.0, 19.55, 0.0), clock_dark))
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.25
	cap_mesh.bottom_radius = 1.95
	cap_mesh.height = 1.8
	cap_mesh.radial_segments = 4
	cap.mesh = cap_mesh
	cap.position.y = 18.75
	cap.rotation_degrees.y = 45.0
	cap.material_override = trim
	root.add_child(cap)

func _build_cimenlik(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V20_Çimenlik_Kalesi"
	root.position = GeoReference.to_local(GeoReference.CIMENLIK_CASTLE) + Vector3(0.0, 2.0, 0.0)
	scene.add_child(root)
	var stone: StandardMaterial3D = _mat(Color(0.46, 0.40, 0.31), 0.96, 0.0)
	var dark_stone: StandardMaterial3D = _mat(Color(0.34, 0.30, 0.24), 0.98, 0.0)
	root.add_child(_box(Vector3(52.0, 8.0, 5.5), Vector3(0.0, 4.0, -22.0), stone))
	root.add_child(_box(Vector3(52.0, 8.0, 5.5), Vector3(0.0, 4.0, 22.0), stone))
	root.add_child(_box(Vector3(5.5, 8.0, 44.0), Vector3(-23.5, 4.0, 0.0), stone))
	root.add_child(_box(Vector3(5.5, 8.0, 44.0), Vector3(23.5, 4.0, 0.0), stone))
	for corner: Vector3 in [Vector3(-23.0, 5.0, -22.0), Vector3(23.0, 5.0, -22.0), Vector3(-23.0, 5.0, 22.0), Vector3(23.0, 5.0, 22.0)]:
		root.add_child(_cylinder(6.2, 10.0, corner, stone, 28))
	root.add_child(_cylinder(8.8, 17.0, Vector3(0.0, 8.5, 0.0), dark_stone, 34))
	root.add_child(_box(Vector3(19.0, 15.0, 16.0), Vector3(0.0, 7.5, 0.0), stone))
	for x: float in [-7.0, 0.0, 7.0]:
		root.add_child(_box(Vector3(3.2, 2.0, 1.0), Vector3(x, 5.2, -8.3), dark_stone))

func _build_kilitbahir(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V20_Kilitbahir_Kalesi"
	root.position = GeoReference.to_local(GeoReference.KILITBAHIR) + Vector3(0.0, 4.0, 0.0)
	scene.add_child(root)
	var stone: StandardMaterial3D = _mat(Color(0.43, 0.37, 0.29), 0.97, 0.0)
	var shadow_stone: StandardMaterial3D = _mat(Color(0.30, 0.27, 0.23), 0.99, 0.0)
	root.add_child(_cylinder(8.6, 24.0, Vector3(0.0, 12.0, 0.0), stone, 32))
	for p: Vector3 in [Vector3(-12.0, 7.0, 1.0), Vector3(12.0, 7.0, 1.0), Vector3(0.0, 7.0, -12.0)]:
		root.add_child(_cylinder(5.8, 14.0, p, stone, 26))
	root.add_child(_box(Vector3(27.0, 7.0, 4.5), Vector3(0.0, 4.0, -7.5), shadow_stone))
	root.add_child(_box(Vector3(4.5, 7.0, 24.0), Vector3(-7.5, 4.0, 0.0), shadow_stone))
	root.add_child(_box(Vector3(4.5, 7.0, 24.0), Vector3(7.5, 4.0, 0.0), shadow_stone))

func _build_dur_yolcu(scene: Node) -> void:
	var old_label: Node = scene.find_child("Dur Yolcu", true, false)
	if old_label is VisualInstance3D:
		(old_label as VisualInstance3D).visible = false
	var label := Label3D.new()
	label.name = "V20_Dur_Yolcu"
	label.text = "DUR YOLCU"
	label.font_size = 150
	label.outline_size = 5
	label.pixel_size = 0.030
	label.modulate = Color(0.96, 0.96, 0.91)
	label.position = GeoReference.to_local(GeoReference.DUR_YOLCU) + Vector3(0.0, 68.0, 0.0)
	label.rotation_degrees = Vector3(-18.0, 78.0, 0.0)
	scene.add_child(label)

func _build_terminal_identity(scene: Node, dock: Vector2, opposite: Vector2, title: String) -> void:
	var root := Node3D.new()
	root.name = "V20_%s_Identity" % title
	root.position = GeoReference.to_local(dock) + Vector3(0.0, 2.2, 0.0)
	scene.add_child(root)
	var target: Vector3 = GeoReference.to_local(opposite)
	root.look_at(target, Vector3.UP)

	var yellow: StandardMaterial3D = _mat(Color(0.93, 0.69, 0.04), 0.62, 0.08)
	var blue: StandardMaterial3D = _mat(Color(0.025, 0.17, 0.34), 0.42, 0.18)
	for side: float in [-1.0, 1.0]:
		root.add_child(_box(Vector3(0.18, 1.25, 17.0), Vector3(side * 10.2, 0.75, 10.0), yellow))
		for z: float in [2.0, 6.0, 10.0, 14.0, 18.0]:
			root.add_child(_box(Vector3(0.24, 1.30, 0.24), Vector3(side * 10.2, 0.75, z), yellow))
	var sign_back := _box(Vector3(12.5, 2.0, 0.30), Vector3(0.0, 4.7, 25.0), blue)
	root.add_child(sign_back)
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 72
	sign.outline_size = 6
	sign.pixel_size = 0.015
	sign.modulate = Color(0.96, 0.97, 0.95)
	sign.position = Vector3(0.0, 4.7, 24.78)
	root.add_child(sign)

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node

func _cylinder(radius: float, height: float, pos: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	return node
