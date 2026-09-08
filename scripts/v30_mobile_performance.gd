extends Node

const MobileWaterShader = preload("res://shaders/water_v30_safe.gdshader")

var _scene: Node
var _stress_samples := 0
var _recovery_samples := 0
var _reduced_detail := false
var _timer := 0.0

func _ready() -> void:
	Engine.max_fps = 60
	call_deferred("_install")

func _process(delta: float) -> void:
	if _scene == null:
		return
	_timer += delta
	if _timer < 2.0:
		return
	_timer = 0.0
	_update_adaptive_detail()

func _install() -> void:
	for _frame: int in range(36):
		await get_tree().process_frame
	_scene = get_tree().current_scene
	if _scene == null:
		return
	_disable_duplicate_water_layers()
	_install_safe_water()
	_tune_environment()
	_tune_geometry(_scene)
	_hide_expensive_duplicate_layers()

func _disable_duplicate_water_layers() -> void:
	# V30.0 accumulated several wake/foam/water overlays from older versions. On some Android GPUs
	# one of those layers rendered as a giant white surface. Keep exactly one ocean mesh.
	for node: Node in _scene.find_children("*", "GeometryInstance3D", true, false):
		if not (node is GeometryInstance3D):
			continue
		var geom: GeometryInstance3D = node as GeometryInstance3D
		var lower_name: String = geom.name.to_lower()
		if lower_name == "v20sea":
			geom.visible = true
			continue
		if "wake" in lower_name or "foam" in lower_name or "waterlinewash" in lower_name or "bowbreaker" in lower_name:
			geom.visible = false
		elif ("water" in lower_name or "sea" in lower_name) and not ("marine" in lower_name):
			geom.visible = false

func _install_safe_water() -> void:
	var water_node: Node = _scene.find_child("V20Sea", true, false)
	if not (water_node is MeshInstance3D):
		water_node = _scene.find_child("V12RealWater", true, false)
	if not (water_node is MeshInstance3D):
		return
	var water: MeshInstance3D = water_node as MeshInstance3D
	water.visible = true
	if water.mesh is PlaneMesh:
		var plane: PlaneMesh = water.mesh as PlaneMesh
		plane.subdivide_width = 96
		plane.subdivide_depth = 96
	var material := ShaderMaterial.new()
	material.shader = MobileWaterShader
	material.set_shader_parameter("deep_color", Vector3(0.010, 0.075, 0.115))
	material.set_shader_parameter("mid_color", Vector3(0.018, 0.125, 0.175))
	material.set_shader_parameter("horizon_color", Vector3(0.090, 0.245, 0.310))
	material.set_shader_parameter("wave_height", 0.30)
	material.set_shader_parameter("time_scale", 0.75)
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scene.set("v20_water_material", material)

func _tune_environment() -> void:
	RenderingServer.set_default_clear_color(Color(0.36, 0.55, 0.67))
	for node: Node in _scene.find_children("*", "WorldEnvironment", true, false):
		if not (node is WorldEnvironment):
			continue
		var world: WorldEnvironment = node as WorldEnvironment
		var env: Environment = world.environment
		if env == null:
			continue
		env.ambient_light_energy = minf(env.ambient_light_energy, 0.44)
		env.tonemap_exposure = 0.72
		env.tonemap_white = 1.45
		env.adjustment_enabled = true
		env.adjustment_brightness = 0.86
		env.adjustment_contrast = 1.10
		env.adjustment_saturation = 1.09
		env.ssao_enabled = false
		env.glow_enabled = false
		env.fog_enabled = true
		env.fog_density = 0.00010
		env.fog_light_color = Color(0.50, 0.62, 0.68)
		env.fog_sky_affect = 0.30

	for node: Node in _scene.find_children("*", "DirectionalLight3D", true, false):
		if not (node is DirectionalLight3D):
			continue
		var sun: DirectionalLight3D = node as DirectionalLight3D
		sun.light_energy = minf(sun.light_energy, 0.72)
		if sun.shadow_enabled:
			sun.directional_shadow_max_distance = 2400.0
			sun.shadow_bias = 0.055
			sun.shadow_normal_bias = 1.05

	for node: Node in _scene.find_children("*", "Camera3D", true, false):
		if node is Camera3D:
			var camera: Camera3D = node as Camera3D
			camera.near = maxf(camera.near, 0.18)
			camera.far = minf(camera.far, 8500.0)

func _tune_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		var geom: GeometryInstance3D = node as GeometryInstance3D
		var n: String = geom.name.to_lower()
		if "facadewindows" in n or "balcon" in n or "storefront" in n:
			geom.visibility_range_end = 1750.0
			geom.visibility_range_end_margin = 160.0
			geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif "streetlight" in n or "shore_rock" in n or "fender" in n:
			geom.visibility_range_end = 1300.0
			geom.visibility_range_end_margin = 120.0
			geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif "road" in n or "sidewalk" in n or "curb" in n or "marking" in n:
			geom.visibility_range_end = 2900.0
			geom.visibility_range_end_margin = 200.0
			geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif "v22_foreground" in n or "v20_ultra_nature" in n or "scrub" in n:
			geom.visibility_range_end = 3300.0
			geom.visibility_range_end_margin = 260.0
			geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif "osm_buildings" in n:
			geom.visibility_range_end = 5800.0
			geom.visibility_range_end_margin = 400.0
	for child: Node in node.get_children():
		_tune_geometry(child)

func _hide_expensive_duplicate_layers() -> void:
	for name: String in ["V30_OSM_CC0_VEGETATION", "V20CanakkalePhotoPass", "V20EceabatPhotoPass"]:
		var node: Node = _scene.find_child(name, true, false)
		if node is Node3D:
			(node as Node3D).visible = false

func _update_adaptive_detail() -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	if fps > 0.0 and fps < 34.0:
		_stress_samples += 1
		_recovery_samples = 0
	elif fps >= 50.0:
		_recovery_samples += 1
		_stress_samples = 0
	else:
		_stress_samples = maxi(0, _stress_samples - 1)
		_recovery_samples = maxi(0, _recovery_samples - 1)

	if not _reduced_detail and _stress_samples >= 2:
		_reduced_detail = true
		_set_secondary_detail(false)
	elif _reduced_detail and _recovery_samples >= 4:
		_reduced_detail = false
		_set_secondary_detail(true)

func _set_secondary_detail(show: bool) -> void:
	if _scene == null:
		return
	for node: Node in _scene.find_children("*", "GeometryInstance3D", true, false):
		if not (node is GeometryInstance3D):
			continue
		var geom: GeometryInstance3D = node as GeometryInstance3D
		var n: String = geom.name.to_lower()
		if "balconyrail" in n or "streetlight" in n or "shore_rock" in n or "dryscrub" in n:
			geom.visible = show
