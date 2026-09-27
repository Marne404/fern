class_name Scout
extends Node3D
## The hiker you play: a soft, bean-shaped scout with dot eyes, noodle arms, short legs, a neckerchief,
## a merit-badge sash and a big backpack (inspired by the scouts of PEAK).
## Built entirely from procedural meshes and animated procedurally (walk, run, crouch, sit, lie,
## swim, climb, fall, wave), with springs on arms, backpack and hat so everything flops a little.

const SKIN_COLORS := [
	Color("f2c230"), Color("f08a3c"), Color("ef6f6c"), Color("f59ac0"), Color("b28ce8"),
	Color("6fb6ee"), Color("3fbfb0"), Color("8cc657"), Color("9a6a4b"), Color("f3e2c4"),
]
const OUTFIT_COLORS := [
	Color("c9a86a"), Color("5b8a4c"), Color("3d5a8c"), Color("b3424a"),
	Color("d9a735"), Color("9bb48a"), Color("9c86c9"), Color("4a4f55"),
]
const ACCENT_COLORS := [
	Color("d1493f"), Color("ec8a34"), Color("f2c53d"), Color("9ccc4a"), Color("4f8f4a"), Color("3aa99c"),
	Color("58a6e0"), Color("3f5fae"), Color("8a62c4"), Color("ec86b0"), Color("8b5a36"), Color("efe2c2"),
]
const HAT_NAMES := ["No hat", "Ranger hat", "Bucket hat", "Beanie", "Cap"]
const FACE_NAMES := ["Happy", "Cheery", "Sleepy", "Wide-eyed"]
const DEFAULT_LOOK := {"skin": 0, "outfit": 0, "scarf": 0, "hat": 1, "hat_color": 10, "pack": 1, "face": 0}

enum Pose { STAND, CROUCH, SIT, LIE, SWIM, CLIMB }
enum Mood { NORMAL, TIRED, KNOCKED_OUT, ASLEEP, JOY }

# Body shape (meters, feet at y = 0, facing -Z)
const BODY_Y0 := 0.40
const BODY_H := 1.22
const BODY_DZ := 0.88
const HIP_Y := 0.54
const SHIRT_TOP := 0.53      # fraction of the body height
const HAT_Y := 1.45

## Animation inputs (set by the owner every frame)
var speed := 0.0
var sprint := false
var on_floor := true
var pose := Pose.STAND
var mood := Mood.NORMAL
var waving := false
## Yaw change per second (lean into turns, arms swing out)
var turn_rate := 0.0

var look := DEFAULT_LOOK.duplicate()
## true: StandardMaterial3D instead of the toon shader (for glTF export)
var export_mode := false

var rig: Node3D
var hips: Node3D
var _upper: Node3D
var _legs := []      # per side: [hip, knee, foot]
var _arms := []      # per side: [shoulder, elbow, hand]
var _pack: Node3D
var _hat_pivot: Node3D
var _hats: Array[Node3D] = []
var _face := {}
var _mats := {}
var _meshes: Array[MeshInstance3D] = []
var _shadow_only := false
## Merged meshes per animated node: [MeshInstance3D, vertices, normals, indices, roles per vertex]
var _baked: Array = []
var _baked_mat: ShaderMaterial
const NO_BAKE := ["eye", "white", "mouth"]
const NO_SHADOW := ["eye", "white", "mouth", "cheek"]

var _t := 0.0
var _phase := 0.0
var _amp := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _springs := {}
var _look_eyes := Vector2.ZERO
var _look_timer := 1.0
var _wave_t := 0.0
var _face_state := ""


func _init(look_in: Dictionary = {}, for_export := false) -> void:
	export_mode = for_export
	name = "Scout"
	set_look_data(look_in)
	_build()
	if not export_mode:
		_bake()
	apply_look()


func set_look_data(d: Dictionary) -> void:
	look = DEFAULT_LOOK.duplicate()
	for k in d:
		if look.has(k):
			look[k] = int(d[k])


static func random_look() -> Dictionary:
	return {
		"skin": randi() % SKIN_COLORS.size(), "outfit": randi() % OUTFIT_COLORS.size(),
		"scarf": randi() % ACCENT_COLORS.size(), "hat": randi() % HAT_NAMES.size(),
		"hat_color": randi() % ACCENT_COLORS.size(), "pack": randi() % ACCENT_COLORS.size(),
		"face": randi() % FACE_NAMES.size(),
	}


## First person: only the shadow of the scout is visible
func set_shadow_only(on: bool) -> void:
	_shadow_only = on
	for m in _meshes:
		if m.get_meta("role", "") in NO_SHADOW:
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_face_state = ""


func wave(duration := 2.2) -> void:
	_wave_t = duration


# ================================================================ Colors

func apply_look() -> void:
	var skin: Color = SKIN_COLORS[look["skin"] % SKIN_COLORS.size()]
	var outfit: Color = OUTFIT_COLORS[look["outfit"] % OUTFIT_COLORS.size()]
	var scarf: Color = ACCENT_COLORS[look["scarf"] % ACCENT_COLORS.size()]
	var hat: Color = ACCENT_COLORS[look["hat_color"] % ACCENT_COLORS.size()]
	var pack: Color = ACCENT_COLORS[look["pack"] % ACCENT_COLORS.size()]
	_set_color("skin", skin)
	_set_color("cheek", skin.lerp(Color("ff5a7a"), 0.35))
	_set_color("outfit", outfit)
	_set_color("collar", outfit.lightened(0.12))
	_set_color("pants", outfit.darkened(0.3).lerp(Color("5a4632"), 0.35))
	_set_color("scarf", scarf)
	_set_color("hat", hat)
	_set_color("hatband", hat.darkened(0.45))
	_set_color("pack", pack)
	_set_color("pack2", pack.darkened(0.22))
	# the sleeping pad contrasts with the backpack
	_set_color("pad", Color("5b86b5") if pack.b < pack.r else Color("d9824a"))
	for i in _hats.size():
		_hats[i].visible = i == look["hat"] % HAT_NAMES.size()
	_face_state = ""
	_recolor()


