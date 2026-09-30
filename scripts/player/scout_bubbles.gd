class_name ScoutBubbles
extends Node3D
## Little symbols that pop up above the scout's head: hearts, music notes, "!", "?", an anger mark, sparkles,
## Zzz, a sweat drop, thinking dots. Drawn as flat inked shapes that always face the camera, popping in with
## an overshoot, floating up with a wobble and shrinking away.

const KINDS := ["heart", "note", "exclaim", "question", "anger", "sparkle", "zzz", "drop", "dots"]
const MAX := 5

var scout: Scout
var head: Node3D
var _active: Array[Dictionary] = []
var _pool := {}


func setup(sc: Scout, head_node: Node3D) -> void:
	scout = sc
	head = head_node
	name = "Bubbles"


## Shows a symbol; side: -1 left, 1 right, 0 middle; big: scale factor
func pop(kind: String, dur := 1.6, side := 0.0, big := 1.0) -> void:
	if not kind in KINDS:
		return
	if _active.size() >= MAX:
		_release(_active.pop_front())
	var n := _take(kind)
	n.visible = true
	_active.append({"node": n, "t": 0.0, "dur": dur, "side": side + randf_range(-0.15, 0.15), "big": big, "spin": randf_range(-1.0, 1.0)})


func clear() -> void:
	for a in _active:
		_release(a)
	_active.clear()


func _process(delta: float) -> void:
	if _active.is_empty() or head == null:
		return
	var cam := get_viewport().get_camera_3d()
	# just above the top of the head (the neck pivot sits at the chin)
	var top := head.global_transform * Vector3(0, 0.62, 0)
	var i := 0
	while i < _active.size():
		var a: Dictionary = _active[i]
		a["t"] += delta
		var t: float = a["t"]
		var dur: float = a["dur"]
		if t >= dur:
			_release(a)
			_active.remove_at(i)
			continue
		var n: Node3D = a["node"]
		var right := Vector3.RIGHT
		if cam:
			right = cam.global_basis.x
		var rise := 0.12 + 0.3 * (t / dur)
		n.global_position = top + right * (float(a["side"]) * 0.28 + sin(t * 3.0 + float(a["spin"]) * 3.0) * 0.03) + Vector3(0, rise, 0)
		if cam:
			# +Z (the shapes' front) towards the camera
			n.look_at(n.global_position - cam.global_basis.z, Vector3.UP)
		n.rotate_object_local(Vector3.BACK, sin(t * 5.0) * 0.18 * float(a["spin"]))
		# pop in with an overshoot, hold, shrink away
		var k := _ease_back(clampf(t / 0.28, 0.0, 1.0)) * (1.0 - smoothstep(dur - 0.3, dur, t))
		n.scale = Vector3.ONE * maxf(k * float(a["big"]), 0.001)
		i += 1


static func _ease_back(x: float) -> float:
	var c := 2.2
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


func _take(kind: String) -> Node3D:
	var list: Array = _pool.get(kind, [])
	if not list.is_empty():
		return list.pop_back()
	var n := _build(kind)
	n.set_meta("kind", kind)
	add_child(n)
	return n


func _release(a: Dictionary) -> void:
	var n: Node3D = a["node"]
	n.visible = false
	var kind: String = n.get_meta("kind")
	if not _pool.has(kind):
		_pool[kind] = []
	_pool[kind].append(n)


# ---------------------------------------------------------------- shapes

func _shape(parent: Node3D, pts: PackedVector2Array, role: String, outline := 1.22, at := Vector2.ZERO) -> void:
	var back := PackedVector2Array()
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	for p in pts:
		back.append(c + (p - c) * outline + at)
	var fore := PackedVector2Array()
	for p in pts:
		fore.append(p + at)
	_mesh(parent, ScoutFaceFx.flat(back, -0.01), "ink")
	_mesh(parent, ScoutFaceFx.flat(fore, 0.0), role)


