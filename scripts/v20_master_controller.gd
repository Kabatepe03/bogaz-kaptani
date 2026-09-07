extends "res://scripts/v20_remaster_controller.gd"

const V20_MASTER_WORLD_PATH := "res://assets/v20/canakkale_eceabat_remaster_v20.glb"
const V20_HALF_WATERLINE_LENGTH := 37.0
const V20_HALF_BEAM := 8.4

var v20_near_sea: MeshInstance3D

func _process(delta: float) -> void:
	super._process(delta)
	if v20_near_sea != null and ferry != null:
		v20_near_sea.global_position = Vector3(ferry.global_position.x, 0.045, ferry.global_position.z)

func _build_world() -> void:
	var real_world_resource: Resource = load(V20_MASTER_WORLD_PATH)
	if not (real_world_resource is PackedScene):
		super._build_world()
		return

	# Far field gives the full Dardanelles horizon without spending hundreds of thousands of
	# vertices where the captain cannot resolve them.
	var far_water := MeshInstance3D.new()
	far_water.name = "V20SeaFar"
	var far_plane := PlaneMesh.new()
	far_plane.size = Vector2(17000.0, 17000.0)
	far_plane.subdivide_width = 180
	far_plane.subdivide_depth = 180
	far_water.mesh = far_plane
	v20_water_material = ShaderMaterial.new()
	v20_water_material.shader = V20WaterShader
	far_water.material_override = v20_water_material
	far_water.position.y = -0.055
	far_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far_water)

	# Dense local patch follows the ferry. World-space shader coordinates keep the wave pattern
	# anchored to the Strait while the mesh itself moves under the camera. ~6 m vertex spacing
	# lets broad swells actually deform the surface instead of looking like a scrolling carpet.
	v20_near_sea = MeshInstance3D.new()
	v20_near_sea.name = "V20SeaNearHighRes"
	var near_plane := PlaneMesh.new()
	near_plane.size = Vector2(1800.0, 1800.0)
	near_plane.subdivide_width = 300
	near_plane.subdivide_depth = 300
	v20_near_sea.mesh = near_plane
	v20_near_sea.material_override = v20_water_material
	v20_near_sea.position.y = 0.045
	v20_near_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(v20_near_sea)

	var real_world: Node = (real_world_resource as PackedScene).instantiate()
	real_world.name = "V20_REAL_CANAKKALE_WORLD"
	add_child(real_world)

	var canakkale := GeoReference.to_local(GeoReference.CANAKKALE_DOCK)
	var eceabat := GeoReference.to_local(GeoReference.ECEABAT_DOCK)
	_build_v20_terminal(canakkale, eceabat, "ÇANAKKALE FERİBOT TERMİNALİ")
	_build_v20_terminal(eceabat, canakkale, "ECEABAT FERİBOT TERMİNALİ")
	_build_dur_yolcu(GeoReference.to_local(GeoReference.DUR_YOLCU))

func _update_v13_assist() -> void:
	super._update_v13_assist()
	if captain_assist_label != null:
		captain_assist_label.text = captain_assist_label.text.replace("V13 KAPTAN ASİSTANI", "V20 KAPTAN KÖPRÜSÜ")

func _apply_v20_wave_buoyancy(delta: float) -> void:
	if ferry == null or delta <= 0.0:
		return
	var basis: Basis = ferry.global_transform.basis
	var forward: Vector3 = -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var starboard: Vector3 = basis.x
	starboard.y = 0.0
	starboard = starboard.normalized()

	var center: Vector3 = ferry.global_position
	var bow_h: float = _v20_sea_height(center + forward * V20_HALF_WATERLINE_LENGTH)
	var stern_h: float = _v20_sea_height(center - forward * V20_HALF_WATERLINE_LENGTH)
	var port_h: float = _v20_sea_height(center - starboard * V20_HALF_BEAM)
	var starboard_h: float = _v20_sea_height(center + starboard * V20_HALF_BEAM)
	var quarter_port_bow: float = _v20_sea_height(center + forward * 19.0 - starboard * 6.0)
	var quarter_starboard_bow: float = _v20_sea_height(center + forward * 19.0 + starboard * 6.0)
	var center_h: float = _v20_sea_height(center)

	# A long Ro-Ro does not ride one point on the sea. Blend six buoyancy samples so broad swells
	# lift the whole vessel while shorter chop mainly changes pitch/roll rather than teleporting it.
	var average_h: float = (bow_h + stern_h + port_h + starboard_h + quarter_port_bow + quarter_starboard_bow + center_h * 2.0) / 8.0
	var target_y: float = 2.0 + average_h * 0.68
	ferry.global_position.y = lerpf(ferry.global_position.y, target_y, clampf(delta * 0.68, 0.0, 1.0))

	var wave_pitch: float = atan2(bow_h - stern_h, V20_HALF_WATERLINE_LENGTH * 2.0)
	var beam_wave: float = ((starboard_h + quarter_starboard_bow) - (port_h + quarter_port_bow)) * 0.5
	var wave_roll: float = atan2(beam_wave, V20_HALF_BEAM * 2.0)

	# Turning heel remains speed/yaw dependent; broad-beam ferry resists rapid roll changes.
	var turn_heel_deg: float = rad_to_deg(yaw_rate) * surge_mps * 0.21
	var drift_heel_deg: float = sway_mps * 0.68
	var static_roll: float = deg_to_rad(base_load_roll + turn_heel_deg + drift_heel_deg)
	var target_pitch: float = clampf(wave_pitch * 0.90, deg_to_rad(-3.4), deg_to_rad(3.4))
	var target_roll: float = clampf(static_roll + wave_roll * 0.82, deg_to_rad(-18.0), deg_to_rad(18.0))

	ferry.rotation.x = lerp_angle(ferry.rotation.x, target_pitch, clampf(delta * 0.62, 0.0, 1.0))
	ferry.rotation.z = lerp_angle(ferry.rotation.z, target_roll, clampf(delta * 0.70, 0.0, 1.0))
