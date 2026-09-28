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
	# round 12: ancient trees, fallen giants and grove circles (an own hash, the rest of the plan stays)
	var roll := hash([gen.seed_value, k, 808]) % 100
	if roll < 45:
		type = ["uralt", "uralt", "riese", "hain"][roll % 4]
		if biome == 2 and type == "hain":
			type = "uralt"
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
		"uralt":
			_ancient_tree(root, rng, ground, int(p["biome"]), lod)
		"riese":
			_fallen_giant(root, rng, ground, int(p["biome"]), lod)
		"hain":
			_grove_circle(root, rng, ground, int(p["biome"]), lod)
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


# ================================================================ round 12: ancient tree, fallen giant, grove circle

## The biome's typical tree: [model, style] (its landmark tree if it has one, else its first tree layer)
func _biome_tree(biome: int, rng: RandomNumberGenerator) -> Array:
	var best: Dictionary = {}
	for layer: Dictionary in gen.biomes[biome]["layers"]:
		if layer["kind"] != "tree":
			continue
		# a living tree if the biome has one; its landmark tree if it has one
		var dead := TreeKinds.family(layer["models"][0]) == "DeadTree"
		var best_dead: bool = not best.is_empty() and TreeKinds.family(best["models"][0]) == "DeadTree"
		if best.is_empty() or (best_dead and not dead) or (not dead and float(layer.get("spacing", 10.0)) >= 300.0):
			best = layer
	if best.is_empty():
		return ["CommonTree_3", BiomeDefs.tree_style(Color(0.24, 0.5, 0.08), Color(0.68, 0.9, 0.26))]
	var models: Array = best["models"]
	var styles: Array = best.get("styles", [{}])
	return [models[rng.randi() % models.size()], styles[0]]


func _moss_style() -> Dictionary:
	return BiomeDefs.rock_style(Color(0.66, 0.68, 0.64), 0.9, true, {"triplanar_scale": 0.08})


func _add_mesh(root: Node3D, mesh: Mesh, xf: Transform3D, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func _ancient_tree(root: Node3D, rng: RandomNumberGenerator, ground: Callable, biome: int, lod: int) -> void:
	var pick := _biome_tree(biome, rng)
	var model: String = pick[0]
	var style: Dictionary = pick[1]
	var raw := lib.raw_mesh(model).get_aabb()
	var dead := TreeKinds.family(model) == "DeadTree"
	var target := 20.0 if dead else 36.0
	var s := target / maxf(raw.end.y, 1.0)
	var squash: Vector3 = TreeKinds.of(model).get("squash", Vector3.ONE)
	var gy: float = ground.call(0.0, 0.0)
	var trunk_r := clampf(0.3 * s, 0.9, 2.2)
	_add_mesh(root, lib.mesh(model, style), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(squash * s), Vector3(0, gy - 0.3, 0)))
	if lod == 0:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = trunk_r
		cap.height = 10.0
		cs.shape = cap
		cs.position = Vector3(0, gy + 4.0, 0)
		body.add_child(cs)
		root.add_child(body)
	# a ring of mossy boulders around the roots, ferns and fungi between them
	var ms := _moss_style()
	var n := rng.randi_range(6, 9)
	for i in n:
		var a := i * TAU / n + rng.randf_range(-0.25, 0.25)
		var d := rng.randf_range(3.6, 5.2) * clampf(s / 3.0, 0.8, 1.4)
		var x := cos(a) * d
		var z := sin(a) * d
		var m := lib.mesh(["Rock_Medium_4", "Rock_Medium_1", "Rock_Big_1", "Rock_Medium_3"][i % 4], ms)
		var sc := rng.randf_range(0.5, 1.0) * (0.55 if i % 4 == 2 else 1.0)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, ground.call(x, z) - 0.25 * sc, z))
		_piece(root, m, xf, null, _rock_shape(m, Vector3.ONE * sc) if lod == 0 else null, lod)
	for i in 10:
		var a2 := rng.randf() * TAU
		var d2 := rng.randf_range(2.0, 7.0)
		var fx := cos(a2) * d2
		var fz := sin(a2) * d2
		var fm: String = ["Fern_2", "Fern_1", "Mushroom_RedCap", "Mushroom_Common", "Clover_2"][i % 5]
		var fsc := rng.randf_range(0.9, 1.3) if fm.begins_with("Fern") else rng.randf_range(0.4, 0.7)
		_add_mesh(root, lib.mesh(fm), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * fsc), Vector3(fx, ground.call(fx, fz), fz)), false)
	# shelf fungi climbing the trunk
	for i in 5:
		var a3 := rng.randf() * TAU
		var py := gy + rng.randf_range(0.8, 3.5)
		_add_mesh(root, lib.mesh("Mushroom_Oyster"), Transform3D(Basis(Vector3.UP, -a3 + PI * 0.5).scaled(Vector3.ONE * rng.randf_range(0.5, 0.8)), Vector3(cos(a3) * trunk_r * 0.9, py, sin(a3) * trunk_r * 0.9)), false)
	_flowers(root, rng, ground, 8.0)
	# a bench facing the tree
	var bz := 9.0
	var by: float = ground.call(0.0, bz)
	_add_mesh(root, StructureModels.bench(), Transform3D(Basis(Vector3.UP, PI), Vector3(0, by, bz)))
	if lod == 0:
		var bb := StaticBody3D.new()
		var bcs := CollisionShape3D.new()
		var bsh := BoxShape3D.new()
		bsh.size = Vector3(1.6, 0.5, 0.45)
		bcs.shape = bsh
		bb.add_child(bcs)
		bb.position = Vector3(0, by + 0.25, bz)
		root.add_child(bb)
		Songbirds.mark(root, Vector3(0.55, by + 0.92, bz + 0.28))


