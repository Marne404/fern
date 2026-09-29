class_name StructureModels
extends RefCounted
## Hand-built procedural models for finds, obstacles and landmarks (vertex-colored, toon-shaded like
## the items). Meshes are cached by key; all functions return meshes in meters, origin at the bottom
## center unless noted.

static var _cache := {}

const WOOD := Color("9a6a40")
const WOOD_DARK := Color("6b4428")
const IRON := Color("3a3d42")
const BRASS := Color("c9a24a")
const ROPE := Color("cdb07a")


static func _cached(key: String, build: Callable) -> ArrayMesh:
	if not _cache.has(key):
		var b := ItemModels.B.new()
		build.call(b)
		var m := _commit_bottom(b)
		m.surface_set_material(0, ItemModels.material())
		_cache[key] = m
	return _cache[key]


## Like B.commit() but keeps the original origin (structures are placed by their base)
static func _commit_bottom(b: ItemModels.B) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = b.verts
	arr[Mesh.ARRAY_NORMAL] = b.norms
	arr[Mesh.ARRAY_COLOR] = b.cols
	arr[Mesh.ARRAY_INDEX] = b.idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func T(pos := Vector3.ZERO, rot := Vector3.ZERO, sc := Vector3.ONE) -> Transform3D:
	return ItemModels.T(pos, rot, sc)


## Recompute smooth normals (for displaced shapes)
static func _renormal(m: ArrayMesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.create_from_arrays(m.surface_get_arrays(0))
	st.generate_normals()
	return st.commit()


## Blob with noisy lumps (stones)
static func lumpy(half: Vector3, p: float, seed_v: int, amount := 0.12, rings := 10, segs := 16) -> ArrayMesh:
	var m := Mesh3.blob(half, p, rings, segs)
	var arr := m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ns := FastNoiseLite.new()
	ns.seed = seed_v
	ns.frequency = 2.2
	var s := half.length()
	for i in v.size():
		var d := ns.get_noise_3dv(v[i] / s * 1.3) * amount * s
		v[i] += n[i] * d
	arr[Mesh.ARRAY_VERTEX] = v
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _renormal(out)


## Board: rounded plank with grain lines and nails at both ends (size = full extents, centered)
static func _board(b: ItemModels.B, size: Vector3, xf: Transform3D, tint: Color, nails := true) -> void:
	b.add(ItemModels.box(size, 7.0), tint, xf)
	var long_x := size.x >= size.z
	for k in 3:
		var off := (k - 1) * (size.z if long_x else size.x) * 0.28
		var g := Vector3(size.x * 0.9, 0.004, 0.006) if long_x else Vector3(0.006, 0.004, size.z * 0.9)
		var gp := Vector3(0, size.y * 0.5, off) if long_x else Vector3(off, size.y * 0.5, 0)
		b.add(ItemModels.box(g, 3.0), tint.darkened(0.25), xf * T(gp + Vector3(0, 0.0005, 0)))
	if nails:
		for e in [-1.0, 1.0]:
			var np := Vector3(e * size.x * 0.44, size.y * 0.5, 0) if long_x else Vector3(0, size.y * 0.5, e * size.z * 0.44)
			b.add(Mesh3.blob(Vector3(0.008, 0.003, 0.008), 2.0, 4, 6), IRON, xf * T(np))


# ================================================================ finds

static func picnic_blanket() -> ArrayMesh:
	return _cached("blanket", func(b: ItemModels.B):
		# plaid: a grid of small cells colored by crossing stripes, gently folded
		var nx := 18
		var nz := 14
		var w := 1.8
		var d := 1.4
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var red := Color("c8453e")
		var cream := Color("f4ecd6")
		for j in nz:
			for i in nx:
				var stripe_a := (i / 2) % 2 == 0
				var stripe_b := (j / 2) % 2 == 0
				var c := red if stripe_a and stripe_b else (cream if not stripe_a and not stripe_b else red.lerp(cream, 0.55))
				var x0 := -w * 0.5 + i * w / nx
				var z0 := -d * 0.5 + j * d / nz
				var x1 := x0 + w / nx
				var z1 := z0 + d / nz
				var q := [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]
				for k in 4:
					var p: Vector3 = q[k]
					p.y = 0.012 + 0.018 * sin(p.x * 3.1) * sin(p.z * 4.3) + 0.03 * maxf(absf(p.x) / (w * 0.5) - 0.8, 0.0)
					q[k] = p
				for t in [[0, 1, 2], [0, 2, 3]]:
					for idx in t:
						st.set_color(c.srgb_to_linear() * Color(1, 1, 1, 0.5))
						st.set_normal(Vector3.UP)
						st.add_vertex(q[idx])
		st.index()
		st.generate_normals()
		var m := st.commit()
		var arr := m.surface_get_arrays(0)
		var base := b.verts.size()
		for v in arr[Mesh.ARRAY_VERTEX]:
			b.verts.append(v)
		for n in arr[Mesh.ARRAY_NORMAL]:
			b.norms.append(n)
		for c in arr[Mesh.ARRAY_COLOR]:
			b.cols.append(c)
		for i in arr[Mesh.ARRAY_INDEX]:
			b.idx.append(base + i)
		# fringe on the short sides
		for s in [-1.0, 1.0]:
			for i in 14:
				var z := -d * 0.45 + i * d * 0.9 / 13.0
				b.add(ItemModels.tube([Vector3(s * w * 0.5, 0.02, z), Vector3(s * (w * 0.5 + 0.05), 0.008, z + 0.01)], 0.006, 4), cream))


static func basket() -> ArrayMesh:
	return _cached("basket", func(b: ItemModels.B):
		# woven body: stacked rings in two tones, rim, handle, two lid flaps
		for i in 7:
			var y := i * 0.034
			var r := 0.19 + i * 0.006
			b.add(Mesh3.lathe([Vector2(r - 0.004, y), Vector2(r + 0.004, y + 0.006), Vector2(r + 0.004, y + 0.03), Vector2(r - 0.004, y + 0.036)], 24, 0.72), Color("b07a3e") if i % 2 == 0 else Color("c99257"), T(), ItemModels.CLOTH)
		b.add(Mesh3.lathe([Vector2(0, 0), Vector2(0.19, 0), Vector2(0.19, 0.01), Vector2(0, 0.01)], 24, 0.72), Color("8a5a36"))
		b.add(ItemModels.ring(0.235, 0.014, 0.245), Color("8a5a36"), T(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.72)))
		b.add(ItemModels.tube([Vector3(-0.21, 0.24, 0), Vector3(-0.17, 0.4, 0), Vector3(0, 0.46, 0), Vector3(0.17, 0.4, 0), Vector3(0.21, 0.24, 0)], 0.014, 6), Color("8a5a36"))
		for s in [-1.0, 1.0]:
			b.add(ItemModels.box(Vector3(0.21, 0.02, 0.33), 5.0), Color("c99257"), T(Vector3(s * 0.105, 0.255, 0), Vector3(0, 0, s * 0.12)), ItemModels.CLOTH)
		b.add(ItemModels.box(Vector3(0.12, 0.03, 0.2), 4.0), Color("c8453e"), T(Vector3(0.12, 0.27, 0.02), Vector3(0, 0.3, 0.15)), ItemModels.CLOTH))


