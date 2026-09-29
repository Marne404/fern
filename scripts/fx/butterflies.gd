class_name Butterflies
extends Node3D
## Butterflies around the camera: they flutter from flower to flower, land, fold their wings and rest,
## and take off again (or when you come close). They hide at night and in the rain.
## Bees buzz around lavender rows and flower clusters.

const COLORS := [Color(1.0, 0.55, 0.1), Color(1.0, 0.85, 0.2), Color(0.35, 0.6, 1.0), Color(1.0, 0.98, 0.94), Color(0.95, 0.35, 0.2)]
const BEES := 22

var camera: Camera3D
var world: ChunkManager
## 0..1: 0 at night or in the rain (they hide), 1 on a sunny day
var activity := 1.0
var _items: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _flower_timer := 0.0
var _flowers: Array = []
var _bees: MultiMeshInstance3D
var _bee_state: Array[Dictionary] = []
var _buzz: AudioStreamPlayer3D
## 0..1: how long you have been crouching quietly – butterflies stay, and one may land on you
var patience := 0.0
## where one could land on you (local), INF if nowhere
var rest_spot := Vector3.INF
var _body_mesh: ArrayMesh


func _ready() -> void:
	_rng.randomize()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _bee_mesh()
	mm.instance_count = BEES
	mm.visible_instance_count = 0
	_bees = MultiMeshInstance3D.new()
	_bees.multimesh = mm
	_bees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bees.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	add_child(_bees)
	for i in BEES:
		_bee_state.append({"flower": Vector3.INF, "next": 0.0, "seed": _rng.randf() * 100.0, "pos": Vector3.ZERO})
	_buzz = AudioStreamPlayer3D.new()
	_buzz.stream = Sfx.buzz_loop()
	_buzz.unit_size = 1.2
	_buzz.max_distance = 9.0
	_buzz.volume_db = -14.0
	add_child(_buzz)


func spawn(count: int) -> void:
	for it in _items:
		it["node"].queue_free()
	_items.clear()
	if count == 0:
		return
	var mesh := _wing_mesh()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/butterfly.gdshader")
	mesh.surface_set_material(0, mat)
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("wing_color", COLORS[_rng.randi() % COLORS.size()])
		mi.set_instance_shader_parameter("phase", _rng.randf() * TAU)
		mi.set_instance_shader_parameter("flap_speed", _rng.randf_range(13.0, 19.0))
		mi.scale = Vector3.ONE * _rng.randf_range(0.09, 0.14)
		mi.visible = false
		add_child(mi)
		# a furry body with head and antennae between the wings
		var body := MeshInstance3D.new()
		body.mesh = _butterfly_body()
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(body)
		_items.append({"node": mi, "pos": Vector3.INF, "target": Vector3.INF, "rest": 0.0, "rest_t": 0.0,
			"seed": _rng.randf() * 100.0, "speed": _rng.randf_range(0.9, 1.5), "yaw": _rng.randf() * TAU, "wander": false})


func _wing_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var quad := [Vector3(0, 0, -0.5), Vector3(side, 0, -0.5), Vector3(side, 0, 0.5), Vector3(0, 0, 0.5)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv[k])
			st.set_normal(Vector3.UP)
			st.add_vertex(quad[k])
	return st.commit()


func _butterfly_body() -> ArrayMesh:
	if _body_mesh == null:
		var b := CreatureMesh.new()
		var dark := Color("2a2220")
		b.add(Mesh3.tube([Vector3(0, 0.03, -0.32), Vector3(0, 0.03, -0.1), Vector3(0, 0.02, 0.2), Vector3(0, 0.0, 0.55)], [0.07, 0.085, 0.06, 0.03], 8),
			func(_n: Vector3, p: Vector3) -> Color: return dark.lerp(Color("5a4638"), smoothstep(0.0, 0.5, sin(p.z * 40.0)) * 0.4))
		b.add(Mesh3.blob(Vector3.ONE * 0.07, 2.0, 6, 8), dark, Transform3D(Basis(), Vector3(0, 0.04, -0.38)))
		for side: float in [-1.0, 1.0]:
			b.add(Mesh3.tube([Vector3(side * 0.02, 0.06, -0.42), Vector3(side * 0.12, 0.18, -0.62), Vector3(side * 0.16, 0.22, -0.72)], [0.012, 0.01, 0.01], 4), dark, Transform3D.IDENTITY, CreatureMesh.PLAIN)
			b.add(Mesh3.blob(Vector3.ONE * 0.025, 2.0, 4, 6), dark, Transform3D(Basis(), Vector3(side * 0.16, 0.22, -0.72)))
		_body_mesh = b.commit()
	return _body_mesh


