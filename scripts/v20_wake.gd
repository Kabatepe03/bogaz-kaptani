extends Node

const WakeShader = preload("res://shaders/wake_v20.gdshader")
const SAMPLE_INTERVAL := 0.11
const WAKE_LIFE := 10.5
const MIN_WAKE_SPEED := 0.75

var ferry: Node3D
var wake_mesh: MeshInstance3D
var wake_material: ShaderMaterial
var samples: Array[Dictionary] = []
var sample_timer := 0.0
var rebuild_timer := 0.0
var previous_position := Vector3.ZERO
var estimated_speed := 0.0

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
	ferry = found as Node3D
	previous_position = ferry.global_position

	# The old V8 plane wake is what produced the huge white triangular carpet in v15.
	var old_wake := scene.find_child("V8Wake", true, false)
	if old_wake is Node3D:
		(old_wake as Node3D).visible = false

	wake_mesh = MeshInstance3D.new()
	wake_mesh.name = "V20DynamicWake"
	wake_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wake_material = ShaderMaterial.new()
	wake_material.shader = WakeShader
	wake_mesh.material_override = wake_material
	scene.add_child(wake_mesh)

func _process(delta: float) -> void:
	if ferry == null or wake_mesh == null or delta <= 0.0:
		return
	var current := ferry.global_position
	var instant_speed := current.distance_to(previous_position) / maxf(delta, 0.001)
	estimated_speed = lerpf(estimated_speed, instant_speed, clampf(delta * 3.0, 0.0, 1.0))
	previous_position = current

	sample_timer += delta
	rebuild_timer += delta
	if sample_timer >= SAMPLE_INTERVAL:
		sample_timer = 0.0
		if estimated_speed >= MIN_WAKE_SPEED:
			samples.append({
				"p": Vector3(current.x, 0.19, current.z),
				"yaw": ferry.global_rotation.y,
				"speed": estimated_speed,
				"t": Time.get_ticks_msec() * 0.001,
			})

	var now := Time.get_ticks_msec() * 0.001
	while not samples.is_empty() and now - float(samples[0]["t"]) > WAKE_LIFE:
		samples.pop_front()

	if rebuild_timer >= 0.085:
		rebuild_timer = 0.0
		_rebuild_wake(now)

func _rebuild_wake(now: float) -> void:
	if samples.size() < 3:
		wake_mesh.mesh = null
		return

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var strips := [0, -1, 1]

	for strip_kind in strips:
		var strip_start := vertices.size()
		var pair_count := 0
		for sample in samples:
			var age := clampf((now - float(sample["t"])) / WAKE_LIFE, 0.0, 1.0)
			var p: Vector3 = sample["p"]
			var yaw := float(sample["yaw"])
			var speed := float(sample["speed"])
			var right := Basis(Vector3.UP, yaw).x.normalized()

			var center_offset := 0.0
			var width := 2.4 + age * 2.2
			if strip_kind != 0:
				center_offset = float(strip_kind) * (3.0 + age * (11.0 + minf(speed, 9.0) * 0.45))
				width = 1.15 + age * 2.4
			var center := p + right * center_offset
			var left := center - right * width * 0.5
			var right_p := center + right * width * 0.5
			vertices.append(left)
			vertices.append(right_p)
			uvs.append(Vector2(0.0, age))
			uvs.append(Vector2(1.0, age))
			pair_count += 1

		for i in range(pair_count - 1):
			var a := strip_start + i * 2
			var b := a + 1
			var c := a + 2
			var d := a + 3
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	wake_mesh.mesh = mesh

	if wake_material != null:
		wake_material.set_shader_parameter("strength", clampf(estimated_speed / 6.5, 0.22, 0.92))
