class_name Mountains
extends Node3D
## Two rings of distant mountain ranges that move with the camera (so they seem infinitely far away).

var _layers: Array[MeshInstance3D] = []


func _ready() -> void:
	var mesh := _ring_mesh(512, 10)
	var noise: Texture2D = preload("res://assets/paint_noise.tres")
	for spec in [[2600.0, 620.0, 0.13, 0.62], [1500.0, 300.0, 0.57, 0.42]]:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/mountains.gdshader")
		mat.set_shader_parameter("noise_tex", noise)
		mat.set_shader_parameter("radius", spec[0])
		mat.set_shader_parameter("height", spec[1])
		mat.set_shader_parameter("seed", spec[2])
		mat.set_shader_parameter("haze", spec[3])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-4000, -500, -4000), Vector3(8000, 2000, 8000))
		mi.set_meta("height", spec[1])
		add_child(mi)
		_layers.append(mi)


func _ring_mesh(segments: int, rows: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in segments + 1:
		var a := i * TAU / segments
		for j in rows + 1:
			verts.append(Vector3(a, float(j) / rows, 0.0))
	for i in segments:
		for j in rows:
			var v := i * (rows + 1) + j
			var w := v + rows + 1
			idx.append_array([v, w, v + 1, v + 1, w, w + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func follow(cam_pos: Vector3, ground_y: float) -> void:
	global_position = Vector3(cam_pos.x, ground_y, cam_pos.z)


## atmo: current, blended atmosphere of the biome
func apply(atmo: Dictionary, sun_dir_to_sun: Vector3) -> void:
	for i in _layers.size():
		var mat: ShaderMaterial = _layers[i].material_override
		var near := i == 1
		var col: Color = atmo["mountain_color"]
		mat.set_shader_parameter("base_color", col.lerp(atmo["horizon_color"], 0.0 if near else 0.25))
		mat.set_shader_parameter("shadow_color", (atmo["mountain_shadow"] as Color))
		mat.set_shader_parameter("haze_color", atmo["horizon_color"])
		mat.set_shader_parameter("snow", atmo["mountain_snow"] * (0.8 if near else 1.0))
		mat.set_shader_parameter("height", _layers[i].get_meta("height") * atmo["mountain_scale"])
		mat.set_shader_parameter("sun_dir", sun_dir_to_sun)
		mat.set_shader_parameter("sun_color", atmo["sun_color"])
