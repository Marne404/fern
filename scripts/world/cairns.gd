class_name Cairns
extends Node
## Cairns and skipping stones.
## Cairns: little stone towers at some spots beside the trail; add a stone to one ("Add a stone") or start
## your own with a pebble or a pretty stone. What you built is saved per world (user://cairns.cfg).
## Skipping stones: use a flat pebble facing water and it skips over the surface, ringing the water.

const CELL := 520.0
const PATH := "user://cairns.cfg"

var gen: WorldGen
var world: ChunkManager
var player: Wanderer
var _added := {}          # key (planned cairn uid or own cairn id) → stones added
var _own: Array = []      # own cairns: [id, x, z]
var _nodes := {}          # key → Node3D (built cairns that are loaded right now)
var _stone_meshes: Array[Mesh] = []
var _flying: Array = []   # skipping stones in flight


func setup(p_gen: WorldGen, p_world: ChunkManager) -> void:
	gen = p_gen
	world = p_world
	world.chunk_ready.connect(_on_chunk_ready)
	for i in 6:
		_stone_meshes.append(StructureModels.lumpy(Vector3(0.32, 0.12, 0.26) * (1.0 - i * 0.07), 2.4, 40 + i, 0.16, 6, 10))
	_load()


## Pure function: the cairn standing near the trail in cell k, or {}
static func plan(gen: WorldGen, k: int) -> Dictionary:
	if k < 1:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([gen.seed_value, k, 616])
	if rng.randf() > 0.6:
		return {}
	var z := -(k + 0.2 + rng.randf() * 0.6) * CELL
	if gen.obstacle_zone(z, 50.0):
		return {}
	var r := gen.row(z)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var x: float = r["px"] + side * (float(r["half_w"]) + rng.randf_range(1.6, 3.0)) / r["inv_len"]
	if gen.water_level(x, z) > -INF:
		return {}
	return {"key": "c%d" % k, "x": x, "z": z, "stones": rng.randi_range(3, 6), "seed": rng.randi()}


func _on_chunk_ready(coord: Vector2i, node: Node3D, lod: int) -> void:
	if lod != 0:
		return
	var corner := Vector2(coord.x * ChunkBuilder.SIZE, coord.y * ChunkBuilder.SIZE)
	var rect := Rect2(corner, Vector2(ChunkBuilder.SIZE, ChunkBuilder.SIZE))
	var k0 := floori(-(corner.y + ChunkBuilder.SIZE) / CELL) - 1
	for k in range(maxi(k0, 1), k0 + 3):
		var p := plan(gen, k)
		if not p.is_empty() and rect.has_point(Vector2(p["x"], p["z"])):
			_build(node, p["key"], Vector2(p["x"], p["z"]), int(p["stones"]), int(p["seed"]), corner)
	for o in _own:
		if rect.has_point(Vector2(o[1], o[2])):
			_build(node, o[0], Vector2(o[1], o[2]), 0, hash(o[0]), corner)


## A tower of flat stones, biggest at the bottom, each a little turned and offset
func _build(parent: Node3D, key: String, at: Vector2, base_count: int, seed_v: int, corner: Vector2) -> void:
	var root := Node3D.new()
	root.position = Vector3(at.x - corner.x, gen.height(at.x, at.y) - 0.03, at.y - corner.y)
	root.set_meta("cairn", key)
	parent.add_child(root)
	root.tree_exiting.connect(func(): if _nodes.get(key) == root: _nodes.erase(key))
	_nodes[key] = root
	root.set_meta("seed", seed_v)
	root.set_meta("base", base_count)
	_restack(root)
	var area := Area3D.new()
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("poi_prompt", func(w: Wanderer) -> String:
		return "Add a stone to the cairn" if _stone_item(w) != {} else "A cairn – bring a stone to add one")
	area.set_meta("poi_action", func(w: Wanderer):
		var it := _stone_item(w)
		if it.is_empty():
			w.message.emit("You need a flat pebble or a pretty stone.")
			return
		_add_stone(w, it, key))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.2, 1.4, 1.2)
	cs.shape = sh
	area.add_child(cs)
	area.position = Vector3(0, 0.6, 0)
	root.add_child(area)
	Songbirds.mark(root, Vector3(0, 0.05, 0))


