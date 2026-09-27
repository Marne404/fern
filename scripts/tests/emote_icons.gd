extends SceneTree
## Renders the scout doing every emote to assets/emotes/<id>.png (transparent, for the emote wheel)
## plus an optional contact sheet.
## godot --path . -s res://scripts/tests/emote_icons.gd -- [--sheet=/tmp/emotes.png]

var _args := {}
var _vp: SubViewport
var _holder: Node3D
var _cam: Camera3D
var _ids: Array = []
var _i := -1
var _wait := 0
var _images := []
const SIZE := 192


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_ids = Scout.EMOTES.keys()
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE * 2, SIZE * 2)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6eef8")
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 160, 0)
	sun.light_energy = 1.6
	_vp.add_child(sun)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/emotes"))


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _i >= 0:
		var img := _vp.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://assets/emotes/%s.png" % _ids[_i]))
		_images.append(img)
	_i += 1
	if _i >= _ids.size():
		_sheet()
		return true
	for c in _holder.get_children():
		c.queue_free()
	var id: String = _ids[_i]
	var sc := Scout.new(Scout.DEFAULT_LOOK)
	sc.set_process(false)
	sc.rotation.y = -0.6 if id not in ["lie"] else 0.2
	_holder.add_child(sc)
	if id == "sit":
		sc.pose = Scout.Pose.SIT
	elif id == "lie":
		sc.pose = Scout.Pose.LIE
		sc.mood = Scout.Mood.ASLEEP
	else:
		sc.play_emote(id)
	# the most expressive moment of each emote
	var t: float = {"point": 1.0, "thumbs": 0.9, "cheer": 0.35, "laugh": 1.1, "shrug": 1.0, "facepalm": 1.2, "clap": 1.05,
		"salute": 1.0, "think": 1.4, "yawn": 1.0, "cower": 1.0, "stomp": 0.8, "look": 1.3, "wave": 1.0, "sit": 1.6, "lie": 1.6}.get(id, 1.0)
	for f in int(t * 60.0):
		sc.animate(1.0 / 60.0)
	var target := Vector3(0, 1.02, 0) if id not in ["sit", "lie"] else Vector3(0.0, 0.6, 0)
	var back := Vector3(0.3, 0.35, -2.75) if id != "lie" else Vector3(0.2, 1.6, -3.4)
	if id == "lie":
		target = Vector3(-0.1, 0.35, 0)
	_cam.look_at_from_position(target + back, target)
	_wait = 3
	return false


func _sheet() -> void:
	if not _args.has("sheet"):
		print("emote icons: %d" % _images.size())
		return
	var cols := 8
	var rows := ceili(_images.size() / float(cols))
	var sheet := Image.create(cols * SIZE, rows * SIZE, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("3f4a3a"))
	for k in _images.size():
		var img: Image = _images[k]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i((k % cols) * SIZE, (k / cols) * SIZE))
	sheet.save_png(_args["sheet"])
	print("emote icons: %d, sheet %s" % [_images.size(), _args["sheet"]])
