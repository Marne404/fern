class_name Atmosphere
extends Node
## Sky, sun, fog and color mood – softly blended between biomes.

var gen: WorldGen
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var current := {}
var mountains: Mountains
var world_env: WorldEnvironment
## 0..1 – camera underwater: short, turquoise view
var underwater := 0.0:
	set(v):
		if absf(v - underwater) > 0.001:
			underwater = v
			_apply_underwater()
var dominant := 0
var dust := 0.0
## times of day
var day := DayCycle.new()
var weather := Weather.new()
## the atmosphere as shown: biome blend bent to the time of day (current stays the pure biome blend)
var shown := {}
## ground height of the valley near the camera (for the valley mist)
var valley_y := 0.0

var _timer := 0.0
var _last_z := INF


## Distance at which the haze reaches full strength
var fog_end := 1100.0
var _dof: CameraAttributesPractical
var _rest_k := 0.0

func setup(p_gen: WorldGen, parent: Node) -> void:
	gen = p_gen
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_noise", preload("res://assets/cloud_noise.tres"))
	sky_mat.set_shader_parameter("cloud_cells", preload("res://assets/cloud_cells.tres"))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_intensity = 0.25
	env.glow_strength = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.9
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	# aerial perspective like in Genshin: near is clear, the distance turns bright and sky blue
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 70.0
	env.fog_depth_end = fog_end
	env.fog_depth_curve = 1.25   # middle clear, only the distance turns blue (Genshin aerial perspective)
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.65
	env.volumetric_fog_albedo = Color(1.0, 0.97, 0.9)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_detail_spread = 1.5
	env.volumetric_fog_ambient_inject = 0.2
	env.volumetric_fog_sky_affect = 0.0
	env.adjustment_enabled = true
	world_env = WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.5
	sun.light_volumetric_fog_energy = 0.7
	parent.add_child(sun)
	apply_quality()
	_read_day_settings()
	Settings.changed.connect(func(k):
		apply_quality()
		if k in ["time_of_day", "day_minutes", "weather"]:
			_read_day_settings()
			_last_z = INF)


func apply_quality() -> void:
	# with large view distances the aerial-perspective haze moves further out
	fog_end = maxf(1100.0, float(Settings.values["view_distance"]) * 64.0 * 1.15)
	env.fog_depth_end = fog_end
	if mountains:
		mountains.set_view(float(Settings.values["view_distance"]) * 64.0)
	var sp := Settings.shadow_params()
	sun.shadow_enabled = sp["enabled"]
	sun.directional_shadow_max_distance = sp["distance"]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sp["splits"] == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = 0.08 if sp["splits"] == 4 else 0.25
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	env.ssao_enabled = Settings.values["ssao"]
	env.glow_enabled = Settings.values["glow"]
	var ultra: bool = Settings.values["ssil"]
	env.ssil_enabled = ultra
	env.ssil_radius = 6.0
	env.ssil_intensity = 1.2
	env.ssil_sharpness = 0.9
	sky_mat.set_shader_parameter("cloud_detail", 1.0 if ultra else 0.0)
	sun.light_angular_distance = 1.2 if Settings.values["shadows"] >= 4 else 0.5
	# depth of field: distant scenery soft like a painting
	var attrs := CameraAttributesPractical.new()
	_dof = attrs
	attrs.dof_blur_far_enabled = Settings.values["dof"]
	attrs.dof_blur_far_distance = 220.0
	attrs.dof_blur_far_transition = 400.0
	attrs.dof_blur_amount = 0.035
	world_env.camera_attributes = attrs
	_last_z = INF


