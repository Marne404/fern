extends Node
## Automated obstacle test (phase C). Start: godot --path . -- --obtest
## Simulates real key presses via Input.parse_input_event.

var main: Node
var _fails := 0
var _results: Array[String] = []


func check(name: String, ok: bool, info := "") -> void:
	var line := ("  OK     " if ok else "  FAIL   ") + name + ("  (" + info + ")" if info != "" else "")
	print(line)
	_results.append(line)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func secs(t: float) -> void:
	await frames(int(t * 60.0))


func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func release_all() -> void:
	for k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_CTRL, KEY_SPACE, KEY_SHIFT]:
		key(k, false)


## Put the player at a world position and wait until ground and obstacle are loaded
func place(p: Wanderer, wpos: Vector3, k := -1) -> void:
	release_all()
	# every check starts rested: fatigue from earlier checks must not make results timing-dependent
	p.body.stamina = 100.0
	p.body.food = 90.0
	p.body.water = 90.0
	p.body.rest = 90.0
	p.body.health = 100.0
	p.body.state = Body.State.FIT
	p.autopilot = Callable()
	p.rope = {}
	p.velocity = Vector3.ZERO
	var w: ChunkManager = main.world
	w.focus = Vector2(wpos.x, wpos.z)
	p.global_position = w.world_to_local(wpos)
	main._update_focus()
	var tries := 0
	while (not w.is_ready_around(Vector2(wpos.x, wpos.z), 20.0) or (k >= 0 and not main.obstacles._built.has(k))) and tries < 1200:
		p.global_position = w.world_to_local(wpos)
		p.velocity = Vector3.ZERO
		await get_tree().process_frame
		tries += 1
	var lp := w.world_to_local(wpos)
	lp.y = maxf(lp.y, w.ground_y(lp.x, lp.z) + 0.1)
	p.global_position = lp
	if tries >= 1200:
		print("    [place] timeout at %s: ready=%s built=%s cam=%s" % [wpos, w.is_ready_around(Vector2(wpos.x, wpos.z), 20.0), main.obstacles._built.keys(), w.local_to_world(p.camera.global_position)])
	await frames(3)


func wpos(p: Wanderer) -> Vector3:
	return main.world.local_to_world(p.global_position)


## Direction in world coordinates as autopilot (local = world for directions)
func steer(p: Wanderer, dir: Vector3) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	p.autopilot = func() -> Vector3: return d
	p.look_along(d)