static func lost_pack(color: Color) -> ArrayMesh:
	return _cached("pack_" + color.to_html(), func(b: ItemModels.B):
		var dark := color.darkened(0.25)
		# lying on its back, tilted
		var base := T(Vector3(0, 0.15, 0), Vector3(-1.3, 0.3, 0.15))
		b.add(Mesh3.blob(Vector3(0.21, 0.28, 0.14), 3.4, 12, 20), color, base, ItemModels.CLOTH)
		b.add(Mesh3.blob(Vector3(0.22, 0.075, 0.15), 3.0, 8, 16), dark, base * T(Vector3(0, 0.26, 0.01)), ItemModels.CLOTH)
		b.add(Mesh3.blob(Vector3(0.15, 0.1, 0.05), 3.0, 8, 14), dark, base * T(Vector3(0, -0.08, 0.14)), ItemModels.CLOTH)
		b.add(Mesh3.lathe([Vector2(0, -0.24), Vector2(0.075, -0.24), Vector2(0.08, 0), Vector2(0.075, 0.24), Vector2(0, 0.24)], 16), Color("5b86b5"), base * T(Vector3(0, 0.36, 0), Vector3(0, 0, PI * 0.5)), ItemModels.CLOTH)
		for s in [-1.0, 1.0]:
			b.add(ItemModels.tube([Vector3(0.1 * s, 0.25, -0.14), Vector3(0.12 * s, 0.1, -0.2), Vector3(0.11 * s, -0.2, -0.16)], 0.02, 5), dark, base)
		b.add(Mesh3.blob(Vector3(0.016, 0.011, 0.008), 2.0, 4, 6), BRASS, base * T(Vector3(0, -0.02, 0.19))))