## world_z: view point in world coordinates
func update(world_z: float, delta: float, force := false) -> void:
	_timer -= delta
	if not force and _timer > 0.0 and absf(world_z - _last_z) < 2.0:
		return
	_timer = 0.25
	_last_z = world_z
	var bb := gen.biome_blend(world_z)
	var a: Dictionary = gen.biomes[int(bb.x)]["atmosphere"]
	var b: Dictionary = gen.biomes[int(bb.y)]["atmosphere"]
	var t := bb.z
	dominant = int(bb.y) if t >= 0.5 else int(bb.x)
	current = {}
	for k in a:
		var va = a[k]
		var vb = b[k]
		if va is float or va is int:
			current[k] = lerpf(va, vb, t)
		elif va is Color:
			current[k] = (va as Color).lerp(vb, t)
		elif va is Vector3:
			current[k] = (va as Vector3).normalized().slerp((vb as Vector3).normalized(), t)
		elif va is Dictionary:
			# per-biome effects {name: strength}: fade out on one side, in on the other
			var fx := {}
			for n in va:
				fx[n] = float(va[n]) * (1.0 - t)
			for n in vb:
				fx[n] = float(fx.get(n, 0.0)) + float(vb[n]) * t
			current[k] = fx
		else:
			current[k] = va if t < 0.5 else vb
	_apply()


## test helper (--skyset=key:value,…): sky shader parameters forced after every update
var debug_sky := {}


## Sky forms by time of day: towering clouds grow in the afternoon, pastel strata glow at dawn and in the
## golden hour, the mackerel sky is best when the sun is low; overcast hides them, the aurora needs the night.
func _apply_sky_forms(c: Dictionary) -> void:
	var h := day.hour
	var night := float(c.get("night", 0.0))
	var clear := 1.0 - clampf(float(c.get("overcast", 0.0)) * 1.4, 0.0, 1.0)
	var afternoon := smoothstep(11.0, 14.0, h) * (1.0 - smoothstep(18.4, 19.8, h)) + 0.3 * smoothstep(8.5, 10.5, h) * (1.0 - smoothstep(11.0, 12.5, h))
	var golden := maxf(smoothstep(16.6, 18.2, h) * (1.0 - smoothstep(20.3, 21.2, h)), smoothstep(4.5, 5.4, h) * (1.0 - smoothstep(7.4, 8.6, h)))
	var low_sun := maxf(golden, 1.0 - smoothstep(8.0, 10.5, h) + smoothstep(15.5, 18.0, h))
	sky_mat.set_shader_parameter("sky_towers", float(c.get("sky_towers", 0.0)) * afternoon * (1.0 - night) * clear)
	sky_mat.set_shader_parameter("sky_bands", float(c.get("sky_bands", 0.0)) * (0.2 + 0.8 * golden) * (1.0 - night * 0.7) * clear)
	sky_mat.set_shader_parameter("sky_mackerel", float(c.get("sky_mackerel", 0.0)) * (0.55 + 0.45 * clampf(low_sun, 0.0, 1.0)) * (1.0 - night * 0.8) * clear)
	sky_mat.set_shader_parameter("aurora", float(c.get("aurora", 0.0)) * clear)
	sky_mat.set_shader_parameter("shooting_stars", float(c.get("shooting_stars", 1.0)) * clear)
	for k in debug_sky:
		sky_mat.set_shader_parameter(k, debug_sky[k])


func _read_day_settings() -> void:
	day.fixed = int(Settings.values.get("time_of_day", 0))
	weather.mode = int(Settings.values.get("weather", 0))
	day.day_minutes = float(Settings.values.get("day_minutes", 36.0))
	day.advance(0.0)


## Sandstorm haze (0..1), comes from the desert effects
func set_dust(v: float) -> void:
	if absf(v - dust) < 0.005:
		return
	dust = v
	_apply_fog()


