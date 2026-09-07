extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")

var controller: Node
var facade_materials: Array[ShaderMaterial] = []
var night_lights: Array[OmniLight3D] = []
var timer := 0.0
var last_night := false

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(46):
		await get_tree().process_frame
	controller = get_tree().current_scene
	if controller == null:
		return
	_cache_facade_materials()
	_build_waterfront_lights()
	_update_lighting(true)

func _process(delta: float) -> void:
	if controller == null:
		return
	timer += delta
	if timer < 0.30:
		return
	timer = 0.0
	_update_lighting(false)

func _cache_facade_materials() -> void:
	facade_materials.clear()
	var world: Node = controller.find_child("V20_REAL_CANAKKALE_WORLD", true, false)
	if world == null:
		return
	for node: Node in world.find_children("*", "MeshInstance3D", true, false):
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		if not mesh_node.name.begins_with("OSM_Buildings_"):
			continue
		if mesh_node.material_override is ShaderMaterial:
			var material := mesh_node.material_override as ShaderMaterial
			if not facade_materials.has(material):
				facade_materials.append(material)

func _build_waterfront_lights() -> void:
	var root := Node3D.new()
	root.name = "V23_NIGHT_LIGHTS"
	controller.add_child(root)

	# Çanakkale Kordon light line from ferry terminal toward the Trojan Horse / northern promenade.
	var canakkale_points: Array[Vector2] = [
		GeoReference.CANAKKALE_DOCK,
		Vector2(40.15145, 26.40345),
		Vector2(40.152257, 26.405329),
		Vector2(40.15335, 26.40675)
	]
	_add_polyline_lights(root, canakkale_points, 13, Color(1.0, 0.65, 0.36), 30.0, 0.72)

	# Eceabat sahil runs roughly north/south around the ferry terminal.
	var eceabat_points: Array[Vector2] = [
		Vector2(40.18195, 26.36065),
		GeoReference.ECEABAT_DOCK,
		Vector2(40.18630, 26.36005)
	]
	_add_polyline_lights(root, eceabat_points, 11, Color(1.0, 0.68, 0.38), 28.0, 0.68)

	# Stronger but still local pools at both ferry ramps.
	for ll: Vector2 in [GeoReference.CANAKKALE_DOCK, GeoReference.ECEABAT_DOCK]:
		var base := GeoReference.to_local(ll)
		for offset: Vector3 in [Vector3(-13.0, 7.0, -12.0), Vector3(13.0, 7.0, -12.0), Vector3(-13.0, 7.0, 22.0), Vector3(13.0, 7.0, 22.0)]:
			_add_light(root, base + offset, Color(1.0, 0.72, 0.46), 34.0, 0.82)

func _add_polyline_lights(root: Node3D, points_ll: Array[Vector2], count: int, color: Color, range_value: float, energy: float) -> void:
	var points: Array[Vector3] = []
	for ll: Vector2 in points_ll:
		points.append(GeoReference.to_local(ll))
	for i in range(count):
		var t := (float(i) + 0.5) / float(count)
		var p := _sample_polyline(points, t)
		p.y = 7.2
		_add_light(root, p, color, range_value, energy)

func _add_light(root: Node3D, position: Vector3, color: Color, range_value: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 420.0
	light.distance_fade_length = 380.0
	light.visible = false
	root.add_child(light)
	night_lights.append(light)

func _sample_polyline(points: Array[Vector3], t: float) -> Vector3:
	var total := 0.0
	var lengths: Array[float] = []
	for i in range(points.size() - 1):
		var length := points[i].distance_to(points[i + 1])
		lengths.append(length)
		total += length
	var target := clampf(t, 0.0, 1.0) * total
	var accumulated := 0.0
	for i in range(lengths.size()):
		if target <= accumulated + lengths[i] or i == lengths.size() - 1:
			var u := (target - accumulated) / maxf(lengths[i], 0.001)
			return points[i].lerp(points[i + 1], clampf(u, 0.0, 1.0))
		accumulated += lengths[i]
	return points[-1]

func _update_lighting(force: bool) -> void:
	var weather_index: int = int(controller.get("weather_index"))
	var night := weather_index == 3
	if not force and night == last_night:
		return
	last_night = night
	var night_factor := 1.0 if night else 0.0
	for material: ShaderMaterial in facade_materials:
		material.set_shader_parameter("night_factor", night_factor)
	for light: OmniLight3D in night_lights:
		if is_instance_valid(light):
			light.visible = night

	var water_variant = controller.get("v20_water_material")
	if water_variant is ShaderMaterial:
		var water := water_variant as ShaderMaterial
		if night:
			water.set_shader_parameter("deep_color", Vector3(0.0015, 0.008, 0.020))
			water.set_shader_parameter("mid_color", Vector3(0.004, 0.022, 0.040))
			water.set_shader_parameter("shallow_color", Vector3(0.010, 0.050, 0.065))
			water.set_shader_parameter("horizon_color", Vector3(0.025, 0.060, 0.080))
		else:
			water.set_shader_parameter("deep_color", Vector3(0.004, 0.030, 0.052))
			water.set_shader_parameter("mid_color", Vector3(0.010, 0.073, 0.105))
			water.set_shader_parameter("shallow_color", Vector3(0.035, 0.135, 0.148))
			water.set_shader_parameter("horizon_color", Vector3(0.075, 0.180, 0.205))