func run() -> void:
	print("== Obstacle test ==")
	while main.player == null or not main.player.is_physics_processing():
		await get_tree().process_frame
	var p: Wanderer = main.player
	var gen: WorldGen = main.gen
	var ob: ObstacleManager = main.obstacles
	ob.on_knot = func(_book: bool, cb: Callable) -> void: cb.call(_knot_q)
	p.body.food = 100.0
	p.body.water = 100.0

	await _test_fallen_tree(p, gen, ob)
	await _test_river(p, gen, ob)
	await _test_rope(p, gen, ob)
	await _test_cliff(p, gen, ob)
	await _test_bounds(p, gen, ob)
	await _test_stile(p, gen)
	await _test_mud(p, gen)
	await _test_boulders(p, gen)
	await _test_freecam(p, gen)

	print("== %s: %d failures ==" % ["PASSED" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


var _knot_q := 0.9


# ---------------------------------------------------------------- fallen tree

func _test_fallen_tree(p: Wanderer, gen: WorldGen, ob: ObstacleManager) -> void:
	var o := gen.obstacle(0)
	var z0: float = o["z"]
	var start := gen.path_point(z0 + 6.0) + Vector3(0, 0.3, 0)
	var fwd := (gen.path_point(z0 - 6.0) - start) * Vector3(1, 0, 1)
	await place(p, start, 0)
	steer(p, fwd)
	await secs(4.0)
	check("Can't walk under the trunk upright", wpos(p).z > z0 - 0.3, "z=%.1f, trunk at %.1f" % [wpos(p).z, z0])

	# crouching with heavy luggage: gets stuck
	var stones: Array = []
	for i in 10:
		var s := ItemDefs.make("stein")
		if p.inventory.add(s):
			stones.append(s)
	await place(p, start, 0)
	steer(p, fwd)
	key(KEY_CTRL, true)
	await secs(5.0)
	check("With 12+ kg the backpack gets stuck", wpos(p).z > z0 + 0.3, "%.1f kg" % p.inventory.total_weight())
	key(KEY_CTRL, false)
	for s in stones:
		p.inventory.remove(s)

	# crouching without luggage: fits underneath
	await place(p, start, 0)
	steer(p, fwd)
	key(KEY_CTRL, true)
	await secs(9.0)
	check("Crouched under the trunk", wpos(p).z < z0 - 1.0, "z=%.1f" % wpos(p).z)
	key(KEY_CTRL, false)
	p.autopilot = Callable()
	await secs(1.0)
	check("Stood up again after the trunk", not p.crouching)

	# climb over
	await place(p, start, 0)
	steer(p, fwd)
	await secs(2.5)
	p.autopilot = Callable()
	var st0 := p.body.stamina
	key(KEY_SPACE, true)
	await frames(4)
	key(KEY_SPACE, false)
	await secs(2.0)
	check("Climbed over the trunk", wpos(p).z < z0 - 0.8 and p.body.stamina < st0, "z=%.1f, stamina %.0f→%.0f" % [wpos(p).z, st0, p.body.stamina])


# ---------------------------------------------------------------- river

func _river_log(ob: ObstacleManager, k: int, idx: int) -> RigidBody3D:
	var root: Node3D = ob._built[k]
	for c in root.get_children():
		if c is RigidBody3D and c.get_meta("log_index", -1) == idx:
			return c
	return null


func _test_river(p: Wanderer, gen: WorldGen, ob: ObstacleManager) -> void:
	var o := gen.obstacle(1)
	var k: int = o["k"]
	var f := ob.river_frame(o)
	var n: Vector2 = f["fwd"]
	var a: Vector2 = f["axis"]
	var n3 := Vector3(n.x, 0, n.y)
	var near: Vector2 = f["near"]
	var far: Vector2 = f["far"]

	# push the log
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) - n3 * 6.0, k)
	var lg := _river_log(ob, k, 0)
	check("Long log exists", lg != null)
	if lg == null:
		return
	await secs(1.0)
	var axis := lg.global_basis.z
	if axis.dot(n3) < 0.0:
		axis = -axis
	var length: float = lg.get_meta("length")
	var back: Vector3 = main.world.local_to_world(lg.global_position - axis * (length * 0.5 + 0.9))
	back.y = gen.height(back.x, back.z) + 0.3
	await place(p, back, k)
	var before := lg.global_position
	steer(p, axis)
	await secs(10.0)
	p.autopilot = Callable()
	var moved := (lg.global_position - before).dot(axis)
	check("Log can be pushed slowly alone", moved > 2.0, "%.1f m in 10 s" % moved)

	# lay the log across the river and balance over it
	# next to the bridge line (that's where the bases are)
	var mid := (near + far) * 0.5 + a * 5.5
	# rest the log on both banks: the higher bank edge counts
	var top := -INF
	for bank in [near - n * 3.0, far + n * 3.0]:
		var bp: Vector2 = bank + a * 5.5
		top = maxf(top, gen.height(bp.x, bp.y))
	var span_xf := Transform3D(Basis(Vector3(n.y, 0, -n.x), Vector3.UP, n3), main.world.world_to_local(Vector3(mid.x, top + 0.5, mid.y)))
	lg.global_transform = span_xf
	lg.linear_velocity = Vector3.ZERO
	lg.angular_velocity = Vector3.ZERO
	await secs(2.0)
	var lax := lg.global_basis.z
	if lax.dot(n3) < 0.0:
		lax = -lax
	lax.y = 0.0
	lax = lax.normalized()
	var lcw: Vector3 = main.world.local_to_world(lg.global_position)
	var start := lcw - lax * (length * 0.5 + 1.2)
	start.y = gen.height(start.x, start.z) + 0.3
	await place(p, start, k)
	steer(p, lax)
	var swam := false
	for i in 20 * 60:
		await get_tree().physics_frame
		if p.swimming:
			swam = true
		if i > 120 and (Vector2(wpos(p).x, wpos(p).z) - far).dot(n) > 0.5:
			break
		# step up at the log's end
		if i == 90:
			key(KEY_SPACE, true)
		if i == 94:
			key(KEY_SPACE, false)
	p.autopilot = Callable()
	var d_far := (Vector2(wpos(p).x, wpos(p).z) - far).dot(n)
	check("Balanced across the log to the far bank", not swam and d_far > -1.0, "distance to bank %.1f m" % d_far)

	# swimming: the current carries you away, you get wet
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) + Vector3(a.x, 0, a.y) * 11.0 - n3 * 1.5, k)
	p.body.wet = 0.0
	var s0 := wpos(p)
	steer(p, n3)
	var swam2 := false
	for i in 30 * 60:
		await get_tree().physics_frame
		if p.swimming:
			swam2 = true
	p.autopilot = Callable()
	var s1 := wpos(p)
	var drift := (Vector2(s1.x - s0.x, s1.z - s0.z)).dot(a) * signf(o["flow"])
	var crossed := (Vector2(s1.x, s1.z) - (far + a * 11.0)).dot(n) > -2.0
	check("Swam through the river", swam2 and crossed and p.body.wet > 0.3, "wet %.1f" % p.body.wet)
	check("Current carries you downstream", drift > 1.0, "drifted %.1f m" % drift)

	# short log floats and drifts away
	var short := _river_log(ob, k, 1)
	var c3 := Vector3(mid.x, o["level"] + 0.6, mid.y) + Vector3(a.x, 0, a.y) * 10.0
	short.global_transform = Transform3D(Basis(), main.world.world_to_local(c3))
	short.linear_velocity = Vector3.ZERO
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) - n3 * 3.0, k)
	await secs(6.0)
	var sp: Vector3 = main.world.local_to_world(short.global_position)
	var sdrift := Vector2(sp.x - c3.x, sp.z - c3.z).dot(a) * signf(o["flow"])
	check("Log floats", absf(sp.y - o["level"]) < 0.9, "height %.2f, water %.2f" % [sp.y, o["level"]])
	check("Log drifts with the current", sdrift > 2.0, "%.1f m" % sdrift)


