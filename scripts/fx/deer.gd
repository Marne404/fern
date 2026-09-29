class_name Deer
extends Node3D
## Deer at the edge of the woods: a doe (sometimes with a fawn) grazes 35–70 m away near the tree line,
## raises its head and watches you when you come closer, and bounds away when you get too close or run.
## Built from soft blobs like the scout; legs, neck, head, ears and tail are animated.

const COAT := Color("a95f2c")
const BELLY := Color("e8c9a0")
const DARK := Color("3a2a20")
const WHITE := Color("f4efe4")

var camera: Camera3D
var world: ChunkManager
var allowed := false
var activity := 1.0
var _herd: Array[Dictionary] = []
## test helper: keep every deer in this state ("graze", "alert", "flee")
var hold := ""
## 0..1: how long you have been crouching quietly – deer stay calm, come closer, graze near you
var patience := 0.0
var _timer := 8.0
var _rng := RandomNumberGenerator.new()
var _mat: StandardMaterial3D


func _ready() -> void:
	_rng.randomize()
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 0.95


func _process(delta: float) -> void:
	if camera == null or world == null:
		return
	var cam := camera.global_position
	_timer -= delta
	if _timer <= 0.0:
		_timer = 12.0
		if _herd.is_empty() and allowed and activity > 0.3 and _rng.randf() < 0.45:
			_spawn(cam)
	for i in range(_herd.size() - 1, -1, -1):
		var d := _herd[i]
		_update(d, cam, delta)
		if d["gone"]:
			(d["node"] as Node3D).queue_free()
			_herd.remove_at(i)


func _spawn(cam: Vector3) -> void:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var trees := world.canopy_near(cam, 80.0)
	trees.shuffle()
	for t in trees:
		var c: Vector3 = t[0]
		var to := Vector3(c.x - cam.x, 0, c.z - cam.z)
		var dist := to.length()
		if dist < 38.0 or dist > 72.0 or to.normalized().dot(fwd) < 0.2:
			continue
		# just outside the crown, on the side towards you
		var p := c - to.normalized() * (float(t[1]) + _rng.randf_range(1.5, 4.0))
		p.y = world.ground_y(p.x, p.z)
		var n := _ground_normal(p)
		if n.y < 0.85:
			continue
		var w := world.local_to_world(p)
		if world.gen.water_level(w.x, w.z) > p.y - 0.3:
			continue
		_add_deer(p, 1.0, false)
		if _rng.randf() < 0.4:
			var a := _rng.randf() * TAU
			_add_deer(p + Vector3(cos(a), 0, sin(a)) * 2.2, 0.62, true)
		return


