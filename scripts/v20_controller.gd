extends "res://scripts/v15_controller.gd"

const V20WaterShader = preload("res://shaders/water_v20.gdshader")
const V20VehicleFactory = preload("res://scripts/v20_vehicle_factory.gd")
const V20_WORLD_PATH := "res://assets/v12/canakkale_real_world_v12.glb"
const V20_DOCK_CENTER_OFFSET_M := 64.0

const ASPHALT_DIFF := "res://assets/v20/materials/asphalt_diff.png"
const ASPHALT_NORMAL := "res://assets/v20/materials/asphalt_normal.png"
const ASPHALT_ROUGH := "res://assets/v20/materials/asphalt_rough.png"
const CONCRETE_DIFF := "res://assets/v20/materials/concrete_diff.png"
const CONCRETE_NORMAL := "res://assets/v20/materials/concrete_normal.png"
const CONCRETE_ROUGH := "res://assets/v20/materials/concrete_rough.png"
const RAMP_DIFF := "res://assets/v20/materials/ramp_metal_diff.png"
const RAMP_NORMAL := "res://assets/v20/materials/ramp_metal_normal.png"
const RAMP_ROUGH := "res://assets/v20/materials/ramp_metal_rough.png"
const HARBOUR_HDRI := "res://assets/v20/lighting/harbour_day_2k.hdr"

var v20_water_material: ShaderMaterial
var v20_asphalt: StandardMaterial3D
var v20_concrete: StandardMaterial3D
var v20_ramp_metal: StandardMaterial3D

func _ready() -> void:
	super._ready()
	call_deferred("_install_v20_remaster")

func _build_world() -> void:
	var real_world_resource: Resource = load(V20_WORLD_PATH)
	if not (real_world_resource is PackedScene):
		super._build_world()
		return

	var water := MeshInstance3D.new()
	water.name = "V20Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(17000.0, 17000.0)
	plane.subdivide_width = 320
	plane.subdivide_depth = 320
	water.mesh = plane
	v20_water_material = ShaderMaterial.new()
	v20_water_material.shader = V20WaterShader
	water.material_override = v20_water_material
	water.position.y = 0.0
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	var real_world: Node = (real_world_resource as PackedScene).instantiate()
	real_world.name = "V20_REAL_CANAKKALE_WORLD"
	add_child(real_world)

	var canakkale: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	_build_v20_terminal(canakkale, eceabat, "ÇANAKKALE FERİBOT TERMİNALİ")
	_build_v20_terminal(eceabat, canakkale, "ECEABAT FERİBOT TERMİNALİ")
	_build_dur_yolcu(GeoReference.to_local(GeoReference.DUR_YOLCU))

func _build_real_docking_targets() -> void:
	var canakkale_terminal: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat_terminal: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var c_to_e: Vector3 = (eceabat_terminal - canakkale_terminal).normalized()
	canakkale_stop = canakkale_terminal + c_to_e * V20_DOCK_CENTER_OFFSET_M
	eceabat_stop = eceabat_terminal - c_to_e * V20_DOCK_CENTER_OFFSET_M
	canakkale_zone = _make_docking_zone(canakkale_stop, -c_to_e, "ÇANAKKALE YANAŞMA ALANI")
	eceabat_zone = _make_docking_zone(eceabat_stop, c_to_e, "ECEABAT YANAŞMA ALANI")
	add_child(canakkale_zone)
	add_child(eceabat_zone)

func _reset_route() -> void:
	super._reset_route()
	if ferry == null:
		return

	route_start = canakkale_stop if route_forward else eceabat_stop
	route_target = eceabat_stop if route_forward else canakkale_stop
	ferry.global_position = route_start + Vector3(0.0, 2.0, 0.0)
	ferry.look_at(route_target + Vector3(0.0, 2.0, 0.0), Vector3.UP)
	route_distance_m = ferry.global_position.distance_to(route_target)
	engine_order = 0.0
	rudder_state = 0.0
	surge_mps = 0.0
	sway_mps = 0.0
	yaw_rate = 0.0
	velocity_knots = 0.0
	ground_speed_kn = 0.0
	_update_dock_visibility()

func _add_cargo_vehicle(kind: String, x: float, z: float, color_index: int) -> void:
	var vehicle: Node3D = V20VehicleFactory.create_vehicle(kind, Vector3(x, 5.31, z), VEHICLE_COLORS[color_index % VEHICLE_COLORS.size()])
	cargo_root.add_child(vehicle)
	var weight: float = V20VehicleFactory.weight_for(kind)
	cargo_tons += weight
	if x < 0.0:
		port_tons += weight
	else:
		starboard_tons += weight

