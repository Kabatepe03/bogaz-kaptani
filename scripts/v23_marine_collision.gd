extends Node

const FERRY_HALF_LENGTH := 40.0
const FERRY_HALF_BEAM := 7.8

var controller: Node
var ferry: Node3D
var vessels: Array[Node3D] = []
var last_safe_position: Vector3 = Vector3.ZERO
var last_safe_rotation: Vector3 = Vector3.ZERO
var have_safe_pose: bool = false
var cooldown: float = 0.0
var refresh_timer: float = 0.0
var warning_timer: float = 0.0
var warning_label: Label

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _frame: int in range(34):
		await get_tree().process_frame
	controller = get_tree().current_scene
	if controller == null:
		return
	var found: Node = controller.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	ferry = found as Node3D
	last_safe_position = ferry.global_position
	last_safe_rotation = ferry.global_rotation
	have_safe_pose = true
	_install_ui()
	_refresh_vessels()

func _physics_process(delta: float) -> void:
	if ferry == null or controller == null:
		return
	cooldown = maxf(0.0, cooldown - delta)
	warning_timer = maxf(0.0, warning_timer - delta)
	refresh_timer += delta
	if warning_label != null:
		warning_label.visible = warning_timer > 0.0
	if refresh_timer >= 1.5:
		refresh_timer = 0.0
		_refresh_vessels()

	var collided: Node3D = _find_collision()
	if collided == null:
		if cooldown <= 0.0:
			last_safe_position = ferry.global_position
			last_safe_rotation = ferry.global_rotation
			have_safe_pose = true
		return
	_resolve_collision(collided)

func _refresh_vessels() -> void:
	vessels.clear()
	if controller == null:
		return
	var root: Node = controller.find_child("V20_Dardanelles_Marine_Traffic", true, false)
	if root != null:
		for child: Node in root.get_children():
			if child is Node3D and child.has_meta("v23_half_length"):
				vessels.append(child as Node3D)
	var opposite: Node = controller.find_child("V20_Opposite_Route_Ferry", true, false)
	if opposite is Node3D and opposite.has_meta("v23_half_length"):
		vessels.append(opposite as Node3D)

func _find_collision() -> Node3D:
	if cooldown > 0.0:
		return null
	var samples: Array[Vector3] = [
		Vector3(0.0, 0.0, -FERRY_HALF_LENGTH), Vector3(0.0, 0.0, FERRY_HALF_LENGTH),
		Vector3(-FERRY_HALF_BEAM, 0.0, -31.0), Vector3(FERRY_HALF_BEAM, 0.0, -31.0),
		Vector3(-FERRY_HALF_BEAM, 0.0, 0.0), Vector3(FERRY_HALF_BEAM, 0.0, 0.0),
		Vector3(-FERRY_HALF_BEAM, 0.0, 31.0), Vector3(FERRY_HALF_BEAM, 0.0, 31.0)
	]
	for vessel: Node3D in vessels:
		if not is_instance_valid(vessel) or not vessel.visible:
			continue
		var half_length: float = float(vessel.get_meta("v23_half_length", 20.0))
		var half_beam: float = float(vessel.get_meta("v23_half_beam", 6.0))
		if ferry.global_position.distance_to(vessel.global_position) > half_length + FERRY_HALF_LENGTH + 35.0:
			continue
		var inv: Transform3D = vessel.global_transform.affine_inverse()
		for local_sample: Vector3 in samples:
			var world_sample: Vector3 = ferry.global_transform * local_sample
			var v: Vector3 = inv * world_sample
			if absf(v.x) <= half_beam + 1.25 and absf(v.z) <= half_length + 1.25 and absf(v.y) <= 11.0:
				return vessel
	return null

func _resolve_collision(vessel: Node3D) -> void:
	if cooldown > 0.0:
		return
	cooldown = 0.72
	warning_timer = 2.8
	var vessel_class: String = str(vessel.get_meta("v23_vessel_class", "gemi")).to_upper()
	if warning_label != null:
		warning_label.text = "⚠ GEMİ ÇARPIŞMASI • %s" % vessel_class

	var impact_knots: float = absf(float(controller.get("ground_speed_kn")))
	if have_safe_pose:
		ferry.global_position = last_safe_position
		ferry.global_rotation = last_safe_rotation

	var surge: float = float(controller.get("surge_mps"))
	var sway: float = float(controller.get("sway_mps"))
	controller.set("surge_mps", -surge * 0.16)
	controller.set("sway_mps", -sway * 0.28)
	controller.set("yaw_rate", -float(controller.get("yaw_rate")) * 0.20)
	controller.set("engine_order", move_toward(float(controller.get("engine_order")), 0.0, 0.30))
	controller.set("throttle", 0.0)

	var damage_now: float = float(controller.get("damage"))
	var damage_hit: float = clampf(5.0 + impact_knots * impact_knots * 1.10, 5.0, 48.0)
	controller.set("damage", minf(100.0, damage_now + damage_hit))
	controller.set("comfort", maxf(0.0, float(controller.get("comfort")) - minf(42.0, 8.0 + impact_knots * 3.0)))

func _install_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 92
	add_child(layer)
	warning_label = Label.new()
	warning_label.anchor_left = 0.34
	warning_label.anchor_top = 0.215
	warning_label.anchor_right = 0.66
	warning_label.anchor_bottom = 0.265
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 17)
	warning_label.modulate = Color(1.0, 0.34, 0.24)
	warning_label.visible = false
	layer.add_child(warning_label)