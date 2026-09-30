class_name ScoutFaceFx
extends RefCounted
## The scout's expressive face kit: extra eye shapes (star, heart, spiral, squeezed "><", teary), extra mouths
## ("o", pout, grin, frown, tongue out), blush strokes, tears and a sweat drop. All drawn like the rest of the
## face: flat shapes lying on the head, switched on and off by the face parameters.
## Also the flat shape helpers used by the symbol bubbles (ScoutBubbles).

const EYES := ["dot", "sclera", "wide", "happy", "closed", "x", "star", "heart", "spiral", "squeeze", "teary"]
const MOUTHS := ["smile", "flat", "wavy", "open", "teeth", "cheeky", "o", "pout", "grin", "frown", "tongue"]


## A flat filled shape (a polygon that is star-shaped around its centroid) in the XY plane at depth z, facing +Z
static func flat(pts: PackedVector2Array, z := 0.0) -> ArrayMesh:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var verts := PackedVector3Array([Vector3(c.x, c.y, z)])
	var norms := PackedVector3Array([Vector3(0, 0, 1)])
	for p in pts:
		verts.append(Vector3(p.x, p.y, z))
		norms.append(Vector3(0, 0, 1))
	var idx := PackedInt32Array()
	var n := pts.size()
	for i in n:
		var a := 1 + i
		var b := 1 + (i + 1) % n
		# Godot: clockwise seen from the front
		var cr := (verts[a] - verts[0]).cross(verts[b] - verts[0])
		if cr.z > 0.0:
			idx.append_array([0, b, a])
		else:
			idx.append_array([0, a, b])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func star_pts(r_out: float, r_in: float, n := 5, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := PI * 0.5 + rot + PI * i / n
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


static func heart_pts(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		# the classic heart curve, centered and scaled to about s wide
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y + 2.0) * s / 32.0)
	return pts


