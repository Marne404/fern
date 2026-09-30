class_name ScoutGear
extends Node3D
## What the scout carries, visibly: things hanging on the backpack (rope coil, lantern on its hook, walking
## stick strapped across, kite on the back, bottle and thermos in the side pockets, a sun hat that isn't worn),
## camera and binoculars on straps around the neck, whistle and compass on the straps and belt, the clothes it
## wears (they override the editor look) and one item in each hand.
## Everything comes from the inventory: set_items() after every change, hold() for the hands.

## Where carried items hang: id -> [parent ("pack", "chest", "hips"), position, rotation, scale, dangles]
const HANG := {
	"wasserflasche": ["pack", Vector3(0.245, -0.07, 0.16), Vector3.ZERO, 1.0, false],
	"tee": ["pack", Vector3(0.245, -0.07, 0.06), Vector3.ZERO, 0.95, false],
	"seil": ["pack", Vector3(0.0, -0.17, 0.3), Vector3.ZERO, 1.0, false],
	"laterne": ["pack", Vector3(-0.255, 0.1, 0.12), Vector3.ZERO, 1.2, true],
	"stock": ["pack", Vector3(0.02, 0.06, 0.305), Vector3(0, 0, 0.95), 0.85, false],
	"drachen": ["pack", Vector3(0.0, 0.06, 0.315), Vector3(PI * 0.5, 0, 0.15), 0.9, false],
	"sonnenhut": ["pack", Vector3(0.0, 0.47, 0.13), Vector3(-0.15, 0, 0.1), 0.95, false],
	"kamera": ["chest", Vector3(0.05, 0.8, -0.215), Vector3(0, PI, 0), 0.95, true],
	"fernglas": ["chest", Vector3(-0.06, 0.82, -0.215), Vector3(PI * 0.5, 0, 0), 0.9, true],
	"pfeife": ["chest", Vector3(0.12, 0.9, -0.2), Vector3(0, 0, -1.2), 1.1, true],
	"kompass": ["hips", Vector3(-0.15, 0.645, -0.17), Vector3(PI * 0.5, 0, 0), 1.0, false],
	"messer": ["hips", Vector3(0.16, 0.64, -0.155), Vector3(0, 0.5, PI * 0.5), 1.0, false],
}
## When two items want the same place, the first in this list gets it
const HANG_ORDER := ["laterne", "stock", "drachen", "sonnenhut", "seil", "wasserflasche", "tee", "kamera", "fernglas", "pfeife", "kompass", "messer"]

## Items with a grip of their own: id -> [hand, grip pose, position, rotation, scale]
## Grip poses: "hang" (lantern hangs from the hand), "point" (flashlight forward), "stick", "read" (map, book,
## compass looked at), "hold" (anything small, shown in the palm)
const HOLD := {
	"laterne": ["L", "hang", Vector3(0, -0.085, 0), Vector3.ZERO, 1.35],
	"taschenlampe": ["L", "point", Vector3(0, -0.1, -0.02), Vector3(0, 0, -PI * 0.5), 1.3],
	"stock": ["R", "stick", Vector3(0, -0.07, -0.02), Vector3(0, 0, PI * 0.5), 0.85],
	"karte": ["R", "read", Vector3(0.0, 0.8, -0.34), Vector3(-1.05, 0, 0), 2.2],
	"feldhandbuch": ["R", "read", Vector3(0.0, 0.8, -0.32), Vector3(-1.0, 0, 0), 1.1],
	"kompass": ["R", "palm", Vector3(0.06, 0.76, -0.31), Vector3(-0.7, 0, 0), 1.6],
}
const NO_HOLD := ["seil", "regenjacke", "pullover", "muetze", "sonnenhut", "schal", "handschuhe", "stiefel", "poncho"]

## Clothing worn -> look overrides
const WEAR := {
	"muetze": {"hat": 3, "hat_rgb": Color("d1493f")},
	"sonnenhut": {"hat": 2, "hat_rgb": Color("e8d29a")},
	"schal": {"scarf_rgb": Color("ec8a34")},
	"handschuhe": {"hand_rgb": Color("5b86b5")},
	"regenjacke": {"outfit_rgb": Color("f2c230")},
	"pullover": {"outfit_rgb": Color("b5473a")},
	"poncho": {"outfit_rgb": Color("3aa99c")},
}

var scout: Scout
var _spaces := {}
var _hung := {}          # id -> Node3D on the pack / neck / belt
var _held := {"L": null, "R": null}   # Node3D in the hand
var _held_id := {"L": "", "R": ""}
var _carried := {}        # id -> true (what is in the inventory, usable)
var _dangle := {}         # Node3D -> [angle x, angle z, vel x, vel z, last global pos]


