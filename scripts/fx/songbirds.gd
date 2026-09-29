class_name Songbirds
extends Node3D
## Little songbirds that sit on fence posts, signposts, benches, standing stones and rock tops, or hop about
## on the ground beside the trail. They peck, look around, flick their tails and chirp; when you come close
## they flutter off in bouncing flight to another perch (or away). Only by day, not in the rain.

const MAX_BIRDS := 6
const KINDS := [
	# back, breast, head, wing
	[Color("7a5a3c"), Color("e8793a"), Color("7a5a3c"), Color("5e4630")],   # robin
	[Color("7e9a4a"), Color("f2d24a"), Color("3f78c8"), Color("4d77b0")],   # blue tit
	[Color("8a6a48"), Color("d8c8ae"), Color("6c5a4a"), Color("6a4e34")],   # sparrow
	[Color("9a5a4a"), Color("e89a8a"), Color("4a4a52"), Color("5a4a44")],   # bullfinch
]

var camera: Camera3D
var world: ChunkManager
## 0..1 (day, no rain)
var activity := 1.0
## biome allows birds
var allowed := true
## 0..1: how long you have been crouching quietly – birds come close and hop about near you
var patience := 0.0
var _birds: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _perches: Array = []
var _meshes := {}


func _ready() -> void:
	_rng.randomize()


## Perch markers (fence posts, signposts, benches, stones) register themselves in the "perch" group
static func mark(parent: Node3D, local_pos: Vector3) -> void:
	var m := Marker3D.new()
	m.position = local_pos
	m.add_to_group("perch")
	parent.add_child(m)


func _process(delta: float) -> void:
	if camera == null or world == null:
		return
	var cam := camera.global_position
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.5
		_gather(cam)
		var want := MAX_BIRDS if (allowed and activity > 0.5) else 0
		var live := 0
		for b in _birds:
			if b["state"] != "leave":
				live += 1
		if live < want and _rng.randf() < 0.6:
			_spawn(cam)
		if want == 0:
			for b in _birds:
				if b["state"] != "leave":
					_leave(b, cam)
	for i in range(_birds.size() - 1, -1, -1):
		var b := _birds[i]
		_update_bird(b, cam, delta)
		if b["dead"]:
			(b["node"] as Node3D).queue_free()
			_birds.remove_at(i)


# ---------------------------------------------------------------- perches

func _gather(cam: Vector3) -> void:
	_perches.clear()
	for m in get_tree().get_nodes_in_group("perch"):
		var p: Vector3 = (m as Node3D).global_position
		if p.distance_to(cam) < 45.0:
			_perches.append(p)
	# rock tops: a ray down onto the rock's collision
	var space := get_world_3d().direct_space_state
	for d in world.rock_disks_near(cam, 40.0):
		if d.z < 0.8 or d.z > 4.0:
			continue
		var top := Vector3(d.x, world.ground_y(d.x, d.y) + 12.0, d.y)
		var q := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 16, 0), 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.6:
			_perches.append(hit["position"] as Vector3)


## A perch not too close to you, preferably ahead; else a spot on the ground beside the trail
func _choose_perch(cam: Vector3, from: Vector3, min_cam := 9.0) -> Vector3:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var options := []
	for p: Vector3 in _perches:
		var dc := p.distance_to(cam)
		if dc < min_cam or dc > 42.0 or p.distance_to(from) < 3.0:
			continue
		if _occupied(p):
			continue
		options.append(p)
	if not options.is_empty() and _rng.randf() < 0.75:
		return options[_rng.randi() % options.size()]
	for i in 8:
		var p := cam + fwd * _rng.randf_range(10.0, 30.0) + fwd.cross(Vector3.UP) * _rng.randf_range(-12.0, 12.0)
		p.y = world.ground_y(p.x, p.z)
		if p.distance_to(cam) > min_cam:
			return p
	return Vector3.INF


func _occupied(p: Vector3) -> bool:
	for b in _birds:
		if (b["perch"] as Vector3).distance_to(p) < 0.4:
			return true
	return false


# ---------------------------------------------------------------- birds

