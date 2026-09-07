extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(14):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null or scene.find_child("V20_Eceabat_Hillside_Flag", true, false) != null:
		return

	var root := Node3D.new()
	root.name = "V20_Eceabat_Hillside_Flag"
	var dock: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	# Visually representative hillside placement above/behind Eceabat, viewed from the strait.
	root.position = dock + Vector3(-520.0, 106.0, -125.0)
	scene.add_child(root)
	root.look_at(GeoReference.to_local(GeoReference.CANAKKALE_DOCK) + Vector3(0.0, 35.0, 0.0), Vector3.UP)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.50, 0.53, 0.54)
	pole_mat.metallic = 0.72
	pole_mat.roughness = 0.27
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.16
	pole_mesh.bottom_radius = 0.22
	pole_mesh.height = 31.0
	pole_mesh.radial_segments = 20
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 15.5, 0.0)
	pole.material_override = pole_mat
	root.add_child(pole)

	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.80, 0.015, 0.025)
	red.roughness = 0.68
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.98, 0.98, 0.96)
	white.roughness = 0.58

	# Large, readable cloth silhouette. Thin enough to avoid the billboard/toy-card look.
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(31.0, 18.0, 0.16)
	cloth.mesh = cloth_mesh
	cloth.position = Vector3(15.4, 21.0, 0.0)
	cloth.material_override = red
	root.add_child(cloth)

	var crescent_outer := _disc(4.25, 0.19, white)
	crescent_outer.position = Vector3(10.8, 21.0, -0.13)
	crescent_outer.rotation_degrees.x = 90.0
	root.add_child(crescent_outer)
	var crescent_cut := _disc(3.55, 0.21, red)
	crescent_cut.position = Vector3(12.6, 21.0, -0.25)
	crescent_cut.rotation_degrees.x = 90.0
	root.add_child(crescent_cut)

	var star := _star(3.1, 1.25, white)
	star.position = Vector3(21.0, 21.0, -0.28)
	root.add_child(star)

func _disc(radius: float, depth: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 48
	node.mesh = mesh
	node.material_override = material
	return node

func _star(outer_radius: float, inner_radius: float, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3.ZERO
	for i: int in range(10):
		var a0: float = -PI * 0.5 + float(i) * PI / 5.0
		var a1: float = -PI * 0.5 + float(i + 1) * PI / 5.0
		var r0: float = outer_radius if i % 2 == 0 else inner_radius
		var r1: float = outer_radius if (i + 1) % 2 == 0 else inner_radius
		st.set_normal(Vector3(0.0, 0.0, -1.0))
		st.add_vertex(center)
		st.add_vertex(Vector3(cos(a1) * r1, sin(a1) * r1, 0.0))
		st.add_vertex(Vector3(cos(a0) * r0, sin(a0) * r0, 0.0))
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = material
	return node
