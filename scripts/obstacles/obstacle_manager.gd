class_name ObstacleManager
extends Node3D
## Builds obstacles (river with broken bridge, cliff with waterfall, fallen tree) near the player,
## remembers their state (moved logs, stretched ropes) and simulates buoyancy and current.

const BUILD_DIST := 260.0
const FREE_DIST := 420.0
const PERSON_KG := 75.0

var gen: WorldGen
var world: ChunkManager
var lib: AssetLibrary
## Callbacks into the game: message(text), knot(book, callback(q)), spawn_item(item, pos, vel)
var on_message: Callable
var on_knot: Callable
var on_spawn_item: Callable

var _built := {}        # k -> Node3D
var _state := {}        # k -> Dictionary (kept when the obstacle is unloaded)
var _floaters: Array = []   # [{"body": RigidBody3D, "len": float, "radius": float}]
var _mats := {}
var _noise: Texture2D = preload("res://assets/paint_noise.tres")


func setup(p_gen: WorldGen, p_world: ChunkManager, p_lib: AssetLibrary) -> void:
	gen = p_gen
	world = p_world
	lib = p_lib


# ================================================================ Loading / unloading

func update(focus_world: Vector3) -> void:
	var near := gen.obstacles_near(focus_world.z)
	for o in near:
		var k: int = o["k"]
		if not _built.has(k) and absf(focus_world.z - o["z"]) < BUILD_DIST:
			_built[k] = _build(o)
	for k in _built.keys():
		var node: Node3D = _built[k]
		var o := gen.obstacle(k)
		if absf(focus_world.z - o["z"]) > FREE_DIST:
			_save(k, node)
			_floaters = _floaters.filter(func(f): return is_instance_valid(f["body"]) and not node.is_ancestor_of(f["body"]))
			node.queue_free()
			_built.erase(k)


func shift(offset: Vector3) -> void:
	for k in _built:
		(_built[k] as Node3D).position -= offset


func st(k: int) -> Dictionary:
	if not _state.has(k):
		_state[k] = {}
	return _state[k]


func _save(k: int, node: Node3D) -> void:
	var s := st(k)
	var logs: Array = []
	for c in node.get_children():
		if c is RigidBody3D and c.has_meta("log_index"):
			var xf: Transform3D = c.global_transform
			xf.origin = world.local_to_world(xf.origin)
			logs.append(xf)
	if not logs.is_empty():
		s["logs"] = logs