func _spawn(cam: Vector3) -> void:
	var perch := _choose_perch(cam, cam, 12.0)
	if perch == Vector3.INF:
		return
	var kind := _rng.randi() % KINDS.size()
	var node := _make_bird(kind)
	add_child(node)
	# arrives flying in from the side
	var a := _rng.randf() * TAU
	var start := perch + Vector3(cos(a) * 25.0, 9.0, sin(a) * 25.0)
	node.global_position = start
	var b := {"node": node, "state": "fly", "perch": perch, "pos": start, "from": start, "t": 0.0, "dur": 0.0,
		"act": 0.0, "act_kind": "", "yaw": 0.0, "dead": false, "hop": 0.0, "chirp": _rng.randf_range(2.0, 8.0)}
	_fly_to(b, perch)
	_birds.append(b)


func _fly_to(b: Dictionary, target: Vector3) -> void:
	b["state"] = "fly"
	b["from"] = b["pos"]
	b["perch"] = target
	b["t"] = 0.0
	b["dur"] = maxf((b["pos"] as Vector3).distance_to(target) / 7.5, 0.6)


func _leave(b: Dictionary, cam: Vector3) -> void:
	var away: Vector3 = (b["pos"] as Vector3) - cam
	away.y = 0.0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	_fly_to(b, (b["pos"] as Vector3) + away * 40.0 + Vector3(0, 14.0, 0))
	b["state"] = "leave"


func _update_bird(b: Dictionary, cam: Vector3, delta: float) -> void:
	var node: Node3D = b["node"]
	var body: Node3D = node.get_child(0)
	var head: Node3D = body.get_node("Head")
	var wl: Node3D = body.get_node("WingL")
	var wr: Node3D = body.get_node("WingR")
	var tail: Node3D = body.get_node("Tail")
	var pos: Vector3 = b["pos"]
	var flap := 0.0
	b["t"] = float(b["t"]) + delta
	match b["state"]:
		"fly", "leave":
			var k := clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
			var from: Vector3 = b["from"]
			var to: Vector3 = b["perch"]
			var p := from.lerp(to, smoothstep(0.0, 1.0, k))
			# arc over the ground plus the finch-like bouncing flight (flap up, glide down)
			var arc := sin(k * PI) * minf(from.distance_to(to) * 0.25, 5.0)
			var bounce := sin(float(b["t"]) * 9.0) * 0.18 * sin(k * PI)
			p.y += arc + bounce
			var dir := to - from
			b["yaw"] = atan2(-dir.x, -dir.z)
			flap = 1.0 if (cos(float(b["t"]) * 9.0) > -0.2 or k > 0.85 or k < 0.1) else 0.0
			pos = p
			if k >= 1.0:
				if b["state"] == "leave":
					b["dead"] = true
				else:
					b["state"] = "sit"
					b["t"] = 0.0
					b["act"] = _rng.randf_range(0.5, 2.0)
		"sit":
			# too close: off to another perch
			var d := pos.distance_to(cam)
			var sprinting := d < 9.0 and _cam_speed > 4.0
			if patience > 0.8 and d > 4.0 and _rng.randf() < delta * 0.12:
				# curious: it drops down onto the grass right next to you
				var a := _rng.randf() * TAU
				var near := cam + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(1.6, 3.0)
				near.y = world.ground_y(near.x, near.z)
				_fly_to(b, near)
			elif d < lerpf(5.5, 1.1, patience) or sprinting:
				var np := _choose_perch(cam, pos)
				if np == Vector3.INF or _rng.randf() < 0.25:
					_leave(b, cam)
				else:
					_fly_to(b, np)
				Sfx.play_at(self, "flutter", pos, -14.0)
			else:
				_idle(b, pos, delta)
				pos = b["pos"]
	b["pos"] = pos
	node.global_position = pos + Vector3(0, float(b["hop"]), 0)
	node.rotation.y = lerp_angle(node.rotation.y, float(b["yaw"]), 1.0 - exp(-10.0 * delta))
	# wings: fast beats while flying, folded when sitting (with the odd shuffle)
	var beat := sin(float(b["t"]) * 42.0) * 0.9 * flap
	var fold := 0.0 if b["state"] == "sit" else 0.35
	wl.rotation.z = -(fold + beat)
	wr.rotation.z = fold + beat
	var pitch := -0.25 if b["state"] != "sit" else 0.0
	body.rotation.x = lerpf(body.rotation.x, pitch + (0.45 if b["act_kind"] == "peck" else 0.0), 1.0 - exp(-14.0 * delta))
	head.rotation.y = lerpf(head.rotation.y, float(b.get("look", 0.0)), 1.0 - exp(-12.0 * delta))
	tail.rotation.x = lerpf(tail.rotation.x, float(b.get("flick", 0.0)), 1.0 - exp(-20.0 * delta))
	b["flick"] = move_toward(float(b.get("flick", 0.0)), 0.0, delta * 3.0)


