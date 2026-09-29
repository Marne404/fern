class_name Impostors
extends Node
## Impostors for distant trees.
##
## Every tree (model × style) is baked once, in the background, into two small atlases: 8 views around the tree
## (every 45°, seen slightly from above), albedo from an unshaded render and normals from the normal buffer.
## Distant tree batches get a sibling MultiMesh of billboards with the same instance data; inside the impostor
## band every tree hands over from its mesh to its impostor at its own random distance (see wind.gdshaderinc).
## Until a tree's impostor is ready its far mesh simply stays.

const FRAMES := 8
const CELL_PX := 128          # height of one view in pixels (a tree at 200 m is ~60 px tall on 1080p)
const ELEVATION := 0.1        # the views are taken from 6° above
const EVICT_AFTER := 90.0     # textures of trees that are no longer anywhere in view are freed after this (s)

var lib: AssetLibrary
## the mesh material to hand over with (same key as the chunk manager: "biome/layer/style/model")
var mesh_for: Callable

var _baked := {}        # key → {albedo, normal, quad, material, used}
var _queue: Array[String] = []
var _users := {}        # key → Array of [far MultiMeshInstance3D, impostor MultiMeshInstance3D or null]
var _world: World3D
var _vp_albedo: SubViewport
var _vp_normal: SubViewport
var _vp_mask: SubViewport
var _cams: Array[Camera3D] = []
var _holder: Node3D
var _baking := ""
var _bake_frames := 0
var _bake_info := {}
var _tone_img: Image
var _evict_timer := 10.0
var enabled := true
var band := Vector2.ZERO


