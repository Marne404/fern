class_name Campfire
extends Node3D
## A campfire in a fire ring: dark until someone lights it, then flames, rising sparks, glowing embers,
## a thin trail of smoke, a flickering warm light and a crackling sound. It burns for a while, then only
## the embers glow. Lit fires are remembered by their find spot (`fires`: uid → time it goes out).

const BURN_TIME := 480.0
const GLOW_TIME := 90.0

static var fires := {}
## test helper (--lightfires): every campfire burns
static var debug_lit := false

var uid := 0
var _burn := 0.0           # 0..1 how strong the fire burns now
var _flames: GPUParticles3D
var _sparks: GPUParticles3D
var _smoke: GPUParticles3D
var _embers: MeshInstance3D
var _ember_mat: StandardMaterial3D
var _light: OmniLight3D
var _sound: AudioStreamPlayer3D
var _noise := FastNoiseLite.new()


func _ready() -> void:
	add_to_group("campfire")
	if debug_lit:
		light()
	_noise.frequency = 3.0
	_noise.seed = uid & 0xffff
	_build()
	_apply(_target(), true)


## Seconds this fire still burns (≤ 0: out); from the remembered state
func time_left() -> float:
	return float(fires.get(uid, -1e9)) - Time.get_ticks_msec() / 1000.0


func is_burning() -> bool:
	return time_left() > 0.0


func light() -> void:
	fires[uid] = Time.get_ticks_msec() / 1000.0 + BURN_TIME


## Doused (water pistol): the flames die, the embers still smoke a little
func douse() -> void:
	if is_burning():
		fires[uid] = Time.get_ticks_msec() / 1000.0 - GLOW_TIME * 0.4


## How strong the fire should be: 1 while burning (fading in the last minute), embers glow afterwards
func _target() -> float:
	var t := time_left()
	if t > 60.0:
		return 1.0
	if t > 0.0:
		return lerpf(0.35, 1.0, t / 60.0)
	if t > -GLOW_TIME:
		return 0.12 * (1.0 + t / GLOW_TIME)
	return 0.0


func _process(delta: float) -> void:
	_apply(move_toward(_burn, _target(), delta * 0.8), false)


func _apply(b: float, force: bool) -> void:
	if not force and absf(b - _burn) < 0.0001 and b <= 0.0:
		return
	_burn = b
	var flames := smoothstep(0.15, 0.5, b)
	_flames.emitting = flames > 0.01
	_flames.amount_ratio = clampf(flames, 0.05, 1.0)
	_sparks.emitting = flames > 0.3
	_smoke.emitting = b > 0.05
	_embers.visible = b > 0.01
	var t := Time.get_ticks_msec() / 1000.0
	var flicker := 0.85 + 0.15 * _noise.get_noise_1d(t * 6.0) + 0.08 * _noise.get_noise_1d(t * 17.0 + 40.0)
	_ember_mat.emission_energy_multiplier = (0.6 + 2.2 * b) * flicker
	_light.visible = b > 0.01
	_light.light_energy = (0.25 + 2.1 * flames) * flicker
	_light.omni_range = 4.0 + 5.0 * flames
	var vol: float = Settings.values.get("sfx_volume", 0.8) if is_inside_tree() else 0.0
	if flames > 0.02 and vol > 0.01:
		if not _sound.playing:
			_sound.play()
		_sound.volume_db = linear_to_db(flames * vol * 0.9) - 2.0
	elif _sound.playing:
		_sound.stop()