## A tiny bee in the toon style: fuzzy golden thorax, striped abdomen with a dark tip, a dark head with big
## eyes and antennae, little legs; two glassy wings as a second surface
func _bee_mesh() -> ArrayMesh:
	var b := CreatureMesh.new()
	var gold := Color("f2b632")
	var dark := Color("2a2118")
	b.add(Mesh3.blob(Vector3(0.2, 0.19, 0.3), 2.1, 8, 12), func(_n: Vector3, p: Vector3) -> Color:
		var band := int(floor((p.z + 0.3) / 0.12))
		return dark if (band % 2 == 1 or p.z > 0.22) else gold, Transform3D(Basis(), Vector3(0, 0, 0.18)))
	b.add(Mesh3.blob(Vector3(0.17, 0.16, 0.16), 2.0, 7, 10), Color("d99a2a").lerp(Color("7a5a2a"), 0.3), Transform3D(Basis(), Vector3(0, 0.03, -0.14)))
	b.add(Mesh3.blob(Vector3(0.13, 0.12, 0.11), 2.0, 6, 10), dark, Transform3D(Basis(), Vector3(0, 0.02, -0.33)))
	for side: float in [-1.0, 1.0]:
		b.add(Mesh3.blob(Vector3(0.05, 0.08, 0.06), 2.0, 5, 8), Color("3a3230"), Transform3D(Basis(), Vector3(side * 0.09, 0.04, -0.35)), CreatureMesh.GLOSS)
		b.add(Mesh3.tube([Vector3(side * 0.04, 0.1, -0.4), Vector3(side * 0.09, 0.22, -0.5), Vector3(side * 0.11, 0.2, -0.58)], 0.012, 4), dark, Transform3D.IDENTITY, CreatureMesh.PLAIN)
		for leg in 3:
			var z := -0.2 + leg * 0.09
			b.add(Mesh3.tube([Vector3(side * 0.1, -0.08, z), Vector3(side * 0.19, -0.2, z + 0.03), Vector3(side * 0.2, -0.3, z + 0.06)], 0.014, 4), dark, Transform3D.IDENTITY, CreatureMesh.PLAIN)
	var mesh := b.commit()
	var sw := SurfaceTool.new()
	sw.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var base := Vector3(0.05 * side, 0.22, -0.08)
		var quad := [base, base + Vector3(0.5 * side, 0.26, -0.08), base + Vector3(0.48 * side, 0.22, 0.24), base + Vector3(0.03 * side, 0.02, 0.16)]
		for k in [0, 1, 2, 0, 2, 3]:
			sw.set_normal(Vector3.UP)
			sw.add_vertex(quad[k])
	sw.commit(mesh)
	var wings := ShaderMaterial.new()
	wings.shader = preload("res://shaders/bee.gdshader")
	mesh.surface_set_material(1, wings)
	return mesh


func _process(delta: float) -> void:
	if camera == null or world == null:
		return
	_time += delta
	var cam := camera.global_position
	_flower_timer -= delta
	if _flower_timer <= 0.0:
		_flower_timer = 1.0
		_flowers = world.flowers_near(cam, 30.0)
	_update_butterflies(cam, delta)
	_update_bees(cam, delta)


func _pick_flower(near: Vector3, max_d: float, lavender_ok := true) -> Vector3:
	var best := Vector3.INF
	for i in 8:
		if _flowers.is_empty():
			break
		var f: Array = _flowers[_rng.randi() % _flowers.size()]
		if not lavender_ok and f[1] == 1 and _rng.randf() < 0.7:
			continue
		var p: Vector3 = f[0]
		if p.distance_to(near) < max_d:
			return p
		if best == Vector3.INF or p.distance_to(near) < best.distance_to(near):
			best = p
	return best


