extends Node

const TerrainShader = preload("res://shaders/terrain_v20.gdshader")
const FacadeShader = preload("res://shaders/facade_v20.gdshader")
const RoadShader = preload("res://shaders/road_v20.gdshader")

const GRASS_DIFF := "res://assets/v20/terrain/dry_grass_diff.png"
const GRASS_ROUGH := "res://assets/v20/terrain/dry_grass_rough.png"
const DIRT_DIFF := "res://assets/v20/terrain/dirt_diff.png"
const DIRT_ROUGH := "res://assets/v20/terrain/dirt_rough.png"
const ROCK_DIFF := "res://assets/v20/terrain/rock_diff.png"
const ROCK_ROUGH := "res://assets/v20/terrain/rock_rough.png"
const ASPHALT_DIFF := "res://assets/v20/materials/asphalt_diff.png"
const ASPHALT_ROUGH := "res://assets/v20/materials/asphalt_rough.png"

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	# Older visual autoloads also run deferred. Wait until all of them finish, then make v20 the
	# final owner of landscape/city materials.
	for _i in range(14):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	_apply_terrain(scene)
	_apply_buildings(scene)
	_apply_roads(scene)
	_apply_forest(scene)
	_tune_atmosphere(scene)

func _apply_terrain(scene: Node) -> void:
	if not (_tex_exists(GRASS_DIFF) and _tex_exists(DIRT_DIFF) and _tex_exists(ROCK_DIFF)):
		return
	var mat := ShaderMaterial.new()
	mat.shader = TerrainShader
	mat.set_shader_parameter("grass_tex", load(GRASS_DIFF) as Texture2D)
	mat.set_shader_parameter("grass_rough", load(GRASS_ROUGH) as Texture2D)
	mat.set_shader_parameter("dirt_tex", load(DIRT_DIFF) as Texture2D)
	mat.set_shader_parameter("dirt_rough", load(DIRT_ROUGH) as Texture2D)
	mat.set_shader_parameter("rock_tex", load(ROCK_DIFF) as Texture2D)
	mat.set_shader_parameter("rock_rough", load(ROCK_ROUGH) as Texture2D)
	for item in scene.find_children("RealTerrain*", "MeshInstance3D", true, false):
		if item is MeshInstance3D:
			(item as MeshInstance3D).material_override = mat

func _apply_buildings(scene: Node) -> void:
	var facade := ShaderMaterial.new()
	facade.shader = FacadeShader
	for item in scene.find_children("OSM_Buildings_*", "MeshInstance3D", true, false):
		if item is MeshInstance3D:
			(item as MeshInstance3D).material_override = facade

func _apply_roads(scene: Node) -> void:
	if not (_tex_exists(ASPHALT_DIFF) and _tex_exists(ASPHALT_ROUGH)):
		return
	var road_mat := ShaderMaterial.new()
	road_mat.shader = RoadShader
	road_mat.set_shader_parameter("asphalt_tex", load(ASPHALT_DIFF) as Texture2D)
	road_mat.set_shader_parameter("asphalt_rough", load(ASPHALT_ROUGH) as Texture2D)
	for pattern in ["OSM_Roads", "OSM_MainRoads"]:
		for item in scene.find_children(pattern, "MeshInstance3D", true, false):
			if item is MeshInstance3D:
				(item as MeshInstance3D).material_override = road_mat

func _apply_forest(scene: Node) -> void:
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.16, 0.095, 0.050)
	trunk_mat.roughness = 0.96
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.085, 0.18, 0.075)
	crown_mat.roughness = 0.94
	for item in scene.find_children("OSM_Forest_Trunks", "MeshInstance3D", true, false):
		if item is MeshInstance3D:
			(item as MeshInstance3D).material_override = trunk_mat
	for item in scene.find_children("OSM_Forest_Canopies", "MeshInstance3D", true, false):
		if item is MeshInstance3D:
			(item as MeshInstance3D).material_override = crown_mat

func _tune_atmosphere(scene: Node) -> void:
	for item in scene.find_children("*", "WorldEnvironment", true, false):
		if not (item is WorldEnvironment):
			continue
		var world := item as WorldEnvironment
		if world.environment == null:
			continue
		var env := world.environment
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.055, 0.245, 0.47)
		sky_mat.sky_horizon_color = Color(0.62, 0.76, 0.84)
		sky_mat.ground_bottom_color = Color(0.055, 0.075, 0.075)
		sky_mat.ground_horizon_color = Color(0.48, 0.58, 0.60)
		sky_mat.sun_angle_max = 18.0
		sky_mat.sun_curve = 0.10
		sky.sky_material = sky_mat
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.68
		env.fog_enabled = true
		env.fog_density = 0.000075
		env.fog_light_color = Color(0.62, 0.72, 0.77)
		env.adjustment_enabled = true
		env.adjustment_brightness = 0.98
		env.adjustment_contrast = 1.10
		env.adjustment_saturation = 1.03

	# Replace the harsh multi-light appearance with one warm sun plus a very soft sky fill.
	var directional := scene.find_children("*", "DirectionalLight3D", true, false)
	var first := true
	for item in directional:
		if not (item is DirectionalLight3D):
			continue
		var light := item as DirectionalLight3D
		if first:
			first = false
			light.light_color = Color(1.0, 0.92, 0.79)
			light.light_energy = 1.38
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 5200.0
		else:
			light.light_energy = minf(light.light_energy, 0.12)

func _tex_exists(path: String) -> bool:
	return ResourceLoader.exists(path)
