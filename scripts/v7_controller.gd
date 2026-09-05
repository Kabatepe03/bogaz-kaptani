extends "res://scripts/main.gd"

const VehicleFactory = preload("res://scripts/vehicle_factory.gd")
const TrafficFactory = preload("res://scripts/traffic_factory.gd")

const WEATHER_NAMES := ["AÇIK", "RÜZGAR", "SİS", "GECE"]
const VEHICLE_COLORS := [
	Color(0.72, 0.10, 0.08),
	Color(0.08, 0.23, 0.60),
	Color(0.84, 0.84, 0.80),
	Color(0.12, 0.14, 0.16),
	Color(0.10, 0.46, 0.30),
	Color(0.78, 0.52, 0.08)
]

var route_forward := true
var route_start := Vector3.ZERO
var route_target := Vector3.ZERO
var route_distance_m := 0.0
var elapsed_seconds := 0.0
var trip_finished := false
var trip_score := 0

var weather_index := 0
var wind_strength := 0.0
var current_strength := 0.18
var wind_vector := Vector3(0.70, 0.0, -0.28).normalized()
var current_vector := Vector3(-0.28, 0.0, -0.96).normalized()

var cargo_root: Node3D
var port_tons := 0.0
var starboard_tons := 0.0
var cargo_tons := 0.0
var base_load_roll := 0.0
var damage := 0.0
var comfort := 100.0
var ramp_open := false

var ai_ships: Array[CharacterBody3D] = []
var traffic_center := Vector3.ZERO
var collision_cooldown := 0.0

var v7_status: Label
var route_button: Button
var weather_button: Button
var ramp_button: Button
var result_panel: ColorRect
var result_label: Label

func _ready() -> void:
	super._ready()
	_setup_v7_cameras()
	_setup_dynamic_cargo()
	_spawn_ai_traffic()
	_build_v7_ui()
	_reset_route()
	_load_balanced_cargo()
	_apply_weather()

func _process(delta: float) -> void:
	if trip_finished:
		steer = 0.0
		touch_steer_left = false
		touch_steer_right = false
		touch_throttle_up = false
		touch_throttle_down = false
		throttle = move_toward(throttle, 0.0, delta * 0.8)
	else:
		_update_dynamic_roll()

	super._process(delta)

	if not trip_finished:
		elapsed_seconds += delta
		_apply_current_and_wind(delta)
		_update_traffic(delta)
		_update_trip_state(delta)
	else:
		_update_traffic(delta)

	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	_update_v7_hud()

func _setup_v7_cameras() -> void:
	_add_camera(Vector3(0, 7.4, -24.0), Vector3(0, 5.2, 7.0), "Kıç Kamera")
	_add_camera(Vector3(0, 7.4, -5.5), Vector3(0, 6.2, -27.0), "Güverte")

func _setup_dynamic_cargo() -> void:
	var old_vehicles := ferry.get_node_or_null("Vehicles")
	if old_vehicles != null:
		old_vehicles.visible = false
	cargo_root = Node3D.new()
	cargo_root.name = "DynamicCargo"
	ferry.add_child(cargo_root)

func _clear_cargo() -> void:
	if cargo_root == null:
		return
	for child in cargo_root.get_children():
		child.queue_free()
	port_tons = 0.0
	starboard_tons = 0.0
	cargo_tons = 0.0

func _add_cargo_vehicle(kind: String, x: float, z: float, color_index: int) -> void:
	var vehicle := VehicleFactory.create_vehicle(kind, Vector3(x, 5.62, z), VEHICLE_COLORS[color_index % VEHICLE_COLORS.size()])
	cargo_root.add_child(vehicle)
	var weight := VehicleFactory.weight_for(kind)
	cargo_tons += weight
	if x < 0.0:
		port_tons += weight
	else:
		starboard_tons += weight

func _load_balanced_cargo() -> void:
	_clear_cargo()
	var manifest := [
		["truck", -6.3, -13.0], ["truck", 6.3, -13.0],
		["bus", -6.3, 1.5], ["bus", 6.3, 1.5],
		["minibus", -2.2, -15.5], ["minibus", 2.2, -15.5],
		["car", -2.2, -7.0], ["car", 2.2, -7.0],
		["car", -6.3, 15.0], ["car", 6.3, 15.0],
		["car", -2.2, 15.0], ["car", 2.2, 15.0]
	]
	for i in range(manifest.size()):
		var item: Array = manifest[i]
		_add_cargo_vehicle(str(item[0]), float(item[1]), float(item[2]), i)
	_recalculate_load_roll()

