extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")
const VehicleFactory = preload("res://scripts/vehicle_factory.gd")

var ferry: Node3D
var smoke_puffs: Array[MeshInstance3D] = []
var smoke_phase: Array[float] = []

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	_tune_environment(scene)
	_upgrade_harbors(scene)
	_build_navigation_channel(scene)
	var found := scene.find_child("Ferry", true, false)
	if found is Node3D:
		ferry = found as Node3D
		_finish_ferry(ferry)
		_build_exhaust(ferry)

func _process(delta: float) -> void:
	if ferry == null:
		return
	for i in range(smoke_puffs.size()):
		var puff: MeshInstance3D = smoke_puffs[i]
		if not is_instance_valid(puff):
			continue
		smoke_phase[i] += delta * (0.55 + float(i) * 0.04)
		if smoke_phase[i] > 1.0:
			smoke_phase[i] -= 1.0
		var t: float = smoke_phase[i]
		var side: float = -1.0 if i % 2 == 0 else 1.0
		puff.position = Vector3(side * 3.0 + sin(t * TAU) * 0.22, 16.8 + t * 5.0, 9.0 + t * 1.8)
		var scale_value: float = 0.34 + t * 0.58
		puff.scale = Vector3.ONE * scale_value
		var mat := puff.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.22 * (1.0 - t)

func _tune_environment(scene: Node) -> void:
	var world := scene.find_child("WorldEnvironment", true, false)
	if world is WorldEnvironment:
		var env := (world as WorldEnvironment).environment
		if env != null:
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.11
			env.adjustment_saturation = 0.98
			env.fog_density = minf(env.fog_density, 0.000060)
			env.fog_light_color = Color(0.61, 0.70, 0.76)
			env.glow_enabled = true
			env.glow_intensity = 0.42
			env.glow_bloom = 0.025

	var sun_fill := DirectionalLight3D.new()
	sun_fill.name = "V10NaturalFill"
	sun_fill.rotation_degrees = Vector3(-18.0, 128.0, 0.0)
	sun_fill.light_color = Color(0.52, 0.64, 0.76)
	sun_fill.light_energy = 0.12
	sun_fill.shadow_enabled = false
	scene.add_child(sun_fill)

func _upgrade_harbors(scene: Node) -> void:
	for harbor_name in ["Çanakkale İskelesi", "Eceabat İskelesi"]:
		var found := scene.find_child(harbor_name, true, false)
		if found is Node3D:
			_build_harbor_extension(found as Node3D, harbor_name)

