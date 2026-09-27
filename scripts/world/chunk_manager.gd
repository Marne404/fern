class_name ChunkManager
extends Node3D
## Loads chunks around the focus point, builds them on worker threads and
## shifts the world back to the origin at large distances (floating origin).

signal origin_shifted(shift: Vector3)
signal chunk_ready(coord: Vector2i, node: Node3D, lod: int)

const SIZE := ChunkBuilder.SIZE
const ORIGIN_STEP := 1024.0
const MAX_JOBS := 4
const FINALIZE_BUDGET_MS := 6.0

var gen: WorldGen
var lib: AssetLibrary
## World coordinates (x, z) of the local origin
var origin := Vector2.ZERO
## Focus in world coordinates (x, z) and view direction
var focus := Vector2.ZERO
var focus_dir := Vector2(0, -1)

var _chunks := {}          # Vector2i -> {"node": Node3D, "lod": int}
var _rock_disks := {}      # Vector2i -> PackedVector3Array (world x, z, radius)
var _crowns := {}          # Vector2i -> PackedFloat32Array (colorful tree crowns, see ChunkBuilder.crowns)
var _jobs := {}            # Vector2i -> {"lod": int, "task": int, "gen": int}
var _results: Array = []
var _mutex := Mutex.new()
var _generation := 0
var _plan_timer := 0.0
var _terrain_shader: Shader = preload("res://shaders/terrain.gdshader")
var _paint_noise: Texture2D = preload("res://assets/paint_noise.tres")
var _convex_cache := {}
var _water_mat: ShaderMaterial
var _water_mesh: ArrayMesh
var _mesh_cache := {}

var view_radius := 5
var near_distance := 96.0
var veg := 1.0
var grass_distance := 50.0


func setup(p_gen: WorldGen, p_lib: AssetLibrary) -> void:
	gen = p_gen
	lib = p_lib
	_read_settings()
	Settings.changed.connect(_on_setting)


func _read_settings() -> void:
	ChunkBuilder.opt_cells = Settings.values["opt_cells"]
	ChunkBuilder.opt_far_batch = Settings.values["opt_far_batch"]
	ChunkBuilder.opt_far_trees = Settings.values["opt_far_trees"]
	view_radius = Settings.values["view_distance"]
	veg = Settings.values["veg_density"]
	grass_distance = Settings.values["grass_distance"]
	RenderingServer.global_shader_parameter_set("grass_fade", Vector2(grass_distance * 0.62, grass_distance))
	near_distance = maxf(grass_distance + 40.0, 96.0)


func _on_setting(key: String) -> void:
	if key in ["view_distance", "veg_density", "grass_distance", "opt_cells", "opt_far_batch", "opt_far_trees",
			"opt_opaque_grass", "opt_small_noshadow", "opt_foliage_noaniso"]:
		_read_settings()
		if key in ["opt_opaque_grass", "opt_foliage_noaniso"]:
			lib.clear_styled()
		_mesh_cache.clear()
		rebuild_all()


## Regenerate all chunks (existing ones stay visible until the replacement is ready)
func rebuild_all() -> void:
	_generation += 1
	for c in _chunks:
		_chunks[c]["lod"] = -1


## Are all chunks with collision loaded within `radius` around the point?
func is_ready_around(world_xz: Vector2, radius := 16.0) -> bool:
	var c0 := _coord_of(world_xz - Vector2(radius, radius))
	var c1 := _coord_of(world_xz + Vector2(radius, radius))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var k := Vector2i(cx, cz)
			if not _chunks.has(k) or _chunks[k]["lod"] != 0:
				return false
	return true


