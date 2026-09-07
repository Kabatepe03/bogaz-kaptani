extends Node

const V20SkyShader = preload("res://shaders/sky_v20_ultra.gdshader")

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(10):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	for node: Node in scene.find_children("*", "WorldEnvironment", true, false):
		if not (node is WorldEnvironment):
			continue
		var world := node as WorldEnvironment
		var env: Environment = world.environment
		if env == null:
			continue

		# Visible sky is original procedural atmosphere. The external harbour HDRI remains only an
		# asset source/reference and is never shown as a fake Çanakkale horizon.
		var sky_material := ShaderMaterial.new()
		sky_material.shader = V20SkyShader
		var sky := Sky.new()
		sky.sky_material = sky_material
		env.sky = sky
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		env.ambient_light_energy = 0.74

		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.01
		env.tonemap_white = 1.20
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = 1.065
		env.adjustment_saturation = 1.01

		# Contact shadows are critical for cars, ferry equipment and OSM buildings not to float.
		env.ssao_enabled = true
		env.ssao_radius = 2.4
		env.ssao_intensity = 1.42
		env.ssao_power = 1.34
		env.ssao_detail = 0.60
		env.ssao_horizon = 0.08
		env.ssao_sharpness = 0.96
		env.ssao_light_affect = 0.08

		env.glow_enabled = true
		env.glow_intensity = 0.20
		env.glow_bloom = 0.012
		env.fog_enabled = true
		env.fog_density = 0.000072
		env.fog_light_color = Color(0.69, 0.75, 0.78)
		env.fog_sky_affect = 0.46

	for node: Node in scene.find_children("*", "DirectionalLight3D", true, false):
		if not (node is DirectionalLight3D):
			continue
		var sun := node as DirectionalLight3D
		if sun.shadow_enabled:
			sun.directional_shadow_max_distance = 6800.0
			sun.shadow_bias = 0.040
			sun.shadow_normal_bias = 0.92
			sun.shadow_blur = 1.08

	for node: Node in scene.find_children("*", "Camera3D", true, false):
		if node is Camera3D:
			var camera := node as Camera3D
			camera.near = 0.14
			camera.far = 13500.0
