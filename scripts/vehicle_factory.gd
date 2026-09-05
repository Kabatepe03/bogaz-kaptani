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

static func _mat(color: Color, roughness := 0.62, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness := 0.62, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, roughness, metallic)
	parent.add_child(node)
	return node

static func _wheel(parent: Node3D, x: float, z: float, radius: float) -> void:
	var wheel := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.34
	mesh.radial_segments = 12
	wheel.mesh = mesh
	wheel.rotation_degrees.z = 90.0
	wheel.position = Vector3(x, radius, z)
	wheel.material_override = _mat(Color(0.025, 0.027, 0.03), 0.92, 0.0)
	parent.add_child(wheel)

static func _windows(parent: Node3D, width: float, height: float, z: float, y: float) -> void:
	_box(parent, Vector3(width, height, 0.06), Vector3(0, y, z), Color(0.025, 0.06, 0.085), 0.16, 0.08)

static func _build_car(root: Node3D, color: Color) -> void:
	_box(root, Vector3(1.95, 0.58, 4.25), Vector3(0, 0.52, 0), color, 0.34, 0.12)
	_box(root, Vector3(1.58, 0.66, 2.05), Vector3(0, 1.04, -0.1), color.lightened(0.05), 0.31, 0.10)
	_windows(root, 1.42, 0.43, -1.10, 1.06)
	_windows(root, 1.42, 0.43, 1.10, 1.06)
	for x in [-0.88, 0.88]:
		for z in [-1.40, 1.40]:
			_wheel(root, x, z, 0.31)

static func _build_minibus(root: Node3D, color: Color) -> void:
	_box(root, Vector3(2.15, 1.65, 5.75), Vector3(0, 1.05, 0), color, 0.42, 0.08)
	_windows(root, 1.82, 0.55, -2.90, 1.48)
	for x in [-1.02, 1.02]:
		for z in [-1.85, 1.85]:
			_wheel(root, x, z, 0.38)

static func _build_bus(root: Node3D, color: Color) -> void:
	_box(root, Vector3(2.55, 2.85, 11.4), Vector3(0, 1.75, 0), color, 0.48, 0.06)
	_windows(root, 2.20, 0.92, -5.73, 2.35)
	for i in range(5):
		var z := -3.8 + float(i) * 1.9
		_box(root, Vector3(0.06, 0.82, 1.38), Vector3(-1.29, 2.38, z), Color(0.02, 0.055, 0.075), 0.16, 0.08)
		_box(root, Vector3(0.06, 0.82, 1.38), Vector3(1.29, 2.38, z), Color(0.02, 0.055, 0.075), 0.16, 0.08)
	for x in [-1.20, 1.20]:
		for z in [-3.75, 3.70]:
			_wheel(root, x, z, 0.49)

static func _build_truck(root: Node3D, color: Color) -> void:
	_box(root, Vector3(2.55, 2.65, 3.25), Vector3(0, 1.60, -4.65), color, 0.42, 0.10)
	_windows(root, 2.22, 0.72, -6.30, 2.20)
	_box(root, Vector3(2.60, 2.95, 8.1), Vector3(0, 1.88, 1.15), Color(0.72, 0.73, 0.70), 0.78, 0.02)
	_box(root, Vector3(2.70, 0.18, 8.25), Vector3(0, 0.48, 1.15), Color(0.15, 0.16, 0.17), 0.82, 0.08)
	for x in [-1.20, 1.20]:
		for z in [-5.05, -2.65, 2.5, 4.2]:
			_wheel(root, x, z, 0.46)
