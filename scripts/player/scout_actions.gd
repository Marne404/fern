class_name ScoutActions
extends RefCounted
## What the scout does with an item: eating, drinking, taking a photo, looking through binoculars, playing the
## harmonica, whistling, squeezing the rubber chicken, spraying the water pistol, throwing a stone, putting on
## clothes or a bandage, lighting and sitting at a campfire, holding a kite string.
## Upper-body layers (you can walk meanwhile): they change the arm targets and the face and return offsets for
## the head and chest. The item shows in the right hand for the moment (ScoutGear.show_temp).

## kind -> [seconds (0 = until stopped), item shown in the hand ("" = the one given), both hands]
const KINDS := {
	"eat": [1.7, "", false], "drink": [1.8, "", false], "photo": [1.4, "kamera", true], "binoculars": [0.0, "fernglas", true],
	"harmonica": [3.2, "mundharmonika", true], "whistle": [1.0, "pfeife", false], "squeeze": [1.1, "gummihuhn", false],
	"spray": [1.6, "wasserpistole", false], "throw": [0.9, "", false], "apply": [1.4, "", false], "dress": [1.0, "", false],
	"light": [1.8, "streichhoelzer", false], "roast": [4.0, "roast_stick", false], "kite": [0.0, "", false],
	"read": [1.6, "", false],
}


## Hand targets in chest space (the model's rest coordinates; x = right for the right hand)
const MOUTH := Vector3(0.03, 1.12, -0.36)
const FACE := Vector3(0.1, 1.12, -0.38)
const CHEST := Vector3(0.06, 0.88, -0.3)
const HEAD_SIDE := Vector3(0.27, 1.3, -0.06)
const FORWARD := Vector3(0.1, 0.98, -0.42)
const UP := Vector3(0.22, 1.36, -0.1)


static func duration(kind: String) -> float:
	return KINDS[kind][0] if KINDS.has(kind) else 1.0


