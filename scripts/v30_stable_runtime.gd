extends Node

const WATER_LEVEL := 0.38
const OCEAN_SIZE := 18000.0

var _scene: Node
var _ocean: MeshInstance3D

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	# Run after the inherited V20/V30 passes have finished creating or modifying water.
	for _frame: int in range(92):
		await get_tree().process_frame
	_scene = get_tree().current_scene
	if _scene == null:
		return
	_disable_legacy_water_surfaces(_scene)
	_build_guaranteed_ocean(_scene)
	_force_safe_spawn()

func _disable_legacy_water_surfaces(root: Node) -> void:
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		if not (node is GeometryInstance3D):
			continue
		var geom: GeometryInstance3D = node as GeometryInstance3D
		var n: String = geom.name.to_lower()
		if n == "v303stableocean":
			continue
		if "wake" in n or "foam" in n or "bowbreaker" in n or "waterlinewash" in n:
			geom.visible = false
		elif n == "v20sea" or n == "v12realwater" or n == "v15nearwater" or n == "v15farwater":
			geom.visible = false

func _build_guaranteed_ocean(root: Node) -> void:
	var old: Node = root.find_child("V303StableOcean", true, false)
	if old is MeshInstance3D:
		_ocean = old as MeshInstance3D
		_ocean.visible = true
		return

	_ocean = MeshInstance3D.new()
	_ocean.name = "V303StableOcean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(OCEAN_SIZE, OCEAN_SIZE)
	# A modest grid avoids the GPU cost of the older 320x320 ocean while remaining future-proof
	# for a lightweight vertex-wave material in V31.
	plane.subdivide_width = 72
	plane.subdivide_depth = 72
	_ocean.mesh = plane
	_ocean.position.y = WATER_LEVEL
	_ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Deliberately use StandardMaterial3D here instead of a custom shader. This is the permanent
	# Android-safe fallback: even if a future water shader fails to compile, the Strait stays blue.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.018, 0.145, 0.215)
	mat.roughness = 0.27
	mat.metallic = 0.03
	_ocean.material_override = mat
	root.add_child(_ocean)

func _force_safe_spawn() -> void:
	if _scene == null:
		return
	var collision_guard: Node = _scene.get_node_or_null("/root/V23WorldCollision")
	if collision_guard != null and collision_guard.has_method("_force_safe_spawn"):
		collision_guard.call_deferred("_force_safe_spawn")
	var ferry_node: Node = _scene.find_child("Ferry", true, false)
	if ferry_node is Node3D:
		var ferry := ferry_node as Node3D
		# Never allow the root of the ship below the guaranteed sea surface after a route reset.
		if ferry.global_position.y < WATER_LEVEL + 1.35:
			ferry.global_position.y = WATER_LEVEL + 1.35
