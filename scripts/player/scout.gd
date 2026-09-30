class_name Scout
extends Node3D
## The hiker you play, modeled after the scouts of PEAK: a big round head sitting right on the collar,
## a drawn-on face with thick brows, a short-sleeved uniform shirt with pocket and buttons, a merit-badge
## sash, shorts, ribbed socks, chunky boots and a backpack.
## Built from procedural meshes; animated procedurally with springs (walk, run, sneak, sit, lie, swim,
## climb, jump, fall, land, wave, idle fidgets) and a face driven by continuous expression parameters.

const SKIN_COLORS := [
	Color("f5c518"), Color("f08a24"), Color("e8553a"), Color("f07ab8"), Color("8f6ad8"),
	Color("4aa3e8"), Color("3cc7c2"), Color("4cc25a"), Color("a6d63c"), Color("9a6a4b"), Color("f1dcb8"),
]
const OUTFIT_COLORS := [
	Color("d9c08a"), Color("e3b23c"), Color("f2efe6"), Color("8fc6e8"),
	Color("8f9b4a"), Color("e39a4a"), Color("c8483e"), Color("a891d6"),
]
const PANTS_COLORS := [
	Color("5f7d3a"), Color("3d5a8c"), Color("c2a878"), Color("7a5236"),
	Color("5b8fd9"), Color("3f7d3a"), Color("6b6f76"), Color("a8423a"),
]
const ACCENT_COLORS := [
	Color("d1493f"), Color("ec8a34"), Color("f2c53d"), Color("9ccc4a"), Color("4f8f4a"), Color("3aa99c"),
	Color("58a6e0"), Color("3f5fae"), Color("8a62c4"), Color("ec86b0"), Color("8b5a36"), Color("efe2c2"),
]
const HAT_NAMES := ["No hat", "Ranger hat", "Bucket hat", "Beanie", "Cap", "Helmet", "Propeller cap", "Sailor cap"]
const FACE_NAMES := ["Happy", "Bright-eyed", "Chill", "Cheeky", "Determined"]
const EXTRA_NAMES := ["Nothing", "Round glasses", "Eye patch", "Neckerchief", "Glasses & neckerchief"]
const DEFAULT_LOOK := {"skin": 0, "outfit": 0, "pants": 0, "sash": 7, "scarf": 0, "hat": 1, "hat_color": 10, "pack": 1, "face": 0, "extra": 3}

## Emotes (see ScoutEmotes): id -> [name, seconds] (0 = held until you move; sit/lie are resting poses)
const EMOTES := ScoutEmotes.EMOTES
const DEFAULT_WHEEL := ScoutEmotes.DEFAULT_WHEEL

enum Pose { STAND, CROUCH, SIT, LIE, SWIM, CLIMB }
enum Mood { NORMAL, TIRED, KNOCKED_OUT, ASLEEP, JOY, EFFORT, SCARED, COLD }

# Proportions (meters, feet at y = 0, facing -Z)
const HIP_Y := 0.58
const CHEST_Y := 0.78
const NECK_Y := 1.0
const HEAD_C := Vector3(0, 1.29, 0)
const HEAD_R := 0.29
const HEAD_SCALE := Vector3(1.0, 0.95, 0.95)
## Eyes sit a little below the middle of the head (cute: big features low in the face)
const EYE_EL := -0.07
const EYE_AZ := 0.36
const LID_UP := 0.11
const TORSO_DZ := 0.78
const THIGH := 0.235
const SHIN := 0.22
## Ankle above the ground (bottom of the sole) and the sole's heel / toe ends (foot space, -Z forward)
const ANKLE_H := 0.132
const HEEL := Vector3(0, -0.132, 0.085)
const TOE := Vector3(0, -0.132, -0.16)

## A foot touches the ground while walking (footprints, dust, sounds) / landed after a jump or fall
signal stepped(foot: Node3D)
signal landed(fall_speed: float)

## Animation inputs (set by the owner every frame)
var speed := 0.0
var sprint := false
var on_floor := true
var pose := Pose.STAND
var mood := Mood.NORMAL
var waving := false
## Yaw change per second (lean into turns)
var turn_rate := 0.0
## 0..1 how heavy the backpack is
var load := 0.0
## Upward speed (jump / fall)
var vy := 0.0
## Optional point (global) the head turns to, e.g. the camera in the scout editor
var look_target := Vector3.INF
## Voice level 0..1 (lip sync)
var talk := 0.0

var look := DEFAULT_LOOK.duplicate()
## Holds the current pose (studio filmstrips animate by hand)
var frozen := false
## Face parameters forced on top of everything (studio, tests)
var face_override := {}
## true: StandardMaterial3D instead of the toon shader and no merging (for glTF export)
var export_mode := false

var rig: Node3D
var hips: Node3D
var chest: Node3D
var neck: Node3D
var _legs := []      # per side: [hip, knee, foot]
var _arms := []      # per side: [shoulder, elbow, hand]
var _pack: Node3D
var _hat_pivot: Node3D
var _hats: Array[Node3D] = []
var _propeller: Node3D
var _face := {}
var _extras := {}
var _mats := {}
var _meshes: Array[MeshInstance3D] = []
var _shadow_only := false
var _baked: Array = []
var _baked_mat: ShaderMaterial
const FACE_FX := ["star", "heart", "tear", "blush", "blushline", "anger", "ink", "note", "alert", "sleep"]
const NO_BAKE := ["eye", "white", "mouth", "sclera", "tongue", "teeth", "brow", "star", "heart", "tear", "blush", "blushline", "anger", "ink", "note", "alert", "sleep"]
const NO_SHADOW := ["eye", "white", "mouth", "cheek", "sclera", "tongue", "teeth", "brow", "glass", "star", "heart", "tear", "blush", "blushline", "anger", "ink", "note", "alert", "sleep"]

var _t := 0.0
# gait: cycle phase, smoothed world velocity and forward acceleration, the two feet, IK weight, pelvis
var _gait_g := 0.0
var _gait_v := Vector3.ZERO
var _gait_acc := 0.0
var _prev_xf := Transform3D()
var _has_prev := false
var _feet: Array = []
var _feet_ok := false
var _ik_w := 0.0
var _osc_w := 0.0
var _pelvis_h := HIP_Y
var _pelvis_ok := false
var _rig_s := Vector3.ZERO
var _last_rig_y := 0.0
var _step_pending: Array[Node3D] = []
var _amp := 0.0
var _springs := {}
var _blink := 0.0
var _next_blink := 2.0
var _wave_t := 0.0
var _air_t := 0.0
var _fall_v := 0.0
var _land := 0.0
var _idle_t := 0.0
var _fidget := ""
var _fidget_t := 0.0
var _next_fidget := 6.0
var _look := Vector2.ZERO          # head yaw / pitch target from glancing
var _look_timer := 1.5
var _pupil := Vector2.ZERO
var _face_state := ""
var _prop_angle := 0.0
var _emote := ""
var _bubbles: ScoutBubbles
# item action (ScoutActions): kind, time, duration, state
var _action := ""
var _action_t := 0.0
var _action_dur := 0.0
var _action_st := {}
# reactions to the world (ScoutReactions, fed by WorldSense)
var _react := ""
var _react_t := 0.0
var _react_dur := 0.0
var _react_st := {}
var _react_dir := Vector3.ZERO
var _react_cd := {}
var _react_gap := 0.0
## a point in the world the scout pays attention to (global; INF = none) and how much (0..1)
var attention := Vector3.INF
var attention_w := 0.0
var _att_w := 0.0
## what the world is like right now: "rain" 0..1, "mud" 0..1, "glare" 0..1, "cold" 0..1
var world_state := {}
var _breath_t := 2.0
## Carried, held and worn items (see ScoutGear)
var gear: ScoutGear
var _tear_t := 0.0
var _emote_t := 0.0
var _emote_st := {}


func _init(look_in: Dictionary = {}, for_export := false) -> void:
	export_mode = for_export
	name = "Scout"
	set_look_data(look_in)
	_build()
	if not export_mode:
		_bake()
	gear = ScoutGear.new()
	gear.setup(self)
	add_child(gear)
	apply_look()


func set_look_data(d: Dictionary) -> void:
	look = DEFAULT_LOOK.duplicate()
	for k in d:
		if look.has(k):
			look[k] = int(d[k])


static func random_look() -> Dictionary:
	return {
		"skin": randi() % SKIN_COLORS.size(), "outfit": randi() % OUTFIT_COLORS.size(), "pants": randi() % PANTS_COLORS.size(),
		"sash": randi() % ACCENT_COLORS.size(), "scarf": randi() % ACCENT_COLORS.size(), "hat": randi() % HAT_NAMES.size(),
		"hat_color": randi() % ACCENT_COLORS.size(), "pack": randi() % ACCENT_COLORS.size(),
		"face": randi() % FACE_NAMES.size(), "extra": randi() % EXTRA_NAMES.size(),
	}


## First person: only the shadow of the scout is visible (face and glasses are hidden)
func set_shadow_only(on: bool) -> void:
	_shadow_only = on
	for m in _meshes:
		if m.get_meta("role", "") in NO_SHADOW:
			# they cast no shadow anyway: in first person they would float in front of the camera
			m.set_layer_mask_value(1, not on)
			continue
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_face_state = ""


func wave(duration := 2.2) -> void:
	_wave_t = duration


## Plays an emote (body movement + face); sit/lie are handled by the owner as resting poses
func play_emote(id: String) -> void:
	if not EMOTES.has(id):
		return
	_emote = id
	_emote_t = 0.0
	_emote_st = {}
	if id == "wave":
		_wave_t = EMOTES[id][1]
	elif id == "yawn":
		fidget("stretch")


## Something done with an item (see ScoutActions.KINDS); item: what shows in the hand ("" = the action's own)
func play_action(kind: String, item := "", dur := -1.0) -> void:
	if not ScoutActions.KINDS.has(kind):
		return
	_action = kind
	_action_t = 0.0
	_action_dur = dur if dur >= 0.0 else ScoutActions.duration(kind)
	_action_st = {}
	var show: String = ScoutActions.KINDS[kind][1] if item == "" else item
	if gear:
		gear.show_temp(show)


func stop_action() -> void:
	if _action == "":
		return
	_action = ""
	if gear:
		gear.end_temp()


func action_playing() -> String:
	return _action


## A reaction to the world (see ScoutReactions.KINDS); dir: world direction it is about. Returns false when
## it can't play now (cooling down, busy, or not standing still for a full-body one).
func react(kind: String, dir := Vector3.ZERO, force := false) -> bool:
	if not ScoutReactions.KINDS.has(kind):
		return false
	if not force:
		if _react != "" or _emote != "" or _action != "" or _react_gap > 0.0 or _react_cd.get(kind, 0.0) > 0.0:
			return false
		if not pose in [Pose.STAND, Pose.SIT, Pose.CROUCH] or not on_floor:
			return false
		if ScoutReactions.full_body(kind) and (speed > 0.4 or pose == Pose.CROUCH):
			return false
	_react = kind
	_react_t = 0.0
	_react_dur = ScoutReactions.duration(kind)
	_react_st = {}
	_react_dir = dir
	_react_cd[kind] = ScoutReactions.KINDS[kind][2]
	_react_gap = 6.0
	return true


func reaction_playing() -> String:
	return _react


## A symbol above the head (see ScoutBubbles.KINDS)
func bubble(kind: String, dur := 1.6, side := 0.0, big := 1.0) -> void:
	if _bubbles and not _shadow_only:
		_bubbles.pop(kind, dur, side, big)


func stop_emote() -> void:
	_emote = ""
	_wave_t = 0.0
	if _fidget == "stretch":
		_fidget = ""


## Id of the emote that is playing ("" if none)
func emote_playing() -> String:
	return _emote


## Idle gestures and how long they take
const FIDGETS := {"stretch": 2.2, "look": 2.2, "straps": 2.2, "scratch": 2.2, "tap": 2.2, "hum": 3.4, "rock": 2.6}

## Plays an idle gesture right away (a key of FIDGETS; empty = random)
func fidget(which := "") -> void:
	var all := FIDGETS.keys()
	_fidget = which if which != "" else all[randi() % all.size()]
	_fidget_t = 0.0


# ================================================================ Colors

## Clothes worn from the backpack (ScoutGear) override the editor look: hat, scarf, gloves, jacket
var wear := {}
var wear_ids := {}


func set_wear(w: Dictionary) -> void:
	if w == wear:
		return
	wear = w
	apply_look()