func _fallen_giant(root: Node3D, rng: RandomNumberGenerator, ground: Callable, biome: int, lod: int) -> void:
	var radius := 1.1
	var length := 24.0
	# one end rests on the ground, the root plate lifts the other a little: you can walk up onto it
	var y0: float = ground.call(-length * 0.5, 0.0) + radius * 0.55
	var y1: float = ground.call(length * 0.5, 0.0) + radius * 1.35
	var center := Vector3(0, (y0 + y1) * 0.5, 0)
	var tilt := atan2(y1 - y0, length)
	var basis := Basis(Vector3.BACK, tilt) * Basis(Quaternion(Vector3.UP, Vector3.RIGHT))
	var bark := StandardMaterial3D.new()
	bark.albedo_texture = lib.texture("Bark_PineTree.png")
	bark.albedo_color = Color(1.35, 1.2, 1.05)
	bark.normal_enabled = true
	bark.normal_texture = lib.texture("Bark_PineTree_Normal.png")
	bark.uv1_scale = Vector3(2.0, 6.0, 1.0)
	bark.roughness = 0.95
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.78
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 24
	cm.rings = 10
	var log_mi := _add_mesh(root, cm, Transform3D(basis, center))
	log_mi.material_override = bark
	if lod == 0:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = radius * 0.9
		cap.height = length
		cs.shape = cap
		cs.transform = Transform3D(basis, center)
		body.add_child(cs)
		root.add_child(body)
	# moss blanket on top
	var mm := CylinderMesh.new()
	mm.top_radius = radius * 0.62
	mm.bottom_radius = radius * 0.74
	mm.height = length * 0.85
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.4, 0.62, 0.16)
	mmat.roughness = 1.0
	var moss := _add_mesh(root, mm, Transform3D(basis.scaled(Vector3(1.0, 1.0, 0.55)), center + Vector3(0, radius * 0.48, 0)))
	moss.material_override = mmat
	# root plate at the lifted end, the broken top at the low end
	var axis := basis.y.normalized()
	_add_mesh(root, StructureModels.root_plate(3.2, rng.randi() % 3), Transform3D(basis, center + axis * length * 0.5))
	_add_mesh(root, StructureModels.log_cap(radius * 0.8), Transform3D(basis * Basis(Vector3.RIGHT, PI), center - axis * length * 0.5))
	# young trees growing out of it (a nurse log), fungi, ferns and flowers along it
	var pick := _biome_tree(biome, rng)
	var raw := lib.raw_mesh(pick[0]).get_aabb()
	var young := 4.0 / maxf(raw.end.y, 1.0)
	for i in 3:
		var t := rng.randf_range(-0.35, 0.35)
		_add_mesh(root, lib.mesh(pick[0], pick[1]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * young), center + axis * length * t + Vector3(0, radius * 0.9, 0)))
	for i in 16:
		var t2 := rng.randf_range(-0.45, 0.45)
		var a := rng.randf_range(-1.2, 1.2)
		var on := center + axis * length * t2 + Vector3(0, cos(a) * radius * 0.95, sin(a) * radius * 0.95)
		var fm: String = ["Mushroom_Oyster", "Fern_2", "Clover_1", "Mushroom_RedCap", "Flower_7_Single"][i % 5]
		var fsc := 0.45 if fm == "Mushroom_Oyster" else (0.7 if fm == "Fern_2" else 0.5)
		_add_mesh(root, lib.mesh(fm), Transform3D(Basis(Vector3.RIGHT, a).scaled(Vector3.ONE * fsc), on), false)
	for i in 8:
		var gx := rng.randf_range(-length * 0.5, length * 0.5)
		var gz := rng.randf_range(-3.5, 3.5)
		if absf(gz) < radius + 0.4:
			gz = signf(gz + 0.01) * (radius + 0.6)
		_add_mesh(root, lib.mesh("Fern_1" if i % 2 == 0 else "Fern_2"), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), Vector3(gx, ground.call(gx, gz), gz)), false)
	if lod == 0:
		Songbirds.mark(root, center + Vector3(0, radius + 0.05, 0))


