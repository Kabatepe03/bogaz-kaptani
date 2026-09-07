extends "res://scripts/v22_controller.gd"

const GeoReferenceV23 = preload("res://scripts/geo_reference.gd")
const V23WaterShader: Shader = preload("res://shaders/water_v23.gdshader")
const V23SkyShader: Shader = preload("res://shaders/sky_v23.gdshader")

const CHANNEL_LL: Array[Vector2] = [
	Vector2(40.2140, 26.4380),
	Vector2(40.1920, 26.4100),
	Vector2(40.1710, 26.3920),
	Vector2(40.1510, 26.3820),
	Vector2(40.1260, 26.3560)
]

var v23_timer := 0.0
var v23_sky_material: ShaderMaterial
var v23_sky: Sky
var v23_mooring_locked := false
var v23_mooring_position := Vector3.ZERO
var v23_mooring_yaw := 0.0
var v23_mooring_dock_name := ""

func _ready() -> void:
	super._ready()
	call_deferred("_install_v23")

func _process(delta: float) -> void:
	super._process(delta)
	v23_timer += delta
	if v23_timer >= 0.42:
		v23_timer = 0.0
		_retitle_v23(self)
		_update_v23_mooring_status()

func _update_ferry(delta: float) -> void:
	if v23_mooring_locked and ferry != null:
		throttle = 0.0
		engine_order = 0.0
		port_engine_order = 0.0
		starboard_engine_order = 0.0
		port_rpm = move_toward(port_rpm, 0.0, delta * 0.55)
		starboard_rpm = move_toward(starboard_rpm, 0.0, delta * 0.55)
		surge_mps = 0.0
		sway_mps = 0.0
		yaw_rate = 0.0
		ground_speed_kn = 0.0
		ferry.global_position.x = v23_mooring_position.x
		ferry.global_position.z = v23_mooring_position.z
		ferry.rotation.y = v23_mooring_yaw
		_apply_v20_wave_buoyancy(delta)
		return
	# v22's update calls _apply_v22_current_correction() virtually. V23 overrides that method below,
	# so the legacy radial field is replaced once rather than accidentally applying two corrections.
	super._update_ferry(delta)

func _reset_route() -> void:
	v23_mooring_locked = false
	v23_mooring_dock_name = ""
	super._reset_route()
	call_deferred("_validate_v23_spawn")

func _validate_v23_spawn() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	if V23WorldCollision != null and V23WorldCollision.has_method("_force_safe_spawn"):
		V23WorldCollision.call("_force_safe_spawn")

func _install_v23() -> void:
	for _frame: int in range(22):
		await get_tree().process_frame
	if v20_water_material != null:
		v20_water_material.shader = V23WaterShader
		v20_water_material.set_shader_parameter("sea_state", clampf(0.46 + wind_strength * 0.085, 0.46, 0.92))
		v20_water_material.set_shader_parameter("wave_height", clampf(0.58 + wind_strength * 0.065, 0.58, 0.94))
	_ensure_v21_environment()
	_update_v23_atmosphere_for_weather()
	_retitle_v23(self)
	_validate_v23_spawn()