func apply_look() -> void:
	var skin: Color = SKIN_COLORS[look["skin"] % SKIN_COLORS.size()]
	var outfit: Color = wear.get("outfit_rgb", OUTFIT_COLORS[look["outfit"] % OUTFIT_COLORS.size()])
	var pants: Color = PANTS_COLORS[look["pants"] % PANTS_COLORS.size()]
	var hat: Color = wear.get("hat_rgb", ACCENT_COLORS[look["hat_color"] % ACCENT_COLORS.size()])
	var pack: Color = ACCENT_COLORS[look["pack"] % ACCENT_COLORS.size()]
	_set_color("skin", skin)
	_set_color("hand", wear.get("hand_rgb", skin))
	_set_color("cheek", skin.lerp(Color("ff5f86"), 0.5))
	_set_color("outfit", outfit)
	_set_color("collar", outfit.darkened(0.12) if outfit.get_luminance() > 0.5 else outfit.lightened(0.18))
	_set_color("pants", pants)
	_set_color("sash", ACCENT_COLORS[look["sash"] % ACCENT_COLORS.size()])
	_set_color("scarf", wear.get("scarf_rgb", ACCENT_COLORS[look["scarf"] % ACCENT_COLORS.size()]))
	_set_color("hat", hat)
	_set_color("hatband", hat.darkened(0.45) if hat.get_luminance() > 0.25 else hat.lightened(0.5))
	_set_color("pack", pack)
	_set_color("pack2", pack.darkened(0.25))
	_set_color("pad", Color("5b86b5") if pack.b < pack.r else Color("d9824a"))
	var hat_i: int = wear.get("hat", look["hat"] % HAT_NAMES.size())
	for i in _hats.size():
		_hats[i].visible = i == hat_i
	var ex: int = look["extra"] % EXTRA_NAMES.size()
	_extras["glasses"].visible = ex == 1 or ex == 4
	_extras["patch"].visible = ex == 2
	_extras["scarf"].visible = ex == 3 or ex == 4 or wear.has("scarf_rgb")
	_face_state = ""
	_recolor()


func _set_color(role: String, c: Color) -> void:
	var m = _mat(role)
	if m is ShaderMaterial:
		m.set_shader_parameter("color", c)
	else:
		m.albedo_color = c


const FIXED := {
	"leather": Color("6b4428"), "sole": Color("e9dcc0"), "metal": Color("9fb6c4"), "eye": Color("1b1820"),
	"white": Color(1, 1, 1), "sclera": Color("fbf7ee"), "sock": Color("f4efe4"), "rope": Color("cdb07a"),
	"mouth": Color("4a1d28"), "tongue": Color("e0566a"), "teeth": Color("fffaf2"), "brow": Color("1b1820"),
	"badge1": Color("d8453e"), "badge2": Color("f2c230"), "badge3": Color("3d7fd6"), "badge4": Color("3aa99c"),
	"wood": Color("a0703c"), "button": Color("f4efe4"), "glass": Color("1b1820"), "lace": Color("f4efe4"),
	"star": Color("ffd23f"), "heart": Color("ff4f7a"), "tear": Color("8fd3ff"), "blush": Color("ff7a9a"),
	"blushline": Color("d84a6a"), "anger": Color("e8453c"), "ink": Color("2a2230"), "note": Color("5b8fd9"),
	"alert": Color("ffb02e"), "sleep": Color("8fb4ff"),
}
const GLOSSY := ["eye", "metal", "badge1", "badge2", "badge3", "badge4", "button", "glass", "tear", "heart", "star"]
const CLOTH := ["outfit", "pants", "scarf", "sash", "hat", "pack", "pack2", "pad", "sock", "collar"]


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
		if role in ["white", "sclera", "teeth"]:
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m = sm
	else:
		var shm := ShaderMaterial.new()
		shm.shader = preload("res://shaders/scout.gdshader")
		shm.set_shader_parameter("color", c)
		shm.set_shader_parameter("gloss", 1.0 if role in GLOSSY else 0.0)
		shm.set_shader_parameter("cloth", 1.0 if role in CLOTH else 0.0)
		shm.set_shader_parameter("emission", {"white": 1.0, "sclera": 0.55, "teeth": 0.5, "star": 0.45, "heart": 0.35, "tear": 0.4,
			"blush": 0.25, "anger": 0.35, "note": 0.3, "alert": 0.4, "sleep": 0.35, "ink": 0.1}.get(role, 0.0))
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


## Pivot at an absolute rest position plus a child "space" node in which children use absolute coordinates
func _pivot(parent_space: Node3D, node_name: String, abs_pos: Vector3) -> Array:
	var p := _node(parent_space, node_name, abs_pos)
	var space := _node(p, node_name + "Space", -abs_pos)
	return [p, space]


func _build() -> void:
	rig = _node(self, "Rig")
	var h: Array = _pivot(rig, "Hips", Vector3(0, HIP_Y, 0))
	hips = h[0]
	var hip_space: Node3D = h[1]
	var c: Array = _pivot(hip_space, "Chest", Vector3(0, CHEST_Y, 0))
	chest = c[0]
	var chest_space: Node3D = c[1]
	var n: Array = _pivot(chest_space, "Neck", Vector3(0, NECK_Y, 0))
	neck = n[0]
	var head_space: Node3D = n[1]
	_build_shorts(hip_space)
	_build_torso(chest_space)
	_build_head(head_space)
	_build_face(head_space)
	ScoutFaceFx.build(self, head_space)
	_build_hats(head_space)
	_bubbles = ScoutBubbles.new()
	_bubbles.setup(self, neck)
	add_child(_bubbles)

	for side: int in [-1, 1]:
		_build_arm(chest_space, side)
		_build_leg(side)
	_build_pack(chest_space)


# ---------------------------------------------------------------- torso

static func torso_r(y: float) -> float:
	# rounded box-ish trunk: slightly wider at the belly, rounded shoulders on top
	var belly := 0.19 + 0.026 * exp(-pow((y - 0.74) / 0.14, 2.0))
	if y > 0.97:
		var k := clampf((y - 0.97) / 0.08, 0.0, 1.0)
		return belly * sqrt(maxf(1.0 - k * k, 0.0))
	return belly


static func torso_point(y: float, th: float, off := 0.0) -> Array:
	var r := torso_r(y)
	var e := 0.004
	var dr := (torso_r(y + e) - torso_r(y - e)) / (2.0 * e)
	var n2 := Vector2(1.0, -dr).normalized()
	var nrm := Vector3(n2.x * sin(th), n2.y, -n2.x * cos(th) / TORSO_DZ).normalized()
	return [Vector3(r * sin(th), y, -r * cos(th) * TORSO_DZ) + nrm * off, nrm]


func _build_torso(space: Node3D) -> void:
	# shirt = the trunk itself
	var prof := [Vector2(0.0, 0.64), Vector2(0.17, 0.642)]
	for i in 31:
		var y := lerpf(0.645, 1.049, i / 30.0)
		prof.append(Vector2(torso_r(y), y))
	prof.append(Vector2(0.0, 1.05))
	_add(space, Mesh3.lathe(prof, 48, TORSO_DZ), "outfit", "Shirt")
	# hem where the shirt meets the shorts
	var hem := []
	for i in 49:
		var p: Array = torso_point(0.665, TAU * i / 48.0, 0.008)
		hem.append(p[0])
	_add(space, Mesh3.tube(hem, 0.014, 6, [], 1.0, false), "outfit", "Hem")
	# breast pocket with flap (wearer's left = -X)
	var pp: Array = torso_point(0.87, -0.5, 0.004)
	var pf := _frame(pp[0], pp[1])
	_add(space, Mesh3.blob(Vector3(0.05, 0.055, 0.012), 4.0, 8, 14, pf), "outfit", "Pocket")
	_add(space, Mesh3.blob(Vector3(0.054, 0.018, 0.016), 4.0, 6, 14, pf.translated_local(Vector3(0, 0.045, 0.004))), "collar", "PocketFlap")
	# collar: a band around the neck and two rounded flaps lying on the chest
	var band := []
	for i in 41:
		var p: Array = torso_point(1.03, TAU * i / 40.0, 0.004)
		band.append(p[0])
	_add(space, Mesh3.tube(band, 0.022, 8, [], 1.0, false), "collar", "CollarBand")
	for side: int in [-1, 1]:
		var cp: Array = torso_point(1.0, 0.2 * side, 0.012)
		var f := _frame(cp[0], cp[1]).rotated_local(Vector3(0, 0, 1), -0.55 * side)
		_add(space, Mesh3.blob(Vector3(0.05, 0.075, 0.01), 2.6, 8, 14, f.translated_local(Vector3(0, -0.035, 0))), "collar", "Collar" + ("L" if side < 0 else "R"))
	# merit-badge sash from the right shoulder to the left hip, around the back
	var sash := []
	var sash_n := []
	for i in 65:
		var th := TAU * i / 64.0 - PI
		var y := 0.83 + 0.15 * sin(th)
		var p: Array = torso_point(y, th, 0.016)
		sash.append(p[0])
		sash_n.append(p[1])
	_add(space, Mesh3.tube(sash, 0.045, 8, sash_n, 0.24, false), "sash", "Sash")
	var bi := 1
	for th: float in [-0.8, -0.35, 0.1]:
		var y: float = 0.83 + 0.15 * sin(th)
		var p: Array = torso_point(y, th, 0.026)
		var disc := [Vector2(0, -0.005), Vector2(0.021, -0.005), Vector2(0.025, 0.0), Vector2(0.021, 0.005), Vector2(0, 0.006)]
		_add(space, Mesh3.lathe(disc, 14, 1.0, _frame_up(p[0], p[1])), "badge%d" % bi, "Badge%d" % bi)
		bi += 1
	# backpack straps over the shoulders
	for side: int in [-1, 1]:
		var ctrl := [Vector2(0.62, 0.72), Vector2(0.6, 0.86), Vector2(0.62, 0.99), Vector2(0.9, 1.045), Vector2(1.9, 1.045), Vector2(2.45, 0.98), Vector2(2.6, 0.9)]
		var pts := []
		var nrm := []
		for q in Mesh3.catmull(ctrl, 5):
			var p: Array = torso_point(q.y, q.x * side, 0.03)
			pts.append(p[0])
			nrm.append(p[1])
		_add(space, Mesh3.tube(pts, 0.022, 8, nrm, 0.3), "pack2", "Strap")
	# neckerchief (optional extra): rolled band + triangle over the collar
	var scarf := _node(space, "Neckerchief")
	var roll := []
	var roll_n := []
	for i in 41:
		var p: Array = torso_point(1.035, TAU * i / 40.0, 0.03)
		roll.append(p[0])
		roll_n.append(p[1])
	_add(scarf, Mesh3.tube(roll, 0.028, 10, roll_n, 0.75, false), "scarf")
	var flap := []
	var flap_n := []
	var flap_r := []
	for i in 9:
		var f := i / 8.0
		var p: Array = torso_point(1.02 - f * 0.16, 0.0, 0.03 + (1.0 - f) * 0.01)
		flap.append(p[0])
		flap_n.append(p[1])
		flap_r.append(lerpf(0.085, 0.012, pow(f, 0.8)))
	_add(scarf, Mesh3.tube(flap, flap_r, 10, flap_n, 0.22), "scarf")
	var kp: Array = torso_point(1.0, 0.0, 0.05)
	_add(scarf, Mesh3.blob(Vector3(0.03, 0.026, 0.022), 2.0, 8, 12, _frame(kp[0], kp[1])), "scarf")
	_extras["scarf"] = scarf


func _build_shorts(space: Node3D) -> void:
	var dz := TORSO_DZ + 0.04
	var prof := [Vector2(0.0, 0.525), Vector2(0.09, 0.528), Vector2(0.155, 0.545), Vector2(0.195, 0.585), Vector2(0.212, 0.635), Vector2(0.214, 0.69), Vector2(0.205, 0.702), Vector2(0.0, 0.704)]
	_add(space, Mesh3.lathe(prof, 40, dz), "pants", "Shorts")
	var belt := []
	var belt_n := []
	for i in 49:
		var th := TAU * i / 48.0
		belt.append(Vector3(0.214 * sin(th), 0.675, -0.214 * cos(th) * dz))
		belt_n.append(Vector3(sin(th), 0, -cos(th) / dz).normalized())
	_add(space, Mesh3.tube(belt, 0.024, 8, belt_n, 0.4, false), "leather", "Belt")
	_add(space, Mesh3.blob(Vector3(0.03, 0.024, 0.01), 3.0, 6, 12, Transform3D(Basis(), Vector3(0, 0.675, -0.183))), "metal", "Buckle")


# ---------------------------------------------------------------- head and face

static func head_point(el: float, az: float, off := 0.0) -> Array:
	var d := Vector3(cos(el) * sin(az), sin(el), -cos(el) * cos(az))
	var p := HEAD_C + d * HEAD_R * HEAD_SCALE
	var nrm := (d / HEAD_SCALE).normalized()
	return [p + nrm * off, nrm]


static func head_r(y: float) -> float:
	var k := (y - HEAD_C.y) / (HEAD_R * HEAD_SCALE.y)
	return HEAD_R * sqrt(maxf(1.0 - k * k, 0.0))


func _build_head(space: Node3D) -> void:
	var prof := []
	for i in 33:
		var a := -PI * 0.5 + PI * i / 32.0
		prof.append(Vector2(cos(a) * HEAD_R, HEAD_C.y + sin(a) * HEAD_R * HEAD_SCALE.y))
	_add(space, Mesh3.lathe(prof, 48, HEAD_SCALE.z), "skin", "Head")
	for side: int in [-1, 1]:
		var cp: Array = head_point(-0.22, 0.6 * side, -0.002)
		_add(space, Mesh3.blob(Vector3(0.048, 0.03, 0.01), 2.0, 6, 12, _frame(cp[0], cp[1])), "cheek", "Cheek")


## A face feature pivot on the head surface: +Z out of the face, +Y up
func _face_pivot(space: Node3D, node_name: String, el: float, az: float, off := 0.0) -> Node3D:
	var p: Array = head_point(el, az, off)
	var n := Node3D.new()
	n.name = node_name
	n.transform = _frame(p[0], p[1])
	space.add_child(n)
	n.set_meta("rest", n.transform)
	return n


