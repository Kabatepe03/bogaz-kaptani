class_name VehicleFactory
extends RefCounted

static func weight_for(kind: String) -> float:
	match kind:
		"minibus": return 3.2
		"bus": return 12.0
		"truck": return 28.0
		_: return 1.6

static func create_vehicle(kind: String, pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = kind.capitalize()
	root.position = pos
	root.set_meta("kind", kind)
	root.set_meta("weight_tons", weight_for(kind))
	match kind:
		"minibus":
			_build_minibus(root, color)
		"bus":
			_build_bus(root, color)
		"truck":
			_build_truck(root, color)
		_:
			_build_car(root, color)
	return root

static func _mat(color: Color, roughness: float = 0.48, metallic: float = 0.08) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func _glass_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.018, 0.055, 0.085, 0.92)
	mat.roughness = 0.10
	mat.metallic = 0.22
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

static func _emissive_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := _mat(color, 0.16, 0.02)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness: float = 0.48, metallic: float = 0.08) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, roughness, metallic)
	parent.add_child(node)
	return node

static func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness: float = 0.42, metallic: float = 0.10) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 18
	mesh.rings = 8
	node.mesh = mesh
	node.position = pos
	node.scale = size * 0.5
	node.material_override = _mat(color, roughness, metallic)
	parent.add_child(node)
	return node