func _ready() -> void:
	_world = World3D.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	_world.environment = env
	# albedo and normals see the trees (layer 1), the mask sees their bark-mask twins (layer 2)
	for i in 3:
		var mode := Viewport.DEBUG_DRAW_NORMAL_BUFFER if i == 1 else Viewport.DEBUG_DRAW_UNSHADED
		var vp := SubViewport.new()
		vp.world_3d = _world
		vp.transparent_bg = true
		vp.debug_draw = mode
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.size = Vector2i(64, 64)
		add_child(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.cull_mask = 2 if i == 2 else 1
		vp.add_child(cam)
		_cams.append(cam)
		match i:
			0: _vp_albedo = vp
			1: _vp_normal = vp
			2: _vp_mask = vp
	_holder = Node3D.new()
	_vp_albedo.add_child(_holder)
	apply_settings()
	Settings.changed.connect(func(k):
		if k in ["impostors", "impostor_distance", "shadows", "shadow_range"]:
			apply_settings())


## Impostor band from the settings; never inside the shadow distance (impostors cast no shadows)
func apply_settings() -> void:
	enabled = Settings.values.get("impostors", true)
	var d: float = Settings.values.get("impostor_distance", 180.0)
	var sp := Settings.shadow_params()
	if sp["enabled"]:
		d = maxf(d, float(sp["distance"]) + 15.0)
	band = Vector2(d, d * 1.25) if enabled else Vector2.ZERO
	RenderingServer.global_shader_parameter_set("impostor_band", band)
	if not enabled:
		for key in _baked.keys():
			_evict(key)


## A far tree batch was built: give it an impostor (now or as soon as it is baked)
func attach(far_mmi: MultiMeshInstance3D, key: String) -> void:
	if not enabled:
		return
	if not _users.has(key):
		_users[key] = []
	var entry := [far_mmi, null]
	_users[key].append(entry)
	if _baked.has(key):
		_make_impostor(key, entry)
	elif key != _baking and not _queue.has(key):
		_queue.append(key)


func baked_count() -> int:
	return _baked.size()


func pending_count() -> int:
	return _queue.size() + (1 if _baking != "" else 0)


# ---------------------------------------------------------------- baking

func _process(delta: float) -> void:
	if _baking != "":
		_bake_frames += 1
		# the views are drawn in the frame after setup; read them one frame later to be safe
		if _bake_frames >= 3:
			_finish_bake()
	elif not _queue.is_empty():
		_start_bake(_queue.pop_front())
	_evict_timer -= delta
	if _evict_timer <= 0.0:
		_evict_timer = 10.0
		_cleanup()


func _start_bake(key: String) -> void:
	# baked from the far mesh it replaces (thinned, larger leaf cards): same silhouette and fullness
	var mesh: Mesh = mesh_for.call(key + "@far")
	if mesh == null:
		return
	var aabb := mesh.get_aabb()
	# radius around the trunk (the rotation must fit into the cell) and height
	var r := 0.0
	for i in 8:
		var c := aabb.get_endpoint(i)
		r = maxf(r, Vector2(c.x, c.z).length())
	var y0 := aabb.position.y
	var y1 := aabb.end.y
	var ce := cos(ELEVATION)
	var se := sin(ELEVATION)
	var half_h := (y1 - y0) * 0.5 * ce + r * se
	var cell_w_m := 2.0 * r * 1.04
	var cell_h_m := 2.0 * half_h * 1.04
	# the longer side of a view gets CELL_PX pixels
	var px_per_m := float(CELL_PX) / maxf(cell_h_m, cell_w_m)
	var cw := maxi(16, roundi(cell_w_m * px_per_m))
	var ch := maxi(16, roundi(cell_h_m * px_per_m))
	var yc := (y0 + y1) * 0.5
	for c in _holder.get_children():
		c.free()
	# the bark-mask twins draw with copies of the materials that have bake_mask set (a plain uniform: as an
	# instance uniform every tree, bush and grass batch in the world would take a slot of the global buffer)
	var mask_mats: Array[Material] = []
	for s in mesh.get_surface_count():
		var mat := mesh.surface_get_material(s)
		if mat is ShaderMaterial:
			mat = mat.duplicate()
			(mat as ShaderMaterial).set_shader_parameter("bake_mask", 1.0)
		mask_mats.append(mat)
	for i in FRAMES:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# view i sees the tree from its local direction (sin a, cos a): turn the tree by -a
		mi.transform = Transform3D(Basis(Vector3.UP, -i * TAU / FRAMES), Vector3((i - (FRAMES - 1) * 0.5) * cell_w_m, 0.0, 0.0))
		mi.layers = 1
		_holder.add_child(mi)
		var mask := mi.duplicate() as MeshInstance3D
		mask.layers = 2
		for s in mask_mats.size():
			mask.set_surface_override_material(s, mask_mats[s])
		_holder.add_child(mask)
	var size := Vector2i(cw * FRAMES, ch)
	for vp: SubViewport in [_vp_albedo, _vp_normal, _vp_mask]:
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for cam in _cams:
		cam.size = cell_h_m
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		cam.near = 0.05
		cam.far = 400.0
		var target := Vector3(0.0, yc, 0.0)
		cam.transform = Transform3D(Basis(Vector3.RIGHT, -ELEVATION), target + Vector3(0.0, se, ce) * 150.0)
	_baking = key
	_bake_frames = 0
	_bake_info = {"cell_w": cell_w_m, "cell_h": cell_h_m, "yc": yc}


func _finish_bake() -> void:
	var key := _baking
	_baking = ""
	var a := _vp_albedo.get_texture().get_image()
	var n := _vp_normal.get_texture().get_image()
	var m := _vp_mask.get_texture().get_image()
	for vp: SubViewport in [_vp_albedo, _vp_normal, _vp_mask]:
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for c in _holder.get_children():
		c.queue_free()
	if a == null or n == null or a.is_empty():
		return
	a.convert(Image.FORMAT_RGBA8)
	n.convert(Image.FORMAT_RGBA8)
	# test helper: --impdump=/dir saves the raw views
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--impdump="):
			var dir := arg.trim_prefix("--impdump=")
			var fname := key.replace("/", "_")
			a.save_png("%s/%s_albedo.png" % [dir, fname])
			n.save_png("%s/%s_normal.png" % [dir, fname])
	# spread the colors into the transparent border so mipmaps don't darken the silhouette
	a.fix_alpha_edges()
	n.fix_alpha_edges()
	a.generate_mipmaps()
	n.generate_mipmaps()
	m.convert(Image.FORMAT_L8)
	m.generate_mipmaps()
	var info := _bake_info
	# quad in tree space: centered on the trunk, as tall as the view (the slight tilt of the views stretched out)
	var w: float = info["cell_w"]
	var h: float = info["cell_h"] / cos(ELEVATION)
	var yc: float = info["yc"]
	var quad := _quad(w, yc - h * 0.5, yc + h * 0.5)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/impostor.gdshader")
	mat.set_shader_parameter("albedo_atlas", ImageTexture.create_from_image(a))
	mat.set_shader_parameter("normal_atlas", ImageTexture.create_from_image(n))
	mat.set_shader_parameter("bark_atlas", ImageTexture.create_from_image(m))
	mat.set_shader_parameter("frames", float(FRAMES))
	mat.set_shader_parameter("elevation", ELEVATION)
	mat.set_shader_parameter("bake_tone", 0.9 + 0.2 * _tone_at(Vector2(0.0, 0.0)))
	var style_mat := _first_foliage_material(mesh_for.call(key + "@far"))
	if style_mat:
		mat.set_shader_parameter("translucency", style_mat.get_shader_parameter("translucency"))
		mat.set_shader_parameter("wrap", style_mat.get_shader_parameter("wrap"))
	_baked[key] = {"quad": quad, "material": mat, "used": Time.get_ticks_msec()}
	_set_cut(key, true)
	for entry in _users.get(key, []):
		_make_impostor(key, entry)


## The large-scale color noise that the foliage shader applied at the bake spot (world origin at bake time)
func _tone_at(_xz: Vector2) -> float:
	if _tone_img == null:
		var noise: Texture2D = load("res://assets/wind_noise.tres")
		_tone_img = noise.get_image() if noise else null
		if _tone_img == null:
			return 0.5
		_tone_img.decompress()
	var uv := (_world_origin() + _xz) * 0.004
	var x := posmod(int(uv.x * _tone_img.get_width()), _tone_img.get_width())
	var y := posmod(int(uv.y * _tone_img.get_height()), _tone_img.get_height())
	return _tone_img.get_pixel(x, y).r


func _world_origin() -> Vector2:
	var cm := get_parent() as ChunkManager
	return cm.origin if cm else Vector2.ZERO


func _first_foliage_material(mesh: Mesh) -> ShaderMaterial:
	if mesh == null:
		return null
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as ShaderMaterial
		if m and m.shader and m.shader.code.contains("foliage_body"):
			return m
	return null


func _quad(w: float, y0: float, y1: float) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-w * 0.5, y1, 0), Vector3(w * 0.5, y1, 0), Vector3(w * 0.5, y0, 0), Vector3(-w * 0.5, y0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# ---------------------------------------------------------------- instances

func _make_impostor(key: String, entry: Array) -> void:
	# chunks come and go: the far batch may already be gone
	if not is_instance_valid(entry[0]) or is_instance_valid(entry[1]):
		return
	var far: MultiMeshInstance3D = entry[0]
	var b: Dictionary = _baked[key]
	b["used"] = Time.get_ticks_msec()
	_set_cut(key, true)
	var src := far.multimesh
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = b["quad"]
	mm.instance_count = src.instance_count
	mm.buffer = src.buffer
	var imp := MultiMeshInstance3D.new()
	imp.multimesh = mm
	imp.material_override = b["material"]
	imp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# billboards turn in the shader: cull with the tree batch's own box
	imp.custom_aabb = src.get_aabb().grow(4.0)
	# whole batches that are entirely in front of / behind the band are skipped (chunks are 64 m)
	imp.visibility_range_begin = maxf(band.x - 100.0, 0.0)
	far.visibility_range_end = band.y + 100.0
	far.get_parent().add_child(imp)
	entry[1] = imp


## Hand-over test on or off in the far mesh's materials (only when its impostor exists)
func _set_cut(key: String, on: bool) -> void:
	var mesh: Mesh = mesh_for.call(key + "@far")
	if mesh == null:
		return
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s) as ShaderMaterial
		if m:
			m.set_shader_parameter("impostor_cut", on)


func _cleanup() -> void:
	var now := Time.get_ticks_msec()
	for key in _users.keys():
		var live := []
		for e in _users[key]:
			if is_instance_valid(e[0]):
				live.append(e)
		if live.is_empty():
			_users.erase(key)
		else:
			_users[key] = live
			if _baked.has(key):
				_baked[key]["used"] = now
	for key in _baked.keys():
		if not _users.has(key) and now - int(_baked[key]["used"]) > EVICT_AFTER * 1000.0:
			_evict(key)


func _evict(key: String) -> void:
	_set_cut(key, false)
	for e in _users.get(key, []):
		if is_instance_valid(e[1]):
			e[1].queue_free()
		if is_instance_valid(e[0]):
			e[0].visibility_range_end = 0.0
		e[1] = null
	_baked.erase(key)