func _set_color(role: String, c: Color) -> void:
	var m = _mat(role)
	if m is ShaderMaterial:
		m.set_shader_parameter("color", c)
	else:
		m.albedo_color = c


const FIXED := {
	"leather": Color("6b4428"), "sole": Color("3a2d24"), "metal": Color("9fb6c4"), "eye": Color("1d1a22"),
	"white": Color(1, 1, 1), "sock": Color("f4efe4"), "rope": Color("cdb07a"), "mouth": Color("5a2530"),
	"badge1": Color("d8453e"), "badge2": Color("f2c230"), "badge3": Color("3d7fd6"), "wood": Color("a0703c"),
}
const GLOSSY := ["eye", "metal", "badge1", "badge2", "badge3"]
const CLOTH := ["outfit", "pants", "scarf", "hat", "pack", "pack2", "pad", "sock", "collar"]


func _mat(role: String) -> Material:
	if _mats.has(role):
		return _mats[role]
	var c: Color = FIXED.get(role, Color.WHITE)
	var m: Material
	if export_mode:
		var sm := StandardMaterial3D.new()
		sm.resource_name = role
		sm.albedo_color = c
		sm.roughness = 0.35 if role in GLOSSY else 0.9
		if role == "white":
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m = sm
	else:
		var shm := ShaderMaterial.new()
		shm.shader = preload("res://shaders/scout.gdshader")
		shm.set_shader_parameter("color", c)
		shm.set_shader_parameter("gloss", 1.0 if role in GLOSSY else 0.0)
		shm.set_shader_parameter("cloth", 1.0 if role in CLOTH else 0.0)
		shm.set_shader_parameter("emission", 1.0 if role == "white" else 0.0)
		m = shm
	_mats[role] = m
	return m


# ================================================================ Construction

