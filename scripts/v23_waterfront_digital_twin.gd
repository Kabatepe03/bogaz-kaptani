extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")

const CANAKKALE_KORDON := Vector2(40.15201, 26.40574)
const TROJAN_HORSE_REAL := Vector2(40.152257, 26.405329)
const KORDON_NORTH := Vector2(40.15335, 26.40675)
const KORDON_MID := Vector2(40.15145, 26.40345)
const ECEABAT_NORTH := Vector2(40.18630, 26.36005)
const ECEABAT_SOUTH := Vector2(40.18195, 26.36065)

var asphalt: StandardMaterial3D
var concrete: StandardMaterial3D
var paving: StandardMaterial3D
var cycle_red: StandardMaterial3D
var rail_white: StandardMaterial3D
var dark_metal: StandardMaterial3D
var warm_stone: StandardMaterial3D
var glass: StandardMaterial3D
var roof_red: StandardMaterial3D
var foliage_dark: StandardMaterial3D
var foliage_olive: StandardMaterial3D
var trunk_mat: StandardMaterial3D

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(34):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_setup_materials()
	if scene.find_child("V23_CANAKKALE_KORDON", true, false) == null:
		_build_canakkale_kordon(scene)
	if scene.find_child("V23_ECEABAT_SAHIL", true, false) == null:
		_build_eceabat_waterfront(scene)