func setup(sc: Scout) -> void:
	scout = sc
	name = "Gear"
	_spaces = {"pack": sc._pack, "chest": sc.chest.get_node("ChestSpace"), "hips": sc.hips.get_node("HipsSpace")}


## Holdable at all: everything small enough, except clothes and ropes
static func holdable(id: String) -> bool:
	if id in NO_HOLD or not ItemDefs.ITEMS.has(id):
		return false
	return HOLD.has(id) or ItemDefs.half_extent(id) < 0.16


static func hand_of(id: String) -> String:
	return HOLD[id][0] if HOLD.has(id) else "R"


## Reading things are held in front of the chest (the hands go there), not at a hand
static func anchored(id: String) -> bool:
	return HOLD.has(id) and HOLD[id][1] in ["read", "palm"]


static func grip_of(id: String) -> String:
	return HOLD[id][1] if HOLD.has(id) else "hold"


func held(side: String) -> String:
	return _held_id[side]


## The inventory changed: what hangs where, what is worn
func set_items(items: Array) -> void:
	_carried.clear()
	var wear := {}
	for it in items:
		if it.get("condition", 1.0) < 0.35 and not ItemDefs.def(it["id"]).has("slot"):
			continue
		_carried[it["id"]] = true
		if it.get("equipped", false) and WEAR.has(it["id"]):
			wear.merge(WEAR[it["id"]], true)
	# a held item that is gone leaves the hand
	for side in ["L", "R"]:
		if _held_id[side] != "" and not _carried.has(_held_id[side]):
			hold(side, "")
	var worn := {}
	for it in items:
		if it.get("equipped", false):
			worn[it["id"]] = true
	scout.wear_ids = worn
	_refresh_hung(items)
	scout.set_wear(wear)


func _refresh_hung(items: Array) -> void:
	var worn := {}
	for it in items:
		if it.get("equipped", false):
			worn[it["id"]] = true
	var want := {}
	var taken := {}
	for id in HANG_ORDER:
		if not _carried.has(id) or worn.has(id) or id == _held_id["L"] or id == _held_id["R"]:
			continue
		var h: Array = HANG[id]
		var key := "%s%s" % [h[0], (h[1] as Vector3).snapped(Vector3.ONE * 0.05)]
		if taken.has(key):
			continue
		taken[key] = true
		want[id] = true
	for id in _hung.keys():
		if not want.has(id):
			_remove(_hung[id])
			_hung.erase(id)
	for id in want:
		if not _hung.has(id) and _lit.get(id, false):
			call_deferred("_update_glow")
		if not _hung.has(id):
			var h: Array = HANG[id]
			_hung[id] = _attach(_spaces[h[0]], id, h[1], h[2], h[3], h[4])
			if id in ["kamera", "fernglas", "pfeife"]:
				_neck_strap(_hung[id])


## Puts an item into a hand ("" = empty hand). The item leaves its place on the pack.
func hold(side: String, id: String) -> void:
	if _held[side]:
		_remove(_held[side])
		_held[side] = null
	_held_id[side] = id
	if id != "":
		var hand: Node3D = scout._arms[0 if side == "L" else 1][2]
		var d: Array = HOLD[id] if HOLD.has(id) else ["R", "hold", Vector3(0, -0.105, -0.035), Vector3.ZERO, 1.0]
		var parent: Node3D = _spaces["chest"] if anchored(id) else hand
		_held[side] = _attach(parent, id, d[2], d[3], d[4], grip_of(id) == "hang")
	_refresh_hung_keep()
	_update_glow()


func _refresh_hung_keep() -> void:
	var items := []
	for k in _carried:
		items.append({"id": k, "equipped": scout.wear_ids.has(k)})
	_refresh_hung(items)


# ---------------------------------------------------------------- items shown during an action (ScoutActions)
var _temp: Node3D
var _temp_id := ""
var _temp_hidden: Array[Node3D] = []

