extends Node

const FERRY_ASSET := "res://assets/v11/ferry_gestas_style_v11.glb"

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	# Let the legacy visual passes finish first, then replace only their visible ship shell.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	var ferry := found as Node3D
	if ferry.find_child("V12PBRFerryModel", false, false) != null:
		return
	if not ResourceLoader.exists(FERRY_ASSET):
		return
	var packed := load(FERRY_ASSET) as PackedScene
	if packed == null:
		return

	for child in ferry.get_children():
		if child is Camera3D:
			continue
		var child_name := str(child.name)
		if child_name in ["DynamicCargo", "RampFront", "RampRear"]:
			continue
		if "Exhaust" in child_name or "Smoke" in child_name:
			continue
		if child is Node3D:
			(child as Node3D).visible = false

	var model := packed.instantiate()
	model.name = "V12PBRFerryModel"
	ferry.add_child(model)

	# Keep functional ramps above the imported model so the existing RAMPA button still has feedback.
	for ramp_name in ["RampFront", "RampRear"]:
		var ramp := ferry.get_node_or_null(ramp_name)
		if ramp is Node3D:
			(ramp as Node3D).visible = true
