class_name ForageManager
extends Node
## Things to gather beside the trail: berry bushes (red, blue or black berries), mushroom clusters at the
## foot of trees (edible ones, now and then fly agarics) and flat pebbles on the shores of ponds and brooks.
## Deterministic per world, appear with the near chunks; what you took stays gone for this journey.

const CELL := 48.0

var gen: WorldGen
var world: ChunkManager
var lib: AssetLibrary
var taken := {}
var _berry_mats := {}


func setup(p_gen: WorldGen, p_world: ChunkManager, p_lib: AssetLibrary) -> void:
	gen = p_gen
	world = p_world
	lib = p_lib
	world.chunk_ready.connect(_on_chunk_ready)


## Pure function: what grows in cell (cx, cz) – {} or {type, x, z, variant, uid}
static func plan(gen: WorldGen, cx: int, cz: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([gen.seed_value, cx, cz, 515])
	var roll := rng.randf()
	var z := (cz + rng.randf()) * CELL
	var r := gen.row(z)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var off: float = r["half_w"] + rng.randf_range(2.0, 7.0)
	var x: float = r["px"] + side * off / r["inv_len"]
	# only the cell that holds the path at this z (one column of cells along the trail)
	if floori(x / CELL) != cx:
		return {}
	var biome := gen.dominant_biome(z)
	var atmo: Dictionary = gen.biomes[biome]["atmosphere"]
	var forest: bool = float(atmo.get("shafts", 0.0)) >= 0.5
	var dry: bool = float(atmo.get("rain", 1.0)) <= 0.0
	var out := {"x": x, "z": z, "uid": hash([gen.seed_value, cx, cz, 1]) & 0x7fffffff, "variant": rng.randi() % 3}
	if gen.obstacle_zone(z, 30.0) or gen.water_level(x, z) > -INF:
		return {}
	# on the shore of a brook or pond (water within a few meters, but dry here): flat pebbles
	for dx: float in [-2.0, 2.0, -3.5, 3.5, -5.0, 5.0]:
		if gen.water_level(x + dx, z) > -INF:
			if roll < 0.85:
				out["type"] = "kiesel"
				return out
			return {}
	if dry:
		return {}
	if roll < (0.16 if forest else 0.12):
		out["type"] = "beeren"
	elif roll < (0.3 if forest else 0.17):
		out["type"] = "pilze"
		# now and then the pretty, poisonous kind
		out["variant"] = 1 if rng.randf() < 0.3 else 0
	else:
		return {}
	return out


func _on_chunk_ready(coord: Vector2i, node: Node3D, lod: int) -> void:
	if lod != 0:
		return
	var z0 := coord.y * ChunkBuilder.SIZE
	var cz0 := floori(z0 / CELL)
	var cz1 := floori((z0 + ChunkBuilder.SIZE) / CELL)
	var corner := Vector2(coord.x * ChunkBuilder.SIZE, z0)
	for cz in range(cz0, cz1 + 1):
		var r := gen.row((cz + 0.5) * CELL)
		var px: float = r["px"]
		for cx in range(floori((px - 20.0) / CELL), floori((px + 20.0) / CELL) + 1):
			var p := plan(gen, cx, cz)
			if p.is_empty() or taken.has(p["uid"]):
				continue
			if p["x"] < corner.x or p["x"] >= corner.x + ChunkBuilder.SIZE or p["z"] < z0 or p["z"] >= z0 + ChunkBuilder.SIZE:
				continue
			# also the pebbles' water check: shores only, not deep in a pond
			var root := _build(p, corner)
			if root:
				node.add_child(root)


func _build(p: Dictionary, corner: Vector2) -> Node3D:
	var x: float = p["x"]
	var z: float = p["z"]
	var root := Node3D.new()
	root.position = Vector3(x - corner.x, gen.height(x, z), z - corner.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = p["uid"]
	root.rotation.y = rng.randf() * TAU
	match p["type"]:
		"beeren":
			_berry_bush(root, rng, int(p["variant"]), p["uid"])
		"pilze":
			_mushrooms(root, rng, int(p["variant"]), p["uid"])
		"kiesel":
			for i in 3:
				var mi := MeshInstance3D.new()
				mi.mesh = ItemDefs.make_mesh("kiesel")
				mi.position = Vector3(rng.randf_range(-0.4, 0.4), 0.01, rng.randf_range(-0.4, 0.4))
				mi.rotation.y = rng.randf() * TAU
				mi.scale = Vector3.ONE * rng.randf_range(1.2, 1.8)
				root.add_child(mi)
				# picked up by hand, one by one
				var pa := _grab_area(root, mi.position + Vector3(0, 0.04, 0), 0.09, {"kind": "tear", "what": "pebble", "resist": 0.0, "stretch": 0.01, "pull": 0.5})
				pa.set_meta("on_tear", func(w: Wanderer):
					if not w.inventory.add(ItemDefs.make("kiesel")):
						w.message.emit("No room in the backpack.")
						return
					mi.queue_free()
					pa.queue_free())
			_interactable(root, Vector3(0, 0.2, 0), Vector3(1.4, 0.6, 1.4), "Pick up flat pebbles", func(w: Wanderer):
				var n := 0
				for i in 3:
					if w.inventory.add(ItemDefs.make("kiesel")):
						n += 1
				if n == 0:
					w.message.emit("No room in the backpack.")
					return
				taken[p["uid"]] = true
				root.queue_free()
				w.message.emit("%d flat pebbles – perfect for skipping." % n))
	return root


## A bush heavy with berries: red currants, blueberries or blackberries, in bunches on the outside
func _berry_bush(root: Node3D, rng: RandomNumberGenerator, variant: int, uid: int) -> void:
	var bush := MeshInstance3D.new()
	var model: String = ["Bush_Common", "Bush_Large", "Bush_Long_1"][variant]
	bush.mesh = lib.mesh(model, {"leaves": {"color_dark": Color(0.14, 0.38, 0.08), "color_light": Color(0.44, 0.7, 0.16), "sphere_normals": 0.85}, "stiffness": 6.0})
	var bs := 1.2 if model == "Bush_Common" else 0.7
	bush.scale = Vector3.ONE * bs
	root.add_child(bush)
	var colors := [Color(0.85, 0.08, 0.12), Color(0.22, 0.28, 0.62), Color(0.12, 0.06, 0.16)]
	var names := ["red currants", "blueberries", "blackberries"]
	var berry_col: Color = colors[variant]
	var aabb := bush.mesh.get_aabb()
	var bmesh := SphereMesh.new()
	bmesh.radius = 0.05
	bmesh.height = 0.1
	bmesh.radial_segments = 8
	bmesh.rings = 4
	var berries := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bmesh
	mm.instance_count = 60
	berries.multimesh = mm
	berries.material_override = _berry_mat(berry_col)
	berries.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half := aabb.size * 0.5 * bs
	var center := aabb.get_center() * bs
	var bunches := []
	for i in 20:
		# bunches of three on the outer shell of the bush
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.0), rng.randf_range(-1, 1)).normalized()
		var at := center + Vector3(dir.x * half.x, dir.y * half.y, dir.z * half.z) * 0.92
		for k in 3:
			var o := Vector3(rng.randf_range(-0.05, 0.05), -k * 0.05, rng.randf_range(-0.05, 0.05))
			mm.set_instance_transform(i * 3 + k, Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), at + o))
		bunches.append(at)
	root.add_child(berries)
	# every bunch can be pulled off by hand (a little resistance): +1 handful in the backpack
	var left := [bunches.size()]
	for i in bunches.size():
		var area := _grab_area(root, bunches[i] + Vector3(0, -0.05, 0), 0.11,
			{"kind": "tear", "what": names[variant], "resist": 0.25, "stretch": 0.08, "pull": 0.3})
		area.set_meta("on_tear", func(w: Wanderer):
			if not ItemDefs.add_picked(w.inventory, "beeren"):
				w.message.emit("No room in the backpack.")
				return
			for k in 3:
				mm.set_instance_transform(i * 3 + k, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3.ZERO))
			area.queue_free()
			left[0] -= 1
			Sfx.play(w, "stone_click", -16.0, 2.2)
			if left[0] <= 0:
				taken[uid] = true
				for c in root.get_children():
					if c.has_meta("poi_prompt"):
						c.queue_free()
				w.message.emit("The last %s – the bush is bare." % names[variant]))
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = maxf(half.x, half.z) * 0.8
	cs.shape = sh
	cs.position = center
	body.add_child(cs)
	root.add_child(body)
	Songbirds.mark(root, center + Vector3(0, half.y * 0.9, 0))
	# picking is done by hand now: the prompt only tells how
	_interactable(root, center, Vector3(half.x * 2.4, half.y * 2.2, half.z * 2.4), func(_w: Wanderer) -> String:
		return "You can pick the %s by hand: hold %s or %s on a bunch" % [names[variant], GameInput.glyph("hand_left"), GameInput.glyph("hand_right")],
		func(w: Wanderer): w.message.emit("Hold a hand button on a bunch and pull."))
	# a punch shakes the bush
	body.set_meta("punch", func(w: Wanderer, _at: Vector3, _dir: Vector3):
		var tw := bush.create_tween()
		tw.tween_property(bush, "scale", Vector3.ONE * bs * Vector3(1.08, 0.94, 1.08), 0.07)
		tw.tween_property(bush, "scale", Vector3.ONE * bs * Vector3(0.96, 1.04, 0.96), 0.1)
		tw.tween_property(bush, "scale", Vector3.ONE * bs, 0.18)
		Sfx.play(w, "whoosh", -14.0, 0.7))


