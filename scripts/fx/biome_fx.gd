class_name BiomeFx
extends Node3D
## The small effects that belong to single biomes (atmosphere key "fx" = {name: strength}, blended across
## borders). Every effect is built when first needed and fades with its strength; weather and time of day
## are applied here (gossamer only on dry days, …).

var world: ChunkManager
var _fx := {}          # name → {"node": GPUParticles3D, "level": strength now}
var _haze: MeshInstance3D
var _haze_mat: ShaderMaterial
var _haze_level := 0.0
var _gulls: Node3D
var _gull_level := 0.0
var _gull_center := Vector3.ZERO
var _gull_data: Array = []       # per gull: [radius, height, speed, angle]
var _swallows: Node3D
var _sw_level := 0.0
var _sw_data: Array = []         # per swallow: phase offsets for its looping path
var _flies: Node3D
var _fly_level := 0.0
var _fly_data: Array = []        # per dragonfly: {pos, target, wait}
var _fly_rng := RandomNumberGenerator.new()


## fx: blended strengths of the current biomes; shown: the atmosphere after time of day and weather
func update(cam: Camera3D, delta: float, fx: Dictionary, shown: Dictionary) -> void:
	var night := float(shown.get("night", 0.0))
	var rain := float(shown.get("rain", 0.0))
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var dry := (1.0 - clampf(rain * 4.0, 0.0, 1.0)) * (1.0 - float(shown.get("wet", 0.0)) * 0.8)
	# heat shimmer: strongest with a high sun, gone under clouds or in the rain
	var sun_up := clampf(-(shown.get("sun_dir", Vector3.DOWN) as Vector3).normalized().y, 0.0, 1.0)
	var heat := float(fx.get("heat_haze", 0.0)) * smoothstep(0.35, 0.75, sun_up) * (1.0 - night) \
		* (1.0 - clampf(rain * 5.0, 0.0, 1.0)) * (1.0 - float(shown.get("wet", 0.0)))
	_update_haze(heat, delta)
	_update_gulls(float(fx.get("gulls", 0.0)) * (1.0 - night) * (1.0 - clampf(rain * 3.0, 0.0, 1.0)), cam, delta)
	_update_swallows(float(fx.get("swallows", 0.0)) * (1.0 - night) * (1.0 - clampf(rain * 3.0, 0.0, 1.0)), cam, delta)
	_update_dragonflies(float(fx.get("dragonflies", 0.0)) * (1.0 - night) * dry, cam, delta)
	# how hard the wind blows right now (1 = calm, up to ~2.6 in a strong gust)
	var gust := clampf((WindGusts.current_strength - 1.0) / 1.2, 0.0, 1.0)
	for name in ["gossamer", "petal_gust", "dandelion", "samara", "crystal_motes", "wisps", "spores"]:
		var w := float(fx.get(name, 0.0))
		var at := cam.global_position + fwd * 9.0 + Vector3(0, -0.4, 0)
		match name:
			"gossamer":
				w *= (1.0 - night) * dry
			"petal_gust":
				w *= smoothstep(0.1, 0.6, gust) * dry
			"dandelion", "samara":
				w *= (1.0 - night) * dry
			"wisps":
				# will-o'-wisps: from dusk to dawn, faintly on grey foggy days
				w *= clampf(night * 1.4 + float(shown.get("overcast", 0.0)) * 0.3, 0.0, 1.0) * (1.0 - clampf(rain * 3.0, 0.0, 1.0))
				at = cam.global_position + fwd * 14.0 + Vector3(0, -0.8, 0)
			"spores":
				# glowing spores: always a few, many more when it gets dark
				w *= lerpf(0.35, 1.0, night) * (1.0 - clampf(rain * 3.0, 0.0, 1.0))
			"crystal_motes":
				# cold, clear mornings: the air glitters in the low sun
				var hour := float(shown.get("hour", 12.0))
				w *= smoothstep(5.0, 6.5, hour) * (1.0 - smoothstep(10.5, 12.5, hour)) * dry * (1.0 - float(shown.get("overcast", 0.0)))
				at = cam.global_position + fwd * 6.0 + Vector3(0, 2.5, 0)
		_drive(name, w, at, delta, 0.4 if name != "petal_gust" else 2.5)