func _load_random_cargo() -> void:
	_clear_cargo()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var kinds := ["car", "car", "car", "minibus", "bus", "truck", "truck"]
	var slots := [
		Vector2(-6.3,-16.0), Vector2(-2.2,-16.0), Vector2(2.2,-16.0), Vector2(6.3,-16.0),
		Vector2(-6.3,-5.0), Vector2(-2.2,-5.0), Vector2(2.2,-5.0), Vector2(6.3,-5.0),
		Vector2(-6.3,7.0), Vector2(-2.2,7.0), Vector2(2.2,7.0), Vector2(6.3,7.0),
		Vector2(-6.3,18.0), Vector2(-2.2,18.0), Vector2(2.2,18.0), Vector2(6.3,18.0)
	]
	slots.shuffle()
	var count := rng.randi_range(9, 14)
	for i in range(count):
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var slot: Vector2 = slots[i]
		_add_cargo_vehicle(kind, slot.x, slot.y, rng.randi_range(0, VEHICLE_COLORS.size() - 1))
	_recalculate_load_roll()

func _load_dangerous_cargo() -> void:
	_clear_cargo()
	var manifest := [
		["truck", 6.3, -14.0], ["truck", 6.3, 0.0], ["truck", 6.3, 14.0],
		["bus", 2.2, -13.0], ["bus", 2.2, 1.0], ["minibus", 2.2, 14.0],
		["car", -6.3, -10.0], ["car", -6.3, 5.0]
	]
	for i in range(manifest.size()):
		var item: Array = manifest[i]
		_add_cargo_vehicle(str(item[0]), float(item[1]), float(item[2]), i)
	_recalculate_load_roll()

func _recalculate_load_roll() -> void:
	var delta_tons := starboard_tons - port_tons
	base_load_roll = clampf(delta_tons * 0.20, -14.0, 14.0)
	load_roll_deg = base_load_roll

func _update_dynamic_roll() -> void:
	var weather_roll := sin(Time.get_ticks_msec() * 0.00165) * wind_strength * 0.75
	load_roll_deg = base_load_roll + weather_roll
	var roll_abs := absf(load_roll_deg)
	var comfort_loss := roll_abs * 0.012 + absf(steer * velocity_knots) * 0.006 + wind_strength * 0.015
	comfort = clampf(comfort - comfort_loss + 0.018, 0.0, 100.0)
	if roll_abs > 11.5:
		damage = minf(100.0, damage + (roll_abs - 11.5) * 0.006)
	if roll_abs > 15.0:
		_finish_trip(false, "ALABORA RİSKİ")

func _spawn_ai_traffic() -> void:
	var canakkale := GeoReference.to_local(GeoReference.CANAKKALE)
	var eceabat := GeoReference.to_local(GeoReference.ECEABAT)
	traffic_center = (canakkale + eceabat) * 0.5
	var specs := [
		["cargo", Vector3(-620, 1.0, -980), 22.0],
		["cargo", Vector3(520, 1.0, 720), 202.0],
		["ferry", Vector3(-300, 1.0, 420), 105.0],
		["ferry", Vector3(380, 1.0, -360), -75.0]
	]
	for spec in specs:
		var ship := TrafficFactory.create_ship(str(spec[0]), traffic_center + spec[1], float(spec[2]))
		add_child(ship)
		ai_ships.append(ship)

func _update_traffic(delta: float) -> void:
	for ship in ai_ships:
		if not is_instance_valid(ship):
			continue
		var speed := float(ship.get_meta("speed_mps", 4.0))
		ship.global_position += -ship.global_transform.basis.z * speed * delta
		if ship.global_position.distance_to(traffic_center) > 3300.0:
			ship.rotation.y += PI
		if ferry != null and ship.global_position.distance_to(ferry.global_position) < 42.0 and collision_cooldown <= 0.0:
			damage = minf(100.0, damage + 18.0)
			comfort = maxf(0.0, comfort - 22.0)
			collision_cooldown = 3.0

func _apply_current_and_wind(delta: float) -> void:
	if ferry == null:
		return
	ferry.global_position += current_vector * current_strength * delta
	ferry.global_position += wind_vector * wind_strength * 0.11 * delta