# ---------------------------------------------------------------- rope

func _anchor_area(ob: ObstacleManager, k: int, idx: int) -> Area3D:
	var root: Node3D = ob._built[k]
	for c in root.get_children():
		if c is Area3D and c.has_meta("anchor") and (c.get_meta("anchor") as Array)[1] == idx:
			return c
	return null


func _test_rope(p: Wanderer, gen: WorldGen, ob: ObstacleManager) -> void:
	var o := gen.obstacle(1)
	var k: int = o["k"]
	var f := ob.river_frame(o)
	var n: Vector2 = f["fwd"]
	var n3 := Vector3(n.x, 0, n.y)
	var near: Vector2 = f["near"]
	var far: Vector2 = f["far"]
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) - n3 * 2.0, k)
	for it in p.inventory.items.duplicate():
		if it["id"] == "seil":
			p.inventory.remove(it)
	var r1 := ItemDefs.make("seil")
	p.inventory.add(r1)
	var a0 := _anchor_area(ob, k, 0)
	var a1 := _anchor_area(ob, k, 1)
	var prompt: String = (a0.get_meta("poi_prompt") as Callable).call(p)
	(a0.get_meta("poi_action") as Callable).call(p)
	check("10 m rope is too short", ob._rope(k)["stage"] == "none", prompt)
	# add a second rope and knot them (like in the backpack)
	var r2 := ItemDefs.make("seil")
	p.inventory.add(r2)
	p.inventory.remove(r2)
	r1["length"] = 20
	r1["knot"] = 0.9
	_knot_q = 0.9
	(a0.get_meta("poi_action") as Callable).call(p)
	check("Rope tied to the first post", ob._rope(k)["stage"] == "carried" and not p.inventory.items.has(r1))
	await place(p, Vector3(far.x, gen.height(far.x, far.y) + 0.3, far.y) + n3 * 1.5, k)
	await frames(5)
	check("Rope end is carried along", ob._rope(k)["stage"] == "carried")
	(a1.get_meta("poi_action") as Callable).call(p)
	check("Rope stretched across the river", ob._rope(k)["stage"] == "spanned")

	# climb across from near to far
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) - n3 * 0.5, k)
	p.body.stamina = 100.0
	(a0.get_meta("poi_action") as Callable).call(p)
	p.look_along(n3)
	check("Hooked onto the rope", not p.rope.is_empty())
	key(KEY_W, true)
	var swam := false
	for i in 20 * 60:
		await get_tree().physics_frame
		if p.swimming:
			swam = true
		if p.rope.is_empty():
			break
	key(KEY_W, false)
	await secs(1.0)
	var d_far := (Vector2(wpos(p).x, wpos(p).z) - far).dot(n)
	check("Climbed across", not swam and d_far > -2.5, "distance %.1f m, stamina %.0f" % [d_far, p.body.stamina])

	# weak knot + heavy luggage: the knot loosens
	ob._rope(k).clear()
	ob._rope(k)["stage"] = "none"
	var r3 := ItemDefs.make("seil")
	r3["length"] = 20
	p.inventory.add(r3)
	_knot_q = 0.1
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) - n3 * 2.0, k)
	(a0.get_meta("poi_action") as Callable).call(p)
	await place(p, Vector3(far.x, gen.height(far.x, far.y) + 0.3, far.y) + n3 * 1.5, k)
	(a1.get_meta("poi_action") as Callable).call(p)
	var heavy: Array = []
	for i in 12:
		var s := ItemDefs.make("stein")
		if p.inventory.add(s):
			heavy.append(s)
	await place(p, Vector3(near.x, gen.height(near.x, near.y) + 0.3, near.y) - n3 * 0.5, k)
	p.body.stamina = 100.0
	(a0.get_meta("poi_action") as Callable).call(p)
	p.look_along(n3)
	key(KEY_W, true)
	var fell := false
	for i in 12 * 60:
		await get_tree().physics_frame
		if p.rope.is_empty() and ob._rope(k)["stage"] == "none":
			fell = true
			break
	key(KEY_W, false)
	await secs(2.0)
	check("Weak knot gives way under load", fell and ob._rope(k)["stage"] == "none")
	check("… and you land in the river", p.in_water, "in water: %s" % p.in_water)
	for s in heavy:
		p.inventory.remove(s)