func _build_harbor_extension(harbor: Node3D, harbor_name: String) -> void:
	if harbor.find_child("V10Harbor", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V10Harbor"
	harbor.add_child(root)

	# Yol ve bekleme sahası: oyuncunun sürüş kamerasında iskele hattı okunur.
	root.add_child(_box(Vector3(58.0, 0.24, 190.0), Vector3(0, 1.88, 196.0), Color(0.075, 0.080, 0.085), 0.92, 0.02))
	root.add_child(_box(Vector3(8.0, 0.28, 190.0), Vector3(-33.0, 1.90, 196.0), Color(0.36, 0.37, 0.35), 0.94, 0.0))
	root.add_child(_box(Vector3(8.0, 0.28, 190.0), Vector3(33.0, 1.90, 196.0), Color(0.36, 0.37, 0.35), 0.94, 0.0))

	for lane_x in [-18.0, -6.0, 6.0, 18.0]:
		for z in range(118, 286, 18):
			root.add_child(_box(Vector3(0.20, 0.035, 8.0), Vector3(lane_x, 2.04, float(z)), Color(0.90, 0.88, 0.67), 0.72, 0.0))

	# Terminal yapısı ve cam cephesi.
	var terminal := Node3D.new()
	terminal.position = Vector3(46.0, 2.0, 220.0)
	root.add_child(terminal)
	terminal.add_child(_box(Vector3(30.0, 7.0, 38.0), Vector3(0, 3.5, 0), Color(0.72, 0.71, 0.67), 0.84, 0.02))
	terminal.add_child(_box(Vector3(31.5, 0.42, 40.0), Vector3(0, 7.15, 0), Color(0.20, 0.21, 0.22), 0.52, 0.18))
	for z in [-13.0, -6.5, 0.0, 6.5, 13.0]:
		terminal.add_child(_glass(Vector3(0.10, 3.4, 5.0), Vector3(-15.05, 3.9, z)))
	for x in [-9.0, -3.0, 3.0, 9.0]:
		terminal.add_child(_glass(Vector3(4.8, 3.4, 0.10), Vector3(x, 3.9, -19.05)))

	var sign := Label3D.new()
	sign.text = harbor_name.to_upper()
	sign.font_size = 64
	sign.outline_size = 8
	sign.modulate = Color(0.96, 0.97, 0.94)
	sign.pixel_size = 0.014
	sign.position = Vector3(0, 8.8, -19.35)
	terminal.add_child(sign)

	for z in range(115, 294, 28):
		root.add_child(_street_lamp(Vector3(-37.0, 2.0, float(z))))
		root.add_child(_street_lamp(Vector3(37.0, 2.0, float(z))))

	# Gerçek araç sınıflarına benzeyen markasız trafik seti.
	var colors := [Color(0.10,0.14,0.18), Color(0.73,0.75,0.74), Color(0.42,0.055,0.045), Color(0.05,0.22,0.47), Color(0.22,0.25,0.27), Color(0.68,0.55,0.13)]
	for i in range(10):
		var vehicle_kind := "car"
		if i == 7:
			vehicle_kind = "minibus"
		elif i == 8:
			vehicle_kind = "bus"
		elif i == 9:
			vehicle_kind = "truck"
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var vehicle := VehicleFactory.create_vehicle(vehicle_kind, Vector3.ZERO, colors[i % colors.size()])
		vehicle.position = Vector3(side * 21.0, 2.08, 126.0 + float(i / 2) * 28.0)
		vehicle.rotation.y = 0.0 if side < 0.0 else PI
		root.add_child(vehicle)

	# İskele rampasına yaklaşırken görülen siyah-sarı tampon ve yönlendirme işaretleri.
	for side in [-1.0, 1.0]:
		for z in [88.0, 98.0, 108.0]:
			root.add_child(_box(Vector3(1.0, 1.1, 4.6), Vector3(side * 26.0, 2.25, z), Color(0.08, 0.09, 0.095), 0.86, 0.06))
			root.add_child(_box(Vector3(1.03, 0.20, 2.0), Vector3(side * 26.02, 2.35, z), Color(0.90, 0.68, 0.08), 0.68, 0.0))

func _build_navigation_channel(scene: Node) -> void:
	var canakkale := GeoReference.to_local(GeoReference.CANAKKALE)
	var eceabat := GeoReference.to_local(GeoReference.ECEABAT)
	var route := eceabat - canakkale
	var route_dir := route.normalized()
	var side_dir := Vector3(-route_dir.z, 0.0, route_dir.x)
	for i in range(1, 8):
		var t: float = float(i) / 8.0
		var center := canakkale.lerp(eceabat, t)
		var spacing: float = 78.0 + sin(float(i) * 1.7) * 10.0
		var red := _buoy(Color(0.86, 0.045, 0.03), true)
		red.position = center + side_dir * spacing + Vector3(0, 0.2, 0)
		scene.add_child(red)
		var green := _buoy(Color(0.02, 0.55, 0.18), false)
		green.position = center - side_dir * spacing + Vector3(0, 0.2, 0)
		scene.add_child(green)

func _buoy(color: Color, is_red: bool) -> Node3D:
	var root := Node3D.new()
	root.add_child(_cylinder(0.65, 1.30, Vector3(0, 0.65, 0), color, 0.54, 0.04))
	root.add_child(_cylinder(0.30, 1.55, Vector3(0, 1.95, 0), Color(0.22,0.23,0.22), 0.48, 0.25))
	root.add_child(_emissive_sphere(0.20, Vector3(0, 2.75, 0), color, 3.2))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.75, 0)
	light.light_color = color
	light.light_energy = 0.22
	light.omni_range = 10.0
	light.shadow_enabled = false
	root.add_child(light)
	if is_red:
		root.add_child(_box(Vector3(0.80, 0.12, 0.80), Vector3(0, 2.46, 0), color, 0.46, 0.04))
	else:
		root.add_child(_cylinder(0.38, 0.50, Vector3(0, 2.42, 0), color, 0.46, 0.04))
	return root

