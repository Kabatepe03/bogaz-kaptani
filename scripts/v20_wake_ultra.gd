extends Node

const WakeShader = preload("res://shaders/wake_v20_ultra.gdshader")
const SAMPLE_INTERVAL := 0.14
const WAKE_LIFE := 7.6
const MIN_WAKE_SPEED := 0.95

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
	for _i in range(7):
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		return
	var found := scene.find_child("Ferry", true, false)
	if not (found is Node3D):
		return
	ferry = found as Node3D
	previous_position = ferry.global_position

	for old_name in ["V8Wake", "V20DynamicWake"]:
		var old_wake := scene.find_child(old_name, true, false)
		if old_wake is Node3D:
			(old_wake as Node3D).visible = false

	wake_mesh = MeshInstance3D.new()
	wake_mesh.name = "V20UltraWake"
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
	estimated_speed = lerpf(estimated_speed, instant_speed, clampf(delta * 2.6, 0.0, 1.0))
	previous_position = current

	sample_timer += delta
	rebuild_timer += delta
	if sample_timer >= SAMPLE_INTERVAL:
		sample_timer = 0.0
		if estimated_speed >= MIN_WAKE_SPEED:
			samples.append({
				"p": Vector3(current.x, 0.12, current.z),
				"yaw": ferry.global_rotation.y,
				"speed": estimated_speed,
				"t": Time.get_ticks_msec() * 0.001,
			})

	var now := Time.get_ticks_msec() * 0.001
	while not samples.is_empty() and now - float(samples[0]["t"]) > WAKE_LIFE:
		samples.pop_front()

	if rebuild_timer >= 0.10:
		rebuild_timer = 0.0
		_rebuild_wake(now)

func _rebuild_wake(now: float) -> void:
	if samples.size() < 3:
		wake_mesh.mesh = null
		return

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# 0 = propeller turbulence, -1/+1 = Kelvin side arms.
	for strip_kind in [0, -1, 1]:
		var strip_start := vertices.size()
		var pair_count := 0
		for sample_index in range(samples.size()):
			var sample: Dictionary = samples[sample_index]
			var age := clampf((now - float(sample["t"])) / WAKE_LIFE, 0.0, 1.0)
			var p: Vector3 = sample["p"]
			var yaw := float(sample["yaw"])
			var speed := float(sample["speed"])
			var right := Basis(Vector3.UP, yaw).x.normalized()
			var jitter := sin(float(sample_index) * 1.71 + float(strip_kind) * 2.13) * (0.18 + age * 0.55)

			var center_offset := jitter
			var width := 1.15 + age * 1.15
			var strip_code := 1.0
			if strip_kind != 0:
				center_offset += float(strip_kind) * (2.25 + age * (5.4 + minf(speed, 9.0) * 0.26))
				width = 0.55 + age * 1.25
				strip_code = 0.46
			var center := p + right * center_offset
			var left := center - right * width * 0.5
			var right_p := center + right * width * 0.5
			vertices.append(left)
			vertices.append(right_p)
			uvs.append(Vector2(0.0, age))
			uvs.append(Vector2(1.0, age))
			var fade := 1.0 - age
			colors.append(Color(strip_code, fade, 0.0, fade))
			colors.append(Color(strip_code, fade, 0.0, fade))
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
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	wake_mesh.mesh = mesh
	if wake_material != null:
		wake_material.set_shader_parameter("strength", clampf((estimated_speed - 0.8) / 6.2, 0.12, 0.82))
