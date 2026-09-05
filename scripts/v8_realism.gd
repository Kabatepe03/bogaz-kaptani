extends Node

const TerrainRealismShader = preload("res://shaders/terrain_realism.gdshader")
const WakeShader = preload("res://shaders/wake.gdshader")

var ferry: Node3D
var wake_root: Node3D
var wake_material: ShaderMaterial
var radar_head: Node3D
var previous_ferry_position := Vector3.ZERO
var estimated_speed := 0.0

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	_enhance_environment(scene)
	_enhance_terrain(scene)
	_enhance_harbors(scene)
	var found := scene.find_child("Ferry", true, false)
	if found is Node3D:
		ferry = found as Node3D
		previous_ferry_position = ferry.global_position
		_enhance_ferry(ferry)
		_build_wake(scene)

func _process(delta: float) -> void:
	if radar_head != null:
		radar_head.rotate_y(delta * 1.8)
	if ferry == null or wake_root == null or delta <= 0.0:
		return
	var current := ferry.global_position
	estimated_speed = lerpf(estimated_speed, current.distance_to(previous_ferry_position) / delta, minf(delta * 3.0, 1.0))
	previous_ferry_position = current
	wake_root.global_position = Vector3(current.x, 0.16, current.z)
	wake_root.global_rotation = Vector3(0.0, ferry.global_rotation.y, 0.0)
	if wake_material != null:
		wake_material.set_shader_parameter("strength", clampf(estimated_speed / 7.0, 0.10, 0.96))

func _enhance_environment(scene: Node) -> void:
	var world := scene.find_child("WorldEnvironment", true, false)
	if world is WorldEnvironment and (world as WorldEnvironment).environment != null:
		var env := (world as WorldEnvironment).environment
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.02
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.06
		env.fog_density = minf(env.fog_density, 0.000085)
		env.fog_height = 34.0
		env.fog_height_density = 0.025
		env.glow_enabled = true
		env.glow_intensity = 0.55
		env.glow_bloom = 0.035

	var fill := DirectionalLight3D.new()
	fill.name = "V8SkyFill"
	fill.rotation_degrees = Vector3(-24.0, 145.0, 0.0)
	fill.light_color = Color(0.46, 0.60, 0.78)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	scene.add_child(fill)

func _enhance_terrain(scene: Node) -> void:
	var nodes := scene.find_children("*", "MeshInstance3D", true, false)
	for item in nodes:
		if not (item is MeshInstance3D):
			continue
		var mesh_node := item as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var size := mesh_node.mesh.get_aabb().size
		if size.x > 4400.0 and size.x < 8000.0 and size.z > 4400.0 and size.z < 8000.0:
			var mat := ShaderMaterial.new()
			mat.shader = TerrainRealismShader
			mesh_node.material_override = mat

func _enhance_harbors(scene: Node) -> void:
	for harbor_name in ["Çanakkale İskelesi", "Eceabat İskelesi"]:
		var found := scene.find_child(harbor_name, true, false)
		if found is Node3D:
			_decorate_harbor(found as Node3D, harbor_name)

