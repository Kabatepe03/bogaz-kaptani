extends Node

const TerrainShader = preload("res://shaders/terrain_v20.gdshader")
const FacadeShader = preload("res://shaders/facade_v20.gdshader")
const RoadShader = preload("res://shaders/road_v20.gdshader")

var _installed := false

func _ready() -> void:
	call_deferred("_install_when_ready")

func _install_when_ready() -> void:
	for _i in range(16):
		await get_tree().process_frame
		if _install_materials():
			_installed = true
			return
	await get_tree().create_timer(0.75).timeout
	_install_materials()

func _install_materials() -> bool:
	if _installed:
		return true
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var world: Node = scene.find_child("V20_REAL_CANAKKALE_WORLD", true, false)
	if world == null:
		return false

	var grass_diff: Texture2D = _load_texture("res://assets/v20/terrain/dry_grass_diff")
	var grass_rough: Texture2D = _load_texture("res://assets/v20/terrain/dry_grass_rough")
	var dirt_diff: Texture2D = _load_texture("res://assets/v20/terrain/dirt_diff")
	var dirt_rough: Texture2D = _load_texture("res://assets/v20/terrain/dirt_rough")
	var rock_diff: Texture2D = _load_texture("res://assets/v20/terrain/rock_diff")
	var rock_rough: Texture2D = _load_texture("res://assets/v20/terrain/rock_rough")
	var asphalt_diff: Texture2D = _load_texture("res://assets/v20/materials/asphalt_diff")
	var asphalt_rough: Texture2D = _load_texture("res://assets/v20/materials/asphalt_rough")

	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = TerrainShader
	if grass_diff != null: terrain_mat.set_shader_parameter("grass_tex", grass_diff)
	if grass_rough != null: terrain_mat.set_shader_parameter("grass_rough", grass_rough)
	if dirt_diff != null: terrain_mat.set_shader_parameter("dirt_tex", dirt_diff)
	if dirt_rough != null: terrain_mat.set_shader_parameter("dirt_rough", dirt_rough)
	if rock_diff != null: terrain_mat.set_shader_parameter("rock_tex", rock_diff)
	if rock_rough != null: terrain_mat.set_shader_parameter("rock_rough", rock_rough)

	var facade_mat := ShaderMaterial.new()
	facade_mat.shader = FacadeShader

	var road_mat := ShaderMaterial.new()
	road_mat.shader = RoadShader
	if asphalt_diff != null: road_mat.set_shader_parameter("asphalt_tex", asphalt_diff)
	if asphalt_rough != null: road_mat.set_shader_parameter("asphalt_rough", asphalt_rough)

	var changed := 0
	for node in world.find_children("*", "MeshInstance3D", true, false):
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.name.begins_with("RealTerrain"):
			mesh_node.material_override = terrain_mat
			changed += 1
		elif mesh_node.name.begins_with("OSM_Buildings_"):
			mesh_node.material_override = facade_mat
			changed += 1
		elif mesh_node.name == "OSM_Roads" or mesh_node.name == "OSM_MainRoads":
			mesh_node.material_override = road_mat
			changed += 1

	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if not (node is MeshInstance3D):
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.name == "AsphaltSurface":
			mesh_node.material_override = road_mat

	return changed > 0

func _load_texture(base_path: String) -> Texture2D:
	var extensions: Array[String] = [".png", ".jpg", ".jpeg"]
	for extension: String in extensions:
		var path: String = base_path + extension
		if ResourceLoader.exists(path):
			var resource: Resource = load(path)
			if resource is Texture2D:
				return resource as Texture2D
	return null
