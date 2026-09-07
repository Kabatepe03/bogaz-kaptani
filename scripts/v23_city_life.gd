extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")
const VehicleFactory = preload("res://scripts/v20_vehicle_factory.gd")

const KORDON_MID := Vector2(40.15145, 26.40345)
const TROJAN_HORSE := Vector2(40.152257, 26.405329)
const KORDON_NORTH := Vector2(40.15335, 26.40675)
const ECEABAT_SOUTH := Vector2(40.18195, 26.36065)
const ECEABAT_NORTH := Vector2(40.18630, 26.36005)

var root: Node3D
var movers: Array[Node3D] = []

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(44):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null or scene.find_child("V23_CITY_LIFE", true, false) != null:
		return
	root = Node3D.new()
	root.name = "V23_CITY_LIFE"
	scene.add_child(root)

	var canakkale_points: Array[Vector3] = [
		GeoReference.to_local(GeoReference.CANAKKALE_DOCK),
		GeoReference.to_local(KORDON_MID),
		GeoReference.to_local(TROJAN_HORSE),
		GeoReference.to_local(KORDON_NORTH)
	]
	var eceabat_points: Array[Vector3] = [
		GeoReference.to_local(ECEABAT_SOUTH),
		GeoReference.to_local(GeoReference.ECEABAT_DOCK),
		GeoReference.to_local(ECEABAT_NORTH)
	]
	var eceabat_target: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var canakkale_target: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)

	_spawn_moving_stream(canakkale_points, eceabat_target, 17.8, 18, 8.2, "CANAKKALE")
	_spawn_moving_stream(eceabat_points, canakkale_target, 13.2, 10, 6.4, "ECEABAT")
	_spawn_parked(canakkale_points, eceabat_target, 17.8, 22, "CANAKKALE")
	_spawn_parked(eceabat_points, canakkale_target, 13.2, 12, "ECEABAT")

func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	for vehicle: Node3D in movers:
		if not is_instance_valid(vehicle):
			continue
		var progress: float = float(vehicle.get_meta("progress", 0.0))
		var speed: float = float(vehicle.get_meta("speed", 7.0))
		var direction: float = float(vehicle.get_meta("direction", 1.0))
		var path_length: float = maxf(float(vehicle.get_meta("path_length", 1.0)), 1.0)
		progress += direction * speed * delta / path_length
		if progress > 1.03:
			progress = -0.03
		elif progress < -0.03:
			progress = 1.03
		vehicle.set_meta("progress", progress)
		_update_vehicle_pose(vehicle, clampf(progress, 0.0, 1.0))

func _spawn_moving_stream(points: Array[Vector3], sea_target: Vector3, road_offset: float, count: int, base_speed: float, label: String) -> void:
	var path_length: float = _polyline_length(points)
	var palette: Array[Color] = [
		Color(0.12,0.17,0.24), Color(0.72,0.72,0.68), Color(0.50,0.07,0.045),
		Color(0.08,0.29,0.54), Color(0.17,0.18,0.17), Color(0.60,0.50,0.26)
	]
	for i: int in range(count):
		var kind: String = "car"
		if i % 9 == 0:
			kind = "bus"
		elif i % 6 == 0:
			kind = "minibus"
		var vehicle: Node3D = VehicleFactory.create_vehicle(kind, Vector3.ZERO, palette[i % palette.size()])
		vehicle.name = "V23_%s_Moving_%02d" % [label, i]
		root.add_child(vehicle)
		var direction: float = 1.0 if i % 2 == 0 else -1.0
		var progress: float = fmod(0.075 + float(i) / float(maxi(count, 1)), 1.0)
		vehicle.set_meta("progress", progress)
		vehicle.set_meta("direction", direction)
		vehicle.set_meta("speed", base_speed * (0.76 + float((i * 7) % 11) * 0.035))
		vehicle.set_meta("path_length", path_length)
		vehicle.set_meta("road_offset", road_offset)
		vehicle.set_meta("lane_offset", 2.35 if direction > 0.0 else -2.35)
		vehicle.set_meta("sea_target", sea_target)
		vehicle.set_meta("path_points", points)
		movers.append(vehicle)
		_update_vehicle_pose(vehicle, progress)