func _build_face(space: Node3D) -> void:
	for side: int in [-1, 1]:
		var s := "L" if side < 0 else "R"
		var eye := _face_pivot(space, "Eye" + s, EYE_EL, EYE_AZ * side, -0.003)
		_face["eye" + s] = eye
		# drawn eye: dark outline, white sclera, pupil with two sparkles
		_face["outline" + s] = _add(eye, Mesh3.blob(Vector3(0.051, 0.06, 0.012), 2.0, 10, 18), "eye", "Outline" + s)
		var sclera := _add(eye, Mesh3.blob(Vector3(0.044, 0.053, 0.014), 2.0, 10, 18), "sclera", "Sclera" + s)
		sclera.position.z = 0.002
		_face["sclera" + s] = sclera
		var pupil := _node(eye, "Pupil" + s, Vector3(0, 0, 0.012))
		_add(pupil, Mesh3.blob(Vector3(0.024, 0.031, 0.008), 2.0, 8, 14), "eye", "PupilDot" + s)
		var hl := _add(pupil, Mesh3.blob(Vector3(0.0085, 0.0095, 0.005), 2.0, 5, 8), "white", "Shine" + s)
		hl.position = Vector3(-0.008, 0.011, 0.006)
		var hl2 := _add(pupil, Mesh3.blob(Vector3(0.0038, 0.0038, 0.004), 2.0, 4, 6), "white", "Sparkle" + s)
		hl2.position = Vector3(0.009, -0.012, 0.006)
		_face["pupil" + s] = pupil
		# eyelid: skin cap sliding down over the eye
		var lid := _add(eye, Mesh3.blob(Vector3(0.06, 0.054, 0.02), 2.0, 8, 14), "skin", "Lid" + s)
		lid.position = Vector3(0, LID_UP, 0.006)
		_face["lid" + s] = lid
		# alternative eyes
		_face["happy" + s] = _curve(eye, "Happy" + s, _arc(0.036, 0.03), 0.011, "eye")
		_face["closed" + s] = _curve(eye, "Closed" + s, _arc(0.034, -0.016), 0.009, "eye")
		var x := _curve(eye, "X" + s, [Vector3(-0.03, 0.03, 0.01), Vector3(0.03, -0.03, 0.01)], 0.01, "eye")
		_curve(x, "X2" + s, [Vector3(-0.03, -0.03, 0.01), Vector3(0.03, 0.03, 0.01)], 0.01, "eye")
		_face["x" + s] = x
		# eyebrow
		var brow := _face_pivot(space, "Brow" + s, EYE_EL + 0.235, (EYE_AZ - 0.01) * side, 0.0)
		_curve(brow, "BrowLine" + s, _arc(0.044, 0.012), 0.015, "brow", 0.55)
		_face["brow" + s] = brow
	# mouth
	var mouth := _face_pivot(space, "Mouth", -0.29, 0.0, -0.002)
	_face["mouth"] = mouth
	_face["smile"] = _curve(mouth, "Smile", _arc(0.033, -0.016), 0.0085, "mouth")
	_face["flat"] = _curve(mouth, "Flat", [Vector3(-0.025, 0, 0.004), Vector3(0.025, 0, 0.004)], 0.008, "mouth")
	var wavy := []
	for i in 9:
		var u := i / 8.0
		wavy.append(Vector3(lerpf(-0.034, 0.034, u), sin(u * TAU) * 0.007, 0.004))
	_face["wavy"] = _curve(mouth, "Wavy", wavy, 0.007, "mouth")
	# open mouth: dark D-shape with tongue and upper teeth; scaled for talking, panting, screaming
	var open := _node(mouth, "Open")
	_add(open, Mesh3.blob(Vector3(0.042, 0.03, 0.01), 2.2, 8, 16, Transform3D(Basis(), Vector3(0, -0.012, 0.002))), "mouth")
	_add(open, Mesh3.blob(Vector3(0.024, 0.012, 0.006), 2.0, 6, 10, Transform3D(Basis(), Vector3(0, -0.03, 0.008))), "tongue")
	_add(open, Mesh3.blob(Vector3(0.034, 0.008, 0.005), 3.0, 4, 10, Transform3D(Basis(), Vector3(0, 0.01, 0.009))), "teeth")
	_face["open"] = open
	# gritted teeth
	var teeth := _node(mouth, "Teeth")
	_add(teeth, Mesh3.blob(Vector3(0.042, 0.018, 0.008), 4.0, 6, 14, Transform3D(Basis(), Vector3(0, -0.006, 0.003))), "teeth")
	for x: float in [-0.021, 0.0, 0.021]:
		_curve(teeth, "Gap", [Vector3(x, -0.02, 0.011), Vector3(x, 0.008, 0.011)], 0.003, "mouth")
	_curve(teeth, "Mid", [Vector3(-0.04, -0.006, 0.011), Vector3(0.04, -0.006, 0.011)], 0.003, "mouth")
	_face["teeth"] = teeth
	# cheeky: smile with the tongue sticking out
	var cheeky := _node(mouth, "Cheeky")
	_curve(cheeky, "CheekySmile", _arc(0.04, -0.016), 0.009, "mouth")
	_add(cheeky, Mesh3.blob(Vector3(0.016, 0.022, 0.008), 2.0, 6, 10, Transform3D(Basis(), Vector3(0.012, -0.026, 0.008))), "tongue")
	_face["cheeky"] = cheeky
	# extras: round glasses, eye patch
	var glasses := _node(space, "Glasses")
	for side: int in [-1, 1]:
		var p: Array = head_point(EYE_EL, EYE_AZ * side, 0.03)
		var f := _frame(p[0], p[1])
		var pts := []
		for i in 25:
			var a := TAU * i / 24.0
			pts.append(f * Vector3(cos(a) * 0.068, sin(a) * 0.068, 0.0))
		_add(glasses, Mesh3.tube(pts, 0.008, 6, [], 1.0, false), "glass")
		var tp: Array = head_point(EYE_EL + 0.03, 1.02 * side, 0.012)
		_add(glasses, Mesh3.tube([f * Vector3(0.068 * side, 0.0, 0.0), tp[0]], 0.006, 5), "glass")
	_add(glasses, Mesh3.tube([head_point(EYE_EL, -0.13, 0.03)[0], head_point(EYE_EL + 0.03, 0.0, 0.04)[0], head_point(EYE_EL, 0.13, 0.03)[0]], 0.007, 5), "glass")
	_extras["glasses"] = glasses
	var patch := _node(space, "EyePatch")
	var pp: Array = head_point(EYE_EL, EYE_AZ, 0.012)
	_add(patch, Mesh3.blob(Vector3(0.06, 0.066, 0.012), 2.4, 8, 14, _frame(pp[0], pp[1])), "glass")
	var strap := []
	for i in 41:
		var a := TAU * i / 40.0
		strap.append(head_point(0.12 * cos(a - EYE_AZ) + 0.02, a, 0.006)[0])
	_add(patch, Mesh3.tube(strap, 0.007, 5, [], 1.0, false), "glass")
	_extras["patch"] = patch


func _curve(parent: Node3D, node_name: String, pts: Array, rad: float, role: String, flat := 0.7) -> MeshInstance3D:
	var ups := []
	for i in pts.size():
		ups.append(Vector3(0, 0, 1))
	return _add(parent, Mesh3.tube(pts, rad, 8, ups, flat), role, node_name)


## Arc from -w to w; bump > 0 bends upwards in the middle
static func _arc(w: float, bump: float) -> Array:
	var pts := []
	for i in 9:
		var u := i / 8.0 * 2.0 - 1.0
		pts.append(Vector3(u * w, bump * (1.0 - u * u), 0.006))
	return pts


# ---------------------------------------------------------------- limbs

func _build_arm(space: Node3D, side: int) -> void:
	var s := "L" if side < 0 else "R"
	var shoulder := _node(space, "Shoulder" + s, Vector3(0.205 * side, 0.965, 0.0))
	_add(shoulder, Mesh3.capsule(0.056, 0.05, 0.2), "skin", "UpperArm" + s)
	# profiles run upwards on the outside (outward normals)
	var sleeve := [Vector2(0.06, -0.128), Vector2(0.072, -0.136), Vector2(0.087, -0.133), Vector2(0.093, -0.122), Vector2(0.092, -0.108),
		Vector2(0.088, -0.09), Vector2(0.086, -0.04), Vector2(0.078, 0.03), Vector2(0.05, 0.078), Vector2(0.0, 0.085)]
	_add(shoulder, Mesh3.lathe(sleeve, 22), "outfit", "Sleeve" + s)
	var elbow := _node(shoulder, "Elbow" + s, Vector3(0, -0.2, 0))
	_add(elbow, Mesh3.capsule(0.05, 0.045, 0.165), "skin", "Forearm" + s)
	var hand := _node(elbow, "Hand" + s, Vector3(0, -0.165, 0))
	_add(hand, Mesh3.blob(Vector3(0.06, 0.066, 0.052), 2.1, 10, 14, Transform3D(Basis(), Vector3(0, -0.05, 0))), "hand", "Mitten" + s)
	_add(hand, Mesh3.blob(Vector3(0.022, 0.034, 0.022), 2.0, 6, 10, Transform3D(Basis(Vector3(0, 0, 1), 0.55 * side), Vector3(0.044 * -side, -0.03, -0.032))), "hand", "Thumb" + s)
	_arms.append([shoulder, elbow, hand])


func _build_leg(side: int) -> void:
	var s := "L" if side < 0 else "R"
	var hip := _node(rig, "Hip" + s, Vector3(0.1 * side, HIP_Y, 0))
	_add(hip, Mesh3.capsule(0.078, 0.07, THIGH), "skin", "Thigh" + s)
	var leg := [Vector2(0.074, -0.145), Vector2(0.096, -0.148), Vector2(0.109, -0.142), Vector2(0.112, -0.13), Vector2(0.108, -0.09), Vector2(0.1, 0.01), Vector2(0.075, 0.07)]
	_add(hip, Mesh3.lathe(leg, 22), "pants", "ShortsLeg" + s)
	var knee := _node(hip, "Knee" + s, Vector3(0, -THIGH, 0))
	_add(knee, Mesh3.capsule(0.07, 0.066, SHIN), "skin", "Shin" + s)
	# ribbed sock
	var sock := []
	for i in 15:
		var y := lerpf(-0.23, -0.07, i / 14.0)
		sock.append(Vector2(0.079 + 0.004 * sin(i * PI * 0.5) * sin(i * PI * 0.5), y))
	sock.append(Vector2(0.08, -0.06))
	sock.append(Vector2(0.072, -0.054))
	_add(knee, Mesh3.lathe(sock, 20), "sock", "Sock" + s)
	var foot := _node(knee, "Foot" + s, Vector3(0, -SHIN, 0))
	_add(foot, Mesh3.blob(Vector3(0.086, 0.075, 0.13), 2.8, 10, 16, Transform3D(Basis(), Vector3(0, -0.05, -0.035))), "leather", "Boot" + s)
	_add(foot, Mesh3.blob(Vector3(0.09, 0.022, 0.135), 3.2, 6, 16, Transform3D(Basis(), Vector3(0, -0.11, -0.035))), "sole", "Sole" + s)
	var cuffp := []
	for i in 21:
		var a := TAU * i / 20.0
		cuffp.append(Vector3(sin(a) * 0.084, 0.012, -cos(a) * 0.088 - 0.01))
	_add(foot, Mesh3.tube(cuffp, 0.02, 6, [], 1.0, false), "leather", "BootCuff" + s)
	for k in 3:
		var z := -0.09 - k * 0.026
		var y := -0.0 - k * 0.02
		_add(foot, Mesh3.tube([Vector3(-0.034, y, z), Vector3(0.034, y, z)], 0.006, 5), "lace", "Lace" + s)
	_legs.append([hip, knee, foot])


func _build_pack(space: Node3D) -> void:
	_pack = _node(space, "Pack", Vector3(0, 0.84, 0.2 * TORSO_DZ))
	_add(_pack, Mesh3.blob(Vector3(0.2, 0.25, 0.13), 3.4, 14, 24, Transform3D(Basis(), Vector3(0, 0.02, 0.15))), "pack", "PackBody")
	_add(_pack, Mesh3.blob(Vector3(0.207, 0.07, 0.142), 3.0, 8, 20, Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(0, 0.25, 0.155))), "pack2", "PackLid")
	_add(_pack, Mesh3.blob(Vector3(0.14, 0.095, 0.048), 3.0, 8, 16, Transform3D(Basis(), Vector3(0, -0.08, 0.285))), "pack2", "PackPocket")
	_add(_pack, Mesh3.blob(Vector3(0.146, 0.032, 0.052), 3.0, 6, 16, Transform3D(Basis(), Vector3(0, 0.005, 0.292))), "pack", "PackFlap")
	_add(_pack, Mesh3.blob(Vector3(0.016, 0.011, 0.008), 2.0, 5, 8, Transform3D(Basis(), Vector3(0, -0.025, 0.343))), "metal", "PackButton")
	var roll := [Vector2(0, -0.25), Vector2(0.065, -0.25), Vector2(0.082, -0.235), Vector2(0.084, 0.0), Vector2(0.082, 0.235), Vector2(0.065, 0.25), Vector2(0, 0.25)]
	_add(_pack, Mesh3.lathe(roll, 20, 1.0, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, 0.37, 0.15))), "pad", "Bedroll")
	for sx: float in [-0.13, 0.13]:
		var band := []
		for i in 21:
			var a := TAU * i / 20.0
			band.append(Vector3(sx, 0.37 + cos(a) * 0.089, 0.15 + sin(a) * 0.089))
		_add(_pack, Mesh3.tube(band, 0.015, 6, [], 0.4, false), "leather", "RollStrap")
	var mug := [Vector2(0, -0.033), Vector2(0.034, -0.033), Vector2(0.038, 0.033), Vector2(0.032, 0.034), Vector2(0.028, -0.018), Vector2(0, -0.018)]
	_add(_pack, Mesh3.lathe(mug, 16, 1.0, Transform3D(Basis(), Vector3(-0.235, 0.0, 0.19))), "metal", "Mug")
	var handle := []
	for i in 13:
		var a := PI * i / 12.0
		handle.append(Vector3(-0.273 - sin(a) * 0.024, cos(a) * 0.023, 0.19))
	_add(_pack, Mesh3.tube(handle, 0.007, 6), "metal", "MugHandle")


