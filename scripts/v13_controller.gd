extends "res://scripts/v12_controller.gd"

const V13_ROLL_CAUTION_DEG := 8.0
const V13_ROLL_CRITICAL_DEG := 13.0
const V13_ROLL_EMERGENCY_DEG := 18.0
const V13_ROLL_FAIL_DEG := 22.0
const V13_FAIL_HOLD_SECONDS := 5.0
const V13_STABILIZER_COOLDOWN := 12.0

var captain_assist_label: Label
var stability_bar: ProgressBar
var emergency_button: Button
var stabilizer_cooldown := 0.0
var stability_state := "DENGELİ"
var stability_risk := 0.0

func _ready() -> void:
	super._ready()
	call_deferred("_install_v13_captain_assist")

func _process(delta: float) -> void:
	super._process(delta)
	stabilizer_cooldown = maxf(0.0, stabilizer_cooldown - delta)
	_update_v13_assist()

func _update_dynamic_roll() -> void:
	# v13 makes heel progressive and recoverable: a brief high-roll event warns first,
	# while a sustained dangerous condition is required to end the voyage.
	var delta: float = maxf(0.001, get_process_delta_time())
	var weather_roll: float = sin(Time.get_ticks_msec() * 0.00165) * wind_strength * 0.68
	var turn_roll: float = rad_to_deg(yaw_rate) * surge_mps * 0.24
	var drift_roll: float = sway_mps * 0.72
	load_roll_deg = base_load_roll + weather_roll + turn_roll + drift_roll

	var roll_abs: float = absf(load_roll_deg)
	var comfort_loss: float = roll_abs * 0.009 + absf(rudder_state * velocity_knots) * 0.0045 + wind_strength * 0.010
	comfort = clampf(comfort - comfort_loss + 0.020, 0.0, 100.0)

	if roll_abs > 15.0:
		damage = minf(100.0, damage + (roll_abs - 15.0) * 0.012 * delta)

	if roll_abs >= V13_ROLL_FAIL_DEG:
		critical_roll_timer += delta
	else:
		critical_roll_timer = maxf(0.0, critical_roll_timer - delta * 1.8)

	if roll_abs < V13_ROLL_CAUTION_DEG:
		stability_state = "DENGELİ"
	elif roll_abs < V13_ROLL_CRITICAL_DEG:
		stability_state = "DENGE UYARISI"
	elif roll_abs < V13_ROLL_EMERGENCY_DEG:
		stability_state = "KRİTİK YATIŞ"
	else:
		stability_state = "ACİL DURUM"

	stability_risk = clampf((roll_abs / 24.0) * 100.0, 0.0, 100.0)

	if critical_roll_timer >= V13_FAIL_HOLD_SECONDS and not trip_finished:
		_finish_trip(false, "SÜREKLİ KRİTİK YATIŞ")

func _install_v13_captain_assist() -> void:
	await get_tree().process_frame
	_retitle_v13(self)

	var layer := CanvasLayer.new()
	layer.layer = 18
	add_child(layer)

	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var panel := ColorRect.new()
	panel.color = Color(0.008, 0.024, 0.034, 0.84)
	panel.anchor_left = 0.705
	panel.anchor_top = 0.025
	panel.anchor_right = 0.985
	panel.anchor_bottom = 0.205
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	captain_assist_label = Label.new()
	captain_assist_label.anchor_left = 0.035
	captain_assist_label.anchor_top = 0.05
	captain_assist_label.anchor_right = 0.965
	captain_assist_label.anchor_bottom = 0.78
	captain_assist_label.add_theme_font_size_override("font_size", 16)
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
	emergency_button.anchor_left = 0.705
	emergency_button.anchor_top = 0.215
	emergency_button.anchor_right = 0.855
	emergency_button.anchor_bottom = 0.282
	emergency_button.add_theme_font_size_override("font_size", 16)
	emergency_button.mouse_filter = Control.MOUSE_FILTER_STOP
	emergency_button.pressed.connect(_on_emergency_balance_pressed)
	root.add_child(emergency_button)

	_update_v13_assist()

func _retitle_v13(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.text.begins_with("V12 •") or label.text.begins_with("V7 •"):
			label.text = "V13 • KAPTAN ASİSTANI + GERÇEK DÜNYA"
	for child in node.get_children():
		_retitle_v13(child)

func _on_emergency_balance_pressed() -> void:
	if trip_finished or stabilizer_cooldown > 0.0:
		return

	# Simulated emergency ballast / trim correction. It does not magically erase cargo;
	# it reduces list and rotational energy enough to give the captain a recovery window.
	base_load_roll = move_toward(base_load_roll, 0.0, 7.0)
	load_roll_deg = base_load_roll
	sway_mps *= 0.48
	yaw_rate *= 0.48
	rudder_state *= 0.55
	engine_order = clampf(engine_order, -0.25, 0.25)
	throttle = clampf(throttle, -0.25, 0.25)
	critical_roll_timer *= 0.25
	comfort = maxf(0.0, comfort - 3.0)
	damage = minf(100.0, damage + 0.5)
	stabilizer_cooldown = V13_STABILIZER_COOLDOWN

func _update_v13_assist() -> void:
	if captain_assist_label == null or ferry == null:
		return

	var target_name: String = "ECEABAT" if route_forward else "ÇANAKKALE"
	var distance_m: float = maxf(0.0, route_distance_m)
	var speed_mps: float = maxf(0.0, ground_speed_kn * 0.514444)
	var eta_text := "--:--"
	if speed_mps > 0.35:
		var eta_seconds: int = int(round(distance_m / speed_mps))
		var eta_minutes: int = eta_seconds / 60
		var eta_remainder: int = eta_seconds % 60
		eta_text = "%02d:%02d" % [eta_minutes, eta_remainder]

	var heading_deg: float = fposmod(-rad_to_deg(ferry.global_rotation.y), 360.0)
	var roll_abs: float = absf(load_roll_deg)
	var recovery_text := "HAZIR"
	if stabilizer_cooldown > 0.0:
		recovery_text = "%ds" % int(ceil(stabilizer_cooldown))

	captain_assist_label.text = "V13 KAPTAN ASİSTANI\nHedef %s • %.0f m • ETA %s\nBaş %.0f° • Su %.1f kn • Yer %.1f kn\nSapma %.1f° • Yatış %.1f° • %s" % [
		target_name,
		distance_m,
		eta_text,
		heading_deg,
		absf(velocity_knots),
		ground_speed_kn,
		drift_angle_deg,
		roll_abs,
		stability_state
	]

	if stability_bar != null:
		stability_bar.value = stability_risk
	if emergency_button != null:
		emergency_button.disabled = trip_finished or stabilizer_cooldown > 0.0
		emergency_button.text = "ACİL DENGELE" if stabilizer_cooldown <= 0.0 else "DENGE %s" % recovery_text

	if stability_state == "DENGELİ":
		captain_assist_label.modulate = Color(0.86, 1.0, 0.90)
	elif stability_state == "DENGE UYARISI":
		captain_assist_label.modulate = Color(1.0, 0.90, 0.44)
	elif stability_state == "KRİTİK YATIŞ":
		captain_assist_label.modulate = Color(1.0, 0.61, 0.20)
	else:
		captain_assist_label.modulate = Color(1.0, 0.30, 0.24)
