extends "res://scripts/v20_controller.gd"

const V20_ASPHALT_DIFF := "res://assets/v20/materials/asphalt_diff.png"
const V20_ASPHALT_NORMAL := "res://assets/v20/materials/asphalt_normal.png"
const V20_ASPHALT_ROUGH := "res://assets/v20/materials/asphalt_rough.png"
const V20_CONCRETE_DIFF := "res://assets/v20/materials/concrete_diff.png"
const V20_CONCRETE_NORMAL := "res://assets/v20/materials/concrete_normal.png"
const V20_CONCRETE_ROUGH := "res://assets/v20/materials/concrete_rough.png"
const V20_RAMP_DIFF := "res://assets/v20/materials/ramp_metal_diff.png"
const V20_RAMP_NORMAL := "res://assets/v20/materials/ramp_metal_normal.png"
const V20_RAMP_ROUGH := "res://assets/v20/materials/ramp_metal_rough.png"

var captain_menu_open := false
var v20_management_buttons: Array[Button] = []
var v20_menu_button: Button
var v20_hud_button: Button
var v20_hud_hidden := false

func _ready() -> void:
	super._ready()
	call_deferred("_install_v20_mobile_ui")

func _process(delta: float) -> void:
	super._process(delta)
	if emergency_button != null:
		emergency_button.visible = absf(load_roll_deg) >= 8.0 and not v20_hud_hidden

func _update_ferry(delta: float) -> void:
	super._update_ferry(delta)
	_apply_v20_wave_buoyancy(delta)

func _build_v20_materials() -> void:
	v20_asphalt = _make_textured_material(V20_ASPHALT_DIFF, V20_ASPHALT_NORMAL, V20_ASPHALT_ROUGH, Color(0.12,0.12,0.12), 5.5)
	v20_concrete = _make_textured_material(V20_CONCRETE_DIFF, V20_CONCRETE_NORMAL, V20_CONCRETE_ROUGH, Color(0.46,0.45,0.42), 4.0)
	v20_ramp_metal = _make_textured_material(V20_RAMP_DIFF, V20_RAMP_NORMAL, V20_RAMP_ROUGH, Color(0.31,0.33,0.34), 3.0)
	v20_ramp_metal.metallic = 0.50