# ---------------------------------------------------------------- hats

func _build_hats(space: Node3D) -> void:
	var hy := 1.45
	_hat_pivot = _node(space, "HatPivot", Vector3(0, hy, 0))
	var inner := _node(_hat_pivot, "HatSpace", Vector3(0, -hy, 0))
	var dz := HEAD_SCALE.z
	var rb := head_r(1.44) + 0.012     # radius of the head where hats sit
	_hats.append(_node(inner, "HatNone"))
	# ranger / campaign hat
	var ranger := _node(inner, "HatRanger")
	_add(ranger, Mesh3.lathe([Vector2(rb - 0.02, 1.432), Vector2(0.42, 1.436), Vector2(0.445, 1.45), Vector2(0.432, 1.464), Vector2(rb - 0.01, 1.458)], 44, dz), "hat")
	_add(ranger, Mesh3.lathe([Vector2(rb, 1.43), Vector2(rb - 0.004, 1.55), Vector2(rb - 0.03, 1.64), Vector2(0.14, 1.69), Vector2(0.0, 1.705)], 40, dz), "hat")
	_add(ranger, Mesh3.lathe([Vector2(rb + 0.003, 1.455), Vector2(rb + 0.006, 1.46), Vector2(rb + 0.004, 1.5), Vector2(rb - 0.002, 1.506)], 40, dz), "hatband")
	_hats.append(ranger)
	# bucket hat
	var bucket := _node(inner, "HatBucket")
	_add(bucket, Mesh3.lathe([Vector2(rb + 0.02, 1.41), Vector2(rb + 0.005, 1.54), Vector2(rb - 0.025, 1.62), Vector2(0.14, 1.65), Vector2(0.0, 1.656)], 40, dz), "hat")
	_add(bucket, Mesh3.lathe([Vector2(rb + 0.01, 1.41), Vector2(0.37, 1.35), Vector2(0.385, 1.36), Vector2(0.378, 1.372), Vector2(rb + 0.02, 1.436)], 44, dz), "hat")
	_add(bucket, Mesh3.lathe([Vector2(rb + 0.02, 1.436), Vector2(rb + 0.024, 1.44), Vector2(rb + 0.02, 1.475), Vector2(rb + 0.014, 1.48)], 40, dz), "hatband")
	_hats.append(bucket)
	# beanie with cuff and pompom
	var beanie := _node(inner, "HatBeanie")
	var dome := []
	for i in 17:
		var y := lerpf(1.42, 1.575, i / 16.0)
		dome.append(Vector2(head_r(y) + 0.022, y))
	dome.append(Vector2(0.1, 1.598))
	dome.append(Vector2(0.0, 1.605))
	_add(beanie, Mesh3.lathe(dome, 36, dz), "hat")
	var r0 := head_r(1.42) + 0.03
	_add(beanie, Mesh3.lathe([Vector2(r0 - 0.012, 1.4), Vector2(r0 + 0.012, 1.412), Vector2(r0 + 0.012, 1.475), Vector2(r0 - 0.012, 1.487)], 36, dz), "hatband")
	_add(beanie, Mesh3.blob(Vector3(0.072, 0.068, 0.072), 2.0, 10, 14, Transform3D(Basis(), Vector3(0, 1.65, 0))), "hat")
	_hats.append(beanie)
	# cap with visor
	var cdome := []
	for i in 15:
		var y := lerpf(1.42, 1.565, i / 14.0)
		cdome.append(Vector2(head_r(y) + 0.014, y))
	cdome.append(Vector2(0.08, 1.585))
	cdome.append(Vector2(0.0, 1.59))
	var cap := _node(inner, "HatCap")
	_add(cap, Mesh3.lathe(cdome, 36, dz), "hat")
	_add(cap, Mesh3.blob(Vector3(0.17, 0.012, 0.15), 2.2, 8, 20, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, 1.43, -0.27))), "hatband")
	_add(cap, Mesh3.blob(Vector3(0.024, 0.012, 0.024), 2.0, 5, 8, Transform3D(Basis(), Vector3(0, 1.59, 0))), "hatband")
	_hats.append(cap)
	# helmet: round shell with a brim and a first-aid heart
	var helmet := _node(inner, "HatHelmet")
	var hd := []
	for i in 13:
		var a := PI * 0.5 * i / 12.0
		hd.append(Vector2(cos(a) * (rb + 0.03), 1.42 + sin(a) * 0.2))
	_add(helmet, Mesh3.lathe(hd, 40, dz), "hat")
	_add(helmet, Mesh3.lathe([Vector2(rb + 0.02, 1.415), Vector2(0.36, 1.405), Vector2(0.37, 1.415), Vector2(0.362, 1.428), Vector2(rb + 0.03, 1.43)], 44, dz), "hat")
	var hf := Transform3D(Basis(), Vector3(0, 1.53, -(rb + 0.02) * dz)).rotated_local(Vector3.RIGHT, -0.5)
	_add(helmet, Mesh3.blob(Vector3(0.05, 0.045, 0.012), 2.2, 8, 12, hf), "badge1")
	_add(helmet, Mesh3.blob(Vector3(0.028, 0.009, 0.006), 3.0, 4, 8, hf.translated_local(Vector3(0, 0, 0.012))), "white")
	_add(helmet, Mesh3.blob(Vector3(0.009, 0.028, 0.006), 3.0, 4, 8, hf.translated_local(Vector3(0, 0, 0.012))), "white")
	_hats.append(helmet)
	# propeller cap: four colored panels, a visor and a spinning propeller
	var prop := _node(inner, "HatPropeller")
	_add(prop, Mesh3.lathe(cdome, 36, dz), "hat")
	_add(prop, Mesh3.blob(Vector3(0.16, 0.012, 0.14), 2.2, 8, 20, Transform3D(Basis(Vector3.RIGHT, 0.18), Vector3(0, 1.43, -0.27))), "badge3")
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		var seg := []
		for i in 9:
			var y := lerpf(1.43, 1.575, i / 8.0)
			seg.append(Vector3(sin(a) * (head_r(y) + 0.017), y, -cos(a) * (head_r(y) + 0.017) * dz))
		_add(prop, Mesh3.tube(seg, 0.012, 5), ["badge1", "badge2", "badge3", "badge4"][k])
	_add(prop, Mesh3.lathe([Vector2(0.0, 1.58), Vector2(0.012, 1.585), Vector2(0.012, 1.64), Vector2(0.0, 1.645)], 8), "metal")
	_propeller = _node(prop, "Propeller", Vector3(0, 1.645, 0))
	for k in 2:
		var b := Basis(Vector3.UP, PI * k)
		_add(_propeller, Mesh3.blob(Vector3(0.1, 0.006, 0.026), 2.2, 6, 12, Transform3D(b * Basis(Vector3.RIGHT, 0.3), b * Vector3(0.095, 0, 0))), ["badge1", "badge2"][k])
	_hats.append(prop)
	# sailor cap: white drum with a colored band
	var sailor := _node(inner, "HatSailor")
	_add(sailor, Mesh3.lathe([Vector2(0.0, 1.418), Vector2(rb - 0.01, 1.42), Vector2(rb + 0.01, 1.47), Vector2(rb + 0.035, 1.53), Vector2(rb + 0.03, 1.56), Vector2(0.0, 1.565)], 40, dz), "sock")
	_add(sailor, Mesh3.lathe([Vector2(rb + 0.002, 1.435), Vector2(rb + 0.012, 1.44), Vector2(rb + 0.02, 1.47), Vector2(rb + 0.012, 1.475)], 40, dz), "hat")
	_hats.append(sailor)


# ================================================================ Merging

## Merges the static parts of every animated node into one mesh with vertex colors:
## far fewer draw calls (matters for the shadow cascades in first person).
func _bake() -> void:
	_baked_mat = ShaderMaterial.new()
	_baked_mat.shader = preload("res://shaders/scout.gdshader")
	_baked_mat.set_shader_parameter("use_vertex_color", true)
	var skip := {}
	for v in _face.values():
		skip[v] = true
	var nodes: Array = []
	for n in find_children("*", "Node3D", true, false):
		if not (n is MeshInstance3D):
			nodes.append(n)
	for node: Node3D in nodes:
		# face features stay separate (they switch on and off and move)
		if skip.has(node) or node.get_parent() == _face.get("mouth"):
			continue
		# shadow casters and shadowless parts (cheeks, glasses) are merged separately: a shadowless part must
		# not take the shadow away from the whole head, and in first person only the casters stay (as shadow)
		var groups := {true: [], false: []}
		for c in node.get_children():
			if c is MeshInstance3D and not skip.has(c) and not (c.get_meta("role", "") in NO_BAKE):
				groups[not (c.get_meta("role", "") in NO_SHADOW)].append(c)
		for casts: bool in [true, false]:
			var parts: Array = groups[casts]
			if parts.size() >= 2:
				_merge_parts(node, parts, casts)


func _merge_parts(node: Node3D, parts: Array, casts: bool) -> void:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var roles := PackedStringArray()
	for mi: MeshInstance3D in parts:
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
	merged.name = "Merged" if casts else "MergedNoShadow"
	merged.mesh = ArrayMesh.new()
	merged.material_override = _baked_mat
	merged.set_meta("role", "merged" if casts else "glass")
	if not casts:
		merged.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

## Local frame on a surface: +Z along the normal, +Y roughly up
static func _frame(p: Vector3, n: Vector3) -> Transform3D:
	var x := Vector3.UP.cross(n)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := n.cross(x)
	return Transform3D(Basis(x, y, n), p)


## Frame with +Y along the normal (for lathe discs)
static func _frame_up(p: Vector3, n: Vector3) -> Transform3D:
	var x := Vector3.UP.cross(n).normalized()
	var z := x.cross(n)
	return Transform3D(Basis(x, n, z), p)


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


func _kick(key: String, impulse: float) -> void:
	var s: Vector2 = _springs.get(key, Vector2.ZERO)
	s.y += impulse
	_springs[key] = s


func _process(delta: float) -> void:
	if is_visible_in_tree() and not frozen:
		animate(minf(delta, 0.05))


