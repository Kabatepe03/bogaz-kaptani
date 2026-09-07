extends Node

const FoamShader = preload("res://shaders/hull_foam_v20.gdshader")

var ferry: Node3D
var foam_root: Node3D
var foam_material: ShaderMaterial
var last_position := Vector3.ZERO
var filtered_speed := 0.0

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _frame in range(10):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	ferry = found as Node3D
	last_position = ferry.global_position

	foam_root = Node3D.new()
	foam_root.name = "V20HullContactFoam"
	scene.add_child(foam_root)

	foam_material = ShaderMaterial.new()
	foam_material.shader = FoamShader

	var bow_mesh := MeshInstance3D.new()
	bow_mesh.name = "BowWave"
	bow_mesh.mesh = _build_bow_wave_mesh()
	bow_mesh.material_override = foam_material
	bow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam_root.add_child(bow_mesh)

	var side_mesh := MeshInstance3D.new()
	side_mesh.name = "HullSideWash"
	side_mesh.mesh = _build_side_wash_mesh()
	side_mesh.material_override = foam_material
	side_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam_root.add_child(side_mesh)

func _process(delta: float) -> void:
	if ferry == null or foam_root == null or delta <= 0.0:
		return
	var p := ferry.global_position
	var instant_speed := p.distance_to(last_position) / maxf(delta, 0.001)
	filtered_speed = lerpf(filtered_speed, instant_speed, clampf(delta * 2.8, 0.0, 1.0))
	last_position = p

	foam_root.global_position = Vector3(p.x, 0.13, p.z)
	foam_root.global_rotation = Vector3(0.0, ferry.global_rotation.y, 0.0)
	if foam_material != null:
		foam_material.set_shader_parameter("intensity", clampf((filtered_speed - 0.35) / 5.8, 0.05, 0.86))
	foam_root.visible = filtered_speed > 0.45

func _build_bow_wave_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for side in [-1.0, 1.0]:
		var start := vertices.size()
		var segments := 18
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var z := -39.0 + t * 28.0
			var center_x := side * (0.8 + pow(t, 0.62) * 10.7)
			var width := 0.65 + t * 1.85
			vertices.append(Vector3(center_x - side * width * 0.5, 0.0, z))
			vertices.append(Vector3(center_x + side * width * 0.5, 0.0, z))
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
			colors.append(Color(1,1,1,1.0 - t * 0.38))
			colors.append(Color(1,1,1,1.0 - t * 0.38))
		for i in range(segments):
			var a := start + i * 2
			indices.append_array(PackedInt32Array([a, a+2, a+1, a+1, a+2, a+3]))
	return _mesh_from_arrays(vertices, uvs, colors, indices)

func _build_side_wash_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for side in [-1.0, 1.0]:
		var start := vertices.size()
		var segments := 24
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var z := -29.0 + t * 58.0
			var hull_x := side * (8.35 - abs(z) / 44.0 * 0.75)
			vertices.append(Vector3(hull_x, 0.0, z))
			vertices.append(Vector3(hull_x + side * 1.35, 0.0, z))
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
			var end_fade := smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.90, 1.0, t))
			colors.append(Color(1,1,1,end_fade * 0.82))
			colors.append(Color(1,1,1,end_fade * 0.50))
		for i in range(segments):
			var a := start + i * 2
			indices.append_array(PackedInt32Array([a, a+2, a+1, a+1, a+2, a+3]))
	return _mesh_from_arrays(vertices, uvs, colors, indices)

func _mesh_from_arrays(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
