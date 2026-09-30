extends SceneTree
## Renders scouts in a small studio scene and saves a picture (for looking at the character).
## godot --path . --resolution 1600x900 -s res://scripts/tests/scout_studio.gd -- --out=/tmp/x.png --mode=lineup
## Modes: lineup, poses, face, back, walk, gait (filmstrip: 8 phases of a cycle per speed, side view;
## --speeds=1.6,3.4,6.2 --cols=8)

var _frames := 0
var _args := {}
var _scouts: Array[Scout] = []
var _cam: Camera3D
var _vp: SubViewport


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var mode: String = _args.get("mode", "lineup")
	var sz: PackedStringArray = _args.get("size", "1600x900").split("x")
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(sz[0]), int(sz[1]))
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = _args.has("transparent")
	root.add_child(_vp)
	var world := Node3D.new()
	_vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("5a9ee8")
	sm.sky_horizon_color = Color("cfe6f5")
	sm.ground_horizon_color = Color("cfe6f5")
	sm.ground_bottom_color = Color("6b8f4a")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	if _args.has("transparent"):
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("dfe9f5")
		env.ambient_light_energy = 1.25
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, float(_args.get("sun", "35")), 0)
	sun.light_energy = 1.6 if _args.has("transparent") else 1.35
	sun.light_color = Color("fff1dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("7fae4f")
	gm.roughness = 1.0
	ground.material_override = gm
	if not _args.has("transparent"):
		world.add_child(ground)
	_cam = Camera3D.new()
	world.add_child(_cam)
	_cam.fov = 35.0
	seed(int(_args.get("seed", "3")))
	match mode:
		"lineup":
			for i in 5:
				var lk := Scout.random_look()
				lk["hat"] = [1, 5, 6, 2, 7][i]
				lk["face"] = i
				if i == 0:
					lk = Scout.DEFAULT_LOOK.duplicate()
				var sc := Scout.new(lk)
				sc.position = Vector3((i - 2) * 1.05, 0, 0)
				sc.rotation.y = (i - 2) * -0.18
				world.add_child(sc)
				_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0, 1.3, 6.2) * Vector3(1, 1, -1), Vector3(0, 0.85, 0))
		"poses":
			var poses := [Scout.Pose.STAND, Scout.Pose.CROUCH, Scout.Pose.SIT, Scout.Pose.LIE, Scout.Pose.CLIMB]
			for i in poses.size():
				var sc := Scout.new(Scout.random_look())
				sc.pose = poses[i]
				sc.mood = [Scout.Mood.JOY, Scout.Mood.TIRED, Scout.Mood.NORMAL, Scout.Mood.KNOCKED_OUT, Scout.Mood.NORMAL][i]
				if i == 0:
					sc.wave(100.0)
				sc.position = Vector3((i - 2) * 1.2, 0, 0)
				world.add_child(sc)
				_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0, 1.4, -6.8), Vector3(0, 0.7, 0))
		"face":
			var sc := Scout.new(Scout.DEFAULT_LOOK)
			world.add_child(sc)
			_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0.35, 1.35, -1.5), Vector3(0, 1.2, 0))
		"side":
			var sc := Scout.new(Scout.DEFAULT_LOOK)
			sc.set_look_data({"hat": 0})
			sc.apply_look()
			world.add_child(sc)
			_scouts.append(sc)
			_cam.look_at_from_position(Vector3(-2.6, 1.2, -0.6), Vector3(0, 0.95, 0))
		"group":
			var looks := [
				{"skin": 0, "outfit": 0, "pants": 0, "sash": 7, "scarf": 0, "hat": 1, "hat_color": 10, "pack": 1, "face": 0, "extra": 3},
				{"skin": 5, "outfit": 2, "pants": 1, "sash": 0, "scarf": 2, "hat": 3, "hat_color": 11, "pack": 0, "face": 1, "extra": 1},
				{"skin": 3, "outfit": 1, "pants": 2, "sash": 6, "scarf": 5, "hat": 6, "hat_color": 8, "pack": 6, "face": 3, "extra": 0},
				{"skin": 7, "outfit": 4, "pants": 3, "sash": 2, "scarf": 7, "hat": 4, "hat_color": 0, "pack": 4, "face": 4, "extra": 3},
				{"skin": 1, "outfit": 3, "pants": 4, "sash": 9, "scarf": 3, "hat": 7, "hat_color": 1, "pack": 7, "face": 2, "extra": 4},
			]
			# a happy troop: waving, cheering, thumbs up, laughing
			var acts := ["wave", "thumbs", "cheer", "laugh", "wave"]
			var xs := [0.0, -1.0, 1.0, -1.95, 1.95]
			var zs := [0.0, 0.35, 0.3, 0.8, 0.75]
			for i in looks.size():
				var sc := Scout.new(looks[i])
				sc.position = Vector3(xs[i], 0, zs[i])
				sc.rotation.y = xs[i] * 0.12
				if acts[i] == "wave":
					sc.wave(100.0)
				else:
					sc.play_emote(acts[i])
				world.add_child(sc)
				_scouts.append(sc)
			_cam.fov = 28.0
			_cam.look_at_from_position(Vector3(0, 1.25, -8.2), Vector3(0, 0.82, 0.3))
		"structures":
			var items := [
				[StructureModels.picnic_blanket(), Vector3(-7, 0, 0)], [StructureModels.basket(), Vector3(-6.2, 0, -0.6)],
				[StructureModels.lost_pack(Color("d1493f")), Vector3(-4.2, 0, 0)], [StructureModels.bench(), Vector3(-2.2, 0, 0)],
				[StructureModels.spring_stones(1), Vector3(0.3, 0, 0)], [StructureModels.chest_body(), Vector3(2.4, 0, 0)],
				[StructureModels.signpost_post(), Vector3(4.2, 0, 0)], [StructureModels.post(1.35), Vector3(5.4, 0.6, 0)],
				[StructureModels.plank(Vector3(2.4, 0.07, 0.34)), Vector3(7.0, 0.1, 0)],
			]
			for it in items:
				var mi := MeshInstance3D.new()
				mi.mesh = it[0]
				mi.position = it[1]
				world.add_child(mi)
			for k in 2:
				var arm := MeshInstance3D.new()
				arm.mesh = StructureModels.sign_arrow(1.2)
				arm.position = Vector3(4.25, 1.75 - k * 0.36, 0)
				arm.rotation.y = 0.4 + PI * k
				world.add_child(arm)
			_cam.fov = 40.0
			_cam.look_at_from_position(Vector3(0, 3.2, -10.5), Vector3(0, 0.6, 0))
		"landmarks":
			var parts := [
				[StructureModels.column(4.5, false), Vector3(-6, 2.25, 2)], [StructureModels.column(3.0, true), Vector3(-4.2, 1.5, 2)],
				[StructureModels.arch_wall(5.5, 4.2, 0.9, 1, false), Vector3(0, 0, 3)], [StructureModels.steps(3, 4.0, false), Vector3(0, 0, 0.5)],
				[StructureModels.standing_stone(3.4, 2, false), Vector3(5, 1.7, 2)], [StructureModels.standing_stone(3.4, 3, false), Vector3(8.2, 1.7, 2)],
				[StructureModels.lintel(3.6, 1, false), Vector3(6.6, 3.7, 2)], [StructureModels.altar(false), Vector3(6.5, 0.3, -1)],
				[StructureModels.masonry(Vector3(3.8, 3.0, 2.4), 3), Vector3(-7, 1.5, -2)], [StructureModels.root_plate(2.4, 1), Vector3(-2.5, 1.2, -3)],
			]
			for it in parts:
				var mi := MeshInstance3D.new()
				mi.mesh = it[0]
				mi.position = it[1]
				world.add_child(mi)
			var cap := MeshInstance3D.new()
			cap.mesh = StructureModels.log_cap(0.7)
			cap.position = Vector3(-2.5, 1.2, -1.2)
			cap.rotation.x = -PI * 0.5
			world.add_child(cap)
			_cam.fov = 45.0
			_cam.look_at_from_position(Vector3(0, 5.0, -15.0), Vector3(0, 1.6, 1))
		"back":
			for i in 3:
				var sc := Scout.new(Scout.random_look() if i > 0 else Scout.DEFAULT_LOOK)
				sc.position = Vector3((i - 1) * 1.1, 0, 0)
				sc.rotation.y = PI + (i - 1) * 0.5
				world.add_child(sc)
				_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0, 1.5, -4.8), Vector3(0, 0.9, 0))
		"gait":
			_gait_strip(world)
		"clip":
			_clip_setup(world, ground)
		"faces":
			# every eye shape, every mouth, blush / sweat / tears, and the bubbles
			var eyes: Array = ScoutFaceFx.EYES
			var mouths: Array = ScoutFaceFx.MOUTHS
			var cells := []
			for e in eyes:
				cells.append({"eyes": e})
			for m in mouths:
				cells.append({"mouth": m, "open": 0.7})
			cells.append({"blush": 1.0, "eyes": "happy"})
			cells.append({"sweat": 1.0, "eyes": "sclera", "mouth": "wavy"})
			cells.append({"tears": 1.0, "eyes": "teary", "mouth": "frown"})
			var cols := 8
			for i in cells.size():
				var sc := Scout.new(Scout.DEFAULT_LOOK)
				sc.set_look_data({"hat": 0, "extra": 0})
				sc.apply_look()
				sc.face_override = cells[i]
				sc.position = Vector3((i % cols - (cols - 1) * 0.5) * 0.72, -(i / cols) * 0.82, 0)
				sc.rotation.y = PI
				world.add_child(sc)
				_scouts.append(sc)
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = 3.2
			_cam.look_at_from_position(Vector3(0, 0.25, 6.0), Vector3(0, 0.25, 0))
		"bubbles":
			var kinds: Array = ScoutBubbles.KINDS
			for i in kinds.size():
				var sc := Scout.new(Scout.DEFAULT_LOOK)
				sc.set_look_data({"hat": 0, "extra": 0})
				sc.apply_look()
				sc.position = Vector3((i - (kinds.size() - 1) * 0.5) * 0.8, 0, 0)
				sc.rotation.y = PI
				sc.set_meta("bubble", kinds[i])
				world.add_child(sc)
				_scouts.append(sc)
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = 3.4
			_cam.look_at_from_position(Vector3(0, 1.55, 6.0), Vector3(0, 1.55, 0))
		"gear":
			# carried, worn and held things; --back shows the backpacks
			var sets := [
				[["wasserflasche", "kamera", "fernglas", "pfeife", "kompass", "messer", "stock", "laterne"], ["muetze", "schal"], "stock", "laterne"],
				[["seil", "laterne", "drachen", "tee", "sonnenhut", "wasserflasche"], [], "", ""],
				[["karte", "kamera", "wasserflasche"], ["sonnenhut"], "karte", ""],
				[["kompass", "taschenlampe", "seil", "stock"], ["regenjacke", "handschuhe"], "kompass", "taschenlampe"],
				[["apfel", "fernglas", "drachen"], ["pullover"], "apfel", ""],
			]
			var back := _args.has("back")
			for i in sets.size():
				var sc := Scout.new(Scout.random_look() if i > 0 else Scout.DEFAULT_LOOK)
				sc.position = Vector3((i - 2) * 1.1, 0, 0)
				sc.rotation.y = (PI if back else 0.0) + (i - 2) * -0.15
				world.add_child(sc)
				var items := []
				for id in sets[i][0]:
					items.append(ItemDefs.make(id))
				for id in sets[i][1]:
					var it := ItemDefs.make(id)
					it["equipped"] = true
					items.append(it)
				sc.gear.set_items(items)
				if sets[i][2] != "":
					sc.gear.hold("R", sets[i][2])
				if sets[i][3] != "":
					sc.gear.hold("L", sets[i][3])
				_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0, 1.3, 6.2) * Vector3(1, 1, -1), Vector3(0, 0.85, 0))
		"actions":
			# every item action, frozen at --at (share of its length, default 0.55)
			var kinds: Array = ScoutActions.KINDS.keys()
			var items := {"eat": "apfel", "drink": "wasserflasche", "throw": "kiesel", "apply": "verband", "dress": "muetze", "kite": "", "read": "karte"}
			var cols := 8
			for i in kinds.size():
				var sc := Scout.new(Scout.DEFAULT_LOOK)
				sc.set_look_data({"hat": 0})
				sc.apply_look()
				sc.position = Vector3(-(i % cols - (cols - 1) * 0.5) * 1.05, -(i / cols) * 2.3, 0)
				sc.rotation.y = -0.6
				world.add_child(sc)
				sc.frozen = true
				for f in 30:
					sc.animate(1.0 / 60.0)
				var kind: String = kinds[i]
				var lab := Label3D.new()
				lab.text = kind
				lab.font_size = 64
				lab.outline_size = 12
				lab.position = Vector3(0, 2.05, 0)
				lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sc.add_child(lab)
				if kind == "read":
					sc.gear.set_items([ItemDefs.make("karte")])
					sc.gear.hold("R", "karte")
				sc.play_action(kind, items.get(kind, ""), 2.0 if ScoutActions.duration(kind) <= 0.0 else -1.0)
				var dur: float = ScoutActions.duration(kind) if ScoutActions.duration(kind) > 0.0 else 2.0
				for f in int(dur * float(_args.get("at", "0.55")) * 60.0):
					sc.animate(1.0 / 60.0)
				_scouts.append(sc)
			_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			_cam.size = 4.9
			_cam.look_at_from_position(Vector3(0, 0.0, -8.0), Vector3(0, 0.0, 0))
		"idle":
			var names: Array = Scout.FIDGETS.keys()
			for i in names.size():
				var sc := Scout.new(Scout.random_look() if i > 0 else Scout.DEFAULT_LOOK)
				sc.position = Vector3((i - (names.size() - 1) * 0.5) * 0.95, 0, 0)
				world.add_child(sc)
				sc.frozen = true
				for f in 60:
					sc.animate(1.0 / 60.0)
				sc.fidget(names[i])
				for f in int(float(_args.get("at", "1.2")) * 60.0):
					sc.animate(1.0 / 60.0)
				_scouts.append(sc)
			_cam.fov = 30.0
			_cam.look_at_from_position(Vector3(0, 1.4, -9.0), Vector3(0, 0.8, 0))
		"walk":
			for i in 4:
				var sc := Scout.new(Scout.random_look() if i > 0 else Scout.DEFAULT_LOOK)
				sc.speed = [1.5, 3.4, 6.0, 3.4][i]
				sc.sprint = i == 2
				sc.on_floor = i != 3
				sc.position = Vector3((i - 1.5) * 1.2, 0, 0)
				sc.rotation.y = PI * 0.5
				world.add_child(sc)
				_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0, 1.3, -6.5), Vector3(0, 0.8, 0))