func _line(parent: Node3D, pts: Array, r: float, role: String) -> void:
	var ups := []
	for i in pts.size():
		ups.append(Vector3(0, 0, 1))
	var p3 := []
	for p in pts:
		p3.append(Vector3(p.x, p.y, 0.0))
	var back := []
	for p in pts:
		back.append(Vector3(p.x, p.y, -0.02))
	_mesh(parent, Mesh3.tube(back, r * 1.8, 8, ups, 0.35), "ink")
	_mesh(parent, Mesh3.tube(p3, r, 8, ups, 0.35), role)


func _mesh(parent: Node3D, m: Mesh, role: String) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = scout._mat(role)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build(kind: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Bubble_" + kind
	match kind:
		"heart":
			_shape(n, ScoutFaceFx.heart_pts(0.16), "heart")
			_mesh(n, ScoutFaceFx.flat(ScoutFaceFx.oval_pts(0.014, 0.01), 0.004), "white")
			(n.get_child(n.get_child_count() - 1) as Node3D).position = Vector3(-0.035, 0.025, 0)
		"sparkle":
			_shape(n, ScoutFaceFx.star_pts(0.085, 0.022, 4), "star")
			_shape(n, ScoutFaceFx.star_pts(0.04, 0.011, 4), "star", 1.3, Vector2(0.09, 0.07))
			_shape(n, ScoutFaceFx.star_pts(0.03, 0.008, 4), "star", 1.3, Vector2(-0.08, 0.08))
		"drop":
			_shape(n, ScoutFaceFx.drop_pts(0.12), "tear")
		"note":
			for k in 2:
				var x := -0.05 + k * 0.07
				var y := -0.05 + k * 0.02
				var head_pts := PackedVector2Array()
				for p in ScoutFaceFx.oval_pts(0.024, 0.018):
					head_pts.append(p.rotated(0.4))
				_shape(n, head_pts, "note", 1.35, Vector2(x, y))
				_line(n, [Vector2(x + 0.02, y + 0.005), Vector2(x + 0.02, y + 0.1)], 0.006, "note")
			_line(n, [Vector2(-0.03, 0.105), Vector2(0.04, 0.125)], 0.009, "note")
		"exclaim":
			_line(n, [Vector2(0, 0.1), Vector2(0, 0.0)], 0.018, "alert")
			_shape(n, ScoutFaceFx.oval_pts(0.018, 0.018), "alert", 1.5, Vector2(0, -0.05))
		"question":
			var q := []
			for i in 14:
				var a := PI * 1.05 - i / 13.0 * PI * 1.5
				q.append(Vector2(cos(a) * 0.045, 0.07 + sin(a) * 0.04))
			q.append(Vector2(0.0, 0.0))
			_line(n, q, 0.013, "alert")
			_shape(n, ScoutFaceFx.oval_pts(0.016, 0.016), "alert", 1.5, Vector2(0, -0.045))
		"anger":
			for k in 4:
				var a := k * PI * 0.5 + PI * 0.25
				var c := Vector2(cos(a), sin(a)) * 0.1
				var arc := []
				for i in 7:
					var b := a + PI * 0.82 + i / 6.0 * PI * 0.36
					arc.append(c + Vector2(cos(b), sin(b)) * 0.06)
				_line(n, arc, 0.014, "anger")
		"zzz":
			for k in 3:
				var s := 0.022 + k * 0.01
				var o := Vector2(-0.1 + k * 0.085, -0.06 + k * 0.08)
				_line(n, [o + Vector2(-s, s), o + Vector2(s, s), o + Vector2(-s, -s), o + Vector2(s, -s)], 0.008, "sleep")
		"dots":
			for k in 3:
				_shape(n, ScoutFaceFx.oval_pts(0.017, 0.017), "white", 1.45, Vector2(-0.06 + k * 0.06, 0))
	return n