func _restack(root: Node3D) -> void:
	for c in root.get_children():
		if c.has_meta("stone"):
			c.free()
	var key: String = root.get_meta("cairn")
	var n := int(root.get_meta("base")) + int(_added.get(key, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root.get_meta("seed"))
	var y := 0.0
	var shrink := 1.0
	var top := Vector3.ZERO
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = _stone_meshes[mini(i, _stone_meshes.size() - 1)]
		var s := shrink * rng.randf_range(0.9, 1.1)
		var h := 0.2 * s
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.08, 0.08)).scaled(Vector3.ONE * s),
			Vector3(rng.randf_range(-0.03, 0.03), y + h * 0.5, rng.randf_range(-0.03, 0.03)))
		mi.material_override = _stone_mat(rng.randf())
		mi.set_meta("stone", true)
		root.add_child(mi)
		y += h * 0.82
		shrink = maxf(shrink * 0.9, 0.45)
		top = Vector3(0, y, 0)
	# the songbird perch sits on the top stone
	for c in root.get_children():
		if c.is_in_group("perch"):
			c.position = top


var _mats := {}


func _stone_mat(t: float) -> Material:
	var k := int(t * 3.0)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = [Color("9a9a94"), Color("aaa69c"), Color("8e928f")][k]
		m.roughness = 0.9
		_mats[k] = m
	return _mats[k]


func _stone_item(w: Wanderer) -> Dictionary:
	for id in ["kiesel", "stein"]:
		for it in w.inventory.items:
			if it["id"] == id:
				return it
	return {}


func _add_stone(w: Wanderer, it: Dictionary, key: String) -> void:
	w.inventory.remove(it)
	_added[key] = int(_added.get(key, 0)) + 1
	if _nodes.has(key):
		_restack(_nodes[key])
	Sfx.play(w, "stone_click", -8.0)
	var total := int(_added[key])
	w.message.emit("Click. One more stone on the cairn." if total < 3 else "The cairn grows. Someone will find it and smile.")
	_save()


## A pebble or stone was used from the backpack: skip it over water, add it to a cairn, or start one
func use_stone(w: Wanderer, it: Dictionary) -> void:
	var fwd := -w.camera.global_basis.z if w.camera else -w.global_basis.z
	var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var wp := world.local_to_world(w.global_position)
	# water ahead? (within 3–14 m)
	for d in [3.0, 5.0, 7.0, 10.0, 14.0]:
		var q: Vector3 = wp + flat * d
		if gen.water_level(q.x, q.z) > -INF:
			if it["id"] != "kiesel":
				w.message.emit("Too round to skip. It sinks with a plop.")
				w.inventory.remove(it)
				_throw(w, flat, 1, false)
				return
			w.inventory.remove(it)
			_throw(w, flat, _roll_skips(), true)
			return
	# a cairn close by?
	for key in _nodes:
		var n: Node3D = _nodes[key]
		if is_instance_valid(n) and n.global_position.distance_to(w.global_position) < 2.5:
			_add_stone(w, it, key)
			return
	# start an own cairn just in front
	var at := wp + flat * 1.2
	var id := "o%d_%d" % [roundi(at.x), roundi(at.z)]
	_own.append([id, at.x, at.z])
	_added[id] = 1
	w.inventory.remove(it)
	# into the chunk it stands in (so it moves with the floating origin and unloads with the chunk)
	var cc := Vector2i(floori(at.x / ChunkBuilder.SIZE), floori(at.z / ChunkBuilder.SIZE))
	var ch: Dictionary = world._chunks.get(cc, {})
	if ch.is_empty() or ch["node"] == null:
		_save()
		return
	_build(ch["node"], id, Vector2(at.x, at.z), 0, hash(id), Vector2(cc.x * ChunkBuilder.SIZE, cc.y * ChunkBuilder.SIZE))
	Sfx.play(w, "stone_click", -8.0)
	w.message.emit("You set down a stone. The start of a cairn.")
	_save()