func _apply_fog() -> void:
	if shown.is_empty():
		return
	var c := shown
	# haze has the horizon's color: distant hills turn blue, not gray
	env.fog_light_color = (c["fog_color"] as Color).lerp(c["horizon_color"], 0.5).lerp(Color(0.62, 0.78, 0.98), 0.25)
	# map the biome density (0.001–0.009) onto the depth fog
	env.fog_density = clampf(0.5 + c["fog_density"] * 40.0, 0.5, 0.85)
	if dust > 0.0:
		# sand gust: warm, dense haze, the distance blurs
		env.fog_light_color = env.fog_light_color.lerp(Color(0.93, 0.78, 0.55), dust * 0.6)
		env.fog_density = minf(env.fog_density + dust * 0.25, 1.0)
	env.fog_depth_begin = lerpf(70.0, 10.0, dust)
	env.fog_depth_end = lerpf(fog_end, 260.0, dust)
	# (the morning valley mist is its own full-screen pass, see mist.gdshader)
	if underwater > 0.001:
		_apply_underwater()


func _apply_underwater() -> void:
	if shown.is_empty():
		return
	var u := underwater
	env.fog_light_color = (shown["fog_color"] as Color).lerp(Color(0.1, 0.42, 0.5), u)
	env.fog_depth_begin = lerpf(70.0, 0.0, u)
	env.fog_depth_end = lerpf(fog_end, 22.0, u)
	env.fog_depth_curve = lerpf(1.25, 0.6, u)
	env.fog_density = lerpf(clampf(0.5 + shown["fog_density"] * 40.0, 0.5, 0.85), 1.0, u)


func _apply() -> void:
	shown = weather.apply(day.apply(current))
	var c := shown
	sun.basis = Basis.looking_at(c["sun_dir"], Vector3.UP)
	sun.light_color = c["sun_color"]
	sun.light_energy = c["sun_energy"]
	for k in ["zenith_color", "horizon_color", "cloud_coverage", "cirrus_amount", "cloud_shadow", "rainbow", "sun_glow",
			"cloud_color", "stars", "moon"]:
		sky_mat.set_shader_parameter(k, c[k])
	_apply_sky_forms(c)
	# water and waterfalls brighten themselves a little (anime look): not in the dark
	RenderingServer.global_shader_parameter_set("daylight", 1.0 - float(c["night"]) * 0.75)
	RenderingServer.global_shader_parameter_set("sun_vector", -(c["sun_dir"] as Vector3).normalized())
	RenderingServer.global_shader_parameter_set("sun_light", c["sun_color"])
	RenderingServer.global_shader_parameter_set("wetness", float(c.get("wet", 0.0)))
	RenderingServer.global_shader_parameter_set("rain_amount", float(c.get("rain", 0.0)))
	env.ambient_light_energy = c["ambient_energy"]
	env.ambient_light_color = c["ambient_color"]
	_apply_fog()
	# backlight may glow, but not wash the image out white
	env.fog_sun_scatter = minf(c["fog_sun_scatter"], 0.35) * 0.5
	env.tonemap_exposure = c["exposure"]
	env.adjustment_saturation = c["saturation"]
	if mountains:
		mountains.apply(c, -(c["sun_dir"] as Vector3).normalized())
	var vol: float = c["volumetric"]
	# Ultra: a touch of haze everywhere so sun shafts fall through every canopy
	if Settings.values["ssil"]:
		vol = maxf(vol, 0.0015)
	env.volumetric_fog_enabled = Settings.values["volumetric"] and vol > 0.0005
	env.volumetric_fog_density = minf(vol, 0.007)


## Resting: the distance melts softly (and comes back when you walk on). Works on every preset
## (setting "rest_blur"); on Ultra it deepens the always-on distance blur.
func set_resting(on: bool, delta: float) -> void:
	if _dof == null:
		return
	var want := 1.0 if (on and Settings.values.get("rest_blur", true)) else 0.0
	_rest_k = move_toward(_rest_k, want, delta * (0.45 if want > _rest_k else 0.9))
	var always: bool = Settings.values["dof"]
	_dof.dof_blur_far_enabled = always or _rest_k > 0.01
	var k := smoothstep(0.0, 1.0, _rest_k)
	_dof.dof_blur_far_distance = lerpf(220.0, 24.0, k)
	_dof.dof_blur_far_transition = lerpf(400.0, 60.0, k)
	_dof.dof_blur_amount = lerpf(0.035 if always else 0.0, 0.06, k)
