class_name GrassField
extends Node3D
## Dense carpet of individual grass blades around the camera (High/Ultra).
## Tiles of 8 m with 16 patches of 2 m each (one prebuilt blade mesh, mirrored against repetition).
## Near tiles get the dense mesh, distant ones a sparser one with wider blades.

const TILE := 8.0
const PATCH := 2.0
const BUILD_PER_FRAME := 6
const BUILD_BUDGET_MS := 3.0   # limit tile building per frame (prevents hitches)

# level -> [blades per m² near, near radius, far radius]
const LEVELS := {
	1: [34.0, 16.0, 34.0],
	2: [60.0, 20.0, 46.0],
	3: [100.0, 26.0, 62.0],
}

var gen: WorldGen
var world: ChunkManager
var level := 0
var _range := 1.0
var _meshes: Array[ArrayMesh] = []
var _materials: Array[ShaderMaterial] = []
var _tiles := {}          # Vector2i -> {"node": MultiMeshInstance3D, "lod": int}
var _rng := RandomNumberGenerator.new()


func setup(p_gen: WorldGen, p_world: ChunkManager) -> void:
	gen = p_gen
	world = p_world
	_apply_level()
	Settings.changed.connect(func(k): if k in ["grass_blades", "preset", "blade_range"]: _apply_level())


## Blade density and radii of the current level, radii scaled by the "Grass blade range" setting
func _spec() -> Array:
	var sp: Array = (LEVELS[level] as Array).duplicate()
	sp[1] *= _range
	sp[2] *= _range
	return sp


func _apply_level() -> void:
	var l: int = Settings.values["grass_blades"]
	var rng_mul: float = Settings.values["blade_range"]
	if l == level and rng_mul == _range and not _meshes.is_empty():
		return
	level = l
	_range = rng_mul
	for t in _tiles:
		_tiles[t]["node"].queue_free()
	_tiles.clear()
	_meshes.clear()
	_materials.clear()
	if level == 0:
		return
	var spec := _spec()
	_meshes.append(_patch_mesh(int(spec[0] * PATCH * PATCH), 0.045, 3, 11))
	_meshes.append(_patch_mesh(int(spec[0] * PATCH * PATCH * 0.22), 0.1, 2, 23))
	for i in 2:
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/grass_blades.gdshader")
		m.set_shader_parameter("patch_size", PATCH)
		m.set_shader_parameter("blade_height", 0.55)
		m.set_shader_parameter("fade_start", spec[2] - 16.0)
		m.set_shader_parameter("fade_end", spec[2])
		m.set_shader_parameter("near_radius", spec[1])
		_materials.append(m)


