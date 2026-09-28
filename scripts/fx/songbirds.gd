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
			if d < 5.5 or sprinting:
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
		_cam_speed = lerpf(_cam_speed, camera.global_position.distance_to(_last_cam) / maxf(delta, 1e-4), 0.2)
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
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var cols: Array = KINDS[kind]
	var s := 0.11   # a bird is ~13 cm long, drawn a little plump
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	# body: round, back color on top, breast in front below
	var bm := _blob(Vector3(0.55, 0.5, 0.75) * s, func(n: Vector3) -> Color:
		var breast := smoothstep(-0.1, 0.5, -n.z * 0.6 - n.y * 0.8)
		return (cols[0] as Color).lerp(cols[1], breast))
	var bmi := MeshInstance3D.new()
	bmi.mesh = bm
	bmi.material_override = mat
	bmi.position = Vector3(0, 0.07, 0)
	body.add_child(bmi)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.12, -0.055)
	body.add_child(head)
	var hm := MeshInstance3D.new()
	hm.mesh = _blob(Vector3(0.36, 0.34, 0.36) * s, func(n: Vector3) -> Color:
		return (cols[2] as Color).lerp(cols[1], smoothstep(0.0, 0.6, -n.y * 0.7 - n.z * 0.4) * 0.6))
	hm.material_override = mat
	head.add_child(hm)
	# eyes and beak
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.0065
		em.height = 0.013
		eye.mesh = em
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color("141414")
		emat.roughness = 0.2
		eye.material_override = emat
		eye.position = Vector3(side * 0.03, 0.008, -0.022)
		head.add_child(eye)
	var beak := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.009
	cm.height = 0.028
	cm.radial_segments = 6
	beak.mesh = cm
	var beak_mat := StandardMaterial3D.new()
	beak_mat.albedo_color = Color("3a3028")
	beak.material_override = beak_mat
	beak.rotation.x = -PI * 0.5
	beak.position = Vector3(0, -0.004, -0.05)
	head.add_child(beak)
	# wings on the shoulders (they fold along the body)
	for side: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.name = "WingL" if side < 0 else "WingR"
		w.position = Vector3(side * 0.04, 0.1, -0.01)
		body.add_child(w)
		var wm := MeshInstance3D.new()
		wm.mesh = _blob(Vector3(0.36, 0.08, 0.6) * s, func(_n: Vector3) -> Color: return cols[3])
		wm.material_override = mat
		wm.position = Vector3(side * 0.025, 0.0, 0.03)
		w.add_child(wm)
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.09, 0.07)
	body.add_child(tail)
	var tm := MeshInstance3D.new()
	tm.mesh = _blob(Vector3(0.22, 0.05, 0.5) * s, func(_n: Vector3) -> Color: return (cols[3] as Color).darkened(0.15))
	tm.material_override = mat
	tm.position = Vector3(0, 0.0, 0.045)
	tm.rotation.x = 0.35
	tail.add_child(tm)
	# thin legs
	for side: float in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.003
		lm.bottom_radius = 0.003
		lm.height = 0.035
		lm.radial_segments = 4
		leg.mesh = lm
		leg.material_override = beak_mat
		leg.position = Vector3(side * 0.015, 0.017, 0.0)
		body.add_child(leg)
	for c in root.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a little larger than life: reads better next to the round scout
	root.scale = Vector3.ONE * 1.4
	return root


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
