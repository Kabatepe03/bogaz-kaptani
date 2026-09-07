extends Node

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(78):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	# V20 terminal photo-pass was intentionally made from many primitive boxes. V23/V30 now has a
	# richer waterfront/OSM layer, so keeping both causes the exact interpenetrating block look we
	# want to eliminate. Keep the functional berth base, hide only the obsolete decorative overlay.
	for legacy_name: String in ["V20CanakkalePhotoPass", "V20EceabatPhotoPass"]:
		var legacy: Node = scene.find_child(legacy_name, true, false)
		if legacy is Node3D:
			(legacy as Node3D).visible = false

	_hide_floating_terminal_labels(scene)
	_tune_render_ranges(scene)

func _hide_floating_terminal_labels(node: Node) -> void:
	if node is Label3D:
		var label: Label3D = node as Label3D
		var text_upper: String = label.text.to_upper()
		if ("İSKELESİ" in text_upper or "FERİBOT TERMİNAL" in text_upper or "YANAŞMA ALANI" in text_upper) and not ("DUR YOLCU" in text_upper):
			label.visible = false
	for child: Node in node.get_children():
		_hide_floating_terminal_labels(child)

func _tune_render_ranges(node: Node) -> void:
	if node is GeometryInstance3D:
		var geom: GeometryInstance3D = node as GeometryInstance3D
		var n: String = geom.name.to_lower()
		if "v30_facade" in n or "v30_balcon" in n or "v30_store" in n:
			geom.visibility_range_end = 3200.0
			geom.visibility_range_end_margin = 240.0
		elif "v30_road" in n or "v30_sidewalk" in n or "v30_curb" in n:
			geom.visibility_range_end = 4300.0
			geom.visibility_range_end_margin = 300.0
	for child: Node in node.get_children():
		_tune_render_ranges(child)
