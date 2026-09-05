extends "res://scripts/v7_controller.gd"

var v10_camera_offsets: Array[Vector3] = []
var v10_camera_targets: Array[Vector3] = []
var v10_camera_fovs: Array[float] = []

func _ready() -> void:
	super._ready()
	call_deferred("_install_v10_cameras")

func _process(delta: float) -> void:
	super._process(delta)
	_update_v10_cameras(delta)

func _install_v10_cameras() -> void:
	await get_tree().process_frame
	for cam in cameras:
		if is_instance_valid(cam):
			cam.current = false
			cam.queue_free()
	cameras.clear()
	v10_camera_offsets.clear()
	v10_camera_targets.clear()
	v10_camera_fovs.clear()

	_add_v10_camera("SÜRÜŞ", Vector3(0.0, 20.0, 44.0), Vector3(0.0, 4.5, -105.0), 72.0)
	_add_v10_camera("KAPTAN", Vector3(0.0, 14.0, 6.5), Vector3(0.0, 6.7, -145.0), 76.0)
	_add_v10_camera("YANAŞMA SOL", Vector3(-16.0, 12.5, 28.0), Vector3(-5.0, 3.2, -92.0), 70.0)
	_add_v10_camera("YANAŞMA SAĞ", Vector3(16.0, 12.5, 28.0), Vector3(5.0, 3.2, -92.0), 70.0)
	_add_v10_camera("DRONE ROTA", Vector3(0.0, 52.0, 70.0), Vector3(0.0, 1.0, -150.0), 67.0)

	camera_index = 0
	if not cameras.is_empty():
		cameras[0].current = true
	_update_v10_cameras(1.0)
	_update_status()

func _add_v10_camera(camera_name: String, offset: Vector3, target: Vector3, fov_value: float) -> void:
	var cam := Camera3D.new()
	cam.name = camera_name
	cam.fov = fov_value
	cam.near = 0.20
	cam.far = 12000.0
	add_child(cam)
	cameras.append(cam)
	v10_camera_offsets.append(offset)
	v10_camera_targets.append(target)
	v10_camera_fovs.append(fov_value)

func _update_v10_cameras(delta: float) -> void:
	if ferry == null or cameras.is_empty():
		return
	var yaw_basis := Basis(Vector3.UP, ferry.global_rotation.y)
	var position_lerp := clampf(delta * 5.0, 0.0, 1.0)
	for i in range(cameras.size()):
		if i >= v10_camera_offsets.size() or i >= v10_camera_targets.size():
			continue
		var cam: Camera3D = cameras[i]
		if not is_instance_valid(cam):
			continue
		var desired_position := ferry.global_position + yaw_basis * v10_camera_offsets[i]
		if cam.global_position.length_squared() < 0.01:
			cam.global_position = desired_position
		else:
			cam.global_position = cam.global_position.lerp(desired_position, position_lerp)
		var target_world := ferry.global_position + yaw_basis * v10_camera_targets[i]
		cam.look_at(target_world, Vector3.UP)

func _next_camera() -> void:
	if cameras.is_empty():
		return
	cameras[camera_index].current = false
	camera_index = (camera_index + 1) % cameras.size()
	cameras[camera_index].current = true
	_update_status()
