extends "res://scripts/v11_controller.gd"

const V12WaterShader = preload("res://shaders/water.gdshader")
const V12_WORLD_PATH := "res://assets/v12/canakkale_real_world_v12.glb"

var engine_order: float = 0.0
var rudder_state: float = 0.0
var ground_speed_kn: float = 0.0
var drift_angle_deg: float = 0.0
var critical_roll_timer: float = 0.0
var v12_attribution: Label
var approach_root: Node3D

func _ready() -> void:
	super._ready()
	call_deferred("_install_v12_finish")

func _build_world() -> void:
	var real_world_resource: Resource = load(V12_WORLD_PATH)
	if not (real_world_resource is PackedScene):
		# Developer fallback only. CI generates the real-world GLB before Godot import.
		super._build_world()
		return

	var water := MeshInstance3D.new()
	water.name = "V12RealWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(15500.0, 15500.0)
	plane.subdivide_width = 210
	plane.subdivide_depth = 210
	water.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = V12WaterShader
	water.material_override = water_mat
	water.position.y = 0.0
	add_child(water)

	var real_world: Node = (real_world_resource as PackedScene).instantiate()
	real_world.name = "V12_REAL_CANAKKALE_WORLD"
	add_child(real_world)

	# Keep functional ferry terminals at the real terminal coordinates; v8/v10 visual passes decorate them.
	var canakkale: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	_build_harbor(canakkale, eceabat, "Çanakkale İskelesi")
	_build_harbor(eceabat, canakkale, "Eceabat İskelesi")

	# The hillside inscription remains a navigation landmark at its geographic reference position.
	_build_dur_yolcu(GeoReference.to_local(GeoReference.DUR_YOLCU))

func _install_v12_finish() -> void:
	await get_tree().process_frame
	_build_v12_attribution()
	_build_approach_markers()
	_retitle_legacy_ui(self)

