class_name WorldSense
extends Node
## The scout's senses: looks at the world a few times a second and tells the scout what is interesting (where
## to look) and when to react – the first drops of rain, a gust, the low sun, a shooting star, a deer at the
## edge of the woods, a bird on a post, a warm fire, leaving the water, a hard landing, a new biome …
## Only moods and reactions; nothing here changes the game.

var main: Node
var _t := 0.0
var _att_t := 0.0
var _was_rain := 0.0
var _was_water := false
var _was_biome := -1
var _lm_cache := {}
var _moment_ms := -600000


func setup(m: Node) -> void:
	main = m
	name = "WorldSense"
	main.atmosphere.shooting_star.connect(_on_shooting_star)


func _player() -> Wanderer:
	return main.player


func _scout() -> Scout:
	var p := _player()
	return p.scout if p else null


func enabled() -> bool:
	# main.mode: 1 = playing
	return Settings.values.get("scout_reactions", true) and int(main.mode) == 1 and _player() != null


func _process(delta: float) -> void:
	var sc := _scout()
	if sc == null:
		return
	if not enabled():
		sc.attention = Vector3.INF
		sc.world_state = {}
		return
	_t -= delta
	_att_t -= delta
	if _att_t <= 0.0:
		_att_t = 0.25
		_update_attention(sc)
	if _t <= 0.0:
		_t = 0.5
		_update_moods(sc)
		_check(sc)


## a reaction, with a direction in the world
func _react(kind: String, dir := Vector3.ZERO) -> void:
	var sc := _scout()
	if sc and sc.react(kind, dir):
		if main._args.has("reactlog"):
			print("[React] %.1f s  %s" % [Time.get_ticks_msec() / 1000.0, kind])
		# a rare beautiful moment gets a little musical sparkle (at most every ten minutes)
		if kind in ["shooting_star", "awe_sky", "rainbow"] and Time.get_ticks_msec() - _moment_ms > 600000:
			_moment_ms = Time.get_ticks_msec()
			main.music.stinger("moment")


func on_made_it() -> void:
	if enabled():
		_react("fist_pump")


func on_landed(fall_speed: float) -> void:
	if enabled() and fall_speed > 8.0:
		get_tree().create_timer(0.4).timeout.connect(func(): _react("dust_off"))


func _on_shooting_star(dir: Vector3) -> void:
	if enabled():
		# the scout notices it after a blink (and only when looking roughly that way doesn't matter: it's big news)
		get_tree().create_timer(0.15).timeout.connect(func(): _react("shooting_star", dir))


# ---------------------------------------------------------------- attention

func _update_attention(sc: Scout) -> void:
	var p := _player()
	var me := p.global_position
	var fwd := -sc.global_basis.z
	var best := Vector3.INF
	var best_s := 0.0
	var consider := func(pos: Vector3, interest: float, reach: float) -> void:
		var d := pos.distance_to(me)
		if d > reach or d < 0.6:
			return
		var to := (pos - me)
		to.y = 0.0
		var ahead := fwd.dot(to.normalized()) if to.length() > 0.01 else 1.0
		# things behind you are not noticed (you can't see them)
		if ahead < -0.25:
			return
		var s := interest * (1.0 - d / reach) * (0.6 + 0.4 * ahead)
		if s > best_s:
			best_s = s
			best = pos
	for d in main.deer._herd:
		consider.call((d["node"] as Node3D).global_position + Vector3(0, 0.9, 0), 3.0, 30.0)
	for b in main.songbirds._birds:
		if not b["state"] in ["fly", "leave"]:
			consider.call((b["node"] as Node3D).global_position, 2.0, 12.0)
	for it in main.butterflies._items:
		if it["pos"] != Vector3.INF:
			consider.call(it["pos"], 1.4, 4.0)
	for f in get_tree().get_nodes_in_group("campfire"):
		if (f as Campfire).is_burning():
			consider.call((f as Node3D).global_position + Vector3(0, 0.4, 0), 1.8, 9.0)
	for lp in _landmarks_near(me):
		consider.call(lp, 2.2, 32.0)
	var shown: Dictionary = main.atmosphere.shown
	# the sky: a rainbow, the aurora
	if float(shown.get("rainbow", 0.0)) > 0.35 and best_s < 1.0:
		var sd: Vector3 = shown.get("sun_dir", Vector3.DOWN)
		var away := Vector3(sd.x, 0, sd.z).normalized()
		best = me + away * 60.0 + Vector3(0, 25.0, 0)
		best_s = 1.0
	if float(main.atmosphere.current.get("aurora", 0.0)) * float(shown.get("night", 0.0)) > 0.4 and best_s < 0.8 and p.velocity.length() < 0.5:
		best = me + fwd * 30.0 + Vector3(0, 40.0, 0)
		best_s = 0.8
	sc.attention = best
	sc.attention_w = clampf(best_s * 0.9, 0.0, 0.9)


func _landmarks_near(me: Vector3) -> Array:
	var out := []
	var w: Vector3 = main.world.local_to_world(me)
	var k0 := floori(-w.z / LandmarkManager.CELL)
	for k in range(k0 - 1, k0 + 2):
		if not _lm_cache.has(k):
			_lm_cache[k] = LandmarkManager.plan(main.gen, k)
		var lm: Dictionary = _lm_cache[k]
		if lm.is_empty():
			continue
		var wp := Vector3(lm["x"], main.gen.height(lm["x"], lm["z"]) + 3.0, lm["z"])
		out.append(main.world.world_to_local(wp))
	return out


# ---------------------------------------------------------------- moods and reactions

