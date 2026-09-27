class_name Sea
extends MeshInstance3D
## Large sea surface at the coast. Follows the camera, sits at the sea level of the coastal section.

var world: ChunkManager


func _ready() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# rings with increasing spacing: fine enough near the camera for wave normals, coarse far away
	var radii := [0.0, 40.0, 120.0, 300.0, 700.0, 1500.0, 2600.0, 3800.0]
	var seg := 96
	for ri in radii.size() - 1:
		for i in seg:
			var a0 := i * TAU / seg
			var a1 := (i + 1) * TAU / seg
			var r0: float = radii[ri]
			var r1: float = radii[ri + 1]
			var p00 := Vector3(cos(a0) * r0, 0, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, 0, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, 0, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, 0, sin(a1) * r1)
			for p in [p00, p10, p11, p00, p11, p01]:
				st.set_normal(Vector3.UP)
				st.add_vertex(p)
	mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ocean.gdshader")
	mat.set_shader_parameter("noise_tex", preload("res://assets/paint_noise.tres"))
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-3900, -5, -3900), Vector3(7800, 10, 7800))
	visible = false


func follow(cam_local: Vector3, atmo: Dictionary) -> void:
	if world == null:
		return
	var w := world.local_to_world(cam_local)
	var s := world.gen.sea_near(w.z)
	visible = s.y > 0.0
	if not visible:
		return
	global_position = Vector3(cam_local.x, s.x, cam_local.z)
	var hz: Color = atmo.get("horizon_color", Color.WHITE)
	set_instance_shader_parameter("shallow_color", Color(0.3, 0.72, 0.74))
	set_instance_shader_parameter("deep_color", Color(0.05, 0.22, 0.42).lerp(hz * 0.4, 0.15))
	set_instance_shader_parameter("horizon_color", hz)
	set_instance_shader_parameter("sky_color", atmo.get("zenith_color", Color(0.3, 0.5, 0.9)))
	set_instance_shader_parameter("sun_dir", -(atmo.get("sun_dir", Vector3(0, -0.5, 0.8)) as Vector3).normalized())
	set_instance_shader_parameter("sun_color", atmo.get("sun_color", Color(1, 0.9, 0.75)))