# Overrides v22. v12 first adds its old radial current; this method removes that exact field and
# substitutes a centreline-following Dardanelles current. There is only one correction in V23.
func _apply_v22_current_correction(delta: float) -> void:
	if ferry == null or delta <= 0.0 or v23_mooring_locked:
		return
	var c_dock: Vector3 = GeoReferenceV23.to_local(GeoReferenceV23.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReferenceV23.to_local(GeoReferenceV23.ECEABAT_DOCK)
	var old_mid: Vector3 = (c_dock + e_dock) * 0.5
	var old_dist_mid: float = ferry.global_position.distance_to(old_mid)
	var old_central_factor: float = clampf(1.0 - old_dist_mid / 3200.0, 0.28, 1.0)
	var old_dir: Vector3 = Vector3(-0.10, 0.0, 0.995).normalized()
	var weather_factor: float = clampf(0.78 + current_strength * 0.55, 0.72, 1.35)
	var old_speed: float = (0.43 + 0.42 * old_central_factor) * weather_factor
	var old_velocity: Vector3 = old_dir * old_speed

	var best_distance := INF
	var best_direction := Vector3(0.0, 0.0, 1.0)
	for i in range(CHANNEL_LL.size() - 1):
		var a: Vector3 = GeoReferenceV23.to_local(CHANNEL_LL[i])
		var b: Vector3 = GeoReferenceV23.to_local(CHANNEL_LL[i + 1])
		var segment := b - a
		segment.y = 0.0
		var len_sq: float = maxf(segment.length_squared(), 0.001)
		var t: float = clampf((ferry.global_position - a).dot(segment) / len_sq, 0.0, 1.0)
		var closest := a + segment * t
		var d: float = ferry.global_position.distance_to(closest)
		if d < best_distance:
			best_distance = d
			best_direction = segment.normalized()

	var channel_factor: float = 1.0 - smoothstep(260.0, 1450.0, best_distance)
	var desired_speed: float = lerpf(0.24, 0.88, channel_factor) * weather_factor
	var dock_distance: float = minf(ferry.global_position.distance_to(c_dock), ferry.global_position.distance_to(e_dock))
	var harbour_relief: float = lerpf(0.38, 1.0, smoothstep(120.0, 650.0, dock_distance))
	desired_speed *= harbour_relief
	var desired_velocity: Vector3 = best_direction * desired_speed

	ferry.global_position += (desired_velocity - old_velocity) * delta

	var forward: Vector3 = -ferry.global_transform.basis.z
	var starboard: Vector3 = ferry.global_transform.basis.x
	var through_water: Vector3 = forward * surge_mps + starboard * sway_mps
	var wind_velocity: Vector3 = wind_vector * (wind_strength * 0.052)
	var corrected_ground: Vector3 = through_water + desired_velocity + wind_velocity
	ground_speed_kn = corrected_ground.length() / 0.514444
	if through_water.length() > 0.08 and corrected_ground.length() > 0.08:
		drift_angle_deg = rad_to_deg(acos(clampf(through_water.normalized().dot(corrected_ground.normalized()), -1.0, 1.0)))
	else:
		drift_angle_deg = 0.0

func _on_ramp_pressed() -> void:
	if ferry == null:
		return
	# Closing the ramp always releases the mooring lock first.
	if ramp_open:
		v23_mooring_locked = false
		v23_mooring_dock_name = ""
		super._on_ramp_pressed()
		return

	var info: Dictionary = _v23_mooring_info()
	var distance: float = float(info.get("distance", 9999.0))
	var longitudinal: float = float(info.get("longitudinal", 9999.0))
	var lateral: float = absf(float(info.get("lateral", 9999.0)))
	var heading_error: float = float(info.get("heading_error", 180.0))
	var speed_ok: bool = absf(ground_speed_kn) <= 0.75 and absf(surge_mps) <= 0.42 and absf(sway_mps) <= 0.25
	var engines_ok: bool = absf(engine_order) <= 0.08 and absf(port_rpm) <= 0.10 and absf(starboard_rpm) <= 0.10
	var pose_ok: bool = distance <= 92.0 and longitudinal >= 42.0 and longitudinal <= 88.0 and lateral <= 8.6 and heading_error <= 9.0
	if not (speed_ok and engines_ok and pose_ok):
		_show_v23_dock_message("RAMPA KİLİTLİ • ≤0.75 kn • motor boş • rıhtıma hizalan")
		return

	v23_mooring_locked = true
	v23_mooring_position = ferry.global_position
	v23_mooring_yaw = ferry.rotation.y
	v23_mooring_dock_name = str(info.get("dock_name", "RIHTIM"))
	throttle = 0.0
	engine_order = 0.0
	surge_mps = 0.0
	sway_mps = 0.0
	yaw_rate = 0.0
	super._on_ramp_pressed()
	_show_v23_dock_message("%s • BAĞLANDI • RAMPA AÇIK" % v23_mooring_dock_name)

func _v23_mooring_info() -> Dictionary:
	var c_dock: Vector3 = GeoReferenceV23.to_local(GeoReferenceV23.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReferenceV23.to_local(GeoReferenceV23.ECEABAT_DOCK)
	var use_canakkale: bool = ferry.global_position.distance_to(c_dock) <= ferry.global_position.distance_to(e_dock)
	var dock: Vector3 = c_dock if use_canakkale else e_dock
	var opposite: Vector3 = e_dock if use_canakkale else c_dock
	var seaward: Vector3 = opposite - dock
	seaward.y = 0.0
	seaward = seaward.normalized()
	var lateral_axis := Vector3(-seaward.z, 0.0, seaward.x)
	var rel: Vector3 = ferry.global_position - dock
	var longitudinal: float = rel.dot(seaward)
	var lateral: float = rel.dot(lateral_axis)
	var forward: Vector3 = -ferry.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var axis_alignment: float = absf(forward.dot(seaward))
	var heading_error: float = rad_to_deg(acos(clampf(axis_alignment, -1.0, 1.0)))
	return {
		"dock_name": "ÇANAKKALE" if use_canakkale else "ECEABAT",
		"distance": ferry.global_position.distance_to(dock),
		"longitudinal": longitudinal,
		"lateral": lateral,
		"heading_error": heading_error
	}

func _show_v23_dock_message(text_value: String) -> void:
	if dock_hint != null:
		dock_hint.text = text_value
		var parent: CanvasItem = dock_hint.get_parent() as CanvasItem
		if parent != null:
			parent.visible = true

func _update_v23_mooring_status() -> void:
	if v23_mooring_locked and captain_assist_label != null and not captain_assist_label.text.contains("BAĞLI"):
		captain_assist_label.text += "\n%s RIHTIM • BAĞLI" % v23_mooring_dock_name

func _apply_weather() -> void:
	super._apply_weather()
	if v20_water_material != null:
		v20_water_material.set_shader_parameter("sea_state", clampf(0.46 + wind_strength * 0.085, 0.46, 0.92))
		v20_water_material.set_shader_parameter("wave_height", clampf(0.58 + wind_strength * 0.065, 0.58, 0.94))
	_update_v23_atmosphere_for_weather()

func _ensure_v21_environment() -> void:
	if v23_sky_material == null:
		v23_sky_material = ShaderMaterial.new()
		v23_sky_material.shader = V23SkyShader
		v23_sky = Sky.new()
		v23_sky.sky_material = v23_sky_material
	for node: Node in find_children("*", "WorldEnvironment", true, false):
		if not (node is WorldEnvironment):
			continue
		var world := node as WorldEnvironment
		var env: Environment = world.environment
		if env == null:
			continue
		env.sky = v23_sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.76
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.98
		env.tonemap_white = 1.38
		env.adjustment_enabled = true
		env.adjustment_brightness = 0.99
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.02
		env.fog_enabled = true
		env.fog_density = 0.00010
		env.fog_light_color = Color(0.68, 0.73, 0.73)
		env.fog_sky_affect = 0.58
		env.glow_enabled = true
		env.glow_intensity = 0.10
		env.glow_bloom = 0.004

func _update_v23_atmosphere_for_weather() -> void:
	if v23_sky_material == null:
		return
	match weather_index:
		0:
			v23_sky_material.set_shader_parameter("cloud_amount", 0.30)
			v23_sky_material.set_shader_parameter("haze_amount", 0.38)
			v23_sky_material.set_shader_parameter("sun_elevation", 0.78)
			v23_sky_material.set_shader_parameter("zenith_color", Vector3(0.105, 0.285, 0.520))
			v23_sky_material.set_shader_parameter("mid_sky_color", Vector3(0.275, 0.505, 0.690))
			v23_sky_material.set_shader_parameter("horizon_color", Vector3(0.690, 0.755, 0.775))
		1:
			v23_sky_material.set_shader_parameter("cloud_amount", 0.58)
			v23_sky_material.set_shader_parameter("haze_amount", 0.47)
			v23_sky_material.set_shader_parameter("sun_elevation", 0.67)
		2:
			v23_sky_material.set_shader_parameter("cloud_amount", 0.76)
			v23_sky_material.set_shader_parameter("haze_amount", 0.92)
			v23_sky_material.set_shader_parameter("sun_elevation", 0.48)
			v23_sky_material.set_shader_parameter("zenith_color", Vector3(0.30, 0.39, 0.44))
			v23_sky_material.set_shader_parameter("mid_sky_color", Vector3(0.47, 0.54, 0.56))
			v23_sky_material.set_shader_parameter("horizon_color", Vector3(0.67, 0.69, 0.67))
		3:
			v23_sky_material.set_shader_parameter("cloud_amount", 0.34)
			v23_sky_material.set_shader_parameter("haze_amount", 0.42)
			v23_sky_material.set_shader_parameter("sun_elevation", 0.03)
			v23_sky_material.set_shader_parameter("zenith_color", Vector3(0.006, 0.018, 0.050))
			v23_sky_material.set_shader_parameter("mid_sky_color", Vector3(0.016, 0.040, 0.090))
			v23_sky_material.set_shader_parameter("horizon_color", Vector3(0.055, 0.075, 0.105))
	for node: Node in find_children("*", "WorldEnvironment", true, false):
		if node is WorldEnvironment:
			var env: Environment = (node as WorldEnvironment).environment
			if env != null:
				if weather_index == 2:
					env.fog_density = 0.00115
				elif weather_index == 3:
					env.fog_density = 0.00016
					env.ambient_light_energy = 0.22
				else:
					env.fog_density = 0.00010 + wind_strength * 0.000008
					env.ambient_light_energy = 0.76

func _update_v13_assist() -> void:
	super._update_v13_assist()
	if captain_assist_label != null:
		captain_assist_label.text = captain_assist_label.text.replace("V22 KAPTAN KÖPRÜSÜ", "V23 KAPTAN KÖPRÜSÜ")

func _retitle_v23(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.text = label.text.replace("V22 KAPTAN KÖPRÜSÜ", "V23 KAPTAN KÖPRÜSÜ")
		label.text = label.text.replace("V22 • ULTRA SİMÜLASYON", "V23 • ÇANAKKALE DİJİTAL İKİZ")
		label.text = label.text.replace("BOĞAZ KAPTANI V22", "BOĞAZ KAPTANI V23")
	for child: Node in node.get_children():
		_retitle_v23(child)
