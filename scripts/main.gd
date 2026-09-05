extends Node3D

const GeoReference = preload("res://scripts/geo_reference.gd")
const TerrainBuilder = preload("res://scripts/terrain_builder.gd")
const FerryFactory = preload("res://scripts/ferry_factory.gd")
const WaterShader = preload("res://shaders/water.gdshader")

const LAND_EXTENT := Vector2(5200.0, 6200.0)
const CANAKKALE_SEED := 104
const ECEABAT_SEED := 208

var ferry: CharacterBody3D
var cameras: Array[Camera3D] = []
var camera_index := 0
var throttle := 0.0
var steer := 0.0
var velocity_knots := 0.0
var load_roll_deg := 0.0

var touch_throttle_up := false
var touch_throttle_down := false
var touch_steer_left := false
var touch_steer_right := false
var status_label: Label

var canakkale_terrain_center: Vector3
var eceabat_terrain_center: Vector3

func _ready() -> void:
	_build_environment()
	_build_world()
	_build_ferry()
	_build_ui()

func _process(delta: float) -> void:
	var throttle_up_pressed := Input.is_action_pressed("throttle_up") or touch_throttle_up
	var throttle_down_pressed := Input.is_action_pressed("throttle_down") or touch_throttle_down

	if throttle_up_pressed:
		throttle = min(1.0, throttle + delta * 0.35)
	if throttle_down_pressed:
		throttle = max(-0.45, throttle - delta * 0.35)

	var keyboard_steer := Input.get_axis("steer_left", "steer_right")
	var touch_steer := 0.0
	if touch_steer_left:
		touch_steer -= 1.0
	if touch_steer_right:
		touch_steer += 1.0
	steer = clamp(keyboard_steer + touch_steer, -1.0, 1.0)

	if Input.is_action_just_pressed("camera_next"):
		_next_camera()

	_update_ferry(delta)
	_update_status()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.36, 0.68)
	sky_mat.sky_horizon_color = Color(0.60, 0.78, 0.90)
	sky_mat.ground_bottom_color = Color(0.04, 0.07, 0.08)
	sky_mat.sun_angle_max = 16.0
	sky_mat.sun_curve = 0.12
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.74
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.70, 0.78)
	env.fog_density = 0.00012
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.light_energy = 1.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 4800.0
	add_child(sun)

func _build_world() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12500.0, 12500.0)
	plane.subdivide_width = 240
	plane.subdivide_depth = 240
	water.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WaterShader
	water.material_override = water_mat
	water.position.y = 0.0
	add_child(water)

	canakkale_terrain_center = GeoReference.to_local(GeoReference.CANAKKALE) + Vector3(1450, 0, 300)
	eceabat_terrain_center = GeoReference.to_local(GeoReference.ECEABAT) + Vector3(-1200, 0, -150)
	add_child(TerrainBuilder.make_landmass(canakkale_terrain_center, LAND_EXTENT, 1.0, CANAKKALE_SEED))
	add_child(TerrainBuilder.make_landmass(eceabat_terrain_center, LAND_EXTENT, -1.0, ECEABAT_SEED))

	var canakkale := GeoReference.to_local(GeoReference.CANAKKALE)
	var eceabat := GeoReference.to_local(GeoReference.ECEABAT)
	_build_harbor(canakkale, eceabat, "Çanakkale İskelesi")
	_build_harbor(eceabat, canakkale, "Eceabat İskelesi")
	_build_town(canakkale, 55, 11, 1.0, canakkale_terrain_center, 1.0, CANAKKALE_SEED)
	_build_town(eceabat, 38, 17, -1.0, eceabat_terrain_center, -1.0, ECEABAT_SEED)
	_build_forest(canakkale_terrain_center, 1.0, CANAKKALE_SEED, 210, 7001)
	_build_forest(eceabat_terrain_center, -1.0, ECEABAT_SEED, 180, 7002)
	_build_kilitbahir(GeoReference.to_local(GeoReference.KILITBAHIR))
	_build_dur_yolcu(GeoReference.to_local(GeoReference.DUR_YOLCU))
	_build_clock_tower(canakkale + Vector3(105, 0, 175))

func _mat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box_node(size: Vector3, pos: Vector3, color: Color, roughness := 0.7, metallic := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, roughness, metallic)
	return node

func _cylinder_node(radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color, 0.78, 0.02)
	return node

