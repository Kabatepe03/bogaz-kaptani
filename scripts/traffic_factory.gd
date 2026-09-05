class_name TrafficFactory
extends RefCounted

static func create_ship(kind: String, pos: Vector3, heading_deg: float) -> CharacterBody3D:
	var root := CharacterBody3D.new()
	root.name = "AI_%s" % kind
	root.position = pos
	root.rotation_degrees.y = heading_deg
	root.set_meta("speed_mps", 5.0 if kind == "cargo" else 3.2)
	root.set_meta("kind", kind)
	if kind == "cargo":
		_build_cargo(root)
	else:
		_build_local_ferry(root)
	return root

static func _mat(color: Color, roughness := 0.65, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, roughness := 0.65, metallic := 0.0) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, roughness, metallic)
	parent.add_child(node)

static func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, 0.55, 0.12)
	parent.add_child(node)

static func _build_cargo(root: Node3D) -> void:
	_box(root, Vector3(18.0, 5.0, 78.0), Vector3(0, 1.2, 0), Color(0.18, 0.22, 0.24), 0.58, 0.22)
	_box(root, Vector3(15.5, 3.2, 26.0), Vector3(0, 5.1, 8.0), Color(0.68, 0.70, 0.69), 0.50, 0.10)
	_box(root, Vector3(13.0, 4.2, 11.0), Vector3(0, 8.7, -22.0), Color(0.88, 0.88, 0.84), 0.42, 0.06)
	_cylinder(root, 1.2, 7.0, Vector3(0, 11.2, -15.0), Color(0.17, 0.18, 0.19))
	var container_colors := [Color(0.65,0.16,0.10), Color(0.08,0.28,0.50), Color(0.14,0.42,0.24), Color(0.72,0.48,0.08)]
	for row in range(2):
		for col in range(3):
			var z := -2.0 + float(row) * 13.0
			var x := -6.0 + float(col) * 6.0
			_box(root, Vector3(5.2, 2.6, 11.0), Vector3(x, 5.8, z), container_colors[(row * 3 + col) % container_colors.size()], 0.68, 0.04)

static func _build_local_ferry(root: Node3D) -> void:
	_box(root, Vector3(13.0, 3.2, 38.0), Vector3(0, 1.0, 0), Color(0.82, 0.84, 0.83), 0.42, 0.12)
	_box(root, Vector3(11.0, 0.5, 31.0), Vector3(0, 3.2, 0), Color(0.14, 0.15, 0.16), 0.80, 0.05)
	_box(root, Vector3(9.0, 3.2, 8.0), Vector3(0, 5.0, 4.5), Color(0.88, 0.89, 0.88), 0.40, 0.04)
	_box(root, Vector3(8.5, 0.9, 0.10), Vector3(0, 5.6, 0.42), Color(0.02, 0.06, 0.08), 0.16, 0.08)
	_cylinder(root, 0.7, 3.0, Vector3(0, 8.0, 6.0), Color(0.14, 0.15, 0.16))
