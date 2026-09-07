extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")

const WATER_LEVEL := 0.0
const LAND_HEIGHT_THRESHOLD := 0.58
const HULL_HALF_BEAM := 7.75
const HULL_HALF_LENGTH := 40.0
const DOCK_CLEAR_HALF_WIDTH := 11.4
const DOCK_PIER_OUTER_WIDTH := 72.0
const DOCK_PIER_LENGTH := 88.0

var ferry: Node3D
var controller: Node
var terrain_collision_ready := false
var last_safe_position := Vector3.ZERO
var last_safe_rotation := Vector3.ZERO
var previous_frame_position := Vector3.ZERO
var have_safe_pose := false
var collision_cooldown := 0.0
var warning_timer := 0.0
var warning_label: Label

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _frame: int in range(28):
		await get_tree().process_frame
	controller = get_tree().current_scene
	if controller == null:
		return
	var found: Node = controller.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	ferry = found as Node3D
	_install_terrain_collision()
	_install_warning_ui()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_force_safe_spawn()
	previous_frame_position = ferry.global_position

func _physics_process(delta: float) -> void:
	if ferry == null or controller == null:
		return
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	warning_timer = maxf(0.0, warning_timer - delta)
	if warning_label != null:
		warning_label.visible = warning_timer > 0.0

	var teleport_distance: float = ferry.global_position.distance_to(previous_frame_position)
	if teleport_distance > 180.0:
		have_safe_pose = false
		_force_safe_spawn()
		previous_frame_position = ferry.global_position
		return
	previous_frame_position = ferry.global_position

	var hit_reason: String = _hull_collision_reason(ferry.global_transform)
	if hit_reason.is_empty():
		if collision_cooldown <= 0.0:
			last_safe_position = ferry.global_position
			last_safe_rotation = ferry.global_rotation
			have_safe_pose = true
		return

	_resolve_collision(hit_reason)
	previous_frame_position = ferry.global_position

func _install_terrain_collision() -> void:
	var world: Node = controller.find_child("V20_REAL_CANAKKALE_WORLD", true, false)
	if world == null:
		return
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		if not mesh_node.name.begins_with("RealTerrain"):
			continue
		if mesh_node.mesh == null:
			continue
		mesh_node.create_trimesh_collision()
		terrain_collision_ready = true
		break

func _install_warning_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	warning_label = Label.new()
	warning_label.anchor_left = 0.34
	warning_label.anchor_top = 0.16
	warning_label.anchor_right = 0.66
	warning_label.anchor_bottom = 0.215
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warning_label.add_theme_font_size_override("font_size", 18)
	warning_label.modulate = Color(1.0, 0.76, 0.35)
	warning_label.visible = false
	layer.add_child(warning_label)

func _hull_collision_reason(transform: Transform3D) -> String:
	var samples: Array[Vector3] = [
		Vector3(0.0, 0.0, -HULL_HALF_LENGTH),
		Vector3(0.0, 0.0, HULL_HALF_LENGTH),
		Vector3(-HULL_HALF_BEAM, 0.0, -34.0),
		Vector3(HULL_HALF_BEAM, 0.0, -34.0),
		Vector3(-HULL_HALF_BEAM, 0.0, 0.0),
		Vector3(HULL_HALF_BEAM, 0.0, 0.0),
		Vector3(-HULL_HALF_BEAM, 0.0, 34.0),
		Vector3(HULL_HALF_BEAM, 0.0, 34.0)
	]
	for local_point: Vector3 in samples:
		var world_point: Vector3 = transform * local_point
		var dock_reason: String = _dock_collision_reason(world_point)
		if not dock_reason.is_empty():
			return dock_reason
		if _is_land_at(world_point):
			return "KARAYA OTURMA / KIYI ÇARPIŞMASI"
	return ""