## Skips: mostly 3–7, sometimes a great throw
func _roll_skips() -> int:
	var r := randf()
	if r < 0.1:
		return randi_range(0, 1)
	if r < 0.85:
		return randi_range(3, 7)
	return randi_range(8, 12)


## The stone flies out low over the water and bounces, each hop shorter, with a ring at every touch
func _throw(w: Wanderer, dir: Vector3, skips: int, flat: bool) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ItemDefs.make_mesh("kiesel" if flat else "stein")
	mi.scale = Vector3.ONE * 1.6
	world.add_child(mi)
	mi.global_position = w.global_position + Vector3(0, 1.1, 0) + dir * 0.5
	_flying.append({"node": mi, "vel": dir * 12.0 + Vector3(0, 1.5, 0), "skips": skips, "count": 0, "w": w, "spin": 0.0})
	Sfx.play(w, "whoosh", -12.0)


func _process(delta: float) -> void:
	for i in range(_flying.size() - 1, -1, -1):
		var f: Dictionary = _flying[i]
		var n: MeshInstance3D = f["node"]
		if not is_instance_valid(n):
			_flying.remove_at(i)
			continue
		var v: Vector3 = f["vel"]
		v.y -= 9.8 * delta
		n.global_position += v * delta
		f["spin"] = float(f["spin"]) + delta * 25.0
		n.rotation = Vector3(0.0, float(f["spin"]), 0.0)
		var wp := world.local_to_world(n.global_position)
		var lvl := gen.water_level(wp.x, wp.z)
		var ground := gen.height(wp.x, wp.z)
		var w: Wanderer = f["w"]
		if lvl > -INF and wp.y <= lvl:
			var local_hit := world.world_to_local(Vector3(wp.x, lvl, wp.z))
			if is_instance_valid(w):
				w.add_ring(local_hit, 1.2)
			if int(f["count"]) < int(f["skips"]):
				f["count"] = int(f["count"]) + 1
				# each skip a bit lower and shorter
				v = Vector3(v.x * 0.82, absf(v.y) * 0.62 + 0.4, v.z * 0.82)
				n.global_position.y = local_hit.y + 0.01
				if is_instance_valid(w):
					Sfx.play(w, "skip", -14.0, randf_range(0.9, 1.25))
			else:
				_done(f, i, true)
				continue
		elif lvl == -INF and wp.y <= ground:
			_done(f, i, false)
			continue
		f["vel"] = v
		if n.global_position.length() > 1e6:
			_done(f, i, false)


func _done(f: Dictionary, i: int, sank: bool) -> void:
	var n: Node3D = f["node"]
	n.queue_free()
	_flying.remove_at(i)
	var w: Wanderer = f["w"]
	if not is_instance_valid(w):
		return
	var c := int(f["count"])
	if sank:
		Sfx.play(w, "plop", -10.0)
	if c == 0:
		w.message.emit("Plop. Straight down.")
	elif c < 4:
		w.message.emit("%d skips." % c)
	elif c < 8:
		w.message.emit("%d skips! Nice throw." % c)
	else:
		w.message.emit("%d skips!! That one's going in the journal." % c)


func _save() -> void:
	# test runs (--preset/--set) don't write the player's files
	if not Settings.persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var s := str(gen.seed_value)
	cfg.set_value(s, "added", _added)
	cfg.set_value(s, "own", _own)
	cfg.save(PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	var s := str(gen.seed_value)
	_added = cfg.get_value(s, "added", {})
	_own = cfg.get_value(s, "own", [])
