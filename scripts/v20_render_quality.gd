extends Node

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
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.02
		env.tonemap_white = 1.15
		env.adjustment_enabled = true
		env.adjustment_brightness = 1.0
		env.adjustment_contrast = 1.055
		env.adjustment_saturation = 0.96

		# Contact shadows are critical for cars, ferry equipment and OSM buildings not to float.
		env.ssao_enabled = true
		env.ssao_radius = 2.2
		env.ssao_intensity = 1.35
		env.ssao_power = 1.30
		env.ssao_detail = 0.55
		env.ssao_horizon = 0.08
		env.ssao_sharpness = 0.96
		env.ssao_light_affect = 0.10

		env.glow_enabled = true
		env.glow_intensity = 0.26
		env.glow_bloom = 0.018
		env.fog_enabled = true
		env.fog_density = 0.000055
		env.fog_light_color = Color(0.66, 0.73, 0.77)
		env.fog_sky_affect = 0.34

	for node: Node in scene.find_children("*", "DirectionalLight3D", true, false):
		if not (node is DirectionalLight3D):
			continue
		var sun := node as DirectionalLight3D
		if sun.shadow_enabled:
			sun.directional_shadow_max_distance = 6200.0
			sun.shadow_bias = 0.045
			sun.shadow_normal_bias = 1.1
			sun.shadow_blur = 1.15

	for node: Node in scene.find_children("*", "Camera3D", true, false):
		if node is Camera3D:
			var camera := node as Camera3D
			camera.near = 0.16
			camera.far = 12500.0