func _reset_route() -> void:
	trip_finished = false
	trip_score = 0
	elapsed_seconds = 0.0
	damage = 0.0
	comfort = 100.0
	throttle = 0.0
	velocity_knots = 0.0
	var canakkale := GeoReference.to_local(GeoReference.CANAKKALE)
	var eceabat := GeoReference.to_local(GeoReference.ECEABAT)
	if route_forward:
		route_start = canakkale
		route_target = eceabat
	else:
		route_start = eceabat
		route_target = canakkale
	var route_dir := (route_target - route_start).normalized()
	ferry.global_position = route_start + route_dir * 95.0 + Vector3(0, 2.0, 0)
	ferry.look_at(route_target + Vector3(0, 2.0, 0), Vector3.UP)
	if result_panel != null:
		result_panel.visible = false
	_update_route_button()

func _update_trip_state(delta: float) -> void:
	if ferry == null:
		return
	route_distance_m = ferry.global_position.distance_to(route_target)
	if route_distance_m < 90.0:
		if absf(velocity_knots) <= 3.2:
			_finish_trip(true, "YUMUŞAK YANAŞMA")
		elif absf(velocity_knots) > 7.5:
			damage = minf(100.0, damage + delta * 9.0)
	if damage >= 100.0:
		_finish_trip(false, "AĞIR HASAR")

func _finish_trip(success: bool, reason: String) -> void:
	if trip_finished:
		return
	trip_finished = true
	throttle = 0.0
	var balance_score := clampf(100.0 - absf(starboard_tons - port_tons) * 1.3, 0.0, 100.0)
	var damage_score := clampf(100.0 - damage, 0.0, 100.0)
	var comfort_score := comfort
	var time_score := clampf(100.0 - maxf(0.0, elapsed_seconds - 520.0) * 0.08, 35.0, 100.0)
	trip_score = int(round((balance_score * 0.28) + (damage_score * 0.28) + (comfort_score * 0.24) + (time_score * 0.20)))
	if not success:
		trip_score = mini(trip_score, 45)
	_show_result(success, reason, balance_score)

func _build_v7_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var badge := Label.new()
	badge.text = "V7 • BÜYÜK GÜNCELLEME"
	badge.anchor_left = 0.40
	badge.anchor_top = 0.025
	badge.anchor_right = 0.60
	badge.anchor_bottom = 0.075
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 20)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(badge)

	var status_bg := ColorRect.new()
	status_bg.color = Color(0.012, 0.022, 0.032, 0.78)
	status_bg.anchor_left = 0.34
	status_bg.anchor_top = 0.085
	status_bg.anchor_right = 0.67
	status_bg.anchor_bottom = 0.205
	status_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_bg)
	v7_status = Label.new()
	v7_status.anchor_left = 0.03
	v7_status.anchor_top = 0.08
	v7_status.anchor_right = 0.97
	v7_status.anchor_bottom = 0.95
	v7_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v7_status.add_theme_font_size_override("font_size", 19)
	v7_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_bg.add_child(v7_status)

	route_button = _v7_button(root, "ROTA", 0.015, 0.23, 0.135, 0.315)
	route_button.pressed.connect(_on_route_pressed)
	var load_button := _v7_button(root, "YÜKLE", 0.015, 0.33, 0.135, 0.415)
	load_button.pressed.connect(_on_load_pressed)
	var balance_button := _v7_button(root, "DENGELE", 0.015, 0.43, 0.135, 0.515)
	balance_button.pressed.connect(_on_balance_pressed)
	var danger_button := _v7_button(root, "AĞIR YÜK", 0.015, 0.53, 0.135, 0.615)
	danger_button.pressed.connect(_on_danger_pressed)

	weather_button = _v7_button(root, "HAVA", 0.865, 0.23, 0.985, 0.315)
	weather_button.pressed.connect(_on_weather_pressed)
	ramp_button = _v7_button(root, "RAMPA", 0.865, 0.33, 0.985, 0.415)
	ramp_button.pressed.connect(_on_ramp_pressed)
	var restart_button := _v7_button(root, "YENİ SEFER", 0.865, 0.43, 0.985, 0.515)
	restart_button.pressed.connect(_on_restart_pressed)

	result_panel = ColorRect.new()
	result_panel.color = Color(0.01, 0.02, 0.03, 0.92)
	result_panel.anchor_left = 0.31
	result_panel.anchor_top = 0.28
	result_panel.anchor_right = 0.69
	result_panel.anchor_bottom = 0.67
	result_panel.visible = false
	root.add_child(result_panel)
	result_label = Label.new()
	result_label.anchor_left = 0.06
	result_label.anchor_top = 0.08
	result_label.anchor_right = 0.94
	result_label.anchor_bottom = 0.92
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 26)
	result_panel.add_child(result_label)

func _v7_button(parent: Control, text_value: String, left: float, top: float, right: float, bottom: float) -> Button:
	var button := Button.new()
	button.text = text_value
	button.anchor_left = left
	button.anchor_top = top
	button.anchor_right = right
	button.anchor_bottom = bottom
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 19)
	parent.add_child(button)
	return button