# ---------------------------------------------------------------- cliff

func _test_cliff(p: Wanderer, gen: WorldGen, ob: ObstacleManager) -> void:
	var o := gen.obstacle(2)
	var k: int = o["k"]
	var pool: Vector4 = o["pool"]
	var top_h := gen.height(pool.x, o["z"] + 3.0)
	# jump into the pool: no damage
	await place(p, Vector3(o["px"], gen.height(o["px"], o["z"] + 5.0) + 0.3, o["z"] + 5.0), k)
	p.body.health = 100.0
	p.global_position = main.world.world_to_local(Vector3(pool.x, top_h + 0.5, pool.y))
	p.velocity = Vector3.ZERO
	await secs(3.0)
	check("Jump into the pool without damage", p.body.health >= 99.0 and p.in_water, "health %.0f, fall height %.1f m" % [p.body.health, top_h - pool.w])

	# fall onto solid ground: damage
	var below: float = o["z"] - 8.0
	var bx := gen.path_x(below) - float(o["side"]) * 1.0
	await place(p, Vector3(bx, gen.height(bx, below) + 0.3, below), k)
	p.body.health = 100.0
	p.global_position = main.world.world_to_local(Vector3(bx, top_h + 0.5, below))
	p.velocity = Vector3.ZERO
	var minv := 0.0
	for i in 180:
		await get_tree().physics_frame
		minv = minf(minv, p.velocity.y)
	print("    [Fall] ground %.1f, start %.1f, now %.1f, min v.y %.1f, water %s" % [gen.height(bx, below), top_h + 0.5, wpos(p).y, minv, p.in_water])
	check("Falling onto the ground hurts", p.body.health < 90.0, "health %.0f" % p.body.health)

	# rappelling (the cliff is 16–22 m high: three knotted ropes)
	var rope := ItemDefs.make("seil")
	rope["length"] = 30
	p.inventory.add(rope)
	_knot_q = 0.97
	var a0 := _anchor_area(ob, k, 0)
	var ga := a0.global_position
	await place(p, main.world.local_to_world(ga) + Vector3(0, -0.5, 1.0), k)
	(a0.get_meta("poi_action") as Callable).call(p)
	check("Rope tied at the cliff", ob._rope(k)["stage"] == "hanging")
	p.body.health = 100.0
	(a0.get_meta("poi_action") as Callable).call(p)
	check("Hooked onto the rope (rappelling)", not p.rope.is_empty())
	key(KEY_S, true)
	for i in 30 * 60:
		await get_tree().physics_frame
		if p.rope.is_empty():
			break
	key(KEY_S, false)
	await secs(2.0)
	var h_now := wpos(p).y
	var ground_below := gen.height(wpos(p).x, wpos(p).z)
	check("Arrived at the bottom unhurt", p.body.health >= 95.0 and h_now < top_h - 6.0,
		"height %.1f (top %.1f, ground %.1f), health %.0f" % [h_now, top_h, ground_below, p.body.health])