func _drive(name: String, w: float, pos: Vector3, delta: float, speed := 0.4) -> void:
	var on: bool = w > 0.01 and Settings.values.get("particles", true)
	if not _fx.has(name):
		if not on:
			return
		_fx[name] = {"node": _build(name), "level": 0.0}
	var e: Dictionary = _fx[name]
	e["level"] = move_toward(float(e["level"]), w if on else 0.0, delta * speed)
	var p: GPUParticles3D = e["node"]
	p.emitting = float(e["level"]) > 0.01
	p.amount_ratio = clampf(float(e["level"]), 0.0, 1.0)
	p.global_position = pos


func _update_haze(w: float, delta: float) -> void:
	_haze_level = move_toward(_haze_level, w, delta * 0.3)
	if _haze == null:
		if _haze_level <= 0.005:
			return
		_haze_mat = ShaderMaterial.new()
		_haze_mat.shader = preload("res://shaders/heat_haze.gdshader")
		_haze_mat.set_shader_parameter("noise_tex", preload("res://assets/paint_noise.tres"))
		# first of all transparent things: impostors and water are drawn after it and stay unshifted
		_haze_mat.render_priority = -120
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		_haze = MeshInstance3D.new()
		_haze.mesh = q
		_haze.material_override = _haze_mat
		_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_haze.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
		add_child(_haze)
	_haze.visible = _haze_level > 0.005 and Settings.values.get("heat_haze", true)
	_haze_mat.set_shader_parameter("amount", _haze_level)


## Sea gulls circling over the water side (the sea lies towards +x), gliding with a wingbeat now and then
func _update_gulls(w: float, cam: Camera3D, delta: float) -> void:
	_gull_level = move_toward(_gull_level, w, delta * 0.3)
	if _gulls == null:
		if _gull_level <= 0.01:
			return
		_gulls = Node3D.new()
		_gulls.top_level = true
		add_child(_gulls)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			# long, bent gull wings: inner arm up, outer hand slightly down
			st.add_vertex(Vector3(0.0, 0.0, -0.2))
			st.add_vertex(Vector3(side * 0.55, 0.12, 0.05))
			st.add_vertex(Vector3(0.0, 0.0, 0.2))
			st.add_vertex(Vector3(side * 0.55, 0.12, 0.05))
			st.add_vertex(Vector3(side * 1.2, 0.0, 0.3))
			st.add_vertex(Vector3(side * 0.5, 0.12, -0.12))
		st.add_vertex(Vector3(0.0, 0.03, -0.55))
		st.add_vertex(Vector3(0.1, 0.0, 0.45))
		st.add_vertex(Vector3(-0.1, 0.0, 0.45))
		st.generate_normals()
		var mesh := st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/bird.gdshader")
		# seen from below against the bright sky: a soft grey underside reads better than white
		mat.set_shader_parameter("color", Color(0.72, 0.74, 0.8))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 6:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3.ONE * rng.randf_range(0.55, 0.75)
			mi.set_instance_shader_parameter("phase", rng.randf() * TAU)
			_gulls.add_child(mi)
			_gull_data.append([rng.randf_range(7.0, 18.0), rng.randf_range(-4.0, 6.0), rng.randf_range(0.18, 0.3) * (1.0 if i % 3 else -1.0), rng.randf() * TAU])
		_gull_center = Vector3(INF, INF, INF)
	for d in _fly_data:
		d["pos"] = Vector3.INF
	_gulls.visible = _gull_level > 0.01
	if not _gulls.visible:
		return
	# the circle drifts along with you, out over the sea and ahead
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var target := cam.global_position + Vector3(30.0, 18.0, 0.0) + fwd * 20.0
	if not _gull_center.is_finite() or _gull_center.distance_to(target) > 200.0:
		_gull_center = target
	_gull_center = _gull_center.lerp(target, 1.0 - exp(-delta * 0.15))
	var n := _gulls.get_child_count()
	var shown := int(round(_gull_level * n))
	for i in n:
		var g: Array = _gull_data[i]
		g[3] = float(g[3]) + float(g[2]) * delta
		var a := float(g[3])
		var r := float(g[0])
		var p := _gull_center + Vector3(cos(a) * r, float(g[1]) + sin(a * 2.0) * 1.5, sin(a) * r)
		var tangent := Vector3(-sin(a), 0.0, cos(a)) * signf(float(g[2]))
		var mi := _gulls.get_child(i) as MeshInstance3D
		mi.visible = i < shown
		mi.global_transform = Transform3D(Basis.looking_at(tangent, Vector3.UP).rotated(tangent, -0.3 * signf(float(g[2]))), p).scaled_local(Vector3.ONE * 1.25)


