extends "res://scripts/v14_controller.gd"

const V15_SPAWN_FROM_TERMINAL_M := 185.0
const V15_FREE_MIN_DISTANCE := 48.0
const V15_FREE_MAX_DISTANCE := 185.0

var free_camera_index: int = -1
var free_orbit_yaw: float = 0.0
var free_orbit_pitch: float = deg_to_rad(19.0)
var free_orbit_distance: float = 92.0
var free_mouse_drag: bool = false
var free_touch_points: Dictionary = {}
var free_pinch_last_distance: float = 0.0
var v15_water_material: ShaderMaterial

func _ready() -> void:
	super._ready()
	call_deferred("_install_v15_graphics_mode")

func _process(delta: float) -> void:
	super._process(delta)
	_update_v15_water()

func _install_v10_cameras() -> void:
	await get_tree().process_frame
	for cam: Camera3D in cameras:
		if is_instance_valid(cam):
			cam.current = false
			cam.queue_free()
	cameras.clear()
	v10_camera_offsets.clear()
	v10_camera_targets.clear()
	v10_camera_fovs.clear()

	_add_v10_camera("SÜRÜŞ", Vector3(0.0, 14.0, 58.0), Vector3(0.0, 3.6, -205.0), 60.0)
	_add_v10_camera("KAPTAN", Vector3(0.0, 15.8, 2.0), Vector3(0.0, 5.7, -225.0), 66.0)
	_add_v10_camera("YANAŞMA SOL", Vector3(-36.0, 20.0, 66.0), Vector3(-3.0, 3.0, -175.0), 58.0)
	_add_v10_camera("YANAŞMA SAĞ", Vector3(36.0, 20.0, 66.0), Vector3(3.0, 3.0, -175.0), 58.0)
	_add_v10_camera("DRONE ROTA", Vector3(0.0, 72.0, 126.0), Vector3(0.0, 1.2, -255.0), 54.0)
	_add_v10_camera("SERBEST 360°", Vector3(0.0, 24.0, 92.0), Vector3(0.0, 5.0, 0.0), 58.0)
	free_camera_index = cameras.size() - 1

	camera_index = 0
	if not cameras.is_empty():
		cameras[0].current = true
	_update_v10_cameras(1.0)
	_update_status()

