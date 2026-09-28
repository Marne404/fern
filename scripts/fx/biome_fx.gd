class_name BiomeFx
extends Node3D
## The small effects that belong to single biomes (atmosphere key "fx" = {name: strength}, blended across
## borders). Every effect is built when first needed and fades with its strength; weather and time of day
## are applied here (gossamer only on dry days, …).

var _fx := {}          # name → {"node": GPUParticles3D, "base": amount}


## fx: blended strengths of the current biomes; shown: the atmosphere after time of day and weather
func update(cam: Camera3D, delta: float, fx: Dictionary, shown: Dictionary) -> void:
	var night := float(shown.get("night", 0.0))
	var rain := float(shown.get("rain", 0.0))
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	for name in ["gossamer"]:
		var w := float(fx.get(name, 0.0))
		match name:
			"gossamer":
				w *= (1.0 - night) * (1.0 - clampf(rain * 4.0, 0.0, 1.0)) * (1.0 - float(shown.get("wet", 0.0)) * 0.8)
		_drive(name, w, cam.global_position + fwd * 9.0 + Vector3(0, -0.4, 0), delta)


func _drive(name: String, w: float, pos: Vector3, delta: float) -> void:
	var on: bool = w > 0.01 and Settings.values.get("particles", true)
	if not _fx.has(name):
		if not on:
			return
		_fx[name] = {"node": _build(name), "level": 0.0}
	var e: Dictionary = _fx[name]
	e["level"] = move_toward(float(e["level"]), w if on else 0.0, delta * 0.4)
	var p: GPUParticles3D = e["node"]
	p.emitting = float(e["level"]) > 0.01
	p.amount_ratio = clampf(float(e["level"]), 0.0, 1.0)
	p.global_position = pos


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
	p.process_material = pm
	p.preprocess = p.lifetime
	add_child(p)
	return p