func _is_land_at(point: Vector3) -> bool:
	if not terrain_collision_ready or get_viewport().world_3d == null:
		return false
	var state: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var from := Vector3(point.x, 180.0, point.z)
	var to := Vector3(point.x, -18.0, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y > LAND_HEIGHT_THRESHOLD

func _dock_collision_reason(point: Vector3) -> String:
	var reason := _dock_point_test(point, GeoReference.CANAKKALE_DOCK, GeoReference.ECEABAT_DOCK, "ÇANAKKALE")
	if not reason.is_empty():
		return reason
	return _dock_point_test(point, GeoReference.ECEABAT_DOCK, GeoReference.CANAKKALE_DOCK, "ECEABAT")

func _dock_point_test(point: Vector3, dock_ll: Vector2, opposite_ll: Vector2, dock_name: String) -> String:
	var dock: Vector3 = GeoReference.to_local(dock_ll)
	var opposite: Vector3 = GeoReference.to_local(opposite_ll)
	var seaward: Vector3 = opposite - dock
	seaward.y = 0.0
	seaward = seaward.normalized()
	var lateral_axis := Vector3(-seaward.z, 0.0, seaward.x)
	var rel := point - dock
	var longitudinal: float = rel.dot(seaward)
	var lateral: float = rel.dot(lateral_axis)

	if longitudinal < -1.5 and longitudinal > -420.0 and absf(lateral) < 330.0:
		return "%s KIYISI" % dock_name
	if longitudinal >= -2.0 and longitudinal <= DOCK_PIER_LENGTH:
		var abs_lat := absf(lateral)
		if abs_lat > DOCK_CLEAR_HALF_WIDTH and abs_lat < DOCK_PIER_OUTER_WIDTH:
			return "%s RIHTIM / FENDER ÇARPIŞMASI" % dock_name
	return ""

func _resolve_collision(reason: String) -> void:
	if collision_cooldown > 0.0:
		return
	collision_cooldown = 0.55
	warning_timer = 2.2
	if warning_label != null:
		warning_label.text = "⚠ %s" % reason

	var impact_knots: float = absf(float(controller.get("ground_speed_kn")))
	if have_safe_pose:
		ferry.global_position = last_safe_position
		ferry.global_rotation = last_safe_rotation
	else:
		_force_safe_spawn()

	var surge: float = float(controller.get("surge_mps"))
	var sway: float = float(controller.get("sway_mps"))
	controller.set("surge_mps", -surge * 0.10)
	controller.set("sway_mps", -sway * 0.18)
	controller.set("yaw_rate", float(controller.get("yaw_rate")) * 0.24)
	controller.set("engine_order", move_toward(float(controller.get("engine_order")), 0.0, 0.18))

	var current_damage: float = float(controller.get("damage"))
	var hit_damage: float = clampf(2.0 + impact_knots * impact_knots * 0.72, 2.0, 34.0)
	controller.set("damage", minf(100.0, current_damage + hit_damage))
	controller.set("comfort", maxf(0.0, float(controller.get("comfort")) - minf(28.0, 3.0 + impact_knots * 2.2)))

func _force_safe_spawn() -> void:
	if ferry == null or controller == null:
		return
	var route_forward: bool = bool(controller.get("route_forward"))
	var dock_ll: Vector2 = GeoReference.CANAKKALE_DOCK if route_forward else GeoReference.ECEABAT_DOCK
	var opposite_ll: Vector2 = GeoReference.ECEABAT_DOCK if route_forward else GeoReference.CANAKKALE_DOCK
	var dock: Vector3 = GeoReference.to_local(dock_ll)
	var opposite: Vector3 = GeoReference.to_local(opposite_ll)
	var seaward: Vector3 = opposite - dock
	seaward.y = 0.0
	seaward = seaward.normalized()

	var basis := Basis.looking_at(seaward, Vector3.UP)
	var selected := dock + seaward * 64.0 + Vector3.UP * 2.0
	var selected_transform := Transform3D(basis, selected)
	if not _hull_collision_reason(selected_transform).is_empty():
		for offset in range(72, 253, 10):
			var candidate := dock + seaward * float(offset) + Vector3.UP * 2.0
			var candidate_transform := Transform3D(basis, candidate)
			if _hull_collision_reason(candidate_transform).is_empty():
				selected = candidate
				break

	ferry.global_position = selected
	ferry.look_at(selected + seaward * 100.0, Vector3.UP)
	controller.set("route_start", selected)
	last_safe_position = ferry.global_position
	last_safe_rotation = ferry.global_rotation
	previous_frame_position = ferry.global_position
	have_safe_pose = true