## Swallows darting low over the meadow in fast loops around you (forked tails, swept wings)
func _update_swallows(w: float, cam: Camera3D, delta: float) -> void:
	_sw_level = move_toward(_sw_level, w, delta * 0.3)
	if _swallows == null:
		if _sw_level <= 0.01:
			return
		_swallows = Node3D.new()
		_swallows.top_level = true
		add_child(_swallows)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side in [-1.0, 1.0]:
			# long, pointed, swept-back wings
			st.add_vertex(Vector3(0.0, 0.0, -0.12))
			st.add_vertex(Vector3(side * 0.95, 0.0, 0.42))
			st.add_vertex(Vector3(0.0, 0.0, 0.12))
			# forked tail
			st.add_vertex(Vector3(0.0, 0.0, 0.2))
			st.add_vertex(Vector3(side * 0.22, 0.0, 0.75))
			st.add_vertex(Vector3(side * 0.05, 0.0, 0.3))
		st.add_vertex(Vector3(0.0, 0.03, -0.4))
		st.add_vertex(Vector3(0.07, 0.0, 0.3))
		st.add_vertex(Vector3(-0.07, 0.0, 0.3))
		st.generate_normals()
		var mesh := st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/bird.gdshader")
		mat.set_shader_parameter("color", Color(0.1, 0.14, 0.28))
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for i in 5:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.set_instance_shader_parameter("phase", rng.randf() * TAU)
			_swallows.add_child(mi)
			_sw_data.append([rng.randf() * TAU, rng.randf_range(0.55, 0.85), rng.randf_range(9.0, 16.0), rng.randf() * TAU])
	_swallows.visible = _sw_level > 0.01
	if not _swallows.visible:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var center := cam.global_position + fwd * 12.0
	var ground := center.y - 1.0
	var n := _swallows.get_child_count()
	for i in n:
		var d: Array = _sw_data[i]
		# a figure-eight-ish loop: two frequencies, low over the grass with quick rises
		var s := t * float(d[1]) + float(d[0])
		var r := float(d[2])
		var p := center + Vector3(sin(s) * r, 0.0, sin(s * 2.0 + float(d[3])) * r * 0.6)
		p.y = ground + 1.6 + (sin(s * 3.0 + float(d[3])) * 0.5 + 0.5) * 3.5
		var s2 := s + 0.02
		var p2 := center + Vector3(sin(s2) * r, 0.0, sin(s2 * 2.0 + float(d[3])) * r * 0.6)
		p2.y = ground + 1.6 + (sin(s2 * 3.0 + float(d[3])) * 0.5 + 0.5) * 3.5
		var dir := (p2 - p).normalized()
		var mi := _swallows.get_child(i) as MeshInstance3D
		mi.visible = i < int(round(_sw_level * n))
		if dir.length() > 0.5 and absf(dir.y) < 0.98:
			# banking into the curve
			var bank := clampf((p2 - p).cross(Vector3.UP).dot(fwd) * 8.0, -0.8, 0.8)
			mi.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP).rotated(dir, bank), p).scaled_local(Vector3.ONE * 0.28)


