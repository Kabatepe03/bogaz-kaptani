extends "res://scripts/v22_controller.gd"

var v22_notice: Label
var v22_notice_timer: float = 0.0

func _ready() -> void:
	super._ready()
	call_deferred("_install_v22_safety_ui")

func _process(delta: float) -> void:
	super._process(delta)
	if v22_notice_timer > 0.0:
		v22_notice_timer = maxf(0.0, v22_notice_timer - delta)
		if v22_notice != null:
			v22_notice.visible = v22_notice_timer > 0.0
	_enforce_ramp_safety()

func _on_ramp_pressed() -> void:
	if ramp_open:
		ramp_open = false
		_apply_ramp_visual(false)
		_show_v22_notice("RAMPA KAPATILDI")
		return
	if not _v22_safe_for_ramp():
		_show_v22_notice("RAMPA KİLİTLİ • İskelede dur ve motoru boşa al")
		return
	ramp_open = true
	_apply_ramp_visual(true)
	_show_v22_notice("RAMPA AÇIK • ARAÇ TAHLİYESİ/YÜKLEME")

func _on_load_pressed() -> void:
	if not _v22_safe_for_loading():
		_show_v22_notice("YÜKLEME KİLİTLİ • Önce iskeleye emniyetli yanaş")
		return
	super._on_load_pressed()

func _on_balance_pressed() -> void:
	if not _v22_safe_for_loading():
		_show_v22_notice("DENGELEME KİLİTLİ • İşlem yalnız iskelede")
		return
	super._on_balance_pressed()

func _on_danger_pressed() -> void:
	if not _v22_safe_for_loading():
		_show_v22_notice("AĞIR YÜK KİLİTLİ • İşlem yalnız iskelede")
		return
	super._on_danger_pressed()

func _v22_safe_for_ramp() -> bool:
	return _distance_to_nearest_berth() < 30.0 and ground_speed_kn < 0.55 and absf(engine_order) < 0.08

func _v22_safe_for_loading() -> bool:
	return _distance_to_nearest_berth() < 34.0 and ground_speed_kn < 0.45 and absf(engine_order) < 0.06 and ramp_open

func _distance_to_nearest_berth() -> float:
	if ferry == null:
		return 99999.0
	var a: float = ferry.global_position.distance_to(canakkale_stop)
	var b: float = ferry.global_position.distance_to(eceabat_stop)
	return minf(a, b)

func _enforce_ramp_safety() -> void:
	if not ramp_open:
		return
	if ground_speed_kn > 0.85 or absf(engine_order) > 0.14 or _distance_to_nearest_berth() > 40.0:
		ramp_open = false
		_apply_ramp_visual(false)
		_show_v22_notice("EMNİYET • Rampa otomatik kapandı")

func _apply_ramp_visual(opened: bool) -> void:
	var angle: float = -22.0 if opened else 0.0
	var front_ramp: Node = ferry.get_node_or_null("RampFront") if ferry != null else null
	var rear_ramp: Node = ferry.get_node_or_null("RampRear") if ferry != null else null
	if front_ramp is Node3D:
		(front_ramp as Node3D).rotation_degrees.x = angle
	if rear_ramp is Node3D:
		(rear_ramp as Node3D).rotation_degrees.x = -angle
	if ramp_button != null:
		ramp_button.text = "RAMPA: %s" % ("AÇIK" if opened else "KAPALI")

func _install_v22_safety_ui() -> void:
	for _frame: int in range(20):
		await get_tree().process_frame
	var layer := CanvasLayer.new()
	layer.layer = 62
	add_child(layer)
	v22_notice = Label.new()
	v22_notice.anchor_left = 0.32
	v22_notice.anchor_top = 0.145
	v22_notice.anchor_right = 0.68
	v22_notice.anchor_bottom = 0.188
	v22_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v22_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v22_notice.add_theme_font_size_override("font_size", 12)
	v22_notice.modulate = Color(0.96, 0.88, 0.66, 0.94)
	v22_notice.visible = false
	v22_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(v22_notice)

func _show_v22_notice(text_value: String) -> void:
	if v22_notice == null:
		return
	v22_notice.text = text_value
	v22_notice.visible = true
	v22_notice_timer = 2.6