## Rock footprints touching a rectangle (world xz)
func rock_disks_in(rect: Rect2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c := _coord_of(rect.get_center())
	if not _rock_disks.has(c):
		return out
	for d in (_rock_disks[c] as PackedVector3Array):
		var cx := clampf(d.x, rect.position.x, rect.end.x)
		var cz := clampf(d.y, rect.position.y, rect.end.y)
		if Vector2(d.x - cx, d.y - cz).length() < d.z:
			out.append(d)
	return out


## Colorful tree crowns nearby (local coordinates): array of [Vector3 center, radius, Color]
func crowns_near(local_pos: Vector3, radius: float) -> Array:
	var out := []
	var wp := Vector2(local_pos.x + origin.x, local_pos.z + origin.y)
	var c0 := _coord_of(wp - Vector2(radius, radius))
	var c1 := _coord_of(wp + Vector2(radius, radius))
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var arr: PackedFloat32Array = _crowns.get(Vector2i(cx, cz), PackedFloat32Array())
			for i in range(0, arr.size(), 7):
				var p := Vector2(arr[i], arr[i + 2])
				if p.distance_squared_to(wp) < radius * radius:
					out.append([Vector3(arr[i] - origin.x, arr[i + 1], arr[i + 2] - origin.y), arr[i + 3], Color(arr[i + 4], arr[i + 5], arr[i + 6])])
	return out


func loaded_count() -> int:
	return _chunks.size()


func pending_count() -> int:
	return _jobs.size()


func _coord_of(world_xz: Vector2) -> Vector2i:
	return Vector2i(floori(world_xz.x / SIZE), floori(world_xz.y / SIZE))


# ================================================================ Planning

func _process(delta: float) -> void:
	if gen == null:
		return
	_finalize_results()
	_plan_timer -= delta
	if _plan_timer <= 0.0:
		_plan_timer = 0.2
		_plan()


func _plan() -> void:
	var center := _coord_of(focus)
	var wanted := []
	var r := view_radius
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var c := center + Vector2i(dx, dz)
			var mid := Vector2((c.x + 0.5) * SIZE, (c.y + 0.5) * SIZE)
			var to := mid - focus
			var dist := maxf(to.length() - SIZE * 0.5, 0.0)
			if dist > r * SIZE:
				continue
			var lod := 0 if dist < near_distance else 1
			# hysteresis: near chunks stay near a bit longer
			if _chunks.has(c) and _chunks[c]["lod"] == 0 and dist < near_distance + 24.0:
				lod = 0
			var have: int = _chunks[c]["lod"] if _chunks.has(c) else -2
			if have == lod:
				continue
			if _jobs.has(c) and _jobs[c]["lod"] == lod and _jobs[c]["gen"] == _generation:
				continue
			# priority: proximity, view direction, missing chunks before LOD changes
			var facing := to.normalized().dot(focus_dir) if to.length() > 1.0 else 1.0
			var prio := dist - facing * 40.0 + (0.0 if have == -2 else 60.0)
			wanted.append([prio, c, lod])
	wanted.sort_custom(func(a, b): return a[0] < b[0])
	for w in wanted:
		if _jobs.size() >= MAX_JOBS:
			break
		var c: Vector2i = w[1]
		if _jobs.has(c):
			continue
		_start_job(c, w[2])
	# remove what's outside the view distance
	var remove := []
	for c in _chunks:
		var mid := Vector2((c.x + 0.5) * SIZE, (c.y + 0.5) * SIZE)
		if (mid - focus).length() - SIZE * 0.7 > (r + 1) * SIZE:
			remove.append(c)
	for c in remove:
		_chunks[c]["node"].queue_free()
		_chunks.erase(c)
		_rock_disks.erase(c)
		_crowns.erase(c)


func _start_job(c: Vector2i, lod: int) -> void:
	var g := _generation
	var task := WorkerThreadPool.add_task(_job.bind(c, lod, g, veg), false, "chunk")
	_jobs[c] = {"lod": lod, "task": task, "gen": g}


func _job(c: Vector2i, lod: int, g: int, v: float) -> void:
	var data := ChunkBuilder.new(gen, c, lod, v).build()
	data["coord"] = c
	data["lod"] = lod
	data["gen"] = g
	_mutex.lock()
	_results.append(data)
	_mutex.unlock()


# ================================================================ Building on the main thread

func _finalize_results() -> void:
	var t0 := Time.get_ticks_usec()
	while true:
		_mutex.lock()
		var data = _results.pop_front() if not _results.is_empty() else null
		_mutex.unlock()
		if data == null:
			break
		var c: Vector2i = data["coord"]
		if _jobs.has(c):
			WorkerThreadPool.wait_for_task_completion(_jobs[c]["task"])
			_jobs.erase(c)
		if data["gen"] == _generation or not _chunks.has(c):
			_install(data)
		if (Time.get_ticks_usec() - t0) / 1000.0 > FINALIZE_BUDGET_MS:
			break


func _install(data: Dictionary) -> void:
	var c: Vector2i = data["coord"]
	var mid := Vector2((c.x + 0.5) * SIZE, (c.y + 0.5) * SIZE)
	if (mid - focus).length() - SIZE * 0.7 > (view_radius + 1) * SIZE:
		return
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [c.x, c.y]
	node.position = Vector3(c.x * SIZE - origin.x, 0.0, c.y * SIZE - origin.y)
	node.add_child(_make_terrain(data))
	_make_instances(node, data)
	for w in data.get("water", []):
		node.add_child(_make_water(w))
	if data.has("collision"):
		node.add_child(_make_collision(data))
	add_child(node)
	if _chunks.has(c):
		_chunks[c]["node"].queue_free()
	_chunks[c] = {"node": node, "lod": data["lod"]}
	_rock_disks[c] = data.get("rock_disks", PackedVector3Array())
	_crowns[c] = data.get("crowns", PackedFloat32Array())
	chunk_ready.emit(c, node, data["lod"])


func _make_terrain(data: Dictionary) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["verts"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_CUSTOM0] = data["custom0"]
	arrays[Mesh.ARRAY_CUSTOM1] = data["custom1"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var fmt := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, fmt)
	var pi: Dictionary = data["path_image"]
	var img := Image.create_from_data(pi["res"], pi["res"], false, Image.FORMAT_R8, pi["bytes"])
	var mat := ShaderMaterial.new()
	mat.shader = _terrain_shader
	mat.set_shader_parameter("path_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("path_res", float(pi["res"]))
	mat.set_shader_parameter("paint_noise", _paint_noise)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


## Mesh + settings for an instance key "biome/layer/style/model"
func _mesh_for(key: String) -> Dictionary:
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var parts := key.split("/")
	if parts[0] == "under":
		var uinfo := {"mesh": lib.mesh(parts[1], {"leaves": BiomeDefs.leaves(Color(0.2, 0.45, 0.1), Color(0.55, 0.8, 0.28), {"sphere_normals": 0.9}), "stiffness": 6.0}),
			"kind": "detail", "shadows": true, "vis": 110.0}
		_mesh_cache[key] = uinfo
		return uinfo
	if parts[0] == "shore":
		var sinfo := {"mesh": lib.mesh(parts[1]), "kind": "grass" if parts[1].begins_with("Grass") else "detail",
			"shadows": false, "vis": 70.0}
		_mesh_cache[key] = sinfo
		return sinfo
	var layer: Dictionary = gen.biomes[int(parts[0])]["layers"][int(parts[1])]
	var styles: Array = layer.get("styles", [{}])
	var all_styles: Array = styles + layer.get("region_styles", [])
	var style: Dictionary = all_styles[int(parts[2])] if int(parts[2]) < all_styles.size() else {}
	var kind: String = layer["kind"]
	var info := {
		"mesh": lib.mesh(parts[3], style),
		"kind": kind,
		"shadows": kind in ["tree", "rock"] or layer.get("shadows", false)
			or (not Settings.values["opt_small_noshadow"] and kind in ["detail", "path_stones"]),
		"vis": layer.get("vis", 0.0),
	}
	_mesh_cache[key] = info
	return info


func _make_instances(node: Node3D, data: Dictionary) -> void:
	var inst: Dictionary = data["instances"]
	var counts: Dictionary = data["counts"]
	for key in inst:
		var info := _mesh_for(key.get_slice("#", 0))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = info["mesh"]
		mm.instance_count = counts[key]
		mm.buffer = inst[key]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if info["shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var vis: float = grass_distance if info["kind"] == "grass" else info["vis"]
		if info["kind"] == "grass" or info["kind"] == "cluster":
			# hard limit just behind the shader thinning, without cell blending
			mmi.visibility_range_end = grass_distance * (1.0 if info["kind"] == "grass" else 1.25) + 24.0
			node.add_child(mmi)
			continue
		if vis > 0.0:
			var model: String = key.get_slice("#", 0).get_slice("/", key.get_slice("#", 0).get_slice_count("/") - 1)
			mmi.visibility_range_end = vis + ChunkBuilder.cell_size(model) * 0.5
			mmi.visibility_range_end_margin = 12.0
			mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		node.add_child(mmi)


func _make_water(w: Dictionary) -> MeshInstance3D:
	if _water_mat == null:
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = preload("res://shaders/water.gdshader")
		_water_mat.set_shader_parameter("noise_tex", _paint_noise)
		# unit disc with rings so the edge is soft
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 48
		for i in seg:
			var a0 := i * TAU / seg
			var a1 := (i + 1) * TAU / seg
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(cos(a1), 0, sin(a1)))
			st.add_vertex(Vector3(cos(a0), 0, sin(a0)))
		_water_mesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = _water_mesh
	mi.material_override = _water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var r: float = w["radius"] * 1.6   # irregular shore: the terrain covers the rest
	mi.transform = Transform3D(Basis().scaled(Vector3(r, 1.0, r)), w["pos"])
	mi.set_instance_shader_parameter("shallow_color", w["shallow"])
	mi.set_instance_shader_parameter("deep_color", w["deep"])
	return mi


const TERRAIN_LAYER := 8   # bit 4: terrain only (for ground height rays)


func _make_collision(data: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | TERRAIN_LAYER
	var hm := HeightMapShape3D.new()
	hm.map_width = 65
	hm.map_depth = 65
	hm.map_data = data["collision"]
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.position = Vector3(SIZE * 0.5, 0.0, SIZE * 0.5)
	body.add_child(cs)
	# trunks and rocks in their own body: ground height rays (TERRAIN_LAYER) only hit the terrain
	var props := StaticBody3D.new()
	props.collision_layer = 1
	body.add_child(props)
	for t in data["trunks"]:
		# hull of the real lower trunk (including the lean of gnarly trees)
		var hull := lib.trunk_hull(t[4])
		var txf: Transform3D = t[3]
		var tp2 := PackedVector3Array()
		tp2.resize(hull.size())
		for i in hull.size():
			tp2[i] = txf * hull[i]
		var tshape := ConvexPolygonShape3D.new()
		tshape.points = tp2
		var tcs := CollisionShape3D.new()
		tcs.shape = tshape
		props.add_child(tcs)
	for r in data["rocks"]:
		var pts := _convex_points(r[0])
		var xf: Transform3D = r[1]
		var tp := PackedVector3Array()
		tp.resize(pts.size())
		for i in pts.size():
			tp[i] = xf * pts[i]
		var shape := ConvexPolygonShape3D.new()
		shape.points = tp
		var rcs := CollisionShape3D.new()
		rcs.shape = shape
		props.add_child(rcs)
	return body


func _convex_points(model: String) -> PackedVector3Array:
	if not _convex_cache.has(model):
		var shape := lib.raw_mesh(model).create_convex_shape(true, true)
		_convex_cache[model] = shape.points
	return _convex_cache[model]


# ================================================================ Floating origin

## Checks whether the focus (local) is far from the origin and then shifts everything.
## Returns the shift (local, already applied to the chunks).
func maybe_shift_origin(local_focus: Vector3) -> Vector3:
	var sx := 0.0
	var sz := 0.0
	if absf(local_focus.x) > ORIGIN_STEP:
		sx = snappedf(local_focus.x, ORIGIN_STEP)
	if absf(local_focus.z) > ORIGIN_STEP:
		sz = snappedf(local_focus.z, ORIGIN_STEP)
	if sx == 0.0 and sz == 0.0:
		return Vector3.ZERO
	var shift := Vector3(sx, 0.0, sz)
	origin += Vector2(sx, sz)
	for c in _chunks:
		_chunks[c]["node"].position -= shift
	RenderingServer.global_shader_parameter_set("world_origin", origin)
	origin_shifted.emit(shift)
	return shift


func local_to_world(local: Vector3) -> Vector3:
	return local + Vector3(origin.x, 0.0, origin.y)


func world_to_local(world: Vector3) -> Vector3:
	return world - Vector3(origin.x, 0.0, origin.y)


## Height at a world point (exactly from the formula, not the mesh)
func height_at_world(x: float, z: float) -> float:
	return gen.height(x, z)


## Height at a local point
func height_local(x: float, z: float) -> float:
	return gen.height(x + origin.x, z + origin.y)


## Actual height of the ground collision (local). Falls back to the formula if nothing is loaded.
func ground_y(x: float, z: float) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 3000.0, z), Vector3(x, -3000.0, z), TERRAIN_LAYER)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return height_local(x, z)
	return (hit["position"] as Vector3).y


func wait_all() -> void:
	for c in _jobs:
		WorkerThreadPool.wait_for_task_completion(_jobs[c]["task"])


func _exit_tree() -> void:
	wait_all()
