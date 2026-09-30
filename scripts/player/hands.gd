class_name Hands
extends Node
## The scout's two hands, one per mouse button (left / right; LT / RT on a controller).
## A click punches forward; holding stretches the hand out, and the first thing it touches it grips until the button
## is let go. What a grip does depends on the thing (see Grab kinds in the round-17 plan):
##   loose     – light things (items, pebbles): lifted into the hand, carried, dropped or flung when released
##   heavy     – logs: dragged towards the hand; speed from the strength on it (all hands of all holders) against its
##               weight, lifted when the lift capacity reaches its weight; you can't walk away faster than it moves
##   tear      – grass, berry bunches, mushrooms: you are held back until the stretch tears it off
##   anchor    – trees, rocks, fences, posts: you hold on and can't walk further than your arm reaches
## A hand that holds an item from the backpack uses it instead (click), binoculars as long as the button is held.

signal gripped(side: int, kind: String)
signal released(side: int)

const GRAB_LAYER := 1 << 5          # areas of tearable things (berry bunches, mushrooms …)
const REACH := 0.72                 # shoulder to palm
const CLICK := 0.2                  # shorter = a punch
const PUNCH_TIME := 0.32
const STRENGTH := 120.0             # pulling force of one hand (N)
const LIFT := 15.0                  # lift capacity of one hand (kg)
const LOOSE_MAX := 8.0              # heavier loose rigid bodies are dragged instead
const MY_ID := 0                    # multiplayer: the peer id of this player

var p: Wanderer
## per hand: {down, t, mode ("idle", "punch", "reach", "hold", "item"), punch_t, ext (0..1), grip {}, pos (world), fist}
var h: Array[Dictionary] = []
## binoculars held up with a hand button
var zooming := false
## for the HUD: something grippable in reach (kind) and the tension of a tear (0..1)
var hover := ""
var tension := 0.0
## tests: a fixed world point the hands aim at (INF = the crosshair)
var aim_override := Vector3.INF
var _kg := 0.0
var _probe_t := 0.0
var _hover := ""


func setup(owner_player: Wanderer) -> void:
	p = owner_player
	name = "Hands"
	for i in 2:
		h.append({"down": false, "t": 0.0, "mode": "idle", "punch_t": 0.0, "ext": 0.0, "grip": {}, "pos": Vector3.ZERO, "fist": false,
			"vel": Vector3.ZERO})


## Where the busy hands are (average), INF when both are idle – the body turns towards it
func busy_point() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for i in 2:
		if h[i]["mode"] in ["reach", "hold", "punch"]:
			sum += _grip_world(h[i]["grip"]) if h[i]["mode"] == "hold" else _aim_point(i)
			n += 1
	return sum / n if n > 0 else Vector3.INF


func holding(i: int) -> bool:
	return h[i]["mode"] == "hold"


func grip_kind(i: int) -> String:
	return h[i]["grip"].get("kind", "") if holding(i) else ""


# ================================================================ input

func press(i: int) -> void:
	var s := h[i]
	s["down"] = true
	s["t"] = 0.0
	var item := p.held_item("L" if i == 0 else "R")
	s["mode"] = "item" if not item.is_empty() else "wait"


func release(i: int) -> void:
	var s := h[i]
	if not s["down"]:
		return
	s["down"] = false
	match s["mode"]:
		"item":
			var item := p.held_item("L" if i == 0 else "R")
			if s["t"] < CLICK and not item.is_empty() and item["id"] != "fernglas":
				p.use_item(item)
			s["mode"] = "idle"
		"wait":
			_punch(i)
		"reach":
			s["mode"] = "idle"
		"hold":
			_let_go(i)


func release_all() -> void:
	for i in 2:
		if h[i]["mode"] == "hold":
			_let_go(i)
		h[i]["down"] = false
		h[i]["mode"] = "idle"


# ================================================================ per frame (physics)

func _shoulder(i: int) -> Vector3:
	if p.scout and p.scout._arms.size() == 2:
		return (p.scout._arms[i][0] as Node3D).global_position
	return p.global_position + Vector3(0.2 * (i * 2 - 1), 1.1, 0)


## How far a hand gets towards a point: bending down (or crouching) brings low things within reach
func reach_len(sh: Vector3, aim: Vector3) -> float:
	return REACH + clampf(sh.y - aim.y - 0.15, 0.0, 0.95)


