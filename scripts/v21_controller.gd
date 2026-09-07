extends "res://scripts/v20_master_controller.gd"

const V21SkyShader = preload("res://shaders/sky_v21.gdshader")

var v21_thruster_input: float = 0.0
var v21_title_timer: float = 0.0
var v21_env_timer: float = 0.0
var v21_thruster_left: Button
var v21_thruster_right: Button
var v21_speed_readout: Label
var v21_engine_readout: Label

func _ready() -> void:
	super._ready()
	call_deferred("_install_v21_upgrade")

func _process(delta: float) -> void:
	super._process(delta)
	v21_title_timer += delta
	v21_env_timer += delta
	if v21_title_timer >= 0.35:
		v21_title_timer = 0.0
		_enforce_v21_text(self)
		_update_v21_readouts()
	if v21_env_timer >= 2.0:
		v21_env_timer = 0.0
		_ensure_v21_environment()

func _update_ferry(delta: float) -> void:
	super._update_ferry(delta)
	_apply_v21_low_speed_physics(delta)

func _update_v13_assist() -> void:
	super._update_v13_assist()
	if captain_assist_label != null:
		captain_assist_label.text = captain_assist_label.text.replace("V13 KAPTAN ASİSTANI", "V21 KAPTAN KÖPRÜSÜ")
		captain_assist_label.text = captain_assist_label.text.replace("V20 KAPTAN KÖPRÜSÜ", "V21 KAPTAN KÖPRÜSÜ")

func _install_v20_image_based_lighting() -> void:
	# V21 deliberately keeps the licensed CC0 HDRI as a reflection source only. The visible
	# horizon is generated for the Dardanelles so the player never sees a fake harbour skyline.
	_ensure_v21_environment()

func _install_v21_upgrade() -> void:
	for _frame: int in range(18):
		await get_tree().process_frame
	_install_v21_cameras()
	_install_v21_mobile_ui()
	_ensure_v21_environment()
	_enforce_v21_text(self)

func _install_v21_cameras() -> void:
	if v10_camera_offsets.size() < 5 or v10_camera_targets.size() < 5 or v10_camera_fovs.size() < 5:
		return
	# Lower, tighter chase camera; bridge camera sees the waterline and berth; drone camera is
	# high enough for route reading but no longer turns the ship into a toy.
	v10_camera_offsets[0] = Vector3(0.0, 12.8, 35.0)
	v10_camera_targets[0] = Vector3(0.0, 3.4, -115.0)
	v10_camera_fovs[0] = 64.0
	v10_camera_offsets[1] = Vector3(0.0, 12.0, 1.0)
	v10_camera_targets[1] = Vector3(0.0, 5.1, -170.0)
	v10_camera_fovs[1] = 68.0
	v10_camera_offsets[2] = Vector3(-13.5, 9.8, 21.0)
	v10_camera_targets[2] = Vector3(-4.0, 2.2, -105.0)
	v10_camera_fovs[2] = 62.0
	v10_camera_offsets[3] = Vector3(13.5, 9.8, 21.0)
	v10_camera_targets[3] = Vector3(4.0, 2.2, -105.0)
	v10_camera_fovs[3] = 62.0
	v10_camera_offsets[4] = Vector3(0.0, 68.0, 86.0)
	v10_camera_targets[4] = Vector3(0.0, 0.8, -205.0)
	v10_camera_fovs[4] = 58.0
	for i in range(mini(cameras.size(), v10_camera_fovs.size())):
		if is_instance_valid(cameras[i]):
			cameras[i].fov = v10_camera_fovs[i]