func _retitle_legacy_ui(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.text.begins_with("V7 •"):
			label.text = "V12 • GERÇEK DÜNYA + GEMİ FİZİĞİ"
	for child: Node in node.get_children():
		_retitle_legacy_ui(child)

func _build_v12_attribution() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	v12_attribution = Label.new()
	v12_attribution.text = "© OpenStreetMap contributors • Terrain: AWS Open Data / Mapzen"
	v12_attribution.anchor_left = 0.31
	v12_attribution.anchor_top = 0.965
	v12_attribution.anchor_right = 0.69
	v12_attribution.anchor_bottom = 0.995
	v12_attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v12_attribution.add_theme_font_size_override("font_size", 12)
	v12_attribution.modulate = Color(0.88, 0.91, 0.92, 0.72)
	v12_attribution.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(v12_attribution)

func _build_approach_markers() -> void:
	approach_root = Node3D.new()
	approach_root.name = "V12ApproachMarkers"
	add_child(approach_root)
	_update_approach_markers()

func _update_approach_markers() -> void:
	if approach_root == null:
		return
	for child: Node in approach_root.get_children():
		child.queue_free()
	var target: Vector3 = eceabat_stop if route_forward else canakkale_stop
	var start: Vector3 = canakkale_stop if route_forward else eceabat_stop
	var inbound: Vector3 = (target - start).normalized()
	var starboard_direction: Vector3 = Vector3.UP.cross(inbound).normalized()
	var distances: Array[float] = [320.0, 220.0, 135.0, 75.0]
	var sides: Array[float] = [-1.0, 1.0]
	for distance_value: float in distances:
		var centre: Vector3 = target - inbound * distance_value
		for side: float in sides:
			var buoy_color: Color = Color(0.95, 0.16, 0.08) if side < 0.0 else Color(0.08, 0.88, 0.26)
			var marker: Node3D = _make_approach_buoy(buoy_color)
			marker.global_position = centre + starboard_direction * side * 22.0 + Vector3(0, 0.35, 0)
			approach_root.add_child(marker)

func _make_approach_buoy(color: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.55
	mesh.height = 1.7
	mesh.radial_segments = 14
	body.mesh = mesh
	body.position.y = 0.55
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.48
	mat.metallic = 0.08
	mat.emission_enabled = true
	mat.emission = color * 0.35
	mat.emission_energy_multiplier = 0.55
	body.material_override = mat
	root.add_child(body)
	var top := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	top.mesh = sphere
	top.position.y = 1.55
	top.material_override = mat
	root.add_child(top)
	return root

func _update_dynamic_roll() -> void:
	# v12 gives the captain a recovery window instead of an instant failure at one roll threshold.
	var delta: float = maxf(0.001, get_process_delta_time())
	var weather_roll: float = sin(Time.get_ticks_msec() * 0.00165) * wind_strength * 0.68
	load_roll_deg = base_load_roll + weather_roll
	var roll_abs: float = absf(load_roll_deg)
	var comfort_loss: float = roll_abs * 0.010 + absf(steer * velocity_knots) * 0.005 + wind_strength * 0.012
	comfort = clampf(comfort - comfort_loss + 0.018, 0.0, 100.0)
	if roll_abs > 13.0:
		damage = minf(100.0, damage + (roll_abs - 13.0) * 0.018 * delta)
	if roll_abs > 20.5:
		critical_roll_timer += delta
	else:
		critical_roll_timer = maxf(0.0, critical_roll_timer - delta * 1.5)
	if critical_roll_timer > 4.0 and not trip_finished:
		_finish_trip(false, "KONTROLSÜZ KRİTİK YATIŞ")

func _update_ferry(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return

	# Engine telegraph: a ferry engine does not jump instantly from stop to full thrust.
	engine_order = move_toward(engine_order, throttle, delta * (0.19 if absf(throttle) > absf(engine_order) else 0.28))
	rudder_state = move_toward(rudder_state, steer, delta * 0.72)

	var target_speed: float = engine_order * MAX_AHEAD_MPS if engine_order >= 0.0 else (-engine_order / 0.45) * -MAX_ASTERN_MPS
	var speed_error: float = target_speed - surge_mps
	var prop_gain: float = 0.105 + 0.055 * absf(engine_order)
	var prop_accel: float = clampf(speed_error * prop_gain, -0.22, 0.16)
	surge_mps += prop_accel * delta

	# Longitudinal resistance grows approximately with v²; low-speed coasting remains visible.
	var resistance: float = 0.0032 * surge_mps * absf(surge_mps)
	surge_mps -= resistance * delta
	if absf(engine_order) < 0.012:
		surge_mps = move_toward(surge_mps, 0.0, delta * 0.018)

	# Strong cross-flow damping gives a heavy displacement-hull feel instead of arcade strafing.
	var lateral_damping: float = 0.23 + absf(surge_mps) * 0.095
	sway_mps = move_toward(sway_mps, 0.0, lateral_damping * delta)

	var direction_sign: float = signf(surge_mps)
	if absf(surge_mps) < 0.18:
		direction_sign = signf(engine_order)
	var prop_wash: float = absf(engine_order) * 1.35
	var water_flow: float = absf(surge_mps) + prop_wash
	var rudder_authority: float = clampf((water_flow * water_flow) / 28.0, 0.0, 1.0)
	var desired_yaw_rate: float = rudder_state * direction_sign * deg_to_rad(1.48) * rudder_authority
	var yaw_accel: float = deg_to_rad(0.22 + water_flow * 0.075)
	yaw_rate = move_toward(yaw_rate, desired_yaw_rate, yaw_accel * delta)
	if absf(rudder_state) < 0.025:
		yaw_rate = move_toward(yaw_rate, 0.0, deg_to_rad(0.17 + absf(surge_mps) * 0.018) * delta)
	yaw_rate = clampf(yaw_rate, -deg_to_rad(1.55), deg_to_rad(1.55))

	ferry.rotation.y -= yaw_rate * delta
	var forward: Vector3 = -ferry.global_transform.basis.z
	var starboard: Vector3 = ferry.global_transform.basis.x

	# Turning produces stern slide and drift. Cross-flow damping then slowly removes it.
	sway_mps += -yaw_rate * surge_mps * 0.72 * delta
	sway_mps = clampf(sway_mps, -1.55, 1.55)

	# Dardanelles surface flow: generally toward the Aegean, stronger in the central channel,
	# reduced near shore. This is a navigation simulation field, not live hydrographic data.
	var c_dock: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var channel_mid: Vector3 = (c_dock + e_dock) * 0.5
	var dist_mid: float = ferry.global_position.distance_to(channel_mid)
	var central_factor: float = clampf(1.0 - dist_mid / 3200.0, 0.28, 1.0)
	var south_surface: Vector3 = Vector3(-0.10, 0.0, 0.995).normalized()
	var weather_current_factor: float = clampf(0.78 + current_strength * 0.55, 0.72, 1.35)
	var current_speed: float = (0.43 + 0.42 * central_factor) * weather_current_factor
	var current_velocity: Vector3 = south_surface * current_speed
	var wind_velocity: Vector3 = wind_vector * (wind_strength * 0.052)

	var through_water: Vector3 = forward * surge_mps + starboard * sway_mps
	var ground_velocity: Vector3 = through_water + current_velocity + wind_velocity
	ferry.global_position += ground_velocity * delta

	velocity_knots = surge_mps / 0.514444
	ground_speed_kn = ground_velocity.length() / 0.514444
	if through_water.length() > 0.08 and ground_velocity.length() > 0.08:
		drift_angle_deg = rad_to_deg(acos(clampf(through_water.normalized().dot(ground_velocity.normalized()), -1.0, 1.0)))
	else:
		drift_angle_deg = 0.0

	var turn_heel: float = rad_to_deg(yaw_rate) * surge_mps * 0.24
	var drift_heel: float = sway_mps * 0.72
	var wave_roll: float = sin(Time.get_ticks_msec() * 0.00122) * (0.24 + wind_strength * 0.12)
	var target_roll: float = deg_to_rad(base_load_roll + turn_heel + drift_heel + wave_roll)
	ferry.rotation.z = lerp_angle(ferry.rotation.z, target_roll, clampf(delta * 0.92, 0.0, 1.0))
	var pitch_wave: float = sin(Time.get_ticks_msec() * 0.00088) * (0.16 + wind_strength * 0.055)
	var accel_pitch: float = clampf(prop_accel * -1.6, -0.35, 0.35)
	ferry.rotation.x = lerp_angle(ferry.rotation.x, deg_to_rad(pitch_wave + accel_pitch), clampf(delta * 0.66, 0.0, 1.0))

func _reset_route() -> void:
	engine_order = 0.0
	rudder_state = 0.0
	ground_speed_kn = 0.0
	drift_angle_deg = 0.0
	critical_roll_timer = 0.0
	super._reset_route()
	_update_approach_markers()

func _on_route_pressed() -> void:
	super._on_route_pressed()
	_update_approach_markers()

func _update_v7_hud() -> void:
	super._update_v7_hud()
	if v7_status != null:
		v7_status.text += "\nYere göre %.1f kn   Akıntı sapması %.1f°   Motor emir %.0f%%" % [ground_speed_kn, drift_angle_deg, engine_order * 100.0]