## Where the hands aim: the point under the crosshair, or straight ahead
func _aim_point(i: int, centered := false) -> Vector3:
	# the two hands a hand's width apart (a punch goes straight for the crosshair)
	var side := Vector3.ZERO if centered else p.global_basis.x * (0.07 * (i * 2 - 1))
	if aim_override != Vector3.INF:
		return aim_override + side
	var cam := p.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * (8.0 if p.third_person else 3.0), 1 | (1 << (WorldItem.LAYER - 1)) | GRAB_LAYER)
	q.collide_with_areas = true
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	var sh := _shoulder(i)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		# in third person the camera sees things behind the scout too: only what lies ahead counts
		if (hp - sh).dot(-p.global_basis.z) > -0.1:
			return hp + side
	return sh + dir * REACH


func physics(delta: float) -> void:
	zooming = false
	tension = 0.0
	var carry := 0.0
	_kg = 0.0
	for i in 2:
		var s := h[i]
		if s["down"]:
			s["t"] += delta
		match s["mode"]:
			"item":
				var item := p.held_item("L" if i == 0 else "R")
				if not item.is_empty() and item["id"] == "fernglas" and s["t"] >= CLICK:
					zooming = true
			"wait":
				if s["t"] >= CLICK:
					s["mode"] = "reach"
					s["ext"] = 0.0
			"reach":
				_reach(i, delta)
			"hold":
				carry += _hold(i, delta)
			"punch":
				s["punch_t"] += delta
				var k: float = s["punch_t"] / PUNCH_TIME
				s["ext"] = sin(clampf(k, 0.0, 1.0) * PI)
				if s["punch_t"] >= 0.12 and not s.get("hit", false):
					s["hit"] = true
					_punch_hit(i)
				if s["punch_t"] >= PUNCH_TIME:
					s["mode"] = "idle"
					s["ext"] = 0.0
			_:
				s["ext"] = move_toward(s["ext"], 0.0, delta * 4.0)
		# the hand's world position (for the looks and the checks)
		var sh := _shoulder(i)
		var prev: Vector3 = s["pos"]
		if s["mode"] == "hold":
			s["pos"] = _grip_world(s["grip"])
		elif s["mode"] in ["reach", "punch"]:
			var aim := _aim_point(i)
			s["pos"] = sh + (aim - sh).limit_length(reach_len(sh, aim) * (0.35 + 0.65 * float(s["ext"])))
		else:
			s["pos"] = sh
		s["vel"] = (s["pos"] - prev) / maxf(delta, 1e-4)
		s["fist"] = s["mode"] == "punch"
	# what's under the crosshair, a few times a second (the grass search isn't free)
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = 0.15
		_hover = _probe_kind(_aim_point(1)) if not (holding(0) and holding(1)) else ""
	hover = _hover
	p.body.carry_block = carry
	p.body.carry_kg = _kg
	if OS.get_cmdline_user_args().has("--handlog") and Engine.get_physics_frames() % 10 == 0 and (h[0]["mode"] != "idle" or h[1]["mode"] != "idle"):
		var r: Dictionary = h[1]
		print("[Hands] t=%.1f R %s %s ext %.2f tension %.2f hand %s shoulder %s grip %s" % [Time.get_ticks_msec() / 1000.0, r["mode"], r["grip"].get("what", r["grip"].get("kind", "")),
			r["ext"], tension, (r["pos"] as Vector3).snapped(Vector3.ONE * 0.01), _shoulder(1).snapped(Vector3.ONE * 0.01), _grip_world(r["grip"]).snapped(Vector3.ONE * 0.01) if not r["grip"].is_empty() else ""])


## A stretched hand grips the first thing it touches
func _reach(i: int, delta: float) -> void:
	var s := h[i]
	s["ext"] = minf(float(s["ext"]) + delta * 4.0, 1.0)
	var pos: Vector3 = s["pos"]
	# grass only where the hand arrives (on the way it would snatch a tuft next to the stone you meant)
	var g := _grip_at(pos, i, float(s["ext"]) >= 1.0)
	if not g.is_empty():
		# how far you can move away: the arm's length when it gripped (bent down for low things)
		g["slack"] = maxf(REACH, (pos - _shoulder(i)).length()) + 0.08
		s["grip"] = g
		s["mode"] = "hold"
		_start(i, g)
		gripped.emit(i, g["kind"])


