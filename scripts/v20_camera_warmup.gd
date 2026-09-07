extends Node

func _ready() -> void:
	call_deferred("_warm_render_paths")

func _warm_render_paths() -> void:
	# Let the real world, ferry GLB and material overrides finish importing/instantiating first.
	for _frame: int in range(18):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D

	var viewport := SubViewport.new()
	viewport.name = "V20HiddenShaderWarmup"
	viewport.size = Vector2i(96, 54)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = scene.get_world_3d()
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	var camera := Camera3D.new()
	camera.near = 0.18
	camera.far = 9000.0
	camera.fov = 62.0
	viewport.add_child(camera)
	camera.current = true

	var offsets: Array[Vector3] = [
		Vector3(0.0, 28.0, 105.0),
		Vector3(95.0, 22.0, 0.0),
		Vector3(0.0, 30.0, -105.0),
		Vector3(-95.0, 22.0, 0.0),
		Vector3(0.0, 95.0, 150.0),
	]
	for offset: Vector3 in offsets:
		camera.global_position = ferry.global_position + offset
		camera.look_at(ferry.global_position + Vector3(0.0, 6.0, 0.0), Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame

	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
