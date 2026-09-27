class_name DesertFx
extends Node3D
## Desert life: rolling tumbleweeds, wandering dust devils and small sandstorms during gusts
## (low sand streamers over the ground, sandy haze). Strength follows the biome (atmosphere "dust").

var world: ChunkManager
var gusts: WindGusts
var fog_boost := 0.0       # 0..1, for the haze in the atmosphere

var _weeds: Array[Dictionary] = []
var _devil: Dictionary = {}
var devil_timer := 12.0
var devil_ahead := false     # test helper: dust devil straight ahead
var _streamers: GPUParticles3D
var _weed_mesh: ArrayMesh
var _weed_mat: StandardMaterial3D
var _devil_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_weed_mesh = _tumbleweed_mesh()
	_weed_mat = StandardMaterial3D.new()
	_weed_mat.albedo_color = Color(0.5, 0.36, 0.2)
	_weed_mat.roughness = 1.0
	_weed_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_devil_mat = ShaderMaterial.new()
	_devil_mat.shader = preload("res://shaders/dust_devil.gdshader")
	_devil_mat.set_shader_parameter("noise_tex", preload("res://assets/paint_noise.tres"))
	_streamers = _make_streamers()
	add_child(_streamers)


func update(cam: Camera3D, delta: float, intensity: float) -> void:
	var on: bool = Settings.values["particles"] and intensity > 0.02
	var g := gusts.gust if gusts else 0.0
	var wd := WindGusts.direction()
	var cp := cam.global_position
	_update_weeds(cp, wd, g, intensity if on else 0.0, delta)
	_update_devil(cp, wd, -cam.global_basis.z, intensity if on else 0.0, delta)
	# sand streamers only during gusts
	var storm := g * intensity if on else 0.0
	_streamers.emitting = storm > 0.08
	_streamers.amount_ratio = clampf(storm * 1.2, 0.05, 1.0)
	var ground := world.height_local(cp.x, cp.z)
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	_streamers.global_position = Vector3(cp.x, ground + 0.4, cp.z) + fwd.normalized() * 8.0 - wd * 10.0
	(_streamers.process_material as ParticleProcessMaterial).direction = wd
	fog_boost = lerpf(fog_boost, smoothstep(0.35, 0.95, storm), 1.0 - exp(-1.5 * delta))
	RenderingServer.global_shader_parameter_set("sand_storm", fog_boost)


func shift(offset: Vector3) -> void:
	for w in _weeds:
		(w["node"] as Node3D).global_position -= offset
	if not _devil.is_empty():
		(_devil["node"] as Node3D).global_position -= offset
	_streamers.restart()


# ---------------------------------------------------------------- Tumbleweeds

func _update_weeds(cp: Vector3, wd: Vector3, g: float, intensity: float, delta: float) -> void:
	var want := int(round(intensity * 4.0 + g * intensity * 3.0))
	var side := Vector3(-wd.z, 0.0, wd.x)
	if _weeds.size() < want:
		var r := _rng.randf_range(0.5, 0.85)
		var node := MeshInstance3D.new()
		node.mesh = _weed_mesh
		node.material_override = _weed_mat
		node.scale = Vector3.ONE * r
		add_child(node)
		var p := cp - wd * _rng.randf_range(25.0, 45.0) + side * _rng.randf_range(-30.0, 30.0)
		p.y = world.height_local(p.x, p.z) + r
		node.global_position = p
		_weeds.append({"node": node, "r": r, "vy": 0.0, "speed": _rng.randf_range(0.8, 1.2), "wobble": _rng.randf() * TAU})
	for i in range(_weeds.size() - 1, -1, -1):
		var w: Dictionary = _weeds[i]
		var node: MeshInstance3D = w["node"]
		var r: float = w["r"]
		var p := node.global_position
		var rel := p - cp
		# far behind the camera or too many: remove
		if rel.dot(wd) > 60.0 or Vector2(rel.x, rel.z).length() > 95.0 or i >= want + 2:
			node.queue_free()
			_weeds.remove_at(i)
			continue
		w["wobble"] += delta * 0.7
		var dir := (wd + side * sin(w["wobble"]) * 0.25).normalized()
		var speed: float = (2.2 + 5.5 * g) * w["speed"]
		var step := dir * speed * delta
		p += step
		# bouncing: jump up again on impact, higher during gusts
		var ground := world.height_local(p.x, p.z) + r * 0.9
		w["vy"] -= 9.8 * delta
		p.y += w["vy"] * delta
		if p.y <= ground:
			p.y = ground
			w["vy"] = _rng.randf_range(0.6, 2.2) * (0.5 + g)
		node.global_position = p
		# roll around the axis perpendicular to the motion
		var axis := Vector3.UP.cross(dir).normalized()
		node.global_basis = Basis(axis, step.length() / r) * node.global_basis.orthonormalized()
		node.scale = Vector3.ONE * r