func _update_v7_hud() -> void:
	if v7_status == null:
		return
	var imbalance := starboard_tons - port_tons
	var route_name := "ÇANAKKALE → ECEABAT" if route_forward else "ECEABAT → ÇANAKKALE"
	v7_status.text = "%s   •   Kalan %.0f m\nYük %.1f t   Denge %+0.1f t   Yatış %+0.1f°   Hasar %.0f%%   Konfor %.0f%%" % [route_name, route_distance_m, cargo_tons, imbalance, load_roll_deg, damage, comfort]
	if weather_button != null:
		weather_button.text = "HAVA: %s" % WEATHER_NAMES[weather_index]
	if ramp_button != null:
		ramp_button.text = "RAMPA: %s" % ("AÇIK" if ramp_open else "KAPALI")

func _update_route_button() -> void:
	if route_button == null:
		return
	route_button.text = "ROTA: %s" % ("E→" if route_forward else "Ç→")

func _apply_weather() -> void:
	var world_env: WorldEnvironment = null
	var sun: DirectionalLight3D = null
	for child in get_children():
		if child is WorldEnvironment:
			world_env = child as WorldEnvironment
		elif child is DirectionalLight3D:
			sun = child as DirectionalLight3D
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment
	var sky_mat: ProceduralSkyMaterial = null
	if env.sky != null and env.sky.sky_material is ProceduralSkyMaterial:
		sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	match weather_index:
		0:
			wind_strength = 0.0
			current_strength = 0.18
			env.fog_density = 0.00010
			env.ambient_light_energy = 0.76
			if sun: sun.light_energy = 1.72
			if sky_mat:
				sky_mat.sky_top_color = Color(0.10, 0.36, 0.68)
				sky_mat.sky_horizon_color = Color(0.60, 0.78, 0.90)
		1:
			wind_strength = 2.2
			current_strength = 0.34
			env.fog_density = 0.00013
			env.ambient_light_energy = 0.66
			if sun: sun.light_energy = 1.35
			if sky_mat:
				sky_mat.sky_top_color = Color(0.19, 0.28, 0.38)
				sky_mat.sky_horizon_color = Color(0.52, 0.60, 0.65)
		2:
			wind_strength = 0.45
			current_strength = 0.20
			env.fog_density = 0.00062
			env.ambient_light_energy = 0.52
			if sun: sun.light_energy = 0.72
			if sky_mat:
				sky_mat.sky_top_color = Color(0.48, 0.54, 0.58)
				sky_mat.sky_horizon_color = Color(0.70, 0.72, 0.71)
		3:
			wind_strength = 0.75
			current_strength = 0.22
			env.fog_density = 0.00018
			env.ambient_light_energy = 0.20
			if sun: sun.light_energy = 0.12
			if sky_mat:
				sky_mat.sky_top_color = Color(0.008, 0.018, 0.045)
				sky_mat.sky_horizon_color = Color(0.035, 0.065, 0.10)

func _show_result(success: bool, reason: String, balance_score: float) -> void:
	if result_panel == null or result_label == null:
		return
	result_panel.visible = true
	var title := "SEFER TAMAMLANDI" if success else "SEFER BAŞARISIZ"
	result_label.text = "%s\n%s\n\nKaptanlık Puanı: %d / 100\nDenge: %.0f   Konfor: %.0f   Hasar: %.0f%%\nSüre: %d dk %d sn" % [title, reason, trip_score, balance_score, comfort, damage, int(elapsed_seconds) / 60, int(elapsed_seconds) % 60]

func _on_route_pressed() -> void:
	route_forward = not route_forward
	_reset_route()

func _on_load_pressed() -> void:
	_load_random_cargo()

func _on_balance_pressed() -> void:
	_load_balanced_cargo()

func _on_danger_pressed() -> void:
	_load_dangerous_cargo()

func _on_weather_pressed() -> void:
	weather_index = (weather_index + 1) % WEATHER_NAMES.size()
	_apply_weather()

func _on_ramp_pressed() -> void:
	ramp_open = not ramp_open
	var front_ramp := ferry.get_node_or_null("RampFront")
	var rear_ramp := ferry.get_node_or_null("RampRear")
	var angle := -22.0 if ramp_open else 0.0
	if front_ramp != null:
		front_ramp.rotation_degrees.x = angle
	if rear_ramp != null:
		rear_ramp.rotation_degrees.x = -angle

func _on_restart_pressed() -> void:
	_reset_route()