## How an item sits in the right hand during an action: id -> [position, rotation, scale]
const TEMP := {
	"kamera": [Vector3(0.05, -0.08, -0.03), Vector3(PI * 0.5, 0, 0), 1.0],
	"fernglas": [Vector3(0.06, -0.08, -0.02), Vector3(0, 0, 0), 1.0],
	"mundharmonika": [Vector3(0.05, -0.09, -0.02), Vector3(0, 0, PI * 0.5), 1.1],
	"pfeife": [Vector3(0.0, -0.1, -0.02), Vector3(0, 0, PI * 0.5), 1.2],
	"gummihuhn": [Vector3(0.0, -0.12, -0.04), Vector3(0, PI, 0), 1.2],
	"wasserpistole": [Vector3(0.0, -0.1, -0.02), Vector3(-PI * 0.5, PI * 0.5, 0), 1.2],
	"wasserflasche": [Vector3(0.0, -0.12, -0.02), Vector3.ZERO, 1.0],
	"tee": [Vector3(0.0, -0.12, -0.02), Vector3.ZERO, 1.0],
	"streichhoelzer": [Vector3(0.0, -0.1, -0.03), Vector3.ZERO, 1.2],
	"roast_stick": [Vector3(0.0, -0.07, -0.02), Vector3(-PI * 0.5, 0, 0), 1.0],
}


## Shows an item in the right hand for an action; what is held or hanging with the same id hides meanwhile
func show_temp(id: String) -> void:
	end_temp()
	if id == "":
		return
	_temp_id = id
	var hand: Node3D = scout._arms[1][2]
	var d: Array = TEMP.get(id, [Vector3(0, -0.105, -0.035), Vector3.ZERO, 1.0])
	if id == "roast_stick":
		_temp = _attach_mesh(hand, _roast_stick(), d[0], d[1], d[2])
	else:
		_temp = _attach(hand, id, d[0], d[1], d[2], false)
	for n in [_held["R"], _hung.get(id)]:
		if n and (n as Node3D).visible:
			(n as Node3D).visible = false
			_temp_hidden.append(n)


func end_temp() -> void:
	if _temp:
		_remove(_temp)
		_temp = null
	_temp_id = ""
	for n in _temp_hidden:
		if is_instance_valid(n):
			n.visible = true
	_temp_hidden.clear()


## Rubber chicken squeezing
func squash_temp(k: float) -> void:
	if _temp and _temp_id == "gummihuhn":
		_temp.scale = Vector3(1.0 + (1.0 - k) * 0.5, k, 1.0 + (1.0 - k) * 0.3)


func _attach_mesh(parent: Node3D, m: Mesh, pos: Vector3, rot: Vector3, sc: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation = rot
	pivot.scale = Vector3.ONE * sc
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.set_meta("role", "gear")
	pivot.add_child(mi)
	scout._meshes.append(mi)
	return pivot


## A green twig with a marshmallow on the tip (pointing along -Y of the hand, i.e. away from the palm)
static var _stick_mesh: ArrayMesh


static func _roast_stick() -> ArrayMesh:
	if _stick_mesh:
		return _stick_mesh
	var b := ItemModels.B.new()
	b.add(Mesh3.tube([Vector3(0, 0.1, 0), Vector3(0.01, -0.3, 0.01), Vector3(0, -0.72, 0.03)], 0.011, 6), Color("8b5a36"))
	b.add(Mesh3.blob(Vector3(0.028, 0.034, 0.028), 3.0, 8, 12, Transform3D(Basis(), Vector3(0, -0.74, 0.03))), Color("fff2dc"))
	_stick_mesh = b.commit()
	_stick_mesh.surface_set_material(0, ItemModels.material())
	return _stick_mesh


## The node showing an item (in a hand or hanging), or null
func item_node(id: String) -> Node3D:
	for side in ["L", "R"]:
		if _held_id[side] == id and _held[side]:
			return _held[side]
	return _hung.get(id)


## A lit lantern glows (a warm light inside the glass)
var _lit := {}


func set_lit(id: String, on: bool) -> void:
	_lit[id] = on
	_update_glow()


func _update_glow() -> void:
	for id in ["laterne", "taschenlampe"]:
		var n := item_node(id)
		if n == null:
			continue
		var g: Node3D = n.get_node_or_null("Glow")
		var on: bool = _lit.get(id, false)
		if on and g == null:
			var mi := MeshInstance3D.new()
			mi.name = "Glow"
			var sm := SphereMesh.new()
			sm.radius = 0.03 if id == "laterne" else 0.018
			sm.height = sm.radius * 2.0
			mi.mesh = sm
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.0, 0.85, 0.5) if id == "laterne" else Color(1.0, 0.97, 0.85)
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var body: Node3D = n.get_child(0)
			var inner: MeshInstance3D = body.get_child(0)
			mi.position = body.position + body.basis * (inner.position + Vector3(0, 0.0, 0))
			n.add_child(mi)
		elif not on and g:
			g.queue_free()