func _update_v15_water() -> void:
	if v20_water_material == null:
		var found: Node = find_child("V20Sea", true, false)
		if found is MeshInstance3D and (found as MeshInstance3D).material_override is ShaderMaterial:
			v20_water_material = (found as MeshInstance3D).material_override as ShaderMaterial
	if v20_water_material == null:
		return
	var state: float = clampf(0.32 + wind_strength * 0.10, 0.32, 0.86)
	var height: float = clampf(0.40 + wind_strength * 0.095, 0.40, 0.82)
	var time_speed: float = clampf(0.58 + wind_strength * 0.040, 0.58, 0.88)
	v20_water_material.set_shader_parameter("sea_state", state)
	v20_water_material.set_shader_parameter("wave_height", height)
	v20_water_material.set_shader_parameter("time_scale", time_speed)

func _install_v20_remaster() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_build_v20_materials()
	_apply_v20_terminal_materials()
	_install_v20_image_based_lighting()
	_retitle_v20(self)
	if v12_attribution != null:
		v12_attribution.text = "© OpenStreetMap contributors • Terrain: AWS/Mapzen • PBR/HDRI: Poly Haven CC0"
	_update_v14_nav()

func _build_v20_materials() -> void:
	v20_asphalt = _make_textured_material(ASPHALT_DIFF, ASPHALT_NORMAL, ASPHALT_ROUGH, Color(0.12,0.12,0.12), 5.5)
	v20_concrete = _make_textured_material(CONCRETE_DIFF, CONCRETE_NORMAL, CONCRETE_ROUGH, Color(0.46,0.45,0.42), 4.0)
	v20_ramp_metal = _make_textured_material(RAMP_DIFF, RAMP_NORMAL, RAMP_ROUGH, Color(0.31,0.33,0.34), 3.0)
	v20_ramp_metal.metallic = 0.50

