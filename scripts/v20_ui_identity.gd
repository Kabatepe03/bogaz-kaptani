extends Node

func _ready() -> void:
	call_deferred("_refresh_identity")

func _refresh_identity() -> void:
	for _frame in range(18):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_retitle_tree(scene)

func _retitle_tree(node: Node) -> void:
	if node is Label:
		var label: Label = node as Label
		label.text = _updated_text(label.text)
	elif node is Label3D:
		var label_3d: Label3D = node as Label3D
		label_3d.text = _updated_text(label_3d.text)
	elif node is Button:
		var button: Button = node as Button
		button.text = _updated_text(button.text)

	var children: Array[Node] = node.get_children()
	for child: Node in children:
		_retitle_tree(child)

func _updated_text(value: String) -> String:
	var result: String = value
	result = result.replace("V13 KAPTAN ASİSTANI", "V20 KAPTAN KÖPRÜSÜ")
	result = result.replace("V13 • KAPTAN ASİSTANI", "V20 • KAPTAN KÖPRÜSÜ")
	return result