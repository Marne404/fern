class_name AmbientParticles
extends Node3D
## Leaves, petals, pollen or sand drifting through the air around the camera.

var kind := ""
var color := Color.WHITE
var particles: GPUParticles3D


func set_kind(p_kind: String, p_color: Color) -> void:
	if p_kind == kind and p_color.is_equal_approx(color):
		return
	kind = p_kind
	color = p_color
	if particles:
		particles.queue_free()
		particles = null
	if not Settings.values["particles"]:
		return
	particles = GPUParticles3D.new()
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.turbulence_enabled = true
	pm.turbulence_noise_scale = 6.0
	var wind: Vector2 = ProjectSettings.get_setting("shader_globals/wind_direction")["value"]
	var wdir := Vector3(wind.x, 0.0, wind.y).normalized()
	var mat := ShaderMaterial.new()
	var falling := kind == "leaves" or kind == "petals"
	if falling:
		particles.amount = 90 if kind == "leaves" else 140
		particles.lifetime = 14.0
		pm.emission_box_extents = Vector3(28, 6, 28)
		pm.direction = wdir
		pm.spread = 25.0
		pm.initial_velocity_min = 0.8
		pm.initial_velocity_max = 2.0
		pm.gravity = Vector3(0, -0.45 if kind == "leaves" else -0.3, 0)
		pm.turbulence_noise_strength = 1.5
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.15
		pm.scale_min = 0.07 if kind == "leaves" else 0.05
		pm.scale_max = 0.12 if kind == "leaves" else 0.08
		var g := Gradient.new()
		g.set_color(0, color)
		g.set_color(1, color.lerp(Color(1, 1, 1), 0.35) if kind == "petals" else color.lerp(Color(0.9, 0.15, 0.05), 0.5))
		g.add_point(0.5, color.lerp(Color(1.0, 0.8, 0.3), 0.4))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_initial_ramp = gt
		mat.shader = preload("res://shaders/leaf_particle.gdshader")
	elif kind == "drizzle":
		# light highland drizzle: thin streaks that fall slanted in the wind
		particles.amount = 700
		particles.lifetime = 1.6
		pm.emission_box_extents = Vector3(22, 3, 22)
		pm.direction = (Vector3.DOWN * 3.0 + wdir).normalized()
		pm.spread = 4.0
		pm.initial_velocity_min = 7.0
		pm.initial_velocity_max = 9.0
		pm.gravity = Vector3(0, -2.0, 0)
		pm.scale_min = 1.0
		pm.scale_max = 1.0
		pm.particle_flag_align_y = true
		var gd := Gradient.new()
		gd.set_color(0, Color(1, 1, 1, 0))
		gd.set_color(1, Color(1, 1, 1, 0))
		gd.add_point(0.15, Color(1, 1, 1, 1))
		gd.add_point(0.85, Color(1, 1, 1, 1))
		var gtd := GradientTexture1D.new()
		gtd.gradient = gd
		pm.color_ramp = gtd
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.vertex_color_use_as_albedo = true
		sm.albedo_color = Color(color, 0.2)
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		sm.billboard_keep_scale = true
		sm.disable_receive_shadows = true
		var streak := QuadMesh.new()
		streak.size = Vector2(0.01, 0.3)
		streak.material = sm
		particles.process_material = pm
		particles.draw_pass_1 = streak
		particles.preprocess = particles.lifetime
		pm.emission_shape_offset = Vector3(0, 6, 0)
		add_child(particles)
		return
	elif kind == "fireflies":
		particles.amount = 160
		particles.lifetime = 10.0
		pm.emission_box_extents = Vector3(24, 1.6, 24)
		pm.direction = Vector3.UP
		pm.spread = 180.0
		pm.initial_velocity_min = 0.05
		pm.initial_velocity_max = 0.25
		pm.gravity = Vector3(0, 0.01, 0)
		pm.turbulence_noise_strength = 1.2
		pm.turbulence_noise_scale = 2.5
		pm.turbulence_influence_min = 0.05
		pm.turbulence_influence_max = 0.12
		pm.scale_min = 0.05
		pm.scale_max = 0.09
		var gf := Gradient.new()
		gf.set_color(0, Color(1, 1, 1, 0))
		gf.set_color(1, Color(1, 1, 1, 0))
		gf.add_point(0.2, Color(1, 1, 1, 1))
		gf.add_point(0.45, Color(1, 1, 1, 0.2))
		gf.add_point(0.6, Color(1, 1, 1, 1))
		gf.add_point(0.85, Color(1, 1, 1, 0.3))
		var gtf := GradientTexture1D.new()
		gtf.gradient = gf
		pm.color_ramp = gtf
		mat.shader = preload("res://shaders/mote.gdshader")
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("intensity", 5.0)
	else:
		var sand := kind == "sand"
		particles.amount = 200 if sand else 240
		particles.lifetime = 9.0
		pm.emission_box_extents = Vector3(22, 5, 22)
		pm.direction = wdir
		pm.spread = 40.0
		pm.initial_velocity_min = 1.5 if sand else 0.1
		pm.initial_velocity_max = 3.0 if sand else 0.4
		pm.gravity = Vector3(0, 0.02, 0)
		pm.turbulence_noise_strength = 0.6
		pm.turbulence_influence_min = 0.02
		pm.turbulence_influence_max = 0.06
		pm.scale_min = 0.035
		pm.scale_max = 0.07
		var g2 := Gradient.new()
		g2.set_color(0, Color(1, 1, 1, 0))
		g2.set_color(1, Color(1, 1, 1, 0))
		g2.add_point(0.3, Color(1, 1, 1, 1))
		g2.add_point(0.7, Color(1, 1, 1, 1))
		var gt2 := GradientTexture1D.new()
		gt2.gradient = g2
		pm.color_ramp = gt2
		mat.shader = preload("res://shaders/mote.gdshader")
		mat.set_shader_parameter("tint", color)
		mat.set_shader_parameter("intensity", 0.7 if sand else 1.6)
	var quad := QuadMesh.new()
	quad.material = mat
	particles.process_material = pm
	particles.draw_pass_1 = quad
	particles.preprocess = particles.lifetime
	add_child(particles)


func follow(pos: Vector3, forward: Vector3) -> void:
	if particles:
		particles.global_position = pos + forward * 10.0 - (Vector3(0, 0.6, 0) if kind == "fireflies" else Vector3.ZERO)


## After an origin shift old particles are in the wrong place – restart.
func restart() -> void:
	if particles:
		particles.restart()