func _make_textured_material(diff_path: String, normal_path: String, rough_path: String, fallback: Color, uv_scale: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback
	mat.roughness = 0.78
	mat.metallic = 0.02
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	if ResourceLoader.exists(diff_path):
		mat.albedo_texture = load(diff_path) as Texture2D
	if ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_scale = 0.60
		mat.normal_texture = load(normal_path) as Texture2D
	if ResourceLoader.exists(rough_path):
		mat.roughness_texture = load(rough_path) as Texture2D
	return mat

func _build_v20_terminal(origin: Vector3, opposite: Vector3, terminal_name: String) -> void:
	var root := Node3D.new()
	root.name = "V20_%s" % terminal_name
	root.global_position = origin
	root.look_at(opposite, Vector3.UP)
	add_child(root)

	var concrete := _flat_mat(Color(0.46,0.46,0.43), 0.88, 0.03)
	var asphalt := _flat_mat(Color(0.105,0.11,0.115), 0.88, 0.02)
	var steel := _flat_mat(Color(0.30,0.32,0.33), 0.42, 0.62)
	var glass := _flat_mat(Color(0.018,0.050,0.066), 0.12, 0.20)

	root.add_child(_v20_box(Vector3(55.0, 1.7, 42.0), Vector3(0, 0.72, 22.0), concrete, "ConcreteSurface"))
	root.add_child(_v20_box(Vector3(49.0, 0.16, 36.0), Vector3(0, 1.63, 23.0), asphalt, "AsphaltSurface"))
	root.add_child(_v20_box(Vector3(34.0, 0.18, 88.0), Vector3(0, 1.67, 82.0), asphalt, "AsphaltSurface"))

	root.add_child(_v20_box(Vector3(18.6, 0.30, 24.0), Vector3(0, 1.17, -9.0), steel, "RampSurface"))
	root.add_child(_v20_box(Vector3(0.44, 1.15, 25.0), Vector3(-9.45, 1.35, -9.0), steel, "RampSurface"))
	root.add_child(_v20_box(Vector3(0.44, 1.15, 25.0), Vector3(9.45, 1.35, -9.0), steel, "RampSurface"))
	for x in [-6.0, -2.0, 2.0, 6.0]:
		root.add_child(_v20_box(Vector3(0.10, 0.025, 21.0), Vector3(x, 1.34, -9.0), _flat_mat(Color(0.86,0.77,0.19),0.62,0.01), "LaneMark"))

	for side in [-1.0, 1.0]:
		for z in [-18.0, -30.0]:
			var dolphin := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.72
			mesh.bottom_radius = 0.86
			mesh.height = 4.8
			mesh.radial_segments = 24
			dolphin.mesh = mesh
			dolphin.position = Vector3(side * 13.8, 1.20, z)
			dolphin.material_override = steel
			root.add_child(dolphin)

	var terminal := Node3D.new()
	terminal.position = Vector3(21.0, 1.65, 69.0)
	root.add_child(terminal)
	terminal.add_child(_v20_box(Vector3(20.0, 5.4, 15.0), Vector3(0, 2.7, 0), concrete, "TerminalConcrete"))
	terminal.add_child(_v20_box(Vector3(20.4, 0.35, 15.4), Vector3(0, 5.58, 0), steel, "TerminalRoof"))
	for x in [-7.0,-3.5,0.0,3.5,7.0]:
		terminal.add_child(_v20_box(Vector3(2.4, 1.55, 0.10), Vector3(x, 3.05, -7.56), glass, "TerminalGlass"))

	for z in [10.0, 30.0, 52.0, 76.0, 100.0, 122.0]:
		root.add_child(_v20_lamp(Vector3(-15.0, 1.72, z)))
		root.add_child(_v20_lamp(Vector3(15.0, 1.72, z)))

	var label := Label3D.new()
	label.text = terminal_name
	label.font_size = 46
	label.outline_size = 6
	label.pixel_size = 0.017
	label.position = Vector3(0, 7.0, 37.0)
	label.modulate = Color(0.93,0.94,0.92)
	root.add_child(label)

func _apply_v20_terminal_materials() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		match mesh_node.name:
			"AsphaltSurface":
				mesh_node.material_override = v20_asphalt
			"ConcreteSurface", "TerminalConcrete":
				mesh_node.material_override = v20_concrete
			"RampSurface":
				mesh_node.material_override = v20_ramp_metal

func _install_v20_image_based_lighting() -> void:
	if not ResourceLoader.exists(HARBOUR_HDRI):
		return
	var texture := load(HARBOUR_HDRI) as Texture2D
	if texture == null:
		return
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = texture
	panorama.energy_multiplier = 0.62
	var sky := Sky.new()
	sky.sky_material = panorama
	for child in get_children():
		if child is WorldEnvironment:
			var world := child as WorldEnvironment
			if world.environment == null:
				continue
			var env := world.environment
			env.sky = sky
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.60, 0.72, 0.79)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			env.ambient_light_energy = 0.70

func _flat_mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _v20_box(size: Vector3, pos: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	return node

func _v20_lamp(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	var steel := _flat_mat(Color(0.18,0.19,0.20),0.40,0.55)
	var pole := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.12
	mesh.height = 7.0
	mesh.radial_segments = 14
	pole.mesh = mesh
	pole.position.y = 3.5
	pole.material_override = steel
	root.add_child(pole)
	var head := _v20_box(Vector3(1.25,0.14,0.28), Vector3(0.48,6.75,0), steel, "LampHead")
	root.add_child(head)
	var light := OmniLight3D.new()
	light.position = Vector3(0.88,6.55,0)
	light.light_color = Color(1.0,0.84,0.58)
	light.light_energy = 0.22
	light.omni_range = 9.0
	light.shadow_enabled = false
	root.add_child(light)
	return root

func _update_v14_nav() -> void:
	if v14_nav_label == null or ferry == null or cameras.is_empty():
		return
	var target_name: String = "ECEABAT" if route_forward else "ÇANAKKALE"
	var cam_name: String = "SÜRÜŞ"
	if camera_index >= 0 and camera_index < cameras.size():
		cam_name = String(cameras[camera_index].name)
	var second_line: String = "%.1f kn • Gaz %d%% • %s" % [absf(ground_speed_kn), int(round(throttle * 100.0)), cam_name]
	if camera_index == free_camera_index:
		second_line = "SERBEST 360° • sürükle: döndür • 2 parmak: zoom"
	v14_nav_label.text = "BOĞAZ KAPTANI V20 REMASTER • %s • %.0f m\n%s" % [target_name, maxf(route_distance_m, 0.0), second_line]

func _retitle_v20(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.text.begins_with("V15 •") or label.text.begins_with("V14 •") or label.text.begins_with("V13 •"):
			label.text = "V20 • REMASTER"
	for child in node.get_children():
		_retitle_v20(child)
