extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")

const CARGO := "res://assets/v20/marine/cargo_ship_v20.glb"
const TANKER := "res://assets/v20/marine/tanker_v20.glb"
const TUG := "res://assets/v20/marine/tug_v20.glb"
const FISHING := "res://assets/v20/marine/fishing_boat_v20.glb"
const FERRY := "res://assets/v20/ferry_remaster_v20.glb"

var traffic_root: Node3D
var other_ferry: Node3D
var other_ferry_progress := 0.16

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(12):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var old_traffic: Node = scene.find_child("V7Traffic", true, false)
	if old_traffic is Node3D:
		(old_traffic as Node3D).visible = false

	traffic_root = Node3D.new()
	traffic_root.name = "V20_Dardanelles_Marine_Traffic"
	scene.add_child(traffic_root)

	_spawn_lane(CARGO, -1600.0, 3600.0, -1.0, 5.4, 3.0, 0.17)
	_spawn_lane(TANKER, -2050.0, -2800.0, 1.0, 4.8, 3.2, 1.43)
	_spawn_lane(CARGO, -1510.0, -1200.0, -1.0, 4.9, 2.8, 2.11)
	_spawn_lane(TUG, -1880.0, 1750.0, 1.0, 3.7, 1.25, 0.71)
	_spawn_lane(FISHING, -2350.0, 900.0, -1.0, 2.6, 0.85, 2.81)
	_spawn_lane(FISHING, -1280.0, -3900.0, 1.0, 2.2, 0.82, 4.13)

	_spawn_opposite_ferry(scene)

func _spawn_lane(path: String, x: float, z: float, direction: float, speed: float, base_y: float, phase: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var resource: Resource = load(path)
	if not (resource is PackedScene):
		return
	var ship: Node = (resource as PackedScene).instantiate()
	if not (ship is Node3D):
		return
	var vessel := ship as Node3D
	var class_name := "cargo"
	var half_length := 84.0
	var half_beam := 13.0
	if path == TANKER:
		class_name = "tanker"
		half_length = 91.0
		half_beam = 15.0
	elif path == TUG:
		class_name = "tug"
		half_length = 17.0
		half_beam = 6.0
	elif path == FISHING:
		class_name = "fishing"
		half_length = 12.0
		half_beam = 4.2
	vessel.name = "V23_Marine_%s_%d" % [class_name.capitalize(), traffic_root.get_child_count()]
	vessel.position = Vector3(x, base_y, z)
	vessel.rotation.y = 0.0 if direction < 0.0 else PI
	vessel.set_meta("lane_x", x)
	vessel.set_meta("lane_direction", direction)
	vessel.set_meta("lane_speed", speed)
	vessel.set_meta("base_y", base_y)
	vessel.set_meta("bob_phase", phase)
	vessel.set_meta("v23_vessel_class", class_name)
	vessel.set_meta("v23_half_length", half_length)
	vessel.set_meta("v23_half_beam", half_beam)
	traffic_root.add_child(vessel)

func _spawn_opposite_ferry(scene: Node) -> void:
	if not ResourceLoader.exists(FERRY):
		return
	var resource: Resource = load(FERRY)
	if not (resource is PackedScene):
		return
	var instance: Node = (resource as PackedScene).instantiate()
	if not (instance is Node3D):
		return
	other_ferry = instance as Node3D
	other_ferry.name = "V20_Opposite_Route_Ferry"
	other_ferry.scale = Vector3.ONE * 0.98
	other_ferry.set_meta("v23_vessel_class", "ferry")
	other_ferry.set_meta("v23_half_length", 44.0)
	other_ferry.set_meta("v23_half_beam", 8.4)
	scene.add_child(other_ferry)
	_update_other_ferry(0.0)

func _process(delta: float) -> void:
	if traffic_root != null:
		var now: float = Time.get_ticks_msec() * 0.001
		for child: Node in traffic_root.get_children():
			if not (child is Node3D):
				continue
			var vessel := child as Node3D
			var direction: float = float(vessel.get_meta("lane_direction", -1.0))
			var speed: float = float(vessel.get_meta("lane_speed", 3.0))
			var base_y: float = float(vessel.get_meta("base_y", 1.0))
			var phase: float = float(vessel.get_meta("bob_phase", 0.0))
			vessel.position.z += direction * speed * delta
			if vessel.position.z < -5200.0:
				vessel.position.z = 5200.0
			elif vessel.position.z > 5200.0:
				vessel.position.z = -5200.0
			vessel.position.y = base_y + sin(now * 0.62 + phase) * 0.18
			vessel.rotation.z = sin(now * 0.41 + phase) * 0.0035
			vessel.rotation.x = sin(now * 0.34 + phase * 1.7) * 0.0028

	if other_ferry != null:
		other_ferry_progress += delta * 0.00145
		if other_ferry_progress > 0.93:
			other_ferry_progress = 0.07
		_update_other_ferry(delta)

func _update_other_ferry(_delta: float) -> void:
	if other_ferry == null:
		return
	var canakkale: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var route: Vector3 = eceabat - canakkale
	var forward: Vector3 = route.normalized()
	var side: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var p: Vector3 = canakkale.lerp(eceabat, other_ferry_progress) + side * 105.0
	p.y = 2.0 + sin(Time.get_ticks_msec() * 0.00075 + 1.3) * 0.16
	other_ferry.global_position = p
	other_ferry.look_at(p + forward * 50.0, Vector3.UP)
