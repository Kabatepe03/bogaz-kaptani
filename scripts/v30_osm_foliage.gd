extends Node

const POINTS_PATH := "res://assets/v30/foliage_points.json"
const MANIFEST_PATH := "res://assets/v23/vegetation/MANIFEST.json"
const GeoReference = preload("res://scripts/geo_reference.gd")
const MAX_REAL_TREES := 190

var root: Node3D

func _ready() -> void:
	call_deferred("_install")

func _install() -> void:
	for _frame: int in range(86):
		await get_tree().process_frame
	if not FileAccess.file_exists(POINTS_PATH) or not FileAccess.file_exists(MANIFEST_PATH):
		return
	var point_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(POINTS_PATH))
	var manifest_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not (point_data is Dictionary) or not (manifest_data is Dictionary):
		return
	var points: Array = (point_data as Dictionary).get("points", [])
	var models: Dictionary = (manifest_data as Dictionary).get("models", {})
	if points.is_empty() or models.is_empty():
		return

	var small: PackedScene = _load_model(models, "tree_small_02")
	var island: PackedScene = _load_model(models, "island_tree_03")
	if small == null and island == null:
		return

	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	root = Node3D.new()
	root.name = "V30_OSM_CC0_VEGETATION"
	scene.add_child(root)

	var c_dock: Vector3 = GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var e_dock: Vector3 = GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	var planted := 0
	for raw: Variant in points:
		if planted >= MAX_REAL_TREES:
			break
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw as Dictionary
		var p := Vector3(float(item.get("x", 0.0)), float(item.get("y", 0.0)), float(item.get("z", 0.0)))
		if p.y < 0.65:
			continue
		# Keep terminals and ramp corridors clean so trees never intersect berth geometry.
		if p.distance_to(c_dock) < 115.0 or p.distance_to(e_dock) < 115.0:
			continue
		var kind: String = str(item.get("kind", "small"))
		var packed: PackedScene = island if kind in ["pine", "island"] else small
		if packed == null:
			packed = small if small != null else island
		if packed == null:
			continue
		var model: Node = packed.instantiate()
		if not (model is Node3D):
			model.queue_free()
			continue
		var tree: Node3D = model as Node3D
		tree.name = "V30_RealTree_%03d" % planted
		root.add_child(tree)
		tree.global_position = p
		tree.rotation.y = float(item.get("yaw", 0.0))
		var scale_value: float = float(item.get("scale", 1.0))
		tree.scale = Vector3.ONE * scale_value
		_configure_geometry(tree)
		planted += 1
		if planted % 6 == 0:
			await get_tree().process_frame

func _load_model(models: Dictionary, key: String) -> PackedScene:
	var path: String = str(models.get(key, ""))
	if path.is_empty():
		return null
	if not path.begins_with("res://"):
		path = "res://" + path
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = load(path)
	return resource as PackedScene if resource is PackedScene else null

func _configure_geometry(node: Node) -> void:
	if node is GeometryInstance3D:
		var geom: GeometryInstance3D = node as GeometryInstance3D
		geom.visibility_range_end = 2450.0
		geom.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for child: Node in node.get_children():
		_configure_geometry(child)
