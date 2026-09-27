extends SceneTree
## Renders every item model to assets/icons/<id>.png (transparent, for the UI and the website)
## and a contact sheet of all models.
## godot --path . -s res://scripts/tests/item_icons.gd -- [--sheet=/tmp/items.png] [--size=160]

var _args := {}
var _vp: SubViewport
var _holder: Node3D
var _cam: Camera3D
var _ids: Array = []
var _i := -1
var _wait := 0
var _images := []
var _size := 160


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_size = int(_args.get("size", "160"))
	_ids = ItemDefs.ITEMS.keys()
	_vp = SubViewport.new()
	_vp.size = Vector2i(_size * 2, _size * 2)
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.own_world_3d = true
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6eef8")
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 150, 0)
	sun.light_energy = 1.5
	_vp.add_child(sun)
	_holder = Node3D.new()
	_vp.add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 24.0
	_vp.add_child(_cam)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/icons"))


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _i >= 0:
		var img := _vp.get_texture().get_image()
		img.resize(_size, _size, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("res://assets/icons/%s.png" % _ids[_i]))
		_images.append(img)
	_i += 1
	if _i >= _ids.size():
		_sheet()
		return true
	for c in _holder.get_children():
		c.queue_free()
	var mi := MeshInstance3D.new()
	mi.mesh = ItemModels.mesh(_ids[_i])
	_holder.add_child(mi)
	# frame the model: three-quarter view from the front-top
	var ab := mi.mesh.get_aabb()
	var r := ab.size.length() * 0.5
	var dist := r / sin(deg_to_rad(_cam.fov * 0.5)) * 1.08
	var dir := Vector3(0.55, 0.75, -1.0).normalized()
	_cam.look_at_from_position(ab.get_center() + dir * dist, ab.get_center())
	_wait = 3
	return false


func _sheet() -> void:
	if not _args.has("sheet"):
		print("icons: %d" % _images.size())
		return
	var cols := 10
	var rows := ceili(_images.size() / float(cols))
	var cell := _size + 24
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("f3e7cc"))
	for k in _images.size():
		var img: Image = _images[k]
		img.convert(Image.FORMAT_RGBA8)
		sheet.blend_rect(img, Rect2i(0, 0, _size, _size), Vector2i((k % cols) * cell + 12, (k / cols) * cell + 12))
	sheet.save_png(_args["sheet"])
	print("icons: %d, sheet %s" % [_images.size(), _args["sheet"]])