## A cluster of mushrooms at the foot of a tree or in the grass: edible ones, or fly agarics
func _mushrooms(root: Node3D, rng: RandomNumberGenerator, variant: int, uid: int) -> void:
	var group := Node3D.new()
	root.add_child(group)
	var agaric := variant == 1
	for i in rng.randi_range(4, 7):
		var mi := MeshInstance3D.new()
		mi.mesh = lib.mesh("Mushroom_RedCap" if agaric else "Mushroom_Common")
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.5)
		mi.position = Vector3(cos(a) * d, 0.0, sin(a) * d)
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * (rng.randf_range(0.35, 0.55) if agaric else rng.randf_range(1.1, 1.6))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.add_child(mi)
		# pulled out one by one (they hold on a bit)
		var ma := _grab_area(root, mi.position + Vector3(0, 0.08, 0), 0.1,
			{"kind": "tear", "what": "fly agaric" if agaric else "mushroom", "resist": 0.45, "stretch": 0.14, "pull": 0.25})
		ma.set_meta("on_tear", func(w: Wanderer):
			if not ItemDefs.add_picked(w.inventory, "fliegenpilz" if agaric else "pilze"):
				w.message.emit("No room in the backpack.")
				return
			mi.queue_free()
			ma.queue_free())
	_interactable(root, Vector3(0, 0.2, 0), Vector3(1.3, 0.6, 1.3), "Gather fly agarics" if agaric else "Gather mushrooms", func(w: Wanderer):
		var id := "fliegenpilz" if agaric else "pilze"
		var n := 0
		for i in 2:
			if w.inventory.add(ItemDefs.make(id)):
				n += 1
		if n == 0:
			w.message.emit("No room in the backpack.")
			return
		taken[uid] = true
		root.queue_free()
		w.message.emit("Fly agarics – pretty, but better not eat them." if agaric else "A handful of mushrooms. They smell good."))


func _berry_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _berry_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.25
		m.rim_enabled = true
		m.rim = 0.4
		_berry_mats[key] = m
	return _berry_mats[key]


## An area the hands can grip (Hands.GRAB_LAYER) with its grip description
func _grab_area(root: Node3D, pos: Vector3, radius: float, grab: Dictionary) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = Hands.GRAB_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("grab", grab)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	area.add_child(cs)
	area.position = pos
	root.add_child(area)
	return area


func _interactable(root: Node3D, pos: Vector3, size: Vector3, prompt, action: Callable) -> void:
	var area := Area3D.new()
	area.collision_layer = 1 << 2
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("poi_prompt", prompt)
	area.set_meta("poi_action", action)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	area.position = pos
	root.add_child(area)