func _add(parent: Node3D, mesh: Mesh, role: String, node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(role)
	mi.set_meta("role", role)
	if role in NO_SHADOW:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node_name != "":
		mi.name = node_name
	parent.add_child(mi)
	_meshes.append(mi)
	return mi


func _node(parent: Node3D, node_name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	rig = _node(self, "Rig")
	hips = _node(rig, "Hips", Vector3(0, HIP_Y, 0))
	# everything attached to the torso is modeled in absolute coordinates below this node
	_upper = _node(hips, "Upper", Vector3(0, -HIP_Y, 0))
	_build_body()
	_build_face()
	for side: int in [-1, 1]:
		_build_arm(side)
		_build_leg(side)
	_build_pack()
	_build_hats()


func _build_body() -> void:
	var prof := []
	for i in 49:
		var u := i / 48.0
		var t := (1.0 - cos(PI * u)) * 0.5
		var y := BODY_Y0 + t * BODY_H
		prof.append(Vector2(body_r(y), y))
	_add(_upper, Mesh3.lathe(prof, 64, BODY_DZ), "skin", "Body")
	# shirt and shorts: shells around the lower body
	_add(_upper, Mesh3.lathe(_shell(0.0, SHIRT_TOP, 0.013), 64, BODY_DZ), "outfit", "Shirt")
	_add(_upper, Mesh3.lathe(_shell(0.0, 0.2, 0.024), 64, BODY_DZ), "pants", "Shorts")
	var top_y := BODY_Y0 + SHIRT_TOP * BODY_H
	_add(_upper, Mesh3.tube(_ring(top_y, 0.012, 48), 0.013, 8, [], 1.0, false), "collar", "Collar")
	var belt_y := BODY_Y0 + 0.2 * BODY_H
	var belt := _ring(belt_y, 0.03, 40)
	_add(_upper, Mesh3.tube(belt, 0.022, 8, _ring_normals(belt_y, 40), 0.45, false), "leather", "Belt")
	var bp: Array = body_point(belt_y, 0.0, 0.045)
	_add(_upper, Mesh3.blob(Vector3(0.036, 0.027, 0.012), 3.0, 8, 14, _frame(bp[0], bp[1])), "metal", "Buckle")
	# neckerchief: rolled band around the neck, a tapering flap in front and a wooden woggle
	var roll_y := top_y + 0.02
	_add(_upper, Mesh3.tube(_ring(roll_y, 0.016, 48), 0.02, 10, _ring_normals(roll_y, 48), 0.8, false), "scarf", "ScarfRoll")
	var flap := []
	var flap_n := []
	var flap_r := []
	for i in 9:
		var f := i / 8.0
		var p: Array = body_point(roll_y - f * 0.19, 0.0, 0.022 + (1.0 - f) * 0.008)
		flap.append(p[0])
		flap_n.append(p[1])
		flap_r.append(lerpf(0.075, 0.012, pow(f, 0.8)))
	_add(_upper, Mesh3.tube(flap, flap_r, 10, flap_n, 0.22), "scarf", "ScarfFlap")
	var wp: Array = body_point(roll_y - 0.06, 0.0, 0.03)
	var ring := []
	for i in 17:
		var a := TAU * i / 16.0
		ring.append(wp[0] + Vector3(cos(a) * 0.036, 0, sin(a) * 0.012))
	_add(_upper, Mesh3.tube(ring, 0.01, 6, [], 1.0, false), "wood", "Woggle")
	# merit badge sash: a tilted loop around the torso, three badges in front
	var sash := []
	var sash_n := []
	for i in 65:
		var th := TAU * i / 64.0 - PI
		var y := BODY_Y0 + (0.34 - 0.2 * sin(th)) * BODY_H
		var p: Array = body_point(y, th, 0.024)
		sash.append(p[0])
		sash_n.append(p[1])
	_add(_upper, Mesh3.tube(sash, 0.034, 8, sash_n, 0.28, false), "scarf", "Sash")
	var bi := 1
	for th: float in [-0.62, -0.28, 0.06]:
		var y: float = BODY_Y0 + (0.34 - 0.2 * sin(th)) * BODY_H
		var p: Array = body_point(y, th, 0.034)
		var disc := [Vector2(0, -0.006), Vector2(0.022, -0.006), Vector2(0.027, 0.0), Vector2(0.022, 0.006), Vector2(0, 0.007)]
		_add(_upper, Mesh3.lathe(disc, 16, 1.0, _frame_up(p[0], p[1])), "badge%d" % bi, "Badge%d" % bi)
		bi += 1
	# backpack straps over the shoulders
	for side: int in [-1, 1]:
		var ctrl := [Vector2(-0.5, 0.74), Vector2(-0.6, 0.93), Vector2(-0.8, 1.06), Vector2(-1.2, 1.11),
			Vector2(-1.9, 1.1), Vector2(-2.4, 1.02), Vector2(-2.6, 0.95)]
		var pts := []
		var nrm := []
		for c in Mesh3.catmull(ctrl, 5):
			var p: Array = body_point(c.y, c.x * side, 0.03)
			pts.append(p[0])
			nrm.append(p[1])
		_add(_upper, Mesh3.tube(pts, 0.022, 8, nrm, 0.35), "pack2", "Strap%s" % ("L" if side < 0 else "R"))


func _build_face() -> void:
	var fy := 1.29
	for side: int in [-1, 1]:
		var s := "L" if side < 0 else "R"
		var th: float = 0.36 * side
		var p: Array = body_point(fy, th, -0.004)
		var pivot := Node3D.new()
		pivot.name = "Eye" + s
		pivot.transform = _frame(p[0], p[1])
		_upper.add_child(pivot)
		_add(pivot, Mesh3.blob(Vector3(0.047, 0.074, 0.024), 2.0, 12, 18), "eye")
		var hl := _add(pivot, Mesh3.blob(Vector3(0.013, 0.015, 0.008), 2.0, 6, 10), "white")
		hl.position = Vector3(-0.014, 0.03, 0.02)
		var hl2 := _add(pivot, Mesh3.blob(Vector3(0.006, 0.006, 0.006), 2.0, 5, 8), "white")
		hl2.position = Vector3(0.015, -0.024, 0.021)
		_face["eye" + s] = pivot
		# eyelid (sleepy / tired): skin-colored cap over the upper half of the eye
		var lid := _add(pivot, Mesh3.blob(Vector3(0.056, 0.042, 0.032), 2.0, 8, 14), "skin", "Lid" + s)
		lid.position = Vector3(0, 0.04, 0.004)
		_face["lid" + s] = lid
		# ^ eyes (cheery), closed eyes (sleeping) and X eyes (knocked out)
		_face["happy" + s] = _face_curve("Happy" + s, fy - 0.01, th, _arc(0.036, 0.028, true), 0.012)
		_face["closed" + s] = _face_curve("Closed" + s, fy - 0.012, th, _arc(0.034, -0.018, true), 0.01)
		var x1 := _face_curve("X1" + s, fy, th, [Vector2(-0.03, 0.03), Vector2(0.03, -0.03)], 0.011)
		var x2 := _face_curve("X2" + s, fy, th, [Vector2(-0.03, -0.03), Vector2(0.03, 0.03)], 0.011)
		_upper.remove_child(x2)
		x1.add_child(x2)
		_face["x" + s] = x1
		var cp: Array = body_point(fy - 0.085, 0.6 * side, -0.003)
		_add(_upper, Mesh3.blob(Vector3(0.042, 0.024, 0.012), 2.0, 6, 12, _frame(cp[0], cp[1])), "cheek", "Cheek" + s)
	var my := 1.19
	_face["smile"] = _face_curve("Smile", my, 0.0, _arc(0.034, -0.014, false), 0.009)
	_face["flat"] = _face_curve("Flat", my, 0.0, [Vector2(-0.022, 0.0), Vector2(0.022, 0.0)], 0.008)
	var wavy := []
	for i in 9:
		var u := i / 8.0
		wavy.append(Vector2(lerpf(-0.03, 0.03, u), sin(u * TAU) * 0.006))
	_face["wavy"] = _face_curve("Wavy", my, 0.0, wavy, 0.007)
	var mp: Array = body_point(my, 0.0, -0.006)
	var grin := _add(_upper, Mesh3.blob(Vector3(0.036, 0.024, 0.014), 2.0, 8, 12, _frame(mp[0], mp[1]).translated_local(Vector3(0, -0.006, 0))), "mouth", "Grin")
	_face["grin"] = grin
	var op: Array = body_point(my - 0.006, 0.0, -0.004)
	_face["o"] = _add(_upper, Mesh3.blob(Vector3(0.016, 0.02, 0.012), 2.0, 8, 12, _frame(op[0], op[1])), "mouth", "O")


func _build_arm(side: int) -> void:
	var s := "L" if side < 0 else "R"
	var sp: Array = body_point(0.97, PI * 0.5 * side, -0.035)
	var shoulder := _node(_upper, "Shoulder" + s, sp[0])
	_add(shoulder, Mesh3.capsule(0.06, 0.056, 0.25), "skin", "UpperArm" + s)
	var sleeve := [Vector2(0.066, 0.05), Vector2(0.075, -0.02), Vector2(0.077, -0.1), Vector2(0.071, -0.128), Vector2(0.057, -0.132)]
	_add(shoulder, Mesh3.lathe(sleeve, 18), "outfit", "Sleeve" + s)
	var elbow := _node(shoulder, "Elbow" + s, Vector3(0, -0.25, 0))
	_add(elbow, Mesh3.capsule(0.056, 0.052, 0.22), "skin", "Forearm" + s)
	var hand := _node(elbow, "Hand" + s, Vector3(0, -0.22, 0))
	_add(hand, Mesh3.blob(Vector3(0.056, 0.072, 0.046), 2.0, 10, 14, Transform3D(Basis(), Vector3(0, -0.05, 0))), "skin", "Mitten" + s)
	var thumb_x := 0.04 * -side
	_add(hand, Mesh3.blob(Vector3(0.022, 0.036, 0.022), 2.0, 6, 10, Transform3D(Basis(Vector3(0, 0, 1), 0.5 * side), Vector3(thumb_x, -0.035, -0.03))), "skin", "Thumb" + s)
	_arms.append([shoulder, elbow, hand])


func _build_leg(side: int) -> void:
	var s := "L" if side < 0 else "R"
	var hip := _node(rig, "Hip" + s, Vector3(0.125 * side, HIP_Y, 0))
	_add(hip, Mesh3.capsule(0.086, 0.08, 0.22), "pants", "Thigh" + s)
	var knee := _node(hip, "Knee" + s, Vector3(0, -0.22, 0))
	_add(knee, Mesh3.capsule(0.07, 0.066, 0.2), "skin", "Shin" + s)
	var sock := [Vector2(0.071, -0.1), Vector2(0.075, -0.11), Vector2(0.076, -0.2), Vector2(0.07, -0.21)]
	_add(knee, Mesh3.lathe(sock, 16), "sock", "Sock" + s)
	var stripe := []
	for i in 17:
		var a := TAU * i / 16.0
		stripe.append(Vector3(sin(a) * 0.077, -0.125, -cos(a) * 0.077))
	_add(knee, Mesh3.tube(stripe, 0.008, 6, [], 1.0, false), "scarf", "SockStripe" + s)
	var foot := _node(knee, "Foot" + s, Vector3(0, -0.2, 0))
	_add(foot, Mesh3.blob(Vector3(0.08, 0.07, 0.125), 2.6, 10, 16, Transform3D(Basis(), Vector3(0, -0.04, -0.035))), "leather", "Boot" + s)
	_add(foot, Mesh3.blob(Vector3(0.086, 0.02, 0.13), 3.0, 6, 16, Transform3D(Basis(), Vector3(0, -0.1, -0.035))), "sole", "Sole" + s)
	var cuff := []
	for i in 17:
		var a := TAU * i / 16.0
		cuff.append(Vector3(sin(a) * 0.078, 0.02, -cos(a) * 0.085 - 0.01))
	_add(foot, Mesh3.tube(cuff, 0.018, 6, [], 1.0, false), "leather", "Cuff" + s)
	_legs.append([hip, knee, foot])


func _build_pack() -> void:
	var back: Array = body_point(0.98, PI, 0.0)
	_pack = _node(_upper, "Pack", back[0])
	_add(_pack, Mesh3.blob(Vector3(0.215, 0.28, 0.14), 3.4, 14, 24, Transform3D(Basis(), Vector3(0, 0.0, 0.165))), "pack", "PackBody")
	_add(_pack, Mesh3.blob(Vector3(0.222, 0.075, 0.152), 3.0, 8, 20, Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.255, 0.17))), "pack2", "PackLid")
	_add(_pack, Mesh3.blob(Vector3(0.15, 0.105, 0.05), 3.0, 8, 16, Transform3D(Basis(), Vector3(0, -0.1, 0.31))), "pack2", "Pocket")
	_add(_pack, Mesh3.blob(Vector3(0.156, 0.035, 0.055), 3.0, 6, 16, Transform3D(Basis(), Vector3(0, -0.005, 0.318))), "pack", "PocketFlap")
	_add(_pack, Mesh3.blob(Vector3(0.018, 0.012, 0.008), 2.0, 5, 8, Transform3D(Basis(), Vector3(0, -0.04, 0.37))), "metal", "PocketButton")
	# sleeping pad rolled on top, strapped down
	var roll := [Vector2(0, -0.27), Vector2(0.07, -0.27), Vector2(0.088, -0.255), Vector2(0.09, 0.0), Vector2(0.088, 0.255), Vector2(0.07, 0.27), Vector2(0, 0.27)]
	_add(_pack, Mesh3.lathe(roll, 20, 1.0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.39, 0.16))), "pad", "Bedroll")
	for sx: float in [-0.14, 0.14]:
		var band := []
		for i in 21:
			var a := TAU * i / 20.0
			band.append(Vector3(sx, 0.39 + cos(a) * 0.095, 0.16 + sin(a) * 0.095))
		_add(_pack, Mesh3.tube(band, 0.016, 6, [], 0.4, false), "leather", "RollStrap")
	# bottle, mug and rope coil at the sides
	var bottle := [Vector2(0, -0.09), Vector2(0.04, -0.09), Vector2(0.046, -0.07), Vector2(0.046, 0.05), Vector2(0.03, 0.08), Vector2(0.018, 0.09), Vector2(0.02, 0.12), Vector2(0, 0.122)]
	_add(_pack, Mesh3.lathe(bottle, 16, 1.0, Transform3D(Basis(), Vector3(0.255, -0.1, 0.17))), "metal", "Bottle")
	var mug := [Vector2(0, -0.035), Vector2(0.036, -0.035), Vector2(0.04, 0.035), Vector2(0.034, 0.036), Vector2(0.03, -0.02), Vector2(0, -0.02)]
	_add(_pack, Mesh3.lathe(mug, 16, 1.0, Transform3D(Basis(), Vector3(-0.25, -0.02, 0.2))), "metal", "Mug")
	var handle := []
	for i in 13:
		var a := PI * i / 12.0
		handle.append(Vector3(-0.29 - sin(a) * 0.026, -0.02 + cos(a) * 0.025, 0.2))
	_add(_pack, Mesh3.tube(handle, 0.007, 6), "metal", "MugHandle")
	for k in 3:
		var coil := []
		for i in 25:
			var a := TAU * i / 24.0
			coil.append(Vector3(-0.232 - k * 0.018, -0.15 + cos(a) * 0.085, 0.14 + sin(a) * 0.085))
		_add(_pack, Mesh3.tube(coil, 0.017, 6, [], 1.0, false), "rope", "Rope%d" % k)


