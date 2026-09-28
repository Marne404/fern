class_name RainFx
extends Node3D
## Rain around the camera: slanted streaks, little splashes on the ground and the sound of rain.

const SPLASHES := 90

var world: ChunkManager
var particles: GPUParticles3D
var _streak_mat: StandardMaterial3D
var _splashes: MultiMeshInstance3D
var _splash_age := PackedFloat32Array()
var _sound: AudioStreamPlayer
var _intensity := 0.0


func _ready() -> void:
	particles = GPUParticles3D.new()
	particles.amount = 3000
	particles.lifetime = 0.9
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(12, 3, 12)
	pm.emission_shape_offset = Vector3(0, 8, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, -4.0, 0)
	pm.particle_flag_align_y = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.1, Color(1, 1, 1, 1))
	g.add_point(0.9, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	particles.process_material = pm
	_streak_mat = StandardMaterial3D.new()
	_streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_streak_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak_mat.vertex_color_use_as_albedo = true
	_streak_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_streak_mat.billboard_keep_scale = true
	var streak := QuadMesh.new()
	streak.size = Vector2(0.011, 0.38)
	streak.material = _streak_mat
	particles.draw_pass_1 = streak
	particles.emitting = false
	add_child(particles)

	# splashes: tiny crowns that pop up on the ground near you
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.14)
	q.center_offset = Vector3(0, 0.07, 0)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	sm.albedo_texture = _splash_texture()
	q.material = sm
	mm.mesh = q
	mm.instance_count = SPLASHES
	_splashes = MultiMeshInstance3D.new()
	_splashes.multimesh = mm
	_splashes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splashes.custom_aabb = AABB(Vector3(-1e4, -1e4, -1e4), Vector3(2e4, 2e4, 2e4))
	_splashes.top_level = true
	add_child(_splashes)
	_splash_age.resize(SPLASHES)
	for i in SPLASHES:
		_splash_age[i] = randf() * 0.3
		mm.set_instance_color(i, Color(1, 1, 1, 0))

	_sound = AudioStreamPlayer.new()
	_sound.stream = Sfx.rain_loop()
	_sound.volume_db = -80.0
	add_child(_sound)


## rain 0..1, brightness of the light (streaks are not white at night), camera position, wind direction
func update(rain: float, light: float, cam_pos: Vector3, cam_fwd: Vector3, wind: Vector2, delta: float) -> void:
	_intensity = rain
	var on: bool = rain > 0.02 and Settings.values.get("particles", true)
	particles.emitting = on
	if on:
		particles.amount_ratio = clampf(rain, 0.05, 1.0)
		# most of the rain falls in front of you, where you can see it
		particles.global_position = cam_pos + Vector3(cam_fwd.x, 0, cam_fwd.z).normalized() * 6.0 + Vector3(wind.x, 0, wind.y) * 2.0
		(particles.process_material as ParticleProcessMaterial).direction = (Vector3.DOWN * 4.0 + Vector3(wind.x, 0, wind.y)).normalized()
		_streak_mat.albedo_color = Color(Color(0.84, 0.9, 1.0) * lerpf(0.35, 1.0, light), 0.3)
	# sound: fades in and out with the rain
	var vol: float = Settings.values.get("sfx_volume", 0.8)
	var want := rain * vol
	if want > 0.01:
		if not _sound.playing:
			_sound.play()
		_sound.volume_db = linear_to_db(want * 0.55)
	elif _sound.playing:
		_sound.stop()
	_update_splashes(rain if on else 0.0, light, cam_pos, delta)


func _update_splashes(rain: float, light: float, cam_pos: Vector3, delta: float) -> void:
	var mm := _splashes.multimesh
	_splashes.visible = rain > 0.02 and world != null
	if not _splashes.visible:
		return
	var col := Color(0.86, 0.9, 1.0) * lerpf(0.4, 1.0, light)
	for i in SPLASHES:
		_splash_age[i] += delta
		var life := 0.28
		if _splash_age[i] >= life:
			# only as many splashes as it rains
			if randf() > rain:
				_splash_age[i] = randf() * -0.3
				mm.set_instance_color(i, Color(1, 1, 1, 0))
				continue
			_splash_age[i] = 0.0
			var a := randf() * TAU
			var r := sqrt(randf()) * 11.0 + 0.8
			var p := cam_pos + Vector3(cos(a) * r, 0.0, sin(a) * r)
			p.y = world.ground_y(p.x, p.z)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * randf_range(0.7, 1.3)), p))
		if _splash_age[i] < 0.0:
			continue
		var t := _splash_age[i] / life
		var xf := mm.get_instance_transform(i)
		var s := lerpf(0.5, 1.2, t)
		xf.basis = Basis().scaled(Vector3(s, lerpf(1.0, 0.4, t), s))
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, Color(col, (1.0 - t) * 0.75))


## A little crown of droplets (white on transparent)
static func _splash_texture() -> ImageTexture:
	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	for i in 7:
		var a := lerpf(0.25, PI - 0.25, i / 6.0)
		for k in 6:
			var t := k / 5.0
			var x := 16.0 + cos(a) * (3.0 + t * 12.0)
			var y := 19.0 - sin(a) * (2.0 + t * 15.0) - t * t * 2.0
			var rr := lerpf(1.6, 0.9, t)
			for yy in range(int(y - 2), int(y + 3)):
				for xx in range(int(x - 2), int(x + 3)):
					if xx < 0 or yy < 0 or xx >= 32 or yy >= 20:
						continue
					var d := Vector2(xx + 0.5 - x, yy + 0.5 - y).length()
					var al := clampf(rr - d, 0.0, 1.0) * lerpf(1.0, 0.5, t)
					var old := img.get_pixel(xx, yy)
					img.set_pixel(xx, yy, Color(1, 1, 1, maxf(old.a, al)))
	return ImageTexture.create_from_image(img)