func animate(delta: float) -> void:
	_t += delta
	var standing := pose == Pose.STAND
	var gxf := global_transform if is_inside_tree() else transform
	_track_motion(gxf, delta)
	var v := Vector2(_gait_v.x, _gait_v.z).length()
	var on_ground := (standing or pose == Pose.CROUCH) and on_floor
	var moving := standing and on_floor
	_amp = lerpf(_amp, clampf(v / 3.4, 0.0, 1.6) if on_ground else 0.0, 1.0 - exp(-8.0 * delta))
	var a := _amp
	var gp := _gait_params(v)
	var run: float = gp["run"]
	var walk: float = gp["walk"]
	var beta: float = gp["beta"]
	# gait phase: 0 = left heel strike, 0.5 = right heel strike
	var ga := TAU * _gait_g
	var s := sin(ga)
	var c := cos(ga)
	# 1 at the middle of each stance (lowest point of a run), -1 in between
	var mid := cos(2.0 * TAU * (_gait_g - beta * 0.5))
	var tired := mood == Mood.TIRED
	var breathe := sin(_t * (1.7 + (2.5 if tired else 0.0)))
	_wave_t = maxf(_wave_t - delta, 0.0)

	# airborne / landing
	if standing and not on_floor:
		_air_t += delta
		_fall_v = maxf(_fall_v, -vy)
	else:
		if _air_t > 0.25:
			_land = clampf(_fall_v * 0.03 + 0.08, 0.08, 0.35)
			_kick("land", _land * 7.0)
			landed.emit(_fall_v)
		_air_t = 0.0
		_fall_v = 0.0
	var land := maxf(_spring("land", 0.0, delta, 120.0, 11.0), 0.0)

	# idle fidgets
	if moving and a < 0.05 and not waving and _wave_t <= 0.0 and _emote == "" and mood in [Mood.NORMAL, Mood.COLD]:
		_idle_t += delta
		_next_fidget -= delta
		if _next_fidget <= 0.0 and _fidget == "":
			fidget()
			_next_fidget = randf_range(7.0, 14.0)
	elif a > 0.2:
		_fidget = ""
	if _fidget != "":
		_fidget_t += delta
		if _fidget_t > float(FIDGETS.get(_fidget, 2.2)):
			_fidget = ""

	# ------------------------------------------------ pose targets
	# walking and running: the legs follow the planted feet (IK below); these are the upper body's targets
	var fwd_acc := clampf(_gait_acc, -8.0, 8.0)
	var lean := -0.035 * minf(v, 3.4) - 0.3 * run - load * 0.12 - (0.1 if tired else 0.0) - clampf(fwd_acc * 0.03, -0.14, 0.18)
	var pyaw := -(0.1 + 0.05 * run) * walk * c
	var rig_pos := Vector3(0, -land * 0.5, 0)
	var rig_rot := Vector3(0, 0, -turn_rate * 0.05 * minf(v / 3.4, 1.4))
	var hip_rot := Vector3(lean * 0.4, 0.0, 0.0)
	var chest_rot := Vector3(lean * 0.6 - (0.1 if tired else 0.0), 0.0, 0.0)
	var head_rot := Vector3(-lean * 0.75 - (0.16 if tired else 0.0) + 0.03 * run * mid, pyaw * 0.8, -turn_rate * 0.04 * minf(v / 3.4, 1.0))
	# the head looks into a turn first
	head_rot.y += clampf(turn_rate * 0.12, -0.35, 0.35)
	var leg := [[land * 0.6, -land * 1.6], [land * 0.6, -land * 1.6]]
	var feet_fx := [Vector2.ZERO, Vector2.ZERO]
	# arms swing against the legs: relaxed while walking, pumping with bent elbows when running
	var arm := []
	var arm_osc := []
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var fw := -cos(ga - 0.2 + PI * i)
		var amp := lerpf(0.08 + 0.45 * minf(v / 3.4, 1.0), 1.0, run) * (0.6 if tired else 1.0)
		arm.append([lerpf(0.04, 0.3, run), side * lerpf(0.13 + 0.05 * a, 0.1, run) + side * land, lerpf(0.22 + 0.3 * minf(a, 1.0), 1.5, run)])
		arm_osc.append([fw * amp, -side * 0.08 * run * maxf(fw, 0.0), (0.35 * walk * (1.0 - run) + 0.35 * run) * maxf(fw, 0.0)])
	# the rhythm of the steps on top of the (spring-smoothed) pose
	var rhythm := {"hy": pyaw, "cy": -pyaw * 1.9, "hz": -s * 0.035 * walk, "cz": s * 0.03 * walk, "cx": 0.03 * run * mid}
	var squash := 1.0 + breathe * 0.012 * (1.0 - minf(a, 1.0)) - land * 0.25 - 0.035 * run * maxf(mid, 0.0) + 0.02 * run * maxf(-mid, 0.0)

	# face targets: brow_r raise (-1 low .. 1 high), brow_a angle (-1 worried .. 1 angry), lid 0..1, mouth, open 0..1
	var face := _face_base()
	var brake := smoothstep(4.0, 9.0, -fwd_acc) * smoothstep(0.8, 2.5, v)
	if brake > 0.0 and pose == Pose.STAND:
		for i in 2:
			arm[i] = [lerpf(arm[i][0], 0.9, brake), lerpf(arm[i][1], (0.35 if i == 1 else -0.35), brake), lerpf(arm[i][2], 0.4, brake)]
		if brake > 0.4:
			face["eyes"] = "wide"
			face["mouth"] = "open"
			face["open"] = 0.6
			face["brow_r"] = 0.9
	if land > 0.18 and pose == Pose.STAND:
		face["eyes"] = "wide"
		face["mouth"] = "open"
		face["open"] = 0.8
		face["brow_r"] = 0.8

	match pose:
		Pose.CROUCH:
			hip_rot.x = -0.25
			chest_rot.x = -0.2
			head_rot = Vector3(0.3, sin(_t * 0.9) * 0.35 * (1.0 - minf(a * 2.0, 1.0)), 0.0)
			leg = [[1.15, -1.7], [1.15, -1.7]]
			arm = [[0.95, -0.28, 1.75], [0.95, 0.28, 1.75]]
			# sneaking on tiptoes
			feet_fx = [Vector2(0.0, -0.3), Vector2(0.0, -0.3)]
			face["brow_a"] = 0.35
			face["mouth"] = "flat"
			face["eyes"] = "sclera"
			_pupil = Vector2(sin(_t * 0.9) * 0.6, -0.1)
		Pose.SIT:
			var asleep := mood == Mood.ASLEEP
			rig_pos = Vector3(0, -0.4, 0.05)
			hip_rot = Vector3(0.22, 0, 0)
			chest_rot = Vector3(-0.3 if asleep else -0.05, 0, sin(_t * 0.4) * 0.03)
			head_rot = Vector3(-0.45 if asleep else -0.08, 0.0 if asleep else sin(_t * 0.3) * 0.2, 0.2 if asleep else 0.0)
			leg = [[1.4, -0.35], [1.25, -0.5]]
			arm = [[-0.55, -0.3, 0.1], [-0.55, 0.3, 0.1]]
			squash = 1.0 + breathe * 0.02
		Pose.LIE:
			rig_pos = Vector3(0.95, 0.14, 0)
			rig_rot = Vector3(0, 0, 1.45)
			hip_rot = Vector3(0.1, 0, 0)
			chest_rot = Vector3.ZERO
			head_rot = Vector3(0.1, 0, -0.2)
			leg = [[0.5, -0.8], [0.25, -0.5]]
			arm = [[0.6, -0.2, 0.5], [-0.2, 0.9, 0.3]]
			squash = 1.0 + breathe * 0.025
		Pose.SWIM:
			rig_pos.y = 0.08
			hip_rot = Vector3(-0.55, 0, 0)
			chest_rot = Vector3(-0.1, 0, 0)
			head_rot = Vector3(0.5, sin(_t * 0.7) * 0.15, 0)
			var pa := _t * 5.0
			arm = [[1.5 + sin(pa) * 0.7, -0.35, 1.1 + cos(pa) * 0.4], [1.5 + sin(pa + PI) * 0.7, 0.35, 1.1 - cos(pa) * 0.4]]
			leg = [[sin(_t * 8.0) * 0.4, -0.35], [-sin(_t * 8.0) * 0.4, -0.35]]
			face["brow_r"] = 0.4
		Pose.CLIMB:
			var ca := _t * 4.0
			arm = [[2.8 + sin(ca) * 0.3, -0.2, 0.5 + maxf(0.0, -sin(ca)) * 0.8], [2.8 - sin(ca) * 0.3, 0.2, 0.5 + maxf(0.0, sin(ca)) * 0.8]]
			leg = [[0.5 + sin(ca) * 0.35, -0.9], [0.5 - sin(ca) * 0.35, -0.9]]
			hip_rot = Vector3.ZERO
			chest_rot = Vector3.ZERO
			head_rot = Vector3(0.3, 0, 0)
			face["mouth"] = "teeth"
			face["brow_a"] = 0.8
		_:
			if not on_floor:
				if _air_t < 0.45 and vy > -3.0:
					# jump: stretch, arms up, knees tucked
					arm = [[1.3, -0.5, 0.4], [1.3, 0.5, 0.4]]
					leg = [[0.4, -0.9], [0.1, -0.5]]
					head_rot.x = 0.15
					squash = 1.06
					face["mouth"] = "open"
					face["open"] = 0.5
				else:
					# PEAK-style flailing when falling
					var fa := _t * 17.0
					arm = [[2.4 + sin(fa) * 0.4, -0.8, 0.3 + sin(fa * 1.3) * 0.3], [2.4 + sin(fa + 2.0) * 0.4, 0.8, 0.3 + cos(fa) * 0.3]]
					leg = [[sin(_t * 12.0) * 0.5, -0.4], [-sin(_t * 12.0) * 0.5, -0.5]]
					hip_rot.x = 0.15
					head_rot.x = 0.1
					face["eyes"] = "wide"
					face["mouth"] = "open"
					face["open"] = 1.0
					face["brow_r"] = 1.0
					face["brow_a"] = -0.6
			elif a < 0.05:
				_idle_pose(arm, leg, face, feet_fx)
				# standing: the weight drifts from one foot to the other now and then, a soft sway
				rig_pos.x += sin(_t * 0.45) * 0.018
				hip_rot.z += sin(_t * 0.45) * 0.05
				chest_rot.z -= sin(_t * 0.45) * 0.035
				head_rot.z += sin(_t * 0.45 - 0.6) * 0.03
				var k := _fidget_k()
				match _fidget:
					"stretch":
						chest_rot.x += 0.15 * k
						head_rot.x += 0.35 * k
						# up on the toes
						rig_pos.y += 0.045 * k
						feet_fx[0].y -= 0.4 * k
						feet_fx[1].y -= 0.4 * k
					"look":
						head_rot.y += sin(_fidget_t * 2.6) * 0.8 * k
						head_rot.x += 0.1 * k
					"straps":
						head_rot.x -= 0.3 * k
					"scratch":
						head_rot.z -= 0.15 * k
					"hum":
						var hm := sin(_fidget_t * 3.6)
						head_rot.z += hm * 0.16 * k
						chest_rot.z += hm * 0.05 * k
						rig_pos.x += hm * 0.02 * k
						head_rot.x += 0.08 * k
					"rock":
						head_rot.x += 0.06 * k
						rig_pos.y += 0.05 * maxf(sin(_fidget_t * 5.0), 0.0) * k
				# cold: arms hugged in, shivering
				if mood == Mood.COLD:
					arm[0] = [0.55, 0.35, 1.9]
					arm[1] = [0.55, -0.35, 1.9]
					chest_rot.z += sin(_t * 40.0) * 0.012
					head_rot.x -= 0.12

	# items in the hands (emotes still override them)
	var hands_busy := pose in [Pose.SWIM, Pose.CLIMB, Pose.LIE] or (not on_floor and _air_t > 0.45)
	if gear:
		gear.set_hands_busy(hands_busy)
		gear.update(delta)
		if not hands_busy:
			head_rot.x += _hold_pose(arm, arm_osc, delta)
	# something done with an item (arms and face; walking goes on)
	if _action != "":
		_action_t += delta
		if (_action_dur > 0.0 and _action_t > _action_dur) or hands_busy:
			stop_action()
		else:
			var aoff := ScoutActions.pose(self, _action, _action_t, _action_dur, arm, face, _action_st)
			head_rot += aoff["head"]
			chest_rot += aoff["chest"]
			rig_pos += aoff["rig"]
			# the arms doing something don't swing
			for i in 2:
				arm_osc[i] = [arm_osc[i][0] * 0.2, arm_osc[i][1] * 0.2, arm_osc[i][2] * 0.2]
	# reactions to the world
	_react_gap = maxf(_react_gap - delta, 0.0)
	for key in _react_cd:
		_react_cd[key] = maxf(float(_react_cd[key]) - delta, 0.0)
	if _react != "":
		_react_t += delta
		if _react_t > _react_dur or _emote != "" or _action != "" or hands_busy:
			_react = ""
		else:
			var dl := Vector3.ZERO
			if _react_dir != Vector3.ZERO:
				dl = (global_basis.inverse() * _react_dir).normalized() if is_inside_tree() else _react_dir
			var roff := ScoutReactions.pose(self, _react, _react_t, _react_dur, arm, face, feet_fx, _react_st, dl)
			head_rot += roff["head"]
			chest_rot += roff["chest"]
			rig_pos += roff["rig"]
			hip_rot += roff["hip"]
			for i in 2:
				arm_osc[i] = [arm_osc[i][0] * 0.4, arm_osc[i][1] * 0.4, arm_osc[i][2] * 0.4]
	var wm := _world_moods(delta, face)
	chest_rot.x += wm.x
	head_rot.x += wm.y

	# emotes override arms, legs, head and face (blended in and out)
	if _emote != "":
		_emote_t += delta
		var dur: float = EMOTES[_emote][1]
		if dur > 0.0 and _emote_t > dur:
			_emote = ""
		elif standing and on_floor and _emote not in ["wave", "yawn", "sit", "lie"]:
			var off := ScoutEmotes.pose(self, _emote, _emote_t, dur, arm, leg, face, feet_fx, _emote_st)
			rig_pos += off["rig"]
			# a hop takes the feet along (the planted legs would hold the body down)
			var hop := maxf(off["rig"].y, 0.0)
			feet_fx[0].x += hop
			feet_fx[1].x += hop
			hip_rot += off["hip"]
			chest_rot += off["chest"]
			head_rot += off["head"]
	var waving_now := (waving or _wave_t > 0.0) and standing and on_floor
	if waving_now:
		arm[1] = [0.3, 2.7, 0.2]
		head_rot.z = 0.18
		chest_rot.z = -0.06
		# a happy little bounce in the knees
		rig_pos.y -= absf(sin(_t * 5.0)) * 0.025
		face["eyes"] = "happy"
		face["mouth"] = "open"
		face["open"] = 0.7
		face["brow_r"] = 0.6

	# lip sync: the voice opens the mouth unless an emote or a strong mood face is showing
	if talk > 0.04 and _emote == "" and not waving_now and mood in [Mood.NORMAL, Mood.TIRED, Mood.COLD, Mood.JOY] and pose != Pose.LIE:
		face["mouth"] = "open"
		face["open"] = clampf(talk, 0.0, 1.0)
		face["brow_r"] = float(face["brow_r"]) + talk * 0.3
		head_rot.x += sin(_t * 9.0) * 0.04 * talk

	# the head turns towards a look target (scout editor: the camera) or glances around
	head_rot += _glance(delta, a)

	# ------------------------------------------------ apply
	var rhythm_on := on_ground and a > 0.03 and not waving_now and _emote == ""
	_osc_w = move_toward(_osc_w, 1.0 if rhythm_on else 0.0, delta * 5.0)
	var ow := _osc_w * _osc_w * (3.0 - 2.0 * _osc_w)
	# feet on the ground (IK) while standing, walking, running and sneaking; the other poses blend back to angles
	var ik_on := on_ground
	_ik_w = move_toward(_ik_w, 1.0 if ik_on else 0.0, delta * (6.0 if ik_on else 10.0))
	if _ik_w <= 0.0:
		_feet_ok = false
	_rig_s = _rig_s.lerp(rig_pos, 1.0 - exp(-12.0 * delta))
	var ik_rig := Vector3.ZERO
	if _ik_w > 0.0:
		ik_rig = _gait_update(gxf, delta, gp, feet_fx, rig_pos, pyaw)
	rig.position = _rig_s.lerp(ik_rig, _ik_w)
	rig.rotation = rig.rotation.lerp(rig_rot, 1.0 - exp(-6.0 * delta))
	hips.rotation = Vector3(_spring("hx", hip_rot.x, delta, 110.0, 14.0), _spring("hy", hip_rot.y, delta, 160.0, 18.0) + rhythm["hy"] * ow, _spring("hz", hip_rot.z, delta, 110.0, 12.0) + rhythm["hz"] * ow)
	hips.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))
	chest.rotation = Vector3(_spring("cx", chest_rot.x, delta, 90.0, 11.0) + rhythm["cx"] * ow, _spring("cy", chest_rot.y, delta, 120.0, 13.0) + rhythm["cy"] * ow, _spring("cz", chest_rot.z, delta, 120.0, 10.0) + rhythm["cz"] * ow)
	# the big head lags a little behind the body (wobbly, PEAK-like)
	neck.rotation = Vector3(_spring("nx", head_rot.x, delta, 70.0, 8.0), _spring("ny", head_rot.y, delta, 60.0, 9.0), _spring("nz", head_rot.z, delta, 70.0, 7.0))
	_apply_legs(gxf, leg, delta)
	if gear and gear.held("R") == "stock":
		_update_stick(gxf, delta)
	for i in 2:
		var am: Array = _arms[i]
		var ar: Array = arm[i]
		var sx: float = _spring("ax%d" % i, ar[0], delta, 140.0, 11.0) + arm_osc[i][0] * ow
		var sz: float = _spring("az%d" % i, ar[1], delta, 110.0, 8.0) + arm_osc[i][1] * ow
		var ex: float = _spring("ex%d" % i, ar[2], delta, 110.0, 9.0) + arm_osc[i][2] * ow
		# optional: shoulder twist, wrist pitch and roll
		var sy: float = _spring("ay%d" % i, ar[3] if ar.size() > 3 else 0.0, delta, 120.0, 11.0)
		var wx: float = _spring("wx%d" % i, ar[4] if ar.size() > 4 else 0.0, delta, 160.0, 13.0)
		var wz: float = _spring("wz%d" % i, ar[5] if ar.size() > 5 else 0.0, delta, 160.0, 13.0)
		am[0].rotation = Vector3(sx, sy, sz)
		var wave_z := sin(_t * 11.0) * 0.6 if waving_now and i == 1 else 0.0
		am[1].rotation = Vector3(ex, 0, _spring("ez%d" % i, wave_z, delta, 160.0, 10.0))
		am[2].rotation = Vector3(ex * 0.25 + wx, 0, wz)
	# pack and hat bounce with the body's up and down movement
	var pv := _spring("pelv", (rig.position.y - _last_rig_y) / maxf(delta, 1e-4), delta, 300.0, 30.0)
	_last_rig_y = rig.position.y
	_pack.rotation.x = _spring("pack", 0.05 * a + clampf(-pv * 0.12, -0.25, 0.25) + land * 0.6, delta, 70.0, 5.0)
	_pack.rotation.z = _spring("packz", -hips.rotation.z * 0.8 - rig.rotation.z * 0.5, delta, 70.0, 5.0)
	_hat_pivot.rotation.x = _spring("hat", -0.04 * a + clampf(pv * 0.06, -0.12, 0.12) + land * 0.4, delta, 120.0, 6.0)
	_hat_pivot.rotation.z = _spring("hatz", s * 0.03 * walk + turn_rate * 0.03, delta, 120.0, 6.0)
	if _propeller:
		_prop_angle += delta * (3.0 + v * 6.0 + (25.0 if not on_floor else 0.0))
		_propeller.rotation.y = _prop_angle
	for k in face_override:
		face[k] = face_override[k]
	_update_face(delta, face)
	for f in _step_pending:
		stepped.emit(f)
	_step_pending.clear()