func _build_hats() -> void:
	_hat_pivot = _node(_upper, "HatPivot", Vector3(0, HAT_Y, 0))
	var inner := _node(_hat_pivot, "HatSpace", Vector3(0, -HAT_Y, 0))
	var dz := 0.92
	var none := _node(inner, "HatNone")
	_hats.append(none)
	# ranger hat: wide flat brim, peaked crown, dark band
	var ranger := _node(inner, "HatRanger")
	_add(ranger, Mesh3.lathe([Vector2(0.19, 1.452), Vector2(0.38, 1.456), Vector2(0.405, 1.47), Vector2(0.392, 1.484), Vector2(0.2, 1.478)], 40, dz), "hat")
	_add(ranger, Mesh3.lathe([Vector2(0.214, 1.45), Vector2(0.212, 1.56), Vector2(0.186, 1.64), Vector2(0.11, 1.69), Vector2(0.0, 1.705)], 36, dz), "hat")
	_add(ranger, Mesh3.lathe([Vector2(0.217, 1.474), Vector2(0.221, 1.48), Vector2(0.219, 1.52), Vector2(0.213, 1.526)], 36, dz), "hatband")
	_hats.append(ranger)
	# bucket hat: soft crown with a drooping brim
	var bucket := _node(inner, "HatBucket")
	_add(bucket, Mesh3.lathe([Vector2(0.232, 1.43), Vector2(0.222, 1.56), Vector2(0.2, 1.635), Vector2(0.12, 1.662), Vector2(0.0, 1.668)], 36, dz), "hat")
	_add(bucket, Mesh3.lathe([Vector2(0.22, 1.43), Vector2(0.33, 1.37), Vector2(0.345, 1.378), Vector2(0.338, 1.392), Vector2(0.232, 1.455)], 40, dz), "hat")
	_add(bucket, Mesh3.lathe([Vector2(0.232, 1.455), Vector2(0.235, 1.46), Vector2(0.232, 1.49), Vector2(0.228, 1.495)], 36, dz), "hatband")
	_hats.append(bucket)
	# beanie: knitted dome, thick cuff and a pompom
	var beanie := _node(inner, "HatBeanie")
	var dome := []
	for i in 17:
		var y := lerpf(1.36, 1.615, i / 16.0)
		dome.append(Vector2(body_r(y) + 0.028, y))
	dome.append(Vector2(0.09, 1.648))
	dome.append(Vector2(0.0, 1.655))
	_add(beanie, Mesh3.lathe(dome, 32, BODY_DZ + 0.02), "hat")
	_add(beanie, Mesh3.lathe([Vector2(0.262, 1.33), Vector2(0.285, 1.345), Vector2(0.285, 1.43), Vector2(0.262, 1.445)], 32, BODY_DZ + 0.02), "hatband")
	_add(beanie, Mesh3.blob(Vector3(0.075, 0.07, 0.075), 2.0, 10, 14, Transform3D(Basis(), Vector3(0, 1.7, 0))), "hat")
	_hats.append(beanie)
	# cap: snug dome with a visor
	var cap := _node(inner, "HatCap")
	var cdome := []
	for i in 15:
		var y := lerpf(1.44, 1.615, i / 14.0)
		cdome.append(Vector2(body_r(y) + 0.016, y))
	cdome.append(Vector2(0.07, 1.638))
	cdome.append(Vector2(0.0, 1.642))
	_add(cap, Mesh3.lathe(cdome, 32, BODY_DZ + 0.01), "hat")
	_add(cap, Mesh3.blob(Vector3(0.15, 0.012, 0.14), 2.2, 8, 20, Transform3D(Basis(Vector3.RIGHT, 0.22), Vector3(0, 1.455, -0.24))), "hatband")
	_add(cap, Mesh3.blob(Vector3(0.022, 0.012, 0.022), 2.0, 5, 8, Transform3D(Basis(), Vector3(0, 1.645, 0))), "hatband")
	_hats.append(cap)