func _root_for(o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Hindernis_%d" % o["k"]
	add_child(root)
	root.position = Vector3(o["px"] - world.origin.x, 0.0, o["z"] - world.origin.y)
	return root


func _build(o: Dictionary) -> Node3D:
	var root := _root_for(o)
	match o["type"]:
		"river": _build_river(o, root)
		"cliff": _build_cliff(o, root)
		"fallen_tree": _build_fallen_tree(o, root)
		"stile": _build_stile(o, root)
		"mud": _build_mud(o, root)
		"boulders": _build_boulders(o, root)
	return root


# ================================================================ Materials and shapes

func _mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"wood":
			var w := StandardMaterial3D.new()
			w.albedo_texture = lib.texture("Bark_NormalTree.png")
			w.albedo_color = Color(1.25, 1.05, 0.85)
			w.normal_enabled = true
			w.normal_texture = lib.texture("Bark_NormalTree_Normal.png")
			w.uv1_scale = Vector3(1.0, 3.0, 1.0)
			w.roughness = 0.9
			m = w
		"plank":
			var pl := StandardMaterial3D.new()
			pl.albedo_color = Color(0.62, 0.44, 0.28)
			pl.roughness = 0.85
			m = pl
		"log":
			var lg := StandardMaterial3D.new()
			lg.albedo_texture = lib.texture("Bark_DeadTree.png")
			lg.albedo_color = Color(1.6, 1.4, 1.2)
			lg.normal_enabled = true
			lg.normal_texture = lib.texture("Bark_DeadTree_Normal.png")
			lg.uv1_scale = Vector3(2.0, 6.0, 1.0)
			lg.roughness = 0.95
			m = lg
		"stone":
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://shaders/rock.gdshader")
			sm.set_shader_parameter("albedo_tex", lib.texture("Rocks_Diffuse.png"))
			sm.set_shader_parameter("paint_noise", _noise)
			sm.set_shader_parameter("triplanar", 1.0)
			sm.set_shader_parameter("triplanar_scale", 0.35)
			sm.set_shader_parameter("flatten", 0.55)
			sm.set_shader_parameter("flat_color", Color(0.68, 0.7, 0.74))
			sm.set_shader_parameter("moss_amount", 0.6)
			sm.set_shader_parameter("top_light", 0.4)
			m = sm
		"rope_ring":
			var rr := StandardMaterial3D.new()
			rr.albedo_color = Color(0.86, 0.72, 0.45)
			m = rr
	_mats[key] = m
	return m


var _plank_n := 0


func _box(parent: Node3D, size: Vector3, pos: Vector3, basis: Basis, mat: String, collide := true) -> Node3D:
	var holder: Node3D
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		holder = body
	else:
		holder = Node3D.new()
	var mi := MeshInstance3D.new()
	if mat == "plank":
		mi.mesh = StructureModels.plank(size, _plank_n)
		_plank_n += 1
	elif mat == "stone":
		mi.mesh = StructureModels.masonry(size, 3, false)
	else:
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = _mat(mat)
	holder.add_child(mi)
	holder.transform = Transform3D(basis, pos)
	parent.add_child(holder)
	return holder


func _post(parent: Node3D, pos: Vector3, height := 1.35) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.12
	sh.height = height
	cs.shape = sh
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = StructureModels.post(height)
	body.add_child(mi)
	body.position = pos + Vector3(0, height * 0.5 - 0.15, 0)
	parent.add_child(body)


## World xz relative to the obstacle root → local position with the real ground height
func _ground(o: Dictionary, wxz: Vector2, lift := 0.0) -> Vector3:
	return Vector3(wxz.x - o["px"], gen.height(wxz.x, wxz.y) + lift, wxz.y - o["z"])


func _interact(parent: Node3D, pos: Vector3, size: Vector3, prompt: Callable, action: Callable) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("poi_prompt", prompt)
	area.set_meta("poi_action", action)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	area.add_child(cs)
	area.position = pos
	parent.add_child(area)
	return area


func _item(o: Dictionary, root: Node3D, id: String, idx: int, local: Vector3) -> void:
	var s := st(o["k"])
	var taken: Dictionary = s.get("taken", {})
	if taken.has(idx):
		return
	var it := ItemDefs.make(id, (hash([gen.seed_value, o["k"], idx, 919]) & 0xffffffff) | (1 << 34))
	var wi := WorldItem.create(it)
	wi.world_ref = world
	wi.position = local
	wi.tree_exiting.connect(func():
		if wi.has_meta("taken"):
			taken[idx] = true
			s["taken"] = taken)
	root.add_child(wi)


# ================================================================ River with broken bridge

func river_frame(o: Dictionary) -> Dictionary:
	var a: Vector2 = o["axis"]
	var n := Vector2(-a.y, a.x)
	if n.y > 0.0:
		n = -n     # points in walking direction (−z)
	var half: float = o["width"] * 0.5
	var c := Vector2(o["px"], o["z"])
	return {"axis": a, "fwd": n, "near": c - n * (half + 1.5), "far": c + n * (half + 1.5), "half": half}


func _build_river(o: Dictionary, root: Node3D) -> void:
	var f := river_frame(o)
	var a: Vector2 = f["axis"]
	var n: Vector2 = f["fwd"]
	var a3 := Vector3(a.x, 0, a.y)
	var n3 := Vector3(n.x, 0, n.y)
	var basis := Basis(a3, Vector3.UP, n3)
	var w: float = o["width"]

	# water: ribbon along the winding river center, ends at the spring and a rock barrier
	var water := MeshInstance3D.new()
	water.mesh = _river_ribbon(o)
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/water.gdshader")
	wm.set_shader_parameter("noise_tex", _noise)
	wm.set_shader_parameter("clarity_depth", 1.6)
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bb := gen.biome_blend(o["z"])
	var ta: Dictionary = gen.biomes[int(bb.x)]["terrain"]
	water.set_instance_shader_parameter("flow", a * float(o["flow"]))
	water.set_instance_shader_parameter("shallow_color", ta["water_shallow"])
	water.set_instance_shader_parameter("deep_color", ta["water_deep"])
	root.add_child(water)
	_river_ends(o, root)

	# bridge remains: abutments, broken planks, posts (rope anchors)
	for side in [-1.0, 1.0]:
		var bank: Vector2 = f["near"] if side < 0.0 else f["far"]
		var base := _ground(o, bank - n * side * 0.9)
		# top edge flush with the terrain inland (no step between base and path)
		var inland: Vector2 = bank - n * side * 2.4
		var top_y := maxf(gen.height(bank.x, bank.y), gen.height(inland.x, inland.y))
		# top edge flush with the ground (no step on the path)
		_box(root, Vector3(3.8, 6.0, 2.4), Vector3(base.x, top_y - 3.02, base.z), basis, "stone")
		# two long beams, broken off at the end and bent into the water
		for bx in [-1.2, 1.2]:
			var beam_len := 2.4 if side < 0.0 else 1.6
			var start: Vector3 = Vector3(bank.x - o["px"], top_y - 0.08, bank.y - o["z"]) + a3 * bx
			var tilt := Basis(a3, deg_to_rad(-14.0 * side if bx < 0.0 else -6.0 * side))
			var bbasis := tilt * basis
			_box(root, Vector3(0.22, 0.22, beam_len), start + bbasis.z * side * beam_len * 0.5, bbasis, "plank", false)
		for pi in 4:
			var along := (pi + 0.5) * 0.45
			if side > 0.0 and pi > 2:
				break
			var pc: Vector3 = Vector3(bank.x - o["px"], top_y + 0.035, bank.y - o["z"]) + n3 * side * along
			_box(root, Vector3(2.9 - pi * 0.25, 0.07, 0.36), pc, basis * Basis(Vector3.UP, (pi - 1.5) * 0.06), "plank", false)
		# rope posts
		var post_xz: Vector2 = bank + a * 1.9 - n * side * 0.2
		_post(root, _ground(o, post_xz))
	# a loose plank drifts at the bank
	_box(root, Vector3(2.4, 0.07, 0.34), _ground(o, (f["near"] as Vector2) + a * 5.0 + n * 1.2, 0.05), basis * Basis(Vector3.UP, 0.7), "plank", false)

	# logs: a long one (reaches across the river if you push it right) and one that's too short
	var s := st(o["k"])
	var long_len := clampf(2.25 * (w + 3.0), 18.0, 28.0)
	var saved: Array = s.get("logs", [])
	var specs := [
		[long_len, 0.42, 100.0, (f["near"] as Vector2) - n * (long_len * 0.5 + 2.0) - a * 4.8, n.angle() + 0.12],
		[6.5, 0.36, 40.0, (f["near"] as Vector2) - n * 4.5 + a * 6.5, a.angle()],
	]
	for i in specs.size():
		var sp: Array = specs[i]
		var body := _log_body(sp[0], sp[1], sp[2])
		body.set_meta("log_index", i)
		root.add_child(body)
		if i < saved.size():
			var xf: Transform3D = saved[i]
			xf.origin = world.world_to_local(xf.origin)
			body.global_transform = xf
		else:
			var c2: Vector2 = sp[3]
			var dir2 := Vector2.from_angle(sp[4])
			var y: float = gen.height(c2.x, c2.y) + sp[1] + 0.05
			# log length lies along the local z axis
			body.global_transform = Transform3D(Basis(Vector3(dir2.y, 0, -dir2.x), Vector3.UP, Vector3(dir2.x, 0, dir2.y)),
				world.world_to_local(Vector3(c2.x, y, c2.y)))
		_floaters.append({"body": body, "len": sp[0], "radius": sp[1]})

	# ropes to find: two at the first river (each too short alone – knot them!)
	if o["k"] == 1:
		_item(o, root, "seil", 0, _ground(o, (f["near"] as Vector2) - n * 2.5 - a * 1.5, 0.3))
		_item(o, root, "seil", 1, _ground(o, (f["near"] as Vector2) - n * 6.0 + a * 3.2, 0.3))
		_item(o, root, "feldhandbuch", 2, _ground(o, (f["near"] as Vector2) - n * 2.8 + a * 0.8, 0.3))
	elif hash([o["k"], 3]) % 2 == 0:
		_item(o, root, "seil", 0, _ground(o, (f["near"] as Vector2) - n * 2.5, 0.3))

	# rope anchor
	var near_post: Vector2 = (f["near"] as Vector2) + a * 1.9 + n * 0.2
	var far_post: Vector2 = (f["far"] as Vector2) + a * 1.9 - n * 0.2
	_rope_anchor(o, root, 0, _ground(o, near_post, 1.1), _ground(o, far_post, 1.1), "span")
	_rope_anchor(o, root, 1, _ground(o, far_post, 1.1), _ground(o, near_post, 1.1), "span")


## Water ribbon along the river center (local to the obstacle root)
func _river_ribbon(o: Dictionary) -> ArrayMesh:
	var lr: float = o["length"]
	var half: float = o["width"] * 0.5 + 0.7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 3.0
	var n := int(ceil(lr * 2.0 / step))
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for i in n + 1:
		var al := -lr + i * step
		var c := gen.river_point(al, o)
		var t := (gen.river_point(al + 0.5, o) - gen.river_point(al - 0.5, o)).normalized()
		var side := Vector2(-t.y, t.x)
		var y: float = o["level"]
		half = gen.river_half(al, o) + 0.7
		var l := Vector3(c.x + side.x * half - o["px"], y, c.y + side.y * half - o["z"])
		var r := Vector3(c.x - side.x * half - o["px"], y, c.y - side.y * half - o["z"])
		if i > 0:
			for v in [prev_l, l, r, prev_l, r, prev_r]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		prev_l = l
		prev_r = r
	return st.commit()


## Spring end: waterfall out of the rock wall. Mouth end: the water disappears under a rock barrier.
func _river_ends(o: Dictionary, root: Node3D) -> void:
	var lr: float = o["length"]
	var up_sign := -signf(o["flow"])      # upstream
	var rock_style := BiomeDefs.rock_style(Color(0.6, 0.64, 0.7), 0.6, true)
	for end in [-1.0, 1.0]:
		var al: float = end * (lr + 1.5)
		var c := gen.river_point(al, o)
		var t: Vector2 = (gen.river_point(al + 0.5, o) - gen.river_point(al - 0.5, o)).normalized() * end
		var local := Vector3(c.x - o["px"], 0.0, c.y - o["z"])
		var top := gen.height(c.x + t.x * 4.0, c.y + t.y * 4.0)
		if end == up_sign:
			# waterfall plunges out of the wall into the river
			var src := c + t * 7.0
			_waterfall(root, o, src, -t, float(o["level"]), float(o["width"]) * 0.45)
		# boulders at both ends, a closed barrier at the mouth end
		var count := 0 if end == up_sign else 6
		for i in count:
			var rock := MeshInstance3D.new()
			rock.mesh = lib.mesh(["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"][i % 3], rock_style)
			var sideways: Vector2 = Vector2(-t.y, t.x) * ((float(i) / maxf(count - 1, 1)) - 0.5) * o["width"] * 1.3
			var rp := local + Vector3(sideways.x, float(o["level"]) - 1.5, sideways.y) + Vector3(t.x, 0, t.y) * (0.5 if end != up_sign else 2.0)
			rock.position = rp
			rock.scale = Vector3.ONE * (2.2 if end != up_sign else 1.6) * (0.85 + 0.3 * float(i % 2))
			rock.rotation.y = i * 1.7
			root.add_child(rock)
			var rb := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = rock.scale.x * 1.2
			cs.shape = sph
			rb.add_child(cs)
			rb.position = rp + Vector3(0, rock.scale.x * 0.8, 0)
			root.add_child(rb)
		# mist over the water (visible with volumetric fog)
		var fog := FogVolume.new()
		fog.size = Vector3(o["width"] * 1.6, 3.0, 14.0)
		var fmat := FogMaterial.new()
		fmat.density = 0.06
		fmat.albedo = Color(0.95, 0.98, 1.0)
		fmat.height_falloff = 0.8
		fmat.edge_fade = 0.6
		fog.material = fmat
		fog.position = local + Vector3(0, float(o["level"]) + 1.2, 0) - Vector3(t.x, 0, t.y) * 6.0
		fog.basis = Basis.looking_at(Vector3(t.x, 0, t.y), Vector3.UP)
		root.add_child(fog)


func _log_body(length: float, radius: float, mass_kg: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.freeze = true
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.mass = mass_kg
	body.continuous_cd = true
	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.5
	pmat.rough = true
	body.physics_material_override = pmat
	body.angular_damp = 4.0
	# capsule instead of cylinder: stable on the heightfield (cylinders fall through there)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = length
	cs.shape = sh
	cs.rotation.x = PI * 0.5
	body.add_child(cs)
	body.set_meta("length", length)
	body.set_meta("radius", radius)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.85
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 14
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = _mat("log")
	mi.rotation.x = PI * 0.5
	body.add_child(mi)
	# tree-ring caps on the cut ends (instead of bark on the end faces)
	for e in [-1.0, 1.0]:
		var cap_mi := MeshInstance3D.new()
		cap_mi.mesh = StructureModels.log_cap(radius * (0.85 if e > 0.0 else 1.0))
		cap_mi.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * e), Vector3(0, 0, e * length * 0.5))
		body.add_child(cap_mi)
	# moss on top
	var moss := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = radius * 0.5
	mm.bottom_radius = radius * 0.5
	mm.height = length * 0.6
	moss.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.36, 0.55, 0.14)
	mmat.roughness = 1.0
	moss.material_override = mmat
	moss.rotation.x = PI * 0.5
	moss.position = Vector3(0, radius * 0.62, length * 0.08)
	moss.scale = Vector3(1.0, 1.0, 0.35)
	body.add_child(moss)
	body.set_meta("pushable", true)
	return body