func _update_butterflies(cam: Vector3, delta: float) -> void:
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for it in _items:
		var node: MeshInstance3D = it["node"]
		node.visible = activity > 0.05
		if not node.visible:
			it["pos"] = Vector3.INF
			continue
		var pos: Vector3 = it["pos"]
		# too far away or behind you: appear again somewhere ahead
		if pos == Vector3.INF or pos.distance_to(cam) > 32.0 or (pos - cam).dot(fwd) < -6.0:
			pos = cam + fwd * _rng.randf_range(5.0, 22.0) + fwd.cross(Vector3.UP) * _rng.randf_range(-10.0, 10.0)
			pos.y = world.height_local(pos.x, pos.z) + 1.0
			it["target"] = Vector3.INF
			it["rest"] = 0.0
		var target: Vector3 = it["target"]
		if target == Vector3.INF and patience > 0.9 and rest_spot != Vector3.INF and not _someone_on_you() and _rng.randf() < 0.3:
			# you've been so still: it lands on you
			target = rest_spot
			it["target"] = target
			it["wander"] = false
			it["on_you"] = true
		if it.get("on_you", false) and rest_spot != Vector3.INF:
			target = rest_spot
			it["target"] = target
			if float(it["rest"]) > 0.0:
				pos = rest_spot
		if target == Vector3.INF:
			target = _pick_flower(pos, 9.0, false)
			if target == Vector3.INF or target.distance_to(pos) > 12.0:
				# no flowers near: wander in loops
				var a := _rng.randf() * TAU
				target = pos + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(2.0, 5.0)
				target.y = world.height_local(target.x, target.z) + 0.7
				it["wander"] = true
			else:
				it["wander"] = false
			it["target"] = target
		var t: float = _time * it["speed"] + it["seed"]
		if it["rest"] > 0.0:
			# sitting on the flower: wings slowly open and close; fly off early if you come close
			it["rest"] = float(it["rest"]) - delta
			it["rest_t"] = minf(float(it["rest_t"]) + delta * 3.0, 1.0)
			if pos.distance_to(cam) < 2.2 and patience < 0.6 and not it.get("on_you", false):
				it["rest"] = 0.0
			if it.get("on_you", false) and (rest_spot == Vector3.INF or patience < 0.5):
				it["rest"] = 0.0
				it["on_you"] = false
			if it["rest"] <= 0.0:
				it["target"] = Vector3.INF
				pos.y += 0.05
		else:
			it["rest_t"] = maxf(float(it["rest_t"]) - delta * 4.0, 0.0)
			var to := target - pos
			var dist := to.length()
			if dist < 0.12:
				if not it["wander"]:
					it["rest"] = _rng.randf_range(3.0, 9.0)
					pos = target
				else:
					it["target"] = Vector3.INF
			else:
				# fluttery flight: towards the target with sideways and up-down wobble, slow near the flower
				var dir := to / dist
				var side := dir.cross(Vector3.UP).normalized()
				var spd := lerpf(0.6, 1.6, clampf(dist / 2.0, 0.0, 1.0))
				var wob := side * sin(t * 3.1) * 0.9 + Vector3.UP * (sin(t * 4.3) * 0.7 + (0.4 if dist > 1.0 else 0.0))
				pos += (dir * spd + wob * clampf(dist, 0.0, 1.0)) * delta
				var ground := world.height_local(pos.x, pos.z)
				pos.y = clampf(pos.y, ground + 0.25, ground + 2.4)
				it["yaw"] = lerp_angle(float(it["yaw"]), atan2(-dir.x, -dir.z), 1.0 - exp(-4.0 * delta))
		it["pos"] = pos
		node.global_position = pos
		var s := node.scale
		node.rotation = Vector3(0, float(it["yaw"]), 0)
		node.scale = s
		node.set_instance_shader_parameter("rest", float(it["rest_t"]))


func _someone_on_you() -> bool:
	for it in _items:
		if it.get("on_you", false):
			return true
	return false


func _update_bees(cam: Vector3, delta: float) -> void:
	var mm := _bees.multimesh
	var lav := 0
	for f in _flowers:
		lav += int(f[1])
	# many bees in the lavender, a few at flower meadows, none at night or in the rain
	var want := 0
	if activity > 0.3:
		want = BEES if lav > 20 else (6 if _flowers.size() > 12 else 0)
	mm.visible_instance_count = want
	var nearest := INF
	for i in want:
		var b := _bee_state[i]
		var fl: Vector3 = b["flower"]
		if fl == Vector3.INF or fl.distance_to(cam) > 26.0:
			fl = _pick_flower(cam, 20.0)
			if fl == Vector3.INF:
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), cam))
				continue
			b["pos"] = fl + Vector3(0, 0.3, 0)
		b["next"] = float(b["next"]) - delta
		if b["next"] <= 0.0:
			# dart to a flower close by
			var n := _pick_flower(fl, 3.0)
			if n != Vector3.INF and n.distance_to(fl) < 3.0:
				fl = n
			b["next"] = _rng.randf_range(1.2, 4.0)
		b["flower"] = fl
		var t := _time + float(b["seed"])
		var hover := fl + Vector3(sin(t * 2.3) * 0.18 + sin(t * 7.1) * 0.05, 0.14 + sin(t * 3.7) * 0.07, cos(t * 1.9) * 0.18)
		var p: Vector3 = b["pos"]
		var np := p.lerp(hover, 1.0 - exp(-5.0 * delta))
		var vel := np - p
		b["pos"] = np
		var yaw := atan2(-vel.x, -vel.z) if vel.length() > 0.0005 else 0.0
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.08), np))
		mm.set_instance_custom_data(i, Color(float(b["seed"]), 0, 0, 0))
		var d := np.distance_to(cam)
		if d < nearest:
			nearest = d
			_buzz.global_position = np
	var vol: float = Settings.values.get("sfx_volume", 0.8)
	if nearest < 8.0 and vol > 0.01:
		if not _buzz.playing:
			_buzz.play()
		_buzz.volume_db = -16.0 + linear_to_db(vol)
	elif _buzz.playing:
		_buzz.stop()
