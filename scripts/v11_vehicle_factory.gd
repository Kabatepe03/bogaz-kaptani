class_name V11VehicleFactory
extends RefCounted

const ASSET_ROOT := "res://assets/v11/"

static func weight_for(kind: String) -> float:
	match kind:
		"minibus": return 3.2
		"bus": return 12.0
		"truck": return 28.0
		_: return 1.6

static func create_vehicle(kind: String, pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "V11_%s" % kind.capitalize()
	root.position = pos
	root.set_meta("kind", kind)
	root.set_meta("weight_tons", weight_for(kind))
	var asset_path := _path_for(kind)
	if ResourceLoader.exists(asset_path):
		var packed := load(asset_path) as PackedScene
		if packed != null:
			var model := packed.instantiate()
			model.name = "PBRModel"
			root.add_child(model)
			_apply_color_hint(model, color)
			return root
	_build_fallback(root, kind, color)
	return root

static func _path_for(kind: String) -> String:
	match kind:
		"minibus": return ASSET_ROOT + "minibus_pbr_v11.glb"
		"bus": return ASSET_ROOT + "bus_pbr_v11.glb"
		"truck": return ASSET_ROOT + "truck_pbr_v11.glb"
		_: return ASSET_ROOT + "sedan_pbr_v11.glb"

static func _apply_color_hint(node: Node, color: Color) -> void:
	for child in node.get_children():
		_apply_color_hint(child, color)
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			return
		for surface_index in range(mesh_node.mesh.get_surface_count()):
			var source := mesh_node.get_active_material(surface_index)
			if source is StandardMaterial3D:
				var mat := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				if mat != null and ("paint" in mat.resource_name.to_lower() or "marine" in mat.resource_name.to_lower()):
					mat.albedo_color = color
					mesh_node.set_surface_override_material(surface_index, mat)

static func _build_fallback(root: Node3D, kind: String, color: Color) -> void:
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	match kind:
		"truck": mesh.size = Vector3(2.6, 2.8, 11.0)
		"bus": mesh.size = Vector3(2.55, 2.9, 11.4)
		"minibus": mesh.size = Vector3(2.15, 1.8, 5.8)
		_: mesh.size = Vector3(1.95, 1.2, 4.3)
	body.mesh = mesh
	body.position.y = mesh.size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.16
	mat.roughness = 0.32
	body.material_override = mat
	root.add_child(body)
