class_name LandmarkManager
extends Node
## Landmarks off the path: rock arches, ruins, stone circles, lookout rocks.
## Deterministic from the seed, appear with the near chunks (like find spots), with collision.

const CELL := 380.0
const TYPES := ["bogen", "ruine", "steinkreis", "aussicht", "ruine", "bogen"]

var gen: WorldGen
var world: ChunkManager
var lib: AssetLibrary
var _mats := {}
var _noise: Texture2D = preload("res://assets/paint_noise.tres")


func setup(p_gen: WorldGen, p_world: ChunkManager, p_lib: AssetLibrary) -> void:
	gen = p_gen
	world = p_world
	lib = p_lib
	world.chunk_ready.connect(_on_chunk_ready)
	# prepare expensive things once at start (otherwise the first landmark stutters)
	for i in 3:
		_hull("Rock_Medium_%d" % (i + 1))
		for sand in [false, true]:
			var rs := BiomeDefs.rock_style(Color(0.86, 0.62, 0.4) if sand else Color(0.7, 0.72, 0.74), 0.0 if sand else 0.55, true)
			if sand:
				rs["rock"]["texture"] = "Rocks_Desert_Diffuse.png"
			lib.mesh("Rock_Medium_%d" % (i + 1), rs)
	lib.mesh("Rock_Medium_1", BiomeDefs.rock_style(Color(0.72, 0.74, 0.76), 0.6, true))


func _hull(model: String) -> PackedVector3Array:
	if not _shape_cache.has(model):
		_shape_cache[model] = lib.raw_mesh(model).create_convex_shape(true, true).points
	return _shape_cache[model]


## Pure function: landmark in cell k or {}
static func plan(gen: WorldGen, k: int) -> Dictionary:
	if k < 1:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([gen.seed_value, k, 707])
	if rng.randf() > 0.75:
		return {}
	var z := -(k + 0.2 + rng.randf() * 0.6) * CELL
	if gen.obstacle_zone(z, 60.0) or gen.coast_info(z).y > 0.2:
		return {}
	var biome := gen.dominant_biome(z)
	var type: String = TYPES[rng.randi() % TYPES.size()]
	if biome == 2 and type == "steinkreis":
		type = "bogen"
	var r := gen.row(z)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var off: float = r["half_w"] + rng.randf_range(18.0, 38.0)
	var x: float = r["px"] + side * off / r["inv_len"]
	if gen.water_level(x, z) > -INF:
		return {}
	# only on reasonably flat ground
	var lo := INF
	var hi := -INF
	for a in 8:
		var h := gen.height(x + cos(a * TAU / 8.0) * 6.0, z + sin(a * TAU / 8.0) * 6.0)
		lo = minf(lo, h)
		hi = maxf(hi, h)
	if hi - lo > 3.5:
		return {}
	return {"k": k, "type": type, "x": x, "z": z, "side": side, "yaw": rng.randf() * TAU, "seed": rng.randi(),
		"biome": biome, "ground": lo}


func _on_chunk_ready(coord: Vector2i, node: Node3D, lod: int) -> void:
	var z0 := coord.y * ChunkBuilder.SIZE
	var z1 := z0 + ChunkBuilder.SIZE
	for k in range(maxi(floori(-z1 / CELL) - 1, 1), floori(-z0 / CELL) + 2):
		var p := plan(gen, k)
		if p.is_empty():
			continue
		if p["x"] < coord.x * ChunkBuilder.SIZE or p["x"] >= (coord.x + 1) * ChunkBuilder.SIZE or p["z"] < z0 or p["z"] >= z1:
			continue
		node.add_child(_build(p, Vector2(coord.x * ChunkBuilder.SIZE, z0), lod))


func _stone(sandstone: bool) -> Material:
	var key := "sand" if sandstone else "stone"
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/rock.gdshader")
	m.set_shader_parameter("albedo_tex", lib.texture("Rocks_Desert_Diffuse.png" if sandstone else "Rocks_Diffuse.png"))
	m.set_shader_parameter("paint_noise", _noise)
	m.set_shader_parameter("triplanar", 1.0)
	m.set_shader_parameter("triplanar_scale", 0.3)
	m.set_shader_parameter("flatten", 0.55)
	m.set_shader_parameter("flat_color", Color(0.86, 0.64, 0.42) if sandstone else Color(0.74, 0.74, 0.72))
	m.set_shader_parameter("moss_amount", 0.0 if sandstone else 0.6)
	m.set_shader_parameter("moss_color", Color(0.45, 0.62, 0.18))
	m.set_shader_parameter("top_light", 0.45)
	_mats[key] = m
	return m