# ================================================================ finding something to grip

## What is at a point: {kind, node, local (grip point in the node's space), …} or {}
func _grip_at(pos: Vector3, i: int, ground := true) -> Dictionary:
	var space := p.get_world_3d().direct_space_state
	var sq := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.13
	sq.shape = sphere
	sq.transform = Transform3D(Basis(), pos)
	sq.collision_mask = 1 | (1 << (WorldItem.LAYER - 1)) | GRAB_LAYER
	sq.collide_with_areas = true
	sq.exclude = [p.get_rid()]
	var res := space.intersect_shape(sq, 8)
	# where exactly the hand touches solid things: the closest point on their surface (+ half a palm)
	var touch := pos
	var rest := space.get_rest_info(sq)
	if not rest.is_empty():
		touch = (rest["point"] as Vector3) + (rest["normal"] as Vector3) * 0.045
	var best := {}
	var best_pri := -1
	for r in res:
		var c: Object = r["collider"]
		var g := _classify(c, pos if c is Area3D else touch)
		if g.is_empty():
			continue
		var pri: int = {"tear": 4, "loose": 3, "heavy": 2, "anchor": 1}.get(g["kind"], 0)
		# something the other hand already holds (a berry bunch) can't be taken twice
		if g["kind"] == "tear" and _held_by_other(c, i):
			continue
		if pri > best_pri:
			best_pri = pri
			best = g
	if best.is_empty() and ground:
		best = _ground_grip(pos)
	return best


func _held_by_other(c: Object, i: int) -> bool:
	var o := h[1 - i]
	return o["mode"] == "hold" and o["grip"].get("node") == c


func _classify(c: Object, pos: Vector3) -> Dictionary:
	if c == null or not is_instance_valid(c):
		return {}
	var n := c as Node3D
	if c.has_meta("grab"):
		var d: Dictionary = (c.get_meta("grab") as Dictionary).duplicate()
		d["node"] = c
		d["local"] = n.global_transform.affine_inverse() * pos
		return d
	if c is WorldItem:
		return {"kind": "loose", "node": c, "local": Vector3.ZERO, "mass": (c as RigidBody3D).mass}
	if c is RigidBody3D:
		var rb := c as RigidBody3D
		return {"kind": "loose" if rb.mass <= LOOSE_MAX else "heavy", "node": c, "local": rb.global_transform.affine_inverse() * pos, "mass": rb.mass}
	if c is StaticBody3D:
		var sb := c as StaticBody3D
		# the ground itself is handled by _ground_grip (grass)
		if sb.collision_layer & ChunkManager.TERRAIN_LAYER:
			return {}
		return {"kind": "anchor", "node": c, "local": sb.global_transform.affine_inverse() * pos}
	return {}


## A real grass tuft under the hand: gripped by its stalks, pulled out of the ground
func _ground_grip(pos: Vector3) -> Dictionary:
	if p.world == null:
		return {}
	var gy := p.world.ground_y(pos.x, pos.z)
	if pos.y > gy + 0.35:
		return {}
	var t := p.world.grass_near(pos, 0.6)
	if t.is_empty():
		return {}
	var xf: Transform3D = t["xf"]
	var h: float = maxf((t["mmi"] as MultiMeshInstance3D).multimesh.mesh.get_aabb().end.y * xf.basis.get_scale().y, 0.1)
	return {"kind": "tear", "what": "grass", "node": null, "grass": t, "xf0": xf,
		"world": xf.origin + Vector3.UP * minf(h * 0.35, 0.18), "resist": 0.35, "stretch": 0.55, "pull": 0.12}


func _probe_kind(aim: Vector3) -> String:
	var sh := _shoulder(1)
	if aim.distance_to(sh) > reach_len(sh, aim) + 0.2:
		return ""
	var g := _grip_at(aim, 1)
	return String(g.get("what", g.get("kind", ""))) if not g.is_empty() else ""


func _grip_world(g: Dictionary) -> Vector3:
	var n = g.get("node")
	if n != null and is_instance_valid(n):
		return (n as Node3D).global_transform * (g["local"] as Vector3)
	return g.get("world", p.global_position)


# ================================================================ holding

