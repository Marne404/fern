class_name Mesh3
extends RefCounted
## Small procedural mesh kit with analytic normals: surfaces of revolution, superellipsoids and tubes.

## Grid of rows x cols vertices -> triangle mesh. The winding is detected once (Godot: clockwise = front).
static func grid(verts: PackedVector3Array, norms: PackedVector3Array, rows: int, cols: int) -> ArrayMesh:
	var flip := false
	var r := clampi(rows / 2, 0, rows - 2)
	for cc in cols - 1:
		var a := r * cols + cc
		var cr := (verts[a + 1] - verts[a]).cross(verts[a + cols] - verts[a])
		if cr.length() > 1e-10:
			flip = cr.dot(norms[a]) > 0.0
			break
	var idx := PackedInt32Array()
	for i in rows - 1:
		for j in cols - 1:
			var a := i * cols + j
			var b := a + 1
			var c := a + cols
			var d := c + 1
			if flip:
				idx.append_array([a, c, b, b, c, d])
			else:
				idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Surface of revolution around Y. profile: Vector2(radius, y), front of the object faces -Z.
## dz squashes the cross-section in depth.
static func lathe(profile: Array, segs := 28, dz := 1.0, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var n := profile.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in n:
		var p: Vector2 = profile[i]
		var t: Vector2 = (profile[mini(i + 1, n - 1)] - profile[maxi(i - 1, 0)]).normalized()
		var nr := t.y
		var ny := -t.x
		for j in segs + 1:
			var th := TAU * j / segs
			var v := Vector3(p.x * sin(th), p.y, -p.x * cos(th) * dz)
			var nn := Vector3(nr * sin(th), ny, -nr * cos(th) / dz).normalized()
			verts.append(xf * v)
			norms.append((xf.basis * nn).normalized())
	return grid(verts, norms, n, segs + 1)


## Superellipsoid with half extents `half`; p = 2 is an ellipsoid, larger p gives a rounded box.
static func blob(half: Vector3, p := 2.0, rings := 12, segs := 20, xf := Transform3D.IDENTITY) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for i in rings + 1:
		var phi := PI * i / rings
		for j in segs + 1:
			var th := TAU * j / segs
			var d := Vector3(sin(phi) * sin(th), cos(phi), -sin(phi) * cos(th))
			var k := pow(pow(absf(d.x), p) + pow(absf(d.y), p) + pow(absf(d.z), p), 1.0 / p)
			var u := d / k
			var g := Vector3(signf(u.x) * pow(absf(u.x), p - 1.0) / half.x,
				signf(u.y) * pow(absf(u.y), p - 1.0) / half.y,
				signf(u.z) * pow(absf(u.z), p - 1.0) / half.z)
			if g.length() < 1e-8:
				g = d
			verts.append(xf * (u * half))
			norms.append((xf.basis * g.normalized()).normalized())
	return grid(verts, norms, rings + 1, segs + 1)


## Capsule hanging down from the origin along -Y (radius r0 at the top, r1 at the bottom)
static func capsule(r0: float, r1: float, length: float, segs := 18) -> ArrayMesh:
	var prof := []
	for i in 7:
		var a := -PI * 0.5 + PI * 0.5 * i / 6.0
		prof.append(Vector2(cos(a) * r1, -length + sin(a) * r1))
	for i in 7:
		var a := PI * 0.5 * i / 6.0
		prof.append(Vector2(cos(a) * r0, sin(a) * r0))
	return lathe(prof, segs)


## Tube along points. radii: float or Array. ups: optional per-point "up" vectors (the cross-section's
## thickness axis); flat = thickness / width. Rounded caps at both ends.
static func tube(pts: Array, radii, segs := 10, ups: Array = [], flat := 1.0, caps := true) -> ArrayMesh:
	var n := pts.size()
	var tans: Array[Vector3] = []
	var nors: Array[Vector3] = []
	for i in n:
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		tans.append(t)
		var nv: Vector3
		if ups.size() == n:
			nv = ups[i]
		elif i == 0:
			nv = t.cross(Vector3.UP) if absf(t.dot(Vector3.UP)) < 0.95 else t.cross(Vector3.RIGHT)
		else:
			nv = nors[i - 1]
		nv = (nv - t * nv.dot(t)).normalized()
		nors.append(nv)
	var rows := []   # [center, N, B, T, ra, rb, cap_t]
	for i in n:
		var r: float = radii[i] if radii is Array else radii
		rows.append([pts[i], nors[i], tans[i].cross(nors[i]), tans[i], r, r * flat, 0.0])
	if caps:
		var first: Array = rows[0]
		var last: Array = rows[n - 1]
		for k in range(1, 4):
			var al := PI * 0.5 * k / 3.0
			var rc: float = (first[4] + first[5]) * 0.5
			rows.push_front([first[0] - first[3] * rc * sin(al), first[1], first[2], first[3], first[4] * cos(al), first[5] * cos(al), -sin(al)])
			var rl: float = (last[4] + last[5]) * 0.5
			rows.push_back([last[0] + last[3] * rl * sin(al), last[1], last[2], last[3], last[4] * cos(al), last[5] * cos(al), sin(al)])
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for row in rows:
		var ca := sqrt(maxf(1.0 - row[6] * row[6], 0.0))
		for j in segs + 1:
			var ph := TAU * j / segs
			var off: Vector3 = row[1] * cos(ph) * row[5] + row[2] * sin(ph) * row[4]
			var nn: Vector3 = row[1] * cos(ph) / maxf(row[5], 1e-4) + row[2] * sin(ph) / maxf(row[4], 1e-4)
			nn = nn.normalized() * ca + row[3] * row[6]
			verts.append(row[0] + off)
			norms.append(nn.normalized())
	return grid(verts, norms, rows.size(), segs + 1)


## Catmull-Rom through 2D control points, `sub` samples per span
static func catmull(ctrl: Array, sub: int) -> Array:
	var out := []
	var n := ctrl.size()
	for i in n - 1:
		var p0: Vector2 = ctrl[maxi(i - 1, 0)]
		var p1: Vector2 = ctrl[i]
		var p2: Vector2 = ctrl[i + 1]
		var p3: Vector2 = ctrl[mini(i + 2, n - 1)]
		for k in sub:
			var t := float(k) / sub
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out
