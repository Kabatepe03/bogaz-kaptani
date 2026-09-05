class_name FerryFactory
extends RefCounted

static func create_ferry() -> CharacterBody3D:
	var root := CharacterBody3D.new()
	root.name = "Ferry"
	root.add_child(_curved_hull())
	root.add_child(_deck())
	root.add_child(_bridge())
	root.add_child(_ramp(-30.8))
	root.add_child(_ramp(30.8))
	for side in [-1.0, 1.0]:
		for z in [-20.0, -10.0, 0.0, 10.0, 20.0]:
			root.add_child(_rail_post(Vector3(side * 10.8, 5.8, z)))
	return root

static func _curved_hull() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: int = 24
	for i in range(sections):
		var t0: float = float(i) / float(sections)
		var t1: float = float(i + 1) / float(sections)
		if i == sections - 1:
			continue
		var z0: float = lerpf(-31.0, 31.0, t0)
		var z1: float = lerpf(-31.0, 31.0, t1)
		var w0: float = 10.8 * float(pow(sin(PI * t0), 0.34))
		var w1: float = 10.8 * float(pow(sin(PI * t1), 0.34))
		_emit_side(st, z0, z1, w0, w1, 1.0)
		_emit_side(st, z0, z1, w0, w1, -1.0)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.91, 0.92, 0.90)
	mat.roughness = 0.35
	mat.metallic = 0.18
	node.material_override = mat
	return node

static func _emit_side(st: SurfaceTool, z0: float, z1: float, w0: float, w1: float, side: float) -> void:
	var top0 := Vector3(side * w0, 5.0, z0)
	var top1 := Vector3(side * w1, 5.0, z1)
	var chine0 := Vector3(side * w0 * 0.80, -1.0, z0)
	var chine1 := Vector3(side * w1 * 0.80, -1.0, z1)
	var keel0 := Vector3(side * 2.2, -4.2, z0)
	var keel1 := Vector3(side * 2.2, -4.2, z1)
	for p in [top0, chine0, top1, top1, chine0, chine1, chine0, keel0, chine1, chine1, keel0, keel1]:
		st.add_vertex(p)

static func _deck() -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(20.2, 0.55, 55.0)
	node.mesh = mesh
	node.position.y = 5.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.14, 0.15)
	mat.roughness = 0.82
	node.material_override = mat
	return node

static func _bridge() -> Node3D:
	var group := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(14.5, 4.6, 10.5)
	body.mesh = body_mesh
	body.position = Vector3(0, 8.0, 4.5)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.90, 0.92, 0.91)
	white.roughness = 0.42
	body.material_override = white
	group.add_child(body)
	var glass := MeshInstance3D.new()
	var glass_mesh := BoxMesh.new()
	glass_mesh.size = Vector3(14.7, 1.35, 10.7)
	glass.mesh = glass_mesh
	glass.position = Vector3(0, 9.15, 4.5)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.025, 0.07, 0.09, 0.82)
	gmat.metallic = 0.12
	gmat.roughness = 0.18
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = gmat
	group.add_child(glass)
	return group

static func _ramp(z: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(15.5, 0.40, 5.0)
	node.mesh = mesh
	node.position = Vector3(0, 5.05, z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.22, 0.23)
	mat.roughness = 0.88
	node.material_override = mat
	return node

static func _rail_post(pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.07
	mesh.height = 1.4
	node.mesh = mesh
	node.position = pos
	return node
