class_name ItemModels
extends RefCounted
## Hand-built procedural models for all items: parts from Mesh3 merged into one mesh with vertex colors
## (one draw call per item), toon-shaded like the scout. Real-world sizes, centered on the bounding box.

static var _cache := {}
static var _mat: ShaderMaterial

const PLAIN := 1.0
const CLOTH := 0.5
const GLOSS := 0.0


## Mesh builder: transforms and merges parts, each with a color and a material flag
class B:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()

	func add(m: ArrayMesh, c: Color, xf := Transform3D.IDENTITY, flag := 1.0) -> void:
		var arr := m.surface_get_arrays(0)
		var base := verts.size()
		var lc := c.srgb_to_linear()
		lc.a = flag
		var nb := xf.basis.inverse().transposed()
		for v in arr[Mesh.ARRAY_VERTEX]:
			verts.append(xf * v)
		for n in arr[Mesh.ARRAY_NORMAL]:
			norms.append((nb * n).normalized())
		for i in arr[Mesh.ARRAY_INDEX]:
			idx.append(base + i)
		for i in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
			cols.append(lc)

	func commit() -> ArrayMesh:
		var lo := Vector3.INF
		var hi := -Vector3.INF
		for v in verts:
			lo = lo.min(v)
			hi = hi.max(v)
		var c := (lo + hi) * 0.5
		for i in verts.size():
			verts[i] -= c
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/scout.gdshader")
		_mat.set_shader_parameter("use_vertex_color", true)
	return _mat


static func mesh(id: String) -> ArrayMesh:
	if not _cache.has(id):
		var b := B.new()
		_build(id, b)
		var m := b.commit()
		m.surface_set_material(0, material())
		_cache[id] = m
	return _cache[id]


# ---------------------------------------------------------------- part helpers

static func T(pos := Vector3.ZERO, rot := Vector3.ZERO, sc := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(sc), pos)


## Cylinder standing on y = 0 with softly beveled edges
static func cyl(r0: float, r1: float, h: float, segs := 18, bevel := 0.004) -> ArrayMesh:
	var b := minf(bevel, minf(r0, h) * 0.3)
	return Mesh3.lathe([Vector2(0, 0), Vector2(r0 - b, 0), Vector2(r0, b), Vector2(r1, h - b), Vector2(r1 - b, h), Vector2(0, h)], segs)


static func ball(r: Vector3, p := 2.0, rings := 8, segs := 14) -> ArrayMesh:
	return Mesh3.blob(r, p, rings, segs)


## Rounded box (size = full extents)
static func box(size: Vector3, p := 5.0) -> ArrayMesh:
	return Mesh3.blob(size * 0.5, p, 6, 12)


static func tube(pts: Array, r: float, segs := 6) -> ArrayMesh:
	return Mesh3.tube(pts, r, segs)


## Ring in the XZ plane
static func ring(rad: float, r: float, y := 0.0, n := 20) -> ArrayMesh:
	var pts := []
	for i in n + 1:
		var a := TAU * i / n
		pts.append(Vector3(cos(a) * rad, y, sin(a) * rad))
	return Mesh3.tube(pts, r, 6, [], 1.0, false)


static func lathe(prof: Array, segs := 18, dz := 1.0) -> ArrayMesh:
	return Mesh3.lathe(prof, segs, dz)


# ---------------------------------------------------------------- models