## Dragonflies over the nearest pond: they dart from spot to spot along the shore and hover in between
func _update_dragonflies(w: float, cam: Camera3D, delta: float) -> void:
	var pond := _near_pond(cam)
	if pond.z <= 0.0:
		w = 0.0
	_fly_level = move_toward(_fly_level, w, delta * 0.5)
	if _flies == null:
		if _fly_level <= 0.01:
			return
		_flies = Node3D.new()
		_flies.top_level = true
		add_child(_flies)
		_fly_rng.randomize()
		var mesh := _dragonfly_mesh()
		for i in 5:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3.ONE * 0.2
			mi.set_instance_shader_parameter("phase", _fly_rng.randf() * 10.0)
			_flies.add_child(mi)
			_fly_data.append({"pos": Vector3.INF, "target": Vector3.ZERO, "wait": 0.0})
	_flies.visible = _fly_level > 0.01
	if not _flies.visible:
		for d in _fly_data:
			d["pos"] = Vector3.INF
		return
	var n := _flies.get_child_count()
	for i in n:
		var d: Dictionary = _fly_data[i]
		var mi := _flies.get_child(i) as MeshInstance3D
		mi.visible = i < int(ceil(_fly_level * n))
		if not (d["pos"] as Vector3).is_finite():
			d["pos"] = _shore_spot(pond, cam)
			d["target"] = d["pos"]
		d["wait"] = float(d["wait"]) - delta
		var pos: Vector3 = d["pos"]
		var tgt: Vector3 = d["target"]
		if float(d["wait"]) <= 0.0 and pos.distance_to(tgt) < 0.1:
			d["target"] = _shore_spot(pond, cam)
			d["wait"] = _fly_rng.randf_range(0.8, 3.0)
			tgt = d["target"]
		var to := tgt - pos
		var step := minf(to.length(), delta * 5.5)
		var dir := to.normalized() if to.length() > 0.001 else -mi.global_basis.z
		pos += dir * step
		# while hovering: tiny jitter
		var hover := Vector3(sin(Time.get_ticks_msec() * 0.011 + i), sin(Time.get_ticks_msec() * 0.017 + i * 2.0) * 0.5, cos(Time.get_ticks_msec() * 0.013 + i)) * 0.02
		d["pos"] = pos
		var look := Vector3(dir.x, 0.0, dir.z)
		if look.length() < 0.01:
			look = -mi.global_basis.z
		mi.global_transform = Transform3D(Basis.looking_at(look.normalized(), Vector3.UP).scaled(Vector3.ONE * 0.2), pos + hover)


## Nearest pond (local x, level y, local z in the result: Vector4(x, level, z, radius)); radius 0 if none near
func _near_pond(cam: Camera3D) -> Vector4:
	if world == null:
		return Vector4.ZERO
	var wp := world.local_to_world(cam.global_position)
	var best := Vector4.ZERO
	var bd := 70.0
	for p: Vector4 in world.gen.ponds_near(wp.z):
		var dd := Vector2(p.x - wp.x, p.y - wp.z).length() - p.z
		if dd < bd:
			bd = dd
			var lp := world.world_to_local(Vector3(p.x, p.w, p.y))
			best = Vector4(lp.x, lp.y, lp.z, p.z)
	return best


## A spot just above the water near the shore, preferring the side towards the camera
func _shore_spot(pond: Vector4, cam: Camera3D) -> Vector3:
	var c := Vector3(pond.x, pond.y, pond.z)
	var toward := Vector3(cam.global_position.x - c.x, 0.0, cam.global_position.z - c.z).normalized()
	var a := atan2(toward.z, toward.x) + _fly_rng.randf_range(-0.45, 0.45)
	var r := pond.w * _fly_rng.randf_range(0.82, 0.99)
	return c + Vector3(cos(a) * r, 0.35 + 0.35 + _fly_rng.randf_range(0.0, 0.9), sin(a) * r)


