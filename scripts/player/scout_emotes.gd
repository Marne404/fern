class_name ScoutEmotes
extends RefCounted
## The scout's emotes: gestures and expressions (no dances). Each one has a small timeline – anticipation, the
## action, an overshoot, settling – a face that changes on the way and a symbol bubble where it fits.
## pose() changes arm/leg/face targets in place and returns offsets for rig, hips, chest and head; fx are the
## feet (lift, toe pitch) for hops and tiptoes. st: per-play state (one-shot bubbles).

## id -> [name, seconds (0 = held until you move), page of the wheel]
const EMOTES := {
	"wave": ["Wave", 2.2], "point": ["Point", 2.0], "thumbs": ["Thumbs up", 1.8], "cheer": ["Cheer", 2.0],
	"laugh": ["Laugh", 2.4], "shrug": ["Shrug", 1.8], "facepalm": ["Facepalm", 2.2], "clap": ["Clap", 2.4],
	"salute": ["Salute", 2.0], "think": ["Think", 3.0], "yawn": ["Stretch & yawn", 2.2], "cower": ["Cower", 2.2],
	"stomp": ["Stomp", 2.0], "look": ["Look around", 3.0], "sit": ["Sit down", 0.0], "lie": ["Lie down", 0.0],
	"yes": ["Yes!", 1.4], "no": ["No", 1.5], "beckon": ["Come here", 1.8], "wait": ["Wait", 1.6],
	"bow": ["Bow", 1.8], "heart": ["Heart", 2.2], "aww": ["Aww", 2.2], "cry": ["Cry", 2.6],
	"sneeze": ["Sneeze", 1.9], "starjump": ["Star jump", 1.8], "flex": ["Flex", 2.2], "gasp": ["Gasp", 1.6],
	"hungry": ["Hungry", 2.2], "wipe": ["Phew", 1.8], "peekaboo": ["Peekaboo", 2.4], "hero": ["Hero pose", 2.4],
}
const DEFAULT_WHEEL := ["wave", "point", "thumbs", "cheer", "laugh", "shrug", "facepalm", "sit",
	"yes", "no", "beckon", "wait", "heart", "aww", "cry", "lie",
	"clap", "starjump", "hero", "flex", "sneeze", "peekaboo", "think", "stomp"]

## The 24 wheel slots from the settings: an older 8-slot wheel becomes page 1, the rest from the defaults
static func wheel_slots(w: Array) -> Array:
	var out := DEFAULT_WHEEL.duplicate()
	for i in mini(w.size(), out.size()):
		if EMOTES.has(w[i]):
			out[i] = w[i]
	return out


# hand targets (chest space, right hand; mirrored for the left)
const MOUTH := Vector3(0.03, 1.12, -0.36)
const FACE := Vector3(0.1, 1.14, -0.38)
const EYES := Vector3(0.1, 1.2, -0.36)
const CHEEK := Vector3(0.2, 1.14, -0.3)
const BELLY := Vector3(0.05, 0.74, -0.27)
const HIP := Vector3(0.24, 0.68, -0.02)
const BROW := Vector3(0.12, 1.3, -0.3)