var _bubble_scout: Scout


func _process(_delta: float) -> bool:
	if _frames == 12:
		for sc in _scouts:
			if sc.has_meta("bubble"):
				sc.bubble(sc.get_meta("bubble"), 99.0, 0.0, 1.3)
	if _clip:
		return _clip_step()
	_frames += 1
	if _frames == int(_args.get("frames", "40")):
		var img := _vp.get_texture().get_image()
		img.save_png(_args.get("out", "/tmp/scout.png"))
		print("saved ", _args.get("out", "/tmp/scout.png"))
		return true
	return false


## Filmstrip: one row per speed, one column per phase of the gait cycle (each scout simulated on its own)
func _gait_strip(world: Node3D) -> void:
	var speeds: PackedFloat64Array = str(_args.get("speeds", "1.6,3.4,6.2")).split_floats(",")
	var cols := int(_args.get("cols", "8"))
	var dt := 1.0 / 120.0
	var gap := 0.62
	var row_h := 2.0
	for r in speeds.size():
		var v: float = speeds[r]
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 0.04, cols * gap + 0.8)
		strip.mesh = bm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color("7fae4f")
		strip.material_override = sm
		strip.position = Vector3(0, -r * row_h - 0.02, -(cols - 1) * gap * 0.5)
		world.add_child(strip)
		for k in cols:
			var holder := Node3D.new()
			world.add_child(holder)
			var sc := Scout.new(Scout.DEFAULT_LOOK)
			holder.add_child(sc)
			sc.frozen = true
			var target := float(k) / cols
			var t := 0.0
			var last := 0.0
			while true:
				sc.speed = v
				sc.sprint = v > 3.5
				sc.position.z -= v * dt
				sc.animate(dt)
				t += dt
				var g: float = sc._gait_g
				var crossed := (last <= target and g > target) or (target == 0.0 and g < last)
				last = g
				if t > 2.0 and crossed:
					break
				if t > 8.0:
					break
			holder.position = Vector3(0, -r * row_h, -k * gap) - Vector3(0, 0, sc.position.z)
			_scouts.append(sc)
	var cam_mid := Vector3(0, -(speeds.size() - 1) * row_h * 0.5 + 0.7, -(cols - 1) * gap * 0.5)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = speeds.size() * row_h + 0.2
	_cam.look_at_from_position(cam_mid + Vector3(8, 0, 0), cam_mid)


