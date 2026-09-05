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

func _ready() -> void:
	_build_environment()
	_build_world()
	_build_ferry()
	_build_ui()

func _process(delta: float) -> void:
	if Input.is_action_pressed("throttle_up"):
		throttle = min(1.0, throttle + delta * 0.35)
	if Input.is_action_pressed("throttle_down"):
		throttle = max(-0.45, throttle - delta * 0.35)
	steer = Input.get_axis("steer_left", "steer_right")
	if Input.is_action_just_pressed("camera_next"):
		_next_camera()
	_update_ferry(delta)

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
	_build_landmark("Kilitbahir", GeoReference.to_local(GeoReference.KILITBAHIR), Color(0.47,0.39,0.28), Vector3(28,20,28))
	_build_landmark("Dur Yolcu", GeoReference.to_local(GeoReference.DUR_YOLCU), Color(0.88,0.88,0.82), Vector3(55,2,10))

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
		mat.albedo_color = Color(rng.randf_range(0.58,0.84), rng.randf_range(0.55,0.79), rng.randf_range(0.48,0.72))
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
	_add_camera(Vector3(0, 20, 42), Vector3(0, 7, 0), "Dis Kamera")
	_add_camera(Vector3(0, 11, 7), Vector3(0, 9, -18), "Kaptan")
	_add_camera(Vector3(0, 75, 70), Vector3(0, 0, 0), "Drone")
	_add_camera(Vector3(-22, 10, 4), Vector3(0, 4, 0), "Sol Borda")
	cameras[0].current = true

func _add_camera(offset: Vector3, target: Vector3, camera_name: String) -> void:
	var cam := Camera3D.new()
	cam.name = camera_name
	ferry.add_child(cam)
	cam.position = offset
	cam.look_at(target)
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
	ferry.rotation.x = lerp_angle(ferry.rotation.x, deg_to_rad(sin(Time.get_ticks_msec()*0.0011)*0.28), delta)

func _next_camera() -> void:
	cameras[camera_index].current = false
	camera_index = (camera_index + 1) % cameras.size()
	cameras[camera_index].current = true

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.035, 0.05, 0.72)
	panel.position = Vector2(24, 24)
	panel.size = Vector2(500, 112)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "BOĞAZ KAPTANI  •  ÇANAKKALE → ECEABAT\nW/S Gaz  •  A/D Dümen  •  C Kamera"
	title.position = Vector2(18, 15)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
