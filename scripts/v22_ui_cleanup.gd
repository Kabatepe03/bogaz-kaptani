extends Node

var installed: bool = false

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(30):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_compact_panels(scene)
	_style_buttons(scene)
	installed = true

func _compact_panels(scene: Node) -> void:
	for node: Node in scene.find_children("*", "Label", true, false):
		if not (node is Label):
			continue
		var label := node as Label
		if label.text.contains("BOĞAZ KAPTANI V22"):
			label.add_theme_font_size_override("font_size", 11)
			var panel := label.get_parent() as Control
			if panel != null:
				_set_rect(panel, 0.018, 0.018, 0.300, 0.082)
		elif label.text.contains("V22 KAPTAN KÖPRÜSÜ"):
			label.add_theme_font_size_override("font_size", 10)
			var panel := label.get_parent() as Control
			if panel != null:
				_set_rect(panel, 0.705, 0.018, 0.900, 0.086)
		elif label.text.begins_with("© OpenStreetMap"):
			label.add_theme_font_size_override("font_size", 9)
			label.modulate.a = 0.48

func _style_buttons(scene: Node) -> void:
	for node: Node in scene.find_children("*", "Button", true, false):
		if not (node is Button):
			continue
		var button := node as Button
		button.modulate = Color(1.0, 1.0, 1.0, 0.86)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.018, 0.035, 0.052, 0.72)
		normal.border_color = Color(0.38, 0.55, 0.66, 0.30)
		normal.set_border_width_all(1)
		normal.corner_radius_top_left = 8
		normal.corner_radius_top_right = 8
		normal.corner_radius_bottom_left = 8
		normal.corner_radius_bottom_right = 8
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.035, 0.075, 0.105, 0.86)
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.055, 0.115, 0.145, 0.92)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_color_override("font_color", Color(0.90, 0.94, 0.96))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _set_rect(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
