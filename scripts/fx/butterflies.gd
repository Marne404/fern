class_name Butterflies
extends Node3D
## A few butterflies fluttering around near the camera.

const COLORS := [Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.2), Color(0.35, 0.6, 1.0), Color(1.0, 0.98, 0.94), Color(0.95, 0.35, 0.2)]

var camera: Camera3D
var world: ChunkManager
var _items: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func spawn(count: int) -> void:
	for it in _items:
		it["node"].queue_free()
	_items.clear()
	if count == 0:
		return
	var mesh := _wing_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/butterfly.gdshader")
	mesh.surface_set_material(0, mat)
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("wing_color", COLORS[_rng.randi() % COLORS.size()])
		mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
		mi.set_instance_shader_parameter("flap_speed", _rng.randf_range(13.0, 19.0))
		mi.scale = Vector3.ONE * _rng.randf_range(0.09, 0.14)
		add_child(mi)
		_items.append({"node": mi, "home": Vector3.INF, "seed": _rng.randf() * 100.0,
			"speed": _rng.randf_range(0.5, 0.9), "radius": _rng.randf_range(1.5, 4.0)})


func _wing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var quad := [Vector3(0, 0, -0.5), Vector3(side, 0, -0.5), Vector3(side, 0, 0.5), Vector3(0, 0, 0.5)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k])
	return st.commit()


func _process(delta: float) -> void:
	if camera == null or world == null:
		return
	_time += delta
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for it in _items:
		var home: Vector3 = it["home"]
		if home == Vector3.INF or home.distance_to(camera.global_position) > 28.0 or (home - camera.global_position).dot(fwd) < -4.0:
			var p := camera.global_position + fwd * _rng.randf_range(4.0, 20.0) + fwd.cross(Vector3.UP) * _rng.randf_range(-9.0, 9.0)
			it["home"] = p
			home = p
		var t: float = _time * it["speed"] + it["seed"]
		var r: float = it["radius"]
		var off := Vector3(sin(t * 0.9) * r + sin(t * 2.3) * 0.4, 0.0, cos(t * 0.7) * r + cos(t * 1.9) * 0.4)
		var pos := home + off
		pos.y = world.height_local(pos.x, pos.z) + 0.7 + sin(t * 1.7) * 0.35 + sin(t * 5.1) * 0.08
		var node: MeshInstance3D = it["node"]
		var prev := node.global_position
		node.global_position = pos
		var vel := pos - prev
		vel.y = 0.0
		if vel.length() > 0.01:
			var s := node.scale
			node.look_at(pos + vel, Vector3.UP)
			node.scale = s