static func _panel(parent: Node3D, size: Vector3, pos: Vector3, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := _box(parent, size, pos, Color(0.018, 0.055, 0.085), 0.10, 0.20)
	node.material_override = _glass_mat()
	node.rotation_degrees = rotation
	return node

static func _light(parent: Node3D, pos: Vector3, color: Color, size: Vector3) -> void:
	var node := _box(parent, size, pos, color, 0.12, 0.02)
	node.material_override = _emissive_mat(color, 2.4)

static func _wheel(parent: Node3D, x: float, z: float, radius: float, width: float = 0.30) -> void:
	var tire := MeshInstance3D.new()
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = radius
	tire_mesh.bottom_radius = radius
	tire_mesh.height = width
	tire_mesh.radial_segments = 20
	tire.mesh = tire_mesh
	tire.rotation_degrees.z = 90.0
	tire.position = Vector3(x, radius, z)
	tire.material_override = _mat(Color(0.018, 0.019, 0.022), 0.94, 0.0)
	parent.add_child(tire)

	var rim := MeshInstance3D.new()
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = radius * 0.52
	rim_mesh.bottom_radius = radius * 0.52
	rim_mesh.height = width + 0.02
	rim_mesh.radial_segments = 16
	rim.mesh = rim_mesh
	rim.rotation_degrees.z = 90.0
	rim.position = Vector3(x, radius, z)
	rim.material_override = _mat(Color(0.52, 0.55, 0.57), 0.28, 0.72)
	parent.add_child(rim)

static func _mirror(parent: Node3D, x: float, y: float, z: float) -> void:
	var stem := _box(parent, Vector3(0.08, 0.08, 0.38), Vector3(x, y, z), Color(0.12, 0.13, 0.14), 0.38, 0.35)
	stem.rotation_degrees.y = 10.0 if x > 0.0 else -10.0
	_box(parent, Vector3(0.16, 0.32, 0.28), Vector3(x, y + 0.05, z - 0.22), Color(0.05, 0.07, 0.08), 0.18, 0.22)

static func _build_car(root: Node3D, color: Color) -> void:
	# Markasız ama gerçek sedan/hatchback oranlarına yakın, yuvarlatılmış gövde.
	_ellipsoid(root, Vector3(1.96, 0.72, 4.48), Vector3(0, 0.60, 0.02), color, 0.34, 0.14)
	_ellipsoid(root, Vector3(1.68, 0.98, 2.40), Vector3(0, 1.09, 0.18), color.lightened(0.035), 0.30, 0.12)
	_box(root, Vector3(1.84, 0.20, 3.88), Vector3(0, 0.40, 0.05), color.darkened(0.06), 0.40, 0.12)
	_panel(root, Vector3(1.43, 0.48, 0.065), Vector3(0, 1.17, -1.10), Vector3(-14, 0, 0))
	_panel(root, Vector3(1.35, 0.42, 0.065), Vector3(0, 1.18, 1.22), Vector3(14, 0, 0))
	for side in [-1.0, 1.0]:
		_panel(root, Vector3(0.055, 0.44, 0.96), Vector3(side * 0.855, 1.15, -0.30))
		_panel(root, Vector3(0.055, 0.42, 0.80), Vector3(side * 0.855, 1.14, 0.67))
		_mirror(root, side * 1.02, 1.18, -0.83)
	for side in [-0.58, 0.58]:
		_light(root, Vector3(side, 0.72, -2.17), Color(1.0, 0.91, 0.66), Vector3(0.42, 0.19, 0.07))
		_light(root, Vector3(side, 0.68, 2.20), Color(0.92, 0.035, 0.02), Vector3(0.40, 0.18, 0.07))
	_box(root, Vector3(1.35, 0.16, 0.07), Vector3(0, 0.48, -2.24), Color(0.055, 0.06, 0.065), 0.66, 0.24)
	_box(root, Vector3(1.25, 0.10, 0.05), Vector3(0, 0.60, -2.285), Color(0.34, 0.36, 0.37), 0.24, 0.65)
	for x in [-0.92, 0.92]:
		for z in [-1.48, 1.48]:
			_wheel(root, x, z, 0.33, 0.25)

static func _build_minibus(root: Node3D, color: Color) -> void:
	_box(root, Vector3(2.16, 1.62, 5.72), Vector3(0, 1.10, 0), color, 0.42, 0.10)
	_ellipsoid(root, Vector3(2.12, 0.42, 5.30), Vector3(0, 2.02, 0.05), color.lightened(0.04), 0.46, 0.08)
	_panel(root, Vector3(1.82, 0.82, 0.07), Vector3(0, 1.62, -2.89), Vector3(-4, 0, 0))
	for side in [-1.0, 1.0]:
		for index in range(3):
			var z: float = -1.35 + float(index) * 1.35
			_panel(root, Vector3(0.06, 0.62, 1.03), Vector3(side * 1.09, 1.62, z))
		_mirror(root, side * 1.20, 1.72, -2.55)
	for side in [-0.70, 0.70]:
		_light(root, Vector3(side, 0.82, -2.91), Color(1.0, 0.92, 0.70), Vector3(0.38, 0.22, 0.07))
		_light(root, Vector3(side, 0.82, 2.91), Color(0.92, 0.03, 0.02), Vector3(0.30, 0.22, 0.07))
	_box(root, Vector3(1.45, 0.16, 0.07), Vector3(0, 0.55, -2.95), Color(0.05,0.055,0.06), 0.70, 0.22)
	for x in [-1.03, 1.03]:
		for z in [-1.92, 1.90]:
			_wheel(root, x, z, 0.39, 0.27)

static func _build_bus(root: Node3D, color: Color) -> void:
	_box(root, Vector3(2.56, 2.78, 11.25), Vector3(0, 1.74, 0), color, 0.46, 0.08)
	_ellipsoid(root, Vector3(2.50, 0.44, 10.80), Vector3(0, 3.18, 0.05), color.lightened(0.035), 0.50, 0.06)
	_panel(root, Vector3(2.18, 1.15, 0.075), Vector3(0, 2.32, -5.65), Vector3(-3, 0, 0))
	for side in [-1.0, 1.0]:
		for index in range(6):
			var z: float = -3.95 + float(index) * 1.55
			_panel(root, Vector3(0.06, 0.88, 1.18), Vector3(side * 1.30, 2.36, z))
		_mirror(root, side * 1.42, 2.42, -5.25)
	for side in [-0.82, 0.82]:
		_light(root, Vector3(side, 0.84, -5.66), Color(1.0, 0.92, 0.67), Vector3(0.42, 0.26, 0.08))
		_light(root, Vector3(side, 0.88, 5.65), Color(0.92, 0.03, 0.02), Vector3(0.36, 0.24, 0.08))
	_box(root, Vector3(1.65, 0.18, 0.08), Vector3(0, 0.58, -5.71), Color(0.055,0.06,0.065), 0.72, 0.24)
	for x in [-1.21, 1.21]:
		for z in [-3.80, 3.72]:
			_wheel(root, x, z, 0.50, 0.30)

static func _build_truck(root: Node3D, color: Color) -> void:
	# Avrupa tipi çekici + yarı römork silüeti; gerçek marka/logosu kullanılmaz.
	_box(root, Vector3(2.56, 2.62, 3.35), Vector3(0, 1.66, -4.52), color, 0.40, 0.12)
	_ellipsoid(root, Vector3(2.50, 0.38, 3.05), Vector3(0, 3.04, -4.48), color.lightened(0.04), 0.46, 0.08)
	_panel(root, Vector3(2.20, 0.88, 0.075), Vector3(0, 2.27, -6.22), Vector3(-3, 0, 0))
	for side in [-1.0, 1.0]:
		_panel(root, Vector3(0.06, 0.76, 0.92), Vector3(side * 1.30, 2.24, -4.84))
		_mirror(root, side * 1.45, 2.33, -5.82)
	_box(root, Vector3(2.62, 2.92, 8.15), Vector3(0, 1.90, 1.18), Color(0.73, 0.75, 0.73), 0.70, 0.04)
	_box(root, Vector3(2.72, 0.19, 8.28), Vector3(0, 0.50, 1.18), Color(0.14, 0.15, 0.16), 0.80, 0.12)
	for side in [-0.84, 0.84]:
		_light(root, Vector3(side, 0.82, -6.24), Color(1.0, 0.92, 0.68), Vector3(0.44, 0.24, 0.08))
		_light(root, Vector3(side, 0.76, 5.26), Color(0.93, 0.03, 0.02), Vector3(0.30, 0.22, 0.08))
	_box(root, Vector3(1.55, 0.18, 0.08), Vector3(0, 0.56, -6.29), Color(0.055,0.06,0.065), 0.72, 0.25)
	for x in [-1.22, 1.22]:
		for z in [-4.95, -2.88, 2.65, 4.22]:
			_wheel(root, x, z, 0.47, 0.31)