static func pose(sc: Scout, e: String, t: float, dur: float, arm: Array, leg: Array, face: Dictionary, fx: Array, st: Dictionary) -> Dictionary:
	var k := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(dur - 0.3, dur, t))
	var off := {"rig": Vector3.ZERO, "hip": Vector3.ZERO, "chest": Vector3.ZERO, "head": Vector3.ZERO}
	var to := func(i: int, target: Array) -> void:
		arm[i] = Scout._blend_arm(arm[i], target, k)
	var at := func(i: int, p: Vector3, wrist: Vector2) -> void:
		var q := Vector3(p.x * (-1.0 if i == 0 else 1.0), p.y, p.z)
		var w := wrist * Vector2(1.0, -1.0 if i == 0 else 1.0)
		arm[i] = Scout._blend_arm(arm[i], sc.reach(i, q, w), k)
	var set_face := func(d: Dictionary) -> void:
		if k > 0.3:
			for key in d:
				face[key] = d[key]
	var once := func(key: String, when: float) -> bool:
		if t >= when and not st.has(key):
			st[key] = true
			return true
		return false
	match e:
		"point":
			# a little lean back, then point hard with the whole body
			var go := smoothstep(0.15, 0.35, t)
			to.call(1, [lerpf(0.6, 1.55, go), 0.15, lerpf(1.2, 0.05, go), 0.0, 0.0, 0.0])
			off["chest"] = Vector3(lerpf(0.12, -0.12, go), -0.18 * go, 0) * k
			off["head"] = Vector3(-0.05, -0.12, 0) * k
			set_face.call({"brow_a": 0.5, "mouth": "o" if go < 0.5 else "grin", "eyes": "sclera"})
			if once.call("b", 0.35):
				sc.bubble("exclaim", 1.2, 0.5)
		"thumbs":
			var pop := smoothstep(0.1, 0.3, t)
			to.call(1, [1.1, 0.35, 1.5 + (1.0 - pop) * 0.4, 0.0, -0.3 * pop, 0.0])
			off["head"] = Vector3(sin(t * 7.0) * 0.1 * (1.0 - smoothstep(0.6, 1.2, t)), 0, 0.14) * k
			off["chest"] = Vector3(0.06, 0, -0.05) * k
			set_face.call({"eyes": "happy", "mouth": "grin", "brow_r": 0.5, "blush": 0.3})
			if once.call("b", 0.3):
				sc.bubble("sparkle", 1.1, 0.5)
		"cheer":
			# crouch, jump twice with both fists up, stars
			var hs: float = sin(t * TAU / 0.6 - 0.8)
			var jump := maxf(hs, 0.0) * 0.16 * (1.0 - smoothstep(1.3, 1.5, t))
			var dip := minf(hs, 0.0) * 0.07
			to.call(0, [2.9, -0.4 + sin(t * 9.0) * 0.12, 0.25])
			to.call(1, [2.9, 0.4 - sin(t * 9.0) * 0.12, 0.25])
			off["rig"] = Vector3(0, jump + dip, 0) * k
			off["head"] = Vector3(0.18, 0, 0) * k
			set_face.call({"eyes": "star" if jump > 0.05 else "happy", "mouth": "grin", "brow_r": 0.8})
			if once.call("b1", 0.35):
				sc.bubble("sparkle", 1.2, -0.5)
			if once.call("b2", 0.95):
				sc.bubble("sparkle", 1.2, 0.5)
		"laugh":
			# doubled over, shoulders shaking, happy tears
			var sh := absf(sin(t * 14.0))
			at.call(0, BELLY + Vector3(0.05, 0.02, 0), Vector2.ZERO)
			at.call(1, BELLY + Vector3(0.05, -0.02, 0), Vector2.ZERO)
			off["chest"] = Vector3(-0.18 + sh * 0.06, 0, sin(t * 3.0) * 0.06) * k
			off["head"] = Vector3(0.3 + sh * 0.08, 0, sin(t * 3.0) * 0.1) * k
			off["rig"] = Vector3(0, -sh * 0.025, 0) * k
			set_face.call({"eyes": "squeeze", "mouth": "grin", "blush": 0.6, "tears": 1.0 if t > 1.0 else 0.0})
			if int(t / 0.7) != int(st.get("n", -1)) and t < dur - 0.4:
				st["n"] = int(t / 0.7)
				sc.bubble("note", 0.9, 0.5 if int(t / 0.7) % 2 == 0 else -0.5, 0.7)
		"shrug":
			var up := smoothstep(0.1, 0.35, t) * (1.0 - smoothstep(1.2, 1.6, t) * 0.3)
			to.call(0, [0.35, -0.6, 1.5, 0.3, 0.6, 0.0])
			to.call(1, [0.35, 0.6, 1.5, -0.3, 0.6, 0.0])
			off["head"] = Vector3(0, 0, 0.24) * k
			off["rig"] = Vector3(0, 0.03 * up, 0) * k
			off["chest"] = Vector3(0, 0, -0.05) * k
			set_face.call({"brow_r": 0.9, "brow_a": -0.35, "mouth": "pout", "eyes": "sclera"})
			if once.call("b", 0.35):
				sc.bubble("question", 1.2, 0.5)
		"facepalm":
			at.call(1, BROW + Vector3(-0.06, 0, -0.04), Vector2(-0.6, 0))
			off["head"] = Vector3(-0.3, 0.12, 0) * k
			off["chest"] = Vector3(-0.1, 0, 0) * k
			var slump := smoothstep(0.3, 0.8, t)
			off["rig"] = Vector3(0, -0.02 * slump, 0) * k
			set_face.call({"eyes": "closed", "mouth": "wavy", "brow_a": -0.6, "sweat": 1.0})
			if once.call("b", 0.6):
				sc.bubble("drop", 1.3, -0.5)
		"clap":
			var c := 0.5 + 0.5 * sin(t * 15.0)
			at.call(0, Vector3(0.02 + c * 0.1, 1.02, -0.36), Vector2(0.0, 0.8))
			at.call(1, Vector3(0.02 + c * 0.1, 1.02, -0.36), Vector2(0.0, 0.8))
			off["rig"] = Vector3(0, -absf(sin(t * 7.5)) * 0.015, 0) * k
			set_face.call({"eyes": "happy", "mouth": "grin", "brow_r": 0.5, "blush": 0.4})
			if once.call("b", 0.8):
				sc.bubble("sparkle", 1.0, 0.4)
		"salute":
			var snap := smoothstep(0.1, 0.25, t)
			at.call(1, BROW + Vector3(0.06, 0.02, 0.02), Vector2(0.0, -0.4))
			off["chest"] = Vector3(0.12 * snap, 0, 0) * k
			off["head"] = Vector3(0.08, 0, 0) * k
			off["rig"] = Vector3(0, 0.02 * snap, 0) * k
			fx[0] = Vector2(0.0, -0.2 * snap * k)
			fx[1] = fx[0]
			set_face.call({"brow_a": 0.6, "mouth": "flat", "eyes": "sclera"})
		"think":
			at.call(1, Vector3(0.05, 1.07, -0.34), Vector2(-0.4, 0))
			at.call(0, Vector3(0.05, 0.82, -0.26), Vector2.ZERO)
			off["head"] = Vector3(0.18, 0.1, -0.2) * k
			sc._pupil = Vector2(0.4, 0.6)
			set_face.call({"brow_r": 0.4, "brow_a": -0.3, "mouth": "pout", "eyes": "sclera"})
			if once.call("b1", 0.3):
				sc.bubble("dots", 1.3, 0.5)
			if once.call("b2", 1.8):
				sc.bubble("question", 1.1, 0.5)
		"cower":
			to.call(0, [2.6, -0.3, 1.9])
			to.call(1, [2.6, 0.3, 1.9])
			off["rig"] = Vector3(0, -0.2, 0) * k
			off["chest"] = Vector3(-0.22, 0, sin(t * 40.0) * 0.025) * k
			off["head"] = Vector3(-0.12, 0, 0) * k
			set_face.call({"eyes": "teary", "mouth": "wavy", "brow_r": 1.0, "brow_a": -0.8})
			if once.call("b", 0.15):
				sc.bubble("exclaim", 1.0, 0.5, 1.2)
		"stomp":
			for i in 2:
				var sp: float = maxf(sin(t * 8.0 + i * PI), 0.0)
				fx[i] = Vector2(sp * 0.14 * k, sp * 0.2 * k)
			to.call(0, [-0.25, -0.3, 0.1])
			to.call(1, [-0.25, 0.3, 0.1])
			off["rig"] = Vector3(0, absf(sin(t * 8.0)) * 0.03, 0) * k
			off["chest"] = Vector3(-0.1, 0, 0) * k
			set_face.call({"brow_a": 1.0, "mouth": "teeth", "eyes": "sclera", "blush": 0.8})
			if once.call("b", 0.2):
				sc.bubble("anger", 1.6, 0.5)
		"look":
			at.call(1, EYES + Vector3(0.06, 0.05, 0.02), Vector2(-0.3, 0.0))
			off["head"] = Vector3(0.1, sin(t * 1.8) * 0.9, 0) * k
			sc._pupil = Vector2(sin(t * 1.8), 0.1)
			set_face.call({"brow_r": 0.5, "eyes": "sclera", "mouth": "o"})
			if once.call("b", dur - 0.9):
				sc.bubble("question", 0.9, 0.5)
		# ------------------------------------------------ new
		"yes":
			var nod: float = sin(t * TAU / 0.45) * (1.0 - smoothstep(1.0, 1.3, t))
			off["head"] = Vector3(0.22 * nod, 0, 0) * k
			off["chest"] = Vector3(0.04 * nod, 0, 0) * k
			to.call(1, [0.4, 0.15, 1.0, 0.0, 0.0, 0.0])
			set_face.call({"eyes": "happy", "mouth": "grin", "brow_r": 0.4})
		"no":
			var shake: float = sin(t * TAU / 0.4) * (1.0 - smoothstep(1.0, 1.4, t))
			off["head"] = Vector3(0, 0.35 * shake, 0) * k
			to.call(1, [0.9, 0.1, 1.6, 0.4, 0.0, sin(t * TAU / 0.4) * 0.5])
			set_face.call({"eyes": "squeeze", "mouth": "pout", "brow_a": 0.4})
		"beckon":
			var curl := 0.5 + 0.5 * sin(t * TAU / 0.45)
			to.call(1, [1.2, 0.1, 1.2 + curl * 0.6, 0.3, -0.6 * curl, 0.0])
			off["chest"] = Vector3(-0.05, 0.1, 0) * k
			off["head"] = Vector3(-0.05, 0, 0.12) * k
			set_face.call({"eyes": "happy", "mouth": "cheeky", "brow_r": 0.4})
		"wait":
			# palm out: stop!
			var push := smoothstep(0.08, 0.22, t)
			to.call(1, [1.5, 0.05, 0.25 + (1.0 - push) * 0.8, 0.0, -1.4 * push, 0.0])
			off["chest"] = Vector3(0.08 * push, 0, 0) * k
			off["head"] = Vector3(0.05, 0, 0) * k
			set_face.call({"eyes": "sclera", "mouth": "o", "brow_r": 0.6, "brow_a": 0.2})
			if once.call("b", 0.25):
				sc.bubble("exclaim", 1.1, 0.5)
		"bow":
			var down := smoothstep(0.1, 0.5, t) * (1.0 - smoothstep(1.2, 1.6, t))
			off["hip"] = Vector3(-0.35 * down, 0, 0) * k
			off["chest"] = Vector3(-0.35 * down, 0, 0) * k
			off["head"] = Vector3(-0.2 * down, 0, 0) * k
			at.call(0, BELLY + Vector3(0.02, 0.0, 0), Vector2.ZERO)
			to.call(1, [-0.15, 0.12, 0.2, 0.0, 0.0, 0.0])
			set_face.call({"eyes": "closed", "mouth": "smile", "blush": 0.4})
		"heart":
			# a hand heart in front of the chest (the arms are too short for one over the head)
			at.call(0, Vector3(0.035, 1.0, -0.4), Vector2(-0.5, 0.9))
			at.call(1, Vector3(0.035, 1.0, -0.4), Vector2(-0.5, 0.9))
			off["head"] = Vector3(0.05, 0, sin(t * 3.0) * 0.1) * k
			off["chest"] = Vector3(0, 0, sin(t * 3.0) * 0.04) * k
			set_face.call({"eyes": "heart", "mouth": "grin", "blush": 0.9})
			if once.call("b1", 0.4):
				sc.bubble("heart", 1.3, -0.4)
			if once.call("b2", 1.1):
				sc.bubble("heart", 1.0, 0.45, 0.7)
		"aww":
			at.call(0, CHEEK, Vector2(-0.3, 0))
			at.call(1, CHEEK, Vector2(-0.3, 0))
			var sway: float = sin(t * 3.5)
			off["head"] = Vector3(0.05, 0, sway * 0.18) * k
			off["chest"] = Vector3(0, 0, sway * 0.06) * k
			off["rig"] = Vector3(sway * 0.015, 0, 0) * k
			fx[0] = Vector2(0.0, -0.2 * k)
			fx[1] = fx[0]
			set_face.call({"eyes": "happy", "mouth": "o", "blush": 1.0})
			if once.call("b", 0.5):
				sc.bubble("heart", 1.3, 0.4, 0.8)
		"cry":
			var sob := absf(sin(t * 9.0))
			at.call(0, EYES + Vector3(-0.02, -0.02, 0), Vector2(-0.4, 0))
			at.call(1, EYES + Vector3(-0.02, -0.02, 0), Vector2(-0.4, 0))
			off["chest"] = Vector3(-0.1 + sob * 0.05, 0, 0) * k
			off["head"] = Vector3(-0.12 + sob * 0.05, 0, 0) * k
			off["rig"] = Vector3(0, -sob * 0.02, 0) * k
			set_face.call({"eyes": "teary", "mouth": "wavy", "brow_a": -0.8, "brow_r": 0.4, "tears": 1.0})
			if once.call("b", 0.4):
				sc.bubble("drop", 1.2, 0.5)
		"sneeze":
			# ah… ah… AH-CHOO! – and a sniff
			var build := smoothstep(0.0, 0.9, t)
			var choo := smoothstep(0.95, 1.05, t) * (1.0 - smoothstep(1.2, 1.7, t))
			at.call(1, MOUTH + Vector3(0.0, 0.02, 0), Vector2(-0.3, 0))
			off["head"] = Vector3(0.28 * build * (1.0 - choo) - 0.45 * choo, 0, 0) * k
			off["chest"] = Vector3(0.1 * build * (1.0 - choo) - 0.28 * choo, 0, 0) * k
			off["rig"] = Vector3(0, -0.05 * choo, 0) * k
			if t < 0.95:
				set_face.call({"eyes": "squeeze" if t > 0.5 else "sclera", "mouth": "o", "brow_r": 0.8 * build, "brow_a": -0.4})
			else:
				set_face.call({"eyes": "squeeze", "mouth": "open", "open": 1.0 if choo > 0.3 else 0.3, "blush": 0.8})
			if once.call("b", 1.0):
				sc.bubble("exclaim", 0.9, 0.5, 1.2)
				sc.bubble("drop", 0.9, -0.5, 0.6)
		"starjump":
			# a jumping jack: arms and legs spread in the air
			var hs: float = sin(t * TAU / 0.6 - 0.8)
			var air := maxf(hs, 0.0)
			off["rig"] = Vector3(0, air * 0.2 + minf(hs, 0.0) * 0.06, 0) * k * (1.0 - smoothstep(1.3, 1.6, t))
			to.call(0, [0.2, -2.3 * air - 0.2, 0.2])
			to.call(1, [0.2, 2.3 * air + 0.2, 0.2])
			fx[0] = Vector2(air * 0.2, 0.3 * air) * k
			fx[1] = fx[0]
			off["hip"] = Vector3(0, 0, 0) * k
			set_face.call({"eyes": "star" if air > 0.5 else "happy", "mouth": "grin", "brow_r": 0.9})
			if once.call("b", 0.45):
				sc.bubble("sparkle", 1.1, 0.5)
		"flex":
			var pump := 0.5 + 0.5 * sin(t * TAU / 0.7)
			for i in 2:
				var sd := -1.0 if i == 0 else 1.0
				arm[i] = Scout._blend_arm(arm[i], sc.reach(i, Vector3(sd * 0.36, 1.2 + pump * 0.03, -0.02), Vector2.ZERO, true), k)
			off["chest"] = Vector3(0.1, 0, 0) * k
			off["rig"] = Vector3(0, -0.03 + pump * 0.01, 0) * k
			set_face.call({"eyes": "squeeze" if pump > 0.7 else "sclera", "mouth": "teeth" if pump > 0.7 else "grin", "brow_a": 0.7, "blush": 0.5})
			if once.call("b", 0.5):
				sc.bubble("sparkle", 1.2, 0.5)
		"gasp":
			at.call(0, MOUTH + Vector3(0.05, 0.0, -0.02), Vector2(-0.4, 0))
			at.call(1, MOUTH + Vector3(0.05, 0.0, -0.02), Vector2(-0.4, 0))
			var jolt := smoothstep(0.0, 0.12, t)
			off["chest"] = Vector3(0.12 * jolt, 0, 0) * k
			off["head"] = Vector3(0.15 * jolt, 0, 0) * k
			off["rig"] = Vector3(0, 0.03 * jolt, 0) * k
			fx[0] = Vector2(0.0, -0.25 * jolt * k)
			fx[1] = fx[0]
			set_face.call({"eyes": "wide", "mouth": "o", "brow_r": 1.0})
			if once.call("b", 0.1):
				sc.bubble("exclaim", 1.2, 0.5, 1.2)
		"hungry":
			var rub: float = sin(t * 7.0)
			at.call(0, BELLY + Vector3(rub * 0.04, 0.02, 0), Vector2.ZERO)
			at.call(1, BELLY + Vector3(-rub * 0.04, -0.02, 0), Vector2.ZERO)
			off["head"] = Vector3(-0.15, 0, sin(t * 2.0) * 0.1) * k
			off["chest"] = Vector3(-0.08, 0, 0) * k
			set_face.call({"eyes": "teary" if t > 1.2 else "sclera", "mouth": "wavy", "brow_a": -0.7})
			if once.call("b", 0.6):
				sc.bubble("dots", 1.2, 0.5)
		"wipe":
			var sweep := smoothstep(0.3, 0.9, t)
			at.call(1, BROW + Vector3(lerpf(0.1, -0.1, sweep), 0.0, -0.02), Vector2(-0.6, 0))
			off["head"] = Vector3(0.1, 0, -0.1) * k
			off["chest"] = Vector3(-0.05, 0, 0) * k
			set_face.call({"eyes": "closed" if t > 0.9 else "happy", "mouth": "open" if t > 0.9 else "wavy", "open": 0.5, "sweat": 1.0 - sweep})
			if once.call("b", 1.0):
				sc.bubble("sparkle", 0.9, 0.5, 0.7)
		"peekaboo":
			# hide the face… and pop out
			var hide := smoothstep(0.05, 0.3, t) * (1.0 - smoothstep(1.2, 1.35, t))
			var pop := smoothstep(1.2, 1.35, t)
			for i in 2:
				arm[i] = Scout._blend_arm(arm[i], sc.reach(i, Vector3((-1.0 if i == 0 else 1.0) * 0.07, 1.18, -0.36), Vector2(-0.5, 0)), k * hide)
				arm[i] = Scout._blend_arm(arm[i], [1.5, (-1.0 if i == 0 else 1.0) * 1.0, 0.4], k * pop)
			off["chest"] = Vector3(-0.1 * hide + 0.1 * pop, 0, 0) * k
			off["rig"] = Vector3(0, -0.04 * hide + 0.04 * pop, 0) * k
			set_face.call({"eyes": "closed" if pop < 0.5 else "star", "mouth": "smile" if pop < 0.5 else "grin", "blush": 0.6 * pop})
			if once.call("b", 1.3):
				sc.bubble("exclaim", 1.0, 0.5)
		"hero":
			# hands on the hips, chest out, chin up, a sparkle
			at.call(0, HIP, Vector2(0.4, 0))
			at.call(1, HIP, Vector2(0.4, 0))
			off["chest"] = Vector3(0.14, 0, 0) * k
			off["head"] = Vector3(0.22, -0.15, 0) * k
			off["rig"] = Vector3(0, 0.01, 0) * k
			set_face.call({"eyes": "sclera", "mouth": "grin", "brow_a": 0.5, "brow_r": 0.3})
			if once.call("b", 0.4):
				sc.bubble("sparkle", 1.5, 0.5, 1.1)
	return off