func _dragonfly_mesh() -> ArrayMesh:
	# body: a slim tapering stick with a round head (opaque, iridescent); wings: four glassy blades
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring := func(z: float, r: float) -> PackedVector3Array:
		var pts := PackedVector3Array()
		for k in 6:
			var a := k * TAU / 6.0
			pts.append(Vector3(cos(a) * r, 0.22 + sin(a) * r, z))
		return pts
	var prof := [[-0.62, 0.0], [-0.55, 0.11], [-0.42, 0.12], [-0.3, 0.1], [-0.15, 0.09], [0.1, 0.05], [0.8, 0.035], [0.95, 0.0]]
	for i in prof.size() - 1:
		var a: PackedVector3Array = ring.call(prof[i][0], prof[i][1])
		var b: PackedVector3Array = ring.call(prof[i + 1][0], prof[i + 1][1])
		for k in 6:
			var k2 := (k + 1) % 6
			st.add_vertex(a[k]); st.add_vertex(b[k]); st.add_vertex(b[k2])
			st.add_vertex(a[k]); st.add_vertex(b[k2]); st.add_vertex(a[k2])
	st.generate_normals()
	var body := st.commit()
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.1, 0.45, 0.7)
	bm.metallic = 0.6
	bm.roughness = 0.35
	bm.emission_enabled = true
	bm.emission = Color(0.05, 0.3, 0.35)
	body.surface_set_material(0, bm)
	var sw := SurfaceTool.new()
	sw.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zc: float in [-0.36, -0.18]:
		for side: float in [-1.0, 1.0]:
			var r0 := Vector3(side * 0.05, 0.22, zc - 0.05)
			var r1 := Vector3(side * 0.05, 0.22, zc + 0.05)
			var t0 := Vector3(side * 0.95, 0.22, zc - 0.02)
			var t1 := Vector3(side * 0.9, 0.22, zc + 0.12)
			sw.add_vertex(r0); sw.add_vertex(t0); sw.add_vertex(t1)
			sw.add_vertex(r0); sw.add_vertex(t1); sw.add_vertex(r1)
	sw.generate_normals()
	sw.commit(body)
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/bee.gdshader")
	body.surface_set_material(1, wm)
	return body


## After an origin shift the particles are in the wrong place – restart them.
func restart() -> void:
	for n in _fx:
		(_fx[n]["node"] as GPUParticles3D).restart()
	_gull_center = Vector3(INF, INF, INF)