static func bench() -> ArrayMesh:
	return _cached("bench", func(b: ItemModels.B):
		var wood := Color("a8703f")
		for i in 3:
			_board(b, Vector3(1.62, 0.045, 0.12), T(Vector3(0, 0.46, -0.13 + i * 0.135)), wood.lerp(Color("b98050"), i * 0.3))
		for i in 2:
			_board(b, Vector3(1.62, 0.1, 0.035), T(Vector3(0, 0.66 + i * 0.14, -0.23 - i * 0.03), Vector3(-0.22, 0, 0)), wood)
		# curly cast-iron sides
		for sx in [-0.7, 0.7]:
			var side := [Vector3(sx, 0.0, 0.18), Vector3(sx, 0.2, 0.15), Vector3(sx, 0.44, 0.14), Vector3(sx, 0.47, 0.0),
				Vector3(sx, 0.44, -0.2), Vector3(sx, 0.7, -0.25), Vector3(sx, 0.9, -0.28)]
			b.add(ItemModels.tube(side, 0.022, 6), IRON, T(), ItemModels.GLOSS)
			b.add(ItemModels.tube([Vector3(sx, 0.0, -0.18), Vector3(sx, 0.2, -0.17), Vector3(sx, 0.44, -0.14)], 0.022, 6), IRON, T(), ItemModels.GLOSS)
			# armrest curl
			var curl := []
			for k in 10:
				var a := k / 9.0 * PI * 1.4
				curl.append(Vector3(sx, 0.62 + sin(a) * 0.05, 0.14 - k * 0.028 + cos(a) * 0.03))
			b.add(ItemModels.tube(curl, 0.018, 6), IRON, T(), ItemModels.GLOSS)
		b.add(ItemModels.box(Vector3(0.12, 0.05, 0.006), 4.0), BRASS, T(Vector3(0, 0.74, -0.258), Vector3(-0.22, 0, 0)), ItemModels.GLOSS))


static func spring_stones(seed_v: int) -> ArrayMesh:
	return _cached("spring_%d" % seed_v, func(b: ItemModels.B):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var n := 11
		for i in n:
			var a := i * TAU / n
			var sz := Vector3(rng.randf_range(0.2, 0.28), rng.randf_range(0.12, 0.2), rng.randf_range(0.16, 0.22))
			var c := Color("9aa0a6").lerp(Color("c2bdb0"), rng.randf())
			b.add(lumpy(sz, 2.6, seed_v + i, 0.1, 8, 12), c, T(Vector3(cos(a) * 0.78, sz.y * 0.55, sin(a) * 0.78), Vector3(0, -a, 0)), ItemModels.PLAIN)
			b.add(Mesh3.blob(Vector3(sz.x * 0.8, 0.02, sz.z * 0.7), 2.0, 5, 10), Color("6f9a3a"), T(Vector3(cos(a) * 0.78, sz.y * 1.05, sin(a) * 0.78), Vector3(0, -a, 0)))
		# spout stone with a wooden pipe and a trickle of water
		b.add(lumpy(Vector3(0.24, 0.34, 0.18), 3.0, seed_v + 50, 0.1), Color("8f959b"), T(Vector3(0, 0.3, -0.98)))
		b.add(Mesh3.blob(Vector3(0.2, 0.03, 0.15), 2.0, 5, 10), Color("6f9a3a"), T(Vector3(0, 0.63, -0.98)))
		b.add(ItemModels.tube([Vector3(0, 0.55, -0.8), Vector3(0, 0.56, -0.6)], 0.035, 8), WOOD_DARK, T())
		b.add(ItemModels.tube([Vector3(0, 0.55, -0.6), Vector3(0, 0.4, -0.52), Vector3(0, 0.1, -0.5)], 0.016, 6), Color("8ed0e8"), T(), ItemModels.GLOSS))


static func chest_body() -> ArrayMesh:
	return _cached("chest", func(b: ItemModels.B):
		var wood := Color("8a5a2e")
		for i in 4:
			_board(b, Vector3(0.8, 0.12, 0.02), T(Vector3(0, 0.07 + i * 0.125, 0.265)), wood.lerp(Color("9c6a38"), (i % 2) * 0.5), false)
			_board(b, Vector3(0.8, 0.12, 0.02), T(Vector3(0, 0.07 + i * 0.125, -0.265)), wood.lerp(Color("9c6a38"), ((i + 1) % 2) * 0.5), false)
			_board(b, Vector3(0.02, 0.12, 0.53), T(Vector3(0.39, 0.07 + i * 0.125, 0)), wood, false)
			_board(b, Vector3(0.02, 0.12, 0.53), T(Vector3(-0.39, 0.07 + i * 0.125, 0)), wood, false)
		b.add(ItemModels.box(Vector3(0.78, 0.02, 0.51)), wood.darkened(0.2), T(Vector3(0, 0.01, 0)))
		# rounded lid
		b.add(Mesh3.lathe([Vector2(0, -0.41), Vector2(0.28, -0.41), Vector2(0.285, 0.0), Vector2(0.28, 0.41), Vector2(0, 0.41)], 24), Color("7a4e26"), T(Vector3(0, 0.51, 0), Vector3(0, 0, PI * 0.5), Vector3(1, 0.45, 1)))
		# iron bands, corners and a brass lock
		for x in [-0.28, 0.28]:
			b.add(ItemModels.box(Vector3(0.05, 0.52, 0.56), 8.0), IRON, T(Vector3(x, 0.26, 0)), ItemModels.GLOSS)
			var band := []
			for k in 13:
				var a := PI * k / 12.0
				band.append(Vector3(x, 0.51 + sin(a) * 0.132, cos(a) * 0.29))
			b.add(ItemModels.tube(band, 0.016, 5), IRON, T(), ItemModels.GLOSS)
		b.add(ItemModels.box(Vector3(0.09, 0.11, 0.02), 4.0), BRASS, T(Vector3(0, 0.46, 0.278)), ItemModels.GLOSS)
		b.add(Mesh3.blob(Vector3(0.012, 0.018, 0.006), 2.0, 4, 6), Color("1b1820"), T(Vector3(0, 0.45, 0.29))))


