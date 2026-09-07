extends "res://scripts/v21_controller.gd"

var port_engine_order: float = 0.0
var starboard_engine_order: float = 0.0
var port_rpm: float = 0.0
var starboard_rpm: float = 0.0
var v22_telemetry: Label
var v22_status_timer: float = 0.0

func _ready() -> void:
	super._ready()
	call_deferred("_install_v22")

func _process(delta: float) -> void:
	super._process(delta)
	v22_status_timer += delta
	if v22_status_timer >= 0.16:
		v22_status_timer = 0.0
		_update_v22_telemetry()
		_retitle_v22(self)

func _update_ferry(delta: float) -> void:
	super._update_ferry(delta)
	_apply_v22_current_correction(delta)
	_apply_v22_twin_screw(delta)
	_apply_v22_berth_contact(delta)

func _apply_v22_current_correction(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	# V12 used distance to one midpoint, which made current strength radially symmetric. V22 keeps
	# the inherited value for compatibility, then replaces it with a three-segment Strait field.
	var c_dock: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var old_mid: Vector3 = (c_dock + e_dock) * 0.5
	var old_dist: float = ferry.global_position.distance_to(old_mid)
	var old_factor: float = clampf(1.0 - old_dist / 3200.0, 0.28, 1.0)
	var weather_factor: float = clampf(0.78 + current_strength * 0.55, 0.72, 1.35)
	var old_velocity: Vector3 = Vector3(-0.10, 0.0, 0.995).normalized() * ((0.43 + 0.42 * old_factor) * weather_factor)

	var north: Vector3 = GeoReference.to_local(Vector2(40.2065, 26.3515))
	var centre: Vector3 = GeoReference.to_local(Vector2(40.1665, 26.3865))
	var south: Vector3 = GeoReference.to_local(Vector2(40.1265, 26.4260))
	var p: Vector3 = ferry.global_position
	var d1: float = _distance_xz_to_segment(p, north, centre)
	var d2: float = _distance_xz_to_segment(p, centre, south)
	var channel_distance: float = minf(d1, d2)
	var channel_factor: float = clampf(1.0 - channel_distance / 1150.0, 0.16, 1.0)
	var desired_direction: Vector3 = south - north
	desired_direction.y = 0.0
	desired_direction = desired_direction.normalized()
	var desired_speed: float = (0.30 + 0.58 * channel_factor) * weather_factor
	# Near the ferry terminals the flow is softened to make berth manoeuvres controllable without
	# removing the cross-current the player has to anticipate on approach.
	var berth_distance: float = minf(p.distance_to(c_dock), p.distance_to(e_dock))
	var berth_softening: float = lerpf(0.62, 1.0, clampf(berth_distance / 420.0, 0.0, 1.0))
	var desired_velocity: Vector3 = desired_direction * desired_speed * berth_softening
	ferry.global_position += (desired_velocity - old_velocity) * delta

func _distance_xz_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var pa := Vector2(p.x - a.x, p.z - a.z)
	var ba := Vector2(b.x - a.x, b.z - a.z)
	var denom: float = maxf(ba.length_squared(), 0.001)
	var t: float = clampf(pa.dot(ba) / denom, 0.0, 1.0)
	var closest := Vector2(a.x, a.z) + ba * t
	return Vector2(p.x, p.z).distance_to(closest)

func _apply_v22_twin_screw(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	var speed_abs: float = absf(surge_mps)
	var low_speed_mix: float = 1.0 - clampf(speed_abs / 4.2, 0.0, 1.0)
	var differential_command: float = rudder_state * low_speed_mix * 0.48
	var port_target: float = clampf(engine_order - differential_command, -0.78, 1.0)
	var starboard_target: float = clampf(engine_order + differential_command, -0.78, 1.0)
	port_engine_order = move_toward(port_engine_order, port_target, delta * 0.34)
	starboard_engine_order = move_toward(starboard_engine_order, starboard_target, delta * 0.34)

	# Shaft rpm has its own inertia and does not jump with the telegraph command.
	port_rpm = move_toward(port_rpm, port_engine_order, delta * (0.29 if absf(port_engine_order) > absf(port_rpm) else 0.42))
	starboard_rpm = move_toward(starboard_rpm, starboard_engine_order, delta * (0.29 if absf(starboard_engine_order) > absf(starboard_rpm) else 0.42))

	# Differential thrust creates a yawing moment at dead slow, where a conventional rudder has
	# little authority. The effect fades as the hull gains speed and hydrodynamic rudder forces take over.
	var differential: float = starboard_rpm - port_rpm
	var astern_bias: float = 0.80 if engine_order < -0.02 else 1.0
	var yaw_moment: float = differential * deg_to_rad(0.52) * low_speed_mix * astern_bias
	yaw_rate += yaw_moment * delta
	yaw_rate = clampf(yaw_rate, -deg_to_rad(1.65), deg_to_rad(1.65))

	# Average propeller demand slightly corrects surge so asymmetric manoeuvring costs forward speed.
	var average_order: float = (port_rpm + starboard_rpm) * 0.5
	var asymmetry_loss: float = absf(differential) * 0.022 * low_speed_mix
	if absf(average_order) > 0.02:
		surge_mps = move_toward(surge_mps, surge_mps * (1.0 - asymmetry_loss), delta * 0.12)

func _apply_v22_berth_contact(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	if route_distance_m > 42.0:
		return
	var target: Vector3 = eceabat_stop if route_forward else canakkale_stop
	var to_target: Vector3 = target - ferry.global_position
	to_target.y = 0.0
	if to_target.length() < 0.01:
		return
	var forward: Vector3 = -ferry.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var heading_alignment: float = clampf(forward.dot(to_target.normalized()), -1.0, 1.0)
	var heading_error_deg: float = rad_to_deg(acos(heading_alignment))

	# Fender pressure increases only when the ship is slow and reasonably aligned. It stops the
	# visual skating through the ramp but still punishes bad approaches through inherited damage logic.
	if route_distance_m < 20.0 and ground_speed_kn < 2.0 and heading_error_deg < 18.0:
		var pressure: float = 1.0 - clampf(route_distance_m / 20.0, 0.0, 1.0)
		surge_mps *= exp(-delta * (0.65 + pressure * 1.55))
		sway_mps *= exp(-delta * (0.80 + pressure * 1.85))
		yaw_rate *= exp(-delta * (0.60 + pressure * 1.35))

func _install_v22() -> void:
	for _frame: int in range(22):
		await get_tree().process_frame
	_install_v22_telemetry()
	_install_v22_cameras()
	_retitle_v22(self)

func _install_v22_cameras() -> void:
	if v10_camera_offsets.size() < 5:
		return
	# Cinematic but useful framing: lower chase camera, eye-level bridge camera, tighter docking views.
	v10_camera_offsets[0] = Vector3(0.0, 10.2, 31.0)
	v10_camera_targets[0] = Vector3(0.0, 3.0, -128.0)
	v10_camera_fovs[0] = 60.0
	v10_camera_offsets[1] = Vector3(0.0, 11.5, -0.5)
	v10_camera_targets[1] = Vector3(0.0, 4.8, -185.0)
	v10_camera_fovs[1] = 64.0
	v10_camera_offsets[2] = Vector3(-12.0, 8.1, 18.0)
	v10_camera_targets[2] = Vector3(-4.5, 1.8, -114.0)
	v10_camera_fovs[2] = 58.0
	v10_camera_offsets[3] = Vector3(12.0, 8.1, 18.0)
	v10_camera_targets[3] = Vector3(4.5, 1.8, -114.0)
	v10_camera_fovs[3] = 58.0
	v10_camera_offsets[4] = Vector3(0.0, 78.0, 105.0)
	v10_camera_targets[4] = Vector3(0.0, 0.6, -240.0)
	v10_camera_fovs[4] = 54.0
	for i: int in range(mini(cameras.size(), v10_camera_fovs.size())):
		if is_instance_valid(cameras[i]):
			cameras[i].fov = v10_camera_fovs[i]

func _install_v22_telemetry() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 58
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.405
	panel.anchor_top = 0.089
	panel.anchor_right = 0.595
	panel.anchor_bottom = 0.128
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	v22_telemetry = Label.new()
	v22_telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v22_telemetry.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v22_telemetry.add_theme_font_size_override("font_size", 11)
	panel.add_child(v22_telemetry)
	_update_v22_telemetry()

func _update_v22_telemetry() -> void:
	if v22_telemetry == null:
		return
	v22_telemetry.text = "İSKELE %.0f%%  •  SANCAK %.0f%%  •  SAPMA %.1f°  •  YATIŞ %.1f°" % [port_rpm * 100.0, starboard_rpm * 100.0, drift_angle_deg, load_roll_deg]

func _update_v13_assist() -> void:
	super._update_v13_assist()
	if captain_assist_label != null:
		captain_assist_label.text = captain_assist_label.text.replace("V21 KAPTAN KÖPRÜSÜ", "V22 KAPTAN KÖPRÜSÜ")

func _retitle_v22(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.text = label.text.replace("V21 KAPTAN KÖPRÜSÜ", "V22 KAPTAN KÖPRÜSÜ")
		label.text = label.text.replace("V21 • MEGA GERÇEKÇİLİK", "V22 • ULTRA SİMÜLASYON")
		label.text = label.text.replace("BOĞAZ KAPTANI V21", "BOĞAZ KAPTANI V22")
	for child: Node in node.get_children():
		_retitle_v22(child)
