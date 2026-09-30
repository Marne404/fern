class_name ScoutReactions
extends RefCounted
## Little moments in which the scout reacts to the world (WorldSense decides when): looking up at the first
## raindrops, catching snowflakes, holding the hat in a gust, shading the eyes against the low sun, pointing at a
## shooting star, going cross-eyed at a butterfly on the nose, warming the hands at a fire, shaking itself dry …
## "upper" reactions play while walking, "full" ones only when standing (or sitting) still.

## id -> [seconds, layer, cooldown seconds]
const KINDS := {
	"look_up_rain": [2.0, "upper", 90.0], "cover_head": [2.4, "upper", 50.0], "catch_snow": [3.2, "full", 90.0],
	"shiver": [2.0, "upper", 35.0], "fan": [2.2, "upper", 45.0], "hold_hat": [1.8, "upper", 55.0],
	"shade_eyes": [2.6, "upper", 70.0], "awe_sky": [3.6, "full", 80.0], "shooting_star": [2.2, "upper", 6.0],
	"rainbow": [2.6, "upper", 150.0], "flinch": [0.9, "upper", 6.0], "butterfly": [3.0, "full", 25.0],
	"shh": [2.5, "upper", 50.0], "freeze": [2.2, "full", 50.0], "whistle_back": [2.0, "upper", 50.0],
	"warm_hands": [4.0, "upper", 25.0], "shake_dry": [1.6, "full", 20.0], "dust_off": [1.5, "full", 8.0],
	"fist_pump": [1.3, "upper", 4.0], "wonder": [2.8, "upper", 20.0], "yuck": [2.0, "upper", 35.0],
	"tummy": [2.0, "upper", 90.0], "lick_lips": [1.5, "upper", 90.0], "wring": [2.2, "full", 80.0],
	"nervous": [2.5, "upper", 40.0], "look_up_big": [2.6, "upper", 45.0],
}

const SHOULDER_R := Vector3(0.205, 0.965, 0.0)


static func duration(kind: String) -> float:
	return KINDS[kind][0]


static func full_body(kind: String) -> bool:
	return KINDS[kind][1] == "full"


