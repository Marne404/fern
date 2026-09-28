class_name BiomeFx
extends Node3D
## The small effects that belong to single biomes (atmosphere key "fx" = {name: strength}, blended across
## borders). Every effect is built when first needed and fades with its strength; weather and time of day
## are applied here (gossamer only on dry days, …).

var _fx := {}          # name → {"node": GPUParticles3D, "level": strength now}
var _haze: MeshInstance3D
var _haze_mat: ShaderMaterial
var _haze_level := 0.0


## fx: blended strengths of the current biomes; shown: the atmosphere after time of day and weather
func update(cam: Camera3D, delta: float, fx: Dictionary, shown: Dictionary) -> void:
	var night := float(shown.get("night", 0.0))
	var rain := float(shown.get("rain", 0.0))
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	# heat shimmer: strongest with a high sun, gone under clouds or in the rain
	var sun_up := clampf(-(shown.get("sun_dir", Vector3.DOWN) as Vector3).normalized().y, 0.0, 1.0)
	var heat := float(fx.get("heat_haze", 0.0)) * smoothstep(0.35, 0.75, sun_up) * (1.0 - night) \
		* (1.0 - clampf(rain * 5.0, 0.0, 1.0)) * (1.0 - float(shown.get("wet", 0.0)))
	_update_haze(heat, delta)
	var dry := (1.0 - clampf(rain * 4.0, 0.0, 1.0)) * (1.0 - float(shown.get("wet", 0.0)) * 0.8)
	# how hard the wind blows right now (1 = calm, up to ~2.6 in a strong gust)
	var gust := clampf((WindGusts.current_strength - 1.0) / 1.2, 0.0, 1.0)
	for name in ["gossamer", "petal_gust", "dandelion", "samara"]:
		var w := float(fx.get(name, 0.0))
		var at := cam.global_position + fwd * 9.0 + Vector3(0, -0.4, 0)
		match name:
			"gossamer":
				w *= (1.0 - night) * dry
			"petal_gust":
				w *= smoothstep(0.1, 0.6, gust) * dry
			"dandelion", "samara":
				w *= (1.0 - night) * dry
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


## After an origin shift the particles are in the wrong place – restart them.
func restart() -> void:
	for n in _fx:
		(_fx[n]["node"] as GPUParticles3D).restart()


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