func _build_harbor(pos: Vector3, toward: Vector3, harbor_name: String) -> void:
	var root := Node3D.new()
	root.name = harbor_name
	root.position = pos
	var dir := toward - pos
	dir.y = 0.0
	dir = dir.normalized()
	root.rotation.y = atan2(dir.x, dir.z)
	add_child(root)
	root.add_child(_box_node(Vector3(30, 1.2, 82), Vector3(0, 1.4, 37), Color(0.32, 0.34, 0.34), 0.88, 0.02))
	root.add_child(_box_node(Vector3(18, 0.55, 34), Vector3(0, 1.95, -17), Color(0.16, 0.17, 0.18), 0.86, 0.04))
	root.add_child(_box_node(Vector3(42, 4.0, 18), Vector3(0, 3.0, 80), Color(0.72, 0.73, 0.70), 0.86, 0.0))
	for side in [-1.0, 1.0]:
		for z in [4.0, 22.0, 40.0, 58.0, 74.0]:
			root.add_child(_cylinder_node(0.32, 1.5, Vector3(side * 13.0, 2.7, z), Color(0.12, 0.13, 0.14)))
	for side in [-1.0, 1.0]:
		var rail := _box_node(Vector3(0.16, 0.16, 72), Vector3(side * 14.5, 2.75, 37), Color(0.66, 0.69, 0.70), 0.38, 0.35)
		root.add_child(rail)

func _build_town(center: Vector3, count: int, seed: int, land_sign: float, terrain_center: Vector3, terrain_sign: float, terrain_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(count):
		var width := rng.randf_range(13.0, 25.0)
		var depth := rng.randf_range(12.0, 24.0)
		var floors := rng.randi_range(2, 6)
		var px := center.x + land_sign * rng.randf_range(85.0, 850.0)
		var pz := center.z + rng.randf_range(-760.0, 760.0)
		var ground_y := TerrainBuilder.height_at(terrain_center, LAND_EXTENT, terrain_sign, terrain_seed, px, pz)
		if ground_y < 0.8:
			continue
		var base_color := Color(rng.randf_range(0.60, 0.88), rng.randf_range(0.58, 0.83), rng.randf_range(0.52, 0.76))
		var building := _make_building(Vector3(width, floors * 3.05, depth), base_color, i < 18)
		building.position = Vector3(px, ground_y + floors * 1.525, pz)
		building.rotation.y = rng.randf_range(-0.18, 0.18)
		add_child(building)

func _make_building(size: Vector3, color: Color, detailed: bool) -> Node3D:
	var group := Node3D.new()
	group.add_child(_box_node(size, Vector3.ZERO, color, 0.88, 0.0))
	group.add_child(_box_node(Vector3(size.x + 0.7, 0.35, size.z + 0.7), Vector3(0, size.y * 0.5 + 0.18, 0), Color(0.36, 0.31, 0.27), 0.92, 0.0))
	if detailed:
		var dark := Color(0.035, 0.070, 0.085)
		for floor_y in range(1, int(size.y / 3.05)):
			var y := -size.y * 0.5 + float(floor_y) * 3.05 + 1.2
			group.add_child(_box_node(Vector3(size.x * 0.72, 0.75, 0.12), Vector3(0, y, -size.z * 0.505), dark, 0.18, 0.10))
			group.add_child(_box_node(Vector3(size.x * 0.72, 0.75, 0.12), Vector3(0, y, size.z * 0.505), dark, 0.18, 0.10))
		group.add_child(_box_node(Vector3(size.x * 0.82, 0.22, 1.0), Vector3(0, -size.y * 0.12, -size.z * 0.54), Color(0.44, 0.45, 0.44), 0.74, 0.02))
	return group

func _build_forest(terrain_center: Vector3, terrain_sign: float, terrain_seed: int, count: int, random_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 3.8
	trunk_mesh.radial_segments = 6
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.15
	canopy_mesh.bottom_radius = 2.1
	canopy_mesh.height = 5.4
	canopy_mesh.radial_segments = 7

	var trunk_multi := MultiMesh.new()
	trunk_multi.transform_format = MultiMesh.TRANSFORM_3D
	trunk_multi.mesh = trunk_mesh
	trunk_multi.instance_count = count
	var canopy_multi := MultiMesh.new()
	canopy_multi.transform_format = MultiMesh.TRANSFORM_3D
	canopy_multi.mesh = canopy_mesh
	canopy_multi.instance_count = count

	for i in range(count):
		var lx := rng.randf_range(-LAND_EXTENT.x * 0.42, LAND_EXTENT.x * 0.42)
		var lz := rng.randf_range(-LAND_EXTENT.y * 0.42, LAND_EXTENT.y * 0.42)
		var wx := terrain_center.x + lx
		var wz := terrain_center.z + lz
		var y := TerrainBuilder.height_at(terrain_center, LAND_EXTENT, terrain_sign, terrain_seed, wx, wz)
		var scale := rng.randf_range(0.75, 1.35)
		trunk_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(scale, scale, scale)), Vector3(wx, y + 1.9 * scale, wz)))
		canopy_multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(scale, scale, scale)), Vector3(wx, y + 5.0 * scale, wz)))

	var trunks := MultiMeshInstance3D.new()
	trunks.multimesh = trunk_multi
	trunks.material_override = _mat(Color(0.23, 0.15, 0.09), 0.95, 0.0)
	add_child(trunks)
	var canopies := MultiMeshInstance3D.new()
	canopies.multimesh = canopy_multi
	canopies.material_override = _mat(Color(0.10, 0.25, 0.08), 0.93, 0.0)
	add_child(canopies)

