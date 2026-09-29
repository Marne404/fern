extends Node3D
## Game flow: main menu with camera flight, hiking, pause.
## Connects world streaming, atmosphere, effects, player and UI.
##
## Command line (after "--"): --play  --z=-5000 (start point)  --autowalk  --shot=image.png --wait=300
##     --size=1920x1080  --ui  --fps  --seed=1

enum Mode { MENU, PLAYING, PAUSED }

const RECORD_PATH := "user://records.cfg"

var mode := Mode.MENU
var gen: WorldGen
var lib := AssetLibrary.new()
var world: ChunkManager
var atmosphere: Atmosphere
var menu_cam: MenuCamera
var menu_scout: Scout
var player: Wanderer
var hud: Hud
var backpack: Backpack
var pois: PoiManager
var forage: ForageManager
var cairns: Cairns
var landmarks: LandmarkManager
var dropped: Node3D
var footprints: Footprints
var menus: Menus
var streaks: WindStreaks
var butterflies: Butterflies
var particles: AmbientParticles
var biome_fx: BiomeFx
## fireflies at dusk and night in every biome
var night_flies: AmbientParticles
var rain_fx: RainFx
var canopy_shafts: CanopyShafts
var songbirds: Songbirds
var deer: Deer
var _soaked_hint := false
var _cloud_drift := 0.0
var _brook_sound: AudioStreamPlayer3D
var gusts: WindGusts
var leaf_fall: LeafFall
var desert_fx: DesertFx
var mountains: Mountains
var birds: Birds
var shafts: MeshInstance3D
## valley mist in the mornings (full-screen pass)
var mist: MeshInstance3D
var _mist_mat: ShaderMaterial
var outlines: MeshInstance3D
var film: ColorRect
var underwater_fx: ColorRect
var _underwater := 0.0
var grass: GrassField
var sea: Sea
var obstacles: ObstacleManager
var music: MusicDirector
var _passed_obstacles := {}
var knot_game: KnotGame
var emote_wheel: EmoteWheel
var _knot_cb: Callable
var _shaft_mat: ShaderMaterial
var _sea_open := 0.0