var _cam_speed := 0.0
var _last_cam := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if camera:
		var v := camera.global_position.distance_to(_last_cam) / maxf(delta, 1e-4)
		# teleports (start, respawn, origin shifts) are not running
		if v < 25.0:
			_cam_speed = lerpf(_cam_speed, v, 0.2)
		_last_cam = camera.global_position


## Sitting: hop, peck, look around, flick the tail, chirp
func _idle(b: Dictionary, pos: Vector3, delta: float) -> void:
	b["act"] = float(b["act"]) - delta
	b["hop"] = maxf(float(b["hop"]) - delta * 0.6, 0.0) if b["act_kind"] != "hop" else b["hop"]
	if b["act_kind"] == "hop":
		var ht := float(b["hop_t"]) + delta
		b["hop_t"] = ht
		b["hop"] = sin(clampf(ht / 0.22, 0.0, 1.0) * PI) * 0.07
		var hp: Vector3 = b["hop_from"]
		b["pos"] = hp.lerp(b["hop_to"], clampf(ht / 0.22, 0.0, 1.0))
		if ht >= 0.22:
			b["act_kind"] = ""
			b["hop"] = 0.0
	b["chirp"] = float(b["chirp"]) - delta
	if b["chirp"] <= 0.0:
		b["chirp"] = _rng.randf_range(3.0, 11.0)
		Sfx.play_at(self, "chirp_%d" % (_rng.randi() % 4), pos, -12.0, _rng.randf_range(0.9, 1.15))
		b["look"] = _rng.randf_range(-0.8, 0.8)
	if b["act"] > 0.0:
		return
	b["act"] = _rng.randf_range(0.4, 1.8)
	var on_ground: bool = absf(pos.y - world.ground_y(pos.x, pos.z)) < 0.15
	var r := _rng.randf()
	if on_ground and r < 0.35:
		# a little hop along the ground
		var a := _rng.randf() * TAU
		var to := pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.15, 0.4)
		to.y = world.ground_y(to.x, to.z)
		b["hop_from"] = pos
		b["hop_to"] = to
		b["hop_t"] = 0.0
		b["act_kind"] = "hop"
		b["yaw"] = atan2(-(to.x - pos.x), -(to.z - pos.z))
		b["perch"] = to
	elif on_ground and r < 0.65:
		b["act_kind"] = "peck"
	elif r < 0.85:
		b["act_kind"] = ""
		b["look"] = _rng.randf_range(-1.0, 1.0)
		if not on_ground and _rng.randf() < 0.5:
			b["yaw"] = float(b["yaw"]) + _rng.randf_range(-1.2, 1.2)
	else:
		b["act_kind"] = ""
		b["flick"] = 0.7


# ---------------------------------------------------------------- model

func _make_bird(kind: int) -> Node3D:
	if not _meshes.has(kind):
		_meshes[kind] = _bird_meshes(kind)
	var m: Dictionary = _meshes[kind]
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var bmi := MeshInstance3D.new()
	bmi.mesh = m["body"]
	body.add_child(bmi)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.125, -0.06)
	body.add_child(head)
	var hmi := MeshInstance3D.new()
	hmi.mesh = m["head"]
	head.add_child(hmi)
	for side: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingL" if side < 0 else "WingR"
		w.position = Vector3(side * 0.045, 0.1, -0.015)
		body.add_child(w)
		var wmi := MeshInstance3D.new()
		wmi.mesh = m["wing_l" if side < 0 else "wing_r"]
		w.add_child(wmi)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.09, 0.065)
	body.add_child(tail)
	var tmi := MeshInstance3D.new()
	tmi.mesh = m["tail"]
	tail.add_child(tmi)
	for c in root.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a little larger than life: reads better next to the round scout
	root.scale = Vector3.ONE * 1.4
	return root


