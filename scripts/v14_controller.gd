extends "res://scripts/v13_controller.gd"

var v14_nav_label: Label

func _ready() -> void:
	super._ready()
	call_deferred("_install_v14_cleanup")

func _process(delta: float) -> void:
	super._process(delta)
	_update_v14_nav()

func _install_v10_cameras() -> void:
	await get_tree().process_frame
	for cam in cameras:
		if is_instance_valid(cam):
			cam.current = false
			cam.queue_free()
	cameras.clear()
	v10_camera_offsets.clear()
	v10_camera_targets.clear()
	v10_camera_fovs.clear()

	# Camera positions are deliberately farther from the ferry so the ship never fills the view.
	_add_v10_camera("SÜRÜŞ", Vector3(0.0, 12.5, 52.0), Vector3(0.0, 2.8, -190.0), 62.0)
	_add_v10_camera("KAPTAN", Vector3(0.0, 15.2, -1.5), Vector3(0.0, 5.0, -210.0), 67.0)
	_add_v10_camera("YANAŞMA SOL", Vector3(-32.0, 18.0, 58.0), Vector3(-3.0, 2.8, -155.0), 59.0)
	_add_v10_camera("YANAŞMA SAĞ", Vector3(32.0, 18.0, 58.0), Vector3(3.0, 2.8, -155.0), 59.0)
	_add_v10_camera("DRONE ROTA", Vector3(0.0, 64.0, 112.0), Vector3(0.0, 0.8, -225.0), 55.0)

	camera_index = 0
	if not cameras.is_empty():
		cameras[0].current = true
	_update_v10_cameras(1.0)
	_update_status()

func _add_cargo_vehicle(kind: String, x: float, z: float, color_index: int) -> void:
	# v11 GLB vehicle meshes were authored at roughly 2x road scale. Keep the asset detail,
	# but put them back at true passenger-car / bus / truck proportions on the deck.
	var vehicle: Node3D = V11VehicleFactory.create_vehicle(kind, Vector3(x, 5.62, z), VEHICLE_COLORS[color_index % VEHICLE_COLORS.size()])
	vehicle.scale = Vector3(0.5, 0.5, 0.5)
	cargo_root.add_child(vehicle)
	var weight: float = V11VehicleFactory.weight_for(kind)
	cargo_tons += weight
	if x < 0.0:
		port_tons += weight
	else:
		starboard_tons += weight

func _install_v13_captain_assist() -> void:
	await get_tree().process_frame
	_retitle_v14(self)

	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := ColorRect.new()
	panel.color = Color(0.006, 0.018, 0.027, 0.76)
	panel.anchor_left = 0.675
	panel.anchor_top = 0.020
	panel.anchor_right = 0.985
	panel.anchor_bottom = 0.132
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	captain_assist_label = Label.new()
	captain_assist_label.anchor_left = 0.035
	captain_assist_label.anchor_top = 0.04
	captain_assist_label.anchor_right = 0.965
	captain_assist_label.anchor_bottom = 0.78
	captain_assist_label.add_theme_font_size_override("font_size", 14)
	captain_assist_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	captain_assist_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(captain_assist_label)

	stability_bar = ProgressBar.new()
	stability_bar.anchor_left = 0.04
	stability_bar.anchor_top = 0.80
	stability_bar.anchor_right = 0.96
	stability_bar.anchor_bottom = 0.94
	stability_bar.min_value = 0.0
	stability_bar.max_value = 100.0
	stability_bar.value = 0.0
	stability_bar.show_percentage = false
	stability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stability_bar)

	emergency_button = Button.new()
	emergency_button.text = "ACİL DENGELE"
	emergency_button.anchor_left = 0.885
	emergency_button.anchor_top = 0.145
	emergency_button.anchor_right = 0.985
	emergency_button.anchor_bottom = 0.205
	emergency_button.add_theme_font_size_override("font_size", 14)
	emergency_button.mouse_filter = Control.MOUSE_FILTER_STOP
	emergency_button.pressed.connect(_on_emergency_balance_pressed)
	root.add_child(emergency_button)
	_update_v13_assist()