# ================================================================ Ropes

## kind: "span" (between two posts) or "hang" (down the cliff)
func _rope_anchor(o: Dictionary, root: Node3D, idx: int, pos: Vector3, other: Vector3, kind: String) -> void:
	var k: int = o["k"]
	var s := st(k)
	if not s.has("rope"):
		s["rope"] = {"stage": "none"}
	var area := _interact(root, pos, Vector3(0.9, 1.6, 0.9),
		func(w: Wanderer) -> String: return _rope_prompt(k, idx, kind, w),
		func(w: Wanderer) -> void: _rope_action(k, idx, kind, w, root, pos, other))
	area.set_meta("anchor", [k, idx])
	if not root.has_meta("rope_visual"):
		var visual := RopeVisual.new()
		visual.name = "Seil"
		root.add_child(visual)
		root.set_meta("rope_visual", visual)
	root.set_meta("anchor_%d" % idx, pos)
	_refresh_rope(k, root)


func _rope(k: int) -> Dictionary:
	return st(k)["rope"]


func _rope_prompt(k: int, idx: int, kind: String, w: Wanderer) -> String:
	var r := _rope(k)
	var rope_item := _best_rope(w)
	match r["stage"]:
		"none":
			if rope_item.is_empty():
				return "You could tie a rope here"
			return "Tie rope (%d m)" % rope_item.get("length", 10)
		"carried":
			if r["anchor"] == idx:
				return "Untie rope"
			return "Tie rope here (stretch it)"
		"dangling":
			if r["anchor"] == idx:
				return "Pick up rope end · %s: untie" % GameInput.glyph("untie")
			return ""
		"spanned":
			return "Climb across · %s: untie" % GameInput.glyph("untie")
		"hanging":
			return "Rappel down · %s: untie" % GameInput.glyph("untie")
	return ""