func _build() -> void:
	var noise_tex := preload("res://assets/paint_noise.tres")
	# flames: soft teardrops rising from the logs, yellow → orange → deep red
	_flames = GPUParticles3D.new()
	_flames.amount = 34
	_flames.lifetime = 0.85
	_flames.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fm := ParticleProcessMaterial.new()
	fm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fm.emission_sphere_radius = 0.22
	fm.emission_shape_offset = Vector3(0, 0.3, 0)
	fm.direction = Vector3.UP
	fm.spread = 12.0
	fm.initial_velocity_min = 0.6
	fm.initial_velocity_max = 1.1
	fm.gravity = Vector3(0, 0.8, 0)
	fm.damping_min = 0.5
	fm.damping_max = 1.0
	fm.scale_min = 0.42
	fm.scale_max = 0.62
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.55))
	sc.add_point(Vector2(0.25, 1.0))
	sc.add_point(Vector2(1.0, 0.15))
	var sct := CurveTexture.new()
	sct.curve = sc
	fm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.55, 0.9))
	g.set_color(1, Color(0.7, 0.1, 0.04, 0.0))
	g.add_point(0.35, Color(1.0, 0.62, 0.18, 0.85))
	g.add_point(0.7, Color(0.92, 0.28, 0.06, 0.5))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	fm.color_ramp = gt
	_flames.process_material = fm
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = preload("res://shaders/flame.gdshader")
	flame_mat.set_shader_parameter("noise_tex", noise_tex)
	var fq := QuadMesh.new()
	fq.material = flame_mat
	_flames.draw_pass_1 = fq
	add_child(_flames)

	# sparks: tiny bright dots whirling up
	_sparks = GPUParticles3D.new()
	_sparks.amount = 24
	_sparks.lifetime = 2.2
	_sparks.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.2
	sm.emission_shape_offset = Vector3(0, 0.4, 0)
	sm.direction = Vector3.UP
	sm.spread = 20.0
	sm.initial_velocity_min = 1.2
	sm.initial_velocity_max = 2.4
	sm.gravity = Vector3(0, 0.2, 0)
	sm.turbulence_enabled = true
	sm.turbulence_noise_scale = 1.5
	sm.turbulence_noise_strength = 2.0
	sm.turbulence_influence_min = 0.1
	sm.turbulence_influence_max = 0.3
	sm.scale_min = 0.02
	sm.scale_max = 0.035
	var gs := Gradient.new()
	gs.set_color(0, Color(1, 0.8, 0.4, 1))
	gs.set_color(1, Color(1, 0.3, 0.1, 0))
	var gts := GradientTexture1D.new()
	gts.gradient = gs
	sm.color_ramp = gts
	_sparks.process_material = sm
	var spark_mat := ShaderMaterial.new()
	spark_mat.shader = preload("res://shaders/spore.gdshader")
	var sq := QuadMesh.new()
	sq.material = spark_mat
	_sparks.draw_pass_1 = sq
	add_child(_sparks)

	# smoke: a few grey puffs drifting up and away with the wind
	_smoke = GPUParticles3D.new()
	_smoke.amount = 12
	_smoke.lifetime = 6.0
	_smoke.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 12, 12))
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var km := ParticleProcessMaterial.new()
	km.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	km.emission_sphere_radius = 0.15
	km.emission_shape_offset = Vector3(0, 0.9, 0)
	var wind: Vector2 = ProjectSettings.get_setting("shader_globals/wind_direction")["value"]
	km.direction = (Vector3.UP * 3.0 + Vector3(wind.x, 0, wind.y)).normalized()
	km.spread = 10.0
	km.initial_velocity_min = 0.5
	km.initial_velocity_max = 0.8
	km.gravity = Vector3(wind.x, 0.1, wind.y) * 0.15
	km.scale_min = 0.5
	km.scale_max = 0.8
	var ksc := Curve.new()
	ksc.add_point(Vector2(0.0, 0.3))
	ksc.add_point(Vector2(1.0, 1.6))
	var kst := CurveTexture.new()
	kst.curve = ksc
	km.scale_curve = kst
	var gk := Gradient.new()
	gk.set_color(0, Color(0.6, 0.6, 0.62, 0.0))
	gk.set_color(1, Color(0.8, 0.8, 0.82, 0.0))
	gk.add_point(0.15, Color(0.55, 0.55, 0.58, 0.16))
	gk.add_point(0.6, Color(0.7, 0.7, 0.72, 0.08))
	var gkt := GradientTexture1D.new()
	gkt.gradient = gk
	km.color_ramp = gkt
	_smoke.process_material = km
	var smoke_q := QuadMesh.new()
	var smoke_std := StandardMaterial3D.new()
	smoke_std.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_std.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_std.vertex_color_use_as_albedo = true
	smoke_std.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_std.albedo_texture = _soft_disc()
	smoke_std.disable_receive_shadows = true
	smoke_q.material = smoke_std
	_smoke.draw_pass_1 = smoke_q
	add_child(_smoke)

	# embers: glowing lumps in the ash
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(0.25, 0.08, 0.04)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.38, 0.1)
	_embers = MeshInstance3D.new()
	var em := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.05, 0.3)
		var blob := Mesh3.blob(Vector3(0.07, 0.035, 0.06), 2.4, 4, 8)
		st.append_from(blob, 0, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, 0.03, sin(a) * r)))
	st.commit(em)
	_embers.mesh = em
	_embers.material_override = _ember_mat
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_embers)

	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.8, 0)
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 60.0
	_light.distance_fade_length = 20.0
	add_child(_light)

	_sound = AudioStreamPlayer3D.new()
	_sound.stream = Sfx.fire_loop()
	_sound.unit_size = 3.0
	_sound.max_distance = 30.0
	_sound.position = Vector3(0, 0.3, 0)
	add_child(_sound)


static var _disc: ImageTexture


static func _soft_disc() -> ImageTexture:
	if _disc == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
		_disc = ImageTexture.create_from_image(img)
	return _disc