## A 2×2 m patch full of blades. Geometry with unit height, the shape comes from the shader.
func _patch_mesh(count: int, width: float, segments: int, seed_value: int) -> ArrayMesh:
	_rng.seed = seed_value
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var custom := PackedFloat32Array()
	var idx := PackedInt32Array()
	for b in count:
		var root := Vector2(_rng.randf() * PATCH, _rng.randf() * PATCH)
		var a := _rng.randf() * TAU
		var perp := Vector3(cos(a), 0.0, sin(a))
		var facing := Vector3(-sin(a), 0.0, cos(a))
		var w := width * _rng.randf_range(0.7, 1.3)
		var rnd := [_rng.randf(), _rng.randf(), _rng.randf(), _rng.randf()]
		var base := verts.size()
		for s in segments:
			var t := float(s) / segments
			var half := w * 0.5 * (1.0 - pow(t, 1.4))
			for side in [-1.0, 1.0]:
				verts.append(Vector3(root.x, t, root.y) + perp * side * half)
				normals.append((facing + perp * side * 0.35).normalized())
				uvs.append(Vector2(side * 0.5 + 0.5, t))
				uv2s.append(root)
				colors.append(Color.WHITE)
				custom.append_array(rnd)
		# tip
		verts.append(Vector3(root.x, 1.0, root.y))
		normals.append(facing)
		uvs.append(Vector2(0.5, 1.0))
		uv2s.append(root)
		colors.append(Color.WHITE)
		custom.append_array(rnd)
		for s in segments - 1:
			var v := base + s * 2
			idx.append_array([v, v + 1, v + 2, v + 1, v + 3, v + 2])
		var last := base + (segments - 1) * 2
		idx.append_array([last, last + 1, last + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
		Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return mesh


# ================================================================ Tiles

func update(cam_local: Vector3) -> void:
	if level == 0 or gen == null:
		return
	var spec := _spec()
	var near_r: float = spec[1]
	var far_r: float = spec[2]
	var cam_w := world.local_to_world(cam_local)
	var ct := Vector2i(floori(cam_w.x / TILE), floori(cam_w.z / TILE))
	var reach := int(ceil(far_r / TILE)) + 1
	var wanted := []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := ct + Vector2i(dx, dz)
			var mid := Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)
			var d := (mid - Vector2(cam_w.x, cam_w.z)).length() - TILE * 0.7
			if d > far_r:
				continue
			var lod := 0 if d < near_r else 1
			if _tiles.has(t) and _tiles[t]["lod"] == lod:
				continue
			wanted.append([d, t, lod])
	wanted.sort_custom(func(a, b): return a[0] < b[0])
	var t0 := Time.get_ticks_usec()
	for i in mini(wanted.size(), BUILD_PER_FRAME):
		if i > 0 and Settings.values["opt_blade_budget"] and (Time.get_ticks_usec() - t0) / 1000.0 > BUILD_BUDGET_MS:
			break
		var t: Vector2i = wanted[i][1]
		var lod: int = wanted[i][2]
		var node := _build_tile(t, lod)
		if _tiles.has(t) and _tiles[t]["node"]:
			_tiles[t]["node"].queue_free()
		_tiles[t] = {"node": node, "lod": lod}
	# remove what's too far away
	var remove := []
	for t in _tiles:
		var mid := Vector2((t.x + 0.5) * TILE, (t.y + 0.5) * TILE)
		if (mid - Vector2(cam_w.x, cam_w.z)).length() - TILE * 0.7 > far_r + TILE:
			remove.append(t)
	for t in remove:
		if _tiles[t]["node"]:
			_tiles[t]["node"].queue_free()
		_tiles.erase(t)


func _build_tile(t: Vector2i, lod: int) -> MultiMeshInstance3D:
	var wx := t.x * TILE
	var wz := t.y * TILE
	var n := int(TILE / PATCH) + 1
	# ground heights at all patch corners (one row record per z)
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var rows := []
	for j in n:
		var r := gen.row(wz + j * PATCH)
		rows.append(r)
		for i in n:
			hs[j * n + i] = gen.height_in_row(wx + i * PATCH, r)
	var center_row: Dictionary = rows[n / 2]
	var blades := _blend_blades(rows[0], wx + TILE * 0.5)
	var blades_b := _blend_blades(rows[n - 1], wx + TILE * 0.5)
	if blades["height"] < 0.03 and blades_b["height"] < 0.03:
		return null

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _meshes[lod]
	var count := (n - 1) * (n - 1)
	mm.instance_count = count
	var k := 0
	for pj in n - 1:
		for pi in n - 1:
			var h := func(i: int, j: int) -> float: return hs[(pj + j) * n + (pi + i)]
			var hsh := hash([t.x, t.y, pi, pj])
			var fx := hsh & 1 == 1
			var fz := hsh & 2 == 2
			# the mesh's local corner (0,0) corresponds to a different world corner depending on mirroring
			var ix0 := 1 if fx else 0
			var iz0 := 1 if fz else 0
			var o: float = h.call(ix0, iz0)
			var c := Color(0.0, h.call(1 - ix0, iz0) - o, h.call(ix0, 1 - iz0) - o, h.call(1 - ix0, 1 - iz0) - o)
			var b := Basis().scaled(Vector3(-1.0 if fx else 1.0, 1.0, -1.0 if fz else 1.0))
			# no blades in a brook bed
			var pr: Dictionary = rows[pj]
			for bk in pr["brooks"]:
				var bc := gen.brook_center(bk, pr)
				if bc.x != INF and absf(wx + (pi + 0.5) * PATCH - bc.x) / pr["inv_len"] < float(bk["half"]) * bc.y + PATCH * 0.5 + 0.3:
					b = Basis().scaled(Vector3.ZERO)
			var origin := Vector3((pi + ix0) * PATCH, o, (pj + iz0) * PATCH)
			mm.set_instance_transform(k, Transform3D(b, origin))
			mm.set_instance_custom_data(k, c)
			k += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _materials[lod]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hmin := INF
	var hmax := -INF
	for v in hs:
		hmin = minf(hmin, v)
		hmax = maxf(hmax, v)
	mmi.custom_aabb = AABB(Vector3(-1.5, hmin - 0.5, -1.5), Vector3(TILE + 3.0, hmax - hmin + 2.5, TILE + 3.0))
	add_child(mmi)
	mmi.position = Vector3(wx - world.origin.x, 0.0, wz - world.origin.y)

	# tile parameters: colors, path line, pond
	mmi.set_instance_shader_parameter("root_color", blades["root"])
	mmi.set_instance_shader_parameter("tip_color", blades["tip"])
	mmi.set_instance_shader_parameter("tip_color2", blades["tip2"])

	# second color row at the tile end: smooth transitions at biome borders instead of tiles
	mmi.set_instance_shader_parameter("root_color_b", blades_b["root"])
	mmi.set_instance_shader_parameter("tip_color_b", blades_b["tip"])
	mmi.set_instance_shader_parameter("tip_color2_b", blades_b["tip2"])

	mmi.set_instance_shader_parameter("tile_z", Vector2(wz, TILE))
	mmi.set_instance_shader_parameter("params", Vector4(blades["height"], blades_b["height"], 1.0 if lod == 0 else 0.0, center_row["half_w"]))
	var slope := gen.path_slope(center_row["z"])
	var dir := Vector2(slope, 1.0).normalized()
	mmi.set_instance_shader_parameter("path_line", Vector4(center_row["px"], center_row["z"], dir.x, dir.y))
	var ponds: Array = center_row["ponds"]
	var pv := Vector4(0, 0, 0, -10000.0)
	for p in ponds:
		if Vector2(p.x - (wx + TILE * 0.5), p.y - (wz + TILE * 0.5)).length() < p.z * 1.2 + TILE:
			pv = p
	mmi.set_instance_shader_parameter("pond", pv)
	# no blades under large rocks (up to 4 rocks per tile)
	var disks := world.rock_disks_in(Rect2(wx, wz, TILE, TILE))
	# mud hollows count as big disks: no blades in the mud
	for o in gen.obstacles_near(wz + TILE * 0.5):
		if o["type"] != "mud":
			continue
		for f: float in [-0.6, 0.0, 0.6]:
			var mz: float = o["z"] + f * float(o["len"])
			var md := Vector3(gen.path_x(mz), mz, float(o["wid"]) * (1.0 if f == 0.0 else 0.8))
			if Rect2(wx, wz, TILE, TILE).grow(md.z).has_point(Vector2(md.x, md.y)):
				disks.append(md)
	disks.sort_custom(func(a, b): return a.z > b.z)
	for i in 4:
		var d: Vector3 = disks[i] if i < disks.size() else Vector3(0, 0, 0)
		mmi.set_instance_shader_parameter("rock%d" % i, Vector4(d.x, d.y, d.z * 0.92, 0.0))
	return mmi


func _blend_blades(r: Dictionary, x: float) -> Dictionary:
	var bb: Vector3 = r["blend"]
	var a: Dictionary = gen.biomes[int(bb.x)]["blades"]
	var b: Dictionary = gen.biomes[int(bb.y)]["blades"]
	var t := gen.border_t(x, r["z"], bb.z)
	return {
		"height": lerpf(a["height"], b["height"], t),
		"root": (a["root"] as Color).lerp(b["root"], t),
		"tip": (a["tip"] as Color).lerp(b["tip"], t),
		"tip2": (a["tip2"] as Color).lerp(b["tip2"], t),
	}


func shift(offset: Vector3) -> void:
	for t in _tiles:
		if _tiles[t]["node"]:
			_tiles[t]["node"].position -= offset