func _best_rope(w: Wanderer) -> Dictionary:
	var best := {}
	for it in w.inventory.items:
		if it["id"] == "seil" and (best.is_empty() or it.get("length", 10) > best.get("length", 10)):
			best = it
	return best


func _rope_action(k: int, idx: int, kind: String, w: Wanderer, root: Node3D, pos: Vector3, other: Vector3) -> void:
	var r := _rope(k)
	match r["stage"]:
		"none":
			var item := _best_rope(w)
			if item.is_empty():
				_msg("You don't have a rope.")
				return
			var need := _needed_length(kind, root, pos, other, k)
			if item.get("length", 10) < need:
				_msg("The rope is only %d m long – you need more like %d m here. Knot ropes together?" % [item.get("length", 10), ceili(need)])
				return
			_knot(w, func(q: float) -> void:
				w.inventory.remove(item)
				r["item"] = item
				r["q1"] = q
				r["anchor"] = idx
				r["length"] = item.get("length", 10)
				r["stage"] = "hanging" if kind == "hang" else "carried"
				r["load_time"] = 0.0
				if kind == "hang":
					_msg("Rope tied (%d %%). It hangs down the cliff." % roundi(q * 100))
				else:
					_msg("Rope tied (%d %%). Take the other end to the far bank." % roundi(q * 100))
					w.carried_rope = [k, root, pos]
				_refresh_rope(k, root))
		"carried":
			if r["anchor"] == idx:
				_untie(k, w, root)
			else:
				_knot(w, func(q: float) -> void:
					r["q2"] = q
					r["stage"] = "spanned"
					w.carried_rope = []
					_msg("Rope stretched! Weakest knot: %d %%." % roundi(minf(r["q1"], q) * 100))
					_refresh_rope(k, root))
		"dangling":
			if r["anchor"] == idx:
				r["stage"] = "carried"
				w.carried_rope = [k, root, root.get_meta("anchor_%d" % idx)]
				_refresh_rope(k, root)
		"spanned", "hanging":
			var a: Vector3 = root.get_meta("anchor_%d" % r["anchor"]) if r["stage"] == "hanging" else root.get_meta("anchor_0")
			var b: Vector3 = _hang_end(root, k) if r["stage"] == "hanging" else root.get_meta("anchor_1")
			var ga := root.to_global(a)
			var gb := root.to_global(b)
			var from_b := w.global_position.distance_to(gb) < w.global_position.distance_to(ga)
			w.start_rope(ga, gb, 0.35 if r["stage"] == "spanned" else 0.0, 1.0 if from_b else 0.0,
				"hangel" if r["stage"] == "spanned" else "abseil", k)


func untie_key(k: int, w: Wanderer, root: Node3D) -> void:
	var r := _rope(k)
	if r["stage"] in ["spanned", "hanging", "dangling"]:
		_untie(k, w, root)


func _untie(k: int, w: Wanderer, root: Node3D) -> void:
	var r := _rope(k)
	if r.has("item") and w.inventory.add(r["item"]):
		_msg("Rope untied and packed.")
	elif r.has("item"):
		on_spawn_item.call(r["item"], w.global_position + Vector3(0, 1, 0), Vector3.ZERO)
		_msg("Rope untied – no room in the backpack, it's on the ground.")
	r.clear()
	r["stage"] = "none"
	w.carried_rope = []
	_refresh_rope(k, root)


func _needed_length(kind: String, root: Node3D, pos: Vector3, other: Vector3, k: int) -> float:
	if kind == "hang":
		return gen.obstacle(k)["drop"] - 1.5
	return pos.distance_to(other) + 1.0


func _hang_end(root: Node3D, k: int) -> Vector3:
	var r := _rope(k)
	var a: Vector3 = root.get_meta("anchor_0")
	var o := gen.obstacle(k)
	# rope runs over the edge and hangs down the wall (end just in front of the wall, at the bottom)
	var end_z := -1.6
	var bottom_y := gen.height(o["px"] + a.x, o["z"] + end_z)
	var y := maxf(a.y - float(r.get("length", 10)), bottom_y + 0.4)
	return Vector3(a.x, y, end_z)