# ---------------------------------------------------------------- clip: a scripted little hike, saved frame by frame
# --mode=clip --out=/dir (frames as /dir/f0000.png, 30 fps) --script=… (default: start, walk, sprint, stop, curves)
var _clip: Scout
var _clip_t := 0.0
var _clip_n := 0
var _clip_v := Vector3.ZERO
var _clip_yaw := 0.0
var _clip_len := 16.0
var _cam_pos := Vector3.ZERO
var _cam_yaw := 0.0


func _clip_setup(world: Node3D, ground: MeshInstance3D) -> void:
	(ground.mesh as PlaneMesh).size = Vector2(400, 400)
	var gm := ground.material_override as StandardMaterial3D
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.08
	nt.noise = fn
	nt.seamless = true
	nt.color_ramp = Gradient.new()
	nt.color_ramp.set_color(0, Color("5f8f3a"))
	nt.color_ramp.set_color(1, Color("9cc460"))
	gm.albedo_texture = nt
	gm.uv1_triplanar = true
	gm.uv1_world_triplanar = true
	gm.uv1_scale = Vector3(0.25, 0.25, 0.25)
	_clip = Scout.new(Scout.DEFAULT_LOOK)
	world.add_child(_clip)
	# --gear=stock,laterne: carried things, the first two held (right, left)
	if _args.has("gear"):
		var ids: PackedStringArray = str(_args["gear"]).split(",")
		var items := []
		for id in ids:
			items.append(ItemDefs.make(id))
		_clip.gear.set_items(items)
		if ids.size() > 0:
			_clip.gear.hold("R", ids[0])
		if ids.size() > 1:
			_clip.gear.hold("L", ids[1])
	_clip.frozen = true
	_clip_len = float(_args.get("len", "24"))
	_cam.fov = 40.0