# ================================================================ Merging

## Merges the static parts of every animated node into one mesh with vertex colors:
## ~20 draw calls instead of ~90 (matters for the shadow cascades in first person).
func _bake() -> void:
	_baked_mat = ShaderMaterial.new()
	_baked_mat.shader = preload("res://shaders/scout.gdshader")
	_baked_mat.set_shader_parameter("use_vertex_color", true)
	var skip := {}
	for v in _face.values():
		skip[v] = true
	var nodes: Array = [_upper, _pack]
	for a in _arms:
		nodes.append_array(a)
	for l in _legs:
		nodes.append_array(l)
	nodes.append_array(_hats)
	for node: Node3D in nodes:
		var parts: Array[MeshInstance3D] = []
		for c in node.get_children():
			if c is MeshInstance3D and not skip.has(c) and not (c.get_meta("role", "") in NO_BAKE):
				parts.append(c)
		if parts.size() < 2:
			continue
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var idx := PackedInt32Array()
		var roles := PackedStringArray()
		for mi in parts:
			var arr := mi.mesh.surface_get_arrays(0)
			var xf := mi.transform
			var base := verts.size()
			for v in arr[Mesh.ARRAY_VERTEX]:
				verts.append(xf * v)
			for n in arr[Mesh.ARRAY_NORMAL]:
				norms.append((xf.basis * n).normalized())
			for i in arr[Mesh.ARRAY_INDEX]:
				idx.append(base + i)
			var role: String = mi.get_meta("role")
			for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				roles.append(role)
			_meshes.erase(mi)
			node.remove_child(mi)
			mi.free()
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = ArrayMesh.new()
		merged.material_override = _baked_mat
		node.add_child(merged)
		_meshes.append(merged)
		_baked.append([merged, verts, norms, idx, roles])