static func signpost_post() -> ArrayMesh:
	return _cached("signpost", func(b: ItemModels.B):
		b.add(Mesh3.lathe([Vector2(0, 0), Vector2(0.065, 0), Vector2(0.06, 2.0), Vector2(0.055, 2.08), Vector2(0, 2.1)], 12), Color("7a5232"))
		b.add(Mesh3.lathe([Vector2(0, 2.06), Vector2(0.09, 2.06), Vector2(0.0, 2.2)], 4), Color("5a3a22"), T(Vector3.ZERO, Vector3(0, PI * 0.25, 0)))
		for k in 3:
			b.add(ItemModels.tube([Vector3(0.062, 0.3 + k * 0.03, 0), Vector3(0, 0.3 + k * 0.03, 0.062), Vector3(-0.062, 0.3 + k * 0.03, 0), Vector3(0, 0.3 + k * 0.03, -0.062), Vector3(0.062, 0.3 + k * 0.03, 0)], 0.008, 4), ROPE))


## Arrow-shaped board pointing along +X (length l), painted with a border
static func sign_arrow(l: float) -> ArrayMesh:
	return _cached("arrow_%.2f" % l, func(b: ItemModels.B):
		var h := 0.24
		var body := l - 0.16
		b.add(ItemModels.box(Vector3(body, h, 0.04), 8.0), Color("5a3a22"), T(Vector3(body * 0.5, 0, 0)))
		b.add(Mesh3.lathe([Vector2(0, -0.02), Vector2(h * 0.62, -0.02), Vector2(h * 0.62, 0.02), Vector2(0, 0.02)], 3), Color("5a3a22"), T(Vector3(body + 0.02, 0, 0), Vector3(PI * 0.5, 0, 0)))
		b.add(ItemModels.box(Vector3(body - 0.04, h - 0.05, 0.044), 8.0), Color("f1e3c0"), T(Vector3(body * 0.5 + 0.01, 0, 0)))
		b.add(Mesh3.lathe([Vector2(0, -0.022), Vector2(h * 0.46, -0.022), Vector2(h * 0.46, 0.022), Vector2(0, 0.022)], 3), Color("f1e3c0"), T(Vector3(body + 0.01, 0, 0), Vector3(PI * 0.5, 0, 0))))


# ================================================================ obstacles

static func post(height: float) -> ArrayMesh:
	return _cached("post_%.2f" % height, func(b: ItemModels.B):
		# origin at the center (the collider is centered), tapered log with a cut top
		var h := height
		b.add(Mesh3.lathe([Vector2(0, -h * 0.5), Vector2(0.13, -h * 0.5), Vector2(0.12, h * 0.1), Vector2(0.1, h * 0.5 - 0.02), Vector2(0.085, h * 0.5)], 12), Color("7a5232"))
		b.add(Mesh3.lathe([Vector2(0, h * 0.5 - 0.001), Vector2(0.086, h * 0.5 - 0.001), Vector2(0.06, h * 0.5 + 0.004), Vector2(0, h * 0.5 + 0.005)], 12), Color("d9b98a"))
		b.add(ItemModels.ring(0.107, 0.012, h * 0.5 - 0.25), IRON, T(), ItemModels.GLOSS)
		for k in 4:
			b.add(ItemModels.ring(0.112, 0.014, h * 0.5 - 0.42 - k * 0.028), ROPE))


static func plank(size: Vector3, variant := 0) -> ArrayMesh:
	return _cached("plank_%s_%d" % [size, variant], func(b: ItemModels.B):
		_board(b, size, T(), Color("9a6a40").lerp(Color("b07a48"), (variant % 3) * 0.4)))


static func masonry(size: Vector3, seed_v: int, sand := false) -> ArrayMesh:
	return _cached("masonry_%s_%d_%s" % [size, seed_v, sand], func(b: ItemModels.B):
		# centered box made of beveled blocks in running bond
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var bh := 0.5
		var bw := 0.9
		var rows := maxi(int(round(size.y / bh)), 1)
		var base := Color("d9b27a") if sand else Color("a3a7ab")
		for r in rows:
			var y := -size.y * 0.5 + (r + 0.5) * size.y / rows
			var cols := maxi(int(round(size.x / bw)), 1)
			var off := 0.5 if r % 2 == 1 else 0.0
			for c in cols + 1:
				var x0 := -size.x * 0.5 + (c - off) * size.x / cols
				var x1 := x0 + size.x / cols
				x0 = maxf(x0, -size.x * 0.5)
				x1 = minf(x1, size.x * 0.5)
				if x1 - x0 < 0.05:
					continue
				var col := base.lerp(base.darkened(0.25), rng.randf() * 0.6)
				b.add(Mesh3.blob(Vector3((x1 - x0) * 0.5 - 0.02, size.y / rows * 0.5 - 0.02, size.z * 0.5), 5.0, 6, 10), col, T(Vector3((x0 + x1) * 0.5, y, 0)))
		# mortar core
		b.add(ItemModels.box(size * 0.97, 8.0), base.darkened(0.45), T()))