## Wanted speed and turn rate over time: stand, walk, sprint, stop, stand, walk in curves, stop
func _clip_input(t: float) -> Array:
	if t < 1.2: return [0.0, 0.0, false]
	if t < 4.5: return [3.4, 0.0, false]
	if t < 8.0: return [6.2, 0.0, true]
	if t < 9.5: return [0.0, 0.0, false]
	if t < 11.0: return [1.6, 0.0, false]
	if t < 15.0: return [3.4, 1.4 * sin((t - 11.0) * 1.2), false]
	if t < 15.8: return [0.0, 0.0, false]
	if t < 18.5: return [1.6, 0.0, false, Scout.Pose.CROUCH]
	if t < 19.5: return [0.0, 0.0, false, Scout.Pose.CROUCH]
	if t < 20.3: return [0.0, 0.0, false]
	if t < 23.0: return [2.9, 0.0, false, Scout.Pose.STAND, Scout.Mood.TIRED]
	return [0.0, 0.0, false]


func _clip_step() -> bool:
	var dt := 1.0 / 30.0
	var inp := _clip_input(_clip_t)
	# like the wanderer: velocity eases towards the wanted one
	_clip_yaw += float(inp[1]) * dt
	var dir := Vector3(-sin(_clip_yaw), 0, -cos(_clip_yaw))
	_clip_v = _clip_v.lerp(dir * float(inp[0]), 1.0 - exp(-10.0 * dt))
	_clip.position += _clip_v * dt
	if _clip_v.length() > 0.4:
		_clip.rotation.y = lerp_angle(_clip.rotation.y, atan2(-_clip_v.x, -_clip_v.z), 1.0 - exp(-9.0 * dt))
	_clip.speed = _clip_v.length()
	_clip.sprint = inp[2]
	_clip.turn_rate = float(inp[1])
	_clip.pose = inp[3] if inp.size() > 3 else Scout.Pose.STAND
	_clip.mood = inp[4] if inp.size() > 4 else Scout.Mood.NORMAL
	for k in 2:
		_clip.animate(dt * 0.5)
	# camera: from the side and a little ahead, following smoothly
	_cam_yaw = _clip.rotation.y if _clip_n == 0 else lerp_angle(_cam_yaw, _clip.rotation.y, 1.0 - exp(-2.0 * dt))
	var off := Basis(Vector3.UP, _cam_yaw) * Vector3(2.5, 1.0, -0.9)
	var want := _clip.position + off
	_cam_pos = want if _clip_n == 0 else _cam_pos.lerp(want, 1.0 - exp(-8.0 * dt))
	_cam.look_at_from_position(_cam_pos, _cam_pos - off + Vector3(0, 0.7, 0))
	if _clip_n > 2:
		var img := _vp.get_texture().get_image()
		img.save_png("%s/f%04d.png" % [_args.get("out", "/tmp"), _clip_n - 3])
	_clip_n += 1
	_clip_t += dt
	return _clip_t > _clip_len