func _build(name: String) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	var wind: Vector2 = ProjectSettings.get_setting("shader_globals/wind_direction")["value"]
	var wdir := Vector3(wind.x, 0.0, wind.y).normalized()
	match name:
		"gossamer":
			# silk threads of young spiders, drifting slowly on the air (Altweibersommer)
			p.amount = 110
			p.lifetime = 18.0
			p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 20, 80))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(24, 1.6, 24)
			pm.emission_shape_offset = Vector3(0, 1.2, 0)
			pm.direction = (wdir + Vector3(0, 0.08, 0)).normalized()
			pm.spread = 30.0
			pm.initial_velocity_min = 0.25
			pm.initial_velocity_max = 0.7
			pm.gravity = Vector3(0, 0.005, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_scale = 5.0
			pm.turbulence_noise_strength = 0.4
			pm.turbulence_influence_min = 0.02
			pm.turbulence_influence_max = 0.05
			pm.particle_flag_align_y = true
			pm.scale_min = 0.5
			pm.scale_max = 1.5
			var g := Gradient.new()
			g.set_color(0, Color(1, 1, 1, 0))
			g.set_color(1, Color(1, 1, 1, 0))
			g.add_point(0.2, Color(1, 1, 1, 1))
			g.add_point(0.8, Color(1, 1, 1, 1))
			var gt := GradientTexture1D.new()
			gt.gradient = g
			pm.color_ramp = gt
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/gossamer.gdshader")
			var q := QuadMesh.new()
			q.subdivide_depth = 6
			q.material = mat
			p.draw_pass_1 = q
		"dandelion":
			# dandelion seeds: small white tufts that drift slowly up and away, bright against the sun
			p.amount = 90
			p.lifetime = 16.0
			p.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 20, 80))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(22, 1.2, 22)
			pm.direction = (wdir + Vector3(0, 0.3, 0)).normalized()
			pm.spread = 25.0
			pm.initial_velocity_min = 0.4
			pm.initial_velocity_max = 1.0
			pm.gravity = Vector3(0, 0.03, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_scale = 5.0
			pm.turbulence_noise_strength = 0.8
			pm.turbulence_influence_min = 0.03
			pm.turbulence_influence_max = 0.08
			pm.scale_min = 0.05
			pm.scale_max = 0.08
			var gd := Gradient.new()
			gd.set_color(0, Color(1, 1, 1, 0))
			gd.set_color(1, Color(1, 1, 1, 0))
			gd.add_point(0.15, Color(1, 1, 1, 1))
			gd.add_point(0.8, Color(1, 1, 1, 1))
			var gtd := GradientTexture1D.new()
			gtd.gradient = gd
			pm.color_ramp = gtd
			var dm := ShaderMaterial.new()
			dm.shader = preload("res://shaders/seed_tuft.gdshader")
			var dq := QuadMesh.new()
			dq.material = dm
			p.draw_pass_1 = dq
		"wisps":
			# a few soft lights floating low over the bog, drifting slowly and breathing in and out
			p.amount = 26
			p.lifetime = 14.0
			p.visibility_aabb = AABB(Vector3(-50, -10, -50), Vector3(100, 20, 100))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(22, 0.6, 22)
			pm.direction = Vector3(1, 0, 0)
			pm.spread = 180.0
			pm.flatness = 0.9
			pm.initial_velocity_min = 0.15
			pm.initial_velocity_max = 0.45
			pm.gravity = Vector3.ZERO
			pm.turbulence_enabled = true
			pm.turbulence_noise_scale = 8.0
			pm.turbulence_noise_strength = 0.6
			pm.turbulence_influence_min = 0.04
			pm.turbulence_influence_max = 0.1
			pm.scale_min = 0.28
			pm.scale_max = 0.42
			var gw := Gradient.new()
			gw.set_color(0, Color(1, 1, 1, 0))
			gw.set_color(1, Color(1, 1, 1, 0))
			gw.add_point(0.15, Color(1, 1, 1, 1))
			gw.add_point(0.35, Color(1, 1, 1, 0.45))
			gw.add_point(0.55, Color(1, 1, 1, 1))
			gw.add_point(0.75, Color(1, 1, 1, 0.5))
			gw.add_point(0.88, Color(1, 1, 1, 0.9))
			var gtw := GradientTexture1D.new()
			gtw.gradient = gw
			pm.color_ramp = gtw
			var wm := ShaderMaterial.new()
			wm.shader = preload("res://shaders/mote.gdshader")
			wm.set_shader_parameter("tint", Color(0.45, 1.0, 0.85))
			wm.set_shader_parameter("intensity", 7.0)
			wm.set_shader_parameter("near_fade", 6.0)
			var wq := QuadMesh.new()
			wq.material = wm
			p.draw_pass_1 = wq
		"spores":
			# glowing spores rising slowly from the forest floor, cyan and violet
			p.amount = 320
			p.lifetime = 12.0
			p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 25, 60))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(20, 0.5, 20)
			pm.emission_shape_offset = Vector3(0, -0.5, 0)
			pm.direction = Vector3.UP
			pm.spread = 20.0
			pm.initial_velocity_min = 0.2
			pm.initial_velocity_max = 0.45
			pm.gravity = Vector3(0, 0.01, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_scale = 3.0
			pm.turbulence_noise_strength = 0.8
			pm.turbulence_influence_min = 0.04
			pm.turbulence_influence_max = 0.1
			pm.scale_min = 0.03
			pm.scale_max = 0.07
			var gsp := Gradient.new()
			gsp.set_color(0, Color(0.35, 1.0, 0.95, 0))
			gsp.set_color(1, Color(0.8, 0.5, 1.0, 0))
			gsp.add_point(0.2, Color(0.4, 1.0, 0.95, 1))
			gsp.add_point(0.75, Color(0.75, 0.55, 1.0, 0.9))
			var gtsp := GradientTexture1D.new()
			gtsp.gradient = gsp
			pm.color_ramp = gtsp
			var spm := ShaderMaterial.new()
			spm.shader = preload("res://shaders/spore.gdshader")
			var spq := QuadMesh.new()
			spq.material = spm
			p.draw_pass_1 = spq
		"crystal_motes":
			# fine ice crystals in cold morning air: tiny sparks that flash when they catch the sun
			p.amount = 260
			p.lifetime = 8.0
			p.visibility_aabb = AABB(Vector3(-30, -10, -30), Vector3(60, 20, 60))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(14, 3, 14)
			pm.emission_shape_offset = Vector3(0, 1.5, 0)
			pm.direction = wdir
			pm.spread = 60.0
			pm.initial_velocity_min = 0.1
			pm.initial_velocity_max = 0.3
			pm.gravity = Vector3(0, -0.03, 0)
			pm.scale_min = 0.012
			pm.scale_max = 0.025
			var gc := Gradient.new()
			gc.set_color(0, Color(1, 1, 1, 0))
			gc.set_color(1, Color(1, 1, 1, 0))
			gc.add_point(0.3, Color(1, 1, 1, 1))
			gc.add_point(0.7, Color(1, 1, 1, 1))
			var gtc := GradientTexture1D.new()
			gtc.gradient = gc
			pm.color_ramp = gtc
			var cm := ShaderMaterial.new()
			cm.shader = preload("res://shaders/crystal.gdshader")
			var cq := QuadMesh.new()
			cq.material = cm
			p.draw_pass_1 = cq
		"samara":
			# winged maple seeds: they spin fast like little propellers while sinking slowly
			p.amount = 60
			p.lifetime = 9.0
			p.visibility_aabb = AABB(Vector3(-40, -15, -40), Vector3(80, 30, 80))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(20, 2.0, 20)
			pm.emission_shape_offset = Vector3(0, 6.0, 0)
			pm.direction = wdir
			pm.spread = 30.0
			pm.initial_velocity_min = 0.3
			pm.initial_velocity_max = 0.9
			pm.gravity = Vector3(0, -0.9, 0)
			pm.damping_min = 0.6
			pm.damping_max = 0.9
			pm.scale_min = 0.05
			pm.scale_max = 0.07
			var gs := Gradient.new()
			gs.set_color(0, Color(0.72, 0.22, 0.08))
			gs.set_color(1, Color(0.88, 0.52, 0.2))
			var gts := GradientTexture1D.new()
			gts.gradient = gs
			pm.color_initial_ramp = gts
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://shaders/samara.gdshader")
			var sq := QuadMesh.new()
			sq.material = sm
			p.draw_pass_1 = sq
		"petal_gust":
			# a gust tears petals off the cherry trees: they swirl up and away with the wind
			p.amount = 220
			p.lifetime = 5.0
			p.visibility_aabb = AABB(Vector3(-40, -15, -40), Vector3(80, 30, 80))
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = Vector3(18, 4, 18)
			pm.direction = (wdir + Vector3(0, 0.25, 0)).normalized()
			pm.spread = 35.0
			pm.initial_velocity_min = 2.5
			pm.initial_velocity_max = 5.0
			pm.gravity = Vector3(0, -0.35, 0)
			pm.turbulence_enabled = true
			pm.turbulence_noise_scale = 4.0
			pm.turbulence_noise_strength = 2.0
			pm.turbulence_influence_min = 0.1
			pm.turbulence_influence_max = 0.25
			pm.scale_min = 0.05
			pm.scale_max = 0.085
			var gp := Gradient.new()
			gp.set_color(0, Color(1.0, 0.8, 0.92))
			gp.set_color(1, Color(1.0, 0.95, 0.97))
			var gtp := GradientTexture1D.new()
			gtp.gradient = gp
			pm.color_initial_ramp = gtp
			var sc := Curve.new()
			sc.add_point(Vector2(0.0, 0.0))
			sc.add_point(Vector2(0.12, 1.0))
			sc.add_point(Vector2(0.85, 1.0))
			sc.add_point(Vector2(1.0, 0.0))
			var sct := CurveTexture.new()
			sct.curve = sc
			pm.scale_curve = sct
			var pmat := ShaderMaterial.new()
			pmat.shader = preload("res://shaders/leaf_particle.gdshader")
			var pq := QuadMesh.new()
			pq.material = pmat
			p.draw_pass_1 = pq
	p.process_material = pm
	p.preprocess = p.lifetime if name != "petal_gust" else 0.0
	add_child(p)
	return p