## End caps with tree rings for logs of the given radius (centered, facing ±Y; placed at the ends)
static func log_cap(radius: float) -> ArrayMesh:
	return _cached("logcap_%.2f" % radius, func(b: ItemModels.B):
		var n := 6
		for i in n:
			var r := radius * (1.0 - float(i) / n)
			var c := Color("d9b98a") if i % 2 == 0 else Color("c49c6a")
			b.add(Mesh3.lathe([Vector2(0, 0.004 * i), Vector2(r, 0.004 * i), Vector2(r, 0.004 * i + 0.004), Vector2(0, 0.004 * i + 0.004)], 20), c)
		b.add(Mesh3.lathe([Vector2(radius * 0.98, -0.01), Vector2(radius * 1.03, -0.01), Vector2(radius * 1.03, 0.012), Vector2(radius * 0.98, 0.012)], 20), Color("5a3a22")))


static func root_plate(radius: float, seed_v: int) -> ArrayMesh:
	return _cached("rootplate_%.1f_%d" % [radius, seed_v], func(b: ItemModels.B):
		# soil disc (faces +Y) with roots reaching out and clods
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		b.add(lumpy(Vector3(radius, radius * 0.28, radius), 2.2, seed_v, 0.18, 10, 18), Color("6b4a2e"))
		b.add(lumpy(Vector3(radius * 0.7, radius * 0.3, radius * 0.7), 2.0, seed_v + 1, 0.2, 8, 14), Color("7d5836"), T(Vector3(0, radius * 0.12, 0)))
		for i in 22:
			var a := rng.randf() * TAU
			var start := Vector3(cos(a) * radius * 0.5, rng.randf_range(-0.1, 0.25) * radius, sin(a) * radius * 0.5)
			var len := radius * rng.randf_range(0.7, 1.4)
			var pts := []
			for k in 6:
				var f := k / 5.0
				pts.append(start + Vector3(cos(a), rng.randf_range(-0.4, 0.1) * f, sin(a)) * len * f + Vector3(0, sin(f * PI) * 0.2, 0))
			var r0 := radius * rng.randf_range(0.03, 0.07)
			var radii := []
			for k in 6:
				radii.append(r0 * (1.0 - k / 6.0) + 0.01)
			b.add(Mesh3.tube(pts, radii, 6), Color("5a3a22").lerp(Color("7a5232"), rng.randf()))
		for i in 8:
			var a := rng.randf() * TAU
			b.add(lumpy(Vector3.ONE * radius * rng.randf_range(0.08, 0.16), 2.0, seed_v + 10 + i, 0.25, 6, 10), Color("6b4a2e"), T(Vector3(cos(a) * radius * 0.9, rng.randf_range(-0.2, 0.3) * radius, sin(a) * radius * 0.9))))


# ================================================================ landmarks

static func stone_color(sand: bool) -> Color:
	return Color("d0a872") if sand else Color("a19d94")


static func column(h: float, sand: bool) -> ArrayMesh:
	return _cached("column_%.1f_%s" % [h, sand], func(b: ItemModels.B):
		# centered vertically: base, fluted shaft, capital
		var c := stone_color(sand)
		var y0 := -h * 0.5
		b.add(Mesh3.lathe([Vector2(0, y0), Vector2(0.62, y0), Vector2(0.62, y0 + 0.22), Vector2(0.55, y0 + 0.3), Vector2(0.52, y0 + 0.36), Vector2(0, y0 + 0.36)], 20), c.darkened(0.08))
		var shaft_h := h - 0.36 - 0.35
		b.add(Mesh3.lathe([Vector2(0, y0 + 0.34), Vector2(0.5, y0 + 0.34), Vector2(0.44, y0 + 0.36 + shaft_h), Vector2(0, y0 + 0.36 + shaft_h)], 20), c)
		for k in 12:
			var a := TAU * k / 12.0
			b.add(ItemModels.tube([Vector3(cos(a) * 0.49, y0 + 0.4, sin(a) * 0.49), Vector3(cos(a) * 0.435, y0 + 0.32 + shaft_h, sin(a) * 0.435)], 0.03, 4), c.darkened(0.12))
		var top := y0 + 0.36 + shaft_h
		b.add(Mesh3.lathe([Vector2(0, top), Vector2(0.5, top), Vector2(0.62, top + 0.12), Vector2(0.62, top + 0.2), Vector2(0, top + 0.2)], 20), c.darkened(0.05))
		b.add(ItemModels.box(Vector3(1.35, 0.16, 1.35), 6.0), c.darkened(0.1), T(Vector3(0, top + 0.27, 0)))
		b.add(Mesh3.blob(Vector3(0.6, 0.03, 0.55), 2.0, 5, 10), Color("7aa044"), T(Vector3(0.05, top + 0.36, 0.02))))


