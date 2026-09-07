extends Node

const FOAM_SHADER: Shader = preload("res://shaders/hull_foam_v20.gdshader")

var ferry: Node3D
var root: Node3D
var mat: ShaderMaterial
var previous_position := Vector3.ZERO
var filtered_speed := 0.0

func _ready() -> void:
	call_deferred("_boot")

func _boot() -> void:
	for _frame: int in range(14):
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var found: Node = scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	ferry = found as Node3D
	previous_position = ferry.global_position

	var old: Node = scene.find_child("V20HullContactFoam", true, false)
	if old is Node3D:
		(old as Node3D).visible = false

	root = Node3D.new()
	root.name = "V22HullContactFoam"
	scene.add_child(root)
	mat = ShaderMaterial.new()
	mat.shader = FOAM_SHADER

	var bow := MeshInstance3D.new()
	bow.name = "V22BowBreaker"
	bow.mesh = _make_bow_mesh()
	bow.material_override = mat
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bow)

	var side := MeshInstance3D.new()
	side.name = "V22WaterlineWash"
	side.mesh = _make_side_mesh()
	side.material_override = mat
	side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(side)

func _process(delta: float) -> void:
	if ferry == null or root == null or delta <= 0.0:
		return
	var p := ferry.global_position
	var instant := p.distance_to(previous_position) / maxf(delta, 0.001)
	filtered_speed = lerpf(filtered_speed, instant, clampf(delta * 2.5, 0.0, 1.0))
	previous_position = p
	root.global_position = Vector3(p.x, 0.10, p.z)
	root.global_rotation = Vector3(0.0, ferry.global_rotation.y, 0.0)
	var intensity := clampf((filtered_speed - 0.25) / 6.4, 0.0, 0.72)
	mat.set_shader_parameter("intensity", intensity)
	root.visible = filtered_speed > 0.38

func _make_bow_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var segments := 16
	for side_value: float in [-1.0, 1.0]:
		var start := vertices.size()
		for i: int in range(segments + 1):
			var t := float(i) / float(segments)
			# Only the first ~16 m behind the water-cutting end receive the bright breaking bow wave.
			var z := -41.5 + t * 16.5
			var spread := 0.65 + pow(t, 0.72) * 5.8
			var width := 0.38 + t * 0.92
			var centre := side_value * spread
			vertices.append(Vector3(centre - side_value * width * 0.5, 0.0, z))
			vertices.append(Vector3(centre + side_value * width * 0.5, 0.0, z))
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
			var fade := (1.0 - smoothstep(0.52, 1.0, t)) * smoothstep(0.0, 0.12, t)
			colors.append(Color(1.0, 1.0, 1.0, fade))
			colors.append(Color(1.0, 1.0, 1.0, fade * 0.78))
		for i: int in range(segments):
			var a := start + i * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	return _mesh(vertices, uvs, colors, indices)

func _make_side_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var segments := 38
	for side_value: float in [-1.0, 1.0]:
		var start := vertices.size()
		for i: int in range(segments + 1):
			var t := float(i) / float(segments)
			var z := -31.0 + t * 62.0
			var q := absf(z) / 44.0
			var hull_x := side_value * (8.35 * maxf(0.22, 1.0 - pow(q, 3.0) * 0.45))
			var width := 0.48 + (1.0 - absf(t * 2.0 - 1.0)) * 0.34
			vertices.append(Vector3(hull_x, 0.0, z))
			vertices.append(Vector3(hull_x + side_value * width, 0.0, z))
			uvs.append(Vector2(0.0, t))
			uvs.append(Vector2(1.0, t))
			var end_fade := smoothstep(0.04, 0.14, t) * (1.0 - smoothstep(0.86, 0.96, t))
			colors.append(Color(1.0, 1.0, 1.0, end_fade * 0.62))
			colors.append(Color(1.0, 1.0, 1.0, end_fade * 0.30))
		for i: int in range(segments):
			var a := start + i * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	return _mesh(vertices, uvs, colors, indices)

func _mesh(vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out