func _recolor() -> void:
	for b in _baked:
		var roles: PackedStringArray = b[4]
		var cache := {}
		var cols := PackedColorArray()
		cols.resize(roles.size())
		for i in roles.size():
			var r: String = roles[i]
			if not cache.has(r):
				var m := _mat(r) as ShaderMaterial
				var c: Color = (m.get_shader_parameter("color") as Color).srgb_to_linear()
				c.a = 0.0 if r in GLOSSY else (0.5 if r in CLOTH else 1.0)
				cache[r] = c
			cols[i] = cache[r]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b[1]
		arr[Mesh.ARRAY_NORMAL] = b[2]
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = b[3]
		var mesh := b[0].mesh as ArrayMesh
		mesh.clear_surfaces()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


# ================================================================ Geometry helpers

## Radius of the bean body at height y
static func body_r(y: float) -> float:
	var t := clampf((y - BODY_Y0) / BODY_H, 0.0, 1.0)
	var big := lerpf(0.31, 0.272, smoothstep(0.25, 0.9, t))
	return big * pow(maxf(1.0 - pow(absf(2.0 * t - 1.0), 2.6), 0.0), 1.0 / 2.6)


## Point on the body surface at height y and angle th (0 = front, positive towards +X): [position, normal]
static func body_point(y: float, th: float, off := 0.0) -> Array:
	var r := body_r(y)
	var e := 0.004
	var dr := (body_r(y + e) - body_r(y - e)) / (2.0 * e)
	var n2 := Vector2(1.0, -dr).normalized()
	var n := Vector3(n2.x * sin(th), n2.y, -n2.x * cos(th) / BODY_DZ).normalized()
	return [Vector3(r * sin(th), y, -r * cos(th) * BODY_DZ) + n * off, n]


## Local frame on the surface: +Z along the normal, +Y roughly up
static func _frame(p: Vector3, n: Vector3) -> Transform3D:
	var x := Vector3.UP.cross(n).normalized()
	var y := n.cross(x)
	return Transform3D(Basis(x, y, n), p)


## Frame with +Y along the normal (for lathe discs)
static func _frame_up(p: Vector3, n: Vector3) -> Transform3D:
	var x := Vector3.UP.cross(n).normalized()
	var z := x.cross(n)
	return Transform3D(Basis(x, n, z), p)


## Profile of a shell around the body between two height fractions
func _shell(t0: float, t1: float, off: float) -> Array:
	var prof := []
	for i in 29:
		var u := i / 28.0
		# dense near the bottom pole
		var t := t1 * (1.0 - cos(PI * 0.5 * u)) if t0 <= 0.0 else lerpf(t0, t1, u)
		var y := BODY_Y0 + t * BODY_H
		var r := body_r(y)
		var e := 0.004
		var dr := (body_r(y + e) - body_r(y - e)) / (2.0 * e)
		var n2 := Vector2(1.0, -dr).normalized()
		if t <= 0.0005:
			n2 = Vector2(0, -1)
		prof.append(Vector2(r, y) + n2 * off)
	prof[0].x = 0.0
	return prof


func _ring(y: float, off: float, n: int) -> Array:
	var pts := []
	for i in n + 1:
		var p: Array = body_point(y, TAU * i / n, off)
		pts.append(p[0])
	return pts