func _refresh_rope(k: int, root: Node3D) -> void:
	if not root.has_meta("rope_visual"):
		return
	var vis: RopeVisual = root.get_meta("rope_visual")
	var r := _rope(k)
	vis.visible = r["stage"] in ["spanned", "hanging", "dangling", "carried"]
	match r["stage"]:
		"spanned":
			vis.set_points(root.get_meta("anchor_0") + Vector3(0, 0.05, 0), root.get_meta("anchor_1") + Vector3(0, 0.05, 0), 0.35)
		"hanging":
			var a: Vector3 = root.get_meta("anchor_0")
			vis.set_points(a, _hang_end(root, k), 0.0)
		"dangling":
			var a2: Vector3 = root.get_meta("anchor_%d" % r["anchor"])
			vis.set_points(a2, a2 + Vector3(0.2, -1.4, 0.3), 0.1)


## Rope the player is carrying: update every frame, gets torn from the hand if too long
func update_carried(w: Wanderer) -> void:
	if w.carried_rope.is_empty():
		return
	var k: int = w.carried_rope[0]
	var root: Node3D = w.carried_rope[1]
	if not is_instance_valid(root):
		w.carried_rope = []
		return
	var anchor: Vector3 = w.carried_rope[2]
	var r := _rope(k)
	var ga := root.to_global(anchor)
	var hand := w.global_position + Vector3(0, 1.1, 0) - w.global_basis.z * 0.4
	var vis: RopeVisual = root.get_meta("rope_visual")
	vis.visible = true
	vis.set_points(anchor, root.to_local(hand), 0.6)
	if ga.distance_to(hand) > float(r.get("length", 10)) + 0.5:
		r["stage"] = "dangling"
		w.carried_rope = []
		_msg("The rope is too short and slips out of your hand!")
		_refresh_rope(k, root)


## Called by the player every physics frame while climbing across/rappelling. Returns false if the knot gives way.
func rope_load(k: int, kg: float, delta: float) -> bool:
	var r := _rope(k)
	if not r.has("q1"):
		return true
	var q: float = minf(minf(r["q1"], r.get("q2", 1.0)), float((r.get("item", {}) as Dictionary).get("knot", 1.0)))
	var capacity := 60.0 + q * 160.0
	var limit := INF if q >= 0.95 else 12.0 + q * 70.0
	if kg > capacity:
		limit *= 0.1
	r["load_time"] = float(r.get("load_time", 0.0)) + delta
	if r["load_time"] > limit:
		# knot loosens: the rope falls down, lies as an item in the water/below
		var root: Node3D = _built.get(k)
		var item: Dictionary = r.get("item", {})
		r.clear()
		r["stage"] = "none"
		if root:
			_refresh_rope(k, root)
		if not item.is_empty() and root:
			item["knot"] = maxf(float(item.get("knot", 1.0)) - 0.2, 0.1)
			on_spawn_item.call(item, root.to_global(root.get_meta("anchor_0")) + Vector3(0, -2, -2), Vector3.ZERO)
		_msg("KRRRK – the knot is loosening!")
		return false
	return true


func _knot(w: Wanderer, cb: Callable) -> void:
	var book := false
	for it in w.inventory.items:
		if it["id"] == "feldhandbuch":
			book = true
	on_knot.call(book, func(q: float) -> void:
		if q >= 0.0:
			cb.call(q))


func _msg(t: String) -> void:
	if on_message.is_valid():
		on_message.call(t)


# ================================================================ Cliff with waterfall

func _build_cliff(o: Dictionary, root: Node3D) -> void:
	var pool: Vector4 = o["pool"]
	var side: float = o["side"]
	var edge_z: float = o["z"]
	# waterfall plunges into the pool next to the path: find the plateau above, water runs to the edge (−z)
	_waterfall(root, o, Vector2(pool.x, edge_z + 5.0), Vector2(0, -1), pool.w, 5.5)
	# rope peg at the top of the edge
	var stake_z := edge_z + 2.2
	var stake_x := gen.path_x(stake_z) + side * 2.4
	var stake := _ground(o, Vector2(stake_x, stake_z))
	_post(root, stake, 0.9)
	var anchor := stake + Vector3(0, 0.6, 0)
	_rope_anchor(o, root, 0, anchor, anchor + Vector3(0, -o["drop"], 0), "hang")
	# warning sign
	var label := Label3D.new()
	label.text = "Caution – drop!"
	label.font_size = 42
	label.pixel_size = 0.005
	label.modulate = Color(0.3, 0.2, 0.1)
	label.outline_size = 0
	var sign_pos := _ground(o, Vector2(gen.path_x(edge_z + 6.0) - side * 2.6, edge_z + 6.0))
	_box(root, Vector3(0.1, 1.5, 0.1), sign_pos + Vector3(0, 0.75, 0), Basis(), "wood", false)
	_box(root, Vector3(1.2, 0.36, 0.05), sign_pos + Vector3(0, 1.35, 0), Basis(), "plank", false)
	label.position = sign_pos + Vector3(0, 1.35, 0.03)
	root.add_child(label)