# ================================================================ Gait: planted feet and two-bone IK
# A foot is either planted (a fixed point in world space: it cannot slide, whatever the speed, the turning or
# the frame rate) or swinging to where the body will be at the middle of its next stance. Step length and
# duty factor follow the leg's reach, the cadence follows from the speed. The sole rolls heel → flat → toe.

const FOOT_X := 0.1

func _track_motion(gxf: Transform3D, delta: float) -> void:
	if _has_prev:
		var dp := gxf.origin - _prev_xf.origin
		if dp.length() > 2.5:
			# teleport or floating-origin shift: plant the feet anew
			_feet_ok = false
			dp = Vector3.ZERO
		var vel := dp / maxf(delta, 1e-4)
		vel.y = 0.0
		var prev_v := Vector2(_gait_v.x, _gait_v.z).length()
		_gait_v = _gait_v.lerp(vel, 1.0 - exp(-10.0 * delta))
		var nv := Vector2(_gait_v.x, _gait_v.z).length()
		_gait_acc = lerpf(_gait_acc, (nv - prev_v) / maxf(delta, 1e-4), 1.0 - exp(-6.0 * delta))
	_prev_xf = gxf
	_has_prev = true


func _gait_params(v: float) -> Dictionary:
	var crouch := pose == Pose.CROUCH
	var run := 0.0 if crouch else maxf(smoothstep(3.6, 5.6, v), smoothstep(2.2, 3.4, v) if sprint else 0.0)
	# duty factor: share of the cycle a foot is on the ground (> 0.5 walking, < 0.5 with a flight phase)
	var fast := smoothstep(3.4, 6.2, v)
	var beta := lerpf(lerpf(0.64, 0.46, smoothstep(0.5, 3.4, v)), lerpf(0.36, 0.3, fast), run)
	# how far the body travels over a planted foot (limited by the leg's reach)
	var d := lerpf(lerpf(0.2, 0.5, smoothstep(0.0, 1.6, v)), lerpf(0.42, 0.56, fast), run)
	var lift := lerpf(0.045 + 0.012 * minf(v, 3.4), 0.15, run) * (0.6 if mood == Mood.TIRED else 1.0) * (1.0 + 1.3 * float(world_state.get("mud", 0.0)))
	var h0 := lerpf(0.578 - 0.006 * minf(v, 3.4), 0.55, run)
	if crouch:
		beta = lerpf(0.66, 0.56, smoothstep(0.3, 1.6, v))
		d = lerpf(0.16, 0.36, smoothstep(0.0, 1.6, v))
		lift = 0.06
		h0 = 0.44
	return {"run": run, "beta": beta, "f": maxf(v * beta / d, 1.6), "lift": lift, "h0": h0, "walk": smoothstep(0.1, 1.0, v)}