func _ring_normals(y: float, n: int) -> Array:
	var ns := []
	for i in n + 1:
		var p: Array = body_point(y, TAU * i / n, 0.0)
		ns.append(p[1])
	return ns


## Arc from -w to w; bump > 0 bends upwards in the middle
static func _arc(w: float, bump: float, _eye: bool) -> Array:
	var pts := []
	for i in 9:
		var u := i / 8.0 * 2.0 - 1.0
		pts.append(Vector2(u * w, bump * (1.0 - u * u)))
	return pts


## A curve drawn on the face (eyes, mouths), following the body surface
func _face_curve(node_name: String, y0: float, th0: float, pts2d: Array, rad: float) -> MeshInstance3D:
	var pts := []
	var nrm := []
	for q in pts2d:
		var y: float = y0 + q.y
		var p: Array = body_point(y, th0 + q.x / body_r(y), rad * 0.3)
		pts.append(p[0])
		nrm.append(p[1])
	var role := "mouth" if node_name in ["Smile", "Flat", "Wavy"] else "eye"
	return _add(_upper, Mesh3.tube(pts, rad, 8, nrm, 0.7), role, node_name)


# ================================================================ Animation

func _spring(key: String, target: float, delta: float, k := 140.0, d := 13.0) -> float:
	var s: Vector2 = _springs.get(key, Vector2(target, 0.0))
	# semi-implicit Euler in small steps: stays stable at low frame rates
	var steps := ceili(delta / 0.008)
	var h := delta / maxf(steps, 1)
	for i in steps:
		s.y += ((target - s.x) * k - s.y * d) * h
		s.x += s.y * h
	_springs[key] = s
	return s.x


func _process(delta: float) -> void:
	animate(minf(delta, 0.05))


func animate(delta: float) -> void:
	_t += delta
	var moving := pose == Pose.STAND and on_floor
	_amp = lerpf(_amp, clampf(speed / 3.4, 0.0, 1.5) if moving else 0.0, 1.0 - exp(-8.0 * delta))
	var a := _amp
	_phase += delta * speed * TAU / (1.5 if sprint else 1.25)
	var s := sin(_phase)
	var c := cos(_phase)
	var breathe := sin(_t * 1.7)
	_wave_t = maxf(_wave_t - delta, 0.0)

	var rig_pos := Vector3(0, absf(c) * 0.045 * a - 0.02 * a, 0)
	var rig_rot := Vector3.ZERO
	var hip_rot := Vector3(-0.1 * a - (0.12 if sprint and a > 0.2 else 0.0), s * 0.12 * a, s * 0.05 * a - turn_rate * 0.06 * a)
	var leg := [[s * 0.62 * a, -maxf(0.0, c) * 0.95 * a], [-s * 0.62 * a, -maxf(0.0, -c) * 0.95 * a]]
	var arm := [[-s * 0.6 * a + 0.05, -0.14 - 0.05 * a - turn_rate * 0.12, 0.25 + 0.35 * a],
		[s * 0.6 * a + 0.05, 0.14 + 0.05 * a - turn_rate * 0.12, 0.25 + 0.35 * a]]
	if sprint and a > 0.2:
		arm[0][2] += 0.5
		arm[1][2] += 0.5
	var squash := 1.0 + breathe * 0.012 * (1.0 - minf(a, 1.0))

	match pose:
		Pose.CROUCH:
			rig_pos.y -= 0.17
			hip_rot.x = -0.38
			leg = [[1.1 + s * 0.25 * a, -1.6], [1.1 - s * 0.25 * a, -1.6]]
			arm = [[0.55 - s * 0.3 * a, -0.25, 0.6], [0.55 + s * 0.3 * a, 0.25, 0.6]]
		Pose.SIT:
			rig_pos = Vector3(0, -0.37, 0.05)
			hip_rot = Vector3(0.1, 0, 0)
			leg = [[1.35, -0.55], [1.25, -0.45]]
			arm = [[0.3, -0.45, 0.25], [0.3, 0.45, 0.25]]
		Pose.LIE:
			rig_pos = Vector3(0.9, 0.3, 0)
			rig_rot = Vector3(0, 0, 1.45)
			hip_rot = Vector3(0.1, 0, 0)
			leg = [[0.5, -0.8], [0.25, -0.5]]
			arm = [[0.6, -0.2, 0.5], [-0.2, 0.9, 0.3]]
			squash = 1.0 + breathe * 0.02
		Pose.SWIM:
			rig_pos.y = 0.12
			hip_rot = Vector3(-0.55, 0, 0)
			var pa := _t * 3.6
			arm = [[1.6 + sin(pa) * 0.9, -0.5, 0.4], [1.6 + sin(pa + PI) * 0.9, 0.5, 0.4]]
			leg = [[sin(_t * 7.0) * 0.35, -0.3], [-sin(_t * 7.0) * 0.35, -0.3]]
		Pose.CLIMB:
			var ca := _t * 5.0
			arm = [[2.75 + sin(ca) * 0.2, -0.2, 0.6], [2.75 - sin(ca) * 0.2, 0.2, 0.6]]
			leg = [[0.5 + sin(ca) * 0.3, -0.8], [0.5 - sin(ca) * 0.3, -0.8]]
		_:
			if not on_floor:
				# PEAK-style flailing when airborne
				var fa := _t * 16.0
				arm = [[2.3 + sin(fa) * 0.35, -0.7, 0.3], [2.3 + sin(fa + 2.0) * 0.35, 0.7, 0.3]]
				leg = [[sin(_t * 11.0) * 0.4, -0.4], [-sin(_t * 11.0) * 0.4, -0.4]]
				hip_rot.x = 0.1
	var waving_now := waving or _wave_t > 0.0
	if waving_now and pose == Pose.STAND and on_floor:
		arm[1] = [0.35, 2.55, 0.0]

	# rig and torso (lying poses are eased, not sprung)
	rig.position = rig.position.lerp(rig_pos, 1.0 - exp(-10.0 * delta))
	rig.rotation = rig.rotation.lerp(rig_rot, 1.0 - exp(-6.0 * delta))
	hips.rotation = Vector3(_spring("hx", hip_rot.x, delta, 90.0, 14.0), _spring("hy", hip_rot.y, delta, 90.0, 14.0), _spring("hz", hip_rot.z, delta, 90.0, 12.0))
	hips.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))
	for i in 2:
		var lg: Array = _legs[i]
		var hx := _spring("lx%d" % i, leg[i][0], delta, 260.0, 26.0)
		var kx := _spring("kx%d" % i, leg[i][1], delta, 260.0, 26.0)
		lg[0].rotation = Vector3(hx, 0, 0)
		lg[1].rotation = Vector3(kx, 0, 0)
		# keep the soles roughly level
		lg[2].rotation = Vector3(-(hx + kx) * (0.8 if pose != Pose.LIE else 0.3), 0, 0)
		lg[0].position.y = HIP_Y + (maxf(0.0, c if i == 0 else -c) * 0.03 * a if moving else 0.0)
	for i in 2:
		var am: Array = _arms[i]
		# floppy noodle arms: soft springs, the elbow lags behind the shoulder
		var sx := _spring("ax%d" % i, arm[i][0], delta, 120.0, 9.0)
		var sz := _spring("az%d" % i, arm[i][1], delta, 110.0, 8.0)
		var ex := _spring("ex%d" % i, arm[i][2], delta, 90.0, 7.0)
		am[0].rotation = Vector3(sx, 0, sz)
		var wave_z := sin(_t * 10.0) * 0.55 if waving_now and i == 1 and pose == Pose.STAND else 0.0
		am[1].rotation = Vector3(ex, 0, _spring("ez%d" % i, wave_z, delta, 160.0, 10.0))
		am[2].rotation = Vector3(ex * 0.3, 0, 0)
	# backpack and hat bounce along
	var bounce := rig.position.y - rig_pos.y + absf(c) * 0.04 * a
	_pack.rotation.x = _spring("pack", 0.05 * a + bounce * 1.6, delta, 70.0, 5.0)
	_pack.rotation.z = _spring("packz", -hip_rot.z * 0.6, delta, 70.0, 5.0)
	_hat_pivot.rotation.x = _spring("hat", -0.04 * a - bounce * 0.9, delta, 120.0, 6.0)
	_hat_pivot.rotation.z = _spring("hatz", s * 0.03 * a + turn_rate * 0.03, delta, 120.0, 6.0)
	_update_face(delta, waving_now)