func _apply_v21_low_speed_physics(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	var speed_abs: float = absf(surge_mps)
	var basis: Basis = ferry.global_transform.basis
	var starboard: Vector3 = basis.x
	starboard.y = 0.0
	starboard = starboard.normalized()

	# Bow thruster: strong at dead slow, fades out naturally as the hull gains way.
	if absf(v21_thruster_input) > 0.01 and speed_abs < 2.65:
		var authority: float = 1.0 - clampf(speed_abs / 2.65, 0.0, 1.0)
		var side_speed: float = v21_thruster_input * 0.82 * authority
		ferry.global_position += starboard * side_speed * delta
		sway_mps = lerpf(sway_mps, side_speed * 0.58, clampf(delta * 1.9, 0.0, 1.0))
		yaw_rate += v21_thruster_input * deg_to_rad(0.085) * authority * delta

	# Hydrodynamic cross-flow damping gets stronger near the berth and gives the vessel a heavy,
	# deliberate low-speed response rather than the previous arcade slide.
	var berth_factor: float = 1.0 - clampf(route_distance_m / 105.0, 0.0, 1.0)
	if berth_factor > 0.0:
		sway_mps *= exp(-delta * (0.18 + berth_factor * 0.72))
		yaw_rate *= exp(-delta * (0.10 + berth_factor * 0.52))
		if route_distance_m < 34.0 and ground_speed_kn < 2.4:
			surge_mps *= exp(-delta * 0.24)

	# Soft fender contact. The inherited docking logic still decides success/failure; this only
	# prevents the ship from visually skating through the ramp at very low speed.
	if route_distance_m < 16.0 and ground_speed_kn < 1.6:
		surge_mps *= exp(-delta * 1.25)
		sway_mps *= exp(-delta * 1.55)
		yaw_rate *= exp(-delta * 1.25)

func _install_v21_mobile_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	v21_thruster_left = Button.new()
	v21_thruster_left.text = "BAŞ ←"
	_v21_rect(v21_thruster_left, 0.405, 0.885, 0.455, 0.947, 12)
	v21_thruster_left.button_down.connect(func(): v21_thruster_input = -1.0)
	v21_thruster_left.button_up.connect(func(): v21_thruster_input = 0.0)
	root.add_child(v21_thruster_left)

	v21_thruster_right = Button.new()
	v21_thruster_right.text = "BAŞ →"
	_v21_rect(v21_thruster_right, 0.545, 0.885, 0.595, 0.947, 12)
	v21_thruster_right.button_down.connect(func(): v21_thruster_input = 1.0)
	v21_thruster_right.button_up.connect(func(): v21_thruster_input = 0.0)
	root.add_child(v21_thruster_right)

	var info_panel := PanelContainer.new()
	info_panel.anchor_left = 0.405
	info_panel.anchor_top = 0.023
	info_panel.anchor_right = 0.595
	info_panel.anchor_bottom = 0.086
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info_panel)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	info_panel.add_child(row)
	v21_speed_readout = Label.new()
	v21_speed_readout.add_theme_font_size_override("font_size", 13)
	v21_speed_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(v21_speed_readout)
	v21_engine_readout = Label.new()
	v21_engine_readout.add_theme_font_size_override("font_size", 13)
	v21_engine_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(v21_engine_readout)

	# Existing primary controls become smaller and closer to the screen edge, leaving the world
	# visible. Management buttons remain behind the captain drawer.
	_relayout_v21_controls(self)
	_update_v21_readouts()

func _relayout_v21_controls(node: Node) -> void:
	if node is Button:
		var button := node as Button
		match button.text:
			"SOL": _v21_rect(button, 0.025, 0.858, 0.090, 0.946, 17)
			"SAĞ": _v21_rect(button, 0.102, 0.858, 0.167, 0.946, 17)
			"GAZ +": _v21_rect(button, 0.833, 0.858, 0.898, 0.946, 17)
			"GAZ -": _v21_rect(button, 0.910, 0.858, 0.975, 0.946, 17)
			"DUR": _v21_rect(button, 0.472, 0.866, 0.528, 0.950, 15)
			"KAMERA": _v21_rect(button, 0.910, 0.742, 0.975, 0.794, 11)
			"KAPTAN", "KAPAT": _v21_rect(button, 0.910, 0.672, 0.975, 0.724, 11)
			"HUD", "HUD AÇ": _v21_rect(button, 0.925, 0.026, 0.977, 0.069, 10)
	for child: Node in node.get_children():
		_relayout_v21_controls(child)

func _update_v21_readouts() -> void:
	if v21_speed_readout != null:
		v21_speed_readout.text = "SOG %.1f kn  •  STW %.1f kn" % [ground_speed_kn, velocity_knots]
	if v21_engine_readout != null:
		v21_engine_readout.text = "MOTOR %.0f%%  •  DÜMEN %.0f%%" % [engine_order * 100.0, rudder_state * 100.0]

func _enforce_v21_text(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.text = label.text.replace("V13 KAPTAN ASİSTANI", "V21 KAPTAN KÖPRÜSÜ")
		label.text = label.text.replace("V20 KAPTAN KÖPRÜSÜ", "V21 KAPTAN KÖPRÜSÜ")
		label.text = label.text.replace("V20 • REMASTER", "V21 • MEGA GERÇEKÇİLİK")
		label.text = label.text.replace("BOĞAZ KAPTANI V20 REMASTER", "BOĞAZ KAPTANI V21")
	for child: Node in node.get_children():
		_enforce_v21_text(child)

func _ensure_v21_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = V21SkyShader
	var sky := Sky.new()
	sky.sky_material = sky_material
	for node: Node in find_children("*", "WorldEnvironment", true, false):
		if not (node is WorldEnvironment):
			continue
		var world := node as WorldEnvironment
		var env: Environment = world.environment
		if env == null:
			continue
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.82
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.96
		env.tonemap_white = 1.32
		env.adjustment_enabled = true
		env.adjustment_brightness = 0.98
		env.adjustment_contrast = 1.08
		env.adjustment_saturation = 1.04
		env.fog_enabled = true
		env.fog_density = 0.000105
		env.fog_light_color = Color(0.67, 0.73, 0.76)
		env.fog_sky_affect = 0.52
		env.glow_enabled = true
		env.glow_intensity = 0.12
		env.glow_bloom = 0.006

func _v21_rect(control: Control, left: float, top: float, right: float, bottom: float, font_size: int) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	if control is Button:
		(control as Button).add_theme_font_size_override("font_size", font_size)