func _start(i: int, g: Dictionary) -> void:
	match g["kind"]:
		"loose":
			var rb := g["node"] as RigidBody3D
			rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			rb.freeze = true
			rb.set_meta("held_by_hand", true)
		"heavy":
			var rb := g["node"] as RigidBody3D
			_set_holders(rb, 1)
			if not rb.has_meta("friction0") and rb.physics_material_override:
				rb.set_meta("friction0", rb.physics_material_override.friction)
				rb.physics_material_override.friction = 0.15
			rb.freeze = false
			rb.sleeping = false
		"tear":
			g["done"] = 0.0
	Sfx.play(p, "stone_click", -18.0, 1.6)


func _let_go(i: int) -> void:
	var s := h[i]
	var g: Dictionary = s["grip"]
	s["mode"] = "idle"
	s["grip"] = {}
	if g.is_empty():
		return
	var n = g.get("node")
	if g.has("grass") and is_instance_valid((g["grass"] as Dictionary)["mmi"]):
		# let go before it tore: the tuft springs back
		_grass_set(g, g["xf0"])
	match g["kind"]:
		"loose":
			if n != null and is_instance_valid(n):
				var rb := n as RigidBody3D
				rb.remove_meta("held_by_hand")
				rb.freeze = false
				# a flick of the hand throws it
				rb.linear_velocity = (s["vel"] as Vector3).limit_length(9.0) + p.velocity
				rb.sleeping = false
		"heavy":
			if n != null and is_instance_valid(n):
				var rb := n as RigidBody3D
				_set_holders(rb, -1)
				if _holders(rb) <= 0 and rb.has_meta("friction0") and rb.physics_material_override:
					rb.physics_material_override.friction = rb.get_meta("friction0")
					rb.remove_meta("friction0")
	released.emit(i)


## Multiplayer-ready: every player's hands on a body are counted there (peer id -> hands)
func _set_holders(rb: RigidBody3D, add: int) -> void:
	var d: Dictionary = rb.get_meta("holders", {})
	d[MY_ID] = maxi(int(d.get(MY_ID, 0)) + add, 0)
	if d[MY_ID] == 0:
		d.erase(MY_ID)
	rb.set_meta("holders", d)


static func _holders(rb: RigidBody3D) -> int:
	var n := 0
	var d: Dictionary = rb.get_meta("holders", {})
	for k in d:
		n += int(d[k])
	return n


## Keeps a grip; returns this hand's carry block (stamina points)
func _hold(i: int, delta: float) -> float:
	var s := h[i]
	var g: Dictionary = s["grip"]
	var n = g.get("node")
	if g.get("node") != null and not is_instance_valid(n):
		_let_go(i)
		return 0.0
	var sh := _shoulder(i)
	var gp := _grip_world(g)
	var d := gp.distance_to(sh)
	var state_f: float = [1.0, 0.8, 0.5, 0.0][p.body.state]
	match g["kind"]:
		"loose":
			var rb := n as RigidBody3D
			var aim := _aim_point(i)
			var at := sh + (aim - sh).limit_length(reach_len(sh, aim) * 0.8)
			rb.global_position = rb.global_position.lerp(at, 1.0 - exp(-20.0 * delta))
			g["local"] = Vector3.ZERO
			p.body.spend(rb.mass * 0.02 * delta)
			_kg += rb.mass
			return rb.mass * 1.5
		"heavy":
			var rb := n as RigidBody3D
			var hands := _holders(rb)
			var strength := STRENGTH * hands * state_f
			var resist := rb.mass * 9.8 * 0.5
			var ratio := clampf(strength / resist, 0.0, 1.0)
			var vmax := 1.6 * ratio * ratio
			var target := sh + (gp - sh).limit_length(REACH * 0.9)
			var v_des := ((target - gp) * 5.0).limit_length(vmax)
			var at := gp - rb.global_position
			var v_grip := rb.linear_velocity + rb.angular_velocity.cross(at)
			var f := rb.mass * (Vector3(v_des.x, 0, v_des.z) - Vector3(v_grip.x, 0, v_grip.z)) / 0.06 / maxi(hands, 1)
			rb.apply_force(f.limit_length(rb.mass * 12.0), at)
			# lifted when all hands together can hold its weight
			var share := rb.mass / maxi(hands, 1)
			var lifted := LIFT * hands >= rb.mass
			if lifted:
				var up := rb.mass * 9.8 / maxi(hands, 1) + (sh.y - 0.25 - gp.y) * 400.0 - v_grip.y * 60.0
				rb.apply_force(Vector3.UP * up, at)
			g["vmax"] = vmax
			var moving := Vector2(p.velocity.x, p.velocity.z).length() > 0.3
			p.body.spend(share * (0.06 if lifted else (0.03 if moving else 0.008)) * delta)
			_kg += share * (1.0 if lifted else 0.3)
			return share * (0.8 if lifted else 0.35)
		"tear":
			# pulling the arm back tears a little by itself, walking away much more (see constrain())
			g["done"] = float(g["done"]) + float(g.get("pull", 0.1)) * delta
			tension = maxf(tension, float(g["done"]) / float(g.get("stretch", 0.3)))
			if g.has("grass"):
				_bend_grass(g, sh, clampf(float(g["done"]) / float(g["stretch"]), 0.0, 1.0))
			if float(g["done"]) >= float(g.get("stretch", 0.3)):
				_tear(i)
			return 2.0
		"anchor":
			return 0.0
	return 0.0