func _update_face(delta: float, waving_now: bool) -> void:
	var m := mood
	if waving_now and m == Mood.NORMAL:
		m = Mood.JOY
	var eyes := "oval"
	var mouth := "smile"
	var lid := false
	match int(look["face"]):
		1:
			eyes = "happy"
			mouth = "grin"
		2:
			lid = true
		3:
			mouth = "o"
	match m:
		Mood.TIRED:
			eyes = "oval"
			lid = true
			mouth = "wavy"
		Mood.KNOCKED_OUT:
			eyes = "x"
			mouth = "o"
		Mood.ASLEEP:
			eyes = "closed"
			mouth = "flat"
		Mood.JOY:
			eyes = "happy"
			mouth = "grin"
	var big := int(look["face"]) == 3 and m == Mood.NORMAL
	var state := "%s/%s/%s/%s/%s" % [eyes, mouth, lid, big, _shadow_only]
	if state != _face_state:
		_face_state = state
		# first person: the face casts no shadow and must not show up in front of the camera
		var show := not _shadow_only
		for s in ["L", "R"]:
			var eye: Node3D = _face["eye" + s]
			eye.visible = show and eyes == "oval"
			(_face["lid" + s] as Node3D).visible = lid
			(_face["happy" + s] as Node3D).visible = show and eyes == "happy"
			(_face["closed" + s] as Node3D).visible = show and eyes == "closed"
			(_face["x" + s] as Node3D).visible = show and eyes == "x"
		for k in ["smile", "grin", "flat", "wavy", "o"]:
			(_face[k] as Node3D).visible = show and k == mouth
	# blinking and glancing around
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(1.8, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.0, 3.5)
		_look_eyes = Vector2(randf_range(-1, 1), randf_range(-0.6, 0.6)) if randf() < 0.6 else Vector2.ZERO
	var sy := 0.12 if _blink > 0.0 else (1.18 if big else 1.0)
	for i in 2:
		var s: String = ["L", "R"][i]
		var eye: Node3D = _face["eye" + s]
		var base: Transform3D = eye.get_meta("rest", eye.transform)
		if not eye.has_meta("rest"):
			eye.set_meta("rest", base)
		var sc := Vector3(1.18 if big else 1.0, _spring("blink%d" % i, sy, delta, 900.0, 50.0), 1.0)
		eye.transform = base.translated_local(Vector3(_look_eyes.x * 0.008, _look_eyes.y * 0.006, 0)).scaled_local(sc)