var start_z := 0.0
var best_distance := 0.0
var journey_distance := 0.0
var _last_biome := -1
var _args := {}
var _frame := 0
var _spawn_pending := false
var _shot_vp: SubViewport
var _shot_cam: Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	best_distance = _load_record()
	# test helper: --preset=High  --set=veg_density:0.5,sun_shafts:false
	if _args.has("preset") or _args.has("set"):
		Settings.persist = false
	if _args.has("preset"):
		Settings.apply_preset(_args["preset"])
	if _args.has("set"):
		for pair in _args["set"].split(","):
			var kv2: PackedStringArray = pair.split(":")
			Settings.set_value(kv2[0], str_to_var(kv2[1]))
	if _args.has("timescale"):
		Engine.time_scale = float(_args["timescale"])
	var seed_v: int = Settings.values["last_seed"]
	if Settings.next_seed >= 0:
		seed_v = Settings.next_seed
		Settings.next_seed = -1
	if _args.has("seed"):
		seed_v = Settings.parse_seed(_args["seed"])
	gen = WorldGen.new(seed_v)
	if _args.has("profile"):
		for i in 30:
			var pz := -i * 100.0
			print("Profile z=%6.0f  x=%7.1f  height %6.1f  %s" % [pz, gen.path_x(pz), gen.path_elevation(pz), gen.biomes[gen.dominant_biome(pz)]["name"]])
	if _args.has("pathinfo"):
		var zz := float(_args["pathinfo"])
		print("Path at z=%.0f: x=%.2f, height %.2f, water %s, obstacles %s" % [zz, gen.path_x(zz), gen.height(gen.path_x(zz), zz), gen.water_level(gen.path_x(zz), zz), gen.obstacles_near(zz).map(func(o): return [o["type"], o["z"]])])
	if _args.has("pondinfo"):
		var pi_k := int(_args["pondinfo"])
		print("Pond data: ", gen.pond(pi_k))
	if _args.has("ponds"):
		for k in range(1, 60):
			var pd := gen.pond(k)
			if pd.z > 0.0:
				print("Pond z=%.0f x=%.0f r=%.0f path_x=%.0f biome=%s" % [pd.y, pd.x, pd.z, gen.path_x(pd.y), gen.biomes[gen.dominant_biome(pd.y)]["name"]])
	if _args.has("brooks"):
		for k in 40:
			var b := gen.brook(k)
			if not b.is_empty():
				print("Brook %d: z %.0f → %.0f side %d (%s)" % [k, b["z0"], b["z1"], int(b["side"]), gen.biomes[gen.dominant_biome(b["z0"])]["name"]])
		get_tree().quit()
		return
	if _args.has("obstacles"):
		for k in 30:
			var ob := gen.obstacle(k)
			if not ob.is_empty():
				print("Obstacle %d: %s at z=%.0f (%s)" % [k, ob["type"], ob["z"], gen.biomes[gen.dominant_biome(ob["z"])]["name"]])
		get_tree().quit()
		return
	if _args.has("patchinfo"):
		# test helper: --patchinfo=z0,z1 prints the patch left/right of the path every 40 m
		var pr: PackedFloat64Array = _args["patchinfo"].split_floats(",")
		var zz := pr[0]
		while zz > pr[1]:
			var bi := gen.dominant_biome(zz)
			var names: Array = gen.biomes[bi].get("patches", [{"name": "-"}]).map(func(p): return p["name"])
			var px := gen.path_x(zz)
			print("z=%6.0f %-16s L %-14s R %s" % [zz, gen.biomes[bi]["name"], names[gen.patch_at(px - 30.0, zz, bi)], names[gen.patch_at(px + 30.0, zz, bi)]])
			zz -= 40.0
		get_tree().quit()
		return
	if _args.has("lightfires"):
		Campfire.debug_lit = true
	if _args.has("forage"):
		# test helper: --forage lists the first things to gather along the trail
		var nf := 0
		for cz in range(-1, -900, -1):
			var r0 := gen.row((cz + 0.5) * ForageManager.CELL)
			for cx in range(floori((float(r0["px"]) - 20.0) / ForageManager.CELL), floori((float(r0["px"]) + 20.0) / ForageManager.CELL) + 1):
				var fp := ForageManager.plan(gen, cx, cz)
				if not fp.is_empty():
					nf += 1
					if nf <= 10 or (fp["type"] == "kiesel" and nf < 400):
						print("Forage %s v%d z=%.0f x=%.0f (%s)" % [fp["type"], fp["variant"], fp["z"], fp["x"], gen.biomes[gen.dominant_biome(fp["z"])]["name"]])
		print("Forage spots in 43 km: %d" % nf)
		for ck in range(1, 30):
			var cp := Cairns.plan(gen, ck)
			if not cp.is_empty():
				print("Cairn %s z=%.0f x=%.0f stones %d" % [cp["key"], cp["z"], cp["x"], cp["stones"]])
	if _args.has("findspots"):
		# test helper: --findspots=type lists the first find spots of that type
		var n_found := 0
		for k in range(0, 600):
			var fp := PoiManager.plan(gen, k)
			if not fp.is_empty() and fp["type"] == _args["findspots"]:
				n_found += 1
				if n_found <= 8:
					print("Find spot %s k=%d z=%.0f x=%.0f (%s)" % [fp["type"], k, fp["z"], fp["x"], gen.biomes[gen.dominant_biome(fp["z"])]["name"]])
		print("Find spots of that type in 100 km: %d" % n_found)
	if _args.has("biomes"):
		for k in 30:
			print("Segment %d: %s from %.0f m" % [k, gen.biomes[gen._segment_biome[k]]["name"], gen._segment_start[k]])
	start_z = float(_args.get("z", "0"))

	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(gen, self)

	world = ChunkManager.new()
	world.name = "World"
	add_child(world)
	world.setup(gen, lib)
	world.origin_shifted.connect(_on_origin_shifted)
	RenderingServer.global_shader_parameter_set("world_origin", Vector2.ZERO)

	pois = PoiManager.new()
	add_child(pois)
	pois.setup(gen, world, lib)
	forage = ForageManager.new()
	add_child(forage)
	forage.setup(gen, world, lib)
	cairns = Cairns.new()
	add_child(cairns)
	cairns.setup(gen, world)
	landmarks = LandmarkManager.new()
	add_child(landmarks)
	landmarks.setup(gen, world, lib)
	if _args.has("landmarks"):
		for k in range(1, 40):
			var lp := LandmarkManager.plan(gen, k)
			if not lp.is_empty():
				print("Landmark %d: %s at z=%.0f x=%.0f (path x=%.0f)" % [k, lp["type"], lp["z"], lp["x"], gen.path_x(lp["z"])])
	if _args.has("pois"):
		for k in 20:
			var pp := pois.poi(k)
			if not pp.is_empty():
				print("Find %d: %s at z=%.0f x=%.0f (path x=%.0f) %s" % [k, pp["type"], pp["z"], pp["x"], gen.path_x(pp["z"]), pp["items"]])
	music = MusicDirector.new()
	add_child(music)
	if _args.has("music"):
		music.track_started.connect(func(t, m): print("[Music] %6.0f m  %-26s %s" % [journey_distance, t, m]))
	obstacles = ObstacleManager.new()
	obstacles.name = "Obstacles"
	add_child(obstacles)
	obstacles.setup(gen, world, lib)
	obstacles.on_message = func(t: String): hud.show_message(t)
	obstacles.on_knot = _open_knot
	obstacles.on_spawn_item = _spawn_dropped
	dropped = Node3D.new()
	dropped.name = "Dropped"
	add_child(dropped)
	footprints = Footprints.new()
	add_child(footprints)

	menu_cam = MenuCamera.new()
	menu_cam.world = world
	menu_cam.fov = 62.0
	menu_cam.far = 4000.0
	add_child(menu_cam)
	menu_cam.start_z = start_z + 30.0
	# the title screen shows the golden hour (the clock only runs while hiking)
	atmosphere.day.hour = 17.2
	menu_scout = Scout.new(Settings.values.get("scout", {}))
	menu_scout.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(menu_scout)
	menu_cam.scout = menu_scout
	menu_cam.start()
	menu_cam.make_current()

	streaks = WindStreaks.new()
	streaks.world = world
	butterflies = Butterflies.new()
	butterflies.world = world
	particles = AmbientParticles.new()
	night_flies = AmbientParticles.new()
	add_child(night_flies)
	biome_fx = BiomeFx.new()
	biome_fx.world = world
	add_child(biome_fx)
	rain_fx = RainFx.new()
	rain_fx.world = world
	add_child(rain_fx)
	canopy_shafts = CanopyShafts.new()
	canopy_shafts.world = world
	add_child(canopy_shafts)
	songbirds = Songbirds.new()
	songbirds.world = world
	add_child(songbirds)
	deer = Deer.new()
	deer.world = world
	add_child(deer)
	birds = Birds.new()
	birds.world = world
	mountains = Mountains.new()
	add_child(mountains)
	atmosphere.mountains = mountains
	atmosphere.apply_quality()
	_setup_shafts()
	_setup_post()
	sea = Sea.new()
	sea.world = world
	add_child(sea)
	grass = GrassField.new()
	add_child(grass)
	grass.setup(gen, world)
	gusts = WindGusts.new()
	leaf_fall = LeafFall.new()
	leaf_fall.world = world
	leaf_fall.gusts = gusts
	desert_fx = DesertFx.new()
	desert_fx.world = world
	desert_fx.gusts = gusts
	if _args.has("gust"):
		gusts.force = float(_args["gust"])
	if _args.has("devil"):
		desert_fx.devil_timer = 0.0
		desert_fx.devil_ahead = true
	for n in [streaks, butterflies, particles, birds, menu_cam, gusts, leaf_fall, desert_fx]:
		n.process_mode = Node.PROCESS_MODE_PAUSABLE
		if n != menu_cam:
			add_child(n)

	hud = Hud.new()
	add_child(hud)
	hud.set_playing(false)
	backpack = Backpack.new()
	add_child(backpack)
	backpack.on_knot = _open_knot
	knot_game = KnotGame.new()
	add_child(knot_game)
	knot_game.finished.connect(_on_knot_done)
	emote_wheel = EmoteWheel.new()
	add_child(emote_wheel)
	emote_wheel.chosen.connect(func(id: String):
		if player:
			player.play_emote(id))
	menus = Menus.new()
	add_child(menus)
	menus.start_pressed.connect(_on_start_pressed)
	menus.resume_pressed.connect(resume)
	menus.main_menu_pressed.connect(end_journey)
	menus.scout_editor.connect(func(open: bool):
		menu_cam.portrait = open
		menu_cam.drag_yaw = 0.0
		if open:
			menu_scout.wave(2.4))
	menus.scout_changed.connect(func():
		menu_scout.set_look_data(Settings.values["scout"])
		menu_scout.apply_look()
		if randf() < 0.5:
			menu_scout.wave(1.4)
		else:
			menu_scout.fidget())
	menus.scout_dragged.connect(func(dx: float): menu_cam.drag_yaw += dx * 0.01)

	if _args.has("shot") and not _args.has("ui") or _args.has("size"):
		_setup_offscreen()
	_update_focus()
	atmosphere.update(start_z, 0.0, true)
	menus.set_seed_text(str(gen.seed_value))
	if _args.has("play") or _args.has("selftest") or _args.has("obtest") or Settings.autostart:
		Settings.autostart = false
		start_journey()
	else:
		menus.show_main(best_distance / 1000.0)
		music.set_menu()
		if _args.has("settings"):
			menus._open_settings(menus._main)
			if _args["settings"] != "1":
				menus.scroll_settings_to.call_deferred(_args["settings"])
		if _args.has("fakevoice"):
			Voice.fake_db = float(_args["fakevoice"])
		if _args.has("scout"):
			menus._open_scout()
	if _args.has("obtest"):
		var ot: Node = preload("res://scripts/tests/obstacle_test.gd").new()
		ot.main = self
		add_child(ot)
		ot.run()
	if _args.has("voicetest"):
		var vt: Node = preload("res://scripts/tests/voice_test.gd").new()
		vt.main = self
		add_child(vt)
		vt.run(_args["voicetest"])
	if _args.has("selftest"):
		var t: Node = preload("res://scripts/tests/selftest.gd").new()
		t.main = self
		add_child(t)
		t.run()


# ================================================================ Flow