static func arch_wall(w: float, h: float, d: float, seed_v: int, sand: bool) -> ArrayMesh:
	return _cached("archwall_%d_%s" % [seed_v, sand], func(b: ItemModels.B):
		# centered wall of stone blocks with a round-arched window, the top broken off unevenly
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var base := stone_color(sand)
		var bh := 0.42
		var rows := int(h / bh)
		var win_w := 1.4
		var win_bottom := 0.9
		var win_top := 2.3
		var arch_r := win_w * 0.5
		for r in rows:
			var y := r * bh + bh * 0.5
			var off := 0.5 if r % 2 == 1 else 0.0
			var cols := int(w / 0.8)
			# ruin: the upper rows lose blocks towards the edges
			var keep_w := w * (1.0 - smoothstep(0.55, 1.0, float(r) / rows) * 0.6 * rng.randf_range(0.6, 1.0))
			for c in cols + 1:
				var x0 := -w * 0.5 + (c - off) * w / cols
				var x1 := x0 + w / cols
				x0 = maxf(x0, -w * 0.5)
				x1 = minf(x1, w * 0.5)
				var xc := (x0 + x1) * 0.5
				if x1 - x0 < 0.1 or absf(xc) > keep_w * 0.5:
					continue
				# leave the window open (rectangle + semicircle)
				var in_rect := absf(xc) < win_w * 0.5 and y > win_bottom and y < win_top
				var in_arch := y >= win_top and Vector2(xc, y - win_top).length() < arch_r
				if in_rect or in_arch:
					continue
				var col := base.lerp(base.darkened(0.3), rng.randf() * 0.6)
				if r == rows - 1 or rng.randf() < 0.08:
					col = col.lerp(Color("7aa044"), 0.35)
				b.add(Mesh3.blob(Vector3((x1 - x0) * 0.5 - 0.025, bh * 0.5 - 0.025, d * 0.5 * rng.randf_range(0.93, 1.0)), 5.0, 6, 10), col, T(Vector3(xc, y, rng.randf_range(-0.03, 0.03))))
		# voussoirs around the arch and a sill
		for k in 9:
			var a := PI * k / 8.0
			b.add(Mesh3.blob(Vector3(0.14, 0.2, d * 0.52), 5.0, 6, 10), base.darkened(0.1), T(Vector3(cos(a) * (arch_r + 0.18), win_top + sin(a) * (arch_r + 0.18), 0), Vector3(0, 0, a - PI * 0.5)))
		b.add(ItemModels.box(Vector3(win_w + 0.3, 0.14, d * 1.1), 6.0), base.darkened(0.15), T(Vector3(0, win_bottom - 0.05, 0))))


static func steps(n: int, w: float, sand: bool) -> ArrayMesh:
	return _cached("steps_%d_%.1f_%s" % [n, w, sand], func(b: ItemModels.B):
		var c := stone_color(sand)
		for i in n:
			var worn := 0.03 * i
			b.add(Mesh3.blob(Vector3((w - i * 0.6) * 0.5, 0.17 - worn * 0.2, 0.6), 5.0, 6, 12), c.darkened(0.05 * i), T(Vector3(0, 0.15 + i * 0.35, -i * 0.9))))


static func standing_stone(h: float, seed_v: int, sand: bool) -> ArrayMesh:
	return _cached("stone_%.1f_%d_%s" % [h, seed_v, sand], func(b: ItemModels.B):
		# centered, lumpy slab; lichen and moss near the top
		var c := stone_color(sand).darkened(0.08)
		b.add(lumpy(Vector3(0.6, h * 0.5, 0.35), 2.6, seed_v, 0.1, 12, 16), c)
		b.add(Mesh3.blob(Vector3(0.45, 0.05, 0.3), 2.0, 5, 10), Color("7aa044"), T(Vector3(0.05, h * 0.47, 0)))
		b.add(Mesh3.blob(Vector3(0.12, 0.1, 0.02), 2.0, 5, 8), Color("d9c86a"), T(Vector3(0.2, h * 0.15, -0.34))))


static func lintel(l: float, seed_v: int, sand: bool) -> ArrayMesh:
	return _cached("lintel_%.1f_%d_%s" % [l, seed_v, sand], func(b: ItemModels.B):
		b.add(lumpy(Vector3(l * 0.5, 0.35, 0.4), 3.0, seed_v, 0.08, 8, 16), stone_color(sand).darkened(0.12))
		b.add(Mesh3.blob(Vector3(l * 0.35, 0.04, 0.3), 2.0, 5, 10), Color("7aa044"), T(Vector3(0, 0.34, 0))))