func _update_moods(sc: Scout) -> void:
	var p := _player()
	var wf: Weather = main.atmosphere.weather
	var shown: Dictionary = main.atmosphere.shown
	var sheltered := not p.get_tree().get_nodes_in_group("shelter").filter(func(n): return (n as Node3D).global_position.distance_to(p.global_position) < 2.2).is_empty()
	var rain := 0.0 if sheltered else wf.rain * (1.0 - wf.snow_share)
	if p._wears("regenjacke") or p._wears("poncho"):
		rain *= 0.3
	# the low sun straight ahead
	var sd: Vector3 = shown.get("sun_dir", Vector3.DOWN)
	var to_sun := -sd.normalized()
	var fwd := -sc.global_basis.z
	var glare := 0.0
	if float(shown.get("night", 0.0)) < 0.3 and to_sun.y > 0.0 and to_sun.y < 0.3 and wf.clouds < 0.5:
		glare = smoothstep(0.4, 0.85, fwd.dot(Vector3(to_sun.x, 0, to_sun.z).normalized())) * (1.0 - to_sun.y / 0.3)
	sc.world_state = {"rain": clampf(rain * 1.4, 0.0, 1.0), "mud": p.mud, "glare": glare, "cold": 1.0 if p.body.feel_temp < 6.0 else 0.0}


func _check(sc: Scout) -> void:
	var p := _player()
	var wf: Weather = main.atmosphere.weather
	var shown: Dictionary = main.atmosphere.shown
	var still := Vector2(p.velocity.x, p.velocity.z).length() < 0.3
	var me := p.global_position
	var rng := randf()
	# weather
	var rain := wf.rain * (1.0 - wf.snow_share)
	if rain > 0.1 and _was_rain <= 0.1:
		_react("look_up_rain")
	elif rain > 0.6 and rng < 0.15:
		_react("cover_head")
	_was_rain = rain
	if wf.rain * wf.snow_share > 0.2 and still and rng < 0.2:
		_react("catch_snow")
	if wf.flash > 0.5:
		_react("flinch", Vector3(wf.flash_dir.x, 0.35, wf.flash_dir.y).normalized())
	if p.body.feel_temp < 5.0 and rng < 0.08:
		_react("shiver")
	elif p.body.feel_temp > 28.0 and float(shown.get("night", 0.0)) < 0.3 and rng < 0.08:
		_react("fan")
	# a gust: hold on to the hat
	if main.gusts and main.gusts.gust > 0.75 and sc._hats.size() > 0 and _wears_hat(sc) and rng < 0.5:
		_react("hold_hat")
	if float(sc.world_state.get("glare", 0.0)) > 0.6 and rng < 0.25:
		var sd: Vector3 = shown.get("sun_dir", Vector3.DOWN)
		_react("shade_eyes", -sd.normalized())
	# the sky at night
	var aur := float(main.atmosphere.current.get("aurora", 0.0)) * float(shown.get("night", 0.0)) * (1.0 - wf.clouds)
	if (aur > 0.4 or float(shown.get("stars", 0.0)) > 0.8 and wf.clouds < 0.3) and still and rng < (0.3 if aur > 0.4 else 0.04):
		_react("awe_sky")
	if float(shown.get("rainbow", 0.0)) > 0.45 and rain < 0.05:
		var sd2: Vector3 = shown.get("sun_dir", Vector3.DOWN)
		_react("rainbow", (Vector3(sd2.x, 0, sd2.z).normalized() + Vector3(0, 0.5, 0)).normalized())
	# animals
	if main.butterflies._someone_on_you():
		_react("butterfly")
	for d in main.deer._herd:
		var dp: Vector3 = (d["node"] as Node3D).global_position
		if dp.distance_to(me) < 16.0:
			var dir := (dp - me).normalized()
			if p.crouching:
				_react("shh", dir)
			elif still:
				_react("freeze", dir)
			break
	for b in main.songbirds._birds:
		if not b["state"] in ["fly", "leave"]:
			var bp: Vector3 = (b["node"] as Node3D).global_position
			if bp.distance_to(me) < 6.0 and rng < 0.35:
				_react("whistle_back", (bp - me).normalized())
				break
	# a warm fire
	for f in get_tree().get_nodes_in_group("campfire"):
		var fp := (f as Node3D).global_position
		if (f as Campfire).is_burning() and fp.distance_to(me) < 3.6 and (still or p.resting):
			_react("warm_hands", (fp - me).normalized())
	# water, mud, the body
	var in_water := p.in_water or p.swimming
	if _was_water and not in_water and p.is_on_floor():
		get_tree().create_timer(0.5).timeout.connect(func(): _react("shake_dry"))
	_was_water = in_water
	if p.mud > 0.5 and rng < 0.2:
		_react("yuck")
	if p.body.food < 22.0 and rng < 0.05:
		_react("tummy")
	elif p.body.water < 22.0 and rng < 0.05:
		_react("lick_lips")
	elif p.body.wet > 0.75 and rain < 0.05 and still and rng < 0.1:
		_react("wring")
	# dark woods without a light
	if float(shown.get("night", 0.0)) > 0.7 and p._light == null and float(main.atmosphere.current.get("shafts", 0.0)) > 0.5 and rng < 0.06:
		_react("nervous")
	# a landmark close by
	for lp in _landmarks_near(me):
		if lp.distance_to(me) < 20.0 and rng < 0.3:
			_react("look_up_big", (lp + Vector3(0, 6, 0) - me).normalized())
			break
	# a new biome: look around in wonder
	var b := int(main.atmosphere.dominant)
	if b != _was_biome:
		if _was_biome >= 0:
			get_tree().create_timer(1.5).timeout.connect(func(): _react("wonder"))
		_was_biome = b


func _wears_hat(sc: Scout) -> bool:
	return int(sc.wear.get("hat", sc.look.get("hat", 0))) != 0