func start_journey() -> void:
	if mode != Mode.MENU or player != null:
		return
	if _args.has("startseed"):
		print("[Seed] Journey started in world %d, first biome %s" % [gen.seed_value, gen.biomes[gen.dominant_biome(start_z)]["name"]])
	menus.hide_all()
	player = Wanderer.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	var px := gen.path_x(start_z) + float(_args.get("dx", "0"))
	if _args.has("abs_x"):
		px = float(_args["abs_x"])
	var pos := world.world_to_local(Vector3(px, gen.height(px, start_z) + 0.3, start_z))
	player.global_position = pos
	var ahead := world.world_to_local(gen.path_point(start_z - 6.0))
	player.look_along((ahead - pos) * Vector3(1, 0, 1))
	player.camera.make_current()
	if _args.has("obtest") or _args.has("selftest"):
		player.set_third_person(false)
	elif _args.has("third"):
		player.set_third_person(true)
	player.world = world
	player.footprints = footprints
	player.obstacles = obstacles
	player.spawn_item = _spawn_dropped
	player.collapsed.connect(func():
		hud.collapse_fade(true)
		music.stinger("kollaps"))
	player.recovered.connect(func(): hud.collapse_fade(false))
	player.message.connect(hud.show_message)
	player.use_stone.connect(func(it: Dictionary): cairns.use_stone(player, it))
	player.sleep_fade.connect(func(on):
		hud.collapse_fade(on, "Zzz …")
		# sleeping through the night: you wake up in the morning (the clock jumps while the screen is dark)
		if on:
			get_tree().create_timer(1.3).timeout.connect(func():
				atmosphere.day.sleep()
				atmosphere.update(world.local_to_world(player.global_position).z, 0.0, true)))
	hud.set_player(player)
	if _args.has("autowalk"):
		player.autopilot = _autopilot
	# only start walking once the ground under the feet is loaded
	player.set_physics_process(false)
	_spawn_pending = true
	journey_distance = 0.0
	_last_biome = -1
	music.start_biome(gen.dominant_biome(start_z))
	mode = Mode.PLAYING
	# a journey begins in the morning (test helper: --hour=19.5)
	atmosphere.day.hour = float(_args.get("hour", "7.0"))
	atmosphere.day.advance(0.0)
	atmosphere.weather.reset()
	# test helpers: --rain (a shower right now), --afterrain (wet, clearing, rainbow)
	if _args.has("rain"):
		atmosphere.weather.state = Weather.RAIN
		atmosphere.weather.clouds = 1.0
		atmosphere.weather.rain = float(_args["rain"]) if _args["rain"] != "1" else 1.0
		atmosphere.weather.wet = 1.0
		atmosphere.weather.next_shower = 0.0
		atmosphere.weather.set("_strength", atmosphere.weather.rain)
		atmosphere.weather.set("_dur", 9999.0)
	elif _args.has("afterrain"):
		atmosphere.weather.state = Weather.AFTER
		atmosphere.weather.set("_t", 25.0)
		atmosphere.weather.clouds = 0.2
		atmosphere.weather.wet = 1.0
		atmosphere.weather.rainbow = 1.0
	atmosphere.update(start_z, 0.0, true)
	hud.set_playing(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Different seed than the loaded world? Then reload the scene with the new world and start right away.
func _on_start_pressed() -> void:
	var s := menus.seed_value()
	if s != gen.seed_value:
		Settings.next_seed = s
		Settings.autostart = true
		Settings.set_value("last_seed", s, false)
		get_tree().reload_current_scene.call_deferred()
		return
	Settings.set_value("last_seed", s, false)
	start_journey()


func end_journey() -> void:
	_save_record()
	get_tree().paused = false
	if backpack.is_open():
		backpack.close()
	if player:
		player.queue_free()
		player = null
	for c in dropped.get_children():
		c.queue_free()
	mode = Mode.MENU
	hud.set_playing(false)
	menu_cam.start()
	menu_cam.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.show_main(best_distance / 1000.0)
	music.set_menu()


func pause() -> void:
	mode = Mode.PAUSED
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menus.show_pause(gen.seed_value)


func resume() -> void:
	mode = Mode.PLAYING
	get_tree().paused = false
	menus.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# emote wheel: hold G
	if event is InputEventKey and event.physical_keycode == KEY_G and not event.echo:
		if event.pressed and mode == Mode.PLAYING and player and player.can_act() and not menus.is_open() and not backpack.is_open() and not knot_game.is_open():
			emote_wheel.open()
		elif not event.pressed:
			emote_wheel.close(true)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				if mode == Mode.PLAYING and player and not menus.is_open() and not knot_game.is_open():
					if backpack.is_open():
						backpack.close()
					elif player.can_act():
						backpack.open(player)
			KEY_ESCAPE:
				if backpack.is_open():
					backpack.close()
				elif menus.is_open():
					menus.back()
				elif mode == Mode.PLAYING:
					pause()
			KEY_F12:
				var path := "user://screenshot_%d.png" % Time.get_unix_time_from_system()
				get_viewport().get_texture().get_image().save_png(path)
				print("Screenshot: ", ProjectSettings.globalize_path(path))
	if event is InputEventMouseButton and event.pressed and mode == Mode.PLAYING and not menus.is_open() and not backpack.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


var _script_ms := 0.0
var _stuck_time := 0.0
var _max_frame_ms := 0.0
var _spikes := 0


func _process(delta: float) -> void:
	var t_script := Time.get_ticks_usec()
	_process_inner(delta)
	_script_ms = lerpf(_script_ms, (Time.get_ticks_usec() - t_script) / 1000.0, 0.1)


func _process_inner(delta: float) -> void:
	_frame += 1
	if _args.has("startseed") and _frame == 90 and mode == Mode.MENU:
		print("[Seed] Menu world %d, starting with input '%s'" % [gen.seed_value, _args["startseed"]])
		menus.set_seed_text(_args["startseed"])
		_on_start_pressed()
	if _frame > 120:
		var real_ms := delta / Engine.time_scale * 1000.0
		_max_frame_ms = maxf(_max_frame_ms, real_ms)
		if real_ms > 50.0:
			_spikes += 1
			if _args.has("fps"):
				print("  [Hitch] %.0f ms at frame %d, chunks +%d, music %s" % [real_ms, _frame, world.pending_count(), music.now_playing()])
	var cam := _active_camera()
	_update_focus()
	# test helper: --emote=id plays (again and again) once the player stands on the ground
	if _args.has("emote") and player and player.is_physics_processing() and player.is_on_floor() and player.scout.emote_playing() == "" and not player.resting:
		player.play_emote(_args["emote"])

	if _spawn_pending and world.is_ready_around(Vector2(world.focus.x, world.focus.y)):
		_spawn_pending = false
		var p := player.global_position
		p.y = world.ground_y(p.x, p.z) + 0.2
		player.global_position = p
		player.set_physics_process(true)
		# test helpers: --body=stamina:30,food:10,warm_bonus_t:60  --give=kaese,seil
		if _args.has("body"):
			for pair in _args["body"].split(","):
				var kv: PackedStringArray = pair.split(":")
				player.body.set(kv[0], float(kv[1]))
		if _args.has("give"):
			for id in _args["give"].split(","):
				player.inventory.add(ItemDefs.make(id))
		if _args.has("drop"):
			var fwd := -player.global_transform.basis.z
			_spawn_dropped(ItemDefs.make(_args["drop"]), player.global_position + fwd * 1.6 + Vector3(0, 0.4, 0), Vector3.ZERO)
		if _args.has("wheel"):
			emote_wheel.open()
			emote_wheel._aim = Vector2(80, -60)
			emote_wheel._sel = 1
		if _args.has("pitch"):
			player.set_look(player.rotation.y + deg_to_rad(float(_args.get("yaw", "0"))), deg_to_rad(float(_args["pitch"])))
		if _args.has("deer"):
			# test helper: a deer (and fawn) right ahead
			var fw := -player.global_basis.z
			var dp := player.global_position + Vector3(fw.x, 0, fw.z).normalized() * float(_args["deer"] if _args["deer"] != "1" else "12")
			deer.camera = _active_camera()
			deer._add_deer(dp, 1.0, false)
			deer._add_deer(dp + Vector3(1.6, 0, 1.0), 0.62, true)
			deer.hold = _args.get("deerhold", "")
		if _args.has("lineup"):
			_lineup(_args["lineup"].split(","))
		if _args.has("backpack"):
			backpack.open.call_deferred(player)
		if _args.has("knotui"):
			_open_knot(false, func(_q): pass)
			knot_game._choose.call_deferred(1)
		if _args.has("fly"):
			# test helper: raised, fixed camera
			player.set_physics_process(false)
			player.global_position.y += float(_args["fly"])
			if _args.has("abs_y"):
				player.global_position.y = world.world_to_local(Vector3(0, float(_args["abs_y"]), 0)).y
			var yaw := player.rotation.y
			if _args.has("lookSun"):
				atmosphere.update(world.local_to_world(player.global_position).z, 0.0, true)
				var to_sun := atmosphere.sun.global_basis.z
				yaw = atan2(-to_sun.x, -to_sun.z)
			if _args.has("lookAntiSun"):
				atmosphere.update(world.local_to_world(player.global_position).z, 0.0, true)
				var from_sun := atmosphere.sun.global_basis.z
				yaw = atan2(from_sun.x, from_sun.z)
			if _args.has("lookrel"):
				var lr: PackedFloat64Array = _args["lookrel"].split_floats(",")
				yaw = atan2(-lr[0], -lr[1])
			if _args.has("lookat"):
				var la: PackedFloat64Array = _args["lookat"].split_floats(",")
				var tgt := world.world_to_local(Vector3(la[0], 0, la[1]))
				var d := tgt - player.global_position
				yaw = atan2(-d.x, -d.z)
			player.set_look(yaw, deg_to_rad(float(_args.get("look", "-15"))))

	# Floating origin
	world.maybe_shift_origin(cam.global_position)

	# clouds and their shadows drift with the wind, faster when the gusts blow
	_cloud_drift += delta * (0.6 + 1.2 * WindGusts.current_strength)
	RenderingServer.global_shader_parameter_set("cloud_drift", _cloud_drift)
	atmosphere.sky_mat.set_shader_parameter("cloud_time", _cloud_drift)
	var wpos := world.local_to_world(cam.global_position)
	# the clock runs while you hike (not in the menu, not while paused)
	if mode == Mode.PLAYING and not get_tree().paused:
		atmosphere.day.advance(delta)
		var cur := atmosphere.current
		if atmosphere.weather.advance(delta, float(cur.get("rain", 1.0)), float(cur.get("fog_days", 0.3)), float(cur.get("snowfall", 0.0))):
			hud.show_message("It's starting to snow." if atmosphere.weather.snow_share > 0.6 else "It's starting to rain.")
			_soaked_hint = false
		# heat lightning: warm, mostly clear evenings and nights
		var hr := atmosphere.day.hour
		var evening := smoothstep(19.0, 20.3, hr) + (1.0 - smoothstep(1.5, 3.0, hr)) if hr > 12.0 or hr < 3.0 else 0.0
		var warm := smoothstep(15.0, 20.0, float(atmosphere.shown.get("temperature", 16.0)))
		atmosphere.weather.advance_flash(delta, float(cur.get("heat_lightning", 0.0)) * clampf(evening, 0.0, 1.0) * warm * (1.0 - atmosphere.weather.clouds) * (1.0 - atmosphere.weather.fog))
	var wf := atmosphere.weather
	atmosphere.sky_mat.set_shader_parameter("flash", Vector4(wf.flash_dir.x, wf.flash_dir.y, wf.flash, 0.0))
	if wf.flash > 0.01:
		atmosphere.env.ambient_light_energy = float(atmosphere.shown.get("ambient_energy", 0.5)) + wf.flash * 0.12
		_rain_on_player(delta)
		_campfire_warmth(delta)
	atmosphere.valley_y = cam.global_position.y - (wpos.y - gen.row(wpos.z, false)["elev"])
	atmosphere.update(wpos.z, delta)
	# test helpers for tuning the lighting
	if _args.has("skyset") and atmosphere.debug_sky.is_empty():
		for pair in _args["skyset"].split(","):
			var kv3: PackedStringArray = pair.split(":")
			atmosphere.debug_sky[kv3[0]] = float(kv3[1])
	if _args.has("weatherstate") and _frame == 20:
		# test helper: --weatherstate=fog|snow|rain|flash starts that weather at once
		var ws := atmosphere.weather
		match _args["weatherstate"]:
			"fog":
				ws._enter(Weather.FOG)
				ws._dur = 9999.0
				ws.fog = 1.0
			"snow", "rain":
				ws._enter(Weather.RAIN)
				ws._dur = 9999.0
				ws._strength = 1.0
				ws.rain = 1.0
				ws.clouds = 1.0
				ws.snow_share = 1.0 if _args["weatherstate"] == "snow" else 0.0
				ws.snow_cover = 1.0 if _args["weatherstate"] == "snow" else 0.0
	if _args.has("weatherstate") and _args["weatherstate"] == "flash":
		atmosphere.weather.flash = 1.0
		atmosphere.weather.flash_dir = Vector2(0.3, -1).normalized()
	if _args.has("usestone") and _frame == int(_args["usestone"]) and player:
		# test helper: use a pebble from the backpack at this frame (skip it / cairn)
		var peb := ItemDefs.make("kiesel")
		player.inventory.add(peb)
		cairns.use_stone(player, peb)
	if _args.has("shoot"):
		atmosphere.sky_mat.set_shader_parameter("shooting_seed", float(_args["shoot"]))
	if _args.has("tm"):
		atmosphere.env.tonemap_mode = int(_args["tm"])
	if _args.has("white"):
		atmosphere.env.tonemap_white = float(_args["white"])
	if _args.has("exp"):
		atmosphere.env.tonemap_exposure = float(_args["exp"])
	var fwd := -cam.global_basis.z
	particles.set_kind(atmosphere.current.get("particles", "motes"), atmosphere.current.get("particle_color", Color.WHITE))
	particles.follow(cam.global_position, fwd)
	_update_night_flies(cam, fwd)
	biome_fx.update(cam, delta, atmosphere.current.get("fx", {}), atmosphere.shown)
	_update_brook_sound(cam)
	var sh := atmosphere.shown
	var beams: float = float(sh.get("shafts", 0.0)) * float(sh.get("shaft_time", 1.0)) * (1.0 - atmosphere.weather.clouds) * (1.0 - atmosphere.underwater)
	canopy_shafts.update(beams, -(sh.get("sun_dir", Vector3(0, -1, 0)) as Vector3), sh.get("sun_color", Color.WHITE), cam.global_position, delta)
	var wd: Vector2 = ProjectSettings.get_setting("shader_globals/wind_direction")["value"]
	rain_fx.update(float(atmosphere.shown.get("rain", 0.0)) if atmosphere.underwater < 0.01 else 0.0,
		1.0 - float(atmosphere.shown.get("night", 0.0)) * 0.8, cam.global_position, fwd, wd.normalized(), delta,
		float(atmosphere.shown.get("snow", 0.0)) if atmosphere.underwater < 0.01 else 0.0)
	gusts.strength = atmosphere.current.get("gusts", 0.5)
	leaf_fall.update(cam, delta)
	desert_fx.update(cam, delta, atmosphere.current.get("dust", 0.0))
	atmosphere.set_dust(desert_fx.fog_boost)
	if _args.has("debugfx") and _frame % 60 == 0:
		print("[fx] gust %.2f dust %.2f weeds %d devil %s haze %.2f leaves %s (%d)" % [gusts.gust, atmosphere.current.get("dust", 0.0), desert_fx._weeds.size(), not desert_fx._devil.is_empty(), desert_fx.fog_boost, leaf_fall.particles.emitting, leaf_fall._pm.emission_point_count])
	streaks.camera = cam
	streaks.enabled = Settings.values["wind_fx"]
	butterflies.camera = cam
	songbirds.camera = cam
	deer.camera = cam
	deer.allowed = atmosphere.current.get("deer", false) and mode == Mode.PLAYING
	# deer like dawn and dusk, but not the dark night or heavy rain
	deer.activity = (1.0 - float(atmosphere.shown.get("night", 0.0)) * 0.8) * (1.0 - clampf(atmosphere.weather.rain * 1.5, 0.0, 1.0))
	songbirds.allowed = atmosphere.current.get("birds", true)
	songbirds.activity = (1.0 - float(atmosphere.shown.get("night", 0.0))) * (1.0 - clampf(atmosphere.weather.rain * 3.0, 0.0, 1.0))
	# butterflies and bees hide at night and in the rain
	butterflies.activity = (1.0 - float(atmosphere.shown.get("night", 0.0))) * (1.0 - clampf(atmosphere.weather.rain * 3.0, 0.0, 1.0))
	birds.camera = cam
	birds.enabled = atmosphere.current.get("birds", true)
	grass.update(cam.global_position)
	obstacles.update(world.local_to_world(cam.global_position))
	# only simulate dropped items where ground collision is loaded
	if _frame % 10 == 0:
		for c in dropped.get_children():
			var rb := c as RigidBody3D
			if rb:
				var cw := world.local_to_world(rb.global_position)
				rb.freeze = not world.is_ready_around(Vector2(cw.x, cw.z), 2.0)
	if _args.has("dbgproc") and _frame % 60 == 0:
		print("[proc] frame %d cam %s built %s chunks %d (+%d) mode %d player %s pos %s cam_is_player %s" % [_frame, world.local_to_world(cam.global_position), obstacles._built.keys(), world.loaded_count(), world.pending_count(), mode, player.get_instance_id() if player else 0, player.global_position if player else Vector3.ZERO, cam == (player.camera if player else null)])
	if player and mode != Mode.MENU:
		obstacles.update_carried(player)
	sea.follow(cam.global_position, atmosphere.current)
	var sea_w := world.gen.coast_info(world.local_to_world(cam.global_position).z).y if sea.visible else 0.0
	_sea_open = lerpf(_sea_open, sea_w, 1.0 - exp(-delta * 1.5))
	mountains.set_sea(_sea_open)
	atmosphere.sky_mat.set_shader_parameter("sea_amount", _sea_open)
	atmosphere.sky_mat.set_shader_parameter("sea_color", ((atmosphere.current.get("horizon_color", Color.WHITE) as Color) * 0.8).lerp(Color(0.1, 0.3, 0.5), 0.25))
	RenderingServer.global_shader_parameter_set("player_pos", player.global_position if player and mode != Mode.MENU else Vector3(0, -1000, 0))
	RenderingServer.global_shader_parameter_set("camera_world", _active_camera().global_position)
	film.visible = Settings.values["film_look"]
	_update_grading(delta)
	atmosphere.set_resting(player != null and mode == Mode.PLAYING and (player.resting or player.sleeping), delta)
	_update_underwater(cam, delta)
	outlines.visible = Settings.values["outlines"]
	mountains.follow(cam.global_position, world.height_local(cam.global_position.x, cam.global_position.z) - 30.0)
	_update_shafts(cam)
	_update_mist()

	var biome := atmosphere.dominant
	if mode != Mode.MENU:
		music.set_biome(biome)
	if biome != _last_biome:
		if mode == Mode.PLAYING and _last_biome != -1 and biome in [7, 10, 16, 21]:
			music.stinger("seltsam")
		butterflies.spawn(int(gen.biomes[biome]["atmosphere"]["butterflies"]))
		if mode == Mode.PLAYING and _last_biome != -1:
			hud.show_biome(gen.biomes[biome]["name"], "after %s km" % Menus._km(journey_distance / 1000.0))
		elif mode == Mode.PLAYING:
			hud.show_biome(gen.biomes[biome]["name"], "The journey begins")
		_last_biome = biome

	if mode != Mode.MENU and player:
		var pw := world.local_to_world(player.global_position)
		music.set_situation(_music_situation(pw))
		# obstacle overcome? short joyful stinger (once per obstacle)
		for o in gen.obstacles_near(pw.z):
			var ok: int = o["k"]
			if pw.z > o["z"] + 6.0:
				_passed_obstacles[ok] = false
			elif pw.z < o["z"] - 14.0 and _passed_obstacles.get(ok, true) == false:
				_passed_obstacles[ok] = true
				music.stinger("geschafft")
				hud.show_message("Made it!")
		journey_distance = maxf(journey_distance, gen.arc_length(pw.z) - gen.arc_length(start_z))
		hud.set_distance(journey_distance)
		hud.set_hour(atmosphere.day.hour)
		player.air_temp = atmosphere.shown.get("temperature", 16.0)
		hud.update_body(player.body.stamina, player.body.state, delta)
		hud.set_prompt(player.prompt, player.prompt_title, player.prompt_action)
		hud.set_needs(player.body.needs())
		# safety net: never fall through the ground
		if _frame % 15 == 0 and player.fly_mode == 0:
			var ground := world.ground_y(player.global_position.x, player.global_position.z)
			if player.global_position.y < ground - 2.0:
				player.global_position.y = ground + 0.3
				player.velocity = Vector3.ZERO
	hud.update_fps(Settings.values["show_fps"] or _args.has("fps"))

	if _args.has("debug") and _frame % 60 == 0 and player:
		for ci in player.get_slide_collision_count():
			var cc := player.get_slide_collision(ci)
			var co := cc.get_collider() as Node
			print("  contact: %s (%s) n=%s at %s" % [co.name if co else "?", co.get_parent().name if co and co.get_parent() else "", cc.get_normal(), cc.get_position()])
		print("rot=%s pending=%s pos=%s vel=%s floor=%s act=%s climbing=%s state=%d stamina=%.0f input=%s rope=%s crouch=%s" % [player.rotation_degrees, _spawn_pending, player.global_position, player.velocity, player.is_on_floor(), player.can_act(), player.climbing, player.body.state, player.body.stamina, player.input_enabled, player.rope, player.crouching])
	if _args.has("hide") and _frame % 30 == 0:
		# test helper: --hide=Bush_Large,Fern hides multimeshes whose model starts with one of these
		var pre: PackedStringArray = _args["hide"].split(",")
		for c in world.get_children():
			for m in c.get_children():
				var mh := m as MultiMeshInstance3D
				if mh and mh.multimesh and mh.multimesh.mesh:
					for pfx in pre:
						if mh.multimesh.mesh.resource_name.begins_with(pfx):
							mh.visible = false
	if _args.has("mmistats") and _frame == int(_args.get("wait", "300")) - 5:
		# test helper: which multimeshes cost the most (batches, instances, triangles by model family)
		var st := {}
		for c in world.get_children():
			for m in c.get_children():
				var mmi := m as MultiMeshInstance3D
				if mmi == null or not mmi.is_visible_in_tree() or mmi.multimesh == null or mmi.multimesh.mesh == null:
					continue
				var nm: String = mmi.multimesh.mesh.resource_name
				var fam := TreeKinds.family(nm) if nm.contains("_") else nm
				var n := mmi.multimesh.visible_instance_count if mmi.multimesh.visible_instance_count >= 0 else mmi.multimesh.instance_count
				var tris := 0
				var mesh := mmi.multimesh.mesh
				for si in mesh.get_surface_count():
					var arr := mesh.surface_get_arrays(si)
					tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arr[Mesh.ARRAY_INDEX] != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
				var e: Array = st.get(fam, [0, 0, 0])
				e[0] += 1
				e[1] += n
				e[2] += n * tris
				st[fam] = e
		var keys := st.keys()
		keys.sort_custom(func(a, b): return st[a][2] > st[b][2])
		for k in keys.slice(0, 25):
			print("[mmi] %-22s batches %5d  instances %7d  tris %9d" % [k, st[k][0], st[k][1], st[k][2]])
	if _args.has("fps") and _frame % 120 == 0:
		print("FPS %d | Chunks %d (+%d) | Distance %.0f m | Biome %s | Scale %.2f | prims %d" % [
			Engine.get_frames_per_second(), world.loaded_count(), world.pending_count(), journey_distance,
			gen.biomes[biome]["name"], get_viewport().scaling_3d_scale,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		var vp_rid := _shot_vp.get_viewport_rid() if _shot_vp else get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(vp_rid, true)
		print("   draws %d | objects %d | GPU %.1f ms | Render CPU %.1f ms | Script %.1f ms | Physics %.1f ms" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.viewport_get_measured_render_time_gpu(vp_rid),
			RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu(),
			_script_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		print("   longest frame %.0f ms | hitches >50 ms: %d | impostors %d (+%d)" % [_max_frame_ms, _spikes, world.impostors.baked_count(), world.impostors.pending_count()])
		_max_frame_ms = 0.0
	_update_shot()
	if _args.has("off") and _frame == 30:
		for sys in _args["off"].split(","):
			match sys:
				"sky": atmosphere.env.background_mode = Environment.BG_COLOR
				"mountains": mountains.visible = false
				"shafts": Settings.set_value("sun_shafts", false)
				"particles": particles.visible = false
				"shadows": atmosphere.sun.shadow_enabled = false
				"ssao": atmosphere.env.ssao_enabled = false
				"blades": grass.visible = false
				"pcss": atmosphere.sun.light_angular_distance = 0.5
				"nopcss": atmosphere.sun.light_angular_distance = 0.0
				"softmed": RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
				"dist100": atmosphere.sun.directional_shadow_max_distance = 100.0
				"ssil": atmosphere.env.ssil_enabled = false
				"vol": atmosphere.env.volumetric_fog_enabled = false
				"dof": atmosphere.world_env.camera_attributes = null
				"glow": atmosphere.env.glow_enabled = false
				"fog": atmosphere.env.fog_enabled = false
				"blend": atmosphere.sun.directional_shadow_blend_splits = false
				"hard": RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
				"split2": atmosphere.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				"trees":
					for c in world.get_children():
						for m in c.get_children():
							if m is MultiMeshInstance3D and TreeKinds.is_tree(m.multimesh.mesh.resource_name):
								m.visible = false
				"treeshadows":
					for c in world.get_children():
						for m in c.get_children():
							if m is MultiMeshInstance3D and TreeKinds.is_tree(m.multimesh.mesh.resource_name):
								m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"grass":
					for c in world.get_children():
						for m in c.get_children():
							if m is MultiMeshInstance3D and m.multimesh.mesh.resource_name.begins_with("Grass"):
								m.visible = false
				"terrain":
					for c in world.get_children():
						if c.get_child_count() > 0 and c.get_child(0) is MeshInstance3D:
							c.get_child(0).visible = false


func _active_camera() -> Camera3D:
	if player and mode != Mode.MENU:
		return player.camera
	return menu_cam


func _update_focus() -> void:
	var cam := _active_camera()
	var w := world.local_to_world(cam.global_position)
	world.focus = Vector2(w.x, w.z)
	var f := -cam.global_basis.z
	world.focus_dir = Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else Vector2(0, -1)


func _on_origin_shifted(shift: Vector3) -> void:
	for n in [menu_cam, player]:
		if n:
			n.global_position -= shift
	menu_cam.shift_target(shift)
	streaks.shift(shift)
	birds.shift(shift)
	grass.shift(shift)
	obstacles.shift(shift)
	for c in dropped.get_children():
		c.global_position -= shift
	footprints.shift(shift)
	canopy_shafts.shift(shift)
	songbirds.shift(shift)
	deer.shift(shift)
	particles.restart()
	biome_fx.restart()
	leaf_fall.restart()
	desert_fx.shift(shift)


func _setup_shafts() -> void:
	_shaft_mat = ShaderMaterial.new()
	_shaft_mat.shader = preload("res://shaders/sun_shafts.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	shafts = MeshInstance3D.new()
	shafts.mesh = quad
	shafts.material_override = _shaft_mat
	shafts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shafts.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(shafts)
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = preload("res://shaders/mist.gdshader")
	_mist_mat.set_shader_parameter("noise_tex", preload("res://assets/paint_noise.tres"))
	_mist_mat.render_priority = 100
	mist = MeshInstance3D.new()
	mist.mesh = quad
	mist.material_override = _mist_mat
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(mist)


## What's happening decides the music: obstacle ahead / on the rope / in the current → tension,
## resting and sleeping → calm tracks, swimming in a lake → water music.
func _music_situation(pw: Vector3) -> String:
	if not player.rope.is_empty() or player.body.state == Body.State.COLLAPSED:
		return "spannung"
	if player.swimming and gen.river_flow(pw.x, pw.z) != Vector2.ZERO:
		return "spannung"
	for o in gen.obstacles_near(pw.z):
		# from 55 m before the obstacle until just past it
		if pw.z < o["z"] + 55.0 and pw.z > o["z"] - 10.0:
			return "spannung"
	if player.resting or player.sleeping:
		return "ruhe"
	if player.swimming:
		return "wasser"
	return ""


## Camera below the water surface? Then turquoise veil, dense fog, muffled music.
func _update_underwater(cam: Camera3D, delta: float) -> void:
	var cw := world.local_to_world(cam.global_position)
	var wl := gen.water_level(cw.x, cw.z)
	var depth := wl - cw.y if wl > -INF else -1.0
	var target := 1.0 if depth > 0.02 else 0.0
	_underwater = move_toward(_underwater, target, delta * 4.0)
	underwater_fx.visible = _underwater > 0.001
	var um: ShaderMaterial = underwater_fx.material
	um.set_shader_parameter("amount", _underwater)
	um.set_shader_parameter("depth", maxf(depth, 0.0))
	atmosphere.underwater = _underwater
	music.set_underwater(_underwater)


func _setup_post() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var om := ShaderMaterial.new()
	om.shader = preload("res://shaders/outlines.gdshader")
	outlines = MeshInstance3D.new()
	outlines.mesh = quad
	outlines.material_override = om
	outlines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outlines.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(outlines)
	# color grading as a 2D layer over the finished image, below the HUD
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	film = ColorRect.new()
	film.set_anchors_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://shaders/film_look.gdshader")
	film.material = fm
	layer.add_child(film)
	underwater_fx = ColorRect.new()
	underwater_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	underwater_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var um := ShaderMaterial.new()
	um.shader = preload("res://shaders/underwater.gdshader")
	um.set_shader_parameter("noise_tex", preload("res://assets/paint_noise.tres"))
	underwater_fx.material = um
	underwater_fx.visible = false
	layer.add_child(underwater_fx)


## Rain soaks you unless you wear the rain jacket or the poncho
## By a burning campfire: warm, drying off, resting faster
func _campfire_warmth(delta: float) -> void:
	if not player or mode != Mode.PLAYING:
		return
	for f: Campfire in get_tree().get_nodes_in_group("campfire"):
		if not f.is_burning() or f.global_position.distance_to(player.global_position) > 3.6:
			continue
		player.body.warm_bonus_t = maxf(player.body.warm_bonus_t, 4.0)
		player.body.wet = maxf(player.body.wet - delta * 0.012, 0.0)
		if player.resting:
			player.body.rest = minf(player.body.rest + delta * 0.5, 100.0)
			player.body.stamina = minf(player.body.stamina + delta * 2.0, player.body.max_stamina())
		return


func _rain_on_player(delta: float) -> void:
	var w := atmosphere.weather
	if not player or not w.is_raining() or player.swimming:
		return
	# under a shelter's roof you stay dry (and slowly dry off)
	for sh: Node3D in get_tree().get_nodes_in_group("shelter"):
		var lp := sh.global_transform.affine_inverse() * player.global_position
		if absf(lp.x) < 1.4 and absf(lp.z) < 1.05 and lp.y < 2.3 and lp.y > -0.5:
			player.body.wet = maxf(player.body.wet - delta * 0.004, 0.0)
			return
	var covered := player._wears("regenjacke") or player._wears("poncho")
	# snow soaks you much more slowly than rain
	var soak := w.rain * lerpf(1.0, 0.25, w.snow_share)
	player.body.wet = minf(player.body.wet + soak * delta * (0.004 if covered else 0.03), 1.0)
	if not _soaked_hint and player.body.wet > 0.35:
		_soaked_hint = true
		hud.show_message("You're getting soaked. A rain jacket would help." if not covered else "Good thing you brought rain gear.")


## The brook babbles from its nearest point
func _update_brook_sound(cam: Camera3D) -> void:
	if _brook_sound == null:
		_brook_sound = AudioStreamPlayer3D.new()
		_brook_sound.stream = Sfx.brook_loop()
		_brook_sound.unit_size = 6.0
		_brook_sound.max_distance = 40.0
		add_child(_brook_sound)
	if _frame % 10 != 0:
		return
	var w := world.local_to_world(cam.global_position)
	var best := INF
	var best_p := Vector3.ZERO
	for dz in [-8.0, -3.0, 0.0, 3.0, 8.0]:
		var r := gen.row(w.z + dz)
		for b in r["brooks"]:
			var c := gen.brook_center(b, r)
			if c.x == INF or c.y < 0.3:
				continue
			var p := Vector3(c.x, gen.brook_level(b, r, c.x), w.z + dz)
			var d := p.distance_to(w)
			if d < best:
				best = d
				best_p = p
	var vol: float = Settings.values.get("sfx_volume", 0.8)
	if best < 40.0 and vol > 0.01:
		_brook_sound.global_position = world.world_to_local(best_p)
		_brook_sound.volume_db = -8.0 + linear_to_db(vol)
		if not _brook_sound.playing:
			_brook_sound.play()
	elif _brook_sound.playing:
		_brook_sound.stop()


func _update_night_flies(cam: Camera3D, fwd: Vector3) -> void:
	var flies: float = atmosphere.shown.get("flies", 0.0)
	# the Glowing Forest has its own fireflies; in the dry desert there are only a few
	if atmosphere.current.get("particles", "") == "fireflies":
		flies = 0.0
	elif gen.biomes[atmosphere.dominant]["terrain"].get("dunes", 0.0) > 0.5:
		flies *= 0.15
	if flies <= 0.01:
		if night_flies.particles:
			night_flies.particles.emitting = false
		return
	night_flies.set_kind("fireflies", Color(0.86, 1.0, 0.42))
	if night_flies.particles:
		night_flies.particles.emitting = true
		night_flies.particles.amount_ratio = flies
	night_flies.follow(cam.global_position, fwd)


var _grade := {}


## Biome and time-of-day color grading (smoothly blended). With the film look it drives split toning,
## white balance and contrast; without it (Low/Medium) at least the white balance, through the environment.
func _update_grading(delta: float) -> void:
	var sh := atmosphere.shown
	if sh.is_empty():
		return
	var k := 1.0 - exp(-delta * 1.2)
	for key in ["grade_shadow", "grade_high", "grade_warm", "grade_contrast"]:
		var v = sh.get(key)
		if v == null:
			continue
		if not _grade.has(key):
			_grade[key] = v
		elif v is Color:
			_grade[key] = (_grade[key] as Color).lerp(v, k)
		else:
			_grade[key] = lerpf(_grade[key], v, k)
	var fm := film.material as ShaderMaterial
	fm.set_shader_parameter("shadow_tint", _grade.get("grade_shadow", Color(0.35, 0.55, 0.75)))
	fm.set_shader_parameter("highlight_tint", _grade.get("grade_high", Color(1.0, 0.86, 0.62)))
	fm.set_shader_parameter("warmth", _grade.get("grade_warm", 0.0))
	fm.set_shader_parameter("contrast", _grade.get("grade_contrast", 0.25))
	if not film.visible:
		var w: float = _grade.get("grade_warm", 0.0)
		atmosphere.env.adjustment_color_correction = null
		atmosphere.env.adjustment_brightness = 1.0
		atmosphere.env.adjustment_contrast = 1.0 + float(_grade.get("grade_contrast", 0.25)) * 0.2
		atmosphere.env.adjustment_saturation = float(sh.get("saturation", 1.08)) * (1.0 + absf(w) * 0.03)


func _update_mist() -> void:
	var sh := atmosphere.shown
	var amount: float = sh.get("mist", 0.0)
	mist.visible = amount > 0.01 and atmosphere.underwater < 0.01
	if not mist.visible:
		return
	_mist_mat.set_shader_parameter("amount", amount)
	_mist_mat.set_shader_parameter("base_y", atmosphere.valley_y)
	var fc: Color = sh["fog_color"]
	_mist_mat.set_shader_parameter("mist_color", fc.lerp(Color(1, 1, 1), 0.25))
	_mist_mat.set_shader_parameter("sun_color", sh["sun_color"])
	_mist_mat.set_shader_parameter("to_sun", -(sh["sun_dir"] as Vector3).normalized())


## Project the sun onto the screen; shafts only when it is roughly in view
func _update_shafts(cam: Camera3D) -> void:
	if not Settings.values["sun_shafts"]:
		shafts.visible = false
		return
	var to_sun := -(atmosphere.sun.global_basis.z)
	to_sun = -to_sun
	var sun_pos := cam.global_position + to_sun * 1000.0
	var facing := (-cam.global_basis.z).dot(to_sun)
	if facing < 0.1 or cam.is_position_behind(sun_pos):
		shafts.visible = false
		return
	shafts.visible = true
	var vp := cam.get_viewport().get_visible_rect().size
	var uv := cam.unproject_position(sun_pos) / vp
	_shaft_mat.set_shader_parameter("sun_uv", uv)
	_shaft_mat.set_shader_parameter("strength", smoothstep(0.1, 0.7, facing) * 0.6 * minf(atmosphere.sun.light_energy / 1.8, 1.0))
	_shaft_mat.set_shader_parameter("sun_color", atmosphere.sun.light_color)
	_shaft_mat.set_shader_parameter("samples", 16 if Settings.values["opt_shafts_16"] else 24)


func _open_knot(book: bool, cb: Callable) -> void:
	_knot_cb = cb
	if player:
		player.input_enabled = false
	knot_game.start(book)


func _on_knot_done(q: float) -> void:
	if player:
		player.input_enabled = true
	if not backpack.is_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# gloves: a firmer grip makes knots a bit stronger
	if player and q >= 0.0 and player._wears("handschuhe"):
		q = minf(q * 1.1 + 0.02, 1.0)
	if _knot_cb.is_valid():
		var cb := _knot_cb
		_knot_cb = Callable()
		cb.call(q)


func _spawn_dropped(item: Dictionary, pos: Vector3, vel: Vector3) -> void:
	var wi := WorldItem.create(item)
	wi.world_ref = world
	dropped.add_child(wi)
	wi.global_position = pos
	wi.linear_velocity = vel
	wi.angular_velocity = Vector3(randf(), randf(), randf()) * 4.0
	wi.broke.connect(func(it): hud.show_message("%s broke." % ItemDefs.def(it["id"])["name"]))


## Test helper: walks along the path automatically
func _autopilot() -> Vector3:
	var w := world.local_to_world(player.global_position)
	# crouch under fallen trees
	player.force_crouch = false
	for o in gen.obstacles_near(w.z):
		if o["type"] == "fallen_tree" and absf(w.z - o["z"]) < 3.5:
			player.force_crouch = true
	# stuck? pull up at the ledge / try climbing
	if player.get_real_velocity().length() < 0.2 and player.is_on_floor():
		_stuck_time += get_physics_process_delta_time()
		if _stuck_time > 0.8:
			_stuck_time = 0.0
			player._try_climb()
	else:
		_stuck_time = 0.0
	var ahead_z := w.z - 8.0
	var target := Vector3(gen.path_x(ahead_z), 0.0, ahead_z)
	var d := target - w
	d.y = 0.0
	return d.normalized()


# ================================================================ Records

func _load_record() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(RECORD_PATH) != OK:
		return 0.0
	return cfg.get_value("records", "best_distance", 0.0)


func _save_record() -> void:
	# test runs don't change records
	for a in ["autowalk", "obtest", "selftest", "shot", "set", "preset", "z"]:
		if _args.has(a):
			return
	if journey_distance <= best_distance:
		return
	best_distance = journey_distance
	var cfg := ConfigFile.new()
	cfg.set_value("records", "best_distance", best_distance)
	cfg.save(RECORD_PATH)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and mode != Mode.MENU:
		_save_record()


# ================================================================ Screenshots for tests

func _setup_offscreen() -> void:
	var sz: PackedStringArray = _args.get("size", "1920x1080").split("x")
	_shot_vp = SubViewport.new()
	_shot_vp.size = Vector2i(int(sz[0]), int(sz[1]))
	_shot_vp.world_3d = get_viewport().world_3d
	_shot_vp.msaa_3d = get_viewport().msaa_3d
	_shot_vp.use_debanding = true
	_shot_vp.scaling_3d_mode = get_viewport().scaling_3d_mode
	_shot_vp.scaling_3d_scale = get_viewport().scaling_3d_scale
	_shot_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_shot_vp)
	_shot_cam = Camera3D.new()
	_shot_vp.add_child(_shot_cam)
	var film_layer := film.get_parent()
	film_layer.get_parent().remove_child(film_layer)
	_shot_vp.add_child(film_layer)
	_shot_cam.make_current()
	get_viewport().disable_3d = true
	_shot_vp.use_taa = get_viewport().use_taa
	_shot_vp.screen_space_aa = get_viewport().screen_space_aa
	# --ui with --size: the interface is rendered into the screenshot too (any resolution, no window needed)
	if _args.has("ui"):
		for c in get_children():
			if c is CanvasLayer and c != film_layer:
				c.reparent(_shot_vp, false)


func _update_shot() -> void:
	if _shot_cam:
		var cam := _active_camera()
		_shot_cam.global_transform = cam.global_transform
		_shot_cam.fov = cam.fov
		_shot_cam.near = cam.near
		_shot_cam.far = cam.far
		_shot_vp.scaling_3d_scale = get_viewport().scaling_3d_scale
		_shot_vp.scaling_3d_mode = get_viewport().scaling_3d_mode
		_shot_vp.mesh_lod_threshold = get_viewport().mesh_lod_threshold
		_shot_vp.msaa_3d = get_viewport().msaa_3d
		_shot_vp.screen_space_aa = get_viewport().screen_space_aa
	if _args.has("dbgwater") and _frame == int(_args.get("wait", "300")) - 2:
		for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
			var gi := n as GeometryInstance3D
			var mat = gi.material_override
			if gi.is_visible_in_tree() and mat is ShaderMaterial and (mat.shader.resource_path.contains("water") or mat.shader.resource_path.contains("waterfall")):
				var ab := gi.global_transform * gi.get_aabb()
				print("[water] %s %s pos=%s aabb=%s cam=%s" % [gi.name, gi.get_parent().name, gi.global_position, ab, _active_camera().global_position])
	if _args.has("shot") and _frame == int(_args.get("wait", "300")):
		var img := (_shot_vp.get_texture() if _shot_vp else get_viewport().get_texture()).get_image()
		img.save_png(_args["shot"])
		print("saved: %s  FPS %d  distance %.0f m" % [_args["shot"], Engine.get_frames_per_second(), journey_distance])
		get_tree().quit()


## Test helper: models in a row ahead of the camera, e.g. --lineup=Birch_1,Birch_2 --lstyle=13/1/0
## (styles of biome/layer/style index; default: a plain green tree, gray rock or the plant's own colors)
func _lineup(models: PackedStringArray) -> void:
	var fw := -player.global_basis.z
	fw = Vector3(fw.x, 0, fw.z).normalized()
	var right := fw.cross(Vector3.UP)
	var gap := float(_args.get("lgap", "9"))
	var ahead := float(_args.get("lahead", "22"))
	var style := {}
	if _args.has("lstyle"):
		var p: PackedStringArray = _args["lstyle"].split("/")
		var layer: Dictionary = gen.biomes[int(p[0])]["layers"][int(p[1])]
		style = (layer.get("styles", [{}]) + layer.get("region_styles", []))[int(p[2]) if p.size() > 2 else 0]
	for i in models.size():
		var m: String = models[i]
		var st := style
		if st.is_empty():
			if TreeKinds.is_tree(m):
				st = BiomeDefs.tree_style(Color(0.24, 0.5, 0.08), Color(0.68, 0.9, 0.26))
			elif m.begins_with("Rock"):
				st = BiomeDefs.rock_style(Color(0.7, 0.72, 0.7), 0.4)
			elif m.begins_with("Bush"):
				st = {"leaves": BiomeDefs.leaves(Color(0.2, 0.46, 0.08), Color(0.55, 0.84, 0.2), {"sphere_normals": 0.85}), "stiffness": 6.0}
		var pos := player.global_position + fw * ahead + right * (i - (models.size() - 1) * 0.5) * gap
		var wp := world.local_to_world(pos)
		pos.y = world.world_to_local(Vector3(0, gen.height(wp.x, wp.z), 0)).y
		var mi := MeshInstance3D.new()
		mi.mesh = lib.mesh(m, st)
		mi.scale = Vector3.ONE * float(_args.get("lscale", "1"))
		world.add_child(mi)
		mi.global_position = pos
