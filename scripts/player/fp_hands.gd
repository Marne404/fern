class_name FirstPersonHands
extends Node3D
## First person: what you hold is seen at the lower edge of the view – a mitten with the item on the right, the
## lantern or flashlight on the left, map and book held in both hands – bobbing with your steps and lagging a
## little when you turn.

var _right := ""
var _left := ""
var _r: Node3D
var _l: Node3D
var _bob := 0.0
var _sway := Vector2.ZERO
var _last_yaw := 0.0
var _show := 0.0
# empty hands reaching, punching, holding (world points from Hands), one mitten each
var _bare: Array[Node3D] = [null, null]
var _bare_col := Color.WHITE


func _ready() -> void:
	name = "FirstPersonHands"


## The empty hands at work: per hand {"pos": world, "active": bool, "fist": bool}
func update_bare(delta: float, on: bool, states: Array, hand_color: Color) -> void:
	var cam := get_parent() as Camera3D
	for i in 2:
		var st: Dictionary = states[i]
		var want: bool = on and st.get("active", false)
		if _bare[i] == null and want:
			var n := Node3D.new()
			n.name = "Bare%d" % i
			add_child(n)
			var m := MeshInstance3D.new()
			m.mesh = Mesh3.blob(Vector3(0.06, 0.066, 0.052), 2.1, 10, 14)
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/scout.gdshader")
			mat.set_shader_parameter("color", hand_color)
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(m)
			var th := MeshInstance3D.new()
			th.mesh = Mesh3.blob(Vector3(0.022, 0.034, 0.022), 2.0, 6, 10)
			th.material_override = mat
			th.position = Vector3(0.045 * (1 if i == 0 else -1), 0.02, -0.03)
			th.rotation.z = 0.55 * (-1 if i == 0 else 1)
			n.add_child(th)
			_bare[i] = n
		var b := _bare[i]
		if b == null:
			continue
		b.visible = want
		if not want or cam == null:
			continue
		# into the camera's space, kept at arm's length in front and inside the view
		var local: Vector3 = cam.global_transform.affine_inverse() * (st["pos"] as Vector3)
		local.z = clampf(local.z, -0.75, -0.3)
		var edge := absf(local.z) * 0.62
		local.x = clampf(local.x, -edge, edge)
		local.y = clampf(local.y, -edge * 0.6, edge * 0.5)
		b.position = b.position.lerp(local, 1.0 - exp(-25.0 * delta)) if b.position != Vector3.ZERO else local
		b.rotation = Vector3(0.6 if st.get("fist", false) else 1.2, 0.0, 0.0)
		b.scale = Vector3.ONE * (0.8 if st.get("fist", false) else 1.0)


func update(delta: float, on: bool, right_id: String, left_id: String, hand_color: Color, step_phase: float, speed: float, yaw: float, lit: bool) -> void:
	_show = move_toward(_show, 1.0 if on else 0.0, delta * 5.0)
	visible = _show > 0.0
	if right_id != _right:
		_right = right_id
		_rebuild("R", right_id, hand_color)
	if left_id != _left:
		_left = left_id
		_rebuild("L", left_id, hand_color)
	if not visible:
		return
	# steps: a small figure-eight; turning: the hands lag behind
	var amp := clampf(speed / 3.4, 0.0, 1.3)
	var dyaw := angle_difference(_last_yaw, yaw) / maxf(delta, 1e-4)
	_last_yaw = yaw
	_sway = _sway.lerp(Vector2(clampf(dyaw * 0.012, -0.05, 0.05), 0.0), 1.0 - exp(-8.0 * delta))
	var ph := TAU * step_phase
	var bob := Vector3(sin(ph) * 0.012, -absf(cos(ph)) * 0.014, 0.0) * amp
	var hide := (1.0 - _show) * 0.35
	if _r:
		_r.position = Vector3(0.24, -0.27 - hide, -0.48) + bob + Vector3(_sway.x, 0, 0)
		if ScoutGear.grip_of(_right) == "read":
			_r.position = Vector3(0.0, -0.26 - hide, -0.46) + bob * 0.5
	if _l:
		_l.position = Vector3(-0.25, -0.17 - hide, -0.5) + bob * Vector3(-1, 1, 1) + Vector3(_sway.x, 0, 0)
		var glow: Node3D = _l.get_node_or_null("Glow")
		if glow:
			glow.visible = lit


func _rebuild(side: String, id: String, hand_color: Color) -> void:
	var old: Node3D = _r if side == "R" else _l
	if old:
		old.queue_free()
	var n: Node3D = null
	if id != "":
		n = Node3D.new()
		n.name = "Hand" + side
		add_child(n)
		var read := ScoutGear.grip_of(id) == "read"
		# mittens (two for the map and the book)
		for k in (2 if read else 1):
			var m := MeshInstance3D.new()
			m.mesh = Mesh3.blob(Vector3(0.06, 0.066, 0.052), 2.1, 10, 14)
			var mat := ShaderMaterial.new()
			mat.shader = preload("res://shaders/scout.gdshader")
			mat.set_shader_parameter("color", hand_color)
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.position = Vector3((k * 2 - 1) * 0.13 if read else 0.0, -0.03, 0.03)
			m.rotation = Vector3(0.9, 0, 0)
			n.add_child(m)
		var it := MeshInstance3D.new()
		it.mesh = ItemModels.mesh(id)
		it.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		match ScoutGear.grip_of(id):
			"hang":
				it.position = Vector3(0, -0.13, 0)
				it.scale = Vector3.ONE * 1.35
				var g := MeshInstance3D.new()
				g.name = "Glow"
				var sm := SphereMesh.new()
				sm.radius = 0.035
				sm.height = 0.07
				g.mesh = sm
				var gm := StandardMaterial3D.new()
				gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				gm.albedo_color = Color(1.0, 0.85, 0.5)
				g.material_override = gm
				g.position = Vector3(0, -0.14, 0)
				n.add_child(g)
			"point":
				it.rotation = Vector3(0, PI * 0.5, 0)
				it.position = Vector3(0, 0.0, -0.08)
				it.scale = Vector3.ONE * 1.3
			"stick":
				# only the knob shows above the mitten, the stick goes down and ahead
				it.rotation = Vector3(0.5, 0, PI * 0.5)
				it.position = Vector3(0, -0.36, -0.1)
				it.scale = Vector3.ONE * 0.85
			"read":
				it.rotation = Vector3(1.1, 0, 0)
				it.position = Vector3(0, 0.02, -0.02)
				it.scale = Vector3.ONE * (2.2 if id == "karte" else 1.2)
			_:
				it.rotation = Vector3(0.6, 0.4, 0)
				it.position = Vector3(0, 0.04, -0.04)
				it.scale = Vector3.ONE * 1.1
		n.add_child(it)
	if side == "R":
		_r = n
	else:
		_l = n


## Where the lantern is (for its light), or Vector3.INF
func lantern_pos() -> Vector3:
	if _l and visible and _left == "laterne":
		return _l.global_position + Vector3(0, -0.12, 0)
	return Vector3.INF
