extends Node

func _ready() -> void:
	call_deferred("_install_atmosphere")

func _install_atmosphere() -> void:
	for _frame in range(8):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var world: WorldEnvironment = _find_world_environment(scene)
	if world == null or world.environment == null:
		return

	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.105, 0.245, 0.390)
	sky_material.sky_horizon_color = Color(0.66, 0.75, 0.79)
	sky_material.sky_curve = 0.12
	sky_material.sky_energy_multiplier = 0.92
	sky_material.ground_bottom_color = Color(0.10, 0.12, 0.13)
	sky_material.ground_horizon_color = Color(0.55, 0.58, 0.56)
	sky_material.ground_curve = 0.10
	sky_material.sun_angle_max = 18.0
	sky_material.sun_curve = 0.055
	sky_material.sun_energy_multiplier = 2.2

	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256

	var env: Environment = world.environment
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.72
	env.fog_enabled = true
	env.fog_light_color = Color(0.61, 0.69, 0.70)
	env.fog_light_energy = 0.58
	env.fog_density = 0.000055
	env.fog_sky_affect = 0.34

	_tune_sun(scene)

func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node as WorldEnvironment
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		var found: WorldEnvironment = _find_world_environment(child)
		if found != null:
			return found
	return null

func _tune_sun(node: Node) -> void:
	if node is DirectionalLight3D:
		var sun: DirectionalLight3D = node as DirectionalLight3D
		sun.light_color = Color(1.0, 0.91, 0.76)
		sun.light_energy = 1.12
		sun.shadow_enabled = true
		return
	var children: Array[Node] = node.get_children()
	for child: Node in children:
		_tune_sun(child)