## The bird's parts in the toon style: plump body with the breast color flowing into the back,
## a round head with cap and cheeks, a glossy pointed beak, layered wings with pale feather edges, a fan tail
func _bird_meshes(kind: int) -> Dictionary:
	var cols: Array = KINDS[kind]
	var back_c: Color = cols[0]
	var breast_c: Color = cols[1]
	var head_c: Color = cols[2]
	var wing_c: Color = cols[3]
	var beak_c := Color("3a3028") if kind != 3 else Color("2a2a30")
	var out := {}
	var b := CreatureMesh.new()
	b.add(Mesh3.blob(Vector3(0.06, 0.058, 0.085), 2.2, 12, 16), func(n: Vector3, _p: Vector3) -> Color:
		var breast := smoothstep(-0.15, 0.55, -n.z * 0.6 - n.y * 0.8)
		return back_c.lerp(breast_c, breast).lerp(breast_c.lightened(0.35), smoothstep(0.6, 0.95, -n.y) * 0.6),
		Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.075, 0)))
	# little legs with toes gripping the perch
	for side: float in [-1.0, 1.0]:
		b.add(Mesh3.tube([Vector3(side * 0.016, 0.04, 0.0), Vector3(side * 0.017, 0.002, 0.004)], [0.0045, 0.0035], 5), beak_c, Transform3D.IDENTITY, CreatureMesh.PLAIN)
		for toe: float in [-0.5, 0.0, 0.5]:
			b.add(Mesh3.tube([Vector3(side * 0.017, 0.002, 0.004), Vector3(side * 0.017 + sin(toe) * 0.012, 0.0, 0.004 - cos(toe) * 0.014)], 0.0025, 4), beak_c, Transform3D.IDENTITY, CreatureMesh.PLAIN)
	out["body"] = b.commit()
	var h := CreatureMesh.new()
	h.add(Mesh3.blob(Vector3(0.042, 0.04, 0.043), 2.1, 10, 14), func(n: Vector3, _p: Vector3) -> Color:
		var c := head_c.lerp(breast_c, smoothstep(0.0, 0.6, -n.y * 0.7 - n.z * 0.4) * 0.7)
		# pale cheeks for the tit
		if kind == 1 and absf(n.x) > 0.55 and n.y < 0.35 and n.y > -0.4:
			c = c.lerp(Color("f4f1e8"), 0.9)
		return c)
	h.add(Mesh3.lathe([Vector2(0.0, 0.0), Vector2(0.011, 0.0), Vector2(0.008, 0.012), Vector2(0.0, 0.03)], 8, 0.8, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.004, -0.036))), beak_c, Transform3D.IDENTITY, CreatureMesh.GLOSS)
	for side: float in [-1.0, 1.0]:
		h.eye(0.008, Transform3D(Basis(Vector3.UP, side * -1.2), Vector3(side * 0.031, 0.008, -0.022)))
	out["head"] = h.commit()
	for side: float in [-1.0, 1.0]:
		var w := CreatureMesh.new()
		# three layers: coverts, secondaries, long primaries – each with a paler edge
		for layer in 3:
			var len := 0.05 + layer * 0.022
			var wid := 0.034 - layer * 0.005
			w.add(Mesh3.blob(Vector3(wid, 0.008, len), 2.3, 6, 12), func(n: Vector3, p: Vector3) -> Color:
				var c := wing_c.darkened(layer * 0.12)
				return c.lerp(c.lightened(0.45), smoothstep(len * 0.75, len, p.z) * 0.8),
				Transform3D(Basis(Vector3.UP, side * 0.12), Vector3(side * 0.02, -0.004 * layer, 0.025 + layer * 0.02)))
		out["wing_l" if side < 0 else "wing_r"] = w.commit()
	var t := CreatureMesh.new()
	for f in 5:
		var a := (f - 2) * 0.13
		t.add(Mesh3.blob(Vector3(0.011, 0.004, 0.05), 2.2, 5, 10), wing_c.darkened(0.2).lerp(wing_c, float(f % 2) * 0.3),
			Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.35), Vector3(sin(a) * 0.01, 0.0, 0.045)))
	out["tail"] = t.commit()
	return out


## Ellipsoid with vertex colors from its normal
func _blob(r: Vector3, color: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var segs := 10
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
				st.set_color(color.call(n))
				st.set_normal(n)
				st.add_vertex(n * r)
	return st.commit()


func shift(offset: Vector3) -> void:
	for b in _birds:
		for k in ["pos", "perch", "from"]:
			b[k] = (b[k] as Vector3) - offset
		if b.has("hop_from"):
			b["hop_from"] = (b["hop_from"] as Vector3) - offset
			b["hop_to"] = (b["hop_to"] as Vector3) - offset
