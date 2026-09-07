extends Node

const GeoReference = preload("res://scripts/geo_reference.gd")
const MANIFEST := "res://assets/v23/vegetation/MANIFEST.json"

var root: Node3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 230923
	call_deferred("_install")

func _install() -> void:
	# Wait until the DEM collision is available so every imported tree is planted on real terrain.
	for _frame: int in range(72):
		await get_tree().process_frame
	if not FileAccess.file_exists(MANIFEST):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (parsed is Dictionary):
		return
	var models: Dictionary = parsed.get("models", {})
	if models.is_empty():
		return
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	root = Node3D.new()
	root.name = "V23_CC0_REAL_VEGETATION"
	scene.add_child(root)

	var pine: PackedScene = _load_scene_from_manifest(models, "pine_tree_01")
	var small: PackedScene = _load_scene_from_manifest(models, "tree_small_02")
	var coastal: PackedScene = _load_scene_from_manifest(models, "island_tree_03")
	if pine != null:
		_scatter_eceabat_hills(pine, 185)
	if coastal != null:
		_scatter_eceabat_coast(coastal, 72)
	if small != null:
		_scatter_canakkale_green(small, 82)

func _load_scene_from_manifest(models: Dictionary, key: String) -> PackedScene:
	var path: String = str(models.get(key, ""))
	if path.is_empty():
		return null
	if not path.begins_with("res://"):
		path = "res://" + path
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	return resource as PackedScene if resource is PackedScene else null

func _scatter_eceabat_hills(model: PackedScene, count: int) -> void:
	var center := GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var toward_canakkale := GeoReference.to_local(GeoReference.CANAKKALE_DOCK) - center
	toward_canakkale.y = 0.0
	toward_canakkale = toward_canakkale.normalized()
	var inland := -toward_canakkale
	var lateral := Vector3(-inland.z, 0.0, inland.x)
	var planted := 0
	var attempts := 0
	while planted < count and attempts < count * 9:
		attempts += 1
		var inland_distance := rng.randf_range(140.0, 1700.0)
		var side_distance := rng.randf_range(-1250.0, 1250.0)
		var p := center + inland * inland_distance + lateral * side_distance
		var ground := _ground_point(p.x, p.z)
		if ground == null:
			continue
		var gp: Vector3 = ground
		if gp.y < 2.0 or gp.y > 220.0:
			continue
		_spawn_model(model, gp, rng.randf_range(0.72, 1.22), rng.randf_range(0.0, TAU), 2700.0)
		planted += 1

func _scatter_eceabat_coast(model: PackedScene, count: int) -> void:
	var center := GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var toward_canakkale := GeoReference.to_local(GeoReference.CANAKKALE_DOCK) - center
	toward_canakkale.y = 0.0
	toward_canakkale = toward_canakkale.normalized()
	var inland := -toward_canakkale
	var lateral := Vector3(-inland.z, 0.0, inland.x)
	var planted := 0
	var attempts := 0
	while planted < count and attempts < count * 10:
		attempts += 1
		var p := center + inland * rng.randf_range(55.0, 620.0) + lateral * rng.randf_range(-930.0, 930.0)
		var ground := _ground_point(p.x, p.z)
		if ground == null:
			continue
		var gp: Vector3 = ground
		if gp.y < 1.0 or gp.y > 85.0:
			continue
		_spawn_model(model, gp, rng.randf_range(0.65, 1.08), rng.randf_range(0.0, TAU), 1900.0)
		planted += 1

func _scatter_canakkale_green(model: PackedScene, count: int) -> void:
	var center := GeoReference.to_local(Vector2(40.1520, 26.4055))
	var planted := 0
	var attempts := 0
	while planted < count and attempts < count * 12:
		attempts += 1
		# Keep dense trees out of the water-facing promenade itself; place them behind Kordon and in
		# peri-urban pockets visible from the ferry.
		var p := center + Vector3(rng.randf_range(80.0, 1250.0), 0.0, rng.randf_range(-1200.0, 900.0))
		var ground := _ground_point(p.x, p.z)
		if ground == null:
			continue
		var gp: Vector3 = ground
		if gp.y < 1.0 or gp.y > 120.0:
			continue
		_spawn_model(model, gp, rng.randf_range(0.70, 1.25), rng.randf_range(0.0, TAU), 1700.0)
		planted += 1

func _ground_point(x: float, z: float):
	if get_viewport().world_3d == null:
		return null
	var state: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 320.0, z), Vector3(x, -12.0, z))
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.get("position", null)

func _spawn_model(model: PackedScene, position: Vector3, scale_value: float, yaw: float, visibility_end: float) -> void:
	var node: Node = model.instantiate()
	if not (node is Node3D):
		node.queue_free()
		return
	var tree := node as Node3D
	tree.global_position = position + Vector3.UP * 0.03
	tree.rotation.y = yaw
	tree.scale = Vector3.ONE * scale_value
	root.add_child(tree)
	_tune_visuals(tree, visibility_end)

func _tune_visuals(node: Node, visibility_end: float) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.visibility_range_end = visibility_end
		geometry.visibility_range_end_margin = 160.0
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for child: Node in node.get_children():
		_tune_visuals(child, visibility_end)