static func altar(sand: bool) -> ArrayMesh:
	return _cached("altar_%s" % sand, func(b: ItemModels.B):
		var c := stone_color(sand)
		b.add(lumpy(Vector3(1.2, 0.3, 0.7), 4.0, 77, 0.05, 8, 16), c)
		b.add(Mesh3.blob(Vector3(0.9, 0.04, 0.5), 2.2, 5, 12), Color("6f9a3a"), T(Vector3(0, 0.3, 0)))
		for i in 3:
			b.add(Mesh3.blob(Vector3(0.03, 0.03, 0.03), 2.0, 4, 6), [Color("f59ac0"), Color("f2c53d"), Color("ffffff")][i], T(Vector3(-0.3 + i * 0.3, 0.35, 0.1))))


# ================================================================ shelter

## A small wooden rain shelter: four log posts, a back wall of boards, a pitched roof of wooden shingles with
## moss in the joints, a bench along the back and a lantern under the ridge. 2.8 × 2.0 m, ridge at 2.7 m;
## the open side faces +z.
static func shelter() -> ArrayMesh:
	return _cached("shelter", func(b: ItemModels.B):
		var wood := Color("8c5d36")
		var light_wood := Color("b07a48")
		var w := 2.8
		var d := 2.0
		var eave := 2.05
		var ridge := 2.7
		# posts: slightly tapered logs with a stone footing
		for px in [-w * 0.5 + 0.12, w * 0.5 - 0.12]:
			for pz in [-d * 0.5 + 0.12, d * 0.5 - 0.12]:
				b.add(Mesh3.lathe([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.09, eave), Vector2(0, eave + 0.02)], 10), wood, T(Vector3(px, 0, pz)))
				b.add(Mesh3.blob(Vector3(0.2, 0.09, 0.2), 2.4, 6, 10), Color("8d8f8a"), T(Vector3(px, 0.02, pz)))
		# beams under the roof edges and a ridge beam
		for pz in [-d * 0.5 + 0.12, d * 0.5 - 0.12]:
			b.add(ItemModels.box(Vector3(w + 0.2, 0.14, 0.14), 6.0), wood, T(Vector3(0, eave, pz)))
		b.add(ItemModels.box(Vector3(w + 0.5, 0.14, 0.14), 6.0), wood, T(Vector3(0, ridge, 0)))
		# back wall: vertical boards with a gap to the roof
		var n := 11
		for i in n:
			var x := -w * 0.5 + 0.13 + (i + 0.5) * (w - 0.26) / n
			_board(b, Vector3((w - 0.26) / n - 0.015, 1.55, 0.04), T(Vector3(x, 0.85, -d * 0.5 + 0.1)), wood.lerp(light_wood, float(i % 3) * 0.3), false)
		b.add(ItemModels.box(Vector3(w - 0.2, 0.1, 0.1), 6.0), wood, T(Vector3(0, 1.66, -d * 0.5 + 0.1)))
		# roof: two slopes of overlapping shingle rows (with moss in the joints)
		var slope_len := sqrt((d * 0.5 + 0.35) * (d * 0.5 + 0.35) + (ridge - eave + 0.1) * (ridge - eave + 0.1))
		var ang := atan2(ridge - eave + 0.1, d * 0.5 + 0.35)
		for side in [-1.0, 1.0]:
			var rows := 6
			for r in rows:
				var t := (r + 0.5) / rows
				var pz: float = side * (d * 0.5 + 0.35) * (1.0 - t)
				var py := eave - 0.05 + (ridge - eave + 0.1) * t + 0.08
				var shade := Color("6e4a2c").lerp(Color("9a6a40"), float((r * 7 + int(side + 1.0)) % 4) / 4.0)
				b.add(ItemModels.box(Vector3(w + 0.55, 0.05, slope_len / rows + 0.08), 6.0), shade,
					T(Vector3(0, py, pz), Vector3(side * ang, 0, 0)))
				# single shingles standing out a little, and moss
				for k in 9:
					var sx := -w * 0.5 - 0.2 + (k + 0.3 + fmod(r * 0.37, 1.0) * 0.4) * (w + 0.4) / 9.0
					b.add(ItemModels.box(Vector3(0.26, 0.03, 0.2), 4.0), shade.lightened(0.08 * float((k + r) % 3)),
						T(Vector3(sx, py + 0.035, pz + side * 0.05), Vector3(side * ang, 0, 0)))
				b.add(ItemModels.box(Vector3(w + 0.5, 0.02, 0.05), 3.0), Color("6f8a3a"), T(Vector3(0, py + 0.02, pz - side * (slope_len / rows) * 0.45), Vector3(side * ang, 0, 0)))
		# bench along the back wall
		for i in 2:
			_board(b, Vector3(w - 0.45, 0.05, 0.16), T(Vector3(0, 0.46, -d * 0.5 + 0.32 + i * 0.17)), light_wood)
		for bx in [-w * 0.5 + 0.35, 0.0, w * 0.5 - 0.35]:
			b.add(ItemModels.box(Vector3(0.08, 0.44, 0.3), 6.0), wood, T(Vector3(bx, 0.22, -d * 0.5 + 0.4)))
		# lantern hanging from the ridge beam: a little iron frame around a warm glass
		b.add(ItemModels.tube([Vector3(0.6, ridge - 0.07, 0), Vector3(0.6, ridge - 0.4, 0)], 0.008, 4), IRON)
		b.add(Mesh3.lathe([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.075, 0.16), Vector2(0.04, 0.2), Vector2(0, 0.22)], 8), Color("ffcf7a"),
			T(Vector3(0.6, ridge - 0.64, 0)), ItemModels.GLOSS)
		for k in 4:
			var a := k * TAU / 4.0
			b.add(ItemModels.tube([Vector3(0.6 + cos(a) * 0.08, ridge - 0.64, sin(a) * 0.08), Vector3(0.6 + cos(a) * 0.08, ridge - 0.46, sin(a) * 0.08)], 0.008, 4), IRON)
		b.add(Mesh3.lathe([Vector2(0, 0), Vector2(0.1, 0), Vector2(0, 0.08)], 8), IRON, T(Vector3(0.6, ridge - 0.46, 0))))