## Changes arm / face; returns {"head": Vector3, "chest": Vector3, "rig": Vector3}. st: per-action state
## (for one-shot things like bubbles and sounds).
static func pose(sc: Scout, kind: String, t: float, dur: float, arm: Array, face: Dictionary, st: Dictionary) -> Dictionary:
	var off := {"head": Vector3.ZERO, "chest": Vector3.ZERO, "rig": Vector3.ZERO}
	var k := smoothstep(0.0, 0.22, t) * (1.0 if dur <= 0.0 else (1.0 - smoothstep(dur - 0.25, dur, t)))
	var to := func(i: int, target: Array) -> void:
		arm[i] = Scout._blend_arm(arm[i], target, k)
	# a hand to a point (mirrored for the left hand), with a wrist tilt
	var at := func(i: int, p: Vector3, wrist: Vector2) -> void:
		var q := Vector3(p.x * (-1.0 if i == 0 else 1.0), p.y, p.z)
		arm[i] = Scout._blend_arm(arm[i], sc.reach(i, q, wrist), k)
	var once := func(key: String, at: float) -> bool:
		if t >= at and not st.has(key):
			st[key] = true
			return true
		return false
	match kind:
		"eat":
			# three bites: hand to the mouth, chew, a happy little blush
			var bite := absf(sin(t * TAU / 0.55))
			at.call(1, MOUTH + Vector3(0, -bite * 0.07, -bite * 0.04), Vector2(-0.3, 0))
			off["head"] = Vector3(-0.08 + bite * 0.06, 0, 0) * k
			if k > 0.3:
				face["mouth"] = "open" if bite > 0.5 else "pout"
				face["open"] = 0.35
				face["blush"] = 0.5 * smoothstep(0.8, 1.4, t)
				if t > dur * 0.75:
					face["eyes"] = "happy"
					face["mouth"] = "smile"
			if once.call("heart", dur * 0.72) and randf() < 0.5:
				sc.bubble("heart", 1.1, 0.4, 0.8)
		"drink":
			# bottle up, head back, gulp gulp, "ahh"
			var up := smoothstep(0.1, 0.45, t) * (1.0 - smoothstep(1.2, 1.5, t))
			at.call(1, MOUTH + Vector3(0, 0.05 * up, 0.02), Vector2(-1.1 * up, 0))
			off["head"] = Vector3(0.45 * up, 0, 0) * k
			off["chest"] = Vector3(0.1 * up, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "closed" if up > 0.5 else "happy"
				face["mouth"] = "o" if up > 0.5 else ("open" if t > 1.2 else "smile")
				face["open"] = 0.6
			if once.call("ahh", 1.3):
				sc.bubble("sparkle", 0.9, 0.3, 0.7)
		"photo":
			# camera to the eye, one eye squeezed, click, flash
			at.call(1, FACE, Vector2(-0.5, 0))
			at.call(0, FACE, Vector2(-0.5, 0))
			off["head"] = Vector3(-0.05, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "squeeze" if t < 0.9 else "happy"
				face["mouth"] = "flat" if t < 0.9 else "grin"
			if once.call("snap", 0.7):
				sc.bubble("sparkle", 0.8, 0.5, 0.7)
		"binoculars":
			at.call(1, FACE + Vector3(-0.03, 0.02, 0), Vector2(-0.5, 0))
			at.call(0, FACE + Vector3(-0.03, 0.02, 0), Vector2(-0.5, 0))
			off["head"] = Vector3(0.05, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "closed"
				face["mouth"] = "o"
		"harmonica":
			# both hands at the mouth, swaying, notes rise
			var sway := sin(t * 5.0)
			at.call(1, MOUTH + Vector3(0.05 + sway * 0.02, 0, 0), Vector2(-0.3, 0.3))
			at.call(0, MOUTH + Vector3(0.05 - sway * 0.02, 0, 0), Vector2(-0.3, -0.3))
			off["head"] = Vector3(0.05, sway * 0.12, sway * 0.12) * k
			off["chest"] = Vector3(0, 0, sway * 0.05) * k
			if k > 0.3:
				face["eyes"] = "happy"
				face["mouth"] = "o"
				face["blush"] = 0.4
			if int(t / 0.55) != int(st.get("n", -1)):
				st["n"] = int(t / 0.55)
				if t > 0.3 and t < dur - 0.3:
					sc.bubble("note", 1.3, 0.5 if int(t / 0.55) % 2 == 0 else -0.5, 0.75)
		"whistle":
			at.call(1, MOUTH, Vector2(-0.3, 0))
			off["head"] = Vector3(-0.1, 0, 0) * k
			off["chest"] = Vector3(-0.08 * smoothstep(0.2, 0.4, t), 0, 0) * k
			if k > 0.3:
				face["eyes"] = "squeeze"
				face["mouth"] = "o"
				face["blush"] = 0.8
			if once.call("fweet", 0.3):
				sc.bubble("exclaim", 0.9, 0.5, 0.9)
		"squeeze":
			# chicken held out, squeezed twice
			var sq := absf(sin(t * TAU / 0.5))
			at.call(1, FORWARD + Vector3(0, -0.06 - sq * 0.03, 0), Vector2(0.3, 0))
			off["chest"] = Vector3(-0.05, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "wide" if sq > 0.6 else "happy"
				face["mouth"] = "grin"
			sc.gear.squash_temp(1.0 - sq * 0.35)
			if once.call("squeak", 0.25):
				sc.bubble("exclaim", 0.8, 0.5, 0.8)
		"spray":
			var pump := absf(sin(t * TAU / 0.35))
			at.call(1, FORWARD + Vector3(0.02, 0.02 * pump, -0.03), Vector2(0.4, 0))
			off["chest"] = Vector3(0, -0.12, 0) * k
			if k > 0.3:
				face["eyes"] = "squeeze" if pump > 0.7 else "sclera"
				face["mouth"] = "cheeky"
		"throw":
			# wind-up behind, sidearm throw, follow-through
			var wind := smoothstep(0.0, 0.35, t)
			var go := smoothstep(0.35, 0.5, t)
			to.call(1, [lerpf(lerpf(0.2, -0.9, wind), 1.4, go), lerpf(0.7, 0.9, wind), 0.4, lerpf(0.3, -0.6, go), 0.0, 0.0])
			off["chest"] = Vector3(0, lerpf(0.35 * wind, -0.45, go), 0) * k
			if k > 0.3:
				face["eyes"] = "sclera" if go < 0.5 else "happy"
				face["mouth"] = "flat" if go < 0.5 else "o"
		"apply":
			# a plaster on the arm / cream on the cheeks: rub rub
			var rub := sin(t * 18.0) * 0.12
			at.call(1, Vector3(-0.17, 0.84 + rub * 0.3, -0.24), Vector2.ZERO)
			at.call(0, Vector3(0.1, 0.82, -0.28), Vector2.ZERO)
			off["head"] = Vector3(0.25, 0.2, 0) * k
			if k > 0.3:
				face["mouth"] = "pout" if t < dur * 0.6 else "smile"
				face["eyes"] = "sclera" if t < dur * 0.6 else "happy"
		"dress":
			# both hands to the head (a hat) or the chest (a jacket), a little tug
			var tug := sin(t * TAU / 0.5) * 0.1
			at.call(1, HEAD_SIDE + Vector3(0, tug * 0.3, 0), Vector2.ZERO)
			at.call(0, HEAD_SIDE - Vector3(0, tug * 0.3, 0), Vector2.ZERO)
			off["head"] = Vector3(0.1, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "happy"
				face["mouth"] = "grin" if t > dur * 0.5 else "o"
		"light":
			# crouched, striking a match with a little frown of concentration, then the flame
			var strike := absf(sin(t * TAU / 0.4)) * (1.0 - smoothstep(0.9, 1.1, t))
			at.call(1, Vector3(0.06, 0.74 + strike * 0.05, -0.36), Vector2(0.3, 0))
			at.call(0, Vector3(0.04, 0.72, -0.33), Vector2(0.3, 0))
			off["rig"] = Vector3(0, -0.14, 0) * k
			off["chest"] = Vector3(-0.3, 0, 0) * k
			off["head"] = Vector3(-0.2, 0, 0) * k
			if k > 0.3:
				face["mouth"] = "tongue" if t < 1.1 else "grin"
				face["eyes"] = "sclera" if t < 1.1 else "star"
			if once.call("flame", 1.1):
				sc.bubble("sparkle", 1.0, 0.0, 0.9)
		"roast":
			# the stick held towards the fire, turned slowly
			at.call(1, Vector3(0.12, 0.92, -0.4), Vector2(0.9, sin(t * 2.5) * 0.6))
			off["head"] = Vector3(-0.08, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "sclera" if t < dur * 0.7 else "star"
				face["mouth"] = "o" if t < dur * 0.7 else "grin"
				face["blush"] = 0.3
			if once.call("done", dur * 0.72):
				sc.bubble("heart", 1.2, 0.4, 0.9)
		"kite":
			# the string in the hand, arm up, looking up happily
			at.call(1, UP + Vector3(0, sin(t * 2.0) * 0.02, 0), Vector2.ZERO)
			off["head"] = Vector3(0.35, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "happy"
				face["mouth"] = "open"
				face["open"] = 0.5
		"read":
			# unfold the map / flip a page
			var flip := sin(t * TAU / 0.8)
			at.call(1, CHEST + Vector3(0.02, flip * 0.02, 0), Vector2(0.2, 0))
			at.call(0, CHEST - Vector3(-0.02, flip * 0.02, 0), Vector2(0.2, 0))
			off["head"] = Vector3(0.4, 0, 0) * k
			if k > 0.3:
				face["eyes"] = "sclera"
				face["mouth"] = "o"
			if once.call("hmm", 0.5):
				sc.bubble("question" if randf() < 0.5 else "dots", 1.0, 0.4, 0.8)
	return off