## A teardrop, pointed at the top, about s tall
static func drop_pts(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		pts.append(Vector2(sin(t) * pow(absf(sin(t * 0.5)), 1.3) * 0.36, cos(t) * 0.5) * s)
	return pts


static func oval_pts(rx: float, ry: float, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Adds the extra parts to a built scout (called from Scout._build_face)
static func build(sc: Scout, space: Node3D) -> void:
	var f: Dictionary = sc._face
	for side: int in [-1, 1]:
		var s := "L" if side < 0 else "R"
		var eye: Node3D = f["eye" + s]
		# star eyes: a yellow star with a dark outline
		var star := Node3D.new()
		star.name = "Star" + s
		eye.add_child(star)
		sc._add(star, flat(star_pts(0.066, 0.03, 5), 0.008), "eye")
		sc._add(star, flat(star_pts(0.052, 0.022, 5), 0.012), "star")
		f["star" + s] = star
		# heart eyes
		var heart := Node3D.new()
		heart.name = "Heart" + s
		eye.add_child(heart)
		sc._add(heart, flat(heart_pts(0.12), 0.008), "eye")
		sc._add(heart, flat(heart_pts(0.098), 0.012), "heart")
		f["heart" + s] = heart
		# dizzy spiral
		var sp := []
		for i in 33:
			var t := i / 32.0
			var a := t * TAU * 2.3 * side
			sp.append(Vector3(cos(a), sin(a), 0.0) * (0.006 + t * 0.042) + Vector3(0, 0, 0.01))
		f["spiral" + s] = sc._curve(eye, "Spiral" + s, sp, 0.007, "eye")
		# squeezed eyes "> <": a chevron pointing to the nose
		var sq := Node3D.new()
		sq.name = "Squeeze" + s
		eye.add_child(sq)
		var dx := -0.03 * side
		sc._curve(sq, "SqA" + s, [Vector3(dx, 0.032, 0.01), Vector3(-dx, 0.0, 0.01), Vector3(dx, -0.032, 0.01)], 0.01, "eye")
		f["squeeze" + s] = sq
		# tears: two drops that run down (animated in Scout._update_face); shown for "teary" and crying
		var tears := Node3D.new()
		tears.name = "Tears" + s
		eye.add_child(tears)
		for k in 2:
			var d := sc._add(tears, flat(drop_pts(0.038), 0.016), "tear", "Tear%d" % k)
			d.position = Vector3(0.012 * side, -0.05, 0.0)
		f["tears" + s] = tears
	# blush: pink ovals with three little strokes on each cheek
	var blush := Node3D.new()
	blush.name = "Blush"
	space.add_child(blush)
	for side: int in [-1, 1]:
		var cp: Array = Scout.head_point(-0.2, 0.6 * side, 0.004)
		var fr: Transform3D = Scout._frame(cp[0], cp[1])
		var b := Node3D.new()
		b.transform = fr
		blush.add_child(b)
		sc._add(b, flat(oval_pts(0.062, 0.036), 0.0), "blush")
		for k in 3:
			var x := (k - 1) * 0.022
			sc._curve(b, "Stroke", [Vector3(x + 0.008, 0.012, 0.004), Vector3(x - 0.008, -0.012, 0.004)], 0.0035, "blushline")
	blush.visible = false
	f["blush"] = blush
	# sweat drop at the temple
	var sweat := Node3D.new()
	sweat.name = "Sweat"
	space.add_child(sweat)
	var sp2: Array = Scout.head_point(0.3, 0.72, 0.006)
	sweat.transform = Scout._frame(sp2[0], sp2[1])
	sc._add(sweat, flat(drop_pts(0.05), 0.0), "tear")
	sc._add(sweat, flat(oval_pts(0.008, 0.012), 0.004), "white").position = Vector3(-0.008, -0.008, 0)
	sweat.visible = false
	f["sweat"] = sweat
	# mouths
	var mouth: Node3D = f["mouth"]
	var o := Node3D.new()
	o.name = "O"
	mouth.add_child(o)
	sc._add(o, flat(oval_pts(0.017, 0.021), 0.004), "mouth")
	f["o"] = o
	f["pout"] = sc._curve(mouth, "Pout", [Vector3(-0.022, -0.004, 0.004), Vector3(-0.008, 0.006, 0.004), Vector3(0.0, 0.0, 0.004), Vector3(0.008, 0.006, 0.004), Vector3(0.022, -0.004, 0.004)], 0.0075, "mouth")
	f["frown"] = sc._curve(mouth, "Frown", Scout._arc(0.03, 0.014), 0.0085, "mouth")
	var grin := Node3D.new()
	grin.name = "Grin"
	mouth.add_child(grin)
	var gp := PackedVector2Array()
	for i in 17:
		var u := i / 16.0 * 2.0 - 1.0
		gp.append(Vector2(u * 0.066, -0.046 * (1.0 - u * u) + 0.004))
	gp.append(Vector2(0.06, 0.01))
	gp.append(Vector2(-0.06, 0.01))
	sc._add(grin, flat(gp, 0.003), "mouth")
	var tp := PackedVector2Array()
	for i in 9:
		var u := i / 8.0 * 2.0 - 1.0
		tp.append(Vector2(u * 0.054, -0.011 * (1.0 - u * u)))
	tp.append(Vector2(0.052, 0.008))
	tp.append(Vector2(-0.052, 0.008))
	sc._add(grin, flat(tp, 0.007), "teeth")
	sc._add(grin, flat(oval_pts(0.026, 0.012), 0.006), "tongue").position = Vector3(0, -0.032, 0)
	f["grin"] = grin
	var tongue := Node3D.new()
	tongue.name = "TongueOut"
	mouth.add_child(tongue)
	sc._curve(tongue, "TSmile", Scout._arc(0.028, -0.006), 0.008, "mouth")
	var tg := sc._add(tongue, Mesh3.blob(Vector3(0.017, 0.024, 0.008), 2.0, 6, 10), "tongue")
	tg.position = Vector3(0, -0.02, 0.008)
	f["tongue"] = tongue