func _piece(parent: Node3D, mesh: Mesh, xf: Transform3D, mat: Material, shape: Shape3D, lod: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	if lod == 0 and shape:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		body.transform = xf
		parent.add_child(body)


func _build(p: Dictionary, corner: Vector2, lod: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Wahrzeichen_%s_%d" % [p["type"], p["k"]]
	var gx: float = p["x"]
	var gz: float = p["z"]
	root.position = Vector3(gx - corner.x, 0.0, gz - corner.y)
	root.rotation.y = p["yaw"]
	var rng := RandomNumberGenerator.new()
	rng.seed = p["seed"]
	var sand: bool = p["biome"] == 2
	var mat := _stone(sand)
	var ground := func(lx: float, lz: float) -> float:
		var w := root.transform * Vector3(lx, 0, lz)
		return gen.height(w.x + corner.x, w.z + corner.y)
	match p["type"]:
		"bogen":
			# two pillars of stacked rocks and a massive capstone
			var rs := BiomeDefs.rock_style(Color(0.86, 0.62, 0.4) if sand else Color(0.7, 0.72, 0.74), 0.0 if sand else 0.55, true)
			if sand:
				rs["rock"]["texture"] = "Rocks_Desert_Diffuse.png"
			var span := rng.randf_range(7.0, 10.0)
			var hgt := rng.randf_range(7.0, 10.0)
			for sd in [-1.0, 1.0]:
				var px = sd * span * 0.5
				var gy: float = ground.call(px, 0.0)
				for i in 3:
					var m := lib.mesh("Rock_Medium_%d" % (1 + (i + int(sd > 0)) % 3), rs)
					var sc := Vector3(1.6, 1.25, 1.5) * (2.2 - i * 0.35)
					var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(sc), Vector3(px, gy - 0.6 + i * hgt * 0.3, rng.randf_range(-0.4, 0.4)))
					_piece(root, m, xf, null, _rock_shape(m, sc), lod)
			var top := lib.mesh("Rock_Medium_2", rs)
			var top_sc := Vector3(span * 0.55, 1.4, 1.9)
			var top_xf := Transform3D(Basis(Vector3.UP, 0.1).scaled(top_sc), Vector3(0, maxf(ground.call(-span * 0.5, 0.0), ground.call(span * 0.5, 0.0)) + hgt, 0))
			_piece(root, top, top_xf, null, _rock_shape(top, top_sc), lod)
			_greenery(root, rng, ground, 7.0, sand)
		"ruine":
			# row of columns (some toppled), wall remains with an arched window, stairs
			var cols := rng.randi_range(4, 7)
			for i in cols:
				var ang := i * TAU / cols
				var cx := cos(ang) * 6.5
				var cz := sin(ang) * 6.5
				var gy: float = ground.call(cx, cz)
				var standing := rng.randf() < 0.65
				var hh := rng.randf_range(2.5, 6.0) if standing else 0.0
				if standing:
					# fluted column with base and capital (mesh is centered)
					hh = snappedf(hh, 0.5)
					var sh := CylinderShape3D.new()
					sh.radius = 0.5
					sh.height = hh
					_piece(root, StructureModels.column(hh, sand), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cx, gy + hh * 0.5 - 0.2, cz)), null, sh, lod)
				else:
					var ln := snappedf(rng.randf_range(3.0, 5.0), 0.5)
					var lie := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)
					var sh2 := CylinderShape3D.new()
					sh2.radius = 0.5
					sh2.height = ln
					_piece(root, StructureModels.column(ln, sand), Transform3D(lie, Vector3(cx, gy + 0.35, cz)), null, sh2, lod)
			# wall remains with a window arch
			# block wall with a real arched window, broken off at the top
			var wy: float = ground.call(0.0, -2.0)
			var wbox := BoxShape3D.new()
			wbox.size = Vector3(5.5, 4.2, 0.9)
			var wall_xf := Transform3D(Basis(Vector3.RIGHT, 0.04), Vector3(0, wy - 0.3, -2.0))
			_piece(root, StructureModels.arch_wall(5.5, 4.2, 0.9, p["seed"] % 7, sand), wall_xf, null, null, lod)
			if lod == 0:
				var wb := StaticBody3D.new()
				var wcs := CollisionShape3D.new()
				wcs.shape = wbox
				wb.add_child(wcs)
				wb.transform = Transform3D(Basis(Vector3.RIGHT, 0.04), Vector3(0, wy + 1.8, -2.0))
				root.add_child(wb)
			var sy: float = ground.call(0.0, 3.0)
			_piece(root, StructureModels.steps(3, 4.0, sand), Transform3D(Basis(), Vector3(0, sy, 3.0)), null, null, lod)
			for i in 3:
				var sb := BoxShape3D.new()
				sb.size = Vector3(4.0 - i * 0.6, 0.35, 1.2)
				if lod == 0:
					var body := StaticBody3D.new()
					var cs := CollisionShape3D.new()
					cs.shape = sb
					body.add_child(cs)
					body.position = Vector3(0, sy + 0.15 + i * 0.35, 3.0 - i * 0.9)
					root.add_child(body)
			_greenery(root, rng, ground, 8.0, sand)
		"steinkreis":
			var n := rng.randi_range(7, 11)
			var trilith_h := -1.0
			for i in n:
				var ang2 := i * TAU / n + rng.randf_range(-0.1, 0.1)
				var sx := cos(ang2) * 7.5
				var sz := sin(ang2) * 7.5
				var sh_h := snappedf(rng.randf_range(2.6, 4.2), 0.4)
				if trilith_h > 0.0:
					sh_h = trilith_h
				trilith_h = sh_h if (i % 3 == 1 and i + 1 < n) else -1.0
				var bs := BoxShape3D.new()
				bs.size = Vector3(1.2, sh_h, 0.7)
				var b := Basis(Vector3.UP, -ang2) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12))
				var sp := Vector3(sx, ground.call(sx, sz) + sh_h * 0.5 - 0.4, sz)
				_piece(root, StructureModels.standing_stone(sh_h, i + int(p["seed"]) % 5, sand), Transform3D(b, sp), null, bs, lod)
				if lod == 0:
					Songbirds.mark(root, sp + Vector3(0, sh_h * 0.5 + 0.02, 0))
				# every third pair carries a lintel (trilithon)
				if i % 3 == 1 and i + 1 < n:
					var ang3 := (i + 0.5) * TAU / n
					_piece(root, StructureModels.lintel(3.6, i, sand), Transform3D(Basis(Vector3.UP, -ang3 + PI * 0.5), Vector3(cos(ang3) * 7.4, sp.y + sh_h * 0.5 + 0.28, sin(ang3) * 7.4)), null, null, lod)
			# flat altar stone in the middle, ringed by flowers
			var ab := BoxShape3D.new()
			ab.size = Vector3(2.4, 0.6, 1.4)
			_piece(root, StructureModels.altar(sand), Transform3D(Basis(), Vector3(0, ground.call(0.0, 0.0) + 0.2, 0)), null, ab, lod)
			_flowers(root, rng, ground, 5.5)
		"aussicht":
			# large, flat rock you can climb onto – with a lone tree on top
			var rs2 := BiomeDefs.rock_style(Color(0.72, 0.74, 0.76), 0.6, true)
			var big := lib.mesh("Rock_Medium_1", rs2)
			var bsc := Vector3(4.5, 1.8, 4.0)
			var by: float = ground.call(0.0, 0.0)
			_piece(root, big, Transform3D(Basis().scaled(bsc), Vector3(0, by - 0.8, 0)), null, _rock_shape(big, bsc), lod)
			var tree := MeshInstance3D.new()
			tree.mesh = lib.mesh("CommonTree_3", {"leaves": BiomeDefs.leaves(Color(0.25, 0.52, 0.08), Color(0.7, 0.93, 0.28)), "bark": {}, "stiffness": 6.0})
			tree.position = Vector3(1.0, by + 2.3, 0.5)
			tree.scale = Vector3.ONE * 1.6
			root.add_child(tree)
			_flowers(root, rng, ground, 4.0)
	return root


