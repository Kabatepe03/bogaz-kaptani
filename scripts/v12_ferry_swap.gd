extends Node

const V15_FERRY_ASSET := "res://assets/v15/ferry_realistic_v15.glb"
const V11_FERRY_ASSET := "res://assets/v11/ferry_gestas_style_v11.glb"

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _i in range(5):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D
	if ferry.find_child("V15RealGLTFFerry", false, false) != null:
		return

	var asset_path: String = V15_FERRY_ASSET if ResourceLoader.exists(V15_FERRY_ASSET) else V11_FERRY_ASSET
	if not ResourceLoader.exists(asset_path):
		return
	var packed := load(asset_path) as PackedScene
	if packed == null:
		return

	for child in ferry.get_children():
		if child.name == "DynamicCargo":
			continue
		_hide_visuals(child)

	var model := packed.instantiate()
	model.name = "V15RealGLTFFerry"
	ferry.add_child(model)

func _hide_visuals(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = false
	for child in node.get_children():
		_hide_visuals(child)