# ================================================================ campfire

## A fire ring: a circle of blackened field stones around ash, a little tipi of charred logs in the middle.
static func fire_ring(seed_v: int) -> ArrayMesh:
	return _cached("fire_ring_%d" % seed_v, func(b: ItemModels.B):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v
		var n := 10
		for i in n:
			var a := i * TAU / n + rng.randf_range(-0.12, 0.12)
			var r := rng.randf_range(0.62, 0.72)
			var st := lumpy(Vector3(rng.randf_range(0.14, 0.2), rng.randf_range(0.1, 0.15), rng.randf_range(0.12, 0.17)), 2.4, seed_v + i, 0.18, 6, 10)
			var tone := Color("8e8f8a").lerp(Color("5d5c58"), rng.randf())
			b.add(st, tone, T(Vector3(cos(a) * r, 0.06, sin(a) * r), Vector3(0, -a, rng.randf_range(-0.2, 0.2))))
		# ash bed
		b.add(Mesh3.blob(Vector3(0.55, 0.03, 0.55), 2.2, 4, 18), Color("6d6862"), T(Vector3(0, 0.0, 0)))
		b.add(Mesh3.blob(Vector3(0.35, 0.03, 0.35), 2.2, 4, 14), Color("3e3a37"), T(Vector3(0, 0.015, 0)))
		# charred log tipi
		for i in 5:
			var a2 := i * TAU / 5.0 + 0.3
			var base := Vector3(cos(a2) * 0.32, 0.03, sin(a2) * 0.32)
			b.add(ItemModels.tube([base, Vector3(cos(a2) * 0.05, 0.42, sin(a2) * 0.05)], 0.045, 7), Color("3a2b22") if i % 2 == 0 else Color("4a3527")))


## A neat stack of split firewood (origin at the bottom center)
static func woodpile() -> ArrayMesh:
	return _cached("woodpile", func(b: ItemModels.B):
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for row in 3:
			var count := 4 - row
			for i in count:
				var x := (i - (count - 1) * 0.5) * 0.17
				var y := 0.08 + row * 0.14
				b.add(Mesh3.lathe([Vector2(0, -0.35), Vector2(0.075, -0.35), Vector2(0.075, 0.35), Vector2(0, 0.35)], 7), Color("8c5d36").lerp(Color("a8703f"), rng.randf()), T(Vector3(x, y, rng.randf_range(-0.04, 0.04)), Vector3(PI * 0.5, 0, 0)))
				b.add(Mesh3.lathe([Vector2(0, 0.35), Vector2(0.07, 0.35), Vector2(0, 0.351)], 7), Color("e2c28f"), T(Vector3(x, y, rng.randf_range(-0.04, 0.04)), Vector3(PI * 0.5, 0, 0))))


## A log to sit on, lying on its side (origin at the bottom center, along x)
static func seat_log(length: float) -> ArrayMesh:
	return _cached("seat_log_%.1f" % length, func(b: ItemModels.B):
		b.add(Mesh3.lathe([Vector2(0, -length * 0.5), Vector2(0.2, -length * 0.5), Vector2(0.21, 0), Vector2(0.2, length * 0.5), Vector2(0, length * 0.5)], 12), WOOD, T(Vector3(0, 0.2, 0), Vector3(0, 0, PI * 0.5)))
		for s in [-1.0, 1.0]:
			b.add(Mesh3.lathe([Vector2(0, 0), Vector2(0.19, 0), Vector2(0, 0.002)], 12), Color("e2c28f"), T(Vector3(s * length * 0.5, 0.2, 0), Vector3(0, 0, -s * PI * 0.5)))
		# a flat seat cut on top
		b.add(ItemModels.box(Vector3(length * 0.8, 0.02, 0.2), 4.0), Color("c99257"), T(Vector3(0, 0.395, 0))))
