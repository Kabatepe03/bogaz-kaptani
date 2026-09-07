extends "res://scripts/v22_controller.gd"

const GeoReferenceV23 = preload("res://scripts/geo_reference.gd")

const CHANNEL_LL: Array[Vector2] = [
	Vector2(40.2140, 26.4380),
	Vector2(40.1920, 26.4100),
	Vector2(40.1710, 26.3920),
	Vector2(40.1510, 26.3820),
	Vector2(40.1260, 26.3560)
]

var v23_timer := 0.0

func _ready() -> void:
	super._ready()
	call_deferred("_install_v23")

func _process(delta: float) -> void:
	super._process(delta)
	v23_timer += delta
	if v23_timer >= 0.42:
		v23_timer = 0.0
		_retitle_v23(self)

func _update_ferry(delta: float) -> void:
	# Keep the mature engine/rudder/twin-screw model, then replace the old radial current field
	# with a current vector that follows the long axis of the Dardanelles.
	super._update_ferry(delta)
	_apply_channel_current_correction(delta)

func _reset_route() -> void:
	super._reset_route()
	call_deferred("_validate_v23_spawn")

func _validate_v23_spawn() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	if V23WorldCollision != null and V23WorldCollision.has_method("_force_safe_spawn"):
		V23WorldCollision.call("_force_safe_spawn")

func _install_v23() -> void:
	for _frame: int in range(22):
		await get_tree().process_frame
	_retitle_v23(self)
	_validate_v23_spawn()

func _apply_channel_current_correction(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return

	# Remove the v12 radial-field approximation that has already been applied by super().
	var c_dock: Vector3 = GeoReferenceV23.to_local(GeoReferenceV23.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReferenceV23.to_local(GeoReferenceV23.ECEABAT_DOCK)
	var old_mid: Vector3 = (c_dock + e_dock) * 0.5
	var old_dist_mid: float = ferry.global_position.distance_to(old_mid)
	var old_central_factor: float = clampf(1.0 - old_dist_mid / 3200.0, 0.28, 1.0)
	var old_dir: Vector3 = Vector3(-0.10, 0.0, 0.995).normalized()
	var weather_factor: float = clampf(0.78 + current_strength * 0.55, 0.72, 1.35)
	var old_speed: float = (0.43 + 0.42 * old_central_factor) * weather_factor
	var old_velocity: Vector3 = old_dir * old_speed

	# Find the closest point and tangent on a geographic channel centreline. The polyline follows
	# the strait north-to-south, so current direction bends with the real channel instead of always
	# pointing toward one arbitrary compass vector.
	var best_distance := INF
	var best_direction := Vector3(0.0, 0.0, 1.0)
	for i in range(CHANNEL_LL.size() - 1):
		var a: Vector3 = GeoReferenceV23.to_local(CHANNEL_LL[i])
		var b: Vector3 = GeoReferenceV23.to_local(CHANNEL_LL[i + 1])
		var segment := b - a
		segment.y = 0.0
		var len_sq: float = maxf(segment.length_squared(), 0.001)
		var t: float = clampf((ferry.global_position - a).dot(segment) / len_sq, 0.0, 1.0)
		var closest := a + segment * t
		var d: float = ferry.global_position.distance_to(closest)
		if d < best_distance:
			best_distance = d
			best_direction = segment.normalized()

	var channel_factor: float = 1.0 - smoothstep(260.0, 1450.0, best_distance)
	var desired_speed: float = lerpf(0.24, 0.88, channel_factor) * weather_factor

	# Manoeuvring basins are sheltered compared with the central stream. Keep cross-current visible,
	# but do not make final docking impossible.
	var dock_distance: float = minf(ferry.global_position.distance_to(c_dock), ferry.global_position.distance_to(e_dock))
	var harbour_relief: float = lerpf(0.48, 1.0, smoothstep(150.0, 650.0, dock_distance))
	desired_speed *= harbour_relief
	var desired_velocity: Vector3 = best_direction * desired_speed

	ferry.global_position += (desired_velocity - old_velocity) * delta

	# Ground-speed display must reflect the corrected vector. Reconstruct the through-water velocity
	# plus wind and the new current, matching the inherited HUD semantics.
	var forward: Vector3 = -ferry.global_transform.basis.z
	var starboard: Vector3 = ferry.global_transform.basis.x
	var through_water: Vector3 = forward * surge_mps + starboard * sway_mps
	var wind_velocity: Vector3 = wind_vector * (wind_strength * 0.052)
	var corrected_ground: Vector3 = through_water + desired_velocity + wind_velocity
	ground_speed_kn = corrected_ground.length() / 0.514444
	if through_water.length() > 0.08 and corrected_ground.length() > 0.08:
		drift_angle_deg = rad_to_deg(acos(clampf(through_water.normalized().dot(corrected_ground.normalized()), -1.0, 1.0)))
	else:
		drift_angle_deg = 0.0

func _update_v13_assist() -> void:
	super._update_v13_assist()
	if captain_assist_label != null:
		captain_assist_label.text = captain_assist_label.text.replace("V22 KAPTAN KÖPRÜSÜ", "V23 KAPTAN KÖPRÜSÜ")

func _retitle_v23(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.text = label.text.replace("V22 KAPTAN KÖPRÜSÜ", "V23 KAPTAN KÖPRÜSÜ")
		label.text = label.text.replace("V22 • ULTRA SİMÜLASYON", "V23 • ÇANAKKALE DİJİTAL İKİZ")
		label.text = label.text.replace("BOĞAZ KAPTANI V22", "BOĞAZ KAPTANI V23")
	for child: Node in node.get_children():
		_retitle_v23(child)
