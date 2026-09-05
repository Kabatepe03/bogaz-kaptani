class_name FerryFactory
extends RefCounted

static func create_ferry() -> CharacterBody3D:
	var root := CharacterBody3D.new()
	root.name = "Ferry"
	root.add_child(_curved_hull())
	root.add_child(_deck())
	root.add_child(_bridge())
	root.add_child(_ramp(-30.5))
	root.add_child(_ramp(30.5))
	root.add_child(_deck_details())
	root.add_child(_rails())
	root.add_child(_mast_and_funnel())
	root.add_child(_parked_vehicles())
	return root

static func _mat(color: Color, roughness := 0.65, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

static func _box(size: Vector3, pos: Vector3, color: Color, roughness := 0.65, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, roughness, metallic)
	return node

static func _cylinder(radius: float, height: float, pos: Vector3, color: Color, roughness := 0.55, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, roughness, metallic)
	return node

static func _curved_hull() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: int = 42
	for i in range(sections - 1):
		var t0: float = float(i) / float(sections - 1)
		var t1: float = float(i + 1) / float(sections - 1)
		var z0: float = lerpf(-32.0, 32.0, t0)
		var z1: float = lerpf(-32.0, 32.0, t1)
		var shape0 := maxf(0.08, float(pow(sin(PI * t0), 0.28)))
		var shape1 := maxf(0.08, float(pow(sin(PI * t1), 0.28)))
		var w0: float = 11.2 * shape0
		var w1: float = 11.2 * shape1
		_emit_side(st, z0, z1, w0, w1, 1.0)
		_emit_side(st, z0, z1, w0, w1, -1.0)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := _mat(Color(0.88, 0.90, 0.89), 0.30, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	return node

static func _emit_side(st: SurfaceTool, z0: float, z1: float, w0: float, w1: float, side: float) -> void:
	var top0 := Vector3(side * w0, 5.0, z0)
	var top1 := Vector3(side * w1, 5.0, z1)
	var chine0 := Vector3(side * w0 * 0.82, -1.0, z0)
	var chine1 := Vector3(side * w1 * 0.82, -1.0, z1)
	var keel0 := Vector3(side * 2.0, -4.3, z0)
	var keel1 := Vector3(side * 2.0, -4.3, z1)
	var verts := [top0, chine0, top1, top1, chine0, chine1, chine0, keel0, chine1, chine1, keel0, keel1]
	if side < 0.0:
		verts.reverse()
	for p in verts:
		st.add_vertex(p)

static func _deck() -> MeshInstance3D:
	return _box(Vector3(20.8, 0.55, 57.0), Vector3(0, 5.15, 0), Color(0.12, 0.13, 0.14), 0.88, 0.04)

static func _bridge() -> Node3D:
	var group := Node3D.new()
	group.name = "Bridge"
	group.add_child(_box(Vector3(15.4, 4.3, 12.0), Vector3(0, 8.0, 5.0), Color(0.90, 0.92, 0.91), 0.38, 0.04))
	group.add_child(_box(Vector3(16.0, 0.35, 12.6), Vector3(0, 10.35, 5.0), Color(0.84, 0.87, 0.86), 0.34, 0.06))
	var glass_mat := _mat(Color(0.015, 0.055, 0.075, 0.88), 0.12, 0.18)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var front_glass := _box(Vector3(13.8, 1.45, 0.18), Vector3(0, 9.0, -1.08), Color(0.015, 0.055, 0.075, 0.88), 0.12, 0.18)
	front_glass.material_override = glass_mat
	group.add_child(front_glass)
	for side in [-1.0, 1.0]:
		var side_glass := _box(Vector3(0.18, 1.45, 9.6), Vector3(side * 7.78, 9.0, 5.0), Color(0.015, 0.055, 0.075, 0.88), 0.12, 0.18)
		side_glass.material_override = glass_mat
		group.add_child(side_glass)
	group.add_child(_box(Vector3(12.0, 2.6, 7.0), Vector3(0, 12.0, 5.8), Color(0.88, 0.90, 0.89), 0.42, 0.03))
	group.add_child(_box(Vector3(12.6, 0.25, 7.6), Vector3(0, 13.45, 5.8), Color(0.20, 0.22, 0.23), 0.65, 0.10))
	return group

static func _ramp(z: float) -> MeshInstance3D:
	var ramp := _box(Vector3(15.8, 0.42, 5.0), Vector3(0, 5.08, z), Color(0.19, 0.20, 0.21), 0.90, 0.05)
	return ramp

static func _deck_details() -> Node3D:
	var group := Node3D.new()
	group.name = "DeckDetails"
	for x in [-6.8, -2.3, 2.3, 6.8]:
		for z in [-20.0, -8.0, 4.0, 16.0]:
			group.add_child(_box(Vector3(0.16, 0.035, 7.2), Vector3(x, 5.48, z), Color(0.94, 0.92, 0.66), 0.80, 0.0))
	for side in [-1.0, 1.0]:
		for z in [-23.0, -11.0, 1.0, 13.0, 24.0]:
			group.add_child(_box(Vector3(0.55, 0.35, 1.6), Vector3(side * 9.8, 5.58, z), Color(0.94, 0.42, 0.08), 0.72, 0.0))
	return group

static func _rails() -> Node3D:
	var group := Node3D.new()
	group.name = "Rails"
	var metal := Color(0.76, 0.79, 0.79)
	for side in [-1.0, 1.0]:
		group.add_child(_box(Vector3(0.10, 0.10, 51.0), Vector3(side * 10.6, 6.45, 0), metal, 0.34, 0.42))
		group.add_child(_box(Vector3(0.10, 0.10, 51.0), Vector3(side * 10.6, 5.95, 0), metal, 0.34, 0.42))
		for z in [-24.0, -18.0, -12.0, -6.0, 0.0, 6.0, 12.0, 18.0, 24.0]:
			group.add_child(_cylinder(0.055, 1.5, Vector3(side * 10.6, 6.0, z), metal, 0.32, 0.46))
	return group

static func _mast_and_funnel() -> Node3D:
	var group := Node3D.new()
	group.name = "MastAndFunnel"
	group.add_child(_cylinder(0.16, 8.5, Vector3(0, 17.3, 4.7), Color(0.74, 0.77, 0.77), 0.35, 0.50))
	group.add_child(_box(Vector3(6.0, 0.14, 0.14), Vector3(0, 19.6, 4.7), Color(0.68, 0.71, 0.72), 0.35, 0.48))
	group.add_child(_cylinder(1.05, 3.6, Vector3(-3.0, 15.0, 9.0), Color(0.12, 0.13, 0.14), 0.45, 0.22))
	group.add_child(_cylinder(1.05, 3.6, Vector3(3.0, 15.0, 9.0), Color(0.12, 0.13, 0.14), 0.45, 0.22))
	group.add_child(_box(Vector3(3.2, 0.18, 0.8), Vector3(0, 20.7, 4.7), Color(0.88, 0.90, 0.90), 0.38, 0.30))
	return group

static func _parked_vehicles() -> Node3D:
	var group := Node3D.new()
	group.name = "Vehicles"
	var colors := [Color(0.72,0.12,0.10), Color(0.10,0.22,0.56), Color(0.82,0.82,0.78), Color(0.14,0.15,0.16), Color(0.12,0.44,0.32)]
	var index := 0
	for x in [-6.5, -2.2, 2.2, 6.5]:
		for z in [-17.0, -6.0, 17.0]:
			if abs(x) < 3.0 and z > 10.0:
				continue
			group.add_child(_car(Vector3(x, 5.70, z), colors[index % colors.size()]))
			index += 1
	return group

static func _car(pos: Vector3, color: Color) -> Node3D:
	var group := Node3D.new()
	group.position = pos
	group.add_child(_box(Vector3(1.9, 0.65, 4.1), Vector3(0, 0.32, 0), color, 0.36, 0.12))
	group.add_child(_box(Vector3(1.55, 0.60, 2.0), Vector3(0, 0.88, -0.1), color.lightened(0.08), 0.28, 0.10))
	var window_mat := _mat(Color(0.02,0.05,0.07), 0.14, 0.16)
	var windshield := _box(Vector3(1.42, 0.42, 0.08), Vector3(0, 0.92, -1.12), Color(0.02,0.05,0.07), 0.14, 0.16)
	windshield.material_override = window_mat
	group.add_child(windshield)
	return group