## Called by the player before moving: holding on limits how far you can walk from what you hold
func constrain(vel: Vector3, delta: float) -> Vector3:
	for i in 2:
		if not holding(i):
			continue
		var g: Dictionary = h[i]["grip"]
		var sh := _shoulder(i)
		var gp := _grip_world(g)
		var away := Vector3(sh.x - gp.x, 0, sh.z - gp.z)
		var d := away.length()
		if d < 0.01:
			continue
		var u := away / d
		var slack: float = g.get("slack", REACH + 0.08)
		var outward := vel.dot(u)
		match g["kind"]:
			"anchor":
				if d > slack:
					if outward > 0.0:
						vel -= u * outward
					vel -= u * minf((d - slack) * 6.0, 3.0)
			"tear":
				if d > slack - 0.1 and outward > 0.0:
					var keep: float = 1.0 - float(g.get("resist", 0.4))
					g["done"] = float(g["done"]) + outward * keep * delta
					tension = maxf(tension, float(g["done"]) / float(g.get("stretch", 0.3)))
					vel -= u * outward * (1.0 - keep)
			"heavy":
				if d > slack and outward > 0.0:
					var allowed: float = float(g.get("vmax", 0.0)) + 0.05
					if outward > allowed:
						vel -= u * (outward - allowed)
				if d > slack + 0.35:
					vel -= u * minf((d - slack - 0.35) * 5.0, 2.0)
	return vel


## Something tearable gives way
func _tear(i: int) -> void:
	var g: Dictionary = h[i]["grip"]
	var n = g.get("node")
	var at := _grip_world(g)
	if n != null and is_instance_valid(n) and (n as Object).has_meta("on_tear"):
		((n as Object).get_meta("on_tear") as Callable).call(p)
	elif g.has("grass"):
		_rip_grass(g, i)
	Sfx.play(p, "whoosh", -14.0, 1.4)
	h[i]["grip"] = {}
	h[i]["mode"] = "idle"
	# the arm flies back a little
	h[i]["ext"] = 0.0
	released.emit(i)


## The tuft stretches towards the pulling hand: taller and leaning, more the closer it is to tearing
func _grass_set(g: Dictionary, xf: Transform3D) -> void:
	var t: Dictionary = g["grass"]
	for mmi in [t["mmi"], (t["mmi"] as Node).get_meta("twin", null)]:
		if mmi == null or not is_instance_valid(mmi):
			continue
		var m := mmi as MultiMeshInstance3D
		m.multimesh.set_instance_transform(int(t["idx"]), m.global_transform.affine_inverse() * xf)


func _bend_grass(g: Dictionary, sh: Vector3, k: float) -> void:
	var xf0: Transform3D = g["xf0"]
	var to := sh - xf0.origin
	var lean_axis := Vector3.UP.cross(Vector3(to.x, 0, to.z)).normalized()
	var b := xf0.basis
	if lean_axis.length() > 0.1:
		b = Basis(lean_axis, 0.55 * k) * b
	b = b * Basis.from_scale(Vector3(1.0 - 0.15 * k, 1.0 + 0.45 * k, 1.0 - 0.15 * k))
	# the roots come up a little just before it gives way
	_grass_set(g, Transform3D(b, xf0.origin + Vector3.UP * 0.03 * k * k))