static func _build(id: String, b: B) -> void:
	match id:
		"apfel":
			b.add(lathe([Vector2(0, 0.006), Vector2(0.03, 0.0), Vector2(0.05, 0.016), Vector2(0.057, 0.042), Vector2(0.05, 0.07), Vector2(0.032, 0.083), Vector2(0.012, 0.078), Vector2(0, 0.072)], 20), Color("d8322a"))
			b.add(ball(Vector3(0.022, 0.018, 0.01)), Color("f06a3a"), T(Vector3(0.03, 0.05, -0.04), Vector3(0.3, 0.6, 0)))
			b.add(tube([Vector3(0, 0.07, 0), Vector3(0.004, 0.09, 0.002), Vector3(0.01, 0.1, 0)], 0.003), Color("5a3a1e"))
			b.add(ball(Vector3(0.018, 0.004, 0.009)), Color("5fa332"), T(Vector3(0.02, 0.095, 0), Vector3(0, 0, 0.4)))
		"beeren":
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 8:
				var a := i * 2.4
				var r := 0.012 + (i % 3) * 0.008
				b.add(ball(Vector3.ONE * 0.017, 2.0, 6, 10), Color("5a1f6e").lerp(Color("8a2c7a"), rng.randf() * 0.5), T(Vector3(cos(a) * r, 0.017 + (i % 2) * 0.014, sin(a) * r)), GLOSS)
			b.add(ball(Vector3(0.03, 0.004, 0.014)), Color("4f8f3a"), T(Vector3(0.02, 0.045, 0), Vector3(0, 0.5, 0.3)))
			b.add(ball(Vector3(0.026, 0.004, 0.012)), Color("5fa332"), T(Vector3(-0.02, 0.042, 0.01), Vector3(0, -0.6, -0.3)))
		"brot":
			b.add(ball(Vector3(0.11, 0.055, 0.065), 2.6, 10, 16), Color("c98b45"), T(Vector3(0, 0.055, 0)))
			for i in 3:
				var x := -0.05 + i * 0.05
				b.add(tube([Vector3(x - 0.012, 0.104, -0.035), Vector3(x + 0.012, 0.108, 0.035)], 0.009), Color("ecc17e"))
		"muesliriegel":
			b.add(box(Vector3(0.12, 0.028, 0.045)), Color("e8b23c"), T(Vector3(0, 0.014, 0)), GLOSS)
			for s in [-1.0, 1.0]:
				b.add(box(Vector3(0.012, 0.01, 0.05), 3.0), Color("c48a22"), T(Vector3(0.064 * s, 0.014, 0)))
			b.add(box(Vector3(0.05, 0.03, 0.047)), Color("c8453e"), T(Vector3(0, 0.014, 0)))
			b.add(box(Vector3(0.03, 0.031, 0.02)), Color("fff4d6"), T(Vector3(0, 0.014, 0)))
		"bohnen":
			b.add(cyl(0.04, 0.04, 0.11, 20), Color("b9c2c9"), T(), GLOSS)
			b.add(cyl(0.0405, 0.0405, 0.07, 20, 0.0), Color("c8453e"), T(Vector3(0, 0.02, 0)))
			b.add(cyl(0.041, 0.041, 0.018, 20, 0.0), Color("fff0d2"), T(Vector3(0, 0.046, 0)))
			b.add(ring(0.039, 0.003, 0.11), Color("9aa3ab"), T(), GLOSS)
			b.add(ring(0.039, 0.003, 0.002), Color("9aa3ab"), T(), GLOSS)
		"wasserflasche":
			b.add(lathe([Vector2(0, 0), Vector2(0.034, 0), Vector2(0.037, 0.006), Vector2(0.037, 0.16), Vector2(0.03, 0.19), Vector2(0.018, 0.2), Vector2(0.018, 0.21), Vector2(0, 0.21)], 20), Color("4a8fd8"), T(), GLOSS)
			b.add(cyl(0.021, 0.021, 0.03, 16), Color("2e3338"), T(Vector3(0, 0.205, 0)))
			b.add(Mesh3.tube([Vector3(0, 0.232, -0.01), Vector3(0, 0.25, 0), Vector3(0, 0.232, 0.01)], 0.004, 5), Color("2e3338"))
			b.add(cyl(0.0375, 0.0375, 0.03, 20, 0.0), Color("f2efe6"), T(Vector3(0, 0.08, 0)))
		"limonade":
			b.add(lathe([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.034, 0.008), Vector2(0.034, 0.12), Vector2(0.026, 0.15), Vector2(0.013, 0.175), Vector2(0.014, 0.19), Vector2(0, 0.19)], 20), Color("e3cf4a"), T(), GLOSS)
			b.add(cyl(0.0345, 0.0345, 0.05, 20, 0.0), Color("f4ecd0"), T(Vector3(0, 0.04, 0)))
			b.add(cyl(0.0348, 0.0348, 0.012, 20, 0.0), Color("ec8a34"), T(Vector3(0, 0.058, 0)))
			b.add(ball(Vector3(0.016, 0.008, 0.016)), Color("f4f1ea"), T(Vector3(0, 0.196, 0)))
			b.add(Mesh3.tube([Vector3(-0.016, 0.16, 0), Vector3(-0.018, 0.2, 0), Vector3(0.018, 0.2, 0), Vector3(0.016, 0.16, 0)], 0.002, 4), Color("9fb6c4"), T(), GLOSS)
		"verband":
			b.add(cyl(0.03, 0.03, 0.065, 18, 0.006), Color("f2efe8"), T(Vector3(0, 0.03, -0.0325), Vector3(PI * 0.5, 0, 0)), CLOTH)
			b.add(box(Vector3(0.06, 0.004, 0.06), 4.0), Color("f2efe8"), T(Vector3(0.05, 0.002, 0.0)), CLOTH)
		"regenjacke":
			b.add(box(Vector3(0.3, 0.07, 0.24), 4.0), Color("ec8a34"), T(Vector3(0, 0.035, 0)), CLOTH)
			b.add(ball(Vector3(0.1, 0.04, 0.06), 2.4), Color("d97726"), T(Vector3(0, 0.07, -0.1)), CLOTH)
			b.add(box(Vector3(0.008, 0.074, 0.22), 4.0), Color("2e3338"), T(Vector3(0.02, 0.036, 0.0)))
			b.add(box(Vector3(0.09, 0.075, 0.06), 4.0), Color("d97726"), T(Vector3(-0.07, 0.036, 0.05)), CLOTH)
		"pullover":
			b.add(box(Vector3(0.28, 0.08, 0.24), 4.0), Color("8c3a3a"), T(Vector3(0, 0.04, 0)), CLOTH)
			for s in [-1.0, 1.0]:
				b.add(box(Vector3(0.05, 0.05, 0.08), 3.0), Color("a54a4a"), T(Vector3(0.1 * s, 0.085, 0.07)), CLOTH)
			b.add(ring(0.05, 0.014, 0.085), Color("a54a4a"), T(Vector3(0, 0, -0.07)), CLOTH)
			b.add(box(Vector3(0.2, 0.012, 0.01), 3.0), Color("f2efe6"), T(Vector3(0, 0.081, 0.03)), CLOTH)
		"muetze":
			var dome := []
			for i in 13:
				var a := PI * 0.5 * i / 12.0
				dome.append(Vector2(cos(a) * 0.085, 0.02 + sin(a) * 0.09))
			b.add(lathe(dome, 20), Color("3f6fcf"), T(), CLOTH)
			b.add(lathe([Vector2(0.084, 0.0), Vector2(0.09, 0.004), Vector2(0.09, 0.04), Vector2(0.084, 0.044)], 20), Color("2e56a8"), T(), CLOTH)
			b.add(ball(Vector3.ONE * 0.03), Color("f4f1ea"), T(Vector3(0, 0.12, 0)), CLOTH)
		"sonnenhut":
			b.add(lathe([Vector2(0.075, 0.0), Vector2(0.2, 0.002), Vector2(0.21, 0.01), Vector2(0.2, 0.016), Vector2(0.078, 0.014)], 28), Color("e8cf8a"), T(), CLOTH)
			b.add(lathe([Vector2(0.08, 0.0), Vector2(0.078, 0.07), Vector2(0.06, 0.095), Vector2(0.0, 0.1)], 24), Color("e8cf8a"), T(), CLOTH)
			b.add(lathe([Vector2(0.081, 0.012), Vector2(0.083, 0.015), Vector2(0.082, 0.035), Vector2(0.079, 0.038)], 24), Color("c8453e"), T(), CLOTH)
		"seil":
			for k in 3:
				b.add(ring(0.095 - k * 0.012, 0.016, 0.016 + k * 0.008), Color("cdb07a").darkened(k * 0.06), T(Vector3(k * 0.006, 0, k * 0.004)))
			b.add(tube([Vector3(0.09, 0.02, 0), Vector3(0.14, 0.012, 0.03), Vector3(0.17, 0.01, 0.07)], 0.015), Color("cdb07a"))
			b.add(tube([Vector3(-0.08, 0.03, 0.04), Vector3(-0.12, 0.012, 0.08), Vector3(-0.13, 0.01, 0.13)], 0.015), Color("c4a66e"))
		"taschenlampe":
			var r := T(Vector3.ZERO, Vector3(0, 0, -PI * 0.5))
			b.add(cyl(0.02, 0.02, 0.13, 16), Color("2a2c30"), r, GLOSS)
			b.add(lathe([Vector2(0, 0.13), Vector2(0.02, 0.13), Vector2(0.03, 0.165), Vector2(0.03, 0.18), Vector2(0, 0.18)], 16), Color("3a3d42"), r, GLOSS)
			b.add(cyl(0.026, 0.026, 0.004, 16, 0.0), Color("fff6c8"), r * T(Vector3(0, 0.179, 0)))
			b.add(box(Vector3(0.012, 0.018, 0.012)), Color("ec8a34"), T(Vector3(0.07, 0.02, 0)))
		"fernglas":
			for s in [-1.0, 1.0]:
				var r := T(Vector3(0.034 * s, 0.03, 0), Vector3(PI * 0.5, 0, 0))
				b.add(cyl(0.03, 0.028, 0.1, 16), Color("27302a"), r * T(Vector3(0, -0.05, 0)))
				b.add(cyl(0.02, 0.018, 0.02, 14), Color("1b1f1c"), r * T(Vector3(0, -0.07, 0)))
				b.add(cyl(0.026, 0.026, 0.003, 14, 0.0), Color("7fb6d8"), r * T(Vector3(0, 0.05, 0)), GLOSS)
			b.add(box(Vector3(0.04, 0.02, 0.05)), Color("1b1f1c"), T(Vector3(0, 0.035, 0)))
			b.add(tube([Vector3(-0.06, 0.03, 0.03), Vector3(-0.09, 0.005, 0.08), Vector3(0, 0.003, 0.12), Vector3(0.09, 0.005, 0.08), Vector3(0.06, 0.03, 0.03)], 0.005), Color("6b4428"))
		"kamera":
			b.add(box(Vector3(0.12, 0.075, 0.05)), Color("24262a"), T(Vector3(0, 0.0375, 0)))
			b.add(box(Vector3(0.121, 0.03, 0.051)), Color("8b5a36"), T(Vector3(0, 0.03, 0)))
			b.add(cyl(0.024, 0.022, 0.04, 18), Color("1b1c1f"), T(Vector3(0, 0.04, -0.025), Vector3(-PI * 0.5, 0, 0)))
			b.add(cyl(0.017, 0.017, 0.003, 16, 0.0), Color("7fb6d8"), T(Vector3(0, 0.04, -0.065), Vector3(-PI * 0.5, 0, 0)), GLOSS)
			b.add(box(Vector3(0.03, 0.015, 0.02)), Color("f4f1ea"), T(Vector3(0.035, 0.083, 0)))
			b.add(cyl(0.007, 0.007, 0.008), Color("d1493f"), T(Vector3(-0.035, 0.075, 0)))
		"feldhandbuch":
			b.add(box(Vector3(0.15, 0.028, 0.2), 6.0), Color("4f7a3a"), T(Vector3(0, 0.014, 0)))
			b.add(box(Vector3(0.14, 0.022, 0.19), 8.0), Color("f4ecd6"), T(Vector3(0.006, 0.014, 0)))
			b.add(box(Vector3(0.012, 0.03, 0.2), 3.0), Color("3c5f2c"), T(Vector3(-0.074, 0.014, 0)))
			b.add(box(Vector3(0.008, 0.002, 0.06), 4.0), Color("c8453e"), T(Vector3(0.02, 0.029, 0.12)))
			b.add(ball(Vector3(0.025, 0.002, 0.025), 2.0), Color("f2c53d"), T(Vector3(0.01, 0.029, -0.02)))
		"wasserpistole":
			b.add(box(Vector3(0.14, 0.05, 0.035)), Color("3cc7e8"), T(Vector3(0, 0.07, 0)), GLOSS)
			b.add(box(Vector3(0.035, 0.075, 0.03)), Color("2aa3c8"), T(Vector3(0.04, 0.03, 0), Vector3(0, 0, -0.25)), GLOSS)
			b.add(cyl(0.01, 0.008, 0.05, 12), Color("f2c53d"), T(Vector3(-0.07, 0.075, 0), Vector3(0, 0, PI * 0.5)))
			b.add(ball(Vector3(0.03, 0.025, 0.025)), Color("ec8a34"), T(Vector3(0.0, 0.11, 0)), GLOSS)
		"gummihuhn":
			b.add(ball(Vector3(0.045, 0.04, 0.08), 2.0, 10, 14), Color("f5d018"), T(Vector3(0, 0.04, 0)), GLOSS)
			b.add(tube([Vector3(0, 0.05, -0.06), Vector3(0, 0.1, -0.09), Vector3(0, 0.14, -0.1)], 0.014), Color("f5d018"), T(), GLOSS)
			b.add(ball(Vector3.ONE * 0.024), Color("f5d018"), T(Vector3(0, 0.15, -0.1)), GLOSS)
			b.add(ball(Vector3(0.006, 0.018, 0.012)), Color("e8453a"), T(Vector3(0, 0.175, -0.1)))
			b.add(lathe([Vector2(0.008, 0), Vector2(0.0, 0.025)], 8), Color("ec8a34"), T(Vector3(0, 0.148, -0.12), Vector3(-PI * 0.5, 0, 0)))
			for s in [-1.0, 1.0]:
				b.add(ball(Vector3(0.004, 0.004, 0.004)), Color("1b1820"), T(Vector3(0.018 * s, 0.158, -0.114)))
		"stein":
			b.add(ball(Vector3(0.07, 0.035, 0.05), 2.2, 10, 16), Color("8a8f98"), T(Vector3(0, 0.035, 0)), GLOSS)
			b.add(Mesh3.tube(_ellipse(0.071, 0.051, 0.036, 24), 0.006, 5, [], 1.0, false), Color("f4f1ea"))
		# ---------------------------------------------------------- new items
		"kaese":
			b.add(lathe([Vector2(0, 0), Vector2(0.09, 0), Vector2(0.09, 0.05), Vector2(0, 0.05)], 3), Color("f2c94c"), T(Vector3.ZERO, Vector3(0, 0.3, 0)))
			b.add(lathe([Vector2(0.088, 0), Vector2(0.092, 0.0), Vector2(0.092, 0.05), Vector2(0.088, 0.05)], 3), Color("d9a53a"), T(Vector3.ZERO, Vector3(0, 0.3, 0)))
			for h: Vector3 in [Vector3(0.02, 0.05, 0.0), Vector3(-0.015, 0.05, 0.02), Vector3(0.0, 0.05, -0.03)]:
				b.add(ball(Vector3(0.008, 0.003, 0.008)), Color("d9a53a"), T(h))
		"pilze":
			for i in 3:
				var p := Vector3([-0.025, 0.02, 0.0][i], 0, [0.0, 0.01, -0.025][i])
				var h: float = [0.05, 0.04, 0.03][i]
				b.add(cyl(0.008, 0.007, h, 10), Color("f1e7d3"), T(p))
				b.add(lathe([Vector2(0.0, h - 0.004), Vector2(0.03, h - 0.002), Vector2(0.028, h + 0.01), Vector2(0.015, h + 0.02), Vector2(0.0, h + 0.023)], 16), Color("b8552f"), T(p))
				b.add(ball(Vector3.ONE * 0.004), Color("f4f1ea"), T(p + Vector3(0.01, h + 0.016, 0.005)))
		"honig":
			b.add(lathe([Vector2(0, 0), Vector2(0.04, 0), Vector2(0.045, 0.01), Vector2(0.045, 0.07), Vector2(0.036, 0.085), Vector2(0.036, 0.09), Vector2(0, 0.09)], 20), Color("e0a030"), T(), GLOSS)
			b.add(lathe([Vector2(0, 0.085), Vector2(0.05, 0.08), Vector2(0.052, 0.086), Vector2(0.03, 0.1), Vector2(0, 0.102)], 20), Color("d1493f"), T(), CLOTH)
			b.add(ring(0.039, 0.003, 0.089), Color("f4ecd6"))
			b.add(cyl(0.046, 0.046, 0.03, 20, 0.0), Color("f4ecd6"), T(Vector3(0, 0.03, 0)))
		"trockenobst":
			b.add(ball(Vector3(0.05, 0.07, 0.03), 3.0, 8, 14), Color("c9a06a"), T(Vector3(0, 0.07, 0)))
			b.add(box(Vector3(0.1, 0.02, 0.04), 4.0), Color("b58b58"), T(Vector3(0, 0.14, 0)))
			b.add(box(Vector3(0.05, 0.035, 0.002), 4.0), Color("f4ecd6"), T(Vector3(0, 0.075, -0.03)))
			for c: Color in [Color("ec8a34"), Color("8a2c4a"), Color("f2c53d")]:
				b.add(ball(Vector3.ONE * 0.008), c, T(Vector3(randf_range(-0.012, 0.012), 0.075, -0.034)))
		"schokolade":
			b.add(box(Vector3(0.13, 0.014, 0.06), 6.0), Color("5a3320"), T(Vector3(0, 0.007, 0)), GLOSS)
			for i in 3:
				b.add(box(Vector3(0.002, 0.016, 0.058), 3.0), Color("3f2214"), T(Vector3(-0.02 + i * 0.03, 0.008, 0)))
			b.add(box(Vector3(0.06, 0.016, 0.062), 6.0), Color("8a62c4"), T(Vector3(-0.036, 0.008, 0)))
			b.add(box(Vector3(0.012, 0.017, 0.062), 6.0), Color("d8dde2"), T(Vector3(-0.002, 0.008, 0)), GLOSS)
		"sandwich":
			var rot := Vector3(0, 0.35, 0)
			b.add(lathe([Vector2(0, 0), Vector2(0.075, 0), Vector2(0.075, 0.018), Vector2(0, 0.018)], 3), Color("e6c68a"), T(Vector3.ZERO, rot))
			b.add(lathe([Vector2(0, 0), Vector2(0.08, 0), Vector2(0.08, 0.006), Vector2(0, 0.006)], 3), Color("78b83a"), T(Vector3(0, 0.018, 0), rot))
			b.add(lathe([Vector2(0, 0), Vector2(0.072, 0), Vector2(0.072, 0.006), Vector2(0, 0.006)], 3), Color("f2c53d"), T(Vector3(0, 0.024, 0), rot))
			b.add(cyl(0.022, 0.022, 0.006, 14), Color("d8453e"), T(Vector3(0.01, 0.026, 0.0)))
			b.add(lathe([Vector2(0, 0), Vector2(0.075, 0), Vector2(0.075, 0.018), Vector2(0, 0.018)], 3), Color("e6c68a"), T(Vector3(0, 0.031, 0), rot))
		"moehre":
			var r := T(Vector3.ZERO, Vector3(0, 0, PI * 0.5))
			b.add(lathe([Vector2(0.0, 0.0), Vector2(0.006, 0.01), Vector2(0.018, 0.1), Vector2(0.02, 0.13), Vector2(0.0, 0.135)], 14), Color("ef7d22"), r)
			for i in 4:
				b.add(tube([Vector3(-0.13, 0.0, 0), Vector3(-0.17, 0.01 + i * 0.01, (i - 1.5) * 0.012), Vector3(-0.2, 0.02 + i * 0.012, (i - 1.5) * 0.02)], 0.004), Color("5fa332"))
		"keks":
			b.add(cyl(0.07, 0.07, 0.045, 24), Color("3f6fcf"), T(), GLOSS)
			b.add(cyl(0.072, 0.072, 0.012, 24), Color("2e56a8"), T(Vector3(0, 0.04, 0)), GLOSS)
			b.add(cyl(0.0705, 0.0705, 0.012, 24, 0.0), Color("f2c53d"), T(Vector3(0, 0.014, 0)))
			b.add(cyl(0.03, 0.03, 0.008, 16), Color("d9a55a"), T(Vector3(0, 0.052, 0)))
		"tee":
			b.add(cyl(0.035, 0.035, 0.2, 18), Color("c8453e"), T(), GLOSS)
			b.add(cyl(0.037, 0.035, 0.05, 18), Color("9aa3ab"), T(Vector3(0, 0.2, 0)), GLOSS)
			b.add(cyl(0.0355, 0.0355, 0.012, 18, 0.0), Color("f4f1ea"), T(Vector3(0, 0.05, 0)))
		"kakao":
			b.add(cyl(0.042, 0.042, 0.12, 20), Color("7a4a2a"), T())
			b.add(cyl(0.0425, 0.0425, 0.06, 20, 0.0), Color("f4ecd6"), T(Vector3(0, 0.03, 0)))
			b.add(ball(Vector3(0.02, 0.012, 0.004)), Color("7a4a2a"), T(Vector3(0, 0.06, -0.043)))
			b.add(cyl(0.044, 0.044, 0.012, 20), Color("c8453e"), T(Vector3(0, 0.115, 0)), GLOSS)
		"saft":
			b.add(box(Vector3(0.05, 0.09, 0.035), 6.0), Color("ec8a34"), T(Vector3(0, 0.045, 0)))
			b.add(box(Vector3(0.051, 0.04, 0.036), 6.0), Color("f2c53d"), T(Vector3(0, 0.04, 0)))
			b.add(ball(Vector3(0.012, 0.012, 0.004)), Color("5fa332"), T(Vector3(0, 0.045, -0.018)))
			b.add(tube([Vector3(0.012, 0.09, 0), Vector3(0.014, 0.12, 0), Vector3(0.02, 0.13, 0)], 0.003), Color("f4f1ea"))
		"pflaster":
			b.add(box(Vector3(0.07, 0.015, 0.05), 6.0), Color("f4ecd6"), T(Vector3(0, 0.0075, 0)))
			b.add(box(Vector3(0.03, 0.016, 0.01), 4.0), Color("d8453e"), T(Vector3(0, 0.0078, 0)))
			b.add(box(Vector3(0.01, 0.016, 0.03), 4.0), Color("d8453e"), T(Vector3(0, 0.0078, 0)))
		"erste_hilfe":
			b.add(box(Vector3(0.18, 0.07, 0.12)), Color("d8453e"), T(Vector3(0, 0.035, 0)))
			b.add(box(Vector3(0.06, 0.071, 0.02), 4.0), Color("f4f1ea"), T(Vector3(0, 0.035, -0.001)))
			b.add(box(Vector3(0.02, 0.0712, 0.06), 4.0), Color("f4f1ea"), T(Vector3(0, 0.035, 0)))
			b.add(tube([Vector3(-0.04, 0.07, 0), Vector3(-0.03, 0.09, 0), Vector3(0.03, 0.09, 0), Vector3(0.04, 0.07, 0)], 0.007), Color("2e3338"))
		"sonnencreme":
			b.add(lathe([Vector2(0.0, 0.0), Vector2(0.022, 0.0), Vector2(0.025, 0.02), Vector2(0.028, 0.11), Vector2(0.004, 0.13), Vector2(0.0, 0.13)], 16, 0.45), Color("f2c53d"), T(Vector3.ZERO, Vector3(0, 0, PI * 0.5)), GLOSS)
			b.add(cyl(0.018, 0.018, 0.025, 14), Color("3f6fcf"), T(Vector3(0.0, 0.0, 0), Vector3(0, 0, PI * 0.5)))
			b.add(ball(Vector3(0.02, 0.02, 0.003)), Color("ec8a34"), T(Vector3(-0.06, 0.0, -0.013)))
		"schal":
			var pts := []
			for i in 25:
				var t := i / 24.0
				pts.append(Vector3(sin(t * 5.0) * 0.07, 0.015 + t * 0.03, lerpf(-0.12, 0.12, t)))
			var ups := []
			for i in 25:
				ups.append(Vector3.UP)
			b.add(Mesh3.tube(pts, 0.04, 8, ups, 0.25), Color("d1493f"), T(), CLOTH)
			for i in 5:
				b.add(tube([Vector3(-0.03 + i * 0.015, 0.015, -0.13), Vector3(-0.03 + i * 0.015, 0.012, -0.16)], 0.004), Color("f4f1ea"))
		"handschuhe":
			for s in [-1.0, 1.0]:
				b.add(ball(Vector3(0.045, 0.02, 0.06), 2.2), Color("8b5a36"), T(Vector3(0.05 * s, 0.02, 0), Vector3(0, 0.3 * s, 0)), CLOTH)
				b.add(ball(Vector3(0.015, 0.014, 0.028)), Color("8b5a36"), T(Vector3(0.05 * s + 0.04 * s, 0.018, 0.0), Vector3(0, 0.9 * s, 0)), CLOTH)
				b.add(cyl(0.035, 0.035, 0.03, 14), Color("f4ecd6"), T(Vector3(0.05 * s, 0.02, 0.06), Vector3(PI * 0.5, 0, 0)), CLOTH)
		"stiefel":
			b.add(ball(Vector3(0.05, 0.045, 0.12), 2.8, 10, 16), Color("6b4428"), T(Vector3(0, 0.045, -0.02)))
			b.add(cyl(0.05, 0.048, 0.12, 16), Color("6b4428"), T(Vector3(0, 0.05, 0.05)))
			b.add(ball(Vector3(0.056, 0.012, 0.125), 3.2), Color("e9dcc0"), T(Vector3(0, 0.006, -0.02)))
			for k in 3:
				b.add(tube([Vector3(-0.022, 0.085 + k * 0.02, 0.005 - k * 0.002), Vector3(0.022, 0.085 + k * 0.02, 0.005 - k * 0.002)], 0.004), Color("f4efe4"))
		"poncho":
			b.add(box(Vector3(0.26, 0.05, 0.22), 4.0), Color("4f8f4a"), T(Vector3(0, 0.025, 0)), CLOTH)
			b.add(ball(Vector3(0.09, 0.03, 0.05), 2.4), Color("447d40"), T(Vector3(0, 0.05, -0.09)), CLOTH)
			b.add(tube([Vector3(0.02, 0.052, -0.05), Vector3(0.04, 0.051, 0.02)], 0.004), Color("f2c53d"))
		"kompass":
			b.add(cyl(0.035, 0.035, 0.014, 22), Color("c9a24a"), T(), GLOSS)
			b.add(cyl(0.03, 0.03, 0.003, 22, 0.0), Color("f4f1ea"), T(Vector3(0, 0.013, 0)))
			b.add(ball(Vector3(0.004, 0.002, 0.02)), Color("d8453e"), T(Vector3(0, 0.017, -0.012)))
			b.add(ball(Vector3(0.004, 0.002, 0.02)), Color("2e3338"), T(Vector3(0, 0.017, 0.012)))
			b.add(ring(0.008, 0.003, 0.007), Color("c9a24a"), T(Vector3(0, 0, -0.04)), GLOSS)
		"karte":
			b.add(box(Vector3(0.16, 0.01, 0.12), 8.0), Color("f1e3c0"), T(Vector3(0, 0.005, 0)))
			for i in 4:
				b.add(ball(Vector3(0.03 - i * 0.004, 0.0015, 0.02 + i * 0.004), 2.0), [Color("9ccc4a"), Color("58a6e0"), Color("c9a86a"), Color("7fae4f")][i], T(Vector3(-0.05 + i * 0.03, 0.0105, sin(i) * 0.03)))
			b.add(tube([Vector3(-0.07, 0.012, 0.04), Vector3(-0.02, 0.012, 0.0), Vector3(0.02, 0.012, 0.02), Vector3(0.07, 0.012, -0.04)], 0.002), Color("d1493f"))
		"messer":
			b.add(box(Vector3(0.09, 0.018, 0.025), 6.0), Color("d1493f"), T(Vector3(0, 0.009, 0)), GLOSS)
			b.add(box(Vector3(0.012, 0.019, 0.004), 4.0), Color("f4f1ea"), T(Vector3(0, 0.009, -0.0)))
			b.add(box(Vector3(0.004, 0.019, 0.012), 4.0), Color("f4f1ea"), T(Vector3(0, 0.009, 0.0)))
			b.add(box(Vector3(0.06, 0.004, 0.018), 3.0), Color("c9d2d8"), T(Vector3(0.068, 0.012, 0.004), Vector3(0, 0.25, 0)), GLOSS)
		"stock":
			var pts := []
			for i in 13:
				var t := i / 12.0
				pts.append(Vector3(lerpf(-0.6, 0.6, t), 0.02 + sin(t * 9.0) * 0.004, sin(t * 3.0) * 0.012))
			b.add(Mesh3.tube(pts, 0.016, 7), Color("8b5a36"))
			b.add(ball(Vector3(0.026, 0.024, 0.024)), Color("6b4428"), T(Vector3(0.61, 0.024, 0)))
			b.add(ring(0.03, 0.005), Color("d1493f"), T(Vector3(0.5, 0.022, 0), Vector3(0, 0, PI * 0.5)))
		"laterne":
			b.add(cyl(0.045, 0.045, 0.02, 16), Color("2e3338"), T(), GLOSS)
			b.add(cyl(0.035, 0.035, 0.1, 16, 0.0), Color("ffe08a"), T(Vector3(0, 0.02, 0)))
			for i in 4:
				var a := i * TAU / 4.0
				b.add(tube([Vector3(cos(a) * 0.04, 0.02, sin(a) * 0.04), Vector3(cos(a) * 0.04, 0.12, sin(a) * 0.04)], 0.004), Color("2e3338"))
			b.add(lathe([Vector2(0, 0.12), Vector2(0.048, 0.12), Vector2(0.02, 0.15), Vector2(0, 0.155)], 16), Color("2e3338"), T(), GLOSS)
			b.add(tube([Vector3(-0.025, 0.15, 0), Vector3(-0.02, 0.185, 0), Vector3(0.02, 0.185, 0), Vector3(0.025, 0.15, 0)], 0.004), Color("9fb6c4"), T(), GLOSS)
		"pfeife":
			b.add(ball(Vector3(0.022, 0.016, 0.016), 3.0), Color("c9d2d8"), T(Vector3(0, 0.016, 0)), GLOSS)
			b.add(box(Vector3(0.03, 0.012, 0.014)), Color("c9d2d8"), T(Vector3(0.03, 0.022, 0)), GLOSS)
			b.add(ring(0.008, 0.002, 0.0), Color("9aa3ab"), T(Vector3(-0.028, 0.016, 0), Vector3(PI * 0.5, 0, 0)), GLOSS)
		"mundharmonika":
			b.add(box(Vector3(0.1, 0.02, 0.026)), Color("c9d2d8"), T(Vector3(0, 0.013, 0)), GLOSS)
			b.add(box(Vector3(0.098, 0.008, 0.027), 8.0), Color("a0703c"), T(Vector3(0, 0.013, 0)))
			for i in 10:
				b.add(box(Vector3(0.005, 0.004, 0.003), 3.0), Color("1b1820"), T(Vector3(-0.042 + i * 0.0093, 0.013, -0.0135)))
		"drachen":
			b.add(Mesh3.lathe([Vector2(0.0, -0.002), Vector2(0.2, 0.0), Vector2(0.0, 0.002)], 4, 1.4), Color("d1493f"), T(Vector3(0, 0.004, 0), Vector3(0, PI * 0.25, 0)), CLOTH)
			b.add(tube([Vector3(0, 0.006, -0.28), Vector3(0, 0.006, 0.28)], 0.004), Color("8b5a36"))
			b.add(tube([Vector3(-0.2, 0.006, -0.04), Vector3(0.2, 0.006, -0.04)], 0.004), Color("8b5a36"))
			var tail := []
			for i in 9:
				tail.append(Vector3(sin(i * 0.9) * 0.04, 0.004, 0.28 + i * 0.04))
			b.add(Mesh3.tube(tail, 0.002, 4), Color("f4f1ea"))
			for i in 3:
				b.add(ball(Vector3(0.018, 0.003, 0.008)), [Color("f2c53d"), Color("58a6e0"), Color("f2c53d")][i], T(tail[2 + i * 3]))
		"federn":
			b.add(ball(Vector3(0.018, 0.002, 0.08), 2.0, 6, 12), Color("f4f1ea"), T(Vector3(0, 0.003, 0)), CLOTH)
			b.add(tube([Vector3(0, 0.004, -0.1), Vector3(0, 0.005, 0.08)], 0.0018), Color("c9c2b4"))
			b.add(ball(Vector3(0.012, 0.0022, 0.02)), Color("7fb6d8"), T(Vector3(0, 0.004, 0.05)))
		"muschel":
			# scallop: a ribbed fan with a little hinge
			b.add(ball(Vector3(0.045, 0.012, 0.04), 2.0, 8, 16), Color("f6b69c"), T(Vector3(0, 0.012, 0)))
			for i in 9:
				var a := -1.15 + i * 0.29
				b.add(tube([Vector3(0, 0.018, 0.036), Vector3(sin(a) * 0.022, 0.024, 0.036 - cos(a) * 0.04), Vector3(sin(a) * 0.043, 0.016, 0.036 - cos(a) * 0.074)], 0.0045), Color("e8826a") if i % 2 == 0 else Color("fbd3c0"))
			b.add(box(Vector3(0.034, 0.014, 0.014), 3.0), Color("e8826a"), T(Vector3(0, 0.01, 0.042)))
		"tannenzapfen":
			b.add(ball(Vector3(0.025, 0.05, 0.025), 2.0), Color("6b4428"), T(Vector3(0, 0.05, 0)))
			for i in 34:
				var y := 0.012 + i * 0.0026
				var a := i * 2.4
				var r := 0.022 * sin(PI * (y - 0.005) / 0.1) + 0.006
				b.add(ball(Vector3(0.012, 0.006, 0.01)), Color("8b5a36").lerp(Color("a0703c"), float(i % 3) / 3.0), T(Vector3(cos(a) * r, y, sin(a) * r), Vector3(0.5, -a, 0)))
		"glueckskeks":
			b.add(ball(Vector3(0.03, 0.022, 0.02)), Color("e8b877"), T(Vector3(-0.012, 0.02, 0), Vector3(0, 0, 0.5)))
			b.add(ball(Vector3(0.03, 0.022, 0.02)), Color("e0ac66"), T(Vector3(0.012, 0.02, 0), Vector3(0, 0, -0.5)))
			b.add(box(Vector3(0.01, 0.002, 0.04), 4.0), Color("f4f1ea"), T(Vector3(0.0, 0.026, 0.02)))
		"streichhoelzer":
			# a little matchbox, half open, a few red-tipped matches
			b.add(box(Vector3(0.06, 0.016, 0.04), 8.0), Color("f2d36b"), T(Vector3(0, 0.008, 0)))
			b.add(box(Vector3(0.061, 0.012, 0.03), 8.0), Color("c8453e"), T(Vector3(0, 0.009, 0)))
			b.add(box(Vector3(0.05, 0.012, 0.036), 8.0), Color("e9dcc0"), T(Vector3(0.022, 0.013, 0)))
			for i in 4:
				var z := -0.012 + i * 0.008
				b.add(box(Vector3(0.045, 0.003, 0.003), 3.0), Color("e8c890"), T(Vector3(0.03, 0.02, z)))
				b.add(ball(Vector3(0.0045, 0.004, 0.004)), Color("c22f2a"), T(Vector3(0.053, 0.02, z)))
			b.add(box(Vector3(0.062, 0.017, 0.006), 4.0), Color("7a4a2a"), T(Vector3(0, 0.008, 0.019)))
		"feuerzeug":
			b.add(box(Vector3(0.024, 0.07, 0.012), 6.0), Color("3f7fc8"), T(Vector3(0, 0.035, 0)), GLOSS)
			b.add(box(Vector3(0.022, 0.018, 0.011), 5.0), Color("c9ced3"), T(Vector3(0, 0.078, 0)), GLOSS)
			b.add(cyl(0.006, 0.006, 0.008, 10), Color("5a5d61"), T(Vector3(0.004, 0.09, 0), Vector3(PI * 0.5, 0, 0)))
		"marshmallows":
			# a see-through bag with pink and white marshmallows
			b.add(ball(Vector3(0.065, 0.05, 0.04), 2.6, 10, 16), Color("eef3f7"), T(Vector3(0, 0.05, 0)), GLOSS)
			var cols := [Color("fbe6ee"), Color("f7b6cf"), Color("ffffff"), Color("f7b6cf"), Color("fbe6ee"), Color("ffffff")]
			for i in 6:
				var a := i * 1.1
				b.add(cyl(0.017, 0.017, 0.022, 12, 0.006), cols[i], T(Vector3(cos(a) * 0.028, 0.03 + (i % 2) * 0.03, sin(a) * 0.016), Vector3(0.3 * (i % 3), a, 0)))
			b.add(box(Vector3(0.06, 0.012, 0.012), 4.0), Color("e0507a"), T(Vector3(0, 0.1, 0)))
		"kiesel":
			b.add(ball(Vector3(0.045, 0.011, 0.035), 2.4, 8, 16), Color("9aa0a4"), T(Vector3(0, 0.011, 0)))
			b.add(ball(Vector3(0.03, 0.004, 0.02), 2.0, 5, 10), Color("b8bdc0"), T(Vector3(-0.008, 0.019, 0.004)))
		"fliegenpilz":
			b.add(lathe([Vector2(0, 0), Vector2(0.012, 0), Vector2(0.01, 0.05), Vector2(0.014, 0.055), Vector2(0, 0.055)], 12), Color("f4efe4"))
			b.add(lathe([Vector2(0, 0.05), Vector2(0.045, 0.052), Vector2(0.04, 0.066), Vector2(0.022, 0.078), Vector2(0, 0.08)], 16), Color("d8322a"), T(), GLOSS)
			for i in 7:
				var a2 := i * 2.3
				var r2 := 0.012 + (i % 3) * 0.009
				b.add(ball(Vector3(0.005, 0.003, 0.005)), Color("fffbf0"), T(Vector3(cos(a2) * r2, 0.078 - r2 * 0.45, sin(a2) * r2)))
		_:
			b.add(box(Vector3(0.08, 0.08, 0.08)), Color("ff00ff"))


static func _ellipse(rx: float, rz: float, y: float, n: int) -> Array:
	var pts := []
	for i in n + 1:
		var a := TAU * i / n
		pts.append(Vector3(cos(a) * rx, y, sin(a) * rz))
	return pts