## A holding scout's hands are shown empty while swimming, climbing or lying (the items are back on the pack)
func set_hands_busy(busy: bool) -> void:
	for side in ["L", "R"]:
		if _held[side]:
			(_held[side] as Node3D).visible = not busy


func _attach(parent: Node3D, id: String, pos: Vector3, rot: Vector3, sc: float, dangles: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Gear_" + id
	pivot.position = pos
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = _coil() if id == "seil" and parent == _spaces["pack"] else ItemModels.mesh(id)
	mi.set_meta("role", "gear")
	var body := Node3D.new()
	body.rotation = rot
	body.scale = Vector3.ONE * sc
	pivot.add_child(body)
	body.add_child(mi)
	if dangles:
		# hang below the pivot: the top of the item is at the pivot
		var top := mi.mesh.get_aabb().end.y
		mi.position.y = -top
		_dangle[pivot] = [0.0, 0.0, 0.0, 0.0, Vector3.INF]
	scout._meshes.append(mi)
	if scout._shadow_only:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return pivot


## A thin strap from the item up around the neck
func _neck_strap(pivot: Node3D) -> void:
	var p := pivot.position
	var pts := [Vector3(p.x - 0.03, p.y + 0.01, p.z), Vector3(-0.1, 0.98, -0.14), Vector3(-0.1, 1.04, 0.0), Vector3(0.1, 1.04, 0.0),
		Vector3(0.1, 0.98, -0.14), Vector3(p.x + 0.03, p.y + 0.01, p.z)]
	var mi := MeshInstance3D.new()
	mi.mesh = Mesh3.tube(_smooth(pts, 4), 0.006, 5)
	mi.material_override = scout._mat("leather")
	mi.set_meta("role", "gear")
	mi.name = "Strap"
	_spaces["chest"].add_child(mi)
	pivot.set_meta("strap", mi)
	scout._meshes.append(mi)


## A neat coil of rope, strapped flat against the back of the pack
static var _coil_mesh: ArrayMesh


static func _coil() -> ArrayMesh:
	if _coil_mesh:
		return _coil_mesh
	var b := ItemModels.B.new()
	for k in 3:
		var pts := []
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(Vector3(cos(a) * (0.1 - k * 0.012), sin(a) * (0.075 - k * 0.01), k * 0.012))
		b.add(Mesh3.tube(pts, 0.016, 7, [], 1.0, false), Color("cdb07a").darkened(k * 0.07))
	b.add(Mesh3.tube([Vector3(-0.02, 0.09, 0.02), Vector3(0.0, 0.0, 0.04), Vector3(0.02, -0.09, 0.02)], 0.009, 6), Color("6b4428"))
	_coil_mesh = b.commit()
	_coil_mesh.surface_set_material(0, ItemModels.material())
	return _coil_mesh


static func _smooth(pts: Array, sub: int) -> Array:
	var out := []
	var n := pts.size()
	for i in n - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out


func _remove(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		scout._meshes.erase(mi)
	if n.has_meta("strap"):
		var st: MeshInstance3D = n.get_meta("strap")
		scout._meshes.erase(st)
		st.queue_free()
	_dangle.erase(n)
	n.queue_free()


## Dangling things swing like a pendulum when their hook accelerates
func update(delta: float) -> void:
	if delta <= 0.0:
		return
	for n: Node3D in _dangle:
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var s: Array = _dangle[n]
		var gp := n.global_position
		var last: Vector3 = s[4]
		s[4] = gp
		if last == Vector3.INF:
			continue
		var acc := (gp - last) / delta
		var prev_v: Vector3 = n.get_meta("v", Vector3.ZERO)
		n.set_meta("v", acc)
		var a := (acc - prev_v) / delta
		# acceleration in the parent's frame tilts the pendulum the other way
		var la := n.get_parent_node_3d().global_basis.inverse() * a
		var ax: float = s[0]
		var az: float = s[1]
		var vx: float = s[2]
		var vz: float = s[3]
		vx += (-ax * 60.0 - vx * 4.0 + la.z * 0.09) * delta
		vz += (-az * 60.0 - vz * 4.0 - la.x * 0.09) * delta
		ax = clampf(ax + vx * delta, -0.9, 0.9)
		az = clampf(az + vz * delta, -0.9, 0.9)
		s[0] = ax
		s[1] = az
		s[2] = vx
		s[3] = vz
		# keep hanging straight down in the world, plus the swing
		var up_local := n.get_parent_node_3d().global_basis.inverse() * Vector3.UP
		var hang := Basis(Quaternion(Vector3.UP, up_local.normalized()))
		n.basis = hang * Basis.from_euler(Vector3(ax, 0, az))