func _setup_materials() -> void:
	asphalt = _pbr_or_color("res://assets/v20/materials/asphalt", Color(0.105, 0.11, 0.115), 0.91)
	concrete = _pbr_or_color("res://assets/v20/materials/concrete", Color(0.48, 0.48, 0.45), 0.88)
	paving = _mat(Color(0.53, 0.49, 0.43), 0.86, 0.0)
	cycle_red = _mat(Color(0.37, 0.075, 0.055), 0.88, 0.0)
	rail_white = _mat(Color(0.80, 0.82, 0.80), 0.64, 0.18)
	dark_metal = _mat(Color(0.075, 0.085, 0.088), 0.48, 0.48)
	warm_stone = _mat(Color(0.62, 0.52, 0.39), 0.90, 0.0)
	glass = _mat(Color(0.055, 0.13, 0.16), 0.18, 0.08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.76
	roof_red = _mat(Color(0.40, 0.13, 0.075), 0.88, 0.0)
	foliage_dark = _mat(Color(0.055, 0.19, 0.070), 0.97, 0.0)
	foliage_olive = _mat(Color(0.19, 0.28, 0.10), 0.97, 0.0)
	trunk_mat = _mat(Color(0.16, 0.085, 0.040), 0.99, 0.0)

func _build_canakkale_kordon(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V23_CANAKKALE_KORDON"
	scene.add_child(root)

	var points: Array[Vector3] = [
		GeoReference.to_local(GeoReference.CANAKKALE_DOCK),
		GeoReference.to_local(KORDON_MID),
		GeoReference.to_local(TROJAN_HORSE_REAL),
		GeoReference.to_local(CANAKKALE_KORDON),
		GeoReference.to_local(KORDON_NORTH)
	]
	var eceabat: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	for i in range(points.size() - 1):
		_build_kordon_segment(root, points[i], points[i + 1], eceabat, i)

	# The movie Trojan Horse sits directly on the Kordon. The detailed V22 landmark already owns
	# the sculpture itself; this plaza makes it read as part of the waterfront rather than an object
	# floating in empty terrain.
	var horse_pos := GeoReference.to_local(TROJAN_HORSE_REAL)
	_add_plaza(root, horse_pos, 34.0, 26.0)
	_add_label(root, horse_pos + Vector3(0.0, 0.28, 16.0), "KORDON • TRUVA ATI", 38)

	# Cafe / restaurant frontage behind the promenade. These are intentionally varied instead of
	# one repeated block so the ferry view reads as a lived-in city edge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 230301
	for i in range(15):
		var t: float = (float(i) + 0.5) / 15.0
		var p: Vector3 = _polyline_sample(points, t)
		var tangent: Vector3 = _polyline_tangent(points, t)
		var sea_side: Vector3 = _perp_toward(tangent, eceabat - p)
		var land_side: Vector3 = -sea_side
		var building_pos := p + land_side * rng.randf_range(28.0, 39.0)
		_build_kordon_building(root, building_pos, tangent, rng, i)

	# Street trees and park pockets soften the dense central waterfront.
	for i in range(34):
		var t: float = (float(i) + 0.35) / 34.0
		var p: Vector3 = _polyline_sample(points, t)
		var tangent: Vector3 = _polyline_tangent(points, t)
		var sea_side: Vector3 = _perp_toward(tangent, eceabat - p)
		var land_side: Vector3 = -sea_side
		var tree_pos := p + land_side * (18.0 + float(i % 3) * 4.5)
		root.add_child(_broadleaf_tree(tree_pos + Vector3.UP * 0.15, 0.85 + float(i % 4) * 0.10))

func _build_kordon_segment(root: Node3D, a: Vector3, b: Vector3, sea_target: Vector3, index: int) -> void:
	var tangent := b - a
	tangent.y = 0.0
	var length: float = tangent.length()
	if length < 1.0:
		return
	tangent = tangent.normalized()
	var midpoint := (a + b) * 0.5
	var sea_side := _perp_toward(tangent, sea_target - midpoint)
	var land_side := -sea_side

	# Water edge -> promenade -> cycle lane -> city road.
	_add_oriented_box(root, midpoint + sea_side * 2.0, tangent, Vector3(10.0, 0.26, length + 2.0), concrete, 1.55)
	_add_oriented_box(root, midpoint + land_side * 5.2, tangent, Vector3(6.0, 0.18, length + 1.0), paving, 1.67)
	_add_oriented_box(root, midpoint + land_side * 9.6, tangent, Vector3(2.4, 0.12, length + 1.0), cycle_red, 1.71)
	_add_oriented_box(root, midpoint + land_side * 17.8, tangent, Vector3(11.8, 0.22, length + 1.0), asphalt, 1.61)

	# Kerb and sea wall.
	_add_oriented_box(root, midpoint + sea_side * 7.0, tangent, Vector3(0.75, 1.35, length + 2.0), warm_stone, 0.94)
	_add_railing_line(root, a + sea_side * 6.55 + Vector3.UP * 1.6, b + sea_side * 6.55 + Vector3.UP * 1.6, rail_white, 1.0, 3.2)

	# Road centre marking and bike-lane rhythm.
	_add_oriented_box(root, midpoint + land_side * 17.8 + Vector3.UP * 0.12, tangent, Vector3(0.11, 0.025, length * 0.96), rail_white, 1.73)
	for d in range(12, int(length), 24):
		var p := a.lerp(b, float(d) / length)
		_add_oriented_box(root, p + land_side * 9.6 + Vector3.UP * 0.12, tangent, Vector3(0.10, 0.025, 6.0), rail_white, 1.75)

	# Kordon lamps and benches every few dozen metres.
	var spacing := 22.0
	var count := maxi(1, int(length / spacing))
	for j in range(count + 1):
		var u: float = clampf(float(j) / float(maxi(count, 1)), 0.0, 1.0)
		var p := a.lerp(b, u)
		root.add_child(_lamp(p + land_side * 2.2 + Vector3.UP * 1.75, tangent))
		if (j + index) % 2 == 0:
			root.add_child(_bench(p + land_side * 5.4 + Vector3.UP * 1.72, tangent))

func _build_kordon_building(root: Node3D, position: Vector3, tangent: Vector3, rng: RandomNumberGenerator, index: int) -> void:
	var building := Node3D.new()
	building.position = position
	building.rotation.y = atan2(tangent.x, tangent.z)
	root.add_child(building)
	var width: float = rng.randf_range(12.0, 19.0)
	var depth: float = rng.randf_range(9.0, 15.0)
	var floors: int = rng.randi_range(2, 5)
	var height: float = float(floors) * 3.0 + 0.8
	var tones: Array[Color] = [
		Color(0.67, 0.59, 0.49), Color(0.72, 0.66, 0.55), Color(0.58, 0.62, 0.62),
		Color(0.67, 0.50, 0.42), Color(0.76, 0.72, 0.64)
	]
	var facade := _mat(tones[index % tones.size()], 0.89, 0.0)
	building.add_child(_box(Vector3(width, height, depth), Vector3(0.0, 1.7 + height * 0.5, 0.0), facade))
	building.add_child(_box(Vector3(width + 0.7, 0.28, depth + 0.7), Vector3(0.0, 1.7 + height + 0.18, 0.0), roof_red))
	for floor in range(floors):
		var y: float = 1.7 + 1.8 + float(floor) * 3.0
		for col in range(4):
			var x: float = -width * 0.37 + float(col) * width * 0.245
			building.add_child(_box(Vector3(width * 0.15, 1.45, 0.09), Vector3(x, y, -depth * 0.505), glass))
			if floor > 0 and col % 2 == 0:
				building.add_child(_box(Vector3(width * 0.20, 0.12, 1.15), Vector3(x, y - 0.9, -depth * 0.56), dark_metal))
	# Ground-floor cafe awning.
	var awning_color := _mat(Color(0.18 + float(index % 3) * 0.12, 0.20, 0.17), 0.72, 0.0)
	building.add_child(_box(Vector3(width * 0.72, 0.15, 2.2), Vector3(0.0, 4.15, -depth * 0.60), awning_color))

func _build_eceabat_waterfront(scene: Node) -> void:
	var root := Node3D.new()
	root.name = "V23_ECEABAT_SAHIL"
	scene.add_child(root)
	var a := GeoReference.to_local(ECEABAT_SOUTH)
	var dock := GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var b := GeoReference.to_local(ECEABAT_NORTH)
	var points: Array[Vector3] = [a, dock, b]
	var canakkale := GeoReference.to_local(GeoReference.CANAKKALE_DOCK)

	for i in range(points.size() - 1):
		var p0 := points[i]
		var p1 := points[i + 1]
		var tangent := p1 - p0
		tangent.y = 0.0
		var length := tangent.length()
		tangent = tangent.normalized()
		var midpoint := (p0 + p1) * 0.5
		var sea_side := _perp_toward(tangent, canakkale - midpoint)
		var land_side := -sea_side
		_add_oriented_box(root, midpoint + sea_side * 2.0, tangent, Vector3(8.5, 0.24, length + 2.0), concrete, 1.55)
		_add_oriented_box(root, midpoint + land_side * 5.2, tangent, Vector3(5.5, 0.16, length + 2.0), paving, 1.67)
		_add_oriented_box(root, midpoint + land_side * 13.2, tangent, Vector3(8.0, 0.22, length + 2.0), asphalt, 1.61)
		_add_railing_line(root, p0 + sea_side * 6.0 + Vector3.UP * 1.55, p1 + sea_side * 6.0 + Vector3.UP * 1.55, rail_white, 0.95, 3.0)
		var count := maxi(1, int(length / 25.0))
		for j in range(count + 1):
			var u := float(j) / float(maxi(count, 1))
			var p := p0.lerp(p1, u)
			root.add_child(_lamp(p + land_side * 2.6 + Vector3.UP * 1.70, tangent))
			if j % 2 == 0:
				root.add_child(_bench(p + land_side * 5.4 + Vector3.UP * 1.72, tangent))

	# Eceabat waterfront building row: lower scale and warmer roofs than Çanakkale.
	var rng := RandomNumberGenerator.new()
	rng.seed = 230911
	for i in range(18):
		var t: float = (float(i) + 0.5) / 18.0
		var p := _polyline_sample(points, t)
		var tangent := _polyline_tangent(points, t)
		var sea_side := _perp_toward(tangent, canakkale - p)
		var land_side := -sea_side
		var pos := p + land_side * rng.randf_range(27.0, 38.0)
		_build_eceabat_building(root, pos, tangent, rng, i)

	# Tarihe Saygı-style waterfront green pocket near the terminal: lawn, trees, paths and a low
	# memorial wall silhouette create the recognisable open public-space character without copying
	# any protected sculptural work.
	var park_center := dock + Vector3(-42.0, 1.65, -58.0)
	var lawn := _mat(Color(0.12, 0.31, 0.10), 0.98, 0.0)
	root.add_child(_box(Vector3(58.0, 0.15, 46.0), park_center, lawn))
	root.add_child(_box(Vector3(3.2, 0.12, 42.0), park_center + Vector3(0.0, 0.12, 0.0), paving))
	root.add_child(_box(Vector3(44.0, 0.12, 3.0), park_center + Vector3(0.0, 0.13, 0.0), paving))
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var radius := 14.0 + float(i % 4) * 3.2
		var tp := park_center + Vector3(cos(angle) * radius, 0.15, sin(angle) * radius)
		root.add_child(_broadleaf_tree(tp, 0.80 + float(i % 3) * 0.12))
	root.add_child(_box(Vector3(18.0, 2.2, 0.65), park_center + Vector3(16.0, 1.1, -13.0), warm_stone))
	_add_label(root, park_center + Vector3(16.0, 2.65, -13.4), "ECEABAT SAHİL", 34)

func _build_eceabat_building(root: Node3D, position: Vector3, tangent: Vector3, rng: RandomNumberGenerator, index: int) -> void:
	var building := Node3D.new()
	building.position = position
	building.rotation.y = atan2(tangent.x, tangent.z)
	root.add_child(building)
	var width := rng.randf_range(10.0, 17.0)
	var depth := rng.randf_range(8.0, 13.0)
	var floors := rng.randi_range(2, 4)
	var height := float(floors) * 2.9 + 0.5
	var tones: Array[Color] = [Color(0.76, 0.68, 0.55), Color(0.72, 0.73, 0.65), Color(0.66, 0.58, 0.49), Color(0.79, 0.72, 0.63)]
	var facade := _mat(tones[index % tones.size()], 0.91, 0.0)
	building.add_child(_box(Vector3(width, height, depth), Vector3(0.0, 1.7 + height * 0.5, 0.0), facade))
	building.add_child(_hip_roof(width + 0.8, depth + 0.8, 1.7 + height, roof_red))
	for floor in range(floors):
		for col in range(3):
			var x := -width * 0.31 + float(col) * width * 0.31
			var y := 1.7 + 1.75 + float(floor) * 2.9
			building.add_child(_box(Vector3(width * 0.17, 1.25, 0.08), Vector3(x, y, -depth * 0.505), glass))

func _add_plaza(root: Node3D, center: Vector3, width: float, depth: float) -> void:
	root.add_child(_box(Vector3(width, 0.16, depth), center + Vector3.UP * 1.66, paving))
	for ix in range(-2, 3):
		for iz in range(-1, 2):
			if abs(ix) == 2 or abs(iz) == 1:
				root.add_child(_bench(center + Vector3(float(ix) * 5.5, 1.82, float(iz) * 7.0), Vector3.FORWARD))

func _polyline_sample(points: Array[Vector3], t: float) -> Vector3:
	var lengths: Array[float] = []
	var total := 0.0
	for i in range(points.size() - 1):
		var l := points[i].distance_to(points[i + 1])
		lengths.append(l)
		total += l
	var target := clampf(t, 0.0, 1.0) * total
	var acc := 0.0
	for i in range(lengths.size()):
		if target <= acc + lengths[i] or i == lengths.size() - 1:
			var u := (target - acc) / maxf(lengths[i], 0.001)
			return points[i].lerp(points[i + 1], clampf(u, 0.0, 1.0))
		acc += lengths[i]
	return points[-1]

func _polyline_tangent(points: Array[Vector3], t: float) -> Vector3:
	var a := _polyline_sample(points, maxf(0.0, t - 0.015))
	var b := _polyline_sample(points, minf(1.0, t + 0.015))
	var v := b - a
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.FORWARD

func _perp_toward(tangent: Vector3, target_vector: Vector3) -> Vector3:
	var side := Vector3(-tangent.z, 0.0, tangent.x).normalized()
	var target := target_vector
	target.y = 0.0
	if side.dot(target) < 0.0:
		side = -side
	return side

func _add_oriented_box(root: Node3D, position: Vector3, tangent: Vector3, size: Vector3, material: Material, y: float) -> MeshInstance3D:
	var node := _box(size, Vector3(position.x, y, position.z), material)
	node.rotation.y = atan2(tangent.x, tangent.z)
	root.add_child(node)
	return node

func _add_railing_line(root: Node3D, a: Vector3, b: Vector3, material: Material, height: float, spacing: float) -> void:
	var dir := b - a
	dir.y = 0.0
	var length := dir.length()
	if length < 0.5:
		return
	dir = dir.normalized()
	var mid := (a + b) * 0.5
	_add_oriented_box(root, mid, dir, Vector3(0.09, 0.09, length), material, a.y + height)
	_add_oriented_box(root, mid, dir, Vector3(0.06, 0.06, length), material, a.y + height * 0.54)
	var count := maxi(1, int(length / spacing))
	for i in range(count + 1):
		var p := a.lerp(b, float(i) / float(maxi(count, 1)))
		root.add_child(_box(Vector3(0.09, height, 0.09), Vector3(p.x, a.y + height * 0.5, p.z), material))

func _lamp(position: Vector3, tangent: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = atan2(tangent.x, tangent.z)
	root.add_child(_cylinder(Vector3(0.0, 2.8, 0.0), 0.065, 5.6, dark_metal, 12))
	root.add_child(_box(Vector3(0.9, 0.12, 0.22), Vector3(0.30, 5.45, 0.0), dark_metal))
	var glow := _mat(Color(1.0, 0.73, 0.43), 0.20, 0.0)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.62, 0.28)
	glow.emission_energy_multiplier = 1.6
	root.add_child(_box(Vector3(0.32, 0.10, 0.18), Vector3(0.66, 5.36, 0.0), glow))
	return root

func _bench(position: Vector3, tangent: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = position
	root.rotation.y = atan2(tangent.x, tangent.z)
	var wood := _mat(Color(0.28, 0.13, 0.055), 0.94, 0.0)
	root.add_child(_box(Vector3(2.3, 0.14, 0.62), Vector3(0.0, 0.48, 0.0), wood))
	root.add_child(_box(Vector3(2.3, 0.16, 0.14), Vector3(0.0, 0.92, 0.25), wood))
	for x in [-0.88, 0.88]:
		root.add_child(_box(Vector3(0.10, 0.55, 0.10), Vector3(x, 0.23, 0.0), dark_metal))
	return root

func _broadleaf_tree(position: Vector3, scale_value: float) -> Node3D:
	var root := Node3D.new()
	root.position = position
	var trunk := _cylinder(Vector3(0.0, 2.2 * scale_value, 0.0), 0.22 * scale_value, 4.4 * scale_value, trunk_mat, 10)
	root.add_child(trunk)
	var offsets: Array[Vector3] = [Vector3(0.0, 5.0, 0.0), Vector3(-1.3, 4.7, 0.4), Vector3(1.1, 4.9, -0.5), Vector3(0.3, 5.8, 0.6)]
	for i in range(offsets.size()):
		var crown := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = (1.8 + float(i % 2) * 0.35) * scale_value
		mesh.height = (2.7 + float(i % 3) * 0.25) * scale_value
		mesh.radial_segments = 12
		mesh.rings = 7
		crown.mesh = mesh
		crown.position = offsets[i] * scale_value
		crown.material_override = foliage_dark if i % 3 != 0 else foliage_olive
		root.add_child(crown)
	return root

func _hip_roof(width: float, depth: float, base_y: float, material: Material) -> MeshInstance3D:
	var vertices := PackedVector3Array([
		Vector3(-width * 0.5, base_y, -depth * 0.5), Vector3(width * 0.5, base_y, -depth * 0.5),
		Vector3(width * 0.5, base_y, depth * 0.5), Vector3(-width * 0.5, base_y, depth * 0.5),
		Vector3(0.0, base_y + 2.0, 0.0)
	])
	var indices := PackedInt32Array([0,1,4, 1,2,4, 2,3,4, 3,0,4])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node

func _add_label(root: Node3D, position: Vector3, text: String, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 5
	label.pixel_size = 0.013
	label.position = position
	label.modulate = Color(0.92, 0.93, 0.90)
	root.add_child(label)

func _pbr_or_color(base: String, fallback: Color, roughness: float) -> StandardMaterial3D:
	var mat := _mat(fallback, roughness, 0.0)
	var diff := _load_texture(base + "_diff")
	var normal := _load_texture(base + "_normal")
	var rough := _load_texture(base + "_rough")
	if diff != null:
		mat.albedo_texture = diff
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
	if rough != null:
		mat.roughness_texture = rough
	return mat

func _load_texture(base: String) -> Texture2D:
	for ext in [".png", ".jpg", ".jpeg"]:
		var path := base + ext
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Texture2D:
				return res as Texture2D
	return null

func _mat(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat

func _box(size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = position
	node.material_override = material
	return node

func _cylinder(position: Vector3, radius: float, height: float, material: Material, segments: int) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = segments
	node.mesh = mesh
	node.position = position
	node.material_override = material
	return node