## Ground height below p (world): a short ray in the game, the scout's own level elsewhere (studio, menu)
func _ground_at(p: Vector3, gxf: Transform3D) -> float:
	var y := gxf.origin.y
	if not is_inside_tree():
		return y
	var space := get_world_3d().direct_space_state
	if space == null:
		return y
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, y + 0.5, p.z), Vector3(p.x, y - 0.7, p.z), 1)
	var par := get_parent()
	if par is CollisionObject3D:
		q.exclude = [(par as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else y


## Ankle position of a foot whose sole's flat position is at p (ground point under the ankle), turned by yaw,
## pitched by pitch (> 0 toe up, rolling on the heel; < 0 heel up, rolling on the toe)
static func _ankle(p: Vector3, yaw: float, pitch: float) -> Vector3:
	var b := Basis(Vector3.UP, yaw)
	var pz: float = HEEL.z if pitch > 0.0 else TOE.z
	return p + b * Vector3(0, 0, pz) + b * (Basis(Vector3.RIGHT, pitch) * Vector3(0, ANKLE_H, -pz))


func _reset_feet(gxf: Transform3D) -> void:
	var yaw := gxf.basis.get_euler().y
	_feet.clear()
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var home := gxf * Vector3(side * FOOT_X, 0, 0)
		var p := home
		# after a jump or getting up: plant the feet where they are (not too far from the body)
		if _ik_w < 0.9 and is_inside_tree():
			var cur := (_legs[i][2] as Node3D).global_position
			var off := Vector3(cur.x - home.x, 0, cur.z - home.z).limit_length(0.25)
			p = home + off
		p.y = _ground_at(p, gxf)
		_feet.append({"p": p, "yaw": yaw - side * 0.07, "stance": true, "pitch": 0.0, "t": p, "t_yaw": yaw,
			"lift": p, "lift_yaw": yaw, "lift_pitch": 0.0, "ankle": _ankle(p, yaw, 0.0), "w": 0.0})
	_gait_g = 0.03
	_feet_ok = true
	_pelvis_ok = false


## Moves the feet (plant, lift, swing, land) and returns the rig offset (pelvis height and sway)
func _gait_update(gxf: Transform3D, delta: float, gp: Dictionary, feet_fx: Array, extra: Vector3, pyaw: float) -> Vector3:
	if not _feet_ok:
		_reset_feet(gxf)
	var v3 := _gait_v
	var v := Vector2(v3.x, v3.z).length()
	var beta: float = gp["beta"]
	var f: float = gp["f"]
	var run: float = gp["run"]
	var walk: float = gp["walk"]
	var yaw := gxf.basis.get_euler().y
	var width := lerpf(FOOT_X, 0.08, run)
	# keep stepping while moving, while a foot is in the air, or until both feet stand under the body again
	var active := v > 0.12
	for i in 2:
		var ft: Dictionary = _feet[i]
		var home := gxf * Vector3((i * 2 - 1) * width, 0, 0)
		if not ft["stance"]:
			active = true
		elif Vector2(home.x - ft["p"].x, home.z - ft["p"].z).length() > 0.1 or absf(angle_difference(ft["yaw"], yaw)) > 0.55:
			active = true
	if active:
		_gait_g = fposmod(_gait_g + f * delta, 1.0)
	var tst := beta / f
	var fwd := Vector3(-gxf.basis.z.x, 0, -gxf.basis.z.z).normalized()
	var ph := lerpf(0.26, 0.06, run) * walk
	var pt := -lerpf(0.5, 0.85, run) * walk
	var lift_h: float = gp["lift"]
	var reach := (THIGH + SHIN) * 0.985
	var to_local := gxf.affine_inverse()
	# pelvis: its resting height, a run bounce (low in the middle of a stance, up in the flight) and a walk lilt
	var mid := cos(2.0 * TAU * (_gait_g - beta * 0.5))
	var h: float = gp["h0"] + extra.y - 0.035 * run * mid + 0.012 * walk * (1.0 - run) * mid
	var h_free := h
	var h_cons := 10.0
	for i in 2:
		var ft: Dictionary = _feet[i]
		var side := -1.0 if i == 0 else 1.0
		var phi := fposmod(_gait_g + 0.5 * i, 1.0)
		if active:
			var st := phi < beta
			if ft["stance"] and not st:
				ft["stance"] = false
				ft["lift"] = ft["p"]
				ft["lift_yaw"] = ft["yaw"]
				ft["lift_pitch"] = ft["pitch"]
			elif not ft["stance"] and st:
				ft["stance"] = true
				ft["p"] = ft["t"]
				ft["yaw"] = ft["t_yaw"]
				_step_pending.append(_legs[i][2])
		var ankle: Vector3
		if ft["stance"]:
			var pitch := 0.0
			if active:
				var u := phi / beta
				pitch = ph * (1.0 - smoothstep(0.0, lerpf(0.2, 0.12, run), u)) + pt * smoothstep(lerpf(0.55, 0.4, run), 1.0, u)
			else:
				pitch = lerpf(ft["pitch"], 0.0, 1.0 - exp(-10.0 * delta))
			ft["pitch"] = pitch
			ankle = _ankle(ft["p"], ft["yaw"], pitch + feet_fx[i].y)
			ft["w"] = 1.0
		else:
			var w := clampf((phi - beta) / (1.0 - beta), 0.0, 1.0)
			ft["w"] = w
			# landing point: under the hip at the middle of the coming stance
			var t_rem := (1.0 - w) * (1.0 - beta) / f
			var home := gxf * Vector3(side * width, 0, 0)
			var tgt := home + (v3 * (t_rem + tst * 0.5)).limit_length(0.45)
			tgt.y = _ground_at(tgt, gxf)
			ft["t"] = tgt
			ft["t_yaw"] = yaw - side * 0.07
			var e := w * w * (3.0 - 2.0 * w)
			var g: Vector3 = (ft["lift"] as Vector3).lerp(tgt, e)
			# running: the heel kicks up behind before the knee drives forward
			g -= fwd * (0.1 * run * sin(PI * minf(w * 1.4, 1.0)))
			g.y += lift_h * pow(sin(PI * w), 0.8) + 0.08 * run * sin(PI * minf(w * 1.6, 1.0))
			var pitch: float = lerpf(ft["lift_pitch"], ph, smoothstep(0.25, 0.95, w)) - 0.45 * run * sin(PI * w) + 0.12 * (1.0 - run) * walk * sin(PI * w)
			ft["pitch"] = pitch
			ankle = _ankle(g, lerp_angle(ft["lift_yaw"], ft["t_yaw"], e), pitch + feet_fx[i].y)
		ankle.y += feet_fx[i].x
		ft["ankle"] = ankle
		# the pelvis may not be higher than a planted (or landing) leg can reach
		var al := to_local * ankle
		var jx := side * FOOT_X * cos(pyaw)
		var jz := -side * FOOT_X * sin(pyaw)
		var dxz := Vector2(al.x - jx - extra.x, al.z - jz).length()
		var hmax := al.y + sqrt(maxf(reach * reach - dxz * dxz, 0.0))
		var k := 1.0 if ft["stance"] else smoothstep(0.55, 1.0, ft["w"])
		if feet_fx[i].x > 0.0:
			k *= 0.0
		h_cons = minf(h_cons, lerpf(h_free + 1.0, hmax, k))
	# smooth pelvis motion, but never higher than the legs reach (that would drag the feet)
	var hs := _spring("pelvis", minf(h_free, h_cons), delta, 700.0, 50.0) if _pelvis_ok else minf(h_free, h_cons)
	if not _pelvis_ok:
		_springs["pelvis"] = Vector2(hs, 0.0)
	_pelvis_h = maxf(minf(hs, h_cons), h_free - 0.16)
	_pelvis_ok = true
	# weight over the planted foot
	var sway := -0.014 * walk * (1.0 - run) * cos(TAU * (_gait_g - beta * 0.5))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		(_legs[i][0] as Node3D).position = Vector3(side * FOOT_X * cos(pyaw), HIP_Y, -side * FOOT_X * sin(pyaw))
	return Vector3(sway + extra.x, _pelvis_h - HIP_Y, extra.z)


## Two-bone IK in the leg's plane: [hip pitch, knee, hip roll] for an ankle target in rig space
func _leg_ik(i: int, a: Vector3) -> Array:
	var t: Vector3 = a - (_legs[i][0] as Node3D).position
	var hz := clampf(atan2(t.x, -t.y), -0.6, 0.6)
	var dp := Vector2(t.x, t.y).length()
	var fw := -t.z
	var dist := clampf(Vector2(dp, fw).length(), 0.12, (THIGH + SHIN) * 0.9995)
	var ck := clampf((THIGH * THIGH + SHIN * SHIN - dist * dist) / (2.0 * THIGH * SHIN), -1.0, 1.0)
	var cb := clampf((THIGH * THIGH + dist * dist - SHIN * SHIN) / (2.0 * THIGH * dist), -1.0, 1.0)
	return [atan2(fw, dp) + acos(cb), -(PI - acos(ck)), hz]


func _apply_legs(gxf: Transform3D, leg: Array, delta: float) -> void:
	var to_rig := (gxf * rig.transform).affine_inverse()
	var rb := to_rig.basis.orthonormalized()
	for i in 2:
		var lg: Array = _legs[i]
		var hx := _spring("lx%d" % i, leg[i][0], delta, 260.0, 26.0)
		var kx := _spring("kx%d" % i, leg[i][1], delta, 260.0, 26.0)
		var hz := 0.0
		var foot_b := Basis(Vector3.RIGHT, -(hx + kx) * (0.8 if pose != Pose.LIE else 0.3))
		if _ik_w > 0.0 and _feet.size() == 2:
			var ft: Dictionary = _feet[i]
			var ik := _leg_ik(i, to_rig * (ft["ankle"] as Vector3))
			var w := _ik_w * _ik_w * (3.0 - 2.0 * _ik_w)
			hx = lerpf(hx, ik[0], w)
			kx = lerpf(kx, ik[1], w)
			hz = lerpf(0.0, ik[2], w)
			var fy: float = ft["yaw"] if ft["stance"] else lerp_angle(ft["lift_yaw"], ft["t_yaw"], ft["w"])
			var fw_b := Basis(Vector3.UP, fy) * Basis(Vector3.RIGHT, ft["pitch"])
			var knee_b := Basis(Vector3(0, 0, 1), hz) * Basis(Vector3.RIGHT, hx) * Basis(Vector3.RIGHT, kx)
			var ik_foot := knee_b.inverse() * (rb * fw_b)
			foot_b = Basis(foot_b.get_rotation_quaternion().slerp(ik_foot.get_rotation_quaternion(), w))
			if _ik_w >= 1.0:
				# keep the angle springs in step for a smooth hand-over to the other poses
				_springs["lx%d" % i] = Vector2(hx, 0.0)
				_springs["kx%d" % i] = Vector2(kx, 0.0)
		lg[0].basis = Basis(Vector3(0, 0, 1), hz) * Basis(Vector3.RIGHT, hx)
		lg[1].basis = Basis(Vector3.RIGHT, kx)
		lg[2].basis = foot_b
		if _ik_w <= 0.0:
			lg[0].position = Vector3((i * 2 - 1) * FOOT_X, HIP_Y, 0)


# walking stick: its tip is planted in the world with the left foot and swings forward with the right one
var _stick_p := Vector3.INF
var _stick_from := Vector3.ZERO
var _stick_to := Vector3.ZERO
var _stick_planted := true


func _update_stick(gxf: Transform3D, delta: float) -> void:
	var n := gear.item_node("stock")
	if n == null or not n.is_inside_tree() or not n.visible:
		return
	var body: Node3D = n.get_child(0)
	var fwd := -gxf.basis.z
	var right := gxf.basis.x
	var v := Vector2(_gait_v.x, _gait_v.z).length()
	var rest := gxf.origin + right * 0.27 + fwd * 0.12
	rest.y = _ground_at(rest, gxf)
	if _stick_p == Vector3.INF or _stick_p.distance_to(gxf.origin) > 1.6:
		_stick_p = rest
	if v > 4.2:
		# sprinting: the stick is carried, tip forward and down
		_stick_planted = true
		_stick_p = _stick_p.lerp(n.global_position + fwd * 0.5 + Vector3(0, -0.45, 0), 1.0 - exp(-14.0 * delta))
	elif _feet.size() == 2 and _ik_w > 0.5 and v > 0.3:
		var ft: Dictionary = _feet[0]
		var planted: bool = ft["stance"]
		if planted and not _stick_planted:
			_stick_p = _stick_to
		elif not planted and _stick_planted:
			_stick_from = _stick_p
		_stick_planted = planted
		if not planted:
			# where the left foot will land, a little to the right and ahead
			var land: Vector3 = ft["t"]
			_stick_to = land + right * 0.36 + fwd * 0.1
			_stick_to.y = _ground_at(_stick_to, gxf)
			var w: float = ft["w"]
			var e := w * w * (3.0 - 2.0 * w)
			_stick_p = _stick_from.lerp(_stick_to, e) + Vector3(0, sin(PI * w) * 0.09, 0)
	else:
		_stick_planted = true
		_stick_p = _stick_p.lerp(rest, 1.0 - exp(-6.0 * delta))
	var grip := n.global_position
	var d := _stick_p - grip
	var dist := d.length()
	if dist < 0.05:
		return
	var dir := d / dist
	var x := dir.cross(fwd)
	if x.length() < 0.01:
		x = right
	x = x.normalized()
	# pivot -Y along the stick towards the tip; the grip slides along it
	n.global_basis = Basis(x, -dir, x.cross(-dir)).orthonormalized()
	var half := 0.6 * 0.85
	body.position = Vector3(0, -clampf(dist - half, -0.3, 0.25), 0)


## The weather and the ground as a lasting mood: hunched in heavy rain, squinting into the low sun, puffs of
## breath in the cold
func _world_moods(delta: float, face: Dictionary) -> Vector2:
	var out := Vector2.ZERO
	var rain: float = world_state.get("rain", 0.0)
	if rain > 0.05 and pose == Pose.STAND and _emote == "":
		out = Vector2(-0.1 * rain, -0.12 * rain)
		if face["eyes"] in ["dot", "sclera"]:
			face["brow_a"] = minf(float(face["brow_a"]), -0.4 * rain)
			face["lid"] = maxf(float(face["lid"]), 0.25 * rain)
	var glare: float = world_state.get("glare", 0.0)
	if glare > 0.05 and face["eyes"] in ["dot", "sclera"]:
		face["lid"] = maxf(float(face["lid"]), 0.45 * glare)
	var mud: float = world_state.get("mud", 0.0)
	if mud > 0.3 and speed > 0.3 and face["eyes"] in ["dot", "sclera"] and face["mouth"] in ["smile", "flat"]:
		face["mouth"] = "frown"
	# breath in the cold: a little white puff every few seconds
	if float(world_state.get("cold", 0.0)) > 0.5 and not _shadow_only and is_inside_tree():
		_breath_t -= delta * (1.6 if speed > 3.0 else 1.0)
		if _breath_t <= 0.0:
			_breath_t = randf_range(2.2, 3.2)
			_puff()
	return out


func _puff() -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 1.4
	p.explosiveness = 0.7
	p.direction = Vector3(0, 0.2, -1)
	p.spread = 18.0
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0, 0.12, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.09
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curve
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.mesh = sm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(p)
	p.global_transform = neck.global_transform * Transform3D(Basis(), Vector3(0, 0.2, -0.3))
	p.emitting = true
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)


## Arm targets for the items in the hands; returns how far the head looks down (reading)
func _hold_pose(arm: Array, osc: Array, delta: float) -> float:
	var look_down := 0.0
	for i in 2:
		var side := "L" if i == 0 else "R"
		var sd := -1.0 if i == 0 else 1.0
		var id := gear.held(side)
		var w := _spring("holdw%d" % i, 1.0 if id != "" else 0.0, delta, 60.0, 14.0)
		if w < 0.01:
			continue
		var grip := ScoutGear.grip_of(id) if id != "" else String(get_meta("last_grip%d" % i, "hold"))
		set_meta("last_grip%d" % i, grip)
		var target: Array = arm[i]
		var swing := 1.0
		match grip:
			"hang":
				target = [0.28, sd * 0.2, 0.55, 0.0, -0.2, 0.0]
				swing = 0.35
			"point":
				target = [1.2, sd * 0.1, 0.25, -sd * 0.2, -0.15, 0.0]
				swing = 0.1
			"stick":
				target = [arm[i][0], arm[i][1] + sd * 0.08, arm[i][2] + 0.35, 0.0, 0.0, 0.0]
				swing = 0.8
			"read", "palm":
				# hands in front of the chest (the item is anchored there), head down to look at it
				target = reach(i, Vector3(sd * 0.1, 0.8, -0.32), Vector2(0.2, 0)) if grip == "read" else reach(i, Vector3(sd * 0.07, 0.8, -0.3), Vector2(0.9, 0))
				swing = 0.0
				look_down = maxf(look_down, 0.42 * w)
				# the map and the book need both hands
				if grip == "read":
					var j := 1 - i
					arm[j] = _blend_arm(arm[j], reach(j, Vector3(-sd * 0.1, 0.8, -0.32), Vector2(0.2, 0)), w)
					osc[j] = [osc[j][0] * (1.0 - w), osc[j][1] * (1.0 - w), osc[j][2] * (1.0 - w)]
			_:
				target = [0.3, sd * 0.1, 0.85, 0.0, 0.25, 0.0]
				swing = 0.5
		arm[i] = _blend_arm(arm[i], target, w)
		var k := lerpf(1.0, swing, w)
		osc[i] = [osc[i][0] * k, osc[i][1] * k, osc[i][2] * k]
	return look_down


## Arm IK: the arm angles [pitch, roll, elbow, twist, wrist pitch, wrist roll] that bring the middle of the mitten
## to target (chest space, the model's rest coordinates). The elbow stays low and a little outside.
const UPPER_ARM := 0.2
const FOREARM := 0.215     # elbow to the middle of the mitten
const SHOULDER := Vector3(0.205, 0.965, 0.0)


func reach(i: int, target: Vector3, wrist := Vector2.ZERO, elbow_out := false) -> Array:
	var sd := -1.0 if i == 0 else 1.0
	var t := target - Vector3(SHOULDER.x * sd, SHOULDER.y, SHOULDER.z)
	var dist := clampf(t.length(), 0.08, (UPPER_ARM + FOREARM) * 0.995)
	var ce := clampf((dist * dist - UPPER_ARM * UPPER_ARM - FOREARM * FOREARM) / (2.0 * UPPER_ARM * FOREARM), -1.0, 1.0)
	var ex := acos(ce)
	# the arm's end with this elbow bend, before the shoulder turns it (hanging down, forearm forward)
	var e0 := Vector3(0, -UPPER_ARM - FOREARM * cos(ex), -FOREARM * sin(ex))
	var td := t.normalized() * e0.length()
	var base := Basis(Quaternion(e0.normalized(), td.normalized()))
	# twist around the shoulder-hand line: pick the one with the elbow lowest and slightly outside
	var best := base
	var best_v := INF
	for k in 16:
		var b := Basis(td.normalized(), TAU * k / 16.0) * base
		var elbow := b * Vector3(0, -UPPER_ARM, 0)
		# elbow_out: the elbow points sideways (flexing), else low and a little outside
		var v := -sd * elbow.x * 2.0 + absf(elbow.z) if elbow_out else elbow.y - sd * elbow.x * 0.6 + elbow.z * 0.2
		if v < best_v:
			best_v = v
			best = b
	var e := best.get_euler()
	return [e.x, e.z, ex, e.y, wrist.x, wrist.y]


static func _blend_arm(a: Array, b: Array, w: float) -> Array:
	var out := []
	for n in maxi(a.size(), b.size()):
		var x: float = a[n] if n < a.size() else 0.0
		var y: float = b[n] if n < b.size() else 0.0
		out.append(lerpf(x, y, w))
	return out


func _fidget_k() -> float:
	var len: float = FIDGETS.get(_fidget, 2.2)
	return smoothstep(0.0, 0.35, _fidget_t) * (1.0 - smoothstep(len - 0.5, len, _fidget_t))


func _idle_pose(arm: Array, leg: Array, face: Dictionary, fx: Array) -> void:
	var ft := _fidget_t
	var k := _fidget_k()
	match _fidget:
		"stretch":
			var up := [[2.9, -0.35, 0.2], [2.9, 0.35, 0.2]]
			for i in 2:
				arm[i] = [lerpf(arm[i][0], up[i][0], k), lerpf(arm[i][1], up[i][1], k), lerpf(arm[i][2], up[i][2], k)]
			if k > 0.5:
				face["eyes"] = "closed"
				face["mouth"] = "open"
				face["open"] = 0.9
		"look":
			face["brow_r"] = 0.5
		"straps":
			arm[0] = [lerpf(arm[0][0], 0.45, k), lerpf(arm[0][1], 0.35, k), lerpf(arm[0][2], 1.7, k)]
			arm[1] = [lerpf(arm[1][0], 0.45, k), lerpf(arm[1][1], -0.35, k), lerpf(arm[1][2], 1.7, k)]
		"scratch":
			arm[1] = [lerpf(arm[1][0], 2.3, k), lerpf(arm[1][1], 0.9, k), lerpf(arm[1][2], 1.9 + sin(ft * 18.0) * 0.2, k)]
			face["brow_a"] = -0.5
			face["mouth"] = "wavy"
		"hum":
			# humming a little tune: swaying, head tilted, eyes happily closed
			face["eyes"] = "happy" if k > 0.4 else face["eyes"]
			face["mouth"] = "smile"
			face["brow_r"] = 0.3
			arm[0] = [lerpf(arm[0][0], -0.15, k), lerpf(arm[0][1], -0.2, k), lerpf(arm[0][2], 0.4, k)]
			arm[1] = [lerpf(arm[1][0], -0.15, k), lerpf(arm[1][1], 0.2, k), lerpf(arm[1][2], 0.4, k)]
		"rock":
			# rocking up onto the toes and back onto the heels, hands behind the back
			var r := sin(ft * 5.0)
			fx[0] = Vector2(0.0, (-0.45 * maxf(r, 0.0) + 0.25 * maxf(-r, 0.0)) * k)
			fx[1] = fx[0]
			arm[0] = [lerpf(arm[0][0], -0.5, k), lerpf(arm[0][1], 0.25, k), lerpf(arm[0][2], 0.9, k)]
			arm[1] = [lerpf(arm[1][0], -0.5, k), lerpf(arm[1][1], -0.25, k), lerpf(arm[1][2], 0.9, k)]
			face["brow_r"] = 0.35
		"tap":
			leg[1] = [0.15 * k, -0.2 * k - absf(sin(ft * 9.0)) * 0.25 * k]
			# tapping the toe, the heel stays down
			fx[1] = Vector2(0.0, absf(sin(ft * 9.0)) * 0.4 * k)
			arm[0][1] -= 0.15 * k
			arm[1][1] += 0.15 * k


func _glance(delta: float, a: float) -> Vector3:
	if look_target != Vector3.INF and is_inside_tree():
		var local: Vector3 = (neck.get_parent() as Node3D).global_transform.affine_inverse() * look_target - neck.position
		var yaw := atan2(-local.x, -local.z)
		var pitch := atan2(local.y - 0.3, Vector2(local.x, local.z).length())
		_pupil = Vector2(clampf(yaw * 0.8, -1.0, 1.0), clampf(pitch * 1.5, -0.6, 0.6))
		return Vector3(clampf(pitch, -0.5, 0.5) * 0.6, clampf(yaw, -1.0, 1.0) * 0.7, 0.0)
	# something interesting nearby: the head turns (less while walking), the eyes follow
	_att_w = move_toward(_att_w, attention_w if attention != Vector3.INF else 0.0, delta * 1.5)
	if _att_w > 0.01 and attention != Vector3.INF and is_inside_tree():
		var la: Vector3 = (neck.get_parent() as Node3D).global_transform.affine_inverse() * attention - neck.position
		var ya := clampf(atan2(-la.x, -la.z), -1.2, 1.2)
		var pa := clampf(atan2(la.y - 0.3, Vector2(la.x, la.z).length()), -0.4, 0.8)
		_pupil = _pupil.lerp(Vector2(clampf(ya * 0.8, -1.0, 1.0), clampf(pa * 1.5, -0.6, 0.6)), _att_w)
		var kk := _att_w * (1.0 - minf(a, 1.0) * 0.45)
		return Vector3(pa * 0.7 * kk, ya * 0.75 * kk, 0.0)
	_look_timer -= delta
	if _look_timer <= 0.0:
		_look_timer = randf_range(1.2, 4.0)
		_look = Vector2(randf_range(-0.5, 0.5), randf_range(-0.15, 0.2)) if randf() < 0.5 else Vector2.ZERO
		_pupil = Vector2(signf(_look.x) * 0.7 if absf(_look.x) > 0.1 else randf_range(-0.5, 0.5), randf_range(-0.4, 0.4))
	var k := 1.0 - minf(a, 1.0) * 0.7
	# eyes lead into a turn
	if absf(turn_rate) > 0.4 and a > 0.2:
		_pupil.x = lerpf(_pupil.x, clampf(turn_rate * 0.4, -0.8, 0.8), 1.0 - exp(-8.0 * delta))
	return Vector3(_look.y * k, _look.x * k, 0.0)


func _face_base() -> Dictionary:
	var f := {"eyes": "dot", "mouth": "smile", "open": 0.0, "brow_r": 0.0, "brow_a": 0.0, "lid": 0.0, "blush": 0.0, "sweat": 0.0, "tears": 0.0}
	match int(look["face"]) % FACE_NAMES.size():
		1:
			f["eyes"] = "sclera"
			f["brow_r"] = 0.3
		2:
			f["eyes"] = "sclera"
			f["lid"] = 0.45
			f["mouth"] = "flat"
			f["brow_r"] = -0.3
		3:
			f["mouth"] = "cheeky"
			f["brow_a"] = 0.25
			f["brow_r"] = 0.2
		4:
			f["eyes"] = "sclera"
			f["brow_a"] = 0.7
			f["mouth"] = "flat"
	match mood:
		Mood.TIRED:
			f["lid"] = 0.5
			f["brow_a"] = -0.7
			f["brow_r"] = -0.2
			f["mouth"] = "open" if speed > 0.5 else "wavy"
			f["open"] = 0.35 + 0.25 * sin(_t * 9.0)
		Mood.KNOCKED_OUT:
			f["eyes"] = "x"
			f["mouth"] = "open"
			f["open"] = 0.4
			f["brow_r"] = -0.5
		Mood.ASLEEP:
			f["eyes"] = "closed"
			f["mouth"] = "flat"
			f["brow_r"] = -0.4
			f["lid"] = 0.0
		Mood.JOY:
			f["eyes"] = "happy"
			f["mouth"] = "open"
			f["open"] = 0.7
			f["brow_r"] = 0.6
		Mood.EFFORT:
			f["mouth"] = "teeth"
			f["brow_a"] = 0.9
			f["lid"] = 0.2
		Mood.SCARED:
			f["eyes"] = "wide"
			f["mouth"] = "open"
			f["open"] = 1.0
			f["brow_r"] = 1.0
			f["brow_a"] = -0.6
		Mood.COLD:
			f["mouth"] = "teeth"
			f["brow_a"] = -0.8
			f["brow_r"] = 0.2
	if sprint and speed > 3.0 and f["mouth"] in ["smile", "flat", "wavy", "cheeky"]:
		# sprinting: determined brows, puffing
		f["mouth"] = "open"
		f["open"] = 0.4 + 0.2 * sin(_t * 12.0)
		f["brow_a"] = maxf(float(f["brow_a"]), 0.45)
		f["brow_r"] = float(f["brow_r"]) - 0.15
	return f


func _update_face(delta: float, f: Dictionary) -> void:
	var eyes: String = f["eyes"]
	var mouth: String = f["mouth"]
	var state := "%s/%s/%s" % [eyes, mouth, _shadow_only]
	if state != _face_state:
		_face_state = state
		var show := not _shadow_only
		var drawn := eyes in ["dot", "sclera", "wide", "teary"]
		for s in ["L", "R"]:
			for k in ["star", "heart", "spiral", "squeeze"]:
				(_face[k + s] as Node3D).visible = eyes == k
			(_face["eye" + s] as Node3D).visible = show
			(_face["outline" + s] as Node3D).visible = drawn and eyes != "dot"
			(_face["sclera" + s] as Node3D).visible = drawn and eyes != "dot"
			(_face["pupil" + s] as Node3D).visible = drawn
			(_face["lid" + s] as Node3D).visible = drawn
			(_face["happy" + s] as Node3D).visible = eyes == "happy"
			(_face["closed" + s] as Node3D).visible = eyes == "closed"
			(_face["x" + s] as Node3D).visible = eyes == "x"
			(_face["brow" + s] as Node3D).visible = show
		(_face["mouth"] as Node3D).visible = show
		for k in ScoutFaceFx.MOUTHS:
			(_face[k] as Node3D).visible = k == mouth
	if _shadow_only:
		return
	# blinking
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.13
		_next_blink = randf_range(1.8, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	var wide := eyes == "wide"
	var lid := _spring("lid", 1.0 if _blink > 0.0 else float(f["lid"]), delta, 500.0, 40.0)
	var pup_s := _spring("pups", 0.62 if wide else (1.25 if eyes == "teary" else (1.0 if eyes == "sclera" else 1.35)), delta, 200.0, 20.0)
	var eye_s := _spring("eyes", 1.2 if wide else 1.0, delta, 200.0, 16.0)
	var px := _spring("pupx", _pupil.x, delta, 300.0, 30.0)
	var py := _spring("pupy", _pupil.y, delta, 300.0, 30.0)
	var brow_r := _spring("browr", float(f["brow_r"]), delta, 200.0, 16.0)
	var brow_a := _spring("browa", float(f["brow_a"]), delta, 200.0, 16.0)
	for i in 2:
		var s: String = ["L", "R"][i]
		var side := -1.0 if i == 0 else 1.0
		var eye: Node3D = _face["eye" + s]
		eye.transform = (eye.get_meta("rest") as Transform3D).scaled_local(Vector3(eye_s, eye_s, 1.0))
		var lidn: Node3D = _face["lid" + s]
		lidn.position.y = lerpf(LID_UP, 0.02, clampf(lid, 0.0, 1.0))
		# only while it covers the eye (at rest it would be a bump on the forehead)
		lidn.visible = lid > 0.1 and eyes in ["dot", "sclera", "wide", "teary"]
		var pupil: Node3D = _face["pupil" + s]
		var r := 0.013 if eyes != "dot" else 0.005
		# local +X of the face frame points to the character's left
		pupil.position = Vector3(px * r, py * r, 0.012)
		pupil.scale = Vector3(pup_s, pup_s, 1.0)
		var brow: Node3D = _face["brow" + s]
		# angry: inner ends down; worried: inner ends up
		brow.transform = (brow.get_meta("rest") as Transform3D).translated_local(Vector3(0, brow_r * 0.028, 0.004)).rotated_local(Vector3(0, 0, 1), brow_a * 0.35 * side)
	# blush, sweat drop, tears running down
	var bl := _spring("blush", float(f.get("blush", 0.0)), delta, 120.0, 14.0)
	var blush: Node3D = _face["blush"]
	blush.visible = bl > 0.04
	blush.scale = Vector3.ONE * clampf(0.6 + bl * 0.5, 0.6, 1.1)
	var sw := _spring("sweat", float(f.get("sweat", 0.0)), delta, 150.0, 12.0)
	var sweat: Node3D = _face["sweat"]
	sweat.visible = sw > 0.05
	sweat.scale = Vector3.ONE * maxf(sw, 0.01)
	var tears := float(f.get("tears", 0.0)) > 0.1 or eyes == "teary"
	_tear_t += delta
	for s in ["L", "R"]:
		var tn: Node3D = _face["tears" + s]
		tn.visible = tears
		if tears:
			for k in 2:
				var d: Node3D = tn.get_child(k)
				var ph := fposmod(_tear_t * 0.9 + k * 0.5, 1.0)
				d.position.y = -0.05 - ph * 0.12
				d.scale = Vector3.ONE * (0.6 + 0.5 * sin(PI * ph))
	var open: Node3D = _face["open"]
	var o := _spring("open", float(f["open"]), delta, 260.0, 18.0)
	open.scale = Vector3(lerpf(0.6, 1.0, o), lerpf(0.3, 1.25, o), 1.0)
	(_face["teeth"] as Node3D).position.x = sin(_t * 60.0) * 0.003 if mood == Mood.COLD else 0.0