func _grove_circle(root: Node3D, rng: RandomNumberGenerator, ground: Callable, biome: int, lod: int) -> void:
	var pick := _biome_tree(biome, rng)
	var model: String = pick[0]
	var raw := lib.raw_mesh(model).get_aabb()
	# about 14 m tall, but narrow enough that the ring keeps gaps between the crowns
	var s := minf(14.0 / maxf(raw.end.y, 1.0), 6.0 / maxf(maxf(raw.size.x, raw.size.z), 1.0))
	var squash: Vector3 = TreeKinds.of(model).get("squash", Vector3.ONE)
	var n := rng.randi_range(6, 8)
	for i in n:
		var a := i * TAU / n + rng.randf_range(-0.12, 0.12)
		var d := rng.randf_range(10.0, 11.5)
		var x := cos(a) * d
		var z := sin(a) * d
		_add_mesh(root, lib.mesh(model, pick[1]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(squash * s * rng.randf_range(0.85, 1.1)), Vector3(x, ground.call(x, z) - 0.1, z)))
		if lod == 0:
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.45
			cyl.height = 4.0
			cs.shape = cyl
			cs.position = Vector3(x, ground.call(x, z) + 2.0, z)
			body.add_child(cs)
			root.add_child(body)
	# the big flat stone in the middle and a carpet of flowers and mushrooms
	var stone := lib.mesh("Rock_Big_2", _moss_style())
	var ssc := Vector3(0.8, 0.28, 0.7)
	_piece(root, stone, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(ssc), Vector3(0, ground.call(0.0, 0.0) - 0.15, 0)), null, _rock_shape(stone, ssc) if lod == 0 else null, lod)
	_flowers(root, rng, ground, 7.0)
	for i in 8:
		var a2 := rng.randf() * TAU
		var d2 := rng.randf_range(3.0, 7.5)
		var fx := cos(a2) * d2
		var fz := sin(a2) * d2
		_add_mesh(root, lib.mesh(["Mushroom_Common", "Clover_1", "Flower_6", "Clover_2"][i % 4]), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.0)), Vector3(fx, ground.call(fx, fz), fz)), false)
	if lod == 0:
		Songbirds.mark(root, Vector3(0, ground.call(0.0, 0.0) + 0.9, 0))