# ---------------------------------------------------------------- boundaries

func _test_bounds(p: Wanderer, gen: WorldGen, ob: ObstacleManager) -> void:
	# gorge wall at the fallen tree: can't walk up
	var o := gen.obstacle(0)
	var z0: float = o["z"] + 4.0
	var r := gen.row(z0)
	var side_dir := Vector3(1.0, 0, gen.path_slope(z0)).normalized()
	var start := gen.path_point(z0) + Vector3(0, 0.3, 0)
	await place(p, start, 0)
	var y0 := wpos(p).y
	steer(p, side_dir)
	key(KEY_SPACE, true)
	await secs(6.0)
	key(KEY_SPACE, false)
	p.autopilot = Callable()
	await secs(1.0)
	check("Gorge wall can't be climbed", wpos(p).y - y0 < 2.5, "height gain %.1f m" % (wpos(p).y - y0))

	# far to the side of the path: corridor boundary
	var zc := -2500.0
	var edge := gen.path_point(zc) + Vector3(gen.CORRIDOR - 20.0, 0, 0)
	edge.y = gen.height(edge.x, edge.z) + 0.3
	await place(p, edge)
	steer(p, Vector3(1, 0, 0))
	await secs(25.0)
	p.autopilot = Callable()
	var off: float = gen.path_offset(wpos(p).x, wpos(p).z)
	check("Corridor boundary holds", off < gen.CORRIDOR + 20.0, "%.0f m from path" % off)

	# river: swimming downstream ends at the rock barrier
	var rv := gen.obstacle(1)
	var down := signf(rv["flow"])
	var sp := gen.river_point(down * (float(rv["length"]) - 25.0), rv)
	await place(p, Vector3(sp.x, rv["level"] - 1.4, sp.y), 1)
	var tan := gen.river_point(down * (float(rv["length"]) - 20.0), rv) - sp
	steer(p, Vector3(tan.x, 0, tan.y))
	await secs(30.0)
	p.autopilot = Callable()
	var al := gen.river_along(wpos(p).x, wpos(p).z, rv) * down
	check("River ends – no endless swimming", al < float(rv["length"]) + 6.0, "%.0f m along (length %.0f)" % [al, rv["length"]])


func _test_freecam(p: Wanderer, gen: WorldGen) -> void:
	var start := gen.path_point(-300.0) + Vector3(0, 0.3, 0)
	await place(p, start)
	var y0 := wpos(p).y
	key(KEY_F6, true)
	await frames(2)
	key(KEY_F6, false)
	key(KEY_SPACE, true)
	await secs(2.0)
	key(KEY_SPACE, false)
	check("F6: fly upwards", p.fly_mode == 1 and wpos(p).y - y0 > 8.0, "+%.1f m" % (wpos(p).y - y0))
	key(KEY_F7, true)
	await frames(2)
	key(KEY_F7, false)
	key(KEY_CTRL, true)
	await secs(4.0)
	key(KEY_CTRL, false)
	var ground := gen.height(wpos(p).x, wpos(p).z)
	check("F7: noclip through the ground", p.fly_mode == 2 and wpos(p).y < ground - 3.0, "%.1f m below ground" % (ground - wpos(p).y))
	key(KEY_F7, true)
	await frames(2)
	key(KEY_F7, false)
	await secs(2.0)
	check("Back to normal: above ground again", p.fly_mode == 0 and wpos(p).y > gen.height(wpos(p).x, wpos(p).z) - 1.0)