func _decorate_harbor(harbor: Node3D, harbor_name: String) -> void:
	if harbor.find_child("V8HarborDetail", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V8HarborDetail"
	harbor.add_child(root)

	var concrete := Color(0.39, 0.40, 0.39)
	var asphalt := Color(0.095, 0.105, 0.11)
	var steel := Color(0.34, 0.36, 0.37)
	root.add_child(_box(Vector3(54.0, 1.1, 112.0), Vector3(0, 1.0, 84.0), concrete, 0.94, 0.0))
	root.add_child(_box(Vector3(44.0, 0.18, 104.0), Vector3(0, 1.64, 85.0), asphalt, 0.90, 0.02))
	root.add_child(_box(Vector3(1.0, 3.8, 112.0), Vector3(-27.0, -0.25, 84.0), concrete.darkened(0.12), 0.96, 0.0))
	root.add_child(_box(Vector3(1.0, 3.8, 112.0), Vector3(27.0, -0.25, 84.0), concrete.darkened(0.12), 0.96, 0.0))

	for lane_x in [-14.0, 0.0, 14.0]:
		for z in [46.0, 62.0, 78.0, 94.0, 110.0, 126.0]:
			root.add_child(_box(Vector3(0.22, 0.025, 7.5), Vector3(lane_x, 1.76, z), Color(0.90, 0.87, 0.62), 0.75, 0.0))

	for z in [37.0, 57.0, 77.0, 97.0, 117.0, 137.0]:
		root.add_child(_lamp_post(Vector3(-23.0, 1.65, z)))
		root.add_child(_lamp_post(Vector3(23.0, 1.65, z)))

	for z in [33.0, 58.0, 83.0, 108.0, 133.0]:
		for side in [-1.0, 1.0]:
			root.add_child(_cylinder(0.42, 0.82, Vector3(side * 25.0, 2.08, z), steel, 0.38, 0.52))

	var shelter := Node3D.new()
	shelter.position = Vector3(0, 1.8, 132.0)
	root.add_child(shelter)
	shelter.add_child(_box(Vector3(30.0, 0.35, 12.0), Vector3(0, 5.3, 0), Color(0.20, 0.23, 0.25), 0.52, 0.18))
	for x in [-13.5, -4.5, 4.5, 13.5]:
		shelter.add_child(_cylinder(0.16, 5.2, Vector3(x, 2.65, 0), steel, 0.36, 0.58))

	var sign := Label3D.new()
	sign.text = harbor_name.to_upper()
	sign.font_size = 54
	sign.outline_size = 6
	sign.modulate = Color(0.95, 0.96, 0.94)
	sign.position = Vector3(0, 8.6, 136.0)
	sign.rotation_degrees = Vector3(0, 180, 0)
	sign.pixel_size = 0.018
	root.add_child(sign)

	var car_colors := [Color(0.14,0.18,0.22), Color(0.72,0.74,0.72), Color(0.40,0.08,0.07), Color(0.06,0.20,0.44)]
	for i in range(8):
		var side := -1.0 if i % 2 == 0 else 1.0
		var parked := _simple_car(car_colors[i % car_colors.size()])
		parked.position = Vector3(side * 17.0, 1.82, 53.0 + float(i / 2) * 18.0)
		parked.rotation.y = 0.0 if side < 0.0 else PI
		root.add_child(parked)

func _enhance_ferry(ship: Node3D) -> void:
	if ship.find_child("V8RealismDetail", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V8RealismDetail"
	ship.add_child(root)

	root.add_child(_hull_side_band(Color(0.035, 0.075, 0.115), 0.55, 1.55, 1.007))
	root.add_child(_hull_side_band(Color(0.48, 0.055, 0.045), -1.55, -0.62, 1.005))

	for side in [-1.0, 1.0]:
		for z in [-23.0, -15.0, -7.0, 1.0, 9.0, 17.0, 25.0]:
			var fender := _cylinder(0.34, 2.3, Vector3(side * 11.48, 3.0, z), Color(0.025,0.028,0.030), 0.96, 0.02)
			root.add_child(fender)
		for z in [-15.0, 15.0]:
			root.add_child(_lifebuoy(Vector3(side * 11.58, 7.15, z), side))

	_add_ship_name(root, 1.0)
	_add_ship_name(root, -1.0)
	_add_navigation_lights(root)
	_add_deck_equipment(root)
	_add_bridge_glow(root)

func _hull_side_band(color: Color, y0: float, y1: float, scale_width: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := 52
	for i in range(sections - 1):
		var t0 := float(i) / float(sections - 1)
		var t1 := float(i + 1) / float(sections - 1)
		var z0 := lerpf(-31.5, 31.5, t0)
		var z1 := lerpf(-31.5, 31.5, t1)
		var w0 := 11.2 * maxf(0.08, pow(sin(PI * t0), 0.28)) * scale_width
		var w1 := 11.2 * maxf(0.08, pow(sin(PI * t1), 0.28)) * scale_width
		for side in [-1.0, 1.0]:
			var a := Vector3(side * w0, y0, z0)
			var b := Vector3(side * w0, y1, z0)
			var c := Vector3(side * w1, y0, z1)
			var d := Vector3(side * w1, y1, z1)
			for p in [a, b, c, c, b, d]:
				st.add_vertex(p)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	var mat := _material(color, 0.35, 0.18)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	return node

func _lifebuoy(pos: Vector3, side: float) -> Node3D:
	var group := Node3D.new()
	group.position = pos
	var orange := _cylinder(0.56, 0.16, Vector3.ZERO, Color(0.95,0.25,0.045), 0.52, 0.03)
	orange.rotation_degrees.z = 90.0
	group.add_child(orange)
	var center := _cylinder(0.29, 0.19, Vector3(side * 0.03, 0, 0), Color(0.90,0.91,0.88), 0.58, 0.0)
	center.rotation_degrees.z = 90.0
	group.add_child(center)
	return group

func _add_ship_name(root: Node3D, side: float) -> void:
	var label := Label3D.new()
	label.text = "BOĞAZ KAPTANI"
	label.font_size = 58
	label.outline_size = 5
	label.modulate = Color(0.055, 0.105, 0.145)
	label.pixel_size = 0.012
	label.position = Vector3(side * 11.48, 3.55, 4.5)
	label.rotation_degrees = Vector3(0, 90.0 if side > 0.0 else -90.0, 0)
	root.add_child(label)

func _add_navigation_lights(root: Node3D) -> void:
	var red := Color(1.0, 0.035, 0.02)
	var green := Color(0.02, 1.0, 0.22)
	root.add_child(_emissive_sphere(0.20, Vector3(-10.7, 12.0, -1.0), red, 5.0))
	root.add_child(_emissive_sphere(0.20, Vector3(10.7, 12.0, -1.0), green, 5.0))
	root.add_child(_emissive_sphere(0.18, Vector3(0.0, 20.6, 4.7), Color(1.0,0.92,0.68), 4.0))
	for entry in [[Vector3(-10.7,12.0,-1.0), red], [Vector3(10.7,12.0,-1.0), green], [Vector3(0.0,20.6,4.7), Color(1.0,0.88,0.62)]]:
		var light := OmniLight3D.new()
		light.position = entry[0]
		light.light_color = entry[1]
		light.light_energy = 0.42
		light.omni_range = 12.0
		light.shadow_enabled = false
		root.add_child(light)

func _add_deck_equipment(root: Node3D) -> void:
	var metal := Color(0.52, 0.55, 0.56)
	for side in [-1.0, 1.0]:
		for z in [-25.0, 25.0]:
			root.add_child(_cylinder(0.42, 0.62, Vector3(side * 7.8, 5.82, z), Color(0.16,0.17,0.18), 0.48, 0.46))
		root.add_child(_box(Vector3(1.2, 1.0, 2.4), Vector3(side * 8.8, 6.0, -19.0), metal, 0.56, 0.22))
		root.add_child(_box(Vector3(1.2, 1.0, 2.4), Vector3(side * 8.8, 6.0, 19.0), metal, 0.56, 0.22))

	var radar_base := Node3D.new()
	radar_base.position = Vector3(0, 20.8, 4.7)
	root.add_child(radar_base)
	radar_base.add_child(_cylinder(0.11, 1.2, Vector3(0,0.55,0), metal, 0.32, 0.62))
	radar_head = Node3D.new()
	radar_head.position = Vector3(0, 1.2, 0)
	radar_base.add_child(radar_head)
	radar_head.add_child(_box(Vector3(4.3, 0.14, 0.42), Vector3.ZERO, Color(0.88,0.90,0.90), 0.30, 0.35))

	for z in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		root.add_child(_cylinder(0.30, 0.85, Vector3(-9.4, 5.95, z), Color(0.74,0.75,0.72), 0.58, 0.18))
		root.add_child(_cylinder(0.30, 0.85, Vector3(9.4, 5.95, z), Color(0.74,0.75,0.72), 0.58, 0.18))

func _add_bridge_glow(root: Node3D) -> void:
	var warm := Color(1.0, 0.68, 0.34)
	for x in [-5.7, -2.9, 0.0, 2.9, 5.7]:
		root.add_child(_box_emissive(Vector3(2.2, 0.72, 0.07), Vector3(x, 9.05, -1.20), Color(0.055,0.10,0.13), warm, 0.42))

func _build_wake(scene: Node) -> void:
	wake_root = Node3D.new()
	wake_root.name = "V8Wake"
	scene.add_child(wake_root)
	wake_material = ShaderMaterial.new()
	wake_material.shader = WakeShader
	for entry in [[0.0, 18.0, 82.0], [-4.6, 11.0, 58.0], [4.6, 11.0, 58.0]]:
		var wake := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(entry[1], entry[2])
		plane.subdivide_width = 2
		plane.subdivide_depth = 12
		wake.mesh = plane
		wake.position = Vector3(entry[0], 0.0, 44.0 if entry[0] == 0.0 else 32.0)
		wake.material_override = wake_material
		wake_root.add_child(wake)

func _lamp_post(pos: Vector3) -> Node3D:
	var group := Node3D.new()
	group.position = pos
	group.add_child(_cylinder(0.10, 6.6, Vector3(0,3.3,0), Color(0.19,0.21,0.22), 0.38, 0.58))
	group.add_child(_box(Vector3(1.4, 0.10, 0.10), Vector3(0.55,6.35,0), Color(0.19,0.21,0.22), 0.38, 0.58))
	group.add_child(_emissive_sphere(0.20, Vector3(1.15,6.25,0), Color(1.0,0.84,0.54), 2.5))
	return group

func _simple_car(color: Color) -> Node3D:
	var group := Node3D.new()
	group.add_child(_box(Vector3(2.0,0.65,4.2), Vector3(0,0.34,0), color, 0.36, 0.12))
	group.add_child(_box(Vector3(1.6,0.62,2.0), Vector3(0,0.86,-0.15), color.lightened(0.06), 0.30, 0.10))
	var glass := _material(Color(0.018,0.05,0.07), 0.13, 0.18)
	for z in [-1.05, 0.95]:
		var window := _box(Vector3(1.45,0.40,0.07), Vector3(0,0.90,z), Color(0.018,0.05,0.07), 0.13, 0.18)
		window.material_override = glass
		group.add_child(window)
	for x in [-0.92, 0.92]:
		for z in [-1.25, 1.25]:
			var wheel := _cylinder(0.34, 0.22, Vector3(x,0.22,z), Color(0.025,0.025,0.025), 0.92, 0.02)
			wheel.rotation_degrees.z = 90.0
			group.add_child(wheel)
	return group

func _material(color: Color, roughness := 0.65, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(size: Vector3, pos: Vector3, color: Color, roughness := 0.65, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, roughness, metallic)
	return node

func _box_emissive(size: Vector3, pos: Vector3, color: Color, emission: Color, energy: float) -> MeshInstance3D:
	var node := _box(size, pos, color, 0.18, 0.10)
	var mat := node.material_override as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	return node

func _cylinder(radius: float, height: float, pos: Vector3, color: Color, roughness := 0.55, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, roughness, metallic)
	return node

func _emissive_sphere(radius: float, pos: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.position = pos
	var mat := _material(color, 0.18, 0.02)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	node.material_override = mat
	return node