func _install_v14_cleanup() -> void:
	await get_tree().process_frame
	# Remove duplicate text panels from older versions; keep the controls themselves.
	if v7_status != null and v7_status.get_parent() != null:
		v7_status.get_parent().visible = false
	if status_label != null and status_label.get_parent() != null:
		status_label.get_parent().visible = false

	var layer := CanvasLayer.new()
	layer.layer = 19
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var panel := ColorRect.new()
	panel.color = Color(0.006, 0.018, 0.027, 0.72)
	panel.anchor_left = 0.018
	panel.anchor_top = 0.020
	panel.anchor_right = 0.365
	panel.anchor_bottom = 0.105
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	v14_nav_label = Label.new()
	v14_nav_label.anchor_left = 0.035
	v14_nav_label.anchor_top = 0.08
	v14_nav_label.anchor_right = 0.965
	v14_nav_label.anchor_bottom = 0.92
	v14_nav_label.add_theme_font_size_override("font_size", 15)
	v14_nav_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v14_nav_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v14_nav_label)

	_compact_buttons(self)
	_tune_v14_environment()
	_update_v14_nav()

func _retitle_v14(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.text.begins_with("V13 •") or label.text.begins_with("V12 •") or label.text.begins_with("V7 •"):
			label.text = "V14 • GÖRSEL TEMİZLİK + KAPTAN MODU"
	for child in node.get_children():
		_retitle_v14(child)

func _compact_buttons(node: Node) -> void:
	if node is Button:
		var b := node as Button
		var t: String = b.text
		b.modulate.a = 0.78
		if t == "SOL":
			_set_button_rect(b, 0.020, 0.805, 0.120, 0.965, 22)
		elif t == "SAĞ":
			_set_button_rect(b, 0.130, 0.805, 0.230, 0.965, 22)
		elif t == "GAZ +":
			_set_button_rect(b, 0.770, 0.805, 0.870, 0.965, 22)
		elif t == "GAZ -":
			_set_button_rect(b, 0.880, 0.805, 0.980, 0.965, 22)
		elif t == "DUR":
			_set_button_rect(b, 0.455, 0.855, 0.545, 0.965, 20)
		elif t.begins_with("ROTA"):
			_set_button_rect(b, 0.020, 0.205, 0.110, 0.270, 16)
		elif t == "YÜKLE":
			_set_button_rect(b, 0.020, 0.282, 0.110, 0.347, 16)
		elif t == "DENGELE":
			_set_button_rect(b, 0.020, 0.359, 0.110, 0.424, 16)
		elif t == "AĞIR YÜK":
			_set_button_rect(b, 0.020, 0.436, 0.110, 0.501, 15)
		elif t.begins_with("HAVA"):
			_set_button_rect(b, 0.890, 0.220, 0.980, 0.285, 15)
		elif t.begins_with("RAMPA"):
			_set_button_rect(b, 0.890, 0.297, 0.980, 0.362, 15)
		elif t == "YENİ SEFER":
			_set_button_rect(b, 0.890, 0.374, 0.980, 0.439, 15)
		elif t == "KAMERA":
			_set_button_rect(b, 0.890, 0.515, 0.980, 0.580, 15)
	for child in node.get_children():
		_compact_buttons(child)

func _set_button_rect(button: Button, l: float, t: float, r: float, b: float, font_size: int) -> void:
	button.anchor_left = l
	button.anchor_top = t
	button.anchor_right = r
	button.anchor_bottom = b
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	button.add_theme_font_size_override("font_size", font_size)

func _tune_v14_environment() -> void:
	for child in get_children():
		if child is WorldEnvironment:
			var world := child as WorldEnvironment
			if world.environment != null:
				world.environment.ambient_light_energy = 0.64
				world.environment.fog_density = 0.00016
				world.environment.fog_light_color = Color(0.61, 0.70, 0.75)

func _update_v14_nav() -> void:
	if v14_nav_label == null or ferry == null or cameras.is_empty():
		return
	var target_name: String = "ECEABAT" if route_forward else "ÇANAKKALE"
	var cam_name: String = str(cameras[camera_index].name) if camera_index < cameras.size() else "SÜRÜŞ"
	v14_nav_label.text = "BOĞAZ KAPTANI V14 • %s • %.0f m\n%.1f kn  •  Gaz %d%%  •  %s" % [target_name, maxf(route_distance_m, 0.0), absf(ground_speed_kn), int(round(throttle * 100.0)), cam_name]
