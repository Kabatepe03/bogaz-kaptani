extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")
const TROJAN_HORSE := Vector2(40.15210, 26.40548)

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(24):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if scene.find_child("V22_Trojan_Horse", true, false) == null:
		_build_trojan_horse(scene)

func _build_trojan_horse(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V22_Trojan_Horse"
	root.global_position = GeoReference.to_local(TROJAN_HORSE) + Vector3(0.0, 1.3, 0.0)
	root.rotation_degrees.y = -18.0
	scene.add_child(root)

	var wood := _mat(Color(0.28, 0.16, 0.075), 0.90, 0.0)
	var dark_wood := _mat(Color(0.15, 0.085, 0.040), 0.94, 0.0)
	var iron := _mat(Color(0.08, 0.085, 0.088), 0.55, 0.42)

	# Generic Trojan-horse silhouette placed at the real waterfront location. It deliberately does
	# not copy the movie prop mesh; the goal is the instantly recognisable Çanakkale landmark cue.
	root.add_child(_box(Vector3(7.4, 3.7, 2.6), Vector3(0.0, 6.7, 0.0), wood))
	root.add_child(_box(Vector3(2.2, 5.7, 2.0), Vector3(2.3, 10.4, 0.0), wood, Vector3(0.0, 0.0, -18.0)))
	root.add_child(_box(Vector3(3.2, 2.1, 2.1), Vector3(3.5, 13.2, 0.0), wood))
	root.add_child(_box(Vector3(1.6, 0.7, 0.9), Vector3(5.6, 13.0, 0.0), dark_wood))
	for ear_z: float in [-0.62, 0.62]:
		root.add_child(_box(Vector3(0.45, 1.35, 0.32), Vector3(3.1, 14.55, ear_z), dark_wood, Vector3(0.0, 0.0, -12.0)))
	for leg_x: float in [-2.5, 2.0]:
		for leg_z: float in [-0.72, 0.72]:
			root.add_child(_box(Vector3(1.0, 5.8, 0.78), Vector3(leg_x, 3.0, leg_z), wood))
			root.add_child(_box(Vector3(1.9, 0.60, 1.0), Vector3(leg_x + 0.35, 0.25, leg_z), dark_wood))

	# Layered plank rhythm and visible fasteners stop the sculpture reading as one brown cuboid.
	for x: float in [-2.8, -1.4, 0.0, 1.4, 2.8]:
		root.add_child(_box(Vector3(0.10, 3.2, 2.72), Vector3(x, 6.7, 0.0), dark_wood))
	for y: float in [5.5, 6.7, 7.9]:
		root.add_child(_box(Vector3(7.55, 0.08, 2.72), Vector3(0.0, y, 0.0), dark_wood))
	for x: float in [-2.7, 0.0, 2.7]:
		for z: float in [-1.38, 1.38]:
			root.add_child(_cylinder(Vector3(x, 6.7, z), 0.10, 0.22, iron, 12, "z"))

	# Tail and mane.
	root.add_child(_box(Vector3(4.8, 0.55, 0.55), Vector3(-5.1, 7.6, 0.0), dark_wood, Vector3(0.0, 0.0, 24.0)))
	for y: float in [9.4, 10.4, 11.4, 12.4]:
		root.add_child(_box(Vector3(0.45, 0.75, 2.45), Vector3(1.55, y, 0.0), dark_wood))

	var label := Label3D.new()
	label.text = "ÇANAKKALE • TRUVA ATI"
	label.font_size = 44
	label.outline_size = 5
	label.pixel_size = 0.014
	label.position = Vector3(0.0, 16.2, 0.0)
	label.modulate = Color(0.92, 0.92, 0.86)
	root.add_child(label)

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(size: Vector3, pos: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation_degrees = rotation
	node.material_override = material
	return node

func _cylinder(pos: Vector3, radius: float, height: float, material: Material, segments: int, axis: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	node.mesh = mesh
	node.position = pos
	if axis == "z":
		node.rotation_degrees.x = 90.0
	node.material_override = material
	return node