## Spherical tangle of thin, bent twigs
static func _tumbleweed_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var axis := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var b := Basis(Quaternion(Vector3.UP, axis))
		var rr := rng.randf_range(0.55, 1.0)
		var a0 := rng.randf() * TAU
		var arc := rng.randf_range(PI * 0.6, PI * 1.6)
		var w := rng.randf_range(0.025, 0.05)
		var prev := Vector3.ZERO
		for k in 11:
			var a := a0 + arc * k / 10.0
			var p := b * Vector3(cos(a), 0.0, sin(a)) * rr * (1.0 + sin(a * 5.0 + i) * 0.06)
			if k > 0:
				var side := (p - prev).cross(p).normalized() * w
				st.add_vertex(prev - side)
				st.add_vertex(prev + side)
				st.add_vertex(p + side)
				st.add_vertex(prev - side)
				st.add_vertex(p + side)
				st.add_vertex(p - side)
			prev = p
	st.generate_normals()
	return st.commit()


# ---------------------------------------------------------------- Dust devils

func _update_devil(cp: Vector3, wd: Vector3, fwd: Vector3, intensity: float, delta: float) -> void:
	if _devil.is_empty():
		devil_timer -= delta
		if devil_timer <= 0.0 and intensity > 0.3:
			_spawn_devil(cp, wd, fwd)
		return
	var node: MeshInstance3D = _devil["node"]
	_devil["age"] += delta
	var age: float = _devil["age"]
	var life: float = _devil["life"]
	var p := node.global_position + (_devil["vel"] as Vector3) * delta
	# funnel center is at half height: foot slightly in the ground
	p.y = world.height_local(p.x, p.z) + 8.5 * node.scale.y - 0.6
	node.global_position = p
	node.rotate_y(delta * 2.5)
	var fade := smoothstep(0.0, 3.0, age) * (1.0 - smoothstep(life - 3.0, life, age)) * intensity
	_devil_mat.set_shader_parameter("fade", fade)
	if age >= life or Vector2(p.x - cp.x, p.z - cp.z).length() > 140.0:
		node.queue_free()
		_devil = {}
		devil_timer = _rng.randf_range(20.0, 45.0)


func _spawn_devil(cp: Vector3, wd: Vector3, fwd: Vector3) -> void:
	# diagonally ahead at some distance, so you can see it well
	var a := atan2(fwd.z, fwd.x) + (0.25 if devil_ahead else _rng.randf_range(-0.9, 0.9))
	var d := 40.0 if devil_ahead else _rng.randf_range(35.0, 75.0)
	var p := cp + Vector3(cos(a), 0.0, sin(a)) * d
	var node := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 3.4
	cm.bottom_radius = 0.35
	cm.height = 17.0
	cm.radial_segments = 28
	cm.rings = 14
	cm.cap_top = false
	cm.cap_bottom = false
	node.mesh = cm
	node.material_override = _devil_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var s := _rng.randf_range(0.7, 1.25)
	node.scale = Vector3(s, s * _rng.randf_range(0.9, 1.3), s)
	p.y = world.height_local(p.x, p.z) + 8.5 * node.scale.y - 0.6
	node.global_position = p
	var side := Vector3(-wd.z, 0.0, wd.x)
	_devil = {"node": node, "age": 0.0, "life": _rng.randf_range(14.0, 24.0),
		"vel": wd * _rng.randf_range(1.0, 2.2) + side * _rng.randf_range(-1.0, 1.0)}


# ---------------------------------------------------------------- Sand streamers

func _make_streamers() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.local_coords = false
	p.amount = 420
	p.lifetime = 1.6
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-50, -10, -50), Vector3(100, 20, 100))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(20, 0.6, 20)
	pm.direction = WindGusts.direction()
	pm.spread = 6.0
	pm.flatness = 0.9
	pm.initial_velocity_min = 9.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_influence_min = 0.02
	pm.turbulence_influence_max = 0.05
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 1))
	g.add_point(0.7, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 3.6)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/sand_streak.gdshader")
	quad.material = mat
	p.draw_pass_1 = quad
	return p