func _build_kilitbahir(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Kilitbahir Kalesi"
	root.position = pos + Vector3(0, 5.0, 0)
	add_child(root)
	var stone := Color(0.43, 0.36, 0.27)
	root.add_child(_cylinder_node(9.5, 24.0, Vector3(0, 12, 0), stone))
	for p in [Vector3(-13, 7, 0), Vector3(13, 7, 0), Vector3(0, 7, -13)]:
		root.add_child(_cylinder_node(6.0, 14.0, p, stone.lightened(0.04)))
	root.add_child(_box_node(Vector3(26, 8, 5), Vector3(0, 5, -7.5), stone, 0.95, 0.0))
	root.add_child(_box_node(Vector3(5, 8, 24), Vector3(-7.5, 5, 0), stone, 0.95, 0.0))
	root.add_child(_box_node(Vector3(5, 8, 24), Vector3(7.5, 5, 0), stone, 0.95, 0.0))

func _build_dur_yolcu(pos: Vector3) -> void:
	var label := Label3D.new()
	label.name = "Dur Yolcu"
	label.text = "DUR YOLCU"
	label.font_size = 96
	label.outline_size = 6
	label.modulate = Color(0.95, 0.95, 0.90)
	label.position = pos + Vector3(0, 44, 0)
	label.rotation_degrees = Vector3(-8, 120, 0)
	label.scale = Vector3(0.32, 0.32, 0.32)
	add_child(label)

func _build_clock_tower(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Çanakkale Saat Kulesi"
	root.position = pos
	add_child(root)
	var stone := Color(0.69, 0.61, 0.48)
	root.add_child(_box_node(Vector3(7.5, 4.2, 7.5), Vector3(0, 2.1, 0), stone, 0.92, 0.0))
	root.add_child(_box_node(Vector3(6.0, 7.5, 6.0), Vector3(0, 7.8, 0), stone.lightened(0.04), 0.90, 0.0))
	root.add_child(_box_node(Vector3(4.7, 6.8, 4.7), Vector3(0, 14.9, 0), stone.lightened(0.08), 0.88, 0.0))
	root.add_child(_box_node(Vector3(5.2, 0.5, 5.2), Vector3(0, 18.6, 0), Color(0.28,0.24,0.20), 0.86, 0.0))

func _build_ferry() -> void:
	ferry = FerryFactory.create_ferry()
	ferry.position = GeoReference.to_local(GeoReference.CANAKKALE) + Vector3(-60, 2.0, -80)
	ferry.rotation.y = deg_to_rad(-42.0)
	add_child(ferry)

	_add_camera(Vector3(0, 13, 31), Vector3(0, 5.0, 0), "Dış Kamera")
	_add_camera(Vector3(0, 9.5, 1.0), Vector3(0, 8.3, -26), "Kaptan")
	_add_camera(Vector3(0, 58, 53), Vector3(0, 1, 0), "Drone")
	_add_camera(Vector3(-24, 10, 7), Vector3(0, 5, 0), "Sol Borda")
	cameras[0].current = true

func _add_camera(offset: Vector3, target: Vector3, camera_name: String) -> void:
	var cam := Camera3D.new()
	cam.name = camera_name
	ferry.add_child(cam)
	cam.position = offset
	cam.look_at(ferry.to_global(target), Vector3.UP)
	cam.fov = 58.0
	cameras.append(cam)

func _update_ferry(delta: float) -> void:
	velocity_knots = lerp(velocity_knots, throttle * 14.5, delta * 0.38)
	# Godot Y dönüş yönü ekrandaki dümen hissine ters geldiği için işareti çevirdik.
	ferry.rotation.y -= steer * delta * (0.06 + abs(velocity_knots) * 0.004)
	var forward := -ferry.global_transform.basis.z
	ferry.global_position += forward * velocity_knots * 0.514444 * delta
	var wave_roll := sin(Time.get_ticks_msec() * 0.00125) * 0.35
	var target_roll := deg_to_rad(load_roll_deg + wave_roll + steer * velocity_knots * 0.18)
	ferry.rotation.z = lerp_angle(ferry.rotation.z, target_roll, delta * 1.1)
	ferry.rotation.x = lerp_angle(ferry.rotation.x, deg_to_rad(sin(Time.get_ticks_msec() * 0.0011) * 0.28), delta)

func _next_camera() -> void:
	if cameras.is_empty():
		return
	cameras[camera_index].current = false
	camera_index = (camera_index + 1) % cameras.size()
	cameras[camera_index].current = true
	_update_status()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var ui_root := Control.new()
	ui_root.anchor_right = 1.0
	ui_root.anchor_bottom = 1.0
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)

	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.025, 0.035, 0.73)
	panel.anchor_left = 0.018
	panel.anchor_top = 0.025
	panel.anchor_right = 0.31
	panel.anchor_bottom = 0.18
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(panel)

	var title := Label.new()
	title.text = "BOĞAZ KAPTANI  •  ÇANAKKALE → ECEABAT"
	title.anchor_left = 0.04
	title.anchor_top = 0.08
	title.anchor_right = 0.97
	title.anchor_bottom = 0.42
	title.add_theme_font_size_override("font_size", 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	status_label = Label.new()
	status_label.anchor_left = 0.04
	status_label.anchor_top = 0.45
	status_label.anchor_right = 0.97
	status_label.anchor_bottom = 0.96
	status_label.add_theme_font_size_override("font_size", 19)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)

	var left_button := _make_button(ui_root, "SOL", 0.025, 0.76, 0.145, 0.95)
	left_button.button_down.connect(_on_left_down)
	left_button.button_up.connect(_on_left_up)

	var right_button := _make_button(ui_root, "SAĞ", 0.16, 0.76, 0.28, 0.95)
	right_button.button_down.connect(_on_right_down)
	right_button.button_up.connect(_on_right_up)

	var gas_up_button := _make_button(ui_root, "GAZ +", 0.72, 0.76, 0.84, 0.95)
	gas_up_button.button_down.connect(_on_gas_up_down)
	gas_up_button.button_up.connect(_on_gas_up_up)

	var gas_down_button := _make_button(ui_root, "GAZ -", 0.855, 0.76, 0.975, 0.95)
	gas_down_button.button_down.connect(_on_gas_down_down)
	gas_down_button.button_up.connect(_on_gas_down_up)

	var stop_button := _make_button(ui_root, "DUR", 0.44, 0.82, 0.56, 0.95)
	stop_button.pressed.connect(_on_stop_pressed)

	var camera_button := _make_button(ui_root, "KAMERA", 0.84, 0.035, 0.975, 0.155)
	camera_button.pressed.connect(_on_camera_pressed)

	_update_status()

func _make_button(parent: Control, text_value: String, left: float, top: float, right: float, bottom: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.anchor_left = left
	button.anchor_top = top
	button.anchor_right = right
	button.anchor_bottom = bottom
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	parent.add_child(button)
	return button

func _update_status() -> void:
	if status_label == null or cameras.is_empty():
		return
	var throttle_percent := int(round(throttle * 100.0))
	status_label.text = "Hız %.1f kn  •  Gaz %d%%\n%s" % [velocity_knots, throttle_percent, cameras[camera_index].name]

func _on_left_down() -> void:
	touch_steer_left = true

func _on_left_up() -> void:
	touch_steer_left = false

func _on_right_down() -> void:
	touch_steer_right = true

func _on_right_up() -> void:
	touch_steer_right = false

func _on_gas_up_down() -> void:
	touch_throttle_up = true

func _on_gas_up_up() -> void:
	touch_throttle_up = false

func _on_gas_down_down() -> void:
	touch_throttle_down = true

func _on_gas_down_up() -> void:
	touch_throttle_down = false

func _on_stop_pressed() -> void:
	touch_throttle_up = false
	touch_throttle_down = false
	throttle = 0.0

func _on_camera_pressed() -> void:
	_next_camera()