func _apply_v20_wave_buoyancy(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	var basis := ferry.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var starboard := basis.x
	starboard.y = 0.0
	starboard = starboard.normalized()

	var center := ferry.global_position
	var bow_h := _v20_sea_height(center + forward * 30.0)
	var stern_h := _v20_sea_height(center - forward * 30.0)
	var port_h := _v20_sea_height(center - starboard * 8.2)
	var starboard_h := _v20_sea_height(center + starboard * 8.2)
	var center_h := _v20_sea_height(center)

	# Heave follows the same long waves that are actually rendered by the sea shader.
	var average_h := (bow_h + stern_h + port_h + starboard_h + center_h * 2.0) / 6.0
	var target_y := 2.0 + average_h * 0.72
	ferry.global_position.y = lerpf(ferry.global_position.y, target_y, clampf(delta * 0.78, 0.0, 1.0))

	var wave_pitch := atan2(bow_h - stern_h, 60.0)
	var wave_roll := atan2(starboard_h - port_h, 16.4)
	var turn_heel_deg := rad_to_deg(yaw_rate) * surge_mps * 0.24
	var drift_heel_deg := sway_mps * 0.72
	var static_roll := deg_to_rad(base_load_roll + turn_heel_deg + drift_heel_deg)
	var target_pitch := clampf(wave_pitch * 0.92, deg_to_rad(-4.0), deg_to_rad(4.0))
	var target_roll := clampf(static_roll + wave_roll * 0.88, deg_to_rad(-18.0), deg_to_rad(18.0))
	ferry.rotation.x = lerp_angle(ferry.rotation.x, target_pitch, clampf(delta * 0.72, 0.0, 1.0))
	ferry.rotation.z = lerp_angle(ferry.rotation.z, target_roll, clampf(delta * 0.82, 0.0, 1.0))

func _v20_sea_height(world_pos: Vector3) -> float:
	var p := Vector2(world_pos.x, world_pos.z)
	var time_seconds := Time.get_ticks_msec() * 0.001
	var time_speed := clampf(0.58 + wind_strength * 0.040, 0.58, 0.88)
	var state := clampf(0.32 + wind_strength * 0.10, 0.32, 0.86)
	var height_scale := clampf(0.40 + wind_strength * 0.095, 0.40, 0.82)
	var broad := 0.0
	broad += _v20_dir_wave(p, Vector2(1.0, 0.15), 74.0, 0.60, 0.0, time_seconds, time_speed) * 0.34
	broad += _v20_dir_wave(p, Vector2(-0.32, 1.0), 42.0, 0.92, 1.7, time_seconds, time_speed) * 0.22
	broad += _v20_dir_wave(p, Vector2(0.71, 0.69), 24.0, 1.24, 3.2, time_seconds, time_speed) * 0.13
	broad += _v20_dir_wave(p, Vector2(-0.88, 0.34), 13.5, 1.75, 2.1, time_seconds, time_speed) * 0.075
	broad += _v20_dir_wave(p, Vector2(0.17, 1.0), 7.5, 2.20, 0.8, time_seconds, time_speed) * 0.035
	return broad * height_scale * (0.58 + state * 0.70)

func _v20_dir_wave(p: Vector2, direction: Vector2, wavelength: float, speed_value: float, phase: float, time_seconds: float, time_speed: float) -> float:
	var k := TAU / wavelength
	return sin(p.dot(direction.normalized()) * k + time_seconds * time_speed * speed_value + phase)

func _update_docking_hint() -> void:
	if dock_hint == null:
		return
	var container := dock_hint.get_parent()
	if container != null:
		container.visible = route_distance_m < 650.0 and not v20_hud_hidden
	if route_distance_m < 650.0:
		super._update_docking_hint()

func _install_v20_mobile_ui() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	v20_management_buttons.clear()
	_collect_and_relayout_buttons(self)
	_build_v20_menu_buttons()
	_compact_captain_assist()
	_set_management_visible(false)

func _collect_and_relayout_buttons(node: Node) -> void:
	if node is Button:
		var button := node as Button
		var text := button.text
		if text == "SOL":
			_v20_rect(button, 0.024, 0.835, 0.102, 0.958, 20)
		elif text == "SAĞ":
			_v20_rect(button, 0.112, 0.835, 0.190, 0.958, 20)
		elif text == "GAZ +":
			_v20_rect(button, 0.810, 0.835, 0.888, 0.958, 20)
		elif text == "GAZ -":
			_v20_rect(button, 0.898, 0.835, 0.976, 0.958, 20)
		elif text == "DUR":
			_v20_rect(button, 0.462, 0.875, 0.538, 0.962, 18)
		elif text == "KAMERA":
			_v20_rect(button, 0.905, 0.735, 0.976, 0.792, 13)
		elif text.begins_with("ROTA") or text == "YÜKLE" or text == "DENGELE" or text == "AĞIR YÜK" or text.begins_with("HAVA") or text.begins_with("RAMPA") or text == "YENİ SEFER":
			v20_management_buttons.append(button)
	for child in node.get_children():
		_collect_and_relayout_buttons(child)

func _build_v20_menu_buttons() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	v20_menu_button = Button.new()
	v20_menu_button.text = "KAPTAN"
	_v20_rect(v20_menu_button, 0.904, 0.645, 0.976, 0.702, 13)
	v20_menu_button.pressed.connect(_toggle_v20_menu)
	root.add_child(v20_menu_button)

	v20_hud_button = Button.new()
	v20_hud_button.text = "HUD"
	_v20_rect(v20_hud_button, 0.904, 0.030, 0.976, 0.078, 12)
	v20_hud_button.pressed.connect(_toggle_v20_hud)
	root.add_child(v20_hud_button)

func _toggle_v20_menu() -> void:
	captain_menu_open = not captain_menu_open
	_set_management_visible(captain_menu_open)
	if v20_menu_button != null:
		v20_menu_button.text = "KAPAT" if captain_menu_open else "KAPTAN"

func _set_management_visible(show: bool) -> void:
	var y := 0.155
	for button in v20_management_buttons:
		if not is_instance_valid(button):
			continue
		button.visible = show and not v20_hud_hidden
		if show:
			_v20_rect(button, 0.835, y, 0.976, y + 0.055, 13)
			y += 0.062

func _toggle_v20_hud() -> void:
	v20_hud_hidden = not v20_hud_hidden
	captain_menu_open = false
	_set_management_visible(false)
	for text in ["SOL", "SAĞ", "GAZ +", "GAZ -", "DUR", "KAMERA"]:
		_set_named_button_visibility(self, text, not v20_hud_hidden)
	if v14_nav_label != null and v14_nav_label.get_parent() != null:
		v14_nav_label.get_parent().visible = not v20_hud_hidden
	if captain_assist_label != null and captain_assist_label.get_parent() != null:
		captain_assist_label.get_parent().visible = not v20_hud_hidden
	if v20_menu_button != null:
		v20_menu_button.visible = not v20_hud_hidden
	if v20_hud_button != null:
		v20_hud_button.text = "HUD AÇ" if v20_hud_hidden else "HUD"

func _set_named_button_visibility(node: Node, text: String, show: bool) -> void:
	if node is Button and (node as Button).text == text:
		(node as Button).visible = show
	for child in node.get_children():
		_set_named_button_visibility(child, text, show)

func _compact_captain_assist() -> void:
	if captain_assist_label == null:
		return
	var panel := captain_assist_label.get_parent() as Control
	if panel != null:
		panel.anchor_left = 0.705
		panel.anchor_top = 0.020
		panel.anchor_right = 0.895
		panel.anchor_bottom = 0.105
		panel.offset_left = 0.0
		panel.offset_top = 0.0
		panel.offset_right = 0.0
		panel.offset_bottom = 0.0
	captain_assist_label.add_theme_font_size_override("font_size", 12)
	if emergency_button != null:
		emergency_button.visible = false
		_v20_rect(emergency_button, 0.705, 0.112, 0.895, 0.162, 12)

func _v20_rect(button: Control, left: float, top: float, right: float, bottom: float, font_size: int) -> void:
	button.anchor_left = left
	button.anchor_top = top
	button.anchor_right = right
	button.anchor_bottom = bottom
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	if button is Button:
		(button as Button).add_theme_font_size_override("font_size", font_size)