var _shape_cache := {}


func _rock_shape(m: Mesh, sc: Vector3) -> Shape3D:
	var pts := _hull(m.resource_name)
	var out := PackedVector3Array()
	for v in pts:
		out.append(v * sc)
	var s := ConvexPolygonShape3D.new()
	s.points = out
	return s


func _greenery(root: Node3D, rng: RandomNumberGenerator, ground: Callable, radius: float, sand: bool) -> void:
	for i in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(radius * 0.6, radius * 1.2)
		var x := cos(a) * d
		var z := sin(a) * d
		var mi := MeshInstance3D.new()
		if sand:
			mi.mesh = lib.mesh("Grass_Wispy_Short")
		else:
			mi.mesh = lib.mesh("Bush_Common_Flowers" if i % 2 == 0 else "Fern_1", {"leaves": BiomeDefs.leaves(Color(0.22, 0.48, 0.08), Color(0.6, 0.86, 0.22), {"sphere_normals": 0.85}), "stiffness": 6.0})
		mi.position = Vector3(x, ground.call(x, z), z)
		mi.scale = Vector3.ONE * (0.3 if mi.mesh.resource_name == "Fern_1" else rng.randf_range(1.0, 1.6))
		mi.rotation.y = rng.randf() * TAU
		root.add_child(mi)


func _flowers(root: Node3D, rng: RandomNumberGenerator, ground: Callable, radius: float) -> void:
	for i in 18:
		var a := rng.randf() * TAU
		var d := radius * sqrt(rng.randf())
		var x := cos(a) * d
		var z := sin(a) * d
		var mi := MeshInstance3D.new()
		mi.mesh = lib.mesh(["Flower_3_Group", "Flower_4_Group", "Flower_3_Single"][i % 3])
		mi.position = Vector3(x, ground.call(x, z), z)
		mi.scale = Vector3.ONE * rng.randf_range(0.5, 0.8)
		mi.rotation.y = rng.randf() * TAU
		root.add_child(mi)