func _finish_ferry(ship: Node3D) -> void:
	if ship.find_child("V10ShipFinish", false, false) != null:
		return
	var root := Node3D.new()
	root.name = "V10ShipFinish"
	ship.add_child(root)

	# Köprüüstü cam bölmeleri ve silecekler.
	for x in [-5.8, -3.9, -1.95, 0.0, 1.95, 3.9, 5.8]:
		root.add_child(_box(Vector3(0.08, 1.55, 0.12), Vector3(x, 9.0, -1.20), Color(0.55,0.58,0.60), 0.30, 0.55))
	for x in [-4.4, 0.0, 4.4]:
		var wiper := _box(Vector3(0.06, 0.92, 0.08), Vector3(x, 8.96, -1.32), Color(0.045,0.047,0.05), 0.60, 0.32)
		wiper.rotation_degrees.z = 17.0
		root.add_child(wiper)

	# Güverte vinç/ırgat ve yangın dolapları.
	for side in [-1.0, 1.0]:
		for z in [-22.0, 22.0]:
			root.add_child(_cylinder(0.72, 0.55, Vector3(side * 7.6, 5.83, z), Color(0.18,0.19,0.20), 0.48, 0.55))
			root.add_child(_cylinder(0.28, 0.85, Vector3(side * 7.6, 6.45, z), Color(0.42,0.44,0.44), 0.36, 0.62))
		root.add_child(_box(Vector3(0.85, 1.35, 0.45), Vector3(side * 10.25, 6.20, -10.0), Color(0.78,0.045,0.03), 0.54, 0.02))
		root.add_child(_box(Vector3(0.85, 1.35, 0.45), Vector3(side * 10.25, 6.20, 10.0), Color(0.78,0.045,0.03), 0.54, 0.02))

	# Yolcu salonu yan camları: gövdeyi tek parça kutu gibi göstermeyi azaltır.
	for side in [-1.0, 1.0]:
		for z in [-0.2, 2.2, 4.6, 7.0, 9.4]:
			var window := _glass(Vector3(0.08, 0.72, 1.55), Vector3(side * 7.82, 8.35, z))
			root.add_child(window)

	# Baş/kıç güverte reflektörleri ve çalışma ışıkları.
	for z in [-27.0, 27.0]:
		for x in [-7.2, 7.2]:
			root.add_child(_emissive_sphere(0.14, Vector3(x, 6.15, z), Color(1.0,0.82,0.52), 2.8))

func _build_exhaust(ship: Node3D) -> void:
	for i in range(8):
		var puff := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.85
		mesh.height = 1.7
		mesh.radial_segments = 10
		mesh.rings = 5
		puff.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.17, 0.18, 0.19, 0.16)
		mat.roughness = 1.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override = mat
		ship.add_child(puff)
		smoke_puffs.append(puff)
		smoke_phase.append(float(i) / 8.0)

func _street_lamp(pos: Vector3) -> Node3D:
	var group := Node3D.new()
	group.position = pos
	group.add_child(_cylinder(0.11, 7.2, Vector3(0, 3.6, 0), Color(0.20,0.21,0.22), 0.40, 0.55))
	group.add_child(_box(Vector3(2.2, 0.10, 0.10), Vector3(0.92, 7.05, 0), Color(0.20,0.21,0.22), 0.40, 0.55))
	group.add_child(_emissive_sphere(0.18, Vector3(1.88, 6.92, 0), Color(1.0,0.83,0.58), 2.0))
	return group

func _material(color: Color, roughness: float = 0.65, metallic: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(size: Vector3, pos: Vector3, color: Color, roughness: float = 0.65, metallic: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, roughness, metallic)
	return node

func _glass(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var node := _box(size, pos, Color(0.012,0.045,0.072,0.90), 0.10, 0.20)
	var mat := node.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return node

func _cylinder(radius: float, height: float, pos: Vector3, color: Color, roughness: float = 0.55, metallic: float = 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	node.mesh = mesh
	node.position = pos
	node.material_override = _material(color, roughness, metallic)
	return node

func _emissive_sphere(radius: float, pos: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	node.mesh = mesh
	node.position = pos
	var mat := _material(color, 0.16, 0.02)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	node.material_override = mat
	return node