func _ground_normal(p: Vector3) -> Vector3:
	var e := 1.0
	var hx := world.ground_y(p.x + e, p.z) - world.ground_y(p.x - e, p.z)
	var hz := world.ground_y(p.x, p.z + e) - world.ground_y(p.x, p.z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()


func _add_deer(p: Vector3, size: float, fawn: bool) -> void:
	# now and then a young buck with small antlers instead of a doe
	var node := _build(fawn, not fawn and _rng.randf() < 0.3)
	node.scale = Vector3.ONE * size
	add_child(node)
	p.y = world.ground_y(p.x, p.z)
	node.global_position = p
	var d := {"node": node, "pos": p, "yaw": _rng.randf() * TAU, "state": "graze", "t": 0.0, "act": _rng.randf_range(1.0, 4.0),
		"head": 1.0, "ear": 0.0, "tail": 0.0, "phase": 0.0, "speed": 0.0, "gone": false, "size": size, "alert_t": 0.0}
	_herd.append(d)


func _update(d: Dictionary, cam: Vector3, delta: float) -> void:
	var node: Node3D = d["node"]
	var pos: Vector3 = d["pos"]
	var to_cam := cam - pos
	to_cam.y = 0.0
	var dist := to_cam.length()
	d["t"] = float(d["t"]) + delta
	var running := _cam_speed > 4.0
	if hold != "":
		d["state"] = hold
		dist = 50.0 if hold != "flee" else dist
		d["gone"] = false
	match d["state"]:
		"graze":
			d["head"] = move_toward(float(d["head"]), 1.0, delta * 1.5)   # 1 = head down
			d["act"] = float(d["act"]) - delta
			if d["act"] <= 0.0:
				d["act"] = _rng.randf_range(2.0, 6.0)
				if _rng.randf() < 0.5:
					# a few steps to the next tuft
					d["walk"] = _rng.randf_range(0.8, 2.0)
					d["yaw"] = float(d["yaw"]) + _rng.randf_range(-0.9, 0.9)
				else:
					d["tail"] = 1.0
			if float(d.get("walk", 0.0)) > 0.0:
				d["walk"] = float(d["walk"]) - delta
				d["speed"] = 0.6
			else:
				d["speed"] = move_toward(float(d["speed"]), 0.0, delta * 2.0)
			if dist < lerpf(30.0, 7.0, patience) or (running and dist < 40.0):
				d["state"] = "alert"
				d["alert_t"] = 0.0
			elif patience > 0.85 and dist > 11.0 and float(d.get("walk", 0.0)) <= 0.0 and _rng.randf() < delta * 0.25:
				# curious: a few steps towards the quiet figure in the grass
				d["walk"] = _rng.randf_range(1.5, 3.5)
				d["yaw"] = atan2(-to_cam.x, -to_cam.z) + _rng.randf_range(-0.4, 0.4)
		"alert":
			# head up, ears to you, still
			d["head"] = move_toward(float(d["head"]), 0.0, delta * 3.0)
			d["speed"] = move_toward(float(d["speed"]), 0.0, delta * 3.0)
			d["yaw"] = lerp_angle(float(d["yaw"]), atan2(-to_cam.x, -to_cam.z), 1.0 - exp(-1.5 * delta))
			d["alert_t"] = float(d["alert_t"]) + delta
			var calm := patience > 0.7
			if dist < lerpf(18.0, 4.5, patience) or (running and dist < 26.0) or (not calm and d["alert_t"] > 5.0 and dist < 24.0):
				d["state"] = "flee"
				d["t"] = 0.0
				Sfx.play_at(self, "flutter", pos, -18.0, 0.5)
			elif (dist > 38.0 and d["alert_t"] > 4.0) or (calm and d["alert_t"] > 3.0):
				# you're sitting still: it decides you're harmless and goes back to grazing
				d["state"] = "graze"
		"flee":
			d["head"] = move_toward(float(d["head"]), -0.2, delta * 4.0)
			d["speed"] = move_toward(float(d["speed"]), 9.0, delta * 12.0)
			d["yaw"] = lerp_angle(float(d["yaw"]), atan2(to_cam.x, to_cam.z), 1.0 - exp(-4.0 * delta))
			d["tail"] = 1.0
			if dist > 95.0:
				d["gone"] = true
	if dist > 130.0:
		d["gone"] = true
	# move
	var yaw: float = d["yaw"]
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var spd: float = d["speed"]
	pos += fwd * spd * delta
	pos.y = world.ground_y(pos.x, pos.z)
	d["pos"] = pos
	d["phase"] = float(d["phase"]) + delta * (spd * 1.25 + 0.01) * (1.0 if d["state"] != "flee" else 0.62)
	_pose(d, delta)
	node.global_position = pos
	node.rotation.y = yaw


var _cam_speed := 0.0
var _last_cam := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if camera:
		var v := camera.global_position.distance_to(_last_cam) / maxf(delta, 1e-4)
		# teleports (start, respawn, origin shifts) are not running
		if v < 25.0:
			_cam_speed = lerpf(_cam_speed, v, 0.2)
		_last_cam = camera.global_position


func shift(offset: Vector3) -> void:
	for d in _herd:
		d["pos"] = (d["pos"] as Vector3) - offset


# ---------------------------------------------------------------- pose

func _pose(d: Dictionary, delta: float) -> void:
	var node: Node3D = d["node"]
	var body: Node3D = node.get_node("Body")
	var neck: Node3D = body.get_node("Neck")
	var head: Node3D = neck.get_node("Head")
	var ph: float = d["phase"] * TAU
	var flee: bool = d["state"] == "flee"
	var spd: float = d["speed"]
	# bounding: the whole body arcs up and pitches, front and hind legs swing together
	var leap := maxf(sin(ph), 0.0) if flee else 0.0
	var walk_bob := absf(sin(ph)) * 0.025 * clampf(spd, 0.0, 1.0) if not flee else 0.0
	body.position.y = 0.8 + leap * 0.55 + walk_bob
	# breathing: the barrel swells gently (faster after running)
	var breath := sin(float(d["t"]) * (2.2 if d["state"] != "flee" else 6.0)) * 0.012
	body.scale = Vector3(1.0 + breath, 1.0 + breath, 1.0)
	body.rotation.x = (cos(ph) * 0.18) if flee else 0.0
	var k := clampf(spd / 1.0, 0.0, 1.0)
	for leg: Node3D in body.get_node("Legs").get_children():
		var front: bool = leg.get_meta("front")
		var side: float = leg.get_meta("side")
		var a: float
		if flee:
			a = (sin(ph + (0.0 if front else PI)) * 0.8)
		else:
			a = sin(ph + (0.0 if front else PI) + (0.0 if side > 0 else PI)) * 0.35 * k
		leg.rotation.x = a
		(leg.get_child(1) as Node3D).rotation.x = -maxf(-a, 0.0) * 1.2 if not flee else -absf(a) * 0.8
	# neck and head: down to graze, up and alert
	var hd: float = d["head"]
	neck.rotation.x = -lerpf(0.55, 2.4, hd) + sin(ph * 2.0) * 0.05 * clampf(spd, 0.0, 1.0) * float(not flee)
	head.rotation.x = lerpf(0.4, 1.1, hd)
	if not flee:
		body.rotation.x = -0.07 * hd
	# chewing nod while grazing, a turn of the head when alert
	head.rotation.y = sin(float(d["t"]) * 0.7) * 0.25 * (1.0 - hd) if d["state"] == "alert" else 0.0
	# ears: flick now and then, forward when alert
	var ear := sin(float(d["t"]) * 11.0) * 0.3 * float(maxf(sin(float(d["t"]) * 0.6), 0.0) > 0.95)
	for e: Node3D in [head.get_node("EarL"), head.get_node("EarR")]:
		e.rotation.x = (-0.3 if d["state"] == "alert" else 0.1) + ear
	# tail: flicks up, white rump flashes when fleeing
	d["tail"] = move_toward(float(d["tail"]), 1.0 if flee else 0.0, delta * 3.0)
	body.get_node("Tail").rotation.x = -float(d["tail"]) * 1.1


# ---------------------------------------------------------------- model

func _build(fawn: bool, buck := false) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = 0.8
	root.add_child(body)
	var coat := COAT.lerp(Color("c07a3c"), 0.35) if fawn else COAT
	var back := coat.darkened(0.22)
	var spot_rng := RandomNumberGenerator.new()
	spot_rng.seed = 7
	var spots: Array[Vector3] = []
	if fawn:
		# two rows of white spots along each flank
		for side: float in [-1.0, 1.0]:
			for row in 2:
				for i in 7:
					spots.append(Vector3(side * (0.14 - row * 0.03), 0.12 - row * 0.07 + spot_rng.randf_range(-0.01, 0.01), -0.34 + i * 0.11 + row * 0.05))
	var coat_col := func(n: Vector3, p: Vector3) -> Color:
		var c := coat.lerp(back, smoothstep(0.55, 0.95, n.y))
		c = c.lerp(BELLY, smoothstep(0.05, 0.7, -n.y))
		# the white rump patch around the tail
		c = c.lerp(WHITE, smoothstep(0.34, 0.5, p.z) * smoothstep(-0.25, 0.2, n.y) * (1.0 - smoothstep(0.45, 0.8, absf(n.x))))
		for sp in spots:
			if p.distance_to(sp) < 0.028:
				c = c.lerp(WHITE, 0.85)
		return c
	# torso: barrel, deep chest in front, round haunch behind
	var b := CreatureMesh.new()
	b.add(Mesh3.blob(Vector3(0.19, 0.22, 0.46), 2.3, 16, 24), coat_col)
	b.add(Mesh3.blob(Vector3(0.18, 0.24, 0.2), 2.2, 12, 18), func(n: Vector3, p: Vector3) -> Color: return coat_col.call(n, p + Vector3(0, 0.02, -0.33)),
		Transform3D(Basis(), Vector3(0, 0.02, -0.33)))
	b.add(Mesh3.blob(Vector3(0.195, 0.23, 0.22), 2.2, 12, 18), func(n: Vector3, p: Vector3) -> Color: return coat_col.call(n, p + Vector3(0, 0.03, 0.3)),
		Transform3D(Basis(), Vector3(0, 0.03, 0.3)))
	b.instance(body, "Mesh")
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.14, 0.5)
	body.add_child(tail)
	var tb := CreatureMesh.new()
	tb.add(Mesh3.blob(Vector3(0.045, 0.09, 0.035), 2.2, 8, 12), func(n: Vector3, _p: Vector3) -> Color: return coat if n.z < 0.2 and n.y > -0.4 else WHITE,
		Transform3D(Basis(), Vector3(0, -0.06, 0.02)))
	tb.instance(tail, "Mesh", false)
	# neck: a curved tube, pale throat
	var neck := Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.1, -0.4)
	body.add_child(neck)
	var nb := CreatureMesh.new()
	nb.add(Mesh3.tube([Vector3(0, -0.04, 0.03), Vector3(0, 0.14, -0.03), Vector3(0, 0.3, -0.06), Vector3(0, 0.42, -0.04)], [0.12, 0.1, 0.085, 0.075], 14),
		func(n: Vector3, p: Vector3) -> Color: return coat.lerp(BELLY, smoothstep(0.2, 0.8, -n.z) * smoothstep(0.35, 0.05, p.y) * 0.8).lerp(back, smoothstep(0.6, 0.95, n.z) * 0.4))
	nb.instance(neck, "Mesh")
	# head: skull, tapering muzzle, glossy black nose, eyes with a light, pale eye rings and chin
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.44, -0.02)
	neck.add_child(head)
	var hb := CreatureMesh.new()
	hb.add(Mesh3.blob(Vector3(0.085, 0.09, 0.11), 2.2, 12, 18), func(n: Vector3, _p: Vector3) -> Color: return coat.lerp(back, smoothstep(0.6, 1.0, n.y) * 0.5))
	hb.add(Mesh3.tube([Vector3(0, -0.015, -0.06), Vector3(0, -0.04, -0.15), Vector3(0, -0.055, -0.21)], [0.07, 0.052, 0.04], 14),
		func(n: Vector3, _p: Vector3) -> Color: return coat.lerp(BELLY, smoothstep(0.1, 0.8, -n.y)))
	hb.add(Mesh3.blob(Vector3(0.033, 0.024, 0.02), 2.2, 8, 12), DARK, Transform3D(Basis(), Vector3(0, -0.05, -0.235)), CreatureMesh.GLOSS)
	hb.add(Mesh3.blob(Vector3(0.036, 0.018, 0.03), 2.0, 6, 10), BELLY.lerp(WHITE, 0.4), Transform3D(Basis(), Vector3(0, -0.082, -0.18)))
	for side: float in [-1.0, 1.0]:
		var exf := Transform3D(Basis(Vector3.UP, side * -1.05), Vector3(side * 0.07, 0.02, -0.055))
		hb.add(Mesh3.blob(Vector3(0.028, 0.026, 0.012), 2.0, 6, 10), BELLY.lerp(WHITE, 0.5), exf * Transform3D(Basis(), Vector3(0, 0, 0.004)))
		hb.eye(0.019, exf * Transform3D(Basis(), Vector3(0, 0, -0.006)))
	if buck:
		# small antlers: a main beam with two tines on each side
		for side: float in [-1.0, 1.0]:
			var a0 := Vector3(side * 0.045, 0.075, 0.0)
			var a1 := a0 + Vector3(side * 0.06, 0.12, 0.02)
			var a2 := a1 + Vector3(side * 0.02, 0.1, -0.04)
			hb.add(Mesh3.tube([a0, a1, a2], [0.016, 0.012, 0.007], 8), Color("d9c6a0"), Transform3D.IDENTITY, CreatureMesh.PLAIN)
			hb.add(Mesh3.tube([a1, a1 + Vector3(0, 0.06, -0.06)], [0.01, 0.005], 6), Color("e3d3b0"), Transform3D.IDENTITY, CreatureMesh.PLAIN)
			hb.add(Mesh3.blob(Vector3.ONE * 0.022, 2.0, 6, 8), Color("8a6a4a"), Transform3D(Basis(), a0))
	hb.instance(head, "Mesh")
	for side: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "EarL" if side < 0 else "EarR"
		ear.position = Vector3(side * 0.065, 0.075, 0.03)
		ear.rotation.z = -side * 0.7
		head.add_child(ear)
		var eb := CreatureMesh.new()
		# a leaf-shaped ear: coat outside, pale pink-cream inside, dark rim at the tip
		eb.add(Mesh3.blob(Vector3(0.045, 0.1, 0.016), 2.2, 10, 14), func(n: Vector3, p: Vector3) -> Color:
			var c := coat if n.z > -0.2 else BELLY.lerp(Color("e8b4a0"), 0.35)
			return c.lerp(DARK, smoothstep(0.075, 0.1, p.y) * 0.8), Transform3D(Basis(), Vector3(0, 0.085, 0)))
		eb.instance(ear, "Mesh", false)
	# legs: hip or shoulder, slender cannon, dark glossy hooves; hind legs with a hock
	var legs := Node3D.new()
	legs.name = "Legs"
	body.add_child(legs)
	for fz: float in [-0.34, 0.34]:
		for side: float in [-1.0, 1.0]:
			var front := fz < 0.0
			var upper := Node3D.new()
			upper.position = Vector3(side * 0.11, -0.06, fz)
			upper.set_meta("front", front)
			upper.set_meta("side", side)
			legs.add_child(upper)
			var ub := CreatureMesh.new()
			if front:
				ub.add(Mesh3.tube([Vector3(0, 0.04, 0.0), Vector3(0, -0.16, 0.01), Vector3(0, -0.36, 0.0)], [0.075, 0.05, 0.035], 12), coat)
			else:
				ub.add(Mesh3.tube([Vector3(0, 0.06, -0.02), Vector3(0, -0.14, 0.05), Vector3(0, -0.36, 0.06)], [0.095, 0.06, 0.035], 12), coat)
			ub.instance(upper, "Mesh")
			var lower := Node3D.new()
			lower.position = Vector3(0, -0.38, 0.0 if front else 0.06)
			upper.add_child(lower)
			var lb := CreatureMesh.new()
			lb.add(Mesh3.tube([Vector3(0, 0.02, 0), Vector3(0, -0.14, 0.005), Vector3(0, -0.28, 0)], [0.028, 0.022, 0.022], 10), coat.darkened(0.08))
			lb.add(Mesh3.lathe([Vector2(0.0, -0.36), Vector2(0.03, -0.355), Vector2(0.028, -0.31), Vector2(0.022, -0.29), Vector2(0.0, -0.29)], 12), DARK,
				Transform3D(Basis(), Vector3(0, 0.02, -0.005)), CreatureMesh.GLOSS)
			lb.instance(lower, "Mesh")
			upper.move_child(lower, 1)
	return root


## An ellipsoid mesh with vertex colors, added as a child
func _blob(parent: Node3D, r: Vector3, at: Vector3, color: Callable) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 9
	var segs := 12
	var grid := []
	for i in rings + 1:
		var v := PI * i / rings
		var row := []
		for j in segs + 1:
			var u := TAU * j / segs
			row.append(Vector3(sin(v) * cos(u), cos(v), sin(v) * sin(u)))
		grid.append(row)
	for i in rings:
		for j in segs:
			for n: Vector3 in [grid[i][j], grid[i + 1][j + 1], grid[i + 1][j], grid[i][j], grid[i][j + 1], grid[i + 1][j + 1]]:
				st.set_color(color.call(n, n * r + at))
				st.set_normal((n / r).normalized())
				st.add_vertex(n * r)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	mi.position = at
	parent.add_child(mi)
