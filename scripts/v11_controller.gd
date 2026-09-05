extends "res://scripts/v10_controller.gd"

const V11VehicleFactory = preload("res://scripts/v11_vehicle_factory.gd")

const MAX_AHEAD_MPS := 7.35
const MAX_ASTERN_MPS := 2.55
const MAX_YAW_RATE := deg_to_rad(1.75)
const DOCK_CENTER_OFFSET_M := 34.0
const DOCK_SUCCESS_RADIUS_M := 27.0
const DOCK_MAX_SPEED_KN := 1.2
const DOCK_MAX_HEADING_ERROR_DEG := 11.0

var surge_mps := 0.0
var sway_mps := 0.0
var yaw_rate := 0.0
var canakkale_stop := Vector3.ZERO
var eceabat_stop := Vector3.ZERO
var canakkale_zone: Node3D
var eceabat_zone: Node3D
var dock_hint: Label
var docking_text := "SEYİR"

func _ready() -> void:
	super._ready()
	_build_real_docking_targets()
	_build_v11_ui()
	_update_dock_visibility()

func _process(delta: float) -> void:
	super._process(delta)
	_update_docking_hint()

func _add_cargo_vehicle(kind: String, x: float, z: float, color_index: int) -> void:
	var vehicle := V11VehicleFactory.create_vehicle(kind, Vector3(x, 5.62, z), VEHICLE_COLORS[color_index % VEHICLE_COLORS.size()])
	cargo_root.add_child(vehicle)
	var weight := V11VehicleFactory.weight_for(kind)
	cargo_tons += weight
	if x < 0.0:
		port_tons += weight
	else:
		starboard_tons += weight

func _apply_current_and_wind(_delta: float) -> void:
	# v11 folds current and wind into the hydrodynamic integrator below.
	pass

