extends Node

var controller: Node
var ferry: Node3D
var front_ramp: Node3D
var rear_ramp: Node3D

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _frame: int in range(26):
		await get_tree().process_frame
	controller = get_tree().current_scene
	if controller == null:
		return
	var ferry_node: Node = controller.find_child("Ferry", true, false)
	if ferry_node is Node3D:
		ferry = ferry_node as Node3D
	var visual: Node = controller.find_child("V20RemasterFerry", true, false)
	if visual == null:
		return
	var f: Node = visual.find_child("V23_RampFrontVisual", true, false)
	var r: Node = visual.find_child("V23_RampRearVisual", true, false)
	if f is Node3D:
		front_ramp = f as Node3D
	if r is Node3D:
		rear_ramp = r as Node3D

func _process(delta: float) -> void:
	if controller == null or delta <= 0.0:
		return
	var open: bool = bool(controller.get("ramp_open"))
	var target_front: float = deg_to_rad(-18.5) if open else 0.0
	var target_rear: float = deg_to_rad(18.5) if open else 0.0
	var speed: float = deg_to_rad(9.0) * delta
	if front_ramp != null:
		front_ramp.rotation.x = move_toward(front_ramp.rotation.x, target_front, speed)
	if rear_ramp != null:
		rear_ramp.rotation.x = move_toward(rear_ramp.rotation.x, target_rear, speed)