func _spawn_parked(points: Array[Vector3], sea_target: Vector3, road_offset: float, count: int, label: String) -> void:
	var palette: Array[Color] = [Color(0.72,0.72,0.70), Color(0.10,0.13,0.18), Color(0.41,0.05,0.04), Color(0.05,0.21,0.42)]
	for i: int in range(count):
		var progress: float = clampf((float(i) + 0.55) / float(count), 0.02, 0.98)
		var tangent: Vector3 = _polyline_tangent(points, progress)
		var p: Vector3 = _polyline_sample(points, progress)
		var sea_side: Vector3 = _perp_toward(tangent, sea_target - p)
		var land_side: Vector3 = -sea_side
		var side_sign: float = 1.0 if i % 2 == 0 else -1.0
		var parked: Node3D = VehicleFactory.create_vehicle("car", Vector3.ZERO, palette[i % palette.size()])
		parked.name = "V23_%s_Parked_%02d" % [label, i]
		root.add_child(parked)
		parked.global_position = p + land_side * (road_offset + side_sign * 5.1) + Vector3.UP * 1.84
		var heading: Vector3 = tangent if i % 3 != 0 else -tangent
		parked.look_at(parked.global_position + heading * 20.0, Vector3.UP)

func _update_vehicle_pose(vehicle: Node3D, progress: float) -> void:
	var raw_points: Variant = vehicle.get_meta("path_points", [])
	if not (raw_points is Array):
		return
	var points: Array[Vector3] = []
	for item: Variant in raw_points:
		if item is Vector3:
			points.append(item)
	if points.size() < 2:
		return
	var p: Vector3 = _polyline_sample(points, progress)
	var tangent: Vector3 = _polyline_tangent(points, progress)
	var sea_target: Vector3 = vehicle.get_meta("sea_target", Vector3.ZERO)
	var sea_side: Vector3 = _perp_toward(tangent, sea_target - p)
	var land_side: Vector3 = -sea_side
	var road_offset: float = float(vehicle.get_meta("road_offset", 15.0))
	var lane_offset: float = float(vehicle.get_meta("lane_offset", 2.0))
	var direction: float = float(vehicle.get_meta("direction", 1.0))
	vehicle.global_position = p + land_side * (road_offset + lane_offset) + Vector3.UP * 1.84
	var heading: Vector3 = tangent * direction
	vehicle.look_at(vehicle.global_position + heading * 20.0, Vector3.UP)

func _polyline_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for i: int in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return maxf(total, 1.0)

func _polyline_sample(points: Array[Vector3], t: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]
	var total: float = _polyline_length(points)
	var target: float = clampf(t, 0.0, 1.0) * total
	var walked := 0.0
	for i: int in range(points.size() - 1):
		var length: float = points[i].distance_to(points[i + 1])
		if walked + length >= target:
			var local_t: float = (target - walked) / maxf(length, 0.001)
			return points[i].lerp(points[i + 1], local_t)
		walked += length
	return points[-1]

func _polyline_tangent(points: Array[Vector3], t: float) -> Vector3:
	var p0: Vector3 = _polyline_sample(points, clampf(t - 0.0025, 0.0, 1.0))
	var p1: Vector3 = _polyline_sample(points, clampf(t + 0.0025, 0.0, 1.0))
	var tangent := p1 - p0
	tangent.y = 0.0
	if tangent.length() < 0.01:
		return Vector3(0.0, 0.0, -1.0)
	return tangent.normalized()

func _perp_toward(tangent: Vector3, target_direction: Vector3) -> Vector3:
	var p := Vector3(-tangent.z, 0.0, tangent.x).normalized()
	var target := target_direction
	target.y = 0.0
	if p.dot(target) < 0.0:
		p = -p
	return p