func _spray(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 1.8
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(2.0, 0.2, 0.6)
	pm.direction = Vector3(0, 1, -0.4)
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0, -1.5, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.2, Color(1, 1, 1, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/mote.gdshader")
	mat.set_shader_parameter("tint", Color(0.85, 0.95, 1.0))
	mat.set_shader_parameter("intensity", 0.35)
	quad.material = mat
	p.draw_pass_1 = quad
	p.position = pos
	return p


# ================================================================ Fallen tree

func _build_fallen_tree(o: Dictionary, root: Node3D) -> void:
	# A giant trunk lies across the whole gorge, its ends stuck in the rock walls.
	var side: float = o["side"]
	var z: float = o["z"]
	var slope := gen.path_slope(z)
	var across := Vector2(1.0, -slope).normalized()   # perpendicular to the path
	var radius := 0.72
	var length := 34.0
	var ground := gen.height(o["px"], z)
	var axis_y: float = ground + 1.22 + radius     # underside ~1.2 m above the path: crouching yes, standing no
	var dir := Vector3(across.x, 0.0, across.y).normalized()
	var center := Vector3(0.0, axis_y, 0.0)
	var basis := Basis(Quaternion(Vector3.UP, dir))

	var body := StaticBody3D.new()
	body.set_meta("climb_over", true)
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = length
	cs.shape = cap
	cs.transform = Transform3D(basis, center)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.8
	cm.bottom_radius = radius * 1.1
	cm.height = length
	cm.radial_segments = 20
	cm.rings = 8
	mi.mesh = cm
	mi.material_override = _mat("log")
	mi.transform = Transform3D(basis, center)
	body.add_child(mi)
	# thick moss blanket on top
	var moss := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = radius * 0.62
	mm.bottom_radius = radius * 0.7
	mm.height = length * 0.8
	moss.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.4, 0.62, 0.16)
	mmat.roughness = 1.0
	moss.material_override = mmat
	moss.transform = Transform3D(basis.scaled(Vector3(1.0, 1.0, 0.55)), center + Vector3(0, radius * 0.5, 0))
	root.add_child(moss)
	# root plate at one end, half in the wall
	var plate := MeshInstance3D.new()
	plate.mesh = StructureModels.root_plate(2.4, int(o["seed"]) % 3)
	var root_end := center - dir * length * 0.5 * side
	plate.transform = Transform3D(basis, root_end)
	root.add_child(plate)
	# the broken top end shows its tree rings
	var top_cap := MeshInstance3D.new()
	top_cap.mesh = StructureModels.log_cap(radius * (0.8 if side > 0.0 else 1.1))
	top_cap.transform = Transform3D(basis * (Basis() if side > 0.0 else Basis(Vector3.RIGHT, PI)), center + dir * length * 0.5 * side)
	root.add_child(top_cap)
	# branch stubs, mushrooms, ferns, flowers on the trunk
	var rng := RandomNumberGenerator.new()
	rng.seed = o["seed"]
	for i in 7:
		var bp := center + dir * rng.randf_range(-12.0, 12.0)
		var branch := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.06
		bm.bottom_radius = 0.2
		bm.height = rng.randf_range(1.2, 2.4)
		branch.mesh = bm
		branch.material_override = _mat("log")
		var bdir := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.3, 1.0), rng.randf_range(-1, 1)).normalized()
		branch.transform = Transform3D(Basis(Quaternion(Vector3.UP, bdir)), bp + bdir * (radius + bm.height * 0.45))
		root.add_child(branch)
	for i in 14:
		var mp := center + dir * rng.randf_range(-11.0, 11.0) + Vector3(0, radius * 0.85, 0)
		var m := MeshInstance3D.new()
		m.mesh = lib.mesh(["Mushroom_Common", "Clover_1", "Mushroom_Laetiporus", "Fern_1", "Flower_3_Single"][i % 5])
		m.position = mp
		m.scale = Vector3.ONE * (0.25 if i % 5 == 3 else rng.randf_range(0.5, 0.9))
		m.rotation.y = rng.randf() * TAU
		root.add_child(m)
	root.set_meta("trunk_info", {"center": center, "dir": dir, "length": length})


## Lift the trunk so that it isn't stuck below the real ground collision anywhere
func _lift_above_ground(body: RigidBody3D, length: float, radius: float) -> void:
	var axis := body.global_basis.z
	var lift := 0.0
	for i in 7:
		var p := body.global_position + axis * ((float(i) / 6.0 - 0.5) * length)
		var g := world.ground_y(p.x, p.z)
		lift = maxf(lift, g + radius + 0.03 - p.y)
	if lift > 0.0:
		body.global_position += Vector3(0, lift, 0)


# ================================================================ Waterfall building block

## Real 3D waterfall: finds the drop-off edge in the terrain, builds several curved strands,
## foam carpet, spray and mist. from_xz is up on the plateau, flow points towards the drop.
func _waterfall(root: Node3D, o: Dictionary, from_xz: Vector2, flow: Vector2, bottom_y: float, width: float) -> void:
	flow = flow.normalized()
	var top := gen.height(from_xz.x, from_xz.y)
	# find the edge: from the plateau in flow direction until the terrain drops clearly
	var lip := from_xz
	for i in 60:
		var p := from_xz + flow * (i * 0.25)
		if gen.height(p.x, p.y) < top - 0.35:
			break
		lip = p
	var h := maxf(top - bottom_y, 1.5)
	# find the foot of the wall: the water must land at least this far out
	var wall_run := 0.0
	for i in 80:
		var p2 := lip + flow * (i * 0.25)
		wall_run = i * 0.25
		if gen.height(p2.x, p2.y) < bottom_y + 0.6:
			break
	var throw := maxf(clampf(h * 0.12, 0.6, 2.2), wall_run + 0.9)
	var side := Vector2(-flow.y, flow.x)
	var strands := [[0.0, width, 0.0], [width * 0.62, width * 0.35, 0.37], [-width * 0.58, width * 0.3, 0.71]]
	for sd in strands:
		var mesh := _fall_mesh(o, lip + side * float(sd[0]), flow, top + 0.06, bottom_y, float(sd[1]), throw * (0.8 + float(sd[2]) * 0.3))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://shaders/waterfall.gdshader")
		fm.set_shader_parameter("noise_tex", _noise)
		fm.set_shader_parameter("length_m", h + 2.0)
		fm.set_shader_parameter("seed", float(sd[2]))
		mi.material_override = fm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var foot := lip + flow * (throw + 0.4)
	var foot_local := Vector3(foot.x - o["px"], bottom_y + 0.05, foot.y - o["z"])
	# foam carpet
	var foam := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width * 2.6, width * 2.6)
	foam.mesh = pm
	var fmat := ShaderMaterial.new()
	fmat.shader = preload("res://shaders/foam.gdshader")
	fmat.set_shader_parameter("noise_tex", _noise)
	foam.material_override = fmat
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.position = foot_local
	root.add_child(foam)
	root.add_child(_spray(foot_local + Vector3(0, 0.3, 0)))
	var fog := FogVolume.new()
	fog.size = Vector3(width * 3.0, 4.5, width * 3.0)
	var fogm := FogMaterial.new()
	fogm.density = 0.07
	fogm.albedo = Color(0.95, 0.98, 1.0)
	fogm.height_falloff = 0.7
	fogm.edge_fade = 0.7
	fog.material = fogm
	fog.position = foot_local + Vector3(0, 1.6, 0)
	root.add_child(fog)
	# rocks to the right and left of the edge – never in the water
	var rs := BiomeDefs.rock_style(Color(0.62, 0.66, 0.72), 0.6)
	for k in [-1.0, 1.0]:
		var rp: Vector2 = lip + side * k * (width * 0.95 + 1.3) - flow * 0.8
		var rock := MeshInstance3D.new()
		rock.mesh = lib.mesh("Rock_Medium_%d" % (2 if k < 0 else 3), rs)
		rock.position = Vector3(rp.x - o["px"], gen.height(rp.x, rp.y) - 0.5, rp.y - o["z"])
		rock.scale = Vector3.ONE * 1.1
		rock.rotation.y = atan2(flow.x, flow.y) + k
		root.add_child(rock)


