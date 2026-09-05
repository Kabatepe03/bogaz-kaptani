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

func _make_building(size: Vector3, color: Color, detailed: bool) -> Node3D:
	var group := Node3D.new()
	group.add_child(_box_node(size, Vector3.ZERO, color, 0.86, 0.01))

	var trim := color.lightened(0.12)
	group.add_child(_box_node(Vector3(size.x + 0.30, 0.22, size.z + 0.30), Vector3(0, -size.y * 0.50 + 0.11, 0), trim.darkened(0.18), 0.82, 0.01))
	for y_ratio in [-0.22, 0.02, 0.26]:
		if absf(y_ratio * size.y) < size.y * 0.42:
			group.add_child(_box_node(Vector3(size.x + 0.18, 0.13, size.z + 0.18), Vector3(0, y_ratio * size.y, 0), trim, 0.78, 0.01))

	# Kiremit tonlu kırma çatı hissi için iki eğimli yüzey.
	var roof_color := Color(0.34, 0.20, 0.14)
	var roof_left := _box_node(Vector3(size.x * 0.56, 0.28, size.z + 1.0), Vector3(-size.x * 0.245, size.y * 0.50 + 0.55, 0), roof_color, 0.90, 0.0)
	roof_left.rotation_degrees.z = -12.0
	group.add_child(roof_left)
	var roof_right := _box_node(Vector3(size.x * 0.56, 0.28, size.z + 1.0), Vector3(size.x * 0.245, size.y * 0.50 + 0.55, 0), roof_color, 0.90, 0.0)
	roof_right.rotation_degrees.z = 12.0
	group.add_child(roof_right)

	if not detailed:
		return group

	var glass := Color(0.018, 0.055, 0.078)
	var floors: int = maxi(2, int(round(size.y / 3.05)))
	var cols: int = clampi(int(round(size.x / 5.2)), 2, 4)
	for floor_index in range(floors):
		var floor_y: float = -size.y * 0.5 + 1.65 + float(floor_index) * 3.05
		if floor_y > size.y * 0.43:
			continue
		for col_index in range(cols):
			var x_ratio: float = (float(col_index) + 0.5) / float(cols) - 0.5
			var window_x: float = x_ratio * size.x * 0.78
			group.add_child(_box_node(Vector3(1.55, 1.12, 0.10), Vector3(window_x, floor_y, -size.z * 0.505), glass, 0.13, 0.16))
			group.add_child(_box_node(Vector3(1.55, 1.12, 0.10), Vector3(window_x, floor_y, size.z * 0.505), glass, 0.13, 0.16))
		if floor_index > 0 and floor_index % 2 == 1:
			var balcony_z: float = -size.z * 0.53
			group.add_child(_box_node(Vector3(size.x * 0.66, 0.18, 1.20), Vector3(0, floor_y - 0.68, balcony_z), Color(0.52,0.52,0.49), 0.80, 0.02))
			group.add_child(_box_node(Vector3(size.x * 0.66, 0.08, 0.08), Vector3(0, floor_y + 0.22, balcony_z - 0.56), Color(0.20,0.21,0.21), 0.34, 0.46))
			for rail_x in [-0.28, 0.0, 0.28]:
				group.add_child(_box_node(Vector3(0.06, 0.90, 0.06), Vector3(rail_x * size.x, floor_y - 0.22, balcony_z - 0.56), Color(0.20,0.21,0.21), 0.34, 0.46))

	# Zemin kat vitrin/saçak detayları.
	var shop_y: float = -size.y * 0.5 + 1.35
	group.add_child(_box_node(Vector3(size.x * 0.64, 1.85, 0.11), Vector3(0, shop_y, -size.z * 0.507), Color(0.025,0.065,0.085), 0.14, 0.12))
	group.add_child(_box_node(Vector3(size.x * 0.72, 0.16, 1.05), Vector3(0, shop_y + 1.18, -size.z * 0.55), Color(0.23,0.27,0.29), 0.62, 0.12))
	return group
