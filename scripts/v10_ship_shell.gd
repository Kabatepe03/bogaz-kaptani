extends Node

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D
	var old_bridge := ferry.find_child("Bridge", false, false)
	if old_bridge is Node3D:
		(old_bridge as Node3D).visible = false
	_build_superstructure(ferry)

func _build_superstructure(ferry: Node3D) -> void:
	if ferry.find_child("V10Superstructure", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V10Superstructure"
	ferry.add_child(root)

	var white := Color(0.88, 0.90, 0.89)
	var white_top := Color(0.94, 0.95, 0.94)
	var dark := Color(0.035, 0.045, 0.050)
	root.add_child(_tapered_body(15.8, 14.0, 12.4, 10.2, 4.35, Vector3(0, 8.0, 5.0), white))
	root.add_child(_tapered_body(12.5, 11.2, 7.6, 6.4, 2.75, Vector3(0, 11.75, 5.8), white_top))
	root.add_child(_box(Vector3(13.0, 0.28, 8.2), Vector3(0, 13.30, 5.8), Color(0.18, 0.20, 0.21), 0.48, 0.18))

	# Ön köprü camları: tek siyah şerit yerine ayrı paneller ve dikmeler.
	for index in range(7):
		var x: float = -5.55 + float(index) * 1.85
		var window := _glass(Vector3(1.62, 1.35, 0.08), Vector3(x, 8.95, -0.72))
		window.rotation_degrees.x = -8.0
		root.add_child(window)
		if index < 6:
			var pillar_x: float = x + 0.925
			root.add_child(_box(Vector3(0.08, 1.52, 0.12), Vector3(pillar_x, 8.95, -0.78), Color(0.52,0.54,0.55), 0.32, 0.58))

	# Yan camlar ve dış köprü kanatları.
	for side in [-1.0, 1.0]:
		for z in [1.6, 4.2, 6.8, 9.2]:
			root.add_child(_glass(Vector3(0.08, 1.30, 1.75), Vector3(side * 7.45, 8.90, z)))
		root.add_child(_box(Vector3(2.8, 0.24, 5.4), Vector3(side * 8.2, 10.10, 4.5), white, 0.48, 0.08))
		root.add_child(_box(Vector3(0.12, 1.05, 5.2), Vector3(side * 9.48, 10.62, 4.5), Color(0.65,0.68,0.69), 0.32, 0.55))

	# Üst pilothouse camları.
	for index in range(5):
		var x2: float = -4.20 + float(index) * 2.10
		var upper_window := _glass(Vector3(1.82, 0.88, 0.07), Vector3(x2, 12.0, 2.54))
		upper_window.rotation_degrees.x = -5.0
		root.add_child(upper_window)

	# Köprü önü çıkıntısı ve gölgeli saçak.
	root.add_child(_box(Vector3(15.2, 0.22, 1.15), Vector3(0, 10.18, -0.75), dark, 0.56, 0.16))
	root.add_child(_box(Vector3(12.8, 0.18, 0.90), Vector3(0, 13.36, 2.85), white_top, 0.42, 0.10))

	# Yan yolcu salonu cam dizileri gemiyi kutu görünümünden çıkarır.
	for side in [-1.0, 1.0]:
		for z in [-15.5, -12.5, -9.5, -6.5]:
			root.add_child(_glass(Vector3(0.07, 0.82, 2.05), Vector3(side * 9.95, 7.15, z)))
		root.add_child(_box(Vector3(0.10, 0.16, 12.2), Vector3(side * 10.02, 6.48, -11.0), Color(0.68,0.70,0.70), 0.36, 0.55))

func _tapered_body(bottom_width: float, top_width: float, bottom_depth: float, top_depth: float, height: float, center: Vector3, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y0: float = center.y - height * 0.5
	var y1: float = center.y + height * 0.5
	var bx: float = bottom_width * 0.5
	var bz: float = bottom_depth * 0.5
	var tx: float = top_width * 0.5
	var tz: float = top_depth * 0.5
	var p0 := Vector3(center.x - bx, y0, center.z - bz)
	var p1 := Vector3(center.x + bx, y0, center.z - bz)
	var p2 := Vector3(center.x + bx, y0, center.z + bz)
	var p3 := Vector3(center.x - bx, y0, center.z + bz)
	var p4 := Vector3(center.x - tx, y1, center.z - tz)
	var p5 := Vector3(center.x + tx, y1, center.z - tz)
	var p6 := Vector3(center.x + tx, y1, center.z + tz)
	var p7 := Vector3(center.x - tx, y1, center.z + tz)
	_quad(st, p0, p1, p5, p4)
	_quad(st, p1, p2, p6, p5)
	_quad(st, p2, p3, p7, p6)
	_quad(st, p3, p0, p4, p7)
	_quad(st, p4, p5, p6, p7)
	_quad(st, p3, p2, p1, p0)
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = _material(color, 0.36, 0.08)
	return node

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(size: Vector3, pos: Vector3, color: Color, roughness: float, metallic: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, roughness, metallic)
	return node

func _glass(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var node := _box(size, pos, Color(0.012,0.045,0.070,0.94), 0.09, 0.22)
	var mat := node.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return node
