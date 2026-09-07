extends Node

const V20_FERRY_ASSET := "res://assets/v20/ferry_remaster_v20.glb"
const V15_FERRY_ASSET := "res://assets/v15/ferry_realistic_v15.glb"
const V11_FERRY_ASSET := "res://assets/v11/ferry_gestas_style_v11.glb"

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _i in range(6):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D

	var asset_path := ""
	if ResourceLoader.exists(V20_FERRY_ASSET):
		asset_path = V20_FERRY_ASSET
	elif ResourceLoader.exists(V15_FERRY_ASSET):
		asset_path = V15_FERRY_ASSET
	elif ResourceLoader.exists(V11_FERRY_ASSET):
		asset_path = V11_FERRY_ASSET
	if asset_path.is_empty():
		return
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return

	for child in ferry.get_children():
		if child.name == "DynamicCargo":
			continue
		_hide_visuals(child)

	var model := packed.instantiate()
	model.name = "V20RemasterFerry" if asset_path == V20_FERRY_ASSET else "LegacyGLTFFerry"
	ferry.add_child(model)

func _hide_visuals(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = false
	for child in node.get_children():
		_hide_visuals(child)
