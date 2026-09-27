class_name Birds
extends Node3D
## Now and then a small flock of birds flies across the sky in V formation.

var camera: Camera3D
var world: ChunkManager
var enabled := true
var _flocks: Array[Dictionary] = []
var _cooldown := 6.0
var _mesh: ArrayMesh
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		# swept wings
		st.add_vertex(Vector3(0.0, 0.0, -0.25))
		st.add_vertex(Vector3(side * 1.0, 0.0, 0.25))
		st.add_vertex(Vector3(0.0, 0.0, 0.3))
	st.add_vertex(Vector3(0.0, 0.02, -0.45))
	st.add_vertex(Vector3(0.08, 0.0, 0.5))
	st.add_vertex(Vector3(-0.08, 0.0, 0.5))
	st.generate_normals()
	_mesh = st.commit()
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/bird.gdshader")


func _process(delta: float) -> void:
	if camera == null or world == null:
		return
	_cooldown -= delta
	if enabled and _cooldown <= 0.0 and _flocks.size() < 2:
		_spawn()
		_cooldown = _rng.randf_range(20.0, 55.0)
	for i in range(_flocks.size() - 1, -1, -1):
		var f := _flocks[i]
		f["pos"] += f["vel"] * delta
		var root: Node3D = f["node"]
		root.global_position = f["pos"]
		f["age"] += delta
		if f["age"] > 45.0:
			root.queue_free()
			_flocks.remove_at(i)


func _spawn() -> void:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var start := camera.global_position + fwd * _rng.randf_range(70.0, 150.0) - right * side * 180.0
	start.y = world.height_local(start.x, start.z) + _rng.randf_range(28.0, 55.0)
	var dir := (right * side + fwd * _rng.randf_range(-0.3, 0.3)).normalized()
	var root := Node3D.new()
	add_child(root)
	root.look_at_from_position(start, start + dir, Vector3.UP)
	var n := _rng.randi_range(4, 9)
	for k in n:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var row := (k + 1) / 2
		var s := -1.0 if k % 2 == 0 else 1.0
		mi.position = Vector3(s * row * 2.2, _rng.randf_range(-0.4, 0.4), row * 2.6) if k > 0 else Vector3.ZERO
		mi.scale = Vector3.ONE * _rng.randf_range(0.5, 0.7)
		mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
		root.add_child(mi)
	_flocks.append({"node": root, "pos": start, "vel": dir * _rng.randf_range(8.0, 12.0), "age": 0.0})


func shift(offset: Vector3) -> void:
	for f in _flocks:
		f["pos"] -= offset