# ---------------------------------------------------------------- stile, mud, boulders

func _find(gen: WorldGen, type: String) -> Dictionary:
	for k in range(3, 400):
		var o := gen.obstacle(k)
		if not o.is_empty() and o["type"] == type:
			return o
	return {}


## Follow the path from 14 m before the obstacle; returns the seconds until 12 m past it (-1 = not made)
func _walk_through(p: Wanderer, gen: WorldGen, o: Dictionary, limit: float, track := {}) -> float:
	var z0: float = o["z"]
	await place(p, gen.path_point(z0 + 14.0) + Vector3(0, 0.3, 0), o["k"])
	p.autopilot = func() -> Vector3:
		var w := wpos(p)
		var d := gen.path_point(w.z - 5.0) - w
		d.y = 0.0
		return d.normalized()
	p.look_along(gen.path_point(z0) - wpos(p))
	var t := 0.0
	while t < limit and wpos(p).z > z0 - 12.0:
		await frames(6)
		t += 0.1
		var lp := p.global_position
		track["climb"] = maxf(track.get("climb", 0.0), lp.y - main.world.ground_y(lp.x, lp.z))
		track["mud"] = maxf(track.get("mud", 0.0), p.mud)
	p.autopilot = Callable()
	return t if wpos(p).z <= z0 - 12.0 else -1.0


func _test_stile(p: Wanderer, gen: WorldGen) -> void:
	var o := _find(gen, "stile")
	check("A stile exists in the world", not o.is_empty())
	if o.is_empty():
		return
	var tr := {}
	var t := await _walk_through(p, gen, o, 25.0, tr)
	check("Walked over the stile", t > 0.0 and tr.get("climb", 0.0) > 0.8, "%.1f s, up to %.2f m" % [t, tr.get("climb", 0.0)])
	# beside the stile the fence stops you
	var z0: float = o["z"]
	var across := Vector2(1.0, -gen.path_slope(z0)).normalized().rotated(o["angle"])
	var beside := gen.path_point(z0 + 4.0) + Vector3(across.x, 0, across.y) * 7.0
	await place(p, Vector3(beside.x, gen.height(beside.x, beside.z) + 0.3, beside.z), o["k"])
	steer(p, gen.path_point(z0 - 6.0) - gen.path_point(z0 + 6.0))
	await secs(5.0)
	var fence_z := z0 + across.y * 7.0
	check("The fence blocks beside the stile", wpos(p).z > fence_z - 0.6, "z=%.1f, fence at %.1f" % [wpos(p).z, fence_z])
	p.autopilot = Callable()


func _test_mud(p: Wanderer, gen: WorldGen) -> void:
	var o := _find(gen, "mud")
	check("A mud hollow exists in the world", not o.is_empty())
	if o.is_empty():
		return
	# reference: the same distance on dry path just before it
	var ref := o.duplicate()
	ref["z"] = float(o["z"]) + 60.0
	ref["k"] = -1
	var t_ref := await _walk_through(p, gen, ref, 25.0)
	p.body.wet = 0.0
	var tr := {}
	var t := await _walk_through(p, gen, o, 40.0, tr)
	check("Waded through the mud, slower", t > 0.0 and t > t_ref * 1.25 and tr.get("mud", 0.0) > 0.5,
		"%.1f s vs %.1f s dry, mud %.2f" % [t, t_ref, tr.get("mud", 0.0)])
	check("Mud makes you wet", p.body.wet >= 0.2, "wet %.2f" % p.body.wet)


func _test_boulders(p: Wanderer, gen: WorldGen) -> void:
	var o := _find(gen, "boulders")
	check("A boulder field exists in the world", not o.is_empty())
	if o.is_empty():
		return
	var t := await _walk_through(p, gen, o, 30.0)
	check("Found the way through the boulders", t > 0.0, "%.1f s" % t)
