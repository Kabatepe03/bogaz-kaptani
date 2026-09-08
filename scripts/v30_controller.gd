extends "res://scripts/v23_controller.gd"

const GeoReferenceV30 = preload("res://scripts/geo_reference.gd")
const V30_TEST_SPEED_BOOST := 0.82
const V30_BOOST_START_M := 180.0
const V30_BOOST_FULL_M := 620.0

var v30_touch_roles: Dictionary = {}
var v30_speed_badge: Label
var v30_timer := 0.0

func _ready() -> void:
	super._ready()
	call_deferred("_install_v30")

func _process(delta: float) -> void:
	_sync_v30_multitouch()
	super._process(delta)
	v30_timer += delta
	if v30_timer >= 0.30:
		v30_timer = 0.0
		_update_v30_badge()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			var role: String = _v30_touch_role(touch.position)
			if not role.is_empty():
				v30_touch_roles[touch.index] = role
		else:
			v30_touch_roles.erase(touch.index)
		_sync_v30_multitouch()
		return
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		var drag_role: String = _v30_touch_role(drag.position)
		if drag_role.is_empty():
			v30_touch_roles.erase(drag.index)
		else:
			v30_touch_roles[drag.index] = drag_role
		_sync_v30_multitouch()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		v30_touch_roles.clear()
		_sync_v30_multitouch()

func _v30_touch_role(screen_position: Vector2) -> String:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return ""
	var p := Vector2(screen_position.x / viewport_size.x, screen_position.y / viewport_size.y)
	if p.y >= 0.73 and p.y <= 0.985:
		if p.x >= 0.012 and p.x <= 0.150:
			return "steer_left"
		if p.x >= 0.150 and p.x <= 0.292:
			return "steer_right"
		if p.x >= 0.700 and p.x <= 0.850:
			return "throttle_up"
		if p.x >= 0.850 and p.x <= 0.992:
			return "throttle_down"
	return ""

func _sync_v30_multitouch() -> void:
	var roles: Array = v30_touch_roles.values()
	touch_steer_left = roles.has("steer_left")
	touch_steer_right = roles.has("steer_right")
	touch_throttle_up = roles.has("throttle_up")
	touch_throttle_down = roles.has("throttle_down")

func _update_ferry(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	# Test build: faster telegraph response and extra open-water speed for quick map testing.
	# Dock/ramp zones keep the normal slow-speed physics so collision and berthing can still be tested.
	if not v23_mooring_locked:
		engine_order = move_toward(engine_order, throttle, delta * 0.36)
	super._update_ferry(delta)
	if ferry == null or v23_mooring_locked or ramp_open or engine_order <= 0.02:
		return

	var c_dock: Vector3 = GeoReferenceV30.to_local(GeoReferenceV30.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReferenceV30.to_local(GeoReferenceV30.ECEABAT_DOCK)
	var dock_distance: float = minf(ferry.global_position.distance_to(c_dock), ferry.global_position.distance_to(e_dock))
	var open_water_factor: float = smoothstep(V30_BOOST_START_M, V30_BOOST_FULL_M, dock_distance)
	var boost: float = V30_TEST_SPEED_BOOST * open_water_factor * clampf(engine_order, 0.0, 1.0)
	if boost <= 0.001 or surge_mps <= 0.0:
		return

	var forward: Vector3 = -ferry.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	ferry.global_position += forward * surge_mps * boost * delta
	velocity_knots = (surge_mps * (1.0 + boost)) / 0.514444
	ground_speed_kn = maxf(ground_speed_kn, velocity_knots)

func _install_v30() -> void:
	for _frame: int in range(28):
		await get_tree().process_frame
	_build_v30_badge()
	_retitle_v30(self)

func _build_v30_badge() -> void:
	if v30_speed_badge != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 96
	add_child(layer)
	v30_speed_badge = Label.new()
	v30_speed_badge.name = "V30TestBadge"
	v30_speed_badge.text = "V30.1 • PERFORMANS + REALİZM • TEST HIZI x1.8 • ÇOKLU DOKUNMATİK"
	v30_speed_badge.anchor_left = 0.32
	v30_speed_badge.anchor_top = 0.012
	v30_speed_badge.anchor_right = 0.68
	v30_speed_badge.anchor_bottom = 0.052
	v30_speed_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v30_speed_badge.add_theme_font_size_override("font_size", 16)
	v30_speed_badge.modulate = Color(0.92, 0.95, 0.95, 0.90)
	v30_speed_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(v30_speed_badge)

func _update_v30_badge() -> void:
	if v30_speed_badge == null:
		return
	var active_touches: int = v30_touch_roles.size()
	v30_speed_badge.text = "V30.1 • TEST %.1f kn • %d PARMAK" % [absf(ground_speed_kn), active_touches]

func _retitle_v30(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		if label.text.begins_with("V23 •") or label.text.begins_with("V22 •") or label.text.begins_with("V20 •") or label.text.begins_with("V30 •"):
			label.text = "V30.1 • PERFORMANS + ULTRA REALİZM TEST"
	for child: Node in node.get_children():
		_retitle_v30(child)
