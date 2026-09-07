extends Node

const FERRY_ASSET := "res://assets/v11/ferry_gestas_style_v11.glb"

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
	if ferry.find_child("V12RealGLTFFerry", false, false) != null:
		return
	if not ResourceLoader.exists(FERRY_ASSET):
		return
	var packed := load(FERRY_ASSET) as PackedScene
	if packed == null:
		return

	for child in ferry.get_children():
		if child.name == "DynamicCargo":
			continue
		_hide_visuals(child)

	var model := packed.instantiate()
	model.name = "V12RealGLTFFerry"
	ferry.add_child(model)

func _hide_visuals(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).visible = false
	for child in node.get_children():
		_hide_visuals(child)