## dir: the reaction's direction in the scout's own space (unit; ZERO = none)
static func pose(sc: Scout, kind: String, t: float, dur: float, arm: Array, face: Dictionary, fx: Array, st: Dictionary, dir: Vector3) -> Dictionary:
	var off := {"head": Vector3.ZERO, "chest": Vector3.ZERO, "rig": Vector3.ZERO, "hip": Vector3.ZERO}
	var k := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(dur - 0.35, dur, t))
	var at := func(i: int, p: Vector3, wrist: Vector2) -> void:
		var q := Vector3(p.x * (-1.0 if i == 0 else 1.0), p.y, p.z)
		arm[i] = Scout._blend_arm(arm[i], sc.reach(i, q, wrist * Vector2(1.0, -1.0 if i == 0 else 1.0)), k)
	var to := func(i: int, target: Array) -> void:
		arm[i] = Scout._blend_arm(arm[i], target, k)
	var set_face := func(d: Dictionary) -> void:
		if k > 0.3:
			for key in d:
				face[key] = d[key]
	var once := func(key: String, when: float) -> bool:
		if t >= when and not st.has(key):
			st[key] = true
			return true
		return false
	# look along dir (yaw, pitch)
	var look := Vector3.ZERO
	if dir != Vector3.ZERO:
		look = Vector3(clampf(asin(clampf(dir.y, -1.0, 1.0)), -0.35, 0.85), clampf(atan2(-dir.x, -dir.z), -1.1, 1.1), 0.0)
	match kind:
		"look_up_rain":
			off["head"] = Vector3(0.55, 0, 0.1) * k
			# a palm held out to feel the drops
			to.call(1, [1.2, 0.35, 0.5, 0.0, 0.0, -1.4])
			var blink := fmod(t, 0.5) < 0.15
			set_face.call({"eyes": "closed" if blink else "sclera", "mouth": "o", "brow_r": 0.6})
		"cover_head":
			at.call(0, Vector3(0.16, 1.4, -0.12), Vector2.ZERO)
			at.call(1, Vector3(0.16, 1.4, -0.12), Vector2.ZERO)
			off["chest"] = Vector3(-0.12, 0, 0) * k
			off["head"] = Vector3(-0.15, 0, 0) * k
			set_face.call({"eyes": "squeeze", "mouth": "wavy", "brow_a": -0.6})
		"catch_snow":
			off["head"] = Vector3(0.65, 0, sin(t * 2.0) * 0.1) * k
			to.call(1, [1.2, 0.35, 0.5, 0.0, 0.0, -1.4])
			set_face.call({"eyes": "closed", "mouth": "tongue", "blush": 0.5})
			if once.call("b", dur * 0.6):
				sc.bubble("sparkle", 1.0, 0.4, 0.7)
		"shiver":
			var sh := sin(t * 45.0) * 0.02
			at.call(0, Vector3(-0.2, 0.88, -0.2), Vector2.ZERO)
			at.call(1, Vector3(-0.2, 0.86, -0.22), Vector2.ZERO)
			off["chest"] = Vector3(-0.08, 0, sh) * k
			off["head"] = Vector3(-0.1, 0, sh * 2.0) * k
			set_face.call({"eyes": "squeeze", "mouth": "teeth", "brow_a": -0.8})
		"fan":
			var f := sin(t * 14.0)
			at.call(1, Vector3(0.18, 1.18, -0.36), Vector2(-0.4 + f * 0.4, 0.5))
			off["head"] = Vector3(0.1, 0, -0.08) * k
			set_face.call({"eyes": "closed", "mouth": "open", "open": 0.4, "sweat": 1.0})
		"hold_hat":
			at.call(1, Vector3(0.12, 1.46, -0.12), Vector2(0.3, 0))
			off["head"] = Vector3(-0.12, 0, 0.08) * k
			off["chest"] = Vector3(-0.08, 0, 0) * k
			set_face.call({"eyes": "squeeze", "mouth": "o", "brow_a": 0.3})
		"shade_eyes":
			at.call(1, Vector3(0.08, 1.32, -0.34), Vector2(-1.2, 0))
			off["head"] = look * 0.6 * k + Vector3(0.05, 0, 0) * k
			set_face.call({"eyes": "sclera", "lid": 0.5, "mouth": "flat", "brow_a": 0.4})
		"awe_sky":
			off["head"] = Vector3(0.75, look.y * 0.4, 0) * k
			off["chest"] = Vector3(0.12, 0, 0) * k
			at.call(0, Vector3(0.1, 0.9, -0.28), Vector2.ZERO)
			at.call(1, Vector3(0.1, 0.9, -0.28), Vector2.ZERO)
			set_face.call({"eyes": "star" if t > 0.8 else "wide", "mouth": "o", "blush": 0.4})
			if once.call("b", 0.9):
				sc.bubble("sparkle", 1.4, 0.4)
		"shooting_star":
			off["head"] = look * k
			var reach := SHOULDER_R + dir * 0.42 if dir != Vector3.ZERO else Vector3(0.2, 1.3, -0.3)
			if t > 0.25:
				at.call(1, reach, Vector2.ZERO)
			set_face.call({"eyes": "star" if t > 0.4 else "wide", "mouth": "grin" if t > 0.6 else "o", "brow_r": 1.0})
			if once.call("b", 0.2):
				sc.bubble("exclaim", 1.2, 0.5)
		"rainbow":
			off["head"] = look * 0.8 * k
			if dir != Vector3.ZERO:
				at.call(1, SHOULDER_R + dir * 0.42, Vector2.ZERO)
			set_face.call({"eyes": "happy", "mouth": "grin", "blush": 0.4})
			if once.call("b", 0.6):
				sc.bubble("heart", 1.3, 0.5, 0.8)
		"flinch":
			var j := 1.0 - smoothstep(0.0, 0.5, t)
			off["head"] = (look * 0.7 - Vector3(0.1 * j, 0, 0)) * k
			off["chest"] = Vector3(-0.1 * j, 0, 0) * k
			off["rig"] = Vector3(0, -0.03 * j, 0) * k
			set_face.call({"eyes": "wide", "mouth": "o", "brow_r": 1.0})
		"butterfly":
			# something on the hat: cross-eyed, very still, then a giggle
			off["head"] = Vector3(0.25, 0, 0) * k
			sc._pupil = Vector2(0.0, 0.8)
			set_face.call({"eyes": "sclera", "mouth": "o" if t < 1.8 else "grin", "blush": 0.7, "brow_r": 0.8})
			if once.call("b", 1.8):
				sc.bubble("heart", 1.1, 0.4, 0.8)
		"shh":
			at.call(1, Vector3(0.02, 1.13, -0.36), Vector2(-0.5, 0))
			off["head"] = look * 0.8 * k
			set_face.call({"eyes": "sclera", "mouth": "o", "brow_r": 0.5})
			if once.call("b", 0.3):
				sc.bubble("dots", 1.4, 0.5)
		"freeze":
			off["head"] = look * k
			to.call(0, [0.4, -0.25, 0.9])
			to.call(1, [0.4, 0.25, 0.9])
			fx[0] = Vector2(0.0, -0.25 * k)
			fx[1] = fx[0]
			set_face.call({"eyes": "wide", "mouth": "o", "brow_r": 0.9})
		"whistle_back":
			off["head"] = look * 0.8 * k + Vector3(0, 0, 0.2) * k
			set_face.call({"eyes": "happy", "mouth": "o", "blush": 0.3})
			if once.call("b1", 0.4):
				sc.bubble("note", 1.0, 0.5, 0.7)
			if once.call("b2", 1.1):
				sc.bubble("note", 0.9, -0.5, 0.6)
		"warm_hands":
			var rub := sin(t * 10.0) * 0.02
			at.call(0, Vector3(0.1 + rub, 0.9, -0.42), Vector2(0.6, 0))
			at.call(1, Vector3(0.1 - rub, 0.9, -0.42), Vector2(0.6, 0))
			off["head"] = look * 0.5 * k
			set_face.call({"eyes": "happy", "mouth": "smile", "blush": 0.8})
		"shake_dry":
			var w := sin(t * 34.0) * (1.0 - smoothstep(0.9, 1.4, t))
			off["hip"] = Vector3(0, w * 0.35, w * 0.1) * k
			off["chest"] = Vector3(0, -w * 0.5, -w * 0.1) * k
			off["head"] = Vector3(0, w * 0.6, w * 0.2) * k
			to.call(0, [0.3, -0.5 - w * 0.3, 0.6])
			to.call(1, [0.3, 0.5 + w * 0.3, 0.6])
			set_face.call({"eyes": "squeeze", "mouth": "grin"})
			if once.call("b", 0.2):
				sc.bubble("drop", 1.0, -0.5, 0.7)
				sc.bubble("drop", 1.0, 0.5, 0.6)
		"dust_off":
			var pat := absf(sin(t * 16.0))
			# patting the shorts at the sides
			to.call(0, [-0.15 - pat * 0.15, -0.35, 0.3, 0.0, 0.0, 0.0])
			to.call(1, [-0.15 - pat * 0.15, 0.35, 0.3, 0.0, 0.0, 0.0])
			off["chest"] = Vector3(-0.22, 0, 0) * k
			off["head"] = Vector3(-0.3, 0, 0) * k
			set_face.call({"eyes": "sclera", "mouth": "pout", "brow_a": 0.4})
		"fist_pump":
			var up := smoothstep(0.1, 0.3, t)
			to.call(1, [lerpf(0.6, 2.2, up), 0.25, lerpf(1.6, 2.0, up), 0.0, 0.0, 0.0])
			off["chest"] = Vector3(0.08, 0, 0) * k
			set_face.call({"eyes": "squeeze", "mouth": "grin", "brow_a": 0.5})
			if once.call("b", 0.3):
				sc.bubble("sparkle", 0.9, 0.5, 0.8)
		"wonder":
			var sw := sin(t * 2.4)
			off["head"] = Vector3(0.15, sw * 0.6, 0) * k
			sc._pupil = Vector2(sw, 0.2)
			set_face.call({"eyes": "wide" if t < 1.2 else "star", "mouth": "o", "brow_r": 0.8})
			if once.call("b", 1.3):
				sc.bubble("sparkle", 1.2, 0.5)
		"yuck":
			off["head"] = Vector3(-0.3, 0, 0.15) * k
			to.call(0, [0.2, -0.6, 0.9])
			to.call(1, [0.2, 0.6, 0.9])
			set_face.call({"eyes": "squeeze", "mouth": "frown", "brow_a": -0.5})
			if once.call("b", 0.3):
				sc.bubble("anger", 0.9, 0.5, 0.6)
		"tummy":
			at.call(0, Vector3(0.05, 0.74, -0.27), Vector2.ZERO)
			at.call(1, Vector3(0.08, 0.72, -0.27), Vector2.ZERO)
			off["head"] = Vector3(-0.25, 0, 0) * k
			set_face.call({"eyes": "sclera", "mouth": "wavy", "brow_a": -0.7})
			if once.call("b", 0.4):
				sc.bubble("dots", 1.2, 0.5)
		"lick_lips":
			set_face.call({"eyes": "happy", "mouth": "tongue", "brow_r": 0.3})
			off["head"] = Vector3(0.05, 0, 0.1) * k
		"wring":
			var tw := sin(t * 8.0) * 0.15
			at.call(0, Vector3(0.1, 0.7, -0.28), Vector2(0, tw))
			at.call(1, Vector3(0.1, 0.7, -0.28), Vector2(0, -tw))
			off["chest"] = Vector3(-0.25, 0, 0) * k
			off["head"] = Vector3(-0.3, 0, 0) * k
			set_face.call({"eyes": "squeeze", "mouth": "wavy", "brow_a": -0.4})
			if once.call("b", 0.8):
				sc.bubble("drop", 1.0, 0.5, 0.7)
		"nervous":
			var g := sin(t * 3.0)
			off["head"] = Vector3(0.0, g * 0.7, 0) * k
			sc._pupil = Vector2(g, 0.0)
			at.call(0, Vector3(0.1, 0.9, -0.3), Vector2.ZERO)
			set_face.call({"eyes": "sclera", "mouth": "wavy", "brow_a": -0.7, "brow_r": 0.6, "sweat": 1.0})
		"look_up_big":
			off["head"] = (look + Vector3(0.35, 0, 0)) * k
			off["chest"] = Vector3(0.1, 0, 0) * k
			set_face.call({"eyes": "wide", "mouth": "o", "brow_r": 1.0})
			if once.call("b", 0.8):
				sc.bubble("exclaim", 1.0, 0.5)
	return off