func _update_ferry(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return

	var target_speed := throttle * MAX_AHEAD_MPS if throttle >= 0.0 else (-throttle / 0.45) * -MAX_ASTERN_MPS
	var speed_error := target_speed - surge_mps
	var accel_limit := 0.19 if absf(target_speed) > absf(surge_mps) else 0.27
	var prop_accel := clampf(speed_error * 0.16, -accel_limit, accel_limit)
	surge_mps += prop_accel * delta

	# Hull resistance rises non-linearly with speed and removes the arcade-like instant glide.
	var resistance := 0.0027 * surge_mps * absf(surge_mps)
	surge_mps -= resistance * delta
	if absf(throttle) < 0.01 and absf(surge_mps) < 0.025:
		surge_mps = 0.0

	# Lateral hull resistance is much stronger than longitudinal resistance.
	var lateral_damping := 0.34 + absf(surge_mps) * 0.12
	sway_mps = move_toward(sway_mps, 0.0, lateral_damping * delta)

	# Rudder authority depends on water flow and prop wash. Reverse steering naturally flips.
	var direction_sign := signf(surge_mps)
	if absf(surge_mps) < 0.22:
		direction_sign = signf(throttle)
	var water_flow := absf(surge_mps) + absf(throttle) * 1.55
	var rudder_authority := clampf(water_flow / 5.6, 0.0, 1.0)
	var desired_yaw_rate := steer * direction_sign * MAX_YAW_RATE * rudder_authority
	var yaw_accel := deg_to_rad(0.58) + deg_to_rad(0.10) * water_flow
	yaw_rate = move_toward(yaw_rate, desired_yaw_rate, yaw_accel * delta)
	if absf(steer) < 0.02:
		yaw_rate = move_toward(yaw_rate, 0.0, deg_to_rad(0.32) * delta)

	# Keep the already-tested mobile left/right direction while adding yaw inertia.
	ferry.rotation.y -= yaw_rate * delta
	var forward := -ferry.global_transform.basis.z
	var starboard := ferry.global_transform.basis.x

	# A turning hull develops a small sideways velocity instead of rotating around its centre instantly.
	sway_mps += -yaw_rate * surge_mps * 0.56 * delta
	sway_mps = clampf(sway_mps, -1.35, 1.35)

	var current_velocity := current_vector * current_strength
	var wind_velocity := wind_vector * (wind_strength * 0.045)
	var water_velocity := forward * surge_mps + starboard * sway_mps
	ferry.global_position += (water_velocity + current_velocity + wind_velocity) * delta

	velocity_knots = surge_mps / 0.514444

	var turn_heel := rad_to_deg(yaw_rate) * surge_mps * 0.20
	var wave_roll := sin(Time.get_ticks_msec() * 0.00125) * (0.28 + wind_strength * 0.13)
	var target_roll := deg_to_rad(base_load_roll + turn_heel + wave_roll)
	ferry.rotation.z = lerp_angle(ferry.rotation.z, target_roll, clampf(delta * 1.15, 0.0, 1.0))
	var pitch_wave := sin(Time.get_ticks_msec() * 0.00092) * (0.18 + wind_strength * 0.05)
	ferry.rotation.x = lerp_angle(ferry.rotation.x, deg_to_rad(pitch_wave), clampf(delta * 0.72, 0.0, 1.0))

func _reset_route() -> void:
	trip_finished = false
	trip_score = 0
	elapsed_seconds = 0.0
	damage = 0.0
	comfort = 100.0
	throttle = 0.0
	velocity_knots = 0.0
	surge_mps = 0.0
	sway_mps = 0.0
	yaw_rate = 0.0

	var canakkale_terminal := GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat_terminal := GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var canakkale_to_eceabat := (eceabat_terminal - canakkale_terminal).normalized()
	var eceabat_to_canakkale := -canakkale_to_eceabat
	canakkale_stop = canakkale_terminal + canakkale_to_eceabat * DOCK_CENTER_OFFSET_M
	eceabat_stop = eceabat_terminal + eceabat_to_canakkale * DOCK_CENTER_OFFSET_M

	if route_forward:
		route_start = canakkale_stop
		route_target = eceabat_stop
	else:
		route_start = eceabat_stop
		route_target = canakkale_stop

	var route_dir := (route_target - route_start).normalized()
	ferry.global_position = route_start + route_dir * 72.0 + Vector3(0, 2.0, 0)
	ferry.look_at(route_target + Vector3(0, 2.0, 0), Vector3.UP)
	route_distance_m = ferry.global_position.distance_to(route_target)
	if result_panel != null:
		result_panel.visible = false
	_update_route_button()
	_update_dock_visibility()

func _update_trip_state(delta: float) -> void:
	if ferry == null:
		return
	route_distance_m = ferry.global_position.distance_to(route_target)
	var heading_error := _heading_error_deg()
	var lateral_speed := absf(sway_mps)
	var speed_abs := absf(velocity_knots)

	if route_distance_m < 220.0:
		docking_text = "YANAŞMA • %.0f m • baş hata %.0f°" % [route_distance_m, heading_error]
	if route_distance_m < 80.0:
		docking_text = "YAVAŞLA • hedef < %.1f kn" % DOCK_MAX_SPEED_KN
	if route_distance_m <= DOCK_SUCCESS_RADIUS_M:
		if speed_abs <= DOCK_MAX_SPEED_KN and heading_error <= DOCK_MAX_HEADING_ERROR_DEG and lateral_speed <= 0.42:
			surge_mps = 0.0
			sway_mps = 0.0
			yaw_rate = 0.0
			velocity_knots = 0.0
			_finish_trip(true, "İŞARETLİ ALANA HASSAS YANAŞMA")
			return
		elif speed_abs > 3.0:
			damage = minf(100.0, damage + delta * 13.0)
			docking_text = "ÇOK HIZLI YANAŞMA!"

	var route_dir := (route_target - route_start).normalized()
	var passed_target := (route_target - ferry.global_position).dot(route_dir) < -18.0
	if passed_target and route_distance_m < 75.0 and speed_abs > 1.8:
		damage = minf(100.0, damage + delta * 20.0)
		docking_text = "RAMPA HATTINI GEÇTİN"

	if damage >= 100.0:
		_finish_trip(false, "AĞIR HASAR")

func _heading_error_deg() -> float:
	if ferry == null:
		return 180.0
	var forward := -ferry.global_transform.basis.z
	forward.y = 0.0
	var to_target := route_target - ferry.global_position
	to_target.y = 0.0
	if forward.length_squared() < 0.0001 or to_target.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(acos(clampf(forward.normalized().dot(to_target.normalized()), -1.0, 1.0)))

func _build_real_docking_targets() -> void:
	var canakkale_terminal := GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat_terminal := GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var c_to_e := (eceabat_terminal - canakkale_terminal).normalized()
	canakkale_stop = canakkale_terminal + c_to_e * DOCK_CENTER_OFFSET_M
	eceabat_stop = eceabat_terminal - c_to_e * DOCK_CENTER_OFFSET_M
	canakkale_zone = _make_docking_zone(canakkale_stop, -c_to_e, "ÇANAKKALE YANAŞMA ALANI")
	eceabat_zone = _make_docking_zone(eceabat_stop, c_to_e, "ECEABAT YANAŞMA ALANI")
	add_child(canakkale_zone)
	add_child(eceabat_zone)

func _make_docking_zone(pos: Vector3, inbound_direction: Vector3, zone_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = zone_name
	root.global_position = pos + Vector3(0, 0.26, 0)
	var target := root.global_position + inbound_direction
	root.look_at(target, Vector3.UP)

	var plane_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(29.0, 76.0)
	plane_node.mesh = plane
	var zone_mat := StandardMaterial3D.new()
	zone_mat.albedo_color = Color(0.08, 0.90, 0.34, 0.23)
	zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone_mat.emission_enabled = true
	zone_mat.emission = Color(0.04, 0.52, 0.16)
	zone_mat.emission_energy_multiplier = 0.65
	plane_node.material_override = zone_mat
	root.add_child(plane_node)

	for side in [-1.0, 1.0]:
		root.add_child(_dock_strip(Vector3(0.42, 0.06, 76.0), Vector3(side * 14.4, 0.07, 0), Color(0.12, 1.0, 0.38)))
	root.add_child(_dock_strip(Vector3(28.8, 0.07, 0.55), Vector3(0, 0.09, -4.0), Color(1.0, 0.80, 0.08)))
	root.add_child(_dock_strip(Vector3(2.4, 0.08, 18.0), Vector3(0, 0.10, 17.0), Color(1.0, 0.86, 0.12)))

	var label := Label3D.new()
	label.text = "%s\nBURADA DUR • ≤ %.1f kn" % [zone_name, DOCK_MAX_SPEED_KN]
	label.font_size = 54
	label.outline_size = 8
	label.modulate = Color(0.90, 1.0, 0.92)
	label.position = Vector3(0, 8.0, -10.0)
	label.pixel_size = 0.018
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	return root

func _dock_strip(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.35
	node.material_override = mat
	return node

func _update_dock_visibility() -> void:
	if canakkale_zone != null:
		canakkale_zone.visible = not route_forward
	if eceabat_zone != null:
		eceabat_zone.visible = route_forward

func _build_v11_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.025, 0.035, 0.76)
	bg.anchor_left = 0.36
	bg.anchor_top = 0.207
	bg.anchor_right = 0.64
	bg.anchor_bottom = 0.268
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	dock_hint = Label.new()
	dock_hint.anchor_right = 1.0
	dock_hint.anchor_bottom = 1.0
	dock_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dock_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dock_hint.add_theme_font_size_override("font_size", 18)
	dock_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(dock_hint)

func _update_docking_hint() -> void:
	if dock_hint == null:
		return
	if trip_finished:
		dock_hint.text = "YANAŞMA TAMAMLANDI" if trip_score > 45 else "SEFER SONLANDI"
		return
	if route_distance_m >= 220.0:
		docking_text = "SERBEST SEYİR • Akıntı %.2f m/s" % current_strength
	dock_hint.text = "%s   •   sürüklenme %.1f m/s" % [docking_text, absf(sway_mps)]

func _update_v7_hud() -> void:
	super._update_v7_hud()
	if v7_status != null:
		v7_status.text += "\nSuya göre %.1f kn   Dümen atalet %.1f°/sn" % [absf(velocity_knots), absf(rad_to_deg(yaw_rate))]

func _on_route_pressed() -> void:
	super._on_route_pressed()
	_update_dock_visibility()
