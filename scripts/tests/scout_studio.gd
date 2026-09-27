extends SceneTree
## Renders scouts in a small studio scene and saves a picture (for looking at the character).
## godot --path . --resolution 1600x900 -s res://scripts/tests/scout_studio.gd -- --out=/tmp/x.png --mode=lineup
## Modes: lineup, poses, face, back, walk

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
				lk["hat"] = i
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
				{"skin": 0, "outfit": 0, "scarf": 0, "hat": 1, "hat_color": 10, "pack": 1, "face": 0},
				{"skin": 5, "outfit": 2, "scarf": 2, "hat": 3, "hat_color": 11, "pack": 0, "face": 1},
				{"skin": 3, "outfit": 1, "scarf": 5, "hat": 2, "hat_color": 8, "pack": 6, "face": 0},
				{"skin": 7, "outfit": 4, "scarf": 7, "hat": 4, "hat_color": 0, "pack": 4, "face": 3},
				{"skin": 1, "outfit": 3, "scarf": 3, "hat": 0, "hat_color": 1, "pack": 7, "face": 2},
			]
			var xs := [0.0, -1.0, 1.0, -1.95, 1.95]
			var zs := [0.0, 0.35, 0.3, 0.8, 0.75]
			for i in looks.size():
				var sc := Scout.new(looks[i])
				sc.position = Vector3(xs[i], 0, zs[i])
				sc.rotation.y = xs[i] * 0.12
				if i == 0 or i == 3:
					sc.wave(100.0)
				if i == 4:
					sc.speed = 0.0
				world.add_child(sc)
				_scouts.append(sc)
			_cam.fov = 28.0
			_cam.look_at_from_position(Vector3(0, 1.25, -8.2), Vector3(0, 0.82, 0.3))
		"back":
			for i in 3:
				var sc := Scout.new(Scout.random_look() if i > 0 else Scout.DEFAULT_LOOK)
				sc.position = Vector3((i - 1) * 1.1, 0, 0)
				sc.rotation.y = PI + (i - 1) * 0.5
				world.add_child(sc)
				_scouts.append(sc)
			_cam.look_at_from_position(Vector3(0, 1.5, -4.8), Vector3(0, 0.9, 0))
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


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == int(_args.get("frames", "40")):
		var img := _vp.get_texture().get_image()
		img.save_png(_args.get("out", "/tmp/scout.png"))
		print("saved ", _args.get("out", "/tmp/scout.png"))
		return true
	return false