## Curved strand: flat over the edge at the top, then a parabola downwards
func _fall_mesh(o: Dictionary, lip: Vector2, flow: Vector2, top_y: float, bottom_y: float, width: float, throw: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := Vector2(-flow.y, flow.x)
	var rows := 18
	var cols := 4
	var h := top_y - bottom_y
	var pts := []
	for j in rows + 1:
		var v := float(j) / rows
		var p: Vector3
		if v < 0.12:
			# calm water flowing towards the edge
			var k := v / 0.12
			var xz := lip - flow * (1.0 - k) * 1.2
			p = Vector3(xz.x, top_y - k * 0.08, xz.y)
		else:
			var t := (v - 0.12) / 0.88
			var xz2 := lip + flow * throw * pow(t, 0.35)
			p = Vector3(xz2.x, top_y - 0.08 - t * t * 0.35 * h - t * 0.65 * h, xz2.y)
		pts.append(p)
	for j in rows:
		for i in cols:
			var u0 := float(i) / cols
			var u1 := float(i + 1) / cols
			var quad := []
			for c in [[u0, j], [u1, j], [u1, j + 1], [u0, j + 1]]:
				var base: Vector3 = pts[c[1]]
				var spread := 1.0 + float(c[1]) / rows * 0.35
				var xz := Vector2(base.x, base.z) + side * (float(c[0]) - 0.5) * width * spread
				quad.append([Vector3(xz.x - o["px"], base.y, xz.y - o["z"]), Vector2(c[0], float(c[1]) / rows)])
			for idx in [0, 1, 2, 0, 2, 3]:
				st.set_uv(quad[idx][1])
				st.set_normal(Vector3(-flow.x, 0.3, -flow.y).normalized())
				st.add_vertex(quad[idx][0])
	return st.commit()


# ================================================================ Physics in water

func _physics_process(delta: float) -> void:
	for f in _floaters:
		var body: RigidBody3D = f["body"]
		if not is_instance_valid(body):
			continue
		# only simulate once ground collision is loaded under the whole log
		var bw := world.local_to_world(body.global_position)
		var ready := world.is_ready_around(Vector2(bw.x, bw.z), float(f["len"]) * 0.5 + 2.0)
		if body.freeze != (not ready):
			body.freeze = not ready
			if ready and not body.has_meta("grounded"):
				body.set_meta("grounded", true)
				_lift_above_ground(body, f["len"], f["radius"])
		if not ready or body.sleeping:
			continue
		var length: float = f["len"]
		var radius: float = f["radius"]
		var axis := body.global_basis.z
		var n := 5
		var any := false
		for i in n:
			var t := (float(i) / (n - 1) - 0.5) * length * 0.9
			var p := body.global_position + axis * t
			var w := world.local_to_world(p)
			var wl := gen.water_level(w.x, w.z)
			if wl == -INF or p.y - radius > wl:
				continue
			any = true
			var sub := clampf((wl - (p.y - radius)) / (2.0 * radius), 0.0, 1.0)
			# wood floats: buoyancy up to ~1.7× its weight when fully submerged
			var up := body.mass * 9.8 * 1.7 * sub / n
			var flow := gen.river_flow(w.x, w.z)
			var target := Vector3(flow.x, 0.0, flow.y)
			var rel := target - body.linear_velocity
			rel.y *= 0.5
			body.apply_force(Vector3(0, up, 0) + rel * body.mass * 0.9 * sub / n, p - body.global_position)
		if any:
			body.angular_velocity *= 1.0 - 0.8 * delta


# ================================================================ Stile fence

## A pasture fence across the valley; at the path a wooden stile with steps leads over it.
func _build_stile(o: Dictionary, root: Node3D) -> void:
	var z: float = o["z"]
	var slope := gen.path_slope(z)
	var across := Vector2(1.0, -slope).normalized().rotated(o["angle"])
	var fwd := Vector2(-across.y, across.x)
	var c := Vector2(o["px"], z)
	var half_l: float = o["length"]
	# posts symmetric around the stile, rails between them
	var ts: Array[float] = []
	var t := 0.9
	while t < half_l:
		ts.append(-t)
		ts.append(t)
		t += 2.4
	ts.sort()
	var prev := Vector3.INF
	for i in ts.size():
		var p := _ground(o, c + across * ts[i])
		var stile_post := absf(ts[i]) < 1.0
		_post(root, p, 1.75 if stile_post else 1.3)
		if i % 2 == 0:
			Songbirds.mark(root, p + Vector3(0, (1.75 if stile_post else 1.3) - 0.14, 0))
		if prev != Vector3.INF:
			for h: float in [0.5, 0.95]:
				var a := prev + Vector3(0, h, 0)
				var b := p + Vector3(0, h, 0)
				var d := b - a
				_box(root, Vector3(0.05, 0.12, d.length() + 0.1), (a + b) * 0.5, Basis.looking_at(d.normalized(), Vector3.UP), "plank")
		prev = p
	# stile: three steps on each side and a top board over the upper rail. The steps are only the look;
	# underneath lies an invisible ramp (35°) so walking over works smoothly without a jump.
	var face := Basis.looking_at(Vector3(fwd.x, 0.0, fwd.y), Vector3.UP)
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var h := 0.8 - 0.27 * k
			var d := 0.5 + k * 0.5
			var g := _ground(o, c + fwd * d * side)
			_box(root, Vector3(1.2, h, 0.5), g + Vector3(0, h * 0.5, 0), face, "plank", false)
		var top_p := _ground(o, c + fwd * 0.25 * side) + Vector3(0, 1.1, 0)
		var foot := _ground(o, c + fwd * 1.8 * side) + Vector3(0, 0.02, 0)
		var ramp_dir := (foot - top_p).normalized()
		var ramp := StaticBody3D.new()
		var rcs := CollisionShape3D.new()
		var rbox := BoxShape3D.new()
		rbox.size = Vector3(1.2, 0.06, (foot - top_p).length())
		rcs.shape = rbox
		ramp.add_child(rcs)
		ramp.transform = Transform3D(Basis.looking_at(ramp_dir, Vector3.UP), (top_p + foot) * 0.5 - Vector3(0, 0.03, 0))
		root.add_child(ramp)
	var top := _ground(o, c)
	_box(root, Vector3(1.2, 1.06, 0.5), top + Vector3(0, 0.53, 0), face, "plank")

	# the fence ends in bushes
	for side: float in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = lib.mesh("Bush_Common", {"leaves": BiomeDefs.leaves(Color(0.2, 0.42, 0.1), Color(0.5, 0.75, 0.2), {"sphere_normals": 0.85}), "stiffness": 6.0})
		mi.position = _ground(o, c + across * side * (half_l + 1.4))
		mi.scale = Vector3.ONE * 2.2
		root.add_child(mi)


# ================================================================ Mud hollow

var _mud_mat: ShaderMaterial


## The path runs through a wide patch of mud (slow and tiring, see Wanderer); a few flat stones lead across.
func _build_mud(o: Dictionary, root: Node3D) -> void:
	var z: float = o["z"]
	var half_len: float = o["len"] * 1.4
	var half_wid: float = o["wid"] * 1.4
	var step := 0.7
	var nz := int(half_len * 2.0 / step) + 1
	var nx := int(half_wid * 2.0 / step) + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	for j in nz:
		var zz := z - half_len + j * step
		var px := gen.path_x(zz)
		for i in nx:
			var x := px - half_wid + i * step
			verts.append(Vector3(x - o["px"], gen.height(x, zz) + 0.05, zz - z))
			cols.append(Color(1, 1, 1, gen.mud_at(x, zz)))
			norms.append(Vector3.UP)
	var idx := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if _mud_mat == null:
		_mud_mat = ShaderMaterial.new()
		_mud_mat.shader = preload("res://shaders/mud.gdshader")
		_mud_mat.set_shader_parameter("noise_tex", _noise)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mud_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# stepping stones beside the path center, far enough apart that you have to hop
	var side: float = o["side"]
	var zz2: float = z + float(o["len"]) * 0.85
	var rng := RandomNumberGenerator.new()
	rng.seed = o["seed"]
	while zz2 > z - float(o["len"]) * 0.85:
		var x2 := gen.path_x(zz2) + side * rng.randf_range(1.5, 1.9)
		var g := _ground(o, Vector2(x2, zz2))
		var size := Vector3(rng.randf_range(0.7, 0.9), 0.3, rng.randf_range(0.6, 0.8))
		_box(root, size, g + Vector3(0, 0.08, 0), Basis(Vector3.UP, rng.randf() * TAU), "stone")
		zz2 -= rng.randf_range(1.25, 1.5)


# ================================================================ Boulder field

var _hull_cache := {}


## A rockslide across the valley: big boulders with a narrow winding way through, small ones to hop over.
func _build_boulders(o: Dictionary, root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = o["seed"]
	var z: float = o["z"]
	var band: float = o["band"]
	var half: float = o["half"]
	var style := BiomeDefs.rock_style(Color(0.66, 0.66, 0.68), 0.45)
	var models := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	for i in 46:
		var dz := rng.randf_range(-band, band)
		var zz := z + dz
		var px := gen.path_x(zz)
		var way := px + sin(zz * 0.35 + float(o["seed"] % 100)) * 0.8
		var x := px + rng.randf_range(-half, half)
		var big := rng.randf() < 0.78
		var s := rng.randf_range(1.3, 3.2) if big else rng.randf_range(0.45, 0.7)
		var model: String = models[rng.randi() % models.size()]
		var mesh := lib.mesh(model, style)
		# keep a 2.4 m wide way free (measured from the rock's real footprint)
		var aabb := mesh.get_aabb()
		var radius := maxf(absf(aabb.position.x), absf(aabb.end.x)) * s
		radius = maxf(radius, maxf(absf(aabb.position.z), absf(aabb.end.z)) * s)
		var keep := 1.2 + radius
		if big and absf(x - way) < keep:
			x = way + signf(x - way + 0.001) * (keep + rng.randf() * 3.0)
		elif not big and absf(x - way) < 0.9 + radius:
			# small stones lie beside the way, not in its narrowest line
			x = way + signf(x - way + 0.001) * (0.9 + radius)
		var rot := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.2, 0.2))
		var pos := _ground(o, Vector2(x, zz), -s * 0.22)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var hull := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for pnt in _rock_hull(model, mesh):
			pts.append(pnt * s)
		hull.points = pts
		cs.shape = hull
		cs.basis = rot
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.basis = rot.scaled(Vector3.ONE * s)
		body.add_child(mi)
		body.position = pos
		root.add_child(body)


func _rock_hull(model: String, mesh: Mesh) -> PackedVector3Array:
	if not _hull_cache.has(model):
		var shape := mesh.create_convex_shape(true, true) as ConvexPolygonShape3D
		_hull_cache[model] = shape.points
	return _hull_cache[model]
