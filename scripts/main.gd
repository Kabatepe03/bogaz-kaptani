extends Node3D

const GeoReference = preload("res://scripts/geo_reference.gd")
const TerrainBuilder = preload("res://scripts/terrain_builder.gd")
const FerryFactory = preload("res://scripts/ferry_factory.gd")
const WaterShader = preload("res://shaders/water.gdshader")

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
	sky_mat.sky_top_color = Color(0.18, 0.43, 0.72)
	sky_mat.sky_horizon_color = Color(0.72, 0.82, 0.88)
	sky_mat.ground_bottom_color = Color(0.05, 0.08, 0.10)
	sky_mat.sun_angle_max = 20.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.67, 0.74, 0.78)
	env.fog_density = 0.00038
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 4200.0
	add_child(sun)

func _build_world() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12500.0, 12500.0)
	plane.subdivide_width = 220
	plane.subdivide_depth = 220
	water.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WaterShader
	water.material_override = water_mat
	water.position.y = 0.0
	add_child(water)

	var canakkale_center := GeoReference.to_local(GeoReference.CANAKKALE) + Vector3(1450, 0, 300)
	var eceabat_center := GeoReference.to_local(GeoReference.ECEABAT) + Vector3(-1200, 0, -150)
	add_child(TerrainBuilder.make_landmass(canakkale_center, Vector2(5200, 6200), 1.0, 104))
	add_child(TerrainBuilder.make_landmass(eceabat_center, Vector2(5200, 6200), -1.0, 208))
	_build_town(GeoReference.to_local(GeoReference.CANAKKALE), 34, 11)
	_build_town(GeoReference.to_local(GeoReference.ECEABAT), 22, 17)
	_build_landmark("Kilitbahir", GeoReference.to_local(GeoReference.KILITBAHIR), Color(0.47, 0.39, 0.28), Vector3(28, 20, 28))
	_build_landmark("Dur Yolcu", GeoReference.to_local(GeoReference.DUR_YOLCU), Color(0.88, 0.88, 0.82), Vector3(55, 2, 10))

func _build_town(center: Vector3, count: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(count):
		var building := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var floors := rng.randi_range(2, 6)
		mesh.size = Vector3(rng.randf_range(14, 28), floors * 3.1, rng.randf_range(14, 28))
		building.mesh = mesh
		building.position = center + Vector3(rng.randf_range(-650, 650), floors * 1.55 + 3.0, rng.randf_range(-800, 800))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(rng.randf_range(0.58, 0.84), rng.randf_range(0.55, 0.79), rng.randf_range(0.48, 0.72))
		mat.roughness = 0.82
		building.material_override = mat
		add_child(building)

func _build_landmark(label: String, pos: Vector3, color: Color, size: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos + Vector3(0, size.y * 0.5 + 4, 0)
	node.name = label
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	add_child(node)

func _build_ferry() -> void:
	ferry = FerryFactory.create_ferry()
	ferry.position = GeoReference.to_local(GeoReference.CANAKKALE) + Vector3(-60, 2.0, -80)
	ferry.rotation.y = deg_to_rad(-42.0)
	add_child(ferry)

	_add_camera(Vector3(0, 18, 38), Vector3(0, 4, 0), "Dis Kamera")
	_add_camera(Vector3(0, 11, 7), Vector3(0, 8, -22), "Kaptan")
	_add_camera(Vector3(0, 72, 62), Vector3(0, 0, 0), "Drone")
	_add_camera(Vector3(-28, 11, 5), Vector3(0, 5, 0), "Sol Borda")
	cameras[0].current = true

func _add_camera(offset: Vector3, target: Vector3, camera_name: String) -> void:
	var cam := Camera3D.new()
	cam.name = camera_name
	ferry.add_child(cam)
	cam.position = offset
	# look_at() global koordinat ister. Hedefi feribotun lokalinden globale ceviriyoruz.
	cam.look_at(ferry.to_global(target), Vector3.UP)
	cam.fov = 63.0
	cameras.append(cam)

func _update_ferry(delta: float) -> void:
	velocity_knots = lerp(velocity_knots, throttle * 14.5, delta * 0.38)
	ferry.rotation.y += steer * delta * (0.06 + abs(velocity_knots) * 0.004)
	var forward := -ferry.global_transform.basis.z
	ferry.global_position += forward * velocity_knots * 0.514444 * delta
	var wave_roll := sin(Time.get_ticks_msec() * 0.00125) * 0.35
	var target_roll := deg_to_rad(load_roll_deg + wave_roll - steer * velocity_knots * 0.18)
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
	panel.color = Color(0.02, 0.035, 0.05, 0.78)
	panel.anchor_left = 0.02
	panel.anchor_top = 0.025
	panel.anchor_right = 0.34
	panel.anchor_bottom = 0.16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(panel)

	var title := Label.new()
	title.text = "BOGAZ KAPTANI  •  CANAKKALE → ECEABAT\nMobil: ekrandaki tuslari kullan"
	title.anchor_left = 0.03
	title.anchor_top = 0.10
	title.anchor_right = 0.97
	title.anchor_bottom = 0.52
	title.add_theme_font_size_override("font_size", 22)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title)

	status_label = Label.new()
	status_label.anchor_left = 0.03
	status_label.anchor_top = 0.54
	status_label.anchor_right = 0.97
	status_label.anchor_bottom = 0.98
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_label)

	var left_button := _make_button(ui_root, "SOL", 0.025, 0.76, 0.155, 0.95)
	left_button.button_down.connect(_on_left_down)
	left_button.button_up.connect(_on_left_up)

	var right_button := _make_button(ui_root, "SAG", 0.17, 0.76, 0.30, 0.95)
	right_button.button_down.connect(_on_right_down)
	right_button.button_up.connect(_on_right_up)

	var gas_up_button := _make_button(ui_root, "GAZ +", 0.70, 0.76, 0.83, 0.95)
	gas_up_button.button_down.connect(_on_gas_up_down)
	gas_up_button.button_up.connect(_on_gas_up_up)

	var gas_down_button := _make_button(ui_root, "GAZ -", 0.845, 0.76, 0.975, 0.95)
	gas_down_button.button_down.connect(_on_gas_down_down)
	gas_down_button.button_up.connect(_on_gas_down_up)

	var stop_button := _make_button(ui_root, "DUR", 0.435, 0.82, 0.565, 0.95)
	stop_button.pressed.connect(_on_stop_pressed)

	var camera_button := _make_button(ui_root, "KAMERA", 0.825, 0.035, 0.975, 0.145)
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
	button.add_theme_font_size_override("font_size", 28)
	parent.add_child(button)
	return button

func _update_status() -> void:
	if status_label == null or cameras.is_empty():
		return
	var throttle_percent := int(round(throttle * 100.0))
	status_label.text = "Hiz: %.1f knot   Gaz: %d%%\nKamera: %s" % [velocity_knots, throttle_percent, cameras[camera_index].name]

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
