class_name WindStreaks
extends Node3D
## Keeps spawning short white wind lines near the camera that drift with the wind.

const SEGMENTS := 48

var camera: Camera3D
var world: ChunkManager
var shader: Shader = preload("res://shaders/wind_streak.gdshader")
var _streaks: Array[Dictionary] = []
var _cooldown := 0.5
var _rng := RandomNumberGenerator.new()
var enabled := true


func _process(delta: float) -> void:
	if camera == null or world == null:
		return
	_cooldown -= delta
	if enabled and _cooldown <= 0.0 and _streaks.size() < 5:
		_spawn()
		_cooldown = _rng.randf_range(0.6, 2.2)
	for i in range(_streaks.size() - 1, -1, -1):
		var st := _streaks[i]
		st["t"] += delta / st["duration"]
		var mat: ShaderMaterial = st["mat"]
		mat.set_shader_parameter("progress", st["t"])
		if st["t"] > 1.4:
			st["node"].queue_free()
			_streaks.remove_at(i)


func _spawn() -> void:
	var wind: Vector2 = ProjectSettings.get_setting("shader_globals/wind_direction")["value"]
	var wdir := Vector3(wind.x, 0.0, wind.y).normalized()
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var center := camera.global_position + fwd * _rng.randf_range(6.0, 26.0) + right * _rng.randf_range(-10.0, 10.0)
	var length := _rng.randf_range(10.0, 22.0)
	var start := center - wdir * length * 0.5
	start.y = world.height_local(start.x, start.z) + _rng.randf_range(0.8, 3.5)

	var side := wdir.cross(Vector3.UP)
	var amp := _rng.randf_range(0.3, 1.2)
	var freq := _rng.randf_range(0.6, 1.4)
	var loop_at := _rng.randf_range(0.35, 0.7) if _rng.randf() < 0.5 else -1.0
	var pts: Array[Vector3] = []
	for i in SEGMENTS + 1:
		var t := float(i) / SEGMENTS
		var p := start + wdir * length * t
		p += side * sin(t * TAU * freq) * amp
		p.y += sin(t * TAU * freq * 0.7 + 1.0) * amp * 0.35
		# occasionally a small loop
		if loop_at > 0.0:
			var k := (t - loop_at) / 0.12
			if absf(k) < 1.0:
				var a := (k * 0.5 + 0.5) * TAU
				var w := 1.0 - absf(k)
				p += (-wdir * sin(a) * 0.9 + Vector3.UP * (1.0 - cos(a)) * 0.6) * w
		pts.append(p)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in pts.size():
		var tan := (pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)]).normalized()
		var u := float(i) / SEGMENTS
		for sgn in [-1.0, 1.0]:
			verts.append(pts[i])
			normals.append(tan)
			uvs.append(Vector2(u, sgn))
		if i < pts.size() - 1:
			var a := i * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("width", _rng.randf_range(0.025, 0.045))
	mat.set_shader_parameter("opacity", _rng.randf_range(0.35, 0.6))
	mat.set_shader_parameter("trail", _rng.randf_range(0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)
	_streaks.append({"node": mi, "mat": mat, "t": 0.0, "duration": _rng.randf_range(1.6, 2.6)})


func shift(offset: Vector3) -> void:
	for st in _streaks:
		st["node"].global_position -= offset


func clear() -> void:
	for st in _streaks:
		st["node"].queue_free()
	_streaks.clear()