func _update_v10_cameras(delta: float) -> void:
	if ferry == null or cameras.is_empty():
		return

	# Keep the five cinematic cameras on the tested follow-camera path.
	var original_free_index: int = free_camera_index
	free_camera_index = -1
	super._update_v10_cameras(delta)
	free_camera_index = original_free_index

	if original_free_index < 0 or original_free_index >= cameras.size():
		return
	var cam: Camera3D = cameras[original_free_index]
	if not is_instance_valid(cam):
		return

	var ship_yaw: float = ferry.global_rotation.y
	var angle: float = ship_yaw + free_orbit_yaw
	var horizontal: float = cos(free_orbit_pitch) * free_orbit_distance
	var vertical: float = sin(free_orbit_pitch) * free_orbit_distance
	var offset: Vector3 = Vector3(sin(angle) * horizontal, vertical + 6.0, cos(angle) * horizontal)
	var desired_position: Vector3 = ferry.global_position + offset
	var lerp_weight: float = clampf(delta * 7.0, 0.0, 1.0)
	cam.global_position = cam.global_position.lerp(desired_position, lerp_weight)
	cam.look_at(ferry.global_position + Vector3(0.0, 5.0, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if free_camera_index < 0 or camera_index != free_camera_index:
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			free_touch_points[touch.index] = touch.position
		else:
			free_touch_points.erase(touch.index)
			free_pinch_last_distance = 0.0
		if free_touch_points.size() == 2:
			free_pinch_last_distance = _touch_distance()
		return

	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		free_touch_points[drag.index] = drag.position
		if free_touch_points.size() >= 2:
			var current_distance: float = _touch_distance()
			if free_pinch_last_distance > 1.0:
				free_orbit_distance = clampf(free_orbit_distance - (current_distance - free_pinch_last_distance) * 0.12, V15_FREE_MIN_DISTANCE, V15_FREE_MAX_DISTANCE)
			free_pinch_last_distance = current_distance
		else:
			free_orbit_yaw -= drag.relative.x * 0.0052
			free_orbit_pitch = clampf(free_orbit_pitch - drag.relative.y * 0.0036, deg_to_rad(7.0), deg_to_rad(62.0))
		return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			free_mouse_drag = mouse_button.pressed
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			free_orbit_distance = maxf(V15_FREE_MIN_DISTANCE, free_orbit_distance - 8.0)
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			free_orbit_distance = minf(V15_FREE_MAX_DISTANCE, free_orbit_distance + 8.0)
		return

	if event is InputEventMouseMotion and free_mouse_drag:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		free_orbit_yaw -= motion.relative.x * 0.0052
		free_orbit_pitch = clampf(free_orbit_pitch - motion.relative.y * 0.0036, deg_to_rad(7.0), deg_to_rad(62.0))

func _touch_distance() -> float:
	if free_touch_points.size() < 2:
		return 0.0
	var points: Array = free_touch_points.values()
	var p0: Vector2 = points[0]
	var p1: Vector2 = points[1]
	return p0.distance_to(p1)

func _reset_route() -> void:
	super._reset_route()
	if ferry == null:
		return

	var canakkale_terminal: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat_terminal: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var canakkale_to_eceabat: Vector3 = (eceabat_terminal - canakkale_terminal).normalized()
	var start_terminal: Vector3 = canakkale_terminal if route_forward else eceabat_terminal
	var route_dir: Vector3 = canakkale_to_eceabat if route_forward else -canakkale_to_eceabat

	# V8 terminal asphalt reaches roughly 140 m offshore. Starting at 185 m leaves the complete
	# 76 m ferry in open water instead of intersecting the pier/road geometry.
	ferry.global_position = start_terminal + route_dir * V15_SPAWN_FROM_TERMINAL_M + Vector3(0.0, 2.0, 0.0)
	ferry.look_at(route_target + Vector3(0.0, 2.0, 0.0), Vector3.UP)
	route_distance_m = ferry.global_position.distance_to(route_target)

func _install_v15_graphics_mode() -> void:
	await get_tree().process_frame
	var water_node: Node = find_child("V12RealWater", true, false)
	if water_node is MeshInstance3D:
		var water_mesh: MeshInstance3D = water_node as MeshInstance3D
		if water_mesh.material_override is ShaderMaterial:
			v15_water_material = water_mesh.material_override as ShaderMaterial

	# Remove the huge glowing docking plane until the captain is actually approaching.
	if canakkale_zone != null:
		canakkale_zone.visible = false
	if eceabat_zone != null:
		eceabat_zone.visible = false
	_retitle_v15(self)
	_update_v14_nav()

func _update_dock_visibility() -> void:
	if canakkale_zone != null:
		canakkale_zone.visible = (not route_forward) and route_distance_m < 650.0
	if eceabat_zone != null:
		eceabat_zone.visible = route_forward and route_distance_m < 650.0

func _update_v15_water() -> void:
	if v15_water_material == null:
		return
	var weather_wave: float = clampf(0.46 + wind_strength * 0.075, 0.46, 0.78)
	var weather_speed: float = clampf(0.38 + wind_strength * 0.045, 0.38, 0.68)
	v15_water_material.set_shader_parameter("wave_height", weather_wave)
	v15_water_material.set_shader_parameter("speed", weather_speed)

func _update_v14_nav() -> void:
	if v14_nav_label == null or ferry == null or cameras.is_empty():
		return
	var target_name: String = "ECEABAT" if route_forward else "ÇANAKKALE"
	var cam_name: String = cameras[camera_index].name if camera_index < cameras.size() else "SÜRÜŞ"
	var second_line: String = "%.1f kn  •  Gaz %d%%  •  %s" % [absf(ground_speed_kn), int(round(throttle * 100.0)), cam_name]
	if camera_index == free_camera_index:
		second_line = "SERBEST 360° • sürükle: döndür • 2 parmak: zoom"
	v14_nav_label.text = "BOĞAZ KAPTANI V15 • %s • %.0f m\n%s" % [target_name, maxf(route_distance_m, 0.0), second_line]

func _retitle_v15(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		if label.text.begins_with("V14 •") or label.text.begins_with("V13 •") or label.text.begins_with("V12 •"):
			label.text = "V15 • BÜYÜK GRAFİK SIÇRAMASI"
	for child: Node in node.get_children():
		_retitle_v15(child)