## Torn out: the tuft leaves the ground, flies up with the hand's jerk and tumbles down (roots and all)
func _rip_grass(g: Dictionary, i: int) -> void:
	var t: Dictionary = g["grass"]
	var src := t["mmi"] as MultiMeshInstance3D
	if not is_instance_valid(src):
		return
	var idx := int(t["idx"])
	var custom := src.multimesh.get_instance_custom_data(idx)
	var xf0: Transform3D = g["xf0"]
	_grass_set(g, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), xf0.origin - Vector3.UP * 2.0))
	# a one-tuft copy with the same mesh, material and colour data
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = src.multimesh.mesh
	mm.instance_count = 1
	mm.set_instance_custom_data(0, custom)
	var tuft := MultiMeshInstance3D.new()
	tuft.multimesh = mm
	tuft.material_override = src.material_override
	tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.get_parent().add_child(tuft)
	tuft.global_transform = Transform3D(xf0.basis, xf0.origin + Vector3.UP * 0.04)
	var root := MeshInstance3D.new()
	root.mesh = Mesh3.blob(Vector3(0.05, 0.03, 0.05), 2.0, 5, 8)
	root.material_override = ItemModels.material()
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("5b4030")
	root.material_override = sm
	root.position = Vector3(0, -0.02, 0) / xf0.basis.get_scale()
	tuft.add_child(root)
	var hand: Vector3 = h[i]["pos"]
	var land := hand + (hand - _shoulder(i)).normalized() * -0.2 + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	if p.world:
		land.y = p.world.ground_y(land.x, land.z)
	var tw := tuft.create_tween()
	tw.tween_property(tuft, "global_position", hand + Vector3(0, 0.35, 0), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tuft, "global_position", land, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(tuft, "rotation", Vector3(randf_range(1.2, 1.6) * (1 if randf() < 0.5 else -1), randf() * TAU, randf_range(-0.4, 0.4)), 0.5)
	tw.tween_interval(8.0)
	tw.tween_property(tuft, "scale", Vector3.ONE * 0.01, 1.2)
	tw.tween_callback(tuft.queue_free)
	# a little puff of soil
	if p.footprints:
		p.footprints.puff(xf0.origin, "path", 0.25)


# ================================================================ punching

func _punch(i: int) -> void:
	var s := h[i]
	s["mode"] = "punch"
	s["punch_t"] = 0.0
	s["hit"] = false
	p.body.spend(0.8)
	if p.scout:
		p.scout.punch(i)


func _punch_hit(i: int) -> void:
	var sh := _shoulder(i)
	var aim := _aim_point(i, true)
	var dir := (aim - sh).normalized()
	var q := PhysicsRayQueryParameters3D.create(sh, sh + dir * (reach_len(sh, aim) + 0.25), 1 | (1 << (WorldItem.LAYER - 1)) | GRAB_LAYER)
	q.collide_with_areas = true
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if OS.get_cmdline_user_args().has("--handlog"):
		print("[Hands] punch %d from %s to %s hit %s %s %s" % [i, sh, aim, hit.get("collider"), (hit.get("collider") as Object).get("item") if hit.get("collider") else "", (hit.get("collider") as Node3D).global_position if hit.get("collider") else ""])
	if hit.is_empty():
		# into water?
		if p.world:
			var tip := sh + dir * REACH
			var w := p.world.local_to_world(tip)
			var wl := p.world.gen.water_level(w.x, w.z)
			if wl > -INF and tip.y < wl + 0.25:
				p.add_ring(Vector3(tip.x, wl, tip.z), 0.8)
				Sfx.play(p, "plop", -10.0, 1.3)
		Sfx.play(p, "whoosh", -22.0, 1.8)
		return
	var c: Object = hit["collider"]
	var at: Vector3 = hit["position"]
	if c.has_meta("punch"):
		(c.get_meta("punch") as Callable).call(p, at, dir)
	elif c is RigidBody3D:
		var rb := c as RigidBody3D
		rb.freeze = false
		rb.sleeping = false
		rb.apply_impulse(dir * minf(rb.mass * 4.0, 30.0), at - rb.global_position)
		Sfx.play(p, "stone_click", -8.0, 0.8)
	else:
		# a thunk against a tree, a rock or a fence: ouch, a little
		Sfx.play(p, "stone_click", -6.0, 0.6)
		GameInput.rumble(0.3, 0.2, 0.08)